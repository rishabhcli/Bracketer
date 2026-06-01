import CoreSpotlight
import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct BracketProjectSpotlightRecord: Codable, Equatable, Sendable {
    static let schemaVersion = 2
    static let domainIdentifier = "bracketer.projects"

    let schemaVersion: Int
    let projectID: String
    let uniqueIdentifier: String
    let domainIdentifier: String
    let title: String
    let displayName: String
    let contentDescription: String
    let finalOutputActionPlanSummary: String
    let keywords: [String]
    let kind: String
    let createdAt: Date
    let updatedAt: Date
    let rankingHint: Double

    init(project: BracketProject) {
        schemaVersion = Self.schemaVersion
        projectID = project.id
        uniqueIdentifier = Self.uniqueIdentifier(forProjectID: project.id)
        domainIdentifier = Self.domainIdentifier
        title = project.displayTitle
        displayName = project.displayTitle
        finalOutputActionPlanSummary = project.finalOutputActionPlanSummary
        contentDescription = Self.contentDescription(
            for: project,
            finalOutputActionPlanSummary: finalOutputActionPlanSummary
        )
        keywords = Self.keywords(
            for: project,
            finalOutputActionPlanSummary: finalOutputActionPlanSummary
        )
        kind = "Bracketer Project"
        createdAt = project.createdAt
        updatedAt = project.updatedAt
        rankingHint = project.lifecycle == .reviewable ? 90 : 60
    }

    static func uniqueIdentifier(forProjectID projectID: String) -> String {
        let digest = SHA256.hash(data: Data(projectID.utf8))
            .prefix(10)
            .map { String(format: "%02x", $0) }
            .joined()
        return "bracketer.project.\(digest)"
    }

    var searchableText: String {
        ([title, displayName, contentDescription, kind] + keywords)
            .joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            "Spotlight Project",
            title,
            uniqueIdentifier,
            domainIdentifier,
            "\(keywords.count) keywords",
            "Final output action plan: \(finalOutputActionPlanSummary)",
            "Photos identifiers redacted"
        ].joined(separator: " | ")
    }

    func searchableItem() -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .json)
        attributes.title = title
        attributes.displayName = displayName
        attributes.contentDescription = contentDescription
        attributes.keywords = keywords
        attributes.kind = kind
        attributes.identifier = uniqueIdentifier
        attributes.domainIdentifier = domainIdentifier
        attributes.userCreated = true
        attributes.userOwned = true
        attributes.metadataModificationDate = updatedAt
        attributes.rankingHint = NSNumber(value: rankingHint)

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        return item
    }

    private static func contentDescription(
        for project: BracketProject,
        finalOutputActionPlanSummary: String
    ) -> String {
        var parts = [
            project.displaySubtitle,
            project.manifest.plan.projectSummary,
            "Final output action plan: \(finalOutputActionPlanSummary)",
            project.privacy.accessibilityValue,
            "Spotlight index excludes Photos local identifiers, raw photo bytes, and precise coordinates."
        ]
        if let note = project.userNote?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " | ")
    }

    private static func keywords(
        for project: BracketProject,
        finalOutputActionPlanSummary: String
    ) -> [String] {
        var values = [
            "Bracketer",
            "bracket",
            "exposure bracket",
            project.source.rawValue,
            project.lifecycle.rawValue,
            "\(project.reviewSnapshot.shotCount)-shot",
            "\(project.reviewSnapshot.availableShotCount)-available",
            "\(project.reviewSnapshot.rawAvailableCount)-raw",
            "\(project.reviewSnapshot.processedAvailableCount)-processed",
            project.manifest.plan.projectSummary,
            finalOutputActionPlanSummary,
            dateKeyword(project.createdAt),
            dateKeyword(project.updatedAt),
            project.privacy.assetIdentifierPolicy
        ]

        if let selected = project.reviewSnapshot.selectedDisplayLabel {
            values.append(selected)
        }
        if let best = project.reviewSnapshot.bestExposureLabel {
            values.append(best)
        }
        if let recipe = project.manifest.recipe {
            values.append(recipe.title)
            values.append(recipe.source)
        }
        if let generatedNote = project.sidecar?.generatedNote {
            values.append(generatedNote.title)
            values.append(generatedNote.summary)
            values.append(generatedNote.mergeAdvice)
            values.append(contentsOf: generatedNote.tags)
        }
        if let note = project.userNote {
            values.append(note)
        }
        values.append(contentsOf: project.acceptedTags)
        values.append(contentsOf: project.assets.flatMap { asset in
            [asset.displayLabel, asset.fileType, asset.captureState] + asset.availableRepresentations
        })
        if let diagnostics = project.diagnosticsReference?.summary {
            values.append(diagnostics)
        }

        return values
            .flatMap(\.spotlightKeywordComponents)
            .filter { !$0.looksLikePhotosLocalIdentifier }
            .uniquePreservingOrder()
    }

    private static func dateKeyword(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}

protocol BracketProjectSpotlightIndexing {
    func index(_ project: BracketProject)
    func delete(projectID: String)
    func deleteAllProjects()
}

struct DisabledBracketProjectSpotlightIndexer: BracketProjectSpotlightIndexing {
    func index(_ project: BracketProject) {}
    func delete(projectID: String) {}
    func deleteAllProjects() {}
}

final class CoreSpotlightBracketProjectIndexer: BracketProjectSpotlightIndexing {
    private let index: CSSearchableIndex

    init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    func index(_ project: BracketProject) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let item = BracketProjectSpotlightRecord(project: project).searchableItem()
        index.indexSearchableItems([item], completionHandler: nil)
    }

    func delete(projectID: String) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let identifier = BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: projectID)
        index.deleteSearchableItems(withIdentifiers: [identifier], completionHandler: nil)
    }

    func deleteAllProjects() {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        index.deleteSearchableItems(
            withDomainIdentifiers: [BracketProjectSpotlightRecord.domainIdentifier],
            completionHandler: nil
        )
    }
}

enum BracketerSpotlightHandoff {
    static func handoff(
        from activity: NSUserActivity,
        store: FileBracketProjectStore = .defaultStore(),
        requestedAt: Date = Date()
    ) throws -> BracketerAppIntentHandoff? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }
        return try handoff(
            forSpotlightIdentifier: identifier,
            store: store,
            requestedAt: requestedAt
        )
    }

    static func handoff(
        forSpotlightIdentifier identifier: String,
        store: FileBracketProjectStore,
        requestedAt: Date = Date()
    ) throws -> BracketerAppIntentHandoff? {
        guard let project = try store.load(spotlightIdentifier: identifier) else {
            return nil
        }
        return BracketerAppIntentHandoff(
            destination: .review,
            bracketPreset: .threeShotOneEV,
            requestedAt: requestedAt,
            projectIdentifier: project.id,
            projectTitle: project.displayTitle
        )
    }
}

private extension String {
    var spotlightKeywordComponents: [String] {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    var looksLikePhotosLocalIdentifier: Bool {
        hasPrefix("asset") || hasPrefix("private") || contains("localidentifier")
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
