import MetalKit
import SwiftUI
import FilterChain

struct MetalCameraView: UIViewRepresentable {
    let session: CameraSession

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            return view
        }
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30
        view.contentMode = .scaleAspectFill

        if let filterChain = FilterChain(pixelFormat: .bgra8Unorm) {
            context.coordinator.filterChain = filterChain
            view.delegate = filterChain
            session.attachFilterChain(filterChain)
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    final class Coordinator {
        var filterChain: FilterChain?
    }
}
