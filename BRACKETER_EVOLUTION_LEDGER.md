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

## 2026-05-15 22:14 PDT - Enormous plan and Apple Intelligence availability seam

### What changed

- Added `Enormousplans.md` as the giant goal-mode execution prompt for turning Bracketer into a much larger generative, Apple Intelligence-aware camera system.
- Verified the local Xcode stack can see the new Apple platforms needed for the plan:
  - Xcode 26.5 is active.
  - iOS 26.5 simulator runtime was installed after the first destination lookup showed the SDK/runtime mismatch.
  - Local SDKs expose `FoundationModels.framework`, `ImagePlayground.framework`, and `AppIntents.framework`.
- Added `Bracketer/IntelligenceAvailability.swift` as the first concrete Apple Intelligence contract:
  - Models available, user-disabled, SDK-unavailable, framework-unavailable, device-ineligible, Apple Intelligence-disabled, model-not-ready, locale-unsupported, simulator-unsupported, and unknown states.
  - Keeps simulator builds deterministic by reporting simulator generative features as unsupported unless a UI-test launch argument forces a fake state.
  - Preserves local blockers before physical-device Foundation Models queries.
- Threaded Apple Intelligence readiness into the app surface:
  - Hidden camera probe: `camera.intelligence.availability`.
  - Settings tab: `AI`.
  - Settings identifiers: `settings.intelligence.availability.title`, `settings.intelligence.availability`, and `settings.intelligence.recoveryAction`.
- Added deterministic UI-test launch arguments for forced intelligence availability states.
- Updated `README.md` and `docs/ARCHITECTURE.md` with the availability contract and test hooks.
- Added unit and UI coverage for the availability resolver, service overrides, simulator behavior, and settings/camera accessibility contract.

### Verification

- Passed whitespace check:
  - `git diff --check`
- Passed direct typechecks:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphonesimulator swiftc -typecheck Bracketer/IntelligenceAvailability.swift -target arm64-apple-ios26.2-simulator`
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphoneos swiftc -typecheck Bracketer/IntelligenceAvailability.swift -target arm64-apple-ios26.2`
- Passed clean simulator build:
  - Build log: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/logs/build_sim_2026-05-16T04-55-00-769Z_pid25691_71570c65.log`
- Passed focused unit bundle:
  - `BracketerTests`: 52 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-02-33-576Z_pid25691_63066fab.xcresult`
- Passed targeted Apple Intelligence UI contract:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-03-56-282Z_pid25691_fd7d1719.xcresult`
- Passed full simulator gate:
  - Swift Testing unit suite: 52 passed, 0 failed.
  - XCTest UI/launch suite: 16 passed, 0 failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-04-48-893Z_pid25691_bc12167c.xcresult`

### Failures encountered and resolved

- Initial simulator destination discovery failed because Xcode 26.5 was active while only older simulator runtimes were installed. Running the platform download installed iOS 26.5 runtime support and restored simulator destinations.
- The first targeted UI run outlived the XcodeBuildMCP 120-second wrapper, but the underlying `xcodebuild` process completed and passed.
- The full simulator gate also outlived the wrapper. The underlying `xcodebuild` run completed and passed after about 452 seconds.
- The first Apple Intelligence UI case in the full run had a slow simulator idle/probe lookup and took about 145 seconds, but it passed.
- Xcode still reports pre-existing actor-isolation warnings in `Bracketer/OrientationManager.swift:204`.
- This remains simulator proof. A physical Apple Intelligence-capable iPhone has not yet verified `SystemLanguageModel.default.availability`, Image Playground generation, App Intents, or real capture coaching.

### Next slice

- Continue from `Enormousplans.md` with a narrow, testable generative capture-context layer:
  - Define a pure `CaptureContextSummary` from bracket plan, device capability, histogram/zebra/focus signals, settings, and manifest state.
  - Feed that summary into future Foundation Models prompts without exposing raw photos by default.
  - Add deterministic unit tests before any user-visible generated copy.

### Goal status

- Goal still open. The enormous plan is saved, and the first Apple Intelligence availability slice is complete.

## 2026-05-15 22:20 PDT - Generative capture context summary

### What changed

- Added `Bracketer/CaptureContextSummary.swift` as the first structured prompt-input boundary for future Foundation Models work.
- The summary condenses:
  - Bracket plan and resolved EV labels.
  - Effective capture format, flash, timer, and location state.
  - Viewfinder/pro settings such as grid, level, focus peaking, histogram, and zebra overlays.
  - Optional `DeviceCapabilitySnapshot` readiness, lens, permission, storage, and issue data.
  - Optional `HistogramFrameAnalysis` shadow/highlight clipping, zebra regions, focus regions, and guidance signals.
  - Optional review/manifest state without Photos asset identifiers.
  - Apple Intelligence availability status and recovery action.
- Added an explicit privacy block: no raw photo bytes, no Photos asset identifiers, no precise location coordinates, and no user-visible generated copy.
- Added `compactPromptContext` as a deterministic line-based representation that future prompts can consume without reaching into camera objects.
- Documented the generative capture-context layer in `README.md` and `docs/ARCHITECTURE.md`.

### Verification

- Passed whitespace check:
  - `git diff --check`
- Passed focused unit bundle:
  - `BracketerTests`: 54 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-18-19-209Z_pid25691_ef72a7dd.xcresult`
- New focused coverage:
  - `captureContextSummaryBuildsPrivacySafePromptFacts`
  - `captureContextSummaryHandlesMissingOptionalRuntimeSignals`
- The earlier same-session full simulator gate still covers the app/UI surface before this pure model-only slice:
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-04-48-893Z_pid25691_bc12167c.xcresult`

### Failures encountered and resolved

- No failures in this slice.
- Xcode still reports pre-existing actor-isolation warnings in `Bracketer/OrientationManager.swift:204` during the unit bundle.
- This remains structured-state groundwork. No Foundation Models generation has been invoked yet, and no physical-device Apple Intelligence behavior has been verified.

### Next slice

- Add the first deterministic Foundation Models-facing request/response contract on top of `CaptureContextSummary`, with simulator fakes and no user-visible generated copy until output validation exists.

### Goal status

- Goal still open. The enormous plan, Apple Intelligence availability seam, and privacy-safe capture-context summary are complete.

## 2026-05-15 22:24 PDT - Deterministic capture coach contract

### What changed

- Added `Bracketer/CaptureCoachPrompt.swift` as the first model-facing contract above `CaptureContextSummary`.
- Added `CaptureCoachRequest`:
  - Bounded task enum for pre-capture guidance and review narrative.
  - Max suggestion cap normalized to `1...5`.
  - System instruction that requires the model to use only structured app context.
  - User prompt that embeds `CaptureContextSummary.compactPromptContext`.
- Added `CaptureCoachResponse` and `CaptureCoachSuggestion` as the validated response shape for future Foundation Models output.
- Added `CaptureCoachResponseValidator`:
  - Removes empty-title or empty-action suggestions.
  - Trims suggestions to the request cap.
  - Replaces stale task/status metadata with request-derived truth.
  - Allows `usedAppleIntelligence` only when the context availability is usable.
  - Regenerates the privacy disclosure from the context privacy block.
- Added `DeterministicCaptureCoach` as the simulator-safe fallback/regression oracle before real Foundation Models generation is wired in.
- Documented the prompt/response layer in `README.md` and `docs/ARCHITECTURE.md`.

### Verification

- Passed whitespace check:
  - `git diff --check`
- Passed focused unit bundle:
  - `BracketerTests`: 57 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-21-52-781Z_pid25691_f58e8453.xcresult`
- New focused coverage:
  - `captureCoachRequestBuildsPrivacyBoundedPrompt`
  - `deterministicCaptureCoachRespondsFromStructuredSignals`
  - `captureCoachValidatorFiltersAndTrimsModelOutput`

### Failures encountered and resolved

- No failures in this slice.
- This still does not call Foundation Models. It is intentionally the contract and deterministic fallback layer that real on-device generation must satisfy.

### Next slice

- Wire a UI-hidden capture coach probe or settings preview that uses `DeterministicCaptureCoach` in simulator and remains gated by `IntelligenceFeatureAvailability` on device.

### Goal status

- Goal still open. The enormous plan, Apple Intelligence availability seam, capture-context summary, and deterministic coach contract are complete.

## 2026-05-15 22:30 PDT - Hidden capture coach runtime probe

### What changed

- Wired `CaptureContextSummary` and `DeterministicCaptureCoach` into `ModernContentView` without adding visible generated UI.
- Added hidden camera probes:
  - `camera.captureContext.privacy`
  - `camera.captureCoach.firstSuggestion`
- The probes expose the structured privacy boundary and first deterministic fallback suggestion alongside the existing `camera.intelligence.availability` probe.
- Updated the Apple Intelligence UI test to assert:
  - Forced model-not-ready availability.
  - Privacy context excludes raw image pixels, Photos asset identifiers, and precise coordinates.
  - The deterministic coach reports the model-not-ready recovery action.
- Documented the hidden probes in `README.md`.

### Verification

- Passed whitespace check:
  - `git diff --check`
- Passed direct availability typecheck:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphonesimulator swiftc -typecheck Bracketer/IntelligenceAvailability.swift -target arm64-apple-ios26.2-simulator`
- Passed targeted UI contract:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-25-15-370Z_pid25691_dcff5b8f.xcresult`

### Failures encountered and resolved

- XcodeBuildMCP timed out after 120 seconds, but the underlying `xcodebuild` process completed successfully.
- The targeted UI path took about 181 seconds because simulator app-idle/probe lookup was slow before the hidden probes appeared.
- AppIntents metadata extraction warned that no AppIntents dependency exists yet. This is expected because the App Intents slice has not been implemented.

### Next slice

- Add the first real App Intents surface using Apple's camera/app-intent schemas, with simulator-safe validation before any physical-device Siri/Shortcuts proof.

### Goal status

- Goal still open. The camera now has a hidden, test-proven deterministic capture coach runtime probe.

## 2026-05-15 22:39 PDT - App Intents open-camera handoff

### What changed

- Added `Bracketer/BracketerAppIntents.swift` as the first system-facing App Intents slice.
- Added `OpenBracketerIntent`, which opens Bracketer into a camera workflow with destination and bracket-preset parameters.
- Added `BracketerIntentDestination` and `BracketerIntentBracketPreset` AppEnums for Siri/Shortcuts/Spotlight parameterization.
- Added `BracketerShortcuts` with shortcut phrases for opening the camera, preparing a bracket, and opening the Apple Intelligence area.
- Added `BracketerAppIntentRouter` and a hidden `camera.appIntent.lastHandoff` probe so the handoff path can be tested without pretending background camera capture is safe.
- Documented the App Intents contract in `README.md` and `docs/ARCHITECTURE.md`.

### Verification

- Passed focused unit bundle:
  - `BracketerTests`: 59 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-32-49-745Z_pid25691_6c8b7848.xcresult`
- Passed targeted UI contract after the App Intent handoff probe landed:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-40-41-459Z_pid25691_0924ade0.xcresult`
- New focused coverage:
  - `bracketerAppIntentBracketPresetMapsToCapturePlan`
  - `bracketerAppIntentRouterStoresLatestHandoff`

### Failures encountered and resolved

- XcodeBuildMCP timed out after 120 seconds, but the underlying `xcodebuild` process completed successfully.
- The simulator spent about 253 seconds in the test operation even though the Swift test suite itself ran in under one second.
- The targeted UI smoke also exceeded the 120-second MCP wrapper timeout; the underlying `xcodebuild` completed successfully in about 209 seconds, with the selected UI test taking about 134 seconds.
- App Intents metadata extraction now runs for the app target. The test bundle still reports no relevant App Intents symbols, which is expected for the unit-test target.
- This remains simulator proof. Siri/Shortcuts invocation, camera-domain schema expansion, and physical-device handoff behavior still need manual device verification.

### Next slice

- Move from open-app handoff into a richer Apple Intelligence workflow: Foundation Models-backed coaching behind the validated `CaptureCoachResponse` contract, or an App Intent domain pass that maps Bracketer's camera presets into Apple's camera intent vocabulary.

### Goal status

- Goal still open. Bracketer now has the saved enormous plan, Apple Intelligence availability, privacy-safe generative context, deterministic capture coaching, and a first App Intents handoff slice.

## 2026-05-15 22:48 PDT - Foundation Models capture coach provider seam

### What changed

- Added `Bracketer/CaptureCoachProvider.swift` as the runtime provider seam above the deterministic coach contract.
- Added `CaptureCoachEngine`, which:
  - Refuses model calls unless the structured context reports usable Apple Intelligence.
  - Validates every model response through `CaptureCoachResponseValidator`.
  - Falls back to `DeterministicCaptureCoach` when the provider is unavailable, throws, or returns no actionable suggestions.
  - Records whether a run came from `foundationModels` or `deterministicFallback`.
- Added `FoundationModelsCaptureCoachGenerator` behind `canImport(FoundationModels)` and iOS 26 availability guards.
- The physical-device generator uses:
  - `LanguageModelSession`
  - Bracketer's existing capture-coach system instruction and compact prompt context.
  - Guided structured output types for payload and suggestions.
  - Greedy sampling, low temperature, and a bounded response-token budget.
- Kept simulator live routing on deterministic fallback instead of forcing Apple Intelligence to exist where it does not.
- Documented the provider seam in `README.md` and `docs/ARCHITECTURE.md`.

### Verification

- Passed whitespace check:
  - `git diff --check`
- Passed focused unit bundle:
  - `BracketerTests`: 62 passed, 0 failed
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-16T05-47-33-028Z_pid25691_7af59456.xcresult`
- New focused coverage:
  - `captureCoachEngineFallsBackBeforeModelWhenIntelligenceIsUnavailable`
  - `captureCoachEngineValidatesFoundationModelsOutput`
  - `captureCoachEngineFallsBackWhenFoundationModelsFails`

### Failures encountered and resolved

- No failures in this slice.
- The local iOS 26.5 SDK FoundationModels interface was inspected before implementation so the code uses the installed `LanguageModelSession`, `GenerationOptions`, `@Generable`, and `@Guide` API shapes.
- This remains simulator proof for the routing and validation seam. A physical Apple Intelligence-capable iPhone still needs to prove actual `LanguageModelSession.respond` generation.

### Next slice

- Wire the async `CaptureCoachEngine.live` path into a user-facing, cancellable coaching surface that keeps deterministic simulator behavior, or add a device-only smoke harness that can prove real Foundation Models generation on hardware.

### Goal status

- Goal still open. The app now has a real Foundation Models-ready provider seam without compromising simulator determinism.

## 2026-05-15 23:56 PDT - Visible Capture Coach cockpit card

### What changed

- Added a compact, tappable `camera.captureCoach.card` to the live camera surface.
- The card shows the first validated Capture Coach suggestion, current provider source, and Apple Intelligence readiness tint without blocking core capture.
- Added a compact `camera.bracketPlan.strip` under the coach card, generated from the same `BracketPlan` that feeds capture context:
  - Shows shot count, center EV, and planned EV offsets.
  - Keeps the camera cockpit visually tied to the actual bracket recipe instead of generic AI copy.
- Kept the card out of the way during Pro Controls, Settings, active bracket capture, and camera initialization.
- Tapping the card opens the Settings > AI panel by moving `ModernSettingsPanel` category selection into a binding owned by `ModernContentView`.
- Updated the Apple Intelligence UI test to treat the visible coach card as the primary AI entry point before checking Settings > AI.
- Extended camera chrome UI contract assertions to include the visible coach card frame, source value, and bracket-plan strip value.
- Documented the camera-surface coach entry point in `README.md` and `docs/ARCHITECTURE.md`.

### Verification

- Passed whitespace check:
  - `git diff --check`
- Passed simulator compile/build proof against the iOS 26.5 simulator SDK:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/m3-max/Documents/GitHub/Bracketer/Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation -derivedDataPath /tmp/BracketerDerivedData-compilecheck CODE_SIGNING_ALLOWED=NO build`
  - Build product: `/tmp/BracketerDerivedData-compilecheck/Build/Products/Debug-iphonesimulator/Bracketer.app`
- Passed device-specific simulator build proof after the bracket strip landed:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/m3-max/Documents/GitHub/Bracketer/Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=4D05DBBC-708A-4BBC-8F6B-BE196CBBED4C' -skipMacroValidation -derivedDataPath /tmp/BracketerDerivedData-buildcheck2 CODE_SIGNING_ALLOWED=NO build`
  - Build product: `/tmp/BracketerDerivedData-buildcheck2/Build/Products/Debug-iphonesimulator/Bracketer.app`
- Passed compile-only test bundle proof without launching the simulator:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/m3-max/Documents/GitHub/Bracketer/Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -skipMacroValidation -derivedDataPath /tmp/BracketerDerivedData-buildfortesting CODE_SIGNING_ALLOWED=NO build-for-testing`
  - Result: `** TEST BUILD SUCCEEDED **`
  - Product root: `/tmp/BracketerDerivedData-buildfortesting/Build/Products/Debug-iphonesimulator`

### Failures encountered and open

- XcodeBuildMCP initially reused the stale iOS 26.4 `iPhone 17 Pro` simulator even after the session was pointed at the iOS 26.5 simulator; that run was terminated after it kept targeting the old device.
- A direct hosted unit-test run on the iOS 26.5 simulator compiled, then stalled in test-runner launch and reported `NSMachErrorDomain Code=-308 "(ipc/mig) server died"` after interruption.
- Plain `simctl install` on a freshly erased iOS 26.5 simulator eventually succeeded after about 84 seconds, but `simctl launch com.rishabh.Bracketer` timed out without returning a PID.
- An unrelated `Eco Hero` UI test was actively using the simulator launch stack during this pass, so CoreSimulator was not restarted. This slice currently has compile/build proof but not fresh simulator UI proof for the visible card.

### Next slice

- When the simulator stack is free, run:
  - `BracketerUITests/BracketerUITests/testAppleIntelligenceAvailabilityCanBeForcedForUITests`
  - `BracketerUITests/BracketerUITests/testCameraChromeExposesPortraitAndLandscapeContracts`
- If install or launch still hangs with no unrelated simulator users, restart CoreSimulator, re-erase the selected iOS 26.5 device, and rerun the targeted UI proof.
- Continue expanding the camera cockpit with a bracket strip or EV ladder only after the visible coach card has simulator UI proof.

### Goal status

- Goal still open. Capture Coach and planned bracket shape are now visible in the camera cockpit and connected to the AI settings surface, with compile proof complete and simulator UI proof pending on a healthy launch stack.

## 2026-05-16 00:39 PDT - Bracket recipe planner and simulator UI proof

### What changed

- Added `Bracketer/BracketRecipePlanner.swift` as the first prompt-to-bracket planning contract.
- Added Codable request/response models for natural-language scene descriptions plus the existing privacy-safe `CaptureContextSummary`.
- Added `BracketRecipePlan` normalization through the production `BracketPlan` rules, so generated recipes can only resolve to supported 3, 5, or 7-shot sequences and supported EV steps.
- Added `DeterministicBracketRecipePlanner` as the simulator-safe fallback and test oracle for high-contrast, fast handheld, tripod/stable, extreme-HDR, and current-plan cases.
- Added `BracketRecipeEngine` with the same provider shape as Capture Coach:
  - Skip model calls when Apple Intelligence is unavailable.
  - Validate every generated recommendation before use.
  - Fall back deterministically when a provider is missing, throws, or returns no usable recipes.
- Added `FoundationModelsBracketRecipeGenerator` behind Foundation Models and physical-device availability guards, using guided structured output for recipe payloads.
- Updated simulator device gating so the normal simulator path returns synthetic compatible capability inputs before AVFoundation camera discovery. Explicit UI-test blocker launch arguments still return their fake denied/no-camera states.
- Tightened the Apple Intelligence UI test around visible camera-surface behavior:
  - `camera.captureCoach.card`
  - `camera.bracketPlan.strip`
  - Settings > AI availability
  - Capture Coach source, first suggestion, and refresh fallback reason
- Updated `README.md` and `docs/ARCHITECTURE.md` with the bracket recipe provider seam and simulator capability fast path.

### Verification

- Passed focused unit suite after the recipe planner and simulator-gating changes:
  - `BracketerTests`: 69 passed, 0 failed
  - Result bundle: `/tmp/bracketer-units-after-gating-2026-05-16.xcresult`
- Passed targeted Apple Intelligence UI contract:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-ai-ui-2026-05-16-settings-any.xcresult`
- Passed camera chrome layout contract with the visible coach and bracket strip in portrait and landscape:
  - `testCameraChromeExposesPortraitAndLandscapeContracts`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-chrome-ui-2026-05-16.xcresult`

### Failures encountered and resolved

- The first recipe-planner unit run failed because high-contrast frame signals overrode the user's fast handheld prompt. The deterministic planner now prefers fast handheld prompts unless the scene is explicitly extreme HDR or the structured clipping percentages are extreme.
- The simulator initially launched to a blank white app because `DeviceGating.currentCapabilityInputs()` could block inside AVFoundation discovery on the simulator. The simulator path now uses synthetic compatible inputs unless a fake blocker launch argument is present.
- The Apple Intelligence UI test initially failed after tapping the coach card because it queried SwiftUI combined accessibility elements as `otherElements`. The test now uses the suite's type-agnostic `anyElement` helper for Settings > AI rows.

### Current proof boundary

- Foundation Models request/response routing is covered by deterministic and injected-provider unit tests.
- Simulator UI now proves the visible Capture Coach card, bracket plan strip, Settings > AI handoff, and refresh fallback behavior.
- A physical Apple Intelligence-capable iPhone still needs to prove actual `LanguageModelSession.respond` generation for both Capture Coach and Bracket Recipe planning.

### Next slice

- Wire `BracketRecipeEngine` into a small user-facing prompt-to-bracket UI inside Settings > AI or the camera cockpit.
- Keep the first UI slice narrow: typed scene prompt, top validated recipe, apply-to-current-plan action, deterministic simulator proof, and physical-device proof notes.
- Exact next commands:
  - `rg -n "BracketPlan|evStep|shotCount|selectedSettingsCategory|CaptureCoach" Bracketer/ModernContentView.swift Bracketer/ModernSettingsPanel.swift`
  - Add a focused unit test for applying a `BracketRecipePlan` to current camera settings if no helper exists yet.
  - Run `BracketerTests` plus the Apple Intelligence UI contract again.

### Goal status

- Goal still open. The enormous north-star plan is not complete, but this wave now has model, provider, fallback, UI-entry, simulator-launch, unit, and UI proof.

## 2026-05-16 00:50 PDT - Settings AI bracket recipe apply loop

### What changed

- Wired `BracketRecipeEngine` into a real Settings > AI Bracket Recipe card.
- Added parent-owned recipe state in `ModernContentView`:
  - Scene prompt text.
  - Current `BracketRecipeRun`.
  - In-flight planning state.
  - Last applied recipe summary.
- Added deterministic UI-test prompt seeding with:
  - `-ui-testing-bracket-recipe-prompt <prompt>`
  - `-ui-testing-bracket-recipe-prompt-high-contrast`
- Added `SettingsStore.applyBracketRecipePlan(_:)` so applying a generated recipe goes through the same EV-step and shot-count persistence/normalization path as normal settings.
- Applying a recipe now updates:
  - `settings.selectedEVStep`
  - `settings.bracketShotCount`
  - `currentEVCompensation`
  - live camera exposure compensation through `camera.setExposureCompensation`
  - stale Capture Coach state, which is cleared after recipe application.
- Added a hidden `camera.bracketPlan.current` probe so UI tests can prove the live plan changed even while Settings remains open.
- Added Settings > AI accessibility identifiers for:
  - `settings.intelligence.recipe.prompt`
  - `settings.intelligence.recipe.source`
  - `settings.intelligence.recipe.plan`
  - `settings.intelligence.recipe.recommendation.0`
  - `settings.intelligence.recipe.apply.0`
  - `settings.intelligence.recipe.applied`
- Extended the Apple Intelligence UI test to preload a high-contrast scene prompt, plan a deterministic recipe, apply it, and assert that the live bracket plan becomes 5 shots at +/-2 EV.
- Updated `README.md` and `docs/ARCHITECTURE.md` with the user-facing recipe planner, apply path, prompt launch arguments, and current-plan probe.

### Verification

- Focused compile attempt:
  - `settingsStoreAppliesBracketRecipePlanThroughSupportedBracketSettings` selected with an XCTest-style `-only-testing` path compiled the app but executed 0 Swift Testing tests, so it was treated only as compiler proof.
  - Result bundle: `/tmp/bracketer-recipe-apply-unit-2026-05-16.xcresult`
- Passed full focused unit bundle:
  - `BracketerTests`: 70 passed, 0 failed
  - New executed coverage: `settingsStoreAppliesBracketRecipePlanThroughSupportedBracketSettings`
  - Result bundle: `/tmp/bracketer-units-with-recipe-apply-2026-05-16.xcresult`
- Passed targeted Apple Intelligence UI contract with the new bracket recipe flow:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - The test proved Capture Coach refresh plus Bracket Recipe plan/apply/current-plan state.
  - Result bundle: `/tmp/bracketer-ai-recipe-ui-2026-05-16.xcresult`
- Passed camera chrome layout contract after the recipe UI touched `ModernContentView`:
  - `testCameraChromeExposesPortraitAndLandscapeContracts`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-chrome-after-recipe-ui-2026-05-16.xcresult`

### Failures encountered and resolved

- The first focused unit command used an XCTest-style selector for a Swift Testing test and executed 0 tests. The full `BracketerTests` target was rerun, and the new test executed successfully.
- The Settings > AI recipe card sat below the initial sheet viewport, so the UI test uses the existing scroll-reveal helpers before tapping Plan and Apply.

### Current proof boundary

- Simulator UI now proves a visible prompt-to-bracket loop and live application into current camera settings.
- The loop still uses deterministic fallback on simulator and when Apple Intelligence is model-not-ready.
- Physical-device proof is still required for actual Foundation Models recipe generation and for real camera exposure compensation behavior on hardware.

### Next slice

- Add an on-camera compact recipe affordance that can show the active recipe source and reopen Settings > AI without crowding the capture controls.
- Add physical-device smoke notes or a small device-only diagnostic surface for `LanguageModelSession.respond` so real Apple Intelligence output can be distinguished from deterministic fallback.

### Goal status

- Goal still open. Bracketer now has a working prompt-to-bracket UI loop with model contract, deterministic fallback, apply behavior, persistence path, docs, unit tests, and simulator UI proof.

## 2026-05-16 01:12 PDT - Active recipe camera strip

### What changed

- Replaced the simple last-applied recipe string in `ModernContentView` with `ActiveBracketRecipeSummary`.
- Folded the active recipe title and provider source into the existing `camera.bracketPlan.strip` instead of adding another floating camera widget.
- Preserved the old strip accessibility value before a recipe is applied:
  - Shot count.
  - EV sequence.
  - Center EV.
- Extended the strip accessibility value after a recipe is applied:
  - Active recipe title.
  - Provider source.
- Made the bracket strip tappable, so the on-camera active recipe affordance reopens Settings > AI.
- Kept `settings.intelligence.recipe.applied` as the Settings-side proof of the applied recipe and source.
- Added `settings.closeButton` for deterministic UI proof that closes Settings before checking the on-camera strip.
- Extended the Apple Intelligence UI test to prove:
  - Recipe apply includes the deterministic provider source.
  - Settings can close after apply.
  - `camera.bracketPlan.strip` reports the active 5-shot high-contrast recipe and source.
  - Tapping the active strip reopens Settings > AI.
- Updated `README.md` and `docs/ARCHITECTURE.md` with the active strip behavior.

### Verification

- Passed targeted Apple Intelligence UI contract with the active recipe strip:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-ai-recipe-strip-ui-rerun2-2026-05-16.xcresult`
- Passed full focused unit bundle after the active strip change:
  - `BracketerTests`: 70 passed, 0 failed
  - Result bundle: `/tmp/bracketer-units-after-active-strip-2026-05-16.xcresult`
- Passed camera chrome layout contract after the active strip change:
  - `testCameraChromeExposesPortraitAndLandscapeContracts`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-chrome-after-active-strip-2026-05-16.xcresult`

### Failures encountered and resolved

- The first updated Apple Intelligence UI run failed because the expected Settings applied-recipe value did not include the provider source. The expectation now matches the source-aware app behavior.
- The second updated Apple Intelligence UI run queried `camera.bracketPlan.strip` as a button, but SwiftUI exposes the combined strip as an `Other` element. The test now uses the suite's type-agnostic `anyElement` helper.
- XcodeBuildMCP's default simulator failed to launch the unit test runner with Mach error -308 after a timeout. The direct `xcodebuild test` command was rerun on the already-booted iPhone 17 Pro Max simulator and passed.

### Current proof boundary

- Simulator UI now proves the full loop from camera coach, Settings > AI, deterministic bracket recipe planning, apply, on-camera active recipe display, and strip-to-settings return.
- This is still deterministic fallback proof on simulator. A physical Apple Intelligence-capable iPhone still needs to prove real `LanguageModelSession.respond` output and live camera exposure behavior.

### Next slice

- Add a small device-only Apple Intelligence diagnostic path that clearly distinguishes live Foundation Models output from deterministic fallback.
- Start turning the recipe affordance into a richer generative capture workflow: named presets, recent recipe history, and review-manifest annotations that remember which recipe produced a bracket.

### Goal status

- Goal still open. Bracketer now has a visible AI recipe loop that can apply a generated plan and keep the active recipe reachable from the camera surface, but the enormous north-star plan is far from complete.

## 2026-05-16 01:20 PDT - Apple Intelligence runtime proof diagnostic

### What changed

- Added `IntelligenceRuntimeDiagnostic` and `IntelligenceRuntimeDiagnosticState` above the availability and provider seams.
- The diagnostic compares:
  - `CaptureCoachRun.source`
  - `CaptureCoachResponse.usedAppleIntelligence`
  - `BracketRecipeRun.source`
  - `BracketRecipeResponse.usedAppleIntelligence`
  - current `IntelligenceFeatureAvailability`
- It classifies the current session as:
  - deterministic fallback
  - ready for a live physical-device run
  - live Apple Intelligence observed
  - inconclusive Foundation Models output
- Added a Settings > AI Runtime Proof card with:
  - diagnostic title
  - availability/source detail
  - coach and recipe source summary
  - next action
  - accessibility probe `settings.intelligence.runtimeDiagnostic`
- Extended the Apple Intelligence UI test to assert the deterministic fallback diagnostic before refreshing Capture Coach or planning a recipe.
- Added unit coverage for all diagnostic states.
- Updated `README.md` and `docs/ARCHITECTURE.md` so future goal-mode slices know this is proof separation, not real physical-device proof.

### Verification

- Passed full focused unit bundle after adding runtime diagnostics:
  - `BracketerTests`: 74 passed, 0 failed
  - New executed coverage:
    - `intelligenceRuntimeDiagnosticReportsDeterministicFallback`
    - `intelligenceRuntimeDiagnosticReportsReadyPhysicalDeviceWithoutLiveRun`
    - `intelligenceRuntimeDiagnosticReportsLiveFoundationModelsProof`
    - `intelligenceRuntimeDiagnosticFlagsFoundationModelsWithoutProof`
  - Result bundle: `/tmp/bracketer-units-after-runtime-diagnostic-2026-05-16.xcresult`
- Passed targeted Apple Intelligence UI contract with Runtime Proof:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-ai-runtime-diagnostic-ui-2026-05-16.xcresult`

### Failures encountered and resolved

- The first unit compile failed because the new diagnostic referenced `availability.status`; the actual contract exposes `statusTitle`. The diagnostic now uses `statusTitle`, and the rerun passed.

### Current proof boundary

- Simulator proof now explicitly labels deterministic fallback and can no longer be mistaken for live Foundation Models generation.
- Physical-device proof is still required to move the diagnostic into `liveAppleIntelligence` with real `LanguageModelSession.respond` output.

### Next slice

- Persist recent bracket recipes and annotate review manifests with the recipe title/source used for capture.
- Add a small device-run checklist or exportable diagnostic report entry that captures the Runtime Proof value alongside result bundle names.

### Goal status

- Goal still open. Runtime proof is now first-class, but the north-star plan still needs real physical-device Apple Intelligence validation, recipe history, review integration, and the larger generative workflow.

## 2026-05-16 01:28 PDT - Recent recipe history and manifest recipe snapshots

### What changed

- Added `AppliedBracketRecipeRecord` as the durable record for an applied bracket recipe:
  - Stable id.
  - Title.
  - Provider source.
  - Normalized `BracketRecipePlan`.
  - Applied timestamp.
  - Stable accessibility summary.
- Added `SettingsStore.recentBracketRecipes` with `UserDefaults` persistence:
  - Newest first.
  - Duplicate recipes move to the top instead of creating another row.
  - Capped at five records.
  - Cleared by `resetToDefaults`.
- Applying a Settings > AI recipe now:
  - applies the normalized plan
  - updates live EV compensation
  - records recent history
  - updates the active camera-strip recipe summary
  - keeps the applied record available for simulator manifest creation
- Added recent recipe rows to Settings > AI:
  - `settings.intelligence.recipe.recent.0`
  - rows show title, plan, and provider source.
- Added optional `BracketManifest.RecipeSnapshot`:
  - recipe title
  - provider source
  - normalized recipe plan
- `BracketReviewSequence.manifest(...)` can now accept an applied recipe record without disturbing existing manifest callers.
- The UI-test simulated review path now passes the active recipe record into the generated manifest when one exists.
- Updated `README.md` and `docs/ARCHITECTURE.md` with recipe history and manifest recipe metadata.

### Verification

- Passed full focused unit bundle after recipe history and manifest snapshot changes:
  - `BracketerTests`: 77 passed, 0 failed
  - New executed coverage:
    - `bracketManifestCanIncludeAppliedRecipeSnapshot`
    - `settingsStorePersistsRecentBracketRecipesNewestFirst`
    - `settingsStoreLimitsRecentBracketRecipes`
  - Result bundle: `/tmp/bracketer-units-after-recipe-history-2026-05-16.xcresult`
- Passed targeted Apple Intelligence UI contract with recent recipe history:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - The test now proves the recent recipe row after Apply, then closes Settings, verifies the active camera strip, and uses the strip to reopen Settings > AI.
  - Result bundle: `/tmp/bracketer-ai-recipe-history-ui-2026-05-16.xcresult`

### Current proof boundary

- Recent recipe history and manifest recipe snapshots are simulator- and unit-proven.
- Completed live Photos-backed capture still needs a direct handoff from the active recipe record into `CameraController` before physical captures can automatically stamp their manifests.

### Next slice

- Thread the active applied recipe record into the live capture controller path so real Photos-backed manifests can carry recipe metadata too.
- Add a review-surface probe that exposes manifest recipe metadata without requiring ShareLink inspection.

### Goal status

- Goal still open. Recipe history and manifest metadata are in place, but live capture stamping, review UI, physical-device Apple Intelligence proof, and broader generative workflow layers remain.

## 2026-05-16 01:38 PDT - Live capture recipe manifest handoff

### What changed

- Promoted the active applied recipe record into `CameraController`:
  - Settings > AI Apply now publishes the `AppliedBracketRecipeRecord` to the controller.
  - Simulated UI-test captures use that record when building `lastBracketManifest`.
  - Completed Photos-backed capture sequences now pass the active record into `BracketReviewSequence.manifest(...)`.
- Added a recipe-specific manifest accessibility value:
  - `BracketManifest.RecipeSnapshot.accessibilityValue`
  - `review.sequence.manifestRecipe`
  - `review.live.manifestRecipe`
- Reworked `SimulatedBracketReviewView` so its manifest export is generated from the current in-memory sequence plus the active recipe record.
  - Deleting simulated shots still changes the exported sequence manifest.
  - Applied recipe metadata remains present when a recipe produced the capture.
- Extended the Apple Intelligence UI contract so it now proves:
  - deterministic high-contrast recipe planning
  - recipe application
  - active camera strip state
  - strip-to-Settings handoff
  - simulated shutter capture
  - review manifest recipe probe
  - manifest JSON containing the recipe object
- Updated `README.md` and `docs/ARCHITECTURE.md` with the live controller handoff and review manifest probes.

### Verification

- Passed full focused unit bundle after live recipe manifest handoff:
  - `BracketerTests`: 77 passed, 0 failed
  - Result bundle: `/tmp/bracketer-units-after-live-recipe-manifest-2026-05-16.xcresult`
- Passed targeted Apple Intelligence UI contract with review manifest recipe proof:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-ai-live-recipe-manifest-ui-2026-05-16.xcresult`
- Passed existing simulated bracket review contract after the view/manifest changes:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-simulated-review-after-live-recipe-manifest-2026-05-16.xcresult`

### Current proof boundary

- Simulator proof now covers the full AI recipe to simulated capture to review manifest loop.
- The live Photos-backed code path is wired to stamp the active recipe record, but a physical iPhone capture still needs to verify the real Photos save, asset ordering, and manifest handoff on hardware.
- Apple Intelligence remains deterministic fallback proof on simulator; real Foundation Models output still requires an Apple Intelligence-capable physical device.

### Next slice

- Add a physical-device proof checklist/export row that captures runtime diagnostic state, active recipe, and latest manifest recipe.
- Start a review-generation slice: privacy-safe AI captions or merge notes generated from `BracketManifest` and `CaptureContextSummary`, with deterministic fallback first.

### Goal status

- Goal still open. The applied recipe now reaches capture and review metadata, but physical-device proof, richer review generation, and the broader 12-hour north-star system remain unfinished.

## 2026-05-16 01:48 PDT - Review narrative generation seam

### What changed

- Added `BracketNarrativeContext` as the Wave 8 review-side generative boundary:
  - Built from `BracketManifest` plus the current `BracketReviewSequence`.
  - Includes exposure spread, EV labels, selected shot, best-exposure candidate, missing/failed counts, RAW/processed availability, clipping warnings, optional applied recipe title/source, Apple Intelligence readiness, and an explicit privacy block.
  - Excludes raw image pixels, Photos asset identifiers, precise location coordinates, and unsupported camera metadata.
- Added `BracketReviewNarrativeRequest`, `BracketReviewNarrativeResponse`, validator, deterministic fallback, run source, and engine.
- Added `FoundationModelsBracketReviewNarrativeGenerator` behind the same physical-device Foundation Models guard style used by Capture Coach and Bracket Recipe.
- Added `BracketReviewNarrativeCard` to review surfaces:
  - Simulated review renders the card inside the review scroll view.
  - Photos-backed `ImageViewer` renders the card when a manifest exists.
  - The card exposes regenerate and dismiss controls.
  - UI tests can inspect `review.narrative.card`.
- Extended the Apple Intelligence UI test so the recipe-to-review path now also proves the deterministic review narrative is grounded in:
  - active recipe title
  - simulated manifest source
  - exposure spread
  - merge advice from clipping warnings
- Updated `README.md` and `docs/ARCHITECTURE.md` with the review narrative provider seam and probe contract.

### Verification

- Passed full focused unit bundle after review narrative work:
  - `BracketerTests`: 82 passed, 0 failed
  - New executed coverage:
    - `bracketNarrativeContextBuildsPrivacyBoundedPrompt`
    - `deterministicBracketReviewNarrativeSummarizesManifestTruthfully`
    - `bracketReviewNarrativeValidatorNormalizesModelOutput`
    - `bracketReviewNarrativeEngineFallsBackBeforeModelWhenUnavailable`
    - `bracketReviewNarrativeEngineValidatesFoundationModelsOutput`
  - Result bundle: `/tmp/bracketer-units-after-review-narrative-2026-05-16.xcresult`
- Passed targeted Apple Intelligence UI contract with the review narrative card:
  - `testAppleIntelligenceAvailabilityCanBeForcedForUITests`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-ai-review-narrative-ui-2026-05-16.xcresult`
- Passed existing simulated bracket review contract after inserting the new card into the review scroll view:
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: 1 passed, 0 failed
  - Result bundle: `/tmp/bracketer-simulated-review-after-review-narrative-2026-05-16.xcresult`

### Current proof boundary

- Simulator proof covers deterministic review narrative generation and UI rendering.
- Physical-device proof is still needed for live Foundation Models review narration.
- The card can regenerate and dismiss, but save-to-manifest sidecar is not implemented yet.

### Next slice

- Add optional generated-note persistence into a manifest sidecar 2.0 model, with deterministic import/read tests.
- Alternatively, add physical-device proof export rows that capture runtime diagnostic, active recipe, latest manifest recipe, and latest review narrative source in one report.

### Goal status

- Goal still open. Bracketer now has a first truthful generative review layer, but sidecar persistence, physical Apple Intelligence proof, and larger intelligent review workspace work remain.

## 2026-05-26 23:42 PDT - May Goals project spine v1

### What changed

- Added `maygoals.md` as the intentionally impossible imaging-OS goal-mode contract.
- Added `.codex-maygoals-progress.md` as the live parsed checklist, evidence ledger, command log, blocker list, and next-action tracker for the May Goals execution loop.
- Added `BracketProject` as the first durable project-spine model:
  - Stable project id.
  - Capture session identifier.
  - Manifest ownership.
  - Optional manifest sidecar ownership.
  - Review snapshot.
  - Per-shot asset references.
  - Lifecycle state.
  - Accepted tags and user notes.
  - Search tokens.
  - Export history placeholder.
  - Diagnostics reference.
  - Privacy snapshot that explicitly records raw-byte, Photos identifier, generated-text, capture-context, and coordinate policy.
- Added `FileBracketProjectStore`:
  - JSON project persistence.
  - Project index.
  - Current/latest routing.
  - List/load/save/delete operations.
  - Corrupt project data surfaces as a load failure instead of silent success.
- Wired `CameraController` so simulated and Photos-backed manifest completion also publishes and persists `lastBracketProject`.
- Added the hidden `camera.project.latest` accessibility probe for deterministic UI verification of the latest project state.
- Added `LatestBracketProjectSummary` and `LatestBracketProjectSummaryProvider` as the first project-query domain seam.
- Added `SummarizeLatestBracketProjectIntent`, a Shortcuts/Siri-facing summary action that reads the latest persisted project without claiming background camera access.
- Updated `README.md` and `docs/ARCHITECTURE.md` with the project contract and probe.

### Verification

- Initial focused XcodeBuildMCP `test_sim` call timed out at the tool boundary while the underlying `xcodebuild` continued. The `.xcresult` summary showed the build completed and the first run executed `88` unit tests with `86` passing and `2` failing.
- Resolved the root cause: project `updatedAt` used a live `Date()` value that lost subsecond precision during ISO8601 round-trip encoding, breaking equality after persistence. The model now makes `updatedAt` explicit and deterministic for project creation.
- Passed focused unit bundle after the fix:
  - `BracketerTests`: `88` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T06-39-40-952Z_pid18246_39f2b8a7.xcresult`
  - New executed coverage:
    - `bracketProjectBuildsDurableReviewPrivacyAndSearchContract`
    - `bracketProjectMarksPartialManifestIncompleteWithoutRawBytes`
    - `fileBracketProjectStorePersistsCurrentLatestAndDeletionAcrossInstances`
    - `fileBracketProjectStoreSurfacesCorruptProjectData`
- The first App Shortcut implementation used an explicit array literal, which failed because this project/API expects the App Shortcuts result-builder body. Reworked it to separate `AppShortcut` expressions.
- A second unit run caught a missing explicit initializer on `LatestBracketProjectSummary.empty`; added the initializer and reran.
- Passed focused unit bundle after latest-project summary and App Intent query work:
  - `BracketerTests`: `90` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T06-47-09-512Z_pid18246_0fa21744.xcresult`
  - New executed coverage:
    - `latestBracketProjectSummaryProviderReturnsEmptyStateWithoutProject`
    - `latestBracketProjectSummaryProviderDescribesLatestProjectTruthfully`
  - Remaining warnings were the pre-existing `OrientationManager.deinit` main-actor warnings, not new project/App Intent failures.
- Passed targeted simulator UI proof for latest-project publication:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T06-41-21-412Z_pid18246_cf31b6f3.xcresult`

### Proof category

- `pure-model-proof`: project lifecycle, review snapshot, privacy flags, search tokens, JSON round-trip, persistence, current/latest routing, deletion, and corrupt data behavior.
- `simulator-ui-proof`: deterministic simulated bracket capture publishes a latest project exposed by `camera.project.latest` after review dismissal.

### Current proof boundary

- The project spine is now real enough to own manifest/review/sidecar/diagnostic metadata and persist across store instances.
- This is not yet a complete project library UI, relaunch UI recovery flow, import/export bundle system, Spotlight index, RAW pair model, or physical-device proof.
- Physical Photos-backed project persistence is wired through the same manifest path but still needs real-device capture proof.

### Next slice

- Promote the project store from "latest project" infrastructure into an actual project index surface, AppEntity model, or Spotlight/search surface.
- Add project export/import or project-library routing before attempting larger computational imaging features.
- Add a physical-device proof checklist row for Photos-backed project persistence when an iPhone is available.

### Goal status

- Goal still open. Wave Family A has a verified project-spine v1, but the full May Goals imaging OS remains intentionally incomplete.

## 2026-05-27 00:05 PDT - May Goals project library/search v1

### What changed

- Added the first searchable project-library domain layer:
  - `BracketProject.displayTitle`, `displaySubtitle`, `projectLibraryAccessibilityValue`, and `searchCorpus`.
  - `BracketProjectSearchQuery` for deterministic privacy-safe token search.
  - `BracketProjectLibrarySnapshot` for current/latest project summaries, filtered project lists, load-failure reporting, and accessibility proof strings.
- Extended `FileBracketProjectStore` with:
  - `search(_:)`
  - `librarySnapshot(searchText:)`
  - `deleteAll()` for deterministic UI-test archive resets.
- Extended `CameraController` with a published `bracketProjectLibrarySnapshot` that loads from persistent project storage on init and refreshes after successful project saves.
- Added `-ui-testing-reset-projects` so project-library UI tests can start from a known archive without relying on simulator state.
- Added a compact Settings > About project-library surface:
  - `settings.projects.summary`
  - `settings.projects.search`
  - `settings.projects.result.<index>`
  - load-failure and empty-state probes
- Extended the simulated bracket UI test so it now:
  - resets the project archive
  - captures and persists a simulated project
  - verifies `camera.project.latest`
  - terminates and relaunches the app
  - verifies the latest project is loaded back from disk
  - opens Settings > About and verifies the project-library summary and row
- Updated `README.md` and `docs/ARCHITECTURE.md` with the project-library, search, reset-argument, and accessibility-probe contracts.
- Updated `.codex-maygoals-progress.md` with the new Wave A/H evidence, command log, proof boundaries, and next action.

### Verification

- First project-library unit test attempt failed at compile time:
  - Error: extra `}` in `ModernSettingsPanel.swift`.
  - Root cause fixed by removing the stray brace after `ModernProjectLibraryRow`.
- Passed focused unit bundle:
  - `BracketerTests`: `92` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T06-59-49-563Z_pid18246_d974c65e.xcresult`
  - New executed coverage:
    - `bracketProjectLibrarySnapshotFiltersBySearchableFacts`
    - `fileBracketProjectStoreSearchesProjectsAndDeletesAll`
  - Remaining warnings were the pre-existing `OrientationManager.swift:204` main-actor deinit warnings.
- Passed targeted simulator UI project-library/relaunch proof:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-00-55-827Z_pid18246_146b88b2.xcresult`
- Passed targeted simulator UI settings regression proof:
  - `BracketerUITests/BracketerUITests/testSettingsPresetsAndCaptureControlsExposeStableState`: `1` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-02-46-886Z_pid18246_4ecb15a8.xcresult`
- Passed `git diff --check`.

### Proof category

- `pure-model-proof`: project-library snapshot construction, query filtering, store search, archive reset, persistence/search/privacy behavior.
- `simulator-ui-proof`: deterministic simulated project survives app relaunch and appears in the Settings project-library surface.

### Current proof boundary

- The library is a compact Settings surface, not yet the final archive workspace with thumbnails, favorites, smart collections, editing, or import/export.
- Search currently covers stored project facts such as source, lifecycle, EV spread, representations, tags, notes, recipes, diagnostics, and privacy text. It does not yet cover full date facets, lens metadata, location policy, semantic scene search, dynamic-range metrics, output type, or quality scores.
- Physical Photos-backed relaunch proof remains separate and still needs a real iPhone run.
- No AppEntity, Spotlight index, widget, Control Center, Action button, project bundle export, or project import path has been added in this slice.

### Next slice

- Add a Bracket Project `AppEntity`/query layer backed by `BracketProjectSearchQuery`, then use it for App Intents and Spotlight where the local SDK supports it.
- Add a provenance-preserving project export/import bundle that contains project JSON, manifest JSON, sidecar JSON, privacy report, diagnostics report, and eventually selected asset references without raw bytes unless explicitly requested.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 19:18 PDT - May Goals latest manifest App Intent file export v1

### What changed

- Added `LatestBracketManifestExportFile`, `LatestBracketManifestExportFileProvider`, and `ExportLatestBracketManifestIntent`.
- The provider loads the latest saved Bracketer project and returns only the latest `BracketManifest` JSON as an `IntentFile(type: .json)`.
- Privacy defaults to metadata-only redaction, while recovery identifiers can be explicitly requested.
- The manifest export filename is manifest-specific, for example `bracketer-19700101-0000-5shot-photos-metadata-only-manifest.json`.
- Dialog/accessibility copy states the boundary: manifest only, no raw photo bytes, no Photos resource fetches, no RAW decoding, no final rendered output, and no physical proof.
- `BracketerShortcutTileInventory` now lists `Export Latest Bracketer Manifest` as a deferred App Intent while the app remains at 10 of 10 registered shortcut tiles.
- README and architecture docs now document the manifest-only App Intent and shortcut-cap boundary.

### Verification

- Claude offload:
  - Ran `claude --dangerously-skip-permissions -p ...` with a focused v132 implementation prompt.
  - The helper moved into the manifest-export/test task but exited with code 143 and produced no usable final report; final inspection and proof were done locally.
- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v132-latest-manifest-intent-unit-tests.xcresult`.
  - Result: `result=Passed`, 247 unit tests passed, 0 failed, 0 skipped, total 247, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- Focused UI proof:
  - Result bundle: `/tmp/bracketer-v132-latest-manifest-intent-ui-tests.xcresult`.
  - Result: `result=Passed`, 1 focused UI test passed, 0 failed, 0 skipped, total 1, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0.
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is App Intent provider/model proof plus simulator UI proof for the deferred manifest intent inventory.
- It does not prove Shortcuts/Siri runtime execution, physical Spotlight launch, physical iPhone behavior, Photos byte inspection, RAW decoding, final rendered output, real Files export, or physical proof.

### Next slice

- Continue another Wave K/P import/export invariant or Wave F/G/N/J review/system-surface invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 18:57 PDT - May Goals shortcut tile inventory proof v1

### What changed

- Added `BracketerShortcutTileInventory`, a small model that records the 10 App Shortcut tile limit, the registered tile count, deferred intent names, headroom status, and accessibility summary.
- Exposed the inventory through hidden camera probe `camera.appIntent.shortcutInventory`.
- Added unit coverage for the 10-of-10 cap, deferred `PrepareTimedBracketCaptureIntent` and `OpenLatestBracketProjectIntent` names, no-headroom state, and boundary wording.
- Added focused UI coverage to prove the camera probe reports the shortcut cap and deferred intent names.
- Updated README and architecture docs with the inventory probe and shortcut-cap boundary.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Failed unit attempts, resolved:
  - First v131 unit attempt caught a Swift string-interpolation parse error in `BracketerShortcutTileInventory.accessibilityValue`.
  - Second v131 unit attempt caught a missing explicit `return` after adding a local `let` inside that getter.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v131-shortcut-inventory-unit-tests.xcresult`.
  - Result: `result=Passed`, 244 unit tests passed, 0 failed, 0 skipped, total 244, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- Focused UI proof:
  - Result bundle: `/tmp/bracketer-v131-shortcut-inventory-ui-tests.xcresult`.
  - Result: `result=Passed`, 1 focused UI test passed, 0 failed, 0 skipped, total 1, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0.
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is unit/UI simulator proof for shortcut tile inventory and deferred-intent boundaries only.
- It does not prove Shortcuts/Siri runtime execution, physical Spotlight launch, physical iPhone behavior, Photos byte inspection, RAW decoding, final rendered output, or real Files export.

### Next slice

- Continue another Wave K/P import/export invariant or Wave F/G/N/J review/system-surface invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 18:39 PDT - May Goals latest-review provider empty-state hardening v1

### What changed

- Added `LatestBracketProjectReviewHandoffProvider` and `LatestBracketProjectReviewHandoffResult`, moving latest-review App Intent handoff/dialog construction behind a temp-store-testable provider.
- `OpenLatestBracketProjectIntent.perform()` now delegates to the provider before handing off through `BracketerAppIntentRouter`.
- Saved-project state still produces a `.review` handoff with the latest project title.
- Empty-project state now produces a `.camera` handoff and tells the photographer to capture a bracket before review, avoiding a fake review claim when no saved project exists.
- README and architecture docs now document the no-project camera fallback.

### Verification

- Claude offload:
  - Read-only `claude --dangerously-skip-permissions` scout recommended the provider seam, temp-store tests, keeping the router out of the provider, and routing no-project state away from a fake review handoff. The final local patch incorporated those points; Claude made no file edits.
- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v130-latest-review-provider-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v130-latest-review-provider-unit -derivedDataPath /tmp/bracketer-dd-v130-latest-review-provider-unit -resultBundlePath /tmp/bracketer-v130-latest-review-provider-unit-tests.xcresult`.
  - Result: `result=Passed`, 243 unit tests passed, 0 failed, 0 skipped, total 243, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0.
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is provider/model proof only; v129 remains the simulator UI proof for the latest-review handoff route.
- It does not prove Shortcuts/Siri runtime execution, physical Spotlight launch, physical iPhone behavior, Photos byte inspection, RAW decoding, final rendered output, or real Files export.

### Next slice

- Continue another Wave K/P import/export invariant or Wave F/G/N/J review/system-surface invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 18:29 PDT - May Goals latest-review App Intent handoff v1

### What changed

- Added `OpenLatestBracketProjectIntent`, an open-app App Intent that records a latest-project review handoff through `BracketerAppIntentRouter`.
- Kept the new latest-review intent out of `BracketerShortcuts.appShortcuts` while the app remains at the 10-shortcut platform cap.
- Updated `BracketerAppIntentHandoff.accessibilityValue` so a latest-review handoff can speak its project title even when it intentionally routes to `latest` instead of a selected project id.
- Added `-ui-testing-open-latest-review-handoff`, which seeds the App Intent router and restores the latest saved project through the normal `ModernContentView` handoff consumer.
- Updated the saved-project relaunch UI proof to open the persisted simulated project through the App Intent router path instead of the direct latest-project test-only restore path.
- Updated README and architecture docs with the latest-review intent, UI-test route, and shortcut-cap boundary.

### Verification

- Claude offload:
  - First read-only attempt before the 18:30 PDT reset hit the Claude session limit; no files were modified and no output was used.
  - Second read-only attempt after the reset reported no compile, routing, shortcut-cap, or truth-boundary defects. It noted only that the long UI proof depends on the simulated project surviving relaunch, which the passing UI result bundle below verifies.
- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v129-latest-review-handoff-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v129-latest-review-handoff-unit -derivedDataPath /tmp/bracketer-dd-v129-latest-review-handoff-unit -resultBundlePath /tmp/bracketer-v129-latest-review-handoff-unit-tests.xcresult`.
  - Result: `result=Passed`, 241 unit tests passed, 0 failed, 0 skipped, total 241, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- Focused UI proof:
  - Result bundle: `/tmp/bracketer-v129-latest-review-handoff-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v129-latest-review-handoff-ui -derivedDataPath /tmp/bracketer-dd-v129-latest-review-handoff-ui -resultBundlePath /tmp/bracketer-v129-latest-review-handoff-ui-tests.xcresult`.
  - Result: `result=Passed`, 1 focused UI test passed, 0 failed, 0 skipped, total 1, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0.
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is App Intent/model/UI simulator proof only. It does not prove Shortcuts/Siri runtime execution, physical Spotlight launch, physical iPhone behavior, Photos byte inspection, RAW decoding, final rendered output, or real Files export.

### Next slice

- Continue another Wave K/P import/export invariant or Wave F/G/N/J review/system-surface invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 18:06 PDT - May Goals timer-prepared capture App Intent handoff v1

### What changed

- Added `BracketerIntentTimerMode` and `PrepareTimedBracketCaptureIntent`, giving system surfaces a timer-prepared camera handoff with a selected bracket preset and timer mode.
- Extended `BracketerAppIntentHandoff` with optional `timerMode`, timer-aware `capturePlan`, timer-inclusive accessibility text, and timer-inclusive routing identifiers.
- `ModernContentView` now applies capture-preparation handoffs by setting the selected EV step, bracket shot count, and timer mode before presenting the camera screen.
- Added `-ui-testing-open-timed-capture-handoff` so simulator UI proof can seed a deterministic five-shot +/-2 EV, 3s timer handoff without invoking Shortcuts or background camera capture.
- Added unit coverage for timer-mode mapping, timer-prepared handoff storage, routing identifiers, accessibility boundary copy, capture-plan derivation, and preservation of the 10 App Shortcut tile cap.
- Added focused UI coverage proving the handoff updates `camera.appIntent.lastHandoff`, the current bracket plan, the EV strip, the bracketing indicator, the timer button, and the ready shutter state.
- Updated README and architecture docs with the timer-prepared handoff contract and the no-background-capture boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print --output-format text --no-session-persistence --max-budget-usd 1 ...`
  - Result: Claude reported `You've hit your session limit - resets 6:30pm (America/Los_Angeles)` and exited with code `1`; no files were modified by Claude and no audit output was used.
- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v128-timer-prepared-handoff-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v128-timer-prepared-handoff-unit -derivedDataPath /tmp/bracketer-dd-v128-timer-prepared-handoff-unit -resultBundlePath /tmp/bracketer-v128-timer-prepared-handoff-unit-tests.xcresult`.
  - Result: `result=Passed`, 240 unit tests passed, 0 failed, 0 skipped, total 240, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- Focused UI proof:
  - Result bundle: `/tmp/bracketer-v128-timer-prepared-handoff-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testTimedCaptureAppIntentHandoffAppliesPresetAndTimer -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v128-timer-prepared-handoff-ui -derivedDataPath /tmp/bracketer-dd-v128-timer-prepared-handoff-ui -resultBundlePath /tmp/bracketer-v128-timer-prepared-handoff-ui-tests.xcresult`.
  - Result: `result=Passed`, 1 focused UI test passed, 0 failed, 0 skipped, total 1, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.

### Current proof boundary

- This is App Intent/model/UI simulator proof only. It does not prove Shortcuts/Siri runtime execution, background camera capture, real timer capture, Photos writes, final rendered output, or physical iPhone behavior.
- The new intent is intentionally not registered as an additional `AppShortcut` phrase because the app already proves the platform cap at 10 shortcut tiles.

### Next slice

- Continue another Wave K/P import/export invariant or Wave F/G/N/J review/system-surface invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 17:46 PDT - May Goals final-output action-plan system surfaces v1

### What changed

- Added `BracketProject.finalOutputActionPlanSummary` as the single project-level computed bridge from the final-output manifest/readiness audit action plan.
- Project-library accessibility and local search corpus now include the computed action-plan summary, so action-plan terms can resolve saved projects without exposing Photos identifiers or image bytes.
- `LatestBracketProjectSummary` now carries the same action-plan summary in Shortcuts-facing dialog/accessibility metadata.
- `BracketProjectEntity` now carries the action-plan summary in its typed value and accessibility text for AppEntity/query results.
- `BracketProjectSpotlightRecord` schema version is now `2`; Spotlight content description, keywords, and accessibility carry the computed action-plan summary while retaining hashed identifiers and Photos redaction.
- Unit coverage now asserts project-library accessibility, latest-project summary, AppEntity query/search results, local action-plan search, and Spotlight searchable item metadata all expose the action plan and the not-final-rendered-image boundary.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Initial focused unit proof caught a search-corpus regression expectation:
  - Result bundle: `/tmp/bracketer-v127-action-plan-system-surfaces-unit-tests.xcresult`.
  - Result: `result=Failed`, 236 unit tests passed, 1 failed, 0 skipped. Failure was the previous exact search expectation `simulated 3 shot`, which became too broad after the action-plan text expanded the corpus.
- Focused unit proof after tightening that assertion to the simulated project's `Tripod` tag:
  - Result bundle: `/tmp/bracketer-v127-action-plan-system-surfaces-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v127-action-plan-system-surfaces -derivedDataPath /tmp/bracketer-dd-v127-action-plan-system-surfaces -resultBundlePath /tmp/bracketer-v127-action-plan-system-surfaces-unit-tests.xcresult`.
  - Result: `result=Passed`, 237 unit tests passed, 0 failed, 0 skipped, total 237, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0 (no whitespace errors).
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is project metadata/search/AppIntents/Spotlight unit proof only. It does not prove a real Spotlight index round trip, Shortcuts UI picker behavior, final rendered image bytes, Photos byte inspection, RAW decoding, real Files export, or physical iPhone behavior.

### Next slice

- Continue another Wave K/P import/export invariant or Wave F/G/N/J review/system-surface invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 17:18 PDT - May Goals final-output action-plan archive-workspace row v1

### What changed

- `BracketProjectLibraryWorkspace.ProjectSummary` now computes `finalOutputActionPlanSummary` from the project-derived `BracketProjectFinalOutputManifest` plus `BracketProjectFinalOutputReadinessAudit`, using metadata-only export policy and the project update timestamp.
- Archive workspace project-summary accessibility now includes `Final output action plan: ...`, so archive-workspace rows carry the same next-step metadata as export/import/file-provider surfaces.
- The visible Settings archive workspace row now renders a compact final-output action-plan line below the shot/export summary, keeping the workspace metadata-only and row-scannable.
- Extended the existing library/search/workspace unit coverage to assert the summary contains `Resolve blockers before export`, `Final output action plan: 2 action item(s)`, and `not final rendered image proof` in the workspace accessibility value.
- Extended the focused simulated-capture UI route to assert the archive workspace sheet, selected-project row, and per-row export ShareLink all expose the final-output action plan and no-final-rendered-image boundary.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v126-library-workspace-action-plan-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v126-library-workspace-action-plan -derivedDataPath /tmp/bracketer-dd-v126-library-workspace-action-plan -resultBundlePath /tmp/bracketer-v126-library-workspace-action-plan-unit-tests.xcresult`.
  - Result: `result=Passed`, 237 unit tests passed, 0 failed, 0 skipped, total 237, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- Focused UI proof:
  - Result bundle: `/tmp/bracketer-v126-library-workspace-action-plan-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v126-library-workspace-action-plan-ui -derivedDataPath /tmp/bracketer-dd-v126-library-workspace-action-plan-ui -resultBundlePath /tmp/bracketer-v126-library-workspace-action-plan-ui-tests.xcresult`.
  - Result: `result=Passed`, 1 UI test passed, 0 failed, 0 skipped, total 1, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0 (no whitespace errors).
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is archive-workspace metadata/unit/UI proof only. It does not prove final rendered image bytes, Photos byte inspection, RAW decoding, real Files export, or physical iPhone behavior.

### Next slice

- Continue another Wave K/P archive/import invariant or Wave F/G/N review/accessibility invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 17:10 PDT - May Goals final-output action-plan Shortcuts file-provider carry-through v1

### What changed

- `LatestBracketProjectExportFile` now retains `finalOutputActionPlanSummary` as a typed wrapper field alongside archive text and the `IntentFile`.
- `BracketProjectExportFileProvider` sets that field from `BracketProjectExportBundle.finalOutputActionPlanSummary`, preserving the action plan through both latest-project and selected-project Shortcuts export paths.
- `ImportedBracketProjectFile` now retains the imported archive's `finalOutputActionPlanSummary` and includes it in Shortcuts import-result accessibility text, so import file results carry the same next-step metadata as the archive/import model.
- Extended provider tests to assert latest export, selected export, and import file-provider results all carry `Resolve blockers before export` and `Final output action plan: 2 action item(s)` through their typed fields, archive text, or accessibility values.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v125-action-plan-intent-files-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v125-action-plan-intent-files -derivedDataPath /tmp/bracketer-dd-v125-action-plan-intent-files -resultBundlePath /tmp/bracketer-v125-action-plan-intent-files-unit-tests.xcresult`.
  - Result: `result=Passed`, 237 unit tests passed, 0 failed, 0 skipped, total 237, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0 (no whitespace errors).
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is App Intents/file-provider metadata proof only. It does not run a Shortcuts automation, write a real Files export, prove final rendered image bytes, inspect Photos bytes, decode RAW pixels, or prove physical iPhone behavior.

### Next slice

- Continue another Wave K/P archive/import or Wave F/G/N review/accessibility invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 17:03 PDT - May Goals final-output action-plan header validation v1

### What changed

- Added `BracketProjectImportError.finalOutputActionPlanHeaderMismatch` so archive import can distinguish a stale/tampered `Final Output Action Plan` header from generic payload validation failures.
- `BracketProjectImportBundle.parse(...)` now reads the optional header without requiring it for older archives. When present, it must match `BracketProjectFinalOutputReadinessAudit.actionPlanSummary`; if no audit payload exists, only `Unavailable` is accepted.
- `BracketProjectImportPreviewFailure` now reports `final-output-action-plan-header-mismatch` with the recovery suggestion `Export the project again so the final-output action-plan header matches the readiness audit.`
- Extended archive tamper coverage to rewrite only the header line and prove both direct import rejection and no-save import-preview diagnostics.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v124-action-plan-header-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v124-action-plan-header -derivedDataPath /tmp/bracketer-dd-v124-action-plan-header -resultBundlePath /tmp/bracketer-v124-action-plan-header-unit-tests.xcresult`.
  - Result: `result=Passed`, 237 unit tests passed, 0 failed, 0 skipped, total 237, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0 (no whitespace errors).
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This validates archive metadata consistency only. It still does not prove final rendered image bytes, Photos byte inspection, RAW decoding, physical Files export, or physical iPhone behavior.

### Next slice

- Continue another archive/import invariant or review/accessibility invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 16:55 PDT - May Goals final-output action-plan export/archive metadata v1

### What changed

- `BracketProjectExportBundle` now exposes a computed `finalOutputActionPlanSummary` by decoding its existing `final-output-readiness-audit` payload, then carries that summary in the export bundle `accessibilityValue` and the archive header as `Final Output Action Plan: ...`.
- `BracketProjectImportBundle`, `BracketProjectImportPreview`, and `BracketProjectArchiveDocument` now surface the same computed summary, so archive import preview, document validation, and accessibility status carry the action plan without adding new stored Codable fields or changing the audit schema.
- Settings import/export status copy now includes the final-output action plan when a project archive is prepared or imported through the existing FileDocument-backed path.
- The export privacy report now states that the readiness audit contains a computed action plan while preserving the no-final-rendered-bytes, no-Photos-fetch, no-RAW-decode, no-Files-write, and no-physical-proof boundary.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof:
  - Result bundle: `/tmp/bracketer-v123-export-action-plan-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v123-export-action-plan -derivedDataPath /tmp/bracketer-dd-v123-export-action-plan -resultBundlePath /tmp/bracketer-v123-export-action-plan-unit-tests.xcresult`.
  - Result: `result=Passed`, 237 unit tests passed, 0 failed, 0 skipped, total 237, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0 (no whitespace errors).
- Touched-file trailing whitespace scan: no output.

### Current proof boundary

- This is schema-safe archive/import metadata proof only. The action plan remains derived from existing readiness-audit metadata and is explicitly not final rendered image proof, Photos byte inspection, RAW decoding, real Files export proof, or physical iPhone proof.

### Next slice

- Continue another Wave K/P archive/import invariant or Wave F/G/N review/accessibility invariant while the physical iPhone remains unavailable/offline.

## 2026-05-31 16:40 PDT - May Goals VoiceOver traversal action-plan expectation v1

### What changed

- `BracketProjectReviewVoiceOverTraversalSnapshot.make(snapshot:)` now expects the metadata-only action plan in its traversal inventory: the `review.project.finalOutputReadinessAudit` audit probe entry and the visible `review.project.finalOutputs.card` export-card entry each gain `Action plan` and `not final rendered image proof` `expectedValueFragments`.
- These fragments mirror what v120 added to `BracketProjectFinalOutputReadinessAudit.accessibilityValue` (`Action plan: \(actionPlanSummary)`, whose `actionPlanBoundary` ends `it is not final rendered image proof.`) and what v121 appended to the visible `finalOutputCard` accessibility value, so the simulator traversal expectation stays consistent with the surfaces it documents.
- Model-only change: no new Codable stored fields, no UI change. The fragments are plain expectation strings on the existing `Entry` struct; the entry `accessibilityValue` (which joins the fragments) therefore also carries the action-plan and `not final rendered image proof` boundary.
- Extended the focused unit test `bracketProjectReviewVoiceOverTraversalSnapshotOrdersReviewSurface` to assert both entries' `expectedValueFragments` include `Action plan` and `not final rendered image proof`, and that the `review.project.finalOutputs.card` entry `accessibilityValue` carries both fragments.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused unit proof (whole unit target, the reliable Swift Testing path; function-level `-only-testing` selected 0 Swift Testing cases):
  - Result bundle: `/tmp/bracketer-v122-traversal-action-plan-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v122-traversal-action-plan -derivedDataPath /tmp/bracketer-dd-v122-traversal-action-plan -resultBundlePath /tmp/bracketer-v122-traversal-action-plan-unit-tests.xcresult`.
  - Result: `result=Passed`, 237 unit tests passed, 0 failed, 0 skipped, total 237, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check`: exit 0 (no whitespace errors).

### Current proof boundary

- The traversal snapshot is simulator UI-structure/accessibility-value metadata only; it does not run VoiceOver, prove rotor order on hardware, or expose raw photo bytes, Photos identifiers, thumbnails, final rendered output bytes, or precise coordinates.
- The expected action-plan fragments document metadata-only review/export guidance derived from existing audit metadata; they are explicitly **not final rendered image proof** and not physical-device proof.

### Next slice

- Continue another Wave F/G/N review/accessibility invariant (e.g. extend the traversal expectation to other action-plan-bearing surfaces, or surface the action plan in a handoff/export snapshot) while the physical iPhone remains unavailable/offline.

## 2026-05-31 16:26 PDT - May Goals final-output card action-plan visibility v1

### What changed

- `BracketProjectReviewHandoffView.finalOutputCard` (`review.project.finalOutputs.card`) now derives `BracketProjectFinalOutputReadinessAudit.make(manifest:)` next to the existing metadata-only `BracketProjectFinalOutputManifest`, reusing the v120 schema-safe computed action plan with no new Codable stored fields.
- The visible card renders a compact, scannable "Action plan" block: a header row with `audit.statusLabel | <actionPlanStepCount> step(s)` and the first two actionable steps (`audit.actionPlan.dropLast().prefix(2)`) as small lines. No instructional wall of text was added; the card stays scannable.
- The card accessibility value now appends `Action plan: \(audit.actionPlanSummary)` to the manifest accessibility value, so the visible card carries the first action and the `not final rendered image proof` boundary alongside the manifest's metadata-only boundary.
- Extended the focused UI fixture test `testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract` to assert the visible `review.project.finalOutputs.card` value contains `Action plan: 2 action item(s)`, `Resolve blockers before export for 3 blocked output(s)`, `No final rendered bytes`, `without including final rendered image bytes`, and `not final rendered image proof`, while keeping fixture Photos identifiers absent.
- No model helper changed (the audit action-plan helpers shipped in v120), so unit coverage was not modified and BracketerTests was not rerun. README.md and docs/ARCHITECTURE.md already document the action plan and its metadata-only boundary; no doc change was warranted.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Focused UI proof:
  - Result bundle: `/tmp/bracketer-v121-final-output-card-action-plan-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v121-final-output-card-action-plan-ui -derivedDataPath /tmp/bracketer-dd-v121-final-output-card-action-plan-ui -resultBundlePath /tmp/bracketer-v121-final-output-card-action-plan-ui-tests.xcresult`.
  - Result: `result=Passed`, 1 UI test passed, 0 failed, 0 skipped, total 1, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- `git diff --check` → exit 0 (no whitespace errors).

### Proof category

- `simulator-ui-proof`: focused UI test proves the action plan is visible in the selected-project review final-output card (not just the readiness-audit probe value).
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/UI proof for metadata-only final-output action-plan guidance surfaced in the visible review card.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, claim physical proof, or include final rendered image bytes. The visible action plan is explicitly metadata-only and not final rendered image proof.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; strong next targets are adding an archive-readiness/action-plan status to selected-project export surfaces or exposing the action plan in the VoiceOver traversal expected fragments.

### Goal status

- Goal still open. Verified final-output card action-plan visibility complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 16:15 PDT - May Goals final-output readiness audit action plan v1

### What changed

- Added a schema-safe `actionPlan` computed property to `BracketProjectFinalOutputReadinessAudit` in `Bracketer/BracketProject.swift`, derived only from existing audit metadata fields (no new Codable stored fields).
- The plan emits ordered next steps: verify rendered bytes against source exposures when `finalRenderedBytesIncluded`, create a final-output plan when `outputCount == 0`, resolve blockers for the blocked output names plus clear the blocker reasons, generate/attach a preview artifact when unavailable, and a ready-state verification note when nothing is blocking; it always ends with a `not final rendered image proof` boundary line.
- Added `actionPlanStepCount` and `actionPlanSummary`, and surfaced `Action plan: <summary>` inside the audit `accessibilityValue`, so the `review.project.finalOutputReadinessAudit` probe now carries actionable guidance.
- Extended `BracketerTests.bracketProjectFinalOutputReadinessAuditSummarizesMetadataOnlyOutputState` to prove the blocked, ready, missing-plan, and rendered-bytes action plans plus the no-double-period invariant, and extended the focused UI fixture test to assert the action-plan fragments are visible on simulator.
- README.md and docs/ARCHITECTURE.md note the computed action plan and its metadata-only boundary.

### Verification

- Physical device proof: not attempted. No physical iPhone destination change; physical proof remains blocked by the unavailable/offline device.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v120-action-plan-unit-tests-1780269138.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-v120-action-plan-unit-tests-1780269138.xcresult test`.
  - Result: `** TEST SUCCEEDED **`, 237 tests passed, 0 failed, on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS 26.5.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v120-action-plan-ui-tests-1780269240.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-v120-action-plan-ui-tests-1780269240.xcresult test`.
  - Result: `** TEST SUCCEEDED **`, 1 UI test passed, 0 failures, 54.5s.

### Failures encountered and resolved

- First unit run failed one assertion: the blocker-reason action-plan line ended with a double period because each blocker reason already carries a trailing period. Resolved by dropping the extra trailing period in the `Clear N blocker reason(s):` step and adding a `!hasSuffix("..")` invariant assertion.
- Xcode emitted the pre-existing diagnostic-collection `simctl` warning during the successful runs; it did not fail the counted bundles.

### Proof category

- `pure-model-proof`: unit tests prove the action plan is generated for blocked/ready/missing/rendered-bytes states.
- `simulator-ui-proof`: focused UI test proves the action plan is visible in the project-review readiness-audit probe.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit/UI proof for metadata-only final-output readiness action-plan guidance.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior. The action plan is explicitly metadata-only and not final rendered image proof.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; strong next targets are surfacing the action plan in the visible review card (not just the probe value), adding an archive-readiness/action-plan status to selected-project export surfaces, or exposing the action plan in the VoiceOver traversal expected fragments.

### Goal status

- Goal still open. Verified final-output readiness audit action plan complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 16:00 PDT - May Goals final-output readiness audit Settings import-preview visibility v1

### What changed

- Added a UI-test-only Settings import-preview seed for stale `final-output-readiness-audit` payloads through `-ui-testing-preview-final-output-readiness-audit-import-failure`.
- `ModernProjectLibrarySection` now derives a mismatched archive from the latest export bundle by tampering the readiness audit blocker count with a whitespace-tolerant `blockerReasonCount` regex.
- The seeded `settings.projects.importBundle.button` status exposes the preview filename, `final-output-readiness-audit-mismatch`, compact recovery, no-save boundary, and duplicate policy without importing or saving the archive.
- `testSimulatedBracketCaptureCompletesAndOpensReview` now relaunches with the seed flag and proves the restored Settings > About import row surfaces the stale-audit preview state.
- README documents the launch argument for the seeded Settings preview.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only generic `Any iOS Device` and `Any iOS Simulator Device` placeholders.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Focused simulator UI proof:
  - Bundle path: `/tmp/bracketer-v119-final-output-readiness-audit-import-preview-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v119-final-output-readiness-audit-import-preview-ui -derivedDataPath /tmp/bracketer-dd-v119-final-output-readiness-audit-import-preview-ui -resultBundlePath /tmp/bracketer-v119-final-output-readiness-audit-import-preview-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- Initial v119 UI attempts failed because the import-row status was sampled before the seeded mismatch was reliably visible, and then because XCTest's accessibility value truncated the long recovery copy after the failure kind.
- Resolved by keeping the seed success-only, using a whitespace-tolerant blocker-count tamper, adding a wait-for-value-fragment helper, avoiding parser work during SwiftUI body updates, and front-loading compact recovery/no-save/duplicate-policy fragments in the seeded status.
- Ran `claude --dangerously-skip-permissions -p ...` twice in read-only mode during the requested offload window: first to analyze the failing import-row assertion and later to review the deterministic mismatch-status patch. No Claude edits were accepted.
- Xcode still emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundle.

### Proof category

- `simulator-ui-proof`: focused UI test proves Settings > About visibly reports stale final-output readiness audit import-preview failure.
- `no-save-boundary-proof`: the path uses preview-only parsing and reports `No import was saved`.

### Current proof boundary

- This is simulator UI proof for import-preview visibility, backed by the v118 parser/unit validation.
- It does not import a project, render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; strong next targets are archive-readiness status on selected-project export surfaces or deeper final-output readiness explainability.

### Goal status

- Goal still open. Verified final-output readiness audit Settings import-preview visibility complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 14:38 PDT - May Goals final-output readiness audit export/import validation v1

### What changed

- Added `final-output-readiness-audit` to project export bundles beside `final-output-manifest`.
- The readiness audit now participates in archive integrity counts, privacy-report copy, import round trips, duplicate/keep-both conflict resolution, and import-time validation.
- `BracketProjectImportBundle` rejects stale readiness-audit payloads when they no longer match the final-output manifest.
- `BracketProjectImportPreviewFailure` now reports `final-output-readiness-audit-mismatch` with a specific no-save recovery suggestion.
- Unit coverage proves export payload order, redaction, decoded audit values, archive-integrity count, import round trip, privacy report text, stale-audit rejection, and preview-failure copy.
- README and architecture docs now document the archive payload and validation boundary.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only the generic iOS device placeholder in the filtered physical-device output.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v118-final-output-readiness-audit-export-import-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v118-final-output-readiness-audit-export-import-unit -resultBundlePath /tmp/bracketer-v118-final-output-readiness-audit-export-import-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=237`, `failedTests=0`, `skippedTests=0`, `totalTestCount=237`.
  - Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover export/import archive validation for the final-output readiness audit.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit proof for metadata-only final-output readiness audit archive validation.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; a strong next target is exposing import-preview final-output readiness audit mismatch detail in Settings UI or adding a compact archive-readiness status to selected-project export surfaces.

### Goal status

- Goal still open. Verified final-output readiness audit export/import validation complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 14:22 PDT - May Goals final-output readiness audit probe v1

### What changed

- Added `BracketProjectFinalOutputReadinessAudit`, a metadata-only compact export/readiness audit built from `BracketProjectFinalOutputManifest`.
- Exposed it in selected-project review at `review.project.finalOutputReadinessAudit`.
- Added it to `BracketProjectReviewAccessibilityContract`, VoiceOver traversal, and accessibility screenshot matrix.
- Unit coverage proves default blocked output state, injected metadata-ready output, missing-plan state, raw-id redaction, and Codable round trip.
- Focused UI coverage proves the production review fixture exposes the new probe/status/counts/recommendation/boundary text.
- README and architecture docs now mention the readiness audit probe and its metadata-only boundary.
- Used the requested `claude --dangerously-skip-permissions -p ...` offload in read-only mode before the local edit; Claude warned about duplicated probe lists/counts, traversal order, and screenshot matrix membership, all addressed by the verified patch.
- A later read-only Claude bookkeeping audit was launched with the requested flag but hung silently; the single Bracketer Claude process was killed after producing no output, and no file changes were accepted from it.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only the generic iOS device placeholder in the filtered physical-device output.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v117-final-output-readiness-audit-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v117-final-output-readiness-audit-unit -resultBundlePath /tmp/bracketer-v117-final-output-readiness-audit-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=237`, `failedTests=0`, `skippedTests=0`, `totalTestCount=237`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v117-final-output-readiness-audit-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v117-final-output-readiness-audit-ui -derivedDataPath /tmp/bracketer-dd-v117-final-output-readiness-audit-ui -resultBundlePath /tmp/bracketer-v117-final-output-readiness-audit-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundles.
- The second Claude read-only bookkeeping audit hung without output and was terminated; it did not affect the repo.

### Proof category

- `pure-model-proof`: unit tests cover default blocked output state, injected metadata-ready output, missing-plan state, accessibility text, raw-id redaction, and Codable round trip.
- `simulator-ui-proof`: focused UI test proves the production final-output readiness audit probe exposes status/counts/recommendation/boundary detail.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit/UI proof for metadata-only final-output readiness audit explainability.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; a strong next target is import-preview/export audit context for final-output readiness.

### Goal status

- Goal still open. Verified final-output readiness audit probe complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 14:06 PDT - May Goals final-output handoff recommendation detail v1

### What changed

- Expanded `BracketProjectFinalOutputManifest.accessibilityValue` with per-output recommendation lines in plan order.
- The structured `review.project.finalOutputs` handoff probe and visible `review.project.finalOutputs.card` now speak `<n> recommendations` and `Recommendations: ...` beside ready/blocked names, resource-pair count, preview-artifact availability, readiness summary, and no-final-rendered-bytes boundary text.
- Added unit assertions that the final-output manifest accessibility value exposes recommendation count, the tone-mapped review JPEG recommendation, and the HDR HEIF master recommendation text.
- Added focused UI assertions proving the production final-output handoff probe exposes recommendation count/detail and the preview recommendation text.
- Closed the docs/code consistency gap created while documenting v115: README and architecture docs already promised per-output recommendations at the final-output handoff level, and v116 now makes that true.
- Used the requested `claude --dangerously-skip-permissions -p ...` offload in read-only mode to audit the v116 handoff consistency target after the local edit landed.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only the generic iOS device placeholder in the filtered physical-device output.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v116-final-output-handoff-recommendation-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v116-final-output-handoff-recommendation-detail-unit -resultBundlePath /tmp/bracketer-v116-final-output-handoff-recommendation-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=236`, `failedTests=0`, `skippedTests=0`, `totalTestCount=236`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v116-final-output-handoff-recommendation-detail-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v116-final-output-handoff-recommendation-detail-ui -derivedDataPath /tmp/bracketer-dd-v116-final-output-handoff-recommendation-detail-ui -resultBundlePath /tmp/bracketer-v116-final-output-handoff-recommendation-detail-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover recommendation lines on the final-output manifest accessibility value.
- `simulator-ui-proof`: focused UI test proves the production final-output handoff probe exposes recommendation detail.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit/UI proof for metadata-only final-output handoff recommendation explainability.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; a strong next target is a compact export/readiness audit row that summarizes final-output readiness, blockers, and recommendations without claiming rendered output.

### Goal status

- Goal still open. Verified final-output handoff recommendation detail complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 13:54 PDT - May Goals final-workspace final-output recommendation detail v1

### What changed

- Added `finalOutputRecommendations` to `BracketProjectFinalReviewWorkspaceFixtureReport`, sourced from every `BracketProjectFinalOutputManifest.outputs` entry in plan order as `<displayName>: <recommendation>`.
- Updated the final-workspace accessibility value to expose recommendation count and recommendation detail beside final-output readiness and blocker evidence.
- Added a final-output recommendation checklist line that distinguishes missing final-output plans from present recommendation coverage without making recommendations count as rendered-output or physical-export proof.
- Extended unit coverage for:
  - default all-blocked final-output plans exposing all three recommendations
  - an injected all-blocked manifest exposing a single recommendation
  - an injected mixed ready/blocked manifest preserving both recommendations in output order
  - an injected missing-output manifest exposing no recommendations plus explicit missing-plan copy
  - Codable round trip preserving the new field
- Extended focused UI coverage proving `review.project.finalWorkspace.fixture` exposes the recommendation count/detail and the tone-mapped review JPEG recommendation text.
- Updated README and architecture docs with final-output recommendation detail at the final-workspace and final-output handoff levels.
- Used the requested `claude --dangerously-skip-permissions -p ...` offload in read-only mode to audit the v115 invariant; it caught that recommendation lines should map every output in order, not a filtered or deduped subset.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only the generic iOS device placeholder in the filtered physical-device output.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v115-final-output-recommendation-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v115-final-output-recommendation-detail-unit -resultBundlePath /tmp/bracketer-v115-final-output-recommendation-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=236`, `failedTests=0`, `skippedTests=0`, `totalTestCount=236`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v115-final-output-recommendation-detail-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v115-final-output-recommendation-detail-ui -derivedDataPath /tmp/bracketer-dd-v115-final-output-recommendation-detail-ui -resultBundlePath /tmp/bracketer-v115-final-output-recommendation-detail-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover final-output recommendation lines, default/injected/mixed/missing manifests, checklist text, accessibility text, and Codable round trip.
- `simulator-ui-proof`: focused UI test proves the production final-workspace fixture exposes recommendation detail.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit/UI proof for metadata-only final-output recommendation explainability.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; a strong next target is exposing final-output readiness/recommendation detail through a compact export/readiness audit row or making archive-import preview failures speak final-output recommendation mismatch context.

### Goal status

- Goal still open. Verified final-workspace final-output recommendation detail complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 13:39 PDT - May Goals final-output handoff readiness detail v1

### What changed

- Expanded `BracketProjectFinalOutputManifest.accessibilityValue` so the structured `review.project.finalOutputs` handoff and visible final-output card now speak complete resource-pair count, preview-artifact availability, ready output names, blocked output names, and readiness summary directly.
- Added unit assertions that the final-output manifest accessibility value contains source exposure count, complete resource-pair count, preview availability, ready-output names, blocked-output names, readiness summary, and no-final-rendered-byte boundary text.
- Added focused UI assertions proving the production `review.project.finalOutputs` probe exposes the same final-output readiness detail.
- Tightened README and architecture final-output handoff notes so the docs name complete resource-pair count, preview-artifact availability, readiness summary, and blocker detail at the narrower final-output probe level.
- Used the requested `claude --dangerously-skip-permissions -p ...` offload in read-only mode to scout the next pure-model/UI readiness-explainability slice; Codex kept the final repo edits and verification local.

### Verification

- Physical device host probe:
  - A first unpinned `xcrun devicectl` / `xcrun xctrace` probe used the wrong developer-tool lookup and failed to find those utilities.
  - Rerunning with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only the generic iOS device placeholder plus simulators.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v114-final-output-handoff-readiness-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v114-final-output-handoff-readiness-detail-unit -resultBundlePath /tmp/bracketer-v114-final-output-handoff-readiness-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=236`, `failedTests=0`, `skippedTests=0`, `totalTestCount=236`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v114-final-output-handoff-readiness-detail-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v114-final-output-handoff-readiness-detail-ui -derivedDataPath /tmp/bracketer-dd-v114-final-output-handoff-readiness-detail-ui -resultBundlePath /tmp/bracketer-v114-final-output-handoff-readiness-detail-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The first v114 unit run failed because `BracketProjectFinalOutputManifest.accessibilityValue` gained local bindings but lacked the explicit `return` required by Swift computed properties with statement bodies. Added the return and reran the same unit proof successfully.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover final-output handoff accessibility detail for source exposure count, complete resource-pair count, preview-artifact availability, ready/blocked names, readiness summary, and no-final-rendered-byte boundaries.
- `simulator-ui-proof`: focused UI test proves the production final-output handoff probe exposes the new readiness detail.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit/UI proof for metadata-only final-output handoff explainability.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Continue another pure-model/UI invariant while the physical iPhone remains unavailable/offline; Claude's read-only scout suggested final-workspace final-output recommendation detail as a good next explainability target.

### Goal status

- Goal still open. Verified final-output handoff readiness detail complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 13:24 PDT - May Goals final-workspace final-output readiness detail v1

### What changed

- Extended `BracketProjectFinalReviewWorkspaceFixtureReport` with ready final-output counts/names, final-output source exposure count, complete resource-pair count, preview-artifact availability, and the final-output manifest readiness summary.
- Updated the final-workspace accessibility value and checklist to speak ready outputs, blocked outputs, source/resource counts, preview availability, readiness summary, and blocker detail together.
- Added unit coverage for:
  - the default all-blocked final-output manifest carrying zero ready names plus source/resource/preview/readiness facts
  - an injected all-blocked manifest preserving those readiness facts
  - an injected mixed ready/blocked manifest proving ready names and blocked names can coexist without pretending final rendered bytes exist
- Added focused UI coverage proving `review.project.finalWorkspace.fixture` exposes the new readiness detail in the production review accessibility fixture.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the final-output readiness detail boundary.
- Tightened the narrower final-output handoff docs after the Claude read-only audit flagged that the final-output manifest paragraph did not yet name complete resource-pair count, preview-artifact availability, and readiness summary.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` reported `Physical iPhone (26.5)` under `Devices Offline`.
  - `xcodebuild -showdestinations` did not list the actual physical iPhone destination, only the generic iOS device placeholder plus simulators.
  - No physical proof was attempted or counted because the physical destination was unavailable/offline.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v113-final-output-readiness-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v113-final-output-readiness-detail-unit -resultBundlePath /tmp/bracketer-v113-final-output-readiness-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=236`, `failedTests=0`, `skippedTests=0`, `totalTestCount=236`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v113-final-output-readiness-detail-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v113-final-output-readiness-detail-ui -derivedDataPath /tmp/bracketer-dd-v113-final-output-readiness-detail-ui -resultBundlePath /tmp/bracketer-v113-final-output-readiness-detail-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI DebuggerLLDB `no debugger version` warning during successful verification; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover ready output names/counts, all-blocked and mixed ready/blocked final-output manifests, source exposure/resource-pair counts, preview-artifact availability, readiness summaries, blocker detail, Codable round trip, and no-final-rendered-bytes boundaries.
- `simulator-ui-proof`: focused UI test proves the production final-workspace fixture exposes final-output readiness details.
- `blocked-proof`: physical iPhone proof remains blocked by unavailable/offline host state.

### Current proof boundary

- This is simulator/unit/UI proof for metadata-only final-output readiness explainability.
- It does not render final HDR output, tone-map user assets, read Photos bytes, decode RAW pixels, write Files exports, authenticate a physical device, or prove physical-device behavior.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Unlock/restore the physical iPhone and rerun a focused real-device proof, or continue another pure-model/UI invariant that improves review/export explainability without pretending simulator evidence is physical proof.

### Goal status

- Goal still open. Verified final-output readiness detail complete. Physical proof remains blocked by unavailable/offline device.

## 2026-05-31 13:08 PDT - May Goals multi-locked xcodebuild destination enumeration v1

### What changed

- Added `BracketerHostDeviceAvailabilityReport.allRegexCaptures(...)` so xcodebuild locked-preflight parsing can enumerate every `platform=iOS,id=...` destination id in a single log.
- Changed locked xcodebuild parsing from a single collapsed locked row to one distinct redacted locked row per unique physical iPhone destination id.
- Kept the anonymous `device-redacted-none` fallback for locked xcodebuild logs that have iPhone-specific lock evidence but no visible destination id.
- Applied the iPad non-counting guard to the `Unlock Physical iPhone to Continue` branch as well as generic `device is locked` evidence.
- Added unit coverage for two locked iPhone destination ids, distinct hashed rows, raw-id redaction, Codable round trip, and a malformed iPad unlock-phrase log that must not count as iPhone proof.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the multi-locked destination enumeration boundary.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v112-multiple-locked-xcodebuild-devices-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v112-multiple-locked-xcodebuild-devices-unit -resultBundlePath /tmp/bracketer-v112-multiple-locked-xcodebuild-devices-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=236`, `failedTests=0`, `skippedTests=0`, `totalTestCount=236`.
  - Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No new implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning during the successful simulator unit run; it did not fail the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover multiple locked xcodebuild iPhone destinations, distinct redacted ids, JSON round trip, raw-id redaction, duplicate-row prevention, and iPad non-counting for the unlock-phrase branch.

### Current proof boundary

- This is simulator/unit parser proof for host-readiness text only.
- It does not prove physical iPhone launch, real device unlock, camera capture, Photos access, Files/Shortcuts/Spotlight round trips, or accepted physical proof ingestion.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Unlock the physical iPhone and rerun a focused real-device proof, or continue another pure-model/UI invariant that improves review/export explainability without pretending simulator evidence is physical proof.

### Goal status

- Goal still open. Verified parser hardening complete. Physical proof remains blocked by locked device.

## 2026-05-31 13:03 PDT - May Goals locked host-device availability import-preview UI parity v1

### What changed

- Added `-ui-testing-preview-locked-device-availability-report`, a deterministic UI-test fixture that seeds Settings > About with a locked xcodebuild host-device availability import preview.
- The seeded row still routes through `BracketerHostDeviceAvailabilityReport.parse(...)`, reports xcodebuild source, reports `1 locked`, redacts the raw physical destination id, and repeats the no-runbook/no-result-bundle-index/no-proof-count boundary.
- Added focused UI coverage for `settings.deviceProof.deviceAvailabilityReportImportPreview` proving the visible row surfaces `Blocked: physical iPhone is locked`, `Unlock the iPhone before running the physical lab`, no-mutation language, and no raw UDID leakage.
- Updated README and architecture docs with the launch fixture, locked-over-available precedence, and locked iPad non-counting boundary.

### Verification

- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v111-device-availability-locked-preview-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testDeviceAvailabilityReportPreviewShowsLockedXcodebuildVerdictFromLaunchFixture -skip-testing:BracketerTests -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v111-device-availability-locked-preview-ui -derivedDataPath /tmp/bracketer-dd-v111-device-availability-locked-preview-ui -resultBundlePath /tmp/bracketer-v111-device-availability-locked-preview-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No new implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and the UI DebuggerLLDB `no debugger version` warning during the successful focused UI run; neither failed the counted bundle.

### Proof category

- `simulator-ui-proof`: focused UI test proves the Settings import-preview row exposes the locked xcodebuild verdict, import-preview no-mutation wording, destination-id redaction, and no-proof boundary.

### Current proof boundary

- This is simulator UI proof with a launch fixture.
- It does not exercise the real file picker, authenticate or unlock the physical iPhone, launch tests on the physical device, inspect Photos assets, or count physical proof.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Either unlock the physical iPhone and rerun a focused real-device proof, or continue host-report parser hardening by enumerating multiple locked physical iPhone destination ids from one log.

### Goal status

- Goal still open. Verified UI parity complete. Physical proof remains blocked by locked device.

## 2026-05-31 12:54 PDT - May Goals host-device locked-preflight hardening v1

### What changed

- Tightened `BracketerHostDeviceAvailabilityReport.parseXcodebuildDevices(_:)` so locked xcodebuild preflight output creates a locked physical-iPhone row only when the lock evidence is iPhone-specific.
- Prevented generic locked iPad preflight text from being counted as a physical iPhone row or proof-adjacent host readiness.
- Added mixed xcodebuild report coverage proving a locked physical iPhone preflight takes lab-readiness priority even when another physical iPhone destination row is available.
- Extended locked-preflight coverage with Codable round-trip and raw destination-id redaction assertions.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the iPhone-specific locked preflight guardrail.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v110-host-device-locked-preflight-hardening-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v110-host-device-locked-preflight-hardening-unit -resultBundlePath /tmp/bracketer-v110-host-device-locked-preflight-hardening-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=234`, `failedTests=0`, `skippedTests=0`, `totalTestCount=234`.
  - Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No new implementation failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning during the successful simulator unit run; it did not fail the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover iPhone-specific locked evidence, generic iPad lock non-counting, mixed locked/available readiness priority, JSON round trip, and raw destination-id redaction.

### Current proof boundary

- This is simulator/unit parser proof for host-readiness text only.
- It does not prove physical iPhone launch, camera capture, Photos writes, Files/Shortcuts/Spotlight round trips, VoiceOver hardware behavior, or accepted physical proof ingestion.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- Add UI parity for the host-availability import-preview row by previewing a locked xcodebuild report through Settings and asserting the visible locked verdict, or unlock the physical iPhone and rerun a focused real-device proof.

### Goal status

- Goal still open. Verified parser hardening complete. Physical proof remains blocked by locked device.

## 2026-05-31 12:49 PDT - May Goals host-device xcodebuild/preflight availability coverage v1

### What changed

- Extended `BracketerHostDeviceAvailabilityReport` with `Source.xcodebuild` for reviewer-supplied `xcodebuild -showdestinations` and run-destination-preflight logs.
- Added a `locked` availability state, locked physical iPhone counts, locked-device summary wording, and a lab-readiness verdict that prioritizes `Unlock the iPhone before running the physical lab`.
- Taught the host-device parser to:
  - detect xcodebuild destination lists and locked run-destination preflight logs
  - ignore simulator destination rows
  - hash raw physical device ids before exposing row identifiers
  - treat `"Unlock Physical iPhone to Continue"` / locked-device preflight output as a redacted locked physical-iPhone row
- Added unit coverage for xcodebuild physical-destination parsing, simulator-row exclusion, raw-UDID redaction, locked-preflight parsing, and no physical proof count changes.
- Updated README, architecture notes, and `.codex-maygoals-progress.md` with the xcodebuild/preflight host report surface and locked-device proof boundary.

### Verification

- Physical device host probe:
  - `xcrun devicectl list devices` reported the paired `Physical iPhone` as available, model `iPhone 17 Pro Max (iPhone18,2)`.
  - `xcrun xctrace list devices` still listed `Physical iPhone (26.5) (00008150-00027C3E0108401C)` under `Devices Offline`.
  - `xcodebuild -showdestinations` exposed `{ platform:iOS, arch:arm64, id:00008150-00027C3E0108401C, name:Physical iPhone }`.
  - Focused physical-device `xcodebuild test` reached run-destination preflight but blocked with `"Unlock Physical iPhone to Continue"` / `Xcode cannot launch BracketerTests on Physical iPhone because the device is locked`.
  - The interrupted physical-device run was terminated and produced no readable physical proof bundle.
- Unit proof:
  - Bundle path: `/tmp/bracketer-v109-host-device-xcodebuild-preflight-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v109-host-device-xcodebuild-preflight-unit -resultBundlePath /tmp/bracketer-v109-host-device-xcodebuild-preflight-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=232`, `failedTests=0`, `skippedTests=0`, `totalTestCount=232`.
  - Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The physical-device test attempt did not fail the simulator/unit proof; it was an honest host-readiness probe that stopped at Xcode's locked-device preflight.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning during the successful simulator unit run; it did not fail the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover xcodebuild destination parsing, simulator-row exclusion, locked preflight parsing, UDID redaction, locked lab-readiness wording, and no physical proof count changes.
- `local-sdk-proof`: local Xcode/CoreDevice discovery sees the physical iPhone destination, but that only proves host readiness.
- `blocked-proof`: physical proof remains blocked because the connected real iPhone is locked, so Xcode cannot launch tests on it.

### Current proof boundary

- Host availability reports, destination lists, and locked-device preflight output do not count as physical iPhone capture proof.
- Simulator parser tests do not prove camera capture, Photos writes, Files/Shortcuts/Spotlight round trips, VoiceOver hardware behavior, or accepted physical proof ingestion.
- The physical proof accepted count remains `0 of 8`.

### Next slice

- After the iPhone is unlocked, rerun a focused real-device proof and promote exactly one physical capture matrix scenario only if the run produces a readable physical `.xcresult`, scenario-bound hashes, fresh capturedAt evidence, and lab attachments.
- While locked, continue pure-model/simulator hardening around review/export audit coverage or final-output readiness explainability.

### Goal status

- Goal still open. Verified parser wave complete. Physical proof remains blocked by locked device.

## 2026-05-31 12:32 PDT - May Goals project import-preview failure detail coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions -p ...` as a read-only v108 scout. It independently identified the success-only `BracketProjectImportPreview` gap and recommended a structured rejected-preview projection.
- Added `BracketProjectImportPreviewFailure`, a no-save negative preview model with stable failure kind, localized error detail, recovery suggestion, selected duplicate policy, mutation summary, and an explicit no-import/no-store-mutation/no-failed-archive-persistence boundary.
- Added `FileBracketProjectStore.importPreviewFailure(...)`, returning `nil` for previewable archives and a structured failure for thrown import-preview parse/validation errors.
- Updated the Settings project-import catch path to report the structured failure accessibility value instead of a generic `Import failed` string.
- Extended unit coverage to prove invalid archive headers, missing manifest payloads, and byte-count mismatches produce explicit preview failure detail while leaving the project store empty.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the negative import-preview failure surface and proof boundary.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v108-import-preview-failure-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v108-import-preview-failure-detail-unit -resultBundlePath /tmp/bracketer-v108-import-preview-failure-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning during the successful unit run; it did not fail the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover invalid-header, missing-payload, and byte-count-mismatch import-preview failure details, no-save store behavior, duplicate-policy detail, recovery suggestions, and Settings-facing accessibility text.
- `ui-compile-proof`: the Settings import failure path builds against `BracketProjectImportPreviewFailure`; no separate UI run was needed because the slice adds no new visible control or accessibility identifier.

### Current proof boundary

- This is simulator/unit model proof for import-preview rejection explainability.
- It does not prove real user file selection, physical Files document import, Photos-byte inspection, RAW decoding, final rendering, VoiceOver runtime behavior, or physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, especially broader review/export audit coverage, deeper final-output readiness explainability, or physical proof once the real iPhone is available.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 12:23 PDT - May Goals final-workspace final-output blocker detail coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions -p ...` for the v107 slice. It produced an initial blocker-name/reason edit but stayed silent without running verification, so the local supervisor stopped it, tightened the fixture surface, and ran the proof commands directly.
- Added blocked final-output plan names, total blocker reason count, unique blocker reasons, and per-plan blocker summaries to `BracketProjectFinalReviewWorkspaceFixtureReport`.
- Updated final-workspace accessibility output so it speaks blocked output names, blocker reason count, unique blocker reasons, and concrete `Output name: reason; reason` summaries.
- Added checklist text that distinguishes missing final-output plans from present blocked final-output plans, including blocked plan count, total blocker reason count, and blocked plan names.
- Extended unit coverage to prove the default manifest exposes concrete blocker names/reasons, inject a custom one-plan/two-blocker manifest to prove blocker detail is detail-only and does not fail the final workspace by itself, and keep missing-plan/unexpected-rendered-byte proof intact.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the final-output blocker-detail proof boundary.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v107-final-output-blocker-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v107-final-output-blocker-detail-unit -resultBundlePath /tmp/bracketer-v107-final-output-blocker-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v107-final-output-blocker-detail-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v107-final-output-blocker-detail-ui -derivedDataPath /tmp/bracketer-dd-v107-final-output-blocker-detail-ui -resultBundlePath /tmp/bracketer-v107-final-output-blocker-detail-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The Claude offload did not complete or print a report; it was stopped after making a partial edit with no test process running.
- `xcrun xcresulttool ...` failed once without `DEVELOPER_DIR`; rerunning with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` produced the counted result summaries.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default final-output blocker names, unique blocker reasons, total blocker reason count, per-plan blocker summaries, injected one-plan/two-blocker detail, missing-plan fallback, unexpected final rendered byte non-regression, and sibling merge/export/comparison/archive non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the final-output blocker-detail additions.

### Current proof boundary

- This is simulator/unit model proof for metadata-only final-output blocker explainability.
- It does not prove Photos-byte inspection, RAW decoding, tone mapping, final rendered output, Files export, VoiceOver runtime behavior, or physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, especially import-preview negative fixture detail, broader review/export audit coverage, or deeper final-output readiness explainability.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 12:02 PDT - May Goals final-workspace ghosting/moving-mask injection coverage v1

### What changed

- Added `ghostingRisk injectedGhostingRisk: BracketProjectGhostingRiskReport? = nil` and `movingRegionMask injectedMovingRegionMask: BracketProjectMovingRegionMaskReport? = nil` to `BracketProjectFinalReviewWorkspaceFixtureReport.make(...)` while keeping production callers on the default deterministic reports.
- Added ghosting-risk guide count, high-risk shot count, max synthetic ghosting score, moving-region mask guide count, high-priority mask count, and max synthetic mask coverage to the final-workspace Codable/accessibility surface.
- Tightened the final-workspace completeness gate so the ghosting-risk and moving-region mask reports must both contain guidance and one guide per review shot.
- Added checklist text for healthy ghosting/mask guidance and explicit follow-up wording for zero-guide ghosting or zero-guide moving-region mask fixtures.
- Extended unit coverage to prove explicit default ghosting/mask reports preserve the final workspace, while injected zero-guide reports force follow-up and speak the required diagnostic-family failure detail without regressing merge-readiness/export/comparison/archive sibling scopes.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the ghosting/mask injection coverage and proof boundaries.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v106-final-workspace-ghosting-mask-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v106-final-workspace-ghosting-mask-unit -resultBundlePath /tmp/bracketer-v106-final-workspace-ghosting-mask-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v106-final-workspace-ghosting-mask-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v106-final-workspace-ghosting-mask-ui -derivedDataPath /tmp/bracketer-dd-v106-final-workspace-ghosting-mask-ui -resultBundlePath /tmp/bracketer-v106-final-workspace-ghosting-mask-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default ghosting/mask equivalence, zero-guide ghosting follow-up, zero-guide moving-region mask follow-up, diagnostic-family failure detail, and sibling merge/export/comparison/archive non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the ghosting/mask injection additions.

### Current proof boundary

- This is simulator/unit model proof for synthetic ghosting/mask fixture coverage.
- It does not prove optical flow, subject segmentation, real deghosting masks, Photos-byte inspection, RAW decoding, final rendering, VoiceOver runtime behavior, or physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, especially final-output blocker detail, import-preview negative fixture detail, or broader review/export audit coverage.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 11:48 PDT - May Goals final-workspace archive-integrity injection coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions` for a read-only v105 inspection pass; it flagged the heavy-export trap if the review fixture default path constructed `BracketProjectExportBundle`.
- Added `archiveIntegrity injectedArchiveIntegrity: BracketProjectArchiveIntegrityManifest? = nil` to `BracketProjectFinalReviewWorkspaceFixtureReport.make(...)` while keeping the default review/UI path archive-free and complete.
- Added archive-integrity payload count, item count, valid digest count, invalid digest count, total byte count, and `isArchiveIntegrityVerified` to the final-workspace Codable/accessibility surface.
- Added checklist text for the default unattached archive-integrity fixture, valid injected archive manifests, and broken injected manifests.
- Extended unit coverage to decode a real archive-integrity manifest from `BracketProjectExportBundle.make(...)`, inject it into the final workspace report, prove matching counts/digest verification and completion, then inject a broken non-SHA manifest and prove final-workspace follow-up without regressing merge-readiness/export/comparison sibling scopes.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with archive-integrity injection coverage and proof boundaries.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v105-final-workspace-archive-integrity-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v105-final-workspace-archive-integrity-unit -resultBundlePath /tmp/bracketer-v105-final-workspace-archive-integrity-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v105-final-workspace-archive-integrity-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v105-final-workspace-archive-integrity-ui -derivedDataPath /tmp/bracketer-dd-v105-final-workspace-archive-integrity-ui -resultBundlePath /tmp/bracketer-v105-final-workspace-archive-integrity-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both final result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- First v105 unit run failed because the fixture compared a metadata-only export manifest's redacted project id with the live snapshot project id. The archive-integrity gate now checks payload count, item count, SHA-256 digest shape, invalid digest count, and self-reference exclusion without rejecting metadata-only project-id redaction.
- First v105 focused UI run failed with `Failed to get matching snapshots: Timed out while evaluating UI query`; the immediate rerun with the same command and result-bundle path passed, so the final receipt treats that first failure as a simulator/UI-query flake.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default no-archive completeness, real injected archive-integrity counts/digest verification, broken archive-integrity follow-up, and sibling merge/export/comparison non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` without constructing archive export payloads in the review path.

### Current proof boundary

- This is simulator/unit proof for archive-integrity fixture explainability.
- It does not prove real filesystem export, physical Files document import, Photos-byte inspection, RAW decoding, final rendering, VoiceOver runtime behavior, or physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary. A post-v105 Claude scout recommended final-workspace ghosting-risk / moving-region-mask injection coverage as a small v106 candidate.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 11:24 PDT - May Goals final-workspace merge-readiness evidence detail coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions` for a read-only v104 inspection pass; it independently identified that v103 exposed merge-readiness blocker/caution counts but not the underlying evidence detail at the final-workspace boundary.
- Added `mergeReadinessEvidenceCount`, `mergeReadinessBlockerEvidenceTitles`, `mergeReadinessCautionEvidenceTitles`, and `mergeReadinessRecommendationCount` to `BracketProjectFinalReviewWorkspaceFixtureReport`.
- Updated the final-workspace accessibility value so merge-readiness evidence row counts, blocker titles, caution titles, and recommendation counts are spoken beside the existing merge-readiness score/count line.
- Expanded the merge-readiness checklist line so ready reports keep the existing ready prefix with evidence row count, while blocked reports append blocker titles, caution titles, and recommendations after the existing follow-up prefix.
- Extended unit coverage so the default ready fixture proves empty blocker/caution title lists, and an injected blocked report proves one blocker, two caution titles, three recommendations, checklist detail wording, and sibling export/comparison/tap-target non-regression.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the merge-readiness evidence-detail surface and verification receipts.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v104-final-workspace-merge-readiness-evidence-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v104-final-workspace-merge-readiness-evidence-unit -resultBundlePath /tmp/bracketer-v104-final-workspace-merge-readiness-evidence-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v104-final-workspace-merge-readiness-evidence-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v104-final-workspace-merge-readiness-evidence-ui -derivedDataPath /tmp/bracketer-dd-v104-final-workspace-merge-readiness-evidence-ui -resultBundlePath /tmp/bracketer-v104-final-workspace-merge-readiness-evidence-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover ready merge-readiness evidence counts, empty blocker/caution title lists for the passing fixture, injected blocker/caution evidence titles, recommendation count, checklist detail wording, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the merge-readiness evidence-detail additions.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture explainability.
- It does not prove real merge science, Photos-byte inspection, RAW decoding, alignment, ghosting, tone mapping, final rendering, VoiceOver runtime behavior, or physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, especially deeper final-workspace negative fixtures for archive/import integrity or broader review/export audit coverage.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 11:08 PDT - May Goals final-workspace merge-readiness gate coverage v1

### What changed

- Updated `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:alignmentDiagnosticBreakdowns:finalOutputs:assetResources:imageBundle:exposureComparison:pixelComparison:accessibilityContract:traversalSnapshot:mergeReadiness:)` so unit fixtures can inject a custom `BracketProjectMergeReadinessReport` while production callers keep the default merge-readiness report.
- Added merge-readiness score, blocker count, and caution count to the final-workspace Codable/accessibility surface.
- Tightened the final-workspace completeness gate so it requires merge-readiness score `>= 85` and zero blockers before reporting complete.
- Added unit coverage proving an explicit default merge-readiness report produces the same report as the implicit default path.
- Added unit coverage proving a blocked merge-readiness report makes the final workspace report follow-up required, speaks score/blocker/caution counts, keeps export/comparison surfaces complete, and keeps review/export tap targets complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the merge-readiness gate and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v103-final-workspace-merge-readiness-gate-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v103-final-workspace-merge-readiness-gate-unit -resultBundlePath /tmp/bracketer-v103-final-workspace-merge-readiness-gate-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v103-final-workspace-merge-readiness-gate-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v103-final-workspace-merge-readiness-gate-ui -derivedDataPath /tmp/bracketer-dd-v103-final-workspace-merge-readiness-gate-ui -resultBundlePath /tmp/bracketer-v103-final-workspace-merge-readiness-gate-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default merge-readiness equivalence, blocked merge-readiness final-workspace failure, score/blocker/caution accessibility wording, completion-gate behavior, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the merge-readiness gate and count additions.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not prove real merge science, Photos-byte inspection, RAW decoding, alignment, ghosting, tone mapping, final rendering, VoiceOver runtime behavior, or physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or deepen final-workspace negative fixtures for archive/import integrity.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 10:53 PDT - May Goals final-workspace contract privacy detail coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions` for a read-only v102 checklist inspection pass, then applied the verified local patch here.
- Updated `BracketProjectFinalReviewWorkspaceFixtureReport` so failed accessibility contracts speak detailed checklist reasons for missing required probes, missing navigation controls, undersized tap targets, disabled raw-photo-byte redaction, and disabled Photos-identifier redaction while preserving the generic `Workspace accessibility contract needs follow-up.` prefix.
- Added unit coverage proving an injected raw-photo-byte redaction failure makes the final workspace report follow-up required, speaks `raw photo byte redaction needs follow-up`, and does not claim Photos identifier redaction failed.
- Added unit coverage proving an injected Photos-identifier redaction failure makes the final workspace report follow-up required, speaks `Photos asset identifier redaction needs follow-up`, and does not claim raw-photo-byte redaction failed.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the privacy-detail checklist wording and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v102-final-workspace-contract-privacy-detail-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v102-final-workspace-contract-privacy-detail-unit -resultBundlePath /tmp/bracketer-v102-final-workspace-contract-privacy-detail-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v102-final-workspace-contract-privacy-detail-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v102-final-workspace-contract-privacy-detail-ui -derivedDataPath /tmp/bracketer-dd-v102-final-workspace-contract-privacy-detail-ui -resultBundlePath /tmp/bracketer-v102-final-workspace-contract-privacy-detail-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover privacy-specific accessibility contract failures for raw-photo-byte redaction and Photos-identifier redaction, exact checklist detail wording, generic follow-up prefix compatibility, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the detailed contract checklist line.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not prove VoiceOver runtime behavior, physical-device accessibility, Photos-byte inspection, RAW decoding, final rendering, or professional output readiness.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or deepen final-workspace negative fixtures for archive/import integrity.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 10:41 PDT - May Goals final-workspace accessibility-contract/traversal failure coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions` for a read-only v101 model/test inspection pass, then applied the verified local patch here.
- Updated `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:alignmentDiagnosticBreakdowns:finalOutputs:assetResources:imageBundle:exposureComparison:pixelComparison:accessibilityContract:traversalSnapshot:)` so unit fixtures can inject accessibility contracts and traversal snapshots while production callers keep the default contract/traversal factories.
- Added unit coverage proving explicit default accessibility contract and traversal snapshot reports produce the same report as the implicit default path.
- Added unit coverage proving an undersized accessibility contract makes the final workspace report follow-up required while required probes, split handoff/card pairs, traversal entries, and review/export tap targets remain otherwise complete.
- Added unit coverage proving a reduced required-probe contract makes the final workspace report follow-up required, lowers required probe count to 2, and lowers split handoff/card pairs to 0.
- Added unit coverage proving a one-entry incomplete traversal snapshot makes the final workspace report follow-up required, records `traversalEntryCount == 1`, and keeps the workspace accessibility contract plus review/export tap targets complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the injected accessibility-contract/traversal fixture seam and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v101-final-workspace-contract-traversal-failure-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v101-final-workspace-contract-traversal-failure-unit -resultBundlePath /tmp/bracketer-v101-final-workspace-contract-traversal-failure-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v101-final-workspace-contract-traversal-failure-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v101-final-workspace-contract-traversal-failure-ui -derivedDataPath /tmp/bracketer-dd-v101-final-workspace-contract-traversal-failure-ui -resultBundlePath /tmp/bracketer-v101-final-workspace-contract-traversal-failure-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default accessibility contract/traversal equivalence, undersized accessibility contract failure, reduced required-probe/split handoff failure, incomplete traversal failure, checklist wording, required-probe and split-pair counts, traversal-entry counts, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the injected contract/traversal seam.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not prove VoiceOver runtime behavior, physical-device accessibility, Photos-byte inspection, RAW decoding, real Photos-backed comparison, final rendering, or professional output readiness.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or deepen final-workspace negative fixtures for archive/import integrity.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 10:26 PDT - May Goals final-workspace export/comparison surface failure coverage v1

### What changed

- Invoked Claude with `claude --dangerously-skip-permissions` for a read-only v100 model/test inspection pass, then applied the verified local patch here.
- Updated `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:alignmentDiagnosticBreakdowns:finalOutputs:assetResources:imageBundle:exposureComparison:pixelComparison:)` so unit fixtures can inject asset-resource, image-bundle, exposure-comparison, and pixel-comparison reports while production callers keep the default report factories.
- Added unit coverage proving explicit default export/comparison reports produce the same report as the implicit default path.
- Added unit coverage proving missing asset-resource rows and missing image-bundle rows make the final workspace report follow-up required, reduce export-surface count to 2, and keep comparison surfaces plus review/export tap targets complete.
- Added unit coverage proving missing exposure comparison, missing pixel comparison, and both comparison surfaces missing make the final workspace report follow-up required and speak the exact comparison checklist text.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the injected export/comparison surface fixture seam and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v100-final-workspace-export-comparison-surface-failure-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v100-final-workspace-export-comparison-surface-failure-unit -resultBundlePath /tmp/bracketer-v100-final-workspace-export-comparison-surface-failure-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v100-final-workspace-export-comparison-surface-failure-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v100-final-workspace-export-comparison-surface-failure-ui -derivedDataPath /tmp/bracketer-dd-v100-final-workspace-export-comparison-surface-failure-ui -resultBundlePath /tmp/bracketer-v100-final-workspace-export-comparison-surface-failure-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default export/comparison surface equivalence, missing asset-resource rows, missing image-bundle rows, missing exposure comparison, missing pixel comparison, both comparison surfaces missing, checklist wording, export/comparison surface counts, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the injected export/comparison surface seam.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not prove real Photos resource fetches, image-byte export, Photos-byte inspection, RAW decoding, real Photos-backed pixel comparison, final rendering, physical-device behavior, VoiceOver runtime behavior, or professional output readiness.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or deepen final-workspace negative fixtures for archive/export integrity.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 10:09 PDT - May Goals final-workspace final-output failure coverage v1

### What changed

- Updated `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:alignmentDiagnosticBreakdowns:finalOutputs:)` so unit fixtures can inject a custom `BracketProjectFinalOutputManifest` while production callers keep the default final-output plan.
- Added unit coverage proving an explicit default final-output manifest produces the same report as the implicit default path.
- Added unit coverage proving a manifest with zero final-output plans makes the final workspace report follow-up required, reduces export-surface count to 2, and speaks `Final-output plan is missing.` while review/export tap targets remain complete.
- Added unit coverage proving a manifest that claims final rendered bytes are included makes the final workspace report follow-up required and speaks `Unexpected final rendered bytes are included.` while final-output plans and export surfaces remain present.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the injected-final-output fixture seam and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v99-final-workspace-final-output-failure-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v99-final-workspace-final-output-failure-unit -resultBundlePath /tmp/bracketer-v99-final-workspace-final-output-failure-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v99-final-workspace-final-output-failure-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v99-final-workspace-final-output-failure-ui -derivedDataPath /tmp/bracketer-dd-v99-final-workspace-final-output-failure-ui -resultBundlePath /tmp/bracketer-v99-final-workspace-final-output-failure-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default final-output manifest equivalence, missing final-output plan final-workspace failure, unexpected final rendered byte final-workspace failure, checklist wording, export-surface counts, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the injected-final-output seam.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not prove real final rendering, image-byte export, Photos-byte inspection, RAW decoding, physical-device behavior, VoiceOver runtime behavior, or professional output readiness.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or add broader negative fixtures for export/comparison surface counts.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 09:56 PDT - May Goals final-workspace alignment diagnostic failure coverage v1

### What changed

- Updated `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:alignmentDiagnosticBreakdowns:)` so unit fixtures can inject custom alignment diagnostic breakdowns while production callers keep the default seven-family report.
- Added unit coverage proving an explicit default alignment diagnostic breakdown list produces the same report as the implicit default path.
- Added unit coverage proving a missing `movingRegionMask` family makes the final workspace report follow-up required, records 6 diagnostic families and 30 guides, and speaks incomplete required-family and guide coverage while review/export tap targets remain complete.
- Added unit coverage proving an undercounted `ghostingRisk` family makes the final workspace report follow-up required, records `Ghosting Risk 4/5`, records 34 diagnostic guides, and speaks incomplete required-family and guide coverage while review/export tap targets remain complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the injected-alignment fixture seam and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v98-final-workspace-alignment-diagnostic-failure-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v98-final-workspace-alignment-diagnostic-failure-unit -resultBundlePath /tmp/bracketer-v98-final-workspace-alignment-diagnostic-failure-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v98-final-workspace-alignment-diagnostic-failure-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v98-final-workspace-alignment-diagnostic-failure-ui -derivedDataPath /tmp/bracketer-dd-v98-final-workspace-alignment-diagnostic-failure-ui -resultBundlePath /tmp/bracketer-v98-final-workspace-alignment-diagnostic-failure-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default alignment diagnostic equivalence, missing required alignment family final-workspace failure, incomplete alignment guide count final-workspace failure, checklist wording, aggregate counts, and sibling-scope non-regression.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the injected-alignment seam.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not prove real feature matching, homography, optical flow, subject segmentation, Instruments timing, physical-device behavior, VoiceOver runtime behavior, raw Photos-byte inspection, RAW decoding, or final rendering.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or add broader negative fixtures for export surface/final-output failure states.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 09:46 PDT - May Goals final-workspace tap-target scope failure coverage v1

### What changed

- Reused the injected tap-target audit seam on `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:)` to prove additional single-scope final-workspace failures.
- Added unit coverage proving `reviewCardPoints: 40` makes the final workspace report follow-up required, records 15 review-guidance tap-target follow-ups, and keeps export targets complete.
- Added unit coverage proving `exportCardPoints: 40` makes the final workspace report follow-up required, records 3 export tap-target follow-ups, and keeps comparison targets complete.
- Added unit coverage proving `comparisonCardPoints: 40` makes the final workspace report follow-up required, records 2 comparison tap-target follow-ups, and keeps shot-row targets complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the broader injected-audit fixture scope and verification record.
- Offloaded a v97 assertion check to `claude --dangerously-skip-permissions`; Claude called out the need to prove single-scope failures against an otherwise-complete baseline, which the final tests do.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v97-final-workspace-scope-failure-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v97-final-workspace-scope-failure-unit -resultBundlePath /tmp/bracketer-v97-final-workspace-scope-failure-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- The result bundle ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning during the successful run; it did not fail the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover single-scope final-workspace failure gates for review-guidance, export, and comparison tap-target scopes, including counts, checklist wording, and sibling-scope non-regression.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not measure physical touch ergonomics, prove real-device hit testing, run VoiceOver, inspect Photos bytes, expose Photos identifiers, render final output, or prove physical-device accessibility.

### Next slice

- Continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary, or add broader negative fixtures for alignment diagnostics/export surfaces.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 09:40 PDT - May Goals final-workspace incomplete tap-target fixture coverage v1

### What changed

- Updated `BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot:tapTargetAudit:)` so unit fixtures can inject a custom `BracketProjectReviewTapTargetAudit` while production callers keep the default audit behavior.
- Added unit coverage proving an explicit default tap-target audit produces the same final-workspace report as the implicit default path.
- Added unit coverage proving undersized selected-shot controls make the final workspace report follow-up required, record 5 selected-control follow-ups, and speak the selected-control checklist failure while the shot-row scope remains complete.
- Added unit coverage proving an undersized shot-row audit makes the final workspace report follow-up required, records 1 shot-row follow-up, and speaks the shot-row checklist failure while selected controls remain complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the injected-audit fixture seam and verification record.
- Offloaded a v96 design check to `claude --dangerously-skip-permissions`; after one budget-capped retry, Claude flagged overload/default risks, so Codex replaced the existing factory signature rather than adding a second overload and added explicit-default equality proof.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v96-final-workspace-incomplete-tap-target-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v96-final-workspace-incomplete-tap-target-unit -resultBundlePath /tmp/bracketer-v96-final-workspace-incomplete-tap-target-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v96-final-workspace-incomplete-tap-target-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v96-final-workspace-incomplete-tap-target-ui -derivedDataPath /tmp/bracketer-dd-v96-final-workspace-incomplete-tap-target-ui -resultBundlePath /tmp/bracketer-v96-final-workspace-incomplete-tap-target-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover default audit equivalence, selected-control follow-up injection, shot-row follow-up injection, final-workspace completion gate failure, checklist wording, counts, Codable round-trip, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the default final-workspace fixture remains exposed through `review.project.finalWorkspace.fixture` after the injected-audit seam.

### Current proof boundary

- This is simulator/unit proof for deterministic fixture gate behavior.
- It does not measure physical touch ergonomics, prove real-device hit testing, run VoiceOver, inspect Photos bytes, expose Photos identifiers, render final output, or prove physical-device accessibility.

### Next slice

- Add another negative final-workspace fixture for review-guidance/export/comparison scope failures, or continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 09:29 PDT - May Goals selected-control and shot-row tap-target scope coverage v1

### What changed

- Added `BracketProjectReviewTapTargetAudit.selectedControlRowIDs` and `shotRowIDs` as named tap-target scopes for previous/next controls, representation toggle, close button, selected-shot summary, and the shot-row collection.
- Added selected-control and shot-row row counts, verified counts, follow-up counts, and summary text to `BracketProjectReviewTapTargetAudit`.
- Extended unit tests with positive assertions for the 5 selected-shot control targets and 1 shot-row scope, plus negative-path coverage proving undersized selected-shot controls create 5 dedicated follow-ups and undersized shot rows create 1 dedicated follow-up.
- Added selected-control/shot-row tap-target row and follow-up counts to `BracketProjectFinalReviewWorkspaceFixtureReport`, requiring those scopes before the final workspace reports complete.
- Updated focused UI assertions, README, architecture docs, and `.codex-maygoals-progress.md` with the selected-control/shot-row tap-target scope boundary and verification record.
- Offloaded a focused v95 gap audit to `claude --dangerously-skip-permissions`; the first helper stalled and was killed, while the tighter tools-disabled prompt returned the expected missing test/doc checklist before Codex completed verification.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v95-selected-control-shot-row-tap-target-contract-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v95-selected-control-shot-row-tap-target-contract-unit -resultBundlePath /tmp/bracketer-v95-selected-control-shot-row-tap-target-contract-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v95-selected-control-shot-row-tap-target-contract-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v95-selected-control-shot-row-tap-target-contract-ui -derivedDataPath /tmp/bracketer-dd-v95-selected-control-shot-row-tap-target-contract-ui -resultBundlePath /tmp/bracketer-v95-selected-control-shot-row-tap-target-contract-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover selected-control/shot-row target IDs, verified/follow-up counts, undersized selected-control and shot-row failure behavior, final-workspace selected-control/shot-row counts, Codable round-trip, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes selected-control and shot-row summaries through `review.project.tapTargetAudit` and `review.project.finalWorkspace.fixture` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for expected SwiftUI target contracts.
- It does not measure physical touch ergonomics, prove real-device hit testing, run VoiceOver, inspect Photos bytes, expose Photos identifiers, render final output, or prove physical-device accessibility.

### Next slice

- Add richer final-workspace regression fixtures for incomplete selected-shot controls or shot rows, or continue another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 09:14 PDT - May Goals export/comparison tap-target scope coverage v1

### What changed

- Added `BracketProjectReviewTapTargetAudit.exportRowIDs` and `comparisonRowIDs` as named tap-target scopes for final-output/resource/bundle cards and exposure/pixel comparison cards.
- Added export and comparison row counts, verified counts, follow-up counts, and summary text to `BracketProjectReviewTapTargetAudit`.
- Extended unit tests so existing undersized export-card coverage now asserts 3 export follow-ups, and new `comparisonCardPoints: 40` coverage asserts 2 comparison follow-ups while export cards remain verified.
- Added export/comparison tap-target row and follow-up counts to `BracketProjectFinalReviewWorkspaceFixtureReport`, requiring those scopes before the final workspace reports complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the export/comparison tap-target scope boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v94-export-comparison-tap-target-contract-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v94-export-comparison-tap-target-contract-unit -resultBundlePath /tmp/bracketer-v94-export-comparison-tap-target-contract-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v94-export-comparison-tap-target-contract-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v94-export-comparison-tap-target-contract-ui -derivedDataPath /tmp/bracketer-dd-v94-export-comparison-tap-target-contract-ui -resultBundlePath /tmp/bracketer-v94-export-comparison-tap-target-contract-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover export/comparison target IDs, verified/follow-up counts, undersized comparison-card failure behavior, final-workspace export/comparison counts, Codable round-trip, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes export/comparison summaries through `review.project.tapTargetAudit` and `review.project.finalWorkspace.fixture` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for expected SwiftUI target contracts.
- It does not measure physical touch ergonomics, prove real-device hit testing, run VoiceOver, inspect Photos bytes, expose Photos identifiers, render final output, or prove physical-device accessibility.

### Next slice

- Add richer review/export follow-up scenarios, final-workspace regression fixtures for incomplete selected-shot controls or shot rows, or another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 09:03 PDT - May Goals review-guidance tap-target contract coverage v1

### What changed

- Added `BracketProjectReviewTapTargetAudit.reviewGuidanceRowIDs` as the named 15-target contract for visible review-guidance cards.
- Added review-guidance counts and summary text to `BracketProjectReviewTapTargetAudit`, including verified and follow-up counts.
- Added negative-path unit coverage proving `reviewCardPoints: 40` creates 15 review-guidance follow-ups while export cards remain verified.
- Added `reviewGuidanceTapTargetRowCount` and `reviewGuidanceTapTargetFollowUpRowCount` to `BracketProjectFinalReviewWorkspaceFixtureReport`, requiring the 15 review-guidance tap targets before the final workspace reports complete.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the review-guidance tap-target boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v93-review-guidance-tap-target-contract-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v93-review-guidance-tap-target-contract-unit -resultBundlePath /tmp/bracketer-v93-review-guidance-tap-target-contract-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v93-review-guidance-tap-target-contract-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v93-review-guidance-tap-target-contract-ui -derivedDataPath /tmp/bracketer-dd-v93-review-guidance-tap-target-contract-ui -resultBundlePath /tmp/bracketer-v93-review-guidance-tap-target-contract-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover the 15 guidance target IDs, verified/follow-up guidance counts, undersized guidance-card failure behavior, final-workspace guidance counts, Codable round-trip, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes the guidance-target summary through `review.project.tapTargetAudit` and `review.project.finalWorkspace.fixture` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for expected SwiftUI target contracts.
- It does not measure physical touch ergonomics, prove real-device hit testing, run VoiceOver, inspect Photos bytes, expose Photos identifiers, render final output, or prove physical-device accessibility.

### Next slice

- Add richer review/export follow-up scenarios, final-workspace regression fixtures for incomplete tap-target scopes, or another Wave F/G/N pure-model/UI invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 08:52 PDT - May Goals final-workspace alignment family-ID contract coverage v1

### What changed

- Added `BracketProjectFinalReviewWorkspaceFixtureReport.requiredAlignmentDiagnosticFamilyIDs` as the canonical ordered ID list for feature-match, transform, blur, ghosting, moving-region mask, performance, and explanation diagnostic families.
- Added final-workspace helper coverage for missing, duplicate, unexpected, and incomplete alignment diagnostic family IDs.
- Tightened the final-workspace completeness gate so a forged seven-row diagnostic breakdown cannot mask a missing required family.
- Extended unit tests to prove missing `movingRegionMask`, duplicate `featureMatch`, unexpected `unexpectedAlignment`, and incomplete `ghostingRisk` breakdowns all fail the contract.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the exact required-family-ID boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v92-final-workspace-alignment-family-id-contract-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v92-final-workspace-alignment-family-id-contract-unit -resultBundlePath /tmp/bracketer-v92-final-workspace-alignment-family-id-contract-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v92-final-workspace-alignment-family-id-contract-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v92-final-workspace-alignment-family-id-contract-ui -derivedDataPath /tmp/bracketer-dd-v92-final-workspace-alignment-family-id-contract-ui -resultBundlePath /tmp/bracketer-v92-final-workspace-alignment-family-id-contract-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover exact required family IDs, missing-family rejection, duplicate-family rejection, unexpected-family rejection, incomplete-family rejection, aggregate count preservation, Codable round-trip, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture remains exposed through `review.project.finalWorkspace.fixture` after the stricter helper and checklist wording.

### Current proof boundary

- This is simulator/unit proof for deterministic alignment diagnostic scaffolding and contract validation.
- It does not prove real feature detection, descriptor matching, homography solving, optical flow, subject segmentation, deghosting masks, Instruments profiling, Photos-byte inspection, RAW decoding, final rendering, or physical-device behavior.

### Next slice

- Add richer synthetic alignment fixture coverage, final-workspace regression fixtures for missing/stray diagnostic source labels, or another review/export audit invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 08:40 PDT - May Goals final-workspace alignment diagnostic breakdown coverage v1

### What changed

- Added `BracketProjectFinalReviewWorkspaceFixtureReport.AlignmentDiagnosticBreakdown`, with ordered ids, labels, counts, required counts, and per-family completion.
- Derived `alignmentDiagnosticGuideCount` from the seven-family breakdown so the aggregate cannot drift away from the named alignment diagnostic contributors.
- Tightened the final-workspace completeness gate so it requires seven diagnostic families and every family must meet its required count.
- Updated the final-workspace coverage summary, checklist, and accessibility value to expose `35 alignment diagnostic guides across 7 families`, including named receipts such as `Feature Match 5/5` and `Alignment Explanation 5/5`.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the seven-family alignment diagnostic breakdown boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v91-final-workspace-alignment-diagnostic-breakdown-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v91-final-workspace-alignment-diagnostic-breakdown-unit -resultBundlePath /tmp/bracketer-v91-final-workspace-alignment-diagnostic-breakdown-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v91-final-workspace-alignment-diagnostic-breakdown-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v91-final-workspace-alignment-diagnostic-breakdown-ui -derivedDataPath /tmp/bracketer-dd-v91-final-workspace-alignment-diagnostic-breakdown-ui -resultBundlePath /tmp/bracketer-v91-final-workspace-alignment-diagnostic-breakdown-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The first v91 unit attempt failed at compile time because `#expect(report.alignmentDiagnosticBreakdowns.allSatisfy(\.isComplete))` expanded through Swift Testing as a potentially throwing key-path predicate; the assertion was rewritten through a local nonthrowing Boolean and the rerun passed.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover the ordered seven-family breakdown, aggregate sum derivation, per-family completion, coverage/checklist text, Codable round-trip, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `35 alignment diagnostic guides across 7 families` plus named family receipts through `review.project.finalWorkspace.fixture` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic alignment diagnostic scaffolding.
- It does not prove real feature detection, descriptor matching, homography solving, optical flow, subject segmentation, deghosting masks, Instruments profiling, Photos-byte inspection, RAW decoding, final rendering, or physical-device behavior.

### Next slice

- Add richer synthetic alignment fixture coverage, final-workspace regression fixtures for missing families, or another review/export audit invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 08:28 PDT - May Goals final-workspace alignment diagnostic guide coverage v1

### What changed

- Added `alignmentDiagnosticGuideCount` to `BracketProjectFinalReviewWorkspaceFixtureReport`, aggregating feature-match guides, transform guides, blur-risk guides, ghosting-risk guides, moving-region mask guides, alignment performance notes, and alignment explanations.
- Tightened the final-workspace completeness gate so it requires at least `35 alignment diagnostic guides` before reporting complete.
- Updated the final-workspace coverage summary, checklist, and accessibility value to expose `35 alignment diagnostic guides` through `review.project.finalWorkspace.fixture`.
- Extended unit/UI tests so the direct review fixture proves the aggregate alignment diagnostic count, final-workspace accessibility receipt, simulator-only boundary text, and raw Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the alignment diagnostic guide ladder boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v90-final-workspace-alignment-diagnostic-guides-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v90-final-workspace-alignment-diagnostic-guides-unit -resultBundlePath /tmp/bracketer-v90-final-workspace-alignment-diagnostic-guides-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v90-final-workspace-alignment-diagnostic-guides-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v90-final-workspace-alignment-diagnostic-guides-ui -derivedDataPath /tmp/bracketer-dd-v90-final-workspace-alignment-diagnostic-guides-ui -resultBundlePath /tmp/bracketer-v90-final-workspace-alignment-diagnostic-guides-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover the aggregate alignment diagnostic guide count, final-workspace completeness gate, coverage/checklist text, export/comparison/final-output counts, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `35 alignment diagnostic guides` through `review.project.finalWorkspace.fixture` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic alignment diagnostic scaffolding.
- It does not prove real feature detection, descriptor matching, homography solving, optical flow, subject segmentation, deghosting masks, Instruments profiling, Photos-byte inspection, RAW decoding, final rendering, or physical-device behavior.

### Next slice

- Add richer synthetic alignment fixture coverage or another review/export audit invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 08:17 PDT - May Goals review tap-target guidance-card coverage v1

### What changed

- Expanded `BracketProjectReviewTapTargetAudit` with `reviewCardPoints` and 15 visible guidance-card rows for best-base-frame, before/after scrub, per-shot exposure, focus/edge, motion/alignment, motion metadata, feature match, alignment transform, motion/blur, ghosting risk, moving-region mask, alignment performance, alignment explanation, capture quality, and merge readiness.
- Raised the deterministic review fixture's tap-target audit from `11/11 tap targets verified` to `26/26 tap targets verified`.
- Let `BracketProjectFinalReviewWorkspaceFixtureReport` pick up the expanded `26 tap-target rows` count through its composed audit.
- Extended unit/UI tests so the direct review fixture proves `review.project.bestBaseFrame.card`, `review.project.alignmentExplanation.card`, `26/26 tap targets verified`, final-workspace `26 tap-target rows`, and raw Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the expanded review/export tap-target boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v89-review-tap-target-guidance-cards-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v89-review-tap-target-guidance-cards-unit -resultBundlePath /tmp/bracketer-v89-review-tap-target-guidance-cards-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v89-review-tap-target-guidance-cards-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v89-review-tap-target-guidance-cards-ui -derivedDataPath /tmp/bracketer-dd-v89-review-tap-target-guidance-cards-ui -resultBundlePath /tmp/bracketer-v89-review-tap-target-guidance-cards-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover all 26 audit rows, guidance-card row identifiers, follow-up accounting, final-workspace tap-target row count, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `26/26 tap targets verified` and guidance-card identifiers through `review.project.tapTargetAudit`.

### Current proof boundary

- This is simulator/unit proof for expected SwiftUI target contracts.
- It does not measure physical touch ergonomics, prove real-device hit testing, run VoiceOver, inspect Photos bytes, expose Photos identifiers, render final output, or prove physical-device accessibility.

### Next slice

- Add richer synthetic alignment fixture coverage or another review/export audit invariant while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 08:05 PDT - May Goals final-workspace split handoff-pair coverage v1

### What changed

- Added `splitHandoffProbeCount` to `BracketProjectFinalReviewWorkspaceFixtureReport`, derived from required review identifiers that have matching `.card` surfaces.
- Tightened the final-workspace completeness gate so it requires at least 18 split handoff/card pairs before reporting complete.
- Updated the final-workspace coverage summary, checklist, and accessibility value to expose `18 split handoff/card pairs` through `review.project.finalWorkspace.fixture`.
- Extended unit/UI tests so the direct review fixture proves 44 required probes, 18 split handoff/card pairs, traversal coverage, tap-target rows, export/comparison/final-output counts, no-final-rendered-bytes boundary text, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-pair final-workspace boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v88-final-workspace-split-pair-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v88-final-workspace-split-pair-unit -resultBundlePath /tmp/bracketer-v88-final-workspace-split-pair-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v88-final-workspace-split-pair-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v88-final-workspace-split-pair-ui -derivedDataPath /tmp/bracketer-dd-v88-final-workspace-split-pair-ui -resultBundlePath /tmp/bracketer-v88-final-workspace-split-pair-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The first v88 unit attempt failed because the new unit assertion estimated `requiredProbeCount >= 48`, while the actual current contract count is `44`; the assertion was corrected to `requiredProbeCount == 44`, and the rerun passed.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover final-workspace split-pair count, required-probe count, traversal count, tap-target rows, export/comparison/final-output counts, and privacy/boundary text.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `18 split handoff/card pairs` through `review.project.finalWorkspace.fixture` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for review workspace completeness.
- It does not run VoiceOver, prove rotor order or physical-device accessibility, read Photos bytes, decode RAW pixels, expose Photos identifiers, or render final output.

### Next slice

- Broaden review/export tap-target audit coverage or add richer synthetic alignment fixture coverage while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 07:50 PDT - May Goals project-review alignment-explanation handoff probe v1

### What changed

- Added `review.project.alignmentExplanation` as a structured selected-project review handoff probe for `BracketProjectAlignmentExplanationReport`, distinct from the visible `review.project.alignmentExplanation.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both alignment-explanation surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic alignment-explanation report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.alignmentExplanation`, `review.project.alignmentExplanation.card`, `Alignment Explanation`, `5 explanations`, synthetic no-real-pixel-analysis wording, deterministic manifest-scaffolding boundary, no-real-image-feature/deghosting-mask/Instruments boundary text, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v87-alignment-explanation-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v87-alignment-explanation-handoff-probe-unit -resultBundlePath /tmp/bracketer-v87-alignment-explanation-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v87-alignment-explanation-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v87-alignment-explanation-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v87-alignment-explanation-handoff-probe-ui -resultBundlePath /tmp/bracketer-v87-alignment-explanation-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude remained unavailable because the local CLI session limit was still active until 8:30am. The slice continued locally.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and alignment-explanation handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.alignmentExplanation` and `review.project.alignmentExplanation.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic alignment-explanation scaffolding.
- It does not inspect real image features, match pixels, run optical flow, segment subjects, compute deghosting masks, run Instruments, inspect Photos bytes, decode RAW pixels, render final output, or prove physical-device behavior.

### Next slice

- Expand the final-workspace fixture and review/export audit coverage now that the alignment split-probe ladder is complete, while preserving the simulator-only proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 07:39 PDT - May Goals project-review alignment-performance handoff probe v1

### What changed

- Added `review.project.alignmentPerformance` as a structured selected-project review handoff probe for `BracketProjectAlignmentPerformanceReport`, distinct from the visible `review.project.alignmentPerformance.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both alignment-performance surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic alignment-performance report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.alignmentPerformance`, `review.project.alignmentPerformance.card`, `Alignment Performance Notes`, `5 performance notes`, synthetic no-Instruments wording, deterministic manifest-scaffolding boundary, no-Instruments boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v86-alignment-performance-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v86-alignment-performance-handoff-probe-unit -resultBundlePath /tmp/bracketer-v86-alignment-performance-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v86-alignment-performance-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v86-alignment-performance-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v86-alignment-performance-handoff-probe-ui -resultBundlePath /tmp/bracketer-v86-alignment-performance-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- `claude --dangerously-skip-permissions` was attempted as a read-only offload at 07:29 PDT, but the local Claude CLI reported its session limit until 8:30am. The slice continued locally.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and alignment-performance handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.alignmentPerformance` and `review.project.alignmentPerformance.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic alignment-performance scaffolding.
- It does not run Instruments, measure CPU or GPU time, profile memory, inspect Photos bytes, decode RAW pixels, render final output, or prove physical-device performance.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.alignmentExplanation`, while preserving its no-real-pixel-analysis/no-physical-device boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 07:26 PDT - May Goals project-review moving-region-mask handoff probe v1

### What changed

- Added `review.project.movingRegionMask` as a structured selected-project review handoff probe for `BracketProjectMovingRegionMaskReport`, distinct from the visible `review.project.movingRegionMask.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both moving-region mask surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic moving-region mask report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.movingRegionMask`, `review.project.movingRegionMask.card`, `Moving-Region Mask`, `5 mask guides`, synthetic no-real-subject-segmentation wording, deterministic manifest-scaffolding boundary, no-moving-subject-segmentation boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v85-moving-region-mask-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v85-moving-region-mask-handoff-probe-unit -resultBundlePath /tmp/bracketer-v85-moving-region-mask-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v85-moving-region-mask-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v85-moving-region-mask-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v85-moving-region-mask-handoff-probe-ui -resultBundlePath /tmp/bracketer-v85-moving-region-mask-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- A plain `xcodebuild -list -project Bracketer.xcodeproj` inspection command failed because the active developer directory was `/Library/Developer/CommandLineTools`; rerunning with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` listed the `Bracketer`, `BracketerTests`, and `BracketerUITests` targets and the `Bracketer` scheme.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and moving-region mask handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.movingRegionMask` and `review.project.movingRegionMask.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic moving-region mask scaffolding.
- It does not segment moving subjects, run optical flow, compute real deghosting masks, inspect Photos bytes, decode RAW pixels, read real motion sensors, render final output, or prove physical-device capture behavior.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.alignmentPerformance`, while preserving its no-Instruments/no-real-performance-measurement boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 07:10 PDT - May Goals project-review ghosting-risk handoff probe v1

### What changed

- Added `review.project.ghostingRisk` as a structured selected-project review handoff probe for `BracketProjectGhostingRiskReport`, distinct from the visible `review.project.ghostingRisk.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both ghosting-risk surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic ghosting-risk report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.ghostingRisk`, `review.project.ghostingRisk.card`, `Ghosting Risk`, `5 ghosting-risk guides`, synthetic no-moving-subject-detection wording, deterministic manifest-scaffolding boundary, no-optical-flow boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v84-ghosting-risk-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v84-ghosting-risk-handoff-probe-unit -resultBundlePath /tmp/bracketer-v84-ghosting-risk-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v84-ghosting-risk-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v84-ghosting-risk-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v84-ghosting-risk-handoff-probe-ui -resultBundlePath /tmp/bracketer-v84-ghosting-risk-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude was attempted as a read-only scout for v84 at 07:00 PDT, but the local CLI reported its session limit until 8:30am; the slice used the established split-probe pattern.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and ghosting-risk handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.ghostingRisk` and `review.project.ghostingRisk.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic ghosting-risk scaffolding.
- It does not run optical flow, segment moving subjects, compute deghosting masks, inspect Photos bytes, decode RAW pixels, read real motion sensors, render final output, or prove physical-device capture behavior.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.movingRegionMask`, while preserving its no-subject-segmentation/no-deghosting-mask boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 06:56 PDT - May Goals project-review motion-blur handoff probe v1

### What changed

- Added `review.project.motionBlur` as a structured selected-project review handoff probe for `BracketProjectMotionBlurRiskReport`, distinct from the visible `review.project.motionBlur.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both motion/blur surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic motion/blur risk report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.motionBlur`, `review.project.motionBlur.card`, `Motion/Blur Risk`, `5 blur-risk guides`, synthetic no-real-shutter/no-sensor-evidence wording, deterministic manifest-scaffolding boundary, no-real-shutter-speed boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v83-motion-blur-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v83-motion-blur-handoff-probe-unit -resultBundlePath /tmp/bracketer-v83-motion-blur-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v83-motion-blur-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v83-motion-blur-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v83-motion-blur-handoff-probe-ui -resultBundlePath /tmp/bracketer-v83-motion-blur-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude remained unavailable for v83 scouting because the local CLI had reported its session limit until 8:30am; the slice used the established split-probe pattern.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and motion/blur handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.motionBlur` and `review.project.motionBlur.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic motion/blur risk scaffolding.
- It does not read real shutter speed, exposure duration, ISO, CMMotion or IMU samples, optical flow, ghosting masks, Photos bytes, decode RAW pixels, render final output, or prove physical-device capture behavior.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.ghostingRisk`, while preserving its no-optical-flow/no-deghosting-mask boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 06:45 PDT - May Goals project-review alignment-transform handoff probe v1

### What changed

- Added `review.project.alignmentTransform` as a structured selected-project review handoff probe for `BracketProjectAlignmentTransformReport`, distinct from the visible `review.project.alignmentTransform.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both alignment-transform surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic alignment-transform report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.alignmentTransform`, `review.project.alignmentTransform.card`, `Alignment Transform`, `5 transform guides`, synthetic transform wording, deterministic manifest-scaffolding boundary, no-real-image-feature boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v82-alignment-transform-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v82-alignment-transform-handoff-probe-unit -resultBundlePath /tmp/bracketer-v82-alignment-transform-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v82-alignment-transform-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v82-alignment-transform-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v82-alignment-transform-handoff-probe-ui -resultBundlePath /tmp/bracketer-v82-alignment-transform-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude was not available for v82 scouting because the local CLI had reported its session limit until 8:30am; the slice used the established split-probe pattern.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and alignment-transform handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.alignmentTransform` and `review.project.alignmentTransform.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic alignment-transform scaffolding.
- It does not detect real image features, match pixels, compute homographies or warps, inspect Photos bytes, decode RAW pixels, read real motion sensors, render final output, or prove physical-device capture behavior.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.motionBlur`, while preserving its no-real-shutter/no-sensor-evidence boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 06:33 PDT - May Goals project-review feature-match handoff probe v1

### What changed

- Added `review.project.featureMatch` as a structured selected-project review handoff probe for `BracketProjectFeatureMatchFixtureReport`, distinct from the visible `review.project.featureMatch.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both feature-match surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic feature-match fixture in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.featureMatch`, `review.project.featureMatch.card`, `Feature Match Fixture`, `5 feature-match guides`, synthetic matched-pair wording, deterministic fixture/manifest scaffolding boundary, no-real-image-feature boundary, descriptor/homography exclusions, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v81-feature-match-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v81-feature-match-handoff-probe-unit -resultBundlePath /tmp/bracketer-v81-feature-match-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v81-feature-match-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v81-feature-match-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v81-feature-match-handoff-probe-ui -resultBundlePath /tmp/bracketer-v81-feature-match-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude was attempted with `claude --dangerously-skip-permissions -p ...` for read-only feature-match scouting, but the local CLI reported its session limit until 8:30am; the slice continued from the established split-probe pattern.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and feature-match handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.featureMatch` and `review.project.featureMatch.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic feature-match fixture reporting.
- It does not inspect real image features, match real pixels, compute descriptors, solve homographies, run optical flow, inspect Photos bytes, decode RAW pixels, render final output, or prove physical-device capture behavior.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.alignmentTransform`, while preserving its no-real-homography/no-warp boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 06:23 PDT - May Goals project-review motion-metadata handoff probe v1

### What changed

- Added `review.project.motionMetadata` as a structured selected-project review handoff probe for `BracketProjectMotionMetadataReport`, distinct from the visible `review.project.motionMetadata.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both motion-metadata surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the bounded scalar motion-metadata report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.motionMetadata`, `review.project.motionMetadata.card`, `Motion Metadata Capture`, `0 motion samples captured`, unavailable motion metadata, the no-raw-CMMotion boundary, no-physical-device-proof boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v80-motion-metadata-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v80-motion-metadata-handoff-probe-unit -resultBundlePath /tmp/bracketer-v80-motion-metadata-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v80-motion-metadata-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v80-motion-metadata-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v80-motion-metadata-handoff-probe-ui -resultBundlePath /tmp/bracketer-v80-motion-metadata-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only motion-metadata scouting; the scout confirmed the identifier, fragments, and privacy-boundary assertions.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and motion-metadata handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.motionMetadata` and `review.project.motionMetadata.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for bounded scalar motion-metadata reporting and explicit unavailable simulator samples.
- It does not read raw CMMotion samples, accelerometer streams, gyroscope streams, inspect Photos bytes, decode RAW pixels, render final output, or prove physical-device motion capture.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.featureMatch`, while preserving its synthetic-feature privacy boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 06:11 PDT - May Goals project-review motion-alignment handoff probe v1

### What changed

- Added `review.project.motionAlignment` as a structured selected-project review handoff probe for `BracketProjectMotionAlignmentOverlay`, distinct from the visible `review.project.motionAlignment.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both motion/alignment surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic motion/alignment overlay in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.motionAlignment`, `review.project.motionAlignment.card`, `Motion/Alignment Overlay`, `5 overlay guides`, the synthetic motion/alignment note, deterministic fixture/manifest scaffolding boundary, no-real-CMMotion-or-IMU boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v79-motion-alignment-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v79-motion-alignment-handoff-probe-unit -resultBundlePath /tmp/bracketer-v79-motion-alignment-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v79-motion-alignment-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v79-motion-alignment-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v79-motion-alignment-handoff-probe-ui -resultBundlePath /tmp/bracketer-v79-motion-alignment-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only motion-alignment scouting; the scout confirmed the identifier, fragments, and next card-only candidate.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and motion/alignment handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.motionAlignment` and `review.project.motionAlignment.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic motion/alignment overlay scaffolding.
- It does not read real CMMotion or IMU samples, compute real alignment transforms, detect ghosting, inspect Photos bytes, decode RAW pixels, render final output, or prove physical-device behavior.

### Next slice

- Continue the split-probe pattern for the next project-review card-only surface, likely `review.project.motionMetadata`, while preserving its distinct motion-capture privacy boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 06:00 PDT - May Goals project-review focus-edge handoff probe v1

### What changed

- Added `review.project.focusEdge` as a structured selected-project review handoff probe for `BracketProjectFocusEdgeInspection`, distinct from the visible `review.project.focusEdge.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both focus-edge surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic focus/edge inspection in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.focusEdge`, `review.project.focusEdge.card`, `Focus/Edge Inspection`, `5/5 inspected`, the synthetic fixture-pixel note, deterministic fixture/metadata boundary, no-private-Photos-byte boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v78-focus-edge-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v78-focus-edge-handoff-probe-unit -resultBundlePath /tmp/bracketer-v78-focus-edge-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v78-focus-edge-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v78-focus-edge-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v78-focus-edge-handoff-probe-ui -resultBundlePath /tmp/bracketer-v78-focus-edge-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only focus-edge scouting; the scout confirmed the identifier, fragments, and view-emission seam.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and focus-edge handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.focusEdge` and `review.project.focusEdge.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for deterministic synthetic fixture-pixel and manifest metadata review guidance.
- It does not inspect private Photos bytes, decode RAW pixels, use real focus samples, estimate alignment or ghosting, render final output, or prove physical-device accessibility.

### Next slice

- Continue the split-probe pattern for the next project-review guidance card, likely `review.project.motionAlignment`, while preserving the card surface and verification boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 05:49 PDT - May Goals project-review per-shot exposure handoff probe v1

### What changed

- Added `review.project.perShotExposure` as a structured selected-project review handoff probe for `BracketProjectPerShotExposureDistribution`, distinct from the visible `review.project.perShotExposure.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both per-shot exposure surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the manifest-backed per-shot exposure distribution in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.perShotExposure`, `review.project.perShotExposure.card`, `Per-shot Exposure Distribution`, `5 shots`, `EV spread +8.0 EV`, `2 darker highlight guards`, `4 manifest clipping warnings`, the pixel-histogram boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v77-per-shot-exposure-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v77-per-shot-exposure-handoff-probe-unit -resultBundlePath /tmp/bracketer-v77-per-shot-exposure-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v77-per-shot-exposure-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v77-per-shot-exposure-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v77-per-shot-exposure-handoff-probe-ui -resultBundlePath /tmp/bracketer-v77-per-shot-exposure-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only next-slice scouting and v77 audit; the v77 audit reported `NO MISSED ITEMS`.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and per-shot exposure handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.perShotExposure` and `review.project.perShotExposure.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for a deterministic manifest metadata review seam.
- It does not inspect private Photos bytes, decode RAW pixels, compute real pixel histograms, analyze focus edges, estimate alignment or ghosting, render final output, or prove physical-device accessibility.

### Next slice

- Continue the split-probe pattern for the next project-review guidance card, likely `review.project.focusEdge`, while preserving the card surface and verification boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 05:37 PDT - May Goals project-review before-after-scrub handoff probe v1

### What changed

- Added `review.project.beforeAfterScrub` as a structured selected-project review handoff probe for `BracketProjectBeforeAfterScrubPlan`, distinct from the visible `review.project.beforeAfterScrub.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both before/after scrub surfaces are required by the project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the deterministic scrub plan in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.beforeAfterScrub`, `review.project.beforeAfterScrub.card`, `Before/After Scrub Plan`, baseline/compare labels, `5 scrub stops`, the no-private-Photos-byte/no-final-rendered-output boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v76-before-after-scrub-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v76-before-after-scrub-handoff-probe-unit -resultBundlePath /tmp/bracketer-v76-before-after-scrub-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v76-before-after-scrub-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v76-before-after-scrub-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v76-before-after-scrub-handoff-probe-ui -resultBundlePath /tmp/bracketer-v76-before-after-scrub-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and before/after scrub handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.beforeAfterScrub` and `review.project.beforeAfterScrub.card` without leaking raw fixture Photos identifiers.

### Current proof boundary

- This is simulator/unit proof for a deterministic metadata and synthetic-fixture scrub seam.
- It does not inspect private Photos bytes, decode RAW pixels, estimate real alignment or ghosting, render final output, or prove physical-device accessibility.

### Next slice

- Continue the split-probe pattern for the next project-review guidance card, likely `review.project.perShotExposure`, while preserving the card surface and verification boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 05:24 PDT - May Goals project-review best-base-frame handoff probe v1

### What changed

- Added `review.project.bestBaseFrame` as a structured selected-project review handoff probe for `BracketProjectBestBaseFrameSuggestion`, distinct from the visible `review.project.bestBaseFrame.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both best-base-frame surfaces are part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the manifest-backed best-base-frame suggestion in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.bestBaseFrame`, `review.project.bestBaseFrame.card`, `Best Base Frame Suggestion`, `Shot 3 / 0 EV`, confidence text, `2 darker highlight guards`, the not-final-HDR-merge-decision boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v75-best-base-frame-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v75-best-base-frame-handoff-probe-unit -resultBundlePath /tmp/bracketer-v75-best-base-frame-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v75-best-base-frame-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v75-best-base-frame-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v75-best-base-frame-handoff-probe-ui -resultBundlePath /tmp/bracketer-v75-best-base-frame-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only next-slice scouting and v75 auditing; they selected this slice and confirmed the code/test wiring before docs/progress were updated.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and best-base-frame handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the selected-project review fixture exposes `review.project.bestBaseFrame` through the actual SwiftUI accessibility tree.
- Not proof of: private Photos-byte inspection, decoded RAW pixel inspection, alignment analysis, ghosting analysis, final rendered output, final HDR merge behavior, or physical-device behavior.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 05:11 PDT - May Goals project-review capture-quality handoff probe v1

### What changed

- Added `review.project.qualityReport.card` as the visible selected-project review card identifier for `BracketProjectCaptureQualityReport`, preserving `review.project.qualityReport` as the structured handoff probe.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so both capture-quality surfaces are part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the manifest-backed capture-quality report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Moved the visible capture-quality card accessibility identifier to the card container so the structured probe owns the base identifier and the visible card owns `.card`.
- Extended unit/UI tests so the direct review fixture proves `review.project.qualityReport`, `review.project.qualityReport.card`, `Capture Quality`, `5 of 5 available`, `Score 100`, `Ready for careful review`, `Highlight guards 2`, `Shadow guards 2`, the no-private-Photos-byte boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v74-capture-quality-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v74-capture-quality-handoff-probe-unit -resultBundlePath /tmp/bracketer-v74-capture-quality-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v74-capture-quality-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v74-capture-quality-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v74-capture-quality-handoff-probe-ui -resultBundlePath /tmp/bracketer-v74-capture-quality-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only next-slice scouting and v74 auditing; they confirmed the capture-quality split wiring and queued best-base-frame as the next clean split-probe candidate.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and capture-quality handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the selected-project review fixture exposes `review.project.qualityReport` through the actual SwiftUI accessibility tree.
- Not proof of: private Photos-byte inspection, sharpness analysis, alignment analysis, ghosting analysis, physical asset availability, quality science, or physical-device behavior.

### Goal status

- Goal still open. Verified wave complete. Next wave ready; best-base-frame split handoff is queued as the next obvious review-proof slice.

## 2026-05-31 04:58 PDT - May Goals project-review merge-readiness handoff probe v1

### What changed

- Added `review.project.mergeReadiness` as a structured selected-project review handoff probe for `BracketProjectMergeReadinessReport`, distinct from the visible `review.project.mergeReadiness.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the merge-readiness handoff probe is part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the same heuristic merge-readiness report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Removed the latent duplicate `review.project.mergeReadiness` identifier from the visible card's inner label so the structured probe owns that identifier and the card owns `.card`.
- Extended unit/UI tests so the direct review fixture proves `review.project.mergeReadiness`, `Merge Readiness`, `Score 95`, `Ready for cautious merge preview`, `0 blockers`, `0 cautions`, the no-private-Photos-byte boundary, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the split-probe handoff boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v73-merge-readiness-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v73-merge-readiness-handoff-probe-unit -resultBundlePath /tmp/bracketer-v73-merge-readiness-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v73-merge-readiness-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v73-merge-readiness-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v73-merge-readiness-handoff-probe-ui -resultBundlePath /tmp/bracketer-v73-merge-readiness-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Claude sidecars were invoked with `claude --dangerously-skip-permissions -p ...` for read-only next-slice scouting and docs/progress auditing; they flagged the latent duplicate identifier and stale v72 latest-continuation wording.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and merge-readiness handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves the selected-project review fixture exposes `review.project.mergeReadiness` through the actual SwiftUI accessibility tree.
- Not proof of: private Photos-byte inspection, sharpness analysis, alignment analysis, ghosting analysis, moving-subject masks, RAW pixel inspection, final HDR output, or physical-device behavior.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-31 04:42 PDT - May Goals project-review image-bundle handoff probe v1

### What changed

- Added `review.project.imageBundle` as a structured selected-project review handoff probe for `BracketProjectImageBundleManifest`, distinct from the visible `review.project.imageBundle.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the image-bundle handoff probe is part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the manifest and draft-package accessibility summary in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.imageBundle`, `Image Bundle Manifest`, `Metadata only`, `5 of 5 exportable`, `RAW 5`, `Processed 5`, `5 complete RAW/processed pairs`, `Recovery IDs 5`, `Draft package 10 synthetic entries`, no-private-Photos-byte/no-export boundary text, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new image-bundle handoff proof boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v72-image-bundle-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v72-image-bundle-handoff-probe-unit -resultBundlePath /tmp/bracketer-v72-image-bundle-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v72-image-bundle-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v72-image-bundle-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v72-image-bundle-handoff-probe-ui -resultBundlePath /tmp/bracketer-v72-image-bundle-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- A Claude sidecar was invoked with `claude --dangerously-skip-permissions -p ...` for read-only next-slice scouting; it confirmed the expected strings and warned not to expand tap-target export-surface counts.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and image-bundle handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves `review.project.imageBundle` is exposed through the actual SwiftUI accessibility tree.
- `boundary-proof`: this is metadata-only image-bundle handoff scaffolding with deterministic draft-package bytes, not Photos resource fetching, file reads, RAW container decoding, private Photos-byte inspection, real filesystem package contents, physical export, or physical-device proof.

### Goal status

- Goal still open. Verified slice complete. Physical-device proof remains blocked until the real iPhone is available/unlocked.

## 2026-05-31 04:28 PDT - May Goals project-review asset-resource handoff probe v1

### What changed

- Added `review.project.assetResources` as a structured selected-project review handoff probe for `BracketProjectAssetResourceReport`, distinct from the visible `review.project.assetResources.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the asset-resource handoff probe is part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the report in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe`.
- Extended unit/UI tests so the direct review fixture proves `review.project.assetResources`, `Asset Resources`, `5 complete pairs`, `RAW 5`, `Processed 5`, `Recovery IDs 5`, no-Photos-resource-fetch boundary text, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new asset-resource handoff proof boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v71-asset-resource-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v71-asset-resource-handoff-probe-unit -resultBundlePath /tmp/bracketer-v71-asset-resource-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v71-asset-resource-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v71-asset-resource-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v71-asset-resource-handoff-probe-ui -resultBundlePath /tmp/bracketer-v71-asset-resource-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The first focused UI attempt failed at `BracketerUITests.swift:1584` because the test expected `Recovery IDs 0`; the direct review fixture intentionally carries five countable recovery identifiers while still redacting the raw `review-accessibility-0EV` value. The expectation was corrected to `Recovery IDs 5`, and the passing UI bundle above replaced the failed attempt.
- A Claude sidecar was invoked with `claude --dangerously-skip-permissions -p ...` for read-only failure diagnosis; it identified the same failing assertion and made no file edits.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during the successful rerun; neither failed the counted bundle.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and asset-resource handoff accessibility fragments.
- `simulator-ui-proof`: focused UI test proves `review.project.assetResources` is exposed through the actual SwiftUI accessibility tree.
- `boundary-proof`: this is manifest/project asset-resource handoff scaffolding, not Photos resource fetching, file reads, RAW container decoding, private Photos-byte inspection, physical asset availability, or physical-device proof.

### Goal status

- Goal still open. Verified slice complete. Physical-device proof remains blocked until the real iPhone is available/unlocked.

## 2026-05-31 04:10 PDT - May Goals project-review final-output handoff probe v1

### What changed

- Added `review.project.finalOutputs` as a structured selected-project review handoff probe for `BracketProjectFinalOutputManifest`, distinct from the visible `review.project.finalOutputs.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the final-output handoff probe is part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Exposed the manifest in `BracketProjectReviewHandoffView` through a top-level `ProjectReviewProbe` using metadata-only privacy and the project updated timestamp.
- Extended unit/UI tests so the direct review fixture proves `review.project.finalOutputs`, `Final Output Manifest`, `Metadata only`, `0 ready`, `3 blocked`, `5 source exposures`, `No final rendered bytes`, no-rendered-image-byte boundary text, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new final-output handoff proof boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v70-final-output-handoff-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v70-final-output-handoff-probe-unit -resultBundlePath /tmp/bracketer-v70-final-output-handoff-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v70-final-output-handoff-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v70-final-output-handoff-probe-ui -derivedDataPath /tmp/bracketer-dd-v70-final-output-handoff-probe-ui -resultBundlePath /tmp/bracketer-v70-final-output-handoff-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, and final-output manifest readiness/no-rendered-bytes accessibility text.
- `simulator-ui-proof`: focused UI test proves `review.project.finalOutputs` is exposed through the actual SwiftUI accessibility tree.
- `boundary-proof`: this is metadata-only final-output handoff scaffolding, not final rendered image bytes, Photos resource inspection, RAW decoding, tone mapping of user assets, real Files export, or physical-device proof.

### Goal status

- Goal still open. Verified slice complete. Physical-device proof remains blocked until the real iPhone is available/unlocked.

## 2026-05-31 03:59 PDT - May Goals project-review feature-match fixture card v1

### What changed

- Promoted `BracketProjectFeatureMatchFixtureReport` from model-only fixture coverage into the selected-project review surface at `review.project.featureMatch.card`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the feature-match card is part of the required project-review contract, traversal inventory, and screenshot-matrix surface.
- Rendered the feature-match report in `BracketProjectReviewHandoffView` with per-shot synthetic feature candidates, matched pairs, outliers, confidence, guidance, and explicit no-real-feature/no-descriptor/no-homography boundary copy.
- Extended `BracketProjectFinalReviewWorkspaceFixtureReport` so the final workspace fixture counts feature-match guides and requires feature-match guidance before reporting complete.
- Extended unit/UI tests so the direct review fixture proves `review.project.featureMatch.card`, `5 feature-match guides`, synthetic matched-pair wording, final workspace guide counts, traversal fragments, screenshot matrix requirements, and fixture Photos identifier redaction.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new review-surface proof boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v69-feature-match-review-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v69-feature-match-review-probe-unit -resultBundlePath /tmp/bracketer-v69-feature-match-review-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v69-feature-match-review-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v69-feature-match-review-probe-ui -derivedDataPath /tmp/bracketer-dd-v69-feature-match-review-probe-ui -resultBundlePath /tmp/bracketer-v69-feature-match-review-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- No implementation test failures were introduced in this slice.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.
- Claude was invoked with `claude --dangerously-skip-permissions` for a read-only next-slice recommendation. It recommended a final-output handoff probe as a valid alternative; this slice used the feature-match lane because it directly exposed an existing Wave Family F model in the review accessibility tree.

### Proof category

- `pure-model-proof`: unit tests cover required probe inventory, screenshot-matrix identifier requirements, traversal entry requirements, final-workspace feature-match guide counts, and the existing feature-match fixture model contract.
- `simulator-ui-proof`: focused UI test proves `review.project.featureMatch.card` is exposed through the actual SwiftUI accessibility tree.
- `boundary-proof`: this is deterministic manifest/fixture-pixel scaffolding, not real feature detection, descriptor matching, homography solving, optical flow, Photos-byte inspection, RAW decoding, final rendering, or physical-device proof.

### Goal status

- Goal still open. Verified slice complete. Physical-device proof remains blocked until the real iPhone is available/unlocked.

## 2026-05-28 19:05 PDT - May Goals project-review tap-target audit probe v1

### What changed

- Promoted the existing `BracketProjectReviewTapTargetAudit` into a first-class hidden project-review probe at `review.project.tapTargetAudit`, exposing the selected-project review/export tap-target inventory through the actual review fixture instead of leaving it as a pure model contract.
- Exposed the audit in `BracketProjectReviewHandoffView` through a hidden `ProjectReviewProbe` at `review.project.tapTargetAudit`.
- Updated `BracketProjectReviewAccessibilityContract` to define and require `review.project.tapTargetAudit`, `BracketProjectReviewVoiceOverTraversalSnapshot` to include the probe with the expected `Review Export Tap Target Audit` value fragment, and `BracketerAccessibilityScreenshotMatrix` to require the identifier for Project Review Handoff screenshot coverage.
- Extended unit/UI tests so the focused review test asserts the probe exists, reports `11/11 tap targets verified`, includes previous/next/export/image-bundle identifiers, carries model-contract/no-physical-touch/no-physical-accessibility boundary text, and does not leak fixture Photos identifiers.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new probe and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v68-review-tap-target-probe-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v68-review-tap-target-probe-unit -resultBundlePath /tmp/bracketer-v68-review-tap-target-probe-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v68-review-tap-target-probe-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v68-review-tap-target-probe-ui -derivedDataPath /tmp/bracketer-dd-v68-review-tap-target-probe-ui -resultBundlePath /tmp/bracketer-v68-review-tap-target-probe-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- None for this slice: the unit and focused UI bundles passed on the first counted run.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover the required probe inventory, screenshot matrix identifier requirements, traversal entry requirements, and the existing tap-target audit counts/boundaries.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.tapTargetAudit` through the actual SwiftUI accessibility tree.
- `boundary-proof`: the probe is model/simulator accessibility evidence for expected SwiftUI target contracts, not physical touch ergonomics, real-device hit testing, Photos-byte inspection, final rendered output, or physical-device accessibility proof.

### Goal status

- Goal still open. Verified slice complete. Physical-device proof remains blocked until the real iPhone is available/unlocked.

## 2026-05-28 18:53 PDT - May Goals final review workspace fixture v1

### What changed

- Added `BracketProjectFinalReviewWorkspaceFixtureReport`, a direct-review fixture completeness report that composes the review accessibility contract, VoiceOver traversal fixture, review/export tap-target audit, merge-readiness report, final-output manifest, asset-resource report, image-bundle manifest, exposure comparison, and side-by-side pixel comparison.
- Exposed the report in `BracketProjectReviewHandoffView` through the hidden probe `review.project.finalWorkspace.fixture`.
- Updated `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the final workspace probe is part of the required project-review surface.
- Extended unit/UI tests to assert the final workspace report counts probes, traversal entries, tap-target rows, export surfaces, comparison surfaces, final-output plans, shot rows, checklist text, privacy redaction, no-final-rendered-bytes boundary text, and no VoiceOver/physical-accessibility proof boundary text.
- Updated README and `.codex-maygoals-progress.md` with the new proof boundary and verification record.

### Verification

- Unit proof:
  - Bundle path: `/tmp/bracketer-v67-final-workspace-fixture-unit-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /tmp/bracketer-dd-v67-final-workspace-fixture-unit -resultBundlePath /tmp/bracketer-v67-final-workspace-fixture-unit-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=230`, `failedTests=0`, `skippedTests=0`, `totalTestCount=230`.
- Focused UI proof:
  - Bundle path: `/tmp/bracketer-v67-final-workspace-fixture-ui-tests.xcresult`.
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -quiet test -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract -parallel-testing-enabled NO -jobs 1 -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v67-final-workspace-fixture-ui -derivedDataPath /tmp/bracketer-dd-v67-final-workspace-fixture-ui -resultBundlePath /tmp/bracketer-v67-final-workspace-fixture-ui-tests.xcresult`.
  - Result: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Both result bundles ran on iPhone 17 Pro simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Failures encountered and resolved

- The first full v67 unit bundle failed one assertion because the boundary copy said `running VoiceOver` while the contract expected the clearer phrase `does not run VoiceOver`. The copy was tightened and the full unit bundle passed on rerun.
- A focused Swift Testing selector using `BracketerTests/BracketerTests/bracketProjectFinalReviewWorkspaceFixtureReportCoversReviewExportWorkspace` executed `0` tests; it was not counted as proof.
- Repeated Claude offload attempts using `claude --dangerously-skip-permissions` returned `You've hit your session limit - resets 7:30pm (America/Los_Angeles)`, so no Claude edits or recommendations were counted.
- Xcode emitted the pre-existing `OrientationManager` main-actor warning and UI debugger-version warning during successful runs; neither failed the counted bundles.

### Proof category

- `pure-model-proof`: unit tests cover report schema/source, completeness, counts, checklist wording, no-final-rendered-bytes boundary, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.finalWorkspace.fixture` is exposed through the actual SwiftUI accessibility tree.
- `boundary-proof`: the report explicitly does not inspect Photos bytes, expose Photos identifiers, decode RAW pixels, render final output, run VoiceOver, prove physical tap ergonomics, or prove physical-device accessibility.

### Goal status

- Goal still open. Verified slice complete. Physical-device proof remains blocked until the real iPhone is available/unlocked.

## 2026-05-28 13:05 PDT - May Goals reduced motion gating v1

### Changes

- Added `BracketerReducedMotionContract`, a schema-backed policy that verifies the first scoped Reduce Motion runtime contract before the Settings > About Reduced Motion row can report `Verified`.
- Added `ModernDesignSystem.Animations.motionAware` and wired `accessibilityReduceMotion` through the main camera/settings shell: camera chrome toggles, Settings sheet presentation/dismissal, toast transitions, app-intent panel routing, and the Settings grid preview collapse spring/move motion to opacity or no animation when Reduce Motion is enabled.
- Updated Settings > About UI tests so default and forced accessibility-environment paths prove the Reduced Motion row is visible as `Verified`, while incomplete contracts still degrade to follow-up/observed status in unit coverage.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new proof boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v45-reduced-motion-unit-tests-1779998471.xcresult`
  - `result=Passed`
  - `passedTests=210`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=210`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v45-reduced-motion-ui-tests-1779998548.xcresult`
  - `result=Passed`
  - `passedTests=2`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=2`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after code, tests, docs, progress, and ledger updates.

### Proof Boundary

- This proves a scoped simulator-visible Reduce Motion policy for the camera/settings shell, not every animation in the app.
- This does not prove physical-device VoiceOver behavior, Dynamic Type screenshot layout, high-contrast screenshot rendering, or real-iPhone accessibility behavior.

### Next Slice

- Continue Wave Family N with Dynamic Type extra-large layout proof, high-contrast visual proof, or a broader review/workspace tap-target audit while the physical iPhone remains unavailable.

## 2026-05-28 13:09 PDT - May Goals high contrast and accessibility environment evidence v1

### Changes

- Added `BracketerAccessibilityAudit.EnvironmentEvidence` so Settings > About can report the observed Dynamic Type label, accessibility-size status, Reduce Motion state, and High Contrast state at `settings.accessibility.environment`.
- Added the deterministic `-ui-testing-force-accessibility-environment` evidence path for UI tests. It drives an accessibility-heavy audit state through the model without attempting to mutate read-only SwiftUI environment keys or claiming production accessibility settings changed.
- Added `BracketerHighContrastContract`, a schema-backed Settings > About high-contrast policy: status is never color-only, every audit row keeps icon/text/accessibility-value status, and Increased Contrast strengthens the visible audit-row border.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the observed-environment and high-contrast proof boundary.

### Verification

- Failed/diagnostic attempts:
  - Read-only Claude offload attempts using `claude --dangerously-skip-permissions` hit the session limit (`resets 2:30pm America/Los_Angeles`); no files were modified by Claude.
  - `/tmp/bracketer-v45-accessibility-environment-unit-tests-1780040100.xcresult` failed to compile because `accessibilityReduceMotion` is a read-only SwiftUI environment key and the guessed `accessibilityContrast` key is not available in this SDK.
  - `/tmp/bracketer-v45-accessibility-environment-unit-tests-1780040200.xcresult` failed stale unit expectations after the reduced-motion/high-contrast contracts changed the audit verified/follow-up counts.
  - `/tmp/bracketer-v45-accessibility-environment-unit-tests-1780040300.xcresult` hit an Xcode build database lock while another Bracketer unit build was active and was not counted as proof.
- Clean unit bundle: `/tmp/bracketer-v45-accessibility-environment-unit-tests-1780040400.xcresult`
  - `result=Passed`
  - `passedTests=210`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=210`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Clean focused UI bundle: `/tmp/bracketer-v45-accessibility-environment-ui-tests-1780040500.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testAccessibilityAuditReflectsForcedAccessibilityEnvironment`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Additional clean v46 unit bundle: `/tmp/bracketer-v46-high-contrast-unit-tests-1779999030.xcresult`
  - `result=Passed`
  - `passedTests=210`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=210`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Additional clean v46 focused UI bundle: `/tmp/bracketer-v46-high-contrast-ui-tests-1779999136.xcresult`
  - Tests: `BracketerUITests/BracketerUITests/testPhysicalProofIngestorReadinessExposesSummaryCountContract` and `BracketerUITests/BracketerUITests/testAccessibilityAuditReflectsForcedAccessibilityEnvironment`.
  - `result=Passed`
  - `passedTests=2`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=2`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.

### Proof Boundary

- `pure-model-proof`: unit tests cover environment evidence, high-contrast contract truth, audit status counts, incomplete-contract fallback, and Codable round trips.
- `simulator-ui-proof`: the focused UI test proves forced Dynamic Type, Reduce Motion, and High Contrast evidence appears in Settings, with Dynamic Type observed and Reduced Motion/High Contrast verified.
- This does not prove app-wide high-contrast screenshots, Dynamic Type layout screenshots, physical-device VoiceOver behavior, real iPhone accessibility settings, or physical iPhone accessibility behavior.

### Next Slice

- Continue Wave Family N with Dynamic Type extra-large screenshot/layout proof, broader app-wide high-contrast visual proof, or review/workspace tap-target coverage.

## 2026-05-28 13:27 PDT - May Goals dynamic type accessibility layout proof v1

### Changes

- Added a real app-root UI-test Dynamic Type path: `-ui-testing-force-accessibility-environment` and `-ui-testing-force-accessibility-dynamic-type` now apply SwiftUI `.dynamicTypeSize(.accessibility3)` through `UITestDynamicTypeSizeModifier`.
- Tightened `BracketerDynamicTypeContract` so the Dynamic Type audit row is verified only when an accessibility-size environment is observed and the scoped Settings > About audit-row layout contract is true.
- Updated `ModernAccessibilityAuditRow` to stack status icon/text above detail copy at accessibility Dynamic Type sizes, preserve stable row identifiers, and expose `Dynamic Type layout: Stacked` in the row accessibility value.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and UI tests with the scoped proof boundary.

### Verification

- Diagnostic attempts:
  - Read-only Claude offload attempt using `claude --dangerously-skip-permissions` hit the Claude session limit (`resets 2:30pm America/Los_Angeles`); no files were modified by Claude.
  - `/tmp/bracketer-v47-dynamic-type-unit-tests-1780041600.xcresult` failed before test execution because the simulator test host was killed while bootstrapping after an `xcrun`/`simctl` diagnostic-collection error; it was not counted as proof.
  - `/tmp/bracketer-v47-dynamic-type-ui-tests-1780041500.xcresult` failed to compile after the live Dynamic Type contract gained two additional guard fields and one fixture still used the shorter initializer; the fixture was reconciled before the clean reruns.
- Unit bundle: `/tmp/bracketer-v47-dynamic-type-unit-tests-1779999765.xcresult`
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=210`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=210`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Additional shell unit rerun: `/tmp/bracketer-v47-dynamic-type-unit-tests-1780041700.xcresult`
  - `result=Passed`
  - `passedTests=210`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=210`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v47-dynamic-type-ui-tests-1779999850.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testAccessibilityAuditReflectsForcedAccessibilityEnvironment`.
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
  - The test kept a screenshot attachment named `Settings About Accessibility Audit - Accessibility 3`.
- Additional shell focused UI rerun: `/tmp/bracketer-v47-dynamic-type-ui-tests-1780041800.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testAccessibilityAuditReflectsForcedAccessibilityEnvironment`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after code, tests, docs, progress, and ledger updates.

### Proof Boundary

- `pure-model-proof`: unit tests cover Dynamic Type contract truth, default follow-up status without an accessibility-size run, verified status when Accessibility 3 is observed, incomplete-contract fallback, and Codable round trip.
- `simulator-ui-proof`: focused UI test proves the Accessibility 3 app-root path, visible environment evidence, verified Dynamic Type row, and stacked accessibility-row value in Settings > About.
- This does not prove app-wide Dynamic Type screenshots, physical-device VoiceOver behavior, real iPhone accessibility settings, or every review/export surface at accessibility sizes.

### Next Slice

- Continue Wave Family N with broader tap-target coverage, review/workspace accessibility coverage, or app-wide Dynamic Type/high-contrast screenshot evidence while physical-device proof remains blocked by the unavailable iPhone.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 13:40 PDT - May Goals broader tap-target audit contract v1

### Changes

- Added `BracketerTapTargetContract`, a schema-backed 44 pt tap-target policy for compact Apple Intelligence refresh/recipe controls, camera chrome buttons, the compact PRO top-bar button, and the Settings close button.
- Enforced a 44 pt minimum frame on `CompactProControlsBadge`.
- Gave `settings.closeButton` a fixed 44 pt frame instead of relying only on icon padding.
- Added `testAccessibilityAuditTapTargetContractListsCameraChromeControls`, a short focused Settings > About UI test for the expanded tap-target audit row.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and unit tests with the expanded proof boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v48-tap-target-unit-tests-1780000701.xcresult`
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=210`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=210`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Diagnostic UI attempts not counted as proof:
  - `/tmp/bracketer-v48-tap-target-ui-tests-1780000296.xcresult` failed a case-sensitive `Compact PRO` assertion before the audit detail was normalized.
  - `/tmp/bracketer-v48-tap-target-ui-tests-1780000372.xcresult` and `/tmp/bracketer-v48-tap-target-ui-tests-1780000506.xcresult` crashed with `signal kill` in the long Device Proof UI test harness.
  - `/tmp/bracketer-v48-tap-target-ui-tests-1780042000.xcresult` and `/tmp/bracketer-v48-tap-target-ui-tests-1780042100.xcresult` also crashed with `signal kill` through Xcode's simulator diagnostics path after the copy fix; the extra booted Bracketer UI-test simulator was shut down before the final diagnostics-disabled rerun.
- Focused UI bundle: `/tmp/bracketer-v48-tap-target-ui-tests-1780000740.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testAccessibilityAuditTapTargetContractListsCameraChromeControls`.
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Diagnostics-disabled focused UI shell rerun: `/tmp/bracketer-v48-tap-target-ui-tests-1780042200.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testPhysicalProofIngestorReadinessExposesSummaryCountContract`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after code, tests, docs, progress, and ledger updates.

### Proof Boundary

- `pure-model-proof`: unit tests cover tap-target contract truth, expanded control list, failure when compact Apple Intelligence controls fall below 44 pt, and Codable round trip.
- `simulator-ui-proof`: focused UI test proves the expanded Settings > About tap-target row mentions Apple Intelligence controls, camera chrome buttons, compact PRO top-bar button, and Settings close button.
- This does not prove every tappable surface in the app, every review/export control, or physical-device touch ergonomics.

### Next Slice

- Continue Wave Family N with review/workspace accessibility coverage, app-wide accessibility screenshot evidence, or broader camera/review tap-target audits while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 18:30 PDT - May Goals review/export tap-target audit v1

### Changes

- Added `BracketProjectReviewTapTargetAudit`, a schema-backed review/export ergonomics model that inventories expected 44 pt tap targets for selected-shot navigation, representation toggle, close button, selected-shot summary, export/resource/image-bundle cards, comparison cards, and shot rows.
- The audit reports row-level identifiers, scopes, measured points, minimum points, status, verified/follow-up counts, and a model-only proof boundary.
- Added unit coverage for the 11-row verified path, previous/next/toggle/close/export/resource/bundle/comparison/shot-row coverage, privacy redaction, physical-touch boundary wording, failing close/export follow-up detection, and Codable round trip.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the review/export tap-target audit boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v66-review-export-tap-target-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v66-review-export-tap-target-unit`, and `-resultBundlePath /tmp/bracketer-v66-review-export-tap-target-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=229`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=229`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Proof Boundary

- `pure-model-proof`: unit tests cover the expected 44 pt model inventory, follow-up detection, accessibility identifiers, row scopes, privacy redaction, and Codable stability.
- This does not measure physical touch ergonomics, prove real-device hit testing, inspect raw photo bytes, expose Photos asset identifiers, render final output, or prove physical-device accessibility.

### Next Slice

- Continue Wave F/G/N with app-wide accessibility screenshot expansion, dynamic-type edge cases in the enlarged review workspace, real registration proof once captures are available, or physical motion sampling proof once the iPhone is available.

## 2026-05-28 18:24 PDT - May Goals feature-match fixture report v1

### Changes

- Added `BracketProjectFeatureMatchFixtureReport`, a schema-backed deterministic feature-matching fixture report that composes focus/edge fixture facts with synthetic motion/alignment offsets.
- The report produces per-shot feature-candidate counts, matched-pair counts, outlier counts, match-confidence percentages, roles, recommendations, aggregate totals, and guidance for the future real registration seam.
- Kept the boundary explicit: this is fixture scaffolding only, not real feature inspection, real pixel matching, descriptor extraction, homography solving, optical flow, Photos-byte inspection, RAW decoding, final rendering, or physical-device proof.
- Added unit coverage for schema/source, 5-shot guide count, baseline, feature-anchor role, candidate/match/outlier totals, confidence summary, privacy redaction, no-real-feature/no-descriptor/no-homography boundary wording, and Codable round trip.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the feature-match fixture boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v65-feature-match-fixture-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v65-feature-match-fixture-unit`, and `-resultBundlePath /tmp/bracketer-v65-feature-match-fixture-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=228`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=228`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Proof Boundary

- `pure-model-proof`: unit tests cover deterministic candidate/match/outlier derivation, baseline feature-anchor role, aggregate match summaries, boundary wording, privacy redaction, and Codable stability.
- This does not inspect real image features, match real pixels, compute descriptors, solve homographies, run optical flow, inspect Photos bytes, decode RAW pixels, render final output, or prove physical-device captures.

### Next Slice

- Continue Wave F/G/N with real registration proof once real captures are available, physical-device motion sampling proof once the iPhone is available, broader review/export tap-target audits, or deeper final-workspace fixture coverage.

## 2026-05-28 18:18 PDT - May Goals CoreMotion scalar recorder seam v1

### Changes

- Added `CaptureMotionAccumulator`, a pure scalar reducer for CoreMotion samples that records sample count, peak angular velocity, peak acceleration, and quality label without storing raw sensor streams.
- Added `CaptureMotionRecorder`, a capture-lifecycle recorder that starts `CMMotionManager` device-motion updates for real bracket captures, records samples on a serial operation queue, stops at sequence finish, and emits a `BracketManifest.CaptureMotionSnapshot`.
- Wired `CameraController` so real bracket capture starts the recorder alongside capture start time and writes the recorder's scalar snapshot into the Photos-backed manifest path.
- Kept simulator/UI fixture behavior explicit: those paths still write unavailable motion snapshots and do not pretend to prove physical-device samples.
- Added unit coverage for no-sample unavailable snapshots and two-sample scalar reduction into `90` deg/s peak angular velocity, `1200` milli-g peak acceleration, high-motion quality labeling, privacy boundary wording, and Codable round trip.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` to distinguish the live sampler seam from raw sensor storage or physical-device proof.

### Verification

- Unit bundle: `/tmp/bracketer-v64-coremotion-scalar-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v64-coremotion-scalar-unit`, and `-resultBundlePath /tmp/bracketer-v64-coremotion-scalar-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=227`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=227`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Carried-forward UI proof for the unchanged review surface:
  - `/tmp/bracketer-v63-motion-metadata-ui-tests.xcresult`
  - `result=Passed`
  - `passedTests=1`
  - This proves `review.project.motionMetadata.card` in the simulator accessibility tree, not real motion sampling.

### Proof Boundary

- `pure-model-proof`: unit tests cover scalar reduction, no-sample unavailable fallback, high-motion label thresholds, privacy boundary text, and Codable stability.
- `lifecycle-seam-proof`: `CameraController` starts and finishes the recorder in the real capture path and stores the resulting manifest snapshot.
- This does not prove a physical iPhone produced CoreMotion samples, store raw CMMotion data, keep accelerometer or gyroscope streams, inspect Photos bytes, decode RAW pixels, compute alignment, measure blur, estimate ghosting, render final output, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G/N with a physical-device motion sampling proof once the iPhone is available, richer synthetic feature-matching fixtures, broader review/export tap-target audits, or deeper final-workspace fixture coverage.

## 2026-05-28 18:10 PDT - May Goals motion metadata capture contract v1

### Changes

- Added `BracketManifest.CaptureMotionSnapshot`, a bounded scalar motion-metadata manifest contract for sample availability/count, capture duration, peak angular velocity, peak acceleration, quality label, source, and privacy boundary.
- Updated simulated, UI-fixture, and current camera capture paths to write explicit unavailable motion snapshots until live CMMotion sampling is connected, rather than implying missing motion metadata is physical proof.
- Added `BracketProjectMotionMetadataReport`, a schema-backed selected-project review report that summarizes the motion snapshot and renders at `review.project.motionMetadata.card` with unavailable/available guidance and explicit no-raw-CMMotion/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the motion-metadata card.
- Added unit coverage for unavailable and available scalar motion snapshots, report schema/source, unavailable fixture summaries, privacy redaction, no-raw-sensor boundary wording, and Codable round trips.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Motion Metadata Capture`, `0 motion samples captured`, unavailable metadata copy, no-live-IMU boundary text, no-raw-CMMotion copy, no-physical-device-proof copy, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family F/N evidence with the motion metadata capture boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v63-motion-metadata-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v63-motion-metadata-unit`, and `-resultBundlePath /tmp/bracketer-v63-motion-metadata-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=226`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=226`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Focused UI bundle: `/tmp/bracketer-v63-motion-metadata-ui-tests.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-jobs 1`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v63-motion-metadata-ui`, `-derivedDataPath /tmp/bracketer-dd-v63-motion-metadata-ui`, and `-resultBundlePath /tmp/bracketer-v63-motion-metadata-ui-tests.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Non-proof attempts:
  - `claude --dangerously-skip-permissions -p ...` returned the session-limit message `You've hit your session limit · resets 7:30pm (America/Los_Angeles)`. No Claude output or file edits were counted for this slice.

### Proof Boundary

- `pure-model-proof`: unit tests cover the motion snapshot scalar schema, unavailable and available summaries, manifest-backed review report, privacy redaction, no-raw-sensor boundary text, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.motionMetadata.card` is exposed through the actual simulator accessibility tree.
- This does not capture live raw CMMotion samples, store accelerometer or gyroscope streams, prove hardware motion availability, inspect Photos bytes, decode RAW pixels, compute real alignment, measure blur, estimate ghosting, render final output, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G/N with live CMMotion sampling once hardware proof is available, richer synthetic feature-matching fixtures, broader review/export tap-target audits, or deeper final-workspace fixture coverage while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 17:46 PDT - May Goals alignment explanation notes v1

### Changes

- Added `BracketProjectAlignmentExplanationReport`, a schema-backed selected-project review report that translates deterministic alignment-transform confidence, ghosting-risk scores, moving-region mask coverage, and alignment-performance work units into photographer-readable review explanations.
- Rendered the alignment-explanation card in `BracketProjectReviewHandoffView` at `review.project.alignmentExplanation.card` with baseline, high-attention summary, top-watch summary, per-shot explanation rows, guidance, and explicit no-real-pixel-analysis/no-Instruments/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the alignment-explanation card.
- Added unit coverage for schema/source, 5-shot explanation counts, baseline, explanation roles, high-attention/top-watch summaries, photographer guidance, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Alignment Explanation`, `5 explanations`, synthetic/no-real-pixel-analysis boundary text, deghosting-mask and Instruments exclusions, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family F/N evidence with the deterministic user-facing explanation boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v62-alignment-explanation-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v62-alignment-explanation-unit`, and `-resultBundlePath /tmp/bracketer-v62-alignment-explanation-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=224`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=224`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Focused UI bundle: `/tmp/bracketer-v62-alignment-explanation-ui-tests.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-jobs 1`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v62-alignment-explanation-ui`, `-derivedDataPath /tmp/bracketer-dd-v62-alignment-explanation-ui`, and `-resultBundlePath /tmp/bracketer-v62-alignment-explanation-ui-tests.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Non-proof attempts:
  - `timeout 120s claude --dangerously-skip-permissions` failed because `timeout` is not installed in this shell; direct `claude --dangerously-skip-permissions` returned the session-limit message `You've hit your session limit · resets 7:30pm (America/Los_Angeles)`. No Claude output or file edits were counted for this slice.
  - The first BB focused UI attempt failed before the UI test completed with `BracketerUITests-Runner ... Early unexpected exit` and a diagnostic-collection warning that `xcrun` could not find `simctl`; its result bundle was not counted and was replaced by the passing rerun above.
  - Stale duplicate A113-focused v62 UI xcodebuild children from an older parent appeared during the BB reruns and were terminated; no A113 result bundle is counted as proof.

### Proof Boundary

- `pure-model-proof`: unit tests cover alignment-explanation schema, source, 5-shot explanation counts, baseline, user-facing explanation roles, high-attention/top-watch summaries, photographer guidance, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.alignmentExplanation.card` is exposed through the actual simulator accessibility tree.
- This does not detect real image features, match pixels, run optical flow, segment subjects, compute deghosting masks, run Instruments, measure CPU/GPU time, inspect Photos bytes, decode RAW pixels, render final output, decide final HDR merge quality, prove physical-device performance, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G/N with motion metadata capture scaffolding, richer synthetic feature-matching fixtures, broader review/export tap-target audits, or deeper final-workspace fixture coverage while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 17:13 PDT - May Goals alignment performance notes v1

### Changes

- Added `BracketProjectAlignmentPerformanceReport`, a schema-backed selected-project review report that combines deterministic alignment-transform feature-pair counts and moving-region mask tile counts into per-shot work-unit budgets, total synthetic work, peak-work summaries, and benchmark guidance.
- Rendered the alignment-performance card in `BracketProjectReviewHandoffView` at `review.project.alignmentPerformance.card` with baseline, total/peak work summaries, per-shot rows, guidance, and explicit no-Instruments/no-physical-performance boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the alignment-performance card.
- Added unit coverage for schema/source, 5-shot performance-note counts, baseline, performance roles, alignment/mask work units, total and peak work, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Alignment Performance Notes`, `5 performance notes`, synthetic/no-Instruments boundary text, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family F/N evidence with the deterministic performance-planning boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v61-alignment-performance-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v61-alignment-performance-unit`, `-derivedDataPath /tmp/bracketer-dd-v61-alignment-performance-unit`, and `-resultBundlePath /tmp/bracketer-v61-alignment-performance-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=223`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=223`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Focused UI bundle: `/tmp/bracketer-v61-alignment-performance-ui-tests.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-skip-testing:BracketerTests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `CLANG_MODULE_CACHE_PATH=/tmp/bracketer-module-cache-v61-alignment-performance-ui`, `-derivedDataPath /tmp/bracketer-dd-v61-alignment-performance-ui`, and `-resultBundlePath /tmp/bracketer-v61-alignment-performance-ui-tests.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Non-proof attempts:
  - The first v61 unit command failed before Xcode started because `rm -rf /tmp/bracketer-dd-v61-alignment-performance-unit` could not remove a non-empty module-cache directory; no result bundle was counted as proof.
  - Claude offload was attempted with `claude --dangerously-skip-permissions`, but the CLI returned the session-limit message `You've hit your session limit · resets 7:30pm (America/Los_Angeles)`. No Claude output or file edits were counted for this slice.

### Proof Boundary

- `pure-model-proof`: unit tests cover alignment-performance schema, source, 5-shot note counts, baseline, performance roles, alignment/mask work units, total/peak work, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.alignmentPerformance.card` is exposed through the actual simulator accessibility tree.
- This does not run Instruments, measure CPU/GPU time, profile memory, prove dropped-frame behavior, inspect Photos bytes, decode RAW pixels, render final output, decide final HDR merge quality, prove physical-device performance, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G/N with richer synthetic alignment fixtures, broader review/export tap-target audits, or deeper final-workspace fixture coverage while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 16:48 PDT - May Goals moving-region mask scaffold v1

### Changes

- Added `BracketProjectMovingRegionMaskReport`, a schema-backed selected-project review report that derives per-shot synthetic mask tile counts, coverage percentages, priority labels, roles, and recommendations from deterministic ghosting-risk scores.
- Rendered the moving-region mask card in `BracketProjectReviewHandoffView` at `review.project.movingRegionMask.card` with baseline, high-priority guide count, max mask coverage, per-shot rows, guidance, and explicit no-subject-segmentation/no-real-deghosting/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the moving-region mask card.
- Added unit coverage for schema/source, 5-shot mask counts, baseline, mask roles, tile counts, coverage percentages, high-priority guide count, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Moving-Region Mask`, `5 mask guides`, synthetic/no-real-subject-segmentation boundary text, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family C/F evidence with the deterministic manifest-scaffold boundary.
- Claude offload: read-only `claude --dangerously-skip-permissions` audit work mapped the v60 insertion points, proof gaps, and boundary pitfalls. A second read-only audit flagged a misleading coverage clamp, one-shot pluralization, and narrower boundary wording; Codex fixed those before the final reruns. No files were modified by Claude.

### Verification

- Unit bundle: `/tmp/bracketer-v60-moving-region-mask-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v60-moving-region-mask-unit`, and `-resultBundlePath /tmp/bracketer-v60-moving-region-mask-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=222`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=222`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Focused UI bundle: `/tmp/bracketer-v60-moving-region-mask-ui-tests.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v60-moving-region-mask-ui`, and `-resultBundlePath /tmp/bracketer-v60-moving-region-mask-ui-tests.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Non-proof attempts:
  - The first post-cleanup v60 focused UI rerun hung without a readable result-bundle `Info.plist`; stale Bracketer UI runner/app/xcodebuild children were killed and the later BB simulator rerun above is the counted proof.
  - A concurrent generic-path v60 UI run at `/tmp/bracketer-v60-moving-region-mask-ui-tests.xcresult` existed during this continuation and is not counted as proof.

### Proof Boundary

- `pure-model-proof`: unit tests cover moving-region mask schema, source, 5-shot guide counts, baseline selection, roles, tile counts, coverage percentages, high-priority count, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.movingRegionMask.card` is exposed through the actual simulator accessibility tree.
- This does not segment moving subjects, run optical flow, compute real deghosting masks, inspect Photos bytes, decode RAW pixels, read real motion sensors, render final output, decide final HDR merge quality, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G/N with alignment performance notes, richer synthetic feature-matching fixtures, broader review/export tap-target audits, or deeper final-workspace fixture coverage while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 16:33 PDT - May Goals alignment-transform scaffold v1

### Changes

- Added `BracketProjectAlignmentTransformReport`, a schema-backed selected-project review report that derives per-shot synthetic feature-pair counts, translation vectors, transform confidence, and guidance from manifest-backed overlay offsets.
- Rendered the alignment-transform card in `BracketProjectReviewHandoffView` at `review.project.alignmentTransform.card` with baseline, synthetic feature-pair total, average confidence, per-shot rows, guidance, and explicit no-feature-matching/no-homography/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the alignment-transform card.
- Added unit coverage for schema/source, 5-shot transform counts, baseline, transform roles, synthetic feature-pair counts, translations, confidence values, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Alignment Transform`, `5 transform guides`, synthetic/no-real-feature-matching boundary text, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family C/F/N evidence with the deterministic manifest-scaffold boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v59-alignment-transform-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v59-alignment-transform-unit`, and `-resultBundlePath /tmp/bracketer-v59-alignment-transform-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=221`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=221`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Focused UI bundle: `/tmp/bracketer-v59-alignment-transform-ui-tests.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-dd-v59-alignment-transform-ui`, and `-resultBundlePath /tmp/bracketer-v59-alignment-transform-ui-tests.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.

### Proof Boundary

- `pure-model-proof`: unit tests cover alignment-transform schema, source, 5-shot transform counts, baseline selection, roles, synthetic feature pairs, translations, confidence, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.alignmentTransform.card` is exposed through the actual simulator accessibility tree.
- This does not detect real image features, match pixels, compute real homographies or warps, inspect Photos bytes, decode RAW pixels, render final output, decide final HDR merge quality, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G with moving-region mask placeholders, richer alignment performance notes, or broader review/export tap-target audits while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 16:23 PDT - May Goals ghosting-risk scaffold v1

### Changes

- Added `BracketProjectGhostingRiskReport`, a schema-backed selected-project review report that derives per-shot deghosting roles, synthetic ghosting-risk scores, risk labels, and guidance from manifest facts, synthetic blur-risk scores, and synthetic alignment offsets.
- Rendered the ghosting-risk card in `BracketProjectReviewHandoffView` at `review.project.ghostingRisk.card` with baseline, high-risk count, max risk, per-shot rows, guidance, and explicit no-optical-flow/no-moving-subject-detection/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the ghosting-risk card.
- Added unit coverage for schema/source, 5-shot risk counts, baseline, ghosting roles, high-risk count, max synthetic ghosting risk, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Ghosting Risk`, `5 ghosting-risk guides`, synthetic/no-moving-subject-detection boundary text, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family C/F/G evidence with the deterministic manifest-scaffold boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v58-ghosting-risk-unit-tests-1780009886.xcresult`
  - Command: XcodeBuildMCP `test_sim` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v58-ghosting-risk-unit-tests-1780009886.xcresult`.
  - `result=Passed`
  - `passedTests=220`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=220`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v58-ghosting-risk-ui-tests-1780010345.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06'`, `-derivedDataPath /tmp/bracketer-v58-ghosting-risk-ui-dd-1780010060`, `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-skip-testing:BracketerTests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v58-ghosting-risk-ui-tests-1780010345.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Non-proof attempts:
  - The XcodeBuildMCP unit wrapper timed out at 120s, but the underlying `xcodebuild` completed and produced the readable passed unit bundle above.
  - `/tmp/bracketer-v58-ghosting-risk-ui-tests-1780010060.xcresult` was interrupted before producing a readable result-bundle `Info.plist`; it is not counted as proof.
  - A concurrent generic-path BB simulator v58 UI run existed at `/tmp/bracketer-v58-ghosting-risk-ui-tests.xcresult`; this continuation did not start it and does not count it as proof.

### Proof Boundary

- `pure-model-proof`: unit tests cover ghosting-risk schema, source, 5-shot risk counts, baseline selection, roles, high-risk count, max synthetic ghosting risk, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.ghostingRisk.card` is exposed through the actual simulator accessibility tree.
- This does not run optical flow, segment moving subjects, compute deghosting masks, inspect Photos bytes, decode RAW pixels, read real motion sensors, render final output, decide final HDR merge quality, or prove physical-device behavior.

### Next Slice

- Continue Wave F/G with feature-matching/alignment transform scaffolding, moving-region mask placeholders, or broader review/export tap-target audits while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 16:03 PDT - May Goals motion-blur risk scaffold v1

### Changes

- Added `BracketProjectMotionBlurRiskReport`, a schema-backed selected-project review report that derives per-shot blur roles, synthetic exposure-pressure scores, synthetic blur-risk scores, risk labels, and guidance from manifest facts plus the synthetic motion/alignment overlay scores.
- Rendered the motion/blur card in `BracketProjectReviewHandoffView` at `review.project.motionBlur.card` with baseline, high-risk count, max risk, per-shot rows, guidance, and explicit no-shutter/no-IMU/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the motion/blur card.
- Added unit coverage for schema/source, 5-shot risk counts, baseline, blur roles, high-risk count, max synthetic blur risk, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Motion/Blur Risk`, `5 blur-risk guides`, synthetic/no-real-shutter boundary text, and does not leak fixture asset identifiers.
- Replaced the motion/blur UI assertion's generic all-descendants lookup with the typed review-surface helper, matching the earlier v56 fix for the enlarged review accessibility tree.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family C/G evidence with the deterministic manifest-scaffold boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v57-motion-blur-risk-unit-tests-1780009335.xcresult`
  - Command: XcodeBuildMCP `test_sim` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v57-motion-blur-risk-unit-tests-1780009335.xcresult`.
  - `result=Passed`
  - `passedTests=219`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=219`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v57-motion-blur-risk-ui-tests-1780009580.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild test` with `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-skip-testing:BracketerTests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath /tmp/bracketer-v57-motion-blur-risk-ui-dd-1780009580`, and `-resultBundlePath /tmp/bracketer-v57-motion-blur-risk-ui-tests-1780009580.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Non-proof attempts:
  - XcodeBuildMCP UI attempt `/tmp/bracketer-v57-motion-blur-risk-ui-tests-1780009445.xcresult` failed before the test body on the cached `test-without-building` path and produced no readable result-bundle `Info.plist`.
  - Direct quiet UI attempt `/tmp/bracketer-v57-motion-blur-risk-ui-tests-1780009481.xcresult` was interrupted during build, left an orphaned compiler child that cleared, and produced no readable result-bundle `Info.plist`.

### Proof Boundary

- `pure-model-proof`: unit tests cover motion/blur schema, source, 5-shot risk counts, baseline selection, roles, high-risk count, max synthetic blur risk, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.motionBlur.card` is exposed through the actual simulator accessibility tree.
- This does not read real shutter speed, exposure duration, ISO, CMMotion/IMU samples, optical flow, ghosting masks, Photos bytes, RAW pixels, final rendered output, or physical-device captures.

### Next Slice

- Continue Wave F/G with richer synthetic alignment fixtures, ghosting-risk scaffolding, or broader review/export tap-target audits while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 15:51 PDT - May Goals motion-alignment overlay scaffold v1

### Changes

- Added `BracketProjectMotionAlignmentOverlay`, a schema-backed selected-project review report that derives per-shot overlay roles, synthetic motion scores, synthetic alignment offsets, risk labels, and guidance from manifest facts only.
- Rendered the motion/alignment card in `BracketProjectReviewHandoffView` at `review.project.motionAlignment.card` with baseline, motion, alignment, per-shot rows, guidance, and explicit no-IMU/no-real-alignment/no-physical-proof boundary copy.
- Extended `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix require the motion/alignment card.
- Added unit coverage for schema/source, 5-shot guide counts, baseline, overlay roles, synthetic motion/alignment values, boundary wording, privacy redaction, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the card exists, includes `Motion/Alignment Overlay`, `5 overlay guides`, synthetic/no-IMU boundary text, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family G evidence with the deterministic manifest-scaffold boundary.
- Used `claude --dangerously-skip-permissions` as requested for a read-only scout; Claude recommended this slice as the lowest-risk next Wave G/N target, and the implementation was locally inspected and verified.

### Verification

- Unit bundle: `/tmp/bracketer-v56-motion-alignment-unit-tests-1780007800.xcresult`
  - Command: shell `xcodebuild test` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v56-motion-alignment-unit-tests-1780007800.xcresult`.
  - `result=Passed`
  - `passedTests=218`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=218`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v56-motion-alignment-ui-tests-1780008300.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v56-motion-alignment-ui-tests-1780008300.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Non-proof attempts:
  - Claude's read-only audit caught that the initial boundary wording did not include the exact stronger assertion phrase `does not inspect private Photos bytes`; the boundary was tightened before the counted unit run.
  - `/tmp/bracketer-v56-motion-alignment-ui-tests-1780007900.xcresult` failed before reaching the motion/alignment assertion because the generic `app.descendants(matching: .any)` helper timed out evaluating the first review probe. The focused fixture now uses typed review-surface queries for the giant review accessibility tree, and the quiet rerun passed.
  - `/tmp/bracketer-v56-motion-alignment-ui-tests-1780008100.xcresult` and `/tmp/bracketer-v56-motion-alignment-ui-tests-1780008200.xcresult` were interrupted/corrupted before producing usable result summaries and are not counted as proof.

### Proof Boundary

- `pure-model-proof`: unit tests cover motion/alignment schema, source, 5-shot guide counts, baseline selection, roles, synthetic motion/alignment values, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.motionAlignment.card` is exposed through the actual simulator accessibility tree.
- This does not read real CMMotion/IMU samples, compute real alignment transforms, detect ghosting, inspect Photos bytes, decode RAW pixels, render final output, decide final HDR merge quality, or prove physical-device behavior.

### Next Slice

- Continue Wave G/F with deeper synthetic alignment fixtures, motion/blur risk models, or broader review/export tap-target audits while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 15:32 PDT - May Goals focus-edge inspection review card v1

### Changes

- Confirmed and verified `BracketProjectFocusEdgeInspection`, a schema-backed selected-project review report that derives edge-tile counts, peak edge strength, per-shot focus roles, and guidance from deterministic 4x4 fixture pixels plus manifest metadata.
- Confirmed `BracketProjectReviewHandoffView` renders the focus/edge card at `review.project.focusEdge.card` with baseline, peak-edge, clipped-edge, per-shot role, synthetic edge counts, peak strength, guidance, and explicit no-Photos/no-physical-proof boundary copy.
- Confirmed `BracketProjectReviewAccessibilityContract`, `BracketProjectReviewVoiceOverTraversalSnapshot`, and `BracketerAccessibilityScreenshotMatrix` require the focus/edge card so the selected-project review workspace cannot silently drop it.
- Confirmed the dedicated unit test covers schema/source, 5-shot fixture counts, baseline, roles, synthetic edge candidate counts, summary label, boundary wording, privacy redaction, and Codable round trip.
- Confirmed the focused review accessibility UI test asserts the visible card exists, includes `Focus/Edge Inspection`, `5/5 inspected`, synthetic fixture/private-Photos boundary text, and does not leak fixture asset identifiers.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family G evidence with the deterministic fixture-pixel boundary.
- Used `claude --dangerously-skip-permissions` as requested for focus/edge implementation/audit/doc sidecars; Claude output was treated as worker evidence and locally verified before tracker updates.

### Verification

- Unit bundle: `/tmp/bracketer-v55-focus-edge-unit-tests-1780007400.xcresult`
  - Command: shell `xcodebuild test` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v55-focus-edge-unit-tests-1780007400.xcresult`.
  - `result=Passed`
  - `passedTests=217`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=217`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v55-focus-edge-ui-tests-1780007500.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild test` with `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v55-focus-edge-ui-tests-1780007500.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Non-proof attempts:
  - Orphaned bundle `/tmp/bracketer-v55-focus-edge-unit-tests-1780007200.xcresult` was rejected as evidence because `xcresulttool` reported `result=unknown` and `totalTestCount=0`.
  - First unit run against `/tmp/bracketer-v55-focus-edge-unit-tests-1780007200.xcresult` failed at compile time after a test referenced the static `kind` marker as an instance member; the source now asserts `BracketProjectFocusEdgeInspection.kind`, and the clean rerun passed.

### Proof Boundary

- `pure-model-proof`: unit tests cover focus/edge schema, source, 5-shot fixture counts, baseline selection, roles, synthetic edge counts, boundary text, privacy redaction, and Codable stability.
- `simulator-ui-proof`: focused UI test proves `review.project.focusEdge.card` is exposed through the actual simulator accessibility tree.
- This does not inspect private Photos bytes, decode RAW pixels, measure real focus, prove alignment, prove ghosting, render final output, decide final HDR merge quality, or prove physical-device behavior.

### Next Slice

- Continue Wave Family G/N with motion/alignment overlay scaffolding, broader review/export tap-target audits, or deeper final workspace fixture coverage while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 15:16 PDT - May Goals review VoiceOver traversal snapshot v1

### Changes

- Added `BracketProjectReviewVoiceOverTraversalSnapshot`, a schema-backed selected-project review accessibility inventory derived from `BracketProjectReviewSnapshot`.
- The snapshot orders review summary probes, the accessibility contract, guidance cards, capture/merge/export cards, exposure/pixel comparison probes, every `review.project.shot.<index>` row, and previous/next/representation/close controls.
- Each traversal entry records a stable identifier, label, role, traits, and expected value fragments so simulator UI tests can assert the review accessibility shape without relying on visual layout.
- Rendered the hidden probe in `BracketProjectReviewHandoffView` at `review.project.voiceOverTraversal` using `BracketProjectReviewAccessibilityContract.voiceOverTraversalProbeIdentifier`.
- Extended `BracketProjectReviewAccessibilityContract` and `BracketerAccessibilityScreenshotMatrix` so the selected-project review workspace and future accessibility screenshot matrix both require the traversal probe.
- Added unit coverage for schema completeness, ordering, required identifiers, traits, value fragments, no asset-identifier leakage, boundary wording, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the traversal probe exists and contains the expected review card, shot-row, button-trait, and no-VoiceOver-runtime evidence.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family N evidence with the simulator-only accessibility boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v54-review-voiceover-traversal-unit-tests-1780006900.xcresult`
  - Command: shell `xcodebuild test` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v54-review-voiceover-traversal-unit-tests-1780006900.xcresult`.
  - `result=Passed`
  - `passedTests=216`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=216`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v54-review-voiceover-traversal-ui-tests-1780007000.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild test` with `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v54-review-voiceover-traversal-ui-tests-1780007000.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Hygiene:
  - `git diff --check` passed after code, tests, docs, progress, and ledger updates.
  - `rg -n "[[:blank:]]$"` across touched production, test, docs, progress, and ledger files returned no trailing-whitespace hits.

### Proof Boundary

- `pure-model-proof`: unit tests cover ordered traversal entries, required review probes and controls, traits, value fragments, privacy redaction, boundary text, and Codable stability.
- `simulator-ui-proof`: focused UI test proves the project-review fixture exposes `review.project.voiceOverTraversal` through the actual simulator accessibility tree.
- This does not run VoiceOver, prove hardware rotor order, prove physical-device accessibility, inspect private Photos bytes, expose Photos asset identifiers, persist thumbnails, read final rendered output bytes, or prove precise coordinates.

### Next Slice

- Continue Wave Family G/N with motion/alignment overlay scaffolding, broader review/export tap-target audits, or deeper final workspace fixture coverage while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 14:58 PDT - May Goals before-after scrub plan v1

### Changes

- Added `BracketProjectBeforeAfterScrubPlan`, a schema-backed review model that derives a before/after scrub comparison from manifest exposure facts and existing deterministic side-by-side fixture pixels.
- The model compares the baseline exposure with the selected guard exposure when a guard is selected, or the nearest available guard exposure when the baseline is selected.
- Rendered the scrub plan in `BracketProjectReviewHandoffView` at `review.project.beforeAfterScrub.card` with baseline/compare pills, comparison role, five scrub-stop swatches, and an explicit no-private-Photos-bytes/no-final-HDR boundary.
- Extended `BracketProjectReviewAccessibilityContract` so `review.project.beforeAfterScrub.card` is part of the required selected-project review workspace probe inventory.
- Extended `BracketerAccessibilityScreenshotMatrix` so Project Review Handoff screenshot proof now requires `review.project.beforeAfterScrub.card`.
- Added unit coverage for baseline-to-nearest-guard selection, selected-guard selection, scrub stop positions and preview byte counts, privacy redaction, boundary wording, and Codable round trip.
- Extended the focused review accessibility UI test so the direct review fixture proves the contract includes the scrub probe and the visible card value contains the expected baseline, comparison exposure, stop count, and non-Photos boundary.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family G evidence with the before/after scrub boundary.

### Verification

- Initial unit bundle before adding the screenshot-matrix required identifier: `/tmp/bracketer-v52-before-after-unit-tests.xcresult`
  - `result=Passed`
  - `passedTests=215`
  - `failedTests=0`
- Final unit bundle: `/tmp/bracketer-v53-before-after-unit-tests.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v53-before-after-unit-tests.xcresult`.
  - `result=Passed`
  - `passedTests=216`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=216`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Focused UI bundle: `/tmp/bracketer-v52-before-after-ui-tests.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` with `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v52-before-after-ui-tests.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Hygiene:
  - `git diff --check` passed after code, tests, docs, progress, and ledger updates.
  - `rg -n "[[:blank:]]$"` across touched production, test, docs, progress, and ledger files returned no trailing-whitespace hits.
  - Simulators `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` and `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` were shut down after verification.
  - Stale Bracketer `xcodebuild` runners spawned by an external Codex resume process against the known-bad `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` simulator and a generic build-for-testing destination were terminated during cleanup; they were not counted as proof.

### Proof Boundary

- `pure-model-proof`: unit tests cover deterministic scrub-plan selection, scrub-stop generation, preview byte counts, privacy redaction, boundary text, and Codable stability.
- `simulator-ui-proof`: focused UI test proves the project-review fixture exposes `review.project.beforeAfterScrub.card` through the review accessibility contract and the card accessibility value.
- This is deterministic fixture-pixel review guidance, not private Photos-byte inspection, decoded RAW proof, alignment proof, ghosting proof, final rendered output proof, final HDR merge proof, physical capture proof, or physical-device accessibility proof.

### Next Slice

- Continue Wave Family G/N with motion/alignment overlay scaffolding, broader review/export tap-target coverage, deeper final workspace fixture coverage, or VoiceOver traversal snapshots while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 14:46 PDT - May Goals best-base frame suggestion v1

### Changes

- Added `BracketProjectBestBaseFrameSuggestion`, a schema-backed deterministic suggestion that scores manifest shots by availability, best-exposure marker, neutral EV distance, RAW/processed representation availability, and clipping-warning absence.
- Rendered the suggestion in `BracketProjectReviewHandoffView` at `review.project.bestBaseFrame.card` with selected shot label, confidence, score, guard exposure summary, rationale, and a clear no-private-Photos-bytes/no-final-HDR-decision boundary.
- Extended `BracketProjectReviewAccessibilityContract` so `review.project.bestBaseFrame.card` is part of the required selected-project review workspace probe inventory.
- Added unit coverage for the standard 5-shot fixture selecting `Shot 3 / 0 EV`, reporting `2 darker highlight guards and 2 brighter shadow guards`, preserving the boundary, avoiding asset-identifier leakage, and round-tripping through Codable.
- Extended the focused review accessibility UI test so the direct review fixture proves the contract includes the best-base probe and the visible card value contains the expected selected shot, guard summary, and non-final-HDR boundary.
- Fixed the app-root UI-test accessibility modifier to avoid writing read-only SwiftUI environment keys for Reduce Motion and High Contrast; the forced accessibility evidence remains surfaced through the existing audit model rather than fake environment mutation.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and the Wave Family G checklist with the best-base-frame proof boundary.

### Verification

- First unit bundle, not counted as proof: `/tmp/bracketer-v50-best-base-unit-tests-1780043500.xcresult`
  - Compile failed before tests because `.environment(\.accessibilityReduceMotion, true)` and `.environment(\.colorSchemeContrast, .increased)` targeted read-only SwiftUI environment keys.
  - Fix: keep only the writable `.dynamicTypeSize(.accessibility3)` app-root override; leave Reduce Motion and High Contrast as model-backed UI-test evidence.
- Final unit bundle: `/tmp/bracketer-v50-best-base-unit-tests-1780043600.xcresult`
  - Command: shell `xcodebuild -quiet test` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v50-best-base-unit-tests-1780043600.xcresult`.
  - `result=Passed`
  - `passedTests=213`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=213`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Failed UI bundle, not counted as feature proof: `/tmp/bracketer-v50-best-base-ui-rerun.xcresult`
  - `result=Failed`
  - `failedTests=1`
  - Failure: `Test crashed with signal kill`.
  - Follow-up diagnosis: `xcrun simctl bootstatus BB433905-C31E-4E1A-8F4D-C9D53FFC9D06 -b` ended with `Data Migration Failed`, so the simulator destination was unhealthy.
- Focused UI bundle on clean simulator: `/tmp/bracketer-v50-best-base-ui-26-5.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - Command: shell `xcodebuild -quiet test` on simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`, with `-only-testing:BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v50-best-base-ui-26-5.xcresult`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.5`.
- Hygiene:
  - `git diff --check` passed after code, tests, docs, progress, and ledger updates.
  - `rg -n "[[:blank:]]$"` across touched production, test, docs, progress, and ledger files returned no trailing-whitespace hits.
  - Simulators `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` and `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` were shut down after verification.

### Proof Boundary

- `pure-model-proof`: unit tests cover deterministic base-frame scoring, confidence/rationale, guard exposure summary, no private Photos identifier leakage, boundary text, and Codable stability.
- `simulator-ui-proof`: focused UI test proves the project-review fixture exposes `review.project.bestBaseFrame.card` through the review accessibility contract and the card accessibility value.
- `simulator-health-note`: the 26.4.1 destination `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` currently fails boot migration and should not be used as proof until repaired or recreated.
- This does not prove real merge science, private Photos bytes, decoded RAW pixels, alignment, ghosting, moving-subject masks, final rendered HDR output, physical-device capture behavior, or physical-device accessibility behavior.

### Next Slice

- Continue Wave Family G/N with before/after review polish, motion/alignment overlay scaffolding, broader review/export tap-target coverage, or app-wide accessibility screenshot evidence while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 14:46 PDT - May Goals accessibility screenshot matrix v1

### Changes

- Added `BracketerAccessibilityScreenshotMatrix`, a schema-backed simulator screenshot matrix for Camera Cockpit, Settings About, and Project Review Handoff.
- Settings > About now renders the matrix at `settings.accessibility.screenshotMatrix`, including environment evidence, required identifiers, kept screenshot attachment names, and the no-physical-accessibility proof boundary.
- Kept the app-root UI-test Dynamic Type override on writable `.dynamicTypeSize(.accessibility3)` only, while avoiding fake writes to read-only Reduce Motion and High Contrast SwiftUI environment keys.
- Routed app-owned reduced-motion decisions through `-ui-testing-force-accessibility-environment` for the camera shell, settings sheet, compact camera controls, and grid preview.
- Forced audit-row Increased Contrast styling for the deterministic UI-test route without claiming the real system High Contrast setting changed.
- Split the matrix UI proof into camera/settings and project-review tests so each surface gets a focused XCTest timeout budget and kept screenshot attachments.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and Wave Family N evidence with the app-wide simulator screenshot matrix boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v50-accessibility-screenshot-matrix-unit-tests-1780003900.xcresult`
  - Command: XcodeBuildMCP `test_sim` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v50-accessibility-screenshot-matrix-unit-tests-1780003900.xcresult`.
  - `result=Passed`
  - `passedTests=213`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=213`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Combined UI attempt not counted as final proof: `/tmp/bracketer-v50-accessibility-screenshot-matrix-ui-tests-1780004100.xcresult`
  - `result=Failed`
  - Failure: `Test crashed with signal kill` after camera/settings screenshot capture and while launching the review fixture.
  - Fix: split the proof into two focused tests.
- Camera/Settings UI bundle: `/tmp/bracketer-v50-accessibility-screenshot-matrix-camera-settings-ui-tests-1780004403.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testAccessibilityScreenshotMatrixCapturesCameraAndSettingsSurfaces`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Kept attachments: `Accessibility Matrix - Camera Cockpit - Accessibility 3`, `Accessibility Matrix - Settings About - Accessibility 3`.
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Project Review UI bundle: `/tmp/bracketer-v50-accessibility-screenshot-matrix-review-ui-tests-1780004721.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testAccessibilityScreenshotMatrixCapturesProjectReviewSurface`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Kept attachment: `Accessibility Matrix - Project Review - Accessibility 3`.
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Claude offload:
  - Read-only review attempt using `claude --dangerously-skip-permissions -p ...` exited with code `143` and no usable output; no files were modified by Claude.
  - Follow-up read-only next-slice scouting using `claude --dangerously-skip-permissions -p ...` succeeded and recommended a manifest-backed project-review per-shot exposure-distribution card; no files were modified by Claude.
- `git diff --check`
  - Result: passed after code, tests, docs, progress, and ledger updates.

### Proof Boundary

- `pure-model-proof`: unit tests cover matrix completeness, required identifiers, screenshot attachment names, forced evidence requirements, incomplete-environment fallback, Codable round trip, and boundary text.
- `simulator-ui-proof`: focused UI tests prove Camera Cockpit, Settings About, and Project Review Handoff surfaces under the forced accessibility route and keep screenshots in passing result bundles.
- This does not prove physical-device accessibility, VoiceOver hardware behavior, real system Reduce Motion or High Contrast settings, raw photo bytes, Photos identifiers, final rendered output bytes, or precise coordinates.

### Next Slice

- Implement the manifest-backed project-review per-shot exposure-distribution card recommended by the Claude read-only sidecar, or continue Wave Family N with broader review/export tap-target coverage and VoiceOver traversal snapshots while physical-device accessibility proof remains blocked.

## 2026-05-28 14:56 PDT - May Goals project-review per-shot exposure distribution v1

### Changes

- Added `BracketProjectPerShotExposureDistribution`, a manifest-backed metadata model for baseline exposure, EV spread, darker/brighter guard counts, clipping-warning count, per-shot role, capture state, file type, and available representations.
- Rendered the selected-project review card at `review.project.perShotExposure.card` with the same no-private-Photos-byte/no-pixel-histogram/no-final-output boundary used by the rest of the project-review workspace.
- Added the new probe to `BracketProjectReviewAccessibilityContract`, so the review accessibility contract fails if the per-shot exposure card is omitted.
- Added the card to the Project Review Handoff requirements in `BracketerAccessibilityScreenshotMatrix`.
- Extended unit coverage for deterministic 5-shot exposure distribution, per-shot roles, clipping summaries, privacy redaction, boundary wording, and Codable stability.
- Extended the focused review accessibility UI test so the direct review fixture proves the contract and visible card value expose the new per-shot exposure distribution.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and the Wave Family G checklist with the metadata-only/pixel-histogram boundary.

### Verification

- Unit bundle: `/tmp/bracketer-v52-per-shot-exposure-unit-tests-1780005000.xcresult`
  - Command: XcodeBuildMCP `test_sim` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, `-parallel-testing-enabled NO`, `-skipMacroValidation`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `ONLY_ACTIVE_ARCH=YES`, and `-resultBundlePath /tmp/bracketer-v52-per-shot-exposure-unit-tests-1780005000.xcresult`.
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=215`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=215`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI bundle: `/tmp/bracketer-v52-per-shot-exposure-ui-tests-1780005100.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after code, tests, docs, progress, and ledger updates.

### Proof Boundary

- `pure-model-proof`: unit tests cover baseline/EV-spread/guard counts, clipping-warning counts, per-shot roles, privacy redaction, boundary wording, and Codable round trip.
- `simulator-ui-proof`: focused UI test proves the direct review fixture exposes `review.project.perShotExposure.card` through the accessibility contract and card accessibility value.
- This is metadata-only exposure distribution, not pixel histogram proof, Photos-byte inspection, RAW decode proof, focus-edge proof, alignment proof, ghosting proof, final HDR output proof, or physical-device proof.

### Next Slice

- Continue toward true review-side pixel histogram/focus/edge proof only with explicit pixel fixtures or user-asset-byte access; otherwise continue Wave Family N with broader review/export tap-target coverage and VoiceOver traversal snapshots.

## 2026-05-28 14:12 PDT - May Goals review workspace accessibility contract v1

### Changes

- Added `BracketProjectReviewAccessibilityContract`, a schema-backed selected-project review handoff contract that records stable review probes, merge-readiness/final-output/asset-resource/image-bundle review cards, shot-row identifiers, exposure/pixel comparison counts, previous/next/representation/close controls, 44 pt review-control target sizes, and the no-raw-photo/no-Photos-identifier boundary.
- Surfaced the contract in `BracketProjectReviewHandoffView` through the hidden `review.project.accessibility` probe.
- Added stable identifiers and minimum 44 pt frames for `review.project.previousShotButton`, `review.project.nextShotButton`, `review.project.representationToggle`, and `review.project.closeButton`.
- Added `-ui-testing-open-review-accessibility-fixture`, a direct simulator review-handoff fixture that avoids the flaky full simulated capture/relaunch route while still rendering the real handoff view.
- Added unit coverage for verified/incomplete contract behavior, Codable round trip, privacy redaction, review-card identifiers, comparison counts, and control identifiers; added focused UI coverage for the fixture, contract probe, selected-shot surface, and stable review controls.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the v49 review/workspace accessibility proof boundary.

### Verification

- Claude offload:
  - Command attempted with the requested flag: `claude --dangerously-skip-permissions --permission-mode bypassPermissions --model sonnet --effort medium -p ...`
  - Result: Claude Code refused the sidecar run because the session limit was exhausted until `14:30 PDT`; no files were modified by Claude.
- Focused unit preflight:
  - `/tmp/bracketer-v49-review-accessibility-unit-focused-1780001450.xcresult` built cleanly but Swift Testing matched `0` tests through the granular filter, so it was not counted as proof.
- Final unit bundle: `/tmp/bracketer-v49-review-accessibility-unit-tests-1780002850.xcresult`
  - XcodeBuildMCP: `status=SUCCEEDED`
  - `result=Passed`
  - `passedTests=211`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=211`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Duplicate diagnostics-disabled unit proof: `/tmp/bracketer-v49-review-accessibility-unit-tests-1780043200.xcresult`
  - `result=Passed`
  - `passedTests=211`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=211`
- UI attempts not counted as proof:
  - `/tmp/bracketer-v49-review-accessibility-ui-tests-1780001860.xcresult` and `/tmp/bracketer-v49-review-accessibility-ui-tests-1780042600.xcresult` crashed with `signal kill` in the long `testSimulatedBracketCaptureCompletesAndOpensReview` path.
  - `/tmp/bracketer-v49-review-accessibility-fixture-ui-tests-1780002100.xcresult` failed because the simulator test runner was busy after the killed long run.
  - `/tmp/bracketer-v49-review-accessibility-fixture-ui-tests-1780002250.xcresult` and `/tmp/bracketer-v49-review-accessibility-fixture-ui-tests-1780002450.xcresult` terminated while the startup fixture still used a modal/fullScreenCover path; the fixture was moved to a direct overlay and the simulated camera harness before the clean run.
  - `/tmp/bracketer-v49-review-accessibility-focused-ui-tests-1780043300.xcresult` was interrupted before a readable result bundle after the expanded-card assertion pass.
- Focused UI bundle: `/tmp/bracketer-v49-review-accessibility-fixture-ui-tests-1780002700.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract`.
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Duplicate diagnostics-disabled focused UI proof: `/tmp/bracketer-v49-review-accessibility-focused-ui-tests-1780043100.xcresult`
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
- `git diff --check`
  - Result: passed after code, tests, docs, progress, and ledger updates.

### Proof Boundary

- `pure-model-proof`: unit tests cover review accessibility contract truth, missing-probe/failing-target behavior, privacy redaction, comparison/shot counts, navigation-control identifiers, and Codable round trip.
- `simulator-ui-proof`: focused UI test proves the selected-project review handoff fixture exposes the contract probe, selected-shot review surface, and stable previous/next/representation/close controls. The expanded review-card inventory and 44 pt thresholds are covered by pure-model proof.
- This does not prove app-wide Dynamic Type screenshots, high-contrast screenshots, VoiceOver rotor order, physical-device accessibility behavior, physical touch ergonomics, raw photo bytes, Photos asset identifiers, thumbnails, final rendered output bytes, or precise coordinates.

### Next Slice

- Continue Wave Family N with app-wide Dynamic Type/high-contrast screenshot evidence, broader review/export tap-target audits, or VoiceOver traversal snapshots while physical-device proof remains blocked by the unavailable iPhone.

## 2026-05-28 11:18 PDT - May Goals physical proof lab review handoff package preview/decode v1

### What changed

- Added the verified package preview/decode layer for `BracketerPhysicalLabReviewHandoffPackage` archives.
- `BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider` decodes archive text, enforces the copy/share-only package boundary, validates unique filenames, per-block byte counts, SHA-256 digests, readable manifest JSON, supported manifest schema, required payload inventory/kinds, manifest-to-block metadata, and embedded workspace preview before reporting a `pure-model-proof` checklist.
- `BracketerPhysicalLabReviewHandoffPackagePreviewFileProvider` and `PreviewBracketerPhysicalLabReviewHandoffPackageIntent` expose the same preview-only package checklist path to Shortcuts without adding another App Shortcut tile.
- Hardened malformed package manifests with an explicit `unreadableManifest` error instead of treating bad JSON as a missing manifest block.
- Added unit coverage for successful package preview, Shortcuts preview, tampered digest rejection, missing payload rejection, malformed manifest rejection, and unsupported schema rejection.
- Updated README, architecture docs, and progress notes with the package preview/decode boundary.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` design sidecar recommended the manifest/archive-block parser, byte/SHA checks, payload inventory checks, embedded workspace preview reuse, and tamper/schema tests. A later read-only audit attempt stopped at the explicit Claude budget ceiling with `error_max_budget_usd`; no files were modified by Claude.
- App-hosted unit tests: bundle path `/tmp/bracketer-v35-lab-handoff-package-preview-tests-1779992049.xcresult`, compact summary `result=Passed`, `passedTests=197`, `failedTests=0`, `skippedTests=0`, `totalTestCount=197`, device `iPhone 17 Pro`, iOS `26.4.1`.
- The XcodeBuildMCP wrapper timed out after 120 seconds, but the underlying `xcodebuild` completed successfully and the `.xcresult` was read directly with `xcresulttool`.
- `git diff --check` passed for the touched Swift, README, architecture, progress, and ledger files.

### Proof category

- `pure-model-proof`: archive parsing and validation are deterministic local model checks over text bytes, manifests, digests, and the embedded workspace manifest.
- `local-sdk-proof`: the app-hosted test build compiled the package preview App Intent/provider path against the local SDK.
- `blocked-proof`: package preview does not execute commands, authenticate a device, inspect Photos assets, write runbooks, mutate result-bundle indexes, or increment physical proof.

### Current proof boundary

- This previews package integrity only. It still cannot prove that a physical iPhone produced the result bundle or attachments.

### Next slice

- Add a visible Settings handoff-package import-preview row, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Handoff package preview/decode slice complete; physical proof still blocked.

## 2026-05-28 11:20 PDT - May Goals physical proof lab review handoff package Settings import-preview row v1

### What changed

- Added the visible Settings import-preview row for handoff-package archives at `settings.deviceProof.proofIngestor.labReviewHandoffPackageImportPreview`.
- Added a separate security-scoped file importer for plain-text/`.txt` package archives.
- Routed the row through `BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider`, preserving package boundary, manifest, byte-count, SHA-256, payload-inventory, and embedded workspace validation before status text changes.
- Kept the row preview-only: it updates local status text but does not mutate runbooks, result-bundle indexes, capture matrices, or physical proof counts.
- Added unit coverage for successful package preview/Shortcuts preview and tampered SHA-header rejection.
- Extended the focused Device Proof Settings UI contract to require the handoff package preview row and its no-mutation/no-physical-proof wording.
- Updated README, architecture docs, and progress notes with the Settings package preview path.

### Verification

- Claude offload:
  - Broad read-only audit command using `claude --dangerously-skip-permissions` exited without usable output.
  - Smaller read-only compile-risk audit using `claude --dangerously-skip-permissions` confirmed the provider is same-module, throwable, catalog-bound, and safe to call from Settings with `.description` error text. No files were modified by Claude.
- App-hosted unit tests:
  - Bundle path: `/tmp/bracketer-v35-lab-handoff-package-preview-tests-1780033200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=196`, `failedTests=0`, `skippedTests=0`, `totalTestCount=196`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Focused UI test:
  - Bundle path: `/tmp/bracketer-v35-lab-handoff-package-preview-ui-tests-1780033800.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testPhysicalProofIngestorReadinessExposesSummaryCountContract`, including the visible package import-preview row with default no-package-previewed, preview-only, non-mutation, and no-proof-count-changed wording.
- First UI attempt on simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06` failed before app bootstrap with a test-runner early exit and simulator diagnostic `simctl` lookup issue. The dedicated Bracketer UI simulator rerun passed and replaced the bundle path above.
- `git diff --check` passed after the Swift, README, architecture, progress, and ledger updates.

### Proof category

- `pure-model-proof`: unit tests exercise package archive parsing, embedded workspace preview, and tampered SHA rejection over deterministic text bytes.
- `local-sdk-proof`: the app-hosted test build compiles the package preview App Intent/provider and Settings importer against the local SDK.
- `simulator-ui-proof`: the focused UI test proves the visible Settings row exposes the no-save package preview contract.
- `blocked-proof`: package preview still does not execute commands, authenticate a device, inspect Photos assets, write runbooks, mutate result-bundle indexes, or increment physical proof.

### Current proof boundary

- This is still preview infrastructure. It cannot prove a real iPhone produced a result bundle, attachment manifest, Photos resource, or image byte.
- Physical proof remains `0 of 8` until a connected real-device lab run supplies signed evidence.

### Next slice

- Fulfill one physical-capture-matrix scenario with actual real-iPhone proof after the connected iPhone is unlocked, or continue scaffolding toward physical Photos resource fetches, Files document proof, Spotlight continuation, physical lens/EXIF proof, or signed attachment capture.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 11:31 PDT - May Goals physical device lab preflight check-id stability v1

### What changed

- Kept the existing `BracketerPhysicalDeviceLabPreflight` model and `settings.deviceProof.deviceLabPreflight` Settings row as the single preflight source of truth.
- Added a stable `checkIDs` projection on `BracketerPhysicalDeviceLabPreflight` so tests and future exporters can assert preflight checklist ids without remapping `checks.map(\.id)` at every call site.
- Updated the existing preflight unit test to assert `preflight.checkIDs` while preserving the no-command/no-proof-count boundary.
- Restored the single visible `settings.deviceProof.deviceLabPreflight` row beside the physical capture matrix after duplicate-row cleanup, so Device Proof exposes the connected-unlocked-iPhone preparation contract before the verification runbook.
- Updated README, architecture docs, and progress notes with the preflight identifier and no-proof boundary.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` helper for the next preflight slice produced no attached output and was cleared before verification. No files were modified by Claude.
- Physical-device availability check:
  - `xcrun devicectl list devices` reported `Physical iPhone` / iPhone 17 Pro Max as `unavailable`.
  - `xcrun xctrace list devices` listed `Physical iPhone (26.5)` under `Devices Offline`.
  - No physical-device proof was collected from this environment.
- App-hosted unit tests:
  - Bundle path: `/tmp/bracketer-v37-device-lab-preflight-tests-1779993074.xcresult`.
  - XcodeBuildMCP summary: `status=SUCCEEDED`, `passed=197`, `failed=0`, `skipped=0`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Focused UI test:
  - Bundle path: `/tmp/bracketer-v37-device-lab-preflight-ui-tests-1779993320.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
  - Covered the visible `settings.deviceProof.deviceLabPreflight` row in `testPhysicalProofIngestorReadinessExposesSummaryCountContract`.
- First focused UI attempt `/tmp/bracketer-v37-device-lab-preflight-ui-tests-1779993175.xcresult` failed because the preflight row was missing from the Settings hierarchy after duplicate-row cleanup. Fix: restored the single existing row beside the capture matrix and reran successfully.
- `git diff --check` passed after the Swift, README, architecture, progress, and ledger updates.

### Proof category

- `pure-model-proof`: the preflight checklist id projection is deterministic Swift model state.
- `local-sdk-proof`: the app-hosted test bundle compiled the preflight model, Settings references, and App Intents metadata after the duplicate was removed.
- `blocked-proof`: preflight still does not execute commands, authenticate a device, inspect Photos assets, write runbooks, mutate result-bundle indexes, or increment physical proof.

### Current proof boundary

- This is only a stable preflight-test seam. Actual physical proof remains blocked until the offline/unavailable physical iPhone is available/unlocked and a real lab run supplies signed artifacts.

### Next slice

- Fulfill one physical-capture-matrix scenario with actual real-iPhone proof after the connected iPhone is unlocked, or continue toward physical Photos resource fetches, Files document proof, Spotlight continuation, physical lens/EXIF proof, or signed attachment capture.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 12:50 PDT - May Goals inclusive design audit v1

### What changed

- Added `BracketerAccessibilityAudit`, a model-backed Settings > About inclusive-design audit with stable rows for Dynamic Type, Reduced Motion, High Contrast, and Tap Targets.
- Settings now renders the audit at `settings.accessibility.audit` and per-row probes at `settings.accessibility.audit.row.<id>`.
- Increased the compact Apple Intelligence refresh and recipe-plan icon buttons from 34 pt to 44 pt, then recorded that as the first verified tap-target contract while leaving the other inclusive-design axes as explicit follow-ups.
- Updated README, architecture docs, and May Goals progress with the audit boundary.

### Verification

- First attempted selected Swift Testing bundle:
  - `/tmp/bracketer-v43-accessibility-audit-unit-tests-1779997459.xcresult`
  - Result was `unknown`, `totalTestCount=0`, so it was not counted as proof.
- Final app-hosted unit target:
  - `/tmp/bracketer-v43-accessibility-audit-unit-tests-1779997658.xcresult`
  - `xcresulttool` summary: `result=Passed`, `passedTests=209`, `failedTests=0`, `skippedTests=0`, `totalTestCount=209`, simulator `iPhone 17 Pro`, iOS `26.4.1`.
- Focused UI test:
  - `/tmp/bracketer-v43-accessibility-audit-ui-tests-1779997748.xcresult`
  - Test: `BracketerUITests/BracketerUITests/testPhysicalProofIngestorReadinessExposesSummaryCountContract`
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, simulator `iPhone 17 Pro`, iOS `26.4.1`.
- `git diff --check` passed after Swift, docs, progress, and ledger updates.

### Proof category

- `pure-model-proof`: the audit model covers row ids, status counts, tap-target status, Codable round trip, and proof-boundary copy.
- `simulator-ui-proof`: the focused Settings UI test proves the audit summary and verified tap-target row are visible.
- `blocked-proof`: this does not prove Dynamic Type screenshots, reduce-motion runtime behavior, high-contrast visual rendering, physical VoiceOver behavior, physical-device accessibility, raw photo bytes, Photos identifiers, final rendered output bytes, or precise coordinates.

### Current proof boundary

- This is the first inclusive-design audit surface plus one compact-control tap-target fix. Dynamic Type, Reduced Motion, and High Contrast remain follow-up requirements until environment-specific UI proof exists.

### Next slice

- Deepen Wave Family N with Dynamic Type extra-large layout proof, reduce-motion gating, high-contrast visual state, or a broader review/workspace tap-target audit.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 12:37 PDT - May Goals recipe recommendation evidence accessibility verification v1

### What changed

- Verified the Apple Intelligence deterministic-fallback recipe path end to end in the focused UI test after moving the recipe recommendation accessibility surface away from the unstable row-container query.
- Kept the recommendation title, source-evidence text, and Apply button independently queryable so `settings.intelligence.recipe.recommendation.0`, `settings.intelligence.recipe.evidence.0`, and `settings.intelligence.recipe.apply.0` can all be asserted without flattening evidence or hiding the control.
- Recorded the recipe evidence unit bundle that already passed with 207 tests, then reran the focused UI path until it proved source evidence, Apply, applied recipe summary, recent recipe row, active bracket strip, and review manifest recipe wiring.
- Preserved the proof boundary: this is simulator UI proof for deterministic fallback recipe behavior and accessibility stability only, not live Apple Intelligence output or physical-device proof.

### Verification

- Claude offload:
  - A read-only `claude --dangerously-skip-permissions --print` diagnosis reported against the stale recommendation-lookup failure. Codex used the latest result bundle instead, which had progressed to the evidence assertion.
  - A follow-up next-slice scout hit the Claude session limit: `resets 2:30pm (America/Los_Angeles)`.
- Existing app-hosted unit evidence:
  - `/tmp/bracketer-v41-recipe-evidence-unit-tests-1780041900.xcresult`
  - `xcresulttool` summary: `result=Passed`, `passedTests=207`, `failedTests=0`, `skippedTests=0`, `totalTestCount=207`, simulator `BracketerUITest-230901`, iOS `26.4.1`.
- Focused UI evidence:
  - Earlier failed bundle `/tmp/bracketer-v41-recipe-evidence-ui-tests-1780042800.xcresult`: `result=Failed`, `failedTests=1`, recommendation row accessibility assertion.
  - Follow-up failed bundle `/tmp/bracketer-v41-recipe-evidence-ui-tests-1780043900.xcresult`: `result=Failed`, `failedTests=1`, progressed past recommendation lookup and caught the source-evidence assertion path.
  - XcodeBuildMCP rerun `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-28T19-33-13-379Z_pid4917_d2fb49d6.xcresult`: `result=Failed`, `failedTests=1`, `Test crashed with signal kill` after the runner found early Settings rows.
  - Final shell command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' \
  -only-testing:BracketerUITests/BracketerUITests/testAppleIntelligenceAvailabilityCanBeForcedForUITests \
  -skip-testing:BracketerTests \
  -parallel-testing-enabled NO \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES \
  -resultBundlePath /tmp/bracketer-v41-recipe-evidence-ui-tests-1779996921.xcresult
```

  - Final `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- `git diff --check` passed after the progress and ledger updates.

### Proof category

- `visible-ui-proof`: the focused UI test proves deterministic fallback recipe evidence is visible and actionable in Settings and reflected back into camera/review state.
- `accessibility-proof`: the row now exposes separate stable identifiers for recommendation, source evidence, and Apply.
- `blocked-proof`: this does not prove live Apple Intelligence, physical iPhone capture, raw photo bytes, Photos identifiers, active lens state, final rendered output bytes, or precise coordinates.

### Current proof boundary

- This closes a simulator UI evidence/accessibility regression for the recipe planner path. It is not a physical capture matrix artifact and does not move the physical proof count.

### Next slice

- Reduce an unchecked Wave Family N accessibility gap such as Dynamic Type, reduced motion, high contrast, or tap-target sanity while the real iPhone remains unavailable/offline.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 12:43 PDT - May Goals bracket recipe compact evidence summary v1

### What changed

- Added `BracketRecipeRecommendation.compactEvidenceSummary`, a compact evidence string that clamps confidence to `0.00...1.00`, trims source signals, caps the visible source list, and reports `No source signals recorded` for empty evidence.
- Settings > AI now renders the compact recommendation evidence under each recipe row at `settings.intelligence.recipe.evidence.<index>` with an explicit accessibility value.
- The deterministic adaptive planner now treats high-contrast, bright-window, bright-sky, and dark-furniture prompt language as wide dynamic-range signals instead of automatically escalating to extreme HDR; explicit HDR/extreme wording and severe clipping still win.
- Added focused unit tests for evidence formatting, empty-source/clamped-confidence behavior, and high-contrast prompt classification.
- Added `testBracketRecipeEvidenceSummaryAppearsAfterPlanning` to prove the focused Settings > AI evidence row after deterministic fallback planning.
- Updated README, architecture docs, and May Goals progress notes with the compact evidence and wide-vs-extreme prompt boundary.

### Verification

- Claude offload:
  - Read-only `claude --dangerously-skip-permissions -p` audit warned about hard-coded UI expectations, fragile row accessibility, empty source-signal handling, confidence clamping, and stateful disclosure risk. No files were modified by Claude.
  - A follow-up docs/ledger offload attempt with the same flag hit the Claude session limit: `resets 2:30pm (America/Los_Angeles)`.
- App-hosted unit tests:
  - Bundle path: `/tmp/bracketer-v41-recipe-evidence-unit-tests-1780045200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=208`, `failedTests=0`, `skippedTests=0`, `totalTestCount=208`, device `BracketerUITest-230901`, model `iPhone 17`, iOS `26.4.1`.
- Focused UI test:
  - Bundle path: `/tmp/bracketer-v42-recipe-evidence-ui-tests-1780046500.xcresult`.
  - Test: `BracketerUITests/BracketerUITests/testBracketRecipeEvidenceSummaryAppearsAfterPlanning`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Diagnostic notes:
  - Earlier focused UI reruns exposed brittle exact row assertions, an accessibility exposure mismatch, and the real high-contrast prompt classification bug that this slice fixed.
  - One parallel UI attempt hit Xcode's build database lock, and longer UI runs hit runner `signal kill`/simctl diagnostic instability. A zero-test UI bundle was not counted as proof.

### Proof category

- `pure-model-proof`: compact evidence formatting and high-contrast prompt classification are covered by deterministic Swift tests.
- `simulator-ui-proof`: the focused UI test proves the visible Settings > AI evidence row on simulator.
- `local-sdk-proof`: the unit and focused UI bundles compiled against the local iOS simulator SDK.
- `blocked-proof`: physical-device proof remains unavailable because the real iPhone is still offline/unavailable.

### Current proof boundary

- This does not prove live Apple Intelligence output, physical iPhone capture, raw photo bytes, Photos identifiers, precise coordinates, active optical lens state, or final rendered output bytes.
- It improves the deterministic planner and Settings UI evidence contract while keeping physical proof at zero.

### Next slice

- Fulfill one physical-capture-matrix scenario after the real iPhone is unlocked, or keep reducing unchecked Wave Family B/N surfaces with pure model tests and focused simulator UI proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 12:13 PDT - May Goals adaptive capture strategy recommendations v1

### What changed

- Added `AdaptiveCapturePlanningProfile.StrategyRecommendation` and `AdaptiveCapturePlanningProfile.CaptureStrategy` as typed timer, format, lens, and stabilization guidance under the adaptive planning profile.
- Kept the strategy on `AdaptiveCapturePlanningProfile` instead of adding new fields to `BracketRecipeRecommendation`, preserving validator/generative payload boundaries and the existing public recommendation shape.
- Derived strategy from typed scene text, `CaptureContextSummary`, and capability summaries. Lens guidance is phrased as capability-summary advice such as `Prefer Ultra Wide`; it does not claim active-lens or optical proof.
- Wired deterministic recipe action text to draw from the strategy titles while preserving existing recommendation titles, confidence constants, and the `Recipe:` plan suffix.
- Added focused tests for device-capability-driven format/lens strategy plus extended assertions for motion timer/stabilization and deterministic recipe action text.
- Updated README, architecture docs, and May Goals progress notes with the capture-strategy boundary.

### Verification

- Claude offload:
  - Initial read-only `claude --dangerously-skip-permissions` audit warned about recommendation-payload stripping, active-lens truth boundaries, public string/confidence coupling, motion/timer conflicts, and source-signal truncation. No files were modified by Claude.
  - Follow-up read-only docs/progress audit flagged missing bookkeeping around strategy coverage wording, stale result-bundle filename labeling, `git diff --check`, device availability, and architecture-doc wiring wording. Codex corrected those records and documentation. No files were modified by Claude.
- Project discovery:
  - `xcodebuild -list -project Bracketer.xcodeproj` failed under the Command Line Tools developer directory.
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project Bracketer.xcodeproj` succeeded with the Bracketer scheme and test targets.
- App-hosted unit tests:
  - Bundle path: `/tmp/bracketer-v39-adaptive-capture-strategy-tests-1780036200.xcresult`; the filename kept the prior `v39` label from launch time, but this entry records the v40 capability evidence.
  - `xcresulttool` summary: `result=Passed`, `passedTests=203`, `failedTests=0`, `skippedTests=0`, `totalTestCount=203`, device `BracketerUITest-230901`, model `iPhone 17`, iOS `26.4.1`.
- Physical-device availability check:
  - `xcrun devicectl list devices` still reports `Physical iPhone` / iPhone 17 Pro Max (`iPhone18,2`) as `unavailable`.
  - `xcrun xctrace list devices` still lists `Physical iPhone (26.5)` under `Devices Offline`.
- `git diff --check` passed after the Swift, README, architecture, progress, and ledger updates.

### Proof category

- `pure-model-proof`: strategy derivation is deterministic Swift over typed prompt facts and structured capture context.
- `local-sdk-proof`: the app-hosted unit bundle compiled the strategy profile, deterministic planner integration, and tests on the local iOS simulator SDK.
- `blocked-proof`: this does not inspect raw photo bytes, Photos asset identifiers, precise coordinates, active optical lens state, physical-device evidence, or real iPhone capture output.

### Current proof boundary

- The strategy makes the adaptive fallback planner more concrete, but it remains planning guidance. It cannot prove a real lens was active or that a physical iPhone captured a bracket.
- Physical proof remains blocked until an available/unlocked iPhone supplies real run artifacts.

### Next slice

- Fulfill a physical-capture-matrix scenario after the real iPhone is unlocked, or continue reducing Wave Family B planning gaps with typed models that preserve the physical-proof boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 12:10 PDT - May Goals host device availability report preview v1

### What changed

- Added `BracketerHostDeviceAvailabilityReport`, a privacy-safe parser for reviewer-supplied `devicectl list devices` and `xctrace list devices` text.
- The report keeps only physical-iPhone availability rows, ignores simulator sections, redacts raw device identifiers into deterministic `device-<hash>` ids, reports available/unavailable/offline counts, and derives a readiness verdict for blocked/no-device/available-but-still-not-proof host reports without executing host commands.
- Added focused unit tests for unavailable `devicectl` output and offline `xctrace` output, including no-raw-UDID leakage and Codable round trips.
- Added the Settings > About Device Proof import-preview row at `settings.deviceProof.deviceAvailabilityReportImportPreview`.
- Updated README, architecture docs, and May Goals progress notes with the host-availability preview boundary.

### Verification

- Claude offload:
  - First `claude --dangerously-skip-permissions` writer stalled in MCP startup and was stopped with no useful output.
  - Follow-up `claude --dangerously-skip-permissions --strict-mcp-config ...` helped seed the host availability model/tests; Codex audited and reconciled the final tree, removed duplicate draft code, wired Settings, and avoided static `NSRegularExpression` Sendable risk.
- App-hosted unit tests:
  - Final bundle path: `/tmp/bracketer-v41-host-device-availability-readiness-tests-1780041300.xcresult`.
  - XcodeBuildMCP summary: `status=SUCCEEDED`, `passed=205`, `failed=0`, `skipped=0`, simulator `iPhone 17 Pro` (`BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`), iOS `26.4.1`.
  - Covered unavailable `devicectl`, offline `xctrace`, actual hostname-table-shaped `devicectl` output without leaking raw iPhone/iPad/Watch identifiers, and an available-host-report readiness path that still requires signed physical lab artifacts before proof can count.
- Focused UI test:
  - Final bundle path: `/tmp/bracketer-v39-host-device-availability-report-ui-tests-1780040400.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - Covered `testPhysicalProofIngestorReadinessExposesSummaryCountContract`, including the visible `settings.deviceProof.deviceAvailabilityReportImportPreview` row with `No host device availability report previewed`, `host-device-availability preview only`, `Connected unlocked iPhone still required`, and `No physical proof count changed`.
- Failed/interrupted attempts:
  - First focused UI attempt failed before UI execution because the dirty adaptive-planner tree temporarily referenced `makeCaptureStrategy` before the helper existed.
  - Second focused UI attempt through XcodeBuildMCP timed out and left a partial result bundle, but its log proved the new row was found before interruption.
- Physical-device availability check:
  - `xcrun devicectl list devices` still reports `Physical iPhone` / iPhone 17 Pro Max (`iPhone18,2`) as `unavailable`.
  - `xcrun xctrace list devices` still lists `Physical iPhone (26.5)` under `Devices Offline`.
- `git diff --check` passed.

### Proof category

- `pure-model-proof`: the availability report parser is deterministic Swift over pasted host command text.
- `visible-ui-proof`: the focused Settings UI test proves the preview row is present with no-proof wording.
- `blocked-proof`: this does not authenticate a device, execute commands from the app, mutate runbooks, mutate result-bundle indexes, inspect Photos data, store image bytes, or increment physical proof.

### Current proof boundary

- The host report can explain why a physical lab run is blocked, but it is not a physical capture artifact. Real proof remains blocked until the iPhone is available/unlocked and a signed lab run supplies result bundles and attachments.

### Next slice

- Fulfill a physical-capture-matrix scenario after the real iPhone is unlocked, or continue adding no-fake-proof physical-lab handoff surfaces that make the eventual run auditable.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 11:54 PDT - May Goals adaptive capture planning profile v1

### What changed

- Added `AdaptiveCapturePlanningProfile` as a pure Swift planning layer under the bracket recipe fallback.
- The profile derives capture intent, scene condition, dynamic-range estimate, motion/stability estimate, highlight/shadow risk, lens capability status, source signals, recommended bracket plan, confidence, explanation, and privacy boundary from typed scene text plus `CaptureContextSummary`.
- Wired `DeterministicBracketRecipePlanner` to consume the profile while preserving the existing public recommendation titles, plans, and confidence values for extreme range, fast handheld, high contrast, stable detailed, and current-plan cases.
- Added a file-local ordered de-dup helper for profile source signals and removed an initial fragile title-string dependency from recommended-plan selection.
- Hardened lens capability rendering so missing or empty lens summaries produce `Lens capability snapshot unavailable` instead of blank status text.
- Added focused tests for the profile schema/privacy/lens/risk surface, motion-priority behavior when frame analysis also reports wide range, and adaptive source signals in deterministic recommendations.
- Updated README, architecture docs, and May Goals progress notes with the adaptive profile boundary.

### Verification

- Claude offload:
  - Read-only `claude --dangerously-skip-permissions` audit caught missing `uniquePreservingOrder()`, missing tests, unwired profile usage, fragile title matching, and empty lens-summary risk. No files were modified by Claude.
  - A second read-only post-patch Claude audit correctly predicted the fast-recipe confidence regression that the first unit run exposed and flagged future brittleness around scene/weighting fixture assumptions. No files were modified by Claude.
- First app-hosted unit attempt:
  - Bundle path: `/tmp/bracketer-v38-adaptive-capture-profile-tests-1780035000.xcresult`.
  - `xcresulttool` summary: `result=Failed`, `passedTests=199`, `failedTests=1`, `totalTestCount=200`.
  - Failure: `deterministicBracketRecipePlannerKeepsFastSubjectsShort` observed confidence `0.90` instead of the previous public value `0.78`.
  - Fix: deterministic planner now preserves its public confidence constants while the profile keeps richer internal confidence.
- Final app-hosted unit tests:
  - Bundle path: `/tmp/bracketer-v38-adaptive-capture-profile-tests-1780035000.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=202`, `failedTests=0`, `skippedTests=0`, `totalTestCount=202`, device `BracketerUITest-230901`, model `iPhone 17`, iOS `26.4.1`.
- `git diff --check` passed after the Swift, README, architecture, progress, and ledger updates.

### Proof category

- `pure-model-proof`: profile derivation is deterministic Swift over typed scene text and structured capture context.
- `local-sdk-proof`: the app-hosted unit bundle compiled the profile, deterministic planner integration, and tests on the local iOS simulator SDK.
- `blocked-proof`: this does not inspect raw photos, Photos asset identifiers, precise coordinates, physical-device evidence, or real iPhone capture output.

### Current proof boundary

- This is adaptive planning infrastructure only. It does not make Apple Intelligence output or physical-device capture proof complete.
- A refreshed device check still reports `Physical iPhone` / iPhone 17 Pro Max (`iPhone18,2`) as `unavailable` in `devicectl` and as `Physical iPhone (26.5)` under `Devices Offline` in `xctrace`.

### Next slice

- Fulfill a physical-capture-matrix scenario after the real iPhone is unlocked, or keep advancing unblocked adaptive-planning/model surfaces without converting simulator proof into physical proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 10:55 PDT - May Goals physical proof lab workspace Settings import-preview row v1

### What changed

- Recorded the visible no-save lab workspace import-preview row at `settings.deviceProof.proofIngestor.labWorkspaceImportPreview`.
- The row opens plain-text or `.md` workspace files, feeds bytes into `BracketerPhysicalLabWorkspaceReviewPreviewProvider`, and updates status text with the decoded checklist preview.
- The default status states `No physical lab workspace previewed`, `physical-lab-workspace preview only`, `Import preview does not mutate runbooks or result-bundle indexes`, and `No physical proof count changed`.
- Updated README, architecture docs, and progress notes with the Settings import-preview boundary.

### Verification

- Existing unit evidence: `/tmp/bracketer-v32-lab-workspace-preview-tests-1780030200-skip-flake.xcresult`, compact summary `result=Passed`, `passedTests=194`, `failedTests=0`, `skippedTests=0`, `totalTestCount=194`, device `iPhone 17 Pro`, iOS `26.4.1`, covers the shared workspace preview provider and rejection paths.
- Focused UI test: bundle path `/tmp/bracketer-v34-lab-workspace-import-preview-ui-tests-1780032600.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- The focused UI evidence covers `settings.deviceProof.proofIngestor.labWorkspaceImportPreview` with no-save, no-proof-count, and no physical-proof-captured wording.

### Proof category

- `simulator-ui-proof`: Settings exposes the lab workspace import-preview row and its default no-save status on simulator.
- `pure-model-proof`: the shared preview provider was already covered by unit tests for manifest decoding, checklist output, and rejection paths.
- `blocked-proof`: selecting or previewing workspace Markdown does not ingest proof, write runbooks, mutate result-bundle indexes, or increment physical proof.

### Current proof boundary

- This is a preview/status surface only. It still cannot authenticate a device or turn workspace Markdown into physical iPhone evidence.

### Next slice

- Add a symmetric handoff-package preview/decode path, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Lab workspace Settings import-preview row slice complete; physical proof still blocked.

## 2026-05-28 10:58 PDT - May Goals physical proof lab workspace Settings import preview row v1

### What changed

- Added a visible Settings row at `settings.deviceProof.proofIngestor.labWorkspaceImportPreview`.
- Added a separate security-scoped `.fileImporter` for exported physical lab workspace Markdown files.
- Wired the row to `BracketerPhysicalLabWorkspaceReviewPreviewProvider`, reusing the structured workspace-manifest checklist path instead of proof-submission ingest.
- Added default status text that says no workspace has been previewed, the row is `physical-lab-workspace preview only`, runbooks/result-bundle indexes are not mutated, and physical proof counts do not change.
- Surfaced `BracketerPhysicalLabWorkspaceReviewError.description` in row status for useful checklist/manifest errors.
- Extended the focused Device Proof UI test to prove the row is visible and keeps the no-physical-proof boundary.
- Updated README, architecture docs, and progress notes with the Settings workspace preview surface.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` review flagged identifier, fileImporter, UTType, provider-signature, error-description, non-mutation wording, and scroll-reveal risks. No files were modified by Claude.
- Unit tests: bundle path `/tmp/bracketer-v34-lab-workspace-import-preview-tests-1780031400.xcresult`, compact summary `result=Passed`, `passedTests=194`, `failedTests=0`, `skippedTests=0`, `totalTestCount=194`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Focused UI test: bundle path `/tmp/bracketer-v34-lab-workspace-import-preview-ui-tests-1780032000.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- `git diff --check` passed for the touched Swift, README, architecture, progress, and ledger files.

### Proof category

- `simulator-ui-proof`: focused UI coverage proves Settings exposes `settings.deviceProof.proofIngestor.labWorkspaceImportPreview` with workspace-preview-only, non-mutation, and no-proof wording.
- `local-sdk-proof`: the app-hosted unit test build compiled the second file-importer Settings path and App Intents metadata.
- `blocked-proof`: the row previews workspace checklist data only. It does not import proof submissions, execute commands, authenticate a device, inspect Photos assets, mutate runbooks, mutate result-bundle indexes, or increment physical proof.

### Current proof boundary

- This is a visible no-save workspace Markdown preview path. It does not yet parse the v33 handoff package archive and still cannot prove physical iPhone capture.

### Next slice

- Add a symmetric handoff-package preview/decode path, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Lab workspace Settings import-preview row slice complete; physical proof still blocked.

## 2026-05-28 10:45 PDT - May Goals physical proof lab review handoff package v1

### What changed

- Added `BracketerPhysicalLabReviewHandoffPackage`, a single copy/share-only archive text that separates a physical lab workspace into deterministic payload blocks.
- The package includes a package-manifest JSON payload plus the lab workspace Markdown, command-plan text, seeded proof-template JSON, output-paths Markdown, and reviewer-checklist Markdown.
- Each payload records byte count and SHA-256 digest; the package manifest intentionally hashes payloads only, not itself.
- Added `BracketerPhysicalLabReviewHandoffPackageFileProvider` and `ExportBracketerPhysicalLabReviewHandoffPackageIntent` for Shortcuts-facing archive export without adding another `AppShortcut` tile.
- Added the visible Settings row at `settings.deviceProof.proofIngestor.labReviewHandoffPackage`.
- Hardened `BracketerPhysicalLabWorkspaceDocument.accessibilityValue` to explicitly include `Copy/share only`.
- Optimized package construction so payloads and the manifest are computed once, keeping the Settings accessibility surface lightweight.
- Added tests proving deterministic payload order, manifest byte/hash metadata, safe custom path propagation, privacy exclusions, missing-runbook rejection, unsafe path rejection, App Intents metadata compilation, and visible Settings exposure.
- Updated README, architecture docs, and progress notes with the package/export boundary.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` reviews confirmed the workspace row already existed, then highlighted package design risks including ShareLink's single-payload boundary, the App Shortcut cap, manifest self-reference, repeated hashing, and no-proof wording. No files were modified by Claude.
- Unit tests: bundle path `/tmp/bracketer-v32-lab-workspace-preview-tests-1780030200-skip-flake.xcresult`, compact summary `result=Passed`, `passedTests=194`, `failedTests=0`, `skippedTests=0`, `totalTestCount=194`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Focused UI test: bundle path `/tmp/bracketer-v33-lab-review-handoff-package-ui-tests-1780030800.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- The focused UI test outlived the MCP wrapper timeout but completed successfully; the `.xcresult` was read directly with `xcresulttool`.
- `git diff --check` passed for the touched Swift, README, architecture, progress, and ledger files.

### Proof category

- `pure-model-proof`: unit tests cover package composition, deterministic payload ordering, manifest byte counts, SHA-256 payload digests, no-self-hash behavior, and error handling.
- `local-sdk-proof`: the app-hosted unit test build compiled the new handoff package export intent while staying within the 10-App-Shortcut metadata cap.
- `simulator-ui-proof`: focused UI coverage proves Settings exposes `settings.deviceProof.proofIngestor.labReviewHandoffPackage` with package, manifest, checklist, copy/share-only, and no-proof wording.
- `blocked-proof`: the archive packages review handoff text only. It does not execute commands, authenticate a device, inspect Photos assets, replace placeholders, import evidence, or increment physical proof. Physical proof remains `0 of 8`.

### Current proof boundary

- This is a single archive-style `IntentFile`, not six independent shared files. It improves lab handoff reviewability but still cannot prove physical iPhone capture.

### Next slice

- Add a visible Settings import/preview row for workspace Markdown or handoff packages, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Lab review handoff package slice complete; physical proof still blocked.

## 2026-05-28 10:42 PDT - May Goals physical proof lab workspace manifest preview checklist v1

### What changed

- Embedded a structured `bracketer-physical-lab-workspace-manifest` JSON fence inside each `BracketerPhysicalLabWorkspaceDocument`.
- Added manifest decoding, schema validation, deterministic output-path rendering, and review-checklist construction for physical lab workspace Markdown.
- Added `BracketerPhysicalLabWorkspaceReviewPreviewProvider` and `PreviewBracketerPhysicalLabWorkspaceIntent` so a workspace file can be previewed as checklist status without importing proof.
- Hardened checklist validation so missing manifests, missing runbook catalogs, mismatched expected artifacts, missing no-proof boundaries, and missing output artifacts reject before any proof state could change.
- Required the metrics output artifact only when the exported command plan actually includes the metrics extraction command.
- Kept the preview intent out of `AppShortcutsProvider` after local metadata export proved the app was at the iOS 10-App-Shortcut cap.
- Added unit coverage for manifest fields, preview provider output, Shortcuts preview-file plumbing, missing-manifest rejection, missing-runbook rejection, and the unchanged no-physical-proof boundary.
- Updated README, architecture docs, and progress notes with the manifest-preview/checklist contract.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` review highlighted checklist and App Intents risks; no files were modified by Claude.
- Initial unit attempt: bundle path `/tmp/bracketer-v32-lab-workspace-preview-tests-1780029000.xcresult`, failed during App Intents metadata export with `Found 11 App Shortcuts, but each app may have at most 10`; fixed by keeping the preview intent but not adding an eleventh App Shortcut.
- Broad rerun before final: bundle path `/tmp/bracketer-v32-lab-workspace-preview-tests-1780029000-rerun1.xcresult`; workspace tests passed, but the run reported one unrelated `bracketProjectImportBundleCanRejectDuplicateArchives()` signal-kill failure.
- Final unit run: bundle path `/tmp/bracketer-v32-lab-workspace-preview-tests-1780030200-skip-flake.xcresult`, compact summary `result=Passed`, `passedTests=194`, `failedTests=0`, `skippedTests=0`, `totalTestCount=194`, device `iPhone 17 Pro`, iOS `26.4.1`.
- `git diff --check` passed for the touched Swift, README, architecture, progress, and ledger files.

### Proof category

- `pure-model-proof`: unit tests cover manifest embedding/decoding, preview-checklist construction, output-artifact validation, error handling, and Shortcuts preview-file plumbing.
- `local-sdk-proof`: the app-hosted unit test build compiled `PreviewBracketerPhysicalLabWorkspaceIntent` while preserving the 10-shortcut App Intents metadata limit.
- `blocked-proof`: previewing a workspace does not execute commands, authenticate a device, inspect Photos assets, replace placeholders, import evidence, mutate runbooks, mutate the result-bundle index, or increment physical proof.

### Current proof boundary

- The app can now review a lab workspace as structured checklist data, but it still cannot treat that workspace as real iPhone evidence. Physical proof remains `0 of 8`.

### Next slice

- Export the workspace as a multi-file review handoff package, add a visible Settings import/preview row for workspace Markdown, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Lab workspace manifest preview/checklist slice complete; physical proof still blocked.

## 2026-05-28 10:23 PDT - May Goals physical proof per-scenario lab workspace App Intent and Settings export v1

### What changed

- Added `BracketerPhysicalLabWorkspaceDocument`, a copy/share-only Markdown handoff that composes one physical runbook, the non-executing command plan, expected artifacts, derived output paths, and seeded proof-template JSON.
- Added `BracketerPhysicalLabWorkspaceFileProvider`, which exports the workspace as a Shortcuts `IntentFile` while preserving custom safe result-bundle path support.
- Added `ExportBracketerPhysicalLabWorkspaceIntent` and an App Shortcut phrase for bundling a runbook, command plan, and proof template into one lab workspace file.
- Added the visible Settings export row at `settings.deviceProof.proofIngestor.labWorkspace`.
- Tightened workspace status text to say `no physical proof captured`, preserve the `0 of 8` physical-proof boundary, and avoid ambiguous `recorded proof(s)` wording.
- Added tests proving workspace contents, custom safe path propagation, zeroed per-artifact byte-count boundaries, missing-runbook errors, unsafe path rejection, visible Settings row exposure, and privacy exclusions.
- Updated README, architecture docs, and progress notes while preserving the no-execution/no-physical-proof boundary.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` review identified the missing Settings row and ambiguous workspace status wording; both were fixed before final verification.
- Unit tests: bundle path `/tmp/bracketer-v31-lab-workspace-tests-1780027800.xcresult`, compact summary `result=Passed`, `passedTests=190`, `failedTests=0`, `skippedTests=0`, `totalTestCount=190`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Focused UI test: bundle path `/tmp/bracketer-v31-lab-workspace-ui-tests-1780028400.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- The app-hosted unit test build compiled `ExportBracketerPhysicalLabWorkspaceIntent` and the new App Shortcut phrase against the local SDK.

### Proof category

- `pure-model-proof`: unit tests cover lab workspace composition, expected artifact listing, output path derivation, seeded proof-template inclusion, custom safe path propagation, zero per-artifact bytes, missing-runbook errors, unsafe path rejection, and no physical-proof claim.
- `local-sdk-proof`: the app-hosted unit test build compiled the new lab workspace export intent against the local iOS SDK.
- `simulator-ui-proof`: focused UI coverage proves Settings exposes `settings.deviceProof.proofIngestor.labWorkspace` with lab-workspace, command-plan, seeded-template, copy/share-only, and no-proof wording.
- `blocked-proof`: the workspace only bundles handoff text and seeded preview JSON. It does not run commands, authenticate a device, inspect Photos assets, replace placeholders, or accept physical evidence. Physical proof remains `0 of 8`.

### Current proof boundary

- This gives lab operators one scenario-specific handoff file instead of separate command-plan and template exports, and makes it visible in Settings. It still cannot prove physical iPhone capture or mutate the runbook/result-bundle index.

### Next slice

- Export the workspace as a multi-file review handoff package, make the workspace importable as a lab-review checklist, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Per-scenario lab workspace App Intent/Settings export slice complete; physical proof still blocked.

## 2026-05-28 10:09 PDT - May Goals physical proof command-plan caller result-bundle path App Intent export v1

### What changed

- Extended `BracketerPhysicalResultBundleCommandPlanDocument` so command-plan text can be generated for an optional caller-provided `.xcresult` path instead of only the default lab path.
- Extended `BracketerPhysicalResultBundleCommandPlanFileProvider` to trim a caller path before passing it through the existing command-plan validation, while treating blank caller paths as the runbook default.
- Extended `ExportBracketerPhysicalResultBundleCommandPlanIntent` with a Shortcuts `Result Bundle Path` parameter while preserving the metrics-command toggle.
- Tightened `BracketerPhysicalResultBundleCommandPlan.make` so direct custom path input is trimmed before digest, summary, metrics, and tool-version output paths are derived.
- Added tests proving custom safe paths rewrite digest/summary command output paths, blank caller paths fall back to runbook defaults, unsafe and cross-scenario caller paths still reject, and the export remains copy/share-only.
- Updated README, architecture docs, and progress notes while preserving the no-execution/no-physical-proof boundary.

### Verification

- Claude offload: read-only `claude --dangerously-skip-permissions` review found that the lower-level command-plan factory could embed padded direct custom paths; that was fixed before the final unit run.
- Unit tests: bundle path `/tmp/bracketer-v30-command-plan-custom-path-tests-1780027200.xcresult`, compact summary `result=Passed`, `passedTests=187`, `failedTests=0`, `skippedTests=0`, `totalTestCount=187`, device `iPhone 17 Pro`, iOS `26.4.1`.
- The app-hosted test build compiled App Intents metadata for the expanded `ExportBracketerPhysicalResultBundleCommandPlanIntent` and its `Result Bundle Path` parameter.

### Proof category

- `pure-model-proof`: unit tests cover custom result-bundle path trimming, blank-path fallback, command-plan output path derivation, unsafe path rejection, cross-scenario path rejection, optional metrics behavior, and copy/share-only document output.
- `local-sdk-proof`: the app-hosted test build compiled App Intents metadata for the expanded Shortcuts command-plan export against the local iOS SDK.
- `blocked-proof`: caller-provided paths only change exported command text. The app still does not run commands, authenticate a device, inspect Photos assets, or accept physical evidence. Physical proof remains `0 of 8`.

### Current proof boundary

- This makes rerun bundles and lab-specific result paths easier to hand off through Shortcuts. It does not execute `xcodebuild`, hash a real physical bundle, create a proof submission, or count any physical scenario.

### Next slice

- Build a per-scenario lab workspace that bundles the selected runbook, command plan, seeded template, expected artifacts, and output paths, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Caller result-bundle path command-plan export slice complete; physical proof still blocked.

## 2026-05-28 10:00 PDT - May Goals physical proof seeded template App Intent file export v1

### What changed

- Added `BracketerPhysicalProofTemplateFileProvider`, which turns compact xcresult summary JSON plus an attachment byte count into the same preview-only seeded physical proof template used by Settings/import preview.
- Added `ExportBracketerPhysicalProofTemplateIntent`, a non-opening Shortcuts action that returns the seeded template as a JSON `IntentFile` for a selected physical runbook scenario.
- Added an App Shortcut phrase for proof-template export.
- The export keeps real hashes, manifest digest, device identifiers, per-artifact attachment hashes, and scenario reviewer evidence as placeholders; parsed attachment totals remain only in result-bundle metrics, and per-artifact byte counts stay zero.
- Updated README, architecture docs, and progress notes while preserving the no-physical-proof boundary.

### Verification

- Unit tests: bundle path `/tmp/bracketer-v29-proof-template-intent-tests-1780026000.xcresult`, compact summary `result=Passed`, `passedTests=183`, `failedTests=0`, `skippedTests=0`, `totalTestCount=183`, device `iPhone 17 Pro`, iOS `26.4.1`.
- The app-hosted test build compiled App Intents metadata for `ExportBracketerPhysicalProofTemplateIntent` and the new App Shortcut phrase.

### Proof category

- `pure-model-proof`: unit tests cover the seeded-template file provider, JSON `IntentFile`, zeroed per-artifact byte counts, metrics preservation, privacy exclusions, and missing-runbook errors.
- `local-sdk-proof`: the app-hosted test build compiled App Intents metadata for `ExportBracketerPhysicalProofTemplateIntent` and the new App Shortcut phrase against the local iOS SDK.
- `blocked-proof`: Shortcuts export only returns a preview template; it does not authenticate a device, replace lab placeholders, or accept physical evidence. Physical proof remains `0 of 8`.

### Current proof boundary

- This lowers Shortcuts friction for future lab reviewers. It does not create real hashes, inspect Photos assets, run XCTest, or count any physical scenario.

### Next slice

- Allow command-plan exports to accept a caller-provided safe result-bundle path/root, build a richer per-scenario lab workspace with command plan plus seeded template, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Prefilled-template App Intent file export slice complete; physical proof still blocked.

## 2026-05-28 09:55 PDT - May Goals physical proof result-bundle command-plan App Intent file export v1

### What changed

- Added `BracketerPhysicalRunbookIntentScenario`, mapping Shortcuts scenario choices to the eight physical capture runbook ids.
- Added `BracketerPhysicalResultBundleCommandPlanFileProvider`, which returns a `.plainText` `IntentFile` using the same `BracketerPhysicalResultBundleCommandPlanDocument` text as Settings.
- Added `ExportBracketerPhysicalResultBundleCommandPlanIntent`, a non-opening Shortcuts action that exports the copy/share-only command plan for a selected physical runbook scenario.
- The intent can omit the metrics extraction command for shorter handoffs while keeping digest, compact summary, tool-version, no-execution, and no-physical-proof boundaries.
- Added an App Shortcut phrase for command-plan export and updated README, architecture docs, and progress notes.

### Verification

- Unit tests: bundle path `/tmp/bracketer-v28-command-plan-intent-tests-1780025400.xcresult`, compact summary `result=Passed`, `passedTests=183`, `failedTests=0`, `skippedTests=0`, `totalTestCount=183`, device `BracketerUITest-230901`, iOS `26.4.1`.
- The app-hosted test build compiled App Intents metadata for `ExportBracketerPhysicalResultBundleCommandPlanIntent` and the new App Shortcut phrase.

### Proof category

- `pure-model-proof`: unit tests cover the scenario enum mapping, file-provider output, `IntentFile` payload, optional metrics omission, and missing-runbook error.
- `local-sdk-proof`: the app-hosted test build compiled App Intents metadata for `ExportBracketerPhysicalResultBundleCommandPlanIntent` and the new App Shortcut phrase against the local iOS SDK.
- `blocked-proof`: Shortcuts export only returns command-plan text; it does not run commands, authenticate a real device, or accept physical evidence. Physical proof remains `0 of 8`.

### Current proof boundary

- This gives Shortcuts a portable command-plan file for future lab work. It is not physical capture proof and does not mutate runbooks, result-bundle indexes, or physical capture matrix status.

### Next slice

- Add a prefilled-template App Intent file result for compact xcresult summary JSON plus attachment byte count, allow command-plan exports to accept a caller-provided safe result-bundle path/root, or resume physical iPhone proof after device unlock.

### Goal status

- Goal still open. Command-plan App Intent file export slice complete; physical proof still blocked.

## 2026-05-28 09:49 PDT - May Goals physical proof result-bundle command-plan share surface v1

### What changed

- Added `BracketerPhysicalResultBundleCommandPlanDocument`, a deterministic copy/share text wrapper around the non-executing command plan.
- Settings > About Device Proof now exposes the command plan at `settings.deviceProof.proofIngestor.commandPlan` beside the proof-ingestor contract and proof-submission template.
- The share text includes scenario id, schema, result-bundle digest path, compact summary/metrics paths, tool-version paths, quoted `shasum`/`xcresulttool`/tool-version commands, reviewer-evidence lines, and no-execution/no-physical-proof boundaries.
- Updated README, architecture docs, UI assertions, and progress notes while preserving the no-physical-proof boundary.

### Verification

- Unit tests: bundle path `/tmp/bracketer-v27-command-plan-share-tests-1780024200.xcresult`, compact summary `result=Passed`, `passedTests=178`, `failedTests=0`, `skippedTests=0`, `totalTestCount=178`, device `iPhone 17 Pro`, iOS `26.4.1`.
- UI readiness: bundle path `/tmp/bracketer-v27-command-plan-share-ui-tests-1780024800.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.

### Proof category

- `pure-model-proof`: unit tests cover deterministic command-plan share text, command inclusion, output paths, privacy exclusions, and no physical-proof claim.
- `simulator-ui-proof`: focused UI proof shows Settings exposes `settings.deviceProof.proofIngestor.commandPlan` with `shasum`, `xcresulttool`, copy/share-only, and no-execution wording.
- `blocked-proof`: command-plan sharing still does not authenticate a real device or accept physical evidence; physical proof remains `0 of 8`.

### Current proof boundary

- This makes the lab command plan easier to hand to an operator. It does not run the plan, hash a real physical bundle, inspect Photos assets, or count any physical scenario.

### Next slice

- Add a command-plan or prefilled-template App Intent file result, build a richer per-scenario command-plan workspace, or resume physical iPhone proof after the device is unlocked and a readable real-device result bundle exists.

### Goal status

- Goal still open. Command-plan share surface slice complete; physical proof still blocked.

## 2026-05-28 09:40 PDT - May Goals physical proof result-bundle command-plan scaffolding v1

### What changed

- Added `BracketerPhysicalResultBundleCommandPlan`, a pure non-executing lab handoff for scenario-bound physical `.xcresult` bundles.
- The plan emits quoted `shasum`, compact `xcresulttool` summary/metrics, `xcodebuild -version`, and `xcresulttool version` command lines plus deterministic output artifact paths.
- The plan rejects empty, non-`.xcresult`, shell-unsafe, and cross-scenario result-bundle paths before producing command text.
- The plan can decode compact summary JSON through the existing `BracketerPhysicalResultBundleProofInput` parser so command output feeds the seeded-template path.
- Seeded proof-input templates were hardened so parsed attachment totals remain only in `resultBundleMetrics` while all per-artifact attachment byte counts stay zero placeholders until real lab evidence replaces them.
- `BracketerPhysicalProofIngestReadiness` is now schema v26 and exposes command-plan fields in the Settings proof-ingestor contract.
- Updated README, architecture docs, UI assertions, and progress notes while preserving the no-physical-proof boundary.

### Verification

- Unit tests: bundle path `/tmp/bracketer-v26-command-plan-tests-1780022400.xcresult`, compact summary `result=Passed`, `passedTests=177`, `failedTests=0`, `skippedTests=0`, `totalTestCount=177`, device `BracketerUITest-230901`, iOS `26.4.1`.
- UI readiness: bundle path `/tmp/bracketer-v26-command-plan-readiness-ui-tests-1780023000.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
- Superseded stale UI bundle `/tmp/bracketer-v26-command-plan-readiness-ui-tests-1780021800.xcresult` passed before the readiness schema label was bumped from v25 to v26, so it is not final proof.
- Unit coverage also pinned the zeroed per-artifact byte placeholder boundary after parsed proof-input seeding, while preserving parsed attachment totals only in result-bundle metrics.

### Proof category

- `pure-model-proof`: unit tests cover command construction, output paths, path validation, shell quoting, and parser handoff without process execution.
- `simulator-ui-proof`: focused UI proof shows Settings exposes schema v26 command-plan fields.
- `blocked-proof`: command plans still do not authenticate a real device or accept physical evidence; physical proof remains `0 of 8`.

### Current proof boundary

- This reduces lab-operator ambiguity by turning expected result-bundle evidence commands into deterministic text. It does not run those commands, inspect an iPhone, hash a real physical bundle, or count any physical scenario.

### Next slice

- Add a visible command-plan copy/share surface or a dedicated prefilled-template App Intent file result for compact summary JSON plus attachment byte count. Physical iPhone proof still requires an unlocked device and a readable real-device result bundle.

### Goal status

- Goal still open. Command-plan scaffold slice complete; physical proof still blocked.

## 2026-05-28 09:18 PDT - May Goals physical proof parsed proof-input seeded template/import-preview v1

### What changed

- Added a parsed-proof-input seeding path for future physical proof submissions.
- `BracketerPhysicalProofSubmission.template(for:proofInput:)` now fills typed result-bundle summary, metrics, timing, device/platform metadata, reviewer-evidence lines, and preview attachment-manifest byte scaffolds from `BracketerPhysicalResultBundleProofInput`; v26 later hardened those per-artifact byte scaffolds to zero placeholders.
- `BracketerPhysicalProofSubmissionDocument` can build the same seeded template directly from compact `xcresulttool get test-results summary --compact` JSON when a caller supplies attachment byte count.
- `BracketerPhysicalProofPreviewFileProvider` now accepts parsed proof-input JSON whose filename includes a physical runbook id, signs a preview-only seeded template, and runs the shared ingest-preview validator without mutating physical proof counts.
- Settings import preview now uses that shared provider path, keeping Settings and Shortcuts preview behavior aligned.
- Seeded templates keep per-artifact attachment hashes and real reviewer evidence as placeholders; real attachment-manifest evidence remains mandatory after the physical run. The per-artifact byte placeholder policy was tightened in the 09:40 v26 slice so parsed totals stay only in metrics and each artifact byte count stays zero.
- Updated README, architecture docs, and progress notes while preserving the no-physical-proof boundary.

### Verification

- Unit tests: bundle path `/tmp/bracketer-v25-proof-input-template-tests-1780020300.xcresult`, compact summary `result=Passed`, `passedTests=177`, `failedTests=0`, `skippedTests=0`, `totalTestCount=177`, device `BracketerUITest-230901`, iOS `26.4.1`.
- Failed stale-assertion bundles `/tmp/bracketer-v25-proof-input-template-tests-1780019400.xcresult` and `/tmp/bracketer-v25-proof-input-template-tests-1780020000.xcresult` were fixed by replacing old zero-byte/scaffold schema expectations before the final pass.

### Proof category

- `pure-model-proof`: unit tests cover parsed proof-input template seeding, compact-summary JSON document prefill, placeholder retention for real lab facts, provider preview routing, and no catalog/index count mutation. The zeroed per-artifact byte placeholder contract is pinned by the later v26/v27 tests.
- `local-sdk-proof`: app-hosted unit execution proves the shared provider/document path compiles and preserves the no-count preview boundary against the local simulator SDK.
- `blocked-proof`: no real iPhone proof was accepted; physical proof remains blocked by device access.

### Current proof boundary

- This improves reviewer ergonomics for future lab submissions by reducing hand-entered xcresult fields. It does not authenticate a device, hash a real bundle, inspect Photos assets, or count any of the 8 physical scenarios. Physical proof remains `0 of 8`.

### Next slice

- Add a dedicated visible prefilled-template ShareLink/App Intent file result that accepts compact xcresult summary JSON plus attachment byte count, or add digest/xcresulttool command automation around result-bundle parser output. Physical iPhone proof still requires an unlocked device and a readable real-device result bundle.

### Goal status

- Goal still open. Proof-input seeded-template/import-preview slice complete; physical proof still blocked.

## 2026-05-28 09:05 PDT - May Goals physical proof result-bundle device/platform metadata binding v1

### What changed

- Completed the in-progress v24 physical proof device-metadata guardrail already present in the live tree.
- `BracketerPhysicalResultBundleDevice` now binds signed physical proof submissions to xcresult device model, platform, iOS version, and OS build metadata.
- `BracketerPhysicalProofIngestor` rejects missing device metadata, simulator xcresult platforms, non-iPhone result-bundle model names, iOS version/build mismatches against the submitted iOS build label, and reviewer evidence that does not echo the result-bundle device tokens.
- `BracketerPhysicalResultBundleProofInput` now derives device metadata from compact xcresult summaries, and reviewer evidence includes the result-bundle device line when available.
- `BracketerPhysicalProofSubmission.schemaVersion` is v5 and `BracketerPhysicalProofIngestReadiness` is schema v24.
- Updated README, architecture docs, UI assertions, and progress notes while preserving the no-physical-proof boundary.

### Verification

- Unit tests: bundle path `/tmp/bracketer-v24-device-metadata-tests-1780017000.xcresult`, compact summary `result=Passed`, `passedTests=171`, `failedTests=0`, `skippedTests=0`, `totalTestCount=171`, device `BracketerUITest-230901`, iOS `26.4.1`.
- UI readiness: bundle path `/tmp/bracketer-v24-device-metadata-readiness-ui-tests-1780017600.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
- Failed pre-fix bundle `/tmp/bracketer-v24-device-metadata-tests-1780015800.xcresult`: older fixtures had not yet supplied matching v24 device metadata or updated device-summary expectations.
- Discarded zero-test bundle `/tmp/bracketer-v24-device-metadata-tests-1780016400.xcresult`: `xcresulttool` reported `totalTestCount=0`, so it is not proof.

### Proof category

- `pure-model-proof`: unit tests cover compact-summary-derived device metadata, missing/invalid/mismatched device metadata, reviewer-evidence binding, schema v5/v24 output, and old-fixture drift.
- `simulator-ui-proof`: focused Settings UI test proves schema v24 device/platform metadata appears in the visible proof-ingestor contract.
- `blocked-proof`: physical proof remains blocked/no real iPhone proof accepted.

### Current proof boundary

- This binds a future real-device proof submission to claimed xcresult device/platform metadata. It does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested. Physical proof remains `0 of 8`.

### Next slice

- Wire `BracketerPhysicalResultBundleProofInput` into exported physical submission templates/import previews so compact xcresult summaries can prefill proof scaffolds without hand-entered summary/device fields, while keeping real hashes, physical device labels, per-artifact bytes, and reviewer evidence required after a real iPhone run.

### Goal status

- Goal still open. v24 device/platform guardrail complete; physical proof still blocked.

## 2026-05-28 08:40 PDT - May Goals physical proof xcresult compact-summary parser v1

### What changed

- Added `BracketerPhysicalResultBundleProofInput` to decode compact `xcresulttool get test-results summary --compact` JSON into typed summary, metrics, timing, test-plan, environment, and device proof input.
- Added parser-specific errors for invalid attachment byte counts, invalid summary timing windows, and missing test-plan configuration.
- Exposed parser fields and rejections through `BracketerPhysicalProofIngestReadiness` schema v23 and Settings UI assertions.
- Updated README/architecture/progress/UI tests while preserving the no-physical-proof boundary.

### Verification

- Compile proof: `/tmp/bracketer-v23-build-for-testing.xcresult` passed `build-for-testing` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Unit tests: bundle path `/tmp/bracketer-v23-xcresult-parser-target-tests-1780015200.xcresult`, compact summary `result=Passed`, `passedTests=170`, `failedTests=0`, `skippedTests=0`, `totalTestCount=170`, device `iPhone 17 Pro`, iOS `26.4.1`.
- UI readiness: bundle path `/tmp/bracketer-v23-xcresult-parser-readiness-ui-tests-1780014600.xcresult`, compact summary `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17 Pro`, iOS `26.4.1`.
- Discarded individual-test-filter preflight `/tmp/bracketer-physical-proof-xcresult-summary-parser-tests-1780013400.xcresult`: selected 0 tests, so not proof.
- Earlier discarded preflights: `/tmp/bracketer-physical-proof-xcresult-summary-parser-tests-1780012200.xcresult` failed compile on a helper argument-order mismatch that was fixed, and `/tmp/bracketer-physical-proof-xcresult-summary-parser-tests-1780012800.xcresult` was interrupted by simulator runner state and left an unreadable/corrupt bundle.

### Proof category

- pure-model-proof + local-simulator-proof; physical proof still blocked/no real iPhone accepted.

### Current proof boundary

- Parses compact xcresult summaries into typed proof input but still does not hash a live bundle, export a complete signed physical submission, or prove any of the 8 physical scenarios. Physical proof remains `0 of 8`.

### Next slice

- Wire parsed proof input into submission-template/import-preview flow, automate digest/xcresult extraction, or ingest first real-iPhone scenario after device unlock.

### Goal status

- Goal still open. v23 parser guardrail complete; physical proof still blocked.

## 2026-05-28 07:58 PDT - May Goals physical proof result-bundle summary count reconciliation v1

### What changed

- Extended `BracketerPhysicalResultBundleSummary` with signed total, passed, and failed test counts beside status, title, expected-failure count, and skipped-test count.
- Bumped `BracketerPhysicalProofSubmission.schemaVersion` to v4 and `BracketerPhysicalProofIngestReadiness` to schema v22 so templates, reviewer evidence, Settings, and tests expose the expanded typed summary contract.
- Hardened `BracketerPhysicalProofIngestor` so typed summaries reject zero totals, negative passed/failed counts, partial-pass totals, failed counts, and any summary-count mismatch against `BracketerPhysicalResultBundleMetrics`.
- Kept reviewer-evidence binding delimiter-aware by requiring the expanded summary tokens, including `summary.totaltestcount`, `summary.passedtests`, and `summary.failedtests`.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, the Settings readiness accessibility value, and UI readiness assertions while preserving the `0 of 8` physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print "You are assisting Codex in /Users/m3-max/Documents/GitHub/Bracketer. Read-only sidecar. Do not edit files. We are continuing maygoals.md... Proposed v22: add typed result-bundle summary passed/failed/total test counts and reconcile them against BracketerPhysicalResultBundleMetrics..."`
  - Result: installed the missing Claude CLI (`@anthropic-ai/claude-code`, version `2.1.153`) and launched read-only sidecars with the requested flag. The sidecars returned no usable stdout before termination, so Codex audited and verified the v22 slice locally.
- Unit tests:
  - Final result bundle: `/tmp/bracketer-physical-proof-summary-counts-tests-1780003200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=168`, `failedTests=0`, `skippedTests=0`, `totalTestCount=168`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Follow-up post-UI unit reruns under `/tmp/bracketer-physical-proof-summary-counts-tests-1780008600.xcresult`, `/tmp/bracketer-physical-proof-summary-counts-tests-1780009200.xcresult`, `/tmp/bracketer-physical-proof-summary-counts-tests-1780009800.xcresult`, and `/tmp/bracketer-physical-proof-readiness-accessibility-tests-1780011000.xcresult` were discarded as simulator infrastructure failures: CoreSimulator/xcodebuild interrupted the runner with Mach `-308` or left corrupt result bundles while detached broad UI jobs were also being cleaned up.
  - New executed coverage:
    - typed result-bundle summaries preserve total, passed, and failed test counts
    - invalid summary count shapes reject with `.invalidResultBundleSummary(...)`
    - summary counts that disagree with result-bundle metrics reject with `.resultBundleSummaryMetricsMismatch(...)`
    - reviewer evidence must echo the expanded typed summary tokens
    - submission schema v4 and readiness schema v22 are asserted
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-summary-counts-readiness-ui-tests-1780008000.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testPhysicalProofIngestorReadinessExposesSummaryCountContract`, including the Settings > About proof-ingestor row with `schema v22`, summary total/passed/failed required fields, and the summary-count metric-match/mismatch strings.
  - Earlier broad capture/review UI attempts failed or hung in simulator navigation/query state before the focused readiness proof was split out.

### Proof category

- `pure-model-proof`: unit tests cover typed summary counts, metric reconciliation, reviewer-evidence binding, schema v4/v22 output, and privacy-safe Codable persistence.
- `local-simulator-proof`: focused UI automation passed against the Settings readiness surface on the iPhone 17 simulator.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This proves a stricter signed-ingest contract for future physical result-bundle summaries. It still does not parse live `xcresulttool` JSON into submissions and does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Parse live `xcresulttool get test-results summary --compact` JSON into typed proof input, or ingest the first real-iPhone scenario after the connected device is unlocked.

### Goal status

- Goal still open. Verified guardrail complete for v22. Physical proof remains blocked by locked device.

## 2026-05-28 07:48 PDT - May Goals physical proof typed result-bundle summary binding v1

### What changed

- Added `BracketerPhysicalResultBundleSummary` with signed status, title, expected-failure count, and skipped-test count evidence for physical proof submissions.
- Bumped `BracketerPhysicalProofSubmission.schemaVersion` to v3 and `BracketerPhysicalProofIngestReadiness` to schema v21 so the new typed summary contract is visible in templates, reviewer evidence, Settings, and tests.
- Hardened `BracketerPhysicalProofIngestor` so missing summaries, non-`Passed` statuses, blank summary titles, nonzero expected failures, and nonzero skipped tests reject before a physical proof can be accepted.
- Replaced the loose passing-summary reviewer-evidence gate with delimiter-aware typed summary tokens and suffix-collision coverage.
- Preserved typed summary fields in accepted recorded proofs and Codable output without storing Photos identifiers, raw image bytes, or precise coordinates.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and UI readiness assertions while preserving the `0 of 8` physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print "You are assisting Codex in /Users/m3-max/Documents/GitHub/Bracketer. Continue maygoals.md with the next pure-model slice after v20... Proposed v21: make physical proof result-bundle summary parsing less stringly..."`
  - Result: read-only sidecar recommended a typed result-bundle summary status model, schema v3/v21, reviewer-evidence tokens, tests, and docs/progress updates. Codex implemented a narrow signed status/title/expected-failure/skipped-test summary first; no files were modified by Claude.
- Unit tests:
  - Final result bundle: `/tmp/bracketer-physical-proof-typed-summary-tests-1780001800.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=168`, `failedTests=0`, `skippedTests=0`, `totalTestCount=168`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing typed result-bundle summaries reject with `.missingResultBundleSummary`
    - failed status, blank title, expected failures, and skipped tests reject with `.invalidResultBundleSummary(...)`
    - reviewer evidence missing exact typed summary tokens rejects with `.reviewerEvidenceMissingResultBundleSummary(...)`
    - suffix-collision typed summary evidence does not satisfy the delimiter-aware token check
    - recorded proof Codable output preserves typed summary fields without private Photos identifiers, raw image bytes, or precise coordinates
    - submission schema v3 and readiness schema v21 are asserted
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-typed-summary-ui-tests-1780002400.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v21 typed-summary required-field and rejection-rule strings.

### Proof category

- `pure-model-proof`: unit tests cover typed summary presence, value constraints, reviewer-evidence binding, schema v3/v21 output, and privacy-safe Codable persistence.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness surface and review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This proves a stronger signed-ingest contract for future physical result-bundle summaries. It still does not parse live `xcresulttool` summary JSON into submissions and does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Reconcile typed summary totals against signed result-bundle metrics, parse live `xcresulttool get test-results summary --compact` JSON into typed proof input, or ingest the first real-iPhone scenario after the connected device is unlocked.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 07:28 PDT - May Goals physical proof per-artifact attachment-manifest byte-count reconciliation v1

### What changed

- Extended `BracketerPhysicalAttachmentManifest` with signed per-artifact byte counts keyed by every expected runbook artifact id.
- Added delimiter-bound reviewer-evidence byte tokens (`artifact.<id>.bytes=<count>`) plus a signed `attachment.totalBytes=<sum>` summary value.
- Hardened `BracketerPhysicalProofIngestor` so empty, missing, unexpected, or nonpositive attachment-manifest byte counts reject before a physical proof can be accepted.
- Reconciled the signed attachment-manifest byte total against `BracketerPhysicalResultBundleMetrics.attachmentByteCount` and added `.attachmentManifestByteCountMismatch(...)`.
- Added `.reviewerEvidenceMissingAttachmentManifestByteCounts(...)` with suffix-collision coverage so near-matching byte strings cannot satisfy reviewer evidence.
- Bumped `BracketerPhysicalProofSubmission.schemaVersion` to v2 because the signed attachment manifest gained a field, and bumped `BracketerPhysicalProofIngestReadiness` to schema v20 with the new required fields and rejection rules.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and UI readiness assertions while preserving the `0 of 8` physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print "You are assisting Codex in /Users/m3-max/Documents/GitHub/Bracketer... audit the current working tree for compile/test issues in this v20 slice..."`
  - Result: read-only sidecar found no code/test blockers and identified only missing v20 progress/ledger traceability. No files were modified by Claude.
- Unit tests:
  - Interrupted preflight: XcodeBuildMCP `test_sim` wrote `/tmp/bracketer-physical-proof-attachment-bytes-tests-1780000000.xcresult` but timed out without a readable `Info.plist`; the stuck `test-without-building` process was terminated before the shell fallback.
  - Final result bundle: `/tmp/bracketer-physical-proof-attachment-bytes-tests-1780000600.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=168`, `failedTests=0`, `skippedTests=0`, `totalTestCount=168`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing, unexpected, empty, and nonpositive attachment-manifest byte counts reject with `.invalidAttachmentManifestByteCounts(...)`
    - byte-count totals that disagree with result-bundle metrics reject with `.attachmentManifestByteCountMismatch(...)`
    - reviewer evidence missing attachment byte-count tokens rejects with `.reviewerEvidenceMissingAttachmentManifestByteCounts(...)`
    - suffix-collision byte-count evidence does not satisfy the delimiter-aware token check
    - recorded proof Codable output preserves byte counts and total bytes without private Photos identifiers, raw image bytes, or precise coordinates
    - submission schema v2 and readiness schema v20 are asserted
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-attachment-bytes-ui-tests-1780001200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v20 byte-count required-field and rejection-rule strings.

### Proof category

- `pure-model-proof`: unit tests cover byte-count presence, shape, reviewer-evidence binding, total reconciliation, schema v2/v20 output, and privacy-safe Codable persistence.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness surface and review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This proves a stronger signed-ingest contract for future physical result-bundle attachments. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Make result-bundle summary parsing less stringly, or ingest the first real-iPhone scenario after the connected device is unlocked.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 06:55 PDT - May Goals physical proof result-bundle duration/test-window reconciliation v1

### What changed

- Hardened `BracketerPhysicalProofIngestor` so signed result-bundle metric duration must equal the signed scenario test start/finish window before a physical proof submission can replace an indexed runbook entry.
- Added `.resultBundleTimingDurationMismatch(...)` for shorter or longer metric durations and kept the existing timing, capturedAt, reviewer-evidence, attachment-manifest, and artifact-hash gates intact.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v19 and exposed `result-bundle duration disagrees with test window` in Settings > About.
- Left `BracketerPhysicalProofSubmission.schemaVersion` unchanged because the reconciliation uses already-signed metrics and timing fields; the version bump is for readiness/validation surface traceability.
- Normalized physical-proof test fixtures to `60_000` milliseconds where their signed scenario test window is exactly 60 seconds.
- Updated README, architecture docs, `.codex-maygoals-progress.md`, and UI readiness assertions with the v19 contract and unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "In /Users/m3-max/Documents/GitHub/Bracketer, review the current v19 physical proof duration/test-window reconciliation changes only..."`
  - Result: read-only sidecar found missing v19 progress/ledger traceability, recommended the focused UI smoke, and noted that README could explicitly name schema v19. Codex fixed the docs/logs and kept `BracketerPhysicalProofSubmission.schemaVersion` unchanged because the rule uses existing signed fields; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Final result bundle: `/tmp/bracketer-physical-proof-duration-window-tests-1779979800.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=168`, `failedTests=0`, `skippedTests=0`, `totalTestCount=168`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - shorter metric durations reject with `.resultBundleTimingDurationMismatch(...)`
    - longer metric durations reject with `.resultBundleTimingDurationMismatch(...)`
    - exact metric durations matching the signed scenario test window ingest and update the matching result-bundle index entry
    - readiness schema v19 exposes the new duration/test-window rejection rule
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-duration-window-ui-tests-1779980400.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v19 duration/test-window readiness string.

### Proof category

- `pure-model-proof`: unit tests cover duration/test-window reconciliation, mismatch failures, exact-duration acceptance, and schema v19 readiness copy.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness surface and review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This reconciles signed result-bundle metrics with signed result-bundle timing metadata. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Require attachment byte counts to reconcile with result-bundle metrics, make result-bundle summary parsing less stringly, or ingest the first real-iPhone scenario after the connected device is unlocked.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 06:42 PDT - May Goals physical proof result-bundle attachment-manifest context binding v1

### What changed

- Extended signed `BracketerPhysicalAttachmentManifest` records with their own result-bundle filename, scenario test identifier, and scenario test start/finish timestamps.
- Hardened `BracketerPhysicalProofIngestor` so attachment manifests reject before artifact-hash trust if their result-bundle filename, test identifier, or timing metadata diverges from the signed submission.
- Split reviewer-evidence validation into attachment-manifest context tokens first and per-artifact hash tokens second, preserving delimiter-aware suffix-collision rejection for both evidence layers.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v18 and exposed `attachment manifest result-bundle filename`, `attachment manifest scenario test identifier`, `attachment manifest test start and finish time`, `attachment manifest result-bundle context in reviewer evidence`, `invalid attachment manifest context`, and `reviewer evidence missing attachment manifest context` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the v18 contract and unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "In /Users/m3-max/Documents/GitHub/Bracketer, read-only sidecar. Do not edit files. Review the current v18 physical proof attachment-manifest context binding slice for likely Swift test/doc drift..."`
  - Initial result: blocked by Claude session limit (`You've hit your session limit · resets 6:40am (America/Los_Angeles)`); no files were modified by Claude.
  - Retry after reset: read-only sidecar found readiness wording drift (`missing artifacts` vs canonical `missing expected artifacts`) and a missing unit assertion. Codex fixed README/architecture wording and added the assertion; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Failed compile result bundle: `/tmp/bracketer-physical-proof-attachment-context-tests-1779977600.xcresult`.
  - Failure: the submission template closure needed an explicit `return` after local result-bundle context values were introduced.
  - Failed compile result bundle: `/tmp/bracketer-physical-proof-attachment-context-tests-1779977800.xcresult`.
  - Failure: the test helper closure needed an explicit `return` after adding local manifest context defaults.
  - Failed fixture result bundle: `/tmp/bracketer-physical-proof-attachment-context-tests-1779978000.xcresult`.
  - Failure: two older fixtures created default attachment manifests whose timing did not match their custom submission timing; fixed by passing the submission filename, test contract, and timing into those manifests.
  - Final result bundle after the sidecar wording/assertion fix: `/tmp/bracketer-physical-proof-attachment-context-tests-1779979000.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=168`, `failedTests=0`, `skippedTests=0`, `totalTestCount=168`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - attachment manifests whose result-bundle filename does not match the submitted `.xcresult` filename reject before mutation
    - attachment manifests whose scenario test identifier does not match the signed result-bundle test contract reject before mutation
    - attachment manifests whose test start or finish timestamp does not match signed timing metadata reject before mutation
    - reviewer evidence missing attachment-manifest result-bundle context rejects before artifact hash checks
    - reviewer evidence missing per-artifact attachment hashes still rejects after context evidence is present
    - suffix-collision evidence does not satisfy either context or artifact hash tokens
    - readiness copy asserts the canonical `missing expected artifacts` rejection string
    - readiness schema v18 exposes the new attachment-manifest context required fields and rejection rules
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-attachment-context-ui-tests-1779978600.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v18 attachment-manifest context required fields and rejection strings.

### Proof category

- `pure-model-proof`: unit tests cover signed context binding, context mismatch branches, delimiter-aware reviewer-evidence binding, suffix-collision rejection, Codable/readiness output, and schema v18 copy.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness strings and the review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This binds claimed lab attachment hashes to a signed result-bundle filename, scenario test id, and scenario test window. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Require attachment byte counts to reconcile with result-bundle metrics, make result-bundle summary parsing less stringly, or ingest the first real-iPhone scenario after the connected device is unlocked.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 06:14 PDT - May Goals physical proof per-artifact attachment-manifest hash binding v1

### What changed

- Added signed `BracketerPhysicalAttachmentManifest` to physical proof submissions, binding every expected runbook artifact id to a per-artifact SHA-256 digest inside the canonical attachment signature.
- Hardened `BracketerPhysicalProofIngestor` to require the attachment manifest, reject missing expected artifact ids, reject unexpected artifact ids, and reject malformed artifact digests before any runbook/index mutation.
- Required reviewer evidence to echo compact delimiter-bound `artifact.<id>.sha256=<digest>` tokens and preserved the suffix-collision boundary so longer digest strings cannot satisfy the exact artifact hash contract.
- Extended recorded physical proof accessibility/Codable output with attachment-manifest hashes while preserving the no Photos identifiers, no image bytes, and no precise coordinates boundary.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v17 and exposed `per-artifact attachment manifest SHA-256 values`, `attachment manifest hashes in reviewer evidence`, `missing attachment manifest hashes`, `invalid attachment manifest hashes`, and `reviewer evidence missing attachment manifest hashes` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the v17 contract and unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "In /Users/m3-max/Documents/GitHub/Bracketer, review the in-progress v17 physical proof attachment-manifest hash changes for Swift compile/test risks only. Do not edit files. Summarize likely failures and exact file/line fixes."`
  - Result: blocked by Claude session limit (`You've hit your session limit · resets 6:40am (America/Los_Angeles)`); no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Final result bundle: `/tmp/bracketer-physical-proof-attachment-manifest-tests-1779976200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=168`, `failedTests=0`, `skippedTests=0`, `totalTestCount=168`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing `attachmentManifest` rejects before mutation
    - missing expected artifact ids, unexpected artifact ids, and malformed artifact digests reject before mutation
    - reviewer evidence missing compact attachment-manifest tokens rejects before mutation
    - reviewer evidence with suffix-collision artifact hash values does not satisfy the exact manifest binding
    - tampering only signed attachment-manifest data rejects with `.invalidAttachmentSignature`
    - Codable recorded proof output preserves attachment-manifest hashes without Photos identifiers, image bytes, or coordinates
    - readiness schema v17 exposes the new attachment-manifest required fields and rejection rules
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-attachment-manifest-ui-tests-1779976800.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v17 `attachment manifest hashes in reviewer evidence`, `per-artifact attachment manifest SHA-256 values`, `invalid attachment manifest hashes`, and `reviewer evidence missing attachment manifest hashes` readiness strings.

### Proof category

- `pure-model-proof`: unit tests cover signature binding, validation branches, delimiter-aware reviewer-evidence binding, suffix-collision rejection, preview-only rejection, Codable round trip, and schema v17 readiness copy.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness strings and the review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: Claude offload was unavailable due the Claude session limit; physical iPhone proof remains blocked by the locked connected device.

### Current proof boundary

- This binds each claimed lab attachment to a signed per-artifact SHA-256 manifest and reviewer evidence. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Bind attachment manifests to result-bundle timing/test identifiers, require attachment byte counts to match result-bundle metrics, or ingest the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 05:58 PDT - May Goals physical proof result-bundle timing-window binding v1

### What changed

- Added signed `BracketerPhysicalResultBundleTiming` to physical proof submissions, binding xcresult summary start/finish times and scenario test start/finish times into the canonical attachment signature.
- Hardened `BracketerPhysicalProofIngestor` to require timing metadata, reject impossible summary/test windows, reject future/stale timing, and require `capturedAt` to fall inside the result-bundle test window.
- Required reviewer evidence to echo compact timing tokens and reused delimiter-aware matching so suffixed timestamp collisions cannot satisfy the exact timing contract.
- Extended recorded physical proof accessibility/Codable output with timing metadata while preserving the no Photos identifiers, no image bytes, and no precise coordinates boundary.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v16 and exposed `result-bundle timing metadata`, `result-bundle summary start and finish time`, `scenario test start and finish time`, `capturedAt inside result-bundle test window`, `result-bundle timing metadata in reviewer evidence`, `missing result-bundle timing metadata`, `invalid result-bundle timing metadata`, `capturedAt outside result-bundle test window`, and `reviewer evidence missing result-bundle timing metadata` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the v16 contract and unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are a read-only sidecar in /Users/m3-max/Documents/GitHub/Bracketer. Do not edit files. Propose the smallest next maygoals slice after v15: bind capturedAt to explicit xcresult summary/test timing metadata in BracketerPhysicalProofIngestor..."`
  - Result: blocked by Claude session limit (`You've hit your session limit · resets 6:40am (America/Los_Angeles)`); no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Final result bundle: `/tmp/bracketer-physical-proof-timing-tests-1779975000.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=167`, `failedTests=0`, `skippedTests=0`, `totalTestCount=167`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing `resultBundleTiming` rejects before mutation
    - invalid summary/test timing windows reject before mutation
    - capturedAt outside the result-bundle test window rejects before mutation
    - reviewer evidence missing compact timing tokens rejects before mutation
    - reviewer evidence with suffix-collision timing values does not satisfy the exact timing binding
    - tampering only signed timing-window data rejects with `.invalidAttachmentSignature`
    - Codable recorded proof output preserves timing metadata without Photos identifiers, image bytes, or coordinates
    - readiness schema v16 exposes the new timing-window required fields and rejection rules
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-timing-ui-tests-1779975600.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v16 `result-bundle timing metadata in reviewer evidence`, `capturedAt inside result-bundle test window`, `invalid result-bundle timing metadata`, and `reviewer evidence missing result-bundle timing metadata` readiness strings.

### Proof category

- `pure-model-proof`: unit tests cover signature binding, validation branches, delimiter-aware reviewer-evidence binding, suffix-collision rejection, preview-only rejection, Codable round trip, and schema v16 readiness copy.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness strings and the review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: Claude offload was unavailable due the Claude session limit; physical iPhone proof remains blocked by the locked connected device.

### Current proof boundary

- This binds the claimed capture timestamp to a signed xcresult summary/test timing window and reviewer evidence. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Add per-scenario attachment-manifest hashes, bind attachment manifests to result-bundle timing/test identifiers, or ingest the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 05:37 PDT - May Goals physical proof result-bundle test-contract binding v1

### What changed

- Added signed `BracketerPhysicalResultBundleTestContract` to physical proof submissions, binding xcodebuild version, xcresulttool version, test-plan configuration name, scenario-bound test identifier, and test name into the canonical attachment signature.
- Hardened `BracketerPhysicalProofIngestor` to require the test contract, reject missing/invalid tool-version and test-id data, require the test identifier to contain the selected physical scenario id, and require reviewer evidence to echo compact test-contract tokens.
- Reused delimiter-aware reviewer-evidence matching so suffix-collision values such as a longer test identifier or tool version cannot satisfy the exact test-contract token.
- Extended recorded physical proof accessibility/Codable output with the test contract while preserving the no Photos identifiers, no image bytes, and no precise coordinates boundary.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v15 and exposed `result-bundle test contract`, `xcodebuild version`, `xcresulttool version`, `scenario-bound test identifier`, `result-bundle test contract in reviewer evidence`, `missing result-bundle test contract`, `invalid result-bundle test contract`, and `reviewer evidence missing result-bundle test contract` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the v15 contract and unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are a read-only sidecar in /Users/m3-max/Documents/GitHub/Bracketer. Do not edit files. We are continuing maygoals.md. Current unblocked next slice: deepen BracketerPhysicalProofIngestor's result-bundle metrics guardrail into a signed xcresult test-id and tool-version contract..."`
  - Result: blocked by Claude session limit (`You've hit your session limit · resets 6:40am (America/Los_Angeles)`); no files were modified by Claude.
- Local SDK/tool proof:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version` -> `Xcode 26.5`, `Build version 17F42`.
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun xcresulttool --version` -> `xcresulttool version 24757, schema version: 0.1.0 (legacy commands format version: 3.58)`.
- App-hosted unit tests on throwaway simulator:
  - Failed compile result bundle: `/tmp/bracketer-physical-proof-test-contract-tests-1779973400.xcresult`.
  - Failure: reviewer-evidence helper needed an explicit `return` after gaining a local resolved test-contract value.
  - Failed pre-fixture result bundle: `/tmp/bracketer-physical-proof-test-contract-tests-1779973600.xcresult`.
  - Failure: older case/whitespace and template-placeholder fixtures did not yet provide the now-required test contract, so they hit the new missing-contract branch before their intended assertions.
  - Final result bundle: `/tmp/bracketer-physical-proof-test-contract-tests-1779973900.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=166`, `failedTests=0`, `skippedTests=0`, `totalTestCount=166`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing `resultBundleTestContract` rejects before mutation
    - invalid xcodebuild versions, xcresulttool versions, blank test-plan names, missing test names, and test identifiers that do not contain the selected scenario id reject before mutation
    - reviewer evidence missing compact test-contract tokens rejects before mutation
    - reviewer evidence with suffix-collision values does not satisfy the exact test-contract binding
    - tampering only signed test-contract data rejects with `.invalidAttachmentSignature`
    - Codable recorded proof output preserves the test contract without Photos identifiers, image bytes, or coordinates
    - readiness schema v15 exposes the new test-contract required fields and rejection rules
- Focused UI test:
  - Final result bundle: `/tmp/bracketer-physical-proof-test-contract-ui-tests-1779974200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - Covered `testSimulatedBracketCaptureCompletesAndOpensReview`, including the Settings > About proof-ingestor row with the v15 `result-bundle test contract in reviewer evidence`, `scenario-bound test identifier`, and `reviewer evidence missing result-bundle test contract` readiness strings.

### Proof category

- `pure-model-proof`: unit tests cover signature binding, validation branches, delimiter-aware reviewer-evidence binding, suffix-collision rejection, preview-only rejection, Codable round trip, and schema v15 readiness copy.
- `local-sdk-proof`: local Xcode and xcresulttool version commands prove the tool-version strings are available from the installed toolchain.
- `local-simulator-proof`: focused UI automation verifies the Settings readiness strings and the review/project handoff path on the iPhone 17 simulator.
- `blocked-proof`: Claude offload was unavailable due the Claude session limit; physical iPhone proof remains blocked by the locked connected device.

### Current proof boundary

- This binds the claimed xcresult-producing toolchain and scenario test identifier to the signed submission and reviewer evidence. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Completed in the 05:58 timing-window slice. Continue with per-scenario attachment-manifest hashes, attachment-manifest/test-id binding, or the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 05:16 PDT - May Goals physical proof result-bundle metrics binding v1

### What changed

- Added signed `BracketerPhysicalResultBundleMetrics` to physical proof submissions, binding total tests, passed tests, failed tests, duration milliseconds, and attachment byte count into the canonical attachment signature.
- Hardened `BracketerPhysicalProofIngestor` to require metrics, reject invalid metric totals/pass/fail/duration/attachment values, and require reviewer evidence to echo metric-prefixed tokens.
- Tightened reviewer-evidence metric matching so suffix-collision values such as `metrics.totalTestCount=1640` cannot satisfy `metrics.totalTestCount=164`.
- Updated physical proof templates to include a zeroed metrics scaffold so the signed JSON shape advertises the now-required metrics object while still failing validation until real xcresult values replace it.
- Extended recorded physical proof accessibility/Codable output with result-bundle metrics while preserving the no raw Photos identifiers, no image bytes, and no precise coordinates boundary.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v14 and exposed `result-bundle metrics`, `result-bundle metrics in reviewer evidence`, `missing result-bundle metrics`, `invalid result-bundle metrics`, and `reviewer evidence missing result-bundle metrics` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the metrics binding and unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are a read-only sidecar in /Users/m3-max/Documents/GitHub/Bracketer. Do not edit files. Design the next v14 pure-model guardrail: typed result-bundle metrics/timing attachment binding..."`
  - Result: read-only delegate recommended a heavier metrics/timing attachment; Codex implemented the compact signed metrics guardrail first.
  - Command: `claude --dangerously-skip-permissions -p "You are a read-only sidecar reviewer in /Users/m3-max/Documents/GitHub/Bracketer. Do not edit files. Audit the current uncommitted v14 physical proof metrics-binding slice..."`
  - Result: read-only delegate found the metrics substring-collision risk and doc/ledger drift; Codex fixed delimiter-aware token matching and added suffix-collision coverage.
- App-hosted unit tests on throwaway simulator:
  - Failed pre-fix result bundle: `/tmp/bracketer-physical-proof-metrics-binding-tests-1779971600.xcresult`.
  - Failure: delimiter-aware matching exposed that compacted evidence lines were glued together, so the final attachment-byte metric did not have a trailing boundary.
  - Final result bundle after adding the template metrics scaffold: `/tmp/bracketer-physical-proof-metrics-binding-tests-1779972200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=165`, `failedTests=0`, `skippedTests=0`, `totalTestCount=165`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing `resultBundleMetrics` rejects before mutation
    - invalid total tests, passed tests, failed tests, duration, and attachment byte count each reject before mutation
    - reviewer evidence missing metric-prefixed tokens rejects before mutation
    - reviewer evidence with suffix-collision values does not satisfy the exact metrics contract
    - tampering only signed metrics rejects with `.invalidAttachmentSignature`
    - template submissions expose the required metrics shape with zero values that still fail until replaced by real xcresult metrics
    - preview rejects missing-metrics evidence without mutating runbooks, indexes, or physical proof counts
    - readiness schema v14 exposes the new metrics required fields and rejection rules
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - First signal bundle before the final delimiter fix: `/tmp/bracketer-physical-proof-metrics-binding-ui-tests-1779971400.xcresult`, `result=Passed`, `passedTests=1`.
  - Interrupted stale post-fix bundle after the template scaffold changed code: `/tmp/bracketer-physical-proof-metrics-binding-ui-tests-1779972000.xcresult`.
  - Final post-template-scaffold result bundle: `/tmp/bracketer-physical-proof-metrics-binding-ui-tests-1779972400.xcresult`; `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.

### Proof category

- `pure-model-proof`: unit tests cover signature binding, metric validation, delimiter-aware reviewer-evidence binding, preview-only rejection, Codable round trip, and schema v14 readiness copy.
- `visible-ui-proof`: focused UI test is verifying that the metrics contract appears in the Settings > About physical-proof row after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This binds compact result-bundle metrics to the signed submission and reviewer evidence. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Deepen the metrics/timing attachment into a full xcresult test-id/tool-version contract, or ingest the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 04:51 PDT - May Goals physical proof result-bundle-summary SHA-256 binding v1

### What changed

- Added `resultBundleSummarySHA256` to signed `BracketerPhysicalProofSubmission` payloads so the digest of the extracted `.xcresult` summary is part of the attachment integrity check.
- Hardened `BracketerPhysicalProofIngestor` to require that summary digest, validate it as SHA-256, reject it when it equals the full result-bundle SHA-256, require reviewer evidence to echo it, and reject post-signature tampering of the field.
- Extended `BracketerPhysicalCaptureRunbook.RecordedProof` so accepted physical proof records can persist the optional result-bundle summary SHA-256 beside the full result-bundle and manifest digests.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v13 and exposed `result-bundle summary SHA-256`, `result-bundle summary SHA-256 in reviewer evidence`, `missing result-bundle summary SHA-256`, `result-bundle summary SHA-256 equals bundle SHA-256`, and `reviewer evidence missing result-bundle summary SHA-256` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the summary-digest binding and the unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are a sidecar reviewer in /Users/m3-max/Documents/GitHub/Bracketer. Do not edit files. Audit the current uncommitted v13 physical proof result-bundle-summary SHA-256 slice..."`
  - Result: read-only sidecar audit found no expected compile failure, identified doc/progress/ledger drift, and recommended typed result-bundle metrics/timing attachment binding as the next v14 guardrail; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Failed pre-fix result bundle: `/tmp/bracketer-physical-proof-summary-digest-tests-1779970000.xcresult`.
  - Failure: one device-identity reviewer-evidence fixture reused the same `d*64` digest for both the result-bundle summary SHA-256 and hashed device identifier, so the summary line accidentally satisfied the hash echo check.
  - Final result bundle: `/tmp/bracketer-physical-proof-summary-digest-tests-1779970000.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=164`, `failedTests=0`, `skippedTests=0`, `totalTestCount=164`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing `resultBundleSummarySHA256` rejects before mutation
    - malformed summary digests reject on `invalidSHA256(field: "resultBundleSummarySHA256")`
    - summary digests equal to the full bundle digest reject before evidence checks
    - reviewer evidence missing the summary digest rejects before mutation
    - tampering only the signed summary digest rejects with `.invalidAttachmentSignature`
    - preview rejects the missing-summary-digest evidence path without mutating runbooks, result-bundle indexes, or physical proof counts
    - readiness schema v13 exposes the new summary-digest required fields and rejection rules
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Result bundle: `/tmp/bracketer-physical-proof-summary-digest-ui-tests-1779970200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `settings.deviceProof.proofIngestor` with result-bundle summary SHA-256 required-field and rejection strings while keeping `0 of 8 physical submissions accepted`.

### Proof category

- `pure-model-proof`: unit tests cover signature binding, validation ordering, reviewer-evidence binding, preview-only rejection, Codable round trip, and schema v13 readiness copy.
- `visible-ui-proof`: focused UI test proves the result-bundle summary SHA-256 contract appears in the Settings > About physical-proof row after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This binds the extracted result-bundle summary digest to the signed submission and reviewer evidence. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- The compact typed metrics binding was completed in the 05:16 slice; next deepen it into a full xcresult test-id/tool-version contract, or ingest the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 04:29 PDT - May Goals physical proof passing result-bundle-summary evidence binding v1

### What changed

- Hardened `BracketerPhysicalProofIngestor` so reviewer evidence must now include a passing result-bundle summary with `result=Passed` and `failedTests=0` before a signed physical proof submission can replace a runbook/index entry.
- Added `BracketerPhysicalProofIngestor.ValidationFailure.reviewerEvidenceMissingPassingResultBundleSummary`.
- Extended the physical proof reviewer-evidence helper so default accepted evidence now binds capturedAt, result-bundle filename, result-bundle SHA-256, passing result-bundle summary, hashed device identifier, device model identifier, iOS build label, and the runbook-specific evidence descriptors.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v12 and exposed `passing result-bundle summary in reviewer evidence` and `reviewer evidence missing passing result-bundle summary` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the passing result-bundle-summary binding and the unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print "In /Users/m3-max/Documents/GitHub/Bracketer, act as an analysis-only sidecar... Recommend exactly one next small pure-model guardrail..."`
  - Result: analysis-only delegate recommended a heavier result-bundle-summary SHA-256 field; Codex implemented the smaller same-direction guardrail that requires reviewer evidence to include a passing result-bundle summary (`result=Passed`, `failedTests=0`); no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Result bundle: `/tmp/bracketer-physical-proof-passing-summary-evidence-tests-1779968400.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=163`, `failedTests=0`, `skippedTests=0`, `totalTestCount=163`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - reviewer evidence missing a passing result-bundle summary rejects before mutation
    - reviewer evidence reporting `result=Failed` and `failedTests=1` rejects before mutation
    - preview rejects the failed-summary evidence path without mutating runbooks, result-bundle indexes, or physical proof counts
    - case/whitespace-varied `result = PASSED` and `failedTests = 0` reviewer evidence remains accepted
    - readiness schema v12 exposes the new passing result-bundle-summary required field and rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Result bundle: `/tmp/bracketer-physical-proof-passing-summary-evidence-ui-tests-1779968600.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `settings.deviceProof.proofIngestor` with passing result-bundle-summary required-field and rejection strings while keeping `0 of 8 physical submissions accepted`.

### Proof category

- `pure-model-proof`: unit tests cover direct-ingest and preview rejection for missing or failing result-bundle summary evidence, case-tolerant accepted summary evidence, and schema v12 readiness copy.
- `visible-ui-proof`: focused UI test proves the passing result-bundle-summary reviewer-evidence contract appears in the Settings > About physical-proof row after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This binds reviewer evidence to a claimed passing xcresult summary. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- The heavier result-bundle-summary SHA-256 field was completed in the 04:51 slice; next add result-bundle timing/metrics attachment binding, or ingest the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 04:17 PDT - May Goals physical proof device-identity reviewer-evidence binding v1

### What changed

- Hardened `BracketerPhysicalProofIngestor` so reviewer evidence must now echo the hashed device identifier, device model identifier, and iOS build label before a signed physical proof submission can replace a runbook/index entry.
- Added `BracketerPhysicalProofIngestor.ValidationFailure.reviewerEvidenceMissingHashedDeviceIdentifier`, `.reviewerEvidenceMissingDeviceModelIdentifier`, and `.reviewerEvidenceMissingIOSBuild`.
- Extended the physical proof test helper so default reviewer evidence now binds capturedAt, result-bundle filename, result-bundle SHA-256, hashed device identifier, device model identifier, iOS build label, and the runbook-specific evidence descriptors.
- Kept the privacy boundary intact: reviewer evidence binds to a hashed device identifier and does not require raw device unique identifiers, Photos identifiers, raw image bytes, or precise coordinates.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v11 and exposed `hashed device identifier in reviewer evidence`, `device model identifier in reviewer evidence`, `iOS build label in reviewer evidence`, `reviewer evidence missing hashed device identifier`, `reviewer evidence missing device model identifier`, and `reviewer evidence missing iOS build label` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the device-identity reviewer-evidence binding and the unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print "In /Users/m3-max/Documents/GitHub/Bracketer, act as an analysis-only sidecar... Recommend one next small pure-model physical proof ingestor guardrail..."`
  - Result: analysis-only delegate recommended binding reviewer evidence to `hashedDeviceIdentifier`; Codex implemented that plus device model identifier and iOS build label; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Failed pre-fix result bundle: `/tmp/bracketer-physical-proof-device-label-evidence-tests-1779966800.xcresult`.
  - Failure: the case/whitespace-varied reviewer evidence acceptance test had not echoed the new device model identifier.
  - Failed build result bundle: `/tmp/bracketer-physical-proof-device-identity-evidence-tests-1779967200.xcresult`.
  - Failure: several `validPhysicalProofSubmission(...)` call sites used the old argument order after the helper gained device-identity reviewer evidence parameters.
  - Final result bundle: `/tmp/bracketer-physical-proof-device-identity-evidence-tests-1779967600.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=162`, `failedTests=0`, `skippedTests=0`, `totalTestCount=162`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - reviewer evidence missing the hashed device identifier rejects before mutation
    - reviewer evidence missing the device model identifier rejects before mutation
    - reviewer evidence missing the iOS build label rejects before mutation
    - preview rejects the missing-iOS-build evidence path without mutating runbooks, result-bundle indexes, or physical proof counts
    - case-varied hash/model/build reviewer evidence remains accepted
    - readiness schema v11 exposes the new device-identity reviewer-evidence required fields and rejection rules
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Result bundle: `/tmp/bracketer-physical-proof-device-identity-evidence-ui-tests-1779967800.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `settings.deviceProof.proofIngestor` with device-identity reviewer-evidence required-field and rejection strings while keeping `0 of 8 physical submissions accepted`.

### Proof category

- `pure-model-proof`: unit tests cover direct-ingest and preview rejection for unbound device-identity reviewer evidence, case-tolerant accepted evidence, and schema v11 readiness copy.
- `visible-ui-proof`: focused UI test proves the device-identity reviewer-evidence contract appears in the Settings > About physical-proof row after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This binds submitted reviewer evidence to claimed physical-device metadata. It still does not prove any of the 8 physical capture scenarios because no accepted real-iPhone result bundle was ingested.
- The physical proof count remains `0 of 8`.

### Next slice

- Add another pure-model/simulator-visible physical-proof guardrail while the iPhone is locked, such as capturedAt-to-result-bundle-summary binding, or ingest the first real-iPhone scenario after the connected device is unlocked.

## 2026-05-28 04:02 PDT - May Goals physical proof result-bundle reviewer-evidence binding v1

### What changed

- Hardened `BracketerPhysicalProofIngestor` so reviewer evidence must now echo the exact result-bundle filename and result-bundle SHA-256 before a signed physical proof submission can replace a runbook/index entry.
- Added `BracketerPhysicalProofIngestor.ValidationFailure.reviewerEvidenceMissingResultBundleFilename` and `.reviewerEvidenceMissingResultBundleSHA256`.
- Kept same-scenario rerun filenames allowed, but made the reviewer evidence bind to the exact rerun filename instead of only the base scenario prefix.
- Extended the physical proof test helper so default reviewer evidence includes capturedAt, result-bundle filename, result-bundle SHA-256, and the runbook-specific evidence descriptors.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v10 and exposed `result-bundle filename in reviewer evidence`, `result-bundle SHA-256 in reviewer evidence`, `reviewer evidence missing result-bundle filename`, and `reviewer evidence missing result-bundle SHA-256` in Settings > About.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the result-bundle reviewer-evidence binding and the unchanged no-physical-proof boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print "In /Users/m3-max/Documents/GitHub/Bracketer, act as a concise code-review sidecar... Focus only on the physical proof ingestor result-bundle reviewer-evidence binding slice..."`
  - Result: analysis-only delegate confirmed the code path, flagged stale schema/doc references, and suggested a rerun-suffixed filename regression; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Failed pre-fix result bundle: `/tmp/bracketer-physical-proof-resultbundle-evidence-tests-1779965600.xcresult`.
  - Failure: build failed because the expanded `validPhysicalProofSubmission(...)` helper constructed a `BracketerPhysicalProofSubmission` without returning it.
  - First fixed result bundle: `/tmp/bracketer-physical-proof-resultbundle-evidence-tests-1779965900.xcresult`.
  - Final result bundle after adding the rerun-filename evidence regression: `/tmp/bracketer-physical-proof-resultbundle-evidence-tests-1779966500.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=161`, `failedTests=0`, `skippedTests=0`, `totalTestCount=161`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - reviewer evidence missing the exact result-bundle filename rejects before mutation
    - reviewer evidence missing the exact result-bundle SHA-256 rejects before mutation
    - preview rejects the filename-only evidence path without mutating runbooks, result-bundle indexes, or physical proof counts
    - case-varied filename/SHA reviewer evidence remains accepted
    - rerun-suffixed result bundles must echo the exact rerun filename in reviewer evidence
    - readiness schema v10 exposes the new result-bundle reviewer-evidence required fields and rejection rules
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Result bundle: `/tmp/bracketer-physical-proof-resultbundle-evidence-ui-tests-1779966200.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `settings.deviceProof.proofIngestor` with result-bundle reviewer-evidence required-field and rejection strings while keeping `0 of 8 physical submissions accepted`.

### Proof category

- `pure-model-proof`: unit tests cover direct-ingest and preview rejection for unbound result-bundle reviewer evidence, case-tolerant accepted evidence, schema v10 readiness copy, and exact rerun filename binding.
- `visible-ui-proof`: focused UI test proves the result-bundle reviewer-evidence contract appears in the Settings > About physical-proof row after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This binds a signed physical proof submission to its claimed `.xcresult` filename and digest in human reviewer evidence. It does not authenticate the reviewer, parse the `.xcresult` bundle contents, or prove a real physical iPhone capture.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Either bind reviewer evidence to the submitted physical destination/device label fields, bind the result-bundle summary/metrics to capturedAt and scenario id, or unlock the physical iPhone and run one real-device proof.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 03:46 PDT - May Goals physical proof capturedAt evidence binding v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.capturedAtBeforePhysicalLabWindow`, `.capturedAtInFuture`, and `.reviewerEvidenceMissingCapturedAtTimestamp`.
- Hardened physical proof ingest so signed submissions must use a physical-lab-window `capturedAt` timestamp, cannot claim a future capture beyond the ingest tolerance, and must echo the submission's ISO-8601 capturedAt timestamp in reviewer evidence.
- Kept validation ordering honest: signature, scenario, simulator destination, digest, manifest, artifact, placeholder, device-model, iOS-build, privacy, and scenario-descriptor branches still fire before the new timestamp-binding branch where appropriate.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v9 and exposed `physical capturedAt timestamp`, `capturedAt timestamp in reviewer evidence`, `stale capturedAt timestamp`, `future capturedAt timestamp`, and `reviewer evidence missing capturedAt timestamp` in Settings > About.
- Updated README, architecture notes, UI assertions, and the May-goals progress ledger with the timestamp-binding proof boundary.

### Verification

- XcodeBuildMCP attempt:
  - Command shape: `test_sim` with `-only-testing:BracketerTests`, `-skip-testing:BracketerUITests`, and `-resultBundlePath /tmp/bracketer-physical-proof-capturedat-binding-tests-1779964300.xcresult`.
  - Result: tool timed out after 120s while the underlying `test-without-building` process stayed active and produced an unreadable partial result bundle; Codex killed only that Bracketer `xcodebuild` PID and reran the repo-native command below.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-capturedat-binding-tests-1779964700.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=160`, `failedTests=0`, `skippedTests=0`, `totalTestCount=160`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - stale capturedAt values reject before any scenario count changes
    - future capturedAt values reject before any scenario count changes
    - scenario-bound reviewer evidence without the matching capturedAt timestamp rejects through preview and direct ingest
    - timestamp case variation remains accepted when scenario descriptors are present
    - readiness schema v9 exposes the capturedAt binding required fields and rejection rules
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-capturedat-binding-ui-tests-1779965000.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes the capturedAt required-field/rejection strings in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover stale, future, and timestamp-unbound proof submissions plus schema v9 readiness copy.
- `simulator-ui-proof`: focused UI rerun proves the capturedAt binding contract appears in Settings > About after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This prevents a signed proof submission from reusing old or cross-session reviewer notes without echoing the capture timestamp.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Add capturedAt-to-result-bundle-summary binding while the iPhone remains locked, or unlock the connected iPhone and promote a real physical matrix scenario.

### Goal status

- Goal still open. CapturedAt evidence binding is now required for accepted physical proof submissions; physical proof still requires an unlocked real iPhone.

## 2026-05-28 03:26 PDT - May Goals physical proof manifest-hash binding v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.missingManifestSnapshotSHA256`.
- Hardened physical proof ingest so signed submissions must include a `manifestSnapshotSHA256` value before a scenario can be recorded.
- Kept the existing canonical signature payload unchanged; `manifestSnapshotSHA256` was already signed when present, and the new rule makes that manifest fingerprint mandatory without bumping `BracketerPhysicalProofSubmission.schemaVersion`.
- Preserved validation order so signature failures, simulator destinations, result-bundle filename/digest errors, template placeholders, privacy markers, iPhone-model identifiers, iOS build labels, and reviewer-evidence descriptors keep their established branches.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v8 and exposed `manifest snapshot SHA-256` plus `missing manifest snapshot SHA-256` in the Settings > About proof-ingestor contract.
- Updated README, architecture notes, UI assertions, and the May-goals progress ledger with the manifest-hash boundary.

### Verification

- Claude offload:
  - Planning/review: `claude --dangerously-skip-permissions -p "You are assisting Codex in /Users/m3-max/Documents/GitHub/Bracketer... Recommend a focused next pure-model physical proof guardrail after scenario-bound reviewer evidence..."`
  - Result: analysis-only delegate selected mandatory `manifestSnapshotSHA256` as the next non-overlapping proof-binding guardrail, called out validation-order risks, and recommended schema v8 readiness text; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-manifest-hash-tests-1779971700.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=159`, `failedTests=0`, `skippedTests=0`, `totalTestCount=159`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - missing manifest snapshot digest rejects with `.missingManifestSnapshotSHA256`
    - malformed manifest snapshot digest rejects with `.invalidSHA256(field: "manifestSnapshotSHA256")`
    - valid submissions still ingest with a manifest snapshot digest and keep proof counts bounded to the matching scenario
    - readiness schema v8 exposes the manifest snapshot required field and missing-manifest rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-manifest-hash-ui-tests-1779971900.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `manifest snapshot SHA-256` and `missing manifest snapshot SHA-256` in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover required manifest snapshot fingerprinting, malformed manifest digest rejection, and schema v8 readiness text.
- `visible-ui-proof`: focused UI rerun proves the manifest-hash requirement appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This prevents a signed proof submission from severing the result bundle and reviewer evidence from a bracket manifest fingerprint.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Add reviewer-evidence freshness or capturedAt-window binding so signed physical proof cannot reuse stale or cross-session reviewer notes, or unlock the connected iPhone and promote a real physical matrix scenario.

### Goal status

- Goal still open. Manifest hashes are now mandatory for accepted physical proof submissions; physical proof still requires an unlocked real iPhone.

## 2026-05-28 03:14 PDT - May Goals physical proof scenario-bound reviewer-evidence validation v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.reviewerEvidenceMissingScenarioDescriptors`.
- Hardened physical proof ingest so signed submissions must include reviewer evidence that names every `BracketerPhysicalCaptureRunbook.evidenceSteps` descriptor for the selected scenario; generic notes such as "Attached real camera screenshot" reject before runbook/index mutation.
- Normalized reviewer-evidence comparison for case and whitespace variation while preserving the existing `missingReviewerEvidence` branch for empty evidence.
- Preserved validation order so template placeholders, iPhone-model identifiers, iOS build labels, and privacy markers keep their established rejection branches before the descriptor rule.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v7 and exposed `scenario-bound reviewer evidence` plus `reviewer evidence missing scenario descriptors` in the Settings > About proof-ingestor contract.
- Updated README, architecture notes, UI assertions, and the May-goals progress ledger with the reviewer-evidence boundary.

### Verification

- Claude offload:
  - Documentation/checklist review: `claude --dangerously-skip-permissions -p "You are assisting Codex in /Users/m3-max/Documents/GitHub/Bracketer... Summarize exactly what documentation/progress/ledger updates are needed for the just-implemented slice..."`
  - Result: analysis-only delegate confirmed the schema v7/readiness/doc/ledger updates and that the existing focused UI path is the right Settings-visible proof; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-reviewer-evidence-tests-1779971100.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=159`, `failedTests=0`, `skippedTests=0`, `totalTestCount=159`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - generic reviewer evidence rejects with `.reviewerEvidenceMissingScenarioDescriptors(runbook.evidenceSteps)`
    - preview rejection reports the selected runbook's missing scenario descriptors without mutating proof counts
    - case and whitespace variation in reviewer evidence still accepts when every descriptor is present
    - readiness schema v7 exposes the scenario-bound reviewer-evidence required field and rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-reviewer-evidence-ui-tests-1779970800.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `scenario-bound reviewer evidence` and `reviewer evidence missing scenario descriptors` in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover reviewer-evidence descriptor enforcement, preview rejection boundaries, normalization tolerance, and schema v7 readiness text.
- `visible-ui-proof`: focused UI rerun proves the reviewer-evidence requirement appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This prevents a signed proof submission from claiming real-iPhone evidence with generic reviewer notes that do not name every scenario evidence-step descriptor.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Add reviewer-evidence freshness or manifest-hash binding so a signed physical proof cannot reuse stale or cross-session reviewer notes, or unlock the connected iPhone and promote a real physical matrix scenario.

### Goal status

- Goal still open. Reviewer evidence is now scenario-bound; physical proof still requires an unlocked real iPhone.

## 2026-05-28 02:59 PDT - May Goals physical proof iOS build-label validation v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.invalidIOSBuildLabel`.
- Hardened physical proof ingest so signed submissions must use an iOS build label that is either a dotted iOS version (`26.4`, `26.4.1`) or an Apple build number (`23A1`, `23E254`, `23E254a`).
- Kept blank iOS build labels on the existing `missingIOSBuild` branch.
- Tightened Apple build parsing to a canonical two-digit major, uppercase train letter, numeric build, and optional lowercase suffix.
- Extended `BracketerPhysicalResultBundleIndex.Entry` to schema v2 with the accepted iOS build label so the proof index records the same device/runtime label as the recorded proof.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v6 and exposed `iOS version or build label` plus `invalid iOS build label` in the Settings > About proof-ingestor contract.
- Updated README, architecture notes, UI assertions, and the May-goals progress ledger with the iOS build-label boundary.

### Verification

- Claude offload:
  - Static review: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 2 "You are a token-saving helper for Codex... Review the current diff for the physical proof iOS build-label validation slice..."`
  - UI verification: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 2 "You are a token-saving helper for Codex... Run this focused UI verification exactly..."`
  - Result: Claude found schema/doc drift and validator edge coverage gaps; the UI offload failed late at `settings.projects.library.workspaceButton` after finding the new proof-ingestor strings, so Codex reran the UI test locally.
- Failed pre-fix unit run:
  - Result bundle: `/tmp/bracketer-physical-proof-ios-build-tests-1779967300.xcresult`.
  - Failure: the new test expected `BracketerPhysicalResultBundleIndex.Entry.iosBuild` before the result-bundle index entry carried that field.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-ios-build-tests-1779967900.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=157`, `failedTests=0`, `skippedTests=0`, `totalTestCount=157`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - generic/prose/whitespace-padded/malformed dotted labels reject
    - malformed Apple build labels, lowercase train letters, uppercase suffixes, leading-letter labels, and one-digit-major labels reject
    - blank labels reject as `missingIOSBuild`
    - accepted dotted iOS versions and Apple build numbers persist into recorded proof and result-bundle index entries
    - readiness schema v6 exposes the iOS build-label required field and rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Claude result bundle: `/tmp/bracketer-physical-proof-ios-build-ui-tests-1779967600.xcresult`.
  - Claude result: failed late at `settings.projects.library.workspaceButton`; diagnosis confirmed the iOS build readiness strings were present before the unrelated scroll-path failure.
  - Local rerun command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-ios-build-ui-tests-1779968400-rerun.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `iOS version or build label` and `invalid iOS build label` in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover iOS build-label shape enforcement, accepted canonical labels, result-bundle-index persistence, missing-label ordering, and schema v6 readiness text.
- `visible-ui-proof`: focused UI rerun proves the iOS build-label requirement appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This prevents a signed proof submission from claiming real-iPhone evidence with generic, malformed, or placeholder OS labels.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Add reviewer-evidence manifest validation so a signed physical proof cannot name generic reviewer notes without matching the selected scenario's required evidence descriptors.

### Goal status

- Goal still open. iOS build labels are enforced; physical proof still requires an unlocked real iPhone.

## 2026-05-28 02:34 PDT - May Goals physical proof iPhone device-model identifier enforcement v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.deviceModelIdentifierNotIPhone`.
- Hardened physical proof ingest so a signed submission's `deviceModelIdentifier` must be an iPhone hardware identifier shaped like `iPhoneN,M`, rejecting generic, simulator, Mac, iPad, case-variant, malformed, extra-segment, and whitespace-padded labels.
- Kept blank device labels on the existing `missingDeviceModelIdentifier` branch.
- Preserved the earlier proof-template ordering: raw signed templates still reject first on the primary `resultBundleSHA256` placeholder, and retained `REPLACE_WITH_` device-model placeholders still reject as unreplaced template placeholders before the semantic iPhone-model rule.
- Updated the exported proof-submission template placeholder to `REPLACE_WITH_IPHONE_MODEL_IDENTIFIER_LIKE_iPhone17,1`.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v5 and exposed `iPhone model identifier (iPhoneN,M)` plus `non-iPhone model identifier` in the Settings > About proof-ingestor contract.
- Updated README, architecture notes, UI assertions, and the May-goals progress ledger with the iPhone-model identifier boundary.

### Verification

- Claude offload:
  - Planning: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 1.50 "You are a token-saving planning helper for Codex... Recommend exactly one next feasible pure-model or simulator-visible slice..."`
  - Code review: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 1.50 "You are a token-saving code-review helper for Codex... Audit the just-added physical proof iPhone device-model identifier enforcement slice..."`
  - UI verification: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 2 "You are a token-saving helper for Codex... Run this focused UI verification exactly..."`
  - Result: Claude selected the slice, caught the validation-order regression, and ran the slow focused UI pass; no files were modified by Claude.
- Failed pre-fix unit run:
  - Result bundle: `/tmp/bracketer-physical-proof-iphone-model-tests-1779966100.xcresult`.
  - Failure: `physicalProofSubmissionTemplateDocumentAndPreviewRejectPlaceholders` proved the new device-model check was firing before the existing primary digest placeholder. The validator order was corrected before accepting the slice.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-iphone-model-tests-1779966500.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=155`, `failedTests=0`, `skippedTests=0`, `totalTestCount=155`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - non-iPhone and malformed model identifiers reject on the new failure
    - canonical `iPhone17,1` and `iPhone16,2` identifiers ingest and persist into recorded proof and result-bundle index entries
    - retained iPhone-model template placeholders still reject as placeholders
    - raw signed templates still reject first on the primary result-bundle digest placeholder
    - readiness schema v5 exposes the iPhone-model required field and rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command run by Claude: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-iphone-model-ui-tests-1779966800.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary from Claude: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `iPhone model identifier` and `non-iPhone model identifier` in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover iPhone-model shape enforcement, canonical accepted identifiers, template ordering, and schema v5 readiness text.
- `visible-ui-proof`: focused UI test proves the iPhone-model requirement appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This prevents a signed proof submission from claiming real-iPhone evidence with generic or non-iPhone device labels.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Add iOS build-shape validation so a signed physical proof submission cannot use generic or placeholder OS labels while claiming a real iPhone lab run.

### Goal status

- Goal still open. iPhone model identifiers are enforced; physical proof still requires an unlocked real iPhone.

## 2026-05-28 02:20 PDT - May Goals physical proof scenario-bound result-bundle filename v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.resultBundleFilenameScenarioMismatch`.
- Hardened physical proof ingest so a signed submission's `.xcresult` filename must match the selected runbook's `Bracketer-<scenario-id>-physical.xcresult` filename or a same-scenario rerun suffix such as `Bracketer-<scenario-id>-physical-rerun-02.xcresult`.
- Kept path-like filenames on the existing invalid-filename branch before scenario matching, so nested or directory-spoofed result bundles still reject deterministically.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v4 and exposed `scenario-bound result-bundle filename` plus `result-bundle filename for a different scenario` in the Settings > About proof-ingestor contract.
- Updated README, architecture notes, UI assertions, and the May-goals progress ledger with the scenario-bound result-bundle boundary.

### Verification

- Claude offload:
  - Static audit: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 2 "You are a token-saving helper for Codex... Audit the current physical proof scenario-bound result-bundle filename slice..."`
  - Unit preflight: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 2 "You are a token-saving helper for Codex... Run the focused BracketerTests verification..."`
  - UI verification: `claude --dangerously-skip-permissions --print --output-format json --no-session-persistence --max-budget-usd 2 "You are a token-saving helper for Codex... Run this focused UI verification exactly..."`
  - Result: Claude handled analysis-only review, an initial unit pass, and the slow focused UI pass; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-scenario-bound-bundle-tests-1779965000.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=153`, `failedTests=0`, `skippedTests=0`, `totalTestCount=153`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - same-scenario rerun filenames still ingest
    - generic and cross-scenario `.xcresult` filenames reject with the new scenario-mismatch failure
    - nested path-like result-bundle filenames continue to reject as invalid filenames
    - readiness schema v4 exposes the scenario-bound required field and rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command run by Claude: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-scenario-bound-bundle-ui-tests-1779965300.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary from Claude: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `iPhone 17`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `scenario-bound result-bundle filename` and `result-bundle filename for a different scenario` in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover filename binding, valid rerun suffixes, cross-scenario rejection, and schema v4 readiness text.
- `visible-ui-proof`: focused UI test proves the scenario-bound filename requirement appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This prevents a signed proof submission from borrowing a generic or different scenario's `.xcresult` filename.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Add iPhone device-model identifier shape enforcement so a signed physical proof submission cannot use generic device labels such as `Simulator`, `Mac`, or non-iPhone hardware families while still claiming real-iPhone evidence.

### Goal status

- Goal still open. Scenario-bound result-bundle filenames are enforced; physical proof still requires an unlocked real iPhone.

## 2026-05-28 02:01 PDT - May Goals physical proof direct-ingest signature enforcement v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.invalidAttachmentSignature`.
- Moved attachment signature enforcement into the shared `validate(...)` path used by direct `ingest(...)`, so unsigned or tampered submissions are rejected before schema/runbook lookup and before any runbook/index mutation.
- Kept preview's explicit unsigned-file message while direct ingest now has the same underlying signature requirement.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v3 and exposed `valid attachment signature` plus `invalid attachment signature` in the visible Settings contract.
- Updated direct-ingest tests so valid field-specific rejection fixtures are signed over their own invalid content, preserving simulator/artifact/privacy/digest/template validation coverage.
- Updated README, architecture notes, UI test assertions, and the May-goals progress ledger with the direct-ingest signature boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "We are continuing /Users/m3-max/Documents/GitHub/Bracketer maygoals.md. Next slice: close a direct-ingest signature bypass..."`
  - Result: analysis-only delegate confirmed the direct-ingest signature bypass and enumerated the tests needing signed fixtures; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-signature-ingest-tests-1779963600.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=152`, `failedTests=0`, `skippedTests=0`, `totalTestCount=152`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - direct ingest rejects unsigned submissions
    - direct ingest rejects post-signature tampering before normal validation can mask the signature failure
    - signed invalid fixtures still reach simulator, artifact, privacy, label, digest, placeholder, and duplicate-index validation branches
    - readiness schema v3 exposes the attachment-signature requirement and rejection rule
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-signature-ingest-ui-tests-1779963900.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `valid attachment signature` and `invalid attachment signature` in `settings.deviceProof.proofIngestor`, keeps `0 of 8 physical submissions accepted`, and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover the direct-ingest signature gate, tamper rejection, and signed invalid fixture behavior.
- `visible-ui-proof`: focused UI test proves the signature requirement appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- The signature is an integrity check over canonical JSON, not authentication of a person, device, or real-world capture.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Unlock the physical iPhone and rerun one real-device proof, or continue hardening the pre-physical intake path with destination/device label format checks and attachment/runbook binding.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 01:47 PDT - May Goals physical proof hashed-device SHA-256 enforcement v1

### What changed

- Hardened `BracketerPhysicalProofIngestor` so a non-empty `hashedDeviceIdentifier` must also be a SHA-256 hex digest before a physical proof submission can update a runbook or result-bundle index.
- Preserved the existing template-preview rejection order: raw signed templates still fail first on the primary `resultBundleSHA256` placeholder, while submissions with valid bundle/manifest digests now reject malformed hashed-device identifiers.
- Added unit coverage for a non-SHA-256 hashed-device identifier, keeping the valid physical-proof model path green.
- Updated README, architecture notes, and the May-goals progress ledger with the hashed-device digest requirement.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "We are in /Users/m3-max/Documents/GitHub/Bracketer continuing maygoals.md. Focus on physical proof ingest hardening..."`
  - Result: analysis-only delegate identified the hashed-device format gap and the next direct-ingest signature bypass; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-hashed-identifier-tests-1779962600.xcresult test`
  - Result: `** TEST SUCCEEDED **`; Swift Testing reported `151 tests in 1 suite passed`.
  - New executed coverage:
    - non-empty `hashedDeviceIdentifier` values that are not SHA-256 hex digests are rejected
    - raw signed templates still surface the result-bundle SHA-256 placeholder rejection first
    - valid SHA-256 bundle, manifest, and hashed-device digests continue through the normal model-ingest path

### Proof category

- `pure-model-proof`: unit tests cover the hashed-device digest gate and its interaction with template-preview validation order.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This only verifies the submission schema guard. It does not authenticate the hashed device identifier, prove a device identity, or ingest a real physical iPhone result bundle.

### Next slice

- Close the direct-ingest signature bypass so `ingest(...)`, not only `preview(...)`, rejects unsigned or tampered physical proof submissions.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 01:36 PDT - May Goals physical proof template placeholder rejection v1

### What changed

- Added `BracketerPhysicalProofIngestor.ValidationFailure.templatePlaceholderRetained(field:marker:)`.
- Added a template-placeholder scan that rejects retained `REPLACE_WITH_`, `REPLACE_AFTER_PHYSICAL_RUN`, and `<DEVICE-UDID>` tokens across submission strings, optional fields, artifact ids, and reviewer evidence before any physical proof can be recorded.
- Bumped `BracketerPhysicalProofIngestReadiness` to schema v2 and surfaced `unreplaced template placeholder` as a visible rejection rule in Settings > About Device Proof.
- Extended the focused Settings UI test so `settings.deviceProof.proofIngestor` proves the new rejection rule is visible after the relaunch path.
- Updated README, architecture notes, and the May-goals progress ledger with the new anti-spoofing boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "In /Users/m3-max/Documents/GitHub/Bracketer, read maygoals.md, .codex-maygoals-progress.md, Bracketer/BracketerPhysicalProofIngestor.swift... Recommend exactly one next feasible slice..."`
  - Result: analysis-only delegate identified the retained-template-placeholder spoof path; no files were modified by Claude.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-template-placeholder-tests-1779961900.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=151`, `failedTests=0`, `skippedTests=0`, `totalTestCount=151`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - signed template-derived submissions with valid digests/device labels but retained `REPLACE_AFTER_PHYSICAL_RUN` reviewer evidence or a retained `<DEVICE-UDID>` destination are rejected before ingest
    - preview rejects the same signed spoof submission without mutating runbooks, result-bundle indexes, or physical proof counts
    - a fully replaced template-derived submission still ingests through the normal path
    - readiness schema v2 exposes `unreplaced template placeholder`
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-template-placeholder-ui-tests-1779961400.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `unreplaced template placeholder` inside `settings.deviceProof.proofIngestor` and still does not claim `Physical proof captured`.

### Proof category

- `pure-model-proof`: unit tests cover direct ingest rejection, preview rejection, valid replacement acceptance, and schema v2 readiness text.
- `visible-ui-proof`: focused UI test proves the rejection rule appears in the Settings > About physical-proof contract after relaunch.
- `blocked-proof`: physical iPhone proof remains blocked by the locked connected device; simulator evidence still does not count as physical proof.

### Current proof boundary

- This slice prevents a signed-but-still-template file from being accepted as physical proof.
- The physical accepted count remains `0 of 8`; no real iPhone `.xcresult` or capture artifact was ingested.

### Next slice

- Unlock the physical iPhone and rerun one real-device proof, or continue hardening the pre-physical intake path with more anti-spoofing and review-surface guardrails.

### Goal status

- Goal still open. Verified guardrail complete. Physical proof remains blocked by locked device.

## 2026-05-28 01:19 PDT - May Goals physical proof submission preview surface v1

### What changed

- Added `BracketerPhysicalProofSubmissionDocument`, a `FileDocument` wrapper for physical proof submission JSON templates and signed preview files.
- Extended `BracketerPhysicalProofSubmission` with a deterministic canonical JSON SHA-256 attachment signature, plus `template(for:capturedAt:)`, `signed()`, and signature-status helpers.
- Added `BracketerPhysicalProofIngestPreview`, a preview-only model that checks signature integrity, runs the same ingestion validation path, and reports accepted/rejected status without mutating the runbook catalog, result-bundle index, or physical capture matrix.
- Surfaced the preview layer in Settings > About Device Proof:
  - `settings.deviceProof.proofIngestor.exportTemplate` shares a template JSON file for a selected physical runbook.
  - `settings.deviceProof.proofIngestor.importPreview` opens a file importer and reports a preview-only status such as `0 of 8 physical submissions accepted remains unchanged`.
- Added `PreviewBracketerPhysicalProofSubmissionIntent` and `BracketerPhysicalProofPreviewFileProvider` so Shortcuts can parse the same file and return a preview-only dialog.
- Wired README, architecture notes, and the may-goals progress ledger to distinguish preview files from physical proof.

### Verification

- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-preview-tests-1779959800.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=150`, `failedTests=0`, `skippedTests=0`, `totalTestCount=150`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - template documents contain the preview boundary and placeholder replacement requirements
    - placeholders, unsigned submissions, simulator destinations, and private-data markers are rejected in preview
    - signed valid submissions can preview as accepted without changing the original runbook/index/matrix values
    - unreadable and unsupported files fail through typed document errors
    - the App Intent file provider returns a preview-only dialog
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-preview-ui-tests-1779960000.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `settings.deviceProof.proofIngestor.exportTemplate` and `settings.deviceProof.proofIngestor.importPreview`, includes `Physical Proof Submission Template`, `platform=iOS,id=<DEVICE-UDID>`, `physical-device-proof preview only`, and `0 of 8 physical submissions accepted remains unchanged`, and still does not claim `Physical proof captured`.
- Physical iPhone attempt:
  - `devicectl list devices` showed `Physical iPhone` available and paired.
  - `xcodebuild -showdestinations` exposed `platform:iOS,id=00008150-00027C3E0108401C`.
  - Code signing was available through the Apple Development identity and automatic signing team `UZD4BS94DT`.
  - Focused physical-device test preflight blocked with `"Unlock Physical iPhone to Continue"`.
  - `/tmp/bracketer-physical-readiness-device-tests-1779959100.xcresult` is incomplete/corrupt and cannot be read by `xcresulttool`; no physical proof counted.

### Proof category

- `pure-model-proof`: unit tests cover canonical signature behavior, document parsing/export, preview acceptance/rejection, non-mutating preview semantics, typed document errors, and App Intent preview output.
- `visible-ui-proof`: focused UI test proves the Settings > About template/export and import-preview rows render with preview-only language.
- `blocked-proof`: the real iPhone destination, signing identity, and team are visible, but the locked device prevents Xcode from launching tests.

### Current proof boundary

- The attachment signature is an integrity check over canonical JSON, not authentication of a person, device, or capture.
- Previewing a submission does not store a recorded proof, does not update a runbook, does not update the result-bundle index, and does not flip a physical capture matrix scenario.
- Simulator tests, template documents, preview files, and locked-device preflight are not physical iPhone proof; the physical accepted count remains `0 of 8`.

### Next slice

- Unlock the physical iPhone and rerun a focused real-device proof, or keep advancing simulator/pure-model guardrails that make the eventual physical proof path harder to misreport.

### Goal status

- Goal still open. Verified wave complete. Physical proof remains blocked by locked device.

## 2026-05-28 00:56 PDT - May Goals physical proof ingest readiness Settings surface v1

### What changed

- Added `BracketerPhysicalProofIngestReadiness`, a Codable projection of the physical proof ingest contract for the Settings > About Device Proof card.
- Surfaced the readiness model in `ModernSettingsPanel` at `settings.deviceProof.proofIngestor`, beside the existing physical capture matrix, verification runbook, capture runbook catalog, and result-bundle index rows.
- The row truthfully reports `Physical Proof Ingestor`, `0 of 8 physical submissions accepted` by default, and `Real iPhone artifacts required`; its accessibility value enumerates the required submission fields (scenario id, physical `platform=iOS,id=<DEVICE-UDID>` destination, result-bundle filename and SHA-256, device model, hashed device identifier, iOS build, all expected artifact ids, reviewer evidence), the rejection rules (simulator destination, missing artifacts, missing device labels, missing hashed device identifier, invalid SHA-256, Photos local identifiers, raw image bytes, precise coordinates), and the no-Photos-identifier/no-raw-image-byte/no-precise-coordinate privacy boundary.
- Wired README and ARCHITECTURE to describe the new readiness row and its no-physical-proof boundary alongside the existing ingestor model.

### Verification

- App-hosted unit tests on throwaway simulator:
  - Result bundle: `/tmp/bracketer-physical-proof-readiness-tests-1779958800.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=145`, `failedTests=0`, `skippedTests=0`, `totalTestCount=145`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New executed coverage:
    - readiness derives accepted/required counts from `BracketerPhysicalResultBundleIndex` and the runbook catalog
    - default summary reads `Physical Proof Ingestor | 0 of 8 physical submissions accepted | Real iPhone artifacts required`
    - accessibility value lists required submission fields including result-bundle SHA-256 and the privacy boundary excluding Photos identifiers, raw image bytes, and coordinates
    - Codable round trip preserves schema, counts, required fields, rejection rules, and privacy boundary text
- Focused UI test (`testSimulatedBracketCaptureCompletesAndOpensReview`):
  - Result bundle: `/tmp/bracketer-physical-proof-readiness-ui-tests-1779959000.xcresult`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, iOS `26.4.1`.
  - New visible coverage: restored Settings > About exposes `settings.deviceProof.proofIngestor` with `Physical Proof Ingestor`, `0 of 8 physical submissions accepted`, `Real iPhone artifacts required`, result-bundle SHA-256 requirements, simulator-destination rejection, and no `Physical proof captured` claim.

### Proof category

- `pure-model-proof`: Swift tests cover the readiness factory, default text, accessibility text, and Codable shape.
- `local-sdk-proof`: the readiness row builds with the rest of the app target via the existing simulator compile path.
- `visible-ui-proof`: focused UI test proves the restored Settings > About path exposes the physical proof ingestor readiness row without claiming physical iPhone proof.

### Current proof boundary

- The readiness row is a human-visible contract, not physical-device proof. The accepted count remains zero until `BracketerPhysicalProofIngestor` records a real-iPhone submission for a scenario.
- No Photos identifiers, raw image bytes, decoded RAW data, thumbnail pixels, final rendered output bytes, precise coordinates, or hashed device identifiers are stored in the readiness model itself; only the contract text it discloses.

### Next slice

- Connect the ingestor to a signed physical-device attachment/export surface, or satisfy one matrix scenario with actual iPhone evidence for Photos resources, real thumbnails, Files/Shortcuts/Spotlight, live Foundation Models output, final render bytes, side-by-side pixel comparison, or physical lens/EXIF/location.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 00:52 PDT - May Goals physical proof ingestor v1

### What changed

- Added `BracketerPhysicalProofSubmission`, a structured intake model for future real-device lab proof.
- Added `BracketerPhysicalProofIngestor`, which validates scenario id, physical `platform=iOS,id=<DEVICE-UDID>` destination strings, result-bundle SHA-256, device model, hashed device identifier, iOS build, required scenario artifacts, reviewer evidence, and privacy markers before accepting a submission.
- Extended `BracketerPhysicalCaptureRunbook.RecordedProof` with optional result-bundle SHA-256 storage.
- Added replacement helpers so a duplicate submission for the same physical scenario replaces the old runbook/index entry instead of inflating coverage.
- Kept the ingestor pure-model only; there is still no physical-device proof unless a real iPhone run supplies real artifacts.

### Verification

- XcodeBuildMCP simulator compile:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `status=SUCCEEDED`; existing unrelated `OrientationManager.swift` main-actor warnings remain.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-proof-ingestor-tests-1779958200.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary for `/tmp/bracketer-physical-proof-ingestor-tests-1779958200.xcresult`: `result=Passed`, `passedTests=144`, `failedTests=0`, `skippedTests=0`, `totalTestCount=144`, device `BracketerUITest-230901`, simulator `3D6A76E2-86BE-4F15-A384-A920B56478EB`, iOS `26.4.1`.

### Proof category

- `pure-model-proof`: Swift tests cover valid proof ingestion, simulator rejection, missing-artifact rejection, missing device metadata rejection, invalid digest rejection, privacy marker rejection, Codable preservation, and duplicate scenario replacement.
- `local-sdk-proof`: XcodeBuildMCP compile proves the new synchronized Swift source builds in the app target.

### Current proof boundary

- This is not physical-device proof. The tests use synthetic submissions to prove validation logic.
- The app still needs a real iPhone lab run before any actual scenario should be considered physically proven.
- The ingestor now provides the deterministic path for that future run to become recorded proof without storing Photos identifiers, raw image bytes, thumbnail pixels, decoded RAW data, final rendered output bytes, precise coordinates, or hashed device identifiers in `RecordedProof`.

### Next slice

- Connect the ingestor to a signed physical-device attachment/export surface, or satisfy one matrix scenario with actual iPhone evidence for Photos resources, real thumbnails, Files/Shortcuts/Spotlight, live Foundation Models output, final render bytes, side-by-side pixel comparison, or physical lens/EXIF/location.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 00:40 PDT - May Goals physical capture runbooks and result-bundle index v1

### What changed

- Added `BracketerPhysicalCaptureRunbook` with 8 per-scenario real-iPhone lab handoffs generated from the physical capture matrix.
- Added `BracketerPhysicalCaptureRunbook.RecordedProof`, limited to device model, iOS build, capture time, result bundle filename, optional manifest hash, and notes.
- Added `BracketerPhysicalCaptureRunbookCatalog` for the Settings > About row `settings.deviceProof.captureRunbooks`.
- Added `BracketerPhysicalResultBundleIndex` for the Settings > About row `settings.deviceProof.resultBundleIndex`.
- Added `BracketerPhysicalCaptureMatrix.applying(runbooks:)`, which flips scenario status only when a matching runbook has recorded proof.
- Documented per-scenario result-bundle paths at `build/physical-lab/Bracketer-<scenario-id>-physical.xcresult` and kept simulator evidence separate from physical proof.

### Verification

- Claude offloads:
  - Used `claude --dangerously-skip-permissions` for an analysis-only runbook audit and a compact per-scenario runbook drafting pass.
  - Result: no files modified by Claude; the audit drove additional schema, proof-id, factory, per-proof accessibility, and duplicate-index unit assertions.
- Physical device visibility probe:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun xctrace list devices`
  - Result: host Mac visible; `M5`, `Physical iPhone`, and Apple Watch were offline, so no physical-device proof was collected.
- App-hosted unit tests on throwaway simulator:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-runbook-tightened-tests-1779957400.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary for `/tmp/bracketer-physical-runbook-tightened-tests-1779957400.xcresult`: `result=Passed`, `passedTests=139`, `failedTests=0`, `skippedTests=0`, `totalTestCount=139`, device `BracketerUITest-230901`, simulator `3D6A76E2-86BE-4F15-A384-A920B56478EB`, iOS `26.4.1`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-physical-runbook-ui-tests-1779957200.xcresult test`
  - Result: `** TEST SUCCEEDED **`.
  - `xcresulttool` summary for `/tmp/bracketer-physical-runbook-ui-tests-1779957200.xcresult`: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`, device `BracketerUITest-230901`, simulator `3D6A76E2-86BE-4F15-A384-A920B56478EB`, iOS `26.4.1`.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `** BUILD SUCCEEDED **`; App Intents metadata extraction wrote `Metadata.appintents`.
- `git diff --check`
  - Result: passed after physical capture runbook/index code, tests, docs, progress, and ledger updates.

### Proof category

- `lab-handoff-proof`: each physical matrix scenario now has a stable runbook, expected artifact list, linked proof ids, and reserved `.xcresult` path.
- `indexing-proof`: result-bundle entries count unique scenario ids and keep duplicate reruns from inflating scenario coverage.
- `visible-ui-proof`: the restored Settings > About UI exposes the runbook catalog and result-bundle index rows on simulator.
- `privacy-boundary-proof`: recorded proofs and result-bundle index entries store filenames, hashes, notes, device labels, and timestamps only.

### Current proof boundary

- No real iPhone was connected; every physical scenario still reports uncaptured.
- The result-bundle index starts at `0 of 8 scenario result bundles indexed`.
- Per-scenario runbooks are lab handoffs, not camera/Photos/Files/Shortcuts/Spotlight/Foundation Models proof.
- The model stores no Photos identifiers, raw image bytes, thumbnail pixels, decoded RAW data, final rendered output bytes, or precise coordinates.

### Next slice

- Move toward collecting one real physical-matrix scenario or adding signed physical-device attachment automation for Photos resources, real thumbnails, Files/Shortcuts/Spotlight round trips, live Foundation Models output, final render bytes, side-by-side pixel comparison, or physical lens/EXIF evidence.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-28 00:24 PDT - May Goals verification runbook and benchmark commands v1

### What changed

- Added `BracketerVerificationRunbook`, a Codable evidence contract for simulator/unit/UI/physical-device verification commands.
- The runbook now defines stable result bundle paths for:
  - `build/Bracketer-simulator-full.xcresult`
  - `build/Bracketer-unit.xcresult`
  - `build/Bracketer-simulated-capture-ui.xcresult`
  - `build/Bracketer-physical-device-lab.xcresult`
- Added canonical `xcresulttool get test-results summary` and `xcresulttool get test-results metrics` extractor commands.
- Added benchmark contracts for app launch duration, timed diagnostics, and dropped-frame diagnostics while explicitly leaving dropped-frame proof unclaimed until physical-device Instruments or XCTest attachments exist.
- Settings > About now surfaces the runbook at `settings.deviceProof.verificationRunbook` and benchmark commands at `settings.deviceProof.benchmarkCommands`.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the result-bundle, benchmark, and real-iPhone evidence-container boundaries.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are assisting Codex in /Users/m3-max/Documents/GitHub/Bracketer..."`
  - Result: analysis-only sidecar recommended a larger per-scenario physical capture runbook/indexing layer; no files were edited by Claude.
- Device visibility probe:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun xctrace list devices`
  - Result: `M5`, `Physical iPhone`, and Apple Watch were listed under `Devices Offline`; no physical-device proof was collected.
- XcodeBuildMCP attempted unit test:
  - Result: failed before test execution with CoreSimulator `Invalid connectionUUID specified` while preparing `iPhone 17 Pro`; treated as infrastructure failure.
- Direct `iPhone 17 Pro` unit rerun:
  - Result: interrupted after Xcode hung waiting for simulator test workers to materialize; not counted as product proof.
- Target-level Swift Testing run on `BracketerUITest-230901` (`3D6A76E2-86BE-4F15-A384-A920B56478EB`):
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-verification-runbook-tests-1779956200.xcresult test`
  - Result: `** TEST SUCCEEDED **`; `xcresulttool` summary reported `result=Passed`, `passedTests=137`, `failedTests=0`, `skippedTests=0`, `totalTestCount=137`.
  - New executed coverage: command ids, result-bundle paths, benchmark extractor commands, physical-device signing boundary, no-physical-proof wording, and Codable round trip.
- Focused UI test on `BracketerUITest-230901`:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=3D6A76E2-86BE-4F15-A384-A920B56478EB' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-verification-runbook-ui-tests-1779956400.xcresult test`
  - Result: `** TEST SUCCEEDED **`; `xcresulttool` summary reported `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
  - New executed coverage: `settings.deviceProof.verificationRunbook` and `settings.deviceProof.benchmarkCommands`.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `** BUILD SUCCEEDED **`; App Intents metadata extraction wrote `Metadata.appintents`.
- `git diff --check`
  - Result: passed.

### Proof category

- `pure-model-proof`: unit tests prove the runbook/result-bundle/benchmark contracts and physical-proof boundaries.
- `visible-ui-proof`: focused UI test proves the runbook and benchmark-command rows are exposed in the restored Settings > About path.
- `documentation-proof`: README, architecture docs, progress tracker, and ledger describe the commands and evidence boundaries.

### Current proof boundary

- No physical-device proof was collected; available iPhones were offline in `xctrace list devices`.
- Simulator result bundles and `xcresulttool` metrics are evidence contracts, not real camera, Photos, Files, Shortcuts, Spotlight, Foundation Models, or dropped-frame proof.
- The next useful escalation is a per-scenario physical capture runbook/index or a connected real-iPhone run against the physical capture matrix.

### Goal status

- Goal still open. Verification runbook slice complete; May Goals remain far from complete.

## 2026-05-27 23:59 PDT - May Goals physical capture matrix v1

### What changed

- Added `BracketerPhysicalCaptureMatrix`, a Codable real-device lab-plan model that stays separate from physical proof itself.
- The matrix defines 8 physical scenarios:
  - interior-window dynamic range
  - lens and ProRAW resource sweep
  - handheld motion recovery
  - Photos permission and location-policy sweep
  - storage-pressure partial save
  - live Foundation Models capture coach
  - Files, Shortcuts, and Spotlight round trip
  - multi-device OS regression
- Every default scenario starts as `requiresPhysicalDevice`, links to canonical `BracketerPhysicalDeviceProofChecklist` proof ids, and keeps `provenScenarioCount` at `0`.
- Settings > About now renders the matrix at `settings.deviceProof.captureMatrix` with `0 of 8 scenario proofs captured`, `Real iPhone required`, and `Simulator coverage does not satisfy capture matrix`.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the matrix boundary and next physical-proof target.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are a sidecar reviewer..."`
  - Result: analysis-only sidecar identified stale docs/progress/ledger sections, proof-link integrity risk, no-proof wording assertions, and verification commands; no files were modified by Claude.
- XcodeBuildMCP simulator build:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: passed with `status=SUCCEEDED`; existing unrelated `OrientationManager.swift` main-actor warnings remain.
- App-hosted unit tests:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -skipMacroValidation -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -only-testing:BracketerTests -skip-testing:BracketerUITests -resultBundlePath /tmp/bracketer-physical-capture-matrix-tests-1779950880.xcresult test`
  - Result: `** TEST SUCCEEDED **`; `xcresulttool` summary: `result=Passed`, `passedTests=136`, `failedTests=0`, `skippedTests=0`, `totalTestCount=136`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -skipMacroValidation -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -collect-test-diagnostics never COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/DerivedData/Bracketer-9396c4e8762c -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -resultBundlePath /tmp/bracketer-physical-capture-matrix-ui-tests-1779951032.xcresult test`
  - Result: `** TEST SUCCEEDED **`; `xcresulttool` summary: `result=Passed`, `passedTests=1`, `failedTests=0`, `skippedTests=0`, `totalTestCount=1`.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `** BUILD SUCCEEDED **`; App Intents metadata extraction wrote `Metadata.appintents`.

### Proof category

- `pure-model-proof`: unit tests prove scenario ids, proof-id links, privacy boundaries, Codable round trip, and `provenScenarioCount`.
- `visible-ui-proof`: focused UI test proves `settings.deviceProof.captureMatrix` is visible from restored Settings > About.
- `honesty-boundary-proof`: model, UI, docs, and tests keep `0 of 8` and never convert simulator coverage into physical iPhone proof.

### Current proof boundary

- This slice creates the physical capture matrix plan, not any completed physical capture scenario.
- No real iPhone Photos resource fetch, Foundation Models run, Files/Shortcuts round trip, Spotlight continuation, lens/EXIF matrix, storage-pressure run, final render bytes, or real pixel-comparison proof was collected.

### Next slice

- Use a real iPhone target to complete one matrix scenario, preferably Photos resource proof or live Foundation Models output, while recording device model/iOS build and preserving privacy boundaries.

### Goal status

- Goal still open. Verified wave partial. Next wave requires physical-device evidence.

## 2026-05-27 23:07 PDT - May Goals physical-device proof checklist v1

### What changed

- Added `BracketerPhysicalDeviceProofChecklist`, a Codable proof-gap model that records simulator/project/runtime evidence separately from required real-iPhone evidence.
- The checklist covers:
  - live Foundation Models output
  - Photos resource fetches
  - Photos-backed thumbnails
  - final rendered output bytes
  - real Photos side-by-side pixel comparison
  - image-bundle byte export
  - lens/EXIF/ProRAW proof
  - location permission policy
  - Files/Shortcuts round trip
  - Spotlight handoff continuation
- Settings > About now renders a Device Proof card with:
  - `settings.deviceProof.summary`
  - `settings.deviceProof.item.<proof-id>`
  - `settings.deviceProof.matrix`
- The visible summary intentionally reports `0 physical proofs captured` and states that simulator evidence is not physical iPhone proof.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the proof-checklist boundary and the remaining real-device proof gaps.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions -p "You are a delegated coding analyst..."`
  - Result: analysis-only delegate returned insertion-point and identifier recommendations; no files were modified by Claude.
- XcodeBuildMCP simulator build:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: passed with `status=SUCCEEDED`; existing unrelated `OrientationManager.swift` main-actor warnings remain.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`; `** BUILD SUCCEEDED **`; App Intents metadata extraction wrote `Metadata.appintents`.
- XcodeBuildMCP app-hosted unit tests:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -resultBundlePath /tmp/bracketer-device-proof-checklist-tests-1779947136.xcresult test`
  - Result: `status=SUCCEEDED`; Swift Testing reported `135` passed, `0` failed.
  - New executed coverage:
    - checklist ids and required physical-evidence rows are stable
    - simulator coverage and physical proof counts remain separate
    - Codable round trip preserves the checklist
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -collect-test-diagnostics never COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -derivedDataPath /Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/DerivedData/Bracketer-9396c4e8762c -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -resultBundlePath /tmp/bracketer-device-proof-checklist-ui-tests-1779947932.xcresult test`
  - Result: `** TEST SUCCEEDED **`; selected UI test passed.
- `xcresulttool` summary for `/tmp/bracketer-device-proof-checklist-ui-tests-1779947932.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after physical-device proof checklist code, tests, docs, progress, and ledger updates.

### Proof category

- `proof-ledger-proof`: unit tests prove the checklist records required physical evidence while keeping the physical proof count at zero.
- `visible-ui-proof`: focused UI test proves the Device Proof summary, live Foundation Models proof row, and required device matrix are visible from restored Settings > About.
- `honesty-boundary-proof`: docs and UI state explicitly say simulator evidence is not physical iPhone proof.

### Current proof boundary

- This slice creates the proof checklist, not the physical proofs themselves.
- No real iPhone Foundation Models output, Photos resource fetch, Photos thumbnail, Files/Shortcuts round trip, Spotlight continuation, EXIF/ProRAW matrix, final render bytes, or real pixel-comparison proof was collected.

### Next slice

- Move from checklist to actual real-iPhone evidence: physical Photos resource proof, live Foundation Models output, physical Files proof, real output bytes, real Photos-backed pixel comparison, image-bundle byte export, Spotlight continuation, or physical lens/EXIF proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 22:35 PDT - May Goals project-library archive workspace v1

### What changed

- Added `BracketProjectLibraryWorkspace`, a Codable route-level archive workspace projection over `BracketProjectLibrarySnapshot`.
- Workspace summaries include:
  - active `BracketProjectLibrarySearchRoute`
  - current/latest project markers
  - per-project titles, subtitles, privacy summaries, preview-placeholder summaries, and export-readiness counts
  - explicit metadata-only archive boundary
  - result-limit/truncation disclosure
- Settings > About now exposes an Archive Workspace row at `settings.projects.library.workspaceButton`.
- The new workspace sheet renders at `settings.projects.library.workspace` with:
  - `settings.projects.library.workspace.summary`
  - `settings.projects.library.workspace.result.<index>`
  - `settings.projects.library.workspace.result.<index>.exportBundle.shareButton`
- The workspace reuses the current export privacy, filename, and generated-content controls for per-project archive ShareLinks.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the dedicated archive-workspace route and metadata-only proof boundary.

### Verification

- XcodeBuildMCP simulator build:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: passed with `status=SUCCEEDED`; existing unrelated `OrientationManager.swift` main-actor warnings remain.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction wrote `Metadata.appintents`.
- XcodeBuildMCP app-hosted unit tests:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-project-library-workspace-tests-1779946123.xcresult test`
  - Result: `status=SUCCEEDED`; Swift Testing reported `134` passed, `0` failed.
  - New executed coverage:
    - workspace route/project summaries and current/latest markers
    - metadata-only archive workspace boundary
    - explicit truncation disclosure through `Showing n of m`
- Focused UI test:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-project-library-workspace-ui-tests-1779946201.xcresult test`
  - Result: XcodeBuildMCP wrapper timed out at 120s, but the underlying `xcodebuild` completed successfully.
- `xcresulttool` summary for `/tmp/bracketer-project-library-workspace-ui-tests-1779946201.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after project-library archive workspace code, tests, docs, progress, and ledger updates.

### Proof category

- `workspace-model-proof`: unit tests prove route summaries, project summaries, current/latest markers, truncation, and privacy boundary.
- `visible-ui-proof`: focused UI test proves the archive workspace opens from Settings and exposes route summary, a result row, and per-project archive export.
- `privacy-boundary-proof`: workspace rows disclose that they are metadata-only and do not contain Photos identifiers, raw photo bytes, thumbnails, precise coordinates, final rendered output, or filesystem packages.

### Current proof boundary

- This is a Settings-hosted archive workspace, not a final standalone Library tab/window.
- It still exports metadata archives only; real Photos-backed thumbnails, final rendered image bytes, physical Files proof, and physical-device archive proof remain incomplete.

### Next slice

- Move toward physical-device Photos/resource proof, real Photos-backed contact sheets, physical Files document proof, real final-output byte rendering, real Photos-backed side-by-side pixel comparison, image-bundle byte export, Spotlight saved-search continuation, or physical lens/EXIF proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 22:15 PDT - May Goals export-time generated-content controls v1

### What changed

- Added `BracketProjectExportGeneratedContentPolicy` with include/omit cases.
- `BracketProject.exportCopy(...)`, `BracketProjectExportBundle.make(...)`, and `FileBracketProjectStore.exportBundle(...)` now accept the generated-content export policy.
- Omit export removes generated sidecar notes, generated narrative tags, and `noteSource` provenance from exported project/sidecar payloads while preserving user-curated project `acceptedTags`.
- Archive text, bundle summaries, accessibility values, and privacy reports now disclose the generated-content export policy.
- `BracketProjectExportPreset` now selects generated-content behavior:
  - Client Handoff and Privacy Audit omit generated content.
  - Review Archive and Recovery Archive include generated content.
- Settings > About project export controls now include `settings.projects.exportGeneratedContent`, and that value feeds latest-project ShareLink, Files export, and per-row ShareLink bundles.
- Latest and selected project export App Intents now expose a Generated Content parameter and default to omit generated content.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the export-time generated-content boundary.

### Verification

- Claude offload:
  - Command: `claude --dangerously-skip-permissions --print --effort high --output-format text`
  - Result: partial patch produced in the target files; no final stdout was emitted, and the process was terminated after sitting on MCP helper processes with no visible `xcodebuild` child. The partial patch was audited, tightened, and verified manually.
- XcodeBuildMCP simulator build:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: passed with `status=SUCCEEDED`; existing unrelated `OrientationManager.swift` main-actor warnings remain.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction wrote `Metadata.appintents`.
- XcodeBuildMCP app-hosted unit tests:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-export-generated-content-tests-1779944955.xcresult test`
  - Result: `status=SUCCEEDED`; Swift Testing reported `134` passed, `0` failed.
  - New executed coverage:
    - model default includes generated content unless the omit policy is explicit
    - omit policy removes generated sidecar note/tag payloads and `noteSource` provenance
    - omit policy preserves user-curated accepted tags
    - archive text and privacy report disclose generated-content policy
    - export presets and latest-project export App Intent default generated-content behavior are tested
- Focused UI test:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-export-generated-content-ui-tests-1779945041.xcresult test`
  - Result: XcodeBuildMCP wrapper timed out at 120s, but the underlying `xcodebuild` completed successfully.
- `xcresulttool` summary for `/tmp/bracketer-export-generated-content-ui-tests-1779945041.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after export-time generated-content code, tests, docs, progress, and ledger updates.

### Proof category

- `export-policy-proof`: unit tests prove include/omit behavior, privacy disclosure, and preset defaults.
- `visible-ui-proof`: focused UI test proves the restored Settings project library exposes `settings.projects.exportGeneratedContent` with the Client Handoff omit default.
- `shortcuts-surface-proof`: latest-project and selected-project App Intent providers now accept generated-content policy parameters.
- `privacy-boundary-proof`: generated content can be omitted per export without losing user-curated accepted tags.

### Current proof boundary

- This is simulator proof with deterministic generated note fixtures.
- No live Foundation Models generated content was exported from a physical device.
- Physical Files/Shortcuts execution remains separate from App Intent provider and simulator UI proof.

### Next slice

- Move toward physical-device Photos/resource proof, real Photos-backed image payloads, physical Files document proof, real final-output byte rendering, real Photos-backed side-by-side pixel comparison, image-bundle byte export, or physical lens/EXIF proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 21:46 PDT - May Goals generated-content privacy controls v1

### What changed

- Added a persisted generated-note sidecar storage preference:
  - `SettingsStore.storesGeneratedProjectNotes`
  - Default: off.
  - Reset behavior: `-ui-testing-reset-settings` returns it to off.
- Settings > About > Privacy & Trust now exposes the preference through `settings.privacyTrust.generatedNotesStorage`.
- `BracketerPrivacyTrustSnapshot` moved to schema v2 and includes the generated-note storage preference in its generated-content policy.
- `ModernContentView` mirrors the preference into `CameraController` before project persistence.
- `CameraController.recordLatestBracketProject(...)` now uses the preference when creating a project sidecar:
  - off: omit generated notes and generated narrative tags.
  - on: store a deterministic generated note built only from `BracketManifest` and `BracketReviewSequence`.
- `BracketManifestSidecar.make(... storesGeneratedNote:)` is now the pure sidecar-level enforcement point for generated-note omission.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the generated-note storage control and proof boundary.

### Verification

- XcodeBuildMCP simulator build:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: passed with `status=SUCCEEDED`; no warnings/errors reported by XcodeBuildMCP.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- First app-hosted unit run:
  - Result: `130` passed, `1` failed because the omission test rejected `deterministicFallback` even though that string legitimately appeared in the applied recipe snapshot. Tightened the assertion to generated-note payload omission and reran.
- XcodeBuildMCP app-hosted unit rerun:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-generated-notes-privacy-tests-1779943000.xcresult test`
  - Result: `status=SUCCEEDED`; Swift Testing reported `131` passed, `0` failed.
  - New executed coverage:
    - settings persistence/reset for the generated-note storage preference
    - sidecar omission of generated notes/source/tags when storage is off
    - camera project persistence omits generated notes when off and stores a deterministic source-disclosed note when on
    - trust snapshot schema v2 reports generated-note storage state
- Focused UI test:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-generated-notes-privacy-ui-tests-1779943120.xcresult test`
  - Result: XcodeBuildMCP wrapper timed out at 120s, but the underlying `xcodebuild` completed successfully.
- `xcresulttool` summary for `/tmp/bracketer-generated-notes-privacy-ui-tests-1779943120.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after generated-content privacy controls code, tests, docs, progress, and ledger updates.

### Proof category

- `preference-persistence-proof`: generated-note storage is a real `UserDefaults`-backed setting.
- `behavior-proof`: project sidecar content changes according to the preference.
- `visible-ui-proof`: restored Settings > About exposes the generated-note storage toggle and generated-content row.
- `privacy-boundary-proof`: stored notes are deterministic manifest/review-only text, and the default path omits generated notes and generated narrative tags.

### Current proof boundary

- This is simulator proof with deterministic review text.
- No live Foundation Models generated note was stored from a physical device.
- Physical-device privacy proof remains incomplete.

### Next slice

- Move toward physical-device Photos/resource proof, real Photos-backed image payloads, physical Files document proof, real final-output byte rendering, or physical lens/EXIF proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 21:18 PDT - May Goals Privacy & Trust Center v1

### What changed

- Added `BracketerPrivacyTrustSnapshot`, a Codable project/library privacy summary that captures local computation, Photos identifier policy, location policy, Apple Intelligence runtime provenance, generated-note provenance, diagnostics export policy, export redaction, and the no-pixel/no-coordinate boundary.
- Settings > About now renders a visible Privacy & Trust card before the project library.
- New UI hooks:
  - `settings.privacyTrust.summary`
  - `settings.privacyTrust.row.localComputation`
  - `settings.privacyTrust.row.photosAccess`
  - `settings.privacyTrust.row.locationPolicy`
  - `settings.privacyTrust.row.appleIntelligence`
  - `settings.privacyTrust.row.generatedContent`
  - `settings.privacyTrust.row.diagnostics`
  - `settings.privacyTrust.row.exportBoundary`
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the trust-center model, UI contract, and simulator proof.

### Verification

- XcodeBuildMCP simulator build:
  - Command equivalent: `xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: passed with `status=SUCCEEDED`; existing unrelated `OrientationManager.swift` main-actor warnings remain.
- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-privacy-trust-center-tests-1779942000.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `129` tests passed.
  - New executed coverage:
    - `privacyTrustCenterSnapshotSummarizesLocalBoundaries`
    - stable trust row ids
    - Codable round trip for the snapshot
- `xcresulttool` summary for `/tmp/bracketer-privacy-trust-center-tests-1779942000.xcresult`:
  - `result=Passed`
  - `passedTests=129`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=129`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-privacy-trust-center-ui-tests-1779942120.xcresult test`
  - Result: `STATUS=0`; XCTest reported `1` selected UI test passed after the XcodeBuildMCP wrapper timed out while the underlying `xcodebuild` continued to completion.
  - New executed coverage:
    - restored Settings > About exposes `settings.privacyTrust.summary`
    - trust summary accessibility includes `Privacy Trust Center`, `Local Computation`, `Location Policy`, and `No precise coordinates`
    - `settings.privacyTrust.row.locationPolicy` includes `Simulated Location Not Requested` and `No precise coordinates`
    - project-library rows remain visible after the new card insertion
- `xcresulttool` summary for `/tmp/bracketer-privacy-trust-center-ui-tests-1779942120.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after trust-center code, tests, docs, progress, and ledger updates.

### Proof category

- `model-contract-proof`: the trust center is a Codable snapshot built from saved project/library state and runtime provenance, not a UI-only copy block.
- `visible-ui-proof`: focused UI test proves the restored Settings > About path exposes the trust summary and location-policy row.
- `privacy-boundary-proof`: the snapshot states Photos identifier redaction, generated-note provenance, diagnostics/export policy, and no raw pixels or precise coordinates.

### Current proof boundary

- This is simulator proof using a restored simulated project.
- No physical-device Photos permission, physical location-metadata, or real Files export proof was collected for this slice.
- Generated-feature privacy controls were disclosure-only in this slice; the later generated-content privacy-controls slice adds the first user-editable storage toggle.

### Next slice

- Move toward physical-device Photos/location/export proof, generated-note/tag export controls, real Photos-backed image payloads, physical Files document proof, real final-output byte rendering, or physical lens/EXIF proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 21:00 PDT - May Goals privacy-safe location policy library facets v1

### What changed

- Added `BracketManifest.CaptureLocationSnapshot`, a privacy-scoped capture-location policy summary with authorization state, project storage policy, Photos save policy, coordinate-storage flag, location-sample presence, and source.
- Simulated captures now persist `Simulated Location Not Requested`; Photos-backed capture manifests record whether a CoreLocation sample was attached to the Photos save request, without storing latitude, longitude, altitude, or coordinate strings in the project manifest.
- Added `BracketProjectLibraryLocationFacet`, which derives normalized location-policy ids from persisted capture-location snapshots and falls back to the legacy project privacy snapshot for older manifests.
- `BracketProjectLibrarySnapshot` and `BracketProjectLibrarySearchRoute` now compose text query, smart collection, selectable project facet, captured day, lens id, and location-policy id into one deterministic route.
- Settings > About now renders location-policy chips at `settings.projects.locationFacets` with per-policy identifiers such as `settings.projects.locationFacets.simulated-location-not-requested`.
- `QueryBracketProjectsIntent` now includes a Location Policy ID parameter, and `BracketProjectLibrarySearchProvider` passes it into the store-backed route.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the location-policy facet route contract and the no-precise-coordinate boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-location-facet-tests-1779940800.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - New executed coverage:
    - simulated manifests persist capture-location snapshots without precise coordinates
    - Photos-style fixtures persist the Photos-save-location-requested/project-redacted policy
    - location-policy facets derive normalized ids and counts from capture-location metadata
    - route composition preserves query plus smart-collection plus project-facet plus captured-day plus lens plus location-policy result IDs
    - App Intent search provider returns entities through the same location-aware route
- `xcresulttool` summary for `/tmp/bracketer-library-location-facet-tests-1779940800.xcresult`:
  - `result=Passed`
  - `passedTests=128`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=128`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-location-facet-ui-tests-1779940920.xcresult test`
  - Result: `STATUS=0`; XCTest reported 1 selected UI test passed.
  - New executed coverage:
    - restored Settings project library exposes `settings.projects.locationFacets`
    - location-policy row accessibility includes `Location Policy Facets`
    - location-policy row accessibility includes `Simulated Location Not Requested`
    - existing route row remains visible after location-row insertion
- `xcresulttool` summary for `/tmp/bracketer-library-location-facet-ui-tests-1779940920.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after privacy-safe location policy facet code, tests, docs, progress, and ledger updates.

### Proof category

- `route-composition-proof`: unit tests compose text search, smart collections, project facets, captured-day filters, lens filters, and location-policy filters through the same snapshot/route/provider path.
- `visible-ui-proof`: focused UI test proves the restored project library now exposes location-policy chips on simulator.
- `privacy-boundary-proof`: location facets derive from saved policy/sample-presence facts, without Photos identifiers, image bytes, thumbnails, semantic scene labels, or precise coordinates.

### Current proof boundary

- Location-policy facets are project metadata facts, not physical proof that a real Photos asset retained GPS metadata.
- Live device location availability is only proved by code/build; visible UI proof uses the simulated no-location policy.
- No dedicated Privacy settings section, physical-device location metadata proof, direct Shortcuts/Siri execution, or physical Files proof was collected for this slice.

### Next slice

- Move toward a dedicated privacy/trust center, physical Photos resource proof, real Photos-backed contact sheets, physical Files document proof, real Photos-backed image payloads, Spotlight saved-search continuation, or physical lens/location/EXIF proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 04:50 PDT - May Goals metadata-only contact sheet export v1

### What changed

- Added `BracketProjectContactSheet`, a metadata-only professional export payload derived from `BracketProject.PreviewPlaceholder`.
- The contact sheet records per-shot EV label, capture state, file type, representation availability, status label, and best-exposure marker.
- Added the `contact-sheet` JSON payload to `BracketProjectExportBundle` beside project JSON, manifest JSON, optional sidecar JSON, privacy report, and diagnostics report.
- Updated the privacy report to disclose that the contact sheet contains metadata placeholders only, with no thumbnails or raw photo bytes.
- Updated `BracketProjectImportBundle` to decode and validate the optional contact-sheet payload against project preview facts, and to reject mismatched contact sheets.
- Updated import conflict remapping so keep-both duplicate imports keep the in-memory contact-sheet project id aligned with the saved copy id.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the contact-sheet contract and current proof boundary.

### Verification

- XcodeBuildMCP defaults were confirmed before testing:
  - project: `/Users/m3-max/Documents/GitHub/Bracketer/Bracketer.xcodeproj`
  - scheme: `Bracketer`
  - simulator: `iPhone 17 Pro` (`BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`)
- XcodeBuildMCP `test_sim -only-testing:BracketerTests` timed out at the 120s wrapper boundary; the underlying `xcodebuild` then sat without a test runner child and without a readable result-bundle `Info.plist`, so that stale process was killed and not accepted as proof.
  - Incomplete bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T11-44-26-738Z_pid18246_45a00bb3.xcresult`
- Passed direct focused unit bundle after the MCP runner wedged:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO -resultBundlePath /tmp/bracketer-contact-sheet-unit.xcresult`
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/tmp/bracketer-contact-sheet-unit.xcresult`
  - New executed coverage:
    - `bracketProjectExportBundleRedactsIdentifiersByDefault`
    - `bracketProjectImportBundleRoundTripsMetadataOnlyArchiveThroughStore`
    - `bracketProjectImportBundleRejectsInvalidOrIncompleteArchivesWithoutSaving`
- `git diff --check` passed after code/tests and after documentation updates.
- Process sanity check found no lingering Bracketer `xcodebuild`, `xctest`, or contact-sheet test process.

### Proof category

- `pure-model-proof`: contact-sheet model construction, export-bundle payload creation, redaction from metadata-only archives, privacy-report disclosure, import round trip, and contact-sheet mismatch rejection are covered by Swift tests.

### Current proof boundary

- This is a metadata-only JSON contact sheet, not a rendered image/PDF contact sheet.
- It uses project preview placeholders and manifest facts; it does not inspect pixels, create thumbnails, export selected image bytes, pair RAW/processed resources, or render fusion previews.
- UI ShareLinks inherit the new archive payload because they share `BracketProjectExportBundle.archiveText`, but no new simulator UI proof was collected for this pure-model slice.
- Physical-device Files/Share/Shortcuts proof remains separate.

### Next slice

- Turn the metadata contact sheet into a selected-project review/export surface with richer compare state.
- Or start a rendered contact-sheet/final-output model that explicitly separates metadata placeholders, thumbnails, fusion previews, and final image science.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 04:58 PDT - May Goals metadata-only exposure comparison export v1

### What changed

- Added `BracketProjectExposureComparison`, a metadata-only review/export report built from manifest EV facts.
- The comparison report identifies the best/base exposure and labels the remaining shots as darker highlight guards, brighter shadow guards, missing planned exposures, or failed exposures.
- Each comparison item carries a short recommendation while explicitly avoiding pixel inspection, merge-readiness scoring, thumbnails, and image bytes.
- Added the `exposure-comparison` JSON payload to `BracketProjectExportBundle`.
- Updated the privacy report to disclose that exposure comparison uses manifest EV facts only and does not inspect pixels or score merges.
- Updated `BracketProjectImportBundle` to decode and validate optional exposure-comparison payloads against imported project facts, and to reject mismatches.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the exposure-comparison contract and limitations.

### Verification

- Passed direct focused unit bundle:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO -resultBundlePath /tmp/bracketer-exposure-comparison-unit.xcresult`
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/tmp/bracketer-exposure-comparison-unit.xcresult`
  - New executed coverage:
    - `BracketProjectExposureComparison`
    - export-bundle `exposure-comparison` payload generation
    - metadata-only comparison redaction
    - privacy-report comparison disclosure
    - import-bundle exposure-comparison round trip
    - exposure-comparison/project mismatch rejection
- Result summary was independently confirmed with `xcrun xcresulttool get test-results summary --path /tmp/bracketer-exposure-comparison-unit.xcresult --compact`.
- `git diff --check` passed after code/tests and after documentation updates.
- Process sanity check found no lingering Bracketer `xcodebuild`, `xctest`, or exposure-comparison test process.

### Proof category

- `pure-model-proof`: exposure-comparison construction, export-bundle payload generation, metadata-only redaction, privacy-report disclosure, import round trip, and mismatch rejection are covered by Swift tests.

### Current proof boundary

- This is a metadata report for review/export archives, not a visible side-by-side compare UI.
- It does not inspect image pixels, measure clipping, estimate motion, score merge readiness, or render any thumbnail/contact-sheet image.
- Physical-device proof with real Photos-backed captures remains separate.

### Next slice

- Surface the comparison model in the selected-project review sheet or Settings project row.
- Or build a rendered contact-sheet/final-output model with a strict preview-vs-final boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 05:17 PDT - May Goals visible project exposure comparison v1

### What changed

- Added a visible `Exposure Compare` section to `BracketProjectReviewHandoffView`.
- The section is built from `BracketProjectExposureComparison.make(project:)`, so the review UI uses the same manifest-fact comparison contract as export/import validation.
- Added tappable comparison rows at `review.project.exposureComparison.item.<index>`:
  - rows show the EV label, role, and recommendation
  - the selected restored shot is visually marked
  - tapping a row selects the matching `BracketReviewSequence` shot
- Exposed the comparison summary at `review.project.exposureComparison`, including the baseline exposure and comparison count.
- Extended the simulated project handoff UI test to verify:
  - `review.project.exposureComparison`
  - `Baseline 0 EV`
  - baseline row `review.project.exposureComparison.item.2`
  - tapping `review.project.exposureComparison.item.4`
  - selected-shot value updates to `Shot 5 / +4.0 EV | Available | HEIF/JPEG`
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the visible selected-project comparison contract.

### Verification

- Passed focused unit bundle through XcodeBuildMCP:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerTests ... CODE_SIGNING_ALLOWED=NO`
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T12-08-22-943Z_pid18246_ee395773.xcresult`
- Passed focused simulator UI test:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `1` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T12-10-23-516Z_pid18246_4593e1f9.xcresult`
- Independently confirmed both result bundles with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path ... --compact`.
- `git diff --check` passed after the code/test edit and after documentation updates.
- Process sanity check found no lingering Bracketer `xcodebuild`, `xctest`, UI-test runner, or app process. An unrelated Eco Hero `xcodebuild` process was left untouched.

### Proof category

- `simulator-ui-proof`: the selected-project handoff sheet exposes the visible comparison summary and tappable rows, and tapping the +4 EV row selects the +4 EV restored shot.
- `pure-model-proof`: the comparison data still comes from the already-tested `BracketProjectExposureComparison` manifest-fact model.

### Current proof boundary

- This is still a manifest-fact comparison surface, not a side-by-side rendered pixel comparator.
- It does not inspect thumbnails, measure clipping from image data, estimate ghosting, score merge readiness, or export final rendered images.
- Physical-device proof with real Photos-backed projects remains separate.

### Next slice

- Build rendered contact-sheet or final-output export models with a strict preview-vs-final boundary.
- Or deepen the review/library route with actual image-backed comparison once the Photos/image payload path is ready.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 05:33 PDT - May Goals rendered contact-sheet HTML export v1

### What changed

- Added `BracketProjectContactSheetDocument`, a printable HTML document generated from the existing privacy-safe `BracketProjectContactSheet` placeholder model.
- Added a `contact-sheet-html` payload to `BracketProjectExportBundle`:
  - MIME type: `text/html`
  - filename: `<payload-base>-contact-sheet.html`
  - content: deterministic HTML with title, project id, captured/generated timestamps, privacy summary, shot tiles, EV labels, status labels, representation labels, and best-exposure marker
- Kept the privacy boundary explicit:
  - no raw photo bytes
  - no thumbnails
  - no Photos local identifiers
  - no precise location coordinates
  - no pixel analysis or final image science
- Updated the privacy report to disclose the rendered contact-sheet HTML payload.
- Updated `BracketProjectImportBundle` to preserve optional `contactSheetHTML` and validate it against the decoded contact-sheet JSON. Tampered HTML now rejects with the contact-sheet mismatch path instead of silently importing.
- Updated export/import unit tests for:
  - `contact-sheet-html` payload ordering
  - HTML MIME type
  - rendered document markers
  - best-exposure tile marker
  - metadata-only redaction
  - privacy-report disclosure
  - import round trip
  - tampered HTML rejection
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the contact-sheet HTML contract and limits.

### Verification

- First focused unit attempt failed at compile time:
  - `BracketProjectImportBundle.resolvingConflict` needed an explicit `return` after adding a local resolved contact sheet.
  - Fixed and reran.
- Passed focused unit bundle through XcodeBuildMCP:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerTests ... CODE_SIGNING_ALLOWED=NO`
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T12-27-59-741Z_pid18246_f71ac5b0.xcresult`
- Passed focused simulator UI regression:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `1` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T12-29-36-188Z_pid18246_93d25d1c.xcresult`
- Independently confirmed both result bundles with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path ... --compact`.
- `git diff --check` passed after code/tests and after documentation updates.
- Process sanity check found no lingering Bracketer `xcodebuild`, `xctest`, UI-test runner, or app process.

### Proof category

- `pure-model-proof`: contact-sheet HTML generation, export-bundle payload inclusion, import validation, metadata-only redaction, privacy-report disclosure, and tampered HTML rejection are covered by Swift tests.
- `simulator-ui-proof`: the Settings export ShareLink archive path still passes with the larger archive payload.

### Current proof boundary

- This is a rendered HTML contact-sheet document, not an image/PDF contact sheet and not a thumbnail contact sheet.
- It still renders privacy-safe metadata placeholders only; it does not load Photos bytes, inspect pixels, or produce final merged images.
- Physical-device proof with real Photos-backed projects remains separate.

### Next slice

- Move from placeholder documents to image-backed contact sheets or final-output export models with a strict raw-byte permission boundary.
- Or deepen the selected-project review route with actual image-backed side-by-side comparison once the Photos payload path is ready.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 06:47 PDT - May Goals manifest-backed capture-quality report v1

### What changed

- Added `BracketProjectCaptureQualityReport`, a Codable manifest-backed quality artifact for the first closed-loop verification foothold.
- Added a `capture-quality-report` JSON payload to `BracketProjectExportBundle`:
  - available, missing, and failed shot counts
  - EV spread
  - darker highlight guard count
  - brighter shadow guard count
  - RAW and processed availability counts
  - readiness score and label
  - findings and recovery recommendations
  - boundary: manifest facts only, no private Photos bytes, no sharpness/blur/alignment/ghosting inspection, and no physical asset availability proof
- Updated `BracketProjectImportBundle` to decode optional capture-quality reports and reject archives where the report no longer matches the imported project facts.
- Updated duplicate keep-both conflict resolution so imported capture-quality reports get the resolved project id.
- Updated the export privacy report to disclose the manifest-only capture-quality boundary.
- Added a selected-project review card at `review.project.qualityReport` with readiness score, available-shot count, EV spread, top findings, and boundary copy.
- Updated export/import and UI tests for:
  - `capture-quality-report` payload ordering
  - manifest-backed counts and EV spread
  - readiness score and readiness label
  - RAW/processed availability counts
  - metadata-only redaction
  - privacy-report disclosure
  - import round trip
  - semantic tamper rejection without byte-count mismatch
  - visible restored-project quality report
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the capture-quality contract and limits.

### Verification

- First focused unit run failed:
  - Result: `113` passed, `1` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-25-16-717Z_pid18246_373d9592.xcresult`
  - Root cause: the tamper test changed payload length, so the importer rejected the archive for byte-count mismatch before exercising the capture-quality semantic validator.
- Second focused unit run failed for the same tamper-design reason:
  - Result: `113` passed, `1` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-27-13-037Z_pid18246_73f6c97c.xcresult`
- Third focused unit run failed for the same byte-count issue after a different unequal-length boundary mutation:
  - Result: `113` passed, `1` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-28-20-695Z_pid18246_d95fe9c2.xcresult`
- Fixed the tamper to use a same-length readiness-label mutation, then passed focused unit verification:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerTests ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-30-04-799Z_pid18246_d58d69b9.xcresult`
- First focused simulator UI follow-up failed before reaching the new quality report:
  - Result: `0` passed, `1` failed.
  - Failure: initial `camera.proControlsButton` query timed out while evaluating the UI query.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-33-17-910Z_pid18246_f3921174.xcresult`
  - Treated as simulator/query flakiness, not proof.
- Clean focused simulator UI rerun passed:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `1` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-40-43-561Z_pid18246_efdead71.xcresult`
- Independently confirmed the passing unit and UI result bundles with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path ... --compact`.

### Proof category

- `pure-model-proof`: capture-quality report generation, export-bundle payload inclusion, import validation, metadata-only redaction, privacy-report disclosure, count/readiness assertions, recommendation assertions, and semantic tamper rejection are covered by Swift tests.
- `simulator-ui-proof`: restored project review exposes the capture-quality report through deterministic UI tests.

### Current proof boundary

- This is a manifest-backed quality report, not a physical capture verifier.
- It does not inspect actual pixels, sharpness, blur, alignment, ghosting, Photos resource existence, or real-device save integrity.
- It does not automatically stage recovery captures yet.

### Next slice

- Deepen Wave C with physical Photos asset availability modeling, motion/blur/alignment risk, or a recovery workflow.
- Or continue Wave K/G by moving from metadata and synthetic artifacts into image-backed contact sheets or real Photos-backed comparison surfaces.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 06:16 PDT - May Goals deterministic side-by-side pixel comparison v1

### What changed

- Added `BracketProjectSideBySidePixelComparison`, a Codable export artifact that compares the best/base exposure against each available guard exposure using deterministic synthetic RGBA pixel strips.
- Added a `side-by-side-pixel-comparison` JSON payload to `BracketProjectExportBundle`:
  - source: `deterministicFixture`
  - dimensions: `3x1` per strip
  - payload: baseline RGBA bytes, comparison RGBA bytes, difference RGBA bytes, max channel delta, baseline/comparison labels, and role labels
  - boundary: synthetic fixture pixels only, not private Photos bytes, not image-backed review, and not a merge-readiness score
- Updated `BracketProjectImportBundle` to decode optional side-by-side pixel comparison reports and reject archives where the comparison no longer matches the imported project facts.
- Updated duplicate keep-both conflict resolution so imported side-by-side pixel comparison reports get the resolved project id.
- Updated the export privacy report to disclose the deterministic synthetic side-by-side pixel comparison payload.
- Added a selected-project review card at `review.project.pixelComparison` with tappable `review.project.pixelComparison.item.<index>` rows that select the compared exposure.
- Updated export/import and UI tests for:
  - `side-by-side-pixel-comparison` payload ordering
  - deterministic baseline-vs-guard labels
  - RGBA strip byte counts
  - diff alpha samples and max channel deltas
  - metadata-only redaction
  - privacy-report disclosure
  - import round trip
  - tampered side-by-side pixel comparison rejection
  - visible restored-project pixel comparison rows
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the side-by-side pixel comparison contract and limits.

### Verification

- Passed focused unit bundle through XcodeBuildMCP:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerTests ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-05-56-837Z_pid18246_5a6fc64c.xcresult`
- Passed focused simulator UI regression:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `1` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T13-08-25-216Z_pid18246_680fdb32.xcresult`
- Independently confirmed both result bundles with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path ... --compact`.
- `git diff --check` passed before focused verification.

### Proof category

- `pure-model-proof`: side-by-side pixel comparison report generation, export-bundle payload inclusion, import validation, metadata-only redaction, privacy-report disclosure, RGBA strip assertions, diff-byte assertions, and tampered comparison rejection are covered by Swift tests.
- `simulator-ui-proof`: restored project review exposes the pixel-comparison card and tappable `+4.0 EV` comparison row through deterministic UI tests.

### Current proof boundary

- This is a deterministic synthetic `3x1` pixel-comparison artifact, not a real Photos-backed side-by-side review.
- It does not load user image bytes, export selected images, inspect real pixels, score merge readiness, align frames, deghost motion, or produce final rendered output.
- Physical-device proof with real Photos-backed projects remains separate.

### Next slice

- Move from synthetic pixel comparisons to image-backed contact sheets or real Photos-backed side-by-side comparison with an explicit raw-byte permission boundary.
- Or start the final rendered output model while keeping preview, diagnostic, and final-product payloads separately labeled.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 05:51 PDT - May Goals deterministic fusion-preview export v1

### What changed

- Added `BracketProjectFusionPreviewReport`, a Codable export artifact for the existing deterministic Core Image fusion-preview prototype.
- Added a `fusion-preview` JSON payload to `BracketProjectExportBundle` when the project can build a deterministic preview:
  - source: `deterministicFixture`
  - dimensions: `3x1`
  - payload: EV labels, source count, color-pipeline note, preview summary, RGBA bytes, and byte count
  - boundary: synthetic preview pixels only, not final HDR output and not private Photos bytes
- Updated `BracketProjectImportBundle` to decode optional fusion-preview reports and reject archives where the preview no longer matches the imported project facts.
- Updated duplicate keep-both conflict resolution so imported fusion previews get the resolved project id along with the project/contact-sheet/comparison payloads.
- Updated the export privacy report to disclose the deterministic synthetic fusion-preview payload.
- Updated export/import tests for:
  - `fusion-preview` payload ordering
  - RGBA byte count and alpha samples
  - EV label and source-count agreement
  - metadata-only redaction
  - privacy-report disclosure
  - import round trip
  - tampered fusion-preview rejection
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the fusion-preview contract and limits.

### Verification

- Passed focused unit bundle through XcodeBuildMCP:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerTests ... CODE_SIGNING_ALLOWED=NO`
  - Result: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T12-43-52-880Z_pid18246_999a7bdf.xcresult`
- Passed focused simulator UI regression:
  - Command: XcodeBuildMCP `test_sim -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview ... CODE_SIGNING_ALLOWED=NO`
  - Note: the MCP wrapper timed out at `120s`, but its underlying `xcodebuild` completed successfully.
  - Result: `1` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T12-45-32-717Z_pid18246_4bd54bf5.xcresult`
- Independently confirmed both result bundles with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path ... --compact`.
- `git diff --check` passed after code/tests and after documentation updates.
- Process sanity check found no lingering Bracketer `xcodebuild`, `xctest`, UI-test runner, or app process.

### Proof category

- `pure-model-proof`: fusion-preview report generation, export-bundle payload inclusion, import validation, metadata-only redaction, privacy-report disclosure, RGBA fixture assertions, and tampered preview rejection are covered by Swift tests.
- `simulator-ui-proof`: the Settings export ShareLink archive path still passes with the larger archive payload, and selected-project comparison interaction remains green.

### Current proof boundary

- This is a deterministic synthetic `3x1` preview artifact, not a real Photos-backed fusion result.
- It does not perform final HDR reconstruction, tone mapping, alignment, deghosting, RAW processing, or image-backed side-by-side comparison.
- Physical-device proof with real Photos-backed projects remains separate.

### Next slice

- Move from synthetic preview payloads to image-backed contact sheets or side-by-side pixel comparison with an explicit raw-byte permission boundary.
- Or start the final rendered output model while keeping preview, diagnostic, and final-product payloads separately labeled.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 03:58 PDT - May Goals export presets and naming templates v1

### What changed

- Added `BracketProjectExportFilenameTemplate` with three deterministic archive naming modes:
  - `projectIdentifier`: stable project-id bundle names for round trips.
  - `datedSummary`: capture date, shot count, source, and privacy level without Photos identifiers.
  - `privacyAudit`: short privacy-review names tied to schema and privacy level.
- Added `BracketProjectExportPreset` with Client Handoff, Review Archive, Recovery Archive, and Privacy Audit presets that select privacy plus filename behavior together.
- Extended `BracketProjectExportBundle` with:
  - stored `filenameTemplate`
  - stored `archiveFilename`
  - archive `Filename:` and `Naming:` headers
  - template-derived payload basenames
- Extended `FileBracketProjectStore.exportBundle(...)` and `LatestBracketProjectExportFileProvider.exportFile(...)` to accept a filename template.
- Added `BracketProjectExportIntentFilenameTemplate` so `ExportLatestBracketProjectBundleIntent` can return Shortcuts `IntentFile` exports with explicit privacy and filename choices.
- Added visible Settings controls:
  - `settings.projects.exportPreset`
  - `settings.projects.exportPreset.<preset>`
  - `settings.projects.exportFilenameTemplate`
- Updated latest-project and per-row ShareLinks so the selected preset/privacy/name template drives the generated metadata bundle.
- Updated README, architecture notes, and `.codex-maygoals-progress.md`.

### Verification

- First unit run compiled and executed but failed one stale assertion that expected the old internal project payload filename:
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-45-35-041Z_pid18246_e39f2cfd.xcresult`
  - Fixed by asserting the new `archiveFilename`, `Filename:` header, and actual `projectFile.filename`.
- Passed focused unit bundle after the assertion update:
  - `BracketerTests`: `113` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-47-49-452Z_pid18246_befad0dc.xcresult`
  - New executed coverage:
    - `bracketProjectExportPresetsAndFilenameTemplatesProduceDeterministicNames`
    - `latestBracketProjectExportFileProviderBuildsRedactedIntentFile`
    - `bracketProjectExportIntentPrivacyMapsToProjectPrivacyLevel`
- Focused simulator UI proof:
  - First attempt timed out and left a hung runner without a readable result; killed the stuck `xcodebuild` before rerun.
  - Second attempt timed out at the MCP wrapper but underlying `xcodebuild` eventually passed.
  - `testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-54-37-263Z_pid18246_07657e15.xcresult`
  - New executed coverage:
    - `settings.projects.exportPreset`
    - Client Handoff preset
    - `settings.projects.exportFilenameTemplate`
    - Dated summary naming
    - latest/per-row export ShareLink payloads containing deterministic metadata-only filenames.

### Proof category

- `pure-model-proof`: filename template generation, export presets, archive headers, provider filenames, and App Intent filename mapping are covered by Swift tests.
- `simulator-ui-proof`: Settings export preset/name controls and ShareLink payload values were verified in the simulator relaunch-loaded project library.
- `local-sdk-proof`: App Intents filename enum and `IntentFile` export provider compiled against the local iOS 26.5 simulator SDK.

### Current proof boundary

- This is metadata-bundle naming, not photo/RAW/fusion/contact-sheet naming.
- Export presets configure metadata bundle privacy and filenames only; no Files document browser, contact sheet, selected-image package, RAW/processed bundle, fusion preview, or final rendered output exists yet.
- Physical-device Share Sheet, Files, Shortcuts runtime, and Photos-backed proof remain separate.

### Next slice

- Add import preview/conflict review, richer selected-project compare tools, contact-sheet export models, or a dedicated archive route for saved projects.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 04:33 PDT - May Goals import preview and conflict review v1

### What changed

- Added `BracketProjectImportPreview`, a no-save archive preview model that reports:
  - candidate project id and display title
  - resolved project id before import
  - payload kinds
  - privacy summary
  - duplicate project id when present
  - selected duplicate policy
  - action summary for new, replace, keep-both, or reject outcomes
- Added `FileBracketProjectStore.importPreview(...)` so archives can be parsed and conflict-reviewed without mutating the project library.
- Added `CameraController.previewProjectArchiveText(...)` with storage diagnostics matching the existing import path.
- Updated Settings import wiring so selected file text is previewed with the currently selected duplicate policy before `CameraController.importProjectArchiveText(...)` saves it.
- Updated README, architecture notes, and `.codex-maygoals-progress.md`.

### Verification

- Passed focused unit bundle:
  - `BracketerTests`: `114` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T11-12-13-777Z_pid18246_e8af83a5.xcresult`
  - New executed coverage:
    - `bracketProjectImportPreviewDescribesDuplicateResolutionWithoutSaving`
    - `cameraControllerImportsProjectArchiveTextIntoLibrary` preview assertions
- Simulator UI regression was attempted but not accepted:
  - First readable attempt failed at `BracketerUITests.swift:480`, the initial `camera.proControlsButton` wait, before project import/export UI was reached.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T11-14-22-824Z_pid18246_407b8449.xcresult`
  - Second readable attempt failed at the same initial line after app cleanup.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T11-20-11-458Z_pid18246_ea34d22c.xcresult`
  - A third attempt after simulator erase hung before a useful result and the stuck `xcodebuild` was killed.

### Proof category

- `pure-model-proof`: import preview parse/duplicate/no-save behavior and controller preview seam are covered by Swift tests.
- `blocked-proof`: simulator UI proof for this slice is blocked by repeated XCTest startup snapshot timeouts at the first camera button lookup, before the changed import preview path is reached.

### Current proof boundary

- This is a preview model and Settings import-seam handoff, not a dedicated import review screen with a confirm/cancel workflow.
- The visible Settings file importer still uses the system file picker and then previews/imports the selected archive in one path.
- No physical Files restore proof, cloud backup, App Intent import provider, or manual document-browser proof has been collected.

### Next slice

- Add a dedicated import review surface, richer selected-project compare tools, contact-sheet export models, or a dedicated archive route for saved projects.

### Goal status

- Goal still open. Verified model wave complete; simulator UI proof for this slice remains blocked by launch/query flake.

## 2026-05-27 00:51 PDT - May Goals privacy-safe Spotlight index v1

### What changed

- Added `BracketProjectSpotlightRecord`, the first privacy-preserving CoreSpotlight projection for saved Bracketer projects.
- Added hashed Spotlight item identifiers derived from project ids so the system index does not expose Photos local identifiers or project ids that may contain private capture group identifiers.
- Built metadata-only Spotlight title, description, and keywords from project facts:
  - source
  - lifecycle
  - shot count
  - EV labels
  - recipe title/source
  - accepted tags
  - user notes
  - representation/file-type summaries
  - diagnostics summary
- Explicitly kept Photos local identifiers, raw photo bytes, and precise coordinates out of the Spotlight searchable text.
- Added `CoreSpotlightBracketProjectIndexer` and wired `FileBracketProjectStore` so saved projects index into CoreSpotlight, individual project deletion removes the hashed item, and project archive reset clears the `bracketer.projects` domain.
- Added `BracketerSpotlightHandoff`, which resolves a CoreSpotlight continuation identifier back through the project store and records the same review-destination handoff used by the project App Intent path.
- Updated `BracketerApp` to handle `CSSearchableItemActionType` user activities and route them into `BracketerAppIntentRouter`.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the Spotlight boundary and current limitations.

### Verification

- Local SDK proof:
  - Inspected CoreSpotlight headers in the local iOS 26.5 simulator SDK.
  - Typechecked a focused Swift snippet using `CSSearchableItemAttributeSet(contentType: .json)`, `CSSearchableItem`, and `CSSearchableIndex.default().indexSearchableItems(...)`.
- Passed focused unit bundle:
  - `BracketerTests`: `99` passed, `0` failed, `0` skipped.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-46-24-288Z_pid18246_930090c5.xcresult`
  - New executed coverage:
    - `bracketProjectSpotlightRecordRedactsPrivateIdentifiers`
    - `fileBracketProjectStoreIndexesAndDeletesSpotlightRecords`
    - `bracketerSpotlightHandoffResolvesIndexedProjectToReviewHandoff`
  - Remaining warnings were the pre-existing `OrientationManager.swift:204` main-actor deinit warnings.
- Targeted simulator UI run hit the MCP wrapper timeout while the underlying `xcodebuild` continued, then completed successfully:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-47-49-690Z_pid18246_69e88c42.xcresult`
- Passed `git diff --check` before docs/ledger updates and again after the final docs/progress/ledger handoff updates.

### Proof category

- `local-sdk-proof`: CoreSpotlight APIs were verified against the local iOS 26.5 SDK headers and compiler.
- `pure-model-proof`: Spotlight record construction, privacy redaction, store indexing/deletion hooks, hashed identifier lookup, and handoff conversion are covered by Swift tests.
- `simulator-ui-proof`: deterministic simulated capture still passes with the production store attempting CoreSpotlight updates during project save/reset.

### Current proof boundary

- This is real CoreSpotlight indexing code compiled into the app, but no physical-device or manual Spotlight search-result proof has been collected.
- Spotlight entries intentionally index metadata and user-approved notes/tags only; they do not include raw pixels, Photos local identifiers, precise coordinates, contact sheets, thumbnails, or generated image outputs.
- Spotlight item taps record a review handoff through `BracketerAppIntentRouter`; full selected-project review restoration remains a separate routing/UI slice.
- Widgets, Control Center, Action button, file-result App Intents, and document/import workflows remain separate system-surface work.

### Next slice

- Add an App Intent export surface for project bundles where the local SDK supports file-like results.
- Or start project import/backup so the metadata bundle can round-trip back into Bracketer.
- Keep physical Spotlight search-result proof separate until a configured iPhone target is available.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 00:58 PDT - May Goals App Intent project bundle file export v1

### What changed

- Added `BracketProjectExportBundle.archiveFilename` so project bundle archives have a stable file-result name.
- Added `BracketProjectExportIntentPrivacy`, an App Intents privacy enum that maps to the project export privacy policies:
  - `metadataOnly`
  - `recoveryIdentifiers`
- Added `LatestBracketProjectExportFileProvider`, which reads the latest persisted project, builds a `BracketProjectExportBundle`, and converts its archive text into an App Intents `IntentFile`.
- Added `ExportLatestBracketProjectBundleIntent`, a Shortcuts-facing action that returns the latest Bracketer project bundle as a file result without opening the camera.
- Added App Shortcut phrases for exporting the latest project bundle.
- Added unit coverage proving:
  - the exported `IntentFile` contains the same redacted archive text as the project export bundle
  - metadata-only export redacts Photos local identifiers and private group identifiers
  - no-project export requests throw a specific no-project error
  - the App Intents privacy enum maps to the project export privacy enum
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new file-result export surface and remaining limitations.

### Verification

- Local SDK proof:
  - Inspected the local iOS 26.5 AppIntents Swift interface for `IntentFile`, `ReturnsValue<IntentFile>`, and `.result(value:dialog:)`.
  - Typechecked a focused Swift snippet implementing an `AppIntent` that returns an `IntentFile` value with a dialog.
- Passed focused unit bundle:
  - `BracketerTests`: `102` passed, `0` failed, `0` skipped.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-55-50-321Z_pid18246_dd97724b.xcresult`
  - New executed coverage:
    - `latestBracketProjectExportFileProviderBuildsRedactedIntentFile`
    - `latestBracketProjectExportFileProviderThrowsWithoutProject`
    - `bracketProjectExportIntentPrivacyMapsToProjectPrivacyLevel`

### Proof category

- `local-sdk-proof`: App Intents file-result APIs were verified against the local iOS 26.5 SDK interface and compiler.
- `pure-model-proof`: latest-project export-file creation, metadata redaction, filename construction, no-project error handling, and privacy enum mapping are covered by Swift tests.

### Current proof boundary

- This is an App Intents `IntentFile` export surface for Shortcuts/file-result workflows, not a full Files document browser, import provider, document package, or image/RAW export suite.
- The default export remains metadata-only and excludes raw photo bytes, Photos local identifiers, and precise coordinates.
- The recovery-identifier mode can include Photos local identifiers for recovery, but still does not include image bytes.
- No physical-device Shortcuts execution proof has been collected.

### Next slice

- Add project import/backup so metadata bundles can round-trip back into Bracketer.
- Or restore full selected-project review UI from App Intent and Spotlight handoffs.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 01:11 PDT - May Goals project bundle import/backup v1

### What changed

- Added store-backed project bundle import through `FileBracketProjectStore.importArchiveText(...)`.
- Extended the project bundle domain with `BracketProjectImportBundle` and `BracketProjectImportError` validation for:
  - Bracketer archive header.
  - supported schema.
  - required project, manifest, privacy-report, and diagnostics-report payloads.
  - payload byte counts.
  - project id/header consistency.
  - project manifest equality.
  - optional sidecar equality.
  - no raw photo bytes.
- Reused the normal project-store save path for imported archives, so current-project routing, latest-project loading, search, persistence, and Spotlight indexing hooks are exercised by imports instead of a separate restore path.
- Added unit coverage proving:
  - metadata-only archives round-trip through the store without Photos local identifiers or private group identifiers.
  - explicit recovery-identifier archives restore Photos local identifiers while still excluding raw photo bytes.
  - malformed archives reject invalid headers, missing manifest payloads, and byte-count mismatches.
  - invalid imports do not save partial project records.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the import/backup contract and remaining UI/Files limitations.

### Verification

- XcodeBuildMCP `test_sim -only-testing:BracketerTests ... CODE_SIGNING_ALLOWED=NO` hit the MCP wrapper timeout at `120s`, but the underlying `xcodebuild` completed successfully.
- Direct log and `.xcresult` inspection showed:
  - `BracketerTests`: `105` passed, `0` failed, `0` skipped.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-06-32-956Z_pid18246_221da755.xcresult`
  - New executed coverage:
    - `bracketProjectImportBundleRoundTripsMetadataOnlyArchiveThroughStore`
    - `bracketProjectImportBundleRoundTripsRecoveryIdentifierArchiveWhenExplicit`
    - `bracketProjectImportBundleRejectsInvalidOrIncompleteArchivesWithoutSaving`
- Passed `git diff --check` after implementation and again before docs/ledger handoff.

### Proof category

- `pure-model-proof`: archive parsing, metadata-only privacy redaction, explicit recovery-identifier restoration, malformed archive rejection, no-save-on-invalid behavior, current/latest/search persistence, and the injected Spotlight indexing hook are covered by Swift tests.

### Current proof boundary

- This is a model/store import path for Bracketer text archives, not yet a visible Files document importer, document browser, import App Intent, cloud backup, or user-facing conflict-resolution workflow.
- Metadata-only imports intentionally cannot recover Photos local identifiers. Recovery-identifier imports can restore local identifiers but still never contain raw image bytes or precise coordinates.
- Physical-device Files/Shortcuts restore proof with a real Photos-backed project remains separate.

### Next slice

- Add a visible import-provider/UI route so users can choose a Bracketer archive and restore it.
- Or restore full selected-project review UI from App Intent and Spotlight handoffs.
- Keep physical-device proof separate until a configured iPhone target is available.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 01:27 PDT - May Goals selected-project review handoff restoration v1

### What changed

- Added `BracketReviewSequence.make(manifest:)` so persisted project manifests can reconstruct a review sequence without requiring live `PHAsset` objects.
- Added `BracketProjectReviewSnapshot`, the route model for restoring a selected saved project into review.
- Added `CameraController.restoreProjectReview(...)` and `restoreLatestProjectReview(...)`:
  - Loads the selected project from `FileBracketProjectStore`.
  - Marks it current in the project index.
  - Restores `lastBracketProject`, `lastBracketManifest`, and `lastBracketReviewSequence`.
  - Publishes `restoredProjectReviewSnapshot` for UI presentation.
  - Records recoverable diagnostics when a handoff points to a missing project.
- Added `BracketProjectReviewHandoffView`, a full-screen manifest-backed project review sheet with:
  - selected shot card
  - sequence rows
  - generated note or deterministic narrative card
  - project facts/privacy/diagnostics section
  - stable probes under `review.project.*`
- Updated `ModernContentView` to consume `BracketerAppIntentRouter.lastHandoff`, route camera/pro-controls/intelligence destinations, and restore selected or latest review handoffs.
- Added `-ui-testing-open-latest-project-review` for deterministic relaunch proof of the selected-project review route.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new handoff-restoration boundary.

### Verification

- First focused unit run for the slice timed out at the MCP wrapper, but the underlying `.xcresult` completed and passed:
  - `BracketerTests`: `107` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-19-51-942Z_pid18246_907a1596.xcresult`
- Reran focused unit bundle successfully inside the wrapper:
  - `BracketerTests`: `107` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-23-22-086Z_pid18246_514abca6.xcresult`
  - New executed coverage:
    - `bracketReviewSequenceRestoresManifestFactsForProjectReview`
    - `cameraControllerRestoresSelectedProjectReviewFromStore`
- Focused simulator UI run hit the MCP wrapper timeout while underlying `xcodebuild` continued, then completed successfully:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-24-40-536Z_pid18246_f1828e1b.xcresult`
  - New executed coverage: saved simulated project relaunches with `-ui-testing-open-latest-project-review`, presents `review.project.handoff.summary`, exposes selected shot state, and finds `review.project.shot.2`.

### Proof category

- `pure-model-proof`: manifest-to-review-sequence restoration and controller project handoff restoration are covered by Swift tests.
- `simulator-ui-proof`: a saved simulated project survives relaunch and opens directly into the manifest-backed project-review handoff sheet.

### Current proof boundary

- This restores project metadata, manifest facts, generated notes, diagnostics, and per-shot state; it does not restore actual image pixels, RAW resources, thumbnails, or physical Photos assets.
- Physical Siri/Shortcuts/Spotlight execution proof remains separate from simulator launch-argument proof.
- The project review sheet is a first restored route, not the final pro archive workspace with thumbnails, compare tools, favorites, conflict resolution, or editing.

### Next slice

- Add a visible import-provider/UI route so users can choose a Bracketer archive and restore it.
- Or deepen the project archive workspace with thumbnails/placeholders, favorites, tags, and selected-project export/import actions.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 02:26 PDT - May Goals selected-project row export v1

### What changed

- Added a per-project metadata bundle ShareLink inside each visible Settings project-library row.
- New UI hook: `settings.projects.result.<index>.exportBundle.shareButton`.
- The per-row export uses `BracketProjectExportBundle.make(project:privacyLevel:)` with metadata-only redaction, matching the latest-project export privacy boundary.
- Extended the simulated capture UI test to prove the selected-project export row:
  - exists after app relaunch
  - exposes `Project Export Bundle`
  - reports `Metadata only`
  - redacts simulated Photos identifiers
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the selected-project export route.

### Verification

- Passed `git diff --check` before Xcode verification.
- Passed focused unit bundle:
  - `BracketerTests`: `112` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-18-34-293Z_pid18246_3ba811a4.xcresult`
- Focused simulated capture UI run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-20-38-391Z_pid18246_a953b381.xcresult`
  - New executed coverage:
    - `settings.projects.result.0.exportBundle.shareButton`
    - metadata-only privacy value
    - simulated Photos identifier redaction

### Proof category

- `simulator-ui-proof`: a relaunch-loaded saved project exposes its own metadata export ShareLink in the compact project library.
- `pure-model-proof`: the selected export route reuses the already tested `BracketProjectExportBundle` model.

### Current proof boundary

- Selected-project export is visible only for the compact Settings project rows, not yet a full archive workspace or document browser.
- It exports metadata bundles, not image payloads, contact sheets, RAW/processed resources, or rendered fusion outputs.
- Physical share sheet proof with real Photos-backed projects remains separate.

### Next slice

- Add thumbnail/preview placeholders, visible conflict choices, or a richer archive route for saved projects.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 02:47 PDT - May Goals visible duplicate-import policy UI v1

### What changed

- Added a visible Duplicate Imports policy control to the compact Settings > About project library.
- New UI hook: `settings.projects.importConflictPolicy`.
- The control exposes all `BracketProjectImportConflictPolicy` cases:
  - `Keep both`
  - `Replace existing`
  - `Reject duplicate`
- The selected policy is passed into `CameraController.importProjectArchiveText(...)` when the file importer reads a Bracketer archive.
- The import button now includes the selected duplicate policy in its accessibility value, so a user or test can verify the active policy before picking a file.
- Added pure-test coverage for the policy accessibility value.
- Extended the simulated capture UI test to prove the policy is visible after relaunch and defaults to `Keep both`.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new visible conflict-choice boundary.

### Verification

- Passed `git diff --check` before Xcode verification.
- Passed focused unit bundle:
  - `BracketerTests`: `112` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-33-44-101Z_pid18246_a89f7c38.xcresult`
- First focused simulated capture UI run timed out at the MCP wrapper layer and the underlying `.xcresult` failed before reaching the new Settings import-policy assertions:
  - `BracketerUITests.swift:480`
  - Failure: `Failed to get matching snapshots: Timed out while evaluating UI query.`
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-35-49-854Z_pid18246_c587e3c8.xcresult`
- Reran the same focused simulated capture UI test after simulator app cleanup. The MCP wrapper timed out, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-41-49-578Z_pid18246_2c604e66.xcresult`
  - New executed coverage:
    - `settings.projects.importConflictPolicy`
    - `settings.projects.importBundle.button`
    - default duplicate policy value `Keep both`

### Proof category

- `simulator-ui-proof`: the compact project-library import path now exposes user-selectable duplicate-import policy before file selection.
- `pure-model-proof`: duplicate-policy accessibility value is covered by Swift tests.

### Current proof boundary

- This is a visible policy selector, not a full import preview or conflict-review workspace.
- The UI proves default keep-both visibility in simulator; it does not perform a real Files picker import in UI automation.
- Physical Files restore proof with real project archives remains separate.

### Next slice

- Add thumbnail/preview placeholders, a richer import-preview/conflict review surface, or a dedicated archive route for saved projects.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 03:01 PDT - May Goals privacy-safe project preview placeholders v1

### What changed

- Added `BracketProject.PreviewPlaceholder`, a thumbnail-free archive preview projection derived from manifest shots.
- Preview placeholders expose:
  - EV label
  - capture state
  - file type
  - available RAW/processed representations
  - best-exposure candidate marker
  - compact symbol/status for Settings rows
- Preview placeholders intentionally omit Photos local identifiers, raw photo bytes, precise coordinates, and image thumbnails.
- Added `BracketProject.previewPlaceholders` and `previewStripAccessibilityValue` for model and UI reuse.
- Added a compact horizontal preview strip to every visible Settings project-library row.
- New UI hook: `settings.projects.result.<index>.previewStrip`.
- Extended model and UI coverage to prove the preview strip includes shot facts while redacting simulated/Photos identifiers.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new preview-placeholder boundary.

### Verification

- Passed `git diff --check` before Xcode verification.
- Focused unit run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerTests`: `112` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-52-49-109Z_pid18246_4ba22982.xcresult`
  - New executed coverage:
    - `BracketProject.previewPlaceholders`
    - best-exposure marker in preview accessibility output
    - preview output does not include Photos asset identifiers
- Focused simulated capture UI run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-56-18-519Z_pid18246_fc73ea8f.xcresult`
  - New executed coverage:
    - `settings.projects.result.0.previewStrip`
    - `0 EV`
    - `Best exposure candidate`
    - simulated Photos identifier redaction

### Proof category

- `pure-model-proof`: preview placeholders are derived from manifest facts and tested for privacy-safe accessibility output.
- `simulator-ui-proof`: a relaunch-loaded saved project exposes the preview strip in the compact Settings project library.

### Current proof boundary

- These are privacy-safe placeholders, not actual thumbnails, contact sheets, RAW previews, or rendered fusion previews.
- The simulator proof uses deterministic saved projects and simulated asset identifiers.
- Physical Photos-backed thumbnail proof remains separate.

### Next slice

- Add import preview/conflict review, richer compare tools, export presets, or a dedicated archive route for saved projects.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 03:16 PDT - May Goals visible export privacy selector v1

### What changed

- Added a visible Export Privacy selector to the compact Settings > About project library.
- New UI hook: `settings.projects.exportPrivacyLevel`.
- The selector exposes both `BracketProjectExportPrivacyLevel` cases:
  - `Metadata only`
  - `Recovery identifiers`
- The selector defaults to metadata-only redaction.
- The selected privacy level now feeds:
  - latest-project ShareLink at `settings.projects.exportBundle.shareButton`
  - per-row selected-project ShareLinks at `settings.projects.result.<index>.exportBundle.shareButton`
- Added policy accessibility copy to `BracketProjectExportPrivacyLevel`.
- Renamed the visible latest export row from metadata-specific copy to project-bundle copy, because the row now responds to the selected privacy level.
- Extended the simulated capture UI test to prove the selector is visible after relaunch and reports metadata-only redaction before export.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new visible redaction-control boundary.

### Verification

- Passed `git diff --check` before Xcode verification.
- Passed focused unit bundle:
  - `BracketerTests`: `112` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-06-46-776Z_pid18246_29d8de76.xcresult`
  - New executed coverage:
    - `BracketProjectExportPrivacyLevel.metadataOnly.accessibilityValue`
- Focused simulated capture UI run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-08-51-147Z_pid18246_e140a635.xcresult`
  - New executed coverage:
    - `settings.projects.exportPrivacyLevel`
    - default value `Metadata only`
    - redaction policy copy

### Proof category

- `simulator-ui-proof`: the compact project-library export surface exposes a privacy selector before ShareLinks are used.
- `pure-model-proof`: export privacy policy accessibility copy is covered by Swift tests.

### Current proof boundary

- This controls metadata-only vs recovery-identifier bundle generation for Settings ShareLinks.
- It does not add export presets, naming templates, a document browser, contact sheets, image payloads, or physical share-sheet proof.
- The default remains metadata-only redaction.

### Next slice

- Add import preview/conflict review, export presets, richer compare tools, or a dedicated archive route for saved projects.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 03:34 PDT - May Goals project smart collections v1

### What changed

- Added `BracketProjectSmartCollection`, a privacy-safe collection model derived from stored project facts.
- Smart collection kinds now cover:
  - reviewable projects
  - projects needing review
  - favorites
  - RAW-available projects
  - recovery-identifier projects
  - generated-note projects
  - exported projects
- Extended `BracketProjectLibrarySnapshot.make(...)` with an optional smart-collection filter.
- Added collection accessibility summaries for Settings and UI tests.
- Added interactive smart collection chips to Settings > About > Project Library.
- New UI hooks:
  - `settings.projects.smartCollections`
  - `settings.projects.smartCollections.<kind>`
- Smart collections intentionally use only project metadata, lifecycle, review summaries, curation, privacy flags, and export history; they do not claim semantic image understanding or inspect raw pixels.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the smart-collection contract and remaining archive-workspace boundary.

### Verification

- Passed `git diff --check` before Xcode verification.
- Focused unit run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerTests`: `112` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-25-27-088Z_pid18246_6a697228.xcresult`
  - New executed coverage:
    - smart collection derivation
    - favorites collection count/filter
    - RAW-available collection count/filter
    - selected collection accessibility summary
- Focused simulated capture UI run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T10-29-09-740Z_pid18246_1ac949dc.xcresult`
  - New executed coverage:
    - `settings.projects.smartCollections`
    - `settings.projects.smartCollections.reviewable`

### Proof category

- `pure-model-proof`: smart collection derivation and filtering are covered by Swift tests.
- `simulator-ui-proof`: a relaunch-loaded saved project library exposes smart collection controls in Settings.

### Current proof boundary

- These are fact-derived local collections, not Apple Intelligence semantic albums.
- The Settings surface filters the compact project list; it is not yet a dedicated archive workspace.
- Physical Photos-backed project-library proof remains separate.

### Next slice

- Add import preview/conflict review, export presets/naming templates, richer compare tools, or a dedicated archive route for saved projects.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 02:14 PDT - May Goals duplicate project import conflict handling v1

### What changed

- Added `BracketProjectImportConflictPolicy` with three explicit duplicate-import behaviors:
  - `replaceExisting`
  - `keepBoth`
  - `rejectDuplicate`
- Extended `BracketProjectImportError` with `duplicateProjectIdentifier`.
- Added `BracketProject.withImportConflictIdentifier(...)` so keep-both imports save an immutable project copy with a generated import-copy id.
- Extended `BracketProjectImportBundle` with an optional `conflictResolution` summary that appears in accessibility output.
- Updated `FileBracketProjectStore.importArchiveText(...)` to:
  - preserve existing replace behavior by default
  - reject duplicates when requested
  - keep both projects when requested by generating a unique `-import-<timestamp>` id
  - save all accepted imports through the normal store and Spotlight indexing path
- Updated `CameraController.importProjectArchiveText(...)` to default the UI-facing Settings importer to keep-both duplicate handling.
- Updated the Settings import status string so duplicate handling can be surfaced after a file import.
- Added unit coverage for keep-both duplicate imports and duplicate rejection.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the conflict-handling contract and remaining UI boundary.

### Verification

- Passed `git diff --check` before Xcode verification.
- Focused unit run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerTests`: `112` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-58-50-441Z_pid18246_3335bb92.xcresult`
  - New executed coverage:
    - `bracketProjectImportBundleKeepsDuplicateArchivesAsCopiesWhenRequested`
    - `bracketProjectImportBundleCanRejectDuplicateArchives`
- First focused simulated capture UI attempt failed before app interaction:
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-01-17-723Z_pid18246_cc2aaa60.xcresult`
  - Failure: `Failed to get matching snapshots: Timed out while evaluating UI query.`
  - Failure line: `BracketerUITests.swift:480`, waiting for `camera.proControlsButton`.
  - This happened before any project-library, import, curation, or review interaction.
- Reran the same focused simulated capture UI path after simulator cleanup; wrapper timed out but underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T09-07-36-841Z_pid18246_c27c2d44.xcresult`

### Proof category

- `pure-model-proof`: duplicate import policies, generated copy identifiers, duplicate rejection, and normal store routing are covered by Swift tests.
- `simulator-ui-proof`: the existing simulated project-library flow still passes after the conflict-handling changes on rerun.
- `environment-note`: one UI attempt failed at launch-time accessibility snapshot evaluation before exercising changed behavior, then passed on rerun.

### Current proof boundary

- Duplicate policy exists at the store/controller layer, and Settings import defaults to keep-both.
- There is not yet a visible conflict-choice sheet that lets a user choose replace, keep both, or reject at import time.
- Physical Files restore proof with real user-selected archives remains separate.

### Next slice

- Add visible conflict choices, selected-project export/import actions, or thumbnail/preview placeholders for the archive workspace.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 01:55 PDT - May Goals project curation v1

### What changed

- Added optional `BracketProject.Curation` with favorite state and curation update timestamp.
- Added `BracketProject.withUserCuration(...)` so favorites, tags, and notes update through a normalized immutable project copy.
- Normalized project tags and notes on creation and curation updates:
  - trims surrounding whitespace
  - drops empty tags
  - preserves first-seen tag order
  - turns blank notes into `nil`
- Reindexed curation state into project search tokens and search corpus so `favorite`, tag, and note queries find the project.
- Added `FileBracketProjectStore.updateCuration(...)`, which saves the updated project through the normal persistence and Spotlight indexing path.
- Added `CameraController.updateProjectCuration(...)`, which refreshes latest project state, manifest/review sequence state, and the project-library snapshot after curation changes.
- Extended Settings > About project rows with:
  - favorite toggle at `settings.projects.favorite.<index>`
  - tag field at `settings.projects.tags.<index>`
  - note field at `settings.projects.note.<index>`
  - save button at `settings.projects.saveCuration.<index>`
  - curation status at `settings.projects.curationStatus.<index>`
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the curation contract and proof boundaries.

### Verification

- Passed `git diff --check` before Xcode verification.
- Passed focused unit bundle:
  - `BracketerTests`: `110` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-47-23-660Z_pid18246_645b52be.xcresult`
  - New executed coverage:
    - `bracketProjectUserCurationNormalizesFavoriteTagsNotesAndSearchTokens`
    - `cameraControllerUpdatesProjectCurationInLibrarySnapshot`
- Focused simulated capture UI run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-49-20-436Z_pid18246_c93782b2.xcresult`
  - New executed coverage:
    - `settings.projects.favorite.0`
    - default value `Not favorite`

### Proof category

- `pure-model-proof`: curation normalization, favorite/tag/note search tokens, store persistence, controller refresh, and Spotlight reindexing are covered by Swift tests.
- `simulator-ui-proof`: the relaunch-loaded Settings project library exposes the favorite control in the deterministic simulated flow.

### Current proof boundary

- This is compact project curation inside Settings, not the final archive workspace.
- Tags and notes are editable as text fields but do not yet have tag chips, bulk editing, smart collections, or conflict-resolution flows.
- Favorite state is searchable and persisted, but there is no dedicated favorites collection yet.
- Physical-device curation proof with real Photos-backed projects remains separate.

### Next slice

- Add duplicate/conflict handling for imported projects, selected-project export/import actions, or thumbnail/preview placeholders for the archive workspace.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 01:35 PDT - May Goals Settings project import provider v1

### What changed

- Added a visible Settings > About import route for Bracketer project archives.
- Extended the compact project-library surface with `settings.projects.importBundle.button`.
- Wired the import row to a system file importer for text and JSON archive files.
- Added `CameraController.importProjectArchiveText(...)` so UI import uses the same validated `BracketProjectImportBundle` and `FileBracketProjectStore.importArchiveText(...)` path as model tests.
- The controller import route refreshes latest/current project state, the project-library snapshot, and the last manifest/review sequence after a successful import.
- Import failures are recorded through camera diagnostics and surfaced in the row status instead of silently pretending recovery succeeded.
- Added unit and UI proof for the visible/import-provider path.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the import-provider contract and current proof boundary.

### Verification

- First focused unit run failed at compile time because `ModernAboutSection` referenced `camera` outside its scope.
  - Fixed by passing the import closure from `ModernSettingsPanel` into the project library section.
- Passed focused unit bundle:
  - `BracketerTests`: `108` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-32-24-575Z_pid18246_bfb69495.xcresult`
  - New executed coverage:
    - `cameraControllerImportsProjectArchiveTextIntoLibrary`
- Focused simulated capture UI run timed out at the MCP wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T08-33-37-971Z_pid18246_293a716d.xcresult`
  - New executed coverage:
    - `settings.projects.importBundle.button`
    - untouched initial status value `No project import attempted`

### Proof category

- `pure-model-proof`: archive import parsing, validation, store persistence, and controller latest/current state refresh are covered by Swift tests.
- `simulator-ui-proof`: Settings exposes the import-provider row in the deterministic simulated project-library flow.

### Current proof boundary

- This adds a visible system file-importer entry point, but it does not yet automate selecting a real Files document in UI tests.
- There is no conflict-resolution UI for duplicate project identifiers yet.
- Imports still restore metadata, manifests, sidecars, diagnostics, and recovery identifiers only when explicitly present; they do not restore raw image bytes or missing Photos assets.
- Physical Files app restore proof with a real iPhone remains separate.

### Next slice

- Deepen the project archive workspace with thumbnails/placeholders, favorites, tags, selected-project export/import actions, or duplicate/conflict handling.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 00:35 PDT - May Goals Settings project export ShareLink v1

### What changed

- Surfaced the latest persisted project export bundle in Settings through a real `ShareLink`.
- Added `BracketProjectExportBundle.archiveText`, a deterministic single-text archive containing the project JSON, manifest JSON, sidecar JSON, privacy report, and diagnostics report.
- Tightened metadata-only export redaction:
  - Project export identifiers no longer leak the original project id.
  - Manifest group identifiers are redacted when Photos asset identifiers are excluded.
  - The export bundle uses the redacted project id for metadata-only bundles and preserves original ids only for explicit recovery-identifier exports.
- Added a Settings > About export row with stable UI automation hooks:
  - `settings.projects.exportBundle.shareButton`
  - Accessibility value containing the archive payload and privacy report summary for deterministic UI proof.
- Extended unit and UI coverage for the shareable export boundary.
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new export/share surface and current limitations.

### Verification

- First focused unit run through XcodeBuildMCP timed out at the wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerTests`: `96` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-22-45-655Z_pid18246_b038c03f.xcresult`
  - Coverage included metadata-only redaction and explicit recovery-identifier export bundle behavior.
- Focused simulated capture UI run also timed out at the wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-26-02-301Z_pid18246_4cfda858.xcresult`
  - Coverage included the Settings export ShareLink probe and asserted that simulated Photos asset identifiers were not exposed.
- Focused settings regression run timed out at the wrapper layer, but the underlying `.xcresult` completed and passed:
  - `BracketerUITests/BracketerUITests/testSettingsPresetsAndCaptureControlsExposeStableState`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-31-01-441Z_pid18246_701f1a8e.xcresult`
- Passed final `git diff --check`.

### Proof category

- `pure-model-proof`: deterministic archive generation, privacy report generation, metadata-only project id redaction, manifest group id redaction, and explicit recovery export behavior are covered by Swift tests.
- `simulator-ui-proof`: Settings exposes the latest metadata bundle through a stable ShareLink probe in the simulator UI test path.

### Current proof boundary

- This exports metadata/archive text through `ShareLink`; it is not yet a Files document exporter, project import/restore system, App Intent file-result surface, contact sheet generator, image payload exporter, RAW/processed asset exporter, or cloud backup path.
- Metadata-only export intentionally excludes Photos local identifiers and raw image bytes.
- Physical-device share sheet proof with a real Photos-backed project remains separate.

### Next slice

- Add Spotlight indexing for persisted projects using the AppEntity/search corpus.
- Add an App Intent export surface that returns a file-like export result where the local SDK supports it.
- Start the project import/backup path so exported metadata can round-trip back into Bracketer.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 00:18 PDT - May Goals project export bundle v1

### What changed

- Added `BracketProjectExportPrivacyLevel` with two explicit policies:
  - `metadataOnly`: default, redacts Photos local identifiers.
  - `recoveryIdentifiers`: includes Photos local identifiers for recovery while still excluding raw bytes and precise coordinates.
- Added `BracketProjectExportBundle`, the first project-bundle export model:
  - project JSON
  - manifest JSON
  - optional sidecar JSON
  - privacy report
  - diagnostics report
- Added `BracketProject.exportCopy(privacyLevel:)` and manifest redaction helpers so metadata-only exports remove asset identifiers from both project asset references and manifest shots.
- Added `FileBracketProjectStore.exportBundle(id:privacyLevel:)` so persisted projects can produce an export package through the store.
- Added tests proving:
  - metadata-only export redacts asset identifiers by default
  - privacy and diagnostics reports are emitted
  - sidecar provenance remains source-disclosed
  - recovery-identifier export includes Photos identifiers only when requested
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the export-bundle contract and current limitations.

### Verification

- First full unit run hit the 120s MCP timeout while `xcodebuild` continued. Inspecting the result bundle showed:
  - `BracketerTests`: `95` passed, `1` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-12-10-539Z_pid18246_03da8098.xcresult`
  - Root cause: the export sidecar test asserted an outdated phrase, "Deterministic review", while the actual sidecar correctly contained `deterministicFallback` source/disclosure fields.
- A focused Swift Testing selector run succeeded but reported `0` counted tests, so it was not accepted as proof.
- Passed full focused unit bundle after fixing the assertion:
  - `BracketerTests`: `96` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-16-25-536Z_pid18246_a70ee122.xcresult`
  - New executed coverage:
    - `bracketProjectExportBundleRedactsIdentifiersByDefault`
    - `bracketProjectExportBundleCanIncludeRecoveryIdentifiersWhenRequested`

### Proof category

- `pure-model-proof`: export bundle construction, JSON payload creation, default identifier redaction, explicit recovery identifier inclusion, privacy report payload, diagnostics report payload, and store-backed export lookup.

### Current proof boundary

- This is an export package model, not yet a visible ShareLink, Files integration, App Intent file result, import path, contact sheet, selected-image bundle, RAW/processed bundle, fusion preview, or final rendered output.
- Export bundles intentionally do not include raw photo bytes. Image export requires a separate explicit product/permission path.
- Physical-device export proof with real Photos-backed projects remains separate.

### Next slice

- Surface `BracketProjectExportBundle` in Settings or an App Intent so users can actually share/export the generated payloads.
- Add Spotlight indexing for persisted projects using the AppEntity/search corpus.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 00:10 PDT - May Goals Bracket Project AppEntity v1

### What changed

- Added `BracketProjectEntity`, a privacy-safe App Intents entity backed by the persisted `BracketProject` model.
- Added `BracketProjectEntityQuery`, an `EntityStringQuery` implementation that resolves:
  - specific project identifiers
  - suggested recent projects
  - search matches through `FileBracketProjectStore.search(_:)`
- Added `OpenBracketProjectIntent`, which accepts a selected `BracketProjectEntity`, opens the app, and records a review-destination handoff with the selected project id/title.
- Extended `BracketerAppIntentHandoff` with optional project id/title fields while preserving the existing camera/preset handoff contract.
- Added unit coverage for:
  - AppEntity suggested entities
  - identifier resolution
  - search-backed entity lookup
  - project handoff accessibility values
- Updated `README.md`, `docs/ARCHITECTURE.md`, and `.codex-maygoals-progress.md` with the new AppEntity boundary and remaining routing limitations.

### Verification

- First AppEntity compile attempt failed:
  - `BracketProjectEntityQuery` did not satisfy the `EntityQuery` no-argument initializer requirement.
  - The query stored `FileBracketProjectStore`, which is non-`Sendable` and not acceptable for an App Intents query value.
  - Fixed by adding `init()` and storing only an optional root URL, then constructing the store inside each query method.
- Second AppEntity compile attempt failed because query methods were missing explicit `return` statements.
- Passed focused unit bundle after fixes:
  - `BracketerTests`: `94` passed, `0` failed.
  - XcodeBuildMCP result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T07-07-37-670Z_pid18246_408d3b4a.xcresult`
  - New executed coverage:
    - `bracketProjectEntityQueryResolvesSuggestedIdentifierAndSearchResults`
    - `bracketerAppIntentRouterStoresProjectHandoff`
- Passed `git diff --check`.

### Proof category

- `local-sdk-proof`: App Intents `AppEntity`/`EntityStringQuery` conformance compiled against the local iOS 26.5 simulator SDK.
- `pure-model-proof`: entity query resolution and project handoff values are covered by Swift tests.

### Current proof boundary

- The AppEntity is real and search-backed, but it is not yet connected to Spotlight indexing, widgets, Control Center, Action button, or a full selected-project navigation route.
- `OpenBracketProjectIntent` records a selected-project handoff truthfully; the app does not yet restore a full project detail/review screen from that handoff.
- No physical-device Siri/Shortcuts execution proof has been collected.

### Next slice

- Add Spotlight indexing for persisted projects where supported by the local SDK, using the AppEntity/search corpus and preserving privacy boundaries.
- Or add the first project export bundle so project records can leave the app with manifest, sidecar, diagnostics, and privacy reports.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 07:49 PDT - May Goals manifest-backed asset-resource report v1

### What changed

- Added `BracketProjectAssetResourceReport`, a manifest/project-backed resource inventory that records RAW availability, processed availability, complete-pair counts, missing representation labels, recovery-identifier policy, and per-shot recommendations.
- Added the `asset-resource-report` JSON payload to `BracketProjectExportBundle` after `capture-quality-report`.
- Updated metadata-only and recovery-identifier export tests so the report proves redacted identifier policy by default and explicit recovery identifier inclusion only when requested.
- Updated `BracketProjectImportBundle` to decode optional asset-resource reports, validate them against imported project facts, reject mismatches, and rewrite the project id during keep-both duplicate imports.
- Updated the privacy report to disclose that the asset-resource report uses manifest/project facts only and does not fetch Photos resources, open files, inspect RAW containers, or prove physical asset availability.
- Added a restored-project review card at `review.project.assetResources.card`, while keeping the hidden `review.project.assetResources` probe for deterministic handoff diagnostics.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the asset-resource report contract and proof boundary.

### Verification

- First focused unit compile failed because Swift Testing did not accept the key-path-style `allSatisfy` assertions in the new report checks. Rewrote those as explicit closures.
- Passed focused unit bundle after the fix:
  - `BracketerTests`: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T14-03-54-264Z_pid18246_c38d1978.xcresult`
- Several focused UI attempts failed while asserting a nested SwiftUI `Label` accessibility value for the asset-resource card.
  - Root cause: the visible nested `Label` exposed card existence reliably, but its value was not stable enough for a deep text assertion.
  - Fix: moved the visible identifier to `review.project.assetResources.card` and left the report values to the model/export/import tests.
- Passed focused restored-project UI path after the identifier fix:
  - `BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview`: `1` passed, `0` failed.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T14-39-24-424Z_pid18246_7c485d2e.xcresult`
  - New executed coverage: restored project review exposes `review.project.assetResources.card` before continuing through exposure and pixel-comparison checks.
- Passed final focused unit bundle:
  - `BracketerTests`: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T14-48-56-379Z_pid18246_16b5fc4c.xcresult`

### Proof category

- `pure-model-proof`: asset-resource report generation, payload ordering, metadata-only redaction, recovery-identifier counting, RAW/processed complete-pair counting, privacy-report disclosure, import round trip, project-id rewrite, and semantic tamper rejection are covered by Swift tests.
- `simulator-ui-proof`: restored project review exposes the visible asset-resource card in the deterministic simulated handoff path.

### Current proof boundary

- This is a manifest/project inventory, not a physical Photos resource audit.
- The report does not call `PHAssetResource`, open image files, inspect RAW containers, read raw bytes, render image-backed contact sheets, or prove that referenced assets still exist on disk/device.
- Physical-device Photos resource proof remains a separate future slice.

### Next slice

- Deepen resource truth with real Photos-backed resource inspection, image-backed contact sheets, final-output export models, or real Photos-backed side-by-side pixel comparison under an explicit raw-byte permission boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 08:07 PDT - May Goals deterministic contact-sheet preview export v1

### What changed

- Added `BracketProjectContactSheetPreview`, a deterministic pixel-backed contact-sheet artifact:
  - `3x2` RGBA fixture thumbnail tile per manifest shot
  - EV-coded pixel generation from manifest exposure offsets
  - missing/failed capture-state coloring
  - best-exposure marker preservation
  - explicit `deterministicFixture` source and non-Photos/non-RAW/non-final-output boundary
- Added the `contact-sheet-preview` JSON payload to `BracketProjectExportBundle` after the printable HTML contact sheet.
- Updated `BracketProjectImportBundle` to decode optional contact-sheet previews, validate them against imported project facts, reject mismatches, and rewrite the project id during keep-both duplicate imports.
- Updated the export privacy report to disclose that contact-sheet preview pixels are deterministic fixtures, not private Photos bytes, thumbnails, RAW resources, or final output.
- Extended export/import tests for payload ordering, RGBA tile bytes, metadata-only identifier redaction, privacy report disclosure, import round trip, and tamper rejection.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the contact-sheet-preview contract and remaining real-asset boundary.

### Verification

- XcodeBuildMCP unit run timed out at the wrapper layer after 120 seconds, but the underlying `xcodebuild` completed successfully:
  - `BracketerTests`: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T15-03-24-015Z_pid18246_8605744a.xcresult`
  - New executed coverage:
    - `BracketProjectContactSheetPreview`
    - `contact-sheet-preview` payload generation
    - deterministic RGBA tile dimensions/bytes/alpha
    - metadata-only redaction from preview payloads
    - privacy-report disclosure
    - import round trip
    - contact-sheet-preview tamper rejection

### Proof category

- `pure-model-proof`: deterministic contact-sheet preview generation, payload inclusion, import validation, redaction, privacy disclosure, and semantic tamper rejection are covered by Swift tests.

### Current proof boundary

- This is a deterministic fixture-pixel contact-sheet preview, not a real Photos-backed thumbnail contact sheet.
- The preview does not read private Photos bytes, RAW files, image thumbnails, camera captures, or final rendered output.
- Image/PDF contact sheets and physical-device asset-backed contact-sheet proof remain separate future slices.

### Next slice

- Move from deterministic contact-sheet preview pixels to real Photos-backed thumbnail/contact-sheet rendering, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 08:27 PDT - May Goals deterministic contact-sheet image export v1

### What changed

- Added `BracketProjectContactSheetImageDocument`, a deterministic image artifact that renders `contact-sheet-preview` fixture tiles into a base64-encoded PNG payload.
- Added the `contact-sheet-image` payload to `BracketProjectExportBundle` after the JSON contact-sheet preview.
- Updated `BracketProjectImportBundle` to decode optional contact-sheet image payloads, validate the base64 PNG against the deterministic preview pixels, reject mismatches, and regenerate the image when duplicate imports keep both projects.
- Updated the export privacy report to disclose that the contact-sheet image is a base64 PNG rendered from deterministic fixture pixels, not private Photos bytes, thumbnails, RAW resources, or final output.
- Extended export/import tests for PNG signature, rendered dimensions, byte counts, payload ordering, metadata-only identifier redaction, privacy report disclosure, import round trip, and tamper rejection.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the contact-sheet-image contract and remaining real-asset/PDF boundaries.

### Verification

- Local SDK typecheck passed for the `CoreGraphics`/`ImageIO`/`UniformTypeIdentifiers` PNG encoding path:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -typecheck /tmp/bracketer_png_check.swift`
- XcodeBuildMCP unit run timed out at the wrapper layer after 120 seconds, but the underlying `xcodebuild` completed successfully:
  - `BracketerTests`: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T15-22-21-976Z_pid18246_c38a6afb.xcresult`
  - New executed coverage:
    - `BracketProjectContactSheetImageDocument`
    - `contact-sheet-image` base64 PNG payload generation
    - PNG signature and rendered dimensions
    - metadata-only redaction from image payloads
    - privacy-report disclosure
    - import round trip
    - contact-sheet-image tamper rejection

### Proof category

- `local-sdk-proof`: local iOS simulator SDK typechecked the PNG encoding framework calls.
- `pure-model-proof`: deterministic contact-sheet image generation, payload inclusion, import validation, redaction, privacy disclosure, and semantic tamper rejection are covered by Swift tests.

### Current proof boundary

- This is a deterministic fixture-pixel PNG encoded inside the text archive, not a real Photos-backed thumbnail contact sheet and not a standalone Files export flow.
- The PNG does not read private Photos bytes, RAW files, image thumbnails, camera captures, or final rendered output.
- PDF contact sheets, real Photos-backed thumbnails, physical Files proof, and physical-device asset-backed contact-sheet proof remain separate future slices.

### Next slice

- Move toward real Photos-backed thumbnail/contact-sheet rendering, PDF/contact-sheet document export, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 08:42 PDT - May Goals deterministic contact-sheet PDF export v1

### What changed

- Added `BracketProjectContactSheetPDFDocument`, a deterministic PDF artifact that renders the existing `contact-sheet-preview` fixture tiles into a base64-encoded `%PDF-1.4` payload.
- Added the `contact-sheet-pdf` payload to `BracketProjectExportBundle` after the PNG contact-sheet image.
- Updated `BracketProjectImportBundle` to decode optional contact-sheet PDF payloads, validate them against the deterministic preview pixels, reject mismatches, and regenerate the PDF when duplicate imports keep both projects.
- Updated the export privacy report to disclose that the contact-sheet PDF is rendered from deterministic fixture pixels, not private Photos bytes, thumbnails, RAW resources, or final output.
- Extended export/import tests for PDF header, `startxref`, media-box dimensions, payload ordering, metadata-only identifier redaction, privacy report disclosure, import round trip, duplicate-import regeneration, and tamper rejection.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the contact-sheet-pdf contract and remaining real-asset/document boundaries.

### Verification

- First PDF test attempt failed at compile time because a nested `try #require(...)` triggered recursive Swift Testing macro expansion; fixed by splitting the required value before decoding.
- XcodeBuildMCP unit rerun timed out at the wrapper layer after 120 seconds, but the underlying `xcodebuild` completed successfully:
  - `BracketerTests`: `114` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T15-38-12-011Z_pid18246_96309815.xcresult`
  - New executed coverage:
    - `BracketProjectContactSheetPDFDocument`
    - `contact-sheet-pdf` base64 PDF payload generation
    - PDF header, `startxref`, and media-box verification
    - metadata-only redaction from PDF payloads
    - privacy-report disclosure
    - import round trip and duplicate regeneration
    - contact-sheet-pdf tamper rejection

### Proof category

- `pure-model-proof`: deterministic contact-sheet PDF generation, payload inclusion, import validation, redaction, privacy disclosure, and semantic tamper rejection are covered by Swift tests.

### Current proof boundary

- This is a deterministic fixture-pixel PDF encoded inside the text archive, not a real Photos-backed thumbnail contact sheet and not a standalone Files document export flow.
- The PDF does not read private Photos bytes, RAW files, image thumbnails, camera captures, or final rendered output.
- Real Photos-backed thumbnails, physical Files proof, and physical-device asset-backed contact-sheet proof remain separate future slices.

### Next slice

- Move toward real Photos-backed thumbnail/contact-sheet rendering, standalone Files/document export proof, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 09:12 PDT - May Goals resource inspection metadata export v1

### What changed

- Added `BracketProjectResourceInspection`, an optional per-project resource metadata contract for `PHAssetResource`-shaped facts and synthetic fixtures.
- The inspection model records per-shot resource type, original filename, UTI, inspected RAW/processed counts, resource state, mismatch labels, and recommendations without reading image bytes or decoding RAW files.
- Added `BracketProjectResourceInspectionReport` as an optional `resource-inspection-report` export payload.
- Updated export/import so resource-inspection reports:
  - appear immediately after `asset-resource-report` when a project has stored inspection metadata
  - redact recovery identifiers in metadata-only archives
  - include recovery identifiers only when the explicit recovery privacy level is selected
  - validate during import and reject semantic tampering
- Updated the export privacy report to disclose that resource inspection is metadata-only and does not read image bytes, files, RAW containers, or pixels.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new resource-inspection boundary and remaining physical-device gap.

### Verification

- First resource-inspection unit attempt failed at compile time because the new test asserted an optional `Bool?`; fixed the assertion by comparing it to `true`.
- XcodeBuildMCP unit rerun timed out at the wrapper layer after 120 seconds, but the underlying `xcodebuild` completed successfully:
  - `BracketerTests`: `115` passed, `0` failed, `0` skipped.
  - Result bundle: `/Users/m3-max/Library/Developer/XcodeBuildMCP/workspaces/Bracketer-ff9f2e2859e1/result-bundles/test_sim_2026-05-27T16-03-49-858Z_pid18246_628a967e.xcresult`
  - New executed coverage:
    - `BracketProjectResourceInspection`
    - `BracketProjectResourceInspectionReport`
    - optional `resource-inspection-report` payload generation
    - synthetic Photos-resource-shaped HEIC/DNG metadata pairing
    - RAW/processed resource counts and complete-pair counts
    - manifest-vs-inspection mismatch detection
    - metadata-only recovery-identifier redaction
    - explicit recovery-identifier inclusion
    - privacy-report disclosure
    - import round trip, search tokens, and tamper rejection

### Proof category

- `pure-model-proof`: resource inspection metadata modeling, optional payload inclusion, import validation, redaction, search tokens, privacy disclosure, and semantic tamper rejection are covered by Swift tests.

### Current proof boundary

- This is synthetic resource metadata proof for a `PHAssetResource`-shaped contract.
- It does not yet wire real `PHAssetResource.assetResources(for:)` output into persisted projects.
- It does not read private Photos bytes, open files, decode RAW containers, verify physical asset availability, or prove physical iPhone resource behavior.

### Next slice

- Wire the Photos-backed review resource summary path into persisted project resource inspections, then collect simulator-safe UI proof and leave physical-device resource proof as a separate checklist item.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 15:51 PDT - May Goals Photos-backed resource inspection persistence v1

### What changed

- Wired the live Photos review resource summary seam into persisted project state.
- `ImageViewer.refreshResourceSummary(for:at:)` now still updates the selected review shot from `PHAssetResource.assetResources(for:)`, and also publishes a metadata-only `BracketProjectResourceInspection.ShotResources` value with resource type, original filename, UTI, shot index, and Photos local identifier.
- `CameraController.updateLatestProjectResourceInspection(...)` now merges the selected-shot inspection into the latest project, preserves previously inspected shots, saves the updated project, refreshes the project-library snapshot, and records a Photos/storage diagnostic if persistence fails.
- `BracketProjectResourceInspection.replacingShotResources(...)` gives the runtime path a deterministic merge operation so inspecting shot 2 does not erase shot 1.
- `ModernContentView` wires the Photos-backed `ImageViewer` callback into the controller; simulated review remains separate.
- Added `cameraControllerPersistsPhotosResourceInspectionForLatestProject`, covering merge persistence, mismatch labeling, search indexing, Spotlight reindexing, and library refresh from synthetic Photos-shaped resource metadata.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the runtime metadata path and physical-device proof boundary.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`, with no matching warning/error output after the callback and resource-type warning fixes.
- XcodeBuildMCP focused test attempt timed out at the wrapper layer and then produced an `.xcresult` with `0` matched tests because the selector was too narrow for this Swift Testing suite; it was rejected as proof.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-resource-inspection-target-1779922171.xcresult test`
  - Result: `STATUS=0`; Swift Testing log reported `116 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=116`, `failedTests=0`, `skippedTests=0`, `totalTestCount=116`.
  - New executed coverage:
    - `cameraControllerPersistsPhotosResourceInspectionForLatestProject`
    - latest-project resource-inspection persistence
    - per-shot inspection merge without losing prior inspected shots
    - manifest-vs-inspection mismatch labeling
    - project-library snapshot refresh
    - search token indexing for inspected resource filenames and UTIs
    - Spotlight reindexing after persisted inspection updates
- `git diff --check`
  - Result: passed, no whitespace errors after this slice.

### Proof category

- `runtime-bridge-proof`: the production Photos review callback now feeds the persisted project-inspection contract, and the controller/store merge path is covered by Swift tests using Photos-shaped resource metadata.

### Current proof boundary

- The persisted runtime path is wired, but the verified resources are synthetic `BracketProjectResourceInspection.Resource` values in simulator tests.
- This still does not read private Photos bytes, open image files, decode RAW containers, render real Photos-backed contact sheets, prove physical iPhone Photos resources, or validate real ProRAW pairs on device.

### Next slice

- Collect physical-device Photos resource proof on a real library, or move into real Photos-backed thumbnails/contact sheets, standalone Files document export, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 15:59 PDT - May Goals resource inspection review surface v1

### What changed

- Surfaced persisted resource-inspection facts in the selected-project review handoff.
- `BracketProjectReviewHandoffView` now renders `review.project.resourceInspection` and `review.project.resourceInspection.card` when a restored project has resource-inspection metadata.
- The review card shows inspected shot count, complete RAW/processed pairs, mismatch count, per-shot resource state, inspected representation labels, filenames/UTIs through the report accessibility value, and the metadata-only boundary.
- `BracketProjectReviewSnapshot.accessibilityValue` now includes the resource-inspection report summary, so App Intent/Spotlight handoff probes expose the persisted inspection facts.
- Tightened resource-inspection mismatch counting so uninspected shots stay `not-inspected` without inflating mismatch counts.
- Added `bracketProjectReviewSnapshotIncludesResourceInspectionSummary`, covering selected-project review accessibility output for inspected shot count, complete pairs, and mismatch count.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the visible review-surface probe and current proof boundary.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-resource-inspection-review-tests-1779922743.xcresult test`
  - Result: `STATUS=0`; Swift Testing log reported `117 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=117`, `failedTests=0`, `skippedTests=0`, `totalTestCount=117`.
  - New executed coverage:
    - `bracketProjectReviewSnapshotIncludesResourceInspectionSummary`
    - selected-project review accessibility summary for resource inspection
    - inspected shot counts
    - complete RAW/processed pair counts
    - mismatch counts that exclude uninspected shots
    - continued runtime persistence coverage through `cameraControllerPersistsPhotosResourceInspectionForLatestProject`

### Proof category

- `review-surface-proof`: persisted resource-inspection metadata now reaches the selected-project review handoff and is covered by Swift tests at the restored-project summary boundary.

### Current proof boundary

- The review surface is model- and simulator-verified with synthetic Photos-shaped resource metadata.
- This still does not read private Photos bytes, open image files, decode RAW containers, render real Photos-backed contact sheets, prove physical iPhone Photos resources, or validate real ProRAW pairs on device.

### Next slice

- Collect physical-device Photos resource proof on a real library, or move into real Photos-backed thumbnails/contact sheets, standalone Files document export, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 16:11 PDT - May Goals Photos-backed thumbnail delivery persistence v1

### What changed

- Added `BracketProjectThumbnailInspection`, a durable project model for review-thumbnail delivery metadata from `PHImageManager`.
- The thumbnail inspection records per-shot requested pixel size, delivered pixel dimensions, delivery mode, content mode, degraded/cloud/cancel/error flags, result state, recommendation, and recovery identifier policy without storing thumbnail pixels or raw photo bytes.
- Added `BracketProject.withThumbnailInspection(...)` and search-token integration so thumbnail delivery facts can be found in the project library.
- `ImageViewer` now maps `PHCachingImageManager.requestImage(...)` callbacks into `BracketProjectThumbnailInspection.ShotThumbnail` values.
- `ModernContentView` wires the Photos-backed image-viewer callback into `CameraController.updateLatestProjectThumbnailInspection(...)`.
- `CameraController.updateLatestProjectThumbnailInspection(...)` merges selected-shot thumbnail updates into the latest project, preserves previous thumbnail evidence, saves the project, refreshes the library snapshot, and records Photos diagnostics on failure.
- Metadata-only project export redacts thumbnail recovery identifiers while preserving delivery dimensions and flags.
- Added `cameraControllerPersistsPhotosThumbnailInspectionForLatestProject`, covering persistence, merge behavior, search indexing, metadata-only redaction, library refresh, and Spotlight reindexing.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the thumbnail-delivery boundary and remaining physical-device gap.

### Verification

- Physical-device discovery:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl list devices`
  - Result: found paired available `Physical iPhone` / iPhone 17 Pro Max.
- Physical-device build/install lane:
  - Initial command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'id=75C96B6E-24BD-555F-A9B9-5852131BB23D' -skipMacroValidation COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Initial result: `STATUS=65`; no matching development provisioning profile existed.
  - Provisioning command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'id=75C96B6E-24BD-555F-A9B9-5852131BB23D' -allowProvisioningUpdates -skipMacroValidation COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Provisioning result: `STATUS=0`; `** BUILD SUCCEEDED **`; Xcode created/used `iOS Team Provisioning Profile: com.rishabh.Bracketer` with Apple Development signing.
  - Install command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device install app --device 75C96B6E-24BD-555F-A9B9-5852131BB23D /Users/m3-max/Library/Developer/Xcode/DerivedData/Bracketer-fanualotxeikjienxhqjafhbdmnr/Build/Products/Debug-iphoneos/Bracketer.app`
  - Install result: app installed on the paired iPhone with bundle id `com.rishabh.Bracketer`.
  - Launch command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device process launch --device 75C96B6E-24BD-555F-A9B9-5852131BB23D com.rishabh.Bracketer`
  - Launch result: blocked by iOS trust/security state because the profile/signature has not been explicitly trusted on device. This is physical build/install proof, not physical launch, camera, Photos, resource, or thumbnail proof.
- First thumbnail build failed because Swift could not infer the dictionary tuple type while compact-mapping stored thumbnail items; fixed by explicitly typing `[Int: ShotThumbnail]`.
- Clean simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`; `** BUILD SUCCEEDED **`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-thumbnail-inspection-tests-1779923326.xcresult test`
  - Result: `STATUS=0`; Swift Testing log reported `118 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=118`, `failedTests=0`, `skippedTests=0`, `totalTestCount=118`.
  - New executed coverage:
    - `cameraControllerPersistsPhotosThumbnailInspectionForLatestProject`
    - latest-project thumbnail-delivery persistence
    - per-shot thumbnail evidence merge without losing prior inspected shots
    - thumbnail delivered/error result states
    - project-library snapshot refresh
    - search token indexing for thumbnail dimensions and Photos image manager source
    - metadata-only export redaction of thumbnail recovery identifiers
    - Spotlight reindexing after persisted thumbnail updates
- `git diff --check`
  - Result: passed, no whitespace errors after this slice.

### Proof category

- `runtime-bridge-proof`: the production Photos review image callback now feeds a durable thumbnail-delivery metadata contract, and the controller/store merge path is covered by Swift tests using Photos-shaped thumbnail delivery facts.

### Current proof boundary

- The persisted runtime path is wired, but the verified thumbnail facts are synthetic `BracketProjectThumbnailInspection.ShotThumbnail` values in simulator tests.
- This still does not store thumbnail pixels, export real Photos-backed contact-sheet thumbnails, read private Photos bytes, open image files, decode RAW containers, prove physical iPhone Photos resources, or validate real ProRAW pairs on device.

### Next slice

- Collect physical-device Photos resource and thumbnail proof on a real library, or move into real Photos-backed contact-sheet thumbnails, standalone Files document export, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 16:19 PDT - May Goals thumbnail inspection review surface v1

### What changed

- Added `BracketProjectThumbnailInspectionReport`, a selected-project summary for persisted thumbnail-delivery facts.
- `BracketProjectReviewSnapshot.accessibilityValue` now includes thumbnail inspection summaries, so App Intent/Spotlight/project-review handoff probes expose requested shot count, delivered thumbnail count, degraded callback count, cloud-backed callback count, error count, and the no-thumbnail-pixels boundary.
- `BracketProjectReviewHandoffView` now renders `review.project.thumbnailInspection` and `review.project.thumbnailInspection.card` when a restored project has thumbnail-delivery metadata.
- The review card shows requested/delivered counts, degraded/error pills, per-shot delivery state, delivery dimensions, and the metadata-only boundary.
- Added `bracketProjectReviewSnapshotIncludesThumbnailInspectionSummary`, covering restored-project review accessibility output for requested shots, delivered thumbnails, degraded callbacks, and errors.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the visible thumbnail-inspection review probe.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - Warnings: pre-existing `OrientationManager.swift:204` actor-isolation warnings.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-thumbnail-review-tests-1779923840.xcresult test`
  - Result: `STATUS=0`; Swift Testing log reported `119 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=119`, `failedTests=0`, `skippedTests=0`, `totalTestCount=119`.
  - New executed coverage:
    - `bracketProjectReviewSnapshotIncludesThumbnailInspectionSummary`
    - selected-project review accessibility summary for thumbnail delivery
    - requested thumbnail shot counts
    - delivered thumbnail counts
    - degraded callback counts
    - error counts
    - continued runtime persistence coverage through `cameraControllerPersistsPhotosThumbnailInspectionForLatestProject`
- `git diff --check`
  - Result: passed, no whitespace errors after this slice.

### Proof category

- `review-surface-proof`: persisted thumbnail-delivery metadata now reaches the selected-project review handoff and is covered by Swift tests at the restored-project summary boundary.

### Current proof boundary

- The review surface is model- and simulator-verified with synthetic Photos-shaped thumbnail delivery facts.
- This still does not store thumbnail pixels, export real Photos-backed contact-sheet thumbnails, read private Photos bytes, open image files, decode RAW containers, prove physical iPhone Photos resources, or validate real ProRAW pairs on device.

### Next slice

- Collect physical-device launch/trust proof, Photos resource proof, and thumbnail proof on a real library after the device trusts the development profile, or move into real Photos-backed contact-sheet thumbnails, standalone Files document export, final-output export models, or a real image-backed side-by-side comparison path with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 16:25 PDT - May Goals merge-readiness report export and review v1

### What changed

- Added `BracketProjectMergeReadinessReport`, a manifest/project-backed heuristic that combines capture-quality, asset-resource, optional resource-inspection, thumbnail-delivery, and manifest facts into a score, label, blocker/caution counts, evidence rows, recommendations, and an explicit no-pixel/no-final-output boundary.
- `BracketProjectExportBundle` now emits `merge-readiness-report` JSON, the privacy report discloses its heuristic-only boundary, and `BracketProjectImportBundle` validates the report against the imported project while rejecting tampered readiness payloads.
- `BracketProjectReviewSnapshot.accessibilityValue` and `BracketProjectReviewHandoffView` now expose merge readiness in selected-project review at `review.project.mergeReadiness.card`.
- Added Swift Testing coverage for the restored-project summary, metadata-only export payload, archive import round trip, privacy redaction, and invalid/tampered archive rejection.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` so the export/review contract names the new report and its proof boundary.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - Warnings: pre-existing `OrientationManager.swift:204` actor-isolation warnings.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-merge-readiness-tests-1779924340.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `120 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=120`, `failedTests=0`, `skippedTests=0`, `totalTestCount=120`.
  - New executed coverage:
    - `bracketProjectReviewSnapshotIncludesMergeReadinessSummary`
    - merge-readiness export payload and privacy redaction
    - merge-readiness archive import round trip
    - merge-readiness tamper rejection through `BracketProjectImportError.mergeReadinessReportMismatch`
- `git diff --check`
  - Result: passed, no whitespace errors after this slice.

### Proof category

- `pure-model-proof`: the report is deterministic from saved project/manifest metadata and verified by Swift tests.
- `review-surface-proof`: persisted merge-readiness metadata now reaches selected-project review and is covered by restored-project summary tests.

### Current proof boundary

- The score is a heuristic over saved metadata and synthetic/test-shaped inspection facts.
- This still does not inspect private Photos bytes, measure sharpness, align frames, detect ghosting, mask moving subjects, decode RAW pixels, prove physical iPhone Photos resources, or validate final HDR output quality.

### Next slice

- Move toward real Photos-backed thumbnail/contact-sheet export, physical-device Photos resource proof after the development profile is trusted, standalone Files document import/export proof, or image-backed side-by-side/final-output review with explicit raw-byte permission boundaries.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 16:35 PDT - May Goals Shortcuts project archive import v1

### What changed

- Added `BracketProjectImportIntentConflictPolicy`, an App Intents duplicate-policy enum that maps to the existing project import conflict policies.
- Added `BracketProjectImportFileProvider`, which accepts a Shortcuts `IntentFile` or raw data, validates UTF-8 archive text, and delegates to `FileBracketProjectStore.importArchiveText` instead of inventing a second importer.
- Added `ImportBracketProjectBundleIntent`, a non-opening Shortcuts import action with an archive-file parameter and keep-both/replace/reject duplicate handling.
- Added an App Shortcut phrase group for importing or restoring a Bracketer project bundle.
- Added Swift Testing coverage for IntentFile-backed imports, metadata-only archive identity redaction, duplicate keep-both imports, unreadable file rejection, and conflict-policy mapping.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new Shortcuts import surface and current proof boundary.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - App Intents metadata extraction accepted the new import intent and wrote `Metadata.appintents`.
- First target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-import-intent-tests-1779924780.xcresult test`
  - Result: `STATUS=65`; the new assertions failed because they expected the private source project id instead of the metadata-only archive's redacted import id.
  - Fix: changed the tests to assert the exported archive identity and privacy-preserving imported title.
- Corrected target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-import-intent-tests-1779924860.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `123 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=123`, `failedTests=0`, `skippedTests=0`, `totalTestCount=123`.
  - New executed coverage:
    - `bracketProjectImportFileProviderImportsIntentFileThroughStore`
    - `bracketProjectImportFileProviderKeepsDuplicateIntentImportsSeparate`
    - `bracketProjectImportFileProviderRejectsUnreadableIntentData`
    - App Intent import/export enum policy mapping

### Proof category

- `local-sdk-proof`: the App Intents metadata extractor accepted the file-input import intent and shortcut metadata.
- `pure-model-proof`: the import provider is verified through the real export archive text, real store parser, and real duplicate-policy code.

### Current proof boundary

- This is a Shortcuts/App Intents file-input import provider and unit-tested store workflow, not a manual physical Files import run.
- Direct Siri/Shortcuts execution on device, Files document-browser UX, cloud backup, and physical restore proof remain separate.

### Next slice

- Add selected-project App Intent export, manual Files/document proof, physical Shortcuts import/export proof, or a richer import-preview workspace that exposes archive contents before mutation.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 16:40 PDT - May Goals selected-project App Intent export v1

### What changed

- Added `BracketProjectExportFileProvider`, a selected-project export provider that loads a specific project id and builds the same `BracketProjectExportBundle`/`IntentFile` output used by latest-project exports.
- Refactored `LatestBracketProjectExportFileProvider` to delegate bundle creation through the selected-project provider after resolving the latest project id.
- Added `BracketProjectExportFileError.projectNotFound` for missing selected-project exports.
- Added `ExportBracketProjectBundleIntent`, a non-opening App Intent that accepts a `BracketProjectEntity`, privacy level, and filename template, then returns an `IntentFile`.
- Added App Shortcut phrases for exporting a selected Bracketer project bundle.
- Added Swift Testing coverage proving selected-project export does not silently use the latest project, preserves explicit recovery-identifier export when requested, returns an `IntentFile` with matching archive text, and fails clearly for missing projects.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the selected-project App Intent export surface.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - App Intents metadata extraction accepted the selected-project export intent and wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-selected-export-intent-tests-1779925160.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `125 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=125`, `failedTests=0`, `skippedTests=0`, `totalTestCount=125`.
  - New executed coverage:
    - `bracketProjectExportFileProviderBuildsSelectedProjectIntentFile`
    - `bracketProjectExportFileProviderThrowsForMissingSelectedProject`

### Proof category

- `local-sdk-proof`: the App Intents metadata extractor accepted the selected-project file-result intent and shortcut metadata.
- `pure-model-proof`: selected-project export is verified through the real store, real project id lookup, real export bundle, and real `IntentFile` bytes.

### Current proof boundary

- This is simulator and unit-test proof of selected-project App Intent export, not direct Shortcuts/Siri execution on a physical device.
- No Files document-browser UX, selected image bundle, RAW/processed bundle, or physical share/restore proof is claimed.

### Next slice

- Move into physical Shortcuts import/export proof, manual Files document proof, a selected-image/RAW bundle export model, or a richer import-preview workspace.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 16:52 PDT - May Goals standalone Files project archive document export v1

### What changed

- Added `BracketProjectArchiveDocument`, a SwiftUI `FileDocument` wrapper around the existing Bracketer project export archive.
- The document reads plain-text or JSON candidate archives, rejects unreadable UTF-8 input, validates archive structure through `BracketProjectImportBundle.parse`, and writes the same plain-text archive bytes plus deterministic filename produced by `BracketProjectExportBundle`.
- Added a visible Settings > About latest-project Files export row at `settings.projects.exportBundle.fileButton`.
- Kept the existing latest-project ShareLink and per-row selected-project ShareLinks intact.
- Updated Settings import to pass selected files through `BracketProjectArchiveDocument` before preview/import, so the file-import path now shares the document validation boundary.
- Added UI-test coverage intent for the new Files button accessibility value, while keeping actual system document-picker invocation out of deterministic tests.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the document-export boundary and proof state.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - SwiftUI `FileDocument` and `.fileExporter` compiled; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-archive-document-tests-1779925600.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `127 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=127`, `failedTests=0`, `skippedTests=0`, `totalTestCount=127`.
  - New executed coverage:
    - `bracketProjectArchiveDocumentWrapsExportBundleForFiles`
    - `bracketProjectArchiveDocumentRejectsUnreadableAndInvalidFiles`
- Rejected UI proof:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSettingsPresetsAndCaptureControlsExposeStableState -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-archive-document-ui-1779925700.xcresult test`
  - Result: `STATUS=65`; failed before reaching the new Files export assertion.
  - `xcresulttool` summary: `result=Failed`, `passedTests=0`, `failedTests=1`, `totalTestCount=1`.
  - Failure text: `Failed to get matching snapshots: Timed out while evaluating UI query.`
  - Failure location: `BracketerUITests.swift:374`, waiting for pre-existing `camera.timerModeButton`.
- `git diff --check`
  - Result: passed after docs and ledger updates.

### Proof category

- `local-sdk-proof`: the local iOS SDK compiled the SwiftUI `FileDocument` and `.fileExporter` route.
- `pure-model-proof`: the document wrapper round-trips real export archive text through the existing import parser and rejects unreadable/invalid document payloads.
- `rejected-ui-proof`: the UI assertion was added, but the simulator run failed before reaching that surface and is not counted as proof.

### Current proof boundary

- This is simulator compile proof plus pure model/document proof of a Files-compatible archive document.
- It does not prove a manual Files save, physical iPhone document picker export/import, iCloud Drive round trip, or user-visible system picker behavior.
- It still exports metadata/provenance archives only, not raw photo bytes, real Photos-backed contact-sheet thumbnails, RAW/processed image bundles, or final rendered outputs.

### Next slice

- Move into physical Files document proof, real Photos-backed contact-sheet thumbnails, selected image/RAW bundle modeling, or final-output export models.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 17:05 PDT - May Goals selected image/RAW bundle manifest v1

### What changed

- Added `BracketProjectImageBundleManifest`, a metadata-only export payload for planning selected image/RAW bundles without exporting photo bytes.
- The manifest records requested RAW/processed representations, available representations, planned processed/RAW filenames, bundle readiness, missing representation labels, recovery-identifier inclusion flags, aggregate completeness counts, privacy level, and an explicit no-bytes/no-file-read/no-physical-proof boundary.
- `BracketProjectExportBundle` now emits `image-bundle-manifest` JSON after `merge-readiness-report`.
- The privacy report now discloses the selected image/RAW bundle plan boundary.
- `BracketProjectImportBundle` decodes optional image-bundle manifests, validates them against the imported project, rejects tampered payloads with `imageBundleManifestMismatch`, and rewrites project ids for keep-both duplicate imports.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the payload contract and proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - App Intents metadata extraction still wrote `Metadata.appintents`.
- First target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-image-bundle-manifest-tests-1779926520.xcresult test`
  - Result: `STATUS=65`; app target built, but the test target failed to compile because `#expect` expanded a key-path `allSatisfy` assertion as throwing.
  - Fix: changed the assertion to an explicit closure.
- Corrected target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-image-bundle-manifest-tests-1779926700.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `127 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=127`, `failedTests=0`, `skippedTests=0`, `totalTestCount=127`.
  - New executed coverage:
    - image-bundle manifest payload inclusion and ordering
    - metadata-only identifier redaction from the manifest
    - RAW/processed requested representation counts and complete-pair readiness
    - planned processed/RAW filenames
    - recovery-identifier privacy-mode reporting
    - archive import round trip
    - tamper rejection through `BracketProjectImportError.imageBundleManifestMismatch`

### Proof category

- `pure-model-proof`: selected image/RAW bundle planning is deterministic from saved project/manifest metadata and verified through export/import tests.
- `privacy-boundary-proof`: tests prove metadata-only archives do not leak Photos local identifiers in the image-bundle manifest and still disclose recovery-identifier presence when explicitly requested.

### Current proof boundary

- This is a manifest and archive-validation layer, not an image byte exporter.
- It does not fetch Photos resources, read files, decode RAW containers, produce a filesystem package, write JPEG/HEIC/DNG assets, or prove physical-device image bundle export.

### Next slice

- Move into physical Files document proof, real Photos-backed thumbnail/contact-sheet export, byte-export packaging behind explicit permissions, final-output export models, or real Photos-backed side-by-side pixel comparison.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 17:18 PDT - May Goals thumbnail inspection archive report v1

### What changed

- Promoted persisted thumbnail-delivery metadata into a first-class optional archive payload at `thumbnail-inspection-report`.
- Added `BracketProjectThumbnailInspectionReport.kind`, project-id rewrite support, and project-match validation.
- `BracketProjectExportBundle` now emits `thumbnail-inspection-report` JSON when a project has thumbnail inspection metadata, ordered after asset-resource/resource-inspection reports and before merge-readiness.
- `BracketProjectImportBundle` decodes optional thumbnail inspection reports, validates them against the imported project, rejects tampered payloads with `thumbnailInspectionReportMismatch`, and rewrites the report project id for keep-both duplicate imports.
- The export privacy report now discloses that thumbnail inspection reports contain delivery metadata only, with no thumbnail pixels, image bytes, files, RAW decoding, or physical proof.
- Added Swift Testing coverage for delivered, degraded, cloud-backed, error, cancelled, and not-requested thumbnail delivery states in archive export/import.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the archive payload contract and proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-thumbnail-inspection-export-tests-1779927240.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=128`, `failedTests=0`, `skippedTests=0`, `totalTestCount=128`.
  - New executed coverage:
    - optional thumbnail-inspection archive payload inclusion and ordering
    - delivered/degraded/cloud/error/cancel/not-requested counts
    - metadata-only recovery-identifier redaction
    - explicit recovery-identifier export mode
    - store-backed import round trip
    - tamper rejection through `BracketProjectImportError.thumbnailInspectionReportMismatch`
- `git diff --check`
  - Result: passed after thumbnail-report code, docs, progress, and ledger updates.

### Proof category

- `pure-model-proof`: thumbnail inspection archive reports are deterministic from saved project thumbnail-delivery metadata and verified through export/import tests.
- `privacy-boundary-proof`: tests prove metadata-only thumbnail reports redact Photos local identifiers while preserving delivery dimensions and flags, and recovery identifiers appear only under explicit recovery mode.

### Current proof boundary

- This archives thumbnail-delivery metadata, not thumbnail pixels.
- It does not read private Photos bytes, fetch image files, decode RAW containers, create real Photos-backed contact sheets, prove physical-device thumbnail delivery, or validate an actual user photo library.

### Next slice

- Move into physical Files document proof, real Photos-backed contact-sheet thumbnails, byte-export packaging behind explicit permissions, final-output export models, or real Photos-backed side-by-side pixel comparison.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.


## 2026-05-27 17:26 PDT - May Goals archive integrity manifest v1

### What changed

- Added `BracketProjectArchiveIntegrityManifest` as the final archive payload, with payload filename, kind, MIME type, byte count, and SHA-256 digest metadata for every preceding project bundle payload.
- `BracketProjectExportBundle` now appends `archive-integrity-manifest` after diagnostics so the manifest covers project, manifest, sidecar, contact sheet, report, privacy, and diagnostics payload text without self-hashing.
- `BracketProjectImportBundle` decodes the optional archive-integrity manifest and validates it after semantic payload agreement, rejecting non-semantic archive text tampering with `archiveIntegrityManifestMismatch`.
- The export privacy report now discloses the archive-integrity boundary: payload metadata and digests only, no Photos fetches, file reads, RAW decoding, image bytes, or physical export proof.
- Added Swift Testing coverage for final payload ordering, digest length, byte counts, store-backed import round trip, and equal-length privacy-report tamper rejection.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new archive contract and proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-archive-integrity-tests-1779927900.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=128`, `failedTests=0`, `skippedTests=0`, `totalTestCount=128`.
  - New executed coverage:
    - final `archive-integrity-manifest` payload inclusion and ordering
    - SHA-256 digest length checks and byte-count checks for every prior archive payload
    - integrity manifest import round trip through the store-backed importer
    - equal-length privacy-report tamper rejection through `BracketProjectImportError.archiveIntegrityManifestMismatch`
- `git diff --check`
  - Result: passed after archive-integrity code, tests, docs, progress, and ledger updates.

### Proof category

- `archive-integrity-proof`: project archives now carry deterministic metadata hashes for all non-integrity payloads and reject text tampering during import.
- `privacy-boundary-proof`: archive-integrity metadata covers bundle text without reading Photos resources, fetching files, decoding RAW containers, storing thumbnail pixels, or claiming physical export proof.

### Current proof boundary

- This hashes the project archive payload text only.
- It does not hash a Files/iCloud package after export, inspect an external filesystem artifact, read photo bytes, fetch Photos resources, decode RAW, prove real sidecar bytes, or validate physical-device document movement.

### Next slice

- Move into physical Files document proof, final-output export models, real Photos-backed contact-sheet thumbnails, real Photos-backed side-by-side pixel comparison, or image-bundle byte export under an explicit permission boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 17:36 PDT - May Goals final output manifest v1

### What changed

- Added `BracketProjectFinalOutputManifest` as a metadata-only professional output plan for tone-mapped review JPEG, HDR HEIF master, and Lightroom reference TIFF targets.
- `BracketProjectExportBundle` now emits `final-output-manifest` after `image-bundle-manifest`, with planned filenames, MIME types, codecs, color-pipeline notes, provenance inputs, readiness labels, blockers, and an explicit no-final-rendered-bytes boundary.
- `BracketProjectImportBundle` decodes and validates the final-output manifest, rejecting tampered plans through `finalOutputManifestMismatch`.
- `BracketProjectReviewHandoffView` now surfaces the output plan as `review.project.finalOutputs.card` so selected-project review shows what final deliverables are blocked and why.
- The privacy report now discloses that final-output manifests are plans only: no rendered image bytes, Photos resource fetches, RAW decoding, tone mapping, or physical export proof.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new archive payload contract and proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
  - First run exposed an unused-variable warning in the new manifest model; the warning was fixed before the target test run.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-final-output-manifest-tests-1779928440.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=128`, `failedTests=0`, `skippedTests=0`, `totalTestCount=128`.
  - New executed coverage:
    - final-output manifest payload inclusion and ordering
    - planned output filenames, codecs, provenance inputs, blockers, and no-final-bytes boundary
    - metadata-only identifier redaction from final-output plans
    - store-backed import round trip
    - tamper rejection through `BracketProjectImportError.finalOutputManifestMismatch`
    - selected-project review card at `review.project.finalOutputs.card`
- `git diff --check`
  - Result: passed after final-output code, tests, docs, progress, and ledger updates.

### Proof category

- `pure-model-proof`: final-output plans are deterministic from saved project/manifest/readiness metadata and verified through export/import tests.
- `privacy-boundary-proof`: tests and privacy report prove the output plan contains metadata and blockers only, not rendered image bytes or private Photos resources.
- `review-surface-proof`: the selected-project review sheet now has an accessibility-identified final-output card for the plan.

### Current proof boundary

- This is an output contract and blocker model, not a final renderer.
- It does not read Photos bytes, decode RAW, align images, deghost moving subjects, tone-map user assets, write HEIF/JPEG/TIFF bytes, package Lightroom assets, or prove physical Files export.

### Next slice

- Move into real final-output byte rendering, physical Files document proof, real Photos-backed contact-sheet thumbnails, real Photos-backed side-by-side pixel comparison, or image-bundle byte export under an explicit permission boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 17:42 PDT - May Goals final-output preview image v1

### What changed

- Added `BracketProjectFinalOutputPreviewImageDocument`, which renders the deterministic `fusion-preview` pixels into a base64 PNG artifact at `final-output-preview-image`.
- `BracketProjectExportBundle` now emits `final-output-preview-image` after `final-output-manifest` and before exposure comparison, with a preview-only boundary that explicitly excludes final HDR output, private Photos bytes, RAW-decoded data, and physical export proof.
- `BracketProjectImportBundle` decodes and validates the optional preview image against the matching fusion-preview payload, rejecting tampered bytes through `finalOutputPreviewImageMismatch`.
- The privacy report now discloses that final-output preview images are synthetic preview PNG bytes only.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new archive payload contract and proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-final-output-preview-image-tests-1779928920.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=128`, `failedTests=0`, `skippedTests=0`, `totalTestCount=128`.
  - New executed coverage:
    - `final-output-preview-image` payload inclusion and ordering
    - PNG signature, ImageIO dimensions, RGBA byte count, filename, MIME type, and boundary checks
    - store-backed import round trip
    - tamper rejection through `BracketProjectImportError.finalOutputPreviewImageMismatch`
    - privacy-report disclosure
- `git diff --check`
  - Result: passed after final-output-preview-image code, tests, docs, progress, and ledger updates.

### Proof category

- `preview-byte-proof`: project archives now carry deterministic PNG preview bytes derived from the synthetic fusion-preview payload.
- `privacy-boundary-proof`: tests and privacy report prove the preview image is not final HDR output, not private Photos bytes, not RAW decoded data, and not physical export proof.
- `pure-model-proof`: the preview image is deterministic from saved project/export facts and verified through export/import tests.

### Current proof boundary

- This is a synthetic preview artifact, not a final renderer.
- It does not read Photos bytes, decode RAW, align images, deghost moving subjects, tone-map user assets, write real HEIF/JPEG/TIFF output bytes, package Lightroom assets, or prove physical Files export.

### Next slice

- Move into real Photos-backed final output bytes, physical Files document proof, real Photos-backed contact-sheet thumbnails, real Photos-backed side-by-side pixel comparison, or image-bundle byte export under an explicit permission boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 17:55 PDT - May Goals final-output draft review JPEG v1

### What changed

- Added `BracketProjectFinalOutputDraftJPEGDocument`, which encodes deterministic `fusion-preview` pixels into a base64 JPEG draft artifact at `final-output-draft-review-jpeg`.
- `BracketProjectExportBundle` now emits the draft JPEG after the PNG final-output preview image and before exposure comparison.
- `BracketProjectImportBundle` decodes and validates the optional draft JPEG against the matching fusion-preview payload, rejecting tampered bytes through `finalOutputDraftJPEGMismatch`.
- The export privacy report now discloses that draft final-output JPEGs are synthetic review bytes only: not final HDR output, not private Photos bytes, not RAW decoding, not tone-mapped user assets, and not physical export proof.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new archive payload contract and proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-final-output-draft-jpeg-tests-1779929600.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=128`, `failedTests=0`, `skippedTests=0`, `totalTestCount=128`.
	  - New executed coverage:
	    - `final-output-draft-review-jpeg` payload inclusion and ordering
	    - JPEG SOI signature, ImageIO dimensions, filename, MIME type, and boundary checks
	    - store-backed import round trip
	    - tamper rejection through `BracketProjectImportError.finalOutputDraftJPEGMismatch`
	    - privacy-report disclosure
- `git diff --check`
  - Result: passed after final-output-draft-review-jpeg code, tests, docs, progress, and ledger updates.

### Proof category

- `draft-byte-proof`: project archives now carry deterministic JPEG draft bytes derived from the synthetic fusion-preview payload.
- `privacy-boundary-proof`: tests and privacy report prove the draft JPEG is not final HDR output, not private Photos bytes, not RAW decoded data, not tone-mapped user assets, and not physical export proof.
- `pure-model-proof`: the draft JPEG is deterministic from saved project/export facts and verified through export/import tests.

### Current proof boundary

- This is a synthetic draft review artifact, not a final renderer.
- It does not read Photos bytes, decode RAW, align images, deghost moving subjects, tone-map user assets, write real HEIF/JPEG/TIFF output bytes from user assets, package Lightroom assets, or prove physical Files export.

### Next slice

- Move into real Photos-backed final output bytes, physical Files document proof, real Photos-backed contact-sheet thumbnails, real Photos-backed side-by-side pixel comparison, or image-bundle byte export under an explicit permission boundary.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 18:08 PDT - May Goals image-bundle draft package v1

### What changed

- Added `BracketProjectImageBundleDraftPackageDocument`, which turns the metadata-only `image-bundle-manifest` into a base64 JSON draft package at `image-bundle-draft-package`.
- The package contains deterministic synthetic per-file payload bytes for every planned processed/RAW entry, plus SHA-256 digests, byte counts, planned filenames, readiness labels, and explicit source boundaries.
- `BracketProjectExportBundle` now emits the draft package immediately after `image-bundle-manifest` and before final-output payloads.
- `BracketProjectImportBundle` validates the optional draft package against the imported image-bundle manifest and rejects tampering through `imageBundleDraftPackageMismatch`.
- Conflict-resolution regeneration now rebuilds the draft package from the keep-both project's resolved image-bundle manifest.
- README, architecture docs, the privacy report, and `.codex-maygoals-progress.md` now disclose the new payload and its non-Photos/non-RAW-resource boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
- First target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-image-bundle-draft-package-tests-1779930370.xcresult test`
  - Result: `STATUS=65`; failed before test execution because new test assertions nested `#require(...)` macros and referenced a missing local decoder. Fixed the test harness and reran.
- Target-level Swift Testing rerun:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-image-bundle-draft-package-tests-1779930418.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - `xcresulttool` summary: `result=Passed`, `passedTests=128`, `failedTests=0`, `skippedTests=0`, `totalTestCount=128`.
  - New executed coverage:
    - `image-bundle-draft-package` payload inclusion and ordering
    - base64 JSON decoding of the draft package
    - synthetic processed/RAW entry generation for planned filenames
    - SHA-256 digest, byte-count, filename, MIME type, redaction, and privacy-boundary checks
    - store-backed import round trip
    - tamper rejection through `BracketProjectImportError.imageBundleDraftPackageMismatch`
    - privacy-report disclosure
- `git diff --check`
  - Result: passed after image-bundle-draft-package code, tests, docs, progress, and ledger updates.

### Proof category

- `draft-package-proof`: project archives now carry deterministic synthetic package bytes for planned selected image/RAW entries.
- `privacy-boundary-proof`: tests and privacy report prove the draft package is not private Photos bytes, not RAW resources, not decoded image data, not filesystem package contents, and not physical export proof.
- `pure-model-proof`: the package is deterministic from saved project/export facts and verified through export/import tests.

### Current proof boundary

- This is synthetic package-byte plumbing, not real image export.
- It does not fetch Photos resources, read image files, decode RAW, preserve actual EXIF/color metadata, write a real filesystem package, export Lightroom-ready assets, or prove physical Files/device behavior.

### Next slice

- Move toward real Photos-backed image payloads, physical Files document proof, real contact-sheet thumbnails, physical Photos resource fetch proof, or a user-visible image-export workspace.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 18:25 PDT - May Goals image-bundle review surface v1

### What changed

- Added a visible selected-project review card at `review.project.imageBundle.card`.
- The restored review handoff now rebuilds `BracketProjectImageBundleManifest` from the saved project, derives the matching `BracketProjectImageBundleDraftPackageDocument` summary, and surfaces:
  - exportable-shot count
  - requested RAW/processed counts
  - draft package entry count
  - first planned filenames
  - the explicit non-Photos/non-RAW-resource boundary
- Moved the draft-package accessibility summary before the long manifest value so VoiceOver/UI tests can reliably read it.
- Updated the focused simulated capture UI test to prove the processed-only HEIF/JPEG project exposes `Draft package 5 synthetic entries`.
- README, architecture docs, and `.codex-maygoals-progress.md` now record the visible selected-project image-bundle surface.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`.
- First focused simulator UI run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-image-bundle-review-card-ui-tests-1779930774.xcresult test`
  - Result: `STATUS=65`; `review.project.imageBundle.card` existed, but the test expected 10 draft entries while the simulator project is processed-only HEIF/JPEG and correctly produces 5 synthetic entries.
- Focused simulator UI rerun:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-image-bundle-review-card-ui-tests-1779930774-fixed.xcresult test`
  - Result: `STATUS=0`; XCTest reported 1 selected UI test passed.
  - New executed coverage:
    - restored project review exposes `review.project.imageBundle.card`
    - card value includes `Image Bundle Manifest`
    - card value includes `5 of 5 exportable`
    - card value includes `Draft package 5 synthetic entries`
    - card value includes the non-Photos boundary text
- `xcresulttool` summary for `/tmp/bracketer-image-bundle-review-card-ui-tests-1779930774-fixed.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after image-bundle review surface code, UI test, docs, progress, and ledger updates.

### Proof category

- `simulator-ui-proof`: restored selected-project review now exposes the image-bundle manifest and draft-package boundary through the full simulated capture/relaunch/handoff path.
- `privacy-boundary-proof`: the visible card repeats that the draft package is not private Photos bytes, not RAW resources, not decoded image data, not a filesystem package, and not physical export proof.

### Current proof boundary

- This is a visible review surface for deterministic bundle-planning facts.
- It does not fetch Photos resources, export real image bytes, decode RAW, preserve actual EXIF/color metadata, write a real filesystem package, or prove physical Files/device behavior.

### Next slice

- Move toward a richer selected-project library route, real Photos-backed image payloads, physical Files document proof, real contact-sheet thumbnails, or physical Photos resource fetch proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 18:41 PDT - May Goals selected-project library search/filter route v1

### What changed

- Added `BracketProjectLibrarySearchRoute`, a deterministic route value composing text queries and smart-collection filters into a privacy-safe project-library summary.
- Added `FileBracketProjectStore.librarySearchRoute(searchText:smartCollectionKind:)` so saved-project search routes resolve through the existing `BracketProjectLibrarySnapshot` instead of a parallel query path.
- Added a dedicated Settings > About library route row and sheet at `settings.projects.library.searchRoute`.
- Added `BracketProjectLibrarySearchProvider` and `QueryBracketProjectsIntent` so Shortcuts can return filtered `BracketProjectEntity` results without opening the camera.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the new route, App Intent, proof boundary, and next-slice options.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-search-route-tests-1779932040.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - New executed coverage:
    - route construction from query plus RAW smart-collection filter
    - result ids, first result, accessibility summary, collection title, and privacy boundary
    - App Intent provider returning filtered `BracketProjectEntity` results
- `xcresulttool` summary for `/tmp/bracketer-library-search-route-tests-1779932040.xcresult`:
  - `result=Passed`
  - `passedTests=128`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=128`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused simulator UI run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-search-route-ui-tests-1779932400.xcresult test`
  - Result: `STATUS=0`; XCTest reported 1 selected UI test passed.
  - New executed coverage:
    - Settings project library exposes `settings.projects.library.searchRoute`
    - route value includes `Project Search Route`
    - route value includes the saved `5-shot simulated bracket`
    - route value includes the no-Photos-local-identifiers boundary
- `xcresulttool` summary for `/tmp/bracketer-library-search-route-ui-tests-1779932400.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after library-search-route code, tests, docs, progress, and ledger updates.

### Proof category

- `pure-model-proof`: library route composition and store-backed snapshot resolution are deterministic and unit-tested.
- `local-sdk-proof`: `BracketProjectLibrarySearchProvider` returns filtered `BracketProjectEntity` values for the AppEntity-backed query intent path against the local SDK.
- `simulator-ui-proof`: the full simulated capture, relaunch, Settings library, and review handoff path exposes the route row and privacy boundary.

### Current proof boundary

- This is a metadata-only saved-project route, not semantic image search.
- It does not prove direct Shortcuts/Siri execution, Spotlight saved-search continuation, physical-device library behavior, or richer facets such as date, lens, location, dynamic range, or output quality.

### Next slice

- Move toward Spotlight saved-search continuation, richer library facets, real Photos-backed image payloads, physical Files document proof, or physical Photos resource proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 18:51 PDT - May Goals project-library facet summary v1

### What changed

- Added `BracketProjectLibraryFacetSummary`, a metadata-only route facet model for saved project libraries.
- Facets summarize captured date range, source counts, lifecycle counts, shot-count range, EV-spread range, RAW project count, dynamic-range candidate count, quality-ready count, final-output blocker count, exported count, and the current lens-unavailable boundary.
- `BracketProjectLibrarySnapshot` now exposes a computed `facetSummary`, and `BracketProjectLibrarySearchRoute` carries that summary into its route/accessibility value.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the facet summary and its boundary.

### Verification

- First generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=65`; compile failed because static facet formatter helpers were referenced without `Self.` inside `BracketProjectLibraryFacetSummary.accessibilityValue`. Fixed the static helper calls and reran.
- Generic simulator build rerun:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-facet-summary-tests-1779933060.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - New executed coverage:
    - facet summaries derive date range, shot-count range, EV-spread range, RAW count, dynamic-range candidate count, quality-ready count, output-blocker count, and lens-unavailable boundary
    - route accessibility includes the facet summary after the privacy boundary
    - facet summaries remain metadata-only and do not claim Photos bytes, thumbnails, semantic scene labels, or physical lens proof
- `xcresulttool` summary for `/tmp/bracketer-library-facet-summary-tests-1779933060.xcresult`:
  - `result=Passed`
  - `passedTests=128`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=128`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after facet-summary code, tests, docs, progress, and ledger updates.

### Proof category

- `pure-model-proof`: facet derivation is deterministic from stored project metadata and unit-tested.
- `privacy-boundary-proof`: facets explicitly avoid Photos local identifiers, image bytes, thumbnails, precise coordinates, semantic scene labels, and physical lens proof.

### Current proof boundary

- These are summary facets only, not filterable UI facets yet.
- Lens remains an explicit unavailable facet until capture metadata persists trustworthy lens descriptions.
- No direct Shortcuts/Siri run or physical-device library proof was collected for this slice.

### Next slice

- Move toward filterable library facets, persisted lens metadata, Spotlight saved-search continuation, real Photos-backed image payloads, physical Files document proof, or physical Photos resource proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 19:04 PDT - May Goals filterable library facets v1

### What changed

- Added `BracketProjectLibraryFacetFilter` and `BracketProjectLibraryFacet`, turning metadata-only facet summaries into selectable saved-library filters.
- `BracketProjectLibrarySnapshot` and `BracketProjectLibrarySearchRoute` now compose text query, smart collection, and facet filter state into one deterministic route.
- Settings > About now renders facet chips at `settings.projects.facetFilters` with per-filter identifiers for RAW availability, dynamic-range candidates, quality-ready projects, final-output blockers, and exported projects.
- `QueryBracketProjectsIntent` now includes a Project Facet parameter, and `BracketProjectLibrarySearchProvider` passes that facet into the store-backed route.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the filterable-facet route contract and privacy boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-facet-filter-tests-1779933600.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - New executed coverage:
    - facet filters derive counts and match projects for RAW, dynamic range, quality readiness, final-output blockers, and exported state
    - route composition preserves query plus smart-collection plus facet-filter result IDs
    - App Intent search provider returns entities through the same facet-aware route
- `xcresulttool` summary for `/tmp/bracketer-library-facet-filter-tests-1779933600.xcresult`:
  - `result=Passed`
  - `passedTests=128`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=128`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-facet-filter-ui-tests-1779933660.xcresult test`
  - Result: `STATUS=0`; XCTest reported `1` selected UI test passed.
  - New executed coverage:
    - restored Settings project library exposes `settings.projects.facetFilters`
    - facet row accessibility includes `Selectable Facets`, `Dynamic Range`, and `Output Blocked`
    - existing route row remains visible after facet-row insertion
- `git diff --check`
  - Result: passed after filterable-facet code, tests, docs, progress, and ledger updates.

### Proof category

- `route-composition-proof`: unit tests compose text search, smart collections, and facet filters through the same snapshot/route/provider path.
- `visible-ui-proof`: focused UI test proves the restored project library now exposes facet chips on simulator.
- `privacy-boundary-proof`: filters derive only from already-stored project metadata and do not read Photos identifiers, image bytes, thumbnails, precise coordinates, semantic scene labels, or physical lens proof.

### Current proof boundary

- Facets are still limited to project metadata already persisted by Bracketer.
- Date, lens, location, camera body, and true optical/lens facets remain incomplete.
- No direct Shortcuts/Siri execution or physical-device library proof was collected for this slice.

### Next slice

- Move toward date/lens/location facet axes, persisted lens metadata, Spotlight saved-search continuation, real Photos-backed image payloads, physical Files document proof, or physical Photos resource proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 19:15 PDT - May Goals captured-date library facets v1

### What changed

- Added `BracketProjectLibraryDateFacet`, a metadata-only captured-day facet model derived from persisted manifest capture timestamps.
- `BracketProjectLibrarySnapshot` and `BracketProjectLibrarySearchRoute` now compose text query, smart collection, selectable project facet, and captured-day filters into one deterministic route.
- Settings > About now renders captured-day chips at `settings.projects.dateFacets` with per-day identifiers such as `settings.projects.dateFacets.1970-01-01`.
- `QueryBracketProjectsIntent` now includes a Captured Day parameter, and `BracketProjectLibrarySearchProvider` passes it into the store-backed route.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the date-facet route contract and privacy boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-date-facet-tests-1779934200.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - New executed coverage:
    - captured-day facets derive counts from persisted manifest timestamps
    - route composition preserves query plus smart-collection plus project-facet plus captured-day result IDs
    - App Intent search provider returns entities through the same captured-day route
- `xcresulttool` summary for `/tmp/bracketer-library-date-facet-tests-1779934200.xcresult`:
  - `result=Passed`
  - `passedTests=128`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=128`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-date-facet-ui-tests-1779934260.xcresult test`
  - Result: `STATUS=0`; XCTest reported `1` selected UI test passed.
  - New executed coverage:
    - restored Settings project library exposes `settings.projects.dateFacets`
    - date row accessibility includes `Captured Date Facets` and the simulated capture day `1970-01-01`
    - existing route row remains visible after date-row insertion
- `xcresulttool` summary for `/tmp/bracketer-library-date-facet-ui-tests-1779934260.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after captured-date facet code, tests, docs, progress, and ledger updates.

### Proof category

- `route-composition-proof`: unit tests compose text search, smart collections, project facets, and captured-day filters through the same snapshot/route/provider path.
- `visible-ui-proof`: focused UI test proves the restored project library now exposes captured-date chips on simulator.
- `privacy-boundary-proof`: date facets derive only from persisted project manifest timestamps and do not read Photos identifiers, image bytes, thumbnails, precise coordinates, semantic scene labels, or physical lens proof.

### Current proof boundary

- Captured-day facets use stored manifest dates, not Photos EXIF reinspection or physical file metadata proof.
- Lens, location, camera body, and true optical facets remain incomplete.
- No direct Shortcuts/Siri execution or physical-device library proof was collected for this slice.

### Next slice

- Move toward lens/location facet axes, persisted lens metadata, Spotlight saved-search continuation, real Photos-backed image payloads, physical Files document proof, or physical Photos resource proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.

## 2026-05-27 19:29 PDT - May Goals persisted lens library facets v1

### What changed

- Added `BracketManifest.CaptureDeviceSnapshot`, a privacy-safe capture-session lens/device summary with logical lens label, camera name, device type, available lens labels, and source, without persisting device unique identifiers.
- Simulated captures now persist a deterministic `1x Simulated Wide Camera` snapshot, and live Photos captures now persist the selected `AVCaptureDevice` lens snapshot into the project manifest.
- Added `BracketProjectLibraryLensFacet`, which derives normalized lens ids from persisted capture-device snapshots and falls back to already-decoded review metadata for older manifests.
- `BracketProjectLibrarySnapshot` and `BracketProjectLibrarySearchRoute` now compose text query, smart collection, selectable project facet, captured day, and lens id into one deterministic route.
- Settings > About now renders lens chips at `settings.projects.lensFacets` with per-lens identifiers such as `settings.projects.lensFacets.1x-simulated-wide-camera`.
- `QueryBracketProjectsIntent` now includes a Lens ID parameter, and `BracketProjectLibrarySearchProvider` passes it into the store-backed route.
- Updated README, architecture docs, and `.codex-maygoals-progress.md` with the lens-facet route contract and the non-EXIF/non-physical-proof boundary.

### Verification

- Generic simulator build:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'generic/platform=iOS Simulator' -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES build`
  - Result: `STATUS=0`, `** BUILD SUCCEEDED **`; App Intents metadata extraction still wrote `Metadata.appintents`.
- Target-level Swift Testing run:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerTests -skip-testing:BracketerUITests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-lens-facet-tests-1779935100.xcresult test`
  - Result: `STATUS=0`; Swift Testing reported `128 tests in 1 suite passed`.
  - New executed coverage:
    - manifests persist capture-device snapshots for simulated/lens fixtures
    - lens facets derive normalized ids and counts from capture-device metadata
    - route composition preserves query plus smart-collection plus project-facet plus captured-day plus lens result IDs
    - App Intent search provider returns entities through the same lens-aware route
- `xcresulttool` summary for `/tmp/bracketer-library-lens-facet-tests-1779935100.xcresult`:
  - `result=Passed`
  - `passedTests=128`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=128`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- Focused UI test:
  - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -configuration Debug -destination 'platform=iOS Simulator,id=BB433905-C31E-4E1A-8F4D-C9D53FFC9D06' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -skip-testing:BracketerTests -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES -resultBundlePath /tmp/bracketer-library-lens-facet-ui-tests-1779935220.xcresult test`
  - Result: `STATUS=0`; XCTest reported `1` selected UI test passed.
  - New executed coverage:
    - restored Settings project library exposes `settings.projects.lensFacets`
    - lens row accessibility includes `Lens Facets` and `Simulated Wide Camera`
    - existing route row remains visible after lens-row insertion
- `xcresulttool` summary for `/tmp/bracketer-library-lens-facet-ui-tests-1779935220.xcresult`:
  - `result=Passed`
  - `passedTests=1`
  - `failedTests=0`
  - `skippedTests=0`
  - `totalTestCount=1`
  - Device: `iPhone 17 Pro`, simulator `BB433905-C31E-4E1A-8F4D-C9D53FFC9D06`, iOS `26.4.1`.
- `git diff --check`
  - Result: passed after persisted lens facet code, tests, docs, progress, and ledger updates.

### Proof category

- `route-composition-proof`: unit tests compose text search, smart collections, project facets, captured-day filters, and lens filters through the same snapshot/route/provider path.
- `visible-ui-proof`: focused UI test proves the restored project library now exposes persisted lens chips on simulator.
- `privacy-boundary-proof`: lens facets derive from saved capture-session metadata or already-decoded review metadata, without Photos identifiers, image bytes, thumbnails, precise coordinates, EXIF reinspection, or physical optical proof.

### Current proof boundary

- Lens facets are persisted capture-session facts, not physical EXIF proof from original files.
- Live device lens labels are only proved by code/build; the visible UI proof uses the simulated capture-device snapshot.
- Location, camera body, true optical validation, and physical-device library proof remain incomplete.
- No direct Shortcuts/Siri execution was collected for this slice.

### Next slice

- Move toward location facet axes, physical lens/EXIF proof, Spotlight saved-search continuation, real Photos-backed image payloads, physical Files document proof, or physical Photos resource proof.

### Goal status

- Goal still open. Verified wave complete. Next wave ready.
