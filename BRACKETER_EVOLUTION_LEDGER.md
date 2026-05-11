# Bracketer Evolution Ledger

## 2026-05-10 22:46 PDT - Wave A bracket truth/state model

### What changed

- Added a pure bracket domain layer in `Bracketer/BracketSequence.swift`:
  - `BracketPlan` normalizes supported shot counts to 3, 5, or 7 and records visible normalization reasons.
  - `BracketShot` carries EV offset, display label, filename label, and center-exposure identity.
  - `BracketSequenceState` represents idle, preparing, capturing, saving, completed, cancelled, timed out, and failed.
  - `BracketCaptureProgress` derives UI title, subtitle, fraction, and overlay visibility from the state.
- Threaded `BracketSequenceState` into `CameraController` so capture progress, terminal failure, timeout, cancellation, and runtime stop cleanup share one source of truth.
- Updated progress UI and camera controls to read from the sequence state instead of scattered capture booleans where this wave touched the surface.
- Reused the bracket model in pro-control EV sequence preview so shot labels and offsets are no longer duplicated.
- Hardened test startup behavior so app-hosted tests skip camera/motion side effects when `XCTestConfigurationFilePath` is present.
- Stabilized UI tests:
  - The settings Capture tab is selected through the segmented control instead of a global `"Capture"` label that also matched the shutter button.
  - Capture settings badges now expose stable `settings.badge.*` accessibility identifiers.
  - UI tests reset portrait orientation and scroll the settings sheet before asserting capture badges.

### Verification

- Passed:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -showBuildSettings`
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=9A736488-5A58-488C-BFAE-B6E4701CA952' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`
  - Final full-gate result: 7 XCTest UI/launch tests passed, 16 Swift Testing unit tests passed.
  - Result bundle: `/Users/m3-max/Library/Developer/Xcode/DerivedData/Bracketer-fanualotxeikjienxhqjafhbdmnr/Logs/Test/Test-Bracketer-2026.05.10_22-45-15--0700.xcresult`
- Passed targeted checks:
  - Unit-only bracket/model run: `/tmp/bracketer-unit-iphone17.log`
  - Capture-settings UI regression run: `/tmp/bracketer-ui-capture-settings-4.log`

### Failures encountered and resolved

- Earlier full-gate runs failed because the settings UI test tapped `"Capture"` by label and matched both the shutter button and the settings segmented tab.
- After that fix, the capture badge assertions were still offscreen when the simulator inherited landscape orientation from launch tests. The test now owns orientation and scrolls the settings sheet before checking the badge contract.
- CoreSimulator produced noisy warnings during successful runs:
  - `IDELaunchParametersSnapshot: no debugger version`
  - Diagnostic collection warning: `xcrun: error: unable to find utility "simctl", not a developer tool or in PATH`
  These did not fail the final gate.

### Next slice

- Start Wave B: deterministic fake camera UI-test harness.
- Next file to edit: `Bracketer/CameraController.swift`, then add a small simulator-only capture adapter/model file if the seam gets bigger than one file.
- Next command before and after the slice:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=9A736488-5A58-488C-BFAE-B6E4701CA952' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

### Goal status

- Goal still open, wave complete, next slice ready.

## 2026-05-10 23:58 PDT - Wave B deterministic camera simulation harness

### What changed

- Added `Bracketer/SimulatedBracketReview.swift` with deterministic simulated bracket review data, fixed capture date, stable simulated asset identifiers, and a SwiftUI review surface that labels every EV row for UI tests.
- Added a simulator-only camera path behind `-ui-testing-simulated-camera`:
  - `CameraController` can skip live camera startup, publish a simulated review, and present that review through the existing library/review flow.
  - `ModernContentView` uses a non-interactive SwiftUI fake preview under the launch argument.
  - The UI-test harness prepares the deterministic review after Pro Controls are dismissed, keeping Photos writes out of UI tests.
- Added regression coverage:
  - Unit coverage for deterministic simulated review summaries and asset ids.
  - UI coverage for opening Pro Controls, selecting `+/-2.0 EV`, selecting 5 shots, dismissing Pro Controls, opening the simulated review, and asserting the 5-shot EV labels.
- Tightened review accessibility by giving per-shot EV labels their own identifiers instead of inheriting the list identifier.

### Verification

- Passed targeted UI test:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T06-52-28-839Z_pid14786_d88a0e26.xcresult`
- Passed targeted unit suite:
  - `BracketerTests`: 17 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T06-53-27-789Z_pid14786_abcb5613.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - 22 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T06-53-41-642Z_pid14786_6801c9a0.xcresult`

### Failures encountered and resolved

- The original iPhone 17 and iPhone 17 Pro simulators became unreliable during UI runs with CoreSimulator Mach `-308 (ipc/mig) server died` style launcher failures. A throwaway iPhone 17 simulator, `BracketerUITest-230901`, was created and used for final verification.
- XCTest could find and synthesize taps on the shutter button, but in this simulator stack the tap did not reliably drive SwiftUI's shutter action. The final UI test avoids pretending the physical tap was proven: the simulated-camera harness prepares the review after Pro Controls close, then verifies the deterministic review through the library flow.
- The first simulated review UI exposed all EV labels under `review.simulated.shotList`; removing the parent list identifier restored stable per-shot identifiers such as `review.simulated.shot.0.label`.

### Next slice

- Start Wave C: make settings persistence a stable contract.
- Next file to edit: `Bracketer/SettingsStore.swift`.
- Recommended first checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' \
  -only-testing:BracketerTests \
  -skip-testing:BracketerUITests \
  -skip-testing:BracketerUITestsLaunchTests \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

### Goal status

- Goal still open, Wave B complete, next slice ready.

## 2026-05-11 00:03 PDT - Wave C settings persistence contract

### What changed

- Updated `Bracketer/SettingsStore.swift` so settings persistence is testable through an injected `UserDefaults` suite instead of hard-wired `UserDefaults.standard`.
- Added settings normalization:
  - Focus peaking intensity is clamped to the slider-supported `0.1...1.0` range.
  - EV step is snapped to supported UI values `1.0`, `2.0`, or `3.0`.
  - Bracket shot count is snapped to the supported bracket counts `3`, `5`, or `7`.
- Persisted normalized values back to defaults during initialization so corrupt stored values do not survive reload.
- Added `resetToDefaults()` to restore the full settings contract in one call.
- Added focused tests for injected persistence, corrupt persisted values, setter normalization, and reset-to-defaults behavior.
- Documented the settings persistence contract in `README.md`.

### Verification

- Passed targeted unit suite:
  - `BracketerTests`: 20 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-00-32-832Z_pid14786_8dfa2813.xcresult`
- Passed targeted settings UI smoke:
  - `testCaptureSettingsShowEffectiveConfigurationWhenCameraStartupIsDisabled`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-00-53-938Z_pid14786_422b8a2b.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - 25 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-01-23-004Z_pid14786_088cabc4.xcresult`

### Failures encountered and resolved

- No test failures in this slice.
- The implementation also fixed a quiet persistence risk: numeric `UserDefaults` values are now read through `float(forKey:)` only when the key exists, avoiding accidental fallback caused by bridged `NSNumber` reads.

### Next slice

- Continue Wave C with UI coverage for settings categories, quick presets, grid type, focus peaking, timer, and flash.
- Next file to edit: `BracketerUITests/BracketerUITests.swift`, then add missing accessibility identifiers in `ModernSettingsPanel.swift` where needed.
- Recommended first command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' \
  -only-testing:BracketerUITests/BracketerUITests/testCaptureSettingsShowEffectiveConfigurationWhenCameraStartupIsDisabled \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

### Goal status

- Goal still open, Wave C persistence contract slice complete, next slice ready.

## 2026-05-11 00:31 PDT - Wave C settings UI contract

### What changed

- Added stable accessibility identifiers and values for the settings sheet contract:
  - Category segmented picker: `settings.categoryPicker`.
  - Quick presets: `settings.preset.landscape`, `settings.preset.portrait`, `settings.preset.studio`, and `settings.preset.tripod`.
  - Viewfinder toggles: `settings.toggle.grid`, `settings.toggle.level`.
  - Grid style picker: `settings.picker.gridStyle`.
  - Focus peaking toggle, selected color value, intensity readout, and slider.
