import SwiftUI

struct CameraSettingsPopover: View {
    let session: CameraSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Camera") {
                    Picker("Resolution", selection: bindingResolution) {
                        ForEach(CameraSettings.Resolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }

                    Toggle("HDR", isOn: bindingHDR)

                    Picker("Color Space", selection: bindingColorSpace) {
                        ForEach(CameraSettings.ColorSpace.allCases) { space in
                            Text(space.rawValue).tag(space)
                        }
                    }
                }

                Section("Filters") {
                    Toggle("Vintage B&W", isOn: bindingVintageBW)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var bindingResolution: Binding<CameraSettings.Resolution> {
        Binding(
            get: { session.settings.resolution },
            set: { session.settings.resolution = $0; session.applyCameraSettings() }
        )
    }

    private var bindingHDR: Binding<Bool> {
        Binding(
            get: { session.settings.hdrEnabled },
            set: { session.settings.hdrEnabled = $0; session.applyCameraSettings() }
        )
    }

    private var bindingColorSpace: Binding<CameraSettings.ColorSpace> {
        Binding(
            get: { session.settings.colorSpace },
            set: { session.settings.colorSpace = $0; session.applyCameraSettings() }
        )
    }

    private var bindingVintageBW: Binding<Bool> {
        Binding(
            get: { session.settings.vintageBWEnabled },
            set: { session.settings.vintageBWEnabled = $0; session.applyFilterSettings() }
        )
    }

}
