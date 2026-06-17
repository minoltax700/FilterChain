import CoreVideo
import Metal

struct TextureCache {
    let pixelFormat: MTLPixelFormat
    private let cache: CVMetalTextureCache
    
    init?(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        var createdCache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &createdCache)
        guard status == kCVReturnSuccess, let createdCache else { return nil }
        cache = createdCache
        
        self.pixelFormat = pixelFormat
    }
    
    func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvMetalTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               cache,
                                                               pixelBuffer,
                                                               nil,
                                                               pixelFormat,
                                                               width,
                                                               height,
                                                               0,
                                                               &cvMetalTexture)
        guard status == kCVReturnSuccess,
              let cvMetalTexture,
              let mtlTexture = CVMetalTextureGetTexture(cvMetalTexture) else {
            return nil
        }
        
        return mtlTexture
    }
        
}
