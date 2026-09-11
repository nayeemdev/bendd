import MetalKit
import simd

enum RendererError: Error, CustomStringConvertible {
    case commandQueueCreationFailed
    case shaderSourceMissing
    case shaderFunctionMissing
    case bufferCreationFailed
    case samplerCreationFailed

    var description: String {
        switch self {
        case .commandQueueCreationFailed: "Could not create a Metal command queue."
        case .shaderSourceMissing: "Could not locate the bundled Shaders.metal source."
        case .shaderFunctionMissing: "Could not find the bend vertex or fragment function."
        case .bufferCreationFailed: "Could not create a Metal buffer."
        case .samplerCreationFailed: "Could not create a Metal sampler state."
        }
    }
}

final class Renderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let positionBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    private let texture: MTLTexture
    private let samplerState: MTLSamplerState

    var angleDegrees: Float = 55

    init(device: MTLDevice, textureURL: URL) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        guard let shaderURL = Bundle.module.url(forResource: "Shaders", withExtension: "metal") else {
            throw RendererError.shaderSourceMissing
        }
        let shaderSource = try String(contentsOf: shaderURL, encoding: .utf8)
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        guard let vertexFunction = library.makeFunction(name: "bend_vertex"),
              let fragmentFunction = library.makeFunction(name: "bend_fragment")
        else {
            throw RendererError.shaderFunctionMissing
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
            throw RendererError.bufferCreationFailed
        }
        self.positionBuffer = positionBuffer
        self.texCoordBuffer = texCoordBuffer

        texture = try MTKTextureLoader(device: device).newTexture(URL: textureURL, options: [.SRGB: false])

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw RendererError.samplerCreationFailed
        }
        self.samplerState = samplerState
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        var mvp = PerspectiveBend.matrix(angleDegrees: angleDegrees, aspectRatio: aspectRatio)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.size, index: 2)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