- Added `-ui-testing-reset-settings` to the settings store launch path so UI tests can reset persisted preferences before asserting settings state.
- Added `testSettingsPresetsAndCaptureControlsExposeStableState`, which now verifies:
  - Timer control changes from `Off` to `3s`.
  - Flash is truthfully reported as `Unavailable` when camera startup is disabled.
  - Landscape preset applies Golden Ratio grid and keeps grid/level enabled.
  - Portrait preset enables focus peaking with orange peaking color at 65 percent intensity.
  - Capture settings summary reflects timer, flash, and photo format state.
- Updated existing UI-test launches to use the reset-settings argument so settings tests do not leak preference state across runs.
- Documented the UI-test reset argument and settings accessibility contract in `README.md`.

### Verification

- Passed simulator build:
  - Log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T07-15-58-221Z_pid14786_fb092860.log`
- Passed targeted settings UI contract:
  - `testSettingsPresetsAndCaptureControlsExposeStableState`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-21-19-269Z_pid14786_d8d65375.xcresult`
- Passed targeted unit suite:
  - `BracketerTests`: 20 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-24-29-974Z_pid14786_e2a242b5.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - 26 tests passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-25-50-939Z_pid14786_40362a60.xcresult`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- The first targeted settings UI attempt failed because XCTest could not reliably query an individual peaking color swatch inside SwiftUI's lazy grid. The contract now exposes the selected peaking color as a stable value on the peaking color group, while the individual swatches still keep identifiers for future interaction coverage.
- A follow-up targeted run timed out at app launch after the simulator stopped returning screenshots with `Timeout waiting for screen surfaces`. The dedicated throwaway UI-test simulator was erased and booted with `xcrun simctl`, after which the targeted settings test passed.
- XcodeBuildMCP's wrapper timed out on longer UI runs, but the underlying `xcodebuild` processes completed and were verified through their `.xcresult` bundles.
- The final test reports still include a SwiftUI runtime warning:
  - `Adding '_UIReparentingView' as a subview of UIHostingController.view is not supported...`
  This warning did not fail the gate and remains a future UI/runtime cleanup item.

### Next slice

- Start Wave D: audit and harden the pro camera UI across portrait and landscape.
- Next file to inspect first: `Bracketer/ModernContentView.swift`, then `Bracketer/ContextualControls.swift` and `Bracketer/CameraZoomControl.swift` for duplicated state/control surfaces.
- Recommended first checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' \
  -only-testing:BracketerUITests/BracketerUITests/testCameraScreenLaunchesWithStableControls \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

### Goal status

- Goal still open, Wave C settings UI contract slice complete, next slice ready.

## 2026-05-11 00:58 PDT - Wave D camera chrome layout and state contract

### What changed

- Added deterministic UI-test layout overrides for the camera chrome:
  - `-ui-testing-force-portrait-layout`
  - `-ui-testing-force-landscape-layout`
- Added a tiny `CameraChromeProbe` accessibility surface so UI tests can assert layout regions without stealing child control identifiers.
- Added stable accessibility identifiers and values for camera chrome state:
  - Layout branch: `camera.chromeLayout`.
  - Chrome regions: `camera.topBar`, `camera.bottomControls`, `camera.primaryControls`, `camera.secondaryControls`, and `camera.zoomControl`.
  - Shooting mode: `camera.shootingModeButton`.
  - Bracketing step: `camera.bracketingIndicator`.
  - Grid and level toggles: `camera.gridToggleButton`, `camera.levelToggleButton`.
  - Zoom buttons: `camera.zoom.wide` and future lens-specific identifiers.
  - Pro controls now report `Open` or `Closed` from both the top badge and bottom button.
- Added `testCameraChromeExposesPortraitAndLandscapeContracts`, which verifies:
  - Portrait and landscape chrome branches are both reachable through deterministic launch arguments.
  - Top, bottom, primary, secondary, shutter, settings, library, pro controls, flash, timer, grid, level, bracketing, mode, and zoom contracts are visible.
  - Grid toggling reports truthful `On` and `Off` values.
  - Mode switching from `AUTO` to `NIGHT` updates the shooting mode and contextual controls state.
- Documented the new layout launch arguments and camera chrome accessibility contract in `README.md`.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T07-47-23-599Z_pid14786_869a5cec.log`
- Passed targeted camera chrome UI contract:
  - `testCameraChromeExposesPortraitAndLandscapeContracts`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-47-39-750Z_pid14786_56845c9a.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - 27 tests passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T07-51-52-184Z_pid14786_e3248334.xcresult`
- Passed build-settings inspection through XcodeBuildMCP:
  - Project: `/Users/m3-max/Documents/GitHub/Bracketer/Bracketer.xcodeproj`
  - Scheme: `Bracketer`
  - `DEVELOPER_DIR`: `/Applications/Xcode.app/Contents/Developer`
  - `TARGETED_DEVICE_FAMILY`: `1`
  - `IPHONEOS_DEPLOYMENT_TARGET`: `26.2`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- The first targeted chrome UI attempt failed because group-level `accessibilityIdentifier` modifiers on SwiftUI containers propagated into child controls, replacing identifiers like `camera.flashModeButton` with `camera.bottomControls`.
- A simulator UI snapshot confirmed the identity poisoning: top-bar children all surfaced as `camera.topBar`, and bottom controls all surfaced as `camera.bottomControls`.
- Replaced those container identifiers with separate 1-point `CameraChromeProbe` elements, preserving testable group markers while leaving child control identifiers intact.
- XcodeBuildMCP wrapper calls timed out for long UI runs, but the underlying `xcodebuild` processes completed and were verified through `.xcresult` bundles.
- The final test reports still include the existing non-fatal SwiftUI `_UIReparentingView` runtime warning.

### Next slice

- Continue Wave D by reducing duplicated top/bottom chrome implementations and adding a more visual layout regression check for safe areas and overlap.
- Next files to inspect first: `Bracketer/ModernContentView.swift`, `Bracketer/ContextualControls.swift`, and `Bracketer/CameraZoomControl.swift`.
- Recommended first command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' \
  -only-testing:BracketerUITests/BracketerUITests/testCameraChromeExposesPortraitAndLandscapeContracts \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

### Goal status

- Goal still open, Wave D camera chrome contract slice complete, next slice ready.

## 2026-05-11 01:10 PDT - Wave D chrome cleanup and overlap proof

### What changed

- Removed unused legacy camera chrome implementations from `ModernContentView.swift`:
  - `ModernTopBar`
  - `ModernBottomControls`
  - `ModernFlashButton`
  - `ModernTimerButton`
  - `ModernShutterButton`
  - `ModernBottomControlsEnhanced`
- Confirmed the live camera surface still routes through `ModernTopBarEnhanced` and `ContextualBottomControls`.
- Strengthened `testCameraChromeExposesPortraitAndLandscapeContracts` with frame-level UI assertions for the forced portrait and landscape branches.
- Added reusable UI-test helpers that verify:
  - Chrome controls have positive-size frames inside the screen bounds.
  - Secondary controls do not overlap each other.
  - Primary controls do not overlap each other.
  - Top pro controls and shooting mode controls do not overlap.
  - Top chrome sits above secondary controls, secondary controls sit above primary controls, and primary controls sit above zoom controls.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T08-02-15-467Z_pid14786_6bf985f5.log`
- Passed targeted camera chrome UI contract:
  - `testCameraChromeExposesPortraitAndLandscapeContracts`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-02-23-005Z_pid14786_d3f5019a.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 27 passed, 0 failed
  - Device/configuration runs: 30 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-04-23-214Z_pid14786_f4a5ac61.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no remaining references to the removed legacy chrome symbols:
  - `ModernTopBar`
  - `ModernBottomControls`
  - `ModernFlashButton`
  - `ModernTimerButton`
  - `ModernShutterButton`
  - `ModernBottomControlsEnhanced`

