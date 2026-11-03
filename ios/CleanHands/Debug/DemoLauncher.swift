#if DEBUG || QA_TOOLS
import SwiftUI

/// Starts the reveal with a fixed seed and no participant record, so US1 can be tested before
/// registration and consent exist (tasks T047). Compiled only into Debug and QA builds, never
/// into the study build. The demo ends with the N19 debrief, so a reveal is always followed by
/// how to wash (Principle V).
struct DemoLauncher: View {
    @Bindable var model: AppModel
    @State private var showReplay = false
    @State private var showTuning = false

    var body: some View {
        VStack(spacing: 14) {
            Text(verbatim: "Test tools — not for participant sessions")
                .font(.footnote)
                .foregroundStyle(.orange)
            Picker(selection: $model.cameraSetup) {
                Text(verbatim: "A · overhead, rear camera").tag(CameraSetup.overheadRear)
                Text(verbatim: "B · mirror clip, front camera").tag(CameraSetup.mirrorFront)
            } label: {
                Text(verbatim: "Camera setup")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 480)
            HStack(spacing: 16) {
                Button { model.startDemo() } label: {
                    Label { Text(verbatim: "Start demo reveal") } icon: { Image(systemName: "play.fill") }
                }
                .buttonStyle(.borderedProminent)
                Button { showReplay = true } label: {
                    Label { Text(verbatim: "Replay harness") } icon: { Image(systemName: "film") }
                }
                .buttonStyle(.bordered)
                Button { showTuning = true } label: {
                    Label { Text(verbatim: "Tune look") } icon: { Image(systemName: "slider.horizontal.3") }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 20)
        .sheet(isPresented: $showReplay) { ReplayHarnessView(model: model) }
        .sheet(isPresented: $showTuning) { TuningPanel(model: model) }
    }
}
#endif
