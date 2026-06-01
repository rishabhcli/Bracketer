import SwiftUI

struct SimulatedBracketReview: Equatable, Identifiable, Sendable {
    let plan: BracketPlan
    let assetIdentifiers: [String]
    let capturedAt: Date
    let captureDevice: BracketManifest.CaptureDeviceSnapshot
    let captureLocation: BracketManifest.CaptureLocationSnapshot
    let captureMotion: BracketManifest.CaptureMotionSnapshot

    var id: String {
        assetIdentifiers.joined(separator: "|")
    }

    static func make(plan: BracketPlan) -> SimulatedBracketReview {
        SimulatedBracketReview(
            plan: plan,
            assetIdentifiers: plan.shots.map { "simulated-\($0.filenameLabel)" },
            capturedAt: Date(timeIntervalSince1970: 0),
            captureDevice: .simulatedWide,
            captureLocation: .simulatedNotRequested,
            captureMotion: .simulatedUnavailable
        )
    }

    var sequence: BracketReviewSequence {
        BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: assetIdentifiers,
            capturedAt: capturedAt
        )
    }

    var manifest: BracketManifest {
        manifest()
    }

    func manifest(
        recipe: AppliedBracketRecipeRecord? = nil,
        captureMotion resolvedCaptureMotion: BracketManifest.CaptureMotionSnapshot? = nil
    ) -> BracketManifest {
        sequence.manifest(
            groupIdentifier: id,
            source: .simulated,
            plan: plan,
            recipe: recipe,
            captureDevice: captureDevice,
            captureLocation: captureLocation,
            captureMotion: resolvedCaptureMotion ?? captureMotion
        )
    }
}

struct SimulatedBracketReviewView: View {
    let review: SimulatedBracketReview
    let appliedRecipeRecord: AppliedBracketRecipeRecord?
    let intelligenceAvailability: IntelligenceFeatureAvailability
    let onDismiss: () -> Void

    @State private var sequence: BracketReviewSequence
    @State private var showMetadata = false
    @State private var showDeleteConfirmation = false
    @State private var refreshedNarrativeRun: BracketReviewNarrativeRun?
    @State private var isGeneratingNarrative = false
    @State private var isNarrativeDismissed = false

