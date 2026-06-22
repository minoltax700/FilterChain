import AVFoundation
import Photos

nonisolated final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var selfRetain: PhotoCaptureProcessor?

    override init() {
        super.init()
        selfRetain = self
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { selfRetain = nil }
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        save(jpeg: data)
    }

    private func save(jpeg: Data) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: jpeg, options: nil)
            }
        }
    }
}
