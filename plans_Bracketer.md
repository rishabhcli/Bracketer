# Bracketer Ultra Mega Codex Goal Prompt

Copy the prompt below into Codex goal mode from the root of this repository.

```text
You are Codex operating inside /Users/m3-max/Documents/GitHub/Bracketer.

Set your active goal to this:

Make Bracketer the most obsessively reliable, professional, end-to-end bracketed photography system possible on iPhone: a native SwiftUI camera that can plan, capture, verify, review, annotate, export, and test bracketed photo sequences with the level of truthfulness, polish, observability, and resilience expected from a serious computational photography product.

This is intentionally an asymptotic goal. Do not treat it as a quick feature request. Treat it as a long-running product hardening and invention campaign. The north star is not "add a screen." The north star is "a photographer can trust this app under real pressure, understand exactly what it captured, recover from bad device states, and prove the behavior with tests."

However, do not waste the machine in a literal infinite loop. Iterate aggressively, keep going without asking for permission, and only stop when you have delivered a verified, meaningful wave of improvement and written the next wave of work so the goal can resume cleanly. If you cannot continue because of hardware, signing, simulator availability, or an external blocker, make the blocker concrete, preserve all useful work, and leave a runnable continuation plan.

Repository facts you must respect

- This is a native SwiftUI iPhone app in `Bracketer.xcodeproj`.
- Main source lives in `Bracketer/`.
- Unit tests live in `BracketerTests/` and use Swift Testing.
- UI tests live in `BracketerUITests/` and use XCTest.
- The app currently focuses on bracketed camera capture, ProRAW/HEIF handling, settings persistence, Liquid Glass style controls, viewfinder overlays, histogram/focus/depth review surfaces, and a review flow for the latest bracket sequence.
- Current README test command:
  `xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'`
- Existing UI test launch arguments:
  `-ui-testing-skip-onboarding`
  `-ui-testing-disable-camera-startup`
- The working tree may already contain unrelated user changes. Preserve them. Never revert work you did not make.

Operating rules

1. Inspect first, then act. Read the current source, tests, project settings, and docs before changing behavior.
2. Prefer the existing app direction: native SwiftUI, AVFoundation, Photos, CoreImage or Metal where appropriate, strong accessibility identifiers, deterministic test harnesses, and small focused components.
3. Do not ask the user for permission before executing normal development commands. The user already granted permission.
4. Do not claim success from a code diff. Claim success only after running the relevant build, unit, UI, and end-to-end checks.
5. When a simulator cannot represent a real camera behavior, build deterministic simulation seams and test those. Keep simulator proof and physical-device proof clearly separated.
6. Avoid fake product claims. If a feature is simulated, label it as a test harness or preview-only path in code and docs.
7. When you hit a failure, diagnose it from logs, patch the root cause, and rerun the narrowest failing check before the full suite.
8. If the same failure repeats three times, stop repeating the same fix. Change strategy, isolate the failing subsystem, add instrumentation, or reduce the repro.
9. Keep changes shippable. Each iteration should leave the repo more buildable, more testable, and more truthful than before.
10. Maintain a running engineering ledger in `BRACKETER_EVOLUTION_LEDGER.md` if it does not already exist. Update it after every meaningful wave with what changed, what passed, what failed, and what should happen next.

The self-improvement loop

Run this loop continuously during the session:

Cycle 0: Baseline truth
- Run `git status --short --branch`.
- Read `README.md`, `Bracketer/BracketerApp.swift`, `Bracketer/ModernContentView.swift`, `Bracketer/CameraController.swift`, `Bracketer/SettingsStore.swift`, `Bracketer/PreviewContainer.swift`, `Bracketer/ImageViewer.swift`, `Bracketer/ModernProControls.swift`, `Bracketer/ModernSettingsPanel.swift`, `BracketerTests/BracketerTests.swift`, and `BracketerUITests/BracketerUITests.swift`.
- Discover schemes and simulators if the README destination is unavailable.
- Run the current tests once to establish the baseline. Save exact failures and do not hide them.

