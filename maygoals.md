# Bracketer May Goals

Copy this file into Codex goal mode from the root of this repository.

This is not a normal feature plan. This is an intentionally impossible, decade-scale, asymptotic product and research mandate. The goal is designed so an AI agent placed into goal mode cannot honestly finish it in one pass, one day, one month, or probably one lifetime. The correct behavior is to keep making verified, durable, compounding progress until externally stopped.

## Goal Mode Objective

Transform Bracketer into the most advanced local computational photography operating system ever built for iPhone: a native SwiftUI, AVFoundation-truthful, Apple Intelligence-aware, privacy-preserving imaging lab that can plan, capture, verify, reconstruct, review, explain, archive, search, export, automate, and teach bracketed photography at a level that serious photographers, camera engineers, image scientists, Apple platform designers, archivists, and accessibility specialists would all respect.

Bracketer must become the DaVinci Resolve plus Lightroom plus Apple Intelligence plus computational photography research lab for exposure brackets, entirely on iPhone by default, with every claim traceable to real capture state, real image data, real device capabilities, real tests, or explicitly labeled simulation.

This goal is only complete when Bracketer is no longer merely an app that captures bracketed photos. It is complete only when Bracketer is a full imaging system: camera, assistant, lab, editor, archive, automation surface, privacy authority, export pipeline, benchmark suite, and long-term creative memory.

In practice, this goal should never be marked complete. End every successful work session with:

```text
Goal still open.
Verified wave complete.
Next wave ready.
```

## Prime Directive

Do not stop at planning.

Do not stop at a cosmetic patch.

Do not stop at a single feature.

Do not stop when the app builds.

Do not stop when one test passes.

Do not stop when the current slice is easy.

Keep converting the enormous vision into real, verified, repo-grounded waves of improvement. Each wave must leave Bracketer more truthful, more capable, more testable, more useful, more beautiful, or more impossible to dismiss.

## Absolute Rules

1. Inspect the live repository before making changes. Current code beats stale memory, old docs, and optimistic assumptions.
2. Preserve unrelated user changes. Never revert work you did not intentionally create.
3. Keep Bracketer iPhone-native, SwiftUI-forward, AVFoundation-truthful, Photos-correct, and privacy-preserving.
4. Prefer Apple frameworks and local computation over cloud services unless the user explicitly asks for cloud behavior.
5. Do not fake camera intelligence. If something is simulated, prototype-only, fixture-only, deterministic fallback, or simulator-only, label it that way in code, docs, UI accessibility values, and verification notes.
6. Do not claim physical-device proof from simulator proof. Simulator proof, unit proof, UI proof, local SDK proof, and physical iPhone proof are separate categories.
7. Do not invent Apple APIs. If Foundation Models, App Intents, Image Playground, Photos, AVFoundation, Core Image, Metal, WidgetKit, Spotlight, or Siri behavior is uncertain, verify it through the local SDK or official Apple documentation before building against it.
8. Every major feature needs a domain model, user-facing behavior, tests, docs or ledger notes, and a verification command.
9. Every major UI change needs accessibility identifiers, VoiceOver-sensitive copy, dynamic type consideration, safe-area sanity, layout stability, and screenshot or UI-test evidence where feasible.
10. Every image-processing claim must be backed by actual pixels, deterministic fixtures, physical captures, or explicitly labeled research/prototype status.
11. Every generative output must disclose source, fallback reason, data boundary, and whether Apple Intelligence or deterministic fallback produced it.
12. Every export must preserve provenance. Users must be able to understand what was captured, what was generated, what was inferred, what was edited, and what was never inspected.
13. Every recovery path must tell the photographer what happened and what to do next.
14. Keep normal shooting fast and clean. Advanced intelligence belongs in compact, optional, inspectable surfaces, not noisy modal theater.
15. If a build or test fails, diagnose logs and fix the root cause. Do not launder failures into success.
16. If the same failure repeats three times, stop repeating the same maneuver. Isolate, instrument, reduce the repro, or change strategy.
17. If blocked by hardware, signing, SDK availability, entitlements, device access, or simulator instability, make the blocker concrete and leave a runnable continuation plan.
18. Never mark the impossible goal complete unless the entire imaging operating system exists, is verified, is documented, and has real-device proof.

