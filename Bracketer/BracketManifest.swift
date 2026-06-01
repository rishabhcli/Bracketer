import Foundation

enum BracketManifestSource: String, Codable, Equatable, Sendable {
    case simulated
    case photos
}

struct BracketManifest: Codable, Equatable, Sendable {
    struct CaptureDeviceSnapshot: Codable, Equatable, Sendable {
        let logicalLensLabel: String
        let cameraName: String
        let deviceType: String
        let availableLensLabels: [String]
        let source: String

        static let simulatedWide = CaptureDeviceSnapshot(
            logicalLensLabel: "1x",
            cameraName: "Simulated Wide Camera",
            deviceType: "simulated.wide",
            availableLensLabels: ["1x"],
            source: "simulated camera harness"
        )

        var libraryLensTitle: String {
            let trimmedName = cameraName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return logicalLensLabel }
            if trimmedName.localizedCaseInsensitiveContains(logicalLensLabel) {
                return trimmedName
            }
            return "\(logicalLensLabel) \(trimmedName)"
        }

        var accessibilityValue: String {
            [
                "Capture Device",
                libraryLensTitle,
                "Type \(deviceType)",
                "Available lenses \(availableLensLabels.joined(separator: ", "))",
                "Source \(source)"
            ].joined(separator: " | ")
        }
    }

    struct CaptureLocationSnapshot: Codable, Equatable, Sendable {
        let authorizationState: String
        let projectStoragePolicy: String
        let photosWritePolicy: String
        let preciseCoordinatesStored: Bool
        let locationSampleObserved: Bool
        let source: String

        static let simulatedNotRequested = CaptureLocationSnapshot(
            authorizationState: "Not Requested",
            projectStoragePolicy: "Project stores location policy only; precise coordinates are not stored.",
            photosWritePolicy: "Simulated capture does not write Photos location metadata.",
            preciseCoordinatesStored: false,
            locationSampleObserved: false,
            source: "simulated camera harness"
        )

        static func make(
            authorizationState: String,
            locationSampleObserved: Bool,
            source: String
        ) -> CaptureLocationSnapshot {
            CaptureLocationSnapshot(
                authorizationState: authorizationState,
                projectStoragePolicy: "Project stores location policy only; precise coordinates are not stored.",
                photosWritePolicy: locationSampleObserved
                    ? "Photos save request received a CoreLocation sample; project manifest stores no coordinates."
                    : "No CoreLocation sample was attached to the Photos save request.",
                preciseCoordinatesStored: false,
                locationSampleObserved: locationSampleObserved,
                source: source
            )
        }

        var libraryLocationTitle: String {
            if preciseCoordinatesStored {
                return "Precise Coordinates Stored"
            }
            if locationSampleObserved {
                return "Photo Location Requested, Project Redacted"
            }

            switch authorizationState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "on", "authorized", "authorizedwheninuse", "authorized always", "authorizedalways":
                return "Location Authorized, No Sample"
            case "pending", "not determined", "notdetermined":
                return "Location Permission Pending"
            case "off", "denied", "restricted":
                return "Location Disabled"
            case "not requested":
                return "Simulated Location Not Requested"
            default:
                return "Location Policy Unknown"
            }
        }

        var accessibilityValue: String {
            [
                "Capture Location Policy",
                libraryLocationTitle,
                "Authorization \(authorizationState)",
                projectStoragePolicy,
                photosWritePolicy,
                preciseCoordinatesStored ? "Precise coordinates stored" : "No precise coordinates",
                locationSampleObserved ? "Location sample observed" : "No location sample observed",
                "Source \(source)"
            ].joined(separator: " | ")
        }
    }

    struct CaptureMotionSnapshot: Codable, Equatable, Sendable {
        let sampleAvailability: String
        let sampleCount: Int
        let captureDurationMilliseconds: Int
        let maxAngularVelocityDegreesPerSecond: Int
        let maxAccelerationMilliG: Int
        let qualityLabel: String
        let source: String
        let privacyBoundary: String

        static let simulatedUnavailable = CaptureMotionSnapshot.unavailable(
            source: "simulated camera harness"
        )

        static func unavailable(
            source: String,
            captureDurationMilliseconds: Int = 0
        ) -> CaptureMotionSnapshot {
            CaptureMotionSnapshot(
                sampleAvailability: "Unavailable",
                sampleCount: 0,
                captureDurationMilliseconds: max(0, captureDurationMilliseconds),
                maxAngularVelocityDegreesPerSecond: 0,
                maxAccelerationMilliG: 0,
                qualityLabel: "No motion samples captured",
                source: source,
                privacyBoundary: "No raw CMMotion samples, accelerometer streams, gyroscope streams, Photos bytes, precise coordinates, or RAW pixels are stored."
            )
        }

        static func available(
            source: String,
            sampleCount: Int,
            captureDurationMilliseconds: Int,
            maxAngularVelocityDegreesPerSecond: Int,
            maxAccelerationMilliG: Int,
            qualityLabel: String = "Scalar motion summary captured"
        ) -> CaptureMotionSnapshot {
            CaptureMotionSnapshot(
                sampleAvailability: "Available",
                sampleCount: max(0, sampleCount),
                captureDurationMilliseconds: max(0, captureDurationMilliseconds),
                maxAngularVelocityDegreesPerSecond: max(0, maxAngularVelocityDegreesPerSecond),
                maxAccelerationMilliG: max(0, maxAccelerationMilliG),
                qualityLabel: qualityLabel,
                source: source,
                privacyBoundary: "Only bounded scalar motion metadata is stored; no raw CMMotion samples, accelerometer streams, gyroscope streams, Photos bytes, precise coordinates, or RAW pixels are stored."
            )
        }

        var hasMotionSamples: Bool {
            sampleCount > 0
        }

        var summaryLabel: String {
            if sampleCount == 1 {
                return "1 motion sample captured"
            }
            return "\(sampleCount) motion samples captured"
        }

        var accessibilityValue: String {
            [
                "Capture Motion Metadata",
                summaryLabel,
                "Availability \(sampleAvailability)",
                "Duration \(captureDurationMilliseconds) ms",
                "Max angular velocity \(maxAngularVelocityDegreesPerSecond) deg/s",
                "Max acceleration \(maxAccelerationMilliG) milli-g",
                qualityLabel,
                "Source \(source)",
                privacyBoundary,
            ].joined(separator: " | ")
        }
    }

    struct PlanSnapshot: Codable, Equatable, Sendable {
        let requestedShotCount: Int
        let resolvedShotCount: Int
        let evStep: Float
        let centerBias: Float
        let normalizationReason: String?
    }

    struct RecipeSnapshot: Codable, Equatable, Sendable {
        let title: String
        let source: String
        let plan: PlanSnapshot

        init(record: AppliedBracketRecipeRecord) {
            self.title = record.title
            self.source = record.source.rawValue
            self.plan = PlanSnapshot(
                requestedShotCount: record.plan.requestedShotCount,
                resolvedShotCount: record.plan.resolvedShotCount,
                evStep: record.plan.evStep,
                centerBias: record.plan.centerBias,
                normalizationReason: record.plan.normalizationReason
            )
        }

        var accessibilityValue: String {
            let resolvedPlan = BracketPlan(
                evStep: plan.evStep,
                requestedShotCount: plan.resolvedShotCount,
                centerBias: plan.centerBias
            )
            let recipeSummary = "\(resolvedPlan.shotCount) shots | \(resolvedPlan.shots.map(\.displayLabel).joined(separator: ", ")) | Center \(BracketEVFormatter.displayLabel(for: resolvedPlan.centerBias))"
            return "\(title) | \(recipeSummary) | Source: \(source)"
        }
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
    let captureDevice: CaptureDeviceSnapshot?
    let captureLocation: CaptureLocationSnapshot?
    let captureMotion: CaptureMotionSnapshot?
    let plan: PlanSnapshot
    let recipe: RecipeSnapshot?
    let shots: [Shot]

    init(
        schemaVersion: Int = Self.schemaVersion,
        groupIdentifier: String,
        source: BracketManifestSource,
        capturedAt: Date,
        captureDevice: CaptureDeviceSnapshot? = nil,
        captureLocation: CaptureLocationSnapshot? = nil,
        captureMotion: CaptureMotionSnapshot? = nil,
        plan: PlanSnapshot,
        recipe: RecipeSnapshot? = nil,
        shots: [Shot]
    ) {
        self.schemaVersion = schemaVersion
        self.groupIdentifier = groupIdentifier
        self.source = source
        self.capturedAt = capturedAt
        self.captureDevice = captureDevice
        self.captureLocation = captureLocation
        self.captureMotion = captureMotion
        self.plan = plan
        self.recipe = recipe
        self.shots = shots
    }

    static func make(
        groupIdentifier: String,
        source: BracketManifestSource,
        plan: BracketPlan,
        sequence: BracketReviewSequence,
        recipe: AppliedBracketRecipeRecord? = nil,
        captureDevice: CaptureDeviceSnapshot? = nil,
        captureLocation: CaptureLocationSnapshot? = nil,
        captureMotion: CaptureMotionSnapshot? = nil
    ) -> BracketManifest {
        BracketManifest(
            groupIdentifier: groupIdentifier,
            source: source,
            capturedAt: sequence.manifestCapturedAt,
            captureDevice: captureDevice,
            captureLocation: captureLocation,
            captureMotion: captureMotion,
            plan: PlanSnapshot(
                requestedShotCount: plan.requestedShotCount,
                resolvedShotCount: plan.shotCount,
                evStep: plan.evStep,
                centerBias: plan.centerBias,
                normalizationReason: plan.normalizationReason
            ),
            recipe: recipe.map(RecipeSnapshot.init(record:)),
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
        plan: BracketPlan,
        recipe: AppliedBracketRecipeRecord? = nil,
        captureDevice: BracketManifest.CaptureDeviceSnapshot? = nil,
        captureLocation: BracketManifest.CaptureLocationSnapshot? = nil,
        captureMotion: BracketManifest.CaptureMotionSnapshot? = nil
    ) -> BracketManifest {
        BracketManifest.make(
            groupIdentifier: groupIdentifier,
            source: source,
            plan: plan,
            sequence: self,
            recipe: recipe,
            captureDevice: captureDevice,
            captureLocation: captureLocation,
            captureMotion: captureMotion
        )
    }
}
