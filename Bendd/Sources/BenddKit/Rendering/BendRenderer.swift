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

public final class BendRenderer: NSObject, MTKViewDelegate {
    private static let maxShadeAmount: Float = 0.6
    private static let maxBlurSigma: Float = 14

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let positionBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    private let samplerState: MTLSamplerState

    private var blurredTexture: MTLTexture?

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
              let fragmentFunction = library.makeFunction(name: "bend_fragment")
        else {
            throw BendRendererError.shaderFunctionMissing
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

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

        let blurSigma = bendFraction * Self.maxBlurSigma * styleParameters.blurScale * Float(configuration.blurAmount)
        let sceneTexture = blurredTexture(for: sourceTexture, sigma: blurSigma, commandBuffer: commandBuffer)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let tilt = BendTransform.tiltDegrees(
            forLidAngleDegrees: lidAngle,
            clearAngleDegrees: configuration.clearAngleDegrees,
            maxTiltDegrees: configuration.perspectiveDepth
        )
        var mvp = BendTransform.matrix(angleDegrees: tilt, aspectRatio: aspectRatio)
        var uniforms = FragmentUniforms(
            shadeAmount: bendFraction * Self.maxShadeAmount * styleParameters.shadowScale * Float(configuration.shadowStrength),
            desaturation: bendFraction * styleParameters.desaturation
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.size, index: 2)
        encoder.setFragmentTexture(sceneTexture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func blurredTexture(for source: MTLTexture, sigma: Float, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        guard sigma > 0.1 else { return source }

        if blurredTexture == nil || blurredTexture?.width != source.width || blurredTexture?.height != source.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: source.pixelFormat,
                width: source.width,
                height: source.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            blurredTexture = device.makeTexture(descriptor: descriptor)
        }

        guard let destination = blurredTexture else { return source }

        let blur = MPSImageGaussianBlur(device: device, sigma: sigma)
        blur.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }
}
