# Top 15 Execution Roadmap

This document converts the top 15 improvements from `IMPROVEMENT_BACKLOG.md` into an execution sequence that can be implemented directly in this repo.

Principles:
- Ship reliability before adding new pro surface area.
- Fix truthfulness gaps before polishing UI.
- Land tests and observability early enough to protect the rest of the work.
- Prefer changes that reduce ambiguity between persisted UI state and actual camera behavior.

## Sequence

### Phase 1: Capture Truth And Safety

1. Real flash integration
2. Real timer integration
3. Orientation unlock hardening
4. Cancel and recovery path for bracket capture
5. Truthful capture HUD

### Phase 2: Capability And Review Integrity

6. Capability matrix and control gating
7. Persist telephoto resolution preference
8. Image viewer delete-flow repair
9. Replace or hide simulated depth analysis

### Phase 3: Core UX Baseline

10. Tap-to-focus and tap-to-meter
11. Background lifecycle shutdown

### Phase 4: Quality And Release Confidence

12. Bracket planning unit tests
13. Orientation behavior tests
14. Core UI test coverage
15. CI, crash reporting, and analytics

## Dependency Notes

- `#1` and `#2` should land before `#5`, because the HUD cannot be made truthful while capture still ignores flash and timer.
- `#3` and `#4` should land before broader testing, because they stabilize the capture lifecycle.
- `#6` should land before large UX additions, because it determines what controls are real on each device and lens.
- `#12` through `#15` should begin in parallel once the first capture-lifecycle fixes are merged.

## Issue-Ready Specs

## 1. Wire `flashMode` Into The Real Capture Pipeline

Title: `Integrate flash selection into bracket capture settings`

Problem:
- `SettingsStore` persists flash state.
- `ModernContentView` and control views expose flash controls.
- `CameraController` hardcodes `photoSettings.flashMode = .off` in both RAW and processed bracket capture paths.

Scope:
- Define actual supported flash behavior per shooting mode and per lens.
- Thread the selected flash mode from UI state into the capture API.
- Disable or explain flash where hardware or bracket mode cannot support it safely.
- Update top-bar indicators so they reflect effective flash state, not only selected state.

Acceptance criteria:
- Choosing `Auto`, `On`, or `Off` changes the actual capture request when supported.
- Unsupported flash combinations are visibly disabled with explanation.
- Logging records selected and effective flash mode per capture.

Likely files:
- `Bracketer/CameraController.swift`
- `Bracketer/ModernContentView.swift`
- `Bracketer/CameraZoomControl.swift`
- `Bracketer/ContextualControls.swift`

Dependencies:
- None

## 2. Wire `timerMode` Into The Real Capture Pipeline

Title: `Add capture countdown flow driven by timerMode`

Problem:
- Timer is selectable in the UI and persisted.
- `captureLockdownBracket` fires immediately with no countdown behavior.

Scope:
- Add delayed capture scheduling for `3s` and `10s`.
- Provide countdown UI and haptic/audio cues.
- Support cancel during countdown.
- Keep orientation lock and progress UI behavior coherent during countdown.

Acceptance criteria:
- `Off` captures immediately.
- `3s` and `10s` delay capture with visible countdown.
- User can cancel countdown before the first photo is captured.

Likely files:
- `Bracketer/CameraController.swift`
- `Bracketer/ModernContentView.swift`
- `Bracketer/ContextualControls.swift`

Dependencies:
- None

## 3. Add A Safe Cancel And Recovery Path For In-Flight Bracket Captures

Title: `Add explicit cancel and recovery UX for bracket sessions`

Problem:
- The app can time out, but the user cannot proactively abort or recover from a stuck sequence.
- `sequenceInFlight`, `isCapturing`, timeout tasks, and viewer presentation need a single cancellation story.

Scope:
- Add cancel affordance during countdown and active capture.
- Centralize cleanup for cancellation, timeout, and failure.
- Distinguish canceled vs failed vs completed in UI feedback and analytics.

Acceptance criteria:
- Canceling during countdown or capture returns the app to a stable idle state.
- Orientation lock, progress state, and histogram processing all reset correctly.
- No extra asset grouping or viewer presentation occurs for a canceled capture.

Likely files:
- `Bracketer/CameraController.swift`
- `Bracketer/ModernContentView.swift`

Dependencies:
- Benefits from `#2`, but can be scaffolded alongside it

## 4. Guarantee Orientation Unlock On Every Exit Path

Title: `Harden orientation lock lifecycle across all capture exits`

Problem:
- The app locks orientation during bracket capture.
- Unlock happens in `finishSequence`, but all failure and interruption paths need to guarantee the same outcome.