## Existing Foundation To Respect

Bracketer already has important seeds. Build on them rather than replacing them casually.

- `CameraController` owns AVFoundation session behavior, permissions, lens selection, bracket capture, Photos writes, runtime diagnostics, and review transition.
- `BracketPlan`, `BracketShot`, `BracketSequenceState`, and `BracketReviewSequence` are the pure domain anchors for planning, capture state, and review state.
- `BracketManifest` is the JSON-ready contract for a bracket group.
- `BracketManifestSidecar` is the beginning of generated-note, provenance, clipping, and context export.
- `HistogramFrameAnalyzer`, `HistogramProcessor`, zebras, and focus peaking are the existing analysis surface.
- `DeviceCapabilitySnapshot` models permission and device readiness.
- `CaptureContextSummary` is the privacy-safe structured context boundary.
- `CaptureCoachEngine`, `BracketRecipeEngine`, and `BracketReviewNarrativeEngine` are the first guarded Apple Intelligence/deterministic fallback seams.
- `OpenBracketerIntent` is the first system-facing App Intents bridge.
- UI tests already use deterministic launch arguments for camera startup, simulated capture, review fixtures, histogram, zebras, focus peaking, capability states, layout branches, and Apple Intelligence availability.

The system should grow from these seams into a durable imaging platform.

## Impossible Completion Criteria

The goal is not complete until all of the following are true at once:

1. Bracketer can plan a bracket from live scene data, user intent, device capability, lens, motion, histogram, clipping risk, dynamic range, file format, and export goal.
2. Bracketer can run a closed capture loop that verifies whether the bracket is good enough and recommends or automatically stages recovery captures when it is not.
3. Bracketer can ingest RAW and processed assets precisely, pair them per shot, preserve metadata, detect missing resources, and recover from partial Photos saves.
4. Bracketer can reconstruct a high-dynamic-range scene from bracketed captures using a truthful local pipeline.
5. Bracketer can align handheld brackets, estimate ghosting risk, detect subject movement, and choose explainable deghosting strategies.
6. Bracketer can generate exposure-fusion previews, tone-mapped previews, edit variants, contact sheets, reports, and export bundles without confusing previews for final science.
7. Bracketer can store every bracket as a durable project with assets, manifests, sidecars, thumbnails, diagnostics, generated notes, edit graph, tags, favorites, search tokens, and provenance.
8. Bracketer can search and retrieve bracket projects by scene, date, lens, EV spread, recipe, location policy, dynamic range, tags, notes, diagnostics, output type, and capture quality.
9. Bracketer can expose useful system surfaces through App Intents, Siri, Shortcuts, Spotlight, widgets, Control Center, Action button, and file/document workflows where supported by the platform.
10. Bracketer can explain every recommendation, capture, failure, merge, export, and generated note from inspectable facts.
11. Bracketer can run without Apple Intelligence, but becomes dramatically more helpful when Apple Intelligence is locally available.
12. Bracketer can prove simulator behavior with deterministic fixtures and prove physical camera behavior with real iPhone capture evidence.
13. Bracketer can export to serious professional workflows: Lightroom, Photos, Files, archives, sidecars, reports, contact sheets, and future HDR/fusion consumers.
14. Bracketer has a privacy and trust center that makes local computation, Photos access, location policy, Apple Intelligence usage, generated content, diagnostics, and export boundaries obvious.
15. Bracketer is fast enough, stable enough, accessible enough, and beautiful enough to trust during real photography.
16. Bracketer has regression tests, performance probes, benchmark fixtures, docs, and continuation ledgers that allow future agents to keep advancing it.
17. Bracketer is still honest. It never pretends to inspect pixels, metadata, hardware, Apple Intelligence, or physical devices that it did not actually inspect.

Until every item above is true, the goal remains open.

## The Product North Star

Bracketer should feel like an instrument, not a demo.

The photographer opens the app and says, implicitly or explicitly:

- I am shooting a high-contrast sunset.
- I am shooting an interior with bright windows.
- I am handheld and the subject is moving.
- I need a Lightroom-ready bracket.
- I need a clean HDR preview now.
- I need a provenance-safe archive.
- I need the safest capture for highlights.
- I need a quick bracket for later editing.
- I need the app to tell me if this capture failed.

