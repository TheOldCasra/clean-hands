import SwiftUI

/// The reveal (N05–N07): a turn-hand prompt, and eye / lamp buttons to switch between the normal
/// view and the UV view at any time (FR-007).
struct UVRevealView: View {
    var mode: Renderer.ViewMode
    let onShow: (Renderer.ViewMode) -> Void

    var body: some View {
        VStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.6), radius: 6)
                .padding(.top, 120)
                .accessibilityHidden(true)
            Spacer()
            HStack(spacing: 48) {
                viewButton(.normal, symbol: "eye.fill", label: "Normal view")
                viewButton(.uv, symbol: "lamp.desk.fill", label: "Lamp view")
            }
            .padding(.bottom, 60)
        }
    }

    private func viewButton(_ target: Renderer.ViewMode, symbol: String, label: LocalizedStringKey) -> some View {
        let selected = mode == target
        return Button { onShow(target) } label: {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .frame(width: 110, height: 110)
                .foregroundStyle(selected ? .black : .white)
                .background(Circle().fill(selected ? .white : .black.opacity(0.55)))
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
