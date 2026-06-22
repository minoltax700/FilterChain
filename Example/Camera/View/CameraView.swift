import SwiftUI

struct CameraView: View {
    @State private var session = CameraSession()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.authStatus {
            case .denied:
                permissionDeniedView
            default:
                cameraStack
            }
        }
        .navigationBarHidden(true)
        .task {
            await session.requestPermissionsAndConfigure()
            await session.start()
        }
        .onDisappear {
            Task { await session.stop() }
        }
    }

    private var previewAspectRatio: CGFloat {
        let s = session.previewSize
        guard s.width > 0, s.height > 0 else { return 3.0 / 4.0 }
        return s.width / s.height
    }

    private var cameraStack: some View {
        ZStack {
            MetalCameraView(session: session)
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .onTapGesture(count: 2) {
                    session.flipCamera()
                }

            VStack {
                Spacer()

                CameraControlsView(session: session)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 52))
                .foregroundStyle(.white)
            Text("Camera Access Needed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Enable camera access in Settings to take photos.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(40)
    }
}
