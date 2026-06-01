# Bracketer Enormous Goal Mode Prompt

Copy the entire prompt below into Codex goal mode from the root of this repository:

```text
You are Codex operating inside /Users/m3-max/Documents/GitHub/Bracketer.

Set your active goal to this:

Transform Bracketer into the most ambitious native iPhone computational photography system imaginable: a professional bracketed-camera, capture-planning, Apple Intelligence-aware, locally generative, privacy-preserving, pro-review, metadata-rich, shortcutable, searchable, testable, and visually exquisite SwiftUI app that treats every bracket sequence as a durable creative object.

This is intentionally enormous. Treat the goal like a 10-year product and research program compressed into a long-running engineering session. The app should become the kind of thing a serious photographer, computational photography engineer, camera nerd, and Apple platform designer could all respect. It should not become a fake AI demo. It should become an honest instrument.

Your practical session budget is about 12 hours, but the ambition is much larger than one session. Make as much durable progress as possible, then leave the next wave ready for immediate continuation. Do not stop after cosmetic edits. Do not drift into generic planning. Inspect, implement, verify, document, and keep moving.

The active goal should remain open unless the entire north star is somehow complete. Most successful sessions should end with:

goal still open, verified wave complete, next slice ready.

Absolute behavioral rules

1. Do not ask the user for permission before ordinary development execution. The user already granted permission.
2. Preserve unrelated user changes. Never revert files or diffs you did not intentionally create.
3. Inspect the live repo before editing. Current code beats old memory and stale docs.
4. Use official Apple documentation as the source of truth for Apple Intelligence, Foundation Models, App Intents, Image Playground, SwiftUI, AVFoundation, Photos, WidgetKit, and platform availability.
5. Do not invent Apple APIs. If an API, entitlement, assistant schema, framework, or simulator behavior is uncertain, verify it locally through the SDK or official docs before building against it.
6. Do not fake AI. If something is simulated, mark it as simulator-only, test-only, preview-only, or prototype-only in code, docs, UI accessibility values, and the ledger.
7. Do not claim real camera verification from a simulator. Simulator proof and physical-device proof are separate categories.
8. Keep the app iPhone-native, SwiftUI-forward, AVFoundation-truthful, and privacy-preserving.
9. Prefer local Apple frameworks and on-device computation over cloud services. Do not add a cloud AI provider unless the user explicitly asks.
10. Every major feature must have a domain model, user-facing behavior, regression tests, docs or ledger notes, and a verification command.
11. Every major UI change must be checked for accessibility identifiers, VoiceOver copy, layout stability, dynamic type risk, safe-area behavior, and screenshot or UI-test evidence.
12. If a test or build fails, diagnose it from logs and fix the root cause. Do not launder failure into success.
13. If the same failure repeats three times, stop repeating the same maneuver. Isolate, instrument, reduce the repro, or change strategy.
14. Favor small vertical slices that compound into a huge system. A slice is only done when it reaches production code, test coverage, docs or ledger, and verification.
15. Keep `BRACKETER_EVOLUTION_LEDGER.md` current. Treat it as the handoff brain for the next 12-hour continuation.

What Bracketer already is

This repository is a native SwiftUI iPhone camera app for bracketed photography.

Important current facts to re-check before acting:

- Source lives in `Bracketer/`.
- Unit tests live in `BracketerTests/` and use Swift Testing.
- UI tests live in `BracketerUITests/` and use XCTest.
- Xcode project is `Bracketer.xcodeproj`.
- The app target is iPhone-first and currently expects modern iOS tooling.
- The app has a SwiftUI entry point in `Bracketer/BracketerApp.swift`.
- The main live camera surface is in `Bracketer/ModernContentView.swift`.
- AVFoundation session, capture, Photos save, runtime diagnostics, and review transition logic live heavily in `Bracketer/CameraController.swift`.
- Settings persistence lives in `Bracketer/SettingsStore.swift`.
- Bracket planning and state live in `Bracketer/BracketSequence.swift`.
- Shared simulated and Photos-backed review state lives in `Bracketer/BracketReviewSequence.swift`.
- Manifest export lives in `Bracketer/BracketManifest.swift`.
- Review UI lives in `Bracketer/ImageViewer.swift` and `Bracketer/SimulatedBracketReview.swift`.
- Histogram, zebras, and focus-peaking analysis route through `Bracketer/HistogramProcessor.swift`, `Bracketer/PreviewContainer.swift`, and related overlay files.
- Device readiness and permission gating route through `Bracketer/DeviceGating.swift`.
- UI design scaffolding exists in `Bracketer/LiquidGlassDesign.swift`, `Bracketer/ModernDesignSystem.swift`, `Bracketer/ModernProControls.swift`, `Bracketer/ContextualControls.swift`, `Bracketer/ModeSwitcherPanel.swift`, `Bracketer/VirtualZoomDial.swift`, and related files.
- Docs exist in `README.md`, `docs/ARCHITECTURE.md`, `plans_Bracketer.md`, and `BRACKETER_EVOLUTION_LEDGER.md`.

Current known strengths to preserve and expand:

- Pure bracket planning with supported shot counts.
- `BracketSequenceState` and deterministic capture progress.
- Simulated camera and deterministic review harnesses.
- Photos-backed review sequence sharing the same model as simulated review.
- Manifest export separate from pixel/photo sharing.
- Histogram, zebra, and focus-peaking analysis through pure analyzers.
- Device capability gates and exact recovery action paths.
- Runtime diagnostics exposed as hidden accessibility probes and debug exports.
- UI test launch arguments for deterministic camera, review, histogram, zebras, focus peaking, capability states, and layout branches.
- A ledger that records waves, verification, failures, and next work.

Current known danger zones:

- Camera APIs and simulator behavior can lie by omission. Be explicit about proof categories.
- SwiftUI accessibility identifiers can be poisoned by container-level modifiers. Verify hierarchy when adding identifiers.
- Long UI refactors can silently create layout overlap, dynamic type breakage, or noninteractive controls.
- Apple Intelligence APIs are availability-gated and evolving. Verify SDK support before coding.
- On-device Foundation Models can be unavailable because device is unsupported, Apple Intelligence is off, or the model is not ready. Build fallbacks.
- Generative features must keep the photographer in control. Never auto-destructively edit captures.
- A camera app that looks cool but cannot be trusted is a regression.

Primary Apple Intelligence source-of-truth memo

Before implementing Apple Intelligence work, refresh official Apple docs and local SDK symbols. As of the current planning pass, the important Apple surfaces are:

- Foundation Models framework: on-device language model at the core of Apple Intelligence, with availability checks, `LanguageModelSession`, structured/guided generation, tool calling, supported language and context-window constraints, and guardrails.
- App Intents framework: system-facing actions and entities for Siri, Spotlight, Shortcuts, widgets, controls, Live Activities, Action button, and Apple Intelligence. Siri and Apple Intelligence integration uses assistant schemas through `AppIntent(schema:)`, `AppEntity(schema:)`, and `AppEnum(schema:)` where the app action genuinely matches the schema.
- App intent domains: choose matching schemas only. Camera domain is directly relevant for camera capture flows. Photos domain may be relevant for bracket assets, albums, opening assets, creating assets, or non-destructive exposure/edit actions if the app truly implements those behaviors.
- CameraCaptureIntent: relevant for camera quick action style integration if the SDK and app architecture support it.
- Making onscreen content available to Siri and Apple Intelligence: relevant for exposing the current bracket group, review shot, metadata, diagnostics, and manifest context to system intelligence when supported.
- Visual intelligence: relevant only if official docs and SDK support make Bracketer's content searchable or actionable there. Do not fake this.
- Image Playground framework: relevant for optional generative visual artifacts such as contact-sheet covers, moodboards, tutorial visuals, bracket-report thumbnails, or non-photographic creative assets, not for claiming real captured pixels were generated by the camera.
- Human Interface Guidelines for Generative AI: keep people in control, provide fallbacks, identify AI output, preserve privacy, avoid harmful assumptions, and offer generative features only where they create clear value.
- Acceptable use requirements for Foundation Models: build a compliant, photography-focused app. Avoid prohibited or regulated uses and avoid trying to bypass guardrails.

Required Apple Intelligence posture

Make Apple Intelligence deeply integrated in the plan and, when feasible, in implementation. Deep integration means system-level and product-level integration, not a novelty chat box.

Apple Intelligence must become all of these over time:

1. A capture planning layer.
2. A photo-review explanation layer.
3. A structured metadata and manifest generation layer.
4. A Siri and Shortcuts action surface.
5. A Spotlight and system search surface.
6. A Control Center, Action button, widget, and Live Activity control surface.
7. A non-destructive generative assistant for learning, organizing, and exporting.
8. A local-first camera coach that can call deterministic tools rather than hallucinating.
9. A graceful optional enhancement that never blocks core camera use when unavailable.
10. A privacy-preserving creative system that treats captured photos as user-owned data.

Apple Intelligence must not become:

- A generic chatbot screen bolted onto the app.
- An unverified assistant that guesses exposure data.
- A cloud dependency.
- A feature that requires Apple Intelligence for basic camera operation.
- A destructive auto-editing system.
- A fake "AI scene engine" whose output is not traceable to local pixels, metadata, settings, or user intent.
- A broad claim that Siri personal context or onscreen awareness works before the SDK, OS, device, and tests prove it.

First mandatory baseline cycle

Do this before making any code change:

1. Run:
   `git status --short --branch`
2. Read:
   `README.md`
   `docs/ARCHITECTURE.md`
   `BRACKETER_EVOLUTION_LEDGER.md`
   `plans_Bracketer.md`
   `Bracketer/BracketerApp.swift`
   `Bracketer/ModernContentView.swift`
   `Bracketer/CameraController.swift`
   `Bracketer/BracketSequence.swift`
   `Bracketer/BracketReviewSequence.swift`
   `Bracketer/BracketManifest.swift`
   `Bracketer/ImageViewer.swift`
   `Bracketer/SimulatedBracketReview.swift`
   `Bracketer/HistogramProcessor.swift`
   `Bracketer/PreviewContainer.swift`
   `Bracketer/DeviceGating.swift`
   `Bracketer/ModernProControls.swift`
   `Bracketer/ContextualControls.swift`
   `Bracketer/ModernSettingsPanel.swift`
   `Bracketer/LiquidGlassDesign.swift`
   `Bracketer/ModernDesignSystem.swift`
   `BracketerTests/BracketerTests.swift`
   `BracketerUITests/BracketerUITests.swift`
3. Discover current schemes:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project Bracketer.xcodeproj`
4. Discover current simulators if README destination is stale:
   `xcrun simctl list devices available`
