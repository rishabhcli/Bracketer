# Bracketer Architecture

Bracketer is a native SwiftUI camera app built around small deterministic contracts where hardware allows it, and explicit simulator seams where hardware does not.

## Capture

`CameraController` owns the AVFoundation session, permission requests, lens selection, bracket capture, Photos writes, runtime diagnostics, and the transition into review. It keeps live camera behavior separate from UI-test simulation through launch arguments such as `-ui-testing-disable-camera-startup` and `-ui-testing-simulated-camera`.

Capture state is represented by `BracketSequenceState`, so UI can show preparing, capturing, saving, completed, failed, cancelled, and timeout phases without guessing from booleans alone. Live Photos writes report `PhotoSaveResult` values with filename, optional asset identifier, duration, and success state.

## Planning

`BracketPlan` and `BracketSequenceState` are the pure domain layer for exposure sequences. They normalize EV step and shot-count inputs, generate symmetric EV offsets around the requested exposure compensation, label every planned shot, and explain any normalization. Unit tests cover 3, 5, and 7-shot plans plus unsupported inputs.

## Settings

`SettingsStore` persists camera preferences in `UserDefaults` and normalizes values on load and write. The UI binds through `ModernContentView`, `ModernProControls`, and `ModernSettingsPanel`, while tests can reset settings with `-ui-testing-reset-settings` for deterministic state.

## Review

`BracketReviewSequence` is the shared review model for simulated and Photos-backed review. It tracks selected shot, best exposure, missing planned assets, loaded resource type, loaded metadata, RAW/processed representation choice, deletion, and clamping. `SimulatedBracketReview` gives UI tests a fixed bracket review without Photos writes; `ImageViewer` uses the same contract for real Photos assets.

## Manifests

`BracketManifest` is the JSON-ready bracket group snapshot. It combines the resolved `BracketPlan` with the actual `BracketReviewSequence`, preserving source, capture timestamp, shot EVs, asset identifiers, file type, capture state, metadata state, RAW/processed availability, best-exposure markers, and clipping warnings. The app now produces manifests for deterministic simulated review and completed Photos-backed capture sequences, giving future HDR merge, exposure fusion, sidecar metadata, and professional handoff work a stable local contract. Review chrome exposes manifest sharing as JSON separately from photo sharing, so workflow metadata can leave the app without exporting image pixels.

## Exposure Analysis

`HistogramFrameAnalyzer` is the pure analysis core for histogram bins, clipping fractions, zebra regions, and focus-peaking regions. `HistogramProcessor` adapts live camera BGRA buffers into that analyzer, and `PreviewContainer` renders histogram, zebra, and focus-peaking overlays only when the caller enables them.

## Capabilities

`DeviceCapabilitySnapshot` models device and permission readiness before showing the camera. It resolves camera availability, lens availability, flash, ProRAW, Photos add access, location metadata access, notification authorization, storage preflight, and Low Power Mode into blocker or warning issues. Runtime camera failures use the same `DeviceCapabilityIssue` action paths, so launch gating and live alerts stay consistent.

## Observability

`CameraRuntimeDiagnostics` is the structured in-app diagnostics model. It records category, severity, title, detail, optional action path, optional duration, and timestamp. The camera exposes hidden accessibility probes for summary/latest/export values, debug builds expose a Settings/About ShareLink, and review/histogram paths publish their own hidden timing probes. This keeps normal shooting UI clean while preserving inspectable simulator and device evidence.

## Verification

The test suite intentionally prefers pure tests for planning, settings, device capabilities, review, and analysis. UI tests use deterministic launch arguments for camera chrome, denied capability states, simulated capture/review, review fixtures, histogram, zebras, and focus peaking. Physical camera behavior remains a separate proof category because the simulator cannot validate sensor, Photos-library, or real-lens behavior.
