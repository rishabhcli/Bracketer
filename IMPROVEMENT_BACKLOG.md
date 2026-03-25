# Bracketer Improvement Backlog

This document turns the repo review into a concrete, ship-focused backlog of 100 high-impact improvements for Bracketer.

Companion execution plan: `TOP15_EXECUTION_ROADMAP.md`

Current repo signals behind these recommendations:
- Core behavior is concentrated in `CameraController.swift` and `ModernContentView.swift`, which makes the product fast to iterate on but risky to stabilize.
- Several user-facing controls are not wired end-to-end yet, especially flash and timer.
- Some advanced features are currently simulated or aspirational, notably focus peaking and depth analysis.
- Testing is mostly scaffold-only, so there is little protection around capture flows, persistence, and UI regressions.
- The app already has strong ambition around bracketing, manual control, metadata, and review, which makes reliability and truthfulness more important than more decorative surface area.

Scoring:
- Impact: Very High, High, Medium
- Effort: S, M, L
- Horizon: Now, Next, Later

## Top 15 Do First

1. `#1` Wire `flashMode` into the real capture pipeline.
2. `#2` Wire `timerMode` into the real capture pipeline.
3. `#5` Add a safe cancel and recovery path for in-flight bracket captures.
4. `#7` Guarantee orientation unlock on every capture success, failure, timeout, and dismissal path.
5. `#8` Disable or explain controls that the current lens or device cannot actually honor.
6. `#13` Add tap-to-focus and tap-to-meter so the camera behaves like a camera, not only a settings panel.
7. `#16` Make HUD indicators reflect real active capture configuration, not just persisted UI state.
8. `#31` Fix the image delete flow so the bracket sequence viewer remains consistent after deletion.
9. `#38` Replace simulated depth analysis with real depth support or hide it.
10. `#56` Stop camera, motion, and location work aggressively when the app backgrounds.
11. `#71` Add unit tests around bracket planning logic.
12. `#76` Add UI tests for onboarding, permission denial, and the main capture loop.
13. `#78` Add CI for build, test, and formatting checks.
14. `#79` Add crash reporting and basic product analytics before broader testing.
15. `#85` Give users explicit control over location metadata rather than assuming it is always on.

## Highest ROI In Under 1 Day

1. `#4` Persist `teleUses12MP` so capture behavior matches user intent across launches.
2. `#16` Make flash, timer, and ProRAW badges truthful.
3. `#31` Repair the delete flow in `ImageViewer`.
4. `#64` Read version/build from the bundle instead of hardcoding `1.0.0`.
5. `#86` Add one-tap permission recovery links and clearer denied-state messaging.

## Big Bets

1. `#21` Add recipe-based bracketing presets for real-world shooting scenarios.
2. `#24` Save each bracket as a first-class capture set with metadata and ordering.
3. `#61` Split the camera monolith into focused services.
4. `#93` Build a stronger export handoff to desktop HDR and editing workflows.
5. `#99` Use saved presets and recipes as a retention engine rather than a one-time setup feature.

## Do Not Do Yet

1. Do not build in-app HDR merging until the raw capture, grouping, and review pipeline is dependable.
2. Do not add social or community features before the capture product is trustworthy.
3. Do not attempt a cross-platform rewrite while the iOS capture stack is still stabilizing.
4. Do not invest in highly ornamental UI work while several controls are still only partially wired.
5. Do not market simulated pro features as real differentiation; either implement them fully or hide them.

## 1. Core Capture Reliability