5. Inspect SDK availability for Apple Intelligence symbols before using them:
   `xcrun --sdk iphoneos swiftc -print-target-info`
   `xcrun --sdk iphonesimulator swiftc -print-target-info`
   `xcrun --sdk iphoneos --show-sdk-path`
   `xcrun --sdk iphonesimulator --show-sdk-path`
6. Search locally before coding:
   `rg -n "FoundationModels|ImagePlayground|AppIntent|AssistantSchemas|CameraCaptureIntent|Visual intelligence|Intelligence|Intent" Bracketer BracketerTests BracketerUITests README.md docs`
7. Run or attempt the current baseline gate:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -showBuildSettings`
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`
8. If that simulator is unavailable, use a discovered simulator UDID:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`
9. Record baseline results in the ledger before and after the first wave.

Core operating loop

Repeat this loop for the whole session:

1. Select the highest-leverage vertical slice from the waves below.
2. State the slice in the ledger with why it matters.
3. Inspect the exact files involved.
4. Implement the smallest complete architecture that can survive future expansion.
5. Add or update pure tests for models and services.
6. Add or update UI tests for user flows, accessibility identifiers, and deterministic harnesses.
7. Update docs and the ledger.
8. Run targeted verification for the slice.
9. Run the full gate when the slice touches shared behavior or UI flows.
10. Keep going into the next slice if the repo is coherent.

Definition of a completed wave

A wave is complete only when all are true:

- Production code is changed or a major repo artifact is created.
- The behavior is grounded in current source, not guesses.
- Tests exist or a clear test gap is documented with why it cannot be automated yet.
- Targeted verification ran.
- Full verification ran if risk warrants it.
- Docs or ledger were updated.
- No unrelated files were reverted.
- The next exact continuation step is recorded.

Verification categories

Use these categories in the ledger and final answer:

- Static repo proof: file inspection, SDK symbol search, build settings, compile checks.
- Pure model proof: Swift Testing unit tests for models, services, planners, analyzers, manifests, prompts, intent data conversions.
- Simulator UI proof: XCTest with deterministic launch args, screenshots, accessibility hierarchy checks.
- Simulator runtime proof: app launches, route works, logs or diagnostics are inspected.
- Physical-device proof: real iPhone camera, permissions, Photos writes, lens switching, ProRAW, real sample buffers, real capture timing.
- System integration proof: Shortcuts, Siri/App Intents, Spotlight, Control Center, widgets, Live Activities, Action button, Image Playground, and Foundation Models availability checks.
- Documentation proof: README, architecture docs, ledger, generated prompt, or migration notes updated.

Do not blend proof categories. "Simulator UI proof" is not "real camera proof."

North-star product identity

Bracketer should feel like:

- The trustworthiness of a pro light meter.
- The speed of the Apple Camera app.
- The control density of Halide, but without copying it.
- The review intelligence of a computational photography lab.
- The system integration of a first-class Apple platform citizen.
- The local privacy posture of a tool a photojournalist could use.
- The generative creativity of Apple Intelligence, but always subordinate to user agency and image truth.

UI north star

The current UI should evolve into a unified pro camera cockpit with:

- A black-first viewfinder that gives pixels the stage.
- Liquid Glass only where it improves legibility, grouping, or touch affordance.
- Controls that are compact, stable, and one-hand reachable.
- A capture mode rail that does not fight the shutter.
- A bracket strip that makes exposure sequence shape visible before capture.
- A live EV ladder that shows center bias and planned offsets.
- A capture progress choreography that communicates hardware truth without drama.
- An intelligent review drawer with EV cards, metadata, histogram, clipping, RAW/processed status, and manifest export.
- A command palette or search surface for power users.
- A settings sheet that feels like an instrument panel, not a preferences junk drawer.
- A diagnostics export that remains hidden from ordinary photographers.
- VoiceOver labels that make the camera usable without sight.
- Dynamic Type support without broken chrome.
- Landscape and portrait layouts that are both first-class.
- No overlapping UI text, no clipped buttons, no magical disabled states, no unlabelled toggles, no invisible assumptions.

Design constraints

- Use native SwiftUI controls and system materials where they fit.
- Use SF Symbols or existing custom icons intentionally.
- Avoid nested card-on-card UI.
- Avoid decorative gradient blobs, random orbs, and fake AI sparkle visual noise.
- Do not make a landing page.
- Do not add visible tutorial paragraphs to the main camera surface.
- Dense controls are fine if they are readable and testable.
- Preserve the photographer's line of sight to the preview.
- Prefer icon buttons with labels/tooltips/accessibility names over verbose control text.
- Keep stable dimensions for controls and overlays so state changes do not resize the camera cockpit.
- Never put hero-scale typography inside compact camera controls.
- If a view can be tested only through accessibility, its identifiers and values must be stable and intentionally named.

Apple Intelligence architecture charter

Build the intelligence layer as a local-first subsystem with clean boundaries:

Suggested modules over time:

- `IntelligenceAvailability.swift`
- `IntelligenceModels.swift`
- `IntelligencePromptLibrary.swift`
- `IntelligenceTools.swift`
- `CaptureCoach.swift`
- `BracketNarrativeGenerator.swift`
- `BracketIntentModels.swift`
- `BracketAppIntents.swift`
- `BracketSpotlightIndex.swift`
- `BracketWidgetIntents.swift`
- `BracketLiveActivity.swift`
- `ImagePlaygroundExports.swift`
- `OnscreenContentProvider.swift`

The exact file names may differ after inspection, but the boundaries matter:

- Availability and fallback state must be separate from UI.
- Prompt construction must be testable and deterministic.
- Generated outputs must be structured Swift values where possible.
- Tools called by the model must be deterministic and unit-tested.
- App Intents must be thin wrappers over domain services.
- The camera controller should not become an AI dumping ground.
- The UI should render intelligence state through small view models or pure display models.

Apple Intelligence availability requirements

Before using Foundation Models:

- Check `SystemLanguageModel.default.availability` where the framework exists.
- Represent reasons like available, device not eligible, Apple Intelligence not enabled, model not ready, locale unsupported, SDK unavailable, simulator unsupported, and unknown.
- Provide user-facing fallback copy in settings or nonintrusive surfaces.
- Never block capture because model availability is false.
- Keep model calls cancellable.
- Handle context window size limits.
- Use concise prompts.
- Split large bracket reports into smaller requests.
- Store only user-approved generated output.
- Never send photo data to a network service.
- Treat generated text as suggestions until the user accepts it.

Foundation Models candidate features

These are candidates, not all first-wave obligations. Pick high-leverage slices.

1. Capture Coach
   - Input: current shooting mode, EV step, shot count, center bias, histogram summary, clipping fractions, lens, flash, timer, grid/level status, capability warnings.
   - Output: structured `CaptureCoachAdvice` with priority, one-sentence recommendation, optional settings change proposal, confidence, reason, and fallback.
   - Tools: deterministic histogram summarizer, bracket plan explainer, capability issue summarizer.
   - UI: small optional coach chip or review card, never a blocking modal.
   - Tests: prompt construction, structured output parsing, fallback when unavailable, no capture dependency.

2. Prompt-to-Bracket Plan
   - User says "high contrast sunset", "interior window", "hold highlights", or "safe for HDR merge".
   - Model suggests EV step, shot count, timer, RAW/processed preference, zebra threshold, and reason.
   - User must confirm before settings change.
   - Always run the suggestion through `BracketPlan` normalization.
   - Tests: prompt fixtures become bounded suggestions, invalid model output cannot escape normalization.

3. Review Narratives
   - After capture, generate a short explanation of the bracket: which shot is central, which shots are highlight/shadow insurance, whether clipping risk appears, what metadata is missing, and what export path fits.
   - Output should be structured, short, and traceable to manifest fields.
   - Tests: no hallucinated metadata, missing shots are called missing, simulated clipping is labelled simulated.

4. Export Notes
   - Generate optional plain-language manifest notes for Lightroom, HDR merge, exposure fusion, or archival workflows.
   - Store in manifest sidecar only after user action.
   - Keep exact JSON schema separate from prose.

5. Search Tags
   - Generate local tags for bracket groups from metadata and user notes.
   - Tags are suggestions and can be deleted.
   - Spotlight indexing should prefer deterministic metadata plus accepted tags.

6. Learning Mode
   - Explain what a bracket sequence means for a beginner.
   - Use the current actual plan, not general camera lore.
   - Keep it out of the main camera cockpit unless requested.

7. Diagnostics Explainer
   - Convert runtime diagnostics into concise troubleshooting copy.
   - Useful in Settings/About, not in the shooting flow.
   - Never hide the raw diagnostics export.

8. Intent Result Snippets
   - For App Intents that run outside the app, return a short static or interactive snippet showing bracket plan, capture status, or last review summary if supported by SDK.

9. Generative Presets
   - User asks for a shooting setup style.
   - Model proposes a named preset object.
   - The deterministic app validates every field.
   - User confirms before applying.

10. Multilingual Camera Help
   - Generate explanations in the user's language if Foundation Models supports it.
   - Fall back to static localized strings when unavailable.

App Intents and Siri charter

Create an App Intents system surface that makes Bracketer feel native to Apple Intelligence.

Start small, but design for growth:

- App entities:
  - `BracketGroupEntity`
  - `BracketShotEntity`
  - `CapturePresetEntity`
  - `CameraLensEntity` or app enum
  - `BracketExportEntity` if useful
- App enums:
  - capture mode
  - bracket shot count
  - EV step
  - representation preference
  - export destination
- App intents:
  - open Bracketer camera
  - open in bracket capture mode
  - start bracket capture if safe and foreground is required
  - prepare a bracket plan
  - switch camera device or lens if supported
  - open latest bracket review
  - export latest bracket manifest
  - show capture readiness
  - apply a saved preset
  - create a bracket report
  - search bracket groups
  - open a specific bracket group
  - explain the last bracket
  - add accepted tags to a bracket group

Use assistant schemas only when they match:

- Camera domain for opening camera functionality, selecting devices, starting capture, stopping capture, or switching device if the implementation matches Apple's schema requirements.
- Photos domain for opening assets, creating assets, album-like workflows, or exposure/edit actions only if Bracketer truly implements those semantics.
- File/document schemas only for manifest or sidecar files if the app genuinely exposes file-like content in a supported way.

Do not force a schema just to look advanced. A custom App Intent without assistant schema is better than a wrong assistant schema.

App Intents implementation rules:

- Keep intents thin.
- Business logic belongs in services or domain models.
- Use a single app routing/handoff path for foreground continuation.
- Add an `AppShortcutsProvider` for the first high-value shortcuts.
- Define stable phrases that reflect actual photographer language.
- Add tests for entity serialization, query results, and intent data mapping where possible.
- If runtime App Intent testing is awkward, at least compile, inspect generated metadata where possible, and document manual Shortcuts validation.
- Do not break existing user shortcuts if migrating existing intents. Prefer adding assistant-only schema-backed intents where appropriate.

Suggested App Shortcuts phrases:

- "Open Bracketer"
- "Start a bracket in Bracketer"
- "Prepare a sunset bracket in Bracketer"
- "Open my last Bracketer sequence"
- "Export my latest Bracketer manifest"
- "Check Bracketer camera readiness"
- "Switch Bracketer to wide"
- "Explain my last Bracketer capture"

Control Center, Action button, widgets, and Live Activities

Over time, Bracketer should offer:

- A Control Center control to open directly into bracket capture.
- An Action button shortcut for opening capture mode or starting a safe foreground capture flow.
- A Lock Screen widget showing capture readiness or last bracket state.
- A Home Screen widget showing last bracket summary or quick presets.
- A Live Activity for an active bracket capture if capture duration and OS rules make it useful.
- App Intent-backed controls that share the same domain models as Siri and Shortcuts.

Live Activity caution:

- Do not create a Live Activity if the bracket capture finishes so quickly that it becomes noisy.
- If implemented, use it for timer countdown, multi-shot progress, save progress, and review-ready handoff.
- Tests must verify state conversion without requiring a real Live Activity runtime.

Spotlight and visual intelligence charter

Make bracket groups discoverable as first-class content:

- Index user-approved bracket groups by title, date, EV spread, lens, file type, accepted tags, and manifest metadata.
- Preserve privacy. Index only local content the app owns or has permission to describe.
- Provide AppEntity display representations that are useful in system search.
- Support "open latest sunset bracket" style flows only when backed by actual searchable metadata.
- If visual intelligence integration is supported by current SDK/docs, expose app content and actions honestly.
- If visual intelligence support is future-only or unavailable, document it as future work and do not fake UI.

Image Playground charter

Use Image Playground only where it creates honest value:

- Generate non-photographic bracket report covers.
- Generate tutorial illustrations explaining EV bracketing.
- Generate moodboard-style preset cards from user-provided concepts.
- Generate contact-sheet decorative covers that are clearly generated.
- Generate shareable learning cards from accepted bracket notes.

Do not use Image Playground to:

- Pretend generated images are captured photos.
- Alter captured images destructively without explicit user action.
- Generate fake photographic evidence.
- Replace real HDR/exposure fusion algorithms.

Computational photography charter

Bracketer's intelligence should sit on top of real computational photography contracts:

- Bracket planning.
- Exposure metadata.
- Real histogram bins.
- Highlight and shadow clipping metrics.
- Focus-peaking edge regions.
- Lens and capability data.
- Photos asset identifiers.
- RAW/processed resource summaries.
- Manifest export.
- Future HDR/exposure fusion previews.
- Future alignment and deghosting.

The app should eventually support:

- Full bracket group identity.
- RAW plus processed pairing.
- Sidecar manifest export.
- Deterministic exposure fusion preview.
- Core Image or Metal tone mapping prototype.
- Alignment metadata and deghosting strategy.
- Lightroom-friendly handoff.
- Professional naming templates.
- Searchable local archive.
- Batch export.
- Comparison view.
- Review scoring.
- User notes.
- AI-generated explanations from verified metadata.

Do not skip the truth layer. Generative text without pixel and metadata truth is just confetti.

Decade-scale roadmap

The backlog below is intentionally huge. It is not expected to finish in one session. Use it as a priority map and keep delivering vertical slices.

Wave 0: Baseline truth and Apple Intelligence feasibility

Goals:

- Establish current build/test state.
- Verify local Xcode and SDK support.
- Determine which Apple Intelligence APIs can compile today.
- Record exact blockers and next files.

Tasks:

- Run baseline commands.
- Read current docs and ledger.
- Search for existing App Intents and intelligence code.
- Check whether `FoundationModels`, `ImagePlayground`, and current App Intents assistant schema symbols are available in the installed SDK.
- Create a short `AppleIntelligenceFeasibility` note in the ledger.
- If APIs are unavailable, build architecture stubs behind compilation guards and document what requires SDK upgrade.

Deliverables:

- Ledger entry with SDK availability.
- A compile-safe direction for the first intelligence slice.
- No production behavior changes unless verified.

Wave 1: Intelligence availability model

Goals:

- Add a durable representation for whether Apple Intelligence features can be used.
- Keep core camera functionality independent.

Tasks:

- Add a pure `IntelligenceFeatureAvailability` model.
- Represent SDK unavailable, framework unavailable, model available, device ineligible, Apple Intelligence off, model not ready, locale unsupported, simulator unknown, and disabled by user.
- Add a service shell that can query Foundation Models availability only behind `canImport(FoundationModels)` and `@available`.
- Add tests for display copy and fallback behavior.
- Add a hidden diagnostics value or Settings/About row showing intelligence availability.

Verification:

- Unit tests for model states.
- Build on simulator.
- UI or accessibility check if Settings copy is surfaced.

Wave 2: Prompt infrastructure and structured outputs

Goals:

- Make future generative features testable.

Tasks:

- Add prompt templates as pure functions.
- Add structured output models:
  - `CaptureCoachAdvice`
  - `BracketPlanSuggestion`
  - `BracketReviewNarrative`
  - `BracketExportNote`
  - `GeneratedPreset`
- Add deterministic validation and normalization after generation.
- Add red-team tests for invalid output, missing fields, unsupported shot counts, invalid EV steps, exaggerated claims, and metadata hallucinations.
- Add no-network assumptions to docs.

Verification:

- Unit tests.
- Build.
- Ledger.

Wave 3: Capture Coach MVP

Goals:

- Add a local optional coach that can explain current capture state from actual data.

Tasks:

- Create deterministic capture-context summary from settings, bracket plan, histogram/clipping state, device capabilities, and diagnostics.
- If Foundation Models is available, produce one structured advice object.
- If unavailable, produce deterministic static advice from rules.
- Add UI as a small dismissible coach chip or review card.
- Add setting to hide/show coach.
- Keep all camera operations usable without the coach.

Verification:

- Unit tests for context summary.
- Unit tests for fallback advice.
- UI tests for hidden/visible coach state.
- Build and targeted UI run.

Wave 4: Prompt-to-bracket plan

Goals:

- Let the user describe a scene and receive a safe bracket setup suggestion.

Tasks:

- Add a text input surface in Pro Controls or a dedicated sheet.
- Suggested UI name: "Plan".
- Accept short scene descriptions.
- Return EV step, shot count, RAW/processed preference, timer suggestion, and reason.
- User must confirm before applying.
- Validate through `BracketPlan` and `SettingsStore`.
- Add examples like sunset, interiors, backlit subject, night street, snow, concert, window view.

Verification:

- Unit tests for validation.
- UI tests with fake generated responses.
- No real model dependency in UI tests.

Wave 5: Siri and Shortcuts foundation

Goals:

- Expose Bracketer to system actions.

Tasks:

- Add App Intents target or module shape if not present.
- Add first AppShortcut: open Bracketer camera.
- Add open latest review intent.
- Add export latest manifest intent if a manifest exists.
- Add capture readiness intent returning a short result.
- Add app routing handoff in app root.
- Keep intent logic thin.

Verification:

- Build.
- Unit tests for routing targets and data conversion.
- Manual Shortcuts instructions in ledger if runtime validation cannot be automated.

Wave 6: Camera assistant schemas

Goals:

- Integrate camera actions with Siri and Apple Intelligence through correct assistant schemas where possible.

Tasks:

- Verify current Apple camera app intent domain symbols and requirements in the installed SDK.
- Add schema-backed intents only for matching behaviors:
  - open in capture mode
  - start capture
  - stop capture
  - switch/set device
- Use `CameraCaptureIntent` where it fits the app's quick-action behavior and SDK rules.
- Require foreground continuation when real camera permission, UI state, or user confirmation is needed.
- Add stable user-facing phrases.

Verification:

- Compile.
- App Intents metadata or Shortcuts visibility if possible.
- Ledger with exact schema choices and rejected schemas.

Wave 7: Bracket entities and Spotlight

Goals:

- Make bracket groups durable and searchable.

Tasks:

- Define a local bracket group identity separate from Photos asset identity.
- Add persisted metadata store if current app lacks one.
- Create `BracketGroupEntity` and `BracketShotEntity`.
- Index accepted bracket groups into Spotlight where supported.
- Support open group from system search.
- Keep privacy controls.

Verification:

- Unit tests for entity display, query, and persistence.
- Build.
- Manual Spotlight validation if possible.

Wave 8: Review Narratives

Goals:

- Give every bracket sequence a concise, truthful explanation.

Tasks:

- Build `BracketNarrativeContext` from manifest and review sequence.
- Generate or fallback to a structured summary:
  - what was captured
  - exposure spread
  - best exposure candidate
  - clipping risks
  - missing shots
  - RAW/processed availability
  - export advice
- Add review UI card with "generated" labeling only when generated.
- Let user regenerate, dismiss, or save note.

Verification:

- Unit tests for no hallucinated metadata.
- UI tests using deterministic fixture.
- Build.

Wave 9: Manifest sidecar 2.0

Goals:

- Turn manifest into a professional exchange format.

Tasks:

- Version the manifest schema carefully.
- Add optional generated notes, accepted tags, capture context, histogram summary, clipping summary, lens/capability snapshot, and provenance.
- Preserve backward compatibility with schema version 1.
- Add JSON schema doc or sample.
- Add import/read tests.

Verification:

- Unit tests for old/new manifests.
- Snapshot JSON tests if project style allows.
- Docs.

Wave 10: Intelligent review workspace

Goals:

- Make review mode a real analysis surface.

Tasks:

- Add a bracket filmstrip with EV labels and state.
- Add side-by-side compare or before/after scrub.
- Add histogram per shot.
- Add clipping and focus summaries.
- Add metadata panel with lens, ISO, shutter, aperture, pixel size, format, and asset id.
- Add manifest/note export.
- Add "explain" generated card from Wave 8.

Verification:

- UI tests for live fixture.
- Unit tests for review view models.
- Screenshot evidence.

Wave 11: UI cockpit redesign

Goals:

- Make the camera UI dramatically better without losing truth.

Tasks:

- Audit current top bar, bottom controls, Pro Controls, zoom dial, settings, mode switcher, and overlays.
- Redesign around:
  - viewfinder
  - bracket strip
  - lens rail
  - EV ladder
  - shutter cluster
  - pro drawer
  - lightweight coach chip
  - review handoff
- Use Liquid Glass sparingly and correctly.
- Avoid text overlap.
- Make portrait and landscape first-class.
- Add stable dimensions.
- Add accessibility identifiers and VoiceOver labels.

Verification:

- UI tests for portrait and landscape layout contracts.
- Screenshot capture.
- Build.

Wave 12: Settings architecture polish

Goals:

- Make settings feel like a professional instrument panel.

Tasks:

- Split settings into focused sections:
  - Capture
  - Bracket
  - Review
  - Intelligence
  - Export
  - Diagnostics
  - Privacy
- Add an Intelligence section with availability, enabled toggles, privacy copy, and fallbacks.
- Keep controls dense, not marketing-like.
- Add reset and import/export if useful.

Verification:

- Unit tests for settings persistence.
- UI tests for settings categories and toggles.

Wave 13: Generative presets

Goals:

- Let users create local, explainable shooting presets.

Tasks:

- Define `CapturePreset`.
- Support deterministic built-in presets.
- Add generated presets from short descriptions only if validated.
- Store user-approved presets.
- Expose presets to App Intents and widgets.
- Add import/export.

Verification:

- Unit tests.
- UI tests.
- App Intents compile.

Wave 14: Control Center and Action button

Goals:

- Make Bracketer launch and prepare capture from system surfaces.

Tasks:

- Add App Intent-backed controls if SDK supports.
- Add quick actions:
  - Open Bracketer capture
  - Open last review
  - Check readiness
  - Apply preset
- Ensure camera starts only in appropriate foreground context.
- Document setup in README.

Verification:

- Compile.
- Manual setup notes.
- App routing unit tests.

Wave 15: Widgets

Goals:

- Add glanceable system surfaces.

Tasks:

- Add widgets:
  - last bracket summary
  - capture readiness
  - favorite preset launcher
  - quick manifest export status
- Use App Intents for configuration.
- Avoid leaking sensitive image thumbnails unless user opts in.

Verification:

- Widget extension build.
- Snapshot or preview tests where possible.
- Docs.

Wave 16: Live Activity

Goals:

- Represent active bracket capture progress outside the app only if useful.

Tasks:

- Add ActivityKit model for capture states.
- Start for timer or long capture flows only.
- Update shot index and save progress.
- End with review-ready handoff.
- Disable when capture is too short or user opts out.

Verification:

- Unit tests for state mapping.
- Simulator/manual proof if supported.

Wave 17: Onscreen content for Siri and Apple Intelligence

Goals:

- Let system intelligence understand current in-app content when official APIs support it.

Tasks:

- Expose current review bracket group as app entity or user activity.
- Include safe fields:
  - group id
  - date
  - EV range
  - selected shot
  - metadata availability
  - user-approved notes
  - manifest summary
- Do not expose raw image data without explicit user action.
- Verify SDK and OS support.

Verification:

- Compile.
- Manual Siri/onscreen validation if possible.
- Ledger.

Wave 18: Image Playground artifacts

Goals:

- Add delightful but honest generated visuals.

Tasks:

- Add a tutorial card generator or bracket-report cover generator.
- Use Image Playground system UI or programmatic interface only when available.
- Label generated images.
- Store only on user confirmation.
- Keep this separate from captured photo review.

Verification:

- Compile under availability guards.
- Unit tests for artifact metadata.
- Manual proof if simulator/device supports.

Wave 19: Advanced histogram and waveform

Goals:

- Make exposure analysis more pro.

Tasks:

- Add luminance waveform.
- Add RGB parade.
- Add false-color exposure overlay.
- Add IRE-like normalized scale if appropriate.
- Add thresholds and legends.
- Ensure sample buffer cost is measured.

Verification:

- Pure pixel fixture tests.
- Performance diagnostics.
- UI tests for launch args.

Wave 20: Exposure fusion preview

Goals:

- Create a truthful local computational preview from bracket sequences.

Tasks:

- Define fusion input model.
- Start with deterministic Core Image or CPU prototype.
- Align only if feasible.
- Add tone mapping controls.
- Label preview as preview, not final HDR.
- Export result only on user action.

Verification:

- Fixture image tests.
- Performance measurement.
- Docs.

Wave 21: Alignment and deghosting research

Goals:

- Prepare for robust handheld brackets.

Tasks:

- Add motion metadata capture where available.
- Add feature matching prototype.
- Add simple alignment metrics.
- Add deghosting risk estimate.
- Keep all outputs explainable.

Verification:

- Synthetic fixture tests.
- Performance notes.

Wave 22: RAW and processed pairing

Goals:

- Make professional asset handling precise.

Tasks:

- Map RAW and processed pairs per shot.
- Preserve asset identifiers.
- Detect missing pairs.
- Expose representation toggles.
- Export sidecar metadata.

Verification:

- Unit tests for pair mapping.
- Photos-backed fixture where possible.

Wave 23: Archive and library

Goals:

- Turn captured bracket groups into a local library.

Tasks:

- Add a persistent bracket group store.
- Add local thumbnails if privacy allows.
- Add search, filters, tags, favorites, notes.
- Integrate Spotlight.
- Add backup/export.

Verification:

- Persistence tests.
- UI tests.

Wave 24: Professional export suite

Goals:

- Make Bracketer useful after capture.

Tasks:

- Export manifest JSON.
- Export sidecar text notes.
- Export contact sheet.
- Export selected images.
- Export generated report.
- Add share flows with clear privacy controls.
- Add naming templates.

Verification:

- Unit tests for filenames and manifests.
- UI tests for share affordances without opening ambiguous share sheets where possible.

Wave 25: Privacy and trust center

Goals:

- Make local intelligence and permissions understandable.

Tasks:

- Add a Privacy settings section.
- Explain what stays on device.
- Show Apple Intelligence availability and model use.
- Let users disable generated features.
- Show Photos, location, notifications, and indexing settings.
- Export diagnostics without photo pixels.

Verification:

- UI tests.
- Docs.

Wave 26: Accessibility excellence

Goals:

- Make the app usable with VoiceOver, Dynamic Type, Switch Control, and reduced motion.

Tasks:

- Audit all controls.
- Add accessibility labels, values, hints, traits.
- Keep identifiers separate from labels.
- Add UI tests that assert key labels/values.
- Add reduced-motion alternatives for capture progress.
- Avoid relying on color alone for clipping/peaking.

Verification:

- UI tests.
- Manual simulator accessibility inspection if possible.

Wave 27: Performance and thermal discipline

Goals:

- Keep camera work fast and cool.

Tasks:

- Add timing around startup, session config, frame analysis, capture, Photos save, review load, model calls.
- Budget histogram and model calls.
- Back off analysis when thermal state or low power mode warrants it.
- Add diagnostics for dropped analysis frames.
- Use ETTrace/Instruments if available.

Verification:

- Unit tests for thresholds.
- Runtime diagnostics.
- Performance traces where possible.

Wave 28: Reliability torture

Goals:

- Make failure paths boring and recoverable.

Tasks:

- Simulate permissions denied, Photos denied, low storage, no camera, unavailable lens, failed save, failed metadata load, model unavailable, context exceeded, shortcut routing failure.
- Add UI tests for exact recovery copy.
- Add retry paths.
- Keep capture state from getting stuck.

Verification:

- Unit and UI tests.
- Ledger.

Wave 29: Documentation and CI

Goals:

- Keep the repo runnable by future agents and humans.

Tasks:

- Update README commands.
- Document Apple Intelligence availability.
- Document App Intents and system surfaces.
- Document launch arguments.
- Document physical device verification steps.
- Improve CI if present.
- Add a "current frontier" section to architecture docs.

Verification:

- Docs diff review.
- CI config syntax if touched.

Wave 30: Product polish pass

Goals:

- Make the entire app feel cohesive.

Tasks:

- Remove stale aspirational copy.
- Remove fake or unused surfaces.
- Tighten naming.
- Audit colors and typography.
- Audit haptics.
- Audit onboarding.
- Audit first-run permission education.
- Audit empty states.
- Audit review handoff.

Verification:

- Build.
- UI tests.
- Screenshots.

Priority scoring rubric

When choosing the next slice, score each candidate 1 to 5:

- Photographer value.
- Truthfulness improvement.
- Testability improvement.
- Apple Intelligence/system integration leverage.
- UI polish leverage.
- Risk containment.
- Time fit.

Pick the candidate with the highest combined value that can be completed as a vertical slice. Do not pick a huge architectural rewrite if a smaller, compounding slice is better.

Recommended first implementation slice

Start with Wave 0 and Wave 1:

1. Verify current repo state and SDK support.
2. Add a compile-safe intelligence availability model.
3. Surface it in a hidden diagnostics or Settings/About area.
4. Add unit tests.
5. Update docs and ledger.

Why this first:

- It enables every future Apple Intelligence feature.
- It prevents fake claims.
- It is testable without relying on a real model.
- It gives the UI a truthful foundation.
- It creates a safe seam for future Foundation Models, App Intents, Image Playground, and Siri work.

Recommended second slice

Implement the prompt infrastructure for capture advice:

1. Add pure capture context summary.
2. Add structured advice model.
3. Add fallback deterministic advice.
4. Add tests for no hallucinated metadata.
5. Add a minimal UI readout only if the model is ready.

Recommended third slice

Add the first App Intent:

1. Open Bracketer camera.
2. Open latest review.
3. Export latest manifest.
4. Route through one app handoff path.
5. Compile and document manual Shortcuts validation.

Recommended fourth slice

Redesign the camera cockpit around an EV ladder and bracket strip:

1. Use current `BracketPlan`.
2. Show planned offsets before capture.
3. Show live progress during capture.
4. Preserve top/bottom controls.
5. Add identifiers and UI tests.

Detailed implementation patterns

Availability service pattern:

- Define a pure enum that does not import Foundation Models.
- Add a framework adapter in a separate file that imports Foundation Models only under guards.
- Inject availability into UI so tests can fake it.
- Keep display copy in one formatter.
- Add unit tests for every enum case.

Prompt pattern:

- Prompt builders should accept pure context structs.
- Prompts should be short and specific.
- Generated result models should be bounded.
- Every generated setting must pass deterministic validation.
- Keep a raw generation debug string only in diagnostics if useful.
- Do not store prompts that include sensitive data unless user opts in.

Tool-calling pattern:

- Tools should expose deterministic app functions to the model.
- Candidate tools:
  - summarize bracket plan
  - summarize histogram
  - summarize clipping
  - summarize capability blockers
  - summarize review sequence
  - validate preset
  - lookup last manifest
- Every tool should have unit tests.
- The model should call tools to retrieve facts rather than invent facts.

UI pattern:

- Camera cockpit is the primary surface.
- Intelligence is a layer, not a destination.
- Capture advice belongs in compact chips, optional sheets, or review cards.
- Generated notes belong in review/export.
- Settings controls should include toggles for generative features.
- Disabled AI states should have quiet, truthful copy.

Testing pattern:

- Unit-test every pure model.
- UI-test every new visible flow through launch-argument fakes.
- Do not depend on real Foundation Models in CI.
- Add fake intelligence responses for UI tests.
- Add availability fakes for every unavailable state.
- Keep accessibility values precise enough for tests.

Documentation pattern:

- README gets commands and user-facing setup notes.
- Architecture docs get subsystem design.
- Ledger gets exact wave evidence.
- If App Intents are added, docs get manual validation steps.
- If Apple Intelligence APIs are guarded by SDK availability, docs say that clearly.

Concrete file search checklist before each wave

Run targeted searches like:

- `rg -n "BracketPlan|BracketSequenceState|BracketReviewSequence|BracketManifest" Bracketer BracketerTests`
- `rg -n "HistogramFrameAnalyzer|zebra|focusPeaking|clipping|waveform" Bracketer BracketerTests`
- `rg -n "DeviceCapability|CamError|runtimeDiagnostics|CameraRuntimeDiagnostic" Bracketer BracketerTests`
- `rg -n "accessibilityIdentifier|review.live|review.sequence|camera.chrome|settings." Bracketer BracketerUITests README.md`
- `rg -n "AppIntent|AppEntity|AppShortcutsProvider|Widget|Activity|Spotlight|CSSearchable" Bracketer`
- `rg -n "FoundationModels|LanguageModelSession|SystemLanguageModel|ImagePlayground|ImageCreator" Bracketer`

Current UI-test launch arguments to preserve and expand

Re-check README for the current list. Preserve existing arguments and add new ones only with docs and tests:

- `-ui-testing-skip-onboarding`
- `-ui-testing-disable-camera-startup`
- `-ui-testing-reset-settings`
- `-ui-testing-simulated-camera`
- `-ui-testing-review-fixture`
- `-ui-testing-show-histogram`
- `-ui-testing-show-zebras`
- `-ui-testing-show-focus-peaking`
- `-ui-testing-device-capabilities-photos-denied`
- `-ui-testing-device-capabilities-no-camera`
- `-ui-testing-force-portrait-layout`
- `-ui-testing-force-landscape-layout`

Possible new launch arguments:

- `-ui-testing-intelligence-available`
- `-ui-testing-intelligence-unavailable-device`
- `-ui-testing-intelligence-unavailable-disabled`
- `-ui-testing-intelligence-model-not-ready`
- `-ui-testing-generated-capture-advice`
- `-ui-testing-generated-review-narrative`
- `-ui-testing-app-intent-route-latest-review`
- `-ui-testing-app-intent-route-capture`
- `-ui-testing-spotlight-open-bracket`
- `-ui-testing-image-playground-unavailable`

Only add these as actual arguments when production code and tests use them.

Specific UI improvements to pursue

Camera screen:

- Add a compact bracket strip above or around the shutter showing `-2 -1 0 +1 +2` style offsets.
- Show center bias separately from bracket spread.
- Show capture progress as the strip fills shot by shot.
- Add a subtle "saving" state with count.
- Add a clear cancel affordance during countdown/capture when safe.
- Add a review-ready gesture or button after completion.
- Show current representation mode and RAW availability truthfully.
- Make lens rail state explicit and disabled when unavailable.
- Improve landscape layout so controls do not crowd the preview.

Pro controls:

- Group exposure, focus, analysis, capture, and intelligence controls.
- Use segmented controls for EV step and shot count.
- Use sliders for peaking intensity and zebra threshold.
- Use icons for toggles with accessibility labels.
- Add a "Plan" action for prompt-to-bracket suggestions.
- Add a "Coach" toggle if implemented.

Review:

- Make the bracket sequence feel like a timeline.
- Add per-shot chips.
- Add selected shot summary.
- Add histogram and clipping card.
- Add metadata card.
- Add AI explanation card when available.
- Add manifest export.
- Add generated report export.
- Add delete confirmation.
- Add RAW/processed truth labels.

Settings:

- Add Intelligence section.
- Add Privacy section.
- Add Diagnostics section.
- Add export and manifest preferences.
- Keep controls compact.
- Make reset and defaults safe.

Onboarding:

- Avoid a marketing splash.
- Teach only required concepts:
  - camera permission
  - Photos add-only permission
  - bracket capture basics
  - optional Apple Intelligence
  - privacy
- Keep skip paths for UI tests.

Haptics:

- Capture start, shot captured, sequence complete, warning, and review ready should feel distinct.
- Do not overuse haptics.
- Respect system settings.

Sound:

- Do not add custom shutter sounds unless legal/platform constraints are understood.

Data model dreams

A future `BracketGroup` should eventually contain:

- stable id
- creation date
- source
- plan
- actual shots
- capture settings
- lens
- device capability snapshot
- histogram summaries
- clipping summaries
- motion/orientation hints
- Photos asset identifiers
- RAW/processed pair mapping
- user notes
- accepted generated notes
- accepted tags
- manifest version
- export history
- Spotlight index state
- privacy flags

A future `BracketShot` should eventually contain:

- stable id
- group id
- index
- EV offset
- center-bias-adjusted EV
- planned label
- asset identifier
- resource summary
- metadata summary
- histogram summary
- clipping summary
- focus summary
- preview thumbnail reference
- state: planned, captured, missing, failed, deleted

A future `CapturePreset` should eventually contain:

- id
- title
- source: built-in, user, generated
- EV step
- shot count
- center bias
- RAW/processed preference
- timer
- grid/level preferences
- analysis overlays
- intelligence setting
- explanation
- created date
- last used date

Safety and privacy constraints

- Captured photos remain user-owned.
- Do not upload images.
- Do not add analytics SDKs.
- Do not expose raw Photos asset identifiers unnecessarily in visible UI.
- Do not index private notes unless the user opts in.
- Do not store generated content silently.
- Do not imply generated output is fact.
- Do not make regulated claims.
- Do not classify people or sensitive attributes.
- Do not identify people in photos.
- Do not bypass Apple guardrails.

Failure handling requirements

Every subsystem should fail gracefully:

- Camera unavailable: exact recovery action.
- Photos add denied: exact recovery action.
- Low storage: exact recovery action.
- Flash unavailable: disabled state.
- RAW unavailable: truthful fallback.
- Model unavailable: deterministic fallback.
- Model context exceeded: shorter prompt retry or fallback.
- Intent cannot run in background: foreground continuation.
- Spotlight indexing unavailable: local search fallback.
- Widget data unavailable: placeholder without leaking details.
- Image Playground unavailable: hide generator or show unavailable state.
- Live Activity unavailable: in-app progress only.

Testing matrix over time

Pure model tests:

- Bracket planning.
- Settings normalization.
- Capability resolution.
- Diagnostics formatting.
- Manifest encoding.
- Review sequence selection/deletion.
- Histogram bins.
- Zebra regions.
- Focus peaking.
- Intelligence availability.
- Prompt construction.
- Generated output validation.
- App Intent entity mapping.
- Spotlight model mapping.
- Widget state mapping.
- Live Activity state mapping.

UI tests:

- Launch camera.
- Launch denied capability.
- Launch histogram.
- Launch zebra.
- Launch focus peaking.
- Open settings.
- Change presets.
- Open Pro Controls.
- Change EV step.
- Change shot count.
- Simulated capture completes.
- Review fixture shows live chrome.
- Manifest export button exposes JSON.
- Intelligence unavailable settings row.
- Capture coach chip hidden/visible.
- Generated review narrative fixture.
- Portrait and landscape layouts.

Manual device tests:

- First-run camera permission.
- Photos add-only permission.
- Lens switching.
- ProRAW availability.
- Real bracket capture.
- Real Photos save.
- Real review loading.
- Real metadata.
- Real histogram preview.
- Real thermal behavior.
- Real App Shortcuts invocation.
- Real Siri invocation if available.
- Real Control Center and Action button if configured.
- Real Image Playground if available.
- Real Foundation Models availability.

Full verification gate

Run the broadest supported gate before claiming a major wave is complete:

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Bracketer.xcodeproj -scheme Bracketer -showBuildSettings`
2. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`
3. If unavailable, use:
   `xcrun simctl list devices available`
   then:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`