### Failures encountered and resolved

- The XcodeBuildMCP full-suite wrapper timed out after 120 seconds, but the underlying `xcodebuild` process continued and completed successfully. The result was verified directly from the `.xcresult` bundle.
- The final test reports still include the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two UI tests.

### Next slice

- Continue Wave D with visual/screenshot regression evidence for the camera surface, or move into Wave E review intelligence if layout risk is acceptable.
- The most valuable remaining Wave D target is to add screenshot-based artifact capture around portrait and landscape camera chrome so the frame assertions have human-reviewable evidence.

### Goal status

- Goal still open, Wave D cleanup and overlap-proof slice complete, next slice ready.

## 2026-05-11 01:33 PDT - Wave E deterministic review sequence intelligence

### What changed

- Added `BracketReviewSequence`, a pure review model for bracket sequence review state.
- Added review summary types for:
  - Selected processed/RAW representation state.
  - Per-shot capture state.
  - Metadata availability.
  - Closest-to-zero best-exposure candidate.
  - Simulator-labeled highlight/shadow clipping risk.
  - Selected-index clamping, previous/next navigation, and deterministic deletion.
- Reworked `SimulatedBracketReviewView` to consume the review sequence model instead of directly listing `BracketPlan` shots.
- The simulated review now exposes stable UI-test identifiers for sequence count, timestamp, selected EV, file type, capture state, metadata state, representation state, best-exposure marker, clipping warning, metadata panel, sequence rows, and delete confirmation.
- Updated the simulated bracket UI test to verify:
  - Review count and deterministic timestamp.
  - Selected-shot navigation from underexposed through center and overexposed frames.
  - Best-exposure badge.
  - Simulator-labeled clipping warning.
  - Processed-to-RAW toggle truthfully reporting `RAW unavailable`.
  - Metadata panel visibility.
  - Delete confirmation and post-delete count clamping.
- Documented the review sequence contract in `README.md`.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T08-17-26-441Z_pid14786_92dd0164.log`
- Passed targeted unit-model tests:
  - `BracketerTests/BracketerTests`: 25 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-17-50-929Z_pid14786_cff66355.xcresult`
- Passed targeted simulated review UI flow:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-18-52-640Z_pid14786_58f37940.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 32 passed, 0 failed
  - Device/configuration runs: 35 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-22-59-829Z_pid14786_b711db34.xcresult`
- Passed build-settings inspection through XcodeBuildMCP:
  - Project: `/Users/m3-max/Documents/GitHub/Bracketer/Bracketer.xcodeproj`
  - Scheme: `Bracketer`
  - `DEVELOPER_DIR`: `/Applications/Xcode.app/Contents/Developer`
  - `PRODUCT_BUNDLE_IDENTIFIER`: `com.rishabh.Bracketer`
  - `TARGETED_DEVICE_FAMILY`: `1`
  - `IPHONEOS_DEPLOYMENT_TARGET`: `26.2`
- Captured a simulator screenshot of the simulated review flow:
  - `/var/folders/jz/jvg201nn26v_zm12skhjjgkr0000gn/T/screenshot_optimized_e2bb0dfa-f671-4bb1-9b73-e6e7db48cf59.jpg`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- XcodeBuildMCP timed out on long targeted UI, full-suite, and build-run wrapper calls, but the underlying simulator/app processes continued. Test results were verified from their `.xcresult` bundles.
- The app launch wrapper timed out while the simulator was booting, but the app launched with the simulated-camera arguments and accepted accessibility-id taps for the review screenshot path.
- The build still reports existing `OrientationManager` main-actor warnings.
- The full test result still includes the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two UI tests.

### Next slice

- Continue Wave E by connecting the same `BracketReviewSequence` contract to the real Photos-backed `ImageViewer` path so live captures stop relying on positional EV guesses.
- First files to inspect next: `Bracketer/ImageViewer.swift`, `Bracketer/CameraController.swift`, and `Bracketer/BracketReviewSequence.swift`.
- Recommended first target: replace `ImageViewer.evLabelForCurrentIndex()` with sequence metadata derived from the active `BracketPlan` and saved asset identifiers.

### Goal status

- Goal still open, Wave E deterministic review sequence slice complete, next slice ready.

## 2026-05-11 01:44 PDT - Wave E Photos-backed review sequence wiring

### What changed

- Added `CameraController.lastBracketReviewSequence` so completed live captures preserve their bracket review contract alongside fetched `PHAsset`s.
- `finishSequence` now carries the active `BracketPlan`, capture timestamp, and file-type summary into `fetchBracketAssets`.
- `fetchBracketAssets` now builds a `BracketReviewSequence` from the saved asset order for Photos-backed review.
- `ModernContentView` passes the live review sequence into `ImageViewer`.
- `ImageViewer` now consumes `BracketReviewSequence` for selected EV labels, selection sync, representation accessibility state, and post-delete sequence clamping.
- The old positional EV mapping in `ImageViewer.evLabelForCurrentIndex()` is now only a fallback for a standalone recent asset opened without a bracket review sequence.
- Updated `README.md` to document that the Photos-backed viewer uses the same review sequence contract as the simulated harness.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T08-36-21-028Z_pid14786_dd1aca05.log`
- Passed targeted unit-model tests:
  - `BracketerTests/BracketerTests`: 25 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-36-32-804Z_pid14786_1e5c9efe.xcresult`
- Passed targeted simulated review UI flow:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-37-22-681Z_pid14786_3f1d4922.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 32 passed, 0 failed
  - Device/configuration runs: 35 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-39-47-161Z_pid14786_df98cc1c.xcresult`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- XcodeBuildMCP timed out on long UI/full-suite wrappers again, but the underlying `xcodebuild` process completed and the `.xcresult` bundles passed.
- This slice was not physically verified on an iPhone camera. The proof is simulator build/test plus model wiring; real camera capture remains a separate device-only verification category.
- The full test result still includes the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two UI tests.

### Next slice

- Continue Wave E by enriching real review metadata summaries after `ImageViewer.loadMetadata(for:)` succeeds, so selected shots can report actual EXIF availability and file/resource information instead of only the pre-review planned state.
- First files to inspect next: `Bracketer/ImageViewer.swift`, `Bracketer/EXIFViewer.swift`, and `Bracketer/BracketReviewSequence.swift`.

### Goal status

- Goal still open, Wave E Photos-backed review sequence wiring complete, next slice ready.

## 2026-05-11 01:56 PDT - Wave E live review resource and metadata enrichment

### What changed

- Added pure review summary types:
  - `BracketReviewResourceSummary`
  - `BracketReviewMetadataSummary`
- Added `BracketReviewSequence` update methods for loaded resource summaries and loaded metadata availability.
- `ImageViewer` now refreshes the selected shot summary from real `PHAssetResource` data when an asset is loaded.
- `ImageViewer` now updates the selected shot summary after full-size image metadata is decoded from `CIImage.properties`.
- Added a compact live review status strip with stable identifiers:
  - `review.live.position`
  - `review.live.fileType`
  - `review.live.metadataStatus`
- Updated `README.md` to document that the Photos-backed viewer enriches the review sequence as resources and EXIF properties load.
- Added pure tests for resource-summary updates, metadata-summary updates, RAW availability, and invalid-index no-ops.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T08-49-32-298Z_pid14786_c2c25ea2.log`
- Passed targeted unit-model tests:
  - `BracketerTests/BracketerTests`: 27 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-49-57-739Z_pid14786_6bb008b0.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 34 passed, 0 failed
  - Device/configuration runs: 37 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T08-51-07-296Z_pid14786_4f3084d4.xcresult`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- XcodeBuildMCP timed out on the long full-suite wrapper, but the underlying `xcodebuild` process completed and the `.xcresult` bundle passed.
- The simulator did not provide a real Photos-backed bracket asset for visual UI proof of `ImageViewer`; this slice is verified by compile, pure sequence tests, and full regression tests, not by physical camera/Photos metadata proof.
- The build still reports existing `OrientationManager` main-actor warnings.
- The full test result still includes the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two UI tests.

### Next slice