1. Wire `flashMode` into the actual capture flow. The UI persists flash state, but `CameraController` hardcodes flash off for bracket capture. Impact: Very High. Effort: M. Horizon: Now.
2. Wire `timerMode` into capture start. The timer control exists in the UI, but there is no delayed shutter path in the camera controller. Impact: Very High. Effort: M. Horizon: Now.
3. Show capture failures inline with recovery actions. Errors are published, but the main camera surface needs a visible retry or guidance path when configuration or save failures occur. Impact: High. Effort: M. Horizon: Now.
4. Persist `teleUses12MP` in `SettingsStore`. Tele resolution is user-facing, but it resets because it lives only on `CameraController`. Impact: High. Effort: S. Horizon: Now.
5. Add a safe cancel and recovery path for in-progress bracket captures. Today the product can timeout, but the user has no clear cancel affordance or recovery workflow if the session stalls. Impact: Very High. Effort: M. Horizon: Now.
6. Harden bracket asset bookkeeping for partial-save scenarios. A bracket can finish with missing or reordered assets, and the viewer should handle incomplete sets gracefully. Impact: High. Effort: M. Horizon: Now.
7. Guarantee orientation unlock on every exit path. The app correctly locks orientation for bracket integrity, but that guarantee needs explicit coverage for timeout, permission loss, backgrounding, and save failure. Impact: Very High. Effort: M. Horizon: Now.
8. Build a real capability matrix and enforce it in the UI. Advanced controls should disable or explain themselves based on lens, format, and device support instead of allowing false affordances. Impact: Very High. Effort: M. Horizon: Now.
9. Replace silent no-op behavior with explicit user feedback during session configuration failures. When camera setup or lens switching fails, the app should show what happened and what the user can do next. Impact: High. Effort: M. Horizon: Now.
10. Introduce a small capture state machine. Encode states such as idle, preparing, capturing, saving, completed, and failed so the app stops relying on loosely coordinated booleans. Impact: Very High. Effort: L. Horizon: Next.

## 2. Camera UX And Controls

11. Consolidate duplicate control surfaces. The app currently carries overlapping modern, enhanced, legacy, and contextual control variants that increase complexity and user inconsistency. Impact: High. Effort: M. Horizon: Next.
12. Make shooting modes change behavior in visible, concrete ways. Users should understand exactly what Auto, Manual, Portrait, and Night mean in terms of controls, defaults, and capture behavior. Impact: High. Effort: M. Horizon: Now.
13. Add tap-to-focus and tap-to-meter. This is a baseline camera behavior and a major usability gap for a photography app. Impact: Very High. Effort: M. Horizon: Now.
14. Add pinch-to-zoom that cooperates with lens presets. The current zoom controls are rich, but direct pinch interaction would make the app feel much more natural. Impact: High. Effort: M. Horizon: Next.
15. Show live focus, exposure, and white balance status badges. When the user moves into manual controls, the camera should explain what is locked vs auto. Impact: High. Effort: M. Horizon: Next.
16. Make top-bar indicators truthful. If ProRAW, flash, timer, or tele resolution are unavailable or inactive, the UI should reflect reality rather than the last chosen setting. Impact: Very High. Effort: S. Horizon: Now.
17. Add long-press help and micro-tooltips to advanced controls. Onboarding promises quick explanations, but the UI should teach in place when users reach unfamiliar controls. Impact: High. Effort: M. Horizon: Next.
18. Add a customizable HUD density setting. Some photographers will want a minimal frame, others will want more status information visible at all times. Impact: Medium. Effort: M. Horizon: Later.
19. Add explicit limit feedback when sliders hit hardware bounds. Use haptics plus visible labels when ISO, shutter, focus, or white balance clamp to device limits. Impact: High. Effort: S. Horizon: Now.
20. Tune one-handed ergonomics and hit targets. Several controls are visually polished but still need easier reachability and larger touch targets for live shooting. Impact: High. Effort: M. Horizon: Next.

## 3. Bracketing Workflow And Output Quality

21. Add recipe-based bracketing presets. Common patterns like interiors, sunsets, architecture, and handheld HDR should be one tap instead of manual EV math. Impact: Very High. Effort: M. Horizon: Next.
22. Offer asymmetric custom bracket plans. Serious users will want patterns beyond fixed symmetric 3, 5, and 7 shot sets. Impact: High. Effort: M. Horizon: Next.
23. Let users save favorite bracket setups. EV step, shot count, timer, lens, and output format should be recallable as named presets. Impact: High. Effort: M. Horizon: Next.
24. Save each bracket as a first-class capture set. Preserve set ID, EV order, lens, timestamp, and asset IDs so review and export work with the set, not only individual photos. Impact: Very High. Effort: L. Horizon: Next.
25. Support RAW plus processed companion output. Many users will want DNG for editing and HEIF/JPEG for quick sharing from the same capture set. Impact: High. Effort: M. Horizon: Next.
26. Add a pre-capture stability readiness indicator. The motion subsystem should tell the user when handheld bracketing is likely to fail. Impact: High. Effort: M. Horizon: Next.
27. Detect likely subject movement and warn before capture. Bracketing only helps if the scene is suitable for it, and the app should prevent low-value captures. Impact: High. Effort: L. Horizon: Later.
28. Group the last bracket set automatically in the review flow. After capture, users should land in a dedicated set review instead of an opaque asset list. Impact: High. Effort: M. Horizon: Next.
29. Improve filename and grouping strategy. Use stable sequence IDs and EV ordering so assets remain intelligible outside the app. Impact: High. Effort: M. Horizon: Now.
30. Add merge guidance and export intent after capture. The app should help users understand what to do with a bracket set next, even if merging stays external. Impact: High. Effort: M. Horizon: Next.