Bracketer should understand the intent, inspect what it is allowed to inspect, choose or propose a capture strategy, run the bracket, verify the result, preserve the project, explain the outcome, and prepare the next useful action.

## The Imaging OS Spine

The most important architectural migration is the creation of a durable `BracketProject` or `ImagingProject` spine.

Every capture, review, manifest, sidecar, diagnostic, generated note, exposure-fusion preview, RAW pair, export, App Intent, shortcut, search result, and Apple Intelligence context should eventually belong to a project.

The project spine should include:

- Stable project identifier.
- Capture session identifier.
- Resolved bracket plan.
- User intent.
- Applied recipe.
- Device capability snapshot.
- Lens and camera state.
- Capture timeline.
- Per-shot asset references.
- RAW/processed pair mapping.
- Photos local identifiers where permitted.
- File/resource summaries.
- Metadata summaries.
- Histogram and clipping summaries.
- Focus and motion summaries.
- Alignment and deghosting metrics.
- Fusion preview references.
- Tone mapping settings.
- Review selections.
- Generated notes.
- Accepted tags.
- User annotations.
- Diagnostics.
- Export history.
- Provenance records.
- Privacy flags.
- Search tokens.
- Spotlight entity data where supported.

This is the central object that lets the rest of the impossible goal compound.

## Wave Family A: Project Spine And Persistence

Build the durable local project system.

Goals:

- Turn latest-capture state into persistent bracket projects.
- Make every capture recoverable after app relaunch.
- Make simulated and Photos-backed projects share one model.
- Keep raw image bytes out of metadata stores unless explicitly required.
- Keep Photos identifiers and location information privacy-scoped.

Required outcomes:

- `BracketProject` or `ImagingProject` pure model.
- Project store abstraction.
- Codable persistence format or local database.
- Migration path from latest manifest/review state.
- Project lifecycle: planned, capturing, saving, reviewable, incomplete, failed, exported, archived.
- Project list, current project, and latest project routing.
- Recovery from partial capture and partial Photos save.
- Tests for persistence, migration, corruption, missing assets, deletion, and privacy flags.

Never claim this wave complete until a project survives app relaunch in a deterministic test or verified runtime path.

## Wave Family B: Adaptive Capture Agent

Build a capture planner that behaves like a cautious camera engineer.

Goals:

- Convert user intent plus live scene signals into a bracket strategy.
- Keep the photographer in control.
- Never claim to see data that is not present.
- Use Apple Intelligence only as a layer over structured facts, not as magical vision.

Required outcomes:

- Capture intent model.
- Scene condition model.
- Dynamic range estimate.
- Motion/stability estimate.
- Lens-specific capability model.
- Highlight and shadow risk model.
- Suggested shot count, EV step, center bias, timer, RAW/processed choice, lens, and stabilization guidance.
- Confidence and explanation fields.
- Deterministic fallback planner.
- Apple Intelligence planner behind availability gates.
- UI that is compact enough for real shooting.
- Tests for common scene archetypes.

Impossible extension:

- The planner should eventually learn the photographer's style locally from accepted/rejected recipes and successful exports without leaking private image data.

## Wave Family C: Closed-Loop Capture Verification

Build the system that says whether the bracket actually worked.

Goals:

- After each capture, decide whether the sequence is complete, sharp enough, aligned enough, exposed enough, and useful enough.
- Recommend recovery captures when needed.
- Avoid magical certainty.

Required outcomes:

- Per-shot capture quality model.
- Missing-shot detection.
- Exposure coverage estimate.
- Highlight recovery confidence.
- Shadow recovery confidence.
- Motion/blur risk.
- Alignment risk.
- Ghosting risk.
- Save integrity checks.
- Photos asset availability checks.
- Recovery recommendations.
- Diagnostics and UI probes.
- Tests with deterministic fixtures.

Impossible extension:

- Bracketer should eventually guide a photographer through capture like a flight computer: shoot, inspect, recover, confirm, archive.

## Wave Family D: RAW And Processed Asset Truth

Make professional asset handling exact.