- Continue Wave E by making the Photos-backed review UI testable without a real Photos library asset, likely via a deterministic app-only image review fixture that exercises `ImageViewer` with the same `BracketReviewSequence` contract.
- First files to inspect next: `Bracketer/ImageViewer.swift`, `Bracketer/SimulatedBracketReview.swift`, and `BracketerUITests/BracketerUITests.swift`.

### Goal status

- Goal still open, Wave E live review resource and metadata enrichment complete, next slice ready.

## 2026-05-11 02:20 PDT - Wave E deterministic live review fixture

### What changed

- Refactored the Photos-backed overlay controls into a reusable `BracketLiveReviewChrome`.
- Added stable live review accessibility identifiers for close, previous/next, selected EV, position, file type, metadata state, metadata toggle, RAW/processed toggle, share, and delete controls.
- Added `DeterministicImageReviewFixtureView`, gated by `-ui-testing-review-fixture`, so UI tests can exercise the live review chrome and `BracketReviewSequence` contract without a real Photos asset.
- Wired the fixture into `ModernContentView` as an app-only UI-test overlay.
- Added UI coverage for navigation, selected EV, RAW/processed state, metadata detail, clipping summary, and delete clamping.
- Updated `README.md` with the new review fixture launch argument and `review.live.*` identifier contract.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T09-02-54-015Z_pid14786_153f0279.log`
- Passed simulator rebuild after the metadata-panel identifier fix:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T09-06-03-363Z_pid14786_121a2fd5.log`
- Passed targeted deterministic live review UI test:
  - `testDeterministicImageReviewFixtureExposesLiveChromeContract`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-06-14-009Z_pid14786_f4cb623c.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 35 passed, 0 failed
  - Device/configuration runs: 38 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-13-59-032Z_pid14786_6f9d5af6.xcresult`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- First targeted UI run failed because assigning `review.live.metadataPanel` to the visible SwiftUI metadata stack propagated that identifier to its children and hid `review.live.metadataDetail` from XCTest.
- Fixed by adding a separate hidden `ReviewFixtureProbe` for the panel marker while leaving the visible metadata labels with their own identifiers.
- XcodeBuildMCP timed out on the long targeted/full-suite wrappers, but the underlying `xcodebuild` processes completed and the `.xcresult` bundles passed.
- This remains simulator proof. No physical iPhone camera/Photos-library capture was verified in this slice.
- The full test result still includes the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two camera chrome UI tests.

### Next slice

- Move into Wave F by adding a pure histogram/clipping analysis processor with deterministic fixture tests, then route the simulated review warning copy through real analysis-shaped outputs instead of static labels.
- First files to inspect next: `plans_Bracketer.md`, `Bracketer/BracketReviewSequence.swift`, `Bracketer/SimulatedBracketReview.swift`, and `BracketerTests/BracketerTests.swift`.

### Goal status

- Goal still open, Wave E deterministic live review fixture complete, next slice ready.

## 2026-05-11 02:33 PDT - Wave F pure histogram and clipping analysis core

### What changed

- Added a pure `HistogramFrameAnalyzer` that accepts deterministic RGBA fixtures and live camera BGRA buffers.
- Added shared exposure analysis models:
  - `ExposureZebraThresholds`
  - `ExposureZebraClassification`
  - `ExposureClippingThresholds`
  - `ExposureClippingMetrics`
  - `HistogramFrameAnalysis`
- `HistogramProcessor` now delegates sample-buffer binning to the pure analyzer and publishes the latest frame analysis alongside `histogramData`.
- `EXIFViewer` now uses the same analyzer for still-image mini histograms instead of maintaining duplicate histogram code.
- `HistogramData` now carries optional clipping metrics so existing histogram UI exposure indicators can use sampled highlight/shadow fractions.
- Added deterministic unit coverage for normalized bins, clipping fractions, BGRA row-stride handling, and zebra threshold classification.
- Updated `README.md` to document the shared histogram/exposure-analysis contract and the remaining Wave F boundary.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T09-23-37-522Z_pid14786_537c130d.log`
- Targeted method-level Swift Testing selector did not bind and ran 0 tests:
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-23-50-988Z_pid14786_490e1eb1.xcresult`
  - Followed by rerunning the full unit bundle instead.
- Passed unit bundle:
  - `BracketerTests`: 30 passed, 0 failed
  - Includes `histogramFrameAnalyzerBuildsDeterministicBinsAndClippingMetrics`, `histogramFrameAnalyzerReadsBGRAPixelBuffersAndRowStride`, and `zebraThresholdsClassifyShadowHighlightAndNormalPixels`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-24-59-567Z_pid14786_70bd6357.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 38 passed, 0 failed
  - Device/configuration runs: 41 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-26-14-473Z_pid14786_3a9082e1.xcresult`
- Passed:
  - `git diff --check`

### Failures encountered and resolved

- Method-level `-only-testing` for Swift Testing functions produced a successful command with 0 executed tests, so it was treated as non-evidence and replaced with target-level unit-bundle verification.
- XcodeBuildMCP timed out on the long full-suite wrapper again, but the underlying `xcodebuild` process completed and the `.xcresult` bundle passed.
- The full test result still includes the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two camera chrome UI tests.

### Next slice

- Continue Wave F by surfacing the histogram overlay through a real app control or deterministic UI-test launch argument, then add a first real analysis-backed zebra overlay path.
- First files to inspect next: `Bracketer/ModernContentView.swift`, `Bracketer/PreviewContainer.swift`, `Bracketer/ModernProControls.swift`, and `Bracketer/HistogramProcessor.swift`.

### Goal status

- Goal still open, Wave F pure histogram and clipping analysis core complete, next slice ready.

## 2026-05-11 02:47 PDT - Wave F histogram surfacing and UI contract

### What changed

- Added `-ui-testing-show-histogram` so UI tests can start with the live histogram overlay visible without depending on camera frames.
- Threaded `showHistogram` from `ModernContentView` into `ModernCameraPreview` and `PreviewContainer` instead of hardcoding the histogram overlay off.
- Added a real Pro Controls exposure toggle for the histogram overlay:
  - `pro.histogramToggle`
  - Accessibility value reports the on/off state.
- Added an accessibility probe to `HistogramOverlay`:
  - `camera.histogramOverlay`
  - Accessibility value reports the active histogram mode title.
- Added a deterministic UI test that launches with the histogram visible, confirms the overlay contract, opens Pro Controls, toggles the histogram off, and verifies the overlay disappears.
- Updated `README.md` with the histogram launch argument and accessibility identifiers.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T09-36-24-838Z_pid14786_ba5ce4ba.log`
- Passed targeted histogram overlay UI test:
  - `testHistogramOverlayLaunchArgumentAndProToggleExposeState`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-36-34-419Z_pid14786_34a90c1d.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 39 passed, 0 failed
  - Device/configuration runs: 42 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-38-53-938Z_pid14786_7acc9173.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- XcodeBuildMCP timed out on the long full-suite wrapper again, but the underlying `xcodebuild` process completed and the `.xcresult` bundle passed.
- The full test result still includes the existing non-fatal SwiftUI `_UIReparentingView` runtime warning in two camera chrome UI tests.
- This slice verifies histogram surfacing and toggle behavior. It does not yet add per-pixel zebra masks or focus peaking.

### Next slice

- Continue Wave F with the first real analysis-backed zebra overlay path or focus peaking edge-analysis core.
- First files to inspect next: `plans_Bracketer.md`, `Bracketer/PreviewContainer.swift`, `Bracketer/HistogramProcessor.swift`, `Bracketer/ModernProControls.swift`, and `BracketerTests/BracketerTests.swift`.

### Goal status

- Goal still open, Wave F histogram surfacing complete, next slice ready.

## 2026-05-11 03:06 PDT - Wave F analysis-backed zebra overlay

### What changed

- Extended `HistogramFrameAnalyzer` from aggregate clipping counts into a compact tile-based zebra map:
  - `ExposureZebraRegion`
  - `ExposureZebraMap`
  - `HistogramFrameAnalysis.zebraMap`
- The live analyzer now builds normalized histogram bins, clipping fractions, and highlight/shadow zebra regions from the same sampled BGRA camera frames.
- Added a `ZebraOverlay` to `PreviewContainer` that draws highlight and shadow stripe regions from `HistogramFrameAnalysis` instead of decorative fixed positions.
- Added `showZebras` preview plumbing through `ModernContentView`, `ModernCameraPreview`, and `PreviewContainer`.
- Added a Pro Controls exposure switch for the zebra overlay:
  - `pro.zebraToggle`
- Added a deterministic UI-test launch fixture:
  - `-ui-testing-show-zebras`
  - `camera.zebraOverlay`
  - The fixture reports `Highlights 25%, Shadows 25%, Regions 8`.
- Made `ModernCameraPreview` observe `HistogramProcessor` directly so live histogram and zebra overlays can react to new analysis frames.
- Added unit coverage for tile-derived zebra regions and UI coverage for the zebra launch argument and Pro Controls toggle.
- Updated `README.md` with the zebra launch argument, accessibility identifiers, and the current histogram/zebra analysis contract.

### Verification

- First simulator build failed:
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T09-52-05-720Z_pid14786_e7528c83.log`
  - Cause: deterministic RGBA fixture construction in `ModernContentView` used the wrong `flatMap` overload for tuple pixels.
  - Fix: changed fixture construction to explicit `[UInt8]` appends.
- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T09-52-32-517Z_pid14786_e68cca09.log`
- Passed unit bundle:
  - `BracketerTests`: 31 passed, 0 failed
  - Includes `histogramFrameAnalyzerBuildsZebraRegionsFromClippingTiles`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-53-08-868Z_pid14786_60de48d5.xcresult`
- Passed targeted zebra overlay UI test:
  - `testZebraOverlayLaunchArgumentAndProToggleExposeAnalysisState`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-54-09-674Z_pid14786_fc55d086.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 41 passed, 0 failed
  - Device/configuration runs: 44 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T09-57-10-601Z_pid14786_6c567cb5.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- The initial build failure was from the deterministic fixture byte builder, not the production analyzer.
- XcodeBuildMCP timed out on the targeted UI and full-suite wrappers, but the underlying `xcodebuild` processes completed and the `.xcresult` bundles passed.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- The passing build still reports the existing `OrientationManager` main-actor warnings.
- The full-suite summary flagged one long camera chrome UI test as an outlier.
- This remains simulator proof. No physical iPhone camera feed was verified in this slice.

### Next slice

- Continue Wave F by replacing the decorative focus peaking overlay with a real edge-analysis core plus a deterministic simulator fallback.
- First files to inspect next: `Bracketer/PreviewContainer.swift`, `Bracketer/HistogramProcessor.swift`, `Bracketer/ModernSettingsPanel.swift`, `Bracketer/ModernProControls.swift`, and `BracketerTests/BracketerTests.swift`.

### Goal status

- Goal still open, Wave F analysis-backed zebra overlay complete, next slice ready.

## 2026-05-11 03:19 PDT - Wave F analysis-backed focus peaking

### What changed

- Extended `HistogramFrameAnalyzer` again so the shared frame analysis now includes sampled luminance-edge focus data:
  - `FocusPeakingThresholds`
  - `FocusPeakingRegion`
  - `FocusPeakingMap`
  - `HistogramFrameAnalysis.focusPeakingMap`
- Focus peaking detection now compares sampled luminance against neighboring sampled pixels and emits compact tile regions instead of relying only on fixed decorative dots.
- `FocusPeakingOverlay` now renders real analysis regions when frame analysis is available.
- Kept a clearly separated deterministic fallback overlay for simulator/no-frame states.
- Added a stable focus peaking overlay probe:
  - `camera.focusPeakingOverlay`
- Added a Pro Controls focus switch contract:
  - `pro.focusPeakingToggle`
- Added a deterministic UI-test launch fixture:
  - `-ui-testing-show-focus-peaking`
  - The fixture reports `Analysis regions 15`.
- Added unit coverage for edge-derived focus peaking regions and flat frames that should not peak.
- Updated `README.md` with the focus launch argument, accessibility identifiers, and the current histogram/zebra/focus analysis contract.

### Verification

- Passed simulator build:
  - Result: succeeded, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T10-09-29-562Z_pid14786_13ee5809.log`
- Passed unit bundle:
  - `BracketerTests`: 33 passed, 0 failed
  - Includes `histogramFrameAnalyzerBuildsFocusPeakingRegionsFromEdges` and `histogramFrameAnalyzerDoesNotPeakFlatFrames`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-09-42-271Z_pid14786_e9485d86.xcresult`
- Passed targeted focus peaking UI test:
  - `testFocusPeakingLaunchArgumentAndProToggleExposeAnalysisState`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-10-30-241Z_pid14786_8da5b4ee.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 44 passed, 0 failed
  - Device/configuration runs: 47 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-12-22-200Z_pid14786_1b064c82.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- No compile or test failures in this slice.
- XcodeBuildMCP timed out on the long full-suite wrapper, but the underlying `xcodebuild` process completed and the `.xcresult` bundle passed.
- Xcode emitted the recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- This remains simulator proof. No physical iPhone camera feed was verified in this slice.

### Next slice

- Wave F is now materially real for histogram, clipping/zebra, and focus peaking. Next highest-leverage options:
  - Add a false-color exposure view if it stays compact.
  - Move to Wave G and model device/permission capability states.
  - Add observability around histogram/focus processing cost before more live-analysis features.
- First files to inspect next: `plans_Bracketer.md`, `Bracketer/DeviceGating.swift` if present, `Bracketer/CameraController.swift`, `Bracketer/HistogramProcessor.swift`, and `BracketerTests/BracketerTests.swift`.

### Goal status

- Goal still open, Wave F analysis-backed focus peaking complete, next slice ready.

## 2026-05-11 03:34 PDT - Wave G device capability contract

### What changed

- Turned the existing `DeviceGating` surface into a first-class, testable capability contract instead of a mostly hardware-probing singleton.
- Added pure capability models:
  - `DevicePermissionState`
  - `DeviceCapabilityIssue`
  - `DeviceCapabilityInputs`
  - `DeviceCapabilitySnapshot`
- `DeviceCapabilitySnapshot` now resolves:
  - iOS version support
  - back camera and wide lens availability
  - ultra-wide and telephoto lens availability
  - flash availability
  - ProRAW support
  - Photos add authorization
  - location authorization
  - notification authorization
  - storage preflight
  - Low Power Mode
- Each issue carries a blocker/warning severity plus an exact action path, such as:
  - `Settings > Privacy & Security > Photos > Bracketer > Add Photos Only`
- Wired `BracketerApp` through `DeviceCompatibilityView` so the gate is now in the real launch path.
- Added deterministic UI-test capability fakes:
  - `-ui-testing-device-capabilities-photos-denied`
  - `-ui-testing-device-capabilities-no-camera`
- Added stable compatibility UI identifiers:
  - `deviceCompatibility.title`
  - `deviceCompatibility.status`
  - `deviceCompatibility.message`
  - `deviceCompatibility.primaryAction`
  - `deviceCompatibility.issue.<id>.action`
- Kept normal simulator tests deterministic by treating simulator hardware and permissions as available unless a device-capability fake is explicitly requested.
- Added unit tests for:
  - full hardware without blockers
  - denied Photos and low storage blockers with exact action paths
  - recoverable warning states that should not block launch
- Added a UI test for denied Photos add access that proves the exact recovery action appears and the camera shutter is not shown.
- Updated `README.md` with the new launch arguments, identifiers, and capability contract.

### Verification

