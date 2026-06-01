import Foundation

enum BracketReviewRepresentation: String, Equatable, CaseIterable, Sendable {
    case processed
    case raw

    var displayName: String {
        switch self {
        case .processed: return "Processed"
        case .raw: return "RAW"
        }
    }
}

enum BracketReviewCaptureState: Equatable, Sendable {
    case available
    case missing
    case failed(String)

    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .missing:
            return "Missing"
        case .failed:
            return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .available:
            return "Captured"
        case .missing:
            return "Expected shot has no saved asset"
        case .failed(let message):
            return message
        }
    }
}

enum BracketReviewMetadataAvailability: Equatable, Sendable {
    case available(summary: String)
    case unavailable(reason: String)

    var displayName: String {
        switch self {
        case .available:
            return "Metadata available"
        case .unavailable:
            return "Metadata unavailable"
        }
    }

    var detail: String {
        switch self {
        case .available(let summary),
             .unavailable(let summary):
            return summary
        }
    }
}

enum BracketReviewClippingWarning: String, Equatable, Sendable {
    case simulatedShadowRisk
    case simulatedHighlightRisk

    var displayName: String {
        switch self {
        case .simulatedShadowRisk:
            return "Simulated shadow clipping risk"
        case .simulatedHighlightRisk:
            return "Simulated highlight clipping risk"
        }
    }
}

struct BracketReviewResourceSummary: Equatable, Sendable {
    let fileType: String
    let availableRepresentations: [BracketReviewRepresentation]
    let detail: String

    static let unavailable = BracketReviewResourceSummary(
        fileType: "Unknown",
        availableRepresentations: [],
        detail: "No asset resources available"
    )
}

struct BracketReviewMetadataSummary: Equatable, Sendable {
    let availableKeyCount: Int
    let pixelSize: String?
    let isoDescription: String?
    let lensDescription: String?

    var displaySummary: String {
        var parts = ["\(availableKeyCount) metadata keys"]
        if let pixelSize { parts.append(pixelSize) }
        if let isoDescription { parts.append(isoDescription) }
        if let lensDescription { parts.append(lensDescription) }
        return parts.joined(separator: " / ")
    }
}

struct BracketReviewShotSummary: Equatable, Identifiable, Sendable {
    let index: Int
    let evOffset: Float
    let assetIdentifier: String?
    let capturedAt: Date
    let fileType: String
    let captureState: BracketReviewCaptureState
    let metadataAvailability: BracketReviewMetadataAvailability
    let availableRepresentations: [BracketReviewRepresentation]
    let isBestExposureCandidate: Bool
    let clippingWarnings: [BracketReviewClippingWarning]

    var id: String {
        assetIdentifier ?? "planned-\(index)-\(filenameLabel)"
    }

    var displayLabel: String {
        BracketEVFormatter.displayLabel(for: evOffset)
    }

    var filenameLabel: String {
        BracketEVFormatter.filenameLabel(for: evOffset)
    }

    var sequenceLabel: String {
        "Shot \(index + 1)"
    }

    var selectedTitle: String {
        "\(sequenceLabel) / \(displayLabel)"
    }

    var clippingSummary: String {
        if clippingWarnings.isEmpty {
            return "No clipping warning"
        }

        return clippingWarnings.map(\.displayName).joined(separator: ", ")
    }

    func supports(_ representation: BracketReviewRepresentation) -> Bool {
        availableRepresentations.contains(representation)
    }

    func updating(
        fileType: String? = nil,
        metadataAvailability: BracketReviewMetadataAvailability? = nil,
        availableRepresentations: [BracketReviewRepresentation]? = nil
    ) -> BracketReviewShotSummary {
        BracketReviewShotSummary(
            index: index,
            evOffset: evOffset,
            assetIdentifier: assetIdentifier,
            capturedAt: capturedAt,
            fileType: fileType ?? self.fileType,
            captureState: captureState,
            metadataAvailability: metadataAvailability ?? self.metadataAvailability,
            availableRepresentations: availableRepresentations ?? self.availableRepresentations,
            isBestExposureCandidate: isBestExposureCandidate,
            clippingWarnings: clippingWarnings
        )
    }
}

struct BracketReviewSequence: Equatable, Sendable {
    let shots: [BracketReviewShotSummary]
    let selectedIndex: Int
    let selectedRepresentation: BracketReviewRepresentation

    init(
        shots: [BracketReviewShotSummary],
        selectedIndex: Int = 0,
        selectedRepresentation: BracketReviewRepresentation = .processed
    ) {
        self.shots = shots
        self.selectedIndex = Self.clamped(index: selectedIndex, count: shots.count)
        self.selectedRepresentation = selectedRepresentation
    }

    static func make(
        plan: BracketPlan,
        assetIdentifiers: [String],
        capturedAt: Date,
        fileType: String = "HEIF/JPEG",
        metadataAvailability: BracketReviewMetadataAvailability = .unavailable(
            reason: "Metadata was not loaded in the simulator harness"
        ),
        availableRepresentations: [BracketReviewRepresentation] = [.processed]
    ) -> BracketReviewSequence {
        let bestExposureIndex = plan.shots.min { left, right in
            abs(left.evOffset) < abs(right.evOffset)
        }?.index

        let summaries = plan.shots.map { shot in
            let assetIdentifier = assetIdentifiers.indices.contains(shot.index) ? assetIdentifiers[shot.index] : nil
            return BracketReviewShotSummary(
                index: shot.index,
                evOffset: shot.evOffset,
                assetIdentifier: assetIdentifier,
                capturedAt: capturedAt,
                fileType: fileType,
                captureState: assetIdentifier == nil ? .missing : .available,
                metadataAvailability: metadataAvailability,
                availableRepresentations: availableRepresentations,
                isBestExposureCandidate: shot.index == bestExposureIndex,
                clippingWarnings: Self.simulatedWarnings(for: shot.evOffset)
            )
        }

        return BracketReviewSequence(shots: summaries)
    }

