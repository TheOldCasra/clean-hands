# Contract: Lamp Transition (renderer)

How the renderer moves between camera view and UV look, spreads the glow once, tells the UI when
the badge is required, and syncs `LampClick` (US1, US4, FR-001..004a, FR-016, FR-020, FR-021,
SC-001, SC-002, SC-006). Touches `Rendering/LampTransition.swift` (new, pure value type, testable
without Metal), `Renderer.swift`, `Shaders.metal`, `AppModel.swift`, `Audio/LampClick.swift` (new),
`NarrationPlayer.swift`. Tokens: [motion-and-surfaces](motion-and-surfaces.md); timeline and cues:
[choreography](choreography.md).

## 1. State

| Field (`LampTransition`) | Range | Rule |
|---|---|---|
| `uvTarget` | 0 or 1 | Set only by `Renderer.setView(_:animated:) -> Bool`; `Renderer.mode` becomes a read-only view of it |
| `uvLinear` | 0…1 | Internal rate-limited ramp toward `uvTarget` (§2) |
| `uvAmount` | 0…1 | What is drawn: 0 = camera (bit-identical to 001 normal view), 1 = 001 UV look |
| `velocity` | 1/s | `d uvAmount/dt`, carried across every retarget |
| `glowReveal` | 0…1 | Fingertip → wrist spread progress (§5); `spreadPlayed = glowReveal > 0` |
| `glowInterlock` | 0…1 | Glow multiplier that follows `badgeOpaque` (§6) |
| `badgeRequired` | bool | Published to the UI (§6) |
| `frozen` | bool | Session paused or blanked: nothing integrates (§8) |
| `blankAmount` (Renderer) | 0…1 | 1 = black; 1 on the face-guard frame, falls over `Motion.lamp` (§8) |

`resetLamp()` (on `.idle` and when a new pattern is assigned) zeroes all of it.

Per-state target (I1, FR-001):

| Entering | Lamp | Click |
|---|---|---|
| `.uvReveal` | animated → 1 | yes (on the 0 → 1 edge) |
| `.normalView2` | animated → 0 | no |
| `.quickRinseDemo` (001 US3) | animated → 1 if it is off | yes, if it switches on |
| `.realWashPrompt` (001 US3) | animated → 0 | no |
| `.debrief`, `.ended` | **not changed**: capture stops, the last frame is held under the calm surface; `resetLamp()` once the surface is opaque (choreography §7, FR-024) | no |
| idle, positioning, normalView, uvIntro | snapped to 0 (already 0 in the normal flow) | no |

Snapped changes set `uvLinear = uvAmount = uvTarget`, `velocity = 0`, and never click.

## 2. Integrator (interruptible)

Each frame, with `dt = min(frame dt, 1/30 s)` (a hitch slows the lamp, never enlarges a step):

1. Ramp: `uvLinear += clamp(uvTarget − uvLinear, −dt/Tr, +dt/Tr)`, `Tr = 0.7 s`.
2. Follower: critically damped spring, response 0.2 s (`Motion.quick`), `ω = 2π/0.2`, in
   closed form (stable at any `dt`): `e = uvAmount − uvLinear`, `j = velocity + ω·e`,
   `E = exp(−ω·dt)`; `uvAmount ← uvLinear + (e + j·dt)·E`, `velocity ← (velocity − ω·j·dt)·E`.
3. Snap: if `uvLinear == uvTarget`, `|uvAmount − uvTarget| < 0.001`, `|velocity| < 0.01`: set
   `uvAmount = uvTarget`, `velocity = 0` (0 and 1 exact).