- First simulator build passed with warnings:
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T10-24-12-977Z_pid14786_1a53ce2d.log`
  - Warnings came from simulator-only ternary branches that Swift correctly identified as unreachable.
- Clean simulator build passed after warning cleanup:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T10-24-36-728Z_pid14786_9a2a6947.log`
- Passed unit bundle:
  - `BracketerTests`: 36 passed, 0 failed
  - Includes `deviceCapabilitySnapshotResolvesFullHardwareWithoutBlockers`, `deviceCapabilitySnapshotBlocksDeniedPhotosAndLowStorageWithActionPaths`, and `deviceCapabilitySnapshotKeepsRecoverableWarningsOutOfBlockers`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-24-44-763Z_pid14786_2abcd9ee.xcresult`
- Passed targeted device-capability UI test:
  - `testDeviceCapabilitiesPhotosDeniedShowsExactRecoveryPath`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-25-33-106Z_pid14786_4a4be7a9.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 48 passed, 0 failed
  - Device/configuration runs: 51 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-26-40-913Z_pid14786_a807944a.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- No test failures in this slice.
- The initial clean-build issue was warnings-only; fixed by separating simulator permission values with `#if targetEnvironment(simulator)`.
- XcodeBuildMCP timed out on the long full-suite wrapper, but the underlying `xcodebuild` process completed and the `.xcresult` bundle passed.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- The full-suite summary flagged one long camera chrome UI test as an outlier.
- This remains simulator proof. Real denied-permission behavior on a physical device was not verified.

### Next slice

- Continue Wave G by making runtime camera/session permission failures route through the same `DeviceCapabilityIssue` action-path language instead of ad hoc `CamError` strings.
- First files to inspect next: `Bracketer/CameraController.swift`, `Bracketer/DeviceGating.swift`, `Bracketer/ModernContentView.swift`, and `BracketerUITests/BracketerUITests.swift`.

### Goal status

- Goal still open, Wave G device capability contract complete, next slice ready.

## 2026-05-11 03:46 PDT - Wave G runtime recovery paths

### What changed

- Shared the device capability recovery language with the live camera runtime path instead of leaving startup and capture failures as ad hoc strings.
- Added `DeviceCapabilityIssue` factories for:
  - camera permission denial
  - camera unavailable
  - camera input/session failure
  - Photos add access denied/pending/unknown
  - low or unknown storage
- Updated `DeviceCapabilitySnapshot` to use the same shared issue factories for camera availability, Photos add access, and storage.
- Extended `CamError` with:
  - alert title
  - optional `DeviceCapabilityIssue`
  - optional exact action path
  - alert copy that appends `Action: <path>` when recovery guidance exists
- Routed runtime failures through capability-backed errors for:
  - denied camera permission
  - denied Photos add permission
  - unavailable back camera
  - camera input/session construction failure
  - low storage before bracket capture
- Updated the main camera alert to show the issue title and exact recovery action path.
- Added unit tests proving runtime failures share `DeviceCapabilityIssue` action paths and render the recovery action in alert copy.
- Updated `README.md` so the Wave G contract covers runtime alerts as well as launch gating.

### Verification

- Clean simulator build passed:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T10-38-40-909Z_pid14786_7eff37ec.log`
- Passed unit bundle:
  - `BracketerTests`: 38 passed, 0 failed
  - Includes `cameraRuntimeFailuresShareDeviceCapabilityActionPaths` and `cameraRuntimeErrorsRenderActionPathInAlertCopy`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-38-53-385Z_pid14786_2f99b1a1.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 50 passed, 0 failed
  - Device/configuration runs: 53 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-39-57-636Z_pid14786_b5cb0ae0.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- The XcodeBuildMCP full-suite wrapper timed out after 120 seconds, but the underlying `xcodebuild` process continued and completed successfully.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- The full-suite summary flagged one camera chrome UI test as an outlier at about 124 seconds.
- This remains simulator proof. Physical-device denied-permission behavior was not verified.

### Next slice

- Continue Wave G by adding deeper runtime observability around camera/session failures and exposing enough state to diagnose physical-device startup issues without relying on simulator-only fakes.

### Goal status

- Goal still open, Wave G runtime recovery paths complete, next slice ready.

## 2026-05-11 04:02 PDT - Wave G/H runtime diagnostics contract

### What changed

- Added a pure rolling `CameraRuntimeDiagnostics` contract with deterministic `CameraRuntimeDiagnosticEvent` entries.
- Each diagnostic records:
  - category
  - severity
  - title
  - detail
  - optional action path
  - timestamp
- Added diagnostic categories for startup, permissions, session, lens, planning, capture, storage, and recovery.
- Wired `CameraController` to record diagnostics for:
  - camera startup
  - permission success/failure
  - session configuration and running/stopped state
  - lens input readiness
  - bracket planning
  - simulated and live bracket capture start
  - terminal capture completion/cancellation/timeout/failure
  - capability-backed error recovery paths
- Kept diagnostics hidden from normal UI but exposed stable accessibility probes:
  - `camera.diagnostics.summary`
  - `camera.diagnostics.latest`
- Added unit tests for diagnostic trimming, summaries, and capability-issue action-path recording.
- Extended the stable camera-screen UI test to assert the diagnostics probes start empty when startup side effects are disabled.
- Updated `README.md` with the diagnostics probe contract.

### Verification

- Clean simulator build passed:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T10-51-59-992Z_pid14786_f201388e.log`
- Passed unit bundle:
  - `BracketerTests`: 40 passed, 0 failed
  - Includes `cameraRuntimeDiagnosticsSummarizeLatestEventAndTrimOldEntries` and `cameraRuntimeDiagnosticsRecordCapabilityIssueActionPath`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-52-12-924Z_pid14786_156ad1c7.xcresult`
- Passed targeted diagnostics UI test:
  - `testCameraScreenLaunchesWithStableControls`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-52-55-564Z_pid14786_bd0c969e.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 52 passed, 0 failed
  - Device/configuration runs: 55 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T10-55-36-188Z_pid14786_35fa8bb2.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- The targeted UI and full-suite XcodeBuildMCP wrappers both timed out after 120 seconds. The underlying `xcodebuild` processes continued and both `.xcresult` bundles passed.
- The targeted diagnostics UI test took about 101 seconds in this simulator run.
- The full-suite summary flagged one camera chrome UI test as an outlier at about 177 seconds.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- This remains simulator proof. Physical-device camera startup diagnostics were not verified on a real iPhone.

### Next slice

- Move into Wave H by adding timing instrumentation around startup/session configuration and the simulated capture path, then use the diagnostics/event surface to report slow phases instead of only pass/fail state.

### Goal status

- Goal still open, Wave G/H runtime diagnostics contract complete, next slice ready.

## 2026-05-11 04:22 PDT - Wave H timed diagnostics and simulated capture proof

### What changed

- Extended `CameraRuntimeDiagnosticEvent` with optional `durationMilliseconds`.
- Diagnostics accessibility copy now appends timing evidence as:
  - `Duration: <milliseconds> ms`
- Added timing measurements for:
  - permission resolution inside startup
  - full camera startup completion
  - session configuration
  - live bracket capture terminal states
  - simulated bracket capture terminal states
- Added a compact elapsed-time helper backed by `CACurrentMediaTime()`.
- Made the deterministic simulated shutter path open the simulated review after capture completion.
- Updated `testSimulatedBracketCaptureCompletesAndOpensReview` so it now taps the shutter and proves the capture path, rather than using the photo-library shortcut.
- Added a unit test for timed diagnostic accessibility copy.
- Updated `README.md` with the timed diagnostics contract and the real simulated shutter behavior.

### Verification

- Clean simulator build passed after the timing model:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T11-07-07-715Z_pid14786_1bbe53e1.log`
- Clean simulator build passed after the simulated-review presentation fix:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T11-12-46-192Z_pid14786_e67e930b.log`
- Passed unit bundle:
  - `BracketerTests`: 41 passed, 0 failed
  - Includes `cameraRuntimeDiagnosticsIncludeTimingInAccessibilityCopy`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T11-07-18-532Z_pid14786_c6704506.xcresult`
- Passed targeted simulated-capture UI test after fix:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T11-13-00-465Z_pid14786_08dd44d7.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 53 passed, 0 failed
  - Device/configuration runs: 56 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T11-15-58-563Z_pid14786_1be1d72a.xcresult`
- Passed:
  - `git diff --check`
- Confirmed no matching `xcodebuild ... Bracketer.xcodeproj ... test` process remained after the full gate.

### Failures encountered and resolved

- First targeted simulated-capture UI run failed:
  - `BracketerUITests.swift:337: XCTAssertTrue failed`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T11-08-02-918Z_pid14786_728d266b.xcresult`
