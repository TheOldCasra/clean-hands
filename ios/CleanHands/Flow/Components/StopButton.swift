import SwiftUI

/// Large Stop control on every participant screen: a red square, not a hand. One tap ends the
/// session with no confirmation (contracts/ui-flow.md, Principle V).
struct StopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red)
                .frame(width: 56, height: 56)
                .padding(18)
                .background(Circle().fill(.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Stop"))
    }
}
