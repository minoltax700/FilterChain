import AVFoundation
import Observation
import FilterChain

@MainActor
@Observable
final class CameraSession {
    enum AuthStatus {
        case unknown, authorized, denied
    }

    var authStatus: AuthStatus = .unknown
    var previewSize: CGSize = .zero

    let settings = CameraSettings()

    private let cameraActor = CameraActor()
    private var configured = false

    func attachFilterChain(_ filterChain: FilterChain) {
        Task { await cameraActor.setFilterChain(filterChain) }
    }

    func requestPermissionsAndConfigure() async {
        let granted = await requestCameraAccess()
        guard granted else {
            authStatus = .denied
            return
        }
        authStatus = .authorized

        if !configured {
            let snapshot = CameraSettingsSnapshot(settings)
            await cameraActor.configure(settings: snapshot)
            configured = true
        }
    }

    func start() async {
        guard authStatus == .authorized else { return }
        await cameraActor.start()
    }

    func stop() async {
        await cameraActor.stop()
    }

    func capturePhoto() {
        Task { await cameraActor.capturePhoto() }
    }

    func flipCamera() {
        Task { await cameraActor.flipCamera() }
    }

    func applyCameraSettings() {
        let snapshot = CameraSettingsSnapshot(settings)
        Task { await cameraActor.applySettings(snapshot) }
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