## 4. Review, Gallery, And Post-Capture Experience

31. Fix the delete flow in `ImageViewer`. The viewer deletes from Photos, but it does not update the in-memory bracket list, which risks a broken review session immediately after deletion. Impact: Very High. Effort: S. Horizon: Now.
32. Fix the `EXIFViewer` dismissal model. It uses local state that does not appear to control parent presentation, so the close behavior should be simplified and made real. Impact: High. Effort: S. Horizon: Now.
33. Add a filmstrip scrubber for bracket sets. Dot indicators are not enough once capture sets become larger or users want direct navigation. Impact: High. Effort: M. Horizon: Next.
34. Add compare mode. Let users swipe, split, or blink between exposures to decide which frame to keep or export. Impact: High. Effort: M. Horizon: Next.
35. Add keep-best, reject, and favorite actions within a bracket set. The review flow should support curation, not only viewing. Impact: High. Effort: M. Horizon: Next.
36. Add set-level sharing and export. Users should be able to share the whole bracket set, not only the currently visible asset. Impact: High. Effort: M. Horizon: Next.
37. Save captures into a dedicated Bracketer album. This makes the app feel intentional and improves discoverability in Photos. Impact: High. Effort: M. Horizon: Now.
38. Replace simulated depth analysis with real depth support or hide it. The current depth viewer uses simulated data, which is dangerous for user trust. Impact: Very High. Effort: M. Horizon: Now.
39. Make RAW vs processed review truthful. The current toggle should explain when both versions exist, when only one exists, and which one is being shown. Impact: High. Effort: M. Horizon: Next.
40. Add loading, missing-data, and partial-state handling to metadata review. Review screens should not assume EXIF, GPS, histogram, or depth data are always present. Impact: High. Effort: M. Horizon: Now.

## 5. Onboarding, Education, And Discoverability

41. Add pre-permission education screens. Explain why camera, photos, motion, and location matter before the system prompts appear. Impact: High. Effort: M. Horizon: Now.
42. Show a first-run device capability summary. Tell the user which lenses, formats, and advanced features are available on their hardware. Impact: High. Effort: M. Horizon: Now.
43. Add inline education for EV, bracket count, ProRAW, focus peaking, and tele resolution. Advanced controls should teach at the moment of use. Impact: High. Effort: M. Horizon: Next.
44. Reframe onboarding around use cases rather than only feature names. Teach scenarios like real estate windows, sunsets, portraits, and night street scenes. Impact: High. Effort: M. Horizon: Next.
45. Add a release notes and what's-new screen. This keeps the app feeling alive and reduces repeated onboarding for returning users. Impact: Medium. Effort: S. Horizon: Later.
46. Let users replay targeted tutorials. Resetting full onboarding is too blunt; users should be able to revisit specific guidance. Impact: Medium. Effort: M. Horizon: Next.
47. Add a demo mode or sample bracket set for unsupported hardware. This helps marketing, onboarding, and design validation even when a device lacks full capabilities. Impact: Medium. Effort: M. Horizon: Later.
48. Explain unavailable features in context. If flash, timer, ProRAW, or depth are disabled, tell the user why on that lens or device. Impact: High. Effort: S. Horizon: Now.
49. Add a compact help center. Basic FAQs, workflow tips, and export advice should be available inside the app. Impact: Medium. Effort: M. Horizon: Later.
50. Add post-capture coaching. Use horizon level, histogram, exposure spread, and metadata to suggest what the user could improve next time. Impact: High. Effort: L. Horizon: Later.

## 6. Performance, Battery, And Memory

