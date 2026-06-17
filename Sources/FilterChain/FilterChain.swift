import Metal
import MetalKit
import CoreMedia

public enum FilterChainError: Error {
    case noMetalDevice
    case noMetalLibrary
    case noMetalFunctions
    case noMetalPipeline
}

/// A renderer for a linear sequence of Filters.
public final class FilterChain: NSObject {
    /// Set as MTKViewDelegate for view-driven, pull-style rendering.
    public var mtkViewDelegate: MTKViewDelegate?

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    private let pixelFormat: MTLPixelFormat
    private let textureCache: TextureCache
    private var inputTexture: MTLTexture?
    
    private lazy var passThroughPipeline: MTLRenderPipelineState? = {
        return try? makePipeline(vertex: "passThroughVertex", fragment: "passThroughFragment", bundle: Bundle(for: Self.self))
    }()
    private var pipelines: [MTLRenderPipelineState] = []
    private var libraryForBundle: [Bundle: MTLLibrary] = [:]

    /// Pass in the pixel format to set it for the internal texture cache and the pipeline descriptor color attachment.
    public init?(pixelFormat: MTLPixelFormat) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let textureCache = TextureCache(device: device, pixelFormat: pixelFormat) else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        self.pixelFormat = pixelFormat
        self.textureCache = textureCache
    }
    
    /// The input CMSampleBuffer to be rendered on to the MTKView. Requires the mtkViewDelegate to be set.
    public func updateInput(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        inputTexture = textureCache.createTexture(from: pixelBuffer)
    }
    
    /// Set the sequence of Filters to render. If empty, a pass through render will be done.
    public func setFilters(_ filters: [Filter]) throws {
        pipelines = try filters.map { try makePipeline(vertex: $0.vertexFunction, fragment: $0.fragmentFunction, bundle: $0.bundle) }
    }
    
    private func makePipeline(vertex: String, fragment: String, bundle: Bundle) throws -> MTLRenderPipelineState  {
        var library: MTLLibrary?
        
        if let libraryForBundle = libraryForBundle[bundle] {
            library = libraryForBundle
        } else {
            library = try device.makeDefaultLibrary(bundle: bundle)
        }
        
        guard let library else {
            throw FilterChainError.noMetalLibrary
        }
        
        guard let vertexFunction = library.makeFunction(name: vertex),
              let fragmentFunction = library.makeFunction(name: fragment) else {
            throw FilterChainError.noMetalFunctions
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
}

extension FilterChain: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        if pipelines.isEmpty {
            guard let passThroughPipeline else { return }
            encoder.setRenderPipelineState(passThroughPipeline)
            encoder.setFragmentTexture(inputTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 3)
        } else {
            // TODO: Actually support rendering external Filters
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