    init(
        review: SimulatedBracketReview,
        appliedRecipeRecord: AppliedBracketRecipeRecord? = nil,
        intelligenceAvailability: IntelligenceFeatureAvailability = .simulatorUnsupported,
        onDismiss: @escaping () -> Void
    ) {
        self.review = review
        self.appliedRecipeRecord = appliedRecipeRecord
        self.intelligenceAvailability = intelligenceAvailability
        self.onDismiss = onDismiss
        _sequence = State(initialValue: review.sequence)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if sequence.isEmpty {
                SimulatedReviewEmptyState(onDismiss: onDismiss)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if let selectedShot = sequence.selectedShot {
                            SimulatedReviewSelectedShotCard(
                                sequence: sequence,
                                selectedShot: selectedShot,
                                showMetadata: showMetadata,
                                manifestJSON: manifestJSON,
                                onPrevious: { updateSequence(sequence.selectingPrevious()) },
                                onNext: { updateSequence(sequence.selectingNext()) },
                                onToggleRepresentation: { updateSequence(sequence.togglingRepresentation()) },
                                onToggleMetadata: { showMetadata.toggle() },
                                onDelete: { showDeleteConfirmation = true }
                            )
                        }

                        SimulatedReviewProbe(
                            identifier: "review.sequence.manifestRecipe",
                            label: "Simulated Review Manifest Recipe",
                            value: manifestRecipeAccessibilityValue
                        )

                        if !isNarrativeDismissed {
                            BracketReviewNarrativeCard(
                                run: currentNarrativeRun,
                                isLoading: isGeneratingNarrative,
                                onRegenerate: regenerateNarrative,
                                onDismiss: { isNarrativeDismissed = true }
                            )
                        }

                        SimulatedReviewSequenceList(
                            sequence: sequence,
                            onSelect: { index in updateSequence(sequence.selecting(index: index)) }
                        )

                        if showMetadata, let selectedShot = sequence.selectedShot {
                            SimulatedReviewMetadataPanel(shot: selectedShot)
                        }

                        Text("No Photos writes were performed. This review was generated by the UI-test camera harness.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .accessibilityIdentifier("review.simulated.disclaimer")
                    }
                    .padding(24)
                }
            }
        }
        .confirmationDialog("Remove Simulated Shot?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Shot", role: .destructive) {
                updateSequence(sequence.deletingSelected())
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes only the in-memory simulated review item. No Photos library asset is touched.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Simulated Bracket")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("review.simulated.title")

                Text("\(review.plan.shotCount) shots · +/-\(String(format: "%.1f", review.plan.evStep)) EV")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .accessibilityIdentifier("review.simulated.summary")

                HStack(spacing: 8) {
                    Text(sequence.countLabel)
                        .accessibilityIdentifier("review.sequence.count")
                    Text(sequence.captureTimestampLabel)
                        .accessibilityIdentifier("review.sequence.timestamp")
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close review")
            .accessibilityIdentifier("review.simulated.closeButton")
        }
    }

    private var manifestJSON: String {
        (try? currentManifest.jsonString()) ?? "Manifest unavailable"
    }

    private var currentManifest: BracketManifest {
        sequence.manifest(
            groupIdentifier: review.id,
            source: .simulated,
            plan: review.plan,
            recipe: appliedRecipeRecord,
            captureDevice: review.captureDevice,
            captureLocation: review.captureLocation,
            captureMotion: review.captureMotion
        )
    }

    private var manifestRecipeAccessibilityValue: String {
        currentManifest.recipe?.accessibilityValue ?? "No applied bracket recipe"
    }

    private var narrativeRequest: BracketReviewNarrativeRequest {
        BracketReviewNarrativeRequest.make(
            context: BracketNarrativeContext.make(
                manifest: currentManifest,
                sequence: sequence,
                intelligenceAvailability: intelligenceAvailability
            )
        )
    }

    private var currentNarrativeRun: BracketReviewNarrativeRun {
        refreshedNarrativeRun ?? DeterministicBracketReviewNarrative.run(
            for: narrativeRequest,
            fallbackReason: "Not refreshed in this session."
        )
    }

    private func updateSequence(_ updatedSequence: BracketReviewSequence) {
        sequence = updatedSequence
        refreshedNarrativeRun = nil
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

private struct SimulatedReviewProbe: View {
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

private struct SimulatedReviewSelectedShotCard: View {
    let sequence: BracketReviewSequence
    let selectedShot: BracketReviewShotSummary
    let showMetadata: Bool
    let manifestJSON: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToggleRepresentation: () -> Void
    let onToggleMetadata: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sequence.selectedPositionLabel)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.58))
                        .accessibilityIdentifier("review.sequence.selectedIndex")

                    Text(selectedShot.displayLabel)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .accessibilityIdentifier("review.sequence.selectedEV")

                    Text(selectedShot.selectedTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer()

                if selectedShot.isBestExposureCandidate {
                    Label("Best exposure", systemImage: "star.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.yellow, in: Capsule())
                        .accessibilityIdentifier("review.sequence.bestExposureBadge")
                }
            }

            HStack(spacing: 10) {
                SimulatedReviewInfoPill(
                    title: "File",
                    value: selectedShot.fileType,
                    identifier: "review.sequence.selectedFileType"
                )
                SimulatedReviewInfoPill(
                    title: "State",
                    value: selectedShot.captureState.displayName,
                    identifier: "review.sequence.selectedCaptureState"
                )
                SimulatedReviewInfoPill(
                    title: "Metadata",
                    value: selectedShot.metadataAvailability.displayName,
                    identifier: "review.sequence.metadataStatus"
                )
            }

            if !selectedShot.clippingWarnings.isEmpty {
                Label(selectedShot.clippingSummary, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("review.sequence.clippingWarning")
            }

            HStack(spacing: 12) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundColor(sequence.selectedIndex == 0 ? .white.opacity(0.25) : .white)
                .disabled(sequence.selectedIndex == 0)
                .accessibilityLabel("Previous shot")
                .accessibilityIdentifier("review.sequence.previousButton")

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundColor(sequence.selectedIndex >= sequence.shots.count - 1 ? .white.opacity(0.25) : .white)
                .disabled(sequence.selectedIndex >= sequence.shots.count - 1)
                .accessibilityLabel("Next shot")
                .accessibilityIdentifier("review.sequence.nextButton")

                Spacer()

                ShareLink(item: manifestJSON) {
                    Image(systemName: "doc.plaintext")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .accessibilityLabel("Share bracket manifest")
                .accessibilityValue(manifestJSON)
                .accessibilityIdentifier("review.sequence.manifestShareButton")

                Button(action: onToggleRepresentation) {
                    Label(sequence.selectedRepresentation.displayName, systemImage: "square.2.layers.3d")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .accessibilityLabel("Review representation")
                .accessibilityValue(sequence.selectedRepresentationAvailabilityLabel)
                .accessibilityIdentifier("review.sequence.representationToggle")

                Button(action: onToggleMetadata) {
                    Image(systemName: showMetadata ? "info.circle.fill" : "info.circle")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundColor(showMetadata ? .yellow : .white)
                .accessibilityLabel("Metadata overlay")
                .accessibilityValue(showMetadata ? "Shown" : "Hidden")
                .accessibilityIdentifier("review.sequence.metadataToggle")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .accessibilityLabel("Remove simulated shot")
                .accessibilityIdentifier("review.sequence.deleteButton")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SimulatedReviewInfoPill: View {
    let title: String
    let value: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SimulatedReviewSequenceList: View {
    let sequence: BracketReviewSequence
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sequence")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            ForEach(Array(sequence.shots.enumerated()), id: \.element.id) { position, shot in
                Button {
                    onSelect(position)
                } label: {
                    HStack(spacing: 12) {
                        Text(shot.sequenceLabel)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.68))

                        if shot.isBestExposureCandidate {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                                .accessibilityIdentifier("review.sequence.shot.\(shot.index).bestBadge")
                        }

                        Spacer()

                        Text(shot.captureState.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(shot.captureState == .available ? .green : .orange)

                        Text(shot.displayLabel)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(position == sequence.selectedIndex ? .yellow : .white)
                            .accessibilityIdentifier("review.simulated.shot.\(shot.index).label")
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
                .accessibilityValue(shot.captureState.displayName)
                .accessibilityIdentifier("review.sequence.shot.\(shot.index)")
            }
        }
    }
}

private struct SimulatedReviewMetadataPanel: View {
    let shot: BracketReviewShotSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Metadata", systemImage: "info.circle.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)

            Text(shot.metadataAvailability.detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.72))

            Text(shot.captureState.detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("review.sequence.metadataPanel")
    }
}

private struct SimulatedReviewEmptyState: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("No Reviewable Shots")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .accessibilityIdentifier("review.sequence.emptyTitle")

            Text("The simulated review sequence is empty.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.62))

            Button("Close", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("review.simulated.closeButton")
        }
        .padding(24)
    }
}
