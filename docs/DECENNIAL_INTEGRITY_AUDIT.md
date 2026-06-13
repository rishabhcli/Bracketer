# Bracketer Decennial System Evolution & Integrity Audit

**Date:** 2026-06-12 · **Basis:** 62,455 lines of Swift across 45 app source files, all citations verified by direct file reads.
**Headline stats:** 88 types in one 15,032-line file · 29 `@Published` on one controller · 0 localized strings · 399 hardcoded font sizes · 0 privacy manifest · 247 unit tests in one 13,715-line file · 3 `#if DEBUG` guards in the entire app target · deployment target iOS 26.2.

---

# Phase 1: The 50-Point Critique

## Category A: Architecture, State Management & Scaling Anti-Patterns

### [Issue #1]: The 15,032-Line `BracketProject.swift` Mega-Monolith
* **Category:** A
* **SystemicImpact:** Every domain concept lives in a single compilation unit. Team/agent parallelism is impossible, incremental compilation degrades, and any review requires 15K lines of context. This file is the hard ceiling on development throughput.
* **TechnicalBreakdown:** `Bracketer/BracketProject.swift` contains 88 top-level types and zero `// MARK:` sections — domain models (line 197), the `FileBracketProjectStore` engine (line 14681), import/export validation, Spotlight projection, audits, and renderers fused together.
* **RemediationParadigm:** Decompose into SPM modules (`BracketDomain`, `BracketPersistence`, `BracketExchange`, `BracketReviewKit`), one type per file, CI lint gate capping file length, module-boundary tests.

### [Issue #2]: `CameraController` God-Object Owning Seven Subsystems
* **Category:** A
* **SystemicImpact:** Capture, Photos persistence, project orchestration, diagnostics, import/export, and review handoff concentrate in one 2,500-line class — the systemic single point of failure.
* **TechnicalBreakdown:** `CameraController.swift:366` — `final class CameraController: NSObject, ObservableObject, @unchecked Sendable` with 29 `@Published` properties; also hosts `PhotoSaver` (2407) and archive import/curation seams (per docs/ARCHITECTURE.md).
* **RemediationParadigm:** Hexagonal decomposition: `actor CaptureEngine`, `ProjectRepository`, `ReviewCoordinator`, thin composition root, unidirectional data flow.

### [Issue #3]: Every Query Decodes the Entire Project Store
* **Category:** A
* **SystemicImpact:** Read cost scales with lifetime usage; thousands of brackets mean full-library JSON decodes to answer "latest project?" — launch stalls, then watchdog kills. Fatal under 10-year data accretion.
* **TechnicalBreakdown:** `BracketProject.swift:14714` `latest() { try loadAll().first }`; `loadAll()` (14703-14707) decodes every project; `load(spotlightIdentifier:)` (14718-14722) full-scans with per-project hashing; `librarySnapshot` (14728) and `search` (14724) repeat the full load per query.
* **RemediationParadigm:** Indexed local database (SQLite/GRDB/SwiftData), lazy hydration, pagination, LRU caching.

### [Issue #4]: Full Rewrite + Synchronous Spotlight Indexing Inside Every `save()`
* **Category:** A
* **SystemicImpact:** A favorite toggle re-encodes the whole document, rewrites the global index, and does a Spotlight round-trip serially on the caller — write amplification that grows with library size.
* **TechnicalBreakdown:** `BracketProject.swift:14681-14694`: encode (14683), write (14684), O(n) `uniquePreservingOrder` (14687), full index write (14692), inline `spotlightIndexer.index(project)` (14693).
* **RemediationParadigm:** Differential field-level persistence, write-ahead journal, async debounced Spotlight pipeline.

