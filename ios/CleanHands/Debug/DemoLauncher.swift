#if DEBUG || QA_TOOLS
import SwiftUI

/// The big green play button on the start screen: starts the reveal with a fixed seed and no
/// participant record, so the flow can be tested before registration and consent exist (tasks
/// T047). Compiled only into Debug and QA builds, never into the study build.
struct DemoStartButton: View {
    @Bindable var model: AppModel

    var body: some View {
        Button { model.startDemo() } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 6) // optical centre of the triangle
                .frame(width: 168, height: 168)
                .background(Circle().fill(Color.green))
        }
        .buttonStyle(PressableStyle(shape: Circle(), highlight: .black.opacity(0.15), minHitSize: 168))
        .accessibilityLabel(Text(verbatim: "Start"))
    }
}

/// Test settings behind the gear on the start screen: camera setup, replay harness, look tuning.
struct TestSettingsSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showReplay = false
    @State private var showTuning = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $model.cameraSetup) {
                        Text(verbatim: "A · overhead, rear camera").tag(CameraSetup.overheadRear)
                        Text(verbatim: "B · mirror clip, front camera").tag(CameraSetup.mirrorFront)
                    } label: {
                        Text(verbatim: "Camera setup")
                    }
                } header: { Text(verbatim: "Session") }
                Section {
                    let voice = NarrationPlayer.status()
                    LabeledContent {
                        Text(verbatim: voice.recorded == voice.total ? "Swahili, recorded voice"
                             : voice.recorded + voice.synthetic == voice.total ? "Swahili, synthetic voice"
                             : "\(voice.total - voice.recorded - voice.synthetic) of \(voice.total) clips still English")
                    } label: {
                        Text(verbatim: "Narration")
                    }
                    LabeledContent {
                        Text(verbatim: "\(voice.reviewed) of \(voice.total) lines reviewed")
                    } label: {
                        Text(verbatim: "Swahili text")
                    }
                    if voice.reviewed < voice.total || voice.recorded + voice.synthetic < voice.total {
                        Text(verbatim: "Not for sessions with participants until a native speaker has reviewed every line and partner staff have approved the voice.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: { Text(verbatim: "Voice") }
                Section {
                    Button { showReplay = true } label: {
                        Label { Text(verbatim: "Replay harness") } icon: { Image(systemName: "film") }
                    }
                    Button { showTuning = true } label: {
                        Label { Text(verbatim: "Tune look") } icon: { Image(systemName: "slider.horizontal.3") }
                    }
                } header: { Text(verbatim: "Test tools — not for participant sessions") }
            }
            .navigationTitle(Text(verbatim: "Settings"))
            .toolbar { Button { dismiss() } label: { Text(verbatim: "Done") } }
            .sheet(isPresented: $showReplay) { ReplayHarnessView(model: model) }
            .sheet(isPresented: $showTuning) { TuningPanel(model: model) }
        }
    }
}
#endif
