import MetalKit
import MetalPerformanceShaders
import simd

public enum BendRendererError: Error, CustomStringConvertible {
    case commandQueueCreationFailed
    case shaderSourceMissing
    case shaderFunctionMissing
    case bufferCreationFailed
    case samplerCreationFailed

    public var description: String {
        switch self {
        case .commandQueueCreationFailed: "Could not create a Metal command queue."
        case .shaderSourceMissing: "Could not locate the bundled Shaders.metal source."
        case .shaderFunctionMissing: "Could not find the bend vertex or fragment function."
        case .bufferCreationFailed: "Could not create a Metal buffer."
        case .samplerCreationFailed: "Could not create a Metal sampler state."
        }
    }
}

private struct FragmentUniforms {
    var shadeAmount: Float
    var desaturation: Float
}

private struct BackgroundUniforms {
    var alpha: Float
}

public final class BendRenderer: NSObject, MTKViewDelegate {
    private static let maxShadeAmount: Float = 1.4
    private static let maxForegroundBlurSigma: Float = 14
    private static let maxBackgroundAlpha: Float = 1.0

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let foregroundPipelineState: MTLRenderPipelineState
    private let backgroundPipelineState: MTLRenderPipelineState
    private let positionBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    private let samplerState: MTLSamplerState

    private var foregroundBlurTexture: MTLTexture?

    public var lidAngleDegreesProvider: () -> Double = { BendConfiguration.default.clearAngleDegrees }
    public var textureProvider: () -> MTLTexture? = { nil }
    public var configuration: BendConfiguration = .default

    public init(device: MTLDevice) throws {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw BendRendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        guard let shaderURL = Bundle.module.url(forResource: "Shaders", withExtension: "metal") else {
            throw BendRendererError.shaderSourceMissing
        }
        let shaderSource = try String(contentsOf: shaderURL, encoding: .utf8)
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        guard let vertexFunction = library.makeFunction(name: "bend_vertex"),
              let foregroundFragmentFunction = library.makeFunction(name: "bend_fragment"),
              let backgroundFragmentFunction = library.makeFunction(name: "background_fragment")
        else {
            throw BendRendererError.shaderFunctionMissing
        }

        let foregroundDescriptor = MTLRenderPipelineDescriptor()
        foregroundDescriptor.vertexFunction = vertexFunction
        foregroundDescriptor.fragmentFunction = foregroundFragmentFunction
        foregroundDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        foregroundPipelineState = try device.makeRenderPipelineState(descriptor: foregroundDescriptor)

        let backgroundDescriptor = MTLRenderPipelineDescriptor()
        backgroundDescriptor.vertexFunction = vertexFunction
        backgroundDescriptor.fragmentFunction = backgroundFragmentFunction
        backgroundDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        backgroundPipelineState = try device.makeRenderPipelineState(descriptor: backgroundDescriptor)

        let positions: [SIMD3<Float>] = [
            SIMD3(-1, -1, 0), SIMD3(1, -1, 0), SIMD3(-1, 1, 0),
            SIMD3(1, -1, 0), SIMD3(1, 1, 0), SIMD3(-1, 1, 0),
        ]
        let texCoords: [SIMD2<Float>] = [
            SIMD2(0, 1), SIMD2(1, 1), SIMD2(0, 0),
            SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 0),
        ]

        guard let positionBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<SIMD3<Float>>.stride * positions.count),
              let texCoordBuffer = device.makeBuffer(bytes: texCoords, length: MemoryLayout<SIMD2<Float>>.stride * texCoords.count)
        else {
            throw BendRendererError.bufferCreationFailed
        }
        self.positionBuffer = positionBuffer
        self.texCoordBuffer = texCoordBuffer

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw BendRendererError.samplerCreationFailed
        }
        self.samplerState = samplerState
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let sourceTexture = textureProvider(),
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        let lidAngle = lidAngleDegreesProvider()
        let configuration = configuration
        let bendFraction = Float(BendTransform.bendFraction(forLidAngleDegrees: lidAngle, clearAngleDegrees: configuration.clearAngleDegrees))
        let styleParameters = configuration.style.parameters

        let foregroundBlurSigma = bendFraction * Self.maxForegroundBlurSigma * styleParameters.blurScale * Float(configuration.blurAmount)
        let foregroundBlurred = blur(source: sourceTexture, sigma: foregroundBlurSigma, cache: &foregroundBlurTexture, commandBuffer: commandBuffer)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        var identity = matrix_identity_float4x4
        var backgroundUniforms = BackgroundUniforms(alpha: Self.maxBackgroundAlpha)
        encoder.setRenderPipelineState(backgroundPipelineState)
        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&identity, length: MemoryLayout<float4x4>.size, index: 2)
        encoder.setFragmentBytes(&backgroundUniforms, length: MemoryLayout<BackgroundUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        let tilt = BendTransform.tiltDegrees(
            forLidAngleDegrees: lidAngle,
            clearAngleDegrees: configuration.clearAngleDegrees,
            maxTiltDegrees: configuration.perspectiveDepth
        )
        var mvp = BendTransform.matrix(angleDegrees: tilt)
        var foregroundUniforms = FragmentUniforms(
            shadeAmount: bendFraction * Self.maxShadeAmount * styleParameters.shadowScale * Float(configuration.shadowStrength),
            desaturation: bendFraction * styleParameters.desaturation
        )
        encoder.setRenderPipelineState(foregroundPipelineState)
        encoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.size, index: 2)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentTexture(foregroundBlurred, index: 1)
        encoder.setFragmentBytes(&foregroundUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func blur(source: MTLTexture, sigma: Float, cache: inout MTLTexture?, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        guard sigma > 0.1 else { return source }

        if cache == nil || cache?.width != source.width || cache?.height != source.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: source.pixelFormat,
                width: source.width,
                height: source.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            cache = device.makeTexture(descriptor: descriptor)
        }

        guard let destination = cache else { return source }

        let blur = MPSImageGaussianBlur(device: device, sigma: sigma)
        blur.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }
}