51. Reduce unnecessary preview processing. Histogram and other live analysis should back off when hidden or when capture is underway. Impact: High. Effort: M. Horizon: Now.
52. Replace simulated focus peaking animation with either a real edge-based implementation or a much lighter placeholder. The current animated dots create cost without truth. Impact: Very High. Effort: L. Horizon: Next.
53. Audit main-thread work during photo save and review. Asset creation, EXIF parsing, and UI updates should be measured so the app remains responsive during capture bursts. Impact: High. Effort: M. Horizon: Next.
54. Downsample review images more aggressively when full resolution is not needed. This will improve viewer smoothness and reduce memory spikes. Impact: High. Effort: M. Horizon: Now.
55. Make haptic engine usage more lifecycle-aware. Start it when needed, stop it when idle, and avoid unnecessary work after backgrounding. Impact: Medium. Effort: M. Horizon: Next.
56. Stop camera, motion, and location work aggressively when the app backgrounds or loses visibility. Capture apps burn battery quickly if lifecycle handling is loose. Impact: Very High. Effort: M. Horizon: Now.
57. Make histogram sampling adaptive by device tier. Faster devices can render more; slower devices should degrade gracefully. Impact: High. Effort: M. Horizon: Next.
58. Measure startup time and first-preview latency. This should become a tracked metric because nothing matters until the user sees live camera. Impact: High. Effort: M. Horizon: Now.
59. Add memory pressure handling for review surfaces. The image viewer and EXIF screens should release caches and expensive derived data when memory warnings occur. Impact: High. Effort: M. Horizon: Next.
60. Remove dead observers, timers, and duplicate reactive paths. The repo already fixed some leaks; a broader pass will likely uncover more low-grade battery and complexity issues. Impact: High. Effort: M. Horizon: Next.

## 7. Architecture And Maintainability

61. Split `CameraController` into focused services. A monolith of this size is too risky to keep evolving without regression. Impact: Very High. Effort: L. Horizon: Next.
62. Create a single source of truth for camera settings and active capture policy. Right now state is distributed across view state, `SettingsStore`, and controller properties. Impact: Very High. Effort: L. Horizon: Next.
63. Move shooting modes into a domain model with explicit policies. Modes should define allowed controls, defaults, and output behavior rather than only UI labels. Impact: High. Effort: M. Horizon: Next.
64. Replace hardcoded app version and build strings with bundle-derived values. The About screen should never require manual code edits to remain correct. Impact: High. Effort: S. Horizon: Now.
65. Replace hardcoded device naming with capability-led messaging. The current compatibility layer should avoid stale model maps where possible. Impact: High. Effort: M. Horizon: Next.
66. Centralize feature flags and availability checks. iOS and hardware gating is scattered and should be expressed in one place. Impact: High. Effort: M. Horizon: Next.
67. Upgrade logging to structured, privacy-aware instrumentation. Move toward `Logger`-style events with consistent categories, IDs, and user-safe metadata. Impact: High. Effort: M. Horizon: Next.
68. Add dependency injection for motion, location, photo library, notifications, and clock. This will unlock meaningful tests and safer iteration. Impact: Very High. Effort: L. Horizon: Next.
69. Unify the design system. There are several overlapping control implementations that should resolve into a smaller set of camera-specific primitives. Impact: High. Effort: M. Horizon: Next.
70. Add repo docs for architecture, feature ownership, build/run steps, and release process. The current project has code and notes, but not a durable operational guide. Impact: High. Effort: M. Horizon: Now.

## 8. Testing, QA, And Release Readiness

71. Add unit tests for EV offset generation. Bracket pattern math is central product logic and should be covered first. Impact: Very High. Effort: S. Horizon: Now.
72. Add tests for settings persistence and migrations. `SettingsStore` drives a large part of the experience and should survive app updates cleanly. Impact: High. Effort: S. Horizon: Now.
73. Add tests for device capability gating and compatibility messaging. This is product logic, not only UI copy. Impact: High. Effort: M. Horizon: Next.
74. Add tests for orientation lock and unlock behavior. This is a reliability-critical path for bracket integrity. Impact: High. Effort: M. Horizon: Now.
75. Add tests for filename generation and bracket asset ordering. Export correctness matters once users leave the app. Impact: High. Effort: S. Horizon: Now.
76. Add UI tests for onboarding, denied permissions, mode switching, and review flow. These are the parts most likely to regress with ongoing UI iteration. Impact: Very High. Effort: M. Horizon: Now.
77. Add snapshot coverage for portrait and landscape camera surfaces. This is especially useful because the product is UI-dense and orientation-heavy. Impact: High. Effort: M. Horizon: Next.
78. Add CI for build, unit tests, UI tests where feasible, and style checks. The repo needs automated quality gates before wider shipping. Impact: Very High. Effort: M. Horizon: Now.
79. Add crash reporting and basic analytics before broader distribution. TestFlight without observability slows everything down. Impact: Very High. Effort: M. Horizon: Now.
80. Create a QA matrix across device tiers, low-storage scenarios, permission states, and orientation transitions. Capture products fail in edge conditions that generic app QA misses. Impact: Very High. Effort: M. Horizon: Now.