Cycle 1 and onward: Improve, prove, repeat
- Pick the highest-impact, smallest-complete vertical slice from the backlog below.
- Implement it end to end, including production code, test seams, UI identifiers, docs, and regression tests.
- Run targeted checks for the changed subsystem.
- Run the full verification gate.
- Update the ledger with evidence.
- Re-score the backlog based on what you learned.
- Start the next slice immediately if there is context, time, and a safe path forward.

Stopping rule

Do not stop just because one patch landed. Stop only when at least one substantial vertical slice has shipped and the full verification gate has either passed or has a concrete, documented blocker that cannot be resolved in this environment. Before stopping, leave the repo in a coherent state and write the next exact command and next exact file to edit in the ledger.

Full verification gate

Run as much of this as the local machine supports:

1. `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -showBuildSettings`
2. `xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'`
3. If that simulator is unavailable, discover a valid iOS simulator and rerun with that destination.
4. Run unit tests after every model or planner change.
5. Run UI tests after every user-flow, accessibility identifier, onboarding, settings, camera chrome, or review-flow change.
6. Launch the app on a simulator when feasible and inspect the first screen.
7. Capture screenshots for major UI changes.
8. Inspect runtime logs for camera/session/permission errors when startup code changes.
9. If a physical iPhone is connected and signing is configured, run a device build and clearly mark it as physical-device proof.
10. Do not call physical camera behavior verified unless it actually ran on a device with a camera.

Product ambition backlog

Wave A: Make capture truth impossible to fake
- Extract bracket planning into a richer pure Swift model with explicit EV offsets, center bias, shot count, ordering, labels, and validation.
- Support only truthful shot counts. If 3, 5, and 7 are the supported set, reject or normalize unsupported counts with a visible reason.
- Add tests for every supported EV step, center bias, shot count, and invalid state.
- Add a `BracketSequenceState` model that can represent idle, preparing, capturing index N, saving, completed, cancelled, timed out, and failed.
- Make UI progress derive from this state rather than scattered booleans where possible.
- Add cancellation and timeout recovery that cannot leave `isCapturing` stuck.

Wave B: Create a deterministic camera simulation layer
- Add a simulator/test camera path behind launch arguments, never enabled in normal production launch.
- Make fake camera startup deterministic for UI tests.
- Make fake bracket capture produce deterministic progress, assets or asset summaries, metadata, and review states.
- Add UI tests for opening pro controls, changing EV step, changing shot count, starting a simulated bracket capture, seeing progress, reaching completion, and opening review.
- Keep the test harness honest: no Photos writes in UI tests unless explicitly isolated.

Wave C: Turn settings into a stable contract
- Add pure tests for `SettingsStore` persistence with an injectable `UserDefaults` suite or equivalent seam.
- Clamp persisted values such as focus peaking intensity, EV step, and bracket shot count.
- Add reset-to-defaults behavior if corruption is detected.
- Add UI coverage for settings categories, quick presets, grid type, focus peaking, capture summary, timer, and flash.
- Give every important control a stable accessibility identifier.

Wave D: Make the pro camera UI feel inevitable
- Audit portrait and landscape layouts for overlap, safe areas, Dynamic Type, VoiceOver labels, and reachable controls.
- Replace duplicated top and bottom control implementations where duplication causes drift.
- Make mode switching, grid, level, RAW, flash, timer, zoom, settings, and pro controls all expose truthful state.
- Add screenshots or UI tests for portrait and landscape camera chrome.
- Make all controls disabled or explained when the current lens or device cannot support the action.

Wave E: Build real review intelligence
- Make review mode show the entire bracket as a sequence with EV labels, timestamp, file type, capture state, and metadata availability.
- Add comparison affordances: previous/next, best exposure marker, clipped highlights/shadows warning, EXIF overlay, and delete confirmation.
- Create pure metadata summary models so review can be tested without Photos.
- Add tests for empty sequence, partial sequence, deletion, selected index bounds, and RAW/processed toggles.