Goals:

- Map RAW and processed representations per shot.
- Preserve and explain asset identity without overexposing private identifiers.
- Handle HEIF, JPEG, DNG, ProRAW, paired resources, missing resources, and Photos quirks.

Required outcomes:

- RAW/processed pair model.
- Resource identity model.
- Missing pair detection.
- Per-shot representation availability.
- Export naming strategy.
- Sidecar references.
- Tests with synthetic Photos resource summaries.
- Physical-device checklist for ProRAW capture.

Impossible extension:

- Build a robust import path for external bracket folders, sidecars, and Photos collections.

## Wave Family E: Local Computational Imaging Pipeline

Build the real image science core.

Goals:

- Move beyond review into reconstruction.
- Produce truthful local computational outputs.
- Keep previews, research prototypes, and final exports clearly separated.

Required outcomes:

- Fusion input model.
- Linear-light working representation where feasible.
- Exposure normalization.
- Alignment prototype.
- Weight-map fusion.
- Tone mapping controls.
- Noise and clipping diagnostics.
- Color management notes.
- Preview renderer.
- Export renderer.
- Performance diagnostics.
- Pixel fixture tests.

Impossible extension:

- Build a demosaic-aware, RAW-first HDR reconstruction path with local tone mapping, noise modeling, color appearance handling, and explainable failure modes.

## Wave Family F: Alignment, Motion, And Deghosting Lab

Make handheld brackets trustworthy.

Goals:

- Understand camera motion, subject motion, and merge risk.
- Choose explainable deghosting behavior.
- Warn when a bracket is not suitable for fusion.

Required outcomes:

- Motion metadata capture where available.
- Feature matching prototype.
- Alignment transform model.
- Confidence metrics.
- Ghosting risk estimate.
- Moving-region masks where feasible.
- User-facing explanation.
- Synthetic fixture tests.
- Performance notes.

Impossible extension:

- Make handheld bracket fusion good enough that users trust it more than manual review.

## Wave Family G: Pro Review Workspace

Turn review into an analysis cockpit.

Goals:

- Make every shot in a bracket inspectable.
- Compare exposures quickly.
- Explain which shots are useful and why.
- Expose enough data for pro workflows without cluttering normal use.

Required outcomes:

- Bracket filmstrip with EV labels and state.
- Side-by-side compare.
- Before/after or scrub view.
- Per-shot histogram.
- False-color clipping.
- Focus/edge inspection.
- Motion and alignment overlays.
- Metadata panel.
- RAW/processed toggle.
- Best-base-frame suggestion.
- Merge-readiness score.
- Manifest and sidecar export.
- Generated review notes.
- Tests for review view models and UI fixtures.

Impossible extension:

- The review workspace should become good enough that a photographer can diagnose a failed bracket without leaving the app.

## Wave Family H: Project Library, Search, And Creative Memory

Turn Bracketer into a long-term archive.

Goals:

- Persist projects.
- Make them searchable.
- Make the app remember what the user has made.
- Keep privacy and provenance first.

Required outcomes:

- Project library.
- Thumbnails or privacy-safe previews.
- Search by EV spread, date, recipe, tags, notes, file type, lens, capture quality, clipping risk, and export status.
- Favorites.
- Tags.
- Notes.
- Smart collections.
- Recent projects.
- Archive export.
- Backup/import path.
- Spotlight integration where supported.
- Tests for persistence, search tokens, and privacy rules.

Impossible extension:

- Local semantic search over project facts and user-approved notes, with Apple Intelligence summaries that never require cloud upload.

## Wave Family I: Apple Intelligence As A Real System Layer

Make Apple Intelligence deeply integrated without making it a gimmick.

Goals:

- Use local generative capabilities only where they add real photographic leverage.
- Keep core camera behavior independent.
- Make every generated output traceable.

Required outcomes:

- Availability model.
- Runtime proof diagnostics.
- Structured prompt boundaries.
- Capture coach.
- Bracket recipe planner.
- Review narrator.
- Export note generator.
- Troubleshooting explainer.
- Project search assistant.
- User-controlled generated tags.
- Source and fallback disclosure everywhere.
- Deterministic fallback for CI.
- Physical-device proof checklist for live Foundation Models output.