4. Run focused unit tests after model changes.
5. Run focused UI tests after visible behavior changes.
6. Run `git diff --check`.
7. Inspect failure logs and `.xcresult` bundles if wrappers time out.
8. Capture screenshots for major UI work when feasible.

Suggested focused commands

Unit bundle:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -only-testing:BracketerTests -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`

Camera launch UI:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -only-testing:BracketerUITests/BracketerUITests/testCameraScreenLaunchesWithStableControls -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`

Simulated capture UI:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`

Review fixture UI:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -only-testing:BracketerUITests/BracketerUITests/testDeterministicImageReviewFixtureExposesLiveChromeContract -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`

Camera chrome layout UI:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Bracketer.xcodeproj -scheme Bracketer -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -only-testing:BracketerUITests/BracketerUITests/testCameraChromeExposesPortraitAndLandscapeContracts -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO`

Ledger format

Append entries like:

## YYYY-MM-DD HH:MM local - Wave name

### Intent

- What this wave tried to improve.

### Changes

- Files changed.
- Models added.
- UI changed.
- Tests added.

### Verification

- Exact commands.
- Pass/fail.
- Result bundle paths if present.

### Proof category

- Static repo proof.
- Pure model proof.
- Simulator UI proof.
- Physical-device proof.
- System integration proof.

### Known limitations

- What remains unverified.
- What requires physical device.
- What requires newer SDK.

### Next slice

- Exact next file to inspect.
- Exact next command.
- Best next vertical slice.

Final response format when you stop

Keep it high signal:

- What changed.
- What passed.
- What failed or was blocked, with exact command and error.
- What remains next.
- Whether the active goal is complete or intentionally open.

Never call the whole north-star goal complete unless every meaningful backlog class is done and every local verification gate passes. That should be rare.

Important mental model

Bracketer is not "camera plus AI." Bracketer is "a truthful computational photography instrument whose system intelligence can understand, explain, route, and help with the work because the app itself has clean models."

When in doubt, build the model. Then the UI. Then the intent. Then the generated helper. Then the tests. Then the docs.

Now begin.
```