    static func make(
        manifest: BracketManifest,
        selectedIndex: Int = 0
    ) -> BracketReviewSequence {
        let summaries = manifest.shots.map { shot in
            BracketReviewShotSummary(
                index: shot.index,
                evOffset: shot.evOffset,
                assetIdentifier: shot.assetIdentifier,
                capturedAt: manifest.capturedAt,
                fileType: shot.fileType,
                captureState: Self.captureState(displayName: shot.captureState, detail: shot.captureDetail),
                metadataAvailability: Self.metadataAvailability(
                    displayName: shot.metadataStatus,
                    detail: shot.metadataDetail
                ),
                availableRepresentations: shot.availableRepresentations.compactMap(Self.representation(displayName:)),
                isBestExposureCandidate: shot.isBestExposureCandidate,
                clippingWarnings: shot.clippingWarnings.compactMap(Self.clippingWarning(displayName:))
            )
        }

        return BracketReviewSequence(shots: summaries, selectedIndex: selectedIndex)
    }

    var isEmpty: Bool {
        shots.isEmpty
    }

    var selectedShot: BracketReviewShotSummary? {
        guard shots.indices.contains(selectedIndex) else { return nil }
        return shots[selectedIndex]
    }

    var countLabel: String {
        "\(shots.count) \(shots.count == 1 ? "shot" : "shots")"
    }

    var selectedPositionLabel: String {
        guard !shots.isEmpty else { return "0 of 0" }
        return "\(selectedIndex + 1) of \(shots.count)"
    }

    var captureTimestampLabel: String {
        guard let capturedAt = selectedShot?.capturedAt ?? shots.first?.capturedAt else {
            return "No capture timestamp"
        }

        return Self.timestampLabel(for: capturedAt)
    }

    var selectedRepresentationAvailabilityLabel: String {
        guard let selectedShot else { return "No shot selected" }
        if selectedShot.supports(selectedRepresentation) {
            return selectedRepresentation.displayName
        }

        return "\(selectedRepresentation.displayName) unavailable"
    }

    func selecting(index: Int) -> BracketReviewSequence {
        BracketReviewSequence(
            shots: shots,
            selectedIndex: index,
            selectedRepresentation: selectedRepresentation
        )
    }

    func selectingPrevious() -> BracketReviewSequence {
        selecting(index: selectedIndex - 1)
    }

    func selectingNext() -> BracketReviewSequence {
        selecting(index: selectedIndex + 1)
    }

    func togglingRepresentation() -> BracketReviewSequence {
        BracketReviewSequence(
            shots: shots,
            selectedIndex: selectedIndex,
            selectedRepresentation: selectedRepresentation == .processed ? .raw : .processed
        )
    }

    func deletingSelected() -> BracketReviewSequence {
        guard shots.indices.contains(selectedIndex) else { return self }

        var nextShots = shots
        nextShots.remove(at: selectedIndex)

        return BracketReviewSequence(
            shots: nextShots,
            selectedIndex: selectedIndex,
            selectedRepresentation: selectedRepresentation
        )
    }

    func updatingShot(at position: Int, resourceSummary: BracketReviewResourceSummary) -> BracketReviewSequence {
        replacingShot(
            at: position,
            with: shots[safe: position]?.updating(
                fileType: resourceSummary.fileType,
                availableRepresentations: resourceSummary.availableRepresentations
            )
        )
    }

    func updatingShot(
        at position: Int,
        metadataAvailability: BracketReviewMetadataAvailability
    ) -> BracketReviewSequence {
        replacingShot(
            at: position,
            with: shots[safe: position]?.updating(metadataAvailability: metadataAvailability)
        )
    }

    private func replacingShot(
        at position: Int,
        with updatedShot: BracketReviewShotSummary?
    ) -> BracketReviewSequence {
        guard let updatedShot, shots.indices.contains(position) else { return self }

        var nextShots = shots
        nextShots[position] = updatedShot
        return BracketReviewSequence(
            shots: nextShots,
            selectedIndex: selectedIndex,
            selectedRepresentation: selectedRepresentation
        )
    }

    private static func clamped(index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    private static func captureState(
        displayName: String,
        detail: String
    ) -> BracketReviewCaptureState {
        if displayName == BracketReviewCaptureState.available.displayName {
            return .available
        }
        if displayName == BracketReviewCaptureState.missing.displayName {
            return .missing
        }
        return .failed(detail)
    }

    private static func metadataAvailability(
        displayName: String,
        detail: String
    ) -> BracketReviewMetadataAvailability {
        if displayName == BracketReviewMetadataAvailability.available(summary: detail).displayName {
            return .available(summary: detail)
        }
        return .unavailable(reason: detail)
    }

    private static func representation(displayName: String) -> BracketReviewRepresentation? {
        BracketReviewRepresentation.allCases.first { $0.displayName == displayName }
    }

    private static func clippingWarning(displayName: String) -> BracketReviewClippingWarning? {
        switch displayName {
        case BracketReviewClippingWarning.simulatedShadowRisk.displayName:
            return .simulatedShadowRisk
        case BracketReviewClippingWarning.simulatedHighlightRisk.displayName:
            return .simulatedHighlightRisk
        default:
            return nil
        }
    }

    private static func simulatedWarnings(for evOffset: Float) -> [BracketReviewClippingWarning] {
        if evOffset <= -2.0 {
            return [.simulatedShadowRisk]
        }

        if evOffset >= 2.0 {
            return [.simulatedHighlightRisk]
        }

        return []
    }

    private static func timestampLabel(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02dZ",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