Impossible extension:

- Bracketer should become a local photographic mentor that can teach, critique, and automate based on real project facts while preserving user agency.

## Wave Family J: App Intents, Siri, Shortcuts, And System Surfaces

Make Bracketer feel like a first-class Apple platform citizen.

Goals:

- Expose useful, truthful actions outside the app.
- Avoid background camera lies.
- Use supported schemas and entities correctly.

Required outcomes:

- Open camera with preset.
- Open latest review.
- Open project.
- Export latest manifest.
- Export project bundle.
- Start timer-prepared capture handoff where supported.
- Query latest project summary.
- App entities for bracket projects where appropriate.
- Shortcuts phrases.
- Spotlight indexing.
- Widget status if useful.
- Control Center or Action button integration where supported.
- Tests for intent data conversion and handoff probes.

Impossible extension:

- A photographer should be able to say "Prepare a five-shot interior window bracket in Bracketer" and arrive in the app with a truthful, inspectable capture plan ready.

## Wave Family K: Professional Export Suite

Make Bracketer useful after capture.

Goals:

- Export everything professionals need.
- Keep privacy controls obvious.
- Preserve provenance.

Required outcomes:

- Manifest JSON.
- Manifest sidecar.
- Generated notes.
- Contact sheet.
- Selected images.
- RAW/processed image bundles.
- Fusion previews.
- Final rendered outputs where available.
- Diagnostics report.
- Privacy report.
- Naming templates.
- Export presets.
- Share flows.
- Files integration.
- Tests for filenames, manifests, sidecars, and export payloads.

Impossible extension:

- Bracketer export bundles should be good enough to hand to Lightroom, an archive, a client, a print workflow, or a future Bracketer import without losing meaning.

## Wave Family L: Privacy And Trust Center

Make trust a first-class product surface.

Goals:

- Show what stays on device.
- Show what data is used by Apple Intelligence.
- Show what is exported.
- Show what is never included.

Required outcomes:

- Privacy settings section.
- Apple Intelligence toggles.
- Generated feature controls.
- Photos access explanation.
- Location policy.
- Diagnostics export policy.
- Project metadata policy.
- Asset identifier policy.
- Export preview and redaction controls.
- Tests for privacy copy and settings state.

Impossible extension:

- Every project should be able to produce a privacy report that explains what Bracketer knows, what it generated, what it exported, and what it deliberately did not store.

## Wave Family M: Observability, Benchmarks, And Real-Device Lab

Make Bracketer measurable.

Goals:

- Instrument performance and reliability.
- Separate simulator truth from physical-device truth.
- Build evidence that future agents can trust.

Required outcomes:

- Startup timing.
- Session configuration timing.
- Capture timing.
- Photos save timing.
- Review load timing.
- Histogram timing.
- Fusion timing.
- Model-call timing.
- Dropped frame diagnostics.
- Memory and CPU notes.
- Result bundle documentation.
- Device proof checklist.
- Physical capture matrix.
- Regression fixtures.
- Benchmark commands.

Impossible extension:

- Maintain a real-device evidence suite across multiple iPhones, lenses, iOS versions, ProRAW states, Photos permission states, lighting conditions, and storage pressure scenarios.

## Wave Family N: Accessibility And Inclusive Pro Design

Make the app powerful without becoming hostile.

Goals:

- Preserve the photographer's line of sight.
- Make controls understandable.
- Make review and export accessible.
- Support dynamic type and VoiceOver where feasible for a camera UI.

Required outcomes:

- Stable accessibility identifiers.
- VoiceOver labels and values.
- Dynamic type sanity.
- Safe-area stability.
- Landscape and portrait contracts.
- Reduced-motion consideration.
- High-contrast consideration.
- Tap target audit.
- UI tests for key surfaces.

Impossible extension:

- Bracketer should be the rare pro camera app whose advanced controls are still humane.

## Wave Family O: Design, Feel, And Taste

Make the app beautiful enough to deserve the ambition.

Goals:

- Build a premium instrument, not a dashboard.
- Keep camera chrome calm.
- Avoid clutter.
- Make advanced surfaces feel precise.

Required outcomes:

