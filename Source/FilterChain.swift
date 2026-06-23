import Metal
import MetalKit
import CoreMedia

public enum FilterChainError: Error {
    case noMetalDevice
    case noMetalLibrary
    case noMetalFunctions
    case noMetalPipeline
    case failedToMakeInputTextureFromPixelBuffer
    case failedToMakeOutputTexture
    case failedToMakeRenderCommandEncoder
}

/// A renderer for a linear sequence of Filters.
public final class FilterChain: NSObject {
    public var mtkViewDelegate: MTKViewDelegate?

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pixelFormat: MTLPixelFormat
    private let textureCache: TextureCache
    private let passThroughLibrary: MTLLibrary
    private let passThroughPipeline: MTLRenderPipelineState
    private let intermediatePool: IntermediateTexturePool

    private var inputTexture: MTLTexture?
    private var pipelines: [MTLRenderPipelineState] = []
    private var libraryForBundle: [Bundle: MTLLibrary] = [:]

    public init?(pixelFormat: MTLPixelFormat) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let textureCache = TextureCache(device: device, pixelFormat: pixelFormat),
              let library = try? device.makeDefaultLibrary(bundle: .module),
              let vertexFn = library.makeFunction(name: "passThroughVertex"),
              let fragmentFn = library.makeFunction(name: "passThroughFragment") else {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFn
        pipelineDescriptor.fragmentFunction = fragmentFn
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        guard let passThroughPipeline = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pixelFormat = pixelFormat
        self.textureCache = textureCache
        self.passThroughLibrary = library
        self.passThroughPipeline = passThroughPipeline
        self.intermediatePool = IntermediateTexturePool(device: device, pixelFormat: pixelFormat)
    }

    // MARK: - Pull-based (MTKView) rendering

    public func updateInput(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        updateInput(pixelBuffer: pixelBuffer)
    }

    public func updateInput(pixelBuffer: CVPixelBuffer) {
        inputTexture = textureCache.createTexture(from: pixelBuffer)
    }

    // MARK: - Push-based rendering

    public func render(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        guard let inputTexture = textureCache.createTexture(from: pixelBuffer) else {
            throw FilterChainError.failedToMakeInputTextureFromPixelBuffer
        }
        guard let (outputPixelBuffer, outputTexture) = textureCache.createTextureBackedPixelBuffer(
            width: inputTexture.width, height: inputTexture.height
        ) else {
            throw FilterChainError.failedToMakeOutputTexture
        }
        try render(inputTexture: inputTexture, to: outputTexture)
        return outputPixelBuffer
    }

    public func render(texture: MTLTexture) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw FilterChainError.failedToMakeOutputTexture
        }
        try render(inputTexture: texture, to: outputTexture)
        return outputTexture
    }

    public func render(inputTexture: MTLTexture, to outputTexture: MTLTexture) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw FilterChainError.failedToMakeRenderCommandEncoder
        }
        try encodePipelines(from: inputTexture, to: outputTexture, in: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    // MARK: - Filters

    public func setFilters(_ filters: [Filter]) throws {
        pipelines = try filters.map { try makePipeline(for: $0) }
        if pipelines.count <= 1 {
            intermediatePool.invalidate()
        }
    }

    // MARK: - Private

    private func encodePipelines(
        from inputTexture: MTLTexture,
        to outputTexture: MTLTexture,
        in commandBuffer: MTLCommandBuffer
    ) throws {
        if pipelines.isEmpty {
            try encode(pipeline: passThroughPipeline, input: inputTexture, output: outputTexture, into: commandBuffer)
            return
        }
        if pipelines.count == 1 {
            try encode(pipeline: pipelines[0], input: inputTexture, output: outputTexture, into: commandBuffer)
            return
        }
        let (ping, pong) = try intermediatePool.pair(width: inputTexture.width, height: inputTexture.height)
        var current = inputTexture
        var usePing = true
        for (i, pipeline) in pipelines.enumerated() {
            let isLast = i == pipelines.count - 1
            let output: MTLTexture = isLast ? outputTexture : (usePing ? ping : pong)
            try encode(pipeline: pipeline, input: current, output: output, into: commandBuffer)
            current = output
            usePing.toggle()
        }
    }

    private func encode(
        pipeline: MTLRenderPipelineState,
        input: MTLTexture,
        output: MTLTexture,
        into commandBuffer: MTLCommandBuffer
    ) throws {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = output
        descriptor.colorAttachments[0].loadAction = .dontCare
        descriptor.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw FilterChainError.failedToMakeRenderCommandEncoder
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(input, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func makePipeline(for filter: Filter) throws -> MTLRenderPipelineState {
        guard let vertexFn = passThroughLibrary.makeFunction(name: "passThroughVertex") else {
            throw FilterChainError.noMetalFunctions
        }
        let fragmentLibrary = try cachedLibrary(for: filter.bundle)
        guard let fragmentFn = fragmentLibrary.makeFunction(name: filter.fragmentFunction) else {
            throw FilterChainError.noMetalFunctions
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func cachedLibrary(for bundle: Bundle) throws -> MTLLibrary {
        if let cached = libraryForBundle[bundle] { return cached }
        let library = try device.makeDefaultLibrary(bundle: bundle)
        libraryForBundle[bundle] = library
        return library
    }
}

// MARK: - MTKViewDelegate

extension FilterChain: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let inputTexture,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        do {
            if pipelines.isEmpty {
                guard let descriptor = view.currentRenderPassDescriptor,
                      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
                encoder.setRenderPipelineState(passThroughPipeline)
                encoder.setFragmentTexture(inputTexture, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            } else {
                var current = inputTexture

                if pipelines.count > 1 {
                    let (ping, pong) = try intermediatePool.pair(
                        width: inputTexture.width,
                        height: inputTexture.height
                    )
                    var usePing = true
                    for i in 0 ..< pipelines.count - 1 {
                        let output = usePing ? ping : pong
                        try encode(pipeline: pipelines[i], input: current, output: output, into: commandBuffer)
                        current = output
                        usePing.toggle()
                    }
                }

                guard let lastPipeline = pipelines.last,
                      let descriptor = view.currentRenderPassDescriptor,
                      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
                encoder.setRenderPipelineState(lastPipeline)
                encoder.setFragmentTexture(current, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }
        } catch {
            return
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
