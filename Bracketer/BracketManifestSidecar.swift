import Foundation

struct BracketManifestSidecar: Codable, Equatable, Sendable {
    struct ClippingSummary: Codable, Equatable, Sendable {
        let warningCount: Int
        let warnings: [String]
    }

    struct GeneratedNote: Codable, Equatable, Sendable {
        let title: String
        let summary: String
        let mergeAdvice: String
        let warnings: [String]
        let tags: [String]
        let source: String
        let usedAppleIntelligence: Bool
        let fallbackReason: String?
        let disclosure: String

        init(run: BracketReviewNarrativeRun) {
            title = run.response.title
            summary = run.response.summary
            mergeAdvice = run.response.mergeAdvice
            warnings = run.response.warnings
            tags = run.response.tags
            source = run.source.rawValue
            usedAppleIntelligence = run.response.usedAppleIntelligence
            fallbackReason = run.fallbackReason
            disclosure = run.response.disclosure
        }
    }

    struct Provenance: Codable, Equatable, Sendable {
        let appName: String
        let createdAt: Date
        let noteSource: String?
        let containsRawPhotoBytes: Bool
        let containsAssetIdentifiers: Bool
        let containsLocationCoordinates: Bool
    }

    static let schemaVersion = 2

    let schemaVersion: Int
    let manifestSchemaVersion: Int
    let groupReference: String
    let source: BracketManifestSource
    let capturedAt: Date
    let plan: BracketManifest.PlanSnapshot
    let recipe: BracketManifest.RecipeSnapshot?
    let clippingSummary: ClippingSummary
    let generatedNote: GeneratedNote?
    let acceptedTags: [String]
    let captureContextFacts: [String]
    let provenance: Provenance

    static func make(
        manifest: BracketManifest,
        narrativeRun: BracketReviewNarrativeRun? = nil,
        captureContext: CaptureContextSummary? = nil,
        acceptedTags: [String] = [],
        storesGeneratedNote: Bool = true,
        createdAt: Date = Date()
    ) -> BracketManifestSidecar {
        let clippingWarnings = manifest.shots
            .flatMap(\.clippingWarnings)
            .uniquePreservingOrder()
        let storedNarrativeRun = storesGeneratedNote ? narrativeRun : nil
        let narrativeTags = storedNarrativeRun?.response.tags ?? []
        return BracketManifestSidecar(
            schemaVersion: Self.schemaVersion,
            manifestSchemaVersion: manifest.schemaVersion,
            groupReference: "\(manifest.source.rawValue)-schema\(manifest.schemaVersion)-\(manifest.shots.count)shots-\(Int(manifest.capturedAt.timeIntervalSince1970))",
            source: manifest.source,
            capturedAt: manifest.capturedAt,
            plan: manifest.plan,
            recipe: manifest.recipe,
            clippingSummary: ClippingSummary(
                warningCount: clippingWarnings.count,
                warnings: clippingWarnings
            ),
            generatedNote: storedNarrativeRun.map(GeneratedNote.init(run:)),
            acceptedTags: (acceptedTags + narrativeTags).uniquePreservingOrder(),
            captureContextFacts: captureContext?.promptFacts ?? [],
            provenance: Provenance(
                appName: "Bracketer",
                createdAt: createdAt,
                noteSource: storedNarrativeRun?.source.rawValue,
                containsRawPhotoBytes: false,
                containsAssetIdentifiers: false,
                containsLocationCoordinates: false
            )
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
        String(decoding: try jsonData(prettyPrinted: prettyPrinted), as: UTF8.self)
    }

    func omittingGeneratedContent(acceptedTags: [String]) -> BracketManifestSidecar {
        BracketManifestSidecar(
            schemaVersion: schemaVersion,
            manifestSchemaVersion: manifestSchemaVersion,
            groupReference: groupReference,
            source: source,
            capturedAt: capturedAt,
            plan: plan,
            recipe: recipe,
            clippingSummary: clippingSummary,
            generatedNote: nil,
            acceptedTags: acceptedTags.uniquePreservingOrder(),
            captureContextFacts: captureContextFacts,
            provenance: Provenance(
                appName: provenance.appName,
                createdAt: provenance.createdAt,
                noteSource: nil,
                containsRawPhotoBytes: provenance.containsRawPhotoBytes,
                containsAssetIdentifiers: provenance.containsAssetIdentifiers,
                containsLocationCoordinates: provenance.containsLocationCoordinates
            )
        )
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
