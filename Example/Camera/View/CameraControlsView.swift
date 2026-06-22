import SwiftUI

struct CameraControlsView: View {
    let session: CameraSession
    @State private var showSettings = false

    var body: some View {
        HStack {
            galleryButton
            Spacer()
            ShutterButton {
                session.capturePhoto()
            }
            Spacer()
            settingsButton
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 20)
    }

    private var galleryButton: some View {
        Button {
            if let url = URL(string: "photos-redirect://") {
                UIApplication.shared.open(url)
            }
        } label: {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .glassEffect(in: Circle())
        }
        .accessibilityLabel("Open Photos")
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .glassEffect(in: Circle())
        }
        .accessibilityLabel("Settings")
        .popover(isPresented: $showSettings) {
            CameraSettingsPopover(session: session)
                .frame(minWidth: 360, minHeight: 480)
        }
    }
}
