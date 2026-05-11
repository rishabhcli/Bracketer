import Foundation

enum BracketManifestSource: String, Codable, Equatable, Sendable {
    case simulated
    case photos
}

struct BracketManifest: Codable, Equatable, Sendable {
    struct PlanSnapshot: Codable, Equatable, Sendable {
        let requestedShotCount: Int
        let resolvedShotCount: Int
        let evStep: Float
        let centerBias: Float
        let normalizationReason: String?
    }

    struct Shot: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let evOffset: Float
        let displayLabel: String
        let filenameLabel: String
        let assetIdentifier: String?
        let fileType: String
        let captureState: String
        let captureDetail: String
        let metadataStatus: String
        let metadataDetail: String
        let availableRepresentations: [String]
        let isBestExposureCandidate: Bool
        let clippingWarnings: [String]

        var id: Int { index }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let groupIdentifier: String
    let source: BracketManifestSource
    let capturedAt: Date
    let plan: PlanSnapshot
    let shots: [Shot]

    init(
        schemaVersion: Int = Self.schemaVersion,
        groupIdentifier: String,
        source: BracketManifestSource,
        capturedAt: Date,
        plan: PlanSnapshot,
        shots: [Shot]
    ) {
        self.schemaVersion = schemaVersion
        self.groupIdentifier = groupIdentifier
        self.source = source
        self.capturedAt = capturedAt
        self.plan = plan
        self.shots = shots
    }

    static func make(
        groupIdentifier: String,
        source: BracketManifestSource,
        plan: BracketPlan,
        sequence: BracketReviewSequence
    ) -> BracketManifest {
        BracketManifest(
            groupIdentifier: groupIdentifier,
            source: source,
            capturedAt: sequence.manifestCapturedAt,
            plan: PlanSnapshot(
                requestedShotCount: plan.requestedShotCount,
                resolvedShotCount: plan.shotCount,
                evStep: plan.evStep,
                centerBias: plan.centerBias,
                normalizationReason: plan.normalizationReason
            ),
            shots: sequence.shots.map { shot in
                Shot(
                    index: shot.index,
                    evOffset: shot.evOffset,
                    displayLabel: shot.displayLabel,
                    filenameLabel: shot.filenameLabel,
                    assetIdentifier: shot.assetIdentifier,
                    fileType: shot.fileType,
                    captureState: shot.captureState.displayName,
                    captureDetail: shot.captureState.detail,
                    metadataStatus: shot.metadataAvailability.displayName,
                    metadataDetail: shot.metadataAvailability.detail,
                    availableRepresentations: shot.availableRepresentations.map(\.displayName),
                    isBestExposureCandidate: shot.isBestExposureCandidate,
                    clippingWarnings: shot.clippingWarnings.map(\.displayName)
                )
            }
        )
    }

    func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        }
        return try encoder.encode(self)
    }

    func jsonString(prettyPrinted: Bool = true) throws -> String {
        let data = try jsonData(prettyPrinted: prettyPrinted)
        return String(decoding: data, as: UTF8.self)
    }
}

extension BracketReviewSequence {
    var manifestCapturedAt: Date {
        selectedShot?.capturedAt ?? shots.first?.capturedAt ?? Date(timeIntervalSince1970: 0)
    }

    func manifest(
        groupIdentifier: String,
        source: BracketManifestSource,
        plan: BracketPlan
    ) -> BracketManifest {
        BracketManifest.make(
            groupIdentifier: groupIdentifier,
            source: source,
            plan: plan,
            sequence: self
        )
    }
}
