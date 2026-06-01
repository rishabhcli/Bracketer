import Foundation
import CoreGraphics
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

enum BracketProjectLifecycle: String, Codable, CaseIterable, Equatable, Sendable {
    case planned
    case capturing
    case saving
    case reviewable
    case incomplete
    case failed
    case exported
    case archived
}

struct BracketProject: Codable, Equatable, Identifiable, Sendable {
    struct AssetReference: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let evOffset: Float
        let displayLabel: String
        let assetIdentifier: String?
        let fileType: String
        let captureState: String
        let availableRepresentations: [String]

        var id: Int { index }
    }

    struct ReviewSnapshot: Codable, Equatable, Sendable {
        let selectedIndex: Int
        let selectedDisplayLabel: String?
        let selectedRepresentation: String
        let shotCount: Int
        let availableShotCount: Int
        let missingShotCount: Int
        let failedShotCount: Int
        let rawAvailableCount: Int
        let processedAvailableCount: Int
        let bestExposureLabel: String?
        let capturedAt: Date

        static func make(
            sequence: BracketReviewSequence?,
            manifest: BracketManifest
        ) -> ReviewSnapshot {
            if let sequence {
                return ReviewSnapshot(
                    selectedIndex: sequence.selectedIndex,
                    selectedDisplayLabel: sequence.selectedShot?.displayLabel,
                    selectedRepresentation: sequence.selectedRepresentation.displayName,
                    shotCount: sequence.shots.count,
                    availableShotCount: sequence.shots.filter { $0.captureState == .available }.count,
                    missingShotCount: sequence.shots.filter { $0.captureState == .missing }.count,
                    failedShotCount: sequence.shots.filter {
                        if case .failed = $0.captureState { return true }
                        return false
                    }.count,
                    rawAvailableCount: sequence.shots.filter { $0.availableRepresentations.contains(.raw) }.count,
                    processedAvailableCount: sequence.shots.filter { $0.availableRepresentations.contains(.processed) }.count,
                    bestExposureLabel: sequence.shots.first(where: \.isBestExposureCandidate)?.displayLabel,
                    capturedAt: sequence.manifestCapturedAt
                )
            }

            return ReviewSnapshot(
                selectedIndex: 0,
                selectedDisplayLabel: manifest.shots.first?.displayLabel,
                selectedRepresentation: "Processed",
                shotCount: manifest.shots.count,
                availableShotCount: manifest.shots.filter { $0.captureState == "Available" }.count,
                missingShotCount: manifest.shots.filter { $0.captureState == "Missing" }.count,
                failedShotCount: manifest.shots.filter { $0.captureState.localizedCaseInsensitiveContains("failed") }.count,
                rawAvailableCount: manifest.shots.filter { $0.availableRepresentations.contains("RAW") }.count,
                processedAvailableCount: manifest.shots.filter { $0.availableRepresentations.contains("Processed") }.count,
                bestExposureLabel: manifest.shots.first(where: \.isBestExposureCandidate)?.displayLabel,
                capturedAt: manifest.capturedAt
            )
        }
    }

    struct PrivacySnapshot: Codable, Equatable, Sendable {
        let storesRawPhotoBytes: Bool
        let storesAssetIdentifiers: Bool
        let storesPreciseLocationCoordinates: Bool
        let containsGeneratedText: Bool
        let containsCaptureContextFacts: Bool
        let assetIdentifierPolicy: String

        var accessibilityValue: String {
            [
                storesRawPhotoBytes ? "Raw photo bytes stored" : "No raw photo bytes",
                storesAssetIdentifiers ? "Photos identifiers scoped for recovery" : "No Photos identifiers",
                storesPreciseLocationCoordinates ? "Precise coordinates stored" : "No precise coordinates",
                containsGeneratedText ? "Generated notes included" : "No generated notes",
                containsCaptureContextFacts ? "Capture facts included" : "No capture facts"
            ].joined(separator: " | ")
        }

        static func make(
            manifest: BracketManifest,
            sidecar: BracketManifestSidecar?
        ) -> PrivacySnapshot {
            let storesAssetIdentifiers = manifest.shots.contains { $0.assetIdentifier != nil }
            return PrivacySnapshot(
                storesRawPhotoBytes: false,
                storesAssetIdentifiers: storesAssetIdentifiers,
                storesPreciseLocationCoordinates: false,
                containsGeneratedText: sidecar?.generatedNote != nil,
                containsCaptureContextFacts: !(sidecar?.captureContextFacts.isEmpty ?? true),
                assetIdentifierPolicy: storesAssetIdentifiers
                    ? "Photos local identifiers stay inside the project record for recovery and are omitted from generated sidecars."
                    : "No Photos local identifiers are stored in this project record."
            )
        }
    }

    struct ExportRecord: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let kind: String
        let createdAt: Date
        let destinationSummary: String
    }

    struct DiagnosticsReference: Codable, Equatable, Sendable {
        let summary: String
        let capturedAt: Date
    }

    struct Curation: Codable, Equatable, Sendable {
        let isFavorite: Bool
        let updatedAt: Date?

        static let empty = Curation(isFavorite: false, updatedAt: nil)

        var accessibilityValue: String {
            isFavorite ? "Favorite project" : "Not favorite"
        }
    }

    struct PreviewPlaceholder: Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let captureState: String
        let fileType: String
        let availableRepresentations: [String]
        let isBestExposureCandidate: Bool

        var id: Int { index }

        var symbolName: String {
            if isMissing {
                return "questionmark.diamond"
            }
            if isFailed {
                return "exclamationmark.triangle"
            }
            if isBestExposureCandidate {
                return "target"
            }
            return "photo"
        }

        var shortStatus: String {
            if isMissing {
                return "Missing"
            }
            if isFailed {
                return "Failed"
            }
            return "Ready"
        }

        var accessibilityValue: String {
            var parts = [
                displayLabel,
                captureState,
                fileType,
                availableRepresentations.isEmpty ? "No representation" : availableRepresentations.joined(separator: ", ")
            ]
            if isBestExposureCandidate {
                parts.append("Best exposure candidate")
            }
            return parts.joined(separator: " | ")
        }

        private var isMissing: Bool {
            captureState.localizedCaseInsensitiveContains("missing")
        }

        private var isFailed: Bool {
            captureState.localizedCaseInsensitiveContains("failed")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let id: String
    let captureSessionIdentifier: String
    let source: BracketManifestSource
    let lifecycle: BracketProjectLifecycle
    let createdAt: Date
    let updatedAt: Date
    let manifest: BracketManifest
    let sidecar: BracketManifestSidecar?
    let reviewSnapshot: ReviewSnapshot
    let assets: [AssetReference]
    let resourceInspection: BracketProjectResourceInspection?
    let thumbnailInspection: BracketProjectThumbnailInspection?
    let acceptedTags: [String]
    let userNote: String?
    let curation: Curation?
    let searchTokens: [String]
    let exportHistory: [ExportRecord]
    let diagnosticsReference: DiagnosticsReference?
    let privacy: PrivacySnapshot

    static func make(
        manifest: BracketManifest,
        reviewSequence: BracketReviewSequence? = nil,
        sidecar: BracketManifestSidecar? = nil,
        resourceInspection: BracketProjectResourceInspection? = nil,
        thumbnailInspection: BracketProjectThumbnailInspection? = nil,
        acceptedTags: [String] = [],
        userNote: String? = nil,
        exportHistory: [ExportRecord] = [],
        diagnosticsSummary: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> BracketProject {
        let lifecycle = lifecycle(for: manifest, exportHistory: exportHistory)
        let projectCreatedAt = createdAt ?? manifest.capturedAt
        let projectUpdatedAt = updatedAt ?? projectCreatedAt
        let reviewSnapshot = ReviewSnapshot.make(sequence: reviewSequence, manifest: manifest)
        let normalizedTags = normalizedTags(acceptedTags)
        let normalizedUserNote = normalizedUserNote(userNote)
        let assets = manifest.shots.map { shot in
            AssetReference(
                index: shot.index,
                evOffset: shot.evOffset,
                displayLabel: shot.displayLabel,
                assetIdentifier: shot.assetIdentifier,
                fileType: shot.fileType,
                captureState: shot.captureState,
                availableRepresentations: shot.availableRepresentations
            )
        }
        let privacy = PrivacySnapshot.make(manifest: manifest, sidecar: sidecar)
        let diagnosticsReference = diagnosticsSummary.map {
            DiagnosticsReference(summary: $0, capturedAt: projectCreatedAt)
        }

        return BracketProject(
            schemaVersion: Self.schemaVersion,
            id: stableProjectID(for: manifest),
            captureSessionIdentifier: manifest.groupIdentifier,
            source: manifest.source,
            lifecycle: lifecycle,
            createdAt: projectCreatedAt,
            updatedAt: projectUpdatedAt,
            manifest: manifest,
            sidecar: sidecar,
            reviewSnapshot: reviewSnapshot,
            assets: assets,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection,
            acceptedTags: normalizedTags,
            userNote: normalizedUserNote,
            curation: nil,
            searchTokens: (searchTokens(
                manifest: manifest,
                sidecar: sidecar,
                tags: normalizedTags,
                userNote: normalizedUserNote,
                lifecycle: lifecycle,
                isFavorite: false
            ) + (resourceInspection?.searchTokens ?? []) + (thumbnailInspection?.searchTokens ?? []))
                .uniquePreservingOrder(),
            exportHistory: exportHistory,
            diagnosticsReference: diagnosticsReference,
            privacy: privacy
        )
    }

    var accessibilityValue: String {
        [
            "Project \(id)",
            lifecycle.rawValue,
            "\(reviewSnapshot.shotCount) shots",
            source.rawValue,
            curationState.accessibilityValue,
            privacy.accessibilityValue
        ].joined(separator: " | ")
    }

    var displayTitle: String {
        "\(reviewSnapshot.shotCount)-shot \(source.rawValue) bracket"
    }

    var displaySubtitle: String {
        var parts = [
            lifecycle.rawValue,
            manifest.plan.projectSummary,
            "\(reviewSnapshot.availableShotCount) available"
        ]
        if reviewSnapshot.missingShotCount > 0 {
            parts.append("\(reviewSnapshot.missingShotCount) missing")
        }
        if reviewSnapshot.failedShotCount > 0 {
            parts.append("\(reviewSnapshot.failedShotCount) failed")
        }
        if let recipeTitle = manifest.recipe?.title {
            parts.append(recipeTitle)
        }
        return parts.joined(separator: " | ")
    }

    var finalOutputActionPlanSummary: String {
        let finalOutputManifest = BracketProjectFinalOutputManifest.make(
            project: self,
            privacyLevel: .metadataOnly,
            createdAt: updatedAt
        )
        return BracketProjectFinalOutputReadinessAudit.make(
            manifest: finalOutputManifest
        ).actionPlanSummary
    }

    var projectLibraryAccessibilityValue: String {
        var parts = [
            displayTitle,
            displaySubtitle,
            "Identifier \(id)",
            curationState.accessibilityValue,
            privacy.accessibilityValue,
            "Final output action plan: \(finalOutputActionPlanSummary)"
        ]
        if !acceptedTags.isEmpty {
            parts.append("Tags \(acceptedTags.joined(separator: ", "))")
        }
        if let userNote {
            parts.append("Note \(userNote)")
        }
        parts.append(previewStripAccessibilityValue)
        return parts.joined(separator: " | ")
    }

    var previewPlaceholders: [PreviewPlaceholder] {
        manifest.shots.map { shot in
            PreviewPlaceholder(
                index: shot.index,
                displayLabel: shot.displayLabel,
                captureState: shot.captureState,
                fileType: shot.fileType,
                availableRepresentations: shot.availableRepresentations,
                isBestExposureCandidate: shot.isBestExposureCandidate
            )
        }
    }

    var previewStripAccessibilityValue: String {
        let previewValues = previewPlaceholders
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return "Preview placeholders | \(previewValues)"
    }

    var curationState: Curation {
        curation ?? .empty
    }

    var isFavorite: Bool {
        curationState.isFavorite
    }

    var searchCorpus: [String] {
        var corpus = [
            id,
            captureSessionIdentifier,
            source.rawValue,
            lifecycle.rawValue,
            displayTitle,
            displaySubtitle,
            "\(reviewSnapshot.shotCount) shots",
            "\(reviewSnapshot.availableShotCount) available",
            "\(reviewSnapshot.rawAvailableCount) raw",
            "\(reviewSnapshot.processedAvailableCount) processed",
            finalOutputActionPlanSummary,
            manifest.plan.projectSummary,
            privacy.accessibilityValue,
            privacy.assetIdentifierPolicy,
            curationState.accessibilityValue
        ]
        if isFavorite {
            corpus.append(contentsOf: ["favorite", "starred"])
        }
        if let selected = reviewSnapshot.selectedDisplayLabel {
            corpus.append(selected)
        }
        if let best = reviewSnapshot.bestExposureLabel {
            corpus.append(best)
        }
        if let recipe = manifest.recipe {
            corpus.append(recipe.title)
            corpus.append(recipe.source)
        }
        if let captureDevice = manifest.captureDevice {
            corpus.append(captureDevice.accessibilityValue)
            corpus.append(captureDevice.libraryLensTitle)
            corpus.append(captureDevice.deviceType)
            corpus.append(contentsOf: captureDevice.availableLensLabels)
        }
        if let captureLocation = manifest.captureLocation {
            corpus.append(captureLocation.accessibilityValue)
            corpus.append(captureLocation.libraryLocationTitle)
            corpus.append(captureLocation.authorizationState)
            corpus.append(captureLocation.projectStoragePolicy)
            corpus.append(captureLocation.photosWritePolicy)
        }
        if let userNote {
            corpus.append(userNote)
        }
        corpus.append(contentsOf: acceptedTags)
        corpus.append(contentsOf: searchTokens)
        corpus.append(contentsOf: assets.flatMap {
            [$0.displayLabel, $0.fileType, $0.captureState] + $0.availableRepresentations
        })
        if let generatedNote = sidecar?.generatedNote {
            corpus.append(generatedNote.title)
            corpus.append(generatedNote.summary)
            corpus.append(generatedNote.mergeAdvice)
            corpus.append(contentsOf: generatedNote.tags)
        }
        if let resourceInspection {
            corpus.append(contentsOf: resourceInspection.searchTokens)
        }
        if let thumbnailInspection {
            corpus.append(contentsOf: thumbnailInspection.searchTokens)
        }
        if let diagnosticsReference {
            corpus.append(diagnosticsReference.summary)
        }
        return corpus
    }

    func exportCopy(
        privacyLevel: BracketProjectExportPrivacyLevel,
        generatedContentPolicy: BracketProjectExportGeneratedContentPolicy = .include
    ) -> BracketProject {
        let includesAssetIdentifiers = privacyLevel.includesAssetIdentifiers
        let exportManifest = manifest.exportCopy(includingAssetIdentifiers: includesAssetIdentifiers)
        let exportAssets = assets.map { asset in
            AssetReference(
                index: asset.index,
                evOffset: asset.evOffset,
                displayLabel: asset.displayLabel,
                assetIdentifier: includesAssetIdentifiers ? asset.assetIdentifier : nil,
                fileType: asset.fileType,
                captureState: asset.captureState,
                availableRepresentations: asset.availableRepresentations
            )
        }
        let exportSidecar: BracketManifestSidecar?
        switch generatedContentPolicy {
        case .include:
            exportSidecar = sidecar
        case .omit:
            exportSidecar = sidecar?.omittingGeneratedContent(acceptedTags: acceptedTags)
        }
        let exportPrivacy = PrivacySnapshot.make(manifest: exportManifest, sidecar: exportSidecar)
        let exportResourceInspection = resourceInspection?.exportCopy(
            includingAssetIdentifiers: includesAssetIdentifiers
        )
        let exportThumbnailInspection = thumbnailInspection?.exportCopy(
            includingAssetIdentifiers: includesAssetIdentifiers
        )

        return BracketProject(
            schemaVersion: schemaVersion,
            id: includesAssetIdentifiers ? id : exportIdentifier,
            captureSessionIdentifier: includesAssetIdentifiers ? captureSessionIdentifier : exportManifest.groupIdentifier,
            source: source,
            lifecycle: lifecycle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            manifest: exportManifest,
            sidecar: exportSidecar,
            reviewSnapshot: reviewSnapshot,
            assets: exportAssets,
            resourceInspection: exportResourceInspection,
            thumbnailInspection: exportThumbnailInspection,
            acceptedTags: acceptedTags,
            userNote: userNote,
            curation: curation,
            searchTokens: (Self.searchTokens(
                manifest: exportManifest,
                sidecar: exportSidecar,
                tags: acceptedTags,
                userNote: userNote,
                lifecycle: lifecycle,
                isFavorite: isFavorite
            ) + (exportResourceInspection?.searchTokens ?? []) + (exportThumbnailInspection?.searchTokens ?? []))
                .uniquePreservingOrder(),
            exportHistory: exportHistory,
            diagnosticsReference: diagnosticsReference,
            privacy: exportPrivacy
        )
    }

    func withUserCuration(
        isFavorite: Bool,
        acceptedTags: [String],
        userNote: String?,
        updatedAt: Date = Date()
    ) -> BracketProject {
        let normalizedTags = Self.normalizedTags(acceptedTags)
        let normalizedUserNote = Self.normalizedUserNote(userNote)
        return BracketProject(
            schemaVersion: schemaVersion,
            id: id,
            captureSessionIdentifier: captureSessionIdentifier,
            source: source,
            lifecycle: lifecycle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            manifest: manifest,
            sidecar: sidecar,
            reviewSnapshot: reviewSnapshot,
            assets: assets,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection,
            acceptedTags: normalizedTags,
            userNote: normalizedUserNote,
            curation: Curation(isFavorite: isFavorite, updatedAt: updatedAt),
            searchTokens: (Self.searchTokens(
                manifest: manifest,
                sidecar: sidecar,
                tags: normalizedTags,
                userNote: normalizedUserNote,
                lifecycle: lifecycle,
                isFavorite: isFavorite
            ) + (resourceInspection?.searchTokens ?? []) + (thumbnailInspection?.searchTokens ?? []))
                .uniquePreservingOrder(),
            exportHistory: exportHistory,
            diagnosticsReference: diagnosticsReference,
            privacy: privacy
        )
    }

    func withResourceInspection(
        _ resourceInspection: BracketProjectResourceInspection,
        updatedAt: Date = Date()
    ) -> BracketProject {
        BracketProject(
            schemaVersion: schemaVersion,
            id: id,
            captureSessionIdentifier: captureSessionIdentifier,
            source: source,
            lifecycle: lifecycle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            manifest: manifest,
            sidecar: sidecar,
            reviewSnapshot: reviewSnapshot,
            assets: assets,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection,
            acceptedTags: acceptedTags,
            userNote: userNote,
            curation: curation,
            searchTokens: (Self.searchTokens(
                manifest: manifest,
                sidecar: sidecar,
                tags: acceptedTags,
                userNote: userNote,
                lifecycle: lifecycle,
                isFavorite: isFavorite
            ) + resourceInspection.searchTokens + (thumbnailInspection?.searchTokens ?? []))
                .uniquePreservingOrder(),
            exportHistory: exportHistory,
            diagnosticsReference: diagnosticsReference,
            privacy: privacy
        )
    }

    func withThumbnailInspection(
        _ thumbnailInspection: BracketProjectThumbnailInspection,
        updatedAt: Date = Date()
    ) -> BracketProject {
        BracketProject(
            schemaVersion: schemaVersion,
            id: id,
            captureSessionIdentifier: captureSessionIdentifier,
            source: source,
            lifecycle: lifecycle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            manifest: manifest,
            sidecar: sidecar,
            reviewSnapshot: reviewSnapshot,
            assets: assets,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection,
            acceptedTags: acceptedTags,
            userNote: userNote,
            curation: curation,
            searchTokens: (Self.searchTokens(
                manifest: manifest,
                sidecar: sidecar,
                tags: acceptedTags,
                userNote: userNote,
                lifecycle: lifecycle,
                isFavorite: isFavorite
            ) + (resourceInspection?.searchTokens ?? []) + thumbnailInspection.searchTokens)
                .uniquePreservingOrder(),
            exportHistory: exportHistory,
            diagnosticsReference: diagnosticsReference,
            privacy: privacy
        )
    }

    func withImportConflictIdentifier(
        _ newIdentifier: String,
        importedAt: Date
    ) -> BracketProject {
        BracketProject(
            schemaVersion: schemaVersion,
            id: newIdentifier.fileSafeIdentifier,
            captureSessionIdentifier: captureSessionIdentifier,
            source: source,
            lifecycle: lifecycle,
            createdAt: createdAt,
            updatedAt: importedAt,
            manifest: manifest,
            sidecar: sidecar,
            reviewSnapshot: reviewSnapshot,
            assets: assets,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection,
            acceptedTags: acceptedTags,
            userNote: userNote,
            curation: curation,
            searchTokens: (Self.searchTokens(
                manifest: manifest,
                sidecar: sidecar,
                tags: acceptedTags,
                userNote: userNote,
                lifecycle: lifecycle,
                isFavorite: isFavorite
            ) + (resourceInspection?.searchTokens ?? []) + (thumbnailInspection?.searchTokens ?? []))
                .uniquePreservingOrder(),
            exportHistory: exportHistory,
            diagnosticsReference: diagnosticsReference,
            privacy: privacy
        )
    }

    private var exportIdentifier: String {
        [
            "project",
            source.rawValue,
            "metadata",
            "\(reviewSnapshot.shotCount)shots",
            "schema\(schemaVersion)",
            "\(Int(createdAt.timeIntervalSince1970))"
        ]
        .joined(separator: "-")
        .fileSafeIdentifier
    }

    private static func lifecycle(
        for manifest: BracketManifest,
        exportHistory: [ExportRecord]
    ) -> BracketProjectLifecycle {
        if !exportHistory.isEmpty { return .exported }
        if manifest.shots.contains(where: { $0.captureState.localizedCaseInsensitiveContains("failed") }) {
            return .failed
        }
        if manifest.shots.isEmpty || manifest.shots.contains(where: { $0.captureState == "Missing" }) {
            return .incomplete
        }
        return .reviewable
    }

    private static func stableProjectID(for manifest: BracketManifest) -> String {
        [
            "project",
            manifest.source.rawValue,
            manifest.groupIdentifier,
            "schema\(manifest.schemaVersion)"
        ]
        .joined(separator: "-")
        .fileSafeIdentifier
    }

    private static func searchTokens(
        manifest: BracketManifest,
        sidecar: BracketManifestSidecar?,
        tags: [String],
        userNote: String?,
        lifecycle: BracketProjectLifecycle,
        isFavorite: Bool
    ) -> [String] {
        var tokens = [
            manifest.source.rawValue,
            lifecycle.rawValue,
            "\(manifest.plan.resolvedShotCount)-shot",
            "\(manifest.plan.evStep)-ev"
        ]
        if isFavorite {
            tokens.append(contentsOf: ["favorite", "starred"])
        }
        tokens.append(contentsOf: manifest.shots.flatMap {
            [$0.displayLabel, $0.fileType, $0.captureState] + $0.availableRepresentations + $0.clippingWarnings
        })
        if let recipe = manifest.recipe {
            tokens.append(contentsOf: [recipe.title, recipe.source])
        }
        if let captureDevice = manifest.captureDevice {
            tokens.append(contentsOf: [
                captureDevice.libraryLensTitle,
                captureDevice.deviceType,
                captureDevice.source
            ])
            tokens.append(contentsOf: captureDevice.availableLensLabels)
        }
        if let captureLocation = manifest.captureLocation {
            tokens.append(contentsOf: [
                captureLocation.libraryLocationTitle,
                captureLocation.authorizationState,
                captureLocation.projectStoragePolicy,
                captureLocation.photosWritePolicy,
                captureLocation.source,
                "location policy"
            ])
        }
        if let generatedNote = sidecar?.generatedNote {
            tokens.append(contentsOf: [generatedNote.title, generatedNote.summary, generatedNote.mergeAdvice])
            tokens.append(contentsOf: generatedNote.tags)
        }
        tokens.append(contentsOf: tags)
        if let userNote { tokens.append(userNote) }

        return tokens
            .flatMap { $0.searchTokenComponents }
            .uniquePreservingOrder()
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniquePreservingOrder()
    }

    private static func normalizedUserNote(_ userNote: String?) -> String? {
        let trimmed = userNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct BracketProjectIndex: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    var currentProjectID: String?
    var projectIDs: [String]
    var updatedAt: Date

    init(
        schemaVersion: Int = Self.schemaVersion,
        currentProjectID: String? = nil,
        projectIDs: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.currentProjectID = currentProjectID
        self.projectIDs = projectIDs
        self.updatedAt = updatedAt
    }
}

struct LatestBracketProjectSummary: Codable, Equatable, Sendable {
    let hasProject: Bool
    let title: String
    let detail: String
    let privacy: String
    let finalOutputActionPlanSummary: String?
    let suggestedAction: String

    init(
        hasProject: Bool,
        title: String,
        detail: String,
        privacy: String,
        finalOutputActionPlanSummary: String? = nil,
        suggestedAction: String
    ) {
        self.hasProject = hasProject
        self.title = title
        self.detail = detail
        self.privacy = privacy
        self.finalOutputActionPlanSummary = finalOutputActionPlanSummary
        self.suggestedAction = suggestedAction
    }

    static let empty = LatestBracketProjectSummary(
        hasProject: false,
        title: "No bracket project yet",
        detail: "Capture a bracket before requesting a project summary.",
        privacy: "No project data available",
        finalOutputActionPlanSummary: nil,
        suggestedAction: "Open Bracketer and capture a bracket."
    )

    init(project: BracketProject) {
        hasProject = true
        title = "Latest \(project.reviewSnapshot.shotCount)-shot bracket"

        let selected = project.reviewSnapshot.selectedDisplayLabel ?? "no selected exposure"
        let best = project.reviewSnapshot.bestExposureLabel ?? "no best exposure marked"
        var parts = [
            "\(project.lifecycle.rawValue) \(project.source.rawValue) project",
            "selected \(selected)",
            "best \(best)"
        ]
        if project.reviewSnapshot.missingShotCount > 0 {
            parts.append("\(project.reviewSnapshot.missingShotCount) missing")
        }
        if project.reviewSnapshot.failedShotCount > 0 {
            parts.append("\(project.reviewSnapshot.failedShotCount) failed")
        }
        if let recipeTitle = project.manifest.recipe?.title {
            parts.append("recipe \(recipeTitle)")
        }
        detail = parts.joined(separator: " | ")
        privacy = project.privacy.accessibilityValue
        finalOutputActionPlanSummary = project.finalOutputActionPlanSummary
        suggestedAction = project.lifecycle == .reviewable
            ? "Open Bracketer review or export the project manifest."
            : "Open Bracketer review and resolve the incomplete project before export."
    }

    var dialogText: String {
        [
            title,
            detail,
            finalOutputActionPlanSummary.map { "Final output action plan: \($0)" },
            suggestedAction
        ]
            .compactMap { $0 }
            .joined(separator: ". ")
    }

    var accessibilityValue: String {
        [
            title,
            detail,
            privacy,
            finalOutputActionPlanSummary.map { "Final output action plan: \($0)" },
            suggestedAction
        ]
            .compactMap { $0 }
            .joined(separator: " | ")
    }
}

struct BracketProjectReviewSnapshot: Equatable, Identifiable, Sendable {
    let id: String
    let project: BracketProject
    let sequence: BracketReviewSequence
    let openedAt: Date
    let source: String

    init(
        project: BracketProject,
        openedAt: Date = Date(),
        source: String = "Project Library"
    ) {
        id = [
            project.id,
            "\(Int(openedAt.timeIntervalSince1970 * 1_000))"
        ].joined(separator: "-")
        self.project = project
        self.sequence = BracketReviewSequence.make(manifest: project.manifest)
        self.openedAt = openedAt
        self.source = source
    }

    var title: String {
        project.displayTitle
    }

    var detail: String {
        project.displaySubtitle
    }

    var selectedShotTitle: String {
        sequence.selectedShot?.selectedTitle ?? "No selected exposure"
    }

    var generatedSummary: String? {
        project.sidecar?.generatedNote?.summary
    }

    var accessibilityValue: String {
        var parts = [
            "Project Review",
            title,
            detail,
            selectedShotTitle,
            project.privacy.accessibilityValue,
            "Source \(source)"
        ]
        if let resourceInspection = BracketProjectResourceInspectionReport.make(project: project) {
            parts.append(resourceInspection.accessibilityValue)
        }
        if let thumbnailInspection = BracketProjectThumbnailInspectionReport.make(project: project) {
            parts.append(thumbnailInspection.accessibilityValue)
        }
        parts.append(BracketProjectMergeReadinessReport.make(project: project).accessibilityValue)
        return parts.joined(separator: " | ")
    }
}

struct BracketProjectReviewAccessibilityContract: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let handoffSummaryProbeIdentifier = "review.project.handoff.summary"
    static let selectedShotProbeIdentifier = "review.project.selectedShot"
    static let voiceOverTraversalProbeIdentifier = "review.project.voiceOverTraversal"
    static let finalWorkspaceFixtureProbeIdentifier = "review.project.finalWorkspace.fixture"
    static let tapTargetAuditProbeIdentifier = "review.project.tapTargetAudit"
    static let bestBaseFrameHandoffProbeIdentifier = "review.project.bestBaseFrame"
    static let bestBaseFrameProbeIdentifier = "review.project.bestBaseFrame.card"
    static let beforeAfterScrubHandoffProbeIdentifier = "review.project.beforeAfterScrub"
    static let beforeAfterScrubProbeIdentifier = "review.project.beforeAfterScrub.card"
    static let perShotExposureHandoffProbeIdentifier = "review.project.perShotExposure"
    static let perShotExposureProbeIdentifier = "review.project.perShotExposure.card"
    static let focusEdgeInspectionHandoffProbeIdentifier = "review.project.focusEdge"
    static let focusEdgeInspectionProbeIdentifier = "review.project.focusEdge.card"
    static let motionAlignmentOverlayHandoffProbeIdentifier = "review.project.motionAlignment"
    static let motionAlignmentOverlayProbeIdentifier = "review.project.motionAlignment.card"
    static let motionMetadataHandoffProbeIdentifier = "review.project.motionMetadata"
    static let motionMetadataProbeIdentifier = "review.project.motionMetadata.card"
    static let featureMatchFixtureHandoffProbeIdentifier = "review.project.featureMatch"
    static let featureMatchFixtureProbeIdentifier = "review.project.featureMatch.card"
    static let alignmentTransformHandoffProbeIdentifier = "review.project.alignmentTransform"
    static let alignmentTransformProbeIdentifier = "review.project.alignmentTransform.card"
    static let motionBlurRiskHandoffProbeIdentifier = "review.project.motionBlur"
    static let motionBlurRiskProbeIdentifier = "review.project.motionBlur.card"
    static let ghostingRiskHandoffProbeIdentifier = "review.project.ghostingRisk"
    static let ghostingRiskProbeIdentifier = "review.project.ghostingRisk.card"
    static let movingRegionMaskHandoffProbeIdentifier = "review.project.movingRegionMask"
    static let movingRegionMaskProbeIdentifier = "review.project.movingRegionMask.card"
    static let alignmentPerformanceHandoffProbeIdentifier = "review.project.alignmentPerformance"
    static let alignmentPerformanceProbeIdentifier = "review.project.alignmentPerformance.card"
    static let alignmentExplanationHandoffProbeIdentifier = "review.project.alignmentExplanation"
    static let alignmentExplanationProbeIdentifier = "review.project.alignmentExplanation.card"
    static let qualityReportProbeIdentifier = "review.project.qualityReport"
    static let qualityReportCardProbeIdentifier = "review.project.qualityReport.card"
    static let mergeReadinessHandoffProbeIdentifier = "review.project.mergeReadiness"
    static let mergeReadinessProbeIdentifier = "review.project.mergeReadiness.card"
    static let finalOutputsHandoffProbeIdentifier = "review.project.finalOutputs"
    static let finalOutputsProbeIdentifier = "review.project.finalOutputs.card"
    static let finalOutputReadinessAuditProbeIdentifier = "review.project.finalOutputReadinessAudit"
    static let assetResourcesHandoffProbeIdentifier = "review.project.assetResources"
    static let assetResourcesProbeIdentifier = "review.project.assetResources.card"
    static let imageBundleHandoffProbeIdentifier = "review.project.imageBundle"
    static let imageBundleProbeIdentifier = "review.project.imageBundle.card"
    static let exposureComparisonProbeIdentifier = "review.project.exposureComparison"
    static let pixelComparisonProbeIdentifier = "review.project.pixelComparison"
    static let projectFactsProbeIdentifier = "review.project.facts"
    static let shotRowIdentifierPrefix = "review.project.shot"
    static let previousShotButtonIdentifier = "review.project.previousShotButton"
    static let nextShotButtonIdentifier = "review.project.nextShotButton"
    static let representationToggleIdentifier = "review.project.representationToggle"
    static let closeButtonIdentifier = "review.project.closeButton"

    let schemaVersion: Int
    let minimumTapTargetPoints: Int
    let requiredProbeIdentifiers: [String]
    let navigationControlIdentifiers: [String]
    let shotRowIdentifierPrefix: String
    let shotRowCount: Int
    let exposureComparisonCount: Int
    let pixelComparisonCount: Int
    let reviewCloseButtonPoints: Int
    let selectedShotNavigationButtonPoints: Int
    let representationTogglePoints: Int
    let redactsRawPhotoBytes: Bool
    let redactsPhotosAssetIdentifiers: Bool
    let proofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        minimumTapTargetPoints: Int = 44,
        requiredProbeIdentifiers: [String],
        navigationControlIdentifiers: [String],
        shotRowIdentifierPrefix: String = Self.shotRowIdentifierPrefix,
        shotRowCount: Int,
        exposureComparisonCount: Int,
        pixelComparisonCount: Int,
        reviewCloseButtonPoints: Int,
        selectedShotNavigationButtonPoints: Int,
        representationTogglePoints: Int,
        redactsRawPhotoBytes: Bool = true,
        redactsPhotosAssetIdentifiers: Bool = true,
        proofBoundary: String = "Review Workspace Accessibility Contract is manifest metadata and simulator UI structure only; it exposes stable probes, counts, and control identifiers without raw photo bytes, Photos asset identifiers, thumbnails, final rendered output bytes, or precise coordinates, and does not prove physical-device accessibility."
    ) {
        self.schemaVersion = schemaVersion
        self.minimumTapTargetPoints = minimumTapTargetPoints
        self.requiredProbeIdentifiers = requiredProbeIdentifiers
        self.navigationControlIdentifiers = navigationControlIdentifiers
        self.shotRowIdentifierPrefix = shotRowIdentifierPrefix
        self.shotRowCount = shotRowCount
        self.exposureComparisonCount = exposureComparisonCount
        self.pixelComparisonCount = pixelComparisonCount
        self.reviewCloseButtonPoints = reviewCloseButtonPoints
        self.selectedShotNavigationButtonPoints = selectedShotNavigationButtonPoints
        self.representationTogglePoints = representationTogglePoints
        self.redactsRawPhotoBytes = redactsRawPhotoBytes
        self.redactsPhotosAssetIdentifiers = redactsPhotosAssetIdentifiers
        self.proofBoundary = proofBoundary
    }

    static func make(
        snapshot: BracketProjectReviewSnapshot,
        reviewCloseButtonPoints: Int = 44,
        selectedShotNavigationButtonPoints: Int = 44,
        representationTogglePoints: Int = 44
    ) -> BracketProjectReviewAccessibilityContract {
        let exposureComparison = BracketProjectExposureComparison.make(project: snapshot.project)
        let pixelComparison = BracketProjectSideBySidePixelComparison.make(project: snapshot.project)
        return BracketProjectReviewAccessibilityContract(
            requiredProbeIdentifiers: [
                handoffSummaryProbeIdentifier,
                selectedShotProbeIdentifier,
                voiceOverTraversalProbeIdentifier,
                finalWorkspaceFixtureProbeIdentifier,
                tapTargetAuditProbeIdentifier,
                bestBaseFrameHandoffProbeIdentifier,
                bestBaseFrameProbeIdentifier,
                beforeAfterScrubHandoffProbeIdentifier,
                beforeAfterScrubProbeIdentifier,
                perShotExposureHandoffProbeIdentifier,
                perShotExposureProbeIdentifier,
                focusEdgeInspectionHandoffProbeIdentifier,
                focusEdgeInspectionProbeIdentifier,
                motionAlignmentOverlayHandoffProbeIdentifier,
                motionAlignmentOverlayProbeIdentifier,
                motionMetadataHandoffProbeIdentifier,
                motionMetadataProbeIdentifier,
                featureMatchFixtureHandoffProbeIdentifier,
                featureMatchFixtureProbeIdentifier,
                alignmentTransformHandoffProbeIdentifier,
                alignmentTransformProbeIdentifier,
                motionBlurRiskHandoffProbeIdentifier,
                motionBlurRiskProbeIdentifier,
                ghostingRiskHandoffProbeIdentifier,
                ghostingRiskProbeIdentifier,
                movingRegionMaskHandoffProbeIdentifier,
                movingRegionMaskProbeIdentifier,
                alignmentPerformanceHandoffProbeIdentifier,
                alignmentPerformanceProbeIdentifier,
                alignmentExplanationHandoffProbeIdentifier,
                alignmentExplanationProbeIdentifier,
                qualityReportProbeIdentifier,
                qualityReportCardProbeIdentifier,
                mergeReadinessHandoffProbeIdentifier,
                mergeReadinessProbeIdentifier,
                finalOutputsHandoffProbeIdentifier,
                finalOutputsProbeIdentifier,
                finalOutputReadinessAuditProbeIdentifier,
                assetResourcesHandoffProbeIdentifier,
                assetResourcesProbeIdentifier,
                imageBundleHandoffProbeIdentifier,
                imageBundleProbeIdentifier,
                exposureComparisonProbeIdentifier,
                pixelComparisonProbeIdentifier,
                projectFactsProbeIdentifier,
            ],
            navigationControlIdentifiers: [
                previousShotButtonIdentifier,
                nextShotButtonIdentifier,
                representationToggleIdentifier,
                closeButtonIdentifier,
            ],
            shotRowCount: snapshot.sequence.shots.count,
            exposureComparisonCount: exposureComparison.items.count,
            pixelComparisonCount: pixelComparison?.pairs.count ?? 0,
            reviewCloseButtonPoints: reviewCloseButtonPoints,
            selectedShotNavigationButtonPoints: selectedShotNavigationButtonPoints,
            representationTogglePoints: representationTogglePoints
        )
    }

    var hasRequiredProbes: Bool {
        let required = [
            Self.handoffSummaryProbeIdentifier,
            Self.selectedShotProbeIdentifier,
            Self.voiceOverTraversalProbeIdentifier,
            Self.finalWorkspaceFixtureProbeIdentifier,
            Self.tapTargetAuditProbeIdentifier,
            Self.bestBaseFrameHandoffProbeIdentifier,
            Self.bestBaseFrameProbeIdentifier,
            Self.beforeAfterScrubHandoffProbeIdentifier,
            Self.beforeAfterScrubProbeIdentifier,
            Self.perShotExposureHandoffProbeIdentifier,
            Self.perShotExposureProbeIdentifier,
            Self.focusEdgeInspectionHandoffProbeIdentifier,
            Self.focusEdgeInspectionProbeIdentifier,
            Self.motionAlignmentOverlayHandoffProbeIdentifier,
            Self.motionAlignmentOverlayProbeIdentifier,
            Self.motionMetadataHandoffProbeIdentifier,
            Self.motionMetadataProbeIdentifier,
            Self.featureMatchFixtureHandoffProbeIdentifier,
            Self.featureMatchFixtureProbeIdentifier,
            Self.alignmentTransformHandoffProbeIdentifier,
            Self.alignmentTransformProbeIdentifier,
            Self.motionBlurRiskHandoffProbeIdentifier,
            Self.motionBlurRiskProbeIdentifier,
            Self.ghostingRiskHandoffProbeIdentifier,
            Self.ghostingRiskProbeIdentifier,
            Self.movingRegionMaskHandoffProbeIdentifier,
            Self.movingRegionMaskProbeIdentifier,
            Self.alignmentPerformanceHandoffProbeIdentifier,
            Self.alignmentPerformanceProbeIdentifier,
            Self.alignmentExplanationHandoffProbeIdentifier,
            Self.alignmentExplanationProbeIdentifier,
            Self.qualityReportProbeIdentifier,
            Self.qualityReportCardProbeIdentifier,
            Self.mergeReadinessHandoffProbeIdentifier,
            Self.mergeReadinessProbeIdentifier,
            Self.finalOutputsHandoffProbeIdentifier,
            Self.finalOutputsProbeIdentifier,
            Self.finalOutputReadinessAuditProbeIdentifier,
            Self.assetResourcesHandoffProbeIdentifier,
            Self.assetResourcesProbeIdentifier,
            Self.imageBundleHandoffProbeIdentifier,
            Self.imageBundleProbeIdentifier,
            Self.exposureComparisonProbeIdentifier,
            Self.pixelComparisonProbeIdentifier,
            Self.projectFactsProbeIdentifier,
        ]
        return required.allSatisfy(requiredProbeIdentifiers.contains)
            && shotRowCount > 0
            && exposureComparisonCount > 0
            && pixelComparisonCount > 0
    }

    var hasNavigationControls: Bool {
        [
            Self.previousShotButtonIdentifier,
            Self.nextShotButtonIdentifier,
            Self.representationToggleIdentifier,
            Self.closeButtonIdentifier,
        ].allSatisfy(navigationControlIdentifiers.contains)
    }

    var tapTargetsVerified: Bool {
        [
            reviewCloseButtonPoints,
            selectedShotNavigationButtonPoints,
            representationTogglePoints,
        ].allSatisfy { $0 >= minimumTapTargetPoints }
    }

    var isVerified: Bool {
        hasRequiredProbes
            && hasNavigationControls
            && tapTargetsVerified
            && redactsRawPhotoBytes
            && redactsPhotosAssetIdentifiers
    }

    var accessibilityValue: String {
        [
            "Review Workspace Accessibility Contract",
            "schema v\(schemaVersion)",
            isVerified ? "Verified" : "Follow-up required",
            "Minimum tap target \(minimumTapTargetPoints) pt",
            "Probes: \(requiredProbeIdentifiers.joined(separator: ", "))",
            "Controls: \(navigationControlIdentifiers.joined(separator: ", "))",
            "Shot rows: \(shotRowIdentifierPrefix).<index> x\(shotRowCount)",
            "Exposure comparisons: \(exposureComparisonCount)",
            "Pixel comparisons: \(pixelComparisonCount)",
            "Close button \(reviewCloseButtonPoints) pt",
            "Selected-shot navigation \(selectedShotNavigationButtonPoints) pt",
            "Representation toggle \(representationTogglePoints) pt",
            redactsRawPhotoBytes ? "No raw photo bytes exposed" : "Raw photo byte exposure pending review",
            redactsPhotosAssetIdentifiers ? "Photos asset identifiers redacted" : "Photos asset identifier redaction pending review",
            proofBoundary,
        ].joined(separator: " | ")
    }
}

struct BracketProjectReviewTapTargetAudit: Codable, Equatable, Sendable {
    struct Row: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let label: String
        let accessibilityIdentifier: String
        let scope: String
        let measuredPoints: Int
        let minimumPoints: Int
        let status: String

        var isVerified: Bool {
            measuredPoints >= minimumPoints
        }

        var accessibilityValue: String {
            [
                label,
                accessibilityIdentifier,
                scope,
                "\(measuredPoints) pt",
                "Minimum \(minimumPoints) pt",
                status,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let boundary = "Review/export tap-target audit is a model contract for expected SwiftUI control frames only; it does not measure physical touch ergonomics, prove real-device hit testing, inspect raw photo bytes, expose Photos asset identifiers, render final output, or prove physical-device accessibility."
    static let reviewGuidanceRowIDs = [
        "bestBaseFrame",
        "beforeAfterScrub",
        "perShotExposure",
        "focusEdge",
        "motionAlignment",
        "motionMetadata",
        "featureMatch",
        "alignmentTransform",
        "motionBlur",
        "ghostingRisk",
        "movingRegionMask",
        "alignmentPerformance",
        "alignmentExplanation",
        "qualityReport",
        "mergeReadiness",
    ]
    static let exportRowIDs = [
        "finalOutputs",
        "assetResources",
        "imageBundle",
    ]
    static let comparisonRowIDs = [
        "exposureComparison",
        "pixelComparison",
    ]
    static let selectedControlRowIDs = [
        "previousShot",
        "nextShot",
        "representationToggle",
        "close",
        "selectedShot",
    ]
    static let shotRowIDs = [
        "shotRows",
    ]

    let schemaVersion: Int
    let projectID: String
    let title: String
    let minimumTapTargetPoints: Int
    let rows: [Row]
    let verifiedRowCount: Int
    let followUpRowCount: Int
    let boundary: String

    static func make(
        snapshot: BracketProjectReviewSnapshot,
        minimumTapTargetPoints: Int = 44,
        selectedShotNavigationButtonPoints: Int = 44,
        representationTogglePoints: Int = 44,
        closeButtonPoints: Int = 44,
        selectedShotCardPoints: Int = 44,
        reviewCardPoints: Int = 44,
        exportCardPoints: Int = 44,
        comparisonCardPoints: Int = 44,
        shotRowPoints: Int = 44
    ) -> BracketProjectReviewTapTargetAudit {
        let contract = BracketProjectReviewAccessibilityContract.make(
            snapshot: snapshot,
            reviewCloseButtonPoints: closeButtonPoints,
            selectedShotNavigationButtonPoints: selectedShotNavigationButtonPoints,
            representationTogglePoints: representationTogglePoints
        )
        let rows = [
            row(
                id: "previousShot",
                label: "Previous shot button",
                identifier: BracketProjectReviewAccessibilityContract.previousShotButtonIdentifier,
                scope: "Selected-shot navigation",
                points: contract.selectedShotNavigationButtonPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "nextShot",
                label: "Next shot button",
                identifier: BracketProjectReviewAccessibilityContract.nextShotButtonIdentifier,
                scope: "Selected-shot navigation",
                points: contract.selectedShotNavigationButtonPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "representationToggle",
                label: "Representation toggle",
                identifier: BracketProjectReviewAccessibilityContract.representationToggleIdentifier,
                scope: "RAW/processed review toggle",
                points: contract.representationTogglePoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "close",
                label: "Close review button",
                identifier: BracketProjectReviewAccessibilityContract.closeButtonIdentifier,
                scope: "Review dismissal",
                points: contract.reviewCloseButtonPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "selectedShot",
                label: "Selected shot card",
                identifier: BracketProjectReviewAccessibilityContract.selectedShotProbeIdentifier,
                scope: "Selected-shot summary",
                points: selectedShotCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "bestBaseFrame",
                label: "Best-base-frame card",
                identifier: BracketProjectReviewAccessibilityContract.bestBaseFrameProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "beforeAfterScrub",
                label: "Before/after scrub card",
                identifier: BracketProjectReviewAccessibilityContract.beforeAfterScrubProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "perShotExposure",
                label: "Per-shot exposure card",
                identifier: BracketProjectReviewAccessibilityContract.perShotExposureProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "focusEdge",
                label: "Focus/edge card",
                identifier: BracketProjectReviewAccessibilityContract.focusEdgeInspectionProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "motionAlignment",
                label: "Motion/alignment card",
                identifier: BracketProjectReviewAccessibilityContract.motionAlignmentOverlayProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "motionMetadata",
                label: "Motion metadata card",
                identifier: BracketProjectReviewAccessibilityContract.motionMetadataProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "featureMatch",
                label: "Feature-match card",
                identifier: BracketProjectReviewAccessibilityContract.featureMatchFixtureProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "alignmentTransform",
                label: "Alignment transform card",
                identifier: BracketProjectReviewAccessibilityContract.alignmentTransformProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "motionBlur",
                label: "Motion/blur card",
                identifier: BracketProjectReviewAccessibilityContract.motionBlurRiskProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "ghostingRisk",
                label: "Ghosting-risk card",
                identifier: BracketProjectReviewAccessibilityContract.ghostingRiskProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "movingRegionMask",
                label: "Moving-region mask card",
                identifier: BracketProjectReviewAccessibilityContract.movingRegionMaskProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "alignmentPerformance",
                label: "Alignment performance card",
                identifier: BracketProjectReviewAccessibilityContract.alignmentPerformanceProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "alignmentExplanation",
                label: "Alignment explanation card",
                identifier: BracketProjectReviewAccessibilityContract.alignmentExplanationProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "qualityReport",
                label: "Capture quality card",
                identifier: BracketProjectReviewAccessibilityContract.qualityReportCardProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "mergeReadiness",
                label: "Merge readiness card",
                identifier: BracketProjectReviewAccessibilityContract.mergeReadinessProbeIdentifier,
                scope: "Review guidance",
                points: reviewCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "finalOutputs",
                label: "Final outputs card",
                identifier: BracketProjectReviewAccessibilityContract.finalOutputsProbeIdentifier,
                scope: "Export review",
                points: exportCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "assetResources",
                label: "Asset resources card",
                identifier: BracketProjectReviewAccessibilityContract.assetResourcesProbeIdentifier,
                scope: "Export resources",
                points: exportCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "imageBundle",
                label: "Image bundle card",
                identifier: BracketProjectReviewAccessibilityContract.imageBundleProbeIdentifier,
                scope: "Export bundle",
                points: exportCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "exposureComparison",
                label: "Exposure comparison card",
                identifier: BracketProjectReviewAccessibilityContract.exposureComparisonProbeIdentifier,
                scope: "Review comparison",
                points: comparisonCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "pixelComparison",
                label: "Pixel comparison card",
                identifier: BracketProjectReviewAccessibilityContract.pixelComparisonProbeIdentifier,
                scope: "Synthetic pixel comparison",
                points: comparisonCardPoints,
                minimum: minimumTapTargetPoints
            ),
            row(
                id: "shotRows",
                label: "Shot rows",
                identifier: "\(BracketProjectReviewAccessibilityContract.shotRowIdentifierPrefix).<index>",
                scope: "\(snapshot.sequence.shots.count) selectable review rows",
                points: shotRowPoints,
                minimum: minimumTapTargetPoints
            ),
        ]
        let verified = rows.filter(\.isVerified).count
        return BracketProjectReviewTapTargetAudit(
            schemaVersion: schemaVersion,
            projectID: snapshot.project.id,
            title: snapshot.title,
            minimumTapTargetPoints: minimumTapTargetPoints,
            rows: rows,
            verifiedRowCount: verified,
            followUpRowCount: rows.count - verified,
            boundary: boundary
        )
    }

    var isVerified: Bool {
        followUpRowCount == 0 && !rows.isEmpty
    }

    var summaryLabel: String {
        isVerified
            ? "\(verifiedRowCount)/\(rows.count) tap targets verified"
            : "\(followUpRowCount) tap target follow-ups"
    }

    var reviewGuidanceRows: [Row] {
        rows.filter { Self.reviewGuidanceRowIDs.contains($0.id) }
    }

    var reviewGuidanceRowCount: Int {
        reviewGuidanceRows.count
    }

    var reviewGuidanceVerifiedRowCount: Int {
        reviewGuidanceRows.filter(\.isVerified).count
    }

    var reviewGuidanceFollowUpRowCount: Int {
        reviewGuidanceRows.count - reviewGuidanceVerifiedRowCount
    }

    var reviewGuidanceSummaryLabel: String {
        reviewGuidanceFollowUpRowCount == 0
            ? "\(reviewGuidanceVerifiedRowCount)/\(reviewGuidanceRowCount) review guidance tap targets verified"
            : "\(reviewGuidanceFollowUpRowCount) review guidance tap target follow-ups"
    }

    var exportRows: [Row] {
        rows.filter { Self.exportRowIDs.contains($0.id) }
    }

    var exportRowCount: Int {
        exportRows.count
    }

    var exportVerifiedRowCount: Int {
        exportRows.filter(\.isVerified).count
    }

    var exportFollowUpRowCount: Int {
        exportRows.count - exportVerifiedRowCount
    }

    var exportSummaryLabel: String {
        exportFollowUpRowCount == 0
            ? "\(exportVerifiedRowCount)/\(exportRowCount) export tap targets verified"
            : "\(exportFollowUpRowCount) export tap target follow-ups"
    }

    var comparisonRows: [Row] {
        rows.filter { Self.comparisonRowIDs.contains($0.id) }
    }

    var comparisonRowCount: Int {
        comparisonRows.count
    }

    var comparisonVerifiedRowCount: Int {
        comparisonRows.filter(\.isVerified).count
    }

    var comparisonFollowUpRowCount: Int {
        comparisonRows.count - comparisonVerifiedRowCount
    }

    var comparisonSummaryLabel: String {
        comparisonFollowUpRowCount == 0
            ? "\(comparisonVerifiedRowCount)/\(comparisonRowCount) comparison tap targets verified"
            : "\(comparisonFollowUpRowCount) comparison tap target follow-ups"
    }

    var selectedControlRows: [Row] {
        rows.filter { Self.selectedControlRowIDs.contains($0.id) }
    }

    var selectedControlRowCount: Int {
        selectedControlRows.count
    }

    var selectedControlVerifiedRowCount: Int {
        selectedControlRows.filter(\.isVerified).count
    }

    var selectedControlFollowUpRowCount: Int {
        selectedControlRows.count - selectedControlVerifiedRowCount
    }

    var selectedControlSummaryLabel: String {
        selectedControlFollowUpRowCount == 0
            ? "\(selectedControlVerifiedRowCount)/\(selectedControlRowCount) selected-shot control tap targets verified"
            : "\(selectedControlFollowUpRowCount) selected-shot control tap target follow-ups"
    }

    var shotRows: [Row] {
        rows.filter { Self.shotRowIDs.contains($0.id) }
    }

    var shotRowAuditCount: Int {
        shotRows.count
    }

    var shotRowVerifiedCount: Int {
        shotRows.filter(\.isVerified).count
    }

    var shotRowFollowUpCount: Int {
        shotRows.count - shotRowVerifiedCount
    }

    var shotRowSummaryLabel: String {
        shotRowFollowUpCount == 0
            ? "\(shotRowVerifiedCount)/\(shotRowAuditCount) shot-row tap target scopes verified"
            : "\(shotRowFollowUpCount) shot-row tap target follow-ups"
    }

    var accessibilityValue: String {
        [
            "Review Export Tap Target Audit",
            title,
            "schema v\(schemaVersion)",
            summaryLabel,
            selectedControlSummaryLabel,
            reviewGuidanceSummaryLabel,
            exportSummaryLabel,
            comparisonSummaryLabel,
            shotRowSummaryLabel,
            "Minimum tap target \(minimumTapTargetPoints) pt",
            "Rows: \(rows.map(\.accessibilityValue).joined(separator: " ; "))",
            boundary,
        ].joined(separator: " | ")
    }

    private static func row(
        id: String,
        label: String,
        identifier: String,
        scope: String,
        points: Int,
        minimum: Int
    ) -> Row {
        Row(
            id: id,
            label: label,
            accessibilityIdentifier: identifier,
            scope: scope,
            measuredPoints: points,
            minimumPoints: minimum,
            status: points >= minimum ? "Verified" : "Follow-up required"
        )
    }
}

struct BracketProjectReviewVoiceOverTraversalSnapshot: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Identifiable, Sendable {
        let order: Int
        let identifier: String
        let label: String
        let role: String
        let traits: [String]
        let expectedValueFragments: [String]

        var id: String { identifier }

        var accessibilityValue: String {
            [
                "#\(order)",
                label,
                identifier,
                role,
                "Traits: \(traits.joined(separator: ", "))",
                expectedValueFragments.joined(separator: ", "),
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let boundary = "Review VoiceOver traversal snapshot is simulator UI structure and accessibility-value metadata only; it does not run VoiceOver, prove rotor order on hardware, expose raw photo bytes, Photos asset identifiers, thumbnails, final rendered output bytes, or precise coordinates."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let entries: [Entry]
    let boundary: String

    static func make(
        snapshot: BracketProjectReviewSnapshot
    ) -> BracketProjectReviewVoiceOverTraversalSnapshot {
        let baseEntries = [
            Entry(
                order: 0,
                identifier: BracketProjectReviewAccessibilityContract.handoffSummaryProbeIdentifier,
                label: "Project review summary",
                role: "Summary probe",
                traits: ["staticText"],
                expectedValueFragments: ["Project Review", snapshot.title]
            ),
            Entry(
                order: 1,
                identifier: BracketProjectReviewAccessibilityContract.voiceOverTraversalProbeIdentifier,
                label: "VoiceOver traversal snapshot",
                role: "Traversal probe",
                traits: ["staticText"],
                expectedValueFragments: ["Review VoiceOver Traversal", "schema v\(schemaVersion)"]
            ),
            Entry(
                order: 2,
                identifier: BracketProjectReviewAccessibilityContract.finalWorkspaceFixtureProbeIdentifier,
                label: "Final review workspace fixture",
                role: "Workspace fixture probe",
                traits: ["staticText"],
                expectedValueFragments: ["Final Review Workspace Fixture"]
            ),
            Entry(
                order: 3,
                identifier: BracketProjectReviewAccessibilityContract.tapTargetAuditProbeIdentifier,
                label: "Review export tap target audit",
                role: "Tap target audit probe",
                traits: ["staticText"],
                expectedValueFragments: ["Review Export Tap Target Audit"]
            ),
            Entry(
                order: 4,
                identifier: BracketProjectReviewAccessibilityContract.selectedShotProbeIdentifier,
                label: "Selected shot",
                role: "Review card",
                traits: ["group"],
                expectedValueFragments: [snapshot.selectedShotTitle]
            ),
            Entry(
                order: 5,
                identifier: BracketProjectReviewAccessibilityContract.bestBaseFrameHandoffProbeIdentifier,
                label: "Best base frame handoff fixture",
                role: "Best-base-frame probe",
                traits: ["staticText"],
                expectedValueFragments: ["Best Base Frame Suggestion"]
            ),
            Entry(
                order: 6,
                identifier: BracketProjectReviewAccessibilityContract.bestBaseFrameProbeIdentifier,
                label: "Best base frame",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Best Base Frame Suggestion"]
            ),
            Entry(
                order: 7,
                identifier: BracketProjectReviewAccessibilityContract.beforeAfterScrubHandoffProbeIdentifier,
                label: "Before after scrub handoff fixture",
                role: "Before/after scrub probe",
                traits: ["staticText"],
                expectedValueFragments: ["Before/After Scrub Plan"]
            ),
            Entry(
                order: 8,
                identifier: BracketProjectReviewAccessibilityContract.beforeAfterScrubProbeIdentifier,
                label: "Before after scrub",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Before/After Scrub Plan"]
            ),
            Entry(
                order: 9,
                identifier: BracketProjectReviewAccessibilityContract.perShotExposureHandoffProbeIdentifier,
                label: "Per-shot exposure handoff fixture",
                role: "Per-shot exposure probe",
                traits: ["staticText"],
                expectedValueFragments: ["Per-shot Exposure Distribution"]
            ),
            Entry(
                order: 10,
                identifier: BracketProjectReviewAccessibilityContract.perShotExposureProbeIdentifier,
                label: "Per-shot exposure",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Per-shot Exposure Distribution"]
            ),
            Entry(
                order: 11,
                identifier: BracketProjectReviewAccessibilityContract.focusEdgeInspectionHandoffProbeIdentifier,
                label: "Focus/Edge handoff fixture",
                role: "Focus/edge probe",
                traits: ["staticText"],
                expectedValueFragments: ["Focus/Edge Inspection"]
            ),
            Entry(
                order: 12,
                identifier: BracketProjectReviewAccessibilityContract.focusEdgeInspectionProbeIdentifier,
                label: "Focus/Edge Inspection",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Focus/Edge Inspection"]
            ),
            Entry(
                order: 13,
                identifier: BracketProjectReviewAccessibilityContract.motionAlignmentOverlayHandoffProbeIdentifier,
                label: "Motion/alignment handoff fixture",
                role: "Motion/alignment probe",
                traits: ["staticText"],
                expectedValueFragments: ["Motion/Alignment Overlay"]
            ),
            Entry(
                order: 14,
                identifier: BracketProjectReviewAccessibilityContract.motionAlignmentOverlayProbeIdentifier,
                label: "Motion/Alignment Overlay",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Motion/Alignment Overlay"]
            ),
            Entry(
                order: 15,
                identifier: BracketProjectReviewAccessibilityContract.motionMetadataHandoffProbeIdentifier,
                label: "Motion metadata handoff fixture",
                role: "Motion metadata probe",
                traits: ["staticText"],
                expectedValueFragments: ["Motion Metadata Capture"]
            ),
            Entry(
                order: 16,
                identifier: BracketProjectReviewAccessibilityContract.motionMetadataProbeIdentifier,
                label: "Motion Metadata Capture",
                role: "Review metadata card",
                traits: ["staticText"],
                expectedValueFragments: ["Motion Metadata Capture"]
            ),
            Entry(
                order: 17,
                identifier: BracketProjectReviewAccessibilityContract.featureMatchFixtureHandoffProbeIdentifier,
                label: "Feature match handoff fixture",
                role: "Feature-match probe",
                traits: ["staticText"],
                expectedValueFragments: ["Feature Match Fixture"]
            ),
            Entry(
                order: 18,
                identifier: BracketProjectReviewAccessibilityContract.featureMatchFixtureProbeIdentifier,
                label: "Feature Match Fixture",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Feature Match Fixture"]
            ),
            Entry(
                order: 19,
                identifier: BracketProjectReviewAccessibilityContract.alignmentTransformHandoffProbeIdentifier,
                label: "Alignment transform handoff fixture",
                role: "Alignment-transform probe",
                traits: ["staticText"],
                expectedValueFragments: ["Alignment Transform"]
            ),
            Entry(
                order: 20,
                identifier: BracketProjectReviewAccessibilityContract.alignmentTransformProbeIdentifier,
                label: "Alignment Transform",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Alignment Transform"]
            ),
            Entry(
                order: 21,
                identifier: BracketProjectReviewAccessibilityContract.motionBlurRiskHandoffProbeIdentifier,
                label: "Motion/blur handoff fixture",
                role: "Motion-blur probe",
                traits: ["staticText"],
                expectedValueFragments: ["Motion/Blur Risk"]
            ),
            Entry(
                order: 22,
                identifier: BracketProjectReviewAccessibilityContract.motionBlurRiskProbeIdentifier,
                label: "Motion/Blur Risk",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Motion/Blur Risk"]
            ),
            Entry(
                order: 23,
                identifier: BracketProjectReviewAccessibilityContract.ghostingRiskHandoffProbeIdentifier,
                label: "Ghosting risk handoff fixture",
                role: "Ghosting-risk probe",
                traits: ["staticText"],
                expectedValueFragments: ["Ghosting Risk"]
            ),
            Entry(
                order: 24,
                identifier: BracketProjectReviewAccessibilityContract.ghostingRiskProbeIdentifier,
                label: "Ghosting Risk",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Ghosting Risk"]
            ),
            Entry(
                order: 25,
                identifier: BracketProjectReviewAccessibilityContract.movingRegionMaskHandoffProbeIdentifier,
                label: "Moving-region mask handoff fixture",
                role: "Moving-region mask probe",
                traits: ["staticText"],
                expectedValueFragments: ["Moving-Region Mask"]
            ),
            Entry(
                order: 26,
                identifier: BracketProjectReviewAccessibilityContract.movingRegionMaskProbeIdentifier,
                label: "Moving-Region Mask",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Moving-Region Mask"]
            ),
            Entry(
                order: 27,
                identifier: BracketProjectReviewAccessibilityContract.alignmentPerformanceHandoffProbeIdentifier,
                label: "Alignment performance handoff fixture",
                role: "Alignment-performance probe",
                traits: ["staticText"],
                expectedValueFragments: ["Alignment Performance Notes"]
            ),
            Entry(
                order: 28,
                identifier: BracketProjectReviewAccessibilityContract.alignmentPerformanceProbeIdentifier,
                label: "Alignment Performance Notes",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Alignment Performance Notes"]
            ),
            Entry(
                order: 29,
                identifier: BracketProjectReviewAccessibilityContract.alignmentExplanationHandoffProbeIdentifier,
                label: "Alignment explanation handoff fixture",
                role: "Alignment-explanation probe",
                traits: ["staticText"],
                expectedValueFragments: ["Alignment Explanation"]
            ),
            Entry(
                order: 30,
                identifier: BracketProjectReviewAccessibilityContract.alignmentExplanationProbeIdentifier,
                label: "Alignment Explanation",
                role: "Review guidance card",
                traits: ["staticText"],
                expectedValueFragments: ["Alignment Explanation"]
            ),
            Entry(
                order: 31,
                identifier: BracketProjectReviewAccessibilityContract.qualityReportProbeIdentifier,
                label: "Capture quality handoff fixture",
                role: "Quality probe",
                traits: ["staticText"],
                expectedValueFragments: ["Capture Quality"]
            ),
            Entry(
                order: 32,
                identifier: BracketProjectReviewAccessibilityContract.qualityReportCardProbeIdentifier,
                label: "Capture quality",
                role: "Quality card",
                traits: ["staticText"],
                expectedValueFragments: ["Capture Quality"]
            ),
            Entry(
                order: 33,
                identifier: BracketProjectReviewAccessibilityContract.mergeReadinessHandoffProbeIdentifier,
                label: "Merge readiness handoff fixture",
                role: "Merge-readiness probe",
                traits: ["staticText"],
                expectedValueFragments: ["Merge Readiness"]
            ),
            Entry(
                order: 34,
                identifier: BracketProjectReviewAccessibilityContract.mergeReadinessProbeIdentifier,
                label: "Merge readiness",
                role: "Readiness card",
                traits: ["staticText"],
                expectedValueFragments: ["Merge Readiness"]
            ),
            Entry(
                order: 35,
                identifier: BracketProjectReviewAccessibilityContract.finalOutputsHandoffProbeIdentifier,
                label: "Final output handoff fixture",
                role: "Final-output probe",
                traits: ["staticText"],
                expectedValueFragments: ["Final Output Manifest"]
            ),
            Entry(
                order: 36,
                identifier: BracketProjectReviewAccessibilityContract.finalOutputsProbeIdentifier,
                label: "Final outputs",
                role: "Export card",
                traits: ["staticText"],
                expectedValueFragments: ["Final Outputs", "Action plan", "not final rendered image proof"]
            ),
            Entry(
                order: 37,
                identifier: BracketProjectReviewAccessibilityContract.finalOutputReadinessAuditProbeIdentifier,
                label: "Final output readiness audit",
                role: "Export audit probe",
                traits: ["staticText"],
                expectedValueFragments: ["Final Output Readiness Audit", "Action plan", "not final rendered image proof"]
            ),
            Entry(
                order: 38,
                identifier: BracketProjectReviewAccessibilityContract.assetResourcesHandoffProbeIdentifier,
                label: "Asset resource handoff fixture",
                role: "Asset-resource probe",
                traits: ["staticText"],
                expectedValueFragments: ["Asset Resources"]
            ),
            Entry(
                order: 39,
                identifier: BracketProjectReviewAccessibilityContract.assetResourcesProbeIdentifier,
                label: "Asset resources",
                role: "Resource card",
                traits: ["staticText"],
                expectedValueFragments: ["Asset Resources"]
            ),
            Entry(
                order: 40,
                identifier: BracketProjectReviewAccessibilityContract.imageBundleHandoffProbeIdentifier,
                label: "Image bundle handoff fixture",
                role: "Image-bundle probe",
                traits: ["staticText"],
                expectedValueFragments: ["Image Bundle Manifest"]
            ),
            Entry(
                order: 41,
                identifier: BracketProjectReviewAccessibilityContract.imageBundleProbeIdentifier,
                label: "Image bundle",
                role: "Export card",
                traits: ["staticText"],
                expectedValueFragments: ["Image Bundle"]
            ),
            Entry(
                order: 42,
                identifier: BracketProjectReviewAccessibilityContract.exposureComparisonProbeIdentifier,
                label: "Exposure comparison",
                role: "Comparison card",
                traits: ["staticText"],
                expectedValueFragments: ["Exposure Comparison"]
            ),
            Entry(
                order: 43,
                identifier: BracketProjectReviewAccessibilityContract.pixelComparisonProbeIdentifier,
                label: "Pixel comparison",
                role: "Synthetic comparison card",
                traits: ["staticText"],
                expectedValueFragments: ["Pixel Comparison"]
            ),
        ]
        let shotEntries = snapshot.sequence.shots.map { shot in
            Entry(
                order: 100 + shot.index,
                identifier: "\(BracketProjectReviewAccessibilityContract.shotRowIdentifierPrefix).\(shot.index)",
                label: shot.sequenceLabel,
                role: "Sequence row",
                traits: ["button"],
                expectedValueFragments: [shot.displayLabel, shot.captureState.displayName]
            )
        }
        let controlEntries = [
            Entry(
                order: 200,
                identifier: BracketProjectReviewAccessibilityContract.previousShotButtonIdentifier,
                label: "Previous review shot",
                role: "Button",
                traits: ["button"],
                expectedValueFragments: ["Previous"]
            ),
            Entry(
                order: 201,
                identifier: BracketProjectReviewAccessibilityContract.nextShotButtonIdentifier,
                label: "Next review shot",
                role: "Button",
                traits: ["button"],
                expectedValueFragments: ["Next"]
            ),
            Entry(
                order: 202,
                identifier: BracketProjectReviewAccessibilityContract.representationToggleIdentifier,
                label: "Toggle review representation",
                role: "Button",
                traits: ["button"],
                expectedValueFragments: ["Processed", "RAW"]
            ),
            Entry(
                order: 203,
                identifier: BracketProjectReviewAccessibilityContract.closeButtonIdentifier,
                label: "Close project review",
                role: "Button",
                traits: ["button"],
                expectedValueFragments: ["Close"]
            ),
        ]

        return BracketProjectReviewVoiceOverTraversalSnapshot(
            schemaVersion: schemaVersion,
            projectID: snapshot.project.id,
            title: snapshot.title,
            source: snapshot.source,
            entries: baseEntries + shotEntries + controlEntries,
            boundary: boundary
        )
    }

    var isComplete: Bool {
        let requiredIdentifiers = [
            BracketProjectReviewAccessibilityContract.handoffSummaryProbeIdentifier,
            BracketProjectReviewAccessibilityContract.voiceOverTraversalProbeIdentifier,
            BracketProjectReviewAccessibilityContract.finalWorkspaceFixtureProbeIdentifier,
            BracketProjectReviewAccessibilityContract.tapTargetAuditProbeIdentifier,
            BracketProjectReviewAccessibilityContract.selectedShotProbeIdentifier,
            BracketProjectReviewAccessibilityContract.bestBaseFrameHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.bestBaseFrameProbeIdentifier,
            BracketProjectReviewAccessibilityContract.beforeAfterScrubHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.beforeAfterScrubProbeIdentifier,
            BracketProjectReviewAccessibilityContract.perShotExposureHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.perShotExposureProbeIdentifier,
            BracketProjectReviewAccessibilityContract.focusEdgeInspectionHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.focusEdgeInspectionProbeIdentifier,
            BracketProjectReviewAccessibilityContract.motionAlignmentOverlayHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.motionAlignmentOverlayProbeIdentifier,
            BracketProjectReviewAccessibilityContract.motionMetadataHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.motionMetadataProbeIdentifier,
            BracketProjectReviewAccessibilityContract.featureMatchFixtureHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.featureMatchFixtureProbeIdentifier,
            BracketProjectReviewAccessibilityContract.alignmentTransformHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.alignmentTransformProbeIdentifier,
            BracketProjectReviewAccessibilityContract.motionBlurRiskHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.motionBlurRiskProbeIdentifier,
            BracketProjectReviewAccessibilityContract.ghostingRiskHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.ghostingRiskProbeIdentifier,
            BracketProjectReviewAccessibilityContract.movingRegionMaskHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.movingRegionMaskProbeIdentifier,
            BracketProjectReviewAccessibilityContract.alignmentPerformanceHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.alignmentPerformanceProbeIdentifier,
            BracketProjectReviewAccessibilityContract.alignmentExplanationHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.alignmentExplanationProbeIdentifier,
            BracketProjectReviewAccessibilityContract.qualityReportProbeIdentifier,
            BracketProjectReviewAccessibilityContract.qualityReportCardProbeIdentifier,
            BracketProjectReviewAccessibilityContract.mergeReadinessHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.mergeReadinessProbeIdentifier,
            BracketProjectReviewAccessibilityContract.finalOutputsHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.finalOutputsProbeIdentifier,
            BracketProjectReviewAccessibilityContract.finalOutputReadinessAuditProbeIdentifier,
            BracketProjectReviewAccessibilityContract.assetResourcesHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.assetResourcesProbeIdentifier,
            BracketProjectReviewAccessibilityContract.imageBundleHandoffProbeIdentifier,
            BracketProjectReviewAccessibilityContract.imageBundleProbeIdentifier,
            BracketProjectReviewAccessibilityContract.exposureComparisonProbeIdentifier,
            BracketProjectReviewAccessibilityContract.pixelComparisonProbeIdentifier,
            BracketProjectReviewAccessibilityContract.previousShotButtonIdentifier,
            BracketProjectReviewAccessibilityContract.nextShotButtonIdentifier,
            BracketProjectReviewAccessibilityContract.representationToggleIdentifier,
            BracketProjectReviewAccessibilityContract.closeButtonIdentifier,
        ]

        return schemaVersion == Self.schemaVersion
            && requiredIdentifiers.allSatisfy { identifier in
                entries.contains { $0.identifier == identifier }
            }
            && entries.first?.identifier == BracketProjectReviewAccessibilityContract.handoffSummaryProbeIdentifier
            && entries.allSatisfy {
                !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.traits.isEmpty
                    && !$0.expectedValueFragments.isEmpty
            }
            && entries.map(\.order) == entries.map(\.order).sorted()
    }

    var accessibilityValue: String {
        [
            "Review VoiceOver Traversal",
            "schema v\(schemaVersion)",
            isComplete ? "Complete" : "Incomplete",
            title,
            "Source \(source)",
            "\(entries.count) entries",
            "Order: \(entries.map { "\($0.order):\($0.identifier)" }.joined(separator: ", "))",
            "Entries: \(entries.map(\.accessibilityValue).joined(separator: " ; "))",
            boundary,
        ].joined(separator: " | ")
    }
}

struct BracketProjectFinalReviewWorkspaceFixtureReport: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let kind = "final-review-workspace-fixture"
    static let source = "directReviewAccessibilityFixture"
    static let boundary = "Final review workspace fixture report is simulator-ready model/UI coverage only; it verifies review probes, alignment diagnostic guide counts, export cards, comparison cards, tap-target contracts, and fixture counts without reading raw photo bytes, exposing Photos asset identifiers, decoding RAW pixels, or rendering final output; it does not run VoiceOver and does not claim to be proving physical-device accessibility."
    static let requiredAlignmentDiagnosticFamilyIDs = [
        "featureMatch",
        "alignmentTransform",
        "motionBlur",
        "ghostingRisk",
        "movingRegionMask",
        "alignmentPerformance",
        "alignmentExplanation",
    ]

    struct AlignmentDiagnosticBreakdown: Codable, Equatable, Sendable {
        let id: String
        let label: String
        let count: Int
        let requiredCount: Int

        var isComplete: Bool {
            count >= requiredCount
        }

        var accessibilityValue: String {
            "\(label) \(count)/\(requiredCount)"
        }
    }

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let requiredProbeCount: Int
    let splitHandoffProbeCount: Int
    let traversalEntryCount: Int
    let shotRowCount: Int
    let featureMatchGuideCount: Int
    let ghostingRiskGuideCount: Int
    let ghostingHighRiskShotCount: Int
    let maxSyntheticGhostingRiskScore: Int
    let movingRegionMaskGuideCount: Int
    let highPriorityMovingRegionMaskCount: Int
    let maxSyntheticMaskCoveragePercent: Int
    let alignmentDiagnosticGuideCount: Int
    let alignmentDiagnosticBreakdowns: [AlignmentDiagnosticBreakdown]
    let tapTargetRowCount: Int
    let selectedControlTapTargetRowCount: Int
    let selectedControlTapTargetFollowUpRowCount: Int
    let reviewGuidanceTapTargetRowCount: Int
    let reviewGuidanceTapTargetFollowUpRowCount: Int
    let exportTapTargetRowCount: Int
    let exportTapTargetFollowUpRowCount: Int
    let comparisonTapTargetRowCount: Int
    let comparisonTapTargetFollowUpRowCount: Int
    let shotRowTapTargetScopeCount: Int
    let shotRowTapTargetFollowUpCount: Int
    let exportSurfaceCount: Int
    let comparisonSurfaceCount: Int
    let finalOutputPlanCount: Int
    let readyFinalOutputCount: Int
    let readyFinalOutputNames: [String]
    let blockedFinalOutputCount: Int
    let blockedFinalOutputNames: [String]
    let finalOutputSourceExposureCount: Int
    let finalOutputCompleteResourcePairCount: Int
    let finalOutputPreviewArtifactAvailable: Bool
    let finalOutputReadinessSummary: String
    let finalOutputRecommendations: [String]
    let finalOutputBlockerReasonCount: Int
    let finalOutputBlockerReasons: [String]
    let finalOutputBlockerSummaries: [String]
    let mergeReadinessScore: Int
    let mergeReadinessLabel: String
    let mergeReadinessBlockerCount: Int
    let mergeReadinessCautionCount: Int
    let mergeReadinessEvidenceCount: Int
    let mergeReadinessBlockerEvidenceTitles: [String]
    let mergeReadinessCautionEvidenceTitles: [String]
    let mergeReadinessRecommendationCount: Int
    let archiveIntegrityPayloadCount: Int
    let archiveIntegrityItemCount: Int
    let archiveIntegrityDigestCount: Int
    let archiveIntegrityInvalidDigestCount: Int
    let archiveIntegrityTotalByteCount: Int
    let isArchiveIntegrityVerified: Bool
    let isFixtureComplete: Bool
    let checklist: [String]
    let boundary: String

    static func make(
        snapshot: BracketProjectReviewSnapshot,
        tapTargetAudit: BracketProjectReviewTapTargetAudit? = nil,
        alignmentDiagnosticBreakdowns injectedAlignmentDiagnosticBreakdowns: [AlignmentDiagnosticBreakdown]? = nil,
        finalOutputs injectedFinalOutputs: BracketProjectFinalOutputManifest? = nil,
        assetResources injectedAssetResources: BracketProjectAssetResourceReport? = nil,
        imageBundle injectedImageBundle: BracketProjectImageBundleManifest? = nil,
        ghostingRisk injectedGhostingRisk: BracketProjectGhostingRiskReport? = nil,
        movingRegionMask injectedMovingRegionMask: BracketProjectMovingRegionMaskReport? = nil,
        exposureComparison injectedExposureComparison: BracketProjectExposureComparison? = nil,
        pixelComparison injectedPixelComparison: BracketProjectSideBySidePixelComparison?? = nil,
        accessibilityContract injectedContract: BracketProjectReviewAccessibilityContract? = nil,
        traversalSnapshot injectedTraversal: BracketProjectReviewVoiceOverTraversalSnapshot? = nil,
        mergeReadiness injectedMergeReadiness: BracketProjectMergeReadinessReport? = nil,
        archiveIntegrity injectedArchiveIntegrity: BracketProjectArchiveIntegrityManifest? = nil
    ) -> BracketProjectFinalReviewWorkspaceFixtureReport {
        let contract = injectedContract ?? BracketProjectReviewAccessibilityContract.make(snapshot: snapshot)
        let traversal = injectedTraversal ?? BracketProjectReviewVoiceOverTraversalSnapshot.make(snapshot: snapshot)
        let tapTargets = tapTargetAudit ?? BracketProjectReviewTapTargetAudit.make(snapshot: snapshot)
        let splitHandoffProbeCount = splitHandoffProbeIdentifiers(
            in: contract.requiredProbeIdentifiers
        ).count
        let featureMatch = BracketProjectFeatureMatchFixtureReport.make(project: snapshot.project)
        let alignmentTransform = BracketProjectAlignmentTransformReport.make(project: snapshot.project)
        let motionBlur = BracketProjectMotionBlurRiskReport.make(project: snapshot.project)
        let ghostingRisk = injectedGhostingRisk ?? BracketProjectGhostingRiskReport.make(project: snapshot.project)
        let movingRegionMask = injectedMovingRegionMask ?? BracketProjectMovingRegionMaskReport.make(project: snapshot.project)
        let alignmentPerformance = BracketProjectAlignmentPerformanceReport.make(project: snapshot.project)
        let alignmentExplanation = BracketProjectAlignmentExplanationReport.make(project: snapshot.project)
        let defaultAlignmentDiagnosticBreakdowns = [
            AlignmentDiagnosticBreakdown(
                id: "featureMatch",
                label: "Feature Match",
                count: featureMatch.featureMatchGuideCount,
                requiredCount: 5
            ),
            AlignmentDiagnosticBreakdown(
                id: "alignmentTransform",
                label: "Alignment Transform",
                count: alignmentTransform.transformGuideCount,
                requiredCount: 5
            ),
            AlignmentDiagnosticBreakdown(
                id: "motionBlur",
                label: "Motion Blur",
                count: motionBlur.riskGuideCount,
                requiredCount: 5
            ),
            AlignmentDiagnosticBreakdown(
                id: "ghostingRisk",
                label: "Ghosting Risk",
                count: ghostingRisk.riskGuideCount,
                requiredCount: 5
            ),
            AlignmentDiagnosticBreakdown(
                id: "movingRegionMask",
                label: "Moving Region Mask",
                count: movingRegionMask.maskGuideCount,
                requiredCount: 5
            ),
            AlignmentDiagnosticBreakdown(
                id: "alignmentPerformance",
                label: "Alignment Performance",
                count: alignmentPerformance.performanceNoteCount,
                requiredCount: 5
            ),
            AlignmentDiagnosticBreakdown(
                id: "alignmentExplanation",
                label: "Alignment Explanation",
                count: alignmentExplanation.explanationCount,
                requiredCount: 5
            ),
        ]
        let alignmentDiagnosticBreakdowns = injectedAlignmentDiagnosticBreakdowns ?? defaultAlignmentDiagnosticBreakdowns
        let alignmentDiagnosticGuideCount = alignmentDiagnosticBreakdowns.reduce(0) { total, breakdown in
            total + breakdown.count
        }
        let mergeReadiness = injectedMergeReadiness ?? BracketProjectMergeReadinessReport.make(project: snapshot.project)
        let mergeReadinessBlockerEvidenceTitles = mergeReadiness.evidence
            .filter { $0.severity == "Blocker" }
            .map(\.title)
        let mergeReadinessCautionEvidenceTitles = mergeReadiness.evidence
            .filter { $0.severity == "Caution" }
            .map(\.title)
        let archiveIntegrity = injectedArchiveIntegrity
        let archiveIntegrityPayloadCount = archiveIntegrity?.payloadCount ?? 0
        let archiveIntegrityItemCount = archiveIntegrity?.items.count ?? 0
        let archiveIntegrityDigestCount = archiveIntegrity?.items.filter {
            isSHA256Hex($0.sha256Hex)
        }.count ?? 0
        let archiveIntegrityInvalidDigestCount = archiveIntegrity.map {
            $0.items.count - archiveIntegrityDigestCount
        } ?? 0
        let isArchiveIntegrityVerified = archiveIntegrity.map {
            archiveIntegrityPayloadCount >= 20
                && archiveIntegrityItemCount == archiveIntegrityPayloadCount
                && archiveIntegrityDigestCount == archiveIntegrityPayloadCount
                && archiveIntegrityInvalidDigestCount == 0
                && !$0.items.contains { $0.kind == BracketProjectArchiveIntegrityManifest.kind }
        } ?? true
        let defaultFinalOutputs = BracketProjectFinalOutputManifest.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let finalOutputs = injectedFinalOutputs ?? defaultFinalOutputs
        let readyFinalOutputNames = finalOutputs.outputs
            .filter { $0.blockers.isEmpty }
            .map(\.displayName)
        let blockedFinalOutputNames = finalOutputs.outputs
            .filter { !$0.blockers.isEmpty }
            .map(\.displayName)
        let finalOutputBlockerReasons = finalOutputs.outputs
            .flatMap(\.blockers)
            .reduce(into: [String]()) { unique, blocker in
                if !unique.contains(blocker) {
                    unique.append(blocker)
                }
            }
        let finalOutputBlockerReasonCount = finalOutputs.outputs.reduce(0) { total, output in
            total + output.blockers.count
        }
        let finalOutputBlockerSummaries = finalOutputs.outputs.compactMap { output -> String? in
            guard !output.blockers.isEmpty else { return nil }
            return "\(output.displayName): \(output.blockers.joined(separator: "; "))"
        }
        let finalOutputRecommendations = finalOutputRecommendationLines(finalOutputs)
        let assetResources = injectedAssetResources ?? BracketProjectAssetResourceReport.make(project: snapshot.project)
        let imageBundle = injectedImageBundle
            ?? BracketProjectImageBundleManifest.make(
                project: snapshot.project,
                privacyLevel: .metadataOnly,
                createdAt: snapshot.project.updatedAt
            )
        let exposureComparison = injectedExposureComparison
            ?? BracketProjectExposureComparison.make(project: snapshot.project)
        let pixelComparison = injectedPixelComparison
            ?? BracketProjectSideBySidePixelComparison.make(project: snapshot.project)
        let comparisonSurfaceCount = (exposureComparison.items.isEmpty ? 0 : 1)
            + ((pixelComparison?.pairs.isEmpty == false) ? 1 : 0)
        let exportSurfaceCount = [
            finalOutputs.outputCount > 0,
            assetResources.shotCount > 0,
            imageBundle.shotCount > 0,
        ].filter { $0 }.count
        let checklist = checklistLines(
            contract: contract,
            splitHandoffProbeCount: splitHandoffProbeCount,
            traversal: traversal,
            tapTargets: tapTargets,
            featureMatch: featureMatch,
            ghostingRisk: ghostingRisk,
            movingRegionMask: movingRegionMask,
            alignmentDiagnosticBreakdowns: alignmentDiagnosticBreakdowns,
            alignmentDiagnosticGuideCount: alignmentDiagnosticGuideCount,
            finalOutputs: finalOutputs,
            assetResources: assetResources,
            imageBundle: imageBundle,
            exposureComparison: exposureComparison,
            pixelComparison: pixelComparison,
            mergeReadiness: mergeReadiness,
            archiveIntegrity: archiveIntegrity,
            archiveIntegrityDigestCount: archiveIntegrityDigestCount,
            archiveIntegrityInvalidDigestCount: archiveIntegrityInvalidDigestCount,
            isArchiveIntegrityVerified: isArchiveIntegrityVerified
        )
        let isComplete = contract.isVerified
            && traversal.isComplete
            && tapTargets.isVerified
            && tapTargets.selectedControlRowCount == BracketProjectReviewTapTargetAudit.selectedControlRowIDs.count
            && tapTargets.selectedControlFollowUpRowCount == 0
            && tapTargets.reviewGuidanceRowCount == BracketProjectReviewTapTargetAudit.reviewGuidanceRowIDs.count
            && tapTargets.reviewGuidanceFollowUpRowCount == 0
            && tapTargets.exportRowCount == BracketProjectReviewTapTargetAudit.exportRowIDs.count
            && tapTargets.exportFollowUpRowCount == 0
            && tapTargets.comparisonRowCount == BracketProjectReviewTapTargetAudit.comparisonRowIDs.count
            && tapTargets.comparisonFollowUpRowCount == 0
            && tapTargets.shotRowAuditCount == BracketProjectReviewTapTargetAudit.shotRowIDs.count
            && tapTargets.shotRowFollowUpCount == 0
            && splitHandoffProbeCount >= 18
            && featureMatch.hasFeatureMatchGuidance
            && ghostingRisk.hasRiskGuidance
            && ghostingRisk.riskGuideCount == snapshot.sequence.shots.count
            && movingRegionMask.hasMaskGuidance
            && movingRegionMask.maskGuideCount == snapshot.sequence.shots.count
            && hasCompleteAlignmentDiagnosticBreakdown(alignmentDiagnosticBreakdowns)
            && alignmentDiagnosticGuideCount >= 35
            && exportSurfaceCount == 3
            && comparisonSurfaceCount == 2
            && finalOutputs.outputCount > 0
            && !finalOutputs.finalRenderedBytesIncluded
            && assetResources.shotCount == snapshot.sequence.shots.count
            && imageBundle.shotCount == snapshot.sequence.shots.count
            && mergeReadiness.score >= 85
            && mergeReadiness.blockerCount == 0
            && isArchiveIntegrityVerified

        return BracketProjectFinalReviewWorkspaceFixtureReport(
            schemaVersion: schemaVersion,
            projectID: snapshot.project.id,
            title: snapshot.title,
            source: source,
            requiredProbeCount: contract.requiredProbeIdentifiers.count,
            splitHandoffProbeCount: splitHandoffProbeCount,
            traversalEntryCount: traversal.entries.count,
            shotRowCount: snapshot.sequence.shots.count,
            featureMatchGuideCount: featureMatch.featureMatchGuideCount,
            ghostingRiskGuideCount: ghostingRisk.riskGuideCount,
            ghostingHighRiskShotCount: ghostingRisk.highRiskShotCount,
            maxSyntheticGhostingRiskScore: ghostingRisk.maxSyntheticGhostingRiskScore,
            movingRegionMaskGuideCount: movingRegionMask.maskGuideCount,
            highPriorityMovingRegionMaskCount: movingRegionMask.highPriorityMaskCount,
            maxSyntheticMaskCoveragePercent: movingRegionMask.maxSyntheticMaskCoveragePercent,
            alignmentDiagnosticGuideCount: alignmentDiagnosticGuideCount,
            alignmentDiagnosticBreakdowns: alignmentDiagnosticBreakdowns,
            tapTargetRowCount: tapTargets.rows.count,
            selectedControlTapTargetRowCount: tapTargets.selectedControlRowCount,
            selectedControlTapTargetFollowUpRowCount: tapTargets.selectedControlFollowUpRowCount,
            reviewGuidanceTapTargetRowCount: tapTargets.reviewGuidanceRowCount,
            reviewGuidanceTapTargetFollowUpRowCount: tapTargets.reviewGuidanceFollowUpRowCount,
            exportTapTargetRowCount: tapTargets.exportRowCount,
            exportTapTargetFollowUpRowCount: tapTargets.exportFollowUpRowCount,
            comparisonTapTargetRowCount: tapTargets.comparisonRowCount,
            comparisonTapTargetFollowUpRowCount: tapTargets.comparisonFollowUpRowCount,
            shotRowTapTargetScopeCount: tapTargets.shotRowAuditCount,
            shotRowTapTargetFollowUpCount: tapTargets.shotRowFollowUpCount,
            exportSurfaceCount: exportSurfaceCount,
            comparisonSurfaceCount: comparisonSurfaceCount,
            finalOutputPlanCount: finalOutputs.outputCount,
            readyFinalOutputCount: finalOutputs.readyOutputCount,
            readyFinalOutputNames: readyFinalOutputNames,
            blockedFinalOutputCount: finalOutputs.blockedOutputCount,
            blockedFinalOutputNames: blockedFinalOutputNames,
            finalOutputSourceExposureCount: finalOutputs.sourceExposureCount,
            finalOutputCompleteResourcePairCount: finalOutputs.completeResourcePairCount,
            finalOutputPreviewArtifactAvailable: finalOutputs.previewArtifactAvailable,
            finalOutputReadinessSummary: finalOutputs.readinessSummary,
            finalOutputRecommendations: finalOutputRecommendations,
            finalOutputBlockerReasonCount: finalOutputBlockerReasonCount,
            finalOutputBlockerReasons: finalOutputBlockerReasons,
            finalOutputBlockerSummaries: finalOutputBlockerSummaries,
            mergeReadinessScore: mergeReadiness.score,
            mergeReadinessLabel: mergeReadiness.label,
            mergeReadinessBlockerCount: mergeReadiness.blockerCount,
            mergeReadinessCautionCount: mergeReadiness.cautionCount,
            mergeReadinessEvidenceCount: mergeReadiness.evidence.count,
            mergeReadinessBlockerEvidenceTitles: mergeReadinessBlockerEvidenceTitles,
            mergeReadinessCautionEvidenceTitles: mergeReadinessCautionEvidenceTitles,
            mergeReadinessRecommendationCount: mergeReadiness.recommendations.count,
            archiveIntegrityPayloadCount: archiveIntegrityPayloadCount,
            archiveIntegrityItemCount: archiveIntegrityItemCount,
            archiveIntegrityDigestCount: archiveIntegrityDigestCount,
            archiveIntegrityInvalidDigestCount: archiveIntegrityInvalidDigestCount,
            archiveIntegrityTotalByteCount: archiveIntegrity?.totalByteCount ?? 0,
            isArchiveIntegrityVerified: isArchiveIntegrityVerified,
            isFixtureComplete: isComplete,
            checklist: checklist,
            boundary: boundary
        )
    }

    var summaryLabel: String {
        isFixtureComplete
            ? "Final review workspace fixture complete"
            : "Final review workspace fixture follow-up required"
    }

    var coverageSummary: String {
        "\(requiredProbeCount) probes, \(splitHandoffProbeCount) split handoff/card pairs, \(traversalEntryCount) traversal entries, \(alignmentDiagnosticGuideCount) alignment diagnostic guides across \(alignmentDiagnosticBreakdowns.count) families, \(tapTargetRowCount) tap-target rows, \(selectedControlTapTargetRowCount) selected-shot control tap targets, \(reviewGuidanceTapTargetRowCount) review guidance tap targets, \(exportTapTargetRowCount) export tap targets, \(comparisonTapTargetRowCount) comparison tap targets, \(shotRowTapTargetScopeCount) shot-row tap target scopes"
    }

    var alignmentDiagnosticBreakdownSummary: String {
        alignmentDiagnosticBreakdowns.map(\.accessibilityValue).joined(separator: ", ")
    }

    var exportSummary: String {
        "\(exportSurfaceCount) export surfaces, \(comparisonSurfaceCount) comparison surfaces, \(finalOutputPlanCount) final-output plans, \(readyFinalOutputCount) ready final outputs, \(blockedFinalOutputCount) blocked final outputs"
    }

    var accessibilityValue: String {
        [
            "Final Review Workspace Fixture",
            title,
            "schema v\(schemaVersion)",
            summaryLabel,
            coverageSummary,
            "\(shotRowCount) shot rows",
            "\(featureMatchGuideCount) feature-match guides",
            "\(ghostingRiskGuideCount) ghosting-risk guides, \(ghostingHighRiskShotCount) high-risk shots, max ghosting risk \(maxSyntheticGhostingRiskScore)",
            "\(movingRegionMaskGuideCount) moving-region mask guides, \(highPriorityMovingRegionMaskCount) high-priority masks, max mask coverage \(maxSyntheticMaskCoveragePercent)%",
            "\(alignmentDiagnosticGuideCount) alignment diagnostic guides",
            "Alignment diagnostic breakdown: \(alignmentDiagnosticBreakdownSummary)",
            "\(selectedControlTapTargetFollowUpRowCount) selected-shot control tap target follow-ups",
            "\(reviewGuidanceTapTargetFollowUpRowCount) review guidance tap target follow-ups",
            "\(exportTapTargetFollowUpRowCount) export tap target follow-ups",
            "\(comparisonTapTargetFollowUpRowCount) comparison tap target follow-ups",
            "\(shotRowTapTargetFollowUpCount) shot-row tap target follow-ups",
            exportSummary,
            "\(readyFinalOutputCount) ready final outputs",
            "Ready final outputs: \(readyFinalOutputNames.isEmpty ? "none" : readyFinalOutputNames.joined(separator: ", "))",
            "\(blockedFinalOutputCount) blocked final outputs",
            "Blocked final outputs: \(blockedFinalOutputNames.isEmpty ? "none" : blockedFinalOutputNames.joined(separator: ", "))",
            "\(finalOutputSourceExposureCount) final-output source exposures",
            "\(finalOutputCompleteResourcePairCount) complete final-output resource pairs",
            "Final-output preview artifact available: \(finalOutputPreviewArtifactAvailable)",
            "Final-output readiness: \(finalOutputReadinessSummary)",
            "\(finalOutputRecommendations.count) final-output recommendations",
            "Final-output recommendations: \(finalOutputRecommendations.isEmpty ? "none" : finalOutputRecommendations.joined(separator: " | "))",
            "\(finalOutputBlockerReasonCount) final-output blocker reasons",
            "Final-output blockers: \(finalOutputBlockerReasons.isEmpty ? "none" : finalOutputBlockerReasons.joined(separator: ", "))",
            "Final-output blocker detail: \(finalOutputBlockerSummaries.isEmpty ? "none" : finalOutputBlockerSummaries.joined(separator: " | "))",
            "Merge \(mergeReadinessLabel), score \(mergeReadinessScore), \(mergeReadinessBlockerCount) blockers, \(mergeReadinessCautionCount) cautions",
            "\(mergeReadinessEvidenceCount) merge-readiness evidence rows",
            "Merge-readiness blockers: \(mergeReadinessBlockerEvidenceTitles.isEmpty ? "none" : mergeReadinessBlockerEvidenceTitles.joined(separator: ", "))",
            "Merge-readiness cautions: \(mergeReadinessCautionEvidenceTitles.isEmpty ? "none" : mergeReadinessCautionEvidenceTitles.joined(separator: ", "))",
            "\(mergeReadinessRecommendationCount) merge-readiness recommendations",
            "Archive integrity \(archiveIntegrityPayloadCount) payloads, \(archiveIntegrityItemCount) items, \(archiveIntegrityDigestCount) valid digests, \(archiveIntegrityInvalidDigestCount) invalid digests, \(archiveIntegrityTotalByteCount) bytes",
            "Archive integrity verified: \(isArchiveIntegrityVerified)",
            "Checklist: \(checklist.joined(separator: " "))",
            boundary,
        ].joined(separator: " | ")
    }

    private static func checklistLines(
        contract: BracketProjectReviewAccessibilityContract,
        splitHandoffProbeCount: Int,
        traversal: BracketProjectReviewVoiceOverTraversalSnapshot,
        tapTargets: BracketProjectReviewTapTargetAudit,
        featureMatch: BracketProjectFeatureMatchFixtureReport,
        ghostingRisk: BracketProjectGhostingRiskReport,
        movingRegionMask: BracketProjectMovingRegionMaskReport,
        alignmentDiagnosticBreakdowns: [AlignmentDiagnosticBreakdown],
        alignmentDiagnosticGuideCount: Int,
        finalOutputs: BracketProjectFinalOutputManifest,
        assetResources: BracketProjectAssetResourceReport,
        imageBundle: BracketProjectImageBundleManifest,
        exposureComparison: BracketProjectExposureComparison,
        pixelComparison: BracketProjectSideBySidePixelComparison?,
        mergeReadiness: BracketProjectMergeReadinessReport,
        archiveIntegrity: BracketProjectArchiveIntegrityManifest?,
        archiveIntegrityDigestCount: Int,
        archiveIntegrityInvalidDigestCount: Int,
        isArchiveIntegrityVerified: Bool
    ) -> [String] {
        [
            accessibilityContractChecklistLine(contract),
            "\(splitHandoffProbeCount) split handoff/card pairs are present.",
            traversal.isComplete ? "Traversal fixture is complete." : "Traversal fixture needs follow-up.",
            tapTargets.isVerified ? "Review/export tap targets meet the model contract." : "Review/export tap targets need follow-up.",
            tapTargets.selectedControlFollowUpRowCount == 0 ? "\(tapTargets.selectedControlRowCount) selected-shot control tap targets meet the model contract." : "\(tapTargets.selectedControlFollowUpRowCount) selected-shot control tap targets need follow-up.",
            tapTargets.reviewGuidanceFollowUpRowCount == 0 ? "\(tapTargets.reviewGuidanceRowCount) review guidance tap targets meet the model contract." : "\(tapTargets.reviewGuidanceFollowUpRowCount) review guidance tap targets need follow-up.",
            tapTargets.exportFollowUpRowCount == 0 ? "\(tapTargets.exportRowCount) export tap targets meet the model contract." : "\(tapTargets.exportFollowUpRowCount) export tap targets need follow-up.",
            tapTargets.comparisonFollowUpRowCount == 0 ? "\(tapTargets.comparisonRowCount) comparison tap targets meet the model contract." : "\(tapTargets.comparisonFollowUpRowCount) comparison tap targets need follow-up.",
            tapTargets.shotRowFollowUpCount == 0 ? "\(tapTargets.shotRowAuditCount) shot-row tap target scopes meet the model contract." : "\(tapTargets.shotRowFollowUpCount) shot-row tap target scopes need follow-up.",
            featureMatch.hasFeatureMatchGuidance ? "\(featureMatch.featureMatchGuideCount) feature-match guides are present." : "Feature-match guides are missing.",
            ghostingRiskChecklistLine(ghostingRisk),
            movingRegionMaskChecklistLine(movingRegionMask),
            hasCompleteAlignmentDiagnosticBreakdown(alignmentDiagnosticBreakdowns) ? "\(alignmentDiagnosticBreakdowns.count) required alignment diagnostic families are complete." : "Required alignment diagnostic family coverage is incomplete.",
            alignmentDiagnosticGuideCount >= 35 ? "\(alignmentDiagnosticGuideCount) alignment diagnostic guides are present." : "Alignment diagnostic guides are incomplete.",
            finalOutputs.outputCount > 0 ? "\(finalOutputs.outputCount) final-output plans are present." : "Final-output plan is missing.",
            finalOutputReadinessChecklistLine(finalOutputs),
            finalOutputRecommendationChecklistLine(finalOutputs),
            finalOutputBlockerChecklistLine(finalOutputs),
            assetResources.shotCount > 0 ? "\(assetResources.shotCount) asset-resource rows are present." : "Asset-resource rows are missing.",
            imageBundle.shotCount > 0 ? "\(imageBundle.shotCount) image-bundle rows are present." : "Image-bundle rows are missing.",
            exposureComparison.items.isEmpty ? "Exposure comparison is missing." : "\(exposureComparison.items.count) exposure comparison rows are present.",
            (pixelComparison?.pairs.isEmpty == false) ? "\(pixelComparison?.pairs.count ?? 0) pixel comparison pairs are present." : "Pixel comparison pairs are missing.",
            finalOutputs.finalRenderedBytesIncluded ? "Unexpected final rendered bytes are included." : "No final rendered bytes are included.",
            mergeReadinessChecklistLine(mergeReadiness),
            archiveIntegrityChecklistLine(
                archiveIntegrity,
                validDigestCount: archiveIntegrityDigestCount,
                invalidDigestCount: archiveIntegrityInvalidDigestCount,
                isVerified: isArchiveIntegrityVerified
            ),
        ]
    }

    private static func ghostingRiskChecklistLine(
        _ ghostingRisk: BracketProjectGhostingRiskReport
    ) -> String {
        guard ghostingRisk.hasRiskGuidance else {
            return "Ghosting-risk guidance needs follow-up: 0 risk guides are present."
        }
        return "\(ghostingRisk.riskGuideCount) ghosting-risk guides are present; \(ghostingRisk.highRiskShotCount) high-risk shot(s), max ghosting risk \(ghostingRisk.maxSyntheticGhostingRiskScore)."
    }

    private static func movingRegionMaskChecklistLine(
        _ movingRegionMask: BracketProjectMovingRegionMaskReport
    ) -> String {
        guard movingRegionMask.hasMaskGuidance else {
            return "Moving-region mask guidance needs follow-up: 0 mask guides are present."
        }
        return "\(movingRegionMask.maskGuideCount) moving-region mask guides are present; \(movingRegionMask.highPriorityMaskCount) high-priority mask(s), max mask coverage \(movingRegionMask.maxSyntheticMaskCoveragePercent)%."
    }

    private static func finalOutputReadinessChecklistLine(
        _ finalOutputs: BracketProjectFinalOutputManifest
    ) -> String {
        let readyNames = finalOutputs.outputs
            .filter { $0.blockers.isEmpty }
            .map(\.displayName)
        let readySummary = readyNames.isEmpty ? "none" : readyNames.joined(separator: ", ")
        return "Final-output readiness says \(finalOutputs.readyOutputCount) ready, \(finalOutputs.blockedOutputCount) blocked, \(finalOutputs.sourceExposureCount) source exposure(s), \(finalOutputs.completeResourcePairCount) complete resource pair(s), preview artifact available \(finalOutputs.previewArtifactAvailable): \(finalOutputs.readinessSummary) Ready outputs: \(readySummary)."
    }

    private static func finalOutputRecommendationChecklistLine(
        _ finalOutputs: BracketProjectFinalOutputManifest
    ) -> String {
        guard finalOutputs.outputCount > 0 else {
            return "Final-output recommendations cannot be evaluated because final-output plans are missing."
        }

        let recommendations = finalOutputRecommendationLines(finalOutputs)
        guard !recommendations.isEmpty else {
            return "Final-output recommendations are missing."
        }

        return "Final-output recommendations cover \(recommendations.count) planned output(s): \(recommendations.joined(separator: " | "))."
    }

    private static func finalOutputRecommendationLines(
        _ finalOutputs: BracketProjectFinalOutputManifest
    ) -> [String] {
        finalOutputs.outputs
            .map { "\($0.displayName): \($0.recommendation)" }
    }

    private static func finalOutputBlockerChecklistLine(
        _ finalOutputs: BracketProjectFinalOutputManifest
    ) -> String {
        guard finalOutputs.outputCount > 0 else {
            return "Final-output blocker detail cannot be evaluated because final-output plans are missing."
        }

        let blockedOutputNames = finalOutputs.outputs
            .filter { !$0.blockers.isEmpty }
            .map(\.displayName)
        guard !blockedOutputNames.isEmpty else {
            return "Final-output blocker detail has no blocked final-output plans."
        }

        let blockerReasonCount = finalOutputs.outputs.reduce(0) { total, output in
            total + output.blockers.count
        }
        return "Final-output blocker detail covers \(blockedOutputNames.count) blocked plan(s) and \(blockerReasonCount) blocker reason(s): \(blockedOutputNames.joined(separator: ", "))."
    }

    private static func archiveIntegrityChecklistLine(
        _ archiveIntegrity: BracketProjectArchiveIntegrityManifest?,
        validDigestCount: Int,
        invalidDigestCount: Int,
        isVerified: Bool
    ) -> String {
        guard let archiveIntegrity else {
            return "Archive integrity manifest not attached to this fixture."
        }
        if isVerified {
            return "Archive integrity manifest covers \(archiveIntegrity.payloadCount) payloads with valid SHA-256 digests."
        }
        return "Archive integrity needs follow-up: payloads \(archiveIntegrity.payloadCount), items \(archiveIntegrity.items.count), valid digests \(validDigestCount), invalid digests \(invalidDigestCount)."
    }

    private static func isSHA256Hex(_ value: String) -> Bool {
        let allowedCharacters = Set("0123456789abcdefABCDEF")
        return value.count == 64 && value.allSatisfy { allowedCharacters.contains($0) }
    }

    private static func mergeReadinessChecklistLine(
        _ mergeReadiness: BracketProjectMergeReadinessReport
    ) -> String {
        if mergeReadiness.score >= 85 && mergeReadiness.blockerCount == 0 {
            return "Merge readiness is ready for cautious merge preview. \(mergeReadiness.evidence.count) evidence rows are present."
        }

        var details: [String] = []
        let blockerTitles = mergeReadiness.evidence
            .filter { $0.severity == "Blocker" }
            .map(\.title)
        let cautionTitles = mergeReadiness.evidence
            .filter { $0.severity == "Caution" }
            .map(\.title)
        if !blockerTitles.isEmpty {
            details.append("Blockers: \(blockerTitles.joined(separator: ", ")).")
        }
        if !cautionTitles.isEmpty {
            details.append("Cautions: \(cautionTitles.joined(separator: ", ")).")
        }
        if !mergeReadiness.recommendations.isEmpty {
            details.append("Recommendations: \(mergeReadiness.recommendations.joined(separator: " "))")
        }
        let detailSuffix = details.isEmpty ? "" : " \(details.joined(separator: " "))"
        return "Merge readiness needs follow-up: score \(mergeReadiness.score), \(mergeReadiness.blockerCount) blocker(s), \(mergeReadiness.cautionCount) caution(s), \(mergeReadiness.label).\(detailSuffix)"
    }

    private static func accessibilityContractChecklistLine(
        _ contract: BracketProjectReviewAccessibilityContract
    ) -> String {
        guard !contract.isVerified else {
            return "Workspace accessibility contract verified."
        }

        var details: [String] = []
        if !contract.hasRequiredProbes {
            details.append("required probes are incomplete")
        }
        if !contract.hasNavigationControls {
            details.append("navigation controls are incomplete")
        }
        if !contract.tapTargetsVerified {
            details.append("tap targets are below minimum")
        }
        if !contract.redactsRawPhotoBytes {
            details.append("raw photo byte redaction needs follow-up")
        }
        if !contract.redactsPhotosAssetIdentifiers {
            details.append("Photos asset identifier redaction needs follow-up")
        }

        return "Workspace accessibility contract needs follow-up. Details: \(details.joined(separator: "; "))."
    }

    private static func splitHandoffProbeIdentifiers(in identifiers: [String]) -> [String] {
        let identifierSet = Set(identifiers)
        return identifiers.filter { identifier in
            !identifier.hasSuffix(".card") && identifierSet.contains("\(identifier).card")
        }
    }

    static func hasCompleteAlignmentDiagnosticBreakdown(
        _ breakdowns: [AlignmentDiagnosticBreakdown]
    ) -> Bool {
        alignmentDiagnosticMissingFamilyIDs(in: breakdowns).isEmpty
            && alignmentDiagnosticDuplicateFamilyIDs(in: breakdowns).isEmpty
            && alignmentDiagnosticUnexpectedFamilyIDs(in: breakdowns).isEmpty
            && breakdowns.allSatisfy { $0.isComplete }
    }

    static func alignmentDiagnosticMissingFamilyIDs(
        in breakdowns: [AlignmentDiagnosticBreakdown]
    ) -> [String] {
        let observedIDs = Set(breakdowns.map(\.id))
        return requiredAlignmentDiagnosticFamilyIDs.filter { !observedIDs.contains($0) }
    }

    static func alignmentDiagnosticDuplicateFamilyIDs(
        in breakdowns: [AlignmentDiagnosticBreakdown]
    ) -> [String] {
        let countsByID = breakdowns.reduce(into: [String: Int]()) { counts, breakdown in
            counts[breakdown.id, default: 0] += 1
        }
        var duplicateIDs: [String] = []
        var seenIDs = Set<String>()
        for breakdown in breakdowns where (countsByID[breakdown.id] ?? 0) > 1 {
            if seenIDs.insert(breakdown.id).inserted {
                duplicateIDs.append(breakdown.id)
            }
        }
        return duplicateIDs
    }

    static func alignmentDiagnosticUnexpectedFamilyIDs(
        in breakdowns: [AlignmentDiagnosticBreakdown]
    ) -> [String] {
        let requiredIDs = Set(requiredAlignmentDiagnosticFamilyIDs)
        var unexpectedIDs: [String] = []
        var seenIDs = Set<String>()
        for breakdown in breakdowns where !requiredIDs.contains(breakdown.id) {
            if seenIDs.insert(breakdown.id).inserted {
                unexpectedIDs.append(breakdown.id)
            }
        }
        return unexpectedIDs
    }
}

struct LatestBracketProjectSummaryProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func summary() throws -> LatestBracketProjectSummary {
        guard let project = try store.latest() else {
            return .empty
        }
        return LatestBracketProjectSummary(project: project)
    }
}

struct BracketProjectSearchQuery: Codable, Equatable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var tokens: [String] {
        rawValue.searchTokenComponents.uniquePreservingOrder()
    }

    var isEmpty: Bool {
        tokens.isEmpty
    }

    func matches(_ project: BracketProject) -> Bool {
        guard !isEmpty else { return true }
        let corpus = project.searchCorpus
            .flatMap(\.searchTokenComponents)
            .uniquePreservingOrder()

        return tokens.allSatisfy { queryToken in
            corpus.contains { corpusToken in
                corpusToken.localizedCaseInsensitiveContains(queryToken)
            }
        }
    }
}

struct BracketProjectSmartCollection: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Equatable, Sendable {
        case reviewable
        case needsReview
        case favorites
        case rawAvailable
        case recoveryIdentifiers
        case generatedNotes
        case exported

        var title: String {
            switch self {
            case .reviewable:
                return "Reviewable"
            case .needsReview:
                return "Needs Review"
            case .favorites:
                return "Favorites"
            case .rawAvailable:
                return "RAW Available"
            case .recoveryIdentifiers:
                return "Recovery IDs"
            case .generatedNotes:
                return "Generated Notes"
            case .exported:
                return "Exported"
            }
        }

        var iconName: String {
            switch self {
            case .reviewable:
                return "checkmark.seal"
            case .needsReview:
                return "exclamationmark.triangle"
            case .favorites:
                return "star"
            case .rawAvailable:
                return "camera.aperture"
            case .recoveryIdentifiers:
                return "key"
            case .generatedNotes:
                return "text.bubble"
            case .exported:
                return "square.and.arrow.up"
            }
        }

        func matches(_ project: BracketProject) -> Bool {
            switch self {
            case .reviewable:
                return project.lifecycle == .reviewable
            case .needsReview:
                return project.lifecycle == .incomplete
                    || project.lifecycle == .failed
                    || project.reviewSnapshot.missingShotCount > 0
                    || project.reviewSnapshot.failedShotCount > 0
            case .favorites:
                return project.isFavorite
            case .rawAvailable:
                return project.reviewSnapshot.rawAvailableCount > 0
            case .recoveryIdentifiers:
                return project.privacy.storesAssetIdentifiers
            case .generatedNotes:
                return project.privacy.containsGeneratedText
            case .exported:
                return project.lifecycle == .exported || !project.exportHistory.isEmpty
            }
        }
    }

    let kind: Kind
    let count: Int
    let exemplarProjectID: String?

    var id: String { kind.rawValue }

    var title: String { kind.title }

    var accessibilityValue: String {
        [
            title,
            "\(count) \(count == 1 ? "project" : "projects")",
            exemplarProjectID.map { "Example \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    static func make(projects: [BracketProject]) -> [BracketProjectSmartCollection] {
        Kind.allCases.compactMap { kind in
            let matchingProjects = projects.filter(kind.matches)
            guard !matchingProjects.isEmpty else { return nil }
            return BracketProjectSmartCollection(
                kind: kind,
                count: matchingProjects.count,
                exemplarProjectID: matchingProjects.first?.id
            )
        }
    }
}

enum BracketProjectLibraryFacetFilter: String, Codable, CaseIterable, Equatable, Sendable {
    case rawAvailable
    case highDynamicRange
    case qualityReady
    case finalOutputBlocked
    case exported

    var title: String {
        switch self {
        case .rawAvailable:
            return "RAW Available"
        case .highDynamicRange:
            return "Dynamic Range"
        case .qualityReady:
            return "Quality Ready"
        case .finalOutputBlocked:
            return "Output Blocked"
        case .exported:
            return "Exported"
        }
    }

    var iconName: String {
        switch self {
        case .rawAvailable:
            return "camera.aperture"
        case .highDynamicRange:
            return "camera.filters"
        case .qualityReady:
            return "checkmark.seal"
        case .finalOutputBlocked:
            return "exclamationmark.triangle"
        case .exported:
            return "square.and.arrow.up"
        }
    }

    func matches(_ project: BracketProject) -> Bool {
        switch self {
        case .rawAvailable:
            return project.reviewSnapshot.rawAvailableCount > 0
        case .highDynamicRange:
            return BracketProjectCaptureQualityReport.make(project: project).evSpread >= 4
        case .qualityReady:
            return BracketProjectCaptureQualityReport.make(project: project).readinessScore >= 85
        case .finalOutputBlocked:
            return BracketProjectFinalOutputManifest.make(
                project: project,
                privacyLevel: .metadataOnly,
                createdAt: project.updatedAt
            ).blockedOutputCount > 0
        case .exported:
            return project.lifecycle == .exported || !project.exportHistory.isEmpty
        }
    }
}

struct BracketProjectLibraryFacet: Codable, Equatable, Identifiable, Sendable {
    let filter: BracketProjectLibraryFacetFilter
    let count: Int
    let exemplarProjectID: String?

    var id: String { filter.rawValue }

    var title: String { filter.title }

    var accessibilityValue: String {
        [
            title,
            "\(count) \(count == 1 ? "project" : "projects")",
            exemplarProjectID.map { "Example \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    static func make(projects: [BracketProject]) -> [BracketProjectLibraryFacet] {
        BracketProjectLibraryFacetFilter.allCases.compactMap { filter in
            let matchingProjects = projects.filter(filter.matches)
            guard !matchingProjects.isEmpty else { return nil }
            return BracketProjectLibraryFacet(
                filter: filter,
                count: matchingProjects.count,
                exemplarProjectID: matchingProjects.first?.id
            )
        }
    }
}

struct BracketProjectLibraryDateFacet: Codable, Equatable, Identifiable, Sendable {
    let day: String
    let count: Int
    let exemplarProjectID: String?

    var id: String { day }

    var title: String { "Captured \(day)" }

    var accessibilityValue: String {
        [
            title,
            "\(count) \(count == 1 ? "project" : "projects")",
            exemplarProjectID.map { "Example \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    static func make(projects: [BracketProject]) -> [BracketProjectLibraryDateFacet] {
        let groupedProjects = Dictionary(grouping: projects) { project in
            day(for: project.manifest.capturedAt)
        }

        return groupedProjects
            .map { day, projects in
                BracketProjectLibraryDateFacet(
                    day: day,
                    count: projects.count,
                    exemplarProjectID: projects.first?.id
                )
            }
            .sorted { lhs, rhs in lhs.day > rhs.day }
    }

    static func normalizedDay(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(10))
    }

    static func matches(_ project: BracketProject, day: String) -> Bool {
        Self.day(for: project.manifest.capturedAt) == day
    }

    static func day(for date: Date) -> String {
        String(ISO8601DateFormatter().string(from: date).prefix(10))
    }
}

struct BracketProjectLibraryLensFacet: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let count: Int
    let exemplarProjectID: String?
    let source: String

    var accessibilityValue: String {
        [
            title,
            "\(count) \(count == 1 ? "project" : "projects")",
            "Source \(source)",
            exemplarProjectID.map { "Example \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    static func make(projects: [BracketProject]) -> [BracketProjectLibraryLensFacet] {
        let groupedProjects = Dictionary(grouping: projects) { project in
            lensIdentity(for: project)?.id
        }

        return groupedProjects.compactMap { id, projects in
            guard let id, let firstProject = projects.first,
                  let identity = lensIdentity(for: firstProject) else {
                return nil
            }
            return BracketProjectLibraryLensFacet(
                id: id,
                title: identity.title,
                count: projects.count,
                exemplarProjectID: firstProject.id,
                source: identity.source
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.title < rhs.title
        }
    }

    static func normalizedLensID(_ value: String?) -> String? {
        let normalized = value?
            .replacingOccurrences(of: "×", with: "x")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let components = normalized.searchTokenComponents
        guard !components.isEmpty else { return nil }
        return components.joined(separator: "-")
    }

    static func matches(_ project: BracketProject, lensID: String) -> Bool {
        guard let expectedID = normalizedLensID(lensID) else { return true }
        return lensIdentity(for: project)?.id == expectedID
    }

    static func lensTitle(for project: BracketProject) -> String? {
        lensIdentity(for: project)?.title
    }

    private static func lensIdentity(for project: BracketProject) -> LensIdentity? {
        if let captureDevice = project.manifest.captureDevice {
            let title = captureDevice.libraryLensTitle
            return normalizedLensID(title).map {
                LensIdentity(id: $0, title: title, source: captureDevice.source)
            }
        }

        return project.manifest.shots
            .compactMap(metadataLensIdentity(shot:))
            .first
    }

    private static func metadataLensIdentity(shot: BracketManifest.Shot) -> LensIdentity? {
        guard shot.metadataStatus == "Metadata available" else { return nil }
        let candidate = shot.metadataDetail
            .components(separatedBy: " / ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { value in
                value.localizedCaseInsensitiveContains("camera")
                    || value.localizedCaseInsensitiveContains("lens")
            }
        guard let candidate else { return nil }
        return normalizedLensID(candidate).map {
            LensIdentity(id: $0, title: candidate, source: "decoded review metadata")
        }
    }

    private struct LensIdentity: Equatable {
        let id: String
        let title: String
        let source: String
    }
}

struct BracketProjectLibraryLocationFacet: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let count: Int
    let exemplarProjectID: String?
    let source: String

    var accessibilityValue: String {
        [
            title,
            "\(count) \(count == 1 ? "project" : "projects")",
            "Source \(source)",
            exemplarProjectID.map { "Example \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    static func make(projects: [BracketProject]) -> [BracketProjectLibraryLocationFacet] {
        let groupedProjects = Dictionary(grouping: projects) { project in
            locationIdentity(for: project).id
        }

        return groupedProjects.compactMap { id, projects in
            guard let firstProject = projects.first else { return nil }
            let identity = locationIdentity(for: firstProject)
            return BracketProjectLibraryLocationFacet(
                id: id,
                title: identity.title,
                count: projects.count,
                exemplarProjectID: firstProject.id,
                source: identity.source
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.title < rhs.title
        }
    }

    static func normalizedLocationPolicyID(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let components = normalized.searchTokenComponents
        guard !components.isEmpty else { return nil }
        return components.joined(separator: "-")
    }

    static func matches(_ project: BracketProject, locationPolicyID: String) -> Bool {
        guard let expectedID = normalizedLocationPolicyID(locationPolicyID) else { return true }
        return locationIdentity(for: project).id == expectedID
    }

    static func locationTitle(for project: BracketProject) -> String {
        locationIdentity(for: project).title
    }

    private static func locationIdentity(for project: BracketProject) -> LocationIdentity {
        if let captureLocation = project.manifest.captureLocation,
           let id = normalizedLocationPolicyID(captureLocation.libraryLocationTitle) {
            return LocationIdentity(
                id: id,
                title: captureLocation.libraryLocationTitle,
                source: captureLocation.source
            )
        }

        let title = project.privacy.storesPreciseLocationCoordinates
            ? "Precise Coordinates Stored"
            : "Project Coordinates Not Stored"
        return LocationIdentity(
            id: normalizedLocationPolicyID(title) ?? "location-policy-unknown",
            title: title,
            source: "legacy project privacy snapshot"
        )
    }

    private struct LocationIdentity: Equatable {
        let id: String
        let title: String
        let source: String
    }
}

struct BracketProjectLibraryFacetSummary: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let projectCount: Int
    let capturedDateRange: String
    let shotCountRange: String
    let evSpreadRange: String
    let sourceCounts: [String: Int]
    let lifecycleCounts: [String: Int]
    let rawProjectCount: Int
    let highDynamicRangeProjectCount: Int
    let qualityReadyProjectCount: Int
    let finalOutputBlockedProjectCount: Int
    let exportedProjectCount: Int
    let lensFacet: String
    let locationFacet: String
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        projectCount: Int,
        capturedDateRange: String,
        shotCountRange: String,
        evSpreadRange: String,
        sourceCounts: [String: Int],
        lifecycleCounts: [String: Int],
        rawProjectCount: Int,
        highDynamicRangeProjectCount: Int,
        qualityReadyProjectCount: Int,
        finalOutputBlockedProjectCount: Int,
        exportedProjectCount: Int,
        lensFacet: String,
        locationFacet: String,
        privacyBoundary: String
    ) {
        self.schemaVersion = schemaVersion
        self.projectCount = projectCount
        self.capturedDateRange = capturedDateRange
        self.shotCountRange = shotCountRange
        self.evSpreadRange = evSpreadRange
        self.sourceCounts = sourceCounts
        self.lifecycleCounts = lifecycleCounts
        self.rawProjectCount = rawProjectCount
        self.highDynamicRangeProjectCount = highDynamicRangeProjectCount
        self.qualityReadyProjectCount = qualityReadyProjectCount
        self.finalOutputBlockedProjectCount = finalOutputBlockedProjectCount
        self.exportedProjectCount = exportedProjectCount
        self.lensFacet = lensFacet
        self.locationFacet = locationFacet
        self.privacyBoundary = privacyBoundary
    }

    init(projects: [BracketProject]) {
        let captureQualityReports = projects.map(BracketProjectCaptureQualityReport.make(project:))
        let finalOutputManifests = projects.map { project in
            BracketProjectFinalOutputManifest.make(
                project: project,
                privacyLevel: .metadataOnly,
                createdAt: project.updatedAt
            )
        }
        let lensFacets = BracketProjectLibraryLensFacet.make(projects: projects)
        let locationFacets = BracketProjectLibraryLocationFacet.make(projects: projects)

        self.init(
            projectCount: projects.count,
            capturedDateRange: Self.dateRangeLabel(projects.map(\.manifest.capturedAt)),
            shotCountRange: Self.intRangeLabel(
                values: projects.map(\.reviewSnapshot.shotCount),
                noun: "shots"
            ),
            evSpreadRange: Self.evSpreadRangeLabel(projects.map(Self.evSpread(project:))),
            sourceCounts: Self.counts(projects.map { $0.manifest.source.rawValue }),
            lifecycleCounts: Self.counts(projects.map { $0.lifecycle.rawValue }),
            rawProjectCount: projects.filter { $0.reviewSnapshot.rawAvailableCount > 0 }.count,
            highDynamicRangeProjectCount: captureQualityReports.filter { $0.evSpread >= 4 }.count,
            qualityReadyProjectCount: captureQualityReports.filter { $0.readinessScore >= 85 }.count,
            finalOutputBlockedProjectCount: finalOutputManifests.filter { $0.blockedOutputCount > 0 }.count,
            exportedProjectCount: projects.filter { $0.lifecycle == .exported || !$0.exportHistory.isEmpty }.count,
            lensFacet: Self.lensFacetLabel(lensFacets),
            locationFacet: Self.locationFacetLabel(locationFacets),
            privacyBoundary: "Metadata-only library facets; no Photos local identifiers, raw photo bytes, thumbnails, precise coordinates, semantic scene labels, or physical optical proof"
        )
    }

    var routeValue: String {
        [
            capturedDateRange,
            shotCountRange,
            evSpreadRange,
            "RAW projects \(rawProjectCount)",
            "Dynamic range candidates \(highDynamicRangeProjectCount)",
            "Quality-ready \(qualityReadyProjectCount)",
            "Output-blocked \(finalOutputBlockedProjectCount)",
            lensFacet,
            locationFacet
        ].joined(separator: " ; ")
    }

    var accessibilityValue: String {
        [
            "Project Library Facets",
            "\(projectCount) \(projectCount == 1 ? "project" : "projects")",
            capturedDateRange,
            "Sources \(Self.countsValue(sourceCounts))",
            "Lifecycles \(Self.countsValue(lifecycleCounts))",
            shotCountRange,
            evSpreadRange,
            "RAW projects \(rawProjectCount)",
            "Dynamic range candidates \(highDynamicRangeProjectCount)",
            "Quality-ready \(qualityReadyProjectCount)",
            "Output-blocked \(finalOutputBlockedProjectCount)",
            "Exported \(exportedProjectCount)",
            lensFacet,
            locationFacet,
            privacyBoundary
        ].joined(separator: " | ")
    }

    private static func counts(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { result, value in
            result[value, default: 0] += 1
        }
    }

    private static func countsValue(_ counts: [String: Int]) -> String {
        guard !counts.isEmpty else { return "none" }
        return counts
            .sorted { lhs, rhs in lhs.key < rhs.key }
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")
    }

    private static func lensFacetLabel(_ lensFacets: [BracketProjectLibraryLensFacet]) -> String {
        guard !lensFacets.isEmpty else { return "Lens metadata unavailable" }
        let value = lensFacets
            .map { "\($0.title) \($0.count)" }
            .joined(separator: ", ")
        return "Lenses \(value)"
    }

    private static func locationFacetLabel(_ locationFacets: [BracketProjectLibraryLocationFacet]) -> String {
        guard !locationFacets.isEmpty else { return "Location policy unavailable" }
        let value = locationFacets
            .map { "\($0.title) \($0.count)" }
            .joined(separator: ", ")
        return "Location policies \(value)"
    }

    private static func dateRangeLabel(_ dates: [Date]) -> String {
        let sortedDates = dates.sorted()
        guard let first = sortedDates.first, let last = sortedDates.last else {
            return "No captures"
        }
        let firstDay = dayLabel(first)
        let lastDay = dayLabel(last)
        if firstDay == lastDay {
            return "Captured \(firstDay)"
        }
        return "Captured \(firstDay) to \(lastDay)"
    }

    private static func dayLabel(_ date: Date) -> String {
        String(ISO8601DateFormatter().string(from: date).prefix(10))
    }

    private static func intRangeLabel(values: [Int], noun: String) -> String {
        let sortedValues = values.sorted()
        guard let first = sortedValues.first, let last = sortedValues.last else {
            return "No \(noun)"
        }
        if first == last {
            return "\(first) \(noun)"
        }
        return "\(first)-\(last) \(noun)"
    }

    private static func evSpreadRangeLabel(_ values: [Float]) -> String {
        let sortedValues = values.sorted()
        guard let first = sortedValues.first, let last = sortedValues.last else {
            return "No EV spread"
        }
        if first == last {
            return "EV spread \(evLabel(first))"
        }
        return "EV spread \(evValue(first))-\(evValue(last)) EV"
    }

    private static func evLabel(_ value: Float) -> String {
        "\(evValue(value)) EV"
    }

    private static func evValue(_ value: Float) -> String {
        let doubleValue = Double(value)
        if doubleValue.rounded() == doubleValue {
            return "\(Int(doubleValue))"
        }
        return String(format: "%.1f", doubleValue)
    }

    private static func evSpread(project: BracketProject) -> Float {
        let offsets = project.manifest.shots.map(\.evOffset)
        return (offsets.max() ?? 0) - (offsets.min() ?? 0)
    }
}

struct BracketProjectLibrarySnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let query: String
    let smartCollectionKind: BracketProjectSmartCollection.Kind?
    let facetFilter: BracketProjectLibraryFacetFilter?
    let capturedDay: String?
    let lensID: String?
    let locationPolicyID: String?
    let projects: [BracketProject]
    let currentProjectID: String?
    let latestProjectID: String?
    let loadFailure: String?

    init(
        schemaVersion: Int = Self.schemaVersion,
        query: String = "",
        smartCollectionKind: BracketProjectSmartCollection.Kind? = nil,
        facetFilter: BracketProjectLibraryFacetFilter? = nil,
        capturedDay: String? = nil,
        lensID: String? = nil,
        locationPolicyID: String? = nil,
        projects: [BracketProject] = [],
        currentProjectID: String? = nil,
        latestProjectID: String? = nil,
        loadFailure: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.query = query
        self.smartCollectionKind = smartCollectionKind
        self.facetFilter = facetFilter
        self.capturedDay = BracketProjectLibraryDateFacet.normalizedDay(capturedDay)
        self.lensID = BracketProjectLibraryLensFacet.normalizedLensID(lensID)
        self.locationPolicyID = BracketProjectLibraryLocationFacet.normalizedLocationPolicyID(locationPolicyID)
        self.projects = projects
        self.currentProjectID = currentProjectID
        self.latestProjectID = latestProjectID
        self.loadFailure = loadFailure
    }

    static let empty = BracketProjectLibrarySnapshot()

    static func failure(_ message: String) -> BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot(loadFailure: message)
    }

    static func make(
        projects: [BracketProject],
        currentProjectID: String?,
        query: String = "",
        smartCollectionKind: BracketProjectSmartCollection.Kind? = nil,
        facetFilter: BracketProjectLibraryFacetFilter? = nil,
        capturedDay: String? = nil,
        lensID: String? = nil,
        locationPolicyID: String? = nil
    ) -> BracketProjectLibrarySnapshot {
        let search = BracketProjectSearchQuery(query)
        let normalizedCapturedDay = BracketProjectLibraryDateFacet.normalizedDay(capturedDay)
        let normalizedLensID = BracketProjectLibraryLensFacet.normalizedLensID(lensID)
        let normalizedLocationPolicyID = BracketProjectLibraryLocationFacet.normalizedLocationPolicyID(locationPolicyID)
        let searchedProjects = projects.filter(search.matches)
        let collectionProjects = smartCollectionKind.map { kind in
            searchedProjects.filter(kind.matches)
        } ?? searchedProjects
        let facetProjects = facetFilter.map { filter in
            collectionProjects.filter(filter.matches)
        } ?? collectionProjects
        let filteredProjects = normalizedCapturedDay.map { day in
            facetProjects.filter { BracketProjectLibraryDateFacet.matches($0, day: day) }
        } ?? facetProjects
        let lensProjects = normalizedLensID.map { lensID in
            filteredProjects.filter { BracketProjectLibraryLensFacet.matches($0, lensID: lensID) }
        } ?? filteredProjects
        let locationProjects = normalizedLocationPolicyID.map { locationPolicyID in
            lensProjects.filter {
                BracketProjectLibraryLocationFacet.matches($0, locationPolicyID: locationPolicyID)
            }
        } ?? lensProjects
        return BracketProjectLibrarySnapshot(
            query: search.rawValue,
            smartCollectionKind: smartCollectionKind,
            facetFilter: facetFilter,
            capturedDay: normalizedCapturedDay,
            lensID: normalizedLensID,
            locationPolicyID: normalizedLocationPolicyID,
            projects: locationProjects,
            currentProjectID: currentProjectID,
            latestProjectID: projects.first?.id
        )
    }

    var isFiltered: Bool {
        !BracketProjectSearchQuery(query).isEmpty
            || smartCollectionKind != nil
            || facetFilter != nil
            || capturedDay != nil
            || lensID != nil
            || locationPolicyID != nil
    }

    var resultCount: Int {
        projects.count
    }

    var latestProject: BracketProject? {
        projects.first { $0.id == latestProjectID } ?? projects.first
    }

    var smartCollections: [BracketProjectSmartCollection] {
        BracketProjectSmartCollection.make(projects: projects)
    }

    var smartCollectionsAccessibilityValue: String {
        let collectionValue = smartCollections
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        guard !collectionValue.isEmpty else {
            return "Smart Collections | No matching collections"
        }
        return "Smart Collections | \(collectionValue)"
    }

    var facetFilters: [BracketProjectLibraryFacet] {
        BracketProjectLibraryFacet.make(projects: projects)
    }

    var facetFiltersAccessibilityValue: String {
        let facetValue = facetFilters
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        guard !facetValue.isEmpty else {
            return "Selectable Facets | No matching facets"
        }
        return "Selectable Facets | \(facetValue)"
    }

    var dateFacets: [BracketProjectLibraryDateFacet] {
        BracketProjectLibraryDateFacet.make(projects: projects)
    }

    var dateFacetsAccessibilityValue: String {
        let dateValue = dateFacets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        guard !dateValue.isEmpty else {
            return "Captured Date Facets | No captured dates"
        }
        return "Captured Date Facets | \(dateValue)"
    }

    var lensFacets: [BracketProjectLibraryLensFacet] {
        BracketProjectLibraryLensFacet.make(projects: projects)
    }

    var lensFacetsAccessibilityValue: String {
        let lensValue = lensFacets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        guard !lensValue.isEmpty else {
            return "Lens Facets | No persisted lens metadata"
        }
        return "Lens Facets | \(lensValue)"
    }

    var locationFacets: [BracketProjectLibraryLocationFacet] {
        BracketProjectLibraryLocationFacet.make(projects: projects)
    }

    var locationFacetsAccessibilityValue: String {
        let locationValue = locationFacets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        guard !locationValue.isEmpty else {
            return "Location Policy Facets | No location policy metadata"
        }
        return "Location Policy Facets | \(locationValue)"
    }

    var facetSummary: BracketProjectLibraryFacetSummary {
        BracketProjectLibraryFacetSummary(projects: projects)
    }

    var accessibilityValue: String {
        if let loadFailure {
            return "Project Library | Load failed | \(loadFailure)"
        }

        var parts = [
            "Project Library",
            "\(resultCount) \(resultCount == 1 ? "project" : "projects")"
        ]
        if !BracketProjectSearchQuery(query).isEmpty {
            parts.append("Query \(query)")
        }
        if let smartCollectionKind {
            parts.append("Collection \(smartCollectionKind.title)")
        }
        if let facetFilter {
            parts.append("Facet \(facetFilter.title)")
        }
        if let capturedDay {
            parts.append("Captured Day \(capturedDay)")
        }
        if let lensID {
            parts.append("Lens \(lensID)")
        }
        if let locationPolicyID {
            parts.append("Location Policy \(locationPolicyID)")
        }
        if let latestProject {
            parts.append("Latest: \(latestProject.displayTitle)")
        } else {
            parts.append("No saved projects")
        }
        if let currentProjectID {
            parts.append("Current: \(currentProjectID)")
        }
        return parts.joined(separator: " | ")
    }
}

struct BracketerPrivacyTrustSnapshot: Codable, Equatable, Sendable {
    struct Row: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let value: String

        var accessibilityValue: String {
            "\(title) | \(value)"
        }
    }

    static let schemaVersion = 2

    let schemaVersion: Int
    let projectCount: Int
    let latestProjectID: String?
    let latestProjectTitle: String?
    let storesGeneratedProjectNotes: Bool
    let localComputationPolicy: String
    let photosAccessPolicy: String
    let locationPolicy: String
    let appleIntelligencePolicy: String
    let generatedContentPolicy: String
    let diagnosticsPolicy: String
    let exportPolicy: String
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        projectCount: Int,
        latestProjectID: String?,
        latestProjectTitle: String?,
        storesGeneratedProjectNotes: Bool,
        localComputationPolicy: String,
        photosAccessPolicy: String,
        locationPolicy: String,
        appleIntelligencePolicy: String,
        generatedContentPolicy: String,
        diagnosticsPolicy: String,
        exportPolicy: String,
        privacyBoundary: String
    ) {
        self.schemaVersion = schemaVersion
        self.projectCount = projectCount
        self.latestProjectID = latestProjectID
        self.latestProjectTitle = latestProjectTitle
        self.storesGeneratedProjectNotes = storesGeneratedProjectNotes
        self.localComputationPolicy = localComputationPolicy
        self.photosAccessPolicy = photosAccessPolicy
        self.locationPolicy = locationPolicy
        self.appleIntelligencePolicy = appleIntelligencePolicy
        self.generatedContentPolicy = generatedContentPolicy
        self.diagnosticsPolicy = diagnosticsPolicy
        self.exportPolicy = exportPolicy
        self.privacyBoundary = privacyBoundary
    }

    static func make(
        projectLibrary: BracketProjectLibrarySnapshot,
        intelligenceAvailability: IntelligenceFeatureAvailability,
        captureCoachRun: CaptureCoachRun,
        bracketRecipeRun: BracketRecipeRun,
        storesGeneratedProjectNotes: Bool,
        diagnosticsReport: String
    ) -> BracketerPrivacyTrustSnapshot {
        let runtimeDiagnostic = IntelligenceRuntimeDiagnostic(
            availability: intelligenceAvailability,
            captureCoachRun: captureCoachRun,
            bracketRecipeRun: bracketRecipeRun
        )
        let latestProject = projectLibrary.latestProject
        let latestTitle = latestProject?.displayTitle

        return BracketerPrivacyTrustSnapshot(
            projectCount: projectLibrary.projects.count,
            latestProjectID: latestProject?.id,
            latestProjectTitle: latestTitle,
            storesGeneratedProjectNotes: storesGeneratedProjectNotes,
            localComputationPolicy: localComputationPolicy(
                projectCount: projectLibrary.projects.count,
                latestTitle: latestTitle
            ),
            photosAccessPolicy: photosAccessPolicy(for: latestProject),
            locationPolicy: locationPolicy(for: latestProject),
            appleIntelligencePolicy: appleIntelligencePolicy(
                availability: intelligenceAvailability,
                runtimeDiagnostic: runtimeDiagnostic,
                captureCoachRun: captureCoachRun,
                bracketRecipeRun: bracketRecipeRun
            ),
            generatedContentPolicy: generatedContentPolicy(
                for: latestProject,
                storesGeneratedProjectNotes: storesGeneratedProjectNotes
            ),
            diagnosticsPolicy: diagnosticsPolicy(for: diagnosticsReport),
            exportPolicy: exportPolicy(for: latestProject),
            privacyBoundary: "Privacy Trust Center uses persisted manifest/project metadata, runtime availability state, generated-note provenance, and diagnostics text only; it does not inspect raw pixels, Photos resources, thumbnails, or precise location coordinates."
        )
    }

    var rows: [Row] {
        [
            Row(id: "localComputation", title: "Local Computation", value: localComputationPolicy),
            Row(id: "photosAccess", title: "Photos Access", value: photosAccessPolicy),
            Row(id: "locationPolicy", title: "Location Policy", value: locationPolicy),
            Row(id: "appleIntelligence", title: "Apple Intelligence", value: appleIntelligencePolicy),
            Row(id: "generatedContent", title: "Generated Content", value: generatedContentPolicy),
            Row(id: "diagnostics", title: "Diagnostics", value: diagnosticsPolicy),
            Row(id: "exportBoundary", title: "Export Boundary", value: exportPolicy),
        ]
    }

    var accessibilityValue: String {
        var parts = [
            "Privacy Trust Center",
            "\(projectCount) \(projectCount == 1 ? "saved project" : "saved projects")"
        ]
        if let latestProjectTitle {
            parts.append("Latest \(latestProjectTitle)")
        } else {
            parts.append("No saved project")
        }
        parts.append(contentsOf: rows.map(\.accessibilityValue))
        parts.append(privacyBoundary)
        return parts.joined(separator: " | ")
    }

    private static func localComputationPolicy(projectCount: Int, latestTitle: String?) -> String {
        let base = "Library, review, search, curation, diagnostics, and export planning are computed locally from \(projectCount) \(projectCount == 1 ? "saved project" : "saved projects")."
        guard let latestTitle else {
            return "\(base) No latest project is selected."
        }
        return "\(base) Latest project: \(latestTitle)."
    }

    private static func photosAccessPolicy(for project: BracketProject?) -> String {
        guard let project else {
            return "No saved project has Photos local identifiers in this snapshot; raw photo bytes are not stored."
        }
        if project.privacy.storesAssetIdentifiers {
            return "Photos local identifiers are scoped for recovery inside project records; metadata-only exports redact identifiers by default."
        }
        return "No Photos local identifiers are stored in the latest project; raw photo bytes are not stored."
    }

    private static func locationPolicy(for project: BracketProject?) -> String {
        guard let project else {
            return "No saved project has location policy metadata yet; precise coordinates are not stored by project records."
        }
        guard let captureLocation = project.manifest.captureLocation else {
            return project.privacy.storesPreciseLocationCoordinates
                ? "Legacy project privacy snapshot reports precise coordinates stored; review before export."
                : "Legacy project privacy snapshot reports no precise coordinates."
        }

        return [
            captureLocation.libraryLocationTitle,
            captureLocation.projectStoragePolicy,
            captureLocation.photosWritePolicy,
            captureLocation.preciseCoordinatesStored ? "Precise coordinates stored." : "No precise coordinates.",
            captureLocation.locationSampleObserved ? "Location sample observed." : "No location sample observed."
        ].joined(separator: " ")
    }

    private static func appleIntelligencePolicy(
        availability: IntelligenceFeatureAvailability,
        runtimeDiagnostic: IntelligenceRuntimeDiagnostic,
        captureCoachRun: CaptureCoachRun,
        bracketRecipeRun: BracketRecipeRun
    ) -> String {
        var parts = [
            "Availability: \(availability.statusTitle).",
            runtimeDiagnostic.sourceSummary + ".",
            runtimeDiagnostic.title + "."
        ]
        if let coachFallback = captureCoachRun.fallbackReason {
            parts.append("Coach fallback: \(coachFallback).")
        }
        if let recipeFallback = bracketRecipeRun.fallbackReason {
            parts.append("Recipe fallback: \(recipeFallback).")
        }
        return parts.joined(separator: " ")
    }

    private static func generatedContentPolicy(
        for project: BracketProject?,
        storesGeneratedProjectNotes: Bool
    ) -> String {
        let storagePrefix = storesGeneratedProjectNotes
            ? "Generated project-note storage is On."
            : "Generated project-note storage is Off."
        guard let project else {
            return "\(storagePrefix) No saved project exists yet; in-session generated review cards remain source-disclosed."
        }
        guard let generatedNote = project.sidecar?.generatedNote else {
            if storesGeneratedProjectNotes {
                return "\(storagePrefix) Latest project has no generated note yet; generated copy is source-disclosed before use."
            }
            return "\(storagePrefix) Latest project sidecar omits generated notes by preference; in-session review cards remain available."
        }

        let modelState = generatedNote.usedAppleIntelligence ? "Apple Intelligence" : "deterministic"
        var parts = [
            storagePrefix,
            "Latest project stores generated note \"\(generatedNote.title)\" from \(generatedNote.source) using \(modelState) output.",
            generatedNote.disclosure
        ]
        if let fallbackReason = generatedNote.fallbackReason {
            parts.append("Fallback: \(fallbackReason).")
        }
        return parts.joined(separator: " ")
    }

    private static func diagnosticsPolicy(for report: String) -> String {
        let lineCount = report
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline)
            .count
        guard lineCount > 0 else {
            return "Diagnostics export is text-only and local; no diagnostics report has been produced."
        }
        return "Diagnostics export is text-only and local; \(lineCount) report lines are available from About without raw photo bytes or precise coordinates."
    }

    private static func exportPolicy(for project: BracketProject?) -> String {
        guard project != nil else {
            return "Metadata-only export remains the default; no project archive is available until a bracket is saved."
        }
        return "Default metadata-only exports redact Photos local identifiers, export project identifiers, group identifiers, raw photo bytes, and precise coordinates; recovery identifiers require explicit privacy level selection."
    }
}

struct BracketerReducedMotionContract: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let honorsSystemReduceMotion: Bool
    let disablesCameraChromeSprings: Bool
    let disablesSettingsSheetSprings: Bool
    let disablesSettingsPreviewSprings: Bool
    let preservesCaptureTimingAndHaptics: Bool

    init(
        schemaVersion: Int = Self.schemaVersion,
        honorsSystemReduceMotion: Bool,
        disablesCameraChromeSprings: Bool,
        disablesSettingsSheetSprings: Bool,
        disablesSettingsPreviewSprings: Bool,
        preservesCaptureTimingAndHaptics: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.honorsSystemReduceMotion = honorsSystemReduceMotion
        self.disablesCameraChromeSprings = disablesCameraChromeSprings
        self.disablesSettingsSheetSprings = disablesSettingsSheetSprings
        self.disablesSettingsPreviewSprings = disablesSettingsPreviewSprings
        self.preservesCaptureTimingAndHaptics = preservesCaptureTimingAndHaptics
    }

    static let implemented = BracketerReducedMotionContract(
        honorsSystemReduceMotion: true,
        disablesCameraChromeSprings: true,
        disablesSettingsSheetSprings: true,
        disablesSettingsPreviewSprings: true,
        preservesCaptureTimingAndHaptics: true
    )

    var isVerified: Bool {
        honorsSystemReduceMotion
            && disablesCameraChromeSprings
            && disablesSettingsSheetSprings
            && disablesSettingsPreviewSprings
            && preservesCaptureTimingAndHaptics
    }

    var auditDetail: String {
        if isVerified {
            return "Main camera chrome, Settings sheet presentation/dismissal, toast transitions, app-intent panel routing, and Settings grid preview springs use system Reduce Motion to collapse spring/move animations to opacity or no animation while preserving capture timing and tactile camera feedback."
        }

        return "Reduce Motion policy is incomplete; camera chrome, Settings sheet motion, Settings preview springs, and capture timing preservation must all be wired before this row can be verified."
    }

    var accessibilityValue: String {
        [
            "Reduced Motion Contract",
            "schema v\(schemaVersion)",
            honorsSystemReduceMotion ? "honors system Reduce Motion" : "does not honor system Reduce Motion",
            disablesCameraChromeSprings ? "camera chrome springs disabled" : "camera chrome springs pending",
            disablesSettingsSheetSprings ? "Settings sheet springs disabled" : "Settings sheet springs pending",
            disablesSettingsPreviewSprings ? "Settings preview springs disabled" : "Settings preview springs pending",
            preservesCaptureTimingAndHaptics ? "capture timing and haptics preserved" : "capture timing or haptics changed",
        ].joined(separator: " | ")
    }
}

struct BracketerDynamicTypeContract: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let honorsSystemDynamicType: Bool
    let usesSemanticAuditTypography: Bool
    let allowsAuditRowsToWrapVertically: Bool
    let stacksAuditRowsAtAccessibilitySizes: Bool
    let preservesStableAuditIdentifiersAndValues: Bool
    let uiTestForcesAccessibilitySizeAtAppRoot: Bool

    init(
        schemaVersion: Int = Self.schemaVersion,
        honorsSystemDynamicType: Bool,
        usesSemanticAuditTypography: Bool,
        allowsAuditRowsToWrapVertically: Bool,
        stacksAuditRowsAtAccessibilitySizes: Bool,
        preservesStableAuditIdentifiersAndValues: Bool,
        uiTestForcesAccessibilitySizeAtAppRoot: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.honorsSystemDynamicType = honorsSystemDynamicType
        self.usesSemanticAuditTypography = usesSemanticAuditTypography
        self.allowsAuditRowsToWrapVertically = allowsAuditRowsToWrapVertically
        self.stacksAuditRowsAtAccessibilitySizes = stacksAuditRowsAtAccessibilitySizes
        self.preservesStableAuditIdentifiersAndValues = preservesStableAuditIdentifiersAndValues
        self.uiTestForcesAccessibilitySizeAtAppRoot = uiTestForcesAccessibilitySizeAtAppRoot
    }

    static let implemented = BracketerDynamicTypeContract(
        honorsSystemDynamicType: true,
        usesSemanticAuditTypography: true,
        allowsAuditRowsToWrapVertically: true,
        stacksAuditRowsAtAccessibilitySizes: true,
        preservesStableAuditIdentifiersAndValues: true,
        uiTestForcesAccessibilitySizeAtAppRoot: true
    )

    var isVerified: Bool {
        honorsSystemDynamicType
            && usesSemanticAuditTypography
            && allowsAuditRowsToWrapVertically
            && stacksAuditRowsAtAccessibilitySizes
            && preservesStableAuditIdentifiersAndValues
            && uiTestForcesAccessibilitySizeAtAppRoot
    }

    func auditDetail(observedLabel: String?) -> String {
        if isVerified {
            let observedSuffix = observedLabel.map { " Observed Dynamic Type: \($0)." } ?? ""
            return "Settings > About accessibility audit rows honor the SwiftUI Dynamic Type environment, use semantic text styles for the row title/detail, stack status icon/text above detail at accessibility sizes, allow vertical wrapping for dense details, keep stable accessibility identifiers and values, and have a UI-test path that forces Accessibility 3 at the app root.\(observedSuffix) App-wide screenshot layout proof remains a separate follow-up."
        }

        return "Dynamic Type policy is incomplete; the audit needs semantic text styles, stacked accessibility-size rows, vertical wrapping, stable identifiers/values, and an app-root accessibility-size UI proof before this row can be verified."
    }

    var accessibilityValue: String {
        [
            "Dynamic Type Contract",
            "schema v\(schemaVersion)",
            honorsSystemDynamicType ? "honors SwiftUI Dynamic Type" : "does not honor SwiftUI Dynamic Type",
            usesSemanticAuditTypography ? "semantic audit typography" : "fixed audit typography pending",
            allowsAuditRowsToWrapVertically ? "audit rows wrap vertically" : "audit row wrapping pending",
            stacksAuditRowsAtAccessibilitySizes ? "audit rows stack at accessibility sizes" : "audit row stacking pending",
            preservesStableAuditIdentifiersAndValues ? "stable audit identifiers and values preserved" : "audit accessibility stability pending",
            uiTestForcesAccessibilitySizeAtAppRoot ? "UI tests force Accessibility 3 at app root" : "app-root Dynamic Type UI-test path pending",
        ].joined(separator: " | ")
    }
}

struct BracketerHighContrastContract: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let honorsSystemIncreasedContrast: Bool
    let pairsStatusColorWithIconAndText: Bool
    let strengthensAuditRowBorders: Bool
    let preservesStableAccessibilityValues: Bool

    init(
        schemaVersion: Int = Self.schemaVersion,
        honorsSystemIncreasedContrast: Bool,
        pairsStatusColorWithIconAndText: Bool,
        strengthensAuditRowBorders: Bool,
        preservesStableAccessibilityValues: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.honorsSystemIncreasedContrast = honorsSystemIncreasedContrast
        self.pairsStatusColorWithIconAndText = pairsStatusColorWithIconAndText
        self.strengthensAuditRowBorders = strengthensAuditRowBorders
        self.preservesStableAccessibilityValues = preservesStableAccessibilityValues
    }

    static let implemented = BracketerHighContrastContract(
        honorsSystemIncreasedContrast: true,
        pairsStatusColorWithIconAndText: true,
        strengthensAuditRowBorders: true,
        preservesStableAccessibilityValues: true
    )

    var isVerified: Bool {
        honorsSystemIncreasedContrast
            && pairsStatusColorWithIconAndText
            && strengthensAuditRowBorders
            && preservesStableAccessibilityValues
    }

    var auditDetail: String {
        if isVerified {
            return "Accessibility audit rows pair every status color with an icon, status text, and stable accessibility value, and system Increased Contrast strengthens row borders for the Settings > About audit surface."
        }

        return "High Contrast policy is incomplete; status rows must pair color with icon/text, preserve accessibility values, and strengthen visible row boundaries when Increased Contrast is enabled."
    }

    var accessibilityValue: String {
        [
            "High Contrast Contract",
            "schema v\(schemaVersion)",
            honorsSystemIncreasedContrast ? "honors system Increased Contrast" : "does not honor system Increased Contrast",
            pairsStatusColorWithIconAndText ? "color paired with icon and text" : "color-only status pending",
            strengthensAuditRowBorders ? "audit row borders strengthened" : "audit row borders pending",
            preservesStableAccessibilityValues ? "stable accessibility values preserved" : "accessibility values pending",
        ].joined(separator: " | ")
    }
}

struct BracketerTapTargetContract: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let minimumTapTargetPoints: Int
    let compactAppleIntelligenceButtonPoints: Int
    let cameraChromeButtonPoints: Int
    let compactProControlsTopButtonPoints: Int
    let settingsCloseButtonPoints: Int

    init(
        schemaVersion: Int = Self.schemaVersion,
        minimumTapTargetPoints: Int = 44,
        compactAppleIntelligenceButtonPoints: Int,
        cameraChromeButtonPoints: Int,
        compactProControlsTopButtonPoints: Int,
        settingsCloseButtonPoints: Int
    ) {
        self.schemaVersion = schemaVersion
        self.minimumTapTargetPoints = minimumTapTargetPoints
        self.compactAppleIntelligenceButtonPoints = compactAppleIntelligenceButtonPoints
        self.cameraChromeButtonPoints = cameraChromeButtonPoints
        self.compactProControlsTopButtonPoints = compactProControlsTopButtonPoints
        self.settingsCloseButtonPoints = settingsCloseButtonPoints
    }

    static func implemented(
        compactAppleIntelligenceButtonPoints: Int = 44
    ) -> BracketerTapTargetContract {
        BracketerTapTargetContract(
            compactAppleIntelligenceButtonPoints: compactAppleIntelligenceButtonPoints,
            cameraChromeButtonPoints: 44,
            compactProControlsTopButtonPoints: 44,
            settingsCloseButtonPoints: 44
        )
    }

    var isVerified: Bool {
        [
            compactAppleIntelligenceButtonPoints,
            cameraChromeButtonPoints,
            compactProControlsTopButtonPoints,
            settingsCloseButtonPoints,
        ].allSatisfy { $0 >= minimumTapTargetPoints }
    }

    var auditDetail: String {
        if isVerified {
            return "Minimum tap target \(minimumTapTargetPoints) pt is met for compact Apple Intelligence refresh/recipe controls, camera chrome buttons, Compact PRO top-bar button, and Settings close button."
        }

        return "Tap target policy is incomplete; compact Apple Intelligence controls, camera chrome buttons, Compact PRO top-bar button, and Settings close button must all meet the \(minimumTapTargetPoints) pt minimum."
    }

    var accessibilityValue: String {
        [
            "Tap Target Contract",
            "schema v\(schemaVersion)",
            "Minimum \(minimumTapTargetPoints) pt",
            "Apple Intelligence controls \(compactAppleIntelligenceButtonPoints) pt",
            "Camera chrome buttons \(cameraChromeButtonPoints) pt",
            "Compact PRO top-bar button \(compactProControlsTopButtonPoints) pt",
            "Settings close button \(settingsCloseButtonPoints) pt",
        ].joined(separator: " | ")
    }
}

struct BracketerAccessibilityScreenshotMatrix: Codable, Equatable, Sendable {
    struct Surface: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let rootAccessibilityIdentifier: String
        let screenshotAttachmentName: String
        let requiredAccessibilityIdentifiers: [String]

        var accessibilityValue: String {
            [
                title,
                "Root: \(rootAccessibilityIdentifier)",
                "Screenshot: \(screenshotAttachmentName)",
                "Required identifiers: \(requiredAccessibilityIdentifiers.joined(separator: ", "))",
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let environmentEvidence: BracketerAccessibilityAudit.EnvironmentEvidence
    let surfaces: [Surface]
    let proofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        environmentEvidence: BracketerAccessibilityAudit.EnvironmentEvidence,
        surfaces: [Surface],
        proofBoundary: String = "Accessibility Screenshot Matrix is simulator UI screenshot evidence for app-root Accessibility 3 Dynamic Type, UI-test reduce-motion routing, forced audit-row contrast styling, and accessibility environment reporting; it does not prove physical-device accessibility, VoiceOver hardware behavior, raw photo bytes, Photos identifiers, final rendered output bytes, or precise coordinates."
    ) {
        self.schemaVersion = schemaVersion
        self.environmentEvidence = environmentEvidence
        self.surfaces = surfaces
        self.proofBoundary = proofBoundary
    }

    static func accessibilityHeavy(
        environmentEvidence: BracketerAccessibilityAudit.EnvironmentEvidence
    ) -> BracketerAccessibilityScreenshotMatrix {
        BracketerAccessibilityScreenshotMatrix(
            environmentEvidence: environmentEvidence,
            surfaces: [
                Surface(
                    id: "cameraCockpit",
                    title: "Camera Cockpit",
                    rootAccessibilityIdentifier: "camera.chromeLayout",
                    screenshotAttachmentName: "Accessibility Matrix - Camera Cockpit - Accessibility 3",
                    requiredAccessibilityIdentifiers: [
                        "camera.chromeLayout",
                        "camera.topBar",
                        "camera.bottomControls",
                        "camera.captureCoach.card",
                        "camera.bracketPlan.strip",
                        "camera.shutterButton",
                        "camera.settingsButton",
                    ]
                ),
                Surface(
                    id: "settingsAbout",
                    title: "Settings About Accessibility Audit",
                    rootAccessibilityIdentifier: "settings.accessibility.audit",
                    screenshotAttachmentName: "Accessibility Matrix - Settings About - Accessibility 3",
                    requiredAccessibilityIdentifiers: [
                        "settings.accessibility.environment",
                        "settings.accessibility.audit",
                        "settings.accessibility.screenshotMatrix",
                        "settings.accessibility.audit.row.dynamicType",
                        "settings.accessibility.audit.row.highContrast",
                    ]
                ),
                Surface(
                    id: "projectReview",
                    title: "Project Review Handoff",
                    rootAccessibilityIdentifier: "review.project.accessibility",
                    screenshotAttachmentName: "Accessibility Matrix - Project Review - Accessibility 3",
                    requiredAccessibilityIdentifiers: [
                        "review.project.accessibility",
                        "review.project.voiceOverTraversal",
                        "review.project.finalWorkspace.fixture",
                        "review.project.tapTargetAudit",
                        "review.project.selectedShot",
                        "review.project.bestBaseFrame",
                        "review.project.bestBaseFrame.card",
                        "review.project.beforeAfterScrub",
                        "review.project.beforeAfterScrub.card",
                        "review.project.perShotExposure",
                        "review.project.perShotExposure.card",
                        "review.project.focusEdge",
                        "review.project.focusEdge.card",
                        "review.project.motionAlignment",
                        "review.project.motionAlignment.card",
                        "review.project.motionMetadata",
                        "review.project.motionMetadata.card",
                        "review.project.featureMatch",
                        "review.project.featureMatch.card",
                        "review.project.alignmentTransform",
                        "review.project.alignmentTransform.card",
                        "review.project.motionBlur",
                        "review.project.motionBlur.card",
                        "review.project.ghostingRisk",
                        "review.project.ghostingRisk.card",
                        "review.project.movingRegionMask",
                        "review.project.movingRegionMask.card",
                        "review.project.alignmentPerformance",
                        "review.project.alignmentPerformance.card",
                        "review.project.alignmentExplanation",
                        "review.project.alignmentExplanation.card",
                        "review.project.qualityReport",
                        "review.project.qualityReport.card",
                        "review.project.finalOutputs",
                        "review.project.finalOutputReadinessAudit",
                        "review.project.assetResources",
                        "review.project.imageBundle",
                        "review.project.mergeReadiness",
                        "review.project.previousShotButton",
                        "review.project.nextShotButton",
                        "review.project.representationToggle",
                        "review.project.closeButton",
                    ]
                ),
            ]
        )
    }

    var isComplete: Bool {
        schemaVersion == Self.schemaVersion
            && surfaces.map(\.id) == ["cameraCockpit", "settingsAbout", "projectReview"]
            && surfaces.allSatisfy { !$0.requiredAccessibilityIdentifiers.isEmpty }
            && environmentEvidence.dynamicTypeIsAccessibilitySize
            && environmentEvidence.reduceMotionEnabled
            && environmentEvidence.highContrastEnabled
    }

    var screenshotAttachmentNames: [String] {
        surfaces.map(\.screenshotAttachmentName)
    }

    var accessibilityValue: String {
        [
            "Accessibility Screenshot Matrix",
            "schema v\(schemaVersion)",
            isComplete ? "Complete" : "Incomplete",
            environmentEvidence.accessibilityValue,
            "Surfaces: \(surfaces.map(\.title).joined(separator: ", "))",
            "Screenshots: \(screenshotAttachmentNames.joined(separator: ", "))",
            proofBoundary,
        ].joined(separator: " | ")
    }
}

struct BracketerAccessibilityAudit: Codable, Equatable, Sendable {
    enum Status: String, Codable, Equatable, Sendable {
        case observed
        case verified
        case followUpRequired

        var title: String {
            switch self {
            case .observed:
                return "Observed"
            case .verified:
                return "Verified"
            case .followUpRequired:
                return "Follow-up required"
            }
        }
    }

    struct Row: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let status: Status
        let detail: String

        var accessibilityValue: String {
            "\(title) | \(status.title) | \(detail)"
        }
    }

    struct EnvironmentEvidence: Codable, Equatable, Sendable {
        let source: String
        let dynamicTypeLabel: String
        let dynamicTypeIsAccessibilitySize: Bool
        let reduceMotionEnabled: Bool
        let highContrastEnabled: Bool

        var accessibilityValue: String {
            [
                "Accessibility Environment",
                "Source: \(source)",
                "Dynamic Type: \(dynamicTypeLabel)",
                "Accessibility dynamic type: \(dynamicTypeIsAccessibilitySize ? "Yes" : "No")",
                "Reduce Motion: \(reduceMotionEnabled ? "On" : "Off")",
                "High Contrast: \(highContrastEnabled ? "Increased" : "Standard")",
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let minimumTapTargetPoints: Int
    let environmentEvidence: EnvironmentEvidence?
    let rows: [Row]
    let proofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        minimumTapTargetPoints: Int = 44,
        environmentEvidence: EnvironmentEvidence? = nil,
        rows: [Row],
        proofBoundary: String = "Inclusive Design Audit is app metadata and simulator UI evidence only; it does not prove physical-device accessibility, VoiceOver hardware behavior, raw photo bytes, Photos identifiers, final rendered output bytes, or precise coordinates."
    ) {
        self.schemaVersion = schemaVersion
        self.minimumTapTargetPoints = minimumTapTargetPoints
        self.environmentEvidence = environmentEvidence
        self.rows = rows
        self.proofBoundary = proofBoundary
    }

    static func make(
        intelligenceIconButtonPoints: Int = 44,
        environmentEvidence: EnvironmentEvidence? = nil,
        dynamicTypeContract: BracketerDynamicTypeContract = .implemented,
        reducedMotionContract: BracketerReducedMotionContract = .implemented,
        highContrastContract: BracketerHighContrastContract = .implemented
    ) -> BracketerAccessibilityAudit {
        let tapTargetContract = BracketerTapTargetContract.implemented(
            compactAppleIntelligenceButtonPoints: intelligenceIconButtonPoints
        )
        let tapTargetStatus: Status = tapTargetContract.isVerified ? .verified : .followUpRequired
        let dynamicTypeObserved = environmentEvidence?.dynamicTypeIsAccessibilitySize == true
        let dynamicTypeStatus: Status
        if dynamicTypeObserved && dynamicTypeContract.isVerified {
            dynamicTypeStatus = .verified
        } else if dynamicTypeObserved {
            dynamicTypeStatus = .observed
        } else {
            dynamicTypeStatus = .followUpRequired
        }
        let reducedMotionObserved = environmentEvidence?.reduceMotionEnabled == true
        let reducedMotionStatus: Status
        let reducedMotionDetail: String
        if reducedMotionContract.isVerified {
            reducedMotionStatus = .verified
            reducedMotionDetail = reducedMotionContract.auditDetail
        } else if reducedMotionObserved {
            reducedMotionStatus = .observed
            reducedMotionDetail = "Reduce Motion is enabled in the observed environment; animation and haptic policy still need per-surface gating proof."
        } else {
            reducedMotionStatus = .followUpRequired
            reducedMotionDetail = "Camera and settings motion remain usable in simulator tests, but reduce-motion-specific animation and haptic gating still need a dedicated pass."
        }
        let highContrastObserved = environmentEvidence?.highContrastEnabled == true
        let resolvedHighContrastStatus: Status
        let highContrastDetail: String
        if highContrastContract.isVerified {
            resolvedHighContrastStatus = .verified
            highContrastDetail = highContrastContract.auditDetail
        } else if highContrastObserved {
            resolvedHighContrastStatus = .observed
            highContrastDetail = "Increased contrast is enabled in the observed environment; critical rows pair color with text, icons, and accessibility values, but screenshot proof is still required."
        } else {
            resolvedHighContrastStatus = .followUpRequired
            highContrastDetail = "Critical rows pair color with text, icons, and accessibility values, but high-contrast visual proof is still required."
        }
        return BracketerAccessibilityAudit(
            environmentEvidence: environmentEvidence,
            rows: [
                Row(
                    id: "dynamicType",
                    title: "Dynamic Type",
                    status: dynamicTypeStatus,
                    detail: dynamicTypeContract.auditDetail(observedLabel: environmentEvidence?.dynamicTypeLabel)
                ),
                Row(
                    id: "reducedMotion",
                    title: "Reduced Motion",
                    status: reducedMotionStatus,
                    detail: reducedMotionDetail
                ),
                Row(
                    id: "highContrast",
                    title: "High Contrast",
                    status: resolvedHighContrastStatus,
                    detail: highContrastDetail
                ),
                Row(
                    id: "tapTargets",
                    title: "Tap Targets",
                    status: tapTargetStatus,
                    detail: tapTargetContract.auditDetail
                )
            ]
        )
    }

    var verifiedCount: Int {
        rows.filter { $0.status == .verified }.count
    }

    var observedCount: Int {
        rows.filter { $0.status == .observed }.count
    }

    var followUpCount: Int {
        rows.filter { $0.status == .followUpRequired }.count
    }

    var accessibilityValue: String {
        let base = [
            "Inclusive Design Audit",
            "schema v\(schemaVersion)",
            "Minimum tap target \(minimumTapTargetPoints) pt",
            "\(verifiedCount) verified",
            "\(observedCount) observed",
            "\(followUpCount) follow-ups",
        ]
        let environment = environmentEvidence.map { [$0.accessibilityValue] } ?? []
        return (base + environment + rows.map(\.accessibilityValue) + [proofBoundary])
            .joined(separator: " | ")
    }
}

struct BracketerPhysicalDeviceProofChecklist: Codable, Equatable, Sendable {
    enum Status: String, Codable, Equatable, Sendable {
        case requiresPhysicalDevice
        case physicalProofCaptured

        var title: String {
            switch self {
            case .requiresPhysicalDevice:
                return "Requires real iPhone"
            case .physicalProofCaptured:
                return "Physical proof captured"
            }
        }
    }

    struct Item: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let simulatorEvidence: String
        let requiredPhysicalEvidence: String
        let status: Status

        var accessibilityValue: String {
            [
                title,
                status.title,
                "Simulator evidence: \(simulatorEvidence)",
                "Required physical evidence: \(requiredPhysicalEvidence)"
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let projectCount: Int
    let latestProjectID: String?
    let latestProjectTitle: String?
    let simulatorCoverageSummary: String
    let physicalProofSummary: String
    let requiredDeviceMatrix: [String]
    let privacyBoundary: String
    let items: [Item]

    init(
        schemaVersion: Int = Self.schemaVersion,
        projectCount: Int,
        latestProjectID: String?,
        latestProjectTitle: String?,
        simulatorCoverageSummary: String,
        physicalProofSummary: String,
        requiredDeviceMatrix: [String],
        privacyBoundary: String,
        items: [Item]
    ) {
        self.schemaVersion = schemaVersion
        self.projectCount = projectCount
        self.latestProjectID = latestProjectID
        self.latestProjectTitle = latestProjectTitle
        self.simulatorCoverageSummary = simulatorCoverageSummary
        self.physicalProofSummary = physicalProofSummary
        self.requiredDeviceMatrix = requiredDeviceMatrix
        self.privacyBoundary = privacyBoundary
        self.items = items
    }

    static func make(
        projectLibrary: BracketProjectLibrarySnapshot,
        runtimeDiagnostic: IntelligenceRuntimeDiagnostic,
        privacyTrust: BracketerPrivacyTrustSnapshot
    ) -> BracketerPhysicalDeviceProofChecklist {
        let latestProject = projectLibrary.latestProject
        let projectEvidence = simulatorProjectEvidence(
            projectCount: projectLibrary.projects.count,
            latestProject: latestProject
        )
        let runtimeEvidence = [
            runtimeDiagnostic.title,
            runtimeDiagnostic.detail,
            runtimeDiagnostic.sourceSummary
        ].joined(separator: " ")
        let simulatorCoverageSummary = [
            projectEvidence,
            "Runtime evidence: \(runtimeEvidence)",
            "Simulator evidence is not physical iPhone proof."
        ].joined(separator: " ")
        let items = makeItems(
            projectEvidence: projectEvidence,
            runtimeDiagnostic: runtimeDiagnostic,
            privacyTrust: privacyTrust
        )

        return BracketerPhysicalDeviceProofChecklist(
            projectCount: projectLibrary.projects.count,
            latestProjectID: latestProject?.id,
            latestProjectTitle: latestProject?.displayTitle,
            simulatorCoverageSummary: simulatorCoverageSummary,
            physicalProofSummary: "0 physical proofs captured. Simulator evidence is not physical iPhone proof.",
            requiredDeviceMatrix: [
                "Real iPhone model and iOS build",
                "Apple Intelligence availability and non-fallback Foundation Models output",
                "Camera lens, exposure, ProRAW, and capture source facts",
                "Photos authorization, PHAssetResource metadata, and thumbnail delivery",
                "Files app, Share Sheet, Shortcuts, Spotlight, and exported archive bytes",
                "Physical location permission state without precise coordinate storage"
            ],
            privacyBoundary: "Physical Device Proof Checklist stores checklist metadata only; it does not store raw photo bytes, thumbnail pixels, decoded RAW data, final rendered images, Photos resources, or precise coordinates.",
            items: items
        )
    }

    var physicalProofCount: Int {
        items.filter { $0.status == .physicalProofCaptured }.count
    }

    var requiredPhysicalProofCount: Int {
        items.count
    }

    var deviceMatrixAccessibilityValue: String {
        "Required Device Matrix | \(requiredDeviceMatrix.joined(separator: " | "))"
    }

    var accessibilityValue: String {
        var parts = [
            "Physical Device Proof Checklist",
            "\(physicalProofCount) physical proofs captured",
            "\(requiredPhysicalProofCount) required physical proofs",
            "\(projectCount) \(projectCount == 1 ? "saved project" : "saved projects")"
        ]
        if let latestProjectTitle {
            parts.append("Latest \(latestProjectTitle)")
        } else {
            parts.append("No saved project")
        }
        parts.append(simulatorCoverageSummary)
        parts.append(physicalProofSummary)
        parts.append(deviceMatrixAccessibilityValue)
        parts.append(privacyBoundary)
        parts.append(contentsOf: items.map(\.accessibilityValue))
        return parts.joined(separator: " | ")
    }

    private static func simulatorProjectEvidence(
        projectCount: Int,
        latestProject: BracketProject?
    ) -> String {
        guard let latestProject else {
            return "Simulator coverage has \(projectCount) saved project metadata records and no latest project."
        }

        return [
            "Simulator/project coverage has \(projectCount) saved project metadata records.",
            "Latest project \(latestProject.displayTitle) has \(latestProject.reviewSnapshot.shotCount) planned shots, \(latestProject.reviewSnapshot.availableShotCount) available shots, source \(latestProject.source.rawValue), lifecycle \(latestProject.lifecycle.rawValue).",
            latestProject.privacy.accessibilityValue
        ].joined(separator: " ")
    }

    private static func makeItems(
        projectEvidence: String,
        runtimeDiagnostic: IntelligenceRuntimeDiagnostic,
        privacyTrust: BracketerPrivacyTrustSnapshot
    ) -> [Item] {
        [
            Item(
                id: "liveFoundationModelsOutput",
                title: "Live Foundation Models Output",
                simulatorEvidence: "Runtime diagnostic reports \(runtimeDiagnostic.title): \(runtimeDiagnostic.detail)",
                requiredPhysicalEvidence: "Requires real iPhone: capture a non-fallback LanguageModelSession response from Capture Coach or review narrative, with source disclosure and result-bundle evidence.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "photosResourceFetch",
                title: "Photos Resource Fetch",
                simulatorEvidence: privacyTrust.photosAccessPolicy,
                requiredPhysicalEvidence: "Requires real iPhone: fetch PHAssetResource metadata from real Photos assets and compare RAW/processed resources against the saved manifest.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "photosBackedThumbnails",
                title: "Photos-backed Thumbnails",
                simulatorEvidence: "\(projectEvidence) Thumbnail reports may describe delivery metadata without storing pixels.",
                requiredPhysicalEvidence: "Requires real iPhone: request real Photos thumbnails, record delivery/degraded/cloud flags, and prove no thumbnail pixels are persisted in project archives.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "finalRenderedOutputBytes",
                title: "Final Rendered Output Bytes",
                simulatorEvidence: "Deterministic preview and draft JPEG artifacts can be generated without private Photos bytes.",
                requiredPhysicalEvidence: "Requires real iPhone: render tone-mapped JPEG, HDR HEIF, and Lightroom TIFF outputs from real captured inputs, then record byte counts and archive integrity.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "photosSideBySidePixels",
                title: "Photos Side-by-side Pixels",
                simulatorEvidence: "Deterministic side-by-side comparison fixtures can be exported without inspecting user Photos pixels.",
                requiredPhysicalEvidence: "Requires real iPhone: compare real Photos-backed baseline and guard exposure pixels, record deltas, and separate that proof from deterministic fixtures.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "imageBundleByteExport",
                title: "Image Bundle Byte Export",
                simulatorEvidence: "Image-bundle draft packages use synthetic payload bytes and redacted identifiers.",
                requiredPhysicalEvidence: "Requires real iPhone: export real processed and RAW resource bytes through the selected privacy level and prove the Files package contents match the manifest.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "lensExifProRAW",
                title: "Lens, EXIF, and ProRAW",
                simulatorEvidence: "\(projectEvidence) Lens facets can be derived from stored manifest metadata.",
                requiredPhysicalEvidence: "Requires real iPhone: capture each supported lens, preserve EXIF/ProRAW facts, and prove the matrix across ultra-wide, wide, telephoto, RAW, and processed outputs.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "locationPermissionPolicy",
                title: "Location Permission Policy",
                simulatorEvidence: privacyTrust.locationPolicy,
                requiredPhysicalEvidence: "Requires real iPhone: exercise denied, allowed, and no-sample Photos location paths while proving project records never store precise coordinates.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "filesShortcutsRoundTrip",
                title: "Files and Shortcuts Round Trip",
                simulatorEvidence: "SwiftUI FileDocument and App Intents file providers can validate metadata archive parsing without invoking real Files or Shortcuts surfaces.",
                requiredPhysicalEvidence: "Requires real iPhone: export from Share Sheet/Files, import from Files, run Shortcuts export/import intents, and prove resulting bytes round-trip.",
                status: .requiresPhysicalDevice
            ),
            Item(
                id: "spotlightHandoffContinuation",
                title: "Spotlight Handoff Continuation",
                simulatorEvidence: "Hashed Spotlight records and handoff routes can be generated from project metadata.",
                requiredPhysicalEvidence: "Requires real iPhone: search the saved project in Spotlight, open the app from the system result, restore review, and prove the route with real project data.",
                status: .requiresPhysicalDevice
            )
        ]
    }
}

struct BracketerPhysicalCaptureMatrix: Codable, Equatable, Sendable {
    enum ScenarioStatus: String, Codable, Equatable, Sendable {
        case requiresPhysicalDevice
        case physicalProofCaptured

        var title: String {
            switch self {
            case .requiresPhysicalDevice:
                return "Requires physical iPhone lab"
            case .physicalProofCaptured:
                return "Physical proof captured"
            }
        }
    }

    struct Scenario: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let deviceAxis: String
        let captureAxis: String
        let permissionAxis: String
        let environmentAxis: String
        let requiredEvidence: String
        let linkedProofIDs: [String]
        let status: ScenarioStatus

        var accessibilityValue: String {
            [
                title,
                status.title,
                "Device: \(deviceAxis)",
                "Capture: \(captureAxis)",
                "Permissions: \(permissionAxis)",
                "Environment: \(environmentAxis)",
                "Required evidence: \(requiredEvidence)",
                "Linked proofs: \(linkedProofIDs.joined(separator: ", "))"
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let scenarios: [Scenario]
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        scenarios: [Scenario] = Self.defaultScenarios,
        privacyBoundary: String = "Physical Capture Matrix is a real-device lab plan only; it stores no Photos identifiers, image bytes, thumbnails, decoded RAW data, generated outputs, or precise coordinates."
    ) {
        self.schemaVersion = schemaVersion
        self.scenarios = scenarios
        self.privacyBoundary = privacyBoundary
    }

    static func make() -> BracketerPhysicalCaptureMatrix {
        BracketerPhysicalCaptureMatrix()
    }

    var scenarioCount: Int {
        scenarios.count
    }

    var provenScenarioCount: Int {
        scenarios.filter { $0.status == .physicalProofCaptured }.count
    }

    var summaryValue: String {
        [
            "Physical Capture Matrix",
            "\(provenScenarioCount) of \(scenarioCount) scenario proofs captured",
            "Real iPhone required",
            "Simulator coverage does not satisfy capture matrix"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        var parts = [
            summaryValue,
            privacyBoundary
        ]
        parts.append(contentsOf: scenarios.map(\.accessibilityValue))
        return parts.joined(separator: " | ")
    }

    private static let defaultScenarios: [Scenario] = [
        Scenario(
            id: "dynamicRangeInteriorWindow",
            title: "Interior Window Dynamic Range",
            deviceAxis: "At least one real iPhone model and iOS build with wide lens available.",
            captureAxis: "Five-shot +/-2 EV bracket, RAW plus processed where supported.",
            permissionAxis: "Photos read/write allowed; location permission recorded without precise coordinate storage.",
            environmentAxis: "Interior room with bright window and deep shadows.",
            requiredEvidence: "Saved project, histogram/clipping evidence, PHAssetResource metadata, final-output byte plan, and recovery notes if the bracket is incomplete.",
            linkedProofIDs: [
                "photosResourceFetch",
                "finalRenderedOutputBytes",
                "locationPermissionPolicy"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "lensProRAWResourceSweep",
            title: "Lens and ProRAW Resource Sweep",
            deviceAxis: "Real iPhone with every available lens enumerated by AVFoundation.",
            captureAxis: "Ultra-wide, wide, and telephoto where available; ProRAW on/off; processed fallback when RAW is unsupported.",
            permissionAxis: "Photos write allowed and recovery identifiers exported only through explicit recovery mode.",
            environmentAxis: "Static high-detail scene with repeatable lighting.",
            requiredEvidence: "Per-lens capture manifests, EXIF/UTI/resource metadata, RAW/processed pairing, and redacted metadata-only export.",
            linkedProofIDs: [
                "lensExifProRAW",
                "photosResourceFetch",
                "imageBundleByteExport"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "handheldMotionRecovery",
            title: "Handheld Motion Recovery",
            deviceAxis: "Real iPhone with handheld capture and motion metadata availability noted.",
            captureAxis: "Three-shot and five-shot handheld brackets at normal and slow shutter conditions.",
            permissionAxis: "Photos write allowed; diagnostics export remains text-only.",
            environmentAxis: "Moving subject plus static background.",
            requiredEvidence: "Motion/blur/alignment risk diagnostics, recovery recommendation, selected best-base exposure, and no claim of deghosting success without pixel proof.",
            linkedProofIDs: [
                "photosSideBySidePixels",
                "finalRenderedOutputBytes"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "photosPermissionLocationSweep",
            title: "Photos and Location Permission Sweep",
            deviceAxis: "Real iPhone on the current supported iOS build.",
            captureAxis: "One complete bracket per permission state.",
            permissionAxis: "Photos full access, limited/denied where applicable, location allowed, denied, and no sample observed.",
            environmentAxis: "Any repeatable static scene.",
            requiredEvidence: "Privacy & Trust rows, manifest location policy, Photos identifier redaction behavior, and proof that precise coordinates are not stored.",
            linkedProofIDs: [
                "photosResourceFetch",
                "locationPermissionPolicy"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "storagePressurePartialSave",
            title: "Storage Pressure and Partial Save",
            deviceAxis: "Real iPhone with available storage pressure documented.",
            captureAxis: "Attempted bracket under constrained storage or induced save failure.",
            permissionAxis: "Photos write allowed before the pressure condition is introduced.",
            environmentAxis: "Repeatable static scene.",
            requiredEvidence: "Partial-save diagnostics, incomplete project lifecycle, missing-shot/resource report, and user-facing recovery action.",
            linkedProofIDs: [
                "photosResourceFetch",
                "imageBundleByteExport"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "liveFoundationModelsCoach",
            title: "Live Foundation Models Capture Coach",
            deviceAxis: "Apple Intelligence-capable real iPhone with local model available.",
            captureAxis: "Capture Coach or review narrative refreshed from structured project facts.",
            permissionAxis: "Generated-note storage preference and export generated-content policy both recorded.",
            environmentAxis: "High-contrast scene with enough facts for a useful recommendation.",
            requiredEvidence: "Non-fallback LanguageModelSession result, source disclosure, fallback absence, generated-content export policy, and result bundle.",
            linkedProofIDs: [
                "liveFoundationModelsOutput"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "filesShortcutsSpotlightRoundTrip",
            title: "Files, Shortcuts, and Spotlight Round Trip",
            deviceAxis: "Real iPhone signed app install with App Intents and Spotlight available.",
            captureAxis: "Use a real Photos-backed saved project.",
            permissionAxis: "Explicit metadata-only and recovery-identifier export choices exercised.",
            environmentAxis: "Normal on-device Files, Shortcuts, and Spotlight surfaces.",
            requiredEvidence: "Files export/import bytes, Shortcuts export/import intent results, Spotlight search-result continuation, and restored project review.",
            linkedProofIDs: [
                "filesShortcutsRoundTrip",
                "spotlightHandoffContinuation"
            ],
            status: .requiresPhysicalDevice
        ),
        Scenario(
            id: "multiDeviceOSRegression",
            title: "Multi-device OS Regression",
            deviceAxis: "At least two real iPhone models across supported iOS builds.",
            captureAxis: "Same bracket recipe, lens choice, export preset, and review path on each device.",
            permissionAxis: "Same Photos/location/export privacy policy on each device.",
            environmentAxis: "Repeatable lighting target or documented field condition.",
            requiredEvidence: "Per-device result bundles, capability snapshots, capture timings, resource reports, and explicit OS/build labels.",
            linkedProofIDs: [
                "lensExifProRAW",
                "photosResourceFetch",
                "filesShortcutsRoundTrip"
            ],
            status: .requiresPhysicalDevice
        )
    ]
}

struct BracketerPhysicalDeviceLabPreflight: Codable, Equatable, Sendable {
    enum CheckStatus: String, Codable, Equatable, Sendable {
        case requiresReviewerAction
        case verifiedExternally

        var title: String {
            switch self {
            case .requiresReviewerAction:
                return "Requires reviewer action"
            case .verifiedExternally:
                return "Verified externally"
            }
        }
    }

    struct Check: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let requiredEvidence: String
        let blockerIfMissing: String
        let status: CheckStatus

        var accessibilityValue: String {
            [
                title,
                status.title,
                "Required evidence: \(requiredEvidence)",
                "Blocker if missing: \(blockerIfMissing)"
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let scenarioID: String?
    let scenarioTitle: String
    let checks: [Check]
    let externalBoundary: String
    let noProofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        scenarioID: String?,
        scenarioTitle: String,
        checks: [Check],
        externalBoundary: String,
        noProofBoundary: String
    ) {
        self.schemaVersion = schemaVersion
        self.scenarioID = scenarioID
        self.scenarioTitle = scenarioTitle
        self.checks = checks
        self.externalBoundary = externalBoundary
        self.noProofBoundary = noProofBoundary
    }

    static func make(
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make()
    ) -> BracketerPhysicalDeviceLabPreflight {
        let runbook = catalog.runbooks.first(where: { $0.recordedProofs.isEmpty }) ?? catalog.runbooks.first
        return BracketerPhysicalDeviceLabPreflight(
            scenarioID: runbook?.id,
            scenarioTitle: runbook?.scenarioTitle ?? "No physical runbook selected",
            checks: [
                Check(
                    id: "connectedUnlockedIPhone",
                    title: "Connected Unlocked iPhone",
                    requiredEvidence: "Xcode/devicectl lists an available unlocked iPhone destination with model and iOS build.",
                    blockerIfMissing: "Offline, locked, untrusted, or unavailable devices cannot produce physical proof.",
                    status: .requiresReviewerAction
                ),
                Check(
                    id: "physicalDestinationSelected",
                    title: "Physical Destination Selected",
                    requiredEvidence: "The test command uses `platform=iOS,id=<DEVICE-UDID>` for the real device, not an iOS Simulator.",
                    blockerIfMissing: "Simulator destinations are rejected by the physical proof ingestor.",
                    status: .requiresReviewerAction
                ),
                Check(
                    id: "scenarioResultBundleReserved",
                    title: "Scenario Result Bundle Reserved",
                    requiredEvidence: "The result bundle path includes the selected scenario id and ends in `.xcresult`.",
                    blockerIfMissing: "Generic or cross-scenario result-bundle names are rejected before proof can be recorded.",
                    status: .requiresReviewerAction
                ),
                Check(
                    id: "compactSummaryAndDigestsReady",
                    title: "Compact Summary And Digests Ready",
                    requiredEvidence: "The lab exports compact xcresult summary JSON, metrics JSON, result-bundle SHA-256, and summary SHA-256.",
                    blockerIfMissing: "Unsigned or missing result-bundle artifacts cannot satisfy the ingestion contract.",
                    status: .requiresReviewerAction
                ),
                Check(
                    id: "attachmentManifestReady",
                    title: "Attachment Manifest Ready",
                    requiredEvidence: "Every expected artifact id has reviewer-evidence tokens for SHA-256 and byte count.",
                    blockerIfMissing: "Missing attachment hashes or byte counts keep the submission preview rejected.",
                    status: .requiresReviewerAction
                ),
                Check(
                    id: "signedProofPreviewBeforeIngest",
                    title: "Signed Proof Preview Before Ingest",
                    requiredEvidence: "The signed proof submission previews as accepted before any ingest attempt.",
                    blockerIfMissing: "Preview rejection means ingest would not mutate runbooks or count physical proof.",
                    status: .requiresReviewerAction
                )
            ],
            externalBoundary: "Preflight is a reviewer checklist for Xcode/devicectl and lab artifacts; the iOS app does not execute commands or authenticate connected devices here.",
            noProofBoundary: "Preflight does not count physical proof, mutate runbooks, mutate result-bundle indexes, inspect Photos assets, or store image bytes."
        )
    }

    var verifiedCheckCount: Int {
        checks.filter { $0.status == .verifiedExternally }.count
    }

    var checkIDs: [String] {
        checks.map(\.id)
    }

    var summaryValue: String {
        [
            "Physical Device Lab Preflight",
            "Scenario: \(scenarioTitle)",
            "\(verifiedCheckCount) of \(checks.count) preflight checks verified by app",
            "Connected unlocked iPhone required",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        var parts = [
            summaryValue,
            externalBoundary,
            noProofBoundary
        ]
        if let scenarioID {
            parts.append("Scenario id: \(scenarioID)")
        }
        parts.append(contentsOf: checks.map(\.accessibilityValue))
        return parts.joined(separator: " | ")
    }
}

struct BracketerHostDeviceAvailabilityReport: Codable, Equatable, Sendable {
    enum Source: String, Codable, Equatable, Sendable {
        case devicectl
        case xctrace
        case xcodebuild
        case unknown

        var displayLabel: String {
            switch self {
            case .devicectl:
                return "devicectl list devices"
            case .xctrace:
                return "xctrace list devices"
            case .xcodebuild:
                return "xcodebuild destinations/preflight"
            case .unknown:
                return "unknown host availability report"
            }
        }
    }

    enum Availability: String, Codable, Equatable, Sendable {
        case available
        case unavailable
        case offline
        case locked
        case unknown

        var displayLabel: String {
            switch self {
            case .available:
                return "available"
            case .unavailable:
                return "unavailable"
            case .offline:
                return "offline"
            case .locked:
                return "locked"
            case .unknown:
                return "unknown"
            }
        }
    }

    struct Device: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let isPhysicalIPhone: Bool
        let availability: Availability
        let modelLabel: String?
        let osLabel: String?

        var accessibilityValue: String {
            var parts: [String] = [
                "Device \(id)",
                "Physical iPhone: \(isPhysicalIPhone ? "yes" : "no")",
                "Availability: \(availability.displayLabel)"
            ]
            if let modelLabel {
                parts.append("Model: \(modelLabel)")
            }
            if let osLabel {
                parts.append("OS: \(osLabel)")
            }
            return parts.joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let defaultExternalBoundary = "Host Device Availability Report is a privacy-safe summary of a reviewer-supplied devicectl or xctrace listing; the iOS app does not execute commands, authenticate connected devices, or store raw device identifiers."
    static let defaultNoProofBoundary = "Host Device Availability Report is preview only, does not count physical proof, mutate runbooks, mutate result-bundle indexes, inspect Photos assets, or store image bytes. Connected unlocked iPhone still required for physical proof."

    let schemaVersion: Int
    let source: Source
    let devices: [Device]
    let externalBoundary: String
    let noProofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        source: Source,
        devices: [Device],
        externalBoundary: String = Self.defaultExternalBoundary,
        noProofBoundary: String = Self.defaultNoProofBoundary
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.devices = devices
        self.externalBoundary = externalBoundary
        self.noProofBoundary = noProofBoundary
    }

    var physicalIPhoneCount: Int {
        devices.filter(\.isPhysicalIPhone).count
    }

    var availablePhysicalIPhoneCount: Int {
        devices.filter { $0.isPhysicalIPhone && $0.availability == .available }.count
    }

    var unavailablePhysicalIPhoneCount: Int {
        devices.filter { $0.isPhysicalIPhone && $0.availability == .unavailable }.count
    }

    var offlinePhysicalIPhoneCount: Int {
        devices.filter { $0.isPhysicalIPhone && $0.availability == .offline }.count
    }

    var lockedPhysicalIPhoneCount: Int {
        devices.filter { $0.isPhysicalIPhone && $0.availability == .locked }.count
    }

    var labReadinessValue: String {
        if physicalIPhoneCount == 0 {
            return "Blocked: no physical iPhone found | Connected unlocked iPhone still required | No physical proof count changed"
        }
        if lockedPhysicalIPhoneCount > 0 {
            return "Blocked: physical iPhone is locked | Unlock the iPhone before running the physical lab | No physical proof count changed"
        }
        if availablePhysicalIPhoneCount > 0 {
            return "Host report sees an available physical iPhone | Still requires signed physical lab artifacts | No physical proof count changed"
        }
        return "Blocked: physical iPhone unavailable or offline | Connected unlocked iPhone still required | No physical proof count changed"
    }

    var summaryValue: String {
        [
            "Host Device Availability Report",
            "Source: \(source.displayLabel)",
            "\(physicalIPhoneCount) physical iPhone row(s)",
            "\(availablePhysicalIPhoneCount) available",
            "\(unavailablePhysicalIPhoneCount) unavailable",
            "\(offlinePhysicalIPhoneCount) offline",
            "\(lockedPhysicalIPhoneCount) locked",
            labReadinessValue,
            "preview only",
            "no physical proof count changed",
            "Connected unlocked iPhone still required"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        var parts: [String] = [
            summaryValue,
            externalBoundary,
            noProofBoundary
        ]
        parts.append(contentsOf: devices.map(\.accessibilityValue))
        return parts.joined(separator: " | ")
    }

    static func parse(_ text: String, source explicitSource: Source? = nil) -> BracketerHostDeviceAvailabilityReport {
        let detectedSource = explicitSource ?? detectSource(text)
        let devices: [Device]
        switch detectedSource {
        case .xctrace:
            devices = parseXctraceDevices(text)
        case .xcodebuild:
            devices = parseXcodebuildDevices(text)
        case .devicectl:
            devices = parseDevicectlDevices(text)
        case .unknown:
            let xctraceDevices = parseXctraceDevices(text)
            let devicectlDevices = parseDevicectlDevices(text)
            let xcodebuildDevices = parseXcodebuildDevices(text)
            devices = [devicectlDevices, xctraceDevices, xcodebuildDevices]
                .max { lhs, rhs in lhs.count < rhs.count } ?? []
        }
        return BracketerHostDeviceAvailabilityReport(source: detectedSource, devices: devices)
    }

    private static func detectSource(_ text: String) -> Source {
        if text.contains("Available destinations")
            || text.contains("Run Destination Preflight")
            || text.contains("Unlock Physical iPhone to Continue") {
            return .xcodebuild
        }
        if text.contains("== Devices") || text.contains("== Simulators") {
            return .xctrace
        }
        let lowered = text.lowercased()
        if lowered.contains("devicectl") {
            return .devicectl
        }
        if lowered.contains("identifier") && lowered.contains("state") && lowered.contains("model") {
            return .devicectl
        }
        return .unknown
    }

    private static func parseDevicectlDevices(_ text: String) -> [Device] {
        var devices: [Device] = []
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()
            if lower.hasPrefix("devices:")
                || lower.hasPrefix("name ")
                || lower.hasPrefix("identifier ")
                || lower.hasPrefix("hostname")
                || lower.hasPrefix("---")
                || lower.contains("simulator") {
                continue
            }
            guard let modelLabel = firstRegexMatch(pattern: #"iPhone\d+,\d+"#, in: line) else {
                continue
            }
            let availability: Availability = {
                if lower.contains("unavailable") { return .unavailable }
                if lower.contains("offline") || lower.contains("disconnected") { return .offline }
                if lower.contains("connected") || lower.contains("available") || lower.contains("paired") { return .available }
                return .unknown
            }()
            devices.append(Device(
                id: sanitizedIdentifier(firstRegexMatch(pattern: #"[0-9A-Fa-f]{8}-[0-9A-Fa-f\-]{4,}"#, in: line)),
                isPhysicalIPhone: true,
                availability: availability,
                modelLabel: modelLabel,
                osLabel: osLabelToken(in: line)
            ))
        }
        return devices
    }

    private static func parseXctraceDevices(_ text: String) -> [Device] {
        var devices: [Device] = []
        var currentSection = ""
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("==") {
                currentSection = line.lowercased()
                continue
            }
            if currentSection.contains("simulator") {
                continue
            }
            let lower = line.lowercased()
            if lower.contains("(macbook)") || lower.contains("(intel)") || lower.contains("(arm64)") || lower.contains("(apple silicon)") {
                continue
            }
            guard lower.contains("iphone") else { continue }
            if lower.contains("simulator") { continue }
            let availability: Availability = {
                if lower.contains("(offline)") || lower.contains("[offline]") || currentSection.contains("offline") {
                    return .offline
                }
                if lower.contains("(unavailable)") || currentSection.contains("unavailable") {
                    return .unavailable
                }
                return .available
            }()
            devices.append(Device(
                id: sanitizedIdentifier(firstRegexMatch(pattern: #"[0-9A-Fa-f]{8}-[0-9A-Fa-f\-]{4,}"#, in: line)),
                isPhysicalIPhone: true,
                availability: availability,
                modelLabel: firstRegexMatch(pattern: #"iPhone\d+,\d+"#, in: line),
                osLabel: osLabelToken(in: line)
            ))
        }
        return devices
    }

    private static func parseXcodebuildDevices(_ text: String) -> [Device] {
        var devices: [Device] = []
        let isLockedPreflight = text
            .components(separatedBy: "\n")
            .map { $0.lowercased() }
            .contains { line in
                (line.contains("unlock physical iphone to continue") && !line.contains("ipad"))
                    || (line.contains("device is locked")
                        && line.contains("iphone")
                        && !line.contains("ipad")
                        && !line.contains("simulator"))
            }
        if isLockedPreflight {
            var destinationIDs = allRegexCaptures(
                pattern: #"platform=iOS,id=([0-9A-Fa-f\-]+)"#,
                in: text,
                captureIndex: 1
            )
            if destinationIDs.isEmpty {
                destinationIDs = [""]
            }
            for destinationID in destinationIDs {
                let sanitizedID = sanitizedIdentifier(destinationID.isEmpty ? nil : destinationID)
                if devices.contains(where: { $0.id == sanitizedID }) {
                    continue
                }
                devices.append(Device(
                    id: sanitizedID,
                    isPhysicalIPhone: true,
                    availability: .locked,
                    modelLabel: nil,
                    osLabel: nil
                ))
            }
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()
            guard lower.contains("platform:ios"),
                  lower.contains("name:"),
                  lower.contains("iphone"),
                  !lower.contains("simulator") else {
                continue
            }
            let destinationID = firstRegexCapture(
                pattern: #"id:([0-9A-Fa-f\-]+)"#,
                in: line,
                captureIndex: 1
            )
            let sanitizedID = sanitizedIdentifier(destinationID)
            if devices.contains(where: { $0.id == sanitizedID }) {
                continue
            }
            devices.append(Device(
                id: sanitizedID,
                isPhysicalIPhone: true,
                availability: .available,
                modelLabel: firstRegexMatch(pattern: #"iPhone\d+,\d+"#, in: line),
                osLabel: osLabelToken(in: line)
            ))
        }

        return devices
    }

    private static func osLabelToken(in line: String) -> String? {
        firstRegexCapture(pattern: #"\((\d+(?:\.\d+){0,3}[A-Za-z]?)\)"#, in: line, captureIndex: 1)
    }

    private static func firstRegexMatch(pattern: String, in line: String) -> String? {
        firstRegexCapture(pattern: pattern, in: line, captureIndex: 0)
    }

    private static func allRegexCaptures(pattern: String, in line: String, captureIndex: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        return regex
            .matches(in: line, range: range)
            .compactMap { result in
                guard result.numberOfRanges > captureIndex else {
                    return nil
                }
                let captureRange = result.range(at: captureIndex)
                guard captureRange.location != NSNotFound else {
                    return nil
                }
                return nsLine.substring(with: captureRange)
            }
    }

    private static func firstRegexCapture(pattern: String, in line: String, captureIndex: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              captureIndex < match.numberOfRanges else {
            return nil
        }
        return nsLine.substring(with: match.range(at: captureIndex))
    }

    private static func sanitizedIdentifier(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "device-redacted-none" }
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "device-\(hex.prefix(12))"
    }
}

struct BracketerVerificationRunbook: Codable, Equatable, Sendable {
    struct Command: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let kind: String
        let invocation: String
        let expectedResultBundle: String?
        let proofBoundary: String

        var accessibilityValue: String {
            [
                title,
                "Kind: \(kind)",
                "Command: \(invocation)",
                expectedResultBundle.map { "Result bundle: \($0)" },
                "Boundary: \(proofBoundary)"
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        }
    }

    struct ResultBundleContract: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let path: String
        let producedByCommandID: String
        let requiredContents: [String]
        let extractionCommand: String
        let proofBoundary: String

        var accessibilityValue: String {
            [
                id,
                "Path: \(path)",
                "Produced by: \(producedByCommandID)",
                "Required contents: \(requiredContents.joined(separator: ", "))",
                "Extraction: \(extractionCommand)",
                "Boundary: \(proofBoundary)"
            ].joined(separator: " | ")
        }
    }

    struct BenchmarkMetric: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let source: String
        let extractionCommandID: String
        let acceptanceNote: String

        var accessibilityValue: String {
            [
                title,
                "Source: \(source)",
                "Extractor: \(extractionCommandID)",
                acceptanceNote
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let resultBundleRoot: String
    let simulatorUDIDPlaceholder: String
    let physicalDeviceUDIDPlaceholder: String
    let commands: [Command]
    let resultBundles: [ResultBundleContract]
    let benchmarkMetrics: [BenchmarkMetric]
    let privacyBoundary: String
    let physicalProofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        resultBundleRoot: String,
        simulatorUDIDPlaceholder: String,
        physicalDeviceUDIDPlaceholder: String,
        commands: [Command],
        resultBundles: [ResultBundleContract],
        benchmarkMetrics: [BenchmarkMetric],
        privacyBoundary: String = "Verification Runbook stores command text and result-bundle contracts only; it stores no Photos identifiers, image bytes, thumbnails, decoded RAW data, generated output bytes, or precise coordinates.",
        physicalProofBoundary: String = "Simulator result bundles and benchmark extractors do not prove physical iPhone capture; physical proof requires a signed run on platform=iOS,id=<DEVICE-UDID> plus real camera, Photos, Files, Shortcuts, Spotlight, and Foundation Models evidence."
    ) {
        self.schemaVersion = schemaVersion
        self.resultBundleRoot = resultBundleRoot
        self.simulatorUDIDPlaceholder = simulatorUDIDPlaceholder
        self.physicalDeviceUDIDPlaceholder = physicalDeviceUDIDPlaceholder
        self.commands = commands
        self.resultBundles = resultBundles
        self.benchmarkMetrics = benchmarkMetrics
        self.privacyBoundary = privacyBoundary
        self.physicalProofBoundary = physicalProofBoundary
    }

    static func make(
        simulatorUDID: String = "<SIMULATOR-UDID>",
        physicalDeviceUDID: String = "<DEVICE-UDID>",
        developmentTeam: String = "<TEAM_ID>",
        resultBundleRoot: String = "build"
    ) -> BracketerVerificationRunbook {
        let fullSimulatorBundle = "\(resultBundleRoot)/Bracketer-simulator-full.xcresult"
        let unitBundle = "\(resultBundleRoot)/Bracketer-unit.xcresult"
        let simulatedCaptureBundle = "\(resultBundleRoot)/Bracketer-simulated-capture-ui.xcresult"
        let physicalBundle = "\(resultBundleRoot)/Bracketer-physical-device-lab.xcresult"
        let commands = makeCommands(
            simulatorUDID: simulatorUDID,
            physicalDeviceUDID: physicalDeviceUDID,
            developmentTeam: developmentTeam,
            fullSimulatorBundle: fullSimulatorBundle,
            unitBundle: unitBundle,
            simulatedCaptureBundle: simulatedCaptureBundle,
            physicalBundle: physicalBundle
        )
        let resultBundles = makeResultBundles(
            fullSimulatorBundle: fullSimulatorBundle,
            unitBundle: unitBundle,
            simulatedCaptureBundle: simulatedCaptureBundle,
            physicalBundle: physicalBundle
        )
        let benchmarkMetrics = [
            BenchmarkMetric(
                id: "launchPerformance",
                title: "Duration (AppLaunch)",
                source: "XCTest launch-performance metrics from the simulator full gate result bundle.",
                extractionCommandID: "extractBenchmarkMetrics",
                acceptanceNote: "Record all measurements and compare against the prior accepted simulator baseline before treating a run as faster."
            ),
            BenchmarkMetric(
                id: "timedDiagnostics",
                title: "Startup, session, capture, save, review, and histogram diagnostics",
                source: "camera.diagnostics.*, review.diagnostics.*, and camera.histogramDiagnostics.* accessibility probes plus diagnostics ShareLink text.",
                extractionCommandID: "extractResultBundleSummary",
                acceptanceNote: "Use the result bundle to prove the diagnostic probes were exercised; do not infer physical sensor timing from simulator diagnostics."
            ),
            BenchmarkMetric(
                id: "droppedFrameDiagnostics",
                title: "Dropped frame diagnostics",
                source: "Future physical-device Instruments or XCTest attachments.",
                extractionCommandID: "physicalDeviceLabGate",
                acceptanceNote: "Unproven until a real iPhone run attaches frame pacing or Instruments evidence."
            )
        ]

        return BracketerVerificationRunbook(
            resultBundleRoot: resultBundleRoot,
            simulatorUDIDPlaceholder: simulatorUDID,
            physicalDeviceUDIDPlaceholder: physicalDeviceUDID,
            commands: commands,
            resultBundles: resultBundles,
            benchmarkMetrics: benchmarkMetrics
        )
    }

    var commandCount: Int {
        commands.count
    }

    var commandIDs: [String] {
        commands.map(\.id)
    }

    var benchmarkCommandCount: Int {
        commands.filter { $0.kind == "benchmark" }.count
    }

    var summaryValue: String {
        [
            "Verification Runbook",
            "\(commandCount) commands",
            "\(resultBundles.count) result bundles",
            "\(benchmarkMetrics.count) benchmark metrics",
            "Physical iPhone proof still requires platform=iOS,id=\(physicalDeviceUDIDPlaceholder)"
        ].joined(separator: " | ")
    }

    var resultBundleDocumentationValue: String {
        [
            "Result Bundle Documentation",
            "\(resultBundles.count) documented bundles",
            resultBundles.map(\.accessibilityValue).joined(separator: " | ")
        ].joined(separator: " | ")
    }

    var benchmarkSummaryValue: String {
        [
            "Benchmark Commands",
            "\(benchmarkCommandCount) extractor commands",
            "\(benchmarkMetrics.count) benchmark metrics",
            "No physical dropped-frame proof yet"
        ].joined(separator: " | ")
    }

    var benchmarkAccessibilityValue: String {
        [
            benchmarkSummaryValue,
            commands.filter { $0.kind == "benchmark" }.map(\.accessibilityValue).joined(separator: " | "),
            benchmarkMetrics.map(\.accessibilityValue).joined(separator: " | ")
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            privacyBoundary,
            physicalProofBoundary,
            commands.map(\.accessibilityValue).joined(separator: " | "),
            resultBundleDocumentationValue,
            benchmarkAccessibilityValue
        ].joined(separator: " | ")
    }

    private static func makeCommands(
        simulatorUDID: String,
        physicalDeviceUDID: String,
        developmentTeam: String,
        fullSimulatorBundle: String,
        unitBundle: String,
        simulatedCaptureBundle: String,
        physicalBundle: String
    ) -> [Command] {
        [
            Command(
                id: "resolveSimulatorDestination",
                title: "Resolve Simulator Destination",
                kind: "discovery",
                invocation: "\(developerDirPrefix) /usr/bin/xcrun simctl list devices available",
                expectedResultBundle: nil,
                proofBoundary: "Destination discovery only; this does not build, test, benchmark, or prove physical capture."
            ),
            Command(
                id: "fullSimulatorGate",
                title: "Full Simulator Gate",
                kind: "test",
                invocation: xcodebuildTestCommand(
                    destination: "platform=iOS Simulator,id=\(simulatorUDID)",
                    resultBundlePath: fullSimulatorBundle,
                    onlyTesting: nil,
                    codeSigningAllowed: false
                ),
                expectedResultBundle: fullSimulatorBundle,
                proofBoundary: "Full simulator regression proof; not physical iPhone proof."
            ),
            Command(
                id: "unitBundleGate",
                title: "App-hosted Unit Bundle Gate",
                kind: "test",
                invocation: xcodebuildTestCommand(
                    destination: "platform=iOS Simulator,id=\(simulatorUDID)",
                    resultBundlePath: unitBundle,
                    onlyTesting: "BracketerTests",
                    codeSigningAllowed: false
                ),
                expectedResultBundle: unitBundle,
                proofBoundary: "Pure and app-hosted model proof; not UI, camera sensor, or Photos-library proof."
            ),
            Command(
                id: "simulatedCaptureReviewUIGate",
                title: "Simulated Capture Review UI Gate",
                kind: "test",
                invocation: xcodebuildTestCommand(
                    destination: "platform=iOS Simulator,id=\(simulatorUDID)",
                    resultBundlePath: simulatedCaptureBundle,
                    onlyTesting: "BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview",
                    codeSigningAllowed: false
                ),
                expectedResultBundle: simulatedCaptureBundle,
                proofBoundary: "Deterministic simulated capture and review proof; no real camera, Photos asset, or physical-device proof is claimed."
            ),
            Command(
                id: "extractResultBundleSummary",
                title: "Extract Result Bundle Summary",
                kind: "benchmark",
                invocation: "\(developerDirPrefix) /usr/bin/xcrun xcresulttool get test-results summary --path \(fullSimulatorBundle) --compact",
                expectedResultBundle: fullSimulatorBundle,
                proofBoundary: "Summarizes XCTest results from an existing bundle; it cannot create missing physical proof."
            ),
            Command(
                id: "extractBenchmarkMetrics",
                title: "Extract Benchmark Metrics",
                kind: "benchmark",
                invocation: "\(developerDirPrefix) /usr/bin/xcrun xcresulttool get test-results metrics --path \(fullSimulatorBundle) --compact",
                expectedResultBundle: fullSimulatorBundle,
                proofBoundary: "Extracts XCTest performance metrics from a result bundle; simulator metrics are not sensor or dropped-frame proof."
            ),
            Command(
                id: "physicalDeviceLabGate",
                title: "Physical Device Lab Gate",
                kind: "physical",
                invocation: xcodebuildTestCommand(
                    destination: "platform=iOS,id=\(physicalDeviceUDID)",
                    resultBundlePath: physicalBundle,
                    onlyTesting: nil,
                    codeSigningAllowed: nil,
                    developmentTeam: developmentTeam
                ),
                expectedResultBundle: physicalBundle,
                proofBoundary: "Signed real-iPhone XCTest gate only; the May Goals physical capture matrix still needs manual camera, Photos, Files, Shortcuts, Spotlight, and Foundation Models evidence attached to the bundle."
            )
        ]
    }

    private static func makeResultBundles(
        fullSimulatorBundle: String,
        unitBundle: String,
        simulatedCaptureBundle: String,
        physicalBundle: String
    ) -> [ResultBundleContract] {
        [
            ResultBundleContract(
                id: "simulatorFull",
                path: fullSimulatorBundle,
                producedByCommandID: "fullSimulatorGate",
                requiredContents: [
                    "BracketerTests and BracketerUITests outcomes",
                    "launch-performance metrics when the suite includes testLaunchPerformance",
                    "failure screenshots and logs when XCTest records them"
                ],
                extractionCommand: "\(developerDirPrefix) /usr/bin/xcrun xcresulttool get test-results summary --path \(fullSimulatorBundle) --compact",
                proofBoundary: "Simulator-only result bundle."
            ),
            ResultBundleContract(
                id: "unitBundle",
                path: unitBundle,
                producedByCommandID: "unitBundleGate",
                requiredContents: [
                    "Swift Testing model coverage",
                    "Codable round-trip checks",
                    "privacy-boundary assertions"
                ],
                extractionCommand: "\(developerDirPrefix) /usr/bin/xcrun xcresulttool get test-results summary --path \(unitBundle) --compact",
                proofBoundary: "Model and serialization proof only."
            ),
            ResultBundleContract(
                id: "simulatedCaptureReviewUI",
                path: simulatedCaptureBundle,
                producedByCommandID: "simulatedCaptureReviewUIGate",
                requiredContents: [
                    "simulated capture completion",
                    "review handoff probes",
                    "Settings Device Proof probes"
                ],
                extractionCommand: "\(developerDirPrefix) /usr/bin/xcrun xcresulttool get test-results summary --path \(simulatedCaptureBundle) --compact",
                proofBoundary: "Deterministic simulator UI proof only."
            ),
            ResultBundleContract(
                id: "physicalDeviceLab",
                path: physicalBundle,
                producedByCommandID: "physicalDeviceLabGate",
                requiredContents: [
                    "real iPhone model and iOS build",
                    "signed app/test runner execution",
                    "manual attachments for physical capture matrix scenarios before any proof count can increase"
                ],
                extractionCommand: "\(developerDirPrefix) /usr/bin/xcrun xcresulttool get test-results summary --path \(physicalBundle) --compact",
                proofBoundary: "Prepared physical-device evidence container; not proof until a connected iPhone run and lab attachments exist."
            )
        ]
    }

    private static var developerDirPrefix: String {
        "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
    }

    private static func xcodebuildTestCommand(
        destination: String,
        resultBundlePath: String,
        onlyTesting: String?,
        codeSigningAllowed: Bool?,
        developmentTeam: String? = nil
    ) -> String {
        var parts = [
            developerDirPrefix,
            "xcodebuild test",
            "-project Bracketer.xcodeproj",
            "-scheme Bracketer",
            "-destination '\(destination)'"
        ]
        if let onlyTesting {
            parts.append("-only-testing:\(onlyTesting)")
        }
        parts.append("-parallel-testing-enabled NO")
        parts.append("-maximum-concurrent-test-simulator-destinations 1")
        parts.append("-resultBundlePath \(resultBundlePath)")
        if let codeSigningAllowed {
            parts.append("CODE_SIGNING_ALLOWED=\(codeSigningAllowed ? "YES" : "NO")")
        }
        if let developmentTeam {
            parts.append("DEVELOPMENT_TEAM=\(developmentTeam)")
        }
        return parts.joined(separator: " ")
    }
}

struct BracketerPhysicalCaptureRunbook: Codable, Equatable, Identifiable, Sendable {
    struct RecordedProof: Codable, Equatable, Sendable {
        let deviceModel: String
        let iosBuild: String
        let capturedAt: Date
        let resultBundleFilename: String
        let resultBundleSHA256: String?
        let resultBundleSummarySHA256: String?
        let resultBundleSummary: BracketerPhysicalResultBundleSummary?
        let resultBundleMetrics: BracketerPhysicalResultBundleMetrics?
        let resultBundleTestContract: BracketerPhysicalResultBundleTestContract?
        let resultBundleTiming: BracketerPhysicalResultBundleTiming?
        let resultBundleDevice: BracketerPhysicalResultBundleDevice?
        let attachmentManifest: BracketerPhysicalAttachmentManifest?
        let manifestSHA256: String?
        let notes: String?

        init(
            deviceModel: String,
            iosBuild: String,
            capturedAt: Date,
            resultBundleFilename: String,
            resultBundleSHA256: String? = nil,
            resultBundleSummarySHA256: String? = nil,
            resultBundleSummary: BracketerPhysicalResultBundleSummary? = nil,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics? = nil,
            resultBundleTestContract: BracketerPhysicalResultBundleTestContract? = nil,
            resultBundleTiming: BracketerPhysicalResultBundleTiming? = nil,
            resultBundleDevice: BracketerPhysicalResultBundleDevice? = nil,
            attachmentManifest: BracketerPhysicalAttachmentManifest? = nil,
            manifestSHA256: String? = nil,
            notes: String? = nil
        ) {
            self.deviceModel = deviceModel
            self.iosBuild = iosBuild
            self.capturedAt = capturedAt
            self.resultBundleFilename = resultBundleFilename
            self.resultBundleSHA256 = resultBundleSHA256
            self.resultBundleSummarySHA256 = resultBundleSummarySHA256
            self.resultBundleSummary = resultBundleSummary
            self.resultBundleMetrics = resultBundleMetrics
            self.resultBundleTestContract = resultBundleTestContract
            self.resultBundleTiming = resultBundleTiming
            self.resultBundleDevice = resultBundleDevice
            self.attachmentManifest = attachmentManifest
            self.manifestSHA256 = manifestSHA256
            self.notes = notes
        }

        var accessibilityValue: String {
            [
                "Device: \(deviceModel)",
                "iOS build: \(iosBuild)",
                "Result bundle: \(resultBundleFilename)",
                resultBundleSHA256.map { "Result bundle SHA-256: \($0)" },
                resultBundleSummarySHA256.map { "Result bundle summary SHA-256: \($0)" },
                resultBundleSummary.map { "Result bundle summary: \($0.summaryValue)" },
                resultBundleMetrics.map { "Result bundle metrics: \($0.summaryValue)" },
                resultBundleTestContract.map { "Result bundle test contract: \($0.summaryValue)" },
                resultBundleTiming.map { "Result bundle timing: \($0.summaryValue)" },
                resultBundleDevice.map { "Result bundle device: \($0.summaryValue)" },
                attachmentManifest.map { "Attachment manifest hashes: \($0.summaryValue)" },
                manifestSHA256.map { "Manifest SHA-256: \($0)" },
                notes.map { "Notes: \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let id: String
    let scenarioTitle: String
    let preparationSteps: [String]
    let captureSteps: [String]
    let evidenceSteps: [String]
    let linkedProofIDs: [String]
    let resultBundlePath: String
    let expectedArtifacts: [String]
    let privacyBoundary: String
    let recordedProofs: [RecordedProof]

    init(
        schemaVersion: Int = Self.schemaVersion,
        id: String,
        scenarioTitle: String,
        preparationSteps: [String],
        captureSteps: [String],
        evidenceSteps: [String],
        linkedProofIDs: [String],
        resultBundlePath: String,
        expectedArtifacts: [String],
        privacyBoundary: String,
        recordedProofs: [RecordedProof] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.scenarioTitle = scenarioTitle
        self.preparationSteps = preparationSteps
        self.captureSteps = captureSteps
        self.evidenceSteps = evidenceSteps
        self.linkedProofIDs = linkedProofIDs
        self.resultBundlePath = resultBundlePath
        self.expectedArtifacts = expectedArtifacts
        self.privacyBoundary = privacyBoundary
        self.recordedProofs = recordedProofs
    }

    static func defaultRunbooks(
        resultBundleRoot: String = "build/physical-lab"
    ) -> [BracketerPhysicalCaptureRunbook] {
        BracketerPhysicalCaptureMatrix.make().scenarios.map { scenario in
            make(for: scenario, resultBundleRoot: resultBundleRoot)
        }
    }

    var physicalProofCaptured: Bool {
        !recordedProofs.isEmpty
    }

    var summaryValue: String {
        [
            scenarioTitle,
            physicalProofCaptured ? "Physical proof captured" : "Requires real iPhone",
            "Result bundle: \(resultBundlePath)",
            "Linked proofs: \(linkedProofIDs.joined(separator: ", "))"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            "Preparation: \(preparationSteps.joined(separator: " -> "))",
            "Capture: \(captureSteps.joined(separator: " -> "))",
            "Evidence: \(evidenceSteps.joined(separator: " -> "))",
            "Expected artifacts: \(expectedArtifacts.joined(separator: ", "))",
            privacyBoundary,
            recordedProofs.map(\.accessibilityValue).joined(separator: " | ")
        ].joined(separator: " | ")
    }

    func withRecordedProof(_ proof: RecordedProof) -> BracketerPhysicalCaptureRunbook {
        BracketerPhysicalCaptureRunbook(
            schemaVersion: schemaVersion,
            id: id,
            scenarioTitle: scenarioTitle,
            preparationSteps: preparationSteps,
            captureSteps: captureSteps,
            evidenceSteps: evidenceSteps,
            linkedProofIDs: linkedProofIDs,
            resultBundlePath: resultBundlePath,
            expectedArtifacts: expectedArtifacts,
            privacyBoundary: privacyBoundary,
            recordedProofs: recordedProofs + [proof]
        )
    }

    private static func make(
        for scenario: BracketerPhysicalCaptureMatrix.Scenario,
        resultBundleRoot: String
    ) -> BracketerPhysicalCaptureRunbook {
        BracketerPhysicalCaptureRunbook(
            id: scenario.id,
            scenarioTitle: scenario.title,
            preparationSteps: [
                "Record device axis: \(scenario.deviceAxis)",
                "Confirm permission axis: \(scenario.permissionAxis)",
                "Reserve result bundle path \(resultBundleRoot)/Bracketer-\(scenario.id)-physical.xcresult"
            ],
            captureSteps: [
                "Stage environment: \(scenario.environmentAxis)",
                "Execute capture axis: \(scenario.captureAxis)",
                "Keep Settings Device Proof, Privacy & Trust, and export policy surfaces visible for screenshots or XCTest attachments"
            ],
            evidenceSteps: [
                "Attach required evidence: \(scenario.requiredEvidence)",
                "Cross-check linked proof ids: \(scenario.linkedProofIDs.joined(separator: ", "))",
                "Extract xcresult summary and benchmark metrics before increasing any physical proof count"
            ],
            linkedProofIDs: scenario.linkedProofIDs,
            resultBundlePath: "\(resultBundleRoot)/Bracketer-\(scenario.id)-physical.xcresult",
            expectedArtifacts: expectedArtifacts(for: scenario.id),
            privacyBoundary: "Physical Capture Runbook records run steps, result bundle filenames, hashes, and notes only; it stores no Photos identifiers, image bytes, thumbnail pixels, decoded RAW data, final rendered output bytes, or precise coordinates."
        )
    }

    private static func expectedArtifacts(for scenarioID: String) -> [String] {
        switch scenarioID {
        case "dynamicRangeInteriorWindow":
            return ["project-json", "histogram-diagnostics", "capture-quality-report", "asset-resource-report", "final-output-manifest"]
        case "lensProRAWResourceSweep":
            return ["manifest-json", "capture-device-snapshot", "resource-inspection-report", "asset-resource-report", "redacted-export-bundle"]
        case "handheldMotionRecovery":
            return ["diagnostics-report", "capture-quality-report", "exposure-comparison", "side-by-side-pixel-comparison"]
        case "photosPermissionLocationSweep":
            return ["privacy-report", "location-policy-summary", "resource-inspection-report", "redacted-export-bundle"]
        case "storagePressurePartialSave":
            return ["diagnostics-report", "incomplete-project-json", "asset-resource-report", "archive-integrity-manifest"]
        case "liveFoundationModelsCoach":
            return ["runtime-diagnostic", "capture-coach-run", "generated-content-policy", "result-bundle-summary"]
        case "filesShortcutsSpotlightRoundTrip":
            return ["files-export-bytes", "shortcuts-intent-result", "spotlight-handoff-record", "archive-integrity-manifest"]
        case "multiDeviceOSRegression":
            return ["per-device-result-bundle", "capability-snapshot", "timed-diagnostics", "os-build-labels"]
        default:
            return ["result-bundle-summary", "privacy-report", "diagnostics-report"]
        }
    }
}

struct BracketerPhysicalCaptureRunbookCatalog: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let runbooks: [BracketerPhysicalCaptureRunbook]
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        runbooks: [BracketerPhysicalCaptureRunbook] = BracketerPhysicalCaptureRunbook.defaultRunbooks(),
        privacyBoundary: String = "Physical Capture Runbook Catalog is a lab handoff only; default runbooks contain zero recorded proofs and cannot satisfy the physical capture matrix without connected real-iPhone evidence."
    ) {
        self.schemaVersion = schemaVersion
        self.runbooks = runbooks
        self.privacyBoundary = privacyBoundary
    }

    static func make() -> BracketerPhysicalCaptureRunbookCatalog {
        BracketerPhysicalCaptureRunbookCatalog()
    }

    var capturedRunbookCount: Int {
        runbooks.filter(\.physicalProofCaptured).count
    }

    var requiredRunbookCount: Int {
        runbooks.count
    }

    var summaryValue: String {
        [
            "Physical Capture Runbooks",
            "\(capturedRunbookCount) of \(requiredRunbookCount) runbooks captured",
            "Real iPhone required"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            privacyBoundary,
            runbooks.map(\.accessibilityValue).joined(separator: " | ")
        ].joined(separator: " | ")
    }
}

struct BracketerPhysicalResultBundleIndex: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Identifiable, Sendable {
        let scenarioID: String
        let runbookID: String
        let resultBundleFilename: String
        let recordedAt: Date
        let deviceModel: String
        let iosBuild: String

        var id: String {
            "\(scenarioID):\(resultBundleFilename)"
        }

        var accessibilityValue: String {
            [
                "Scenario: \(scenarioID)",
                "Runbook: \(runbookID)",
                "Result bundle: \(resultBundleFilename)",
                "Device: \(deviceModel)",
                "iOS build: \(iosBuild)"
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 2

    let schemaVersion: Int
    let expectedScenarioIDs: [String]
    let entries: [Entry]
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        expectedScenarioIDs: [String],
        entries: [Entry] = [],
        privacyBoundary: String = "Physical Result Bundle Index stores filenames, device labels, and iOS build labels only; it does not store raw image bytes, Photos identifiers, thumbnail pixels, decoded RAW data, or precise coordinates."
    ) {
        self.schemaVersion = schemaVersion
        self.expectedScenarioIDs = expectedScenarioIDs
        self.entries = entries
        self.privacyBoundary = privacyBoundary
    }

    static func make(
        runbooks: [BracketerPhysicalCaptureRunbook] = BracketerPhysicalCaptureRunbook.defaultRunbooks()
    ) -> BracketerPhysicalResultBundleIndex {
        BracketerPhysicalResultBundleIndex(expectedScenarioIDs: runbooks.map(\.id))
    }

    var indexedCount: Int {
        Set(entries.map(\.scenarioID)).count
    }

    var indexedScenarioIDs: Set<String> {
        Set(entries.map(\.scenarioID))
    }

    var summaryValue: String {
        "\(indexedCount) of \(expectedScenarioIDs.count) scenario result bundles indexed"
    }

    var accessibilityValue: String {
        [
            "Physical Result Bundle Index",
            summaryValue,
            privacyBoundary,
            entries.map(\.accessibilityValue).joined(separator: " | ")
        ].joined(separator: " | ")
    }

    func adding(_ entry: Entry) -> BracketerPhysicalResultBundleIndex {
        BracketerPhysicalResultBundleIndex(
            schemaVersion: schemaVersion,
            expectedScenarioIDs: expectedScenarioIDs,
            entries: entries + [entry],
            privacyBoundary: privacyBoundary
        )
    }
}

extension BracketerPhysicalCaptureMatrix {
    static func applying(
        runbooks: [BracketerPhysicalCaptureRunbook]
    ) -> BracketerPhysicalCaptureMatrix {
        let capturedScenarioIDs = Set(
            runbooks
                .filter(\.physicalProofCaptured)
                .map(\.id)
        )
        let updatedScenarios = BracketerPhysicalCaptureMatrix.make().scenarios.map { scenario in
            Scenario(
                id: scenario.id,
                title: scenario.title,
                deviceAxis: scenario.deviceAxis,
                captureAxis: scenario.captureAxis,
                permissionAxis: scenario.permissionAxis,
                environmentAxis: scenario.environmentAxis,
                requiredEvidence: scenario.requiredEvidence,
                linkedProofIDs: scenario.linkedProofIDs,
                status: capturedScenarioIDs.contains(scenario.id) ? .physicalProofCaptured : scenario.status
            )
        }
        return BracketerPhysicalCaptureMatrix(scenarios: updatedScenarios)
    }
}

struct BracketProjectLibrarySearchRoute: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let query: String
    let smartCollectionKind: BracketProjectSmartCollection.Kind?
    let facetFilter: BracketProjectLibraryFacetFilter?
    let capturedDay: String?
    let lensID: String?
    let locationPolicyID: String?
    let resultCount: Int
    let resultProjectIDs: [String]
    let resultTitles: [String]
    let facetSummary: BracketProjectLibraryFacetSummary
    let currentProjectID: String?
    let latestProjectID: String?
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        query: String,
        smartCollectionKind: BracketProjectSmartCollection.Kind?,
        facetFilter: BracketProjectLibraryFacetFilter?,
        capturedDay: String?,
        lensID: String?,
        locationPolicyID: String?,
        resultCount: Int,
        resultProjectIDs: [String],
        resultTitles: [String],
        facetSummary: BracketProjectLibraryFacetSummary,
        currentProjectID: String?,
        latestProjectID: String?,
        privacyBoundary: String
    ) {
        self.schemaVersion = schemaVersion
        self.query = query
        self.smartCollectionKind = smartCollectionKind
        self.facetFilter = facetFilter
        self.capturedDay = BracketProjectLibraryDateFacet.normalizedDay(capturedDay)
        self.lensID = BracketProjectLibraryLensFacet.normalizedLensID(lensID)
        self.locationPolicyID = BracketProjectLibraryLocationFacet.normalizedLocationPolicyID(locationPolicyID)
        self.resultCount = resultCount
        self.resultProjectIDs = resultProjectIDs
        self.resultTitles = resultTitles
        self.facetSummary = facetSummary
        self.currentProjectID = currentProjectID
        self.latestProjectID = latestProjectID
        self.privacyBoundary = privacyBoundary
    }

    init(snapshot: BracketProjectLibrarySnapshot) {
        self.init(
            query: snapshot.query,
            smartCollectionKind: snapshot.smartCollectionKind,
            facetFilter: snapshot.facetFilter,
            capturedDay: snapshot.capturedDay,
            lensID: snapshot.lensID,
            locationPolicyID: snapshot.locationPolicyID,
            resultCount: snapshot.resultCount,
            resultProjectIDs: snapshot.projects.map(\.id),
            resultTitles: snapshot.projects.map(\.displayTitle),
            facetSummary: snapshot.facetSummary,
            currentProjectID: snapshot.currentProjectID,
            latestProjectID: snapshot.latestProjectID,
            privacyBoundary: "Metadata-only project route; no Photos local identifiers, raw photo bytes, thumbnails, precise coordinates, or filesystem package contents"
        )
    }

    static func make(
        projects: [BracketProject],
        currentProjectID: String?,
        query: String = "",
        smartCollectionKind: BracketProjectSmartCollection.Kind? = nil,
        facetFilter: BracketProjectLibraryFacetFilter? = nil,
        capturedDay: String? = nil,
        lensID: String? = nil,
        locationPolicyID: String? = nil
    ) -> BracketProjectLibrarySearchRoute {
        BracketProjectLibrarySearchRoute(
            snapshot: BracketProjectLibrarySnapshot.make(
                projects: projects,
                currentProjectID: currentProjectID,
                query: query,
                smartCollectionKind: smartCollectionKind,
                facetFilter: facetFilter,
                capturedDay: capturedDay,
                lensID: lensID,
                locationPolicyID: locationPolicyID
            )
        )
    }

    var firstResultID: String? {
        resultProjectIDs.first
    }

    var collectionTitle: String {
        smartCollectionKind?.title ?? "All Projects"
    }

    var facetTitle: String {
        facetFilter?.title ?? "All Facets"
    }

    var lensTitle: String {
        lensID ?? "All Lenses"
    }

    var locationPolicyTitle: String {
        locationPolicyID ?? "All Location Policies"
    }

    var dialogText: String {
        var parts = [
            "\(resultCount) \(resultCount == 1 ? "project" : "projects")",
            collectionTitle
        ]
        if let facetFilter {
            parts.append("facet \(facetFilter.title)")
        }
        if let capturedDay {
            parts.append("captured \(capturedDay)")
        }
        if let lensID {
            parts.append("lens \(lensID)")
        }
        if let locationPolicyID {
            parts.append("location policy \(locationPolicyID)")
        }
        if !BracketProjectSearchQuery(query).isEmpty {
            parts.append("matching \(query)")
        }
        if let first = resultTitles.first {
            parts.append("first result \(first)")
        }
        return parts.joined(separator: ", ")
    }

    var accessibilityValue: String {
        var parts = [
            "Project Search Route",
            "\(resultCount) \(resultCount == 1 ? "result" : "results")",
            "Collection \(collectionTitle)"
        ]
        if let facetFilter {
            parts.append("Facet \(facetFilter.title)")
        }
        if let capturedDay {
            parts.append("Captured Day \(capturedDay)")
        }
        if let lensID {
            parts.append("Lens \(lensID)")
        }
        if let locationPolicyID {
            parts.append("Location Policy \(locationPolicyID)")
        }
        if !BracketProjectSearchQuery(query).isEmpty {
            parts.append("Query \(query)")
        }
        if let first = resultTitles.first {
            parts.append("First \(first)")
        } else {
            parts.append("No matching projects")
        }
        parts.append(privacyBoundary)
        parts.append("Facets \(facetSummary.routeValue)")
        return parts.joined(separator: " | ")
    }
}

struct BracketProjectLibraryWorkspace: Codable, Equatable, Sendable {
    struct ProjectSummary: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let subtitle: String
        let isCurrent: Bool
        let isLatest: Bool
        let privacySummary: String
        let previewSummary: String
        let exportSummary: String
        let finalOutputActionPlanSummary: String

        init(project: BracketProject, currentProjectID: String?, latestProjectID: String?) {
            id = project.id
            title = project.displayTitle
            subtitle = project.displaySubtitle
            isCurrent = project.id == currentProjectID
            isLatest = project.id == latestProjectID
            privacySummary = project.privacy.accessibilityValue
            previewSummary = project.previewStripAccessibilityValue
            finalOutputActionPlanSummary = project.finalOutputActionPlanSummary
            exportSummary = [
                "\(project.reviewSnapshot.shotCount) planned shots",
                "\(project.reviewSnapshot.availableShotCount) available",
                "\(project.reviewSnapshot.rawAvailableCount) RAW",
                "\(project.reviewSnapshot.processedAvailableCount) processed"
            ].joined(separator: " | ")
        }

        var accessibilityValue: String {
            [
                title,
                subtitle,
                "Project \(id)",
                isCurrent ? "Current project" : nil,
                isLatest ? "Latest project" : nil,
                exportSummary,
                "Final output action plan: \(finalOutputActionPlanSummary)",
                privacySummary,
                previewSummary
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let route: BracketProjectLibrarySearchRoute
    let projectSummaries: [ProjectSummary]
    let resultLimit: Int
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        route: BracketProjectLibrarySearchRoute,
        projectSummaries: [ProjectSummary],
        resultLimit: Int,
        privacyBoundary: String
    ) {
        self.schemaVersion = schemaVersion
        self.route = route
        self.projectSummaries = projectSummaries
        self.resultLimit = max(0, resultLimit)
        self.privacyBoundary = privacyBoundary
    }

    init(snapshot: BracketProjectLibrarySnapshot, resultLimit: Int = 50) {
        let boundedLimit = max(0, resultLimit)
        let visibleProjects = Array(snapshot.projects.prefix(boundedLimit))
        self.init(
            route: BracketProjectLibrarySearchRoute(snapshot: snapshot),
            projectSummaries: visibleProjects.map {
                ProjectSummary(
                    project: $0,
                    currentProjectID: snapshot.currentProjectID,
                    latestProjectID: snapshot.latestProjectID
                )
            },
            resultLimit: boundedLimit,
            privacyBoundary: "Metadata-only archive workspace; no Photos local identifiers, raw photo bytes, thumbnails, precise coordinates, final rendered output, or filesystem package contents"
        )
    }

    var resultCount: Int {
        route.resultCount
    }

    var visibleCount: Int {
        projectSummaries.count
    }

    var hasTruncatedResults: Bool {
        visibleCount < resultCount
    }

    var accessibilityValue: String {
        var parts = [
            "Project Archive Workspace",
            "\(resultCount) \(resultCount == 1 ? "project" : "projects")",
            "Showing \(visibleCount) of \(resultCount)",
            route.accessibilityValue,
            privacyBoundary
        ]
        if hasTruncatedResults {
            parts.append("Additional projects hidden by workspace result limit \(resultLimit)")
        }
        parts.append(contentsOf: projectSummaries.map(\.accessibilityValue))
        return parts.joined(separator: " | ")
    }
}

enum BracketProjectExportPrivacyLevel: String, Codable, CaseIterable, Equatable, Sendable {
    case metadataOnly
    case recoveryIdentifiers

    var includesAssetIdentifiers: Bool {
        self == .recoveryIdentifiers
    }

    var displayName: String {
        switch self {
        case .metadataOnly:
            return "Metadata only"
        case .recoveryIdentifiers:
            return "Recovery identifiers"
        }
    }

    var policyDescription: String {
        switch self {
        case .metadataOnly:
            return "Photos local identifiers are redacted. Raw photo bytes and precise coordinates are not exported."
        case .recoveryIdentifiers:
            return "Photos local identifiers are included for recovery. Raw photo bytes and precise coordinates are not exported."
        }
    }

    var accessibilityValue: String {
        "Export privacy: \(displayName) | \(policyDescription)"
    }

    var filenameSlug: String {
        switch self {
        case .metadataOnly:
            return "metadata-only"
        case .recoveryIdentifiers:
            return "recovery-identifiers"
        }
    }
}

enum BracketProjectExportGeneratedContentPolicy: String, Codable, CaseIterable, Equatable, Sendable {
    case include
    case omit

    var includesGeneratedContent: Bool {
        self == .include
    }

    var displayName: String {
        switch self {
        case .include:
            return "Include generated"
        case .omit:
            return "Omit generated"
        }
    }

    var policyDescription: String {
        switch self {
        case .include:
            return "Exported project/sidecar carry source-disclosed generated review notes and narrative tags when present."
        case .omit:
            return "Exported project/sidecar omit generated review notes, narrative tags, and noteSource provenance. User-curated accepted tags are preserved."
        }
    }

    var accessibilityValue: String {
        "Export generated content: \(displayName) | \(policyDescription)"
    }

    var filenameSlug: String {
        switch self {
        case .include:
            return "with-generated"
        case .omit:
            return "no-generated"
        }
    }
}

enum BracketProjectExportFilenameTemplate: String, Codable, CaseIterable, Equatable, Sendable {
    case projectIdentifier
    case datedSummary
    case privacyAudit

    var displayName: String {
        switch self {
        case .projectIdentifier:
            return "Project ID"
        case .datedSummary:
            return "Dated summary"
        case .privacyAudit:
            return "Privacy audit"
        }
    }

    var description: String {
        switch self {
        case .projectIdentifier:
            return "Uses the export-safe project identifier for stable archive round trips."
        case .datedSummary:
            return "Uses capture date, shot count, source, and privacy level without Photos identifiers."
        case .privacyAudit:
            return "Uses a short privacy-report filename for compliance review handoffs."
        }
    }

    var accessibilityValue: String {
        "Export filename: \(displayName) | \(description)"
    }

    func archiveFilename(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel
    ) -> String {
        switch self {
        case .projectIdentifier:
            return "\(project.id.fileSafeIdentifier)-bracketer-project-bundle.txt"
        case .datedSummary:
            return [
                "bracketer",
                timestampSlug(for: project.manifest.capturedAt, includesTime: true),
                "\(project.reviewSnapshot.shotCount)shot",
                project.source.rawValue.fileSafeIdentifier,
                privacyLevel.filenameSlug
            ]
            .joined(separator: "-")
            .fileSafeIdentifier + ".txt"
        case .privacyAudit:
            return [
                "bracketer",
                "privacy",
                timestampSlug(for: project.manifest.capturedAt, includesTime: false),
                privacyLevel.filenameSlug,
                "schema\(project.schemaVersion)"
            ]
            .joined(separator: "-")
            .fileSafeIdentifier + ".txt"
        }
    }

    func payloadBaseName(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel
    ) -> String {
        archiveFilename(project: project, privacyLevel: privacyLevel)
            .replacingOccurrences(of: ".txt", with: "")
            .fileSafeIdentifier
    }

    private func timestampSlug(for date: Date, includesTime: Bool) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let day = String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        guard includesTime else { return day }
        return String(
            format: "%@-%02d%02d",
            day,
            components.hour ?? 0,
            components.minute ?? 0
        )
    }
}

enum BracketProjectExportPreset: String, Codable, CaseIterable, Equatable, Sendable {
    case clientHandoff
    case reviewArchive
    case recoveryArchive
    case privacyAudit

    var displayName: String {
        switch self {
        case .clientHandoff:
            return "Client Handoff"
        case .reviewArchive:
            return "Review Archive"
        case .recoveryArchive:
            return "Recovery Archive"
        case .privacyAudit:
            return "Privacy Audit"
        }
    }

    var iconName: String {
        switch self {
        case .clientHandoff:
            return "person.crop.circle.badge.checkmark"
        case .reviewArchive:
            return "archivebox"
        case .recoveryArchive:
            return "key"
        case .privacyAudit:
            return "checklist.checked"
        }
    }

    var privacyLevel: BracketProjectExportPrivacyLevel {
        switch self {
        case .clientHandoff, .reviewArchive, .privacyAudit:
            return .metadataOnly
        case .recoveryArchive:
            return .recoveryIdentifiers
        }
    }

    var filenameTemplate: BracketProjectExportFilenameTemplate {
        switch self {
        case .clientHandoff:
            return .datedSummary
        case .reviewArchive, .recoveryArchive:
            return .projectIdentifier
        case .privacyAudit:
            return .privacyAudit
        }
    }

    var generatedContentPolicy: BracketProjectExportGeneratedContentPolicy {
        switch self {
        case .clientHandoff, .privacyAudit:
            return .omit
        case .reviewArchive, .recoveryArchive:
            return .include
        }
    }

    var description: String {
        switch self {
        case .clientHandoff:
            return "Clean metadata bundle for sharing outside the app."
        case .reviewArchive:
            return "Stable local archive for repeated review and import tests."
        case .recoveryArchive:
            return "Recovery bundle that intentionally includes Photos local identifiers."
        case .privacyAudit:
            return "Metadata-only bundle named for privacy review and compliance notes."
        }
    }

    var accessibilityValue: String {
        [
            "Export preset: \(displayName)",
            privacyLevel.accessibilityValue,
            filenameTemplate.accessibilityValue,
            generatedContentPolicy.accessibilityValue,
            description
        ].joined(separator: " | ")
    }
}

enum BracketProjectImportError: LocalizedError, Equatable {
    case invalidArchiveHeader
    case malformedHeader(String)
    case unsupportedSchema(Int)
    case missingPayload(kind: String)
    case malformedPayload(String)
    case byteCountMismatch(filename: String)
    case projectIdentifierMismatch(expected: String, actual: String)
    case manifestMismatch
    case sidecarMismatch
    case contactSheetMismatch
    case contactSheetPreviewMismatch
    case contactSheetImageMismatch
    case contactSheetPDFMismatch
    case captureQualityReportMismatch
    case assetResourceReportMismatch
    case resourceInspectionReportMismatch
    case thumbnailInspectionReportMismatch
    case archiveIntegrityManifestMismatch
    case mergeReadinessReportMismatch
    case imageBundleManifestMismatch
    case imageBundleDraftPackageMismatch
    case finalOutputManifestMismatch
    case finalOutputReadinessAuditMismatch
    case finalOutputActionPlanHeaderMismatch
    case finalOutputPreviewImageMismatch
    case finalOutputDraftJPEGMismatch
    case exposureComparisonMismatch
    case sideBySidePixelComparisonMismatch
    case fusionPreviewMismatch
    case exportNoteMismatch
    case rawPhotoBytesNotSupported
    case duplicateProjectIdentifier(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchiveHeader:
            return "This is not a Bracketer project export bundle."
        case .malformedHeader(let line):
            return "The Bracketer project export bundle header is malformed: \(line)."
        case .unsupportedSchema(let schema):
            return "Bracketer project export bundle schema \(schema) is not supported."
        case .missingPayload(let kind):
            return "The Bracketer project export bundle is missing its \(kind) payload."
        case .malformedPayload(let reason):
            return "The Bracketer project export bundle payload is malformed: \(reason)."
        case .byteCountMismatch(let filename):
            return "The Bracketer project export bundle payload byte count does not match for \(filename)."
        case .projectIdentifierMismatch(let expected, let actual):
            return "The Bracketer project export bundle project identifier \(actual) does not match header \(expected)."
        case .manifestMismatch:
            return "The Bracketer project export bundle manifest does not match the project manifest."
        case .sidecarMismatch:
            return "The Bracketer project export bundle sidecar does not match the project sidecar."
        case .contactSheetMismatch:
            return "The Bracketer project export bundle contact sheet does not match the project preview facts."
        case .contactSheetPreviewMismatch:
            return "The Bracketer project export bundle contact sheet preview does not match the project preview pixels."
        case .contactSheetImageMismatch:
            return "The Bracketer project export bundle contact sheet image does not match the project preview pixels."
        case .contactSheetPDFMismatch:
            return "The Bracketer project export bundle contact sheet PDF does not match the project preview pixels."
        case .captureQualityReportMismatch:
            return "The Bracketer project export bundle capture quality report does not match the project manifest facts."
        case .assetResourceReportMismatch:
            return "The Bracketer project export bundle asset resource report does not match the project resource facts."
        case .resourceInspectionReportMismatch:
            return "The Bracketer project export bundle resource inspection report does not match the project resource metadata inspection."
        case .thumbnailInspectionReportMismatch:
            return "The Bracketer project export bundle thumbnail inspection report does not match the project thumbnail delivery metadata."
        case .archiveIntegrityManifestMismatch:
            return "The Bracketer project export bundle integrity manifest does not match the archive payloads."
        case .mergeReadinessReportMismatch:
            return "The Bracketer project export bundle merge readiness report does not match the project readiness facts."
        case .imageBundleManifestMismatch:
            return "The Bracketer project export bundle image bundle manifest does not match the project image bundle facts."
        case .imageBundleDraftPackageMismatch:
            return "The Bracketer project export bundle image bundle draft package does not match the project image bundle manifest."
        case .finalOutputManifestMismatch:
            return "The Bracketer project export bundle final output manifest does not match the project output plan facts."
        case .finalOutputReadinessAuditMismatch:
            return "The Bracketer project export bundle final output readiness audit does not match the final output manifest facts."
        case .finalOutputActionPlanHeaderMismatch:
            return "The Bracketer project export bundle final output action plan header does not match the readiness audit payload."
        case .finalOutputPreviewImageMismatch:
            return "The Bracketer project export bundle final output preview image does not match the project fusion preview."
        case .finalOutputDraftJPEGMismatch:
            return "The Bracketer project export bundle final output draft JPEG does not match the project fusion preview."
        case .exposureComparisonMismatch:
            return "The Bracketer project export bundle exposure comparison does not match the project manifest facts."
        case .sideBySidePixelComparisonMismatch:
            return "The Bracketer project export bundle side-by-side pixel comparison does not match the project review facts."
        case .fusionPreviewMismatch:
            return "The Bracketer project export bundle fusion preview does not match the project review facts."
        case .exportNoteMismatch:
            return "The Bracketer project export bundle export note does not match the project and export facts."
        case .rawPhotoBytesNotSupported:
            return "Bracketer project imports cannot contain raw photo bytes."
        case .duplicateProjectIdentifier(let id):
            return "A saved Bracketer project already uses identifier \(id)."
        }
    }
}

enum BracketProjectImportConflictPolicy: String, Codable, CaseIterable, Equatable, Sendable {
    case replaceExisting
    case keepBoth
    case rejectDuplicate

    var displayName: String {
        switch self {
        case .replaceExisting:
            return "Replace existing"
        case .keepBoth:
            return "Keep both"
        case .rejectDuplicate:
            return "Reject duplicate"
        }
    }

    var accessibilityValue: String {
        "Duplicate imports: \(displayName)"
    }
}

enum BracketProjectCurationError: LocalizedError, Equatable {
    case projectNotFound(String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Saved project \(id) could not be found for curation."
        }
    }
}

enum BracketProjectResourceInspectionUpdateError: LocalizedError, Equatable {
    case projectNotFound(String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Saved project \(id) could not be found for resource inspection."
        }
    }
}

enum BracketProjectThumbnailInspectionUpdateError: LocalizedError, Equatable {
    case projectNotFound(String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Saved project \(id) could not be found for thumbnail inspection."
        }
    }
}

struct BracketProjectContactSheet: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let captureState: String
        let fileType: String
        let availableRepresentations: [String]
        let isBestExposureCandidate: Bool
        let statusLabel: String

        var id: Int { index }

        var accessibilityValue: String {
            var parts = [
                displayLabel,
                statusLabel,
                captureState,
                fileType,
                availableRepresentations.isEmpty ? "No representation" : availableRepresentations.joined(separator: ", ")
            ]
            if isBestExposureCandidate {
                parts.append("Best exposure candidate")
            }
            return parts.joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let projectID: String
    let title: String
    let subtitle: String
    let privacyLevel: BracketProjectExportPrivacyLevel
    let privacySummary: String
    let capturedAt: Date
    let createdAt: Date
    let shotCount: Int
    let bestExposureLabel: String?
    let items: [Item]

    static func make(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel,
        createdAt: Date = Date()
    ) -> BracketProjectContactSheet {
        let items = project.previewPlaceholders.map { placeholder in
            Item(
                index: placeholder.index,
                displayLabel: placeholder.displayLabel,
                captureState: placeholder.captureState,
                fileType: placeholder.fileType,
                availableRepresentations: placeholder.availableRepresentations,
                isBestExposureCandidate: placeholder.isBestExposureCandidate,
                statusLabel: placeholder.shortStatus
            )
        }

        return BracketProjectContactSheet(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            subtitle: project.displaySubtitle,
            privacyLevel: privacyLevel,
            privacySummary: project.privacy.accessibilityValue,
            capturedAt: project.manifest.capturedAt,
            createdAt: createdAt,
            shotCount: items.count,
            bestExposureLabel: project.reviewSnapshot.bestExposureLabel,
            items: items
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectContactSheet {
        BracketProjectContactSheet(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            subtitle: subtitle,
            privacyLevel: privacyLevel,
            privacySummary: privacySummary,
            capturedAt: capturedAt,
            createdAt: createdAt,
            shotCount: shotCount,
            bestExposureLabel: bestExposureLabel,
            items: items
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        let placeholders = project.previewPlaceholders
        guard projectID == project.id,
              title == project.displayTitle,
              subtitle == project.displaySubtitle,
              shotCount == placeholders.count,
              bestExposureLabel == project.reviewSnapshot.bestExposureLabel,
              items.count == placeholders.count else {
            return false
        }

        return zip(items, placeholders).allSatisfy { item, placeholder in
            item.index == placeholder.index
                && item.displayLabel == placeholder.displayLabel
                && item.captureState == placeholder.captureState
                && item.fileType == placeholder.fileType
                && item.availableRepresentations == placeholder.availableRepresentations
                && item.isBestExposureCandidate == placeholder.isBestExposureCandidate
                && item.statusLabel == placeholder.shortStatus
        }
    }

    var accessibilityValue: String {
        [
            "Contact Sheet",
            title,
            "\(shotCount) shots",
            privacyLevel.displayName,
            bestExposureLabel.map { "Best exposure \($0)" },
            privacySummary
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }
}

struct BracketProjectContactSheetDocument: Equatable, Sendable {
    static let formatVersion = 1
    static let kind = "contact-sheet-html"
    static let mimeType = "text/html"

    static func html(contactSheet: BracketProjectContactSheet) -> String {
        let generatedAt = ISO8601DateFormatter().string(from: contactSheet.createdAt)
        let capturedAt = ISO8601DateFormatter().string(from: contactSheet.capturedAt)
        let bestExposure = contactSheet.bestExposureLabel ?? "No best exposure"
        let tiles = contactSheet.items
            .map { tileHTML(item: $0) }
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>Bracketer Contact Sheet - \(escape(contactSheet.title))</title>
        <style>
        :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
        body { margin: 32px; background: #f6f7f8; color: #111318; }
        header { border-bottom: 2px solid #111318; padding-bottom: 16px; margin-bottom: 20px; }
        h1 { font-size: 28px; margin: 0 0 6px; }
        p { margin: 4px 0; }
        .meta { color: #4a4f58; font-size: 13px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; }
        .shot { min-height: 136px; border: 1px solid #c8ccd2; border-radius: 8px; padding: 14px; background: #ffffff; }
        .shot.best { border-color: #9b7a00; box-shadow: inset 0 0 0 2px #d6ad1f; }
        .shot-index { color: #4a4f58; font-size: 12px; font-weight: 700; text-transform: uppercase; }
        .ev { font-family: "SF Mono", Menlo, monospace; font-size: 24px; font-weight: 800; margin: 8px 0; }
        .status { font-size: 13px; font-weight: 700; }
        .detail { color: #4a4f58; font-size: 12px; }
        .best-label { color: #7a5f00; font-size: 12px; font-weight: 800; }
        footer { border-top: 1px solid #c8ccd2; color: #4a4f58; font-size: 12px; margin-top: 22px; padding-top: 12px; }
        </style>
        </head>
        <body>
        <header>
        <h1>\(escape(contactSheet.title))</h1>
        <p>\(escape(contactSheet.subtitle))</p>
        <p class="meta">Project: \(escape(contactSheet.projectID))</p>
        <p class="meta">Captured: \(capturedAt) | Generated: \(generatedAt)</p>
        <p class="meta">Privacy: \(escape(contactSheet.privacyLevel.displayName)) | \(escape(contactSheet.privacySummary))</p>
        <p class="meta">Shots: \(contactSheet.shotCount) | Best exposure: \(escape(bestExposure))</p>
        </header>
        <main class="grid">
        \(tiles)
        </main>
        <footer>
        Rendered Contact Sheet v\(formatVersion). Metadata placeholders only. Raw photo bytes, thumbnails, Photos identifiers, and precise location coordinates are not included.
        </footer>
        </body>
        </html>
        """
    }

    static func matches(contents: String, contactSheet: BracketProjectContactSheet) -> Bool {
        contents == html(contactSheet: contactSheet)
    }

    private static func tileHTML(item: BracketProjectContactSheet.Item) -> String {
        let representations = item.availableRepresentations.isEmpty
            ? "No representation"
            : item.availableRepresentations.joined(separator: ", ")
        let bestClass = item.isBestExposureCandidate ? " best" : ""
        let bestLabel = item.isBestExposureCandidate
            ? "\n<p class=\"best-label\">Best exposure candidate</p>"
            : ""

        return """
        <article class="shot\(bestClass)" data-shot-index="\(item.index)">
        <div class="shot-index">Shot \(item.index + 1)</div>
        <div class="ev">\(escape(item.displayLabel))</div>
        <p class="status">\(escape(item.statusLabel))</p>
        <p class="detail">\(escape(item.captureState)) | \(escape(item.fileType))</p>
        <p class="detail">\(escape(representations))</p>\(bestLabel)
        </article>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

struct BracketProjectContactSheetPreview: Codable, Equatable, Sendable {
    struct Tile: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let captureState: String
        let width: Int
        let height: Int
        let rgbaBytes: [UInt8]
        let byteCount: Int
        let isBestExposureCandidate: Bool
        let summary: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                displayLabel,
                captureState,
                "\(width)x\(height)",
                "\(byteCount) bytes",
                isBestExposureCandidate ? "Best exposure candidate" : "Guard exposure",
                summary
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "contact-sheet-preview"
    static let source = "deterministicFixture"
    static let boundary = "Rendered contact-sheet preview from deterministic fixture pixels; not derived from private Photos bytes, thumbnails, RAW resources, or final output."
    static let colorPipeline = "sRGB RGBA8 EV-coded fixture thumbnails generated from manifest exposure offsets and capture state."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let boundary: String
    let colorPipeline: String
    let tileWidth: Int
    let tileHeight: Int
    let tileCount: Int
    let shotCount: Int
    let tiles: [Tile]

    static func make(project: BracketProject) -> BracketProjectContactSheetPreview? {
        guard !project.manifest.shots.isEmpty else { return nil }

        let width = 3
        let height = 2
        let tiles = project.manifest.shots.map { shot in
            let rgbaBytes = deterministicTileRGBABytes(
                width: width,
                height: height,
                evOffset: shot.evOffset,
                captureState: shot.captureState
            )
            return Tile(
                index: shot.index,
                displayLabel: shot.displayLabel,
                captureState: shot.captureState,
                width: width,
                height: height,
                rgbaBytes: rgbaBytes,
                byteCount: rgbaBytes.count,
                isBestExposureCandidate: shot.isBestExposureCandidate,
                summary: "\(shot.displayLabel) contact-sheet tile from deterministic fixture pixels"
            )
        }

        return BracketProjectContactSheetPreview(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            boundary: boundary,
            colorPipeline: colorPipeline,
            tileWidth: width,
            tileHeight: height,
            tileCount: tiles.count,
            shotCount: project.manifest.shots.count,
            tiles: tiles
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectContactSheetPreview {
        BracketProjectContactSheetPreview(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            source: source,
            boundary: boundary,
            colorPipeline: colorPipeline,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            tileCount: tileCount,
            shotCount: shotCount,
            tiles: tiles
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        guard let expected = BracketProjectContactSheetPreview.make(project: project) else {
            return false
        }

        return self == expected
    }

    var accessibilityValue: String {
        [
            "Contact Sheet Preview",
            title,
            "\(tileCount) tiles",
            "\(tileWidth)x\(tileHeight)",
            source,
            boundary
        ].joined(separator: " | ")
    }

    private static func deterministicTileRGBABytes(
        width: Int,
        height: Int,
        evOffset: Float,
        captureState: String
    ) -> [UInt8] {
        let pixelCount = width * height
        let ramp: [Float] = [24, 72, 120, 168, 216, 96]
        let exposureScale = pow(2.0, evOffset)
        let isMissing = captureState.localizedCaseInsensitiveContains("missing")
        let isFailed = captureState.localizedCaseInsensitiveContains("failed")

        return (0..<pixelCount).reduce(into: [UInt8]()) { bytes, index in
            let baseValue = Int((ramp[index % ramp.count] * exposureScale).rounded())
            let clipped = UInt8(clamping: baseValue)
            let red: UInt8
            let green: UInt8
            let blue: UInt8

            if isFailed {
                red = 190
                green = UInt8(clamping: Int(clipped) / 3)
                blue = 34
            } else if isMissing {
                red = 84
                green = 88
                blue = 94
            } else {
                red = clipped
                green = UInt8(clamping: Int(clipped) + (index * 4))
                blue = UInt8(clamping: (Int(clipped) / 2) + 48)
            }

            bytes.append(red)
            bytes.append(green)
            bytes.append(blue)
            bytes.append(255)
        }
    }
}

struct BracketProjectContactSheetImageDocument: Equatable, Sendable {
    struct RenderedImage: Equatable, Sendable {
        let width: Int
        let height: Int
        let rgbaBytes: [UInt8]

        var byteCount: Int {
            rgbaBytes.count
        }
    }

    static let kind = "contact-sheet-image"
    static let mimeType = "image/png"
    static let encoding = "base64"
    static let scale = 16
    static let gutter = 4
    static let border = 2
    static let boundary = "Base64 PNG contact sheet rendered from deterministic fixture pixels; not derived from private Photos bytes, thumbnails, RAW resources, or final output."

    static func renderedImage(preview: BracketProjectContactSheetPreview) -> RenderedImage? {
        guard preview.tileCount == preview.tiles.count,
              preview.tileWidth > 0,
              preview.tileHeight > 0,
              !preview.tiles.isEmpty else {
            return nil
        }

        let columns = min(3, preview.tiles.count)
        let rows = Int(ceil(Double(preview.tiles.count) / Double(columns)))
        let renderedTileWidth = (preview.tileWidth * scale) + (border * 2)
        let renderedTileHeight = (preview.tileHeight * scale) + (border * 2)
        let width = (columns * renderedTileWidth) + (max(columns - 1, 0) * gutter)
        let height = (rows * renderedTileHeight) + (max(rows - 1, 0) * gutter)
        let background: [UInt8] = [246, 247, 248, 255]
        var rgbaBytes = Array(repeating: UInt8(0), count: width * height * 4)

        for pixelIndex in 0..<(width * height) {
            let byteIndex = pixelIndex * 4
            rgbaBytes[byteIndex] = background[0]
            rgbaBytes[byteIndex + 1] = background[1]
            rgbaBytes[byteIndex + 2] = background[2]
            rgbaBytes[byteIndex + 3] = background[3]
        }

        for (tilePosition, tile) in preview.tiles.enumerated() {
            guard tile.width == preview.tileWidth,
                  tile.height == preview.tileHeight,
                  tile.byteCount == tile.rgbaBytes.count,
                  tile.rgbaBytes.count == tile.width * tile.height * 4 else {
                return nil
            }

            let row = tilePosition / columns
            let column = tilePosition % columns
            let originX = column * (renderedTileWidth + gutter)
            let originY = row * (renderedTileHeight + gutter)
            let borderColor: [UInt8] = tile.isBestExposureCandidate
                ? [214, 173, 31, 255]
                : [49, 55, 64, 255]

            for y in 0..<renderedTileHeight {
                for x in 0..<renderedTileWidth {
                    let outputX = originX + x
                    let outputY = originY + y
                    let outputIndex = ((outputY * width) + outputX) * 4
                    let isBorder = x < border
                        || y < border
                        || x >= renderedTileWidth - border
                        || y >= renderedTileHeight - border

                    if isBorder {
                        rgbaBytes[outputIndex] = borderColor[0]
                        rgbaBytes[outputIndex + 1] = borderColor[1]
                        rgbaBytes[outputIndex + 2] = borderColor[2]
                        rgbaBytes[outputIndex + 3] = borderColor[3]
                    } else {
                        let sourceX = (x - border) / scale
                        let sourceY = (y - border) / scale
                        let sourceIndex = ((sourceY * tile.width) + sourceX) * 4
                        rgbaBytes[outputIndex] = tile.rgbaBytes[sourceIndex]
                        rgbaBytes[outputIndex + 1] = tile.rgbaBytes[sourceIndex + 1]
                        rgbaBytes[outputIndex + 2] = tile.rgbaBytes[sourceIndex + 2]
                        rgbaBytes[outputIndex + 3] = tile.rgbaBytes[sourceIndex + 3]
                    }
                }
            }
        }

        return RenderedImage(width: width, height: height, rgbaBytes: rgbaBytes)
    }

    static func pngData(preview: BracketProjectContactSheetPreview) -> Data? {
        guard let renderedImage = renderedImage(preview: preview),
              let provider = CGDataProvider(data: Data(renderedImage.rgbaBytes) as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(
                width: renderedImage.width,
                height: renderedImage.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: renderedImage.width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    static func base64PNG(preview: BracketProjectContactSheetPreview) -> String? {
        pngData(preview: preview)?.base64EncodedString()
    }

    static func matches(
        base64Contents: String,
        preview: BracketProjectContactSheetPreview
    ) -> Bool {
        guard Data(base64Encoded: base64Contents) != nil,
              let expected = base64PNG(preview: preview) else {
            return false
        }

        return base64Contents == expected
    }
}

struct BracketProjectContactSheetPDFDocument: Equatable, Sendable {
    static let kind = "contact-sheet-pdf"
    static let mimeType = "application/pdf"
    static let encoding = "base64"
    static let boundary = "Base64 PDF contact sheet rendered from deterministic fixture pixels; not derived from private Photos bytes, thumbnails, RAW resources, or final output."

    static func pdfData(preview: BracketProjectContactSheetPreview) -> Data? {
        guard let renderedImage = BracketProjectContactSheetImageDocument.renderedImage(preview: preview) else {
            return nil
        }

        let content = contentStream(
            preview: preview,
            pageWidth: renderedImage.width,
            pageHeight: renderedImage.height
        )
        let objects = [
            "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
            "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
            "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(renderedImage.width) \(renderedImage.height)] /Contents 4 0 R >>\nendobj\n",
            "4 0 obj\n<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream\nendobj\n"
        ]
        var pdf = "%PDF-1.4\n% Bracketer deterministic contact sheet\n"
        var offsets: [Int] = []

        for object in objects {
            offsets.append(pdf.utf8.count)
            pdf += object
        }

        let xrefOffset = pdf.utf8.count
        pdf += "xref\n"
        pdf += "0 \(objects.count + 1)\n"
        pdf += "0000000000 65535 f \n"
        for offset in offsets {
            pdf += String(format: "%010d 00000 n \n", offset)
        }
        pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\n"
        pdf += "startxref\n\(xrefOffset)\n%%EOF\n"

        return Data(pdf.utf8)
    }

    static func base64PDF(preview: BracketProjectContactSheetPreview) -> String? {
        pdfData(preview: preview)?.base64EncodedString()
    }

    static func matches(
        base64Contents: String,
        preview: BracketProjectContactSheetPreview
    ) -> Bool {
        guard Data(base64Encoded: base64Contents) != nil,
              let expected = base64PDF(preview: preview) else {
            return false
        }

        return base64Contents == expected
    }

    private static func contentStream(
        preview: BracketProjectContactSheetPreview,
        pageWidth: Int,
        pageHeight: Int
    ) -> String {
        let columns = min(3, preview.tiles.count)
        let renderedTileWidth = (preview.tileWidth * BracketProjectContactSheetImageDocument.scale)
            + (BracketProjectContactSheetImageDocument.border * 2)
        let renderedTileHeight = (preview.tileHeight * BracketProjectContactSheetImageDocument.scale)
            + (BracketProjectContactSheetImageDocument.border * 2)
        var commands = [
            "q",
            "0.965 0.969 0.973 rg",
            "0 0 \(pageWidth) \(pageHeight) re f"
        ]

        func rect(
            x: Int,
            yFromTop: Int,
            width: Int,
            height: Int,
            red: UInt8,
            green: UInt8,
            blue: UInt8
        ) {
            let pdfY = pageHeight - yFromTop - height
            commands.append("\(component(red)) \(component(green)) \(component(blue)) rg")
            commands.append("\(x) \(pdfY) \(width) \(height) re f")
        }

        for (tilePosition, tile) in preview.tiles.enumerated() {
            let row = tilePosition / columns
            let column = tilePosition % columns
            let originX = column * (renderedTileWidth + BracketProjectContactSheetImageDocument.gutter)
            let originY = row * (renderedTileHeight + BracketProjectContactSheetImageDocument.gutter)
            let borderColor: (UInt8, UInt8, UInt8) = tile.isBestExposureCandidate
                ? (214, 173, 31)
                : (49, 55, 64)

            rect(
                x: originX,
                yFromTop: originY,
                width: renderedTileWidth,
                height: renderedTileHeight,
                red: borderColor.0,
                green: borderColor.1,
                blue: borderColor.2
            )

            for sourceY in 0..<tile.height {
                for sourceX in 0..<tile.width {
                    let sourceIndex = ((sourceY * tile.width) + sourceX) * 4
                    rect(
                        x: originX + BracketProjectContactSheetImageDocument.border
                            + (sourceX * BracketProjectContactSheetImageDocument.scale),
                        yFromTop: originY + BracketProjectContactSheetImageDocument.border
                            + (sourceY * BracketProjectContactSheetImageDocument.scale),
                        width: BracketProjectContactSheetImageDocument.scale,
                        height: BracketProjectContactSheetImageDocument.scale,
                        red: tile.rgbaBytes[sourceIndex],
                        green: tile.rgbaBytes[sourceIndex + 1],
                        blue: tile.rgbaBytes[sourceIndex + 2]
                    )
                }
            }
        }

        commands.append("Q")
        return commands.joined(separator: "\n") + "\n"
    }

    private static func component(_ value: UInt8) -> String {
        String(format: "%.3f", Double(value) / 255.0)
    }
}

struct BracketProjectCaptureQualityReport: Codable, Equatable, Sendable {
    struct Finding: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let severity: String
        let title: String
        let detail: String
        let recommendation: String

        var accessibilityValue: String {
            [severity, title, detail, recommendation].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "capture-quality-report"
    static let boundary = "Manifest-backed capture quality report; does not inspect private Photos bytes, sharpness, alignment, ghosting, or physical asset availability."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let boundary: String
    let shotCount: Int
    let availableShotCount: Int
    let missingShotCount: Int
    let failedShotCount: Int
    let evSpread: Float
    let highlightGuardCount: Int
    let shadowGuardCount: Int
    let rawAvailableCount: Int
    let processedAvailableCount: Int
    let readinessScore: Int
    let readinessLabel: String
    let findings: [Finding]
    let recommendations: [String]

    static func make(project: BracketProject) -> BracketProjectCaptureQualityReport {
        let shots = project.manifest.shots
        let availableShots = shots.filter { isAvailable($0) }
        let missingShotCount = shots.filter { $0.captureState.localizedCaseInsensitiveContains("missing") }.count
        let failedShotCount = shots.filter { $0.captureState.localizedCaseInsensitiveContains("failed") }.count
        let evOffsets = shots.map(\.evOffset)
        let evSpread = (evOffsets.max() ?? 0) - (evOffsets.min() ?? 0)
        let baselineEV = shots.first(where: \.isBestExposureCandidate)?.evOffset
            ?? shots.min { abs($0.evOffset) < abs($1.evOffset) }?.evOffset
            ?? 0
        let highlightGuardCount = availableShots.filter { $0.evOffset < baselineEV }.count
        let shadowGuardCount = availableShots.filter { $0.evOffset > baselineEV }.count
        let rawAvailableCount = availableShots.filter { shot in
            shot.availableRepresentations.contains { $0.localizedCaseInsensitiveContains("raw") }
        }.count
        let processedAvailableCount = availableShots.filter { shot in
            shot.availableRepresentations.contains { representation in
                representation.localizedCaseInsensitiveContains("processed")
                    || representation.localizedCaseInsensitiveContains("jpeg")
                    || representation.localizedCaseInsensitiveContains("heif")
            }
        }.count
        let readinessScore = readinessScore(
            shotCount: shots.count,
            missingShotCount: missingShotCount,
            failedShotCount: failedShotCount,
            evSpread: evSpread,
            highlightGuardCount: highlightGuardCount,
            shadowGuardCount: shadowGuardCount
        )
        let findings = findings(
            shotCount: shots.count,
            availableShotCount: availableShots.count,
            missingShotCount: missingShotCount,
            failedShotCount: failedShotCount,
            evSpread: evSpread,
            highlightGuardCount: highlightGuardCount,
            shadowGuardCount: shadowGuardCount,
            rawAvailableCount: rawAvailableCount
        )
        let recommendations = findings.map(\.recommendation)

        return BracketProjectCaptureQualityReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            boundary: boundary,
            shotCount: shots.count,
            availableShotCount: availableShots.count,
            missingShotCount: missingShotCount,
            failedShotCount: failedShotCount,
            evSpread: evSpread,
            highlightGuardCount: highlightGuardCount,
            shadowGuardCount: shadowGuardCount,
            rawAvailableCount: rawAvailableCount,
            processedAvailableCount: processedAvailableCount,
            readinessScore: readinessScore,
            readinessLabel: readinessLabel(score: readinessScore),
            findings: findings,
            recommendations: recommendations
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectCaptureQualityReport {
        BracketProjectCaptureQualityReport(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            boundary: boundary,
            shotCount: shotCount,
            availableShotCount: availableShotCount,
            missingShotCount: missingShotCount,
            failedShotCount: failedShotCount,
            evSpread: evSpread,
            highlightGuardCount: highlightGuardCount,
            shadowGuardCount: shadowGuardCount,
            rawAvailableCount: rawAvailableCount,
            processedAvailableCount: processedAvailableCount,
            readinessScore: readinessScore,
            readinessLabel: readinessLabel,
            findings: findings,
            recommendations: recommendations
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectCaptureQualityReport.make(project: project)
    }

    var accessibilityValue: String {
        [
            "Capture Quality",
            title,
            "\(availableShotCount) of \(shotCount) available",
            "Score \(readinessScore)",
            readinessLabel,
            "Highlight guards \(highlightGuardCount)",
            "Shadow guards \(shadowGuardCount)",
            boundary
        ].joined(separator: " | ")
    }

    private static func isAvailable(_ shot: BracketManifest.Shot) -> Bool {
        shot.captureState.localizedCaseInsensitiveContains("available")
    }

    private static func readinessScore(
        shotCount: Int,
        missingShotCount: Int,
        failedShotCount: Int,
        evSpread: Float,
        highlightGuardCount: Int,
        shadowGuardCount: Int
    ) -> Int {
        var score = 100
        score -= missingShotCount * 25
        score -= failedShotCount * 25
        if shotCount > 1 && evSpread < 2 {
            score -= 15
        }
        if highlightGuardCount == 0 {
            score -= 15
        }
        if shadowGuardCount == 0 {
            score -= 15
        }
        return min(100, max(0, score))
    }

    private static func readinessLabel(score: Int) -> String {
        if score >= 85 {
            return "Ready for careful review"
        }
        if score >= 60 {
            return "Review before export"
        }
        return "Recovery recommended"
    }

    private static func findings(
        shotCount: Int,
        availableShotCount: Int,
        missingShotCount: Int,
        failedShotCount: Int,
        evSpread: Float,
        highlightGuardCount: Int,
        shadowGuardCount: Int,
        rawAvailableCount: Int
    ) -> [Finding] {
        var findings: [Finding] = []

        if availableShotCount == shotCount, missingShotCount == 0, failedShotCount == 0 {
            findings.append(
                Finding(
                    id: "sequence-complete",
                    severity: "Info",
                    title: "Bracket sequence complete",
                    detail: "\(availableShotCount) of \(shotCount) planned shots are marked available in the manifest.",
                    recommendation: "Proceed to review exposure guards before export."
                )
            )
        }
        if missingShotCount > 0 {
            findings.append(
                Finding(
                    id: "missing-shots",
                    severity: "Warning",
                    title: "Missing planned exposures",
                    detail: "\(missingShotCount) planned shots have no saved asset in the manifest.",
                    recommendation: "Recover from Photos if possible or reshoot before relying on this bracket."
                )
            )
        }
        if failedShotCount > 0 {
            findings.append(
                Finding(
                    id: "failed-shots",
                    severity: "Warning",
                    title: "Failed exposures",
                    detail: "\(failedShotCount) shots are marked failed in the manifest.",
                    recommendation: "Inspect diagnostics and exclude failed shots from merge decisions."
                )
            )
        }
        if evSpread < 2 {
            findings.append(
                Finding(
                    id: "narrow-ev-spread",
                    severity: "Caution",
                    title: "Narrow exposure coverage",
                    detail: "The manifest EV spread is \(evSpread) stops.",
                    recommendation: "Use a wider bracket for high-contrast scenes."
                )
            )
        }
        if highlightGuardCount == 0 {
            findings.append(
                Finding(
                    id: "missing-highlight-guard",
                    severity: "Caution",
                    title: "No darker highlight guard",
                    detail: "No available exposure is darker than the selected baseline.",
                    recommendation: "Capture a darker guard frame when highlight recovery matters."
                )
            )
        }
        if shadowGuardCount == 0 {
            findings.append(
                Finding(
                    id: "missing-shadow-guard",
                    severity: "Caution",
                    title: "No brighter shadow guard",
                    detail: "No available exposure is brighter than the selected baseline.",
                    recommendation: "Capture a brighter guard frame when shadow recovery matters."
                )
            )
        }
        if rawAvailableCount == 0 {
            findings.append(
                Finding(
                    id: "no-raw-summary",
                    severity: "Info",
                    title: "No RAW representation in manifest",
                    detail: "The manifest does not list RAW availability for any available shot.",
                    recommendation: "Treat this as a processed-output bracket unless Photos resources prove otherwise."
                )
            )
        }

        return findings
    }
}

struct BracketProjectThumbnailInspection: Codable, Equatable, Sendable {
    enum Source: String, Codable, Equatable, Sendable {
        case photosImageManager
        case syntheticFixture
        case importedSummary

        var displayName: String {
            switch self {
            case .photosImageManager:
                return "Photos image manager thumbnails"
            case .syntheticFixture:
                return "Synthetic thumbnail fixture"
            case .importedSummary:
                return "Imported thumbnail summary"
            }
        }

        var boundary: String {
            switch self {
            case .photosImageManager:
                return "Photos thumbnail delivery metadata; records requested size, delivered dimensions, and delivery flags only. It does not store thumbnail pixels, raw photo bytes, files, or decoded RAW containers."
            case .syntheticFixture:
                return "Synthetic thumbnail delivery fixture for tests; no physical Photos thumbnails, image bytes, files, or device assets were inspected."
            case .importedSummary:
                return "Imported thumbnail delivery summary; records declared thumbnail facts only and does not prove physical asset availability."
            }
        }
    }

    struct ShotThumbnail: Codable, Equatable, Sendable {
        let index: Int
        let assetIdentifier: String?
        let targetPixelWidth: Int
        let targetPixelHeight: Int
        let deliveredPixelWidth: Int?
        let deliveredPixelHeight: Int?
        let deliveryMode: String
        let contentMode: String
        let isDegraded: Bool
        let isCloudBacked: Bool
        let wasCancelled: Bool
        let errorDescription: String?

        init(
            index: Int,
            assetIdentifier: String?,
            targetPixelWidth: Int,
            targetPixelHeight: Int,
            deliveredPixelWidth: Int?,
            deliveredPixelHeight: Int?,
            deliveryMode: String,
            contentMode: String,
            isDegraded: Bool = false,
            isCloudBacked: Bool = false,
            wasCancelled: Bool = false,
            errorDescription: String? = nil
        ) {
            self.index = index
            self.assetIdentifier = assetIdentifier
            self.targetPixelWidth = targetPixelWidth
            self.targetPixelHeight = targetPixelHeight
            self.deliveredPixelWidth = deliveredPixelWidth
            self.deliveredPixelHeight = deliveredPixelHeight
            self.deliveryMode = deliveryMode
            self.contentMode = contentMode
            self.isDegraded = isDegraded
            self.isCloudBacked = isCloudBacked
            self.wasCancelled = wasCancelled
            self.errorDescription = errorDescription
        }
    }

    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let assetIdentifier: String?
        let targetPixelWidth: Int
        let targetPixelHeight: Int
        let deliveredPixelWidth: Int?
        let deliveredPixelHeight: Int?
        let deliveryMode: String
        let contentMode: String
        let isDegraded: Bool
        let isCloudBacked: Bool
        let wasCancelled: Bool
        let errorDescription: String?
        let resultState: String
        let recommendation: String

        var id: Int { index }

        var deliveredPixelLabel: String {
            guard let deliveredPixelWidth, let deliveredPixelHeight else {
                return "No delivered pixels"
            }
            return "\(deliveredPixelWidth)x\(deliveredPixelHeight) delivered pixels"
        }

        var accessibilityValue: String {
            [
                displayLabel,
                resultState,
                "\(targetPixelWidth)x\(targetPixelHeight) requested pixels",
                deliveredPixelLabel,
                "Delivery \(deliveryMode)",
                "Content \(contentMode)",
                isDegraded ? "Degraded result" : "Final quality result",
                isCloudBacked ? "Cloud-backed asset" : "Local asset",
                wasCancelled ? "Request cancelled" : "Request not cancelled",
                assetIdentifier == nil ? "No recovery identifier" : "Recovery identifier present",
                errorDescription.map { "Error \($0)" },
                recommendation
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        }

        var searchTokens: [String] {
            [
                displayLabel,
                resultState,
                "\(targetPixelWidth)x\(targetPixelHeight)",
                deliveredPixelWidth.zip(deliveredPixelHeight).map { "\($0)x\($1)" } ?? "",
                deliveryMode,
                contentMode,
                isDegraded ? "degraded thumbnail" : "final thumbnail",
                isCloudBacked ? "cloud thumbnail" : "local thumbnail",
                wasCancelled ? "cancelled thumbnail request" : "completed thumbnail request",
                errorDescription ?? "",
                recommendation
            ]
            .flatMap { $0.searchTokenComponents }
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let source: Source
    let inspectedAt: Date
    let boundary: String
    let items: [Item]

    static func make(
        project: BracketProject,
        source: Source,
        inspectedAt: Date = Date(),
        shotThumbnails: [ShotThumbnail]
    ) -> BracketProjectThumbnailInspection {
        let thumbnailsByIndex = Dictionary(uniqueKeysWithValues: shotThumbnails.map { ($0.index, $0) })
        let assetByIndex = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.index, $0) })
        let items = project.manifest.shots.map { shot in
            let asset = assetByIndex[shot.index]
            let thumbnail = thumbnailsByIndex[shot.index]
            let resultState = resultState(thumbnail)

            return Item(
                index: shot.index,
                displayLabel: asset?.displayLabel ?? shot.displayLabel,
                assetIdentifier: thumbnail?.assetIdentifier ?? asset?.assetIdentifier ?? shot.assetIdentifier,
                targetPixelWidth: thumbnail?.targetPixelWidth ?? 0,
                targetPixelHeight: thumbnail?.targetPixelHeight ?? 0,
                deliveredPixelWidth: thumbnail?.deliveredPixelWidth,
                deliveredPixelHeight: thumbnail?.deliveredPixelHeight,
                deliveryMode: thumbnail?.deliveryMode ?? "not-requested",
                contentMode: thumbnail?.contentMode ?? "not-requested",
                isDegraded: thumbnail?.isDegraded ?? false,
                isCloudBacked: thumbnail?.isCloudBacked ?? false,
                wasCancelled: thumbnail?.wasCancelled ?? false,
                errorDescription: thumbnail?.errorDescription,
                resultState: resultState,
                recommendation: recommendation(resultState: resultState)
            )
        }

        return BracketProjectThumbnailInspection(
            schemaVersion: schemaVersion,
            source: source,
            inspectedAt: inspectedAt,
            boundary: source.boundary,
            items: items
        )
    }

    func replacingShotThumbnail(
        _ shotThumbnail: ShotThumbnail,
        in project: BracketProject,
        source: Source = .photosImageManager,
        inspectedAt: Date = Date()
    ) -> BracketProjectThumbnailInspection {
        var thumbnailsByIndex: [Int: ShotThumbnail] = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (Int, ShotThumbnail)? in
            guard item.targetPixelWidth > 0 || item.targetPixelHeight > 0 || item.deliveredPixelWidth != nil
                    || item.deliveredPixelHeight != nil || item.errorDescription != nil || item.wasCancelled else {
                return nil
            }
            return (
                item.index,
                ShotThumbnail(
                    index: item.index,
                    assetIdentifier: item.assetIdentifier,
                    targetPixelWidth: item.targetPixelWidth,
                    targetPixelHeight: item.targetPixelHeight,
                    deliveredPixelWidth: item.deliveredPixelWidth,
                    deliveredPixelHeight: item.deliveredPixelHeight,
                    deliveryMode: item.deliveryMode,
                    contentMode: item.contentMode,
                    isDegraded: item.isDegraded,
                    isCloudBacked: item.isCloudBacked,
                    wasCancelled: item.wasCancelled,
                    errorDescription: item.errorDescription
                )
            )
        })
        thumbnailsByIndex[shotThumbnail.index] = shotThumbnail
        let mergedThumbnails = project.manifest.shots.compactMap { shot in
            thumbnailsByIndex[shot.index]
        }

        return BracketProjectThumbnailInspection.make(
            project: project,
            source: source,
            inspectedAt: inspectedAt,
            shotThumbnails: mergedThumbnails
        )
    }

    func exportCopy(includingAssetIdentifiers: Bool) -> BracketProjectThumbnailInspection {
        BracketProjectThumbnailInspection(
            schemaVersion: schemaVersion,
            source: source,
            inspectedAt: inspectedAt,
            boundary: boundary,
            items: items.map { item in
                Item(
                    index: item.index,
                    displayLabel: item.displayLabel,
                    assetIdentifier: includingAssetIdentifiers ? item.assetIdentifier : nil,
                    targetPixelWidth: item.targetPixelWidth,
                    targetPixelHeight: item.targetPixelHeight,
                    deliveredPixelWidth: item.deliveredPixelWidth,
                    deliveredPixelHeight: item.deliveredPixelHeight,
                    deliveryMode: item.deliveryMode,
                    contentMode: item.contentMode,
                    isDegraded: item.isDegraded,
                    isCloudBacked: item.isCloudBacked,
                    wasCancelled: item.wasCancelled,
                    errorDescription: item.errorDescription,
                    resultState: item.resultState,
                    recommendation: item.recommendation
                )
            }
        )
    }

    var searchTokens: [String] {
        (
            [
                source.displayName,
                boundary,
                "thumbnail inspection",
                "thumbnail delivery metadata"
            ]
            + items.flatMap(\.searchTokens)
        )
        .flatMap { $0.searchTokenComponents }
        .uniquePreservingOrder()
    }

    private static func resultState(_ thumbnail: ShotThumbnail?) -> String {
        guard let thumbnail else { return "not-requested" }
        if thumbnail.wasCancelled { return "request-cancelled" }
        if thumbnail.errorDescription != nil { return "thumbnail-error" }
        if thumbnail.deliveredPixelWidth == nil || thumbnail.deliveredPixelHeight == nil {
            return "thumbnail-missing"
        }
        if thumbnail.isDegraded { return "degraded-thumbnail-delivered" }
        if thumbnail.isCloudBacked { return "cloud-backed-thumbnail-delivered" }
        return "thumbnail-delivered"
    }

    private static func recommendation(resultState: String) -> String {
        switch resultState {
        case "thumbnail-delivered":
            return "Photos delivered review thumbnail metadata for this shot without storing pixels."
        case "cloud-backed-thumbnail-delivered":
            return "Photos delivered thumbnail metadata, but the source was cloud-backed; verify availability before offline handoff."
        case "degraded-thumbnail-delivered":
            return "Only a degraded thumbnail callback has been recorded so far; reopen review for a final-quality callback."
        case "thumbnail-missing":
            return "Photos returned no thumbnail image for this shot."
        case "thumbnail-error":
            return "Photos thumbnail delivery reported an error; inspect diagnostics before export."
        case "request-cancelled":
            return "Photos thumbnail request was cancelled before final delivery."
        default:
            return "No thumbnail request metadata has been recorded for this shot."
        }
    }
}

struct BracketProjectThumbnailInspectionReport: Codable, Equatable, Sendable {
    static let kind = "thumbnail-inspection-report"

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let inspectedAt: Date
    let boundary: String
    let shotCount: Int
    let requestedShotCount: Int
    let deliveredShotCount: Int
    let degradedShotCount: Int
    let cloudBackedShotCount: Int
    let errorShotCount: Int
    let items: [BracketProjectThumbnailInspection.Item]

    static func make(project: BracketProject) -> BracketProjectThumbnailInspectionReport? {
        guard let inspection = project.thumbnailInspection else { return nil }
        return BracketProjectThumbnailInspectionReport(
            schemaVersion: BracketProjectThumbnailInspection.schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: inspection.source.displayName,
            inspectedAt: inspection.inspectedAt,
            boundary: inspection.boundary,
            shotCount: project.manifest.shots.count,
            requestedShotCount: inspection.items.filter { $0.resultState != "not-requested" }.count,
            deliveredShotCount: inspection.items.filter {
                $0.deliveredPixelWidth != nil && $0.deliveredPixelHeight != nil
            }.count,
            degradedShotCount: inspection.items.filter(\.isDegraded).count,
            cloudBackedShotCount: inspection.items.filter(\.isCloudBacked).count,
            errorShotCount: inspection.items.filter {
                $0.resultState == "thumbnail-error" || $0.resultState == "request-cancelled"
            }.count,
            items: inspection.items
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectThumbnailInspectionReport {
        BracketProjectThumbnailInspectionReport(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            source: source,
            inspectedAt: inspectedAt,
            boundary: boundary,
            shotCount: shotCount,
            requestedShotCount: requestedShotCount,
            deliveredShotCount: deliveredShotCount,
            degradedShotCount: degradedShotCount,
            cloudBackedShotCount: cloudBackedShotCount,
            errorShotCount: errorShotCount,
            items: items
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectThumbnailInspectionReport.make(project: project)
    }

    var accessibilityValue: String {
        [
            "Thumbnail Inspection",
            title,
            source,
            "\(requestedShotCount) requested shots",
            "\(deliveredShotCount) delivered thumbnails",
            "\(degradedShotCount) degraded callbacks",
            "\(cloudBackedShotCount) cloud-backed callbacks",
            "\(errorShotCount) errors",
            boundary
        ].joined(separator: " | ")
    }
}

private extension Optional where Wrapped == Int {
    func zip(_ other: Int?) -> (Int, Int)? {
        guard let self, let other else { return nil }
        return (self, other)
    }
}

struct BracketProjectResourceInspection: Codable, Equatable, Sendable {
    enum Source: String, Codable, Equatable, Sendable {
        case photosAssetResource
        case syntheticFixture
        case importedSummary

        var displayName: String {
            switch self {
            case .photosAssetResource:
                return "Photos asset resources"
            case .syntheticFixture:
                return "Synthetic resource fixture"
            case .importedSummary:
                return "Imported resource summary"
            }
        }

        var boundary: String {
            switch self {
            case .photosAssetResource:
                return "Photos resource metadata inspection; records resource type, filename, and UTI only. It does not read image bytes, open files, decode RAW containers, or prove pixel correctness."
            case .syntheticFixture:
                return "Synthetic resource metadata fixture for tests; no physical Photos resources, image bytes, files, or device assets were inspected."
            case .importedSummary:
                return "Imported resource metadata summary; records declared resource facts only and does not prove physical asset availability."
            }
        }
    }

    struct Resource: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let resourceType: String
        let originalFilename: String
        let uniformTypeIdentifier: String?

        init(
            id: String? = nil,
            resourceType: String,
            originalFilename: String,
            uniformTypeIdentifier: String? = nil
        ) {
            self.resourceType = resourceType
            self.originalFilename = originalFilename
            self.uniformTypeIdentifier = uniformTypeIdentifier
            self.id = id ?? "\(resourceType)-\(originalFilename)-\(uniformTypeIdentifier ?? "unknown")"
                .fileSafeIdentifier
        }

        var representationLabel: String? {
            if isRaw { return "RAW" }
            if isProcessed { return "Processed" }
            return nil
        }

        var searchTokens: [String] {
            [
                resourceType,
                originalFilename,
                uniformTypeIdentifier ?? "",
                representationLabel ?? "unclassified-resource"
            ].flatMap { $0.searchTokenComponents }
        }

        private var isRaw: Bool {
            let filename = originalFilename.lowercased()
            let uti = uniformTypeIdentifier?.lowercased() ?? ""
            let type = resourceType.lowercased()
            return type.contains("alternate")
                || type.contains("raw")
                || uti.contains("raw")
                || uti.contains("dng")
                || filename.hasSuffix(".dng")
                || filename.hasSuffix(".raw")
        }

        private var isProcessed: Bool {
            let filename = originalFilename.lowercased()
            let uti = uniformTypeIdentifier?.lowercased() ?? ""
            let type = resourceType.lowercased()
            return type == "photo"
                || type.contains("fullsizephoto")
                || type.contains("full size photo")
                || type.contains("processed")
                || uti.contains("heic")
                || uti.contains("heif")
                || uti.contains("jpeg")
                || filename.hasSuffix(".heic")
                || filename.hasSuffix(".heif")
                || filename.hasSuffix(".jpg")
                || filename.hasSuffix(".jpeg")
        }
    }

    struct ShotResources: Codable, Equatable, Sendable {
        let index: Int
        let assetIdentifier: String?
        let resources: [Resource]

        init(
            index: Int,
            assetIdentifier: String?,
            resources: [Resource]
        ) {
            self.index = index
            self.assetIdentifier = assetIdentifier
            self.resources = resources
        }
    }

    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let assetIdentifier: String?
        let manifestFileType: String
        let manifestRepresentations: [String]
        let resources: [Resource]
        let inspectedRepresentationLabels: [String]
        let rawResourceCount: Int
        let processedResourceCount: Int
        let resourceState: String
        let mismatchLabels: [String]
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                displayLabel,
                resourceState,
                "\(resources.count) resources",
                "RAW resources \(rawResourceCount)",
                "Processed resources \(processedResourceCount)",
                assetIdentifier == nil ? "No recovery identifier" : "Recovery identifier present",
                mismatchLabels.isEmpty ? "No resource mismatch" : "Mismatch \(mismatchLabels.joined(separator: ", "))",
                recommendation
            ].joined(separator: " | ")
        }

        var searchTokens: [String] {
            (
                [
                    displayLabel,
                    manifestFileType,
                    resourceState,
                    recommendation
                ]
                + manifestRepresentations
                + inspectedRepresentationLabels
                + mismatchLabels
                + resources.flatMap(\.searchTokens)
            )
            .flatMap { $0.searchTokenComponents }
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let source: Source
    let inspectedAt: Date
    let boundary: String
    let items: [Item]

    static func make(
        project: BracketProject,
        source: Source,
        inspectedAt: Date = Date(),
        shotResources: [ShotResources]
    ) -> BracketProjectResourceInspection {
        let resourcesByIndex = Dictionary(uniqueKeysWithValues: shotResources.map { ($0.index, $0) })
        let assetByIndex = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.index, $0) })
        let items = project.manifest.shots.map { shot in
            let asset = assetByIndex[shot.index]
            let inspected = resourcesByIndex[shot.index]
            let resources = inspected?.resources ?? []
            let inspectedLabels = resources
                .compactMap(\.representationLabel)
                .uniquePreservingOrder()
            let rawResourceCount = inspectedLabels.contains("RAW")
                ? resources.filter { $0.representationLabel == "RAW" }.count
                : 0
            let processedResourceCount = inspectedLabels.contains("Processed")
                ? resources.filter { $0.representationLabel == "Processed" }.count
                : 0
            let manifestRepresentations = asset?.availableRepresentations ?? shot.availableRepresentations
            let expectedLabels = expectedRepresentationLabels(
                fileType: asset?.fileType ?? shot.fileType,
                manifestRepresentations: manifestRepresentations
            )
            let mismatchLabels = resources.isEmpty ? [] : mismatchLabels(
                expectedLabels: expectedLabels,
                inspectedLabels: inspectedLabels
            )
            let resourceState = resourceState(
                resourceCount: resources.count,
                rawResourceCount: rawResourceCount,
                processedResourceCount: processedResourceCount,
                mismatchLabels: mismatchLabels
            )

            return Item(
                index: shot.index,
                displayLabel: asset?.displayLabel ?? shot.displayLabel,
                assetIdentifier: inspected?.assetIdentifier ?? asset?.assetIdentifier ?? shot.assetIdentifier,
                manifestFileType: asset?.fileType ?? shot.fileType,
                manifestRepresentations: manifestRepresentations,
                resources: resources,
                inspectedRepresentationLabels: inspectedLabels,
                rawResourceCount: rawResourceCount,
                processedResourceCount: processedResourceCount,
                resourceState: resourceState,
                mismatchLabels: mismatchLabels,
                recommendation: recommendation(
                    resourceState: resourceState,
                    mismatchLabels: mismatchLabels
                )
            )
        }

        return BracketProjectResourceInspection(
            schemaVersion: schemaVersion,
            source: source,
            inspectedAt: inspectedAt,
            boundary: source.boundary,
            items: items
        )
    }

    func replacingShotResources(
        _ shotResources: ShotResources,
        in project: BracketProject,
        source: Source = .photosAssetResource,
        inspectedAt: Date = Date()
    ) -> BracketProjectResourceInspection {
        var resourcesByIndex = Dictionary(uniqueKeysWithValues: items.map { item in
            (
                item.index,
                ShotResources(
                    index: item.index,
                    assetIdentifier: item.assetIdentifier,
                    resources: item.resources
                )
            )
        })
        resourcesByIndex[shotResources.index] = shotResources
        let mergedResources = project.manifest.shots.map { shot in
            resourcesByIndex[shot.index] ?? ShotResources(
                index: shot.index,
                assetIdentifier: shot.assetIdentifier,
                resources: []
            )
        }

        return BracketProjectResourceInspection.make(
            project: project,
            source: source,
            inspectedAt: inspectedAt,
            shotResources: mergedResources
        )
    }

    func exportCopy(includingAssetIdentifiers: Bool) -> BracketProjectResourceInspection {
        BracketProjectResourceInspection(
            schemaVersion: schemaVersion,
            source: source,
            inspectedAt: inspectedAt,
            boundary: boundary,
            items: items.map { item in
                Item(
                    index: item.index,
                    displayLabel: item.displayLabel,
                    assetIdentifier: includingAssetIdentifiers ? item.assetIdentifier : nil,
                    manifestFileType: item.manifestFileType,
                    manifestRepresentations: item.manifestRepresentations,
                    resources: item.resources,
                    inspectedRepresentationLabels: item.inspectedRepresentationLabels,
                    rawResourceCount: item.rawResourceCount,
                    processedResourceCount: item.processedResourceCount,
                    resourceState: item.resourceState,
                    mismatchLabels: item.mismatchLabels,
                    recommendation: item.recommendation
                )
            }
        )
    }

    var searchTokens: [String] {
        (
            [
                source.displayName,
                boundary
            ]
            + items.flatMap(\.searchTokens)
        )
        .flatMap { $0.searchTokenComponents }
        .uniquePreservingOrder()
    }

    private static func expectedRepresentationLabels(
        fileType: String,
        manifestRepresentations: [String]
    ) -> [String] {
        var labels: [String] = []
        let rawSignals = manifestRepresentations + [fileType]
        if rawSignals.contains(where: { label in
            label.localizedCaseInsensitiveContains("raw")
                || label.localizedCaseInsensitiveContains("dng")
                || label.localizedCaseInsensitiveContains("proraw")
        }) {
            labels.append("RAW")
        }
        if rawSignals.contains(where: { label in
            label.localizedCaseInsensitiveContains("processed")
                || label.localizedCaseInsensitiveContains("jpeg")
                || label.localizedCaseInsensitiveContains("jpg")
                || label.localizedCaseInsensitiveContains("heif")
                || label.localizedCaseInsensitiveContains("heic")
        }) {
            labels.append("Processed")
        }
        return labels
    }

    private static func mismatchLabels(
        expectedLabels: [String],
        inspectedLabels: [String]
    ) -> [String] {
        var labels: [String] = []
        for expected in expectedLabels where !inspectedLabels.contains(expected) {
            labels.append("Expected \(expected) resource missing")
        }
        for inspected in inspectedLabels where !expectedLabels.contains(inspected) {
            labels.append("Inspected \(inspected) resource not listed in manifest")
        }
        return labels
    }

    private static func resourceState(
        resourceCount: Int,
        rawResourceCount: Int,
        processedResourceCount: Int,
        mismatchLabels: [String]
    ) -> String {
        if resourceCount == 0 {
            return "not-inspected"
        }
        if !mismatchLabels.isEmpty {
            return "inspection-mismatch"
        }
        if rawResourceCount > 0 && processedResourceCount > 0 {
            return "inspected-raw-and-processed"
        }
        if rawResourceCount > 0 {
            return "inspected-raw-only"
        }
        if processedResourceCount > 0 {
            return "inspected-processed-only"
        }
        return "inspected-unclassified"
    }

    private static func recommendation(
        resourceState: String,
        mismatchLabels: [String]
    ) -> String {
        switch resourceState {
        case "inspected-raw-and-processed":
            return "Resource metadata lists both RAW and processed resources for this shot."
        case "inspected-raw-only":
            return "Only RAW resource metadata was inspected; produce or locate a processed companion before client handoff."
        case "inspected-processed-only":
            return "Only processed resource metadata was inspected; treat this as processed-only unless RAW is recovered."
        case "inspection-mismatch":
            return "Resource metadata disagrees with manifest expectations: \(mismatchLabels.joined(separator: "; "))."
        case "not-inspected":
            return "No resource metadata was inspected for this shot."
        default:
            return "Resource metadata is present but could not be classified as RAW or processed."
        }
    }
}

struct BracketProjectResourceInspectionReport: Codable, Equatable, Sendable {
    static let kind = "resource-inspection-report"

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let inspectedAt: Date
    let boundary: String
    let shotCount: Int
    let inspectedShotCount: Int
    let rawResourceCount: Int
    let processedResourceCount: Int
    let completePairCount: Int
    let mismatchCount: Int
    let items: [BracketProjectResourceInspection.Item]

    static func make(project: BracketProject) -> BracketProjectResourceInspectionReport? {
        guard let inspection = project.resourceInspection else { return nil }
        return BracketProjectResourceInspectionReport(
            schemaVersion: BracketProjectResourceInspection.schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: inspection.source.displayName,
            inspectedAt: inspection.inspectedAt,
            boundary: inspection.boundary,
            shotCount: project.manifest.shots.count,
            inspectedShotCount: inspection.items.filter { !$0.resources.isEmpty }.count,
            rawResourceCount: inspection.items.reduce(0) { $0 + $1.rawResourceCount },
            processedResourceCount: inspection.items.reduce(0) { $0 + $1.processedResourceCount },
            completePairCount: inspection.items.filter {
                $0.rawResourceCount > 0 && $0.processedResourceCount > 0
            }.count,
            mismatchCount: inspection.items.filter { !$0.mismatchLabels.isEmpty }.count,
            items: inspection.items
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectResourceInspectionReport {
        BracketProjectResourceInspectionReport(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            source: source,
            inspectedAt: inspectedAt,
            boundary: boundary,
            shotCount: shotCount,
            inspectedShotCount: inspectedShotCount,
            rawResourceCount: rawResourceCount,
            processedResourceCount: processedResourceCount,
            completePairCount: completePairCount,
            mismatchCount: mismatchCount,
            items: items
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectResourceInspectionReport.make(project: project)
    }

    var accessibilityValue: String {
        [
            "Resource Inspection",
            title,
            source,
            "\(inspectedShotCount) inspected shots",
            "\(completePairCount) complete pairs",
            "\(mismatchCount) mismatches",
            boundary
        ].joined(separator: " | ")
    }
}

struct BracketProjectAssetResourceReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let captureState: String
        let fileType: String
        let availableRepresentations: [String]
        let rawAvailable: Bool
        let processedAvailable: Bool
        let hasRecoveryIdentifier: Bool
        let identifierPolicy: String
        let missingRepresentationLabels: [String]
        let resourceState: String
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                displayLabel,
                resourceState,
                captureState,
                fileType,
                rawAvailable ? "RAW available" : "RAW missing",
                processedAvailable ? "Processed available" : "Processed missing",
                hasRecoveryIdentifier ? "Recovery identifier present" : "No recovery identifier",
                identifierPolicy,
                recommendation
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "asset-resource-report"
    static let boundary = "Manifest/project asset resource report; does not fetch Photos resources, open image files, inspect RAW containers, or prove physical asset availability."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let boundary: String
    let shotCount: Int
    let assetReferenceCount: Int
    let rawAvailableCount: Int
    let processedAvailableCount: Int
    let completePairCount: Int
    let missingAssetCount: Int
    let recoveryIdentifierCount: Int
    let identifierPolicy: String
    let items: [Item]

    static func make(project: BracketProject) -> BracketProjectAssetResourceReport {
        let assetByIndex = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.index, $0) })
        let items = project.manifest.shots.map { shot in
            let asset = assetByIndex[shot.index]
            let representations = asset?.availableRepresentations ?? shot.availableRepresentations
            let rawAvailable = containsRawRepresentation(representations)
            let processedAvailable = containsProcessedRepresentation(representations)
            let hasRecoveryIdentifier = asset?.assetIdentifier != nil || shot.assetIdentifier != nil
            let missingRepresentations = missingRepresentationLabels(
                fileType: asset?.fileType ?? shot.fileType,
                rawAvailable: rawAvailable,
                processedAvailable: processedAvailable
            )
            let captureState = asset?.captureState ?? shot.captureState
            let resourceState = resourceState(
                captureState: captureState,
                rawAvailable: rawAvailable,
                processedAvailable: processedAvailable
            )
            return Item(
                index: shot.index,
                displayLabel: asset?.displayLabel ?? shot.displayLabel,
                captureState: captureState,
                fileType: asset?.fileType ?? shot.fileType,
                availableRepresentations: representations,
                rawAvailable: rawAvailable,
                processedAvailable: processedAvailable,
                hasRecoveryIdentifier: hasRecoveryIdentifier,
                identifierPolicy: identifierPolicy(hasRecoveryIdentifier: hasRecoveryIdentifier),
                missingRepresentationLabels: missingRepresentations,
                resourceState: resourceState,
                recommendation: recommendation(
                    resourceState: resourceState,
                    missingRepresentationLabels: missingRepresentations,
                    hasRecoveryIdentifier: hasRecoveryIdentifier
                )
            )
        }
        let rawAvailableCount = items.filter(\.rawAvailable).count
        let processedAvailableCount = items.filter(\.processedAvailable).count
        let completePairCount = items.filter { $0.rawAvailable && $0.processedAvailable }.count

        return BracketProjectAssetResourceReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            boundary: boundary,
            shotCount: project.manifest.shots.count,
            assetReferenceCount: project.assets.count,
            rawAvailableCount: rawAvailableCount,
            processedAvailableCount: processedAvailableCount,
            completePairCount: completePairCount,
            missingAssetCount: items.filter { item in
                item.resourceState == "missing-asset" || item.resourceState == "failed-capture"
            }.count,
            recoveryIdentifierCount: items.filter(\.hasRecoveryIdentifier).count,
            identifierPolicy: project.privacy.storesAssetIdentifiers
                ? "Photos recovery identifiers are present in the project record."
                : "Photos recovery identifiers are redacted or unavailable in this project record.",
            items: items
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectAssetResourceReport {
        BracketProjectAssetResourceReport(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            boundary: boundary,
            shotCount: shotCount,
            assetReferenceCount: assetReferenceCount,
            rawAvailableCount: rawAvailableCount,
            processedAvailableCount: processedAvailableCount,
            completePairCount: completePairCount,
            missingAssetCount: missingAssetCount,
            recoveryIdentifierCount: recoveryIdentifierCount,
            identifierPolicy: identifierPolicy,
            items: items
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectAssetResourceReport.make(project: project)
    }

    var accessibilityValue: String {
        [
            "Asset Resources",
            title,
            "\(completePairCount) complete pairs",
            "RAW \(rawAvailableCount)",
            "Processed \(processedAvailableCount)",
            "Missing \(missingAssetCount)",
            "Recovery IDs \(recoveryIdentifierCount)",
            identifierPolicy,
            boundary
        ].joined(separator: " | ")
    }

    private static func containsRawRepresentation(_ representations: [String]) -> Bool {
        representations.contains {
            $0.localizedCaseInsensitiveContains("raw")
                || $0.localizedCaseInsensitiveContains("dng")
                || $0.localizedCaseInsensitiveContains("proraw")
        }
    }

    private static func containsProcessedRepresentation(_ representations: [String]) -> Bool {
        representations.contains {
            $0.localizedCaseInsensitiveContains("processed")
                || $0.localizedCaseInsensitiveContains("jpeg")
                || $0.localizedCaseInsensitiveContains("jpg")
                || $0.localizedCaseInsensitiveContains("heif")
                || $0.localizedCaseInsensitiveContains("heic")
        }
    }

    private static func missingRepresentationLabels(
        fileType: String,
        rawAvailable: Bool,
        processedAvailable: Bool
    ) -> [String] {
        var missing: [String] = []
        let expectsRaw = fileType.localizedCaseInsensitiveContains("raw")
            || fileType.localizedCaseInsensitiveContains("dng")
            || fileType.localizedCaseInsensitiveContains("proraw")
        let expectsProcessed = fileType.localizedCaseInsensitiveContains("processed")
            || fileType.localizedCaseInsensitiveContains("jpeg")
            || fileType.localizedCaseInsensitiveContains("jpg")
            || fileType.localizedCaseInsensitiveContains("heif")
            || fileType.localizedCaseInsensitiveContains("heic")

        if expectsRaw && !rawAvailable {
            missing.append("RAW")
        }
        if expectsProcessed && !processedAvailable {
            missing.append("Processed")
        }
        return missing
    }

    private static func resourceState(
        captureState: String,
        rawAvailable: Bool,
        processedAvailable: Bool
    ) -> String {
        if captureState.localizedCaseInsensitiveContains("failed") {
            return "failed-capture"
        }
        if captureState.localizedCaseInsensitiveContains("missing") {
            return "missing-asset"
        }
        if rawAvailable && processedAvailable {
            return "raw-and-processed-ready"
        }
        if rawAvailable {
            return "raw-only"
        }
        if processedAvailable {
            return "processed-only"
        }
        return "representation-unlisted"
    }

    private static func identifierPolicy(hasRecoveryIdentifier: Bool) -> String {
        hasRecoveryIdentifier
            ? "Recovery identifier present in project metadata."
            : "Recovery identifier redacted or unavailable."
    }

    private static func recommendation(
        resourceState: String,
        missingRepresentationLabels: [String],
        hasRecoveryIdentifier: Bool
    ) -> String {
        switch resourceState {
        case "raw-and-processed-ready":
            return hasRecoveryIdentifier
                ? "Manifest lists a complete RAW/processed pair and a recovery identifier for this shot."
                : "Manifest lists a complete RAW/processed pair; keep the archive with its source library for recovery."
        case "raw-only":
            return "Processed output is not listed; export or regenerate a processed companion before client handoff."
        case "processed-only":
            return "RAW is not listed; treat this as a processed-only bracket unless Photos resources prove otherwise."
        case "missing-asset":
            return "Recover from Photos or reshoot before depending on this exposure."
        case "failed-capture":
            return "Inspect capture diagnostics and exclude this shot until recovered."
        default:
            if missingRepresentationLabels.isEmpty {
                return "No representation labels are listed; verify resources before export."
            }
            return "Missing \(missingRepresentationLabels.joined(separator: " and ")) representation; verify resources before export."
        }
    }
}

struct BracketProjectImageBundleManifest: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let evOffset: Float
        let captureState: String
        let fileType: String
        let requestedRepresentations: [String]
        let availableRepresentations: [String]
        let plannedFilenames: [String]
        let assetIdentifierIncluded: Bool
        let bundleReadiness: String
        let missingRepresentations: [String]
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                displayLabel,
                bundleReadiness,
                captureState,
                fileType,
                requestedRepresentations.isEmpty ? "No requested representation" : requestedRepresentations.joined(separator: ", "),
                availableRepresentations.isEmpty ? "No available representation" : availableRepresentations.joined(separator: ", "),
                assetIdentifierIncluded ? "Recovery identifier included" : "Recovery identifier redacted",
                recommendation
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "image-bundle-manifest"
    static let boundary = "Metadata-only selected image/RAW bundle manifest; does not export, read, fetch, decode, or prove photo bytes, RAW resources, thumbnails, sidecar files, or filesystem package contents."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let privacyLevel: BracketProjectExportPrivacyLevel
    let createdAt: Date
    let boundary: String
    let shotCount: Int
    let exportableShotCount: Int
    let rawRequestedCount: Int
    let processedRequestedCount: Int
    let completeRawProcessedPairCount: Int
    let missingRepresentationCount: Int
    let recoveryIdentifierCount: Int
    let assetIdentifierPolicy: String
    let items: [Item]

    static func make(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel,
        createdAt: Date
    ) -> BracketProjectImageBundleManifest {
        let assetByIndex = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.index, $0) })
        let items = project.manifest.shots.map { shot in
            let asset = assetByIndex[shot.index]
            let availableRepresentations = asset?.availableRepresentations ?? shot.availableRepresentations
            let fileType = asset?.fileType ?? shot.fileType
            let requestedRepresentations = requestedRepresentationLabels(
                fileType: fileType,
                availableRepresentations: availableRepresentations
            )
            let missingRepresentations = missingRepresentationLabels(
                requestedRepresentations: requestedRepresentations,
                availableRepresentations: availableRepresentations
            )
            let captureState = asset?.captureState ?? shot.captureState
            let readiness = bundleReadiness(
                captureState: captureState,
                requestedRepresentations: requestedRepresentations,
                availableRepresentations: availableRepresentations,
                missingRepresentations: missingRepresentations
            )

            return Item(
                index: shot.index,
                displayLabel: asset?.displayLabel ?? shot.displayLabel,
                evOffset: asset?.evOffset ?? shot.evOffset,
                captureState: captureState,
                fileType: fileType,
                requestedRepresentations: requestedRepresentations,
                availableRepresentations: availableRepresentations,
                plannedFilenames: plannedFilenames(
                    projectID: project.id,
                    shot: shot,
                    requestedRepresentations: requestedRepresentations
                ),
                assetIdentifierIncluded: asset?.assetIdentifier != nil || shot.assetIdentifier != nil,
                bundleReadiness: readiness,
                missingRepresentations: missingRepresentations,
                recommendation: recommendation(
                    bundleReadiness: readiness,
                    missingRepresentations: missingRepresentations
                )
            )
        }

        return BracketProjectImageBundleManifest(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            boundary: boundary,
            shotCount: items.count,
            exportableShotCount: items.filter { $0.bundleReadiness.hasPrefix("ready-") }.count,
            rawRequestedCount: items.filter { $0.requestedRepresentations.contains("RAW") }.count,
            processedRequestedCount: items.filter { $0.requestedRepresentations.contains("Processed") }.count,
            completeRawProcessedPairCount: items.filter {
                $0.bundleReadiness == "ready-raw-processed-pair"
            }.count,
            missingRepresentationCount: items.reduce(0) { $0 + $1.missingRepresentations.count },
            recoveryIdentifierCount: items.filter(\.assetIdentifierIncluded).count,
            assetIdentifierPolicy: project.privacy.assetIdentifierPolicy,
            items: items
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectImageBundleManifest {
        let oldStem = projectID.fileSafeIdentifier
        let newStem = newProjectID.fileSafeIdentifier
        return BracketProjectImageBundleManifest(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            boundary: boundary,
            shotCount: shotCount,
            exportableShotCount: exportableShotCount,
            rawRequestedCount: rawRequestedCount,
            processedRequestedCount: processedRequestedCount,
            completeRawProcessedPairCount: completeRawProcessedPairCount,
            missingRepresentationCount: missingRepresentationCount,
            recoveryIdentifierCount: recoveryIdentifierCount,
            assetIdentifierPolicy: assetIdentifierPolicy,
            items: items.map { item in
                Item(
                    index: item.index,
                    displayLabel: item.displayLabel,
                    evOffset: item.evOffset,
                    captureState: item.captureState,
                    fileType: item.fileType,
                    requestedRepresentations: item.requestedRepresentations,
                    availableRepresentations: item.availableRepresentations,
                    plannedFilenames: item.plannedFilenames.map {
                        $0.replacingOccurrences(of: oldStem, with: newStem)
                    },
                    assetIdentifierIncluded: item.assetIdentifierIncluded,
                    bundleReadiness: item.bundleReadiness,
                    missingRepresentations: item.missingRepresentations,
                    recommendation: item.recommendation
                )
            }
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectImageBundleManifest.make(
            project: project,
            privacyLevel: privacyLevel,
            createdAt: createdAt
        )
    }

    var accessibilityValue: String {
        [
            "Image Bundle Manifest",
            title,
            privacyLevel.displayName,
            "\(exportableShotCount) of \(shotCount) exportable",
            "RAW \(rawRequestedCount)",
            "Processed \(processedRequestedCount)",
            "\(completeRawProcessedPairCount) complete RAW/processed pairs",
            "Missing \(missingRepresentationCount)",
            "Recovery IDs \(recoveryIdentifierCount)",
            boundary
        ].joined(separator: " | ")
    }

    private static func requestedRepresentationLabels(
        fileType: String,
        availableRepresentations: [String]
    ) -> [String] {
        let signals = [fileType] + availableRepresentations
        var requested: [String] = []
        if containsProcessedRepresentation(signals) || !containsRawRepresentation(signals) {
            requested.append("Processed")
        }
        if containsRawRepresentation(signals) {
            requested.append("RAW")
        }
        return requested.uniquePreservingOrder()
    }

    private static func missingRepresentationLabels(
        requestedRepresentations: [String],
        availableRepresentations: [String]
    ) -> [String] {
        requestedRepresentations.filter { requested in
            switch requested {
            case "RAW":
                return !containsRawRepresentation(availableRepresentations)
            case "Processed":
                return !containsProcessedRepresentation(availableRepresentations)
            default:
                return !availableRepresentations.contains { $0.localizedCaseInsensitiveContains(requested) }
            }
        }
    }

    private static func plannedFilenames(
        projectID: String,
        shot: BracketManifest.Shot,
        requestedRepresentations: [String]
    ) -> [String] {
        let stem = "\(projectID)-shot-\(String(format: "%03d", shot.index + 1))-\(shot.filenameLabel)"
            .fileSafeIdentifier
        return requestedRepresentations.map { representation in
            switch representation {
            case "RAW":
                return "\(stem)-raw.dng"
            case "Processed":
                return "\(stem)-processed.heic"
            default:
                return "\(stem)-\(representation.fileSafeIdentifier.lowercased()).dat"
            }
        }
    }

    private static func bundleReadiness(
        captureState: String,
        requestedRepresentations: [String],
        availableRepresentations: [String],
        missingRepresentations: [String]
    ) -> String {
        if captureState.localizedCaseInsensitiveContains("failed") {
            return "failed-capture"
        }
        if captureState.localizedCaseInsensitiveContains("missing") {
            return "missing-asset"
        }
        if missingRepresentations.isEmpty {
            if requestedRepresentations.contains("RAW"), requestedRepresentations.contains("Processed") {
                return "ready-raw-processed-pair"
            }
            if requestedRepresentations.contains("RAW") {
                return "ready-raw-only"
            }
            if requestedRepresentations.contains("Processed") {
                return "ready-processed-only"
            }
            return "ready-no-requested-representations"
        }
        if !availableRepresentations.isEmpty {
            return "incomplete-representations"
        }
        return "representation-unlisted"
    }

    private static func recommendation(
        bundleReadiness: String,
        missingRepresentations: [String]
    ) -> String {
        switch bundleReadiness {
        case "ready-raw-processed-pair":
            return "Plan a paired processed image and RAW sidecar for this exposure; manifest says both representations are listed."
        case "ready-raw-only":
            return "Plan a RAW-only bundle entry and generate a processed companion before client handoff if needed."
        case "ready-processed-only":
            return "Plan a processed-image bundle entry; RAW is not requested by the project metadata."
        case "failed-capture":
            return "Exclude this failed capture from the bundle until diagnostics or a reshoot restores it."
        case "missing-asset":
            return "Recover this asset before building a selected-image/RAW bundle."
        case "incomplete-representations":
            return "Missing \(missingRepresentations.joined(separator: " and ")); recover or regenerate before bundle export."
        default:
            return "No concrete representation is listed; verify source resources before bundle export."
        }
    }

    private static func containsRawRepresentation(_ representations: [String]) -> Bool {
        representations.contains {
            $0.localizedCaseInsensitiveContains("raw")
                || $0.localizedCaseInsensitiveContains("dng")
                || $0.localizedCaseInsensitiveContains("proraw")
        }
    }

    private static func containsProcessedRepresentation(_ representations: [String]) -> Bool {
        representations.contains {
            $0.localizedCaseInsensitiveContains("processed")
                || $0.localizedCaseInsensitiveContains("jpeg")
                || $0.localizedCaseInsensitiveContains("jpg")
                || $0.localizedCaseInsensitiveContains("heif")
                || $0.localizedCaseInsensitiveContains("heic")
        }
    }
}

struct BracketProjectImageBundleDraftPackageDocument: Equatable, Sendable {
    struct Package: Codable, Equatable, Sendable {
        struct Entry: Codable, Equatable, Sendable {
            let index: Int
            let displayLabel: String
            let representation: String
            let plannedFilename: String
            let bundleReadiness: String
            let byteCount: Int
            let sha256Hex: String
            let syntheticPayloadBase64: String
            let sourceBoundary: String
        }

        let schemaVersion: Int
        let kind: String
        let projectID: String
        let title: String
        let privacyLevel: BracketProjectExportPrivacyLevel
        let sourceManifestKind: String
        let sourceBoundary: String
        let boundary: String
        let entryCount: Int
        let totalByteCount: Int
        let entries: [Entry]
    }

    static let schemaVersion = 1
    static let kind = "image-bundle-draft-package"
    static let mimeType = "application/vnd.bracketer.image-bundle-draft+json"
    static let encoding = "base64-json"
    static let sourceBoundary = "Synthetic draft bytes from image-bundle-manifest filenames and saved project facts only."
    static let boundary = "Base64 JSON draft package with deterministic synthetic per-file payloads; not private Photos bytes, not RAW resources, not decoded image data, not a filesystem package, and not physical export proof."

    static func package(manifest: BracketProjectImageBundleManifest) -> Package {
        var entries: [Package.Entry] = []
        for item in manifest.items {
            for (offset, plannedFilename) in item.plannedFilenames.enumerated() {
                let representation = item.requestedRepresentations.indices.contains(offset)
                    ? item.requestedRepresentations[offset]
                    : "Unspecified"
                let payloadData = syntheticPayloadData(
                    manifest: manifest,
                    item: item,
                    representation: representation,
                    plannedFilename: plannedFilename
                )
                entries.append(
                    Package.Entry(
                        index: item.index,
                        displayLabel: item.displayLabel,
                        representation: representation,
                        plannedFilename: plannedFilename,
                        bundleReadiness: item.bundleReadiness,
                        byteCount: payloadData.count,
                        sha256Hex: sha256Hex(payloadData),
                        syntheticPayloadBase64: payloadData.base64EncodedString(),
                        sourceBoundary: sourceBoundary
                    )
                )
            }
        }

        return Package(
            schemaVersion: schemaVersion,
            kind: kind,
            projectID: manifest.projectID,
            title: manifest.title,
            privacyLevel: manifest.privacyLevel,
            sourceManifestKind: BracketProjectImageBundleManifest.kind,
            sourceBoundary: BracketProjectImageBundleManifest.boundary,
            boundary: boundary,
            entryCount: entries.count,
            totalByteCount: entries.reduce(0) { $0 + $1.byteCount },
            entries: entries
        )
    }

    static func packageData(manifest: BracketProjectImageBundleManifest) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(package(manifest: manifest))
    }

    static func base64Package(manifest: BracketProjectImageBundleManifest) -> String? {
        packageData(manifest: manifest)?.base64EncodedString()
    }

    static func matches(
        base64Contents: String,
        manifest: BracketProjectImageBundleManifest
    ) -> Bool {
        guard let decodedData = Data(base64Encoded: base64Contents),
              let expectedData = packageData(manifest: manifest) else {
            return false
        }
        return decodedData == expectedData
    }

    private static func syntheticPayloadData(
        manifest: BracketProjectImageBundleManifest,
        item: BracketProjectImageBundleManifest.Item,
        representation: String,
        plannedFilename: String
    ) -> Data {
        let text = [
            "Bracketer synthetic image bundle draft",
            "Project: \(manifest.projectID)",
            "Title: \(manifest.title)",
            "Privacy: \(manifest.privacyLevel.displayName)",
            "Shot: \(item.displayLabel)",
            "Index: \(item.index)",
            "Representation: \(representation)",
            "Filename: \(plannedFilename)",
            "Readiness: \(item.bundleReadiness)",
            "Boundary: \(boundary)"
        ].joined(separator: "\n") + "\n"
        return Data(text.utf8)
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct BracketProjectMergeReadinessReport: Codable, Equatable, Sendable {
    struct Evidence: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let severity: String
        let title: String
        let detail: String
        let recommendation: String

        var accessibilityValue: String {
            [severity, title, detail, recommendation].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "merge-readiness-report"
    static let boundary = "Manifest/project-backed merge readiness heuristic; does not inspect private Photos bytes, sharpness, alignment, ghosting, moving subjects, RAW pixels, or final HDR output."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let boundary: String
    let score: Int
    let label: String
    let blockerCount: Int
    let cautionCount: Int
    let evidence: [Evidence]
    let recommendations: [String]

    static func make(project: BracketProject) -> BracketProjectMergeReadinessReport {
        let captureQuality = BracketProjectCaptureQualityReport.make(project: project)
        let assetResources = BracketProjectAssetResourceReport.make(project: project)
        let resourceInspection = BracketProjectResourceInspectionReport.make(project: project)
        let thumbnailInspection = BracketProjectThumbnailInspectionReport.make(project: project)
        let evidence = evidence(
            captureQuality: captureQuality,
            assetResources: assetResources,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection
        )
        let blockerCount = evidence.filter { $0.severity == "Blocker" }.count
        let cautionCount = evidence.filter { $0.severity == "Caution" }.count
        let score = score(
            captureQuality: captureQuality,
            assetResources: assetResources,
            resourceInspection: resourceInspection,
            thumbnailInspection: thumbnailInspection
        )

        return BracketProjectMergeReadinessReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            boundary: boundary,
            score: score,
            label: label(score: score, blockerCount: blockerCount),
            blockerCount: blockerCount,
            cautionCount: cautionCount,
            evidence: evidence,
            recommendations: evidence.map(\.recommendation).uniquePreservingOrder()
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectMergeReadinessReport {
        BracketProjectMergeReadinessReport(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            boundary: boundary,
            score: score,
            label: label,
            blockerCount: blockerCount,
            cautionCount: cautionCount,
            evidence: evidence,
            recommendations: recommendations
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectMergeReadinessReport.make(project: project)
    }

    var accessibilityValue: String {
        [
            "Merge Readiness",
            title,
            "Score \(score)",
            label,
            "\(blockerCount) blockers",
            "\(cautionCount) cautions",
            boundary
        ].joined(separator: " | ")
    }

    private static func score(
        captureQuality: BracketProjectCaptureQualityReport,
        assetResources: BracketProjectAssetResourceReport,
        resourceInspection: BracketProjectResourceInspectionReport?,
        thumbnailInspection: BracketProjectThumbnailInspectionReport?
    ) -> Int {
        var score = captureQuality.readinessScore
        score -= min(40, assetResources.missingAssetCount * 20)
        if assetResources.completePairCount == 0 {
            score -= 20
        }
        if assetResources.rawAvailableCount == 0 {
            score -= 10
        }
        score -= min(30, (resourceInspection?.mismatchCount ?? 0) * 10)
        if resourceInspection == nil {
            score -= 5
        }
        score -= min(20, (thumbnailInspection?.errorShotCount ?? 0) * 10)
        return min(100, max(0, score))
    }

    private static func label(score: Int, blockerCount: Int) -> String {
        if blockerCount > 0 {
            return "Recovery before merge"
        }
        if score >= 85 {
            return "Ready for cautious merge preview"
        }
        if score >= 60 {
            return "Review before merge"
        }
        return "Recovery before merge"
    }

    private static func evidence(
        captureQuality: BracketProjectCaptureQualityReport,
        assetResources: BracketProjectAssetResourceReport,
        resourceInspection: BracketProjectResourceInspectionReport?,
        thumbnailInspection: BracketProjectThumbnailInspectionReport?
    ) -> [Evidence] {
        var evidence: [Evidence] = [
            Evidence(
                id: "capture-quality",
                severity: captureQuality.readinessScore >= 85 ? "Ready" : "Caution",
                title: "Capture quality score \(captureQuality.readinessScore)",
                detail: captureQuality.accessibilityValue,
                recommendation: captureQuality.recommendations.first
                    ?? "Review capture quality before attempting a merge preview."
            )
        ]

        if captureQuality.missingShotCount > 0 {
            evidence.append(
                Evidence(
                    id: "missing-shots",
                    severity: "Blocker",
                    title: "Missing planned exposures",
                    detail: "\(captureQuality.missingShotCount) shot(s) are missing from the manifest.",
                    recommendation: "Recover or reshoot missing exposures before merge decisions."
                )
            )
        }
        if captureQuality.failedShotCount > 0 {
            evidence.append(
                Evidence(
                    id: "failed-shots",
                    severity: "Blocker",
                    title: "Failed capture states",
                    detail: "\(captureQuality.failedShotCount) shot(s) failed capture.",
                    recommendation: "Inspect diagnostics and exclude failed shots until recovered."
                )
            )
        }
        if captureQuality.highlightGuardCount == 0 || captureQuality.shadowGuardCount == 0 {
            evidence.append(
                Evidence(
                    id: "guard-coverage",
                    severity: "Caution",
                    title: "Exposure guard coverage is incomplete",
                    detail: "Highlight guards \(captureQuality.highlightGuardCount), shadow guards \(captureQuality.shadowGuardCount).",
                    recommendation: "Capture both darker and brighter guard exposures when dynamic range matters."
                )
            )
        }
        if assetResources.missingAssetCount > 0 {
            evidence.append(
                Evidence(
                    id: "missing-assets",
                    severity: "Blocker",
                    title: "Project has missing or failed asset records",
                    detail: "\(assetResources.missingAssetCount) shot(s) are missing assets or failed capture.",
                    recommendation: "Recover Photos assets or reshoot before producing merge output."
                )
            )
        }
        if assetResources.completePairCount == 0 {
            evidence.append(
                Evidence(
                    id: "no-complete-resource-pairs",
                    severity: "Caution",
                    title: "No complete RAW/processed pairs",
                    detail: "Asset report lists \(assetResources.rawAvailableCount) RAW and \(assetResources.processedAvailableCount) processed representations.",
                    recommendation: "Treat this as a limited preview path until RAW/processed resources are verified."
                )
            )
        } else {
            evidence.append(
                Evidence(
                    id: "resource-pairs",
                    severity: "Ready",
                    title: "Resource pairs available",
                    detail: "\(assetResources.completePairCount) complete RAW/processed pair(s) are listed by project metadata.",
                    recommendation: "Use resource inspection or physical device proof before final export."
                )
            )
        }
        if let resourceInspection {
            if resourceInspection.mismatchCount > 0 {
                evidence.append(
                    Evidence(
                        id: "resource-inspection-mismatch",
                        severity: "Caution",
                        title: "Resource inspection mismatch",
                        detail: "\(resourceInspection.mismatchCount) inspected shot(s) disagree with manifest expectations.",
                        recommendation: "Resolve resource mismatches before final merge export."
                    )
                )
            } else {
                evidence.append(
                    Evidence(
                        id: "resource-inspection",
                        severity: "Ready",
                        title: "Resource inspection has no mismatches",
                        detail: "\(resourceInspection.inspectedShotCount) inspected shot(s), \(resourceInspection.completePairCount) complete pair(s).",
                        recommendation: "Continue with preview-only merge checks unless physical pixel proof is available."
                    )
                )
            }
        } else {
            evidence.append(
                Evidence(
                    id: "resource-inspection-missing",
                    severity: "Info",
                    title: "Photos resources not inspected",
                    detail: "No Photos resource-inspection metadata is attached to this project.",
                    recommendation: "Open Photos-backed review on device to collect resource metadata before final export."
                )
            )
        }
        if let thumbnailInspection, thumbnailInspection.errorShotCount > 0 {
            evidence.append(
                Evidence(
                    id: "thumbnail-errors",
                    severity: "Caution",
                    title: "Thumbnail delivery errors",
                    detail: "\(thumbnailInspection.errorShotCount) thumbnail callback(s) reported an error or cancellation.",
                    recommendation: "Reopen review and verify thumbnails before using visual handoff artifacts."
                )
            )
        }
        evidence.append(
            Evidence(
                id: "pixel-proof-boundary",
                severity: "Info",
                title: "No alignment or ghosting proof",
                detail: boundary,
                recommendation: "Do not treat this score as final HDR science until pixel alignment, ghosting, and tone mapping are implemented."
            )
        )

        return evidence
    }
}

struct BracketProjectFinalOutputManifest: Codable, Equatable, Sendable {
    struct Output: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let displayName: String
        let filename: String
        let mimeType: String
        let codec: String
        let colorPipeline: String
        let sourcePolicy: String
        let readiness: String
        let blockers: [String]
        let provenanceInputs: [String]
        let recommendation: String

        var accessibilityValue: String {
            [
                displayName,
                filename,
                mimeType,
                codec,
                readiness,
                blockers.isEmpty ? "No blockers" : blockers.joined(separator: ", "),
                provenanceInputs.joined(separator: ", "),
                recommendation
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "final-output-manifest"
    static let boundary = "Final-output export plan only; records intended render formats, filenames, source requirements, and blockers without including final rendered image bytes, reading Photos resources, decoding RAW, tone mapping user assets, or proving physical export."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let privacyLevel: BracketProjectExportPrivacyLevel
    let createdAt: Date
    let boundary: String
    let sourceExposureCount: Int
    let completeResourcePairCount: Int
    let previewArtifactAvailable: Bool
    let finalRenderedBytesIncluded: Bool
    let outputCount: Int
    let readyOutputCount: Int
    let blockedOutputCount: Int
    let readinessSummary: String
    let outputs: [Output]

    static func make(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel,
        createdAt: Date
    ) -> BracketProjectFinalOutputManifest {
        let mergeReadiness = BracketProjectMergeReadinessReport.make(project: project)
        let imageBundle = BracketProjectImageBundleManifest.make(
            project: project,
            privacyLevel: privacyLevel,
            createdAt: createdAt
        )
        let fusionPreviewAvailable = BracketProjectFusionPreviewReport.make(project: project) != nil
        let stem = project.id.fileSafeIdentifier
        let rendererBlocker = "Final HDR/tone-map renderer is not implemented in this build."
        let physicalProofBlocker = "Physical Photos resource bytes and Files export artifact have not been inspected."
        let mergeReadinessBlockers = mergeReadiness.blockerCount > 0
            ? ["Merge readiness has \(mergeReadiness.blockerCount) blocker(s) that must be resolved before final output."]
            : []
        let rawPairBlocker = imageBundle.completeRawProcessedPairCount == 0
            ? ["No complete RAW/processed source pairs are listed by project metadata."]
            : []
        let previewBlocker = fusionPreviewAvailable
            ? []
            : ["No fusion-preview artifact is available for this project."]

        let outputs = [
            Output(
                id: "tone-mapped-review-jpeg",
                displayName: "Tone-mapped review JPEG",
                filename: "\(stem)-tone-mapped-review.jpg",
                mimeType: "image/jpeg",
                codec: "JPEG",
                colorPipeline: "Display-referred SDR tone map pending final renderer",
                sourcePolicy: "Uses manifest exposures plus fusion-preview when available; does not read private Photos bytes.",
                readiness: fusionPreviewAvailable ? "planned-preview-only" : "blocked-preview-unavailable",
                blockers: [rendererBlocker] + previewBlocker,
                provenanceInputs: [
                    "manifest",
                    BracketProjectMergeReadinessReport.kind,
                    BracketProjectImageBundleManifest.kind,
                    BracketProjectFusionPreviewReport.kind
                ],
                recommendation: fusionPreviewAvailable
                    ? "Use the fusion preview as review context only; do not hand this off as a rendered JPEG until the final renderer writes bytes."
                    : "Generate or recover a preview artifact before planning a tone-mapped JPEG."
            ),
            Output(
                id: "hdr-heif-master",
                displayName: "HDR HEIF master",
                filename: "\(stem)-hdr-master.heic",
                mimeType: "image/heic",
                codec: "HEIF/HDR",
                colorPipeline: "Scene-referred merge, HDR tone mapping, and metadata writing pending implementation",
                sourcePolicy: "Requires verified source resources and final merge output; current archive stores metadata only.",
                readiness: "blocked-final-renderer-missing",
                blockers: [rendererBlocker, physicalProofBlocker] + mergeReadinessBlockers + rawPairBlocker,
                provenanceInputs: [
                    "manifest",
                    BracketProjectAssetResourceReport.kind,
                    BracketProjectMergeReadinessReport.kind,
                    BracketProjectImageBundleManifest.kind
                ],
                recommendation: "Keep this as a planned professional output until RAW/processed bytes, alignment, ghosting, tone mapping, and file writing are implemented."
            ),
            Output(
                id: "lightroom-reference-tiff",
                displayName: "Lightroom reference TIFF",
                filename: "\(stem)-lightroom-reference.tiff",
                mimeType: "image/tiff",
                codec: "TIFF",
                colorPipeline: "16-bit reference render and embedded provenance pending implementation",
                sourcePolicy: "Requires final rendered pixels plus sidecar/provenance export; current archive stores the plan only.",
                readiness: "blocked-source-byte-export-missing",
                blockers: [rendererBlocker, physicalProofBlocker] + mergeReadinessBlockers + rawPairBlocker,
                provenanceInputs: [
                    "manifest",
                    "sidecar",
                    BracketProjectArchiveIntegrityManifest.kind,
                    BracketProjectImageBundleManifest.kind
                ],
                recommendation: "Do not claim a Lightroom-ready rendered TIFF until Bracketer writes verified image bytes and sidecar provenance."
            )
        ]

        let readyOutputCount = outputs.filter(\.blockers.isEmpty).count
        let blockedOutputCount = outputs.count - readyOutputCount
        let readinessSummary = readyOutputCount == 0
            ? "No final rendered outputs are available yet; \(blockedOutputCount) planned outputs require renderer, source-byte, or physical export proof."
            : "\(readyOutputCount) of \(outputs.count) planned final outputs are ready."

        return BracketProjectFinalOutputManifest(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            boundary: boundary,
            sourceExposureCount: imageBundle.exportableShotCount,
            completeResourcePairCount: imageBundle.completeRawProcessedPairCount,
            previewArtifactAvailable: fusionPreviewAvailable,
            finalRenderedBytesIncluded: false,
            outputCount: outputs.count,
            readyOutputCount: readyOutputCount,
            blockedOutputCount: blockedOutputCount,
            readinessSummary: readinessSummary,
            outputs: outputs
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectFinalOutputManifest {
        let oldStem = projectID.fileSafeIdentifier
        let newStem = newProjectID.fileSafeIdentifier
        return BracketProjectFinalOutputManifest(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            boundary: boundary,
            sourceExposureCount: sourceExposureCount,
            completeResourcePairCount: completeResourcePairCount,
            previewArtifactAvailable: previewArtifactAvailable,
            finalRenderedBytesIncluded: finalRenderedBytesIncluded,
            outputCount: outputCount,
            readyOutputCount: readyOutputCount,
            blockedOutputCount: blockedOutputCount,
            readinessSummary: readinessSummary,
            outputs: outputs.map { output in
                Output(
                    id: output.id,
                    displayName: output.displayName,
                    filename: output.filename.replacingOccurrences(of: oldStem, with: newStem),
                    mimeType: output.mimeType,
                    codec: output.codec,
                    colorPipeline: output.colorPipeline,
                    sourcePolicy: output.sourcePolicy,
                    readiness: output.readiness,
                    blockers: output.blockers,
                    provenanceInputs: output.provenanceInputs,
                    recommendation: output.recommendation
                )
            }
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        self == BracketProjectFinalOutputManifest.make(
            project: project,
            privacyLevel: privacyLevel,
            createdAt: createdAt
        )
    }

    var accessibilityValue: String {
        let readyOutputNames = outputs
            .filter { $0.blockers.isEmpty }
            .map(\.displayName)
        let blockedOutputNames = outputs
            .filter { !$0.blockers.isEmpty }
            .map(\.displayName)
        let recommendationLines = outputs.map {
            "\($0.displayName): \($0.recommendation)"
        }

        return [
            "Final Output Manifest",
            title,
            privacyLevel.displayName,
            "\(readyOutputCount) ready",
            "\(blockedOutputCount) blocked",
            "\(sourceExposureCount) source exposures",
            "\(completeResourcePairCount) complete resource pairs",
            previewArtifactAvailable ? "Preview artifact available" : "Preview artifact unavailable",
            finalRenderedBytesIncluded ? "Final rendered bytes included" : "No final rendered bytes",
            "Ready outputs: \(readyOutputNames.isEmpty ? "none" : readyOutputNames.joined(separator: ", "))",
            "Blocked outputs: \(blockedOutputNames.isEmpty ? "none" : blockedOutputNames.joined(separator: ", "))",
            "\(recommendationLines.count) recommendations",
            "Recommendations: \(recommendationLines.isEmpty ? "none" : recommendationLines.joined(separator: " | "))",
            readinessSummary,
            boundary
        ].joined(separator: " | ")
    }
}

struct BracketProjectFinalOutputReadinessAudit: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let kind = "final-output-readiness-audit"
    static let boundary = "Final-output readiness audit is metadata-only review/export guidance; it summarizes planned outputs, blockers, recommendations, source readiness, and preview state without including final rendered image bytes, reading Photos resources, decoding RAW, tone mapping user assets, writing Files exports, or proving physical-device behavior."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let outputCount: Int
    let readyOutputCount: Int
    let blockedOutputCount: Int
    let sourceExposureCount: Int
    let completeResourcePairCount: Int
    let previewArtifactAvailable: Bool
    let finalRenderedBytesIncluded: Bool
    let blockerReasonCount: Int
    let recommendationCount: Int
    let readyOutputNames: [String]
    let blockedOutputNames: [String]
    let blockerReasons: [String]
    let recommendationLines: [String]
    let statusLabel: String
    let summaryLine: String
    let boundary: String

    static func make(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel,
        createdAt: Date
    ) -> BracketProjectFinalOutputReadinessAudit {
        make(
            manifest: BracketProjectFinalOutputManifest.make(
                project: project,
                privacyLevel: privacyLevel,
                createdAt: createdAt
            )
        )
    }

    static func make(
        manifest: BracketProjectFinalOutputManifest
    ) -> BracketProjectFinalOutputReadinessAudit {
        let readyOutputNames = manifest.outputs
            .filter { $0.blockers.isEmpty }
            .map(\.displayName)
        let blockedOutputNames = manifest.outputs
            .filter { !$0.blockers.isEmpty }
            .map(\.displayName)
        let blockerReasons = manifest.outputs
            .flatMap(\.blockers)
            .reduce(into: [String]()) { unique, blocker in
                if !unique.contains(blocker) {
                    unique.append(blocker)
                }
            }
        let recommendationLines = manifest.outputs.map {
            "\($0.displayName): \($0.recommendation)"
        }
        let statusLabel: String
        if manifest.finalRenderedBytesIncluded {
            statusLabel = "Rendered bytes require verification"
        } else if manifest.outputCount == 0 {
            statusLabel = "Final-output plan missing"
        } else if manifest.blockedOutputCount > 0 {
            statusLabel = "Follow-up before final export"
        } else {
            statusLabel = "Metadata ready, final render unverified"
        }
        let summaryLine = "\(manifest.readyOutputCount)/\(manifest.outputCount) outputs ready; \(manifest.blockedOutputCount) blocked; \(blockerReasons.count) blocker reason(s); \(recommendationLines.count) recommendation(s)."

        return BracketProjectFinalOutputReadinessAudit(
            schemaVersion: schemaVersion,
            projectID: manifest.projectID,
            title: manifest.title,
            outputCount: manifest.outputCount,
            readyOutputCount: manifest.readyOutputCount,
            blockedOutputCount: manifest.blockedOutputCount,
            sourceExposureCount: manifest.sourceExposureCount,
            completeResourcePairCount: manifest.completeResourcePairCount,
            previewArtifactAvailable: manifest.previewArtifactAvailable,
            finalRenderedBytesIncluded: manifest.finalRenderedBytesIncluded,
            blockerReasonCount: blockerReasons.count,
            recommendationCount: recommendationLines.count,
            readyOutputNames: readyOutputNames,
            blockedOutputNames: blockedOutputNames,
            blockerReasons: blockerReasons,
            recommendationLines: recommendationLines,
            statusLabel: statusLabel,
            summaryLine: summaryLine,
            boundary: boundary
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectFinalOutputReadinessAudit {
        BracketProjectFinalOutputReadinessAudit(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            outputCount: outputCount,
            readyOutputCount: readyOutputCount,
            blockedOutputCount: blockedOutputCount,
            sourceExposureCount: sourceExposureCount,
            completeResourcePairCount: completeResourcePairCount,
            previewArtifactAvailable: previewArtifactAvailable,
            finalRenderedBytesIncluded: finalRenderedBytesIncluded,
            blockerReasonCount: blockerReasonCount,
            recommendationCount: recommendationCount,
            readyOutputNames: readyOutputNames,
            blockedOutputNames: blockedOutputNames,
            blockerReasons: blockerReasons,
            recommendationLines: recommendationLines,
            statusLabel: statusLabel,
            summaryLine: summaryLine,
            boundary: boundary
        )
    }

    func matches(manifest: BracketProjectFinalOutputManifest) -> Bool {
        self == BracketProjectFinalOutputReadinessAudit.make(manifest: manifest)
    }

    static let actionPlanBoundary = "Action plan is metadata-only review/export guidance derived from existing audit metadata; it is not final rendered image proof."

    /// Compact, ordered next-step guidance derived only from existing audit
    /// metadata fields. Computed (not Codable) so it stays schema-safe and never
    /// implies that final rendered output exists.
    var actionPlan: [String] {
        var steps: [String] = []
        if finalRenderedBytesIncluded {
            steps.append("Verify rendered bytes against the \(sourceExposureCount) source exposure(s) before export.")
        }
        if outputCount == 0 {
            steps.append("Create a final-output plan before export.")
        }
        if blockedOutputCount > 0 {
            let names = blockedOutputNames.isEmpty ? "unnamed outputs" : blockedOutputNames.joined(separator: ", ")
            steps.append("Resolve blockers before export for \(blockedOutputCount) blocked output(s): \(names).")
            if !blockerReasons.isEmpty {
                steps.append("Clear \(blockerReasonCount) blocker reason(s): \(blockerReasons.joined(separator: "; "))")
            }
        }
        if !previewArtifactAvailable {
            steps.append("Generate or attach a preview artifact before handoff.")
        }
        if steps.isEmpty {
            steps.append("Metadata looks ready; verify final rendered image bytes separately before export.")
        }
        steps.append(Self.actionPlanBoundary)
        return steps
    }

    /// Number of actionable steps, excluding the trailing metadata-only boundary line.
    var actionPlanStepCount: Int {
        max(actionPlan.count - 1, 0)
    }

    var actionPlanSummary: String {
        "\(actionPlanStepCount) action item(s): \(actionPlan.joined(separator: " | "))"
    }

    var accessibilityValue: String {
        [
            "Final Output Readiness Audit",
            title,
            "schema v\(schemaVersion)",
            statusLabel,
            summaryLine,
            "\(sourceExposureCount) source exposures",
            "\(completeResourcePairCount) complete resource pairs",
            previewArtifactAvailable ? "Preview artifact available" : "Preview artifact unavailable",
            finalRenderedBytesIncluded ? "Final rendered bytes included" : "No final rendered bytes",
            "Ready outputs: \(readyOutputNames.isEmpty ? "none" : readyOutputNames.joined(separator: ", "))",
            "Blocked outputs: \(blockedOutputNames.isEmpty ? "none" : blockedOutputNames.joined(separator: ", "))",
            "Blocker reasons: \(blockerReasons.isEmpty ? "none" : blockerReasons.joined(separator: ", "))",
            "Recommendations: \(recommendationLines.isEmpty ? "none" : recommendationLines.joined(separator: " | "))",
            "Action plan: \(actionPlanSummary)",
            boundary
        ].joined(separator: " | ")
    }
}

struct BracketProjectExposureComparison: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let displayLabel: String
        let evOffset: Float
        let evDeltaFromBaseline: Float
        let captureState: String
        let fileType: String
        let availableRepresentations: [String]
        let role: String
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                displayLabel,
                role,
                "\(evDeltaFromBaseline) EV from baseline",
                captureState,
                fileType,
                availableRepresentations.isEmpty ? "No representation" : availableRepresentations.joined(separator: ", "),
                recommendation
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let projectID: String
    let title: String
    let baselineIndex: Int?
    let baselineDisplayLabel: String?
    let baselineEVOffset: Float?
    let shotCount: Int
    let items: [Item]

    static func make(project: BracketProject) -> BracketProjectExposureComparison {
        let baselineShot = project.manifest.shots.first(where: \.isBestExposureCandidate)
            ?? project.manifest.shots.min { left, right in
                abs(left.evOffset) < abs(right.evOffset)
            }
        let baselineEV = baselineShot?.evOffset
        let items = project.manifest.shots.map { shot in
            let evDelta = baselineEV.map { shot.evOffset - $0 } ?? 0
            let role = role(for: shot, evDeltaFromBaseline: evDelta)
            return Item(
                index: shot.index,
                displayLabel: shot.displayLabel,
                evOffset: shot.evOffset,
                evDeltaFromBaseline: evDelta,
                captureState: shot.captureState,
                fileType: shot.fileType,
                availableRepresentations: shot.availableRepresentations,
                role: role,
                recommendation: recommendation(for: shot, role: role)
            )
        }

        return BracketProjectExposureComparison(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            baselineIndex: baselineShot?.index,
            baselineDisplayLabel: baselineShot?.displayLabel,
            baselineEVOffset: baselineShot?.evOffset,
            shotCount: items.count,
            items: items
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectExposureComparison {
        BracketProjectExposureComparison(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            baselineIndex: baselineIndex,
            baselineDisplayLabel: baselineDisplayLabel,
            baselineEVOffset: baselineEVOffset,
            shotCount: shotCount,
            items: items
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        let expected = BracketProjectExposureComparison.make(project: project)
        return self == expected
    }

    var accessibilityValue: String {
        [
            "Exposure Comparison",
            title,
            "\(shotCount) shots",
            baselineDisplayLabel.map { "Baseline \($0)" },
            "\(items.count) comparisons"
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    private static func role(
        for shot: BracketManifest.Shot,
        evDeltaFromBaseline: Float
    ) -> String {
        if shot.captureState.localizedCaseInsensitiveContains("missing") {
            return "Missing planned exposure"
        }
        if shot.captureState.localizedCaseInsensitiveContains("failed") {
            return "Failed exposure"
        }
        if shot.isBestExposureCandidate || evDeltaFromBaseline == 0 {
            return "Baseline exposure"
        }
        return evDeltaFromBaseline < 0 ? "Darker highlight guard" : "Brighter shadow guard"
    }

    private static func recommendation(
        for shot: BracketManifest.Shot,
        role: String
    ) -> String {
        switch role {
        case "Missing planned exposure":
            return "Recover or reshoot before relying on this bracket for merge decisions."
        case "Failed exposure":
            return "Inspect diagnostics and exclude this shot from merge decisions until recovered."
        case "Baseline exposure":
            return "Use this as the neutral review anchor before comparing guard exposures."
        case "Darker highlight guard":
            return "Compare against the baseline for highlight detail and clipping recovery."
        case "Brighter shadow guard":
            return "Compare against the baseline for shadow detail and noise risk."
        default:
            return "Compare this exposure against the baseline before export."
        }
    }
}

struct BracketProjectPerShotExposureDistribution: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let evDeltaFromBaseline: Float
        let role: String
        let captureState: String
        let fileType: String
        let availableRepresentations: [String]
        let clippingWarningCount: Int
        let clippingSummary: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "\(evDeltaFromBaseline) EV from baseline",
                captureState,
                fileType,
                availableRepresentations.isEmpty ? "No representations" : availableRepresentations.joined(separator: ", "),
                clippingSummary,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "per-shot-exposure-distribution"
    static let boundary = "Per-shot exposure distribution is manifest metadata and deterministic review guidance only; it does not inspect private Photos bytes, decoded RAW pixels, pixel histograms, focus edges, alignment, ghosting, final rendered output bytes, or physical-device captures."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let baselineIndex: Int?
    let baselineDisplayLabel: String?
    let baselineEVOffset: Float?
    let shotCount: Int
    let evSpread: Float
    let highlightGuardCount: Int
    let shadowGuardCount: Int
    let clippingWarningCount: Int
    let items: [Item]
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectPerShotExposureDistribution {
        let baselineShot = project.manifest.shots.first(where: \.isBestExposureCandidate)
            ?? project.manifest.shots.min { left, right in
                abs(left.evOffset) < abs(right.evOffset)
            }
        let baselineEV = baselineShot?.evOffset
        let evOffsets = project.manifest.shots.map(\.evOffset)
        let evSpread = (evOffsets.max() ?? 0) - (evOffsets.min() ?? 0)
        let highlightGuardCount = baselineEV.map { baseline in
            project.manifest.shots.filter { $0.evOffset < baseline }.count
        } ?? 0
        let shadowGuardCount = baselineEV.map { baseline in
            project.manifest.shots.filter { $0.evOffset > baseline }.count
        } ?? 0
        let items = project.manifest.shots.map { shot in
            let evDelta = baselineEV.map { shot.evOffset - $0 } ?? 0
            let clippingSummary = shot.clippingWarnings.isEmpty
                ? "No manifest clipping warning"
                : shot.clippingWarnings.joined(separator: ", ")
            return Item(
                index: shot.index,
                shotLabel: "Shot \(shot.index + 1)",
                displayLabel: shot.displayLabel,
                evOffset: shot.evOffset,
                evDeltaFromBaseline: evDelta,
                role: role(for: shot, evDeltaFromBaseline: evDelta),
                captureState: shot.captureState,
                fileType: shot.fileType,
                availableRepresentations: shot.availableRepresentations,
                clippingWarningCount: shot.clippingWarnings.count,
                clippingSummary: clippingSummary
            )
        }

        return BracketProjectPerShotExposureDistribution(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            baselineIndex: baselineShot?.index,
            baselineDisplayLabel: baselineShot?.displayLabel,
            baselineEVOffset: baselineShot?.evOffset,
            shotCount: items.count,
            evSpread: evSpread,
            highlightGuardCount: highlightGuardCount,
            shadowGuardCount: shadowGuardCount,
            clippingWarningCount: items.reduce(0) { $0 + $1.clippingWarningCount },
            items: items,
            boundary: boundary
        )
    }

    var evSpreadLabel: String {
        BracketEVFormatter.displayLabel(for: evSpread)
    }

    var guardSummary: String {
        "\(highlightGuardCount) darker highlight guards and \(shadowGuardCount) brighter shadow guards"
    }

    var clippingSummary: String {
        clippingWarningCount == 0
            ? "No manifest clipping warnings"
            : "\(clippingWarningCount) manifest clipping warnings"
    }

    var accessibilityValue: String {
        [
            "Per-shot Exposure Distribution",
            title,
            "\(shotCount) shots",
            baselineDisplayLabel.map { "Baseline \($0)" },
            "EV spread \(evSpreadLabel)",
            guardSummary,
            clippingSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            boundary,
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    private static func role(
        for shot: BracketManifest.Shot,
        evDeltaFromBaseline: Float
    ) -> String {
        if shot.captureState.localizedCaseInsensitiveContains("missing") {
            return "Missing planned exposure"
        }
        if shot.captureState.localizedCaseInsensitiveContains("failed") {
            return "Failed exposure"
        }
        if shot.isBestExposureCandidate || evDeltaFromBaseline == 0 {
            return "Baseline exposure"
        }
        return evDeltaFromBaseline < 0 ? "Darker highlight guard" : "Brighter shadow guard"
    }
}

struct BracketProjectBestBaseFrameSuggestion: Codable, Equatable, Sendable {
    struct Candidate: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let captureState: String
        let fileType: String
        let availableRepresentations: [String]
        let score: Int
        let reasons: [String]

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                captureState,
                fileType,
                availableRepresentations.isEmpty ? "No representations" : availableRepresentations.joined(separator: ", "),
                "Score \(score)",
                reasons.joined(separator: ", "),
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "best-base-frame-suggestion"
    static let boundary = "Best base frame suggestion is manifest metadata and deterministic review guidance only; it does not inspect private Photos bytes, decoded RAW pixels, alignment, ghosting, final rendered output bytes, or physical-device captures, and it is not a final HDR merge decision."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let selectedIndex: Int?
    let selectedShotLabel: String
    let selectedDisplayLabel: String
    let selectedEVOffset: Float?
    let confidenceScore: Int
    let confidenceLabel: String
    let guardExposureSummary: String
    let rationale: [String]
    let candidates: [Candidate]
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectBestBaseFrameSuggestion {
        let candidates = project.manifest.shots
            .map(candidate(for:))
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return abs(left.evOffset) < abs(right.evOffset)
            }
        let selected = candidates.first
        let selectedEVOffset = selected?.evOffset
        let availableShots = project.manifest.shots.filter(isAvailable(_:))
        let highlightGuardCount = selectedEVOffset.map { selectedEV in
            availableShots.filter { $0.evOffset < selectedEV }.count
        } ?? 0
        let shadowGuardCount = selectedEVOffset.map { selectedEV in
            availableShots.filter { $0.evOffset > selectedEV }.count
        } ?? 0
        let guardExposureSummary = "\(highlightGuardCount) darker highlight guards and \(shadowGuardCount) brighter shadow guards"
        let rationale = rationale(
            selected: selected,
            guardExposureSummary: guardExposureSummary
        )
        let confidenceScore = selected?.score ?? 0

        return BracketProjectBestBaseFrameSuggestion(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            selectedIndex: selected?.index,
            selectedShotLabel: selected?.shotLabel ?? "No available base frame",
            selectedDisplayLabel: selected?.displayLabel ?? "No exposure",
            selectedEVOffset: selectedEVOffset,
            confidenceScore: confidenceScore,
            confidenceLabel: confidenceLabel(score: confidenceScore),
            guardExposureSummary: guardExposureSummary,
            rationale: rationale,
            candidates: candidates,
            boundary: boundary
        )
    }

    var hasSuggestion: Bool {
        selectedIndex != nil && confidenceScore > 0
    }

    var accessibilityValue: String {
        [
            "Best Base Frame Suggestion",
            title,
            selectedShotLabel,
            selectedDisplayLabel,
            "Confidence \(confidenceLabel) \(confidenceScore)",
            guardExposureSummary,
            rationale.joined(separator: " "),
            boundary,
        ].joined(separator: " | ")
    }

    private static func candidate(for shot: BracketManifest.Shot) -> Candidate {
        let available = isAvailable(shot)
        let hasRaw = shot.availableRepresentations.contains { $0.localizedCaseInsensitiveContains("raw") }
        let hasProcessed = shot.availableRepresentations.contains { representation in
            representation.localizedCaseInsensitiveContains("processed")
                || representation.localizedCaseInsensitiveContains("jpeg")
                || representation.localizedCaseInsensitiveContains("heif")
        }
        var reasons: [String] = []
        var score = available ? 60 : 0

        if available {
            reasons.append("available capture")
        } else {
            reasons.append("capture unavailable")
        }
        if shot.isBestExposureCandidate {
            score += 25
            reasons.append("marked best exposure")
        }
        let neutralScore = max(0, 20 - Int((abs(shot.evOffset) * 6).rounded()))
        if neutralScore > 0 {
            score += neutralScore
            reasons.append("near neutral exposure")
        }
        if hasRaw {
            score += 5
            reasons.append("RAW representation")
        }
        if hasProcessed {
            score += 5
            reasons.append("processed representation")
        }
        if shot.clippingWarnings.isEmpty {
            score += 5
            reasons.append("no manifest clipping warning")
        } else {
            score = max(0, score - 5)
            reasons.append("manifest clipping warning")
        }

        return Candidate(
            index: shot.index,
            shotLabel: "Shot \(shot.index + 1) / \(shot.displayLabel)",
            displayLabel: shot.displayLabel,
            evOffset: shot.evOffset,
            captureState: shot.captureState,
            fileType: shot.fileType,
            availableRepresentations: shot.availableRepresentations,
            score: min(100, score),
            reasons: reasons
        )
    }

    private static func isAvailable(_ shot: BracketManifest.Shot) -> Bool {
        shot.captureState.localizedCaseInsensitiveContains("available")
    }

    private static func confidenceLabel(score: Int) -> String {
        if score >= 90 { return "High" }
        if score >= 70 { return "Medium" }
        if score > 0 { return "Low" }
        return "Unavailable"
    }

    private static func rationale(
        selected: Candidate?,
        guardExposureSummary: String
    ) -> [String] {
        guard let selected else {
            return ["No available exposure can be suggested as a base frame from manifest metadata."]
        }

        return [
            "Use \(selected.shotLabel) as the neutral base frame.",
            "The bracket provides \(guardExposureSummary).",
            "Treat this as review guidance, not a final HDR merge decision.",
        ]
    }
}

struct BracketProjectSideBySidePixelComparison: Codable, Equatable, Sendable {
    struct Pair: Codable, Equatable, Identifiable, Sendable {
        let baselineIndex: Int
        let comparisonIndex: Int
        let baselineLabel: String
        let comparisonLabel: String
        let comparisonRole: String
        let width: Int
        let height: Int
        let baselineRGBABytes: [UInt8]
        let comparisonRGBABytes: [UInt8]
        let differenceRGBABytes: [UInt8]
        let byteCount: Int
        let maxChannelDelta: Int
        let summary: String

        var id: String {
            "\(baselineIndex)-\(comparisonIndex)"
        }

        var accessibilityValue: String {
            [
                "Side-by-side Pixel Compare",
                "Baseline \(baselineLabel)",
                "Compare \(comparisonLabel)",
                comparisonRole,
                "\(width)x\(height)",
                "Max channel delta \(maxChannelDelta)",
                summary
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "side-by-side-pixel-comparison"
    static let source = "deterministicFixture"
    static let boundary = "Side-by-side comparison from deterministic synthetic scene pixels; not derived from private Photos bytes and not a merge-readiness score."
    static let colorPipeline = "sRGB RGBA8 fixture strips generated by applying each EV offset to the same synthetic luminance ramp."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let boundary: String
    let colorPipeline: String
    let baselineIndex: Int
    let baselineLabel: String
    let baselineEVOffset: Float
    let comparisonCount: Int
    let pairs: [Pair]

    static func make(project: BracketProject) -> BracketProjectSideBySidePixelComparison? {
        let exposureComparison = BracketProjectExposureComparison.make(project: project)
        guard let baselineIndex = exposureComparison.baselineIndex,
              let baselineLabel = exposureComparison.baselineDisplayLabel,
              let baselineEVOffset = exposureComparison.baselineEVOffset else {
            return nil
        }

        let width = 3
        let height = 1
        let baselineBytes = deterministicRGBABytes(width: width, height: height, evOffset: baselineEVOffset)
        let pairs = exposureComparison.items.compactMap { item -> Pair? in
            guard item.index != baselineIndex,
                  item.captureState.localizedCaseInsensitiveContains("available") else {
                return nil
            }

            let comparisonBytes = deterministicRGBABytes(width: width, height: height, evOffset: item.evOffset)
            let differenceBytes = differenceRGBABytes(baselineBytes, comparisonBytes)
            let maxDelta = maxChannelDelta(in: differenceBytes)
            return Pair(
                baselineIndex: baselineIndex,
                comparisonIndex: item.index,
                baselineLabel: baselineLabel,
                comparisonLabel: item.displayLabel,
                comparisonRole: item.role,
                width: width,
                height: height,
                baselineRGBABytes: baselineBytes,
                comparisonRGBABytes: comparisonBytes,
                differenceRGBABytes: differenceBytes,
                byteCount: width * height * 4,
                maxChannelDelta: maxDelta,
                summary: "\(baselineLabel) baseline compared with \(item.displayLabel) using synthetic fixture pixels"
            )
        }

        guard !pairs.isEmpty else { return nil }

        return BracketProjectSideBySidePixelComparison(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            boundary: boundary,
            colorPipeline: colorPipeline,
            baselineIndex: baselineIndex,
            baselineLabel: baselineLabel,
            baselineEVOffset: baselineEVOffset,
            comparisonCount: pairs.count,
            pairs: pairs
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectSideBySidePixelComparison {
        BracketProjectSideBySidePixelComparison(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            source: source,
            boundary: boundary,
            colorPipeline: colorPipeline,
            baselineIndex: baselineIndex,
            baselineLabel: baselineLabel,
            baselineEVOffset: baselineEVOffset,
            comparisonCount: comparisonCount,
            pairs: pairs
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        guard let expected = BracketProjectSideBySidePixelComparison.make(project: project) else {
            return false
        }

        return self == expected
    }

    var accessibilityValue: String {
        [
            "Side-by-side Pixel Compare",
            title,
            "Baseline \(baselineLabel)",
            "\(comparisonCount) comparisons",
            source,
            boundary
        ].joined(separator: " | ")
    }

    private static func deterministicRGBABytes(
        width: Int,
        height: Int,
        evOffset: Float
    ) -> [UInt8] {
        let pixelCount = width * height
        let luminanceRamp: [Float] = [32, 128, 224]
        return (0..<pixelCount).reduce(into: [UInt8]()) { bytes, index in
            let base = luminanceRamp[index % luminanceRamp.count]
            let value = UInt8(clamping: Int((base * pow(2.0, evOffset)).rounded()))
            bytes.append(value)
            bytes.append(value)
            bytes.append(value)
            bytes.append(255)
        }
    }

    private static func differenceRGBABytes(
        _ baselineBytes: [UInt8],
        _ comparisonBytes: [UInt8]
    ) -> [UInt8] {
        zip(baselineBytes, comparisonBytes).enumerated().map { index, pair in
            if (index + 1).isMultiple(of: 4) {
                return 255
            }
            return UInt8(abs(Int(pair.0) - Int(pair.1)))
        }
    }

    private static func maxChannelDelta(in bytes: [UInt8]) -> Int {
        bytes.enumerated()
            .filter { index, _ in !(index + 1).isMultiple(of: 4) }
            .map { Int($0.element) }
            .max() ?? 0
    }
}

struct BracketProjectBeforeAfterScrubPlan: Codable, Equatable, Sendable {
    struct ScrubStop: Codable, Equatable, Identifiable, Sendable {
        let positionPercent: Int
        let baselineWeightPercent: Int
        let comparisonWeightPercent: Int
        let previewRGBABytes: [UInt8]
        let label: String

        var id: Int { positionPercent }

        var accessibilityValue: String {
            [
                label,
                "\(positionPercent) percent",
                "Base \(baselineWeightPercent) percent",
                "Compare \(comparisonWeightPercent) percent",
                "\(previewRGBABytes.count) preview bytes",
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "before-after-scrub-plan"
    static let boundary = "Before/after scrub is deterministic review guidance from manifest metadata and synthetic fixture pixels; it is not derived from private Photos bytes, decoded RAW pixels, alignment, ghosting, or final rendered output, and it is not a final HDR merge decision."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let baselineIndex: Int?
    let baselineLabel: String
    let comparisonIndex: Int?
    let comparisonLabel: String
    let comparisonRole: String
    let comparisonEVDeltaFromBaseline: Float?
    let stopCount: Int
    let scrubStops: [ScrubStop]
    let boundary: String

    static func make(
        project: BracketProject,
        selectedIndex: Int? = nil
    ) -> BracketProjectBeforeAfterScrubPlan {
        guard let comparison = BracketProjectSideBySidePixelComparison.make(project: project) else {
            let exposureComparison = BracketProjectExposureComparison.make(project: project)
            return BracketProjectBeforeAfterScrubPlan(
                schemaVersion: schemaVersion,
                projectID: project.id,
                title: project.displayTitle,
                baselineIndex: exposureComparison.baselineIndex,
                baselineLabel: exposureComparison.baselineDisplayLabel ?? "Baseline unavailable",
                comparisonIndex: nil,
                comparisonLabel: "No comparison exposure",
                comparisonRole: "Scrub unavailable",
                comparisonEVDeltaFromBaseline: nil,
                stopCount: 0,
                scrubStops: [],
                boundary: boundary
            )
        }

        let selectedPair = selectedPair(
            in: comparison.pairs,
            selectedIndex: selectedIndex,
            baselineIndex: comparison.baselineIndex
        )
        let stops = scrubStops(for: selectedPair)

        return BracketProjectBeforeAfterScrubPlan(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            baselineIndex: selectedPair.baselineIndex,
            baselineLabel: selectedPair.baselineLabel,
            comparisonIndex: selectedPair.comparisonIndex,
            comparisonLabel: selectedPair.comparisonLabel,
            comparisonRole: selectedPair.comparisonRole,
            comparisonEVDeltaFromBaseline: evDelta(
                baselineEVOffset: comparison.baselineEVOffset,
                pair: selectedPair,
                project: project
            ),
            stopCount: stops.count,
            scrubStops: stops,
            boundary: boundary
        )
    }

    var hasScrubStops: Bool {
        !scrubStops.isEmpty
    }

    var accessibilityValue: String {
        [
            "Before/After Scrub Plan",
            title,
            "Baseline \(baselineLabel)",
            "Compare \(comparisonLabel)",
            comparisonRole,
            comparisonEVDeltaFromBaseline.map { "Delta \(BracketEVFormatter.displayLabel(for: $0))" },
            "\(stopCount) scrub stops",
            boundary,
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    private static func selectedPair(
        in pairs: [BracketProjectSideBySidePixelComparison.Pair],
        selectedIndex: Int?,
        baselineIndex: Int
    ) -> BracketProjectSideBySidePixelComparison.Pair {
        if let selectedIndex,
           selectedIndex != baselineIndex,
           let exactPair = pairs.first(where: { $0.comparisonIndex == selectedIndex }) {
            return exactPair
        }

        return pairs.sorted { left, right in
            let leftDelta = abs(left.comparisonIndex - baselineIndex)
            let rightDelta = abs(right.comparisonIndex - baselineIndex)
            if leftDelta != rightDelta {
                return leftDelta < rightDelta
            }
            return left.comparisonIndex < right.comparisonIndex
        }.first ?? pairs[0]
    }

    private static func scrubStops(
        for pair: BracketProjectSideBySidePixelComparison.Pair
    ) -> [ScrubStop] {
        [0, 25, 50, 75, 100].map { position in
            let comparisonWeight = Float(position) / 100
            let baselineWeight = 1 - comparisonWeight
            return ScrubStop(
                positionPercent: position,
                baselineWeightPercent: 100 - position,
                comparisonWeightPercent: position,
                previewRGBABytes: blend(
                    baselineBytes: pair.baselineRGBABytes,
                    comparisonBytes: pair.comparisonRGBABytes,
                    baselineWeight: baselineWeight,
                    comparisonWeight: comparisonWeight
                ),
                label: position == 0 ? "Before base frame" : (position == 100 ? "After comparison frame" : "\(position)% scrub mix")
            )
        }
    }

    private static func blend(
        baselineBytes: [UInt8],
        comparisonBytes: [UInt8],
        baselineWeight: Float,
        comparisonWeight: Float
    ) -> [UInt8] {
        let count = min(baselineBytes.count, comparisonBytes.count)
        return (0..<count).map { index in
            let value = Float(baselineBytes[index]) * baselineWeight
                + Float(comparisonBytes[index]) * comparisonWeight
            return UInt8(clamping: Int(value.rounded()))
        }
    }

    private static func evDelta(
        baselineEVOffset: Float,
        pair: BracketProjectSideBySidePixelComparison.Pair,
        project: BracketProject
    ) -> Float? {
        project.manifest.shots.first { $0.index == pair.comparisonIndex }
            .map { $0.evOffset - baselineEVOffset }
    }
}

struct BracketProjectFocusEdgeInspection: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let captureState: String
        let role: String
        let syntheticEdgeRegionCount: Int
        let syntheticEdgeCandidateCount: Int
        let syntheticEdgeFractionPercent: Int
        let syntheticPeakEdgeStrengthPercent: Int
        let focusGuidance: String
        let edgeGuidance: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                captureState,
                "Edge tiles \(syntheticEdgeRegionCount)/\(syntheticEdgeCandidateCount)",
                "Edge fraction \(syntheticEdgeFractionPercent)%",
                "Peak edge strength \(syntheticPeakEdgeStrengthPercent)%",
                focusGuidance,
                edgeGuidance,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "focus-edge-inspection"
    static let source = "deterministicFixture"
    static let boundary = "Focus/edge inspection is deterministic fixture-pixel/metadata review guidance only; it does not inspect private Photos bytes, decoded RAW pixels, real focus samples, alignment, ghosting, final rendered output, or physical-device captures."
    static let syntheticFixtureNote = "Synthetic fixture pixels, not private Photos bytes"
    static let fixtureWidth = 4
    static let fixtureHeight = 4
    static let fixtureBaseLuminanceA: Float = 32
    static let fixtureBaseLuminanceB: Float = 224
    static let fixtureTileColumns = 4
    static let fixtureTileRows = 4
    static let edgeThreshold: UInt8 = 18
    static let regionWarningFraction: Float = 0.2

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let inspectedShotCount: Int
    let totalEdgeRegionCount: Int
    let clippedEdgeShotCount: Int
    let peakEdgeShotIndex: Int?
    let peakEdgeShotLabel: String
    let peakEdgeRegionCount: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectFocusEdgeInspection {
        let baselineShot = project.manifest.shots.first(where: \.isBestExposureCandidate)
            ?? project.manifest.shots.min { left, right in
                abs(left.evOffset) < abs(right.evOffset)
            }
        let baselineEV = baselineShot?.evOffset
        let items = project.manifest.shots.map { shot in
            inspectItem(for: shot, baselineEVOffset: baselineEV)
        }
        let inspected = items.filter { isAvailable(captureState: $0.captureState) }
        let totalEdgeRegions = items.reduce(0) { $0 + $1.syntheticEdgeRegionCount }
        let clippedEdgeShotCount = inspected.filter { $0.syntheticEdgeRegionCount == 0 }.count
        let peakItem = items.max { left, right in
            if left.syntheticEdgeRegionCount != right.syntheticEdgeRegionCount {
                return left.syntheticEdgeRegionCount < right.syntheticEdgeRegionCount
            }
            return left.syntheticPeakEdgeStrengthPercent < right.syntheticPeakEdgeStrengthPercent
        }
        let resolvedPeak: Item? = (peakItem?.syntheticEdgeRegionCount ?? 0) > 0 ? peakItem : nil
        let guidance = guidanceLines(
            baselineShot: baselineShot,
            items: items,
            inspectedCount: inspected.count,
            clippedEdgeShotCount: clippedEdgeShotCount,
            peakItem: resolvedPeak
        )

        return BracketProjectFocusEdgeInspection(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: baselineShot?.index,
            baselineLabel: baselineShot?.displayLabel ?? "Baseline unavailable",
            shotCount: items.count,
            inspectedShotCount: inspected.count,
            totalEdgeRegionCount: totalEdgeRegions,
            clippedEdgeShotCount: clippedEdgeShotCount,
            peakEdgeShotIndex: resolvedPeak?.index,
            peakEdgeShotLabel: resolvedPeak?.shotLabel ?? "No focus peak detected",
            peakEdgeRegionCount: resolvedPeak?.syntheticEdgeRegionCount ?? 0,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasFocusGuidance: Bool {
        shotCount > 0 && inspectedShotCount > 0
    }

    var summaryLabel: String {
        "\(inspectedShotCount)/\(shotCount) inspected"
    }

    var clippedEdgeSummary: String {
        clippedEdgeShotCount == 0
            ? "No clipped edge fixtures"
            : "\(clippedEdgeShotCount) shots with clipped synthetic edges"
    }

    var peakEdgeSummary: String {
        peakEdgeShotIndex == nil
            ? "No focus peak detected in synthetic fixture"
            : "Peak edges \(peakEdgeShotLabel) (\(peakEdgeRegionCount) tiles)"
    }

    var accessibilityValue: String {
        [
            "Focus/Edge Inspection",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            peakEdgeSummary,
            clippedEdgeSummary,
            "Total edge tiles \(totalEdgeRegionCount)",
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func inspectItem(
        for shot: BracketManifest.Shot,
        baselineEVOffset: Float?
    ) -> Item {
        let bytes = deterministicFixtureRGBABytes(evOffset: shot.evOffset)
        let analysis = HistogramFrameAnalyzer.analyzeRGBABytes(
            bytes,
            width: fixtureWidth,
            height: fixtureHeight,
            stepX: 1,
            stepY: 1,
            zebraColumns: fixtureTileColumns,
            zebraRows: fixtureTileRows,
            focusThresholds: FocusPeakingThresholds(
                edgeThreshold: edgeThreshold,
                regionWarningFraction: regionWarningFraction
            )
        )
        let regions = analysis?.focusPeakingMap.regions ?? []
        let regionCount = regions.count
        let candidateCount = max(0, fixtureTileColumns * fixtureTileRows - 1)
        let edgeFraction = candidateCount > 0
            ? Int(((Float(regionCount) / Float(candidateCount)) * 100).rounded())
            : 0
        let peakStrength = regions.map(\.strength).max() ?? 0
        let peakStrengthPercent = Int((min(1, max(0, peakStrength)) * 100).rounded())
        let role = role(
            for: shot,
            baselineEVOffset: baselineEVOffset,
            regionCount: regionCount
        )
        let focusGuidance = focusGuidance(
            shot: shot,
            baselineEVOffset: baselineEVOffset,
            regionCount: regionCount
        )
        let edgeGuidance = edgeGuidance(
            regionCount: regionCount,
            peakStrengthPercent: peakStrengthPercent
        )

        return Item(
            index: shot.index,
            shotLabel: "Shot \(shot.index + 1)",
            displayLabel: shot.displayLabel,
            evOffset: shot.evOffset,
            captureState: shot.captureState,
            role: role,
            syntheticEdgeRegionCount: regionCount,
            syntheticEdgeCandidateCount: candidateCount,
            syntheticEdgeFractionPercent: edgeFraction,
            syntheticPeakEdgeStrengthPercent: peakStrengthPercent,
            focusGuidance: focusGuidance,
            edgeGuidance: edgeGuidance
        )
    }

    private static func deterministicFixtureRGBABytes(evOffset: Float) -> [UInt8] {
        let pixelCount = fixtureWidth * fixtureHeight
        var bytes = [UInt8]()
        bytes.reserveCapacity(pixelCount * 4)
        let scale = pow(2.0, evOffset)
        for index in 0..<pixelCount {
            let column = index % fixtureWidth
            let row = index / fixtureWidth
            let useHigh = (column + row).isMultiple(of: 2) == false
            let base = useHigh ? fixtureBaseLuminanceB : fixtureBaseLuminanceA
            let scaled = base * scale
            let clamped = UInt8(clamping: Int(scaled.rounded()))
            bytes.append(clamped)
            bytes.append(clamped)
            bytes.append(clamped)
            bytes.append(255)
        }
        return bytes
    }

    private static func isAvailable(captureState: String) -> Bool {
        captureState.localizedCaseInsensitiveContains("available")
    }

    private static func role(
        for shot: BracketManifest.Shot,
        baselineEVOffset: Float?,
        regionCount: Int
    ) -> String {
        if shot.captureState.localizedCaseInsensitiveContains("missing") {
            return "Missing planned exposure"
        }
        if shot.captureState.localizedCaseInsensitiveContains("failed") {
            return "Failed exposure"
        }
        if regionCount == 0 {
            return "Edge detail clipped"
        }
        if shot.isBestExposureCandidate {
            return "Focus anchor"
        }
        if let baselineEVOffset {
            let delta = shot.evOffset - baselineEVOffset
            if delta == 0 {
                return "Reference focus"
            }
            return delta < 0 ? "Darker guard focus check" : "Brighter guard focus check"
        }
        return "Reference focus"
    }

    private static func focusGuidance(
        shot: BracketManifest.Shot,
        baselineEVOffset: Float?,
        regionCount: Int
    ) -> String {
        if shot.captureState.localizedCaseInsensitiveContains("missing") {
            return "Capture this exposure before relying on focus continuity."
        }
        if shot.captureState.localizedCaseInsensitiveContains("failed") {
            return "Recapture the failed exposure before reviewing focus."
        }
        if regionCount == 0 {
            return "Synthetic fixture shows no detectable edges; verify focus on the device before merging."
        }
        if shot.isBestExposureCandidate {
            return "Anchor merge focus to this base frame."
        }
        if let baselineEVOffset, shot.evOffset == baselineEVOffset {
            return "Treat as a focus reference alongside the base frame."
        }
        return "Use synthetic edges as a focus continuity proxy against the base frame."
    }

    private static func edgeGuidance(
        regionCount: Int,
        peakStrengthPercent: Int
    ) -> String {
        if regionCount == 0 {
            return "Edge detail clipped in synthetic fixture; expect reduced focus confidence."
        }
        return "Synthetic fixture retains \(regionCount) edge tiles with peak strength \(peakStrengthPercent)%."
    }

    private static func guidanceLines(
        baselineShot: BracketManifest.Shot?,
        items: [Item],
        inspectedCount: Int,
        clippedEdgeShotCount: Int,
        peakItem: Item?
    ) -> [String] {
        var lines: [String] = []
        if let baselineShot {
            lines.append("Anchor focus to Shot \(baselineShot.index + 1) / \(baselineShot.displayLabel) as the base frame.")
        } else {
            lines.append("No base frame available for focus anchoring from manifest metadata.")
        }
        if let peakItem {
            lines.append("\(peakItem.shotLabel) carries the strongest synthetic edges; cross-check focus continuity there.")
        } else if inspectedCount > 0 {
            lines.append("No detectable synthetic edges in any inspected shot; rely on device focus indicators before merging.")
        }
        if clippedEdgeShotCount > 0 {
            lines.append("\(clippedEdgeShotCount) shots show clipped synthetic edges; expect reduced focus confidence there.")
        }
        lines.append("Treat this as deterministic review guidance, not a final HDR merge decision.")
        return lines
    }
}

struct BracketProjectMotionMetadataReport: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let kind = "motion-metadata-capture"
    static let source = "manifestCaptureMotionMetadata"
    static let captureContractNote = "Motion metadata capture contract, not live IMU proof"
    static let boundary = "Motion metadata capture report summarizes bounded scalar manifest fields only; it does not include raw CMMotion samples, accelerometer streams, gyroscope streams, private Photos bytes, precise coordinates, RAW pixels, or final rendered output, and does not prove physical-device motion capture."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let hasManifestMotionSnapshot: Bool
    let sampleAvailability: String
    let sampleCount: Int
    let captureDurationMilliseconds: Int
    let maxAngularVelocityDegreesPerSecond: Int
    let maxAccelerationMilliG: Int
    let qualityLabel: String
    let captureSource: String
    let guidance: [String]
    let captureContractNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectMotionMetadataReport {
        let hasSnapshot = project.manifest.captureMotion != nil
        let snapshot = project.manifest.captureMotion
            ?? BracketManifest.CaptureMotionSnapshot.unavailable(
                source: "manifest missing capture motion metadata"
            )
        return BracketProjectMotionMetadataReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            hasManifestMotionSnapshot: hasSnapshot,
            sampleAvailability: snapshot.sampleAvailability,
            sampleCount: snapshot.sampleCount,
            captureDurationMilliseconds: snapshot.captureDurationMilliseconds,
            maxAngularVelocityDegreesPerSecond: snapshot.maxAngularVelocityDegreesPerSecond,
            maxAccelerationMilliG: snapshot.maxAccelerationMilliG,
            qualityLabel: snapshot.qualityLabel,
            captureSource: snapshot.source,
            guidance: guidanceLines(snapshot: snapshot, hasManifestMotionSnapshot: hasSnapshot),
            captureContractNote: captureContractNote,
            boundary: boundary
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

    var availabilitySummary: String {
        "\(sampleAvailability) motion metadata"
    }

    var durationSummary: String {
        "Duration \(captureDurationMilliseconds) ms"
    }

    var peakMotionSummary: String {
        "Peak \(maxAngularVelocityDegreesPerSecond) deg/s, \(maxAccelerationMilliG) milli-g"
    }

    var accessibilityValue: String {
        [
            "Motion Metadata Capture",
            title,
            summaryLabel,
            availabilitySummary,
            durationSummary,
            peakMotionSummary,
            qualityLabel,
            "Source \(captureSource)",
            hasManifestMotionSnapshot ? "Manifest motion snapshot present" : "Manifest motion snapshot missing",
            captureContractNote,
            guidance.joined(separator: " "),
            boundary,
        ].joined(separator: " | ")
    }

    private static func guidanceLines(
        snapshot: BracketManifest.CaptureMotionSnapshot,
        hasManifestMotionSnapshot: Bool
    ) -> [String] {
        if snapshot.hasMotionSamples {
            return [
                "\(snapshot.summaryLabel) are stored as scalar metadata for review triage.",
                "Use peak angular velocity and acceleration as capture context, not as final alignment or blur proof.",
                "Physical-device proof still requires a live hardware run with explicit CMMotion capture verification.",
            ]
        }

        if hasManifestMotionSnapshot {
            return [
                "The manifest records that motion metadata was unavailable for this capture path.",
                "Future CMMotion wiring should replace this with scalar sample counts and peak motion summaries.",
                "Do not treat simulator or unavailable metadata as physical-device motion proof.",
            ]
        }

        return [
            "This project predates the motion metadata contract or was imported without that field.",
            "Capture paths should write an explicit unavailable snapshot until live motion sampling is connected.",
            "Do not treat missing metadata as physical-device motion proof.",
        ]
    }
}

struct BracketProjectMotionAlignmentOverlay: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticMotionScore: Int
        let syntheticAlignmentOffsetXPoints: Int
        let syntheticAlignmentOffsetYPoints: Int
        let riskLabel: String
        let guidance: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Motion score \(syntheticMotionScore)",
                "Alignment offset x\(syntheticAlignmentOffsetXPoints) y\(syntheticAlignmentOffsetYPoints) pt",
                riskLabel,
                guidance,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "motion-alignment-overlay"
    static let source = "deterministicManifestFixture"
    static let syntheticFixtureNote = "Synthetic motion/alignment overlay, not real IMU samples"
    static let boundary = "Motion/alignment overlay is deterministic fixture-pixel/manifest scaffolding only; it does not read real CMMotion or IMU samples, does not compute real alignment transforms, does not detect ghosting, does not inspect private Photos bytes, does not decode RAW pixels, does not render final output, and does not prove physical-device behavior."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let overlayGuideCount: Int
    let maxSyntheticMotionScore: Int
    let maxSyntheticAlignmentOffsetPoints: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectMotionAlignmentOverlay {
        let baselineShot = project.manifest.shots.first(where: \.isBestExposureCandidate)
            ?? project.manifest.shots.min { left, right in
                abs(left.evOffset) < abs(right.evOffset)
            }
        let baselineIndex = baselineShot?.index ?? 0
        let baselineEV = baselineShot?.evOffset ?? 0
        let items = project.manifest.shots.map { shot in
            item(for: shot, baselineIndex: baselineIndex, baselineEVOffset: baselineEV)
        }
        let maxMotionScore = items.map(\.syntheticMotionScore).max() ?? 0
        let maxAlignmentOffset = items
            .map { abs($0.syntheticAlignmentOffsetXPoints) + abs($0.syntheticAlignmentOffsetYPoints) }
            .max() ?? 0
        let guidance = guidanceLines(
            baselineShot: baselineShot,
            maxMotionScore: maxMotionScore,
            maxAlignmentOffset: maxAlignmentOffset,
            itemCount: items.count
        )

        return BracketProjectMotionAlignmentOverlay(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: baselineShot?.index,
            baselineLabel: baselineShot?.displayLabel ?? "Baseline unavailable",
            shotCount: items.count,
            overlayGuideCount: items.count,
            maxSyntheticMotionScore: maxMotionScore,
            maxSyntheticAlignmentOffsetPoints: maxAlignmentOffset,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasOverlayGuidance: Bool {
        overlayGuideCount > 0
    }

    var summaryLabel: String {
        "\(overlayGuideCount) overlay guides"
    }

    var motionSummary: String {
        "Max synthetic motion score \(maxSyntheticMotionScore)"
    }

    var alignmentSummary: String {
        "Max synthetic offset \(maxSyntheticAlignmentOffsetPoints) pt"
    }

    var accessibilityValue: String {
        [
            "Motion/Alignment Overlay",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            motionSummary,
            alignmentSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(
        for shot: BracketManifest.Shot,
        baselineIndex: Int,
        baselineEVOffset: Float
    ) -> Item {
        let evDelta = shot.evOffset - baselineEVOffset
        let indexDelta = shot.index - baselineIndex
        let motionScore = Int((abs(evDelta) * 5 + Float(abs(indexDelta)) * 4).rounded())
        let offsetX = Int((evDelta * 2).rounded())
        let offsetY = indexDelta
        let role: String
        if shot.captureState.localizedCaseInsensitiveContains("missing") {
            role = "Missing overlay source"
        } else if shot.captureState.localizedCaseInsensitiveContains("failed") {
            role = "Failed overlay source"
        } else if shot.isBestExposureCandidate || (shot.evOffset == baselineEVOffset && shot.index == baselineIndex) {
            role = "Alignment anchor"
        } else if evDelta < 0 {
            role = "Darker guard overlay"
        } else {
            role = "Brighter guard overlay"
        }

        return Item(
            index: shot.index,
            shotLabel: "Shot \(shot.index + 1)",
            displayLabel: shot.displayLabel,
            evOffset: shot.evOffset,
            role: role,
            syntheticMotionScore: motionScore,
            syntheticAlignmentOffsetXPoints: offsetX,
            syntheticAlignmentOffsetYPoints: offsetY,
            riskLabel: riskLabel(for: motionScore),
            guidance: guidance(for: role, motionScore: motionScore)
        )
    }

    private static func riskLabel(for score: Int) -> String {
        switch score {
        case 0...10:
            return "Low synthetic motion risk"
        case 11...24:
            return "Moderate synthetic motion risk"
        default:
            return "High synthetic motion risk"
        }
    }

    private static func guidance(for role: String, motionScore: Int) -> String {
        if role == "Alignment anchor" {
            return "Anchor overlay preview to this base frame."
        }
        if role.contains("Missing") || role.contains("Failed") {
            return "Resolve capture availability before trusting overlay continuity."
        }
        if motionScore > 24 {
            return "Treat as a synthetic high-drift guide and verify on real captured frames before merging."
        }
        return "Use as deterministic overlay scaffolding against the base frame."
    }

    private static func guidanceLines(
        baselineShot: BracketManifest.Shot?,
        maxMotionScore: Int,
        maxAlignmentOffset: Int,
        itemCount: Int
    ) -> [String] {
        var lines: [String] = []
        if let baselineShot {
            lines.append("Anchor motion/alignment overlays to Shot \(baselineShot.index + 1) / \(baselineShot.displayLabel).")
        } else {
            lines.append("No baseline shot is available for overlay anchoring.")
        }
        lines.append("\(itemCount) synthetic overlay guides describe expected review scaffolding before real image alignment exists.")
        lines.append("Maximum synthetic motion score \(maxMotionScore) and offset \(maxAlignmentOffset) pt are fixture hints only.")
        lines.append("Do not treat this as IMU evidence, real alignment, deghosting, or final merge quality.")
        return lines
    }
}

struct BracketProjectFeatureMatchFixtureReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticFeatureCandidateCount: Int
        let syntheticMatchedFeaturePairCount: Int
        let syntheticOutlierPairCount: Int
        let syntheticMatchConfidencePercent: Int
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Feature candidates \(syntheticFeatureCandidateCount)",
                "Matched pairs \(syntheticMatchedFeaturePairCount)",
                "Outliers \(syntheticOutlierPairCount)",
                "Match confidence \(syntheticMatchConfidencePercent)%",
                recommendation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "feature-match-fixture"
    static let source = "deterministicFeatureMatchFixture"
    static let syntheticFixtureNote = "Synthetic feature-match fixture, not real pixel matching"
    static let boundary = "Feature-match fixture is deterministic manifest and fixture-pixel scaffolding only; it does not inspect real image features, match real pixels, compute descriptors, solve homographies, run optical flow, inspect private Photos bytes, decode RAW pixels, render final output, or prove physical-device captures."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let featureMatchGuideCount: Int
    let totalSyntheticFeatureCandidates: Int
    let totalSyntheticMatchedFeaturePairs: Int
    let totalSyntheticOutlierPairs: Int
    let averageSyntheticMatchConfidencePercent: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectFeatureMatchFixtureReport {
        let overlay = BracketProjectMotionAlignmentOverlay.make(project: project)
        let focus = BracketProjectFocusEdgeInspection.make(project: project)
        let focusByIndex = Dictionary(uniqueKeysWithValues: focus.items.map { ($0.index, $0) })
        let items = overlay.items.map { overlayItem in
            item(for: overlayItem, focusItem: focusByIndex[overlayItem.index])
        }
        let totalCandidates = items.reduce(0) { $0 + $1.syntheticFeatureCandidateCount }
        let totalMatches = items.reduce(0) { $0 + $1.syntheticMatchedFeaturePairCount }
        let totalOutliers = items.reduce(0) { $0 + $1.syntheticOutlierPairCount }
        let averageConfidence = items.isEmpty
            ? 0
            : Int((Float(items.reduce(0) { $0 + $1.syntheticMatchConfidencePercent }) / Float(items.count)).rounded())
        let guidance = guidanceLines(
            baselineLabel: overlay.baselineLabel,
            itemCount: items.count,
            totalCandidates: totalCandidates,
            totalMatches: totalMatches,
            totalOutliers: totalOutliers,
            averageConfidence: averageConfidence
        )

        return BracketProjectFeatureMatchFixtureReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: overlay.baselineIndex,
            baselineLabel: overlay.baselineLabel,
            shotCount: items.count,
            featureMatchGuideCount: items.count,
            totalSyntheticFeatureCandidates: totalCandidates,
            totalSyntheticMatchedFeaturePairs: totalMatches,
            totalSyntheticOutlierPairs: totalOutliers,
            averageSyntheticMatchConfidencePercent: averageConfidence,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasFeatureMatchGuidance: Bool {
        featureMatchGuideCount > 0
    }

    var summaryLabel: String {
        "\(featureMatchGuideCount) feature-match guides"
    }

    var matchSummary: String {
        "\(totalSyntheticMatchedFeaturePairs) synthetic matched pairs"
    }

    var confidenceSummary: String {
        "Avg match confidence \(averageSyntheticMatchConfidencePercent)%"
    }

    var accessibilityValue: String {
        [
            "Feature Match Fixture",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            "\(totalSyntheticFeatureCandidates) synthetic feature candidates",
            matchSummary,
            "\(totalSyntheticOutlierPairs) synthetic outliers",
            confidenceSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(
        for overlayItem: BracketProjectMotionAlignmentOverlay.Item,
        focusItem: BracketProjectFocusEdgeInspection.Item?
    ) -> Item {
        let edgeRegions = focusItem?.syntheticEdgeRegionCount ?? 0
        let candidateCount = max(4, edgeRegions * 6 + 8)
        let driftPenalty = overlayItem.syntheticMotionScore
            + abs(overlayItem.syntheticAlignmentOffsetXPoints)
            + abs(overlayItem.syntheticAlignmentOffsetYPoints * 2)
        let matchedPairs = max(0, candidateCount - max(0, driftPenalty / 2))
        let outlierPairs = max(0, candidateCount - matchedPairs)
        let confidence = candidateCount == 0
            ? 0
            : min(98, max(35, Int(((Float(matchedPairs) / Float(candidateCount)) * 100).rounded()) - max(0, driftPenalty / 5)))
        let role = role(
            overlayRole: overlayItem.role,
            edgeRegions: edgeRegions,
            confidence: confidence
        )

        return Item(
            index: overlayItem.index,
            shotLabel: overlayItem.shotLabel,
            displayLabel: overlayItem.displayLabel,
            evOffset: overlayItem.evOffset,
            role: role,
            syntheticFeatureCandidateCount: candidateCount,
            syntheticMatchedFeaturePairCount: matchedPairs,
            syntheticOutlierPairCount: outlierPairs,
            syntheticMatchConfidencePercent: confidence,
            recommendation: recommendation(role: role, confidence: confidence, outlierPairs: outlierPairs)
        )
    }

    private static func role(
        overlayRole: String,
        edgeRegions: Int,
        confidence: Int
    ) -> String {
        if overlayRole == "Alignment anchor" {
            return "Baseline feature anchor"
        }
        if overlayRole.contains("Missing") || overlayRole.contains("Failed") {
            return "Unavailable feature source"
        }
        if edgeRegions == 0 {
            return "Low-texture feature source"
        }
        if confidence >= 80 {
            return "Strong synthetic feature match"
        }
        if confidence >= 60 {
            return "Moderate synthetic feature match"
        }
        return "Weak synthetic feature match"
    }

    private static func recommendation(
        role: String,
        confidence: Int,
        outlierPairs: Int
    ) -> String {
        if role == "Baseline feature anchor" {
            return "Use this frame as the identity feature-match reference."
        }
        if role == "Unavailable feature source" {
            return "Resolve capture availability before matching features."
        }
        if confidence < 60 {
            return "Treat as a future low-confidence registration seam and require real feature validation."
        }
        return "Use \(outlierPairs) synthetic outliers as a fixture-only robustness hint before real descriptors exist."
    }

    private static func guidanceLines(
        baselineLabel: String,
        itemCount: Int,
        totalCandidates: Int,
        totalMatches: Int,
        totalOutliers: Int,
        averageConfidence: Int
    ) -> [String] {
        [
            "Anchor future feature matching to the \(baselineLabel) base frame.",
            "\(itemCount) deterministic feature-match guides derive \(totalMatches) matched pairs from \(totalCandidates) synthetic candidates.",
            "\(totalOutliers) synthetic outliers and \(averageConfidence)% average confidence are fixture hints only.",
            "Do not treat this as real feature detection, descriptor matching, homography solving, or physical-device proof.",
        ]
    }
}

struct BracketProjectAlignmentTransformReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticFeaturePairCount: Int
        let syntheticTranslationXPoints: Int
        let syntheticTranslationYPoints: Int
        let syntheticTransformConfidencePercent: Int
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Feature pairs \(syntheticFeaturePairCount)",
                "Translation x\(syntheticTranslationXPoints) y\(syntheticTranslationYPoints) pt",
                "Transform confidence \(syntheticTransformConfidencePercent)%",
                recommendation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "alignment-transform"
    static let source = "deterministicManifestAlignment"
    static let syntheticFixtureNote = "Synthetic alignment transform, not real feature matching"
    static let boundary = "Alignment transform is deterministic manifest scaffolding only; it does not detect real image features, match pixels, compute real homographies or warps, inspect private Photos bytes, decode RAW pixels, read real motion sensors, render final output, or prove physical-device captures."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let transformGuideCount: Int
    let totalSyntheticFeaturePairs: Int
    let maxSyntheticTranslationPoints: Int
    let averageSyntheticConfidencePercent: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectAlignmentTransformReport {
        let overlay = BracketProjectMotionAlignmentOverlay.make(project: project)
        let items = overlay.items.map { item(for: $0) }
        let totalPairs = items.reduce(0) { $0 + $1.syntheticFeaturePairCount }
        let maxTranslation = items
            .map { abs($0.syntheticTranslationXPoints) + abs($0.syntheticTranslationYPoints) }
            .max() ?? 0
        let averageConfidence = items.isEmpty
            ? 0
            : Int((Float(items.reduce(0) { $0 + $1.syntheticTransformConfidencePercent }) / Float(items.count)).rounded())
        let guidance = guidanceLines(
            baselineLabel: overlay.baselineLabel,
            itemCount: items.count,
            totalPairs: totalPairs,
            maxTranslation: maxTranslation,
            averageConfidence: averageConfidence
        )

        return BracketProjectAlignmentTransformReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: overlay.baselineIndex,
            baselineLabel: overlay.baselineLabel,
            shotCount: items.count,
            transformGuideCount: items.count,
            totalSyntheticFeaturePairs: totalPairs,
            maxSyntheticTranslationPoints: maxTranslation,
            averageSyntheticConfidencePercent: averageConfidence,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasTransformGuidance: Bool {
        transformGuideCount > 0
    }

    var summaryLabel: String {
        "\(transformGuideCount) transform guides"
    }

    var featurePairSummary: String {
        "\(totalSyntheticFeaturePairs) synthetic feature pairs"
    }

    var confidenceSummary: String {
        "Avg confidence \(averageSyntheticConfidencePercent)%"
    }

    var accessibilityValue: String {
        [
            "Alignment Transform",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            featurePairSummary,
            confidenceSummary,
            "Max synthetic translation \(maxSyntheticTranslationPoints) pt",
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(for overlayItem: BracketProjectMotionAlignmentOverlay.Item) -> Item {
        let translationMagnitude = abs(overlayItem.syntheticAlignmentOffsetXPoints)
            + abs(overlayItem.syntheticAlignmentOffsetYPoints)
        let featurePairs = max(8, 32 - translationMagnitude - overlayItem.syntheticMotionScore / 2)
        let confidence = max(40, min(100, 100 - overlayItem.syntheticMotionScore - translationMagnitude * 2))
        let role: String
        if overlayItem.role == "Alignment anchor" {
            role = "Identity transform anchor"
        } else if overlayItem.evOffset < 0 {
            role = "Dark guard translation"
        } else if overlayItem.evOffset > 0 {
            role = "Bright guard translation"
        } else {
            role = "Reference translation"
        }

        return Item(
            index: overlayItem.index,
            shotLabel: overlayItem.shotLabel,
            displayLabel: overlayItem.displayLabel,
            evOffset: overlayItem.evOffset,
            role: role,
            syntheticFeaturePairCount: featurePairs,
            syntheticTranslationXPoints: overlayItem.syntheticAlignmentOffsetXPoints,
            syntheticTranslationYPoints: overlayItem.syntheticAlignmentOffsetYPoints,
            syntheticTransformConfidencePercent: confidence,
            recommendation: recommendation(role: role, confidence: confidence)
        )
    }

    private static func recommendation(role: String, confidence: Int) -> String {
        if role == "Identity transform anchor" {
            return "Use this base frame as the identity transform reference."
        }
        if confidence < 60 {
            return "Treat as low-confidence synthetic translation until real feature matching exists."
        }
        return "Use as deterministic transform scaffolding, not real image registration."
    }

    private static func guidanceLines(
        baselineLabel: String,
        itemCount: Int,
        totalPairs: Int,
        maxTranslation: Int,
        averageConfidence: Int
    ) -> [String] {
        [
            "Anchor alignment transforms to the \(baselineLabel) base frame.",
            "\(itemCount) deterministic transform guides describe future registration seams using \(totalPairs) synthetic feature pairs.",
            "Maximum synthetic translation \(maxTranslation) pt and average confidence \(averageConfidence)% are fixture hints only.",
            "Do not treat this as feature detection, pixel matching, homography solving, or final merge quality.",
        ]
    }
}

struct BracketProjectMotionBlurRiskReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticMotionScore: Int
        let syntheticExposurePressureScore: Int
        let syntheticBlurRiskScore: Int
        let riskLabel: String
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Motion score \(syntheticMotionScore)",
                "Exposure pressure \(syntheticExposurePressureScore)",
                "Blur risk \(syntheticBlurRiskScore)",
                riskLabel,
                recommendation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "motion-blur-risk"
    static let source = "deterministicManifestRisk"
    static let syntheticFixtureNote = "Synthetic motion/blur risk, not real shutter or sensor evidence"
    static let boundary = "Motion/blur risk is deterministic manifest scaffolding only; it does not read real shutter speed, exposure duration, ISO, CMMotion or IMU samples, optical flow, ghosting masks, private Photos bytes, decoded RAW pixels, final rendered output, or physical-device captures."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let riskGuideCount: Int
    let highRiskShotCount: Int
    let maxSyntheticBlurRiskScore: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectMotionBlurRiskReport {
        let overlay = BracketProjectMotionAlignmentOverlay.make(project: project)
        let items = overlay.items.map { overlayItem in
            item(for: overlayItem)
        }
        let highRiskShotCount = items.filter { $0.syntheticBlurRiskScore >= 35 }.count
        let maxBlurRisk = items.map(\.syntheticBlurRiskScore).max() ?? 0
        let guidance = guidanceLines(
            baselineLabel: overlay.baselineLabel,
            highRiskShotCount: highRiskShotCount,
            maxBlurRisk: maxBlurRisk,
            itemCount: items.count
        )

        return BracketProjectMotionBlurRiskReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: overlay.baselineIndex,
            baselineLabel: overlay.baselineLabel,
            shotCount: items.count,
            riskGuideCount: items.count,
            highRiskShotCount: highRiskShotCount,
            maxSyntheticBlurRiskScore: maxBlurRisk,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasRiskGuidance: Bool {
        riskGuideCount > 0
    }

    var summaryLabel: String {
        "\(riskGuideCount) blur-risk guides"
    }

    var highRiskSummary: String {
        highRiskShotCount == 0
            ? "No high synthetic blur risk"
            : "\(highRiskShotCount) high synthetic blur risks"
    }

    var maxRiskSummary: String {
        "Max blur risk \(maxSyntheticBlurRiskScore)"
    }

    var accessibilityValue: String {
        [
            "Motion/Blur Risk",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            highRiskSummary,
            maxRiskSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(for overlayItem: BracketProjectMotionAlignmentOverlay.Item) -> Item {
        let exposurePressure = max(0, Int((overlayItem.evOffset * 6).rounded()))
        let blurRisk = overlayItem.syntheticMotionScore + exposurePressure
        let role: String
        if overlayItem.role == "Alignment anchor" {
            role = "Blur anchor"
        } else if overlayItem.evOffset > 0 {
            role = "Longer-exposure blur watch"
        } else if overlayItem.evOffset < 0 {
            role = "Shorter-exposure motion reference"
        } else {
            role = "Reference blur guide"
        }

        return Item(
            index: overlayItem.index,
            shotLabel: overlayItem.shotLabel,
            displayLabel: overlayItem.displayLabel,
            evOffset: overlayItem.evOffset,
            role: role,
            syntheticMotionScore: overlayItem.syntheticMotionScore,
            syntheticExposurePressureScore: exposurePressure,
            syntheticBlurRiskScore: blurRisk,
            riskLabel: riskLabel(for: blurRisk),
            recommendation: recommendation(role: role, riskScore: blurRisk)
        )
    }

    private static func riskLabel(for score: Int) -> String {
        switch score {
        case 0...15:
            return "Low synthetic blur risk"
        case 16...34:
            return "Moderate synthetic blur risk"
        default:
            return "High synthetic blur risk"
        }
    }

    private static func recommendation(role: String, riskScore: Int) -> String {
        if role == "Blur anchor" {
            return "Use this base frame as the blur comparison anchor."
        }
        if riskScore >= 35 {
            return "Treat as a synthetic blur watch frame; verify real sharpness before merging."
        }
        return "Use as deterministic blur-risk context, not a real sharpness measurement."
    }

    private static func guidanceLines(
        baselineLabel: String,
        highRiskShotCount: Int,
        maxBlurRisk: Int,
        itemCount: Int
    ) -> [String] {
        [
            "Anchor blur review to the \(baselineLabel) base frame.",
            "\(itemCount) deterministic risk guides prioritize where future real sharpness checks should look.",
            "\(highRiskShotCount) shots cross the synthetic high-risk threshold; max blur risk \(maxBlurRisk).",
            "Do not treat this as shutter-speed evidence, optical flow, deghosting, or final merge quality.",
        ]
    }
}

struct BracketProjectGhostingRiskReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticBlurRiskScore: Int
        let syntheticAlignmentOffsetPoints: Int
        let syntheticGhostingRiskScore: Int
        let riskLabel: String
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Blur risk \(syntheticBlurRiskScore)",
                "Alignment offset \(syntheticAlignmentOffsetPoints) pt",
                "Ghosting risk \(syntheticGhostingRiskScore)",
                riskLabel,
                recommendation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "ghosting-risk"
    static let source = "deterministicManifestGhostingRisk"
    static let syntheticFixtureNote = "Synthetic ghosting risk, not moving-subject detection"
    static let boundary = "Ghosting risk is deterministic manifest scaffolding only; it does not run optical flow, segment moving subjects, compute deghosting masks, inspect private Photos bytes, decode RAW pixels, read real motion sensors, render final output, or prove physical-device captures."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let riskGuideCount: Int
    let highRiskShotCount: Int
    let maxSyntheticGhostingRiskScore: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectGhostingRiskReport {
        let blur = BracketProjectMotionBlurRiskReport.make(project: project)
        let overlay = BracketProjectMotionAlignmentOverlay.make(project: project)
        let offsetsByIndex = Dictionary(
            uniqueKeysWithValues: overlay.items.map { item in
                (item.index, abs(item.syntheticAlignmentOffsetXPoints) + abs(item.syntheticAlignmentOffsetYPoints))
            }
        )
        let items = blur.items.map { blurItem in
            item(
                for: blurItem,
                alignmentOffsetPoints: offsetsByIndex[blurItem.index] ?? 0
            )
        }
        let highRiskShotCount = items.filter { $0.syntheticGhostingRiskScore >= 42 }.count
        let maxGhostingRisk = items.map(\.syntheticGhostingRiskScore).max() ?? 0
        let guidance = guidanceLines(
            baselineLabel: blur.baselineLabel,
            highRiskShotCount: highRiskShotCount,
            maxGhostingRisk: maxGhostingRisk,
            itemCount: items.count
        )

        return BracketProjectGhostingRiskReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: blur.baselineIndex,
            baselineLabel: blur.baselineLabel,
            shotCount: items.count,
            riskGuideCount: items.count,
            highRiskShotCount: highRiskShotCount,
            maxSyntheticGhostingRiskScore: maxGhostingRisk,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasRiskGuidance: Bool {
        riskGuideCount > 0
    }

    var summaryLabel: String {
        "\(riskGuideCount) ghosting-risk guides"
    }

    var highRiskSummary: String {
        highRiskShotCount == 0
            ? "No high synthetic ghosting risk"
            : "\(highRiskShotCount) high synthetic ghosting risks"
    }

    var maxRiskSummary: String {
        "Max ghosting risk \(maxSyntheticGhostingRiskScore)"
    }

    var accessibilityValue: String {
        [
            "Ghosting Risk",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            highRiskSummary,
            maxRiskSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(
        for blurItem: BracketProjectMotionBlurRiskReport.Item,
        alignmentOffsetPoints: Int
    ) -> Item {
        let exposureSpreadPressure = Int((abs(blurItem.evOffset) * 3).rounded())
        let ghostingRisk = blurItem.syntheticBlurRiskScore + alignmentOffsetPoints + exposureSpreadPressure
        let role: String
        if blurItem.role == "Blur anchor" {
            role = "Deghosting anchor"
        } else if blurItem.evOffset > 0 {
            role = "Bright ghosting watch"
        } else if blurItem.evOffset < 0 {
            role = "Dark ghosting reference"
        } else {
            role = "Reference ghosting guide"
        }

        return Item(
            index: blurItem.index,
            shotLabel: blurItem.shotLabel,
            displayLabel: blurItem.displayLabel,
            evOffset: blurItem.evOffset,
            role: role,
            syntheticBlurRiskScore: blurItem.syntheticBlurRiskScore,
            syntheticAlignmentOffsetPoints: alignmentOffsetPoints,
            syntheticGhostingRiskScore: ghostingRisk,
            riskLabel: riskLabel(for: ghostingRisk),
            recommendation: recommendation(role: role, riskScore: ghostingRisk)
        )
    }

    private static func riskLabel(for score: Int) -> String {
        switch score {
        case 0...20:
            return "Low synthetic ghosting risk"
        case 21...41:
            return "Moderate synthetic ghosting risk"
        default:
            return "High synthetic ghosting risk"
        }
    }

    private static func recommendation(role: String, riskScore: Int) -> String {
        if role == "Deghosting anchor" {
            return "Use this base frame as the deghosting comparison anchor."
        }
        if riskScore >= 42 {
            return "Treat as a synthetic ghosting watch frame; verify moving subjects on real pixels before merging."
        }
        return "Use as deterministic ghosting context, not a moving-subject mask."
    }

    private static func guidanceLines(
        baselineLabel: String,
        highRiskShotCount: Int,
        maxGhostingRisk: Int,
        itemCount: Int
    ) -> [String] {
        [
            "Anchor ghosting review to the \(baselineLabel) base frame.",
            "\(itemCount) deterministic risk guides prioritize where future moving-subject checks should look.",
            "\(highRiskShotCount) shots cross the synthetic ghosting threshold; max ghosting risk \(maxGhostingRisk).",
            "Do not treat this as optical flow, subject segmentation, deghosting masks, or final merge quality.",
        ]
    }
}

struct BracketProjectMovingRegionMaskReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticGhostingRiskScore: Int
        let syntheticMaskTileCount: Int
        let syntheticMaskCoveragePercent: Int
        let maskPriorityLabel: String
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Ghosting risk \(syntheticGhostingRiskScore)",
                "Mask tiles \(syntheticMaskTileCount)",
                "Mask coverage \(syntheticMaskCoveragePercent)%",
                maskPriorityLabel,
                recommendation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "moving-region-mask"
    static let source = "deterministicManifestMovingRegionMask"
    static let syntheticFixtureNote = "Synthetic moving-region masks, not real subject segmentation"
    static let boundary = "Moving-region mask report is deterministic manifest scaffolding only; it does not segment moving subjects, run optical flow, compute real deghosting masks, inspect private Photos bytes, decode RAW pixels, read real motion sensors, render final output, or prove physical-device captures."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let maskGuideCount: Int
    let highPriorityMaskCount: Int
    let maxSyntheticMaskCoveragePercent: Int
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectMovingRegionMaskReport {
        let ghosting = BracketProjectGhostingRiskReport.make(project: project)
        let items = ghosting.items.map(item(for:))
        let highPriorityMaskCount = items.filter { $0.syntheticMaskCoveragePercent >= 36 }.count
        let maxSyntheticMaskCoveragePercent = items.map(\.syntheticMaskCoveragePercent).max() ?? 0
        let guidance = guidanceLines(
            baselineLabel: ghosting.baselineLabel,
            highPriorityMaskCount: highPriorityMaskCount,
            maxSyntheticMaskCoveragePercent: maxSyntheticMaskCoveragePercent,
            itemCount: items.count
        )

        return BracketProjectMovingRegionMaskReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: ghosting.baselineIndex,
            baselineLabel: ghosting.baselineLabel,
            shotCount: items.count,
            maskGuideCount: items.count,
            highPriorityMaskCount: highPriorityMaskCount,
            maxSyntheticMaskCoveragePercent: maxSyntheticMaskCoveragePercent,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasMaskGuidance: Bool {
        maskGuideCount > 0
    }

    var summaryLabel: String {
        maskGuideCount == 1 ? "1 mask guide" : "\(maskGuideCount) mask guides"
    }

    var highPrioritySummary: String {
        highPriorityMaskCount == 0
            ? "No high-priority mask guides"
            : "\(highPriorityMaskCount) high-priority mask guides"
    }

    var maxCoverageSummary: String {
        "Max mask coverage \(maxSyntheticMaskCoveragePercent)%"
    }

    var accessibilityValue: String {
        [
            "Moving-Region Mask",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            highPrioritySummary,
            maxCoverageSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(for ghostingItem: BracketProjectGhostingRiskReport.Item) -> Item {
        let tileCount = max(
            0,
            min(16, Int((Float(ghostingItem.syntheticGhostingRiskScore) / 6).rounded()))
        )
        let coveragePercent = tileCount * 6
        let role: String
        if ghostingItem.role == "Deghosting anchor" {
            role = "Mask anchor"
        } else if ghostingItem.evOffset > 0 {
            role = "Bright moving-region watch"
        } else if ghostingItem.evOffset < 0 {
            role = "Dark moving-region reference"
        } else {
            role = "Reference moving-region guide"
        }

        return Item(
            index: ghostingItem.index,
            shotLabel: ghostingItem.shotLabel,
            displayLabel: ghostingItem.displayLabel,
            evOffset: ghostingItem.evOffset,
            role: role,
            syntheticGhostingRiskScore: ghostingItem.syntheticGhostingRiskScore,
            syntheticMaskTileCount: tileCount,
            syntheticMaskCoveragePercent: coveragePercent,
            maskPriorityLabel: maskPriorityLabel(for: coveragePercent),
            recommendation: recommendation(role: role, coveragePercent: coveragePercent)
        )
    }

    private static func maskPriorityLabel(for coveragePercent: Int) -> String {
        switch coveragePercent {
        case 0...17:
            return "Low priority synthetic mask guide"
        case 18...35:
            return "Moderate priority synthetic mask guide"
        default:
            return "High priority synthetic mask guide"
        }
    }

    private static func recommendation(role: String, coveragePercent: Int) -> String {
        if role == "Mask anchor" {
            return "Use this base frame as the static mask anchor."
        }
        if coveragePercent >= 36 {
            return "Queue this frame for future moving-region mask review against real pixels."
        }
        return "Use as deterministic mask context, not a real subject segmentation."
    }

    private static func guidanceLines(
        baselineLabel: String,
        highPriorityMaskCount: Int,
        maxSyntheticMaskCoveragePercent: Int,
        itemCount: Int
    ) -> [String] {
        [
            "Anchor synthetic mask review to the \(baselineLabel) base frame.",
            "\(itemCount) deterministic mask guides mark where a future deghosting UI should ask for real-pixel confirmation.",
            "\(highPriorityMaskCount) shots cross the synthetic mask threshold; max mask coverage \(maxSyntheticMaskCoveragePercent)%.",
            "Do not treat this as subject segmentation, optical flow, real deghosting masks, or final merge quality.",
        ]
    }
}

struct BracketProjectAlignmentPerformanceReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticFeaturePairCount: Int
        let syntheticMaskTileCount: Int
        let estimatedAlignmentWorkUnits: Int
        let estimatedMaskWorkUnits: Int
        let estimatedTotalWorkUnits: Int
        let budgetLabel: String
        let recommendation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Feature pairs \(syntheticFeaturePairCount)",
                "Mask tiles \(syntheticMaskTileCount)",
                "Alignment work \(estimatedAlignmentWorkUnits)",
                "Mask work \(estimatedMaskWorkUnits)",
                "Total work \(estimatedTotalWorkUnits)",
                budgetLabel,
                recommendation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "alignment-performance"
    static let source = "deterministicManifestAlignmentPerformance"
    static let syntheticFixtureNote = "Synthetic alignment performance notes, not measured Instruments timing"
    static let boundary = "Alignment performance report is deterministic manifest scaffolding only; it does not run Instruments, measure CPU or GPU time, profile memory, inspect private Photos bytes, decode RAW pixels, render final output, or prove physical-device performance."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let performanceNoteCount: Int
    let totalEstimatedWorkUnits: Int
    let peakEstimatedWorkUnits: Int
    let peakShotLabel: String
    let frameBudgetLabel: String
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectAlignmentPerformanceReport {
        let transforms = BracketProjectAlignmentTransformReport.make(project: project)
        let masks = BracketProjectMovingRegionMaskReport.make(project: project)
        let masksByIndex = Dictionary(uniqueKeysWithValues: masks.items.map { ($0.index, $0) })
        let items = transforms.items.map { transform in
            item(for: transform, mask: masksByIndex[transform.index])
        }
        let totalWork = items.reduce(0) { $0 + $1.estimatedTotalWorkUnits }
        let peak = items.max { lhs, rhs in
            lhs.estimatedTotalWorkUnits < rhs.estimatedTotalWorkUnits
        }
        let peakWork = peak?.estimatedTotalWorkUnits ?? 0
        let peakShotLabel = peak?.shotLabel ?? "No shot"
        let frameBudget = frameBudgetLabel(for: peakWork)
        let guidance = guidanceLines(
            baselineLabel: transforms.baselineLabel,
            itemCount: items.count,
            totalWork: totalWork,
            peakShotLabel: peakShotLabel,
            peakWork: peakWork,
            frameBudget: frameBudget
        )

        return BracketProjectAlignmentPerformanceReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: transforms.baselineIndex,
            baselineLabel: transforms.baselineLabel,
            shotCount: items.count,
            performanceNoteCount: items.count,
            totalEstimatedWorkUnits: totalWork,
            peakEstimatedWorkUnits: peakWork,
            peakShotLabel: peakShotLabel,
            frameBudgetLabel: frameBudget,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasPerformanceNotes: Bool {
        performanceNoteCount > 0
    }

    var summaryLabel: String {
        performanceNoteCount == 1 ? "1 performance note" : "\(performanceNoteCount) performance notes"
    }

    var totalWorkSummary: String {
        "Total synthetic work \(totalEstimatedWorkUnits)"
    }

    var peakWorkSummary: String {
        "Peak \(peakShotLabel) \(peakEstimatedWorkUnits)"
    }

    var accessibilityValue: String {
        [
            "Alignment Performance Notes",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            totalWorkSummary,
            peakWorkSummary,
            frameBudgetLabel,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(
        for transform: BracketProjectAlignmentTransformReport.Item,
        mask: BracketProjectMovingRegionMaskReport.Item?
    ) -> Item {
        let translationMagnitude = abs(transform.syntheticTranslationXPoints)
            + abs(transform.syntheticTranslationYPoints)
        let maskTiles = mask?.syntheticMaskTileCount ?? 0
        let alignmentWork = transform.syntheticFeaturePairCount * max(1, translationMagnitude + 1)
        let maskWork = maskTiles * 6
        let totalWork = alignmentWork + maskWork
        let role: String
        if transform.role == "Identity transform anchor" {
            role = "Performance anchor"
        } else if transform.evOffset > 0 {
            role = "Bright-frame budget watch"
        } else if transform.evOffset < 0 {
            role = "Dark-frame budget reference"
        } else {
            role = "Reference budget guide"
        }

        return Item(
            index: transform.index,
            shotLabel: transform.shotLabel,
            displayLabel: transform.displayLabel,
            evOffset: transform.evOffset,
            role: role,
            syntheticFeaturePairCount: transform.syntheticFeaturePairCount,
            syntheticMaskTileCount: maskTiles,
            estimatedAlignmentWorkUnits: alignmentWork,
            estimatedMaskWorkUnits: maskWork,
            estimatedTotalWorkUnits: totalWork,
            budgetLabel: budgetLabel(for: totalWork),
            recommendation: recommendation(role: role, totalWork: totalWork)
        )
    }

    private static func budgetLabel(for totalWork: Int) -> String {
        switch totalWork {
        case 0...79:
            return "Nominal synthetic performance budget"
        case 80...159:
            return "Watch synthetic performance budget"
        default:
            return "Heavy synthetic performance budget"
        }
    }

    private static func frameBudgetLabel(for peakWork: Int) -> String {
        switch peakWork {
        case 0...79:
            return "Frame budget: nominal synthetic review cost"
        case 80...159:
            return "Frame budget: watch synthetic review cost"
        default:
            return "Frame budget: heavy synthetic review cost"
        }
    }

    private static func recommendation(role: String, totalWork: Int) -> String {
        if role == "Performance anchor" {
            return "Use this base frame as the zero-transform performance anchor."
        }
        if totalWork >= 160 {
            return "Keep future real registration and mask work behind an explicit measured-performance gate."
        }
        return "Use as deterministic performance planning context, not measured runtime evidence."
    }

    private static func guidanceLines(
        baselineLabel: String,
        itemCount: Int,
        totalWork: Int,
        peakShotLabel: String,
        peakWork: Int,
        frameBudget: String
    ) -> [String] {
        [
            "Anchor future alignment benchmarks to the \(baselineLabel) base frame.",
            "\(itemCount) deterministic performance notes combine synthetic feature-pair and mask-tile work units.",
            "Total synthetic work \(totalWork); peak \(peakShotLabel) at \(peakWork) units. \(frameBudget).",
            "Do not treat this as Instruments timing, CPU/GPU profiling, dropped-frame proof, or physical-device performance.",
        ]
    }
}

struct BracketProjectAlignmentExplanationReport: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let shotLabel: String
        let displayLabel: String
        let evOffset: Float
        let role: String
        let syntheticTransformConfidencePercent: Int
        let syntheticGhostingRiskScore: Int
        let syntheticMaskCoveragePercent: Int
        let estimatedTotalWorkUnits: Int
        let attentionScore: Int
        let explanationSummary: String
        let photographerGuidance: String
        let limitation: String

        var id: Int { index }

        var accessibilityValue: String {
            [
                shotLabel,
                displayLabel,
                role,
                "Transform confidence \(syntheticTransformConfidencePercent)%",
                "Ghosting risk \(syntheticGhostingRiskScore)",
                "Mask coverage \(syntheticMaskCoveragePercent)%",
                "Work \(estimatedTotalWorkUnits)",
                "Attention \(attentionScore)",
                explanationSummary,
                photographerGuidance,
                limitation,
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "alignment-explanation"
    static let source = "deterministicManifestAlignmentExplanation"
    static let syntheticFixtureNote = "Synthetic alignment explanation, not real pixel analysis"
    static let boundary = "Alignment explanation is deterministic manifest scaffolding only; it does not inspect real image features, match pixels, run optical flow, segment subjects, compute deghosting masks, run Instruments, inspect private Photos bytes, decode RAW pixels, render final output, or prove physical-device behavior."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let baselineIndex: Int?
    let baselineLabel: String
    let shotCount: Int
    let explanationCount: Int
    let highAttentionShotCount: Int
    let topConcernShotLabel: String
    let topConcernScore: Int
    let statusLabel: String
    let userFacingSummary: String
    let items: [Item]
    let guidance: [String]
    let syntheticFixtureNote: String
    let boundary: String

    static func make(project: BracketProject) -> BracketProjectAlignmentExplanationReport {
        let transforms = BracketProjectAlignmentTransformReport.make(project: project)
        let ghosting = BracketProjectGhostingRiskReport.make(project: project)
        let masks = BracketProjectMovingRegionMaskReport.make(project: project)
        let performance = BracketProjectAlignmentPerformanceReport.make(project: project)
        let ghostingByIndex = Dictionary(uniqueKeysWithValues: ghosting.items.map { ($0.index, $0) })
        let masksByIndex = Dictionary(uniqueKeysWithValues: masks.items.map { ($0.index, $0) })
        let performanceByIndex = Dictionary(uniqueKeysWithValues: performance.items.map { ($0.index, $0) })
        let items = transforms.items.map { transform in
            item(
                for: transform,
                ghosting: ghostingByIndex[transform.index],
                mask: masksByIndex[transform.index],
                performance: performanceByIndex[transform.index]
            )
        }
        let highAttentionCount = items.filter { $0.attentionScore >= 90 }.count
        let topConcern = items.max { lhs, rhs in
            lhs.attentionScore < rhs.attentionScore
        }
        let topConcernScore = topConcern?.attentionScore ?? 0
        let status = statusLabel(for: topConcernScore)
        let summary = userFacingSummary(
            status: status,
            baselineLabel: transforms.baselineLabel,
            highAttentionCount: highAttentionCount,
            topConcernShotLabel: topConcern?.shotLabel ?? "No shot"
        )
        let guidance = guidanceLines(
            baselineLabel: transforms.baselineLabel,
            highAttentionCount: highAttentionCount,
            topConcernShotLabel: topConcern?.shotLabel ?? "No shot",
            status: status,
            itemCount: items.count
        )

        return BracketProjectAlignmentExplanationReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            baselineIndex: transforms.baselineIndex,
            baselineLabel: transforms.baselineLabel,
            shotCount: items.count,
            explanationCount: items.count,
            highAttentionShotCount: highAttentionCount,
            topConcernShotLabel: topConcern?.shotLabel ?? "No shot",
            topConcernScore: topConcernScore,
            statusLabel: status,
            userFacingSummary: summary,
            items: items,
            guidance: guidance,
            syntheticFixtureNote: syntheticFixtureNote,
            boundary: boundary
        )
    }

    var hasUserFacingExplanations: Bool {
        explanationCount > 0
    }

    var summaryLabel: String {
        explanationCount == 1 ? "1 explanation" : "\(explanationCount) explanations"
    }

    var highAttentionSummary: String {
        highAttentionShotCount == 0
            ? "No high-attention explanation"
            : "\(highAttentionShotCount) high-attention explanations"
    }

    var topConcernSummary: String {
        "Top watch \(topConcernShotLabel) \(topConcernScore)"
    }

    var accessibilityValue: String {
        [
            "Alignment Explanation",
            title,
            summaryLabel,
            "Baseline \(baselineLabel)",
            highAttentionSummary,
            topConcernSummary,
            statusLabel,
            userFacingSummary,
            "Items: \(items.map(\.accessibilityValue).joined(separator: " ; "))",
            "Guidance: \(guidance.joined(separator: " "))",
            syntheticFixtureNote,
            boundary,
        ].joined(separator: " | ")
    }

    private static func item(
        for transform: BracketProjectAlignmentTransformReport.Item,
        ghosting: BracketProjectGhostingRiskReport.Item?,
        mask: BracketProjectMovingRegionMaskReport.Item?,
        performance: BracketProjectAlignmentPerformanceReport.Item?
    ) -> Item {
        let ghostingRisk = ghosting?.syntheticGhostingRiskScore ?? 0
        let maskCoverage = mask?.syntheticMaskCoveragePercent ?? 0
        let work = performance?.estimatedTotalWorkUnits ?? 0
        let confidencePenalty = max(0, 100 - transform.syntheticTransformConfidencePercent)
        let attentionScore = confidencePenalty + ghostingRisk + maskCoverage + work / 4
        let role = role(
            transform: transform,
            ghostingRisk: ghostingRisk,
            maskCoverage: maskCoverage,
            work: work
        )
        return Item(
            index: transform.index,
            shotLabel: transform.shotLabel,
            displayLabel: transform.displayLabel,
            evOffset: transform.evOffset,
            role: role,
            syntheticTransformConfidencePercent: transform.syntheticTransformConfidencePercent,
            syntheticGhostingRiskScore: ghostingRisk,
            syntheticMaskCoveragePercent: maskCoverage,
            estimatedTotalWorkUnits: work,
            attentionScore: attentionScore,
            explanationSummary: explanationSummary(for: role),
            photographerGuidance: photographerGuidance(for: role),
            limitation: "This explanation is synthesized from manifest scaffolding only, not real pixels."
        )
    }

    private static func role(
        transform: BracketProjectAlignmentTransformReport.Item,
        ghostingRisk: Int,
        maskCoverage: Int,
        work: Int
    ) -> String {
        if transform.role == "Identity transform anchor" {
            return "Base-frame explanation"
        }
        if ghostingRisk >= 42 || maskCoverage >= 36 {
            return "Moving-subject explanation"
        }
        if transform.syntheticTransformConfidencePercent < 60 {
            return "Alignment-confidence explanation"
        }
        if work >= 160 {
            return "Performance-gate explanation"
        }
        if transform.evOffset > 0 {
            return "Bright-frame explanation"
        }
        if transform.evOffset < 0 {
            return "Dark-frame explanation"
        }
        return "Reference-frame explanation"
    }

    private static func explanationSummary(for role: String) -> String {
        switch role {
        case "Base-frame explanation":
            return "This is the baseline frame the app uses to compare alignment, ghosting, masks, and future performance."
        case "Moving-subject explanation":
            return "This frame has synthetic movement pressure, so review should ask the photographer to confirm moving subjects before fusion."
        case "Alignment-confidence explanation":
            return "This frame has lower synthetic transform confidence, so future registration needs real feature matching before trust."
        case "Performance-gate explanation":
            return "This frame may become expensive to align and mask, so measured benchmarks should gate future live previews."
        case "Bright-frame explanation":
            return "This brighter frame protects shadow detail while increasing motion and ghosting watch points."
        case "Dark-frame explanation":
            return "This darker frame protects highlights and can help judge stable edges against the base frame."
        default:
            return "This frame remains supporting alignment context around the base exposure."
        }
    }

    private static func photographerGuidance(for role: String) -> String {
        switch role {
        case "Base-frame explanation":
            return "Use it as the visual anchor, then check the other frames for subject movement and blur."
        case "Moving-subject explanation":
            return "Inspect people, leaves, water, screens, and handheld edges before accepting a merge."
        case "Alignment-confidence explanation":
            return "Zoom into edges and reject automatic fusion if real features do not line up."
        case "Performance-gate explanation":
            return "Prefer a review-only path until real timing proves live alignment is smooth."
        case "Bright-frame explanation":
            return "Use it for shadow recovery only after confirming it does not add ghosting."
        case "Dark-frame explanation":
            return "Use it for highlight recovery and edge stability checks against the base frame."
        default:
            return "Treat it as context until real image analysis confirms the alignment story."
        }
    }

    private static func statusLabel(for topConcernScore: Int) -> String {
        switch topConcernScore {
        case 0...59:
            return "Alignment story: calm synthetic review"
        case 60...119:
            return "Alignment story: review synthetic watch points"
        default:
            return "Alignment story: high-attention synthetic review"
        }
    }

    private static func userFacingSummary(
        status: String,
        baselineLabel: String,
        highAttentionCount: Int,
        topConcernShotLabel: String
    ) -> String {
        if highAttentionCount == 0 {
            return "\(status). Start with the \(baselineLabel) base frame and use the other frames as cautious recovery context."
        }
        return "\(status). Start with the \(baselineLabel) base frame, then inspect \(topConcernShotLabel) and \(highAttentionCount) high-attention shots before trusting fusion."
    }

    private static func guidanceLines(
        baselineLabel: String,
        highAttentionCount: Int,
        topConcernShotLabel: String,
        status: String,
        itemCount: Int
    ) -> [String] {
        [
            "Explain alignment from the photographer's point of view: base frame first, then moving-subject, confidence, mask, and performance watch points.",
            "\(itemCount) deterministic explanations summarize synthetic transform, ghosting, mask, and work-unit reports around the \(baselineLabel) base frame.",
            "\(status); \(topConcernShotLabel) is the top synthetic watch frame with \(highAttentionCount) high-attention explanations.",
            "Do not treat this as real feature matching, subject detection, optical flow, deghosting masks, Instruments timing, final merge readiness, or physical-device proof.",
        ]
    }
}

struct BracketProjectFusionPreviewReport: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let kind = "fusion-preview"
    static let source = "deterministicFixture"
    static let boundary = "Preview prototype from synthetic scene pixels; not a final HDR render and not derived from private Photos bytes."
    static let colorPipeline = "sRGB RGBA8 fixture normalized with Core Image exposure adjustment and well-exposedness weights."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let source: String
    let boundary: String
    let colorPipeline: String
    let width: Int
    let height: Int
    let sourceCount: Int
    let evOffsets: [Float]
    let evLabels: [String]
    let rgbaBytes: [UInt8]
    let byteCount: Int
    let summary: String

    static func make(project: BracketProject) -> BracketProjectFusionPreviewReport? {
        let sequence = BracketReviewSequence.make(manifest: project.manifest)
        guard let preview = ExposureFusionPreviewGenerator.makeDeterministicPreview(for: sequence) else {
            return nil
        }

        return BracketProjectFusionPreviewReport(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: project.displayTitle,
            source: source,
            boundary: boundary,
            colorPipeline: colorPipeline,
            width: preview.width,
            height: preview.height,
            sourceCount: preview.sourceCount,
            evOffsets: preview.evOffsets,
            evLabels: preview.evOffsets.map(BracketEVFormatter.displayLabel(for:)),
            rgbaBytes: preview.rgbaBytes,
            byteCount: preview.rgbaBytes.count,
            summary: preview.summary
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectFusionPreviewReport {
        BracketProjectFusionPreviewReport(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            source: source,
            boundary: boundary,
            colorPipeline: colorPipeline,
            width: width,
            height: height,
            sourceCount: sourceCount,
            evOffsets: evOffsets,
            evLabels: evLabels,
            rgbaBytes: rgbaBytes,
            byteCount: byteCount,
            summary: summary
        )
    }

    func matches(_ project: BracketProject) -> Bool {
        guard let expected = BracketProjectFusionPreviewReport.make(project: project) else {
            return false
        }

        return self == expected
    }

    var accessibilityValue: String {
        [
            "Fusion Preview",
            source,
            "\(width)x\(height)",
            "\(sourceCount) exposures",
            summary,
            boundary
        ].joined(separator: " | ")
    }
}

struct BracketProjectFinalOutputPreviewImageDocument: Equatable, Sendable {
    struct RenderedImage: Equatable, Sendable {
        let width: Int
        let height: Int
        let rgbaBytes: [UInt8]

        var byteCount: Int {
            rgbaBytes.count
        }
    }

    static let kind = "final-output-preview-image"
    static let mimeType = "image/png"
    static let encoding = "base64"
    static let scale = 32
    static let boundary = "Base64 PNG preview image rendered from deterministic fusion-preview pixels only; not final HDR output, not private Photos bytes, not RAW decoded data, and not physical export proof."

    static func renderedImage(fusionPreview: BracketProjectFusionPreviewReport) -> RenderedImage? {
        guard fusionPreview.width > 0,
              fusionPreview.height > 0,
              fusionPreview.byteCount == fusionPreview.rgbaBytes.count,
              fusionPreview.rgbaBytes.count == fusionPreview.width * fusionPreview.height * 4 else {
            return nil
        }

        let width = fusionPreview.width * scale
        let height = fusionPreview.height * scale
        var rgbaBytes = Array(repeating: UInt8(0), count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let sourceX = x / scale
                let sourceY = y / scale
                let sourceIndex = ((sourceY * fusionPreview.width) + sourceX) * 4
                let outputIndex = ((y * width) + x) * 4
                rgbaBytes[outputIndex] = fusionPreview.rgbaBytes[sourceIndex]
                rgbaBytes[outputIndex + 1] = fusionPreview.rgbaBytes[sourceIndex + 1]
                rgbaBytes[outputIndex + 2] = fusionPreview.rgbaBytes[sourceIndex + 2]
                rgbaBytes[outputIndex + 3] = fusionPreview.rgbaBytes[sourceIndex + 3]
            }
        }

        return RenderedImage(width: width, height: height, rgbaBytes: rgbaBytes)
    }

    static func pngData(fusionPreview: BracketProjectFusionPreviewReport) -> Data? {
        guard let renderedImage = renderedImage(fusionPreview: fusionPreview),
              let provider = CGDataProvider(data: Data(renderedImage.rgbaBytes) as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(
                width: renderedImage.width,
                height: renderedImage.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: renderedImage.width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    static func base64PNG(fusionPreview: BracketProjectFusionPreviewReport) -> String? {
        pngData(fusionPreview: fusionPreview)?.base64EncodedString()
    }

    static func matches(
        base64Contents: String,
        fusionPreview: BracketProjectFusionPreviewReport
    ) -> Bool {
        guard Data(base64Encoded: base64Contents) != nil,
              let expected = base64PNG(fusionPreview: fusionPreview) else {
            return false
        }

        return base64Contents == expected
    }
}

struct BracketProjectFinalOutputDraftJPEGDocument: Equatable, Sendable {
    static let kind = "final-output-draft-review-jpeg"
    static let mimeType = "image/jpeg"
    static let encoding = "base64"
    static let compressionQuality = 0.86
    static let boundary = "Base64 JPEG draft rendered from deterministic fusion-preview pixels only; not final HDR output, not private Photos bytes, not RAW decoded data, not tone-mapped user assets, and not physical export proof."

    static func jpegData(fusionPreview: BracketProjectFusionPreviewReport) -> Data? {
        guard let renderedImage = BracketProjectFinalOutputPreviewImageDocument.renderedImage(
            fusionPreview: fusionPreview
        ) else {
            return nil
        }

        let rgbBytes = renderedImage.rgbaBytes.enumerated().compactMap { index, byte in
            (index + 1).isMultiple(of: 4) ? nil : byte
        }
        guard rgbBytes.count == renderedImage.width * renderedImage.height * 3,
              let provider = CGDataProvider(data: Data(rgbBytes) as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(
                width: renderedImage.width,
                height: renderedImage.height,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: renderedImage.width * 3,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options = [
            kCGImageDestinationLossyCompressionQuality as String: compressionQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    static func base64JPEG(fusionPreview: BracketProjectFusionPreviewReport) -> String? {
        jpegData(fusionPreview: fusionPreview)?.base64EncodedString()
    }

    static func matches(
        base64Contents: String,
        fusionPreview: BracketProjectFusionPreviewReport
    ) -> Bool {
        guard Data(base64Encoded: base64Contents) != nil,
              let expected = base64JPEG(fusionPreview: fusionPreview) else {
            return false
        }

        return base64Contents == expected
    }
}

struct BracketProjectArchiveIntegrityManifest: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let index: Int
        let filename: String
        let kind: String
        let mimeType: String
        let byteCount: Int
        let sha256Hex: String

        var id: String { filename }

        var accessibilityValue: String {
            [
                filename,
                kind,
                mimeType,
                "\(byteCount) bytes",
                sha256Hex
            ].joined(separator: " | ")
        }
    }

    static let schemaVersion = 1
    static let kind = "archive-integrity-manifest"
    static let boundary = "Archive payload integrity metadata only; records payload filenames, kinds, byte counts, and SHA-256 digests without adding raw photo bytes, reading files, fetching Photos resources, or proving physical export."

    let schemaVersion: Int
    let projectID: String
    let privacyLevel: BracketProjectExportPrivacyLevel
    let createdAt: Date
    let boundary: String
    let payloadCount: Int
    let totalByteCount: Int
    let items: [Item]

    static func make(
        projectID: String,
        privacyLevel: BracketProjectExportPrivacyLevel,
        createdAt: Date,
        files: [BracketProjectExportBundle.FilePayload]
    ) -> BracketProjectArchiveIntegrityManifest {
        let inspectedFiles = files.filter { $0.kind != Self.kind }
        let items = inspectedFiles.enumerated().map { index, file in
            Item(
                index: index,
                filename: file.filename,
                kind: file.kind,
                mimeType: file.mimeType,
                byteCount: file.byteCount,
                sha256Hex: sha256Hex(file.contents)
            )
        }

        return BracketProjectArchiveIntegrityManifest(
            schemaVersion: schemaVersion,
            projectID: projectID,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            boundary: boundary,
            payloadCount: items.count,
            totalByteCount: items.reduce(0) { $0 + $1.byteCount },
            items: items
        )
    }

    func matches(
        files: [BracketProjectExportBundle.FilePayload],
        projectID: String
    ) -> Bool {
        guard self.projectID == projectID else { return false }
        return self == Self.make(
            projectID: projectID,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            files: files
        )
    }

    var accessibilityValue: String {
        [
            "Archive Integrity Manifest",
            projectID,
            privacyLevel.displayName,
            "\(payloadCount) payloads",
            "\(totalByteCount) bytes",
            boundary
        ].joined(separator: " | ")
    }

    private static func sha256Hex(_ contents: String) -> String {
        let digest = SHA256.hash(data: Data(contents.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct BracketProjectExportNote: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let kind = "export-note"
    static let source = "deterministicFallback"
    static let fallbackReason = "No live Apple Intelligence export-note generator was invoked; this note was generated deterministically from project and export metadata."
    static let dataBoundary = "Export note generated from project manifest, review, export payload, and policy metadata only; no raw photo bytes, Photos resource fetches, RAW decoding, final rendered image bytes, or physical-device proof."

    let schemaVersion: Int
    let projectID: String
    let title: String
    let summary: String
    let recommendedNextActions: [String]
    let payloadKinds: [String]
    let privacyLevel: BracketProjectExportPrivacyLevel
    let filenameTemplate: BracketProjectExportFilenameTemplate
    let generatedContentPolicy: BracketProjectExportGeneratedContentPolicy
    let source: String
    let usedAppleIntelligence: Bool
    let fallbackReason: String
    let dataBoundary: String
    let createdAt: Date

    static func make(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel,
        filenameTemplate: BracketProjectExportFilenameTemplate,
        generatedContentPolicy: BracketProjectExportGeneratedContentPolicy,
        payloadKinds: [String],
        finalOutputActionPlanSummary: String?,
        createdAt: Date
    ) -> BracketProjectExportNote {
        BracketProjectExportNote(
            schemaVersion: schemaVersion,
            projectID: project.id,
            title: "Export note for \(project.displayTitle)",
            summary: [
                "\(project.reviewSnapshot.shotCount)-shot \(project.source.rawValue) bracket",
                project.reviewSnapshot.bestExposureLabel.map { "best base \($0)" },
                "\(payloadKinds.count) metadata payloads",
                privacyLevel.displayName,
                generatedContentPolicy.displayName
            ]
            .compactMap { $0 }
            .joined(separator: " | "),
            recommendedNextActions: recommendedNextActions(
                privacyLevel: privacyLevel,
                generatedContentPolicy: generatedContentPolicy,
                finalOutputActionPlanSummary: finalOutputActionPlanSummary
            ),
            payloadKinds: payloadKinds,
            privacyLevel: privacyLevel,
            filenameTemplate: filenameTemplate,
            generatedContentPolicy: generatedContentPolicy,
            source: source,
            usedAppleIntelligence: false,
            fallbackReason: fallbackReason,
            dataBoundary: dataBoundary,
            createdAt: createdAt
        )
    }

    func matches(
        project: BracketProject,
        payloadKinds: [String],
        finalOutputActionPlanSummary: String?
    ) -> Bool {
        self == Self.make(
            project: project,
            privacyLevel: privacyLevel,
            filenameTemplate: filenameTemplate,
            generatedContentPolicy: generatedContentPolicy,
            payloadKinds: payloadKinds,
            finalOutputActionPlanSummary: finalOutputActionPlanSummary,
            createdAt: createdAt
        )
    }

    func replacingProjectID(_ newProjectID: String) -> BracketProjectExportNote {
        BracketProjectExportNote(
            schemaVersion: schemaVersion,
            projectID: newProjectID,
            title: title,
            summary: summary,
            recommendedNextActions: recommendedNextActions,
            payloadKinds: payloadKinds,
            privacyLevel: privacyLevel,
            filenameTemplate: filenameTemplate,
            generatedContentPolicy: generatedContentPolicy,
            source: source,
            usedAppleIntelligence: usedAppleIntelligence,
            fallbackReason: fallbackReason,
            dataBoundary: dataBoundary,
            createdAt: createdAt
        )
    }

    var accessibilityValue: String {
        [
            "Project Export Note",
            projectID,
            title,
            summary,
            "Source: \(source)",
            usedAppleIntelligence ? "Apple Intelligence used" : "Deterministic fallback",
            fallbackReason,
            dataBoundary
        ].joined(separator: " | ")
    }

    private static func recommendedNextActions(
        privacyLevel: BracketProjectExportPrivacyLevel,
        generatedContentPolicy: BracketProjectExportGeneratedContentPolicy,
        finalOutputActionPlanSummary: String?
    ) -> [String] {
        [
            finalOutputActionPlanSummary ?? "Review final-output readiness before promising final rendered images.",
            privacyLevel.includesAssetIdentifiers
                ? "Handle recovery identifiers as private project-recovery data."
                : "Use recovery-identifier export only when private Photos references are needed for restore.",
            generatedContentPolicy.includesGeneratedContent
                ? "Generated notes are included with source disclosure; review them before client handoff."
                : "Generated notes are omitted from this export; user-curated tags remain preserved.",
            "Review archive-integrity-manifest before handoff."
        ]
    }
}

struct BracketProjectImportBundle: Equatable, Sendable {
    let project: BracketProject
    let manifest: BracketManifest
    let sidecar: BracketManifestSidecar?
    let contactSheet: BracketProjectContactSheet?
    let contactSheetHTML: String?
    let contactSheetPreview: BracketProjectContactSheetPreview?
    let contactSheetImageBase64: String?
    let contactSheetPDFBase64: String?
    let captureQualityReport: BracketProjectCaptureQualityReport?
    let assetResourceReport: BracketProjectAssetResourceReport?
    let resourceInspectionReport: BracketProjectResourceInspectionReport?
    let thumbnailInspectionReport: BracketProjectThumbnailInspectionReport?
    let archiveIntegrityManifest: BracketProjectArchiveIntegrityManifest?
    let mergeReadinessReport: BracketProjectMergeReadinessReport?
    let imageBundleManifest: BracketProjectImageBundleManifest?
    let imageBundleDraftPackageBase64: String?
    let finalOutputManifest: BracketProjectFinalOutputManifest?
    let finalOutputReadinessAudit: BracketProjectFinalOutputReadinessAudit?
    let finalOutputPreviewImageBase64: String?
    let finalOutputDraftJPEGBase64: String?
    let exposureComparison: BracketProjectExposureComparison?
    let sideBySidePixelComparison: BracketProjectSideBySidePixelComparison?
    let fusionPreview: BracketProjectFusionPreviewReport?
    let exportNote: BracketProjectExportNote?
    let privacyReport: String
    let diagnosticsReport: String
    let importedAt: Date
    let payloadKinds: [String]
    let conflictResolution: String?

    static func parse(
        archiveText: String,
        importedAt: Date = Date()
    ) throws -> BracketProjectImportBundle {
        let normalizedText = archiveText.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedText.components(separatedBy: "\n")
        guard lines.first == "Bracketer Project Export Bundle" else {
            throw BracketProjectImportError.invalidArchiveHeader
        }

        let schema = try headerInteger("Schema", lines: lines)
        guard schema == BracketProjectExportBundle.schemaVersion else {
            throw BracketProjectImportError.unsupportedSchema(schema)
        }
        let headerProjectID = try headerValue("Project", lines: lines)
        let finalOutputActionPlanHeader = optionalHeaderValue("Final Output Action Plan", lines: lines)
        let files = try filePayloads(from: lines)

        let projectFile = try requiredPayload(kind: "project", files: files)
        let manifestFile = try requiredPayload(kind: "manifest", files: files)
        let privacyFile = try requiredPayload(kind: "privacy-report", files: files)
        let diagnosticsFile = try requiredPayload(kind: "diagnostics-report", files: files)

        let project = try decode(BracketProject.self, from: projectFile)
        let manifest = try decode(BracketManifest.self, from: manifestFile)
        let sidecar = try files.first { $0.kind == "sidecar" }
            .map { try decode(BracketManifestSidecar.self, from: $0) }
        let contactSheet = try files.first { $0.kind == "contact-sheet" }
            .map { try decode(BracketProjectContactSheet.self, from: $0) }
        let contactSheetHTML = files.first { $0.kind == BracketProjectContactSheetDocument.kind }
        let contactSheetPreview = try files.first { $0.kind == BracketProjectContactSheetPreview.kind }
            .map { try decode(BracketProjectContactSheetPreview.self, from: $0) }
        let contactSheetImageBase64 = files.first { $0.kind == BracketProjectContactSheetImageDocument.kind }?.contents
        let contactSheetPDFBase64 = files.first { $0.kind == BracketProjectContactSheetPDFDocument.kind }?.contents
        let captureQualityReport = try files.first { $0.kind == BracketProjectCaptureQualityReport.kind }
            .map { try decode(BracketProjectCaptureQualityReport.self, from: $0) }
        let assetResourceReport = try files.first { $0.kind == BracketProjectAssetResourceReport.kind }
            .map { try decode(BracketProjectAssetResourceReport.self, from: $0) }
        let resourceInspectionReport = try files.first { $0.kind == BracketProjectResourceInspectionReport.kind }
            .map { try decode(BracketProjectResourceInspectionReport.self, from: $0) }
        let thumbnailInspectionReport = try files.first { $0.kind == BracketProjectThumbnailInspectionReport.kind }
            .map { try decode(BracketProjectThumbnailInspectionReport.self, from: $0) }
        let archiveIntegrityManifest = try files.first { $0.kind == BracketProjectArchiveIntegrityManifest.kind }
            .map { try decode(BracketProjectArchiveIntegrityManifest.self, from: $0) }
        let mergeReadinessReport = try files.first { $0.kind == BracketProjectMergeReadinessReport.kind }
            .map { try decode(BracketProjectMergeReadinessReport.self, from: $0) }
        let imageBundleManifest = try files.first { $0.kind == BracketProjectImageBundleManifest.kind }
            .map { try decode(BracketProjectImageBundleManifest.self, from: $0) }
        let imageBundleDraftPackageBase64 = files.first {
            $0.kind == BracketProjectImageBundleDraftPackageDocument.kind
        }?.contents
        let finalOutputManifest = try files.first { $0.kind == BracketProjectFinalOutputManifest.kind }
            .map { try decode(BracketProjectFinalOutputManifest.self, from: $0) }
        let finalOutputReadinessAudit = try files.first { $0.kind == BracketProjectFinalOutputReadinessAudit.kind }
            .map { try decode(BracketProjectFinalOutputReadinessAudit.self, from: $0) }
        let finalOutputPreviewImageBase64 = files.first {
            $0.kind == BracketProjectFinalOutputPreviewImageDocument.kind
        }?.contents
        let finalOutputDraftJPEGBase64 = files.first {
            $0.kind == BracketProjectFinalOutputDraftJPEGDocument.kind
        }?.contents
        let exposureComparison = try files.first { $0.kind == "exposure-comparison" }
            .map { try decode(BracketProjectExposureComparison.self, from: $0) }
        let sideBySidePixelComparison = try files.first { $0.kind == BracketProjectSideBySidePixelComparison.kind }
            .map { try decode(BracketProjectSideBySidePixelComparison.self, from: $0) }
        let fusionPreview = try files.first { $0.kind == BracketProjectFusionPreviewReport.kind }
            .map { try decode(BracketProjectFusionPreviewReport.self, from: $0) }
        let exportNote = try files.first { $0.kind == BracketProjectExportNote.kind }
            .map { try decode(BracketProjectExportNote.self, from: $0) }

        guard project.id == headerProjectID else {
            throw BracketProjectImportError.projectIdentifierMismatch(
                expected: headerProjectID,
                actual: project.id
            )
        }
        guard project.manifest == manifest else {
            throw BracketProjectImportError.manifestMismatch
        }
        guard project.sidecar == sidecar else {
            throw BracketProjectImportError.sidecarMismatch
        }
        guard contactSheet?.matches(project) != false else {
            throw BracketProjectImportError.contactSheetMismatch
        }
        if let contactSheetHTML {
            guard contactSheetHTML.mimeType == BracketProjectContactSheetDocument.mimeType,
                  let contactSheet,
                  BracketProjectContactSheetDocument.matches(
                    contents: contactSheetHTML.contents,
                    contactSheet: contactSheet
                  ) else {
                throw BracketProjectImportError.contactSheetMismatch
            }
        }
        guard contactSheetPreview?.matches(project) != false else {
            throw BracketProjectImportError.contactSheetPreviewMismatch
        }
        if let contactSheetImageBase64 {
            guard let contactSheetPreview,
                  BracketProjectContactSheetImageDocument.matches(
                    base64Contents: contactSheetImageBase64,
                    preview: contactSheetPreview
                  ) else {
                throw BracketProjectImportError.contactSheetImageMismatch
            }
        }
        if let contactSheetPDFBase64 {
            guard let contactSheetPreview,
                  BracketProjectContactSheetPDFDocument.matches(
                    base64Contents: contactSheetPDFBase64,
                    preview: contactSheetPreview
                  ) else {
                throw BracketProjectImportError.contactSheetPDFMismatch
            }
        }
        guard captureQualityReport?.matches(project) != false else {
            throw BracketProjectImportError.captureQualityReportMismatch
        }
        guard assetResourceReport?.matches(project) != false else {
            throw BracketProjectImportError.assetResourceReportMismatch
        }
        guard resourceInspectionReport?.matches(project) != false else {
            throw BracketProjectImportError.resourceInspectionReportMismatch
        }
        guard thumbnailInspectionReport?.matches(project) != false else {
            throw BracketProjectImportError.thumbnailInspectionReportMismatch
        }
        guard mergeReadinessReport?.matches(project) != false else {
            throw BracketProjectImportError.mergeReadinessReportMismatch
        }
        guard imageBundleManifest?.matches(project) != false else {
            throw BracketProjectImportError.imageBundleManifestMismatch
        }
        if let imageBundleDraftPackageBase64 {
            guard let imageBundleManifest,
                  BracketProjectImageBundleDraftPackageDocument.matches(
                    base64Contents: imageBundleDraftPackageBase64,
                    manifest: imageBundleManifest
                  ) else {
                throw BracketProjectImportError.imageBundleDraftPackageMismatch
            }
        }
        guard finalOutputManifest?.matches(project) != false else {
            throw BracketProjectImportError.finalOutputManifestMismatch
        }
        if let finalOutputReadinessAudit {
            guard let finalOutputManifest,
                  finalOutputReadinessAudit.matches(manifest: finalOutputManifest) else {
                throw BracketProjectImportError.finalOutputReadinessAuditMismatch
            }
        }
        if let finalOutputActionPlanHeader {
            if let finalOutputReadinessAudit {
                guard finalOutputActionPlanHeader == finalOutputReadinessAudit.actionPlanSummary else {
                    throw BracketProjectImportError.finalOutputActionPlanHeaderMismatch
                }
            } else {
                guard finalOutputActionPlanHeader == "Unavailable" else {
                    throw BracketProjectImportError.finalOutputActionPlanHeaderMismatch
                }
            }
        }
        if let finalOutputPreviewImageBase64 {
            guard let fusionPreview,
                  BracketProjectFinalOutputPreviewImageDocument.matches(
                    base64Contents: finalOutputPreviewImageBase64,
                    fusionPreview: fusionPreview
                  ) else {
                throw BracketProjectImportError.finalOutputPreviewImageMismatch
            }
        }
        if let finalOutputDraftJPEGBase64 {
            guard let fusionPreview,
                  BracketProjectFinalOutputDraftJPEGDocument.matches(
                    base64Contents: finalOutputDraftJPEGBase64,
                    fusionPreview: fusionPreview
                  ) else {
                throw BracketProjectImportError.finalOutputDraftJPEGMismatch
            }
        }
        guard exposureComparison?.matches(project) != false else {
            throw BracketProjectImportError.exposureComparisonMismatch
        }
        guard sideBySidePixelComparison?.matches(project) != false else {
            throw BracketProjectImportError.sideBySidePixelComparisonMismatch
        }
        guard fusionPreview?.matches(project) != false else {
            throw BracketProjectImportError.fusionPreviewMismatch
        }
        if let exportNote {
            let payloadKindsBeforeExportNote = files
                .prefix(while: { $0.kind != BracketProjectExportNote.kind })
                .map(\.kind)
            guard exportNote.matches(
                project: project,
                payloadKinds: payloadKindsBeforeExportNote,
                finalOutputActionPlanSummary: finalOutputReadinessAudit?.actionPlanSummary
            ) else {
                throw BracketProjectImportError.exportNoteMismatch
            }
        }
        guard archiveIntegrityManifest?.matches(files: files, projectID: project.id) != false else {
            throw BracketProjectImportError.archiveIntegrityManifestMismatch
        }
        guard !project.privacy.storesRawPhotoBytes else {
            throw BracketProjectImportError.rawPhotoBytesNotSupported
        }

        return BracketProjectImportBundle(
            project: project,
            manifest: manifest,
            sidecar: sidecar,
            contactSheet: contactSheet,
            contactSheetHTML: contactSheetHTML?.contents,
            contactSheetPreview: contactSheetPreview,
            contactSheetImageBase64: contactSheetImageBase64,
            contactSheetPDFBase64: contactSheetPDFBase64,
            captureQualityReport: captureQualityReport,
            assetResourceReport: assetResourceReport,
            resourceInspectionReport: resourceInspectionReport,
            thumbnailInspectionReport: thumbnailInspectionReport,
            archiveIntegrityManifest: archiveIntegrityManifest,
            mergeReadinessReport: mergeReadinessReport,
            imageBundleManifest: imageBundleManifest,
            imageBundleDraftPackageBase64: imageBundleDraftPackageBase64,
            finalOutputManifest: finalOutputManifest,
            finalOutputReadinessAudit: finalOutputReadinessAudit,
            finalOutputPreviewImageBase64: finalOutputPreviewImageBase64,
            finalOutputDraftJPEGBase64: finalOutputDraftJPEGBase64,
            exposureComparison: exposureComparison,
            sideBySidePixelComparison: sideBySidePixelComparison,
            fusionPreview: fusionPreview,
            exportNote: exportNote,
            privacyReport: privacyFile.contents,
            diagnosticsReport: diagnosticsFile.contents,
            importedAt: importedAt,
            payloadKinds: files.map(\.kind),
            conflictResolution: nil
        )
    }

    func resolvingConflict(
        with savedProject: BracketProject,
        summary: String
    ) -> BracketProjectImportBundle {
        let resolvedContactSheet = contactSheet?.replacingProjectID(savedProject.id)
        let resolvedContactSheetPreview = contactSheetPreview?.replacingProjectID(savedProject.id)
        let resolvedContactSheetImageBase64 = resolvedContactSheetPreview.flatMap {
            BracketProjectContactSheetImageDocument.base64PNG(preview: $0)
        }
        let resolvedContactSheetPDFBase64 = resolvedContactSheetPreview.flatMap {
            BracketProjectContactSheetPDFDocument.base64PDF(preview: $0)
        }
        let resolvedImageBundleManifest = imageBundleManifest?.replacingProjectID(savedProject.id)
        let resolvedImageBundleDraftPackageBase64 = resolvedImageBundleManifest.flatMap {
            BracketProjectImageBundleDraftPackageDocument.base64Package(manifest: $0)
        }
        return BracketProjectImportBundle(
            project: savedProject,
            manifest: manifest,
            sidecar: sidecar,
            contactSheet: resolvedContactSheet,
            contactSheetHTML: resolvedContactSheet.map {
                BracketProjectContactSheetDocument.html(contactSheet: $0)
            },
            contactSheetPreview: resolvedContactSheetPreview,
            contactSheetImageBase64: resolvedContactSheetImageBase64,
            contactSheetPDFBase64: resolvedContactSheetPDFBase64,
            captureQualityReport: captureQualityReport?.replacingProjectID(savedProject.id),
            assetResourceReport: assetResourceReport?.replacingProjectID(savedProject.id),
            resourceInspectionReport: resourceInspectionReport?.replacingProjectID(savedProject.id),
            thumbnailInspectionReport: thumbnailInspectionReport?.replacingProjectID(savedProject.id),
            archiveIntegrityManifest: archiveIntegrityManifest,
            mergeReadinessReport: mergeReadinessReport?.replacingProjectID(savedProject.id),
            imageBundleManifest: resolvedImageBundleManifest,
            imageBundleDraftPackageBase64: resolvedImageBundleDraftPackageBase64,
            finalOutputManifest: finalOutputManifest?.replacingProjectID(savedProject.id),
            finalOutputReadinessAudit: finalOutputReadinessAudit?.replacingProjectID(savedProject.id),
            finalOutputPreviewImageBase64: finalOutputPreviewImageBase64,
            finalOutputDraftJPEGBase64: finalOutputDraftJPEGBase64,
            exposureComparison: exposureComparison?.replacingProjectID(savedProject.id),
            sideBySidePixelComparison: sideBySidePixelComparison?.replacingProjectID(savedProject.id),
            fusionPreview: fusionPreview?.replacingProjectID(savedProject.id),
            exportNote: exportNote?.replacingProjectID(savedProject.id),
            privacyReport: privacyReport,
            diagnosticsReport: diagnosticsReport,
            importedAt: importedAt,
            payloadKinds: payloadKinds,
            conflictResolution: summary
        )
    }

    var accessibilityValue: String {
        var parts = [
            "Project Import Bundle",
            project.id,
            "\(payloadKinds.count) payloads",
            project.privacy.accessibilityValue,
            "Imported \(ISO8601DateFormatter().string(from: importedAt))"
        ]
        if let finalOutputActionPlanSummary {
            parts.append("Final output action plan: \(finalOutputActionPlanSummary)")
        }
        if let exportNote {
            parts.append("Export note: \(exportNote.source)")
        }
        if let conflictResolution {
            parts.append(conflictResolution)
        }
        return parts.joined(separator: " | ")
    }

    var finalOutputActionPlanSummary: String? {
        finalOutputReadinessAudit?.actionPlanSummary
    }

    private static func requiredPayload(
        kind: String,
        files: [BracketProjectExportBundle.FilePayload]
    ) throws -> BracketProjectExportBundle.FilePayload {
        guard let file = files.first(where: { $0.kind == kind }) else {
            throw BracketProjectImportError.missingPayload(kind: kind)
        }
        return file
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        from file: BracketProjectExportBundle.FilePayload
    ) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(type, from: Data(file.contents.utf8))
        } catch {
            throw BracketProjectImportError.malformedPayload("\(file.filename): \(error.localizedDescription)")
        }
    }

    private static func headerValue(
        _ name: String,
        lines: [String]
    ) throws -> String {
        let prefix = "\(name): "
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            throw BracketProjectImportError.malformedHeader(name)
        }
        return String(line.dropFirst(prefix.count))
    }

    private static func optionalHeaderValue(
        _ name: String,
        lines: [String]
    ) -> String? {
        let prefix = "\(name): "
        return lines
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private static func headerInteger(
        _ name: String,
        lines: [String]
    ) throws -> Int {
        let rawValue = try headerValue(name, lines: lines)
        guard let value = Int(rawValue) else {
            throw BracketProjectImportError.malformedHeader("\(name): \(rawValue)")
        }
        return value
    }

    private static func filePayloads(from lines: [String]) throws -> [BracketProjectExportBundle.FilePayload] {
        var payloads: [BracketProjectExportBundle.FilePayload] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard line.hasPrefix("----- BEGIN "), line.hasSuffix(" -----") else {
                index += 1
                continue
            }

            let filename = String(line.dropFirst("----- BEGIN ".count).dropLast(" -----".count))
            index += 1
            let kind = try metadataLine("Kind", lines: lines, index: &index, filename: filename)
            let mimeType = try metadataLine("MIME", lines: lines, index: &index, filename: filename)
            let byteCountText = try metadataLine("Bytes", lines: lines, index: &index, filename: filename)
            guard let expectedByteCount = Int(byteCountText) else {
                throw BracketProjectImportError.malformedPayload("\(filename) has a non-numeric byte count.")
            }
            guard lines.indices.contains(index), lines[index].isEmpty else {
                throw BracketProjectImportError.malformedPayload("\(filename) is missing its content separator.")
            }
            index += 1

            let endMarker = "----- END \(filename) -----"
            var contents: [String] = []
            while lines.indices.contains(index), lines[index] != endMarker {
                contents.append(lines[index])
                index += 1
            }
            guard lines.indices.contains(index) else {
                throw BracketProjectImportError.malformedPayload("\(filename) is missing its end marker.")
            }

            let contentText = contents.joined(separator: "\n")
            guard contentText.utf8.count == expectedByteCount else {
                throw BracketProjectImportError.byteCountMismatch(filename: filename)
            }

            payloads.append(
                BracketProjectExportBundle.FilePayload(
                    id: kind,
                    filename: filename,
                    kind: kind,
                    mimeType: mimeType,
                    contents: contentText
                )
            )
            index += 1
        }

        return payloads
    }

    private static func metadataLine(
        _ name: String,
        lines: [String],
        index: inout Int,
        filename: String
    ) throws -> String {
        guard lines.indices.contains(index) else {
            throw BracketProjectImportError.malformedPayload("\(filename) is missing \(name).")
        }
        let prefix = "\(name): "
        let line = lines[index]
        guard line.hasPrefix(prefix) else {
            throw BracketProjectImportError.malformedPayload("\(filename) has malformed \(name).")
        }
        index += 1
        return String(line.dropFirst(prefix.count))
    }
}

struct BracketProjectExportBundle: Codable, Equatable, Sendable {
    struct FilePayload: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let filename: String
        let kind: String
        let mimeType: String
        let contents: String

        var byteCount: Int {
            contents.utf8.count
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let projectID: String
    let privacyLevel: BracketProjectExportPrivacyLevel
    let filenameTemplate: BracketProjectExportFilenameTemplate
    let generatedContentPolicy: BracketProjectExportGeneratedContentPolicy
    let archiveFilename: String
    let createdAt: Date
    let files: [FilePayload]
    let summary: String

    static func make(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel = .metadataOnly,
        filenameTemplate: BracketProjectExportFilenameTemplate = .projectIdentifier,
        generatedContentPolicy: BracketProjectExportGeneratedContentPolicy = .include,
        createdAt: Date = Date()
    ) throws -> BracketProjectExportBundle {
        let exportProject = project.exportCopy(
            privacyLevel: privacyLevel,
            generatedContentPolicy: generatedContentPolicy
        )
        let baseName = filenameTemplate.payloadBaseName(
            project: exportProject,
            privacyLevel: privacyLevel
        )
        let archiveFilename = filenameTemplate.archiveFilename(
            project: exportProject,
            privacyLevel: privacyLevel
        )
        var files: [FilePayload] = []

        files.append(
            try jsonFile(
                id: "project",
                filename: "\(baseName)-project.json",
                kind: "project",
                value: exportProject
            )
        )
        files.append(
            try jsonFile(
                id: "manifest",
                filename: "\(baseName)-manifest.json",
                kind: "manifest",
                value: exportProject.manifest
            )
        )
        if let sidecar = exportProject.sidecar {
            files.append(
                try jsonFile(
                    id: "sidecar",
                    filename: "\(baseName)-sidecar.json",
                    kind: "sidecar",
                    value: sidecar
                )
            )
        }
        let contactSheet = BracketProjectContactSheet.make(
            project: exportProject,
            privacyLevel: privacyLevel,
            createdAt: createdAt
        )
        files.append(
            try jsonFile(
                id: "contact-sheet",
                filename: "\(baseName)-contact-sheet.json",
                kind: "contact-sheet",
                value: contactSheet
            )
        )
        files.append(
            FilePayload(
                id: BracketProjectContactSheetDocument.kind,
                filename: "\(baseName)-contact-sheet.html",
                kind: BracketProjectContactSheetDocument.kind,
                mimeType: BracketProjectContactSheetDocument.mimeType,
                contents: BracketProjectContactSheetDocument.html(contactSheet: contactSheet)
            )
        )
        if let contactSheetPreview = BracketProjectContactSheetPreview.make(project: exportProject) {
            files.append(
                try jsonFile(
                    id: BracketProjectContactSheetPreview.kind,
                    filename: "\(baseName)-contact-sheet-preview.json",
                    kind: BracketProjectContactSheetPreview.kind,
                    value: contactSheetPreview
                )
            )
            if let contactSheetImage = BracketProjectContactSheetImageDocument.base64PNG(
                preview: contactSheetPreview
            ) {
                files.append(
                    FilePayload(
                        id: BracketProjectContactSheetImageDocument.kind,
                        filename: "\(baseName)-contact-sheet-image.png.base64",
                        kind: BracketProjectContactSheetImageDocument.kind,
                        mimeType: BracketProjectContactSheetImageDocument.mimeType,
                        contents: contactSheetImage
                    )
                )
            }
            if let contactSheetPDF = BracketProjectContactSheetPDFDocument.base64PDF(
                preview: contactSheetPreview
            ) {
                files.append(
                    FilePayload(
                        id: BracketProjectContactSheetPDFDocument.kind,
                        filename: "\(baseName)-contact-sheet.pdf.base64",
                        kind: BracketProjectContactSheetPDFDocument.kind,
                        mimeType: BracketProjectContactSheetPDFDocument.mimeType,
                        contents: contactSheetPDF
                    )
                )
            }
        }
        files.append(
            try jsonFile(
                id: BracketProjectCaptureQualityReport.kind,
                filename: "\(baseName)-capture-quality-report.json",
                kind: BracketProjectCaptureQualityReport.kind,
                value: BracketProjectCaptureQualityReport.make(project: exportProject)
            )
        )
        files.append(
            try jsonFile(
                id: BracketProjectAssetResourceReport.kind,
                filename: "\(baseName)-asset-resource-report.json",
                kind: BracketProjectAssetResourceReport.kind,
                value: BracketProjectAssetResourceReport.make(project: exportProject)
            )
        )
        if let resourceInspectionReport = BracketProjectResourceInspectionReport.make(project: exportProject) {
            files.append(
                try jsonFile(
                    id: BracketProjectResourceInspectionReport.kind,
                    filename: "\(baseName)-resource-inspection-report.json",
                    kind: BracketProjectResourceInspectionReport.kind,
                    value: resourceInspectionReport
                )
            )
        }
        if let thumbnailInspectionReport = BracketProjectThumbnailInspectionReport.make(project: exportProject) {
            files.append(
                try jsonFile(
                    id: BracketProjectThumbnailInspectionReport.kind,
                    filename: "\(baseName)-thumbnail-inspection-report.json",
                    kind: BracketProjectThumbnailInspectionReport.kind,
                    value: thumbnailInspectionReport
                )
            )
        }
        files.append(
            try jsonFile(
                id: BracketProjectMergeReadinessReport.kind,
                filename: "\(baseName)-merge-readiness-report.json",
                kind: BracketProjectMergeReadinessReport.kind,
                value: BracketProjectMergeReadinessReport.make(project: exportProject)
            )
        )
        let imageBundleManifest = BracketProjectImageBundleManifest.make(
            project: exportProject,
            privacyLevel: privacyLevel,
            createdAt: createdAt
        )
        files.append(
            try jsonFile(
                id: BracketProjectImageBundleManifest.kind,
                filename: "\(baseName)-image-bundle-manifest.json",
                kind: BracketProjectImageBundleManifest.kind,
                value: imageBundleManifest
            )
        )
        if let imageBundleDraftPackage = BracketProjectImageBundleDraftPackageDocument.base64Package(
            manifest: imageBundleManifest
        ) {
            files.append(
                FilePayload(
                    id: BracketProjectImageBundleDraftPackageDocument.kind,
                    filename: "\(baseName)-image-bundle-draft-package.json.base64",
                    kind: BracketProjectImageBundleDraftPackageDocument.kind,
                    mimeType: BracketProjectImageBundleDraftPackageDocument.mimeType,
                    contents: imageBundleDraftPackage
                )
            )
        }
        let fusionPreview = BracketProjectFusionPreviewReport.make(project: exportProject)
        let finalOutputManifest = BracketProjectFinalOutputManifest.make(
            project: exportProject,
            privacyLevel: privacyLevel,
            createdAt: createdAt
        )
        files.append(
            try jsonFile(
                id: BracketProjectFinalOutputManifest.kind,
                filename: "\(baseName)-final-output-manifest.json",
                kind: BracketProjectFinalOutputManifest.kind,
                value: finalOutputManifest
            )
        )
        let finalOutputReadinessAudit = BracketProjectFinalOutputReadinessAudit.make(
            manifest: finalOutputManifest
        )
        files.append(
            try jsonFile(
                id: BracketProjectFinalOutputReadinessAudit.kind,
                filename: "\(baseName)-final-output-readiness-audit.json",
                kind: BracketProjectFinalOutputReadinessAudit.kind,
                value: finalOutputReadinessAudit
            )
        )
        if let fusionPreview,
           let finalOutputPreviewImage = BracketProjectFinalOutputPreviewImageDocument.base64PNG(
            fusionPreview: fusionPreview
           ) {
            files.append(
                FilePayload(
                    id: BracketProjectFinalOutputPreviewImageDocument.kind,
                    filename: "\(baseName)-final-output-preview.png.base64",
                    kind: BracketProjectFinalOutputPreviewImageDocument.kind,
                    mimeType: BracketProjectFinalOutputPreviewImageDocument.mimeType,
                    contents: finalOutputPreviewImage
                )
            )
        }
        if let fusionPreview,
           let finalOutputDraftJPEG = BracketProjectFinalOutputDraftJPEGDocument.base64JPEG(
            fusionPreview: fusionPreview
           ) {
            files.append(
                FilePayload(
                    id: BracketProjectFinalOutputDraftJPEGDocument.kind,
                    filename: "\(baseName)-final-output-draft-review.jpg.base64",
                    kind: BracketProjectFinalOutputDraftJPEGDocument.kind,
                    mimeType: BracketProjectFinalOutputDraftJPEGDocument.mimeType,
                    contents: finalOutputDraftJPEG
                )
            )
        }
        files.append(
            try jsonFile(
                id: "exposure-comparison",
                filename: "\(baseName)-exposure-comparison.json",
                kind: "exposure-comparison",
                value: BracketProjectExposureComparison.make(project: exportProject)
            )
        )
        if let sideBySidePixelComparison = BracketProjectSideBySidePixelComparison.make(project: exportProject) {
            files.append(
                try jsonFile(
                    id: BracketProjectSideBySidePixelComparison.kind,
                    filename: "\(baseName)-side-by-side-pixel-comparison.json",
                    kind: BracketProjectSideBySidePixelComparison.kind,
                    value: sideBySidePixelComparison
                )
            )
        }
        if let fusionPreview {
            files.append(
                try jsonFile(
                    id: BracketProjectFusionPreviewReport.kind,
                    filename: "\(baseName)-fusion-preview.json",
                    kind: BracketProjectFusionPreviewReport.kind,
                    value: fusionPreview
                )
            )
        }
        // Capture only the payload inventory that precedes the note so import
        // can detect stale export-note facts before privacy/integrity fallback.
        files.append(
            try jsonFile(
                id: BracketProjectExportNote.kind,
                filename: "\(baseName)-export-note.json",
                kind: BracketProjectExportNote.kind,
                value: BracketProjectExportNote.make(
                    project: exportProject,
                    privacyLevel: privacyLevel,
                    filenameTemplate: filenameTemplate,
                    generatedContentPolicy: generatedContentPolicy,
                    payloadKinds: files.map(\.kind),
                    finalOutputActionPlanSummary: finalOutputReadinessAudit.actionPlanSummary,
                    createdAt: createdAt
                )
            )
        )
        files.append(
            FilePayload(
                id: "privacy",
                filename: "\(baseName)-privacy.txt",
                kind: "privacy-report",
                mimeType: "text/plain",
                contents: privacyReport(
                    project: exportProject,
                    privacyLevel: privacyLevel,
                    generatedContentPolicy: generatedContentPolicy
                )
            )
        )
        files.append(
            FilePayload(
                id: "diagnostics",
                filename: "\(baseName)-diagnostics.txt",
                kind: "diagnostics-report",
                mimeType: "text/plain",
                contents: diagnosticsReport(project: exportProject)
            )
        )
        let archiveIntegrityManifest = BracketProjectArchiveIntegrityManifest.make(
            projectID: exportProject.id,
            privacyLevel: privacyLevel,
            createdAt: createdAt,
            files: files
        )
        files.append(
            try jsonFile(
                id: BracketProjectArchiveIntegrityManifest.kind,
                filename: "\(baseName)-archive-integrity-manifest.json",
                kind: BracketProjectArchiveIntegrityManifest.kind,
                value: archiveIntegrityManifest
            )
        )

        return BracketProjectExportBundle(
            schemaVersion: Self.schemaVersion,
            projectID: exportProject.id,
            privacyLevel: privacyLevel,
            filenameTemplate: filenameTemplate,
            generatedContentPolicy: generatedContentPolicy,
            archiveFilename: archiveFilename,
            createdAt: createdAt,
            files: files,
            summary: "\(files.count) files | \(privacyLevel.displayName) | \(filenameTemplate.displayName) | \(generatedContentPolicy.displayName) | \(exportProject.displayTitle)"
        )
    }

    var accessibilityValue: String {
        [
            "Project Export Bundle",
            projectID,
            privacyLevel.displayName,
            filenameTemplate.displayName,
            generatedContentPolicy.displayName,
            archiveFilename,
            "\(files.count) files",
            finalOutputActionPlanSummary.map { "Final output action plan: \($0)" },
            summary
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    var finalOutputActionPlanSummary: String? {
        guard let readinessAuditFile = file(kind: BracketProjectFinalOutputReadinessAudit.kind) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let audit = try? decoder.decode(
            BracketProjectFinalOutputReadinessAudit.self,
            from: Data(readinessAuditFile.contents.utf8)
        ) else {
            return nil
        }
        return audit.actionPlanSummary
    }

    var archiveText: String {
        var lines = [
            "Bracketer Project Export Bundle",
            "Schema: \(schemaVersion)",
            "Project: \(projectID)",
            "Privacy: \(privacyLevel.displayName)",
            "Filename: \(archiveFilename)",
            "Naming: \(filenameTemplate.displayName)",
            "Generated Content: \(generatedContentPolicy.displayName)",
            "Created: \(ISO8601DateFormatter().string(from: createdAt))",
            "Summary: \(summary)",
            "Final Output Action Plan: \(finalOutputActionPlanSummary ?? "Unavailable")",
            ""
        ]

        for file in files {
            lines.append("----- BEGIN \(file.filename) -----")
            lines.append("Kind: \(file.kind)")
            lines.append("MIME: \(file.mimeType)")
            lines.append("Bytes: \(file.byteCount)")
            lines.append("")
            lines.append(file.contents)
            lines.append("----- END \(file.filename) -----")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    func file(named filename: String) -> FilePayload? {
        files.first { $0.filename == filename }
    }

    func file(kind: String) -> FilePayload? {
        files.first { $0.kind == kind }
    }

    private static func jsonFile<Value: Encodable>(
        id: String,
        filename: String,
        kind: String,
        value: Value
    ) throws -> FilePayload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return FilePayload(
            id: id,
            filename: filename,
            kind: kind,
            mimeType: "application/json",
            contents: String(decoding: data, as: UTF8.self)
        )
    }

    private static func privacyReport(
        project: BracketProject,
        privacyLevel: BracketProjectExportPrivacyLevel,
        generatedContentPolicy: BracketProjectExportGeneratedContentPolicy
    ) -> String {
        [
            "Bracketer Project Privacy Report",
            "Project: \(project.id)",
            "Privacy level: \(privacyLevel.displayName)",
            "Policy: \(privacyLevel.policyDescription)",
            "Generated content export: \(generatedContentPolicy.displayName) | \(generatedContentPolicy.policyDescription)",
            "Raw photo bytes: not included",
            privacyLevel.includesAssetIdentifiers
                ? "Photos asset identifiers: included for recovery"
                : "Photos asset identifiers: redacted",
            "Contact sheet: metadata placeholders only; no thumbnails or raw photo bytes",
            "Rendered contact sheet: HTML document from metadata placeholders only; no thumbnails or raw photo bytes",
            "Contact sheet preview: deterministic fixture pixels only; not private Photos bytes, thumbnails, RAW resources, or final output",
            "Contact sheet image: base64 PNG rendered from deterministic fixture pixels only; not private Photos bytes, thumbnails, RAW resources, or final output",
            "Contact sheet PDF: base64 PDF rendered from deterministic fixture pixels only; not private Photos bytes, thumbnails, RAW resources, or final output",
            "Capture quality report: manifest facts only; no sharpness, alignment, ghosting, or physical asset inspection",
            "Asset resource report: manifest/project asset facts only; no Photos resource fetch, file read, or physical asset proof",
            "Resource inspection report: optional Photos resource metadata summary only; no image bytes, file reads, RAW decoding, or pixel proof",
            "Thumbnail inspection report: optional Photos thumbnail delivery metadata only; no thumbnail pixels, image bytes, files, RAW decoding, or physical proof",
            "Merge readiness report: manifest/project heuristic only; no private Photos bytes, alignment, ghosting, moving-subject masks, RAW pixels, or final HDR proof",
            "Image bundle manifest: metadata-only selected image/RAW bundle plan; no photo bytes, RAW resources, thumbnails, sidecar files, or filesystem package contents",
            "Image bundle draft package: base64 JSON with deterministic synthetic payload bytes only; no private Photos bytes, RAW resources, decoded image data, filesystem package contents, or physical export proof",
            "Final output manifest: planned render formats, filenames, and blockers only; no final rendered image bytes, Photos resource fetch, RAW decoding, tone mapping, or physical export proof",
            "Final output readiness audit: metadata-only readiness, blocker, recommendation, source, preview summary, and computed action plan; no final rendered image bytes, Photos resource fetch, RAW decoding, tone mapping, Files write, or physical proof",
            "Final output preview image: base64 PNG from deterministic fusion-preview pixels only; not final HDR output, Photos bytes, RAW decoding, or physical export proof",
            "Final output draft JPEG: base64 JPEG from deterministic fusion-preview pixels only; not final HDR output, Photos bytes, RAW decoding, tone-mapped user assets, or physical export proof",
            "Archive integrity manifest: payload filename, byte-count, and SHA-256 metadata only; no Photos resource fetch, file reads, RAW decoding, or physical export proof",
            "Exposure comparison: manifest EV facts only; no pixel inspection or merge scoring",
            "Side-by-side pixel comparison: deterministic synthetic pixel strips only; not private Photos bytes or merge-readiness scoring",
            "Fusion preview: deterministic synthetic pixel preview only; not final HDR science or private Photos bytes",
            "Export note: deterministic source-disclosed metadata note only; no raw photo bytes, Photos resource fetch, RAW decoding, final rendered image bytes, or physical-device proof",
            "Precise location coordinates: not included",
            project.privacy.containsGeneratedText
                ? "Generated text: included"
                : "Generated text: not included",
            project.privacy.containsCaptureContextFacts
                ? "Capture context facts: included"
                : "Capture context facts: not included"
        ].joined(separator: "\n")
    }

    private static func diagnosticsReport(project: BracketProject) -> String {
        guard let diagnosticsReference = project.diagnosticsReference else {
            return [
                "Bracketer Project Diagnostics Report",
                "Project: \(project.id)",
                "No diagnostics reference stored."
            ].joined(separator: "\n")
        }

        return [
            "Bracketer Project Diagnostics Report",
            "Project: \(project.id)",
            "Captured at: \(ISO8601DateFormatter().string(from: diagnosticsReference.capturedAt))",
            diagnosticsReference.summary
        ].joined(separator: "\n")
    }
}

struct BracketProjectImportPreview: Equatable, Sendable {
    let projectID: String
    let resolvedProjectID: String
    let displayTitle: String
    let payloadKinds: [String]
    let privacySummary: String
    let finalOutputActionPlanSummary: String?
    let duplicateProjectID: String?
    let conflictPolicy: BracketProjectImportConflictPolicy
    let actionSummary: String

    var isDuplicate: Bool {
        duplicateProjectID != nil
    }

    var accessibilityValue: String {
        [
            "Project Import Preview",
            displayTitle,
            "Project \(projectID)",
            resolvedProjectID == projectID ? nil : "Will save as \(resolvedProjectID)",
            "\(payloadKinds.count) payloads",
            privacySummary,
            finalOutputActionPlanSummary.map { "Final output action plan: \($0)" },
            duplicateProjectID.map { "Duplicate \($0)" },
            conflictPolicy.accessibilityValue,
            actionSummary
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    static func make(
        importBundle: BracketProjectImportBundle,
        existingProject: BracketProject?,
        conflictPolicy: BracketProjectImportConflictPolicy,
        resolvedProjectID: String
    ) -> BracketProjectImportPreview {
        let duplicateProjectID = existingProject?.id
        let actionSummary: String
        if let duplicateProjectID {
            switch conflictPolicy {
            case .replaceExisting:
                actionSummary = "Duplicate found; import will replace existing project \(duplicateProjectID)."
            case .keepBoth:
                actionSummary = "Duplicate found; import will keep both projects as \(resolvedProjectID)."
            case .rejectDuplicate:
                actionSummary = "Duplicate found; import will be rejected."
            }
        } else {
            actionSummary = "Import as new project \(resolvedProjectID)."
        }

        return BracketProjectImportPreview(
            projectID: importBundle.project.id,
            resolvedProjectID: resolvedProjectID,
            displayTitle: importBundle.project.displayTitle,
            payloadKinds: importBundle.payloadKinds,
            privacySummary: importBundle.project.privacy.accessibilityValue,
            finalOutputActionPlanSummary: importBundle.finalOutputActionPlanSummary,
            duplicateProjectID: duplicateProjectID,
            conflictPolicy: conflictPolicy,
            actionSummary: actionSummary
        )
    }
}

struct BracketProjectImportPreviewFailure: Equatable, Sendable {
    static let source = "projectImportPreview"
    static let boundary = "Import preview failure is no-save parser diagnostics only; it does not import, mutate the project store, persist failed archive text, read Photos bytes, decode RAW pixels, or inspect final rendered output."

    let source: String
    let failureKind: String
    let errorDescription: String
    let recoverySuggestion: String
    let conflictPolicy: BracketProjectImportConflictPolicy
    let mutationSummary: String
    let boundary: String

    var accessibilityValue: String {
        [
            "Project Import Preview Failure",
            failureKind,
            errorDescription,
            recoverySuggestion,
            conflictPolicy.accessibilityValue,
            mutationSummary,
            boundary
        ].joined(separator: " | ")
    }

    static func make(
        error: Error,
        conflictPolicy: BracketProjectImportConflictPolicy
    ) -> BracketProjectImportPreviewFailure {
        let importError = error as? BracketProjectImportError
        return BracketProjectImportPreviewFailure(
            source: source,
            failureKind: failureKind(for: importError),
            errorDescription: error.localizedDescription,
            recoverySuggestion: recoverySuggestion(for: importError),
            conflictPolicy: conflictPolicy,
            mutationSummary: "No import was saved.",
            boundary: boundary
        )
    }

    private static func failureKind(
        for error: BracketProjectImportError?
    ) -> String {
        guard let error else {
            return "import-preview-error"
        }

        switch error {
        case .invalidArchiveHeader:
            return "invalid-archive-header"
        case .malformedHeader:
            return "malformed-archive-header"
        case .unsupportedSchema:
            return "unsupported-schema"
        case .missingPayload:
            return "missing-payload"
        case .malformedPayload:
            return "malformed-payload"
        case .byteCountMismatch:
            return "byte-count-mismatch"
        case .rawPhotoBytesNotSupported:
            return "raw-photo-bytes-not-supported"
        case .duplicateProjectIdentifier:
            return "duplicate-project"
        case .finalOutputReadinessAuditMismatch:
            return "final-output-readiness-audit-mismatch"
        case .finalOutputActionPlanHeaderMismatch:
            return "final-output-action-plan-header-mismatch"
        case .exportNoteMismatch:
            return "export-note-mismatch"
        default:
            return "payload-validation-mismatch"
        }
    }

    private static func recoverySuggestion(
        for error: BracketProjectImportError?
    ) -> String {
        guard let error else {
            return "Choose a readable Bracketer project export and try preview again."
        }

        switch error {
        case .invalidArchiveHeader:
            return "Choose a Bracketer project export text file."
        case .malformedHeader:
            return "Export the project again so the archive header can be read."
        case .unsupportedSchema:
            return "Update Bracketer or export the project with a supported archive schema."
        case .missingPayload(let kind):
            return "Export the project again so the \(kind) payload is present."
        case .malformedPayload:
            return "Export the project again so every payload is valid JSON or UTF-8 text."
        case .byteCountMismatch(let filename):
            return "Export the project again because \(filename) changed after the archive was written."
        case .rawPhotoBytesNotSupported:
            return "Use a metadata-only or recovery-identifier project export without raw photo bytes."
        case .duplicateProjectIdentifier:
            return "Use Keep both or Replace existing before importing this duplicate project."
        case .finalOutputReadinessAuditMismatch:
            return "Export the project again so the final-output readiness audit matches the final-output manifest."
        case .finalOutputActionPlanHeaderMismatch:
            return "Export the project again so the final-output action-plan header matches the readiness audit."
        case .exportNoteMismatch:
            return "Export the project again so the export note matches the archive payload facts."
        default:
            return "Export the project again because one payload no longer matches its source facts."
        }
    }
}

final class FileBracketProjectStore {
    let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let spotlightIndexer: BracketProjectSpotlightIndexing

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        spotlightIndexer: BracketProjectSpotlightIndexing = DisabledBracketProjectSpotlightIndexer()
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.spotlightIndexer = spotlightIndexer
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        decoder.dateDecodingStrategy = .iso8601
    }

    static func defaultStore(
        fileManager: FileManager = .default,
        spotlightIndexer: BracketProjectSpotlightIndexing = CoreSpotlightBracketProjectIndexer()
    ) -> FileBracketProjectStore {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return FileBracketProjectStore(
            rootURL: applicationSupport
                .appendingPathComponent("Bracketer", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true),
            fileManager: fileManager,
            spotlightIndexer: spotlightIndexer
        )
    }

    func save(_ project: BracketProject, setCurrent: Bool = true) throws {
        try ensureRootExists()
        let data = try encoder.encode(project)
        try data.write(to: projectURL(for: project.id), options: [.atomic])

        var index = try loadIndex()
        index.projectIDs = ([project.id] + index.projectIDs.filter { $0 != project.id }).uniquePreservingOrder()
        if setCurrent || index.currentProjectID == nil {
            index.currentProjectID = project.id
        }
        index.updatedAt = Date()
        try saveIndex(index)
        spotlightIndexer.index(project)
    }

    func load(id: String) throws -> BracketProject? {
        let url = projectURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(BracketProject.self, from: data)
    }

    func loadAll() throws -> [BracketProject] {
        let index = try loadIndex()
        let projects = try index.projectIDs.compactMap { try load(id: $0) }
        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func current() throws -> BracketProject? {
        guard let id = try loadIndex().currentProjectID else { return nil }
        return try load(id: id)
    }

    func latest() throws -> BracketProject? {
        try loadAll().first
    }

    func load(spotlightIdentifier: String) throws -> BracketProject? {
        try loadAll().first {
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: $0.id) == spotlightIdentifier
        }
    }

    func search(_ text: String) throws -> [BracketProject] {
        try librarySnapshot(searchText: text).projects
    }

    func librarySnapshot(searchText: String = "") throws -> BracketProjectLibrarySnapshot {
        let index = try loadIndex()
        return BracketProjectLibrarySnapshot.make(
            projects: try loadAll(),
            currentProjectID: index.currentProjectID,
            query: searchText
        )
    }

    func librarySearchRoute(
        searchText: String = "",
        smartCollectionKind: BracketProjectSmartCollection.Kind? = nil,
        facetFilter: BracketProjectLibraryFacetFilter? = nil,
        capturedDay: String? = nil,
        lensID: String? = nil,
        locationPolicyID: String? = nil
    ) throws -> BracketProjectLibrarySearchRoute {
        let index = try loadIndex()
        return BracketProjectLibrarySearchRoute.make(
            projects: try loadAll(),
            currentProjectID: index.currentProjectID,
            query: searchText,
            smartCollectionKind: smartCollectionKind,
            facetFilter: facetFilter,
            capturedDay: capturedDay,
            lensID: lensID,
            locationPolicyID: locationPolicyID
        )
    }

    func exportBundle(
        id: String,
        privacyLevel: BracketProjectExportPrivacyLevel = .metadataOnly,
        filenameTemplate: BracketProjectExportFilenameTemplate = .projectIdentifier,
        generatedContentPolicy: BracketProjectExportGeneratedContentPolicy = .include
    ) throws -> BracketProjectExportBundle? {
        guard let project = try load(id: id) else { return nil }
        return try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: privacyLevel,
            filenameTemplate: filenameTemplate,
            generatedContentPolicy: generatedContentPolicy
        )
    }

    func importPreview(
        _ archiveText: String,
        importedAt: Date = Date(),
        conflictPolicy: BracketProjectImportConflictPolicy = .replaceExisting
    ) throws -> BracketProjectImportPreview {
        let importBundle = try BracketProjectImportBundle.parse(
            archiveText: archiveText,
            importedAt: importedAt
        )
        let existingProject = try load(id: importBundle.project.id)
        let resolvedProjectID: String
        if existingProject != nil, conflictPolicy == .keepBoth {
            resolvedProjectID = try uniqueImportCopyIdentifier(
                for: importBundle.project.id,
                importedAt: importedAt
            )
        } else {
            resolvedProjectID = importBundle.project.id
        }
        return BracketProjectImportPreview.make(
            importBundle: importBundle,
            existingProject: existingProject,
            conflictPolicy: conflictPolicy,
            resolvedProjectID: resolvedProjectID
        )
    }

    func importPreviewFailure(
        _ archiveText: String,
        importedAt: Date = Date(),
        conflictPolicy: BracketProjectImportConflictPolicy = .replaceExisting
    ) -> BracketProjectImportPreviewFailure? {
        do {
            _ = try importPreview(
                archiveText,
                importedAt: importedAt,
                conflictPolicy: conflictPolicy
            )
            return nil
        } catch {
            return BracketProjectImportPreviewFailure.make(
                error: error,
                conflictPolicy: conflictPolicy
            )
        }
    }

    @discardableResult
    func importArchiveText(
        _ archiveText: String,
        setCurrent: Bool = true,
        importedAt: Date = Date(),
        conflictPolicy: BracketProjectImportConflictPolicy = .replaceExisting
    ) throws -> BracketProjectImportBundle {
        var importBundle = try BracketProjectImportBundle.parse(
            archiveText: archiveText,
            importedAt: importedAt
        )
        if try load(id: importBundle.project.id) != nil {
            switch conflictPolicy {
            case .replaceExisting:
                importBundle = importBundle.resolvingConflict(
                    with: importBundle.project,
                    summary: "Conflict: replaced existing project \(importBundle.project.id)"
                )
            case .rejectDuplicate:
                throw BracketProjectImportError.duplicateProjectIdentifier(importBundle.project.id)
            case .keepBoth:
                let duplicateID = try uniqueImportCopyIdentifier(
                    for: importBundle.project.id,
                    importedAt: importedAt
                )
                let copyProject = importBundle.project.withImportConflictIdentifier(
                    duplicateID,
                    importedAt: importedAt
                )
                importBundle = importBundle.resolvingConflict(
                    with: copyProject,
                    summary: "Conflict: kept both projects as \(copyProject.id)"
                )
            }
        }
        try save(importBundle.project, setCurrent: setCurrent)
        return importBundle
    }

    func updateCuration(
        id: String,
        isFavorite: Bool,
        acceptedTags: [String],
        userNote: String?,
        updatedAt: Date = Date()
    ) throws -> BracketProject? {
        guard let project = try load(id: id) else { return nil }
        let updated = project.withUserCuration(
            isFavorite: isFavorite,
            acceptedTags: acceptedTags,
            userNote: userNote,
            updatedAt: updatedAt
        )
        try save(updated, setCurrent: false)
        return updated
    }

    func setCurrentProjectID(_ id: String?) throws {
        try ensureRootExists()
        var index = try loadIndex()
        index.currentProjectID = id
        if let id, !index.projectIDs.contains(id) {
            index.projectIDs.insert(id, at: 0)
        }
        index.updatedAt = Date()
        try saveIndex(index)
    }

    func delete(id: String) throws {
        let url = projectURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        var index = try loadIndex()
        index.projectIDs.removeAll { $0 == id }
        if index.currentProjectID == id {
            index.currentProjectID = index.projectIDs.first
        }
        index.updatedAt = Date()
        try saveIndex(index)
        spotlightIndexer.delete(projectID: id)
    }

    func deleteAll() throws {
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
        try saveIndex(BracketProjectIndex())
        spotlightIndexer.deleteAllProjects()
    }

    private var indexURL: URL {
        rootURL.appendingPathComponent("index.json")
    }

    private func ensureRootExists() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func loadIndex() throws -> BracketProjectIndex {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return BracketProjectIndex()
        }
        let data = try Data(contentsOf: indexURL)
        return try decoder.decode(BracketProjectIndex.self, from: data)
    }

    private func saveIndex(_ index: BracketProjectIndex) throws {
        try ensureRootExists()
        let data = try encoder.encode(index)
        try data.write(to: indexURL, options: [.atomic])
    }

    private func uniqueImportCopyIdentifier(
        for originalID: String,
        importedAt: Date
    ) throws -> String {
        let timestamp = Int(importedAt.timeIntervalSince1970)
        let baseID = "\(originalID)-import-\(timestamp)".fileSafeIdentifier
        var candidate = baseID
        var suffix = 2
        while try load(id: candidate) != nil {
            candidate = "\(baseID)-\(suffix)".fileSafeIdentifier
            suffix += 1
        }
        return candidate
    }

    private func projectURL(for id: String) -> URL {
        rootURL.appendingPathComponent(id.fileSafeIdentifier).appendingPathExtension("json")
    }
}

private extension String {
    var fileSafeIdentifier: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let candidate = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return candidate.isEmpty ? UUID().uuidString : candidate
    }

    var searchTokenComponents: [String] {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

extension BracketManifest.PlanSnapshot {
    var projectSummary: String {
        let plan = BracketPlan(
            evStep: evStep,
            requestedShotCount: resolvedShotCount,
            centerBias: centerBias
        )
        return "\(resolvedShotCount) shots | \(plan.shots.map(\.displayLabel).joined(separator: ", ")) | Center \(BracketEVFormatter.displayLabel(for: centerBias))"
    }
}

private extension BracketManifest {
    func exportCopy(includingAssetIdentifiers: Bool) -> BracketManifest {
        return BracketManifest(
            schemaVersion: schemaVersion,
            groupIdentifier: includingAssetIdentifiers ? groupIdentifier : metadataExportGroupIdentifier,
            source: source,
            capturedAt: capturedAt,
            captureDevice: captureDevice,
            captureLocation: captureLocation,
            captureMotion: captureMotion,
            plan: plan,
            recipe: recipe,
            shots: shots.map { shot in
                Shot(
                    index: shot.index,
                    evOffset: shot.evOffset,
                    displayLabel: shot.displayLabel,
                    filenameLabel: shot.filenameLabel,
                    assetIdentifier: includingAssetIdentifiers ? shot.assetIdentifier : nil,
                    fileType: shot.fileType,
                    captureState: shot.captureState,
                    captureDetail: shot.captureDetail,
                    metadataStatus: shot.metadataStatus,
                    metadataDetail: shot.metadataDetail,
                    availableRepresentations: shot.availableRepresentations,
                    isBestExposureCandidate: shot.isBestExposureCandidate,
                    clippingWarnings: shot.clippingWarnings
                )
            }
        )
    }

    var metadataExportGroupIdentifier: String {
        [
            source.rawValue,
            "metadata",
            "\(shots.count)shots",
            "schema\(schemaVersion)",
            "\(Int(capturedAt.timeIntervalSince1970))"
        ]
        .joined(separator: "-")
        .fileSafeIdentifier
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
