#if DEBUG || QA_TOOLS
import SwiftUI

/// Edits the look live for gate 3 (visual QA against the reference images), and exports the result
/// as a new `look.json` to commit. Release builds read only the bundled file.
struct TuningPanel: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var look: LookConfig
    @State private var exportURL: URL?

    init(model: AppModel) {
        self.model = model
        _look = State(initialValue: model.look)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    slider("Skin target value", $look.uvView.skinTargetValue, 0.1...0.4)
                    slider("Skin local contrast", $look.uvView.skinLocalContrast, 0...1)
                    slider("Light pool dilate", $look.uvView.lightPool.dilate, 0...0.4)
                    slider("Light pool blur", $look.uvView.lightPool.blur, 0.05...0.6)
                    slider("Light pool falloff", $look.uvView.lightPool.falloff, 0.2...2)
                    slider("Nail tint", $look.uvView.nailTint.strength, 0...0.5)
                } header: { Text(verbatim: "Skin under UV") }
                Section {
                    slider("Grain scale", $look.glow.grain.scale, 0.004...0.04)
                    slider("Grain strength", $look.glow.grain.strength, 0...1)
                    slider("Skin detail strength", $look.glow.skinDetailStrength, 0...1)
                    slider("Bloom radius", $look.glow.bloom.radius, 0...0.03)
                    slider("Bloom intensity", $look.glow.bloom.intensity, 0...0.5)
                    slider("Hue jitter", $look.glow.hueJitter, 0...0.3)
                } header: { Text(verbatim: "Glow") }
                Section {
                    slider("Wrist extent", $look.pattern.wristExtent, 0...0.5)
                } header: { Text(verbatim: "Pattern") }
                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) { Text(verbatim: "Share look.json") }
                    }
                    Button { look = (try? LookConfig.load()) ?? look } label: { Text(verbatim: "Reset to bundled look.json") }
                }
            }
            .navigationTitle(Text(verbatim: "Tune look"))
            .toolbar { Button { dismiss() } label: { Text(verbatim: "Done") } }
            .onChange(of: look) { _, newLook in
                model.updateLook(newLook)
                exportURL = try? write(newLook)
            }
        }
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            LabeledContent { Text(verbatim: String(format: "%.3f", value.wrappedValue)) } label: { Text(verbatim: label) }
            Slider(value: value, in: range)
        }
    }

    private func write(_ look: LookConfig) throws -> URL {
        let url = URL.documentsDirectory.appending(path: "look.json")
        try look.encoded().write(to: url)
        return url
    }
}
#endif