### [Issue #5]: `@unchecked Sendable` Suppressing Real Data Races
* **Category:** A
* **SystemicImpact:** Compiler race-safety is explicitly disabled on the most concurrency-hostile object; races already corrupt capture state (Issue #23); strict-concurrency migration becomes a rewrite.
* **TechnicalBreakdown:** `CameraController.swift:366` `@unchecked Sendable`; `sequenceStep` read on delegate queue (2274), written on main (2334); `sequenceHadLocationSample` written on delegate queue (2268); `bracketAssetIds` appended on main (2326); no locks or isolation.
* **RemediationParadigm:** Actor-isolated capture state machine, immutable snapshots across executors, `SWIFT_STRICT_CONCURRENCY=complete` as CI gate.

### [Issue #6]: Synchronous Disk I/O at the Persistence Boundary, Reachable From UI
* **Category:** A
* **SystemicImpact:** The store exposes only blocking synchronous APIs; SwiftUI callers pay disk latency inline — dropped frames now, watchdog terminations at scale.
* **TechnicalBreakdown:** `BracketProject.swift:14699` `Data(contentsOf: url)` in `load(id:)`; all of `loadAll/latest/search/librarySnapshot` synchronous, invoked from settings library and review-restore seams.
* **RemediationParadigm:** `async` repository protocol on a dedicated I/O executor; prefetch and snapshot caching; CI main-thread-I/O assertions.

### [Issue #7]: 20 ms Busy-Polling for Exposure Settling Instead of KVO
* **Category:** A
* **SystemicImpact:** ~100 dispatches per shot, ~700 per 7-shot bracket; nondeterministic inter-frame latency that hurts handheld alignment; poll-loop architecture scales cost with every new condition.
* **TechnicalBreakdown:** `CameraController.swift:17` `aeSettlePollInterval = 0.02`; `settleAutoExposure` (1716-1745) recursive `sessionQueue.asyncAfter` (1733) until threshold or 2 s deadline.
* **RemediationParadigm:** KVO/async-sequence observation of `exposureTargetOffset`, cancellation tokens, typed settle outcomes recorded in the manifest.

### [Issue #8]: UserDefaults Used as a Structured Database
* **Category:** A
* **SystemicImpact:** Structured recipe history serialized into the defaults plist — loaded wholesale, no migrations/queries/size discipline; second uncontrolled accretion point.
* **TechnicalBreakdown:** `SettingsStore.swift:239` `decodedRecentBracketRecipes(from defaults:)` decodes recipe records out of `UserDefaults` (`.standard` at 135).
* **RemediationParadigm:** Defaults for scalar prefs only; recipes/history into the transactional database with versioning and eviction.

### [Issue #9]: The 24-Payload Export Equality Matrix
* **Category:** A
* **SystemicImpact:** Archives freeze ~24 derived artifacts and the importer byte-validates each — every schema tweak invalidates every archive ever exported; format evolution is effectively impossible.
* **TechnicalBreakdown:** `docs/ARCHITECTURE.md:29` enumerates the payload list and per-payload equality validation, implemented across `BracketProject.swift` ~13,500-14,400.
* **RemediationParadigm:** Persist sources of truth only; recompute derivatives; versioned container (zip + manifest + semver) with golden-archive compatibility tests.

### [Issue #10]: Whole-Object Publisher Invalidation Across Monolithic Views
* **Category:** A
* **SystemicImpact:** Any of 29 published properties ticking invalidates view bodies thousands of lines deep — continuous diffing cost during live preview, worsening with every feature.
* **TechnicalBreakdown:** 29 `@Published` on `CameraController` feeding `ModernContentView.swift` (1,860 lines), `ModernSettingsPanel.swift` (4,545), `BracketProjectReviewHandoffView.swift` (2,333).
* **RemediationParadigm:** `@Observable` granular models, per-feature view models, view decomposition, render-count instrumentation in CI.

## Category B: Cognitive Friction, Interaction Flow & Next-Gen UX Debt

### [Issue #11]: A Developer Test Lab Shipped Inside Consumer Settings
* **Category:** B
* **SystemicImpact:** Settings is dominated by CI tooling — xcresulttool command plans, result-bundle digests, runbooks, proof-ingestor previews — catastrophic cognitive friction for users changing an EV step.
* **TechnicalBreakdown:** `ModernSettingsPanel.swift` (4,545 lines) contains only 2 `Toggle(` controls; strings "Result-bundle digest and xcresulttool commands" (1809), "Runbook, command plan, seeded template" (1855), "Manifest, workspace, checklist" (1901) back the `settings.deviceProof.*` family.
* **RemediationParadigm:** Hard split: minimal user settings vs internal lab console behind `#if INTERNAL_LAB` in a separate target.

### [Issue #12]: Permanently-Zero "0 of 8" Proof Matrix as User-Facing UI
* **Category:** B
* **SystemicImpact:** A perpetual failure scorecard renders in product Settings, manufacturing distrust by design.
* **TechnicalBreakdown:** `docs/ARCHITECTURE.md:43` — matrix at `settings.deviceProof.captureMatrix`, "simulator coverage keeps the count at 0 of 8"; checklist "keeps 0 physical proofs captured" (ARCHITECTURE.md:41).
* **RemediationParadigm:** Verification evidence belongs in CI dashboards/internal builds; product UI communicates capability only.

### [Issue #13]: ~20 Synthetic "Analysis" Cards Presented as Review Guidance
* **Category:** B
* **SystemicImpact:** Review shows focus/ghosting/alignment/feature-match "analysis" computed from fixture data, not the user's photos — discovery collapses trust in every number in the app. Largest retention threat.
* **TechnicalBreakdown:** `docs/ARCHITECTURE.md:89-107`: FocusEdgeInspection from "deterministic 4x4 synthetic fixture pixels"; MotionAlignmentOverlay "synthetic motion scores… synthetic alignment offsets"; Ghosting/MovingRegionMask/FeatureMatch/AlignmentExplanation reports — each a visible `review.project.*.card` in `BracketProjectReviewHandoffView.swift` (2,333 lines).
* **RemediationParadigm:** No fixture-derived values in product UI ever; internal flags until real Vision/CoreImage analysis exists; one progressive-disclosure review summary of true facts.

### [Issue #14]: Zero Localization Infrastructure
* **Category:** B
* **SystemicImpact:** Hardcoded English everywhere; global distribution foreclosed; retrofit cost compounds per commit.
* **TechnicalBreakdown:** Zero `NSLocalizedString`/`String(localized:)` matches across all app sources (grep verified).
* **RemediationParadigm:** String Catalogs now; lint forbidding bare literals in views; pseudo-localization snapshot tests.

### [Issue #15]: 399 Hardcoded Font Sizes — Dynamic Type Broken
* **Category:** B
* **SystemicImpact:** No text scaling anywhere; accessibility failure and featuring blocker.
* **TechnicalBreakdown:** 399 fixed `size:` font usages (e.g., `EXIFViewer.swift:185,190`).
* **RemediationParadigm:** Semantic text styles + `@ScaledMetric`; Dynamic-Type snapshot tests in CI.

### [Issue #16]: Failures Routed to Diagnostics Export Instead of the User
* **Category:** B
* **SystemicImpact:** Data-affecting failures surface nothing actionable at failure time — fastest path to uninstall.
* **TechnicalBreakdown:** `CameraController.swift:504-511` records persistence failure with actionPath "Settings > About > Export Diagnostics"; `HapticManager.swift:27,35,41` failures only `print()`.
* **RemediationParadigm:** Severity-routed user-facing error layer with recovery actions; diagnostics as supplement.

### [Issue #17]: Permission Ambush — Five Onboarding Pages, Zero Priming
* **Category:** B
* **SystemicImpact:** Cold permission prompts raise denial rates; denied camera = dead app with no recovery design.
* **TechnicalBreakdown:** `OnboardingView.swift:10-40` five `OnboardingPage(` in a `TabView` (48); no `requestAuthorization`, no rationale, no denial recovery.
* **RemediationParadigm:** Just-in-time priming per permission; denied-state UX deep-linking to Settings.

### [Issue #18]: First-Person Permission Copy ("I need the camera…")
* **Category:** B
* **SystemicImpact:** The highest-stakes trust dialog speaks as the developer; scope-misleading and unlocalized.
* **TechnicalBreakdown:** `project.pbxproj:406-409`: "I need the camera to capture bracketed photos.", "I need to geotag your photos", "I need motion data…", "I need to save the photos…".
* **RemediationParadigm:** Benefit-framed, app-voiced, localized purpose strings with privacy review.

### [Issue #19]: Manifest/Sidecar/Runbook Jargon as Primary UX Vocabulary
* **Category:** B
* **SystemicImpact:** Build-engineer dialect inflates time-to-competence and support load.
* **TechnicalBreakdown:** "Capture, review, and manifest export remain available…" (`ModernSettingsPanel.swift:500`) plus lab vocabulary at 1809/1855/1901.
* **RemediationParadigm:** Vocabulary map, banned-terms lint for user strings, copy review as release gate.

### [Issue #20]: Long Operations With No Progress Architecture
* **Category:** B
* **SystemicImpact:** 24-artifact archive builds run synchronously on tap; frozen UI, no cancellation, duration grows with library size.
* **TechnicalBreakdown:** Export path is synchronous end-to-end; only temporal primitive is a hardcoded 2.0 s toast (`ModernContentView.swift:481`).
* **RemediationParadigm:** Cancellable async pipelines with `Progress`; skeleton states; main-thread frame-budget test in CI.

## Category C: Boundary Conditions, Edge Cases & Data Corruption Faults

### [Issue #21]: One Corrupt Project File Bricks the Entire Library
* **Category:** C
* **SystemicImpact:** A single bad record makes latest/search/snapshots/Spotlight all throw — ten years of archive invisible because one file decayed.
* **TechnicalBreakdown:** `BracketProject.swift:14705` `try index.projectIDs.compactMap { try load(id: $0) }` propagates any decode error out of `loadAll()`, the substrate for `latest()` (14714), `search` (14724), `librarySnapshot` (14728), `load(spotlightIdentifier:)` (14718).
* **RemediationParadigm:** Per-record fault isolation with quarantine + recovery surface; corruption drills as CI fixtures.

### [Issue #22]: Non-Transactional Multi-File Persistence (Project → Index → Spotlight)
* **Category:** C
* **SystemicImpact:** Crash between the three mutations yields orphaned files or Spotlight ghosts; divergence compounds for years with no reconciliation.
* **TechnicalBreakdown:** `BracketProject.swift:14681-14694`: project write (14684), index write (14692, atomic separately at 14931), inline Spotlight (14693); individually atomic, collectively not; no boot reconciliation.
* **RemediationParadigm:** ACID transactions (SQLite WAL) for record+index; Spotlight as idempotent outbox; boot-time integrity sweep.

### [Issue #23]: Data Race on `sequenceStep` Corrupts Bracket Labeling
* **Category:** C
* **SystemicImpact:** EV labels — the core truth of a bracketing app — derive from racing state; duplicate/shifted labels silently corrupt filenames and manifests.
* **TechnicalBreakdown:** Delegate queue reads `sequenceStep` (`CameraController.swift:2274`) to pick `filenameLabel` (2277); increment happens later on main inside async save completion (2334). Bracketed frames arrive before any save completes → same step for multiple frames. Plain data race hidden by `@unchecked Sendable` (366).
* **RemediationParadigm:** Shot index from `AVCapturePhoto` sequence metadata, never shared counters; actor-isolated sequence state with event log.

### [Issue #24]: Whole Bracket Shares One Second-Resolution Filename
* **Category:** C
* **SystemicImpact:** File identity is wall-clock seconds; identical suggested filenames within a bracket (label nil under race) and across same-second brackets.
* **TechnicalBreakdown:** `CameraController.swift:2282` `Int(Date().timeIntervalSince1970)`; names `"Bracket-\(timestamp).dng"` (2289)/(2305); `bracketLabel` nil when indices check fails (2276-2279).
* **RemediationParadigm:** Capture-session UUID + monotonic shot ordinal as filename contract; time as display metadata only.

### [Issue #25]: `schemaVersion = 1` With No Migration Engine
* **Category:** C
* **SystemicImpact:** Version is stamped but never branched on; first incompatible change makes historical projects throw — and via #21 one old record kills the library.
* **TechnicalBreakdown:** `BracketProject.swift:197` `static let schemaVersion = 1`, encoded at 256/481/521; no transformation path exists for any other version.
* **RemediationParadigm:** Frozen per-version decoders + stepwise migrations; golden-file decode tests; CI gate refusing model changes without migrations.

### [Issue #26]: Exposure-Settle Timeout Silently Captures Mis-Exposed Frames
* **Category:** C
* **SystemicImpact:** Unsettled AE proceeds to fire the bracket with no record — defective brackets logged as healthy.
* **TechnicalBreakdown:** `CameraController.swift:1728-1731` `completion() // timeout, proceed with best effort`; settle recursion (1716-1745) has no cancellation linkage to sequence state.
* **RemediationParadigm:** Typed settle outcomes recorded per shot in the manifest; cancellation tokens; configurable abort-vs-proceed policy.

### [Issue #27]: Storage Preflight Floor (500 MB) Below a Single ProRAW Bracket
* **Category:** C
* **SystemicImpact:** The gate passes captures that cannot fit: 7-shot ProRAW ≈ 525-560 MB > the 500 MB floor — mid-sequence disk exhaustion for power users.
* **TechnicalBreakdown:** `CameraController.swift:20` `minimumStorageMB = 500`; single check at 1448 via `storagePreflightFailure()` (1753-1767); no per-plan estimation or in-sequence monitoring.
* **RemediationParadigm:** Plan-derived preflight (shots × codec estimate × safety), continuous monitoring, graceful degradation.

### [Issue #28]: Failed Saves Don't Stop the Sequence — Partial Brackets as Progress
* **Category:** C
* **SystemicImpact:** Photos write failures log-and-advance; sequence "completes" with holes discovered only at review, after the moment is gone.
* **TechnicalBreakdown:** `CameraController.swift:2325-2341`: on nil assetIdentifier, log (2329), then unconditional `sequenceStep += 1` (2334) and state advance (2336-2341); no retry/abort/user surfacing.
* **RemediationParadigm:** Save outcomes drive the state machine: bounded retries, abort threshold, live failure surfacing, planned/captured/persisted per-shot states.

### [Issue #29]: Fixed 30-Second Timeout Regardless of Plan or Photos Latency
* **Category:** C
* **SystemicImpact:** Legitimate long sequences get marked failed while frames keep saving — state machine and photo library permanently disagree.
* **TechnicalBreakdown:** `CameraController.swift:19` `bracketTimeoutSeconds = 30.0`; single DispatchWorkItem (1769-1782), no per-shot watchdog, no late-arrival reconciliation.
* **RemediationParadigm:** Plan- and latency-derived deadlines; per-shot watchdogs; reconciliation adopting late assets into the manifest.

### [Issue #30]: No AVCaptureSession Interruption or Thermal Handling
* **Category:** C
* **SystemicImpact:** Calls, Split View preemption, thermal shutdown mid-bracket leave the sequence stuck until generic timeout — mysterious failures users blame on the app.
* **TechnicalBreakdown:** Greps for `wasInterruptedNotification`, `interruptionEnded`, `AVCaptureSessionRuntimeError`, `thermalState` return nothing in the app target (verified absence).
* **RemediationParadigm:** Full session lifecycle observers feeding the state machine: typed interruption states, auto-resume, thermal-aware degradation, cause-specific messaging.

## Category D: Security Posture, Data Leakage & Zero-Trust Violations

### [Issue #31]: No Privacy Manifest Despite Required-Reason API Usage
* **Category:** D
* **SystemicImpact:** Hard App Store compliance gap; signals absent privacy engineering.
* **TechnicalBreakdown:** No `*.xcprivacy` anywhere (verified); required-reason APIs in use: `attributesOfFileSystem` (`CameraController.swift:1755`), `UserDefaults` (`SettingsStore.swift`).
* **RemediationParadigm:** Author the manifest; CI-validate against an allowlist of API usages.

### [Issue #32]: Split-Brain Location Privacy — Manifests Redact GPS, Photos Embed It
* **Category:** D
* **SystemicImpact:** The "no precise coordinates" trust claim covers sidecars only; every geotagged capture embeds full GPS in the shared artifact. Claims and behavior diverge — worse than no claim.
* **TechnicalBreakdown:** `CameraController.swift:2450` `req.location = location`; contrast `docs/ARCHITECTURE.md:25/29` boundaries and the Privacy & Trust card.
* **RemediationParadigm:** Single privacy engine at every egress: geotag opt-in, reduced accuracy, share-time stripping.

### [Issue #33]: Zero Data Protection on Persisted Projects
* **Category:** D
* **SystemicImpact:** Notes/summaries/capture patterns readable after first unlock; sensitive for journalist/photographer users; exposure grows with the archive.
* **TechnicalBreakdown:** Zero `FileProtection` usage repo-wide (verified); writes pass only `[.atomic]` (14684/14931).
* **RemediationParadigm:** `.completeUnlessOpen` store root; documented threat model checked in CI.

### [Issue #34]: User Notes and AI Content Pushed Into the System Spotlight Index
* **Category:** D
* **SystemicImpact:** Private annotations become device-wide searchable keywords with no opt-out; data exits the trust domain on every save.
* **TechnicalBreakdown:** `BracketProjectSpotlight.swift:138-155` indexes generatedNote title/summary/mergeAdvice/tags, userNote, acceptedTags, asset labels; fires inside `save()` (14693).
* **RemediationParadigm:** Opt-in, content-tiered indexing; per-project privacy flags; verifiable index purge on delete.

### [Issue #35]: Unattended Automation — Intents With No Confirmation or Rate Limits
* **Category:** D
* **SystemicImpact:** Shortcuts can prepare timed captures and pull recovery-level exports unattended — exfiltration plus battery/thermal abuse surface.
* **TechnicalBreakdown:** `BracketerAppIntents.swift:216` `PrepareTimedBracketCaptureIntent`; export intents with privacy-level params; zero `requestConfirmation`/`IntentConfirmation`/`throttle|rateLimit` matches (verified); singleton router (183).
* **RemediationParadigm:** Confirmation for state-changing/exporting intents; foreground-only privacy escalation; rate limits; automation audit log.

### [Issue #36]: Client-Side "Physical Proof" Attestation Is Forgeable Theater
* **Category:** D
* **SystemicImpact:** 2,582 lines validating hashes/evidence produced and verified on the same untrusted device — fabricatable in one sitting; ceremony presented as security.
* **TechnicalBreakdown:** `BracketerPhysicalProofIngestor.swift` — no hardware key, no server, no App Attest; `REPLACE_WITH_64_HEX_*` templates (921-954); recomputable checksum chain (1075).
* **RemediationParadigm:** DeviceCheck/App Attest + server-side verification with hardware-rooted signatures, or delete the ceremony.

### [Issue #37]: Plaintext Local Storage; Keychain Never Used
* **Category:** D
* **SystemicImpact:** No data-sensitivity classification exists; no secure foundation for the sync/accounts/keys the roadmap requires.
* **TechnicalBreakdown:** Zero `Keychain|SecureEnclave|kSecClass` matches (verified); plaintext JSON + UserDefaults plists (`SettingsStore.swift:135,239`).
* **RemediationParadigm:** Enforced classification policy: secrets→Keychain, sensitive→protected containers, prefs→defaults; CI checks.

### [Issue #38]: Unbounded Archive Parsing — Memory DoS via Crafted Import
* **Category:** D
* **SystemicImpact:** Externally supplied archives are fully materialized in memory; declared byte counts checked for consistency, never bounds — multi-GB crafted archives jetsam the app; path scriptable via intents.
* **TechnicalBreakdown:** `BracketProjectImportBundle.parse` decodes whole payloads (`BracketProject.swift:13853`); no size-limit constants exist in the import section (~13,500-14,400, verified).
* **RemediationParadigm:** Per-payload/per-archive caps, streaming fail-fast parse, import fuzzing in CI.

### [Issue #39]: Debug Logging Leaks Failure Internals to the System Console
* **Category:** D
* **SystemicImpact:** Raw print() and stringified decode errors reach the unified log, readable from a paired Mac, bypassing privacy annotations.
* **TechnicalBreakdown:** `HapticManager.swift:27,35,41,144` print() error paths; `Logger.swift:93` DEBUG print; importer messages embed decoder internals + filenames (13857).
* **RemediationParadigm:** os.Logger exclusively with privacy annotations; release log policy; sanitized error surfaces.

### [Issue #40]: Precise GPS Rendered and Shared With No Redaction Affordance
* **Category:** D
* **SystemicImpact:** EXIF viewer shows exact coordinates + map; no share flow offers location stripping — default path discloses coordinates for at-risk users.
* **TechnicalBreakdown:** `EXIFViewer.swift:185-193` `locationMapView(for:)` + `formatLocationDetails(location)`; no metadata-stripping step in any share path (verified).
* **RemediationParadigm:** Share-time metadata interceptor, location-stripped defaults, "includes location" badge, capture-time precision options.

## Category E: Observability, Maintainability & Technical Decay

### [Issue #41]: Production Blindness — No Crash Reporting, Metrics, or Telemetry
* **Category:** E
* **SystemicImpact:** Release builds emit nothing; every production failure is invisible. Self-healing is unbuildable without feedback signals.
* **TechnicalBreakdown:** Zero `MetricKit|MXMetric|os_signpost|Sentry|Crashlytics` matches (verified); `Logger.swift:92-94` prints only in DEBUG; diagnostics buffer dies with the process unless manually exported.
* **RemediationParadigm:** MetricKit + structured signposts; consented diagnostics journal upload; SLO dashboards (bracket success rate, save p95).

### [Issue #42]: 13,715-Line Single Test File of Constant-Echo Assertions
* **Category:** E
* **SystemicImpact:** 247 tests/~3,959 assertions verify almost nothing behavioral; green wall signals safety while shipped failure modes (#21-#30) had zero coverage.
* **TechnicalBreakdown:** One file, 247 `@Test` funcs (verified); lines 22-31 assert `evOffsets` against literal arrays; fixture models asserted against their own inputs; no corruption/race/migration/failure-injection tests.
* **RemediationParadigm:** Per-module targets; property-based + failure-injection tests; mutation testing; coverage gates on corruption/race paths.

### [Issue #43]: The Camera Core Is Architecturally Untestable
* **Category:** E
* **SystemicImpact:** The 2,500 lines where the product lives cannot execute in CI; core regressions ship blind forever.
* **TechnicalBreakdown:** AVFoundation consumed concretely, no protocol seam (verified); tests reference `CameraController(projectStore:)` only as inert fixtures (6 instantiation-only references).
* **RemediationParadigm:** Pure capture state machine + AVFoundation adapter; fake-device conformances simulating arrival orders/failures/interruptions in CI.

### [Issue #44]: UI Tests Assert Probe Strings — and the Probes Ship to Production
* **Category:** E
* **SystemicImpact:** UI suite checks hidden probes exist, not that flows work; `-ui-testing-*` switches compile into release — production behavior steerable by launch args.
* **TechnicalBreakdown:** 21 XCUI tests asserting identifiers (`BracketerUITests.swift:36,43`); `docs/ARCHITECTURE.md:7,55` documents launch-arg seams in app code; dozens of hidden probes render in production views.
* **RemediationParadigm:** Flow-level tests on accessibility semantics; probes/launch-args under TESTING configuration; verifiably probe-free release builds.

### [Issue #45]: Simulation and Fixture Engines Compiled Into the Consumer Binary
* **Category:** E
* **SystemicImpact:** Fake-bracket generators and fixture renderers ship to users (3 `#if DEBUG` blocks in the whole target); one routing mistake persists synthetic data as user truth.
* **TechnicalBreakdown:** `SimulatedBracketReview.swift`, `PreviewContainer.swift`, fixture generators in `BracketProject.swift`, seeded proof templates — all unguarded (verified).
* **RemediationParadigm:** `SIMULATION` compilation condition + internal target; CI symbol-scan proving release contains zero fixture engines.

### [Issue #46]: Six Overlapping Planning Documents, ~19K Lines, No Single Truth
* **Category:** E
* **SystemicImpact:** Humans and agents cannot establish current truth without re-reading source — making agent-managed evolution unsafe.
* **TechnicalBreakdown:** LEDGER 11,578 lines; .codex-maygoals-progress 4,827; Enormousplans 1,670; maygoals 715; plans_Bracketer 203; README — partially contradictory; `docs/ARCHITECTURE.md:29` is one ~4,000-word paragraph.
* **RemediationParadigm:** One living architecture doc validated against code (doc-drift CI); ADRs; ledgers archived; "docs describe only what exists" merge rule.

### [Issue #47]: Two Parallel Design Systems Plus an Unused Icon Library
* **Category:** E
* **SystemicImpact:** Competing token sources drift; ~1,000 duplicated/dead lines in every build.
* **TechnicalBreakdown:** `ModernDesignSystem.swift` (312) + `LiquidGlassDesign.swift` (472, iOS 26-gated) both define tokens; `CustomIcons.swift` (279) has zero references (verified).
* **RemediationParadigm:** One token system with platform-conditional adapters; periphery dead-code detection in CI.

### [Issue #48]: Stringly-Typed State Keys and Probe IDs Everywhere
* **Category:** E
* **SystemicImpact:** State gates and the UI-test contract hang on duplicated raw strings — the #1 silent-breakage vector for agent-maintained code.
* **TechnicalBreakdown:** `@AppStorage("hasCompletedOnboarding")` in three files (`BracketerApp.swift:20`, `ModernSettingsPanel.swift:971`, `OnboardingView.swift:7`); dotted probe IDs exist only as hand-mirrored literals.
* **RemediationParadigm:** Typed key namespaces; generated identifier catalog shared by app+tests; lint ban on raw-string keys.

### [Issue #49]: Error Taxonomy Destroyed at Every Catch Site
* **Category:** E
* **SystemicImpact:** ~46 catch blocks flatten errors to strings; automated recovery/self-healing impossible when error identity dies at first catch.
* **TechnicalBreakdown:** `CameraController.swift:504-511` (`detail: error.localizedDescription`), 12 instances in the controller; typed `CameraRuntimeFailure` (87-100) exists but is bypassed.
* **RemediationParadigm:** Typed error channels end-to-end; stable error codes + structured context in diagnostics; taxonomy-keyed recovery policies.

### [Issue #50]: Fragile CI on Unpinned Tooling and a Bleeding-Edge OS Floor
* **Category:** E
* **SystemicImpact:** The only quality gate floats on `latest-stable` tooling and named simulators; product requires iOS 26.2, excluding most devices — verification and distribution both pinned to "newest," the opposite of decade-scale stability.
* **TechnicalBreakdown:** `.github/workflows/ios-ci.yml`: `xcode-version: latest-stable`, hardcoded "iPhone 17 Pro"/"iPhone 17" resolver, `-parallel-testing-enabled NO`, no lint/coverage steps (verified); `project.pbxproj:325` `IPHONEOS_DEPLOYMENT_TARGET = 26.2`.
* **RemediationParadigm:** Pinned Xcode + upgrade cadence; OS/device matrix; tiered pipelines; lint/coverage/dead-code gates; deliberate N-1/N-2 target policy.

---

# Phase 2: The 10-Year Strategic Master Blueprint

**Doctrine:** Bracketer's "edge" is the device itself — Neural Engine, ISP, Secure Enclave. The decade arc moves the system from a hand-maintained monolith that simulates intelligence with fixture data to a modular, contract-governed imaging OS whose real intelligence runs on-silicon, whose health is self-observed, and whose structure agents can safely refactor.

## Epoch I — Years 1–2: Foundation Remediation & Decoupling
**Objective:** Eradicate all 50 flaws; isolated, contract-tested modules over immutable state.

* **WS1 Truthful Substrate (Q1–Q2):** per-record fault isolation/quarantine (#21); transactional SQLite/WAL store (#3,#4,#6,#22); schema-migration engine + golden-file tests (#25); capture identity from session UUIDs + sequence metadata (#23,#24). Exit: corruption drill suite (power-cut, truncation, version-skew, concurrent writers) passes with zero data loss.
* **WS2 Capture Integrity (Q2–Q4):** actor-isolated pure capture state machine + AVFoundation adapter behind protocols (#2,#5,#43); event-driven settle with typed outcomes (#7,#26); plan-derived storage preflight (#27); save-outcome-driven sequencing with retry/abort (#28); latency-derived deadlines + late-arrival reconciliation (#29); interruption/thermal lifecycle (#30). Exit: #23–#30 scenarios deterministic in CI via fake devices.
* **WS3 Honest Product (Q3–Q6):** remove all fixture-derived UI (#13); internal lab target (#11,#12,#44,#45); jargon/copy pass (#18,#19); permission priming + denial recovery (#17); user-facing error layer (#16); String Catalogs + Dynamic Type (#14,#15); async progress architecture (#20).
* **WS4 Zero-Trust Floor (Q4–Q6):** privacy manifest + CI validation (#31); Unified Privacy Engine at every egress — geotag opt-in, share-time stripping, Spotlight tiering (#32,#34,#40); file protection + data classification (#33,#37); intent confirmation/rate limits/audit (#35); App Attest or ceremony deletion (#36); bounded streaming imports + fuzzing (#38); privacy-annotated logging (#39).
* **WS5 Engineering System (continuous):** SPM module decomposition + dependency direction (#1,#9,#10); typed keys/identifier catalogs (#48); typed error taxonomy (#49); one design system (#47); single living architecture doc + drift CI (#46); mutation-tested per-module suites (#42); MetricKit/signpost telemetry (#41); pinned-toolchain matrix CI + N-2 target policy (#50).

**Epoch exit criteria:** no file >1,000 lines; strict concurrency clean; crash-free ≥99.8%; bracket-completion SLO ≥99.5% via real telemetry; all 50 issues closed with regression tests.

## Epoch II — Years 3–5: Cognitive Automation & Edge Migration
* **Real computational photography (Y3–4):** Vision feature matching + homography alignment, optical-flow ghosting masks, Metal exposure fusion/tone mapping on Neural Engine/GPU — shipped only when beating manifest heuristics on a benchmark corpus; Epoch I scaffold contracts become the plug-in API.
* **Semantic telemetry (Y3):** privacy-budgeted structured event streams feeding dashboards and on-device learning; every user-visible number carries provenance (measured/inferred/estimated).
* **Predictive capture intelligence (Y3–5):** on-device models for scene-aware recipes, predicted-intent session pre-warm and storage pre-allocation, proactive review caching; behavior matrix never leaves device custody.
* **Fleet-edge distribution (Y4–5):** CKSyncEngine E2E-encrypted sync; capture/review/fuse across iPhone/iPad/Mac; transactional core becomes a CRDT-mergeable replicated log; fusion offload to idle fleet devices.
* **Agent-ready gate (Y5):** machine-readable module contracts (API+invariants+SLOs); doc-drift CI; mutation score ≥85% on core modules.

## Epoch III — Years 6–10: The Sovereign Autonomous Era
* **Self-healing (Y6–7):** autonomous quarantine-and-repair; migration canaries with auto-rollback; capture-path circuit breakers degrading to last-known-good pipelines on regression signatures.
* **Autonomic load-shedding (Y6–8):** real-time governor over thermal/battery/storage/ANE contention — mid-sequence bracket re-planning, charge-time fusion deferral, sync backpressure; all decisions telemetry-logged.
* **Real-time structural refactoring (Y7–10):** agents perform dependency upgrades, OS-API migrations, module rewrites — mutation-verified, canaried, merged behind invariant gates; humans review contract changes only.
* **Automated feature synthesis (Y8–10):** on-device behavior matrix identifies friction and synthesizes candidate automations, shadow-validated before being offered; only differentially private aggregates leave the device.
* **Sovereign trust (Y9–10):** Secure Enclave signing at sensor-read time, C2PA-compatible provenance manifests — honest completion of what the 2026 proof ceremony performed.

**Decade exit state:** a fleet-distributed, on-silicon, self-healing imaging OS — autonomous in operation and maintenance, sovereign in trust guarantees, with humans governing policy and photographers simply taking pictures.
