# Bracketer

Bracketer is a native SwiftUI iPhone camera app for bracketed photography. It captures bracketed exposure sequences, provides a camera-focused shooting UI, and includes an in-app review flow for the latest sequence.

## Requirements

- Xcode 26.2 or newer
- iOS 26.2 simulator or device support

## Project layout

- `Bracketer/`: app source
- `BracketerTests/`: unit tests using Swift Testing
- `BracketerUITests/`: UI tests using XCTest
- `Bracketer.xcodeproj/`: Xcode project
- `docs/ARCHITECTURE.md`: capture, planning, settings, review, capability, and observability notes

## Local development

Inspect build settings:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -showBuildSettings
```

Build and test with `xcodebuild`:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

If that simulator is unavailable, discover a local destination with `xcrun simctl list devices available` and rerun using its simulator id:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

Open the project in Xcode:

```sh
open Bracketer.xcodeproj
```

Focused unit bundle:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' \
  -only-testing:BracketerTests \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

Focused deterministic camera-screen UI check:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' \
  -only-testing:BracketerUITests/BracketerUITests/testCameraScreenLaunchesWithStableControls \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

Extract launch-performance metrics from a result bundle:

```sh
xcrun xcresulttool get test-results metrics \
  --path <RESULT-BUNDLE>.xcresult \
  --compact