4. Kick: a retarget to the other end from rest (`velocity == 0`, `uvAmount` exactly 0 or 1) sets
   `velocity = ±1/Tr`. The first frame then already changes (≈ 1–2 % mean luma), so the click and
   the first changed frame coincide (FR-016); switch-off is the exact mirror of switch-on (US1 #3).

Full switch: `uvAmount ≥ 0.99` at 0.80 s = `Motion.lamp` (snap ≈ 0.92 s); `|velocity| ≤ 1.43 /s`.

**Why** (FR-004): a retarget changes only `uvTarget`; `uvAmount` and `velocity` are never reset,
so a reversal starts from the presentation value, and the spring carries velocity through the
turn (it runs on ≈ 0.03 for ≈ 0.05 s, then comes back): the skill's "no brick wall". Replaying a
fixed curve backwards (motion-and-surfaces §1, "time left = time elapsed", superseded here) flips
velocity in one frame. A bare spring is front-loaded (peak ≈ 3 /s for a 0.8 s settle) and breaks
SC-001 at 30 fps once channels are eased; the ramp caps the speed, giving the hard bound in §3.

## 3. Channels and composite

Every channel is a function of `a = uvAmount` (and the Reduce Motion flag, §4), so a reversal
replays them in reverse order. They are computed on the CPU by one pure function,
`LampTransition.channels(a, reduceMotion:) -> (dark, skin, gate)`, used by both the renderer and
the unit tests (R1):

| Channel | Formula | Done at | Max slope | Max Δ/frame 60 / 30 fps |
|---|---|---|---|---|
| `dark` (room → `uvView.background`) | `h(clamp(a/0.78))`, `h(x) = x + x² − x³` | 0.78 | 1.71 | 0.041 / 0.082 |
| `skin` (camera colour → violet ramp) | `smoothstep(0.05, 0.78, a)` | 0.78 | 2.05 | 0.049 / 0.098 |
| `glowGate` | `smoothstep(0.80, 1.00, a)` | 1.0 | 7.5 | 0.18 / 0.36 |
| nail tint | × `skin` | — | — | — |

Δ/frame = slope × 1/Tr × dt; discrete stepping adds ≤ 10 % (L2). `h` starts at slope 1, so the
room dims on the click frame, and ends flat. The 0.78 → 0.80 gap enforces FR-002 both ways: glow
is exactly 0 until room and skin are fully UV, and on switch-off it is 0 a frame before they move.

Shader (`finalFragment`), replacing the hard `flags.x < 0.5` switch:
- `flags.x` carries `uvAmount` (for the `== 0` fast path), `texel.zw` carry `dark` and `skin` from
  `channels(…)`, `bloom.w` carries `blankAmount`: no new uniform bytes. The shader only mixes; it
  never needs to know whether Reduce Motion is on.
- `blankAmount ≥ 1` → black (first test). `uvAmount == 0` → camera × (1 − `blankAmount`).
- Else `outside = mix(cam, background, dark)`, `inside = mix(cam, rampColor(skinValue), skin)`,
  `color = mix(outside, inside, lit.r)`; glow, bloom, crease as 001; nail × `skin`; × (1 −
  `blankAmount`). At `a = 1` this is exactly 001's `mix(background, ramp, lit.r)`.
- `glowGate` multiplies instance intensity on the CPU (like 001's presence), so coverage, bloom
  and crease fade together. Pool and coverage passes run iff `uvAmount > 0` and `blankAmount < 1`.

Switch-on, 60 fps: 0.1 s dark 0.11 · 0.3 s dark 0.56, skin 0.37 · 0.5 s 0.94 / 0.90 · 0.6 s both
1, gate opens · 0.8 s gate 1. Switch-off: gate 0 at 0.20 s, then skin and room; camera at 0.92 s.

**SC-001**: mixing happens in the camera's encoded `bgra8Unorm` space, which is what a recording's
mean luma measures. Room and skin partition the screen (`1 − lit.r`, `lit.r`) and peak at
different `a`; glow adds ≤ 0.05 of mean brightness. Simulated worst case, an all-white image going
to black: 0.043 per frame at 60 fps, 0.085 at 30 fps; with 10 random reversals, dropped frames and
24–60 fps, 0.093. Typical auto-exposed image (mean luma ≈ 0.5): 0.018 / 0.037. All < 0.10.

## 4. Reduce Motion

`Renderer.reduceMotion` (forwarded by `ParticipantRootView` → `AppModel` → renderer,
motion-and-surfaces §1) is sampled at each retarget; if it changed, that retarget first sets `uvLinear = uvAmount`, `velocity = 0`. With
it on: no follower, no kick (`uvAmount = uvLinear`), `Tr = 0.6 s`; one linear cross-fade
`dark = skin = clamp(a/0.65)` (≈ 0.4 s = `Motion.lamp.reducedSeconds`), then
`glowGate = clamp((a − 0.67)/0.33)` (0.2 s = `Motion.reducedFade`). Total 0.6 s, shorter than the
standard change (US1 #5), skin still before glow, 30 fps bound 0.085. No spread (§5).

## 5. Glow spread (FR-004a)

**`revealOrder`** (0 = fingertip, 1 = forearm point) is computed once per mark in `preparePattern()`
from its `Anchor` via the joint-chain distance `d(j)`, and stored with the prepared mark. It is
pose-independent: the spread follows anatomy whatever the hand's angle or finger curl.

| Joints | `d` |
|---|---|
| tips 4, 8, 12, 16, 20 | 0 |
| DIP 7, 11, 15, 19; thumb IP 3 | 1/3 |
| PIP 6, 10, 14, 18; thumb MP 2 | 2/3 |
| MCP 5, 9, 13, 17; thumb CMC 1 | 1 |
| wrist 0 / forearm 21 | 2 / 2 + `pattern.wristExtent` (2.25) |

`.bone(a, b, t, _)`: `d = d(a) + (d(b) − d(a))·t`; `.triangle(a, b, c, u, v, w)`:
`d = u·d(a) + v·d(b) + w·d(c)`; `revealOrder = d / d(21)`. Recompute if `wristExtent` changes.

**Reveal factor**, window `W = 0.35`:
`reveal = glowReveal ≥ 1 ? 1 : smoothstep(0, 1, (glowReveal·(1 + W) − revealOrder) / W)`.
Each mark ramps over 0.39 s (like 001's 300 ms fade-in) while the front crosses the hand in
1.5 s: tips from +0 s (full +0.39 s), knuckles from +0.5 s, wrist marks +1.0…1.5 s. At
`glowReveal = 1` the factor is exactly 1.0: final instances are bit-identical to an all-at-once
reveal. Mark intensity = `intensity × presence × surfaceAlpha × regionFade × glowGate ×
glowInterlock × reveal`; marks ≤ 0.001 are culled as today, so the sweep draws fewer instances.

- `glowReveal` advances `dt / Motion.glowSpread` (1.5 s, linear) while `glowReveal < 1`,
  `uvTarget == 1`, `uvAmount ≥ 0.99`, not `frozen`. At the first switch-on the gate opens at 0.6 s
  with every factor still 0: first glow ≈ t0 + 0.8 s, complete ≈ t0 + 2.3 s (choreography §5).
  Hands entering or leaving never pause it; their 001 presence fades still apply.
- Switch-off mid-spread: counts as played; `glowReveal` holds and becomes 1 on the first frame
  with `glowGate == 0` (no unrevealed mark pops in while fading; switched on before that, the
  sweep resumes). Switch-off before it started (`glowReveal == 0`): the next switch-on plays it.
- Afterwards (toggles, returning hands): `reveal = 1`; glow arrives through `glowGate`.
- Reduce Motion: on the first gate opening set `glowReveal = 1`; the pattern fades in at once.
- Offscreen render (replay harness): `uvAmount = reveal = glowInterlock = 1`, live state untouched.

## 6. Simulation badge (FR-003, SC-002)

- `badgeRequired = uvTarget == 1 || uvAmount > 0`. It rises inside `setView` (same main-actor call,
  before the next frame) and falls on the frame `uvAmount` snaps to 0 with `uvTarget == 0`;
  `onBadgeRequiredChanged` → observable `AppModel.badgeRequired`. Glow needs `uvAmount > 0.80`, so
  it leads the first glow by ≥ 0.6 s and outlasts the last by ≥ 0.7 s (≥ 0.4 s with Reduce
  Motion). `blank` does not change it. The UI shows the badge whenever it is true (or the
  choreography state rules require it), except on face-guard frames, which are black.
- Interlock (Principle I by construction): AppModel sets `renderer.badgeOpaque = true` from the
  completion of the badge's entrance (`withAnimation(_:completionCriteria:_:completion:)`), and
  false in the call that hides it or starts its exit. `glowInterlock` rises to 1 over 0.2 s while
  true and drops to 0 on the frame it turns false. The badge is opaque from uvIntro, so in the
  normal flow it delays nothing. QA builds assert `!glowVisible || badgeOpaque` every frame.

## 7. `LampClick` (FR-016)

**Trigger**: AppModel plays it when `setView(.uv, animated: true)` returns true (an animated 0 → 1
edge of `uvTarget`, mid-switch-off reversals included), in the same main-actor turn, before the
next draw: the first changed frame (§2 kick). Never on switch-off, snaps, resume from a pause (no
edge, choreography C8), or while `frozen`. At most one per 0.2 s.

**Narration** (never overlapping a clip start):
1. The click is never delayed; it is part of the visual event.
2. Pre-guard: a clip started < 0.25 s earlier (`NarrationPlayer.currentClipStartedAt`, new) →
   skip the click; the switch still runs.
3. Post-guard (choreography C7): `narration.deferStarts(until: now + Motion.lamp)` (new). Any clip
   start in the window (new `play` or next in queue) waits until it ends; a deferred clip counts as
   `isPlaying`, and `currentClip` changes only when it actually starts.
4. First reveal: N04 ends (and uvIntro has lasted ≥ 1.0 s, FR-004b) → `.uvReveal` entry →
   `setView(.uv)` → click → `deferStarts` → `play(["N05", "N06", "N07"])`: N05 starts at
   t0 + 0.8 s, with the first glow. `deferStarts` uses `CACurrentMediaTime`, is cancelled by
   `stop()`, and fires `currentClip`/`onClipPlayed` at the clip's actual start.

**Playback**: one `AVAudioPlayer`, `prepareToPlay()` at AppModel init, after each completion, and
after an interruption ends; play = `currentTime = 0; play()`. It shares NarrationPlayer's session
(`.playback`, `.spokenAudio`) and never changes category, mode, or activation (that would cut
narration and add route latency); it mixes with narration, offline. Sync assumes the built-in
speaker; Bluetooth adds 100–300 ms and is not used in sessions.

**Asset**: `ios/CleanHands/Resources/LampClick.caf` from `tools/make_lamp_click.py` (stdlib, fixed
seed, reproducible) + `afconvert -f caff -d LEI16@48000 -c 1` (mono LPCM, no decoder start-up,
≈ 10 KB). Waveform: two soft transients 30 ms apart (second 8 dB quieter), each a 1.5 ms
raised-cosine attack into 1–4 kHz band-passed noise (τ ≈ 8 ms) over a 180 Hz thump
(τ ≈ 20 ms), 110 ms, 10 ms fade-out, peak −18 dBFS. No speech or third-party audio; SC-008 review.

## 8. Face guard and pauses (FR-020)

- `blank = true` sets `blankAmount = 1` on the same frame; the shader returns black before any lamp
  math and the pool and coverage passes are skipped. No transition, threshold, or timer delays it.
- AppModel sets `renderer.frozen = isPaused` on every state entry; `blank` implies frozen.
  Frozen holds `uvLinear`, `uvAmount`, `velocity`, `glowReveal` (C8); a retarget is stored with no
  click. Resume continues from the held values: no click, no replayed spread.
- Un-blank: `blankAmount` 1 → 0 through the same ramp and follower, mapped linearly (≤ 0.048 per
  frame at 30 fps); glow waits for the badge (interlock). A new face sets it to 1 again at once.
- Stop and abort leave the lamp as it is: capture stops and the last frame is held under the calm
  surface (choreography §6–7); `blank` is set only if the abort came from the face guard.

## 9. Performance (FR-021, SC-006)

| Item | Cost per frame |
|---|---|
| Integrator, channels, badge edge | 1 `exp`, < 30 flops (CPU) |
| Reveal factor | 1 smoothstep per instance (≤ 800), only during the 1.5 s spread |
| Final pass | ≈ 15 ALU ops per pixel; no new samples, passes, or uniform bytes |
| Pool + coverage | Only when `uvAmount > 0`, as in 001's UV view: switch frames ≤ UV frames + < 0.1 ms |

Nothing is allocated on the switch-on frame (textures ensured every frame, pipelines at init,
`LampClick` prepared). The lamp exists only in the shader: no SwiftUI opacity, blur, or material
animates over `MetalCameraView`. `GlassSurface` chrome (strip, badge) is solid at
`QualityLevel.medium`/`.low` (motion-and-surfaces §2.2): a material over a Metal layer that
changes every frame re-blurs its backdrop every frame. The swap is instant, and
`QualityController`'s hysteresis prevents flicker.

## 10. Acceptance checks

| # | Check | Method | Proves |
|---|---|---|---|
| L1 | `uvAmount ≥ 0.99` at 0.80 ± 0.02 s; Reduce Motion done at 0.60 s | `LampTransitionTests`, dt 1/60 and 1/30 | FR-001 |
| L2 | 400 random runs (≤ 10 reversals, 5 % tripled dt, 24–60 fps): Δ`dark` ≤ 0.09, Δ`skin` ≤ 0.11, white-scene mean Δ ≤ 0.095 per frame | unit | SC-001 |
| L3 | `glowGate > 0` ⇒ `skin == 1 && dark == 1`; on switch-off the last glow frame precedes the first `skin < 1` frame | unit | FR-002 |
| L4 | Retarget at every frame: `|ΔuvAmount| ≤ dt/Tr + 0.002`; at 60 fps `|Δvelocity| ≤ 1.05 /s` per frame except the kick (a reversal spans ≥ 3 frames) | unit | FR-004 |
| L5 | `revealOrder` rises tip → DIP → PIP → MCP → wrist → forearm, within 0…1; instances at `glowReveal = 1` equal `reveal` disabled | `GlowRevealTests` | FR-004a |
| L6 | Fixed `uvAmount` 0, 0.25 … 1: mean luma monotonic; no glow pixel at ≤ 0.80; 1 = 001 UV output; 0 = camera exactly | `RendererTests` | FR-001, FR-002 |
| L7 | No consecutive-frame mean luma step > 25/255: on, off, five fast reversals | `tools/measure_transition.swift` | SC-001 |
| L8 | Badge fully opaque in the first glow frame; QA assertion never fires | recording, QA build | SC-002 |
| L9 | Click onset ≤ 1 frame from the first changed frame; none on switch-off or resume; N05 ≥ 0.8 s after it | recording with audio | FR-016 |
| L10 | Face mid-switch: next frame black; resume: no click, no replayed spread | recording | FR-020 |
| L11 | A10 ≥ 30 fps, A12+ ≥ 60 fps through 10 fast reversals; switch-frame GPU time ≤ UV steady state + 0.3 ms | Device Check, replay harness | SC-006 |

## 11. Alignment with sibling contracts

Resolved 2026-11-04: `choreography.md` and `motion-and-surfaces.md` now follow §2 (integrator and
reversal rule), §3 (glow returns through `glowGate` on toggles), and §4 (0.4 s linear reduced lamp).
