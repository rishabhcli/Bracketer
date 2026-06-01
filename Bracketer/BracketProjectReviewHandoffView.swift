import SwiftUI

struct BracketProjectReviewHandoffView: View {
    let snapshot: BracketProjectReviewSnapshot
    let intelligenceAvailability: IntelligenceFeatureAvailability
    let onDismiss: () -> Void

    @State private var sequence: BracketReviewSequence
    @State private var refreshedNarrativeRun: BracketReviewNarrativeRun?
    @State private var isGeneratingNarrative = false
    @State private var isNarrativeDismissed = false

    init(
        snapshot: BracketProjectReviewSnapshot,
        intelligenceAvailability: IntelligenceFeatureAvailability,
        onDismiss: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.intelligenceAvailability = intelligenceAvailability
        self.onDismiss = onDismiss
        _sequence = State(initialValue: snapshot.sequence)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ProjectReviewProbe(
                        identifier: "review.project.handoff.summary",
                        label: "Project Review Handoff Summary",
                        value: snapshot.accessibilityValue
                    )
                    ProjectReviewProbe(
                        identifier: "review.project.accessibility",
                        label: "Review Workspace Accessibility Contract",
                        value: BracketProjectReviewAccessibilityContract.make(snapshot: snapshot).accessibilityValue
                    )
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.voiceOverTraversalProbeIdentifier,
                        label: "Review VoiceOver Traversal",
                        value: BracketProjectReviewVoiceOverTraversalSnapshot.make(snapshot: snapshot).accessibilityValue
                    )
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.finalWorkspaceFixtureProbeIdentifier,
                        label: "Final Review Workspace Fixture",
                        value: BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot: snapshot).accessibilityValue
                    )
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.tapTargetAuditProbeIdentifier,
                        label: "Review Export Tap Target Audit",
                        value: BracketProjectReviewTapTargetAudit.make(snapshot: snapshot).accessibilityValue
                    )
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.finalOutputsHandoffProbeIdentifier,
                        label: "Final Output Handoff Fixture",
                        value: BracketProjectFinalOutputManifest.make(
                            project: snapshot.project,
                            privacyLevel: .metadataOnly,
                            createdAt: snapshot.project.updatedAt
                        ).accessibilityValue
                    )
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.finalOutputReadinessAuditProbeIdentifier,
                        label: "Final Output Readiness Audit",
                        value: BracketProjectFinalOutputReadinessAudit.make(
                            project: snapshot.project,
                            privacyLevel: .metadataOnly,
                            createdAt: snapshot.project.updatedAt
                        ).accessibilityValue
                    )

                    if let selectedShot = sequence.selectedShot {
                        selectedShotCard(selectedShot)
                    }

                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.bestBaseFrameHandoffProbeIdentifier,
                        label: "Best Base Frame Handoff Fixture",
                        value: BracketProjectBestBaseFrameSuggestion.make(project: snapshot.project).accessibilityValue
                    )
                    bestBaseFrameCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.beforeAfterScrubHandoffProbeIdentifier,
                        label: "Before/After Scrub Handoff Fixture",
                        value: BracketProjectBeforeAfterScrubPlan.make(
                            project: snapshot.project,
                            selectedIndex: sequence.selectedShot?.index
                        ).accessibilityValue
                    )
                    beforeAfterScrubCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.perShotExposureHandoffProbeIdentifier,
                        label: "Per-shot Exposure Handoff Fixture",
                        value: BracketProjectPerShotExposureDistribution.make(project: snapshot.project).accessibilityValue
                    )
                    perShotExposureCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.focusEdgeInspectionHandoffProbeIdentifier,
                        label: "Focus/Edge Handoff Fixture",
                        value: BracketProjectFocusEdgeInspection.make(project: snapshot.project).accessibilityValue
                    )
                    focusEdgeInspectionCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.motionAlignmentOverlayHandoffProbeIdentifier,
                        label: "Motion/Alignment Handoff Fixture",
                        value: BracketProjectMotionAlignmentOverlay.make(project: snapshot.project).accessibilityValue
                    )
                    motionAlignmentOverlayCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.motionMetadataHandoffProbeIdentifier,
                        label: "Motion Metadata Handoff Fixture",
                        value: BracketProjectMotionMetadataReport.make(project: snapshot.project).accessibilityValue
                    )
                    motionMetadataCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.featureMatchFixtureHandoffProbeIdentifier,
                        label: "Feature Match Handoff Fixture",
                        value: BracketProjectFeatureMatchFixtureReport.make(project: snapshot.project).accessibilityValue
                    )
                    featureMatchFixtureCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.alignmentTransformHandoffProbeIdentifier,
                        label: "Alignment Transform Handoff Fixture",
                        value: BracketProjectAlignmentTransformReport.make(project: snapshot.project).accessibilityValue
                    )
                    alignmentTransformCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.motionBlurRiskHandoffProbeIdentifier,
                        label: "Motion/Blur Handoff Fixture",
                        value: BracketProjectMotionBlurRiskReport.make(project: snapshot.project).accessibilityValue
                    )
                    motionBlurRiskCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.ghostingRiskHandoffProbeIdentifier,
                        label: "Ghosting Risk Handoff Fixture",
                        value: BracketProjectGhostingRiskReport.make(project: snapshot.project).accessibilityValue
                    )
                    ghostingRiskCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.movingRegionMaskHandoffProbeIdentifier,
                        label: "Moving-Region Mask Handoff Fixture",
                        value: BracketProjectMovingRegionMaskReport.make(project: snapshot.project).accessibilityValue
                    )
                    movingRegionMaskCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.alignmentPerformanceHandoffProbeIdentifier,
                        label: "Alignment Performance Handoff Fixture",
                        value: BracketProjectAlignmentPerformanceReport.make(project: snapshot.project).accessibilityValue
                    )
                    alignmentPerformanceCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.alignmentExplanationHandoffProbeIdentifier,
                        label: "Alignment Explanation Handoff Fixture",
                        value: BracketProjectAlignmentExplanationReport.make(project: snapshot.project).accessibilityValue
                    )
                    alignmentExplanationCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.qualityReportProbeIdentifier,
                        label: "Capture Quality Handoff Fixture",
                        value: BracketProjectCaptureQualityReport.make(project: snapshot.project).accessibilityValue
                    )
                    captureQualityCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.mergeReadinessHandoffProbeIdentifier,
                        label: "Merge Readiness Handoff Fixture",
                        value: BracketProjectMergeReadinessReport.make(project: snapshot.project).accessibilityValue
                    )
                    mergeReadinessCard
                    finalOutputCard
                    ProjectReviewProbe(
                        identifier: BracketProjectReviewAccessibilityContract.assetResourcesHandoffProbeIdentifier,
                        label: "Asset Resources",
                        value: BracketProjectAssetResourceReport.make(project: snapshot.project).accessibilityValue
                    )
                    assetResourceCard
                    imageBundleHandoffProbe
                    imageBundleCard
                    resourceInspectionSection
                    thumbnailInspectionSection
                    exposureComparisonCard
                    pixelComparisonCard

                    if let generatedNote = snapshot.project.sidecar?.generatedNote {
                        generatedNoteCard(generatedNote)
                    } else if !isNarrativeDismissed {
                        BracketReviewNarrativeCard(
                            run: currentNarrativeRun,
                            isLoading: isGeneratingNarrative,
                            onRegenerate: regenerateNarrative,
                            onDismiss: { isNarrativeDismissed = true }
                        )
                    }

                    sequenceList
                    projectFacts
                }
                .padding(24)
            }
        }
        .accessibilityIdentifier("review.project.handoff")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("review.project.title")

                Text(snapshot.detail)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review.project.summary")

                Text(snapshot.source)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .accessibilityIdentifier("review.project.source")
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Close project review")
            .accessibilityIdentifier("review.project.closeButton")
        }
    }

    private func selectedShotCard(_ shot: BracketReviewShotSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(shot.selectedTitle, systemImage: shot.isBestExposureCandidate ? "star.fill" : "camera.metering.center.weighted")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(shot.isBestExposureCandidate ? .yellow : .white)

                Spacer()

                Text(sequence.selectedPositionLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                projectPill(shot.captureState.displayName, color: shot.captureState == .available ? .green : .orange)
                projectPill(shot.fileType, color: .cyan)
                projectPill(sequence.selectedRepresentationAvailabilityLabel, color: .yellow)
            }

            Text(shot.metadataAvailability.detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: { sequence = sequence.selectingPrevious() }) {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(sequence.selectedIndex == 0)
                .accessibilityLabel("Previous review shot")
                .accessibilityIdentifier("review.project.previousShotButton")

                Button(action: { sequence = sequence.selectingNext() }) {
                    Label("Next", systemImage: "chevron.right")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(sequence.selectedIndex >= sequence.shots.count - 1)
                .accessibilityLabel("Next review shot")
                .accessibilityIdentifier("review.project.nextShotButton")

                Button(action: { sequence = sequence.togglingRepresentation() }) {
                    Label(sequence.selectedRepresentation.displayName, systemImage: "square.2.layers.3d")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Toggle review representation")
                .accessibilityValue(sequence.selectedRepresentationAvailabilityLabel)
                .accessibilityIdentifier("review.project.representationToggle")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.72))
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.project.selectedShot")
        .accessibilityValue([shot.selectedTitle, shot.captureState.displayName, shot.fileType].joined(separator: " | "))
    }

    private var bestBaseFrameCard: some View {
        let suggestion = BracketProjectBestBaseFrameSuggestion.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Best Base Frame", systemImage: "target")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(bestBaseFrameColor(score: suggestion.confidenceScore))

                Spacer()

                Text(suggestion.confidenceLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(bestBaseFrameColor(score: suggestion.confidenceScore))
            }

            HStack(spacing: 10) {
                projectPill(suggestion.selectedShotLabel, color: .yellow)
                projectPill("Score \(suggestion.confidenceScore)", color: bestBaseFrameColor(score: suggestion.confidenceScore))
            }

            ForEach(suggestion.rationale.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(suggestion.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Best Base Frame Suggestion")
        .accessibilityValue(suggestion.accessibilityValue)
        .accessibilityIdentifier("review.project.bestBaseFrame.card")
    }

    private var beforeAfterScrubCard: some View {
        let plan = BracketProjectBeforeAfterScrubPlan.make(
            project: snapshot.project,
            selectedIndex: sequence.selectedShot?.index
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Before/After Scrub", systemImage: "slider.horizontal.below.rectangle")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)

                Spacer()

                Text("\(plan.stopCount) stops")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(plan.baselineLabel)", color: .yellow)
                projectPill("Compare \(plan.comparisonLabel)", color: .cyan)
            }

            projectPill(plan.comparisonRole, color: exposureComparisonColor(for: plan.comparisonRole))

            HStack(spacing: 8) {
                ForEach(plan.scrubStops) { stop in
                    beforeAfterScrubStop(stop)
                }
            }

            Text(plan.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Before After Scrub Plan")
        .accessibilityValue(plan.accessibilityValue)
        .accessibilityIdentifier("review.project.beforeAfterScrub.card")
    }

    private var perShotExposureCard: some View {
        let distribution = BracketProjectPerShotExposureDistribution.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Per-shot Exposure", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)

                Spacer()

                Text("\(distribution.shotCount) shots")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("EV spread \(distribution.evSpreadLabel)", color: .cyan)
                if let baseline = distribution.baselineDisplayLabel {
                    projectPill("Base \(baseline)", color: .yellow)
                }
                projectPill(distribution.clippingSummary, color: distribution.clippingWarningCount == 0 ? .green : .orange)
            }

            Text(distribution.guardSummary)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(distribution.items.prefix(5)) { item in
                perShotExposureRow(item)
            }

            Text(distribution.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Per-shot Exposure Distribution")
        .accessibilityValue(distribution.accessibilityValue)
        .accessibilityIdentifier("review.project.perShotExposure.card")
    }

    private var focusEdgeInspectionCard: some View {
        let inspection = BracketProjectFocusEdgeInspection.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Focus/Edge Inspection", systemImage: "scope")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)

                Spacer()

                Text(inspection.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(inspection.baselineLabel)", color: .yellow)
                projectPill(inspection.peakEdgeSummary, color: inspection.peakEdgeShotIndex == nil ? .orange : .cyan)
                projectPill(inspection.clippedEdgeSummary, color: inspection.clippedEdgeShotCount == 0 ? .green : .orange)
            }

            ForEach(inspection.items.prefix(5)) { item in
                focusEdgeInspectionRow(item)
            }

            ForEach(inspection.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(inspection.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(inspection.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus/Edge Inspection")
        .accessibilityValue(inspection.accessibilityValue)
        .accessibilityIdentifier("review.project.focusEdge.card")
    }

    private func focusEdgeInspectionRow(_ item: BracketProjectFocusEdgeInspection.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(focusEdgeRoleColor(for: item.role))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Edges \(item.syntheticEdgeRegionCount)/\(item.syntheticEdgeCandidateCount)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(item.syntheticEdgeRegionCount == 0 ? .orange : .green)

                Text("Peak \(item.syntheticPeakEdgeStrengthPercent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus edge \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func focusEdgeRoleColor(for role: String) -> Color {
        switch role {
        case "Focus anchor":
            return .yellow
        case "Darker guard focus check":
            return .cyan
        case "Brighter guard focus check":
            return .green
        case "Reference focus":
            return .white
        case "Edge detail clipped":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private var motionAlignmentOverlayCard: some View {
        let overlay = BracketProjectMotionAlignmentOverlay.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Motion/Alignment Overlay", systemImage: "ruler")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.mint)

                Spacer()

                Text(overlay.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(overlay.baselineLabel)", color: .yellow)
                projectPill(overlay.motionSummary, color: overlay.maxSyntheticMotionScore > 24 ? .orange : .green)
                projectPill(overlay.alignmentSummary, color: .cyan)
            }

            ForEach(overlay.items.prefix(5)) { item in
                motionAlignmentOverlayRow(item)
            }

            ForEach(overlay.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(overlay.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(overlay.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Motion/Alignment Overlay")
        .accessibilityValue(overlay.accessibilityValue)
        .accessibilityIdentifier("review.project.motionAlignment.card")
    }

    private func motionAlignmentOverlayRow(_ item: BracketProjectMotionAlignmentOverlay.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(motionAlignmentRoleColor(for: item.role))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Motion \(item.syntheticMotionScore)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(item.syntheticMotionScore > 24 ? .orange : .green)

                Text("Offset \(item.syntheticAlignmentOffsetXPoints),\(item.syntheticAlignmentOffsetYPoints)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Motion alignment \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func motionAlignmentRoleColor(for role: String) -> Color {
        switch role {
        case "Alignment anchor":
            return .yellow
        case "Darker guard overlay":
            return .cyan
        case "Brighter guard overlay":
            return .green
        case "Missing overlay source", "Failed overlay source":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private var motionMetadataCard: some View {
        let report = BracketProjectMotionMetadataReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Motion Metadata Capture", systemImage: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill(report.availabilitySummary, color: report.hasMotionSamples ? .green : .orange)
                projectPill(report.durationSummary, color: .cyan)
                projectPill(report.peakMotionSummary, color: report.hasMotionSamples ? .yellow : .white.opacity(0.58))
            }

            Text(report.qualityLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            Text("Source \(report.captureSource)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.captureContractNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Motion Metadata Capture")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier(BracketProjectReviewAccessibilityContract.motionMetadataProbeIdentifier)
    }

    private var alignmentTransformCard: some View {
        let report = BracketProjectAlignmentTransformReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Alignment Transform", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.teal)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.featurePairSummary, color: .cyan)
                projectPill(report.confidenceSummary, color: report.averageSyntheticConfidencePercent >= 70 ? .green : .orange)
            }

            ForEach(report.items.prefix(5)) { item in
                alignmentTransformRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment Transform")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.alignmentTransform.card")
    }

    private var featureMatchFixtureCard: some View {
        let report = BracketProjectFeatureMatchFixtureReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Feature Match Fixture", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.matchSummary, color: .cyan)
                projectPill(report.confidenceSummary, color: report.averageSyntheticMatchConfidencePercent >= 70 ? .green : .orange)
            }

            ForEach(report.items.prefix(5)) { item in
                featureMatchFixtureRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feature Match Fixture")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier(BracketProjectReviewAccessibilityContract.featureMatchFixtureProbeIdentifier)
    }

    private func featureMatchFixtureRow(_ item: BracketProjectFeatureMatchFixtureReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(alignmentConfidenceColor(for: item.syntheticMatchConfidencePercent))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Pairs \(item.syntheticMatchedFeaturePairCount)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)

                Text("Conf \(item.syntheticMatchConfidencePercent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(alignmentConfidenceColor(for: item.syntheticMatchConfidencePercent))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feature match \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func alignmentTransformRow(_ item: BracketProjectAlignmentTransformReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(alignmentConfidenceColor(for: item.syntheticTransformConfidencePercent))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Pairs \(item.syntheticFeaturePairCount)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)

                Text("Conf \(item.syntheticTransformConfidencePercent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(alignmentConfidenceColor(for: item.syntheticTransformConfidencePercent))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment transform \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func alignmentConfidenceColor(for confidence: Int) -> Color {
        switch confidence {
        case 0..<60:
            return .orange
        case 60..<80:
            return .yellow
        default:
            return .green
        }
    }

    private var motionBlurRiskCard: some View {
        let report = BracketProjectMotionBlurRiskReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Motion/Blur Risk", systemImage: "wind")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.highRiskSummary, color: report.highRiskShotCount == 0 ? .green : .orange)
                projectPill(report.maxRiskSummary, color: report.maxSyntheticBlurRiskScore >= 35 ? .orange : .green)
            }

            ForEach(report.items.prefix(5)) { item in
                motionBlurRiskRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Motion/Blur Risk")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.motionBlur.card")
    }

    private func motionBlurRiskRow(_ item: BracketProjectMotionBlurRiskReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(motionBlurRiskColor(for: item.syntheticBlurRiskScore))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Risk \(item.syntheticBlurRiskScore)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(motionBlurRiskColor(for: item.syntheticBlurRiskScore))

                Text("Pressure \(item.syntheticExposurePressureScore)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Motion blur \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func motionBlurRiskColor(for score: Int) -> Color {
        switch score {
        case 0...15:
            return .green
        case 16...34:
            return .yellow
        default:
            return .orange
        }
    }

    private var ghostingRiskCard: some View {
        let report = BracketProjectGhostingRiskReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Ghosting Risk", systemImage: "person.2.wave.2")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.pink)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.highRiskSummary, color: report.highRiskShotCount == 0 ? .green : .orange)
                projectPill(report.maxRiskSummary, color: report.maxSyntheticGhostingRiskScore >= 42 ? .orange : .green)
            }

            ForEach(report.items.prefix(5)) { item in
                ghostingRiskRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ghosting Risk")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.ghostingRisk.card")
    }

    private func ghostingRiskRow(_ item: BracketProjectGhostingRiskReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ghostingRiskColor(for: item.syntheticGhostingRiskScore))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Ghost \(item.syntheticGhostingRiskScore)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(ghostingRiskColor(for: item.syntheticGhostingRiskScore))

                Text("Offset \(item.syntheticAlignmentOffsetPoints)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ghosting risk \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func ghostingRiskColor(for score: Int) -> Color {
        switch score {
        case 0...20:
            return .green
        case 21...41:
            return .yellow
        default:
            return .orange
        }
    }

    private var movingRegionMaskCard: some View {
        let report = BracketProjectMovingRegionMaskReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Moving-Region Mask", systemImage: "figure.walk.motion")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.mint)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.highPrioritySummary, color: report.highPriorityMaskCount == 0 ? .green : .orange)
                projectPill(report.maxCoverageSummary, color: report.maxSyntheticMaskCoveragePercent >= 36 ? .orange : .green)
            }

            ForEach(report.items.prefix(5)) { item in
                movingRegionMaskRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moving-Region Mask")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.movingRegionMask.card")
    }

    private func movingRegionMaskRow(_ item: BracketProjectMovingRegionMaskReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(movingRegionMaskColor(for: item.syntheticMaskCoveragePercent))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Mask \(item.syntheticMaskTileCount)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(movingRegionMaskColor(for: item.syntheticMaskCoveragePercent))

                Text("\(item.syntheticMaskCoveragePercent)% guide")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moving-region mask \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func movingRegionMaskColor(for coveragePercent: Int) -> Color {
        switch coveragePercent {
        case 0...17:
            return .green
        case 18...35:
            return .yellow
        default:
            return .orange
        }
    }

    private var alignmentPerformanceCard: some View {
        let report = BracketProjectAlignmentPerformanceReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Alignment Performance Notes", systemImage: "speedometer")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.totalWorkSummary, color: .cyan)
                projectPill(report.peakWorkSummary, color: alignmentPerformanceColor(for: report.peakEstimatedWorkUnits))
            }

            ForEach(report.items.prefix(5)) { item in
                alignmentPerformanceRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment Performance Notes")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.alignmentPerformance.card")
    }

    private func alignmentPerformanceRow(_ item: BracketProjectAlignmentPerformanceReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(alignmentPerformanceColor(for: item.estimatedTotalWorkUnits))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Work \(item.estimatedTotalWorkUnits)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(alignmentPerformanceColor(for: item.estimatedTotalWorkUnits))

                Text("Mask \(item.syntheticMaskTileCount)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment performance \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func alignmentPerformanceColor(for workUnits: Int) -> Color {
        switch workUnits {
        case 0...79:
            return .green
        case 80...159:
            return .yellow
        default:
            return .orange
        }
    }

    private var alignmentExplanationCard: some View {
        let report = BracketProjectAlignmentExplanationReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Alignment Explanation", systemImage: "text.bubble")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)

                Spacer()

                Text(report.summaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                projectPill("Base \(report.baselineLabel)", color: .yellow)
                projectPill(report.highAttentionSummary, color: report.highAttentionShotCount == 0 ? .green : .orange)
                projectPill(report.topConcernSummary, color: alignmentExplanationColor(for: report.topConcernScore))
            }

            Text(report.userFacingSummary)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(report.items.prefix(5)) { item in
                alignmentExplanationRow(item)
            }

            ForEach(report.guidance.prefix(3), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(report.syntheticFixtureNote)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment Explanation")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier(BracketProjectReviewAccessibilityContract.alignmentExplanationProbeIdentifier)
    }

    private func alignmentExplanationRow(_ item: BracketProjectAlignmentExplanationReport.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(alignmentExplanationColor(for: item.attentionScore))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))

                Text(item.explanationSummary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Watch \(item.attentionScore)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(alignmentExplanationColor(for: item.attentionScore))

                Text("Ghost \(item.syntheticGhostingRiskScore)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment explanation \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func alignmentExplanationColor(for score: Int) -> Color {
        switch score {
        case 0...59:
            return .green
        case 60...119:
            return .yellow
        default:
            return .orange
        }
    }

    private var captureQualityCard: some View {
        let report = BracketProjectCaptureQualityReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Capture Quality", systemImage: "checkmark.shield")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(captureQualityColor(score: report.readinessScore))

                Spacer()

                Text("Score \(report.readinessScore)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 10) {
                projectPill("\(report.availableShotCount)/\(report.shotCount) available", color: .green)
                projectPill("EV \(BracketEVFormatter.displayLabel(for: report.evSpread)) spread", color: .cyan)
                projectPill(report.readinessLabel, color: captureQualityColor(score: report.readinessScore))
            }

            ForEach(report.findings.prefix(3)) { finding in
                VStack(alignment: .leading, spacing: 3) {
                    Text(finding.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(finding.severity == "Warning" ? .orange : .white)

                    Text(finding.recommendation)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capture Quality")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier(BracketProjectReviewAccessibilityContract.qualityReportCardProbeIdentifier)
    }

    private var exposureComparisonCard: some View {
        let comparison = BracketProjectExposureComparison.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Exposure Compare", systemImage: "rectangle.split.2x1")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .accessibilityLabel("Exposure Comparison")
                    .accessibilityValue(comparison.accessibilityValue)
                    .accessibilityIdentifier("review.project.exposureComparison")

                Spacer()

                Text(exposureComparisonBaselineLabel(comparison))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            ForEach(comparison.items) { item in
                exposureComparisonRow(item)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var mergeReadinessCard: some View {
        let report = BracketProjectMergeReadinessReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Merge Readiness", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(captureQualityColor(score: report.score))

                Spacer()

                Text("Score \(report.score)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 10) {
                projectPill(report.label, color: captureQualityColor(score: report.score))
                projectPill("Blockers \(report.blockerCount)", color: report.blockerCount == 0 ? .green : .red)
                projectPill("Cautions \(report.cautionCount)", color: report.cautionCount == 0 ? .green : .orange)
            }

            ForEach(report.evidence.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(mergeReadinessColor(for: item.severity))

                    Text(item.recommendation)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Merge Readiness")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.mergeReadiness.card")
    }

    private var finalOutputCard: some View {
        let manifest = BracketProjectFinalOutputManifest.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let audit = BracketProjectFinalOutputReadinessAudit.make(manifest: manifest)
        let firstActions = Array(audit.actionPlan.dropLast().prefix(2))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Final Outputs", systemImage: "shippingbox")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(manifest.readyOutputCount > 0 ? .green : .orange)

                Spacer()

                Text("\(manifest.readyOutputCount)/\(manifest.outputCount) ready")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                projectPill("Sources \(manifest.sourceExposureCount)", color: .cyan)
                projectPill("Pairs \(manifest.completeResourcePairCount)", color: .green)
                projectPill("Blocked \(manifest.blockedOutputCount)", color: manifest.blockedOutputCount == 0 ? .green : .orange)
            }

            ForEach(manifest.outputs.prefix(3)) { output in
                VStack(alignment: .leading, spacing: 3) {
                    Text(output.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(finalOutputColor(for: output.readiness))

                    Text(output.blockers.first ?? output.recommendation)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Action plan")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Spacer()

                    Text("\(audit.statusLabel) | \(audit.actionPlanStepCount) step(s)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.58))
                }

                ForEach(firstActions, id: \.self) { step in
                    Text("- \(step)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(manifest.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Final Outputs")
        .accessibilityValue([manifest.accessibilityValue, "Action plan: \(audit.actionPlanSummary)"].joined(separator: " | "))
        .accessibilityIdentifier("review.project.finalOutputs.card")
    }

    private var assetResourceCard: some View {
        let report = BracketProjectAssetResourceReport.make(project: snapshot.project)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Asset Resources", systemImage: "externaldrive.badge.checkmark")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.teal)

                Spacer()

                Text("\(report.completePairCount)/\(report.shotCount) pairs")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                projectPill("RAW \(report.rawAvailableCount)", color: .cyan)
                projectPill("Processed \(report.processedAvailableCount)", color: .green)
                projectPill("Recovery IDs \(report.recoveryIdentifierCount)", color: .yellow)
            }

            ForEach(report.items.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(item.displayLabel) - \(item.resourceState)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(assetResourceColor(for: item.resourceState))

                    Text(item.recommendation)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Asset Resources")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.assetResources.card")
    }

    private var imageBundleCard: some View {
        let manifest = BracketProjectImageBundleManifest.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let package = BracketProjectImageBundleDraftPackageDocument.package(manifest: manifest)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Image Bundle", systemImage: "folder.badge.gearshape")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(manifest.missingRepresentationCount == 0 ? .green : .orange)

                Spacer()

                Text("\(manifest.exportableShotCount)/\(manifest.shotCount) exportable")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                projectPill("RAW \(manifest.rawRequestedCount)", color: .cyan)
                projectPill("Processed \(manifest.processedRequestedCount)", color: .green)
                projectPill("Draft files \(package.entryCount)", color: .yellow)
            }

            ForEach(manifest.items.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(item.displayLabel) - \(item.bundleReadiness)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(imageBundleColor(for: item.bundleReadiness))

                    Text(item.plannedFilenames.joined(separator: ", "))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(package.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Image Bundle")
        .accessibilityValue(imageBundleAccessibilityValue(manifest: manifest, package: package))
        .accessibilityIdentifier("review.project.imageBundle.card")
    }

    private var imageBundleHandoffProbe: some View {
        let manifest = BracketProjectImageBundleManifest.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let package = BracketProjectImageBundleDraftPackageDocument.package(manifest: manifest)

        return ProjectReviewProbe(
            identifier: BracketProjectReviewAccessibilityContract.imageBundleHandoffProbeIdentifier,
            label: "Image Bundle Handoff Fixture",
            value: imageBundleAccessibilityValue(manifest: manifest, package: package)
        )
    }

    @ViewBuilder
    private var resourceInspectionSection: some View {
        if let report = BracketProjectResourceInspectionReport.make(project: snapshot.project) {
            ProjectReviewProbe(
                identifier: "review.project.resourceInspection",
                label: "Resource Inspection",
                value: report.accessibilityValue
            )
            resourceInspectionCard(report)
        }
    }

    private func resourceInspectionCard(_ report: BracketProjectResourceInspectionReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Resource Inspection", systemImage: "doc.viewfinder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)

                Spacer()

                Text("\(report.inspectedShotCount)/\(report.shotCount) inspected")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                projectPill("RAW \(report.rawResourceCount)", color: .cyan)
                projectPill("Processed \(report.processedResourceCount)", color: .green)
                projectPill("Mismatches \(report.mismatchCount)", color: report.mismatchCount == 0 ? .green : .orange)
            }

            ForEach(report.items.filter { !$0.resources.isEmpty }.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(item.displayLabel) - \(item.resourceState)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(resourceInspectionColor(for: item.resourceState))

                    Text(item.recommendation)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Resource Inspection")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.resourceInspection.card")
    }

    @ViewBuilder
    private var thumbnailInspectionSection: some View {
        if let report = BracketProjectThumbnailInspectionReport.make(project: snapshot.project) {
            ProjectReviewProbe(
                identifier: "review.project.thumbnailInspection",
                label: "Thumbnail Inspection",
                value: report.accessibilityValue
            )
            thumbnailInspectionCard(report)
        }
    }

    private func thumbnailInspectionCard(_ report: BracketProjectThumbnailInspectionReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Thumbnail Delivery", systemImage: "photo.stack")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.mint)

                Spacer()

                Text("\(report.deliveredShotCount)/\(report.shotCount) delivered")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                projectPill("Requested \(report.requestedShotCount)", color: .cyan)
                projectPill("Degraded \(report.degradedShotCount)", color: report.degradedShotCount == 0 ? .green : .orange)
                projectPill("Errors \(report.errorShotCount)", color: report.errorShotCount == 0 ? .green : .red)
            }

            ForEach(report.items.filter { $0.resultState != "not-requested" }.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(item.displayLabel) - \(item.resultState)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(thumbnailInspectionColor(for: item.resultState))

                    Text(item.accessibilityValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(report.boundary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thumbnail Inspection")
        .accessibilityValue(report.accessibilityValue)
        .accessibilityIdentifier("review.project.thumbnailInspection.card")
    }

    private func exposureComparisonRow(_ item: BracketProjectExposureComparison.Item) -> some View {
        let isSelected = sequence.selectedShot?.index == item.index

        return Button {
            selectExposureComparisonItem(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .yellow : .white)
                    .frame(minWidth: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.role)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(exposureComparisonColor(for: item.role))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.recommendation)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .yellow : .white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.yellow.opacity(0.16) : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exposure comparison \(item.displayLabel)")
        .accessibilityValue(item.accessibilityValue)
        .accessibilityIdentifier("review.project.exposureComparison.item.\(item.index)")
    }

    @ViewBuilder
    private var pixelComparisonCard: some View {
        if let comparison = BracketProjectSideBySidePixelComparison.make(project: snapshot.project) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Pixel Compare", systemImage: "rectangle.split.2x1.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.mint)
                        .accessibilityLabel("Side-by-side Pixel Compare")
                        .accessibilityValue(comparison.accessibilityValue)
                        .accessibilityIdentifier("review.project.pixelComparison")

                    Spacer()

                    Text("Baseline \(comparison.baselineLabel)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.58))
                }

                Text(comparison.boundary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(comparison.pairs) { pair in
                    pixelComparisonRow(pair)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func pixelComparisonRow(_ pair: BracketProjectSideBySidePixelComparison.Pair) -> some View {
        let isSelected = sequence.selectedShot?.index == pair.comparisonIndex

        return Button {
            selectPixelComparisonPair(pair)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(pair.baselineLabel) vs \(pair.comparisonLabel)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? .yellow : .white)

                        Text(pair.comparisonRole)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(exposureComparisonColor(for: pair.comparisonRole))
                    }

                    Spacer(minLength: 8)

                    Text("Delta \(pair.maxChannelDelta)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.62))
                }

                HStack(alignment: .top, spacing: 10) {
                    pixelStrip(pair.baselineRGBABytes, label: "Base")
                    pixelStrip(pair.comparisonRGBABytes, label: "Compare")
                    pixelStrip(pair.differenceRGBABytes, label: "Diff")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.yellow.opacity(0.16) : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pixel comparison \(pair.comparisonLabel)")
        .accessibilityValue(pair.accessibilityValue)
        .accessibilityIdentifier("review.project.pixelComparison.item.\(pair.comparisonIndex)")
    }

    private func pixelStrip(_ rgbaBytes: [UInt8], label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.54))

            HStack(spacing: 3) {
                ForEach(Array(0..<min(rgbaBytes.count / 4, 3)), id: \.self) { pixelIndex in
                    pixelSwatch(rgbaBytes, pixelIndex: pixelIndex)
                }
            }
        }
    }

    private func beforeAfterScrubStop(_ stop: BracketProjectBeforeAfterScrubPlan.ScrubStop) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(scrubStopColor(stop.previewRGBABytes))
                .frame(height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            Text("\(stop.positionPercent)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stop.label)
        .accessibilityValue(stop.accessibilityValue)
    }

    private func perShotExposureRow(_ item: BracketProjectPerShotExposureDistribution.Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.shotLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(exposureComparisonColor(for: item.role))

                Text(item.role)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()

            Text(item.clippingSummary)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(item.clippingWarningCount == 0 ? .green : .orange)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Per-shot exposure \(item.shotLabel)")
        .accessibilityValue(item.accessibilityValue)
    }

    private func pixelSwatch(_ rgbaBytes: [UInt8], pixelIndex: Int) -> some View {
        let offset = pixelIndex * 4
        let red = rgbaBytes.indices.contains(offset) ? rgbaBytes[offset] : 0
        let green = rgbaBytes.indices.contains(offset + 1) ? rgbaBytes[offset + 1] : 0
        let blue = rgbaBytes.indices.contains(offset + 2) ? rgbaBytes[offset + 2] : 0

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                Color(
                    red: Double(red) / 255,
                    green: Double(green) / 255,
                    blue: Double(blue) / 255
                )
            )
            .frame(width: 18, height: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    private func scrubStopColor(_ rgbaBytes: [UInt8]) -> Color {
        let red = rgbaBytes.indices.contains(0) ? rgbaBytes[0] : 0
        let green = rgbaBytes.indices.contains(1) ? rgbaBytes[1] : 0
        let blue = rgbaBytes.indices.contains(2) ? rgbaBytes[2] : 0

        return Color(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }

    private func generatedNoteCard(_ note: BracketManifestSidecar.GeneratedNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(note.title, systemImage: note.usedAppleIntelligence ? "sparkles" : "text.quote")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)

            Text(note.summary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            Text(note.mergeAdvice)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("review.project.generatedNote")
        .accessibilityValue([note.title, note.summary, note.disclosure].joined(separator: " | "))
    }

    private var sequenceList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sequence")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            ForEach(Array(sequence.shots.enumerated()), id: \.element.id) { position, shot in
                Button {
                    sequence = sequence.selecting(index: position)
                } label: {
                    HStack(spacing: 12) {
                        Text(shot.sequenceLabel)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.68))

                        if shot.isBestExposureCandidate {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                        }

                        Spacer()

                        Text(shot.captureState.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(shot.captureState == .available ? .green : .orange)

                        Text(shot.displayLabel)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(position == sequence.selectedIndex ? .yellow : .white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(position == sequence.selectedIndex ? Color.yellow.opacity(0.18) : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(shot.sequenceLabel), \(shot.displayLabel)")
                .accessibilityValue([shot.captureState.displayName, shot.fileType, shot.metadataAvailability.displayName].joined(separator: " | "))
                .accessibilityIdentifier("review.project.shot.\(shot.index)")
            }
        }
    }

    private var projectFacts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Project Facts", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)

            Text(snapshot.project.privacy.accessibilityValue)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if let diagnostics = snapshot.project.diagnosticsReference?.summary {
                Text(diagnostics)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("review.project.facts")
        .accessibilityValue(snapshot.project.projectLibraryAccessibilityValue)
    }

    private func projectPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func exposureComparisonBaselineLabel(_ comparison: BracketProjectExposureComparison) -> String {
        guard let baseline = comparison.baselineDisplayLabel else {
            return "Baseline unavailable"
        }

        return "Baseline \(baseline)"
    }

    private func exposureComparisonColor(for role: String) -> Color {
        switch role {
        case "Baseline exposure":
            return .yellow
        case "Darker highlight guard":
            return .cyan
        case "Brighter shadow guard":
            return .green
        case "Missing planned exposure", "Failed exposure":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private func assetResourceColor(for resourceState: String) -> Color {
        switch resourceState {
        case "raw-and-processed-ready":
            return .green
        case "raw-only", "processed-only":
            return .yellow
        case "missing-asset", "failed-capture":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private func imageBundleColor(for readiness: String) -> Color {
        if readiness.hasPrefix("ready-") {
            return .green
        }
        if readiness.contains("incomplete") {
            return .yellow
        }
        if readiness.contains("missing") || readiness.contains("failed") {
            return .orange
        }
        return .white.opacity(0.78)
    }

    private func resourceInspectionColor(for resourceState: String) -> Color {
        switch resourceState {
        case "inspected-raw-and-processed":
            return .green
        case "inspected-raw-only", "inspected-processed-only":
            return .yellow
        case "inspection-mismatch":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private func thumbnailInspectionColor(for resultState: String) -> Color {
        switch resultState {
        case "thumbnail-delivered", "cloud-backed-thumbnail-delivered":
            return .green
        case "degraded-thumbnail-delivered":
            return .yellow
        case "thumbnail-error", "request-cancelled", "thumbnail-missing":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private func mergeReadinessColor(for severity: String) -> Color {
        switch severity {
        case "Ready":
            return .green
        case "Caution":
            return .yellow
        case "Blocker":
            return .orange
        default:
            return .white.opacity(0.78)
        }
    }

    private func finalOutputColor(for readiness: String) -> Color {
        if readiness.hasPrefix("planned") {
            return .yellow
        }
        if readiness.hasPrefix("blocked") {
            return .orange
        }
        return .green
    }

    private func imageBundleAccessibilityValue(
        manifest: BracketProjectImageBundleManifest,
        package: BracketProjectImageBundleDraftPackageDocument.Package
    ) -> String {
        [
            "Draft package \(package.entryCount) synthetic entries",
            "\(package.totalByteCount) synthetic bytes",
            package.boundary,
            manifest.accessibilityValue,
        ].joined(separator: " | ")
    }

    private func captureQualityColor(score: Int) -> Color {
        if score >= 85 {
            return .green
        }
        if score >= 60 {
            return .yellow
        }
        return .orange
    }

    private func bestBaseFrameColor(score: Int) -> Color {
        if score >= 90 { return .green }
        if score >= 70 { return .yellow }
        return .orange
    }

    private func selectExposureComparisonItem(_ item: BracketProjectExposureComparison.Item) {
        guard let position = sequence.shots.firstIndex(where: { $0.index == item.index }) else {
            return
        }

        sequence = sequence.selecting(index: position)
    }

    private func selectPixelComparisonPair(_ pair: BracketProjectSideBySidePixelComparison.Pair) {
        guard let position = sequence.shots.firstIndex(where: { $0.index == pair.comparisonIndex }) else {
            return
        }

        sequence = sequence.selecting(index: position)
    }

    private var narrativeRequest: BracketReviewNarrativeRequest {
        BracketReviewNarrativeRequest.make(
            context: BracketNarrativeContext.make(
                manifest: snapshot.project.manifest,
                sequence: sequence,
                intelligenceAvailability: intelligenceAvailability
            )
        )
    }

    private var currentNarrativeRun: BracketReviewNarrativeRun {
        refreshedNarrativeRun ?? DeterministicBracketReviewNarrative.run(
            for: narrativeRequest,
            fallbackReason: "Restored from saved project metadata."
        )
    }

    private func regenerateNarrative() {
        isNarrativeDismissed = false
        isGeneratingNarrative = true
        let request = narrativeRequest
        Task {
            let run = await BracketReviewNarrativeEngine.live.response(for: request)
            await MainActor.run {
                refreshedNarrativeRun = run
                isGeneratingNarrative = false
            }
        }
    }
}

private struct ProjectReviewProbe: View {
    let identifier: String
    let label: String
    let value: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
    }
}