```

## UI test helpers

The app supports these UI-test launch arguments:

- `-ui-testing-skip-onboarding`: launches directly into the camera screen.
- `-ui-testing-disable-camera-startup`: skips camera and motion startup so UI tests can assert stable chrome without permission or sensor side effects.
- `-ui-testing-reset-settings`: resets persisted camera settings to defaults at launch so UI tests start from a deterministic preference state.
- `-ui-testing-simulated-camera`: uses a deterministic SwiftUI camera preview and simulated bracket review path for UI tests. The harness prepares a fake bracket review after Pro Controls are dismissed and does not write to Photos.
- `-ui-testing-review-fixture`: opens a deterministic in-app image review fixture that exercises the Photos-backed review chrome and `BracketReviewSequence` contract without Photos writes.
- `-ui-testing-show-histogram`: launches with the camera histogram overlay visible so UI tests can assert the Wave F preview-analysis surface without camera startup.
- `-ui-testing-show-zebras`: launches with a deterministic analysis-backed zebra overlay so UI tests can assert clipping regions without camera startup.
- `-ui-testing-show-focus-peaking`: launches with deterministic analysis-backed focus peaking so UI tests can assert edge regions without camera startup.
- `-ui-testing-device-capabilities-photos-denied`: launches the device capability gate with denied Photos add access so UI tests can assert the exact recovery path without changing simulator privacy state.
- `-ui-testing-device-capabilities-no-camera`: launches the device capability gate as if no back camera is available.
- `-ui-testing-force-portrait-layout`: forces the portrait camera chrome branch for deterministic layout-contract UI tests.
- `-ui-testing-force-landscape-layout`: forces the landscape camera chrome branch for deterministic layout-contract UI tests.

App-hosted unit tests also skip camera and motion startup when Xcode provides `XCTestConfigurationFilePath`. Settings UI controls expose stable accessibility identifiers for the category picker, quick presets, viewfinder toggles, grid style, focus peaking state, peaking intensity, and capture badges. Camera chrome exposes stable identifiers and values for layout branch, top/bottom control regions, shooting mode, bracketing step, flash, timer, grid, level, pro controls, shutter, and zoom.

Runtime camera diagnostics expose hidden probe values at `camera.diagnostics.summary`, `camera.diagnostics.latest`, and `camera.diagnostics.export`; these summarize startup, permissions, session, lens, planning, capture, storage, Photos save, review, histogram, and recovery events for device debugging without putting a visible debug panel in the photographer's way. Timed diagnostics append `Duration: <milliseconds> ms` for measured startup, permission, session-configuration, bracket-capture, Photos-save, review image/metadata-load, and histogram-processing phases. Slow Photos saves, review loads, and histogram frame processing are promoted to warning diagnostics through the shared `CameraRuntimePerformanceThresholds` contract. Histogram timing probes are exposed as `camera.histogramDiagnostics.summary` and `camera.histogramDiagnostics.latest`; Photos-backed review timing probes are exposed as `review.diagnostics.summary` and `review.diagnostics.latest`. Debug builds also expose an About-settings diagnostics ShareLink (`settings.diagnostics.shareButton`) backed by the same line-oriented report text.

The histogram overlay exposes `camera.histogramOverlay`, and its Pro Controls switch exposes `pro.histogramToggle`. The zebra overlay exposes `camera.zebraOverlay`, and its Pro Controls switch exposes `pro.zebraToggle`. The focus peaking overlay exposes `camera.focusPeakingOverlay`, and its Pro Controls switch exposes `pro.focusPeakingToggle`. The device capability gate exposes `deviceCompatibility.title`, `deviceCompatibility.status`, `deviceCompatibility.message`, `deviceCompatibility.primaryAction`, and per-issue action identifiers like `deviceCompatibility.issue.photos.denied.action`. The simulated review harness exposes a deterministic bracket sequence with count, timestamp, selected EV, file type, capture state, metadata availability, representation toggle state, best-exposure marker, clipping-warning labels, manifest export (`review.sequence.manifestShareButton`), and delete-confirmation behavior; the simulated shutter path now opens that review after deterministic capture completion instead of requiring the photo-library shortcut. The live review fixture exposes stable identifiers under `review.live.*` for selected EV, position, file type, metadata status, metadata panel, manifest export (`review.live.manifestShareButton`), RAW/processed toggle, previous/next, photo share, and delete controls.

## Review sequence contract

`BracketReviewSequence` is the pure model behind review selection and summary state. It can represent complete and partial bracket sequences, clamps selected indexes, tracks the requested RAW/processed representation, marks missing planned shots, labels metadata availability, identifies the closest-to-zero exposure as the best-exposure candidate, and supports deterministic deletion for UI tests. Simulator-only clipping labels are intentionally named as simulated risk, not physical pixel analysis. The Photos-backed `ImageViewer` accepts the same sequence contract for completed live captures, so EV labels come from the bracket plan and saved asset order instead of positional guesses. When Photos resources and EXIF properties load, the viewer updates the selected shot summary with actual file representation and metadata availability.

## Bracket manifest contract

`BracketManifest` is the local JSON-ready sequence export model for future HDR merge, exposure fusion, deghosting, sidecar metadata, and professional workflow handoff. It snapshots the resolved bracket plan, source, capture timestamp, shot EVs, asset identifiers, file type, capture state, metadata availability, available RAW/processed representations, best-exposure marker, and clipping-warning labels. Simulated review and completed Photos-backed captures both produce a manifest when the app has a deterministic review sequence. Review UI exposes manifest sharing separately from photo sharing, so exporting the bracket recipe does not require exporting pixels.

## Histogram and exposure analysis

`HistogramFrameAnalyzer` is the pure frame-analysis core behind live and still-image histograms. It accepts deterministic RGBA fixtures and camera BGRA pixel buffers, returns normalized RGB/luminance bins, reports sampled highlight/shadow clipping fractions through shared zebra thresholds, builds a compact tile-based zebra map, and derives focus peaking regions from sampled luminance edges. `HistogramProcessor` now delegates camera sample-buffer analysis to this pure core, while `EXIFViewer` uses the same analyzer for still-image mini histograms. Histogram, zebra, and focus peaking overlays are shown only when their callers enable `showHistogram`, `showZebras`, or focus peaking.

## Device capability contract

`DeviceCapabilitySnapshot` is the pure Wave G contract behind app launch gating and recovery copy. It resolves camera availability, lens availability, flash, ProRAW, Photos add access, location metadata access, notification authorization, storage preflight, and Low Power Mode into blocker or warning issues. Runtime camera startup, camera input, Photos add access, and low-storage failures also route through `DeviceCapabilityIssue`-backed `CamError` alerts, so the live session path uses the same exact action paths as the launch gate. Every issue carries an exact action path, for example `Settings > Privacy & Security > Photos > Bracketer > Add Photos Only`, so UI tests can assert recovery guidance without mutating real simulator privacy settings. The normal simulator path fakes hardware and permissions as available unless a `-ui-testing-device-capabilities-*` launch argument asks for a blocked state.

## Settings persistence

`SettingsStore` persists camera preferences through `UserDefaults` and supports an injectable defaults suite for tests. Persisted numeric values are normalized on load and write: focus peaking intensity is clamped to the slider range, EV step is snapped to supported UI steps, and bracket shot count is snapped to 3, 5, or 7.

## Current priorities

This repository is mid-hardening. The current implementation focus is:

- keeping `main` buildable and testable
- making camera controls truthful
- stabilizing lifecycle and review flows
- adding regression coverage before larger refactors