## 9. Accessibility, Permissions, And Trust

81. Audit Dynamic Type and scalable layout. The current UI uses many fixed-size labels and dense controls that will not scale well. Impact: High. Effort: M. Horizon: Now.
82. Improve VoiceOver labels, values, and hints across camera controls. Some controls already carry labels, but the whole capture experience needs an accessibility pass. Impact: High. Effort: M. Horizon: Now.
83. Add reduced-motion and higher-contrast variants for the glass-heavy UI. Visual polish should not come at the cost of readability or comfort. Impact: High. Effort: M. Horizon: Next.
84. Enforce minimum hit target sizes on every camera control. A live-shooting interface needs generous touch targets under stress and motion. Impact: High. Effort: M. Horizon: Now.
85. Make location metadata opt-in and clearly controllable. The settings UI currently presents location as simply on, which is not privacy-forward enough. Impact: Very High. Effort: M. Horizon: Now.
86. Add denied-permission recovery flows that deep-link users to Settings. When access is denied, the app should clearly explain how to recover. Impact: High. Effort: S. Horizon: Now.
87. Add haptics settings, including off and reduced intensity. Some users will want tactile control, others will want silence. Impact: Medium. Effort: S. Horizon: Next.
88. Offer left-handed or customizable control placement. Camera ergonomics vary, and customization can materially improve field use. Impact: Medium. Effort: M. Horizon: Later.
89. Localize core product copy and permission messaging. Even a focused launch benefits from clean localization-ready architecture and strings. Impact: Medium. Effort: M. Horizon: Later.
90. Add an in-app privacy explanation. State clearly what stays on device, what is written to Photos, and what telemetry is collected once analytics ship. Impact: High. Effort: S. Horizon: Now.

## 10. Product Strategy, Monetization, And Launch

91. Tighten the positioning. Bracketer should explain why it exists next to the stock camera and other pro camera apps in one sentence. Impact: Very High. Effort: M. Horizon: Now.
92. Pick a narrow launch persona. Real estate shooters, landscape hobbyists, and HDR-focused creators are more actionable than "everyone who takes photos." Impact: Very High. Effort: M. Horizon: Now.
93. Build a stronger export handoff to desktop editing workflows. Bracketer will be more valuable if it fits into Lightroom, Photoshop, Photomator, and HDR merge workflows cleanly. Impact: Very High. Effort: M. Horizon: Next.
94. Make the Bracketer album and capture-set identity part of the brand. The product should leave a recognizable footprint in the user's library and workflow. Impact: High. Effort: M. Horizon: Next.
95. Decide monetization early and design the product around it. Paid upfront, free with pro upgrade, and time-limited trial all create different onboarding and packaging decisions. Impact: Very High. Effort: M. Horizon: Now.
96. Instrument the funnel. Track onboarding completion, permission grant rates, first successful bracket, repeat capture, and review usage. Impact: Very High. Effort: M. Horizon: Now.
97. Add a direct feedback loop. TestFlight testers and early users should be able to report issues and request features inside the app. Impact: High. Effort: M. Horizon: Now.
98. Build launch assets around before-and-after outcomes. Screens and copy should show why bracketed capture matters, not only that the UI looks pro. Impact: High. Effort: M. Horizon: Next.
99. Use recipes and saved presets as a retention feature. If Bracketer remembers the user's style and common scenes, it becomes habit-forming. Impact: Very High. Effort: M. Horizon: Next.
100. Keep the roadmap centered on truthful differentiation. The winning path is dependable bracket capture, strong review/export, and useful guidance, not a long list of partially wired pro features. Impact: Very High. Effort: M. Horizon: Now.