Wave F: Make histogram, waveform, zebra, and focus tools real
- Trace the current histogram path from sample buffer to overlay.
- Replace decorative or simulated analysis with real sample-derived data wherever simulator and AVFoundation allow.
- Add a pure histogram processor test with synthetic pixel buffers or a deterministic image fixture.
- Add clipping detection and zebra overlay thresholds.
- Add false-color exposure view if it can be done cleanly.
- Add focus peaking based on real edge detection for available frames, with a clear fallback in simulator.

Wave G: Device capability and permission hardening
- Turn `DeviceGating` into a first-class capabilities contract.
- Model camera availability, lens availability, flash availability, ProRAW support, Photos authorization, location authorization, notification authorization, storage preflight, and low-power constraints.
- Surface recoverable errors in the UI with exact action paths.
- Add unit tests for capability resolution.
- Add UI tests for denied/pending/unavailable states using launch-argument fakes.

Wave H: Observability and performance
- Add structured logging with categories for launch, permissions, session configuration, lens change, bracket planning, bracket progress, save completion, review, and error recovery.
- Add `os_signpost` or equivalent timing around startup, session configuration, bracket capture, Photos save, review image load, and histogram processing.
- Add debug-only overlays or exportable diagnostics if useful.
- Run launch performance tests and keep the existing launch metric honest.
- If Xcode tooling is available, collect a basic performance trace for launch or a simulated capture flow.

Wave I: Documentation, CI, and release discipline
- Update `README.md` with the verified local commands and simulator fallback guidance.
- Add or update docs that explain test launch arguments and the fake camera harness.
- Add a concise architecture note for capture, planning, settings, and review.
- Add CI or improve existing GitHub Actions if the project already has a workflow.
- Make every new command copy-pasteable.

Wave J: Computational photography moonshots
- Add an internal representation for bracket groups that can support future HDR merge, exposure fusion, deghosting, alignment, and tone mapping.
- Prototype a deterministic exposure-fusion preview using CoreImage if feasible.
- Add a save/export path for bracket manifests so professional workflows can import a sequence with metadata intact.
- Explore RAW plus processed pairing, sidecar metadata, and naming conventions.
- Add privacy-preserving, local-only scene analysis if it materially improves capture recommendations.

Execution strategy

- Start with architecture and tests before ambitious UI.
- Prefer pure Swift models for anything that can be modeled outside AVFoundation.
- Add seams around AVFoundation and Photos instead of trying to drive hardware in unit tests.
- Keep simulator UI tests deterministic.
- Keep physical camera behavior separate and optional.
- After each slice, ask:
  1. Did the app become more truthful?
  2. Did the app become more testable?
  3. Did a real photographer gain a capability or lose a source of uncertainty?
  4. Did verification evidence improve?
  5. What is now the highest-leverage next slice?

First slice recommendation

Begin by building a real bracket domain layer and deterministic capture state model:

- Create or refactor pure models for bracket plan, bracket shot, bracket sequence state, and capture progress.
- Migrate current EV offset logic into the model while preserving existing behavior.
- Add unit tests for 3, 5, and 7 shot plans, center bias, invalid shot counts, display labels, progress, cancellation, timeout, and completion.
- Thread this model into the existing progress UI enough that UI copy and progress are driven by a single source of truth.
- Run the full test gate.
- Update the ledger.
- Then move immediately into the fake camera UI-test harness.

Definition of a meaningful completed wave

A wave is complete only if it includes:

- Production code.
- Focused unit or UI tests.
- A successful targeted verification command, or exact failure evidence with a fixed follow-up.
- Documentation or ledger update.
- No hidden unrelated reverts.
- A clear next slice.

Final response format when you stop

Report:

- What changed.
- What verification passed.
- What verification failed or was blocked, with exact command and error.
- What remains next.
- Whether the active goal is complete or still intentionally open.

Do not call the full north-star goal complete unless Bracketer has passed every local verification gate and there is no known high-impact backlog remaining. That outcome is expected to be extremely rare. Most successful sessions should end with "goal still open, wave complete, next slice ready."
```

