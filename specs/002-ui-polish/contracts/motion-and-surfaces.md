# Contract: Motion Tokens, Controls, and Surfaces

The shared building blocks of every 002 screen: motion values, press behaviour, the glass surface, the facilitator's step indicator and hold-to-end, and the prompt transition. Covers US2 and US3; FR-005..FR-008, FR-011..FR-015, FR-017..FR-019, FR-021, FR-022; SC-003..SC-005. [choreography.md](choreography.md) says **when and where** things move in each state; this contract fixes **what they move with**. It is a contract, not code: signatures show the agreed shape.

- **Platform**: iPadOS 17.0, SwiftUI and system frameworks only (no packages, Principle VI). No iOS 18-only API on participant screens, not even behind `#available`, because study iPads on different OS versions would then show different experiences (Principle III, FR-023).
- **Source**: `.claude/skills/apple-design`, which is written for the web, translated to native SwiftUI.
- **Files** (proposed; plan.md decides): `Design/Motion.swift` (fixed), `Design/PressableStyle.swift`, `Design/GlassSurface.swift`, `Design/PromptTransition.swift`, `Facilitator/StepIndicator.swift`, `Facilitator/HoldToEndButton.swift`.
- **Environment read**: `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `colorSchemeContrast`, `dynamicTypeSize`, plus a new `EnvironmentValues.qualityLevel` (`QualityLevel`, default `.high`) that `ParticipantRootView` sets from `AppModel.quality`.
- **New names introduced here**: `Motion.Token`, `RendererTiming`, `GlassProminence`, `FlowStep`, `EnvironmentValues.qualityLevel`.

## 1. Motion tokens (`Design/Motion.swift`)

| Token | Kind | Value | Used by | Reduce Motion |
|---|---|---|---|---|
| `Motion.standard` | SwiftUI spring | `.spring(response: 0.35, dampingFraction: 1.0)` | prompt entry and exit, hint nudges, step-indicator advance, End ring return, Stop/calm cross-fade (choreography §6) | `reducedFade` |
| `Motion.quick` | SwiftUI spring | `.spring(response: 0.2, dampingFraction: 1.0)` | press scale and highlight release, eye/lamp selection fill, badge opacity, small exits | no scale; highlight appears instantly and fades out with `reducedFade` |
| `Motion.lamp` | `RendererTiming` | 0.8 s. In the renderer: the integrator in lamp-transition §2 (a 0.7 s rate-limited ramp smoothed by a critically damped spring). In SwiftUI (calm-surface cross-fades): `.timingCurve(1/3, 0, 2/3, 1, duration: 0.8)`, which is exactly smoothstep | `uvAmount` 0⇄1 in the shader; calm-surface cross-fades (choreography C6) | 0.4 s **linear** cross-fade, no phases |
| `Motion.glowSpread` | `RendererTiming` | 1.5 s front from fingertips to wrist, first switch-on only (FR-004a) | `glowReveal` in the shader | 0 s: the whole pattern fades in at once |
| `Motion.reducedFade` | SwiftUI curve | `.easeInOut(duration: 0.2)`, opacity only | every reduced SwiftUI equivalent; hint emphasis (choreography §2) | itself |

```swift
enum Motion {
    enum Token: Sendable { case standard, quick, lamp, reducedFade }
    static var standard: Animation { get }      // computed, so Swift 6 needs no isolation
    static var quick: Animation { get }
    static var reducedFade: Animation { get }
    static let lamp: RendererTiming             // (seconds: 0.8, reducedSeconds: 0.4)
    static let glowSpread: RendererTiming       // (seconds: 1.5, reducedSeconds: 0)
    /// The token's animation, or its reduced equivalent when Reduce Motion is on.
    static func animation(_ token: Token, reduceMotion: Bool) -> Animation
}
struct RendererTiming: Sendable {
    let seconds: Double, reducedSeconds: Double
    func seconds(reduceMotion: Bool) -> Double
    var animation: Animation { get }            // smoothstep timing curve over `seconds`
}
```

- Damping is 1.0 everywhere. The skill (§4) reserves bounce for flicks and throws, and nothing in this flow is thrown (FR-005). Do not use `.bouncy`, `.snappy`, `.interactiveSpring`, or `symbolEffect(.bounce)`.
- No literal animation or duration outside `Motion.swift`. The one exception is `HoldToEndButton`'s linear fill, which is a time threshold, not motion (§2.5).
- The renderer cannot read the SwiftUI environment, so `ParticipantRootView` passes `accessibilityReduceMotion` to the model and renderer with `.onChange(of:initial: true)`.
- The lamp reverses from wherever it is, keeping both position and velocity (lamp-transition §2), so a reversal never flips speed in one frame. No queue, no wait.

**Why these values.**
- `standard` 0.35 sits in the middle of the skill's default critically damped range (0.3–0.4).
- `quick` 0.2 reaches about 95 % in 0.15 s, close to the skill's 100 ms press. In the first frame it moves only about 10 % of the way (0.4 pt on a 110 pt button), so the instant highlight is what meets SC-003 (§2.1).
- `lamp` 0.8 s is inside FR-001's 0.6–1.0 s. Smoothstep's steepest point is 1.5× the average rate, so at 30 fps (A10, 24 frames) even a full-range brightness change moves at most 6.3 % per frame, under SC-001's 10 %. Any phase that changes overall brightness must last at least 0.6 s.
- The reduced lamp is 0.4 s linear: 12 frames at 30 fps, at most 8.3 % per frame. `reducedFade` would give only 6 frames, reaching about 28 % at its peak, and would fail SC-001 on a bright scene; choreography §5 should reference `Motion.lamp`'s reduced value. 0.4 s is still shorter than the standard change (US1 #5).

## 2. Components

### 2.1 `PressableStyle`

```swift
struct PressableStyle<S: InsettableShape>: ButtonStyle {
    var shape: S                                   // highlight outline: Circle(), Capsule()
    var minHitSize: CGFloat = 44                   // participant controls pass 88
    var highlight: Color = .white.opacity(0.22)    // light fills pass .black.opacity(0.15)
}
```

| State | Visual | Timing |
|---|---|---|
| Pressed (`configuration.isPressed` on touch-down) | `highlight` fill inside `shape`, scale 0.96 | highlight **unanimated**, so it shows in frame 1 (SC-003); scale `Motion.quick` |
| Released inside | the action runs; visuals return | `Motion.quick` |
| Dragged off before release | `isPressed` becomes false; no action | `Motion.quick` |
| Disabled | opacity 0.35 (0.55 with Increase Contrast); no press visuals | — |
| Reduce Motion | highlight only, no scale | appears instantly; fades out with `reducedFade` |

- It is a `ButtonStyle`, not a `PrimitiveButtonStyle`, so the system keeps its own tracking: act on release, cancel on drag-off, VoiceOver, keyboard. The drag-off slop is the system's, wider than the 10 pt in the skill and in choreography §2. We accept that rather than rebuild touch tracking. Implementation hint: `.animation(isPressed ? nil : Motion.quick, value: isPressed)` on the highlight.
- The hit area is padded: the style applies `.frame(minWidth: minHitSize, minHeight: minHitSize)` and `.contentShape(Rectangle())`, so a smaller visual still gets the full target (skill §10).
- Scale is 0.96 everywhere, for consistency; on small strip buttons the highlight does the work. Put the press visuals in one internal modifier that `HoldToEndButton` also uses.
- Accessibility: every button sets `.accessibilityLabel`, and the selected eye or lamp button adds `.isSelected`.

### 2.2 `GlassSurface`

```swift
enum GlassProminence { case bar, chip }   // strip vs. small facilitator chips (the simulation badge is always solid, FR-026)
extension View {
    func glassSurface<S: InsettableShape>(_ shape: S, prominence: GlassProminence = .bar) -> some View
}
```

Checked on every render; the first matching row wins:

| Condition | Fill | Edge | Content (icons, text) |
|---|---|---|---|
| `colorSchemeContrast == .increased` | solid `Color(white: 0.06)` | 2 pt white 1.0, all round | white 1.0; disabled 0.55 |
| `accessibilityReduceTransparency` | solid `Color(white: 0.10)` | 1 pt white 0.6, all round | white 0.95; disabled 0.4 |
| `qualityLevel` is `.medium` or `.low` | solid `Color(white: 0.10)` | top highlight, as glass | as glass |
| otherwise (`.high`) | `.thinMaterial` in a forced dark scheme, plus a black 0.3 tint | 1 pt top highlight: white 0.35 at the top, fading to 0 by mid-height | white 0.95; disabled 0.35 |

- `.bar` adds a static shadow (black 0.25, radius 8, y 2); `.chip` has none. The skill (§12) says larger surfaces should read as thicker.
- Switching between glass and solid is **instant**: a cross-fade would draw both just when the GPU is already over budget. `QualityController`'s hysteresis (2 s down, 10 s up) prevents flicker.
- A surface appears and leaves by opacity only. The skill's blur-ramp "materialize" effect is deliberately not used (§6).
- Content must reach at least 4.5:1 contrast against the surface, measured with a white card behind it and with black behind it.

### 2.3 `promptTransition`

```swift
extension AnyTransition { static func prompt(reduceMotion: Bool) -> AnyTransition }
extension View { func promptTransition() -> some View }   // reads accessibilityReduceMotion
```

- Entry: opacity 0 → 1 and scale 0.92 → 1 around the element's own centre, **in place**. Exit is the exact reverse (a symmetric transition, never `.asymmetric`), animated with `Motion.standard`. With Reduce Motion it is `.opacity` with `reducedFade`. This matches choreography §2.
- Direction for FR-008 comes from the **hints**, not from entries: the arrow, the hand outline, and the turn-hand each move once per cue (choreography §3). Because entries never travel, any movement on screen means "go this way".
- The container that inserts a prompt animates the insertion, scoped to itself: `.animation(Motion.animation(.standard, reduceMotion: rm), value: promptVisible)`. Screens never slide, and the camera image never moves (skill §14).
- These do not use `promptTransition`: the simulation badge (opacity, `Motion.quick`, fixed position), calm surfaces (`Motion.lamp` cross-fade), and the face guard (no transition, FR-020).

### 2.4 `StepIndicator`

```swift
enum FlowStep: Int, CaseIterable, Sendable {
    case positioning, normalView, lamp, reveal, quickRinse, rehearsal, realWash, debrief
}
struct StepIndicator: View {
    let current: FlowStep?    // nil before positioning and after the end
    let reached: FlowStep?    // last step entered; filled dots run up to here
    let rehearsalStep: Int?   // 1...6 while current == .rehearsal
}
```

| Step shown | `SessionState` |
|---|---|
| hidden | `idle`, `consentCheck`, `blocked` (registration, before the flow starts) |
| 1 positioning · 2 normal view · 3 lamp | `deviceReady` or `positioning` · `normalView` · `uvIntro` |
| 4 reveal | `uvReveal`, `normalView2` (switching between eye and lamp does not move it) |
| 5 quick rinse · 6 rehearsal | `quickRinseDemo` · `rehearsal(n)` or `paused(.step(n))`, with `rehearsalStep = n` |
| 7 real wash · 8 debrief | `realWashPrompt` · `debrief` |
| the step being resumed | `paused(.faceGuard)`, `paused(.facilitator)`; AppModel must expose the machine's `resumeState` |
| `current = nil`, `reached` kept | `ended(.completed)` shows 8 filled dots; `ended(.aborted)` fills up to the last step reached |

- The mapping is one exhaustive `switch` with no `default:`, so a new `SessionState` won't compile until someone places it.
- **Rehearsal is one step**, with six sub-ticks inside the current capsule. Thirteen dots can't be counted at a glance (SC-004). Rehearsal also advances on its own every 4–5 s, and a capsule jumping along the strip that often would pull the participant's eye to the top edge (FR-013). The sub-ticks still show which movement a `paused(.step(n))` will resume.
- Shapes only, no text, no colour code:
  - Completed: filled 6 pt dot, white 0.55.
  - Current: filled 20 × 6 pt capsule, white 1.0. During rehearsal it is 34 × 6 pt with six 4 pt segments; done and current segments are white 1.0, upcoming ones white 0.3.
  - Remaining: hollow 6 pt ring, 1.5 pt stroke, white 0.55.
  - Spacing is 6 pt. With Increase Contrast, all shapes are white 1.0 and strokes are 2 pt.
  - Sizes use `@ScaledMetric(relativeTo: .caption2)`, capped with the strip (§2.6).
- Motion: the capsule moves to the next step with `Motion.standard` (a cross-fade with Reduce Motion). Sub-ticks change opacity only (`reducedFade`) and never travel. Nothing pulses or loops.
- It is not interactive. VoiceOver reads it as one element, label "Step 4 of 8", value the step name ("Reveal"; during rehearsal "Movement 3 of 6"). It sits between Back and Next, so it reads as where they lead (skill §16, grouping and mapping).

### 2.5 `HoldToEndButton`

```swift
struct HoldToEndButton: View {
    static let holdDuration: Double = 1.0
    let onEnd: () -> Void   // AppModel.facilitatorEnd()
}
```

| State | What shows | Timing |
|---|---|---|
| Rest | `xmark` on the strip's glass; no ring | — |
| Touch-down | the shared press visuals (§2.1); a ring track (white 0.2); the fill starts at 12 o'clock and runs clockwise | track appears instantly; fill is **linear** over `holdDuration` |
| Released, or moved more than 10 pt, before 1.0 s | nothing ends; the fill returns to 0 from where it is | `Motion.standard`. Reduce Motion: the ring fades out with `reducedFade`, then resets out of sight |
| Held for 1.0 s | `onEnd()` fires once, while the finger is still down (a hold commits when it completes) | the ring stays full, then resets without animation once the strip shows `ended` |

- Gesture: `.onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 10, perform:onPressingChanged:)`. The ring and the gesture share `holdDuration`, so the ring is full at the moment End fires. It takes one finger, so it stays separate from 001's two-finger, 2 s settings press on the strip.
- The fill is linear, not a spring: the ring is a clock, and a steady rate honestly shows the time left. Choreography uses the same token (reconciled 2026-11-04).
- Size: a 44 × 44 pt target that scales with the strip. Ring: 36 pt diameter, 3 pt stroke, round caps, white. No red, which stays reserved for the participant's Stop. It sits at the strip's trailing end, 16 pt from the other buttons and away from Next.
- Nothing draws outside the button's frame: no dialog, toast, or overlay on the participant's view (FR-015).
- Accessibility: `.isButton` trait, label "End session", hint "Touch and hold". Do **not** add a single-tap `accessibilityAction`, which would bypass FR-015. VoiceOver's double-tap-and-hold passes the hold through.

### 2.6 Changes to existing 001 controls

| Control | Change |
|---|---|
| `StopButton` | `PressableStyle(shape: Circle(), minHitSize: 88)`. Red square on a dark solid tint, no material. With Increase Contrast, a 2 pt white ring. Fixed position; enters once (choreography §2). |
| Eye / lamp buttons | `PressableStyle(shape: Circle(), minHitSize: 88)`. The selected one has a white fill and a black icon (shape and fill, not colour alone) and passes a dark `highlight`. The fill swaps with `Motion.quick`. |
| `ControlStrip` | `glassSurface(Capsule(), prominence: .bar)`. Order: `Back · StepIndicator · Next — Pause · Replay — End (hold)`. 44 × 44 pt buttons (`@ScaledMetric`), symbols `.body.weight(.semibold)`. Remove the whole-strip `.opacity(0.7)`, which lowered icon contrast. Add `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` to the strip and `.accessibilityShowsLargeContentViewer()` to each button, so larger text never pushes the strip over the hands. |
| `SimulationBadge` | Always a **solid** chip (dark fill, white 1 pt border), identical on every iPad and quality level, because it is the Principle I indicator (FR-026); never glass. One fixed top-leading position, below the strip's tallest (capped) height, so the two never overlap. |

## 3. Surfaces and materials (skill §12 applied here)

| Surface | Treatment | Why |
|---|---|---|
| Facilitator strip | `GlassSurface` | Small chrome over a live, changing image: it must stay legible while staying quieter than the hands. |
| Participant controls over the camera (Stop, eye/lamp) | solid black tint 0.55, no blur | Colour and large icons belong on a solid layer. |
| Participant prompt and hint icons | no surface: white 0.85–1.0 with a static dark halo (black 0.6, radius 6–10) | Readable over bright and dark frames without hiding the hands. |
| Calm surfaces (debrief, ended), face-guard blank | solid (001's calm colour, or black) | There is nothing behind them to blur (choreography §7). |
| Facilitator screens (idle, consent, camera error, export, settings) and the rehearsal demo panel | solid, dark; system `Form` and `List` styles where they apply | The camera is off or blanked, or the panel holds content rather than chrome. **This overrides choreography §4**, which puts the consent panel, camera-error text, and demo panel on glass. |

- Never glass on glass, and never a light material: every material is forced dark. Nothing translucent sits on the strip; the End ring and highlights are flat fills.
- No material or blur ever covers the hands. It would change how the hands and glow look, differently on each device (Principles I and III).
- Vibrancy over a changing image: content on glass is solid white and semibold. Never use `.secondary` or hierarchical styles, which let the camera image bleed through (skill §12). Colour, such as Stop's red, sits only on solid layers.
- No dimming scrim anywhere in the participant flow; the strip is a parallel layer that doesn't block. Stop and the strip are always the two topmost layers and never overlap.

## 4. Typography (facilitator and idle screens)

| Role | Text style | Weight | Notes |
|---|---|---|---|
| Screen title ("Clean Hands", registration) | `.largeTitle` | `.semibold` | `.leading(.tight)` |
| Section heading | `.title3` | `.semibold` | |
| Instructions, field values | `.body` | regular | default leading |
| Labels, secondary text | `.subheadline` | regular | `.secondary` only on solid surfaces |
| Codes, counts, timers | `.body.monospacedDigit()` | `.medium` | digits don't shift as values change |
| Build and device info | `.footnote` | regular | |

- Use the system font (SF Pro) through text styles; never `.system(size:)` for facilitator text. Text styles already apply SF's per-size tracking and its Text-to-Display switch at 20 pt, which is skill §15's "tracking per size" done by the platform, so never add `.tracking` or `.kerning`. Build hierarchy from weight and size together, and emphasise with weight, not colour.
- Dynamic Type: use `@ScaledMetric` for spacing, and switch rows from horizontal to vertical at accessibility sizes (`ViewThatFits` or `AnyLayout`). No `.minimumScaleFactor` and no truncated instructions. Test at the largest accessibility size.
- Participant screens show no text except the badge's Swahili label (Principle I). It uses a fixed `.system(size: 22, weight: .semibold, design: .rounded)`, because the iPad's text size is the facilitator's setting and must not resize chrome over the hands. As text on glass, it gets +0.2 pt tracking (skill §12). Participant icons are fixed-size graphics, `accessibilityHidden(true)` unless they are buttons.

## 5. Interaction rules

1. **Feedback on touch-down, action on release.** Every control uses `PressableStyle`, except `HoldToEndButton`, the one control that commits at a threshold while still held.
2. **No animation blocks input (FR-007).** Animations are presentation only; the model changes state at once. Banned: `.disabled` or `.allowsHitTesting(false)` tied to an animation; `withAnimation(…, completion:)` or `Task.sleep` holding back a state change; input queues and debounces. A view leaving with a transition stops taking touches, and its replacement takes them immediately.
3. **Every tap counts from the current state.** Springs retarget from the value on screen, and the lamp reverses from its current progress. Fast eye/lamp taps never queue.
4. **Stop always wins.** It sits outside every transitioning container, is never disabled, and is never covered while the session is running, including during the face guard. It acts on the release frame; choreography §6 covers what follows.
5. **Privacy first (FR-020).** The face-guard blank is inserted with animations off (`.transaction { $0.animation = nil }`) and overrides any running transition.
6. **Nothing loops (FR-011, FR-017).** Banned on participant screens: `.repeatForever` and `.repeatCount`; `phaseAnimator` or `keyframeAnimator` without a `trigger:` (they loop); `symbolEffect` (indefinite effects pulse, and `.bounce` overshoots); decorative `TimelineView(.animation)`; the indeterminate `ProgressView` spinner. The current camera-start spinner and the `.repeatForever` no-hands pulse are both removed.
7. **Hints move once per spoken prompt.** Each hint nudge in choreography §3 runs through `keyframeAnimator(initialValue:trigger:)` (iOS 17), keyed on that clip's cue counter, which the model latches (choreography C3). The hint then rests. With Reduce Motion it becomes the hint emphasis from choreography §2.
8. **Large surfaces fade; they never move** (skill §14). Brightness changes across the whole screen use the `Motion.lamp` curve (choreography C6).

## 6. Performance (FR-021, SC-006)

- Animate only opacity, transforms (scale, offset, rotation), and the End ring's trim. Never animate blur radius, a material, a shadow, the frame or padding of a large container, or anything on `MetalCameraView`. The lamp runs in the shader, not as SwiftUI opacity on the camera view.
- At most one material on screen: the facilitator strip (the badge is solid, FR-026). It is small chrome, under 5 % of the screen, and only at `QualityLevel.high`; at `.medium` or `.low` they fall back to solid (§2.2).
- Scope each animation with `.animation(_:value:)` on the small container that changes. Never wrap model changes in a global `withAnimation`; that would re-evaluate the view holding the `MTKView` on every animated frame, and the renderer draws on the main actor too.
- Shadows are static. The strip and the badge re-layout only on a state change.
- Check: on the oldest study iPad (A10), `renderFPS` stays at or above 30 (60 on A12+) while strip buttons are pressed, End is held, prompts enter, and the lamp switches (SC-006).

## 7. Adoption checklist (FR-022)

For each screen built after this feature (registration, quick-rinse demo, rehearsal, real-wash prompt, debrief, export):

- [ ] Every control uses `PressableStyle`, with targets of at least 44 pt for the facilitator and at least 88 pt for the participant.
- [ ] All motion comes from `Motion`, through `Motion.animation(_:reduceMotion:)` or a `RendererTiming`. `grep -nE '\.spring\(|\.easeInOut\(|\.easeOut\(|\.linear\(|\.bouncy|\.snappy' -r ios/CleanHands` matches only `Design/Motion.swift` and `HoldToEndButton.swift`.
- [ ] Nothing loops: `grep -nE 'repeatForever|repeatCount|symbolEffect|ProgressView\(' -r ios/CleanHands/Flow` finds nothing, and every `phaseAnimator` or `keyframeAnimator` has a `trigger:`.
- [ ] Prompts use `promptTransition` and enter on their cue (choreography §4); hints follow choreography §3.
- [ ] Each new `SessionState` is placed in the `FlowStep` mapping (the exhaustive switch forces it).
- [ ] Surfaces follow §3: glass only for chrome over the camera, solid everywhere else. Facilitator text uses text styles (§4) and fits at the largest accessibility size.
- [ ] No new participant text; decorative icons are `accessibilityHidden(true)`; controls are labelled. Stop is present and topmost, and the face guard still cuts instantly.
- [ ] One walkthrough each with: Reduce Motion (only fades, nothing repeats, SC-005); Reduce Transparency; Increase Contrast (solid with an edge, at least 4.5:1 over a white card and over black); the largest text size; and `QualityLevel.low` forced from the QA tools.

| Screen | Notes |
|---|---|
| Registration, export, settings | Facilitator only; solid and dark, with the camera blanked. Withdrawal and data deletion are truly destructive, so a system confirmation dialog is allowed here (skill §16, Agency). Never in the participant flow. |
| Quick-rinse demo | The palm-centre fade uses renderer timing from `look.json`, not SwiftUI. Badge rules (FR-003) apply. |
| Rehearsal | Indicator step 6 with sub-ticks. The demonstration is instructional content, not a hint: it plays once per step cue (N09–N15), rests on its last frame, and never repeats across a pause. With Reduce Motion it still plays, because it is what the participant copies; SC-005 reviewers log it as content. Its panel is solid. |
| Real-wash prompt | The soap icon uses `promptTransition` on the N18 cue. |
| Debrief | Calm solid surface; icons use `promptTransition` on the N19 cues; no glass. |