- Refined camera cockpit.
- Review workspace polish.
- Project library polish.
- Export flow polish.
- Settings discipline.
- Liquid Glass alignment where appropriate.
- Motion and haptics that support confidence.
- No fake futuristic panels.
- No visual claims unsupported by data.

Impossible extension:

- The app should feel like Apple made a pro bracket camera for people who actually understand exposure.

## Wave Family P: Documentation, Ledger, And Continuation Discipline

Make future progress easy.

Goals:

- Keep the repo understandable.
- Keep verification commands copy-pasteable.
- Keep limitations honest.
- Leave continuation notes after every major wave.

Required outcomes:

- README updates.
- Architecture updates.
- Evolution ledger entries.
- Proof category labels.
- Known limitation notes.
- Next-slice notes.
- Verification command log.
- Physical-device proof checklist.
- SDK availability notes.

Impossible extension:

- Any future agent should be able to resume the mission without rediscovering the same traps.

## Execution Loop For Goal Mode

When this prompt is active, repeat this loop until externally stopped:

1. Inspect current repo state.
2. Read the relevant source, tests, README, architecture docs, and ledger.
3. Pick the highest-leverage unfinished wave.
4. Define a narrow vertical slice that advances the impossible north star.
5. Implement the slice.
6. Add or update tests.
7. Run focused verification.
8. Run broader verification when risk requires it.
9. Update docs or ledger.
10. Record proof category: pure model, simulator UI, local SDK, runtime diagnostic, physical device, or blocked.
11. Identify the next slice.
12. Continue.

Do not ask for permission to continue ordinary development work. The goal itself is permission to keep moving.

## Proof Categories

Use these exact proof categories in reports and ledger notes:

- `pure-model-proof`: Swift tests for pure logic, Codable contracts, validators, planners, analyzers, manifests, sidecars, project stores, and import/export models.
- `simulator-ui-proof`: XCTest UI proof using deterministic launch arguments and simulator-safe fixtures.
- `local-sdk-proof`: Evidence from local SDK symbols, build settings, compiler availability, or official Apple documentation.
- `runtime-diagnostic-proof`: Evidence from app diagnostics, hidden probes, timing reports, or exported debug reports.
- `physical-device-proof`: Real iPhone evidence for camera, Photos, lenses, ProRAW, sample buffers, Foundation Models, or system integration.
- `manual-review-proof`: Human-inspected screenshot, exported artifact, or device behavior that cannot be fully automated yet.
- `blocked-proof`: Concrete blocker with command, output, environment, and next action.

Never mix these categories casually.

## First Strategic Move

The best first move is probably the project spine.

Build a minimal but real `BracketProject` foundation that can eventually own:

- Existing `BracketManifest`.
- Existing `BracketReviewSequence`.
- Existing `BracketManifestSidecar`.
- Existing runtime diagnostics.
- Existing applied recipe.
- Future RAW/processed pairs.
- Future fusion previews.
- Future tags and notes.
- Future export history.

Do not make the first slice too broad. Make it durable. The first slice should create the object that a decade of future work can attach to.

## Good Session Ending

A good session ending looks like this:

```text
Goal still open.
Completed wave: durable project spine v1.
Proof:
- pure-model-proof: BracketerTests passed for project encoding, lifecycle, privacy flags, and manifest attachment.
- simulator-ui-proof: deterministic simulated capture creates a project and opens review from that project.
Docs:
- README updated.
- docs/ARCHITECTURE.md updated.
- BRACKETER_EVOLUTION_LEDGER.md updated.
Next slice:
- Persist project index across relaunch and expose latest project in App Intents.
```

## Bad Session Ending

A bad session ending looks like this:

```text
Implemented a big plan but did not run tests.
Added AI copy without checking whether it uses real data.
Claimed physical camera behavior from simulator.
Added a UI panel that is not connected to the domain model.
Changed unrelated files.
Stopped after docs when code was requested.
Marked the impossible goal complete.
```

## Final Reminder

This goal is supposed to be too large.

The point is not to finish.

The point is to create a gravitational field that keeps pulling the app toward becoming the best bracketed photography system possible.

Make one real thing better.

Prove it.

Document it.

Then keep going.
