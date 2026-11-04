import SwiftUI

/// The reveal (N05–N07): one lamp button that switches between the normal
/// view and the UV view at any time (FR-007). The warning light is off in the normal view and lit
/// in the UV view.
struct UVRevealView: View {
    var mode: Renderer.ViewMode
    let onShow: (Renderer.ViewMode) -> Void

    var body: some View {
        VStack {
            Spacer()
            lampButton
                .padding(.bottom, 60)
        }
    }

    private var lampButton: some View {
        let isOn = mode == .uv
        return Button { onShow(isOn ? .normal : .uv) } label: {
            Image(systemName: isOn ? "exclamationmark.warninglight.fill" : "warninglight")
                .font(.system(size: 52, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isOn ? .black : .white)
                .frame(width: 120, height: 120)
                .background(Circle().fill(isOn ? .white : .black.opacity(0.55)))
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                .animation(Motion.quick, value: isOn)
        }
        .buttonStyle(PressableStyle(shape: Circle(), minHitSize: 120))
        .accessibilityLabel(Text(isOn ? "Normal view" : "Lamp view"))
    }
}