Scope:
- Audit every path that can start, abort, fail, or dismiss capture.
- Move orientation cleanup into a single guaranteed teardown path.
- Add regression tests around lock/unlock behavior.

Acceptance criteria:
- Orientation always unlocks after success, failure, timeout, cancellation, and view dismissal.
- No stale “Orientation Locked” indicator remains after teardown.

Likely files:
- `Bracketer/CameraController.swift`
- `Bracketer/OrientationManager.swift`
- `Bracketer/ModernContentView.swift`

Dependencies:
- None

## 5. Make HUD Indicators Reflect Real Active Capture Configuration

Title: `Make camera HUD show effective rather than selected capture state`

Problem:
- The UI currently displays selected settings even when the camera cannot or does not honor them.
- This is especially visible for ProRAW, flash, timer, and tele resolution.

Scope:
- Introduce “effective capture configuration” derived from hardware support and current mode.
- Display unsupported, pending, and active states distinctly.
- Ensure badges update after lens switches and mode changes.

Acceptance criteria:
- HUD badges always match the actual upcoming capture configuration.
- Lens and mode changes update the HUD immediately.

Likely files:
- `Bracketer/CameraController.swift`
- `Bracketer/ModernContentView.swift`
- `Bracketer/ModernSettingsPanel.swift`

Dependencies:
- `#1`
- `#2`
- `#6`

## 6. Build A Real Capability Matrix And Enforce It In The UI

Title: `Create capability matrix for lenses, formats, and advanced controls`

Problem:
- Device support exists in `DeviceGating`, but control-level support is still implicit and inconsistent.
- The app needs feature truth at the lens and capture-format level, not just device-level gating.

Scope:
- Define a model describing support for RAW, flash, timer, tele resolution, focus control, depth, and review features.
- Use it to disable, hide, or explain controls in camera, settings, and review surfaces.

Acceptance criteria:
- Unsupported controls are not tappable without explanation.
- Capability changes after switching lens are reflected immediately.

Likely files:
- `Bracketer/DeviceGating.swift`
- `Bracketer/CameraController.swift`
- `Bracketer/ModernContentView.swift`
- `Bracketer/ModernSettingsPanel.swift`

Dependencies:
- None

## 7. Persist `teleUses12MP`

Title: `Persist telephoto resolution preference in SettingsStore`

Problem:
- Tele resolution is currently held on `CameraController`, so the user preference does not survive a restart.

Scope:
- Add storage key and persistence behavior.
- Initialize camera state from persisted preference.
- Re-apply the correct capture format when the user changes the setting.

Acceptance criteria:
- Selected tele resolution survives relaunch.
- Switching between relevant tele modes continues to honor the stored preference.

Likely files:
- `Bracketer/SettingsStore.swift`
- `Bracketer/CameraController.swift`
- `Bracketer/ModernSettingsPanel.swift`

Dependencies:
- None

## 8. Fix The Image Delete Flow

Title: `Repair bracket viewer after deleting an asset`

Problem:
- `ImageViewer` deletes from Photos but does not mutate its local `bracketAssets` collection.
- The current logic recalculates indices against a constant array, which risks stale UI state.

Scope:
- Make the review surface own a mutable asset list or delegate deletion back to the parent.
- Update index and dismissal behavior after deletes.
- Handle failed deletes and last-item deletes cleanly.

Acceptance criteria:
- Deleting the current image never leaves the viewer in an invalid state.
- Deleting the last remaining item dismisses cleanly.
- Deleting from the middle or end keeps navigation coherent.

Likely files:
- `Bracketer/ImageViewer.swift`
- `Bracketer/ModernContentView.swift`

Dependencies:
- None

## 9. Replace Or Hide Simulated Depth Analysis

Title: `Remove simulated depth experience or replace with real depth-backed analysis`

Problem:
- `DepthMapViewer` currently uses simulated depth output.
- `EXIFViewer` exposes depth analysis as if it were a real professional review tool.

Scope:
- Decide between real depth support or temporary removal.
- If removing, gate the section behind actual depth availability.
- If implementing, ensure the viewer is fed real captured depth data only.

Acceptance criteria:
- No simulated depth UI is presented as real analysis.
- Depth analysis is shown only when backed by real data.

Likely files:
- `Bracketer/DepthMapViewer.swift`
- `Bracketer/EXIFViewer.swift`

Dependencies:
- `#6`

## 10. Add Tap-To-Focus And Tap-To-Meter

Title: `Support point focus and exposure metering on preview tap`

Problem:
- The camera lacks a baseline interaction users expect from any serious camera app.