- Root cause: the deterministic simulated capture path completed state but did not present review; the prior test avoided that by opening the photo-library shortcut.
- Fix: set `showImageViewer = true` when simulated capture completes, then reran the failing targeted test successfully.
- XcodeBuildMCP wrappers continued to hit the 120 second timeout, but the underlying `xcodebuild` result bundles were parsed directly.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- Full-suite summary still reports one long camera chrome outlier, now about 136 seconds.
- This remains simulator proof. Physical-device startup/session timings were not verified on a real iPhone.

### Next slice

- Continue Wave H by adding timing around Photos save, review image load, and histogram processing, then decide whether any timed phase should surface as a warning diagnostic when it crosses a practical threshold.

### Goal status

- Goal still open, Wave H timed diagnostics and simulated capture proof complete, next slice ready.

## 2026-05-11 05:35 PDT - Wave H Photos review and histogram timing diagnostics

### What changed

- Extended `CameraRuntimeDiagnosticEvent.Category` with timed categories for:
  - Photos
  - Review
  - Histogram
- Added `CameraRuntimePerformanceThresholds` so slow runtime phases can promote from info to warning diagnostics:
  - Photos save: 1,500 ms
  - review image load: 1,000 ms
  - review metadata load: 1,000 ms
  - histogram frame processing: 50 ms
- Added `PhotoSaveResult` so Photos writes report:
  - saved asset identifier
  - filename
  - save duration
  - success/failure state
- Updated `PhotoSaver` and `CameraController.handlePhotoSaved` so each saved or failed bracket shot records a timed Photos diagnostic.
- Added hidden Photos-backed review diagnostics in `ImageViewer`:
  - `review.diagnostics.summary`
  - `review.diagnostics.latest`
- Timed review image loading and review metadata loading, including missing/unavailable/decode-failed outcomes.
- Added `HistogramProcessor.processingDiagnostics` and timed every analyzed camera frame through `HistogramFrameAnalyzer`.
- Added hidden histogram diagnostics probes in the camera preview:
  - `camera.histogramDiagnostics.summary`
  - `camera.histogramDiagnostics.latest`
- Extended the histogram UI test to assert the histogram diagnostics probes start in the deterministic empty state.
- Updated `README.md` with the new diagnostics categories, warning thresholds, and probe identifiers.

### Verification

- Clean simulator build passed:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T11-26-52-218Z_pid14786_a2b1f708.log`
- Passed unit bundle:
  - `BracketerTests`: 44 passed, 0 failed
  - Includes:
    - `cameraRuntimePerformanceThresholdsPromoteSlowPhasesToWarnings`
    - `photoSaveResultReportsSuccessAndDurationForDiagnostics`
    - `cameraRuntimeDiagnosticsAcceptReviewPhotosAndHistogramTimingCategories`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-24-30-047Z_pid14786_e73e4cde.xcresult`
- Passed targeted histogram diagnostics UI test:
  - `testHistogramOverlayLaunchArgumentAndProToggleExposeState`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-25-34-850Z_pid14786_03f9a1bc.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 56 passed, 0 failed
  - Device/configuration runs: 59 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-28-29-689Z_pid14786_1c03a457.xcresult`

### Failures encountered and resolved

- The targeted histogram UI test and full-suite XcodeBuildMCP wrappers timed out after 120 seconds. The underlying `xcodebuild` processes completed, and their `.xcresult` bundles passed when parsed with `xcresulttool`.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- Full-suite summary still reports one long camera chrome outlier, about 136 seconds.
- This remains simulator proof. Physical-device Photos save timing, live review timing, and live camera histogram processing were not verified on a real iPhone.

### Next slice

- Continue Wave H by auditing whether the hidden diagnostics are enough or whether a debug-only export surface is useful, then run a plan-to-artifact audit for remaining Wave H work before moving on.

### Goal status

- Goal still open, Wave H Photos/review/histogram timing diagnostics complete, next slice ready.

## 2026-05-11 05:50 PDT - Wave H diagnostics export surface

### What changed

- Added a line-oriented diagnostics export report to `CameraRuntimeDiagnostics`.
- Each exported diagnostic event includes:
  - stable event id
  - ISO-8601 timestamp
  - severity
  - category
  - title
  - detail
  - optional action path
  - optional duration in milliseconds
- Added a hidden camera diagnostics export probe:
  - `camera.diagnostics.export`
- Added a debug-only Settings/About ShareLink backed by the same diagnostics report:
  - `settings.diagnostics.shareButton`
- Kept the report out of the normal camera surface; the main camera still exposes hidden probe values only.
- Added unit coverage for report formatting with timing and action-path data.
- Extended the stable camera-screen UI test to assert the empty diagnostics export report.
- Updated `README.md` with the export probe and debug ShareLink contract.

### Verification

- Clean simulator build passed:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T12-39-32-809Z_pid14786_d1e915c9.log`
- Passed unit bundle:
  - `BracketerTests`: 45 passed, 0 failed
  - Includes `cameraRuntimeDiagnosticsExportReportIncludesTimingAndActionPath`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-39-49-427Z_pid14786_988f2abc.xcresult`
- Passed targeted diagnostics UI test:
  - `testCameraScreenLaunchesWithStableControls`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-41-25-548Z_pid14786_ed0a5ff0.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 57 passed, 0 failed
  - Device/configuration runs: 60 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-43-40-653Z_pid14786_278c4a8b.xcresult`

### Failures encountered and resolved

- The full-suite XcodeBuildMCP wrapper timed out after 120 seconds. The underlying `xcodebuild` process completed, and its `.xcresult` bundle passed when parsed with `xcresulttool`.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- This remains simulator proof. Physical-device export-from-Settings share-sheet behavior was not manually exercised on a real iPhone.

### Next slice

- Complete a Wave H audit against `plans_Bracketer.md` and decide whether the remaining performance-trace item needs an actual ETTrace/Xcode trace artifact or whether existing launch-performance evidence is enough to move into Wave I.

### Goal status

- Goal still open, Wave H diagnostics export surface complete, next slice ready.

## 2026-05-11 06:01 PDT - Wave H performance trace audit

### What changed

- Audited the remaining Wave H performance-trace requirement against the current toolchain.
- Confirmed Apple `xctrace` is installed at `/usr/bin/xctrace`.
- Confirmed available Xcode templates include:
  - App Launch
  - Time Profiler
  - SwiftUI
  - System Trace
- Booted the default Bracketer simulator through XcodeBuildMCP:
  - `BracketerUITest-230901`
  - `3D6A76E2-86BE-4F15-A384-A920B56478EB`
- Installed the current built app bundle to that simulator for profiling setup:
  - `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/DerivedData/Bracketer-9396c4e8762c/Build/Products/Debug-iphonesimulator/Bracketer.app`
- Tried three focused `xctrace` captures:
  - App Launch, deterministic camera launch arguments
  - Time Profiler attached to the running Bracketer process
  - simulator-wide Time Profiler
- Rejected the generated `.trace` bundles as invalid evidence because they only contained `RunIssues.storedata`, stayed around 52 KB, and `xctrace export --toc` failed with:
  - `Document Missing Template Error`
- Used the valid XCTest launch-performance metric from the latest full gate as the trustworthy performance evidence for this slice.

### Verification

- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`) before the trace audit:
  - Result: passed
  - Logical tests: 57 passed, 0 failed
  - Device/configuration runs: 60 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-43-40-653Z_pid14786_278c4a8b.xcresult`
- Extracted XCTest performance metrics from that result bundle with:
  - `xcrun xcresulttool get test-results metrics --path /Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-43-40-653Z_pid14786_278c4a8b.xcresult --compact`
- Launch performance metric:
  - Test: `BracketerUITests/testLaunchPerformance()`
  - Metric: `Duration (AppLaunch)`
  - Unit: seconds
  - Measurements: `1.462401542`, `1.482843833`, `1.492383333`, `1.505484375`, `1.5586615830000001`

