import SwiftUI

struct ShutterButton: View {
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Circle()
                .frame(width: 72, height: 72)
                .glassEffect(in: Circle())
                .scaleEffect(pressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.12)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.18)) { pressed = false }
                }
        )
        .accessibilityLabel("Shutter")
    }
}
