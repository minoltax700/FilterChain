import AVFoundation
import FilterChain

nonisolated final class VideoDataOutputSampleBufferProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let output = AVCaptureVideoDataOutput()
    let videoDataQueue = DispatchQueue(label: "com.example.videoData", qos: .userInteractive)

    var filterChain: FilterChain?

    func attach(to session: AVCaptureSession, position: AVCaptureDevice.Position) {
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoDataQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            connection.isVideoMirrored = (position == .front)
        }
    }

    func updateConnection(position: AVCaptureDevice.Position) {
        guard let connection = output.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        connection.isVideoMirrored = (position == .front)
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        filterChain?.updateInput(sampleBuffer: sampleBuffer)
    }
}