### Failures encountered and unresolved

- Apple `xctrace record` did not produce a valid trace bundle for the simulator app in this environment.
- The `--time-limit` value was accepted by `xctrace`, but each run had to be terminated after the requested window had already elapsed.
- Because the resulting bundles failed export, no `.trace` artifact should be treated as valid Wave H proof.
- ETTrace was considered, but it would require temporary framework linking into the app target. That is heavier than the current Wave H need and was not added to the project.
- This remains simulator proof. No physical-device Instruments trace was collected.

### Next slice

- Move into Wave I documentation and release discipline unless a future run specifically needs a real Instruments/ETTrace profile. The current Wave H code-level observability and XCTest launch metric are verified; the external trace artifact remains a tooling caveat, not completed evidence.

### Goal status

- Goal still open, Wave H performance trace audit complete with an unresolved `xctrace` artifact blocker, next slice ready.

## 2026-05-11 06:04 PDT - Wave I docs architecture and CI discipline

### What changed

- Added `docs/ARCHITECTURE.md` covering:
  - capture ownership
  - bracket planning
  - settings persistence
  - simulated and Photos-backed review
  - exposure analysis
  - device capabilities
  - runtime observability
  - simulator-vs-physical-device verification boundaries
- Updated `README.md` with a docs pointer and copy-pasteable commands for:
  - build-settings inspection
  - full simulator gate
  - simulator-UDID fallback gate
  - focused unit bundle
  - focused deterministic camera-screen UI check
  - extracting launch-performance metrics from an `.xcresult`
- Improved `.github/workflows/ios-ci.yml` so CI no longer assumes one simulator name string.
- CI now resolves an available `iPhone 17 Pro` or `iPhone 17` simulator UDID before testing.
- CI now uses the same stability flags as the local gate:
  - `-parallel-testing-enabled NO`
  - `-maximum-concurrent-test-simulator-destinations 1`
- Kept failure artifact upload for `build/Bracketer.xcresult`.

### Verification

- Parsed the GitHub Actions workflow with Ruby YAML:
  - Command: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ios-ci.yml"); puts "workflow yaml ok"'`
  - Result: `workflow yaml ok`
- Checked docs and workflow references with `rg`:
  - `docs/ARCHITECTURE.md`
  - `xcodebuild -project`
  - `xcresulttool get test-results metrics`
  - `-ui-testing-simulated-camera`
  - `settings.diagnostics.shareButton`
- Last full simulator gate from the prior code slice remains the current build/test proof:
  - Result: passed
  - Logical tests: 57 passed, 0 failed
  - Device/configuration runs: 60 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T12-43-40-653Z_pid14786_278c4a8b.xcresult`

### Caveats

- The CI workflow was syntax-checked locally, but it was not run on GitHub Actions in this slice.
- The workflow still depends on a GitHub macOS image that has a compatible Xcode/iOS simulator runtime. The resolver makes simulator naming more robust, but it cannot manufacture a missing runtime.
- This was docs/workflow work only after the last full gate, so no additional app build was needed for the markdown/YAML edits.

### Next slice

- Continue Wave I by checking whether a concise release/checklist note is needed, then move toward Wave J bracket manifest/export groundwork if the docs/CI surface is sufficiently covered.

### Goal status

- Goal still open, Wave I docs architecture and CI discipline slice complete, next slice ready.

## 2026-05-11 06:19 PDT - Wave J bracket manifest groundwork

### What changed

- Added `Bracketer/BracketManifest.swift`.
- Introduced `BracketManifestSource`:
  - `simulated`
  - `photos`
- Introduced `BracketManifest`, a JSON-ready bracket group snapshot for future HDR merge, exposure fusion, deghosting, sidecar metadata, and professional handoff workflows.
- Each manifest preserves:
  - schema version
  - group identifier
  - source
  - capture timestamp
  - resolved and requested plan details
  - shot EV offsets
  - display and filename labels
  - optional Photos asset identifiers
  - file type
  - capture state and detail
  - metadata status and detail
  - available RAW/processed representations
  - best-exposure marker
  - clipping-warning labels
- Added pretty/sorted JSON encoding helpers with ISO-8601 dates.
- Added `BracketReviewSequence.manifest(...)` so a review sequence can produce the export model with its matching plan.
- Added `SimulatedBracketReview.manifest`.
- Added `CameraController.lastBracketManifest`.
- Wired manifest production into:
  - deterministic simulated review preparation
  - completed simulated shutter captures
  - completed Photos-backed bracket fetches
- Updated `README.md` and `docs/ARCHITECTURE.md` with the manifest contract.

### Verification

- Clean simulator build passed:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T13-08-15-926Z_pid14786_0faecb0f.log`
- Passed unit bundle:
  - `BracketerTests`: 47 passed, 0 failed
  - Includes:
    - `simulatedBracketReviewBuildsManifestForExport`
    - `bracketManifestPreservesMissingShotsForPartialPhotoSequences`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T13-08-29-814Z_pid14786_880b9623.xcresult`
- Passed targeted simulated capture/review UI test:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T13-09-24-245Z_pid14786_75a6ec0d.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 59 passed, 0 failed
  - Device/configuration runs: 62 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T13-12-03-332Z_pid14786_c6940e5d.xcresult`

### Failures encountered and resolved

- The full-suite XcodeBuildMCP wrapper timed out after 120 seconds. The underlying `xcodebuild` process completed, and its `.xcresult` bundle passed when parsed with `xcresulttool`.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- Full-suite summary still reports one long camera chrome outlier, about 95 seconds.
- This remains simulator proof. No physical-device Photos-backed manifest was generated from a real camera capture.

### Next slice

- Continue Wave J by deciding whether to expose manifest export from review UI, then prototype a deterministic exposure-fusion preview only if it can stay pure and simulator-testable.

### Goal status

- Goal still open, Wave J bracket manifest groundwork complete, next slice ready.

## 2026-05-11 06:31 PDT - Wave J review manifest export controls

### What changed

- Added review-chrome manifest sharing as a separate JSON export path from photo sharing.
- Simulated review now exports the current in-memory `BracketReviewSequence` manifest through:
  - `review.sequence.manifestShareButton`
- Photos-backed live review now accepts `CameraController.lastBracketManifest` and exposes it through:
  - `review.live.manifestShareButton`
- The deterministic live review fixture now builds a manifest with group identifier `review-fixture`.
- `ModernContentView` passes `camera.lastBracketManifest` into `ImageViewer`.
- The manifest export buttons expose their JSON payloads as accessibility values so UI tests can verify the contract without opening a share sheet.
- Updated `README.md` and `docs/ARCHITECTURE.md` to clarify that manifest export is metadata/recipe export, separate from photo pixel sharing.

### Verification

- Clean simulator build passed:
  - Result: succeeded, 0 warnings, 0 errors
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-11T13-21-51-714Z_pid14786_f3c5f760.log`
- Passed targeted review UI tests:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`
  - `testDeterministicImageReviewFixtureExposesLiveChromeContract`
  - Result: 2 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T13-22-07-434Z_pid14786_7c69fa6d.xcresult`
- Passed full gate on simulator `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Result: passed
  - Logical tests: 59 passed, 0 failed
  - Device/configuration runs: 62 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-11T13-24-25-748Z_pid14786_3adc20e4.xcresult`

### Failures encountered and resolved

- The full-suite XcodeBuildMCP wrapper timed out after 120 seconds. The underlying `xcodebuild` process completed, and its `.xcresult` bundle passed when parsed with `xcresulttool`.
- Xcode emitted recurring non-fatal `DebuggerVersionStore.StoreError` launch-parameter warnings during UI tests.
- Full-suite summary still reports one long camera chrome outlier, about 106 seconds.
- This remains simulator proof. The share sheet was not manually exercised on a physical iPhone.

### Next slice

- Continue Wave J with a deterministic exposure-fusion preview prototype if it can remain pure and testable, otherwise narrow the next slice to sidecar naming/pairing rules.

### Goal status

- Goal still open, Wave J review manifest export controls complete, next slice ready.
