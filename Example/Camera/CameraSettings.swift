import AVFoundation
import Observation

@MainActor
@Observable
final class CameraSettings {
    enum Resolution: String, CaseIterable, Identifiable {
        case photo = "Photo"
        case hd1080 = "1080p HD"
        case uhd4K = "4K"

        var id: String { rawValue }

        var preset: AVCaptureSession.Preset {
            switch self {
            case .photo: return .photo
            case .hd1080: return .hd1920x1080
            case .uhd4K: return .hd4K3840x2160
            }
        }
    }

    enum ColorSpace: String, CaseIterable, Identifiable {
        case sRGB = "sRGB"
        case displayP3 = "Display P3"
        case hlgBT2020 = "HLG BT.2020"

        var id: String { rawValue }

        var avColorSpace: AVCaptureColorSpace {
            switch self {
            case .sRGB: return .sRGB
            case .displayP3: return .P3_D65
            case .hlgBT2020: return .HLG_BT2020
            }
        }
    }

    var resolution: Resolution = .photo
    var hdrEnabled: Bool = true
    var colorSpace: ColorSpace = .sRGB
}

struct CameraSettingsSnapshot: Sendable {
    let preset: AVCaptureSession.Preset
    let hdrEnabled: Bool
    let colorSpace: AVCaptureColorSpace

    @MainActor
    init(_ settings: CameraSettings) {
        self.preset = settings.resolution.preset
        self.hdrEnabled = settings.hdrEnabled
        self.colorSpace = settings.colorSpace.avColorSpace
    }
}
