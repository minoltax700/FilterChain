import Metal

final class IntermediateTexturePool {
    private let device: MTLDevice
    private let pixelFormat: MTLPixelFormat
    private var textures: (MTLTexture, MTLTexture)?
    private var cachedWidth: Int = 0
    private var cachedHeight: Int = 0

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.device = device
        self.pixelFormat = pixelFormat
    }

    func pair(width: Int, height: Int) throws -> (MTLTexture, MTLTexture) {
        if let t = textures, cachedWidth == width, cachedHeight == height {
            return t
        }
        guard let a = makeTexture(width: width, height: height),
              let b = makeTexture(width: width, height: height) else {
            throw FilterChainError.failedToMakeOutputTexture
        }
        textures = (a, b)
        cachedWidth = width
        cachedHeight = height
        return (a, b)
    }

    func invalidate() {
        textures = nil
    }

    private func makeTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        return device.makeTexture(descriptor: descriptor)
    }
}