Scope:
- Capture tap location from the preview.
- Translate view coordinates to camera points of interest.
- Drive autofocus and autoexposure at the selected point.
- Show focus UI feedback and failure handling.

Acceptance criteria:
- Tapping the preview updates focus and exposure targets.
- User sees visible focus confirmation and receives error feedback if unsupported.

Likely files:
- `Bracketer/PreviewContainer.swift`
- `Bracketer/CameraController.swift`
- `Bracketer/ModernContentView.swift`

Dependencies:
- `#6`

## 11. Stop Camera, Motion, And Location Work When Backgrounded

Title: `Add scenePhase-driven lifecycle shutdown and resume`

Problem:
- `ModernContentView` starts camera and motion work, but lifecycle handling is minimal.
- Battery and state integrity both depend on aggressive teardown and clean resume.

Scope:
- Observe `scenePhase`.
- Stop camera session, motion updates, location updates, timers, and expensive overlays when backgrounded.
- Restore safely on foreground.

Acceptance criteria:
- Backgrounding leaves no active capture timers or unnecessary sensor work.
- Returning foreground restores preview cleanly without duplicate timers or observers.

Likely files:
- `Bracketer/BracketerApp.swift`
- `Bracketer/ModernContentView.swift`
- `Bracketer/CameraController.swift`
- `Bracketer/MotionManager.swift`

Dependencies:
- `#4`

## 12. Add Unit Tests For Bracket Planning Logic

Title: `Add unit coverage for EV offset generation and sequence planning`

Problem:
- The bracket math is core product logic and currently unprotected.

Scope:
- Cover EV offsets for 3, 5, and 7-shot plans.
- Cover edge cases and invalid shot counts.
- Extract pure planning helpers if needed to make them testable.

Acceptance criteria:
- Tests verify expected EV plans and defaults.
- Planning behavior can change only with explicit test updates.

Likely files:
- `Bracketer/CameraController.swift`
- `BracketerTests/BracketerTests.swift`

Dependencies:
- None

## 13. Add Tests For Orientation Lock And Unlock Behavior

Title: `Add reliability tests for orientation lock lifecycle`

Problem:
- Orientation locking is critical to bracket consistency and easy to break as lifecycle code evolves.

Scope:
- Test lock, unlock, effective orientation, and cleanup behavior.
- Use dependency seams or extracted logic where UIKit scene state makes direct testing awkward.

Acceptance criteria:
- Lock state transitions are covered by tests.
- Failure and completion teardown paths are verifiable.

Likely files:
- `Bracketer/OrientationManager.swift`
- `BracketerTests/BracketerTests.swift`

Dependencies:
- None

## 14. Add UI Tests For Onboarding, Permission Denial, And Main Capture Loop

Title: `Add UI coverage for first-run and core camera flows`

Problem:
- The UI test target is still scaffold-level.

Scope:
- Add launch coverage for onboarding.
- Add denied-permission flows and recovery messaging.
- Add smoke coverage for switching modes, opening settings, and presenting review UI.

Acceptance criteria:
- Core app surfaces can be exercised automatically.
- Tests are deterministic and use launch arguments or injected state where needed.

Likely files:
- `BracketerUITests/BracketerUITests.swift`
- App code for launch arguments and test hooks

Dependencies:
- `#3`
- `#4`
- `#11`

## 15. Add CI, Crash Reporting, And Basic Analytics

Title: `Add release confidence stack for Bracketer`

Problem:
- The app currently lacks automated gates and post-release visibility.

Scope:
- Add CI for build and tests.
- Integrate crash reporting.
- Track onboarding completion, permission outcomes, first successful bracket, and review usage.

Acceptance criteria:
- Every PR can run build and test checks automatically.
- TestFlight builds emit crash and funnel data.
- Analytics events are privacy-conscious and documented.

Likely files:
- `.github/workflows/*`
- `BracketerApp.swift`
- `Logger.swift` or a new analytics/crash service

Dependencies:
- `#12`
- `#13`
- `#14`

## Suggested Sprint Cut

Sprint 1:
- `#1`
- `#2`
- `#4`
- `#7`
- `#8`

Sprint 2:
- `#3`
- `#5`
- `#6`
- `#9`

Sprint 3:
- `#10`
- `#11`
- `#12`
- `#13`

Sprint 4:
- `#14`
- `#15`

## Definition Of Done For The Top 15

- No camera control shown in the main surface is knowingly disconnected from real capture behavior.
- The app survives countdown, capture, timeout, backgrounding, and review transitions without stale UI state.
- At least the pure logic and core UI smoke paths are covered by automated tests.
- A TestFlight build can answer basic questions about crashes, onboarding drop-off, and first successful use.
