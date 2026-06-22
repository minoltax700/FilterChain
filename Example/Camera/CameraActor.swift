import AVFoundation
import FilterChain

actor CameraActor {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutputSampleBufferProcessor = VideoDataOutputSampleBufferProcessor()

    private var videoDeviceInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back

    func setFilterChain(_ filterChain: FilterChain) {
        videoDataOutputSampleBufferProcessor.filterChain = filterChain
    }

    func configure(settings: CameraSettingsSnapshot) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        if session.canSetSessionPreset(settings.preset) {
            session.sessionPreset = settings.preset
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        videoDataOutputSampleBufferProcessor.attach(to: session, position: position)
        applyDeviceSettings(settings, device: device)
    }

    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func applySettings(_ settings: CameraSettingsSnapshot) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(settings.preset) {
            session.sessionPreset = settings.preset
        }
        if let device = videoDeviceInput?.device {
            applyDeviceSettings(settings, device: device)
        }
    }

    private func applyDeviceSettings(_ settings: CameraSettingsSnapshot, device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if settings.hdrEnabled,
               let hdrFormat = device.formats.last(where: { $0.isVideoHDRSupported }) {
                device.activeFormat = hdrFormat
            }
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = false
                device.isVideoHDREnabled = settings.hdrEnabled
            }

            if device.activeFormat.supportedColorSpaces.contains(settings.colorSpace) {
                device.activeColorSpace = settings.colorSpace
            }
        } catch {}
    }

    func flipCamera() {
        guard let currentInput = videoDeviceInput else { return }
        let newPosition: AVCaptureDevice.Position = (position == .back) ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.removeInput(currentInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            videoDeviceInput = newInput
            position = newPosition
        } else {
            session.addInput(currentInput)
        }
        videoDataOutputSampleBufferProcessor.updateConnection(position: position)
    }

    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.photoQualityPrioritization = .quality
        photoOutput.capturePhoto(with: photoSettings, delegate: PhotoCaptureProcessor())
    }
}
