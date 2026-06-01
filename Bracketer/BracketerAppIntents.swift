import AppIntents
import Combine
import Foundation
import UniformTypeIdentifiers

enum BracketerIntentDestination: String, AppEnum {
    case camera
    case proControls
    case intelligence
    case review

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bracketer Destination"

    static var caseDisplayRepresentations: [BracketerIntentDestination: DisplayRepresentation] {
        [
            .camera: "Camera",
            .proControls: "Pro Controls",
            .intelligence: "Apple Intelligence",
            .review: "Last Review",
        ]
    }

    var handoffTitle: String {
        switch self {
        case .camera:
            return "Camera"
        case .proControls:
            return "Pro Controls"
        case .intelligence:
            return "Apple Intelligence"
        case .review:
            return "Last Review"
        }
    }
}

enum BracketerIntentBracketPreset: String, AppEnum {
    case threeShotOneEV
    case fiveShotTwoEV
    case sevenShotTwoEV

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bracket Preset"

    static var caseDisplayRepresentations: [BracketerIntentBracketPreset: DisplayRepresentation] {
        [
            .threeShotOneEV: "3 shots, +/-1 EV",
            .fiveShotTwoEV: "5 shots, +/-2 EV",
            .sevenShotTwoEV: "7 shots, +/-2 EV",
        ]
    }

    var shotCount: Int {
        switch self {
        case .threeShotOneEV:
            return 3
        case .fiveShotTwoEV:
            return 5
        case .sevenShotTwoEV:
            return 7
        }
    }

    var evStep: Float {
        switch self {
        case .threeShotOneEV:
            return 1.0
        case .fiveShotTwoEV, .sevenShotTwoEV:
            return 2.0
        }
    }

    var handoffTitle: String {
        "\(shotCount) shots at +/-\(Int(evStep)) EV"
    }
}

enum BracketerIntentTimerMode: String, AppEnum {
    case off
    case threeSeconds
    case tenSeconds

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Capture Timer"

    static var caseDisplayRepresentations: [BracketerIntentTimerMode: DisplayRepresentation] {
        [
            .off: "Off",
            .threeSeconds: "3 Seconds",
            .tenSeconds: "10 Seconds",
        ]
    }

    init(timerMode: TimerMode) {
        switch timerMode {
        case .off:
            self = .off
        case .threeSeconds:
            self = .threeSeconds
        case .tenSeconds:
            self = .tenSeconds
        }
    }

    var timerMode: TimerMode {
        switch self {
        case .off:
            return .off
        case .threeSeconds:
            return .threeSeconds
        case .tenSeconds:
            return .tenSeconds
        }
    }

    var handoffTitle: String {
        timerMode.displayName
    }
}

struct BracketerAppIntentHandoff: Equatable {
    let destination: BracketerIntentDestination
    let bracketPreset: BracketerIntentBracketPreset
    let requestedAt: Date
    let timerMode: BracketerIntentTimerMode?
    let projectIdentifier: String?
    let projectTitle: String?

    init(
        destination: BracketerIntentDestination,
        bracketPreset: BracketerIntentBracketPreset,
        requestedAt: Date,
        timerMode: BracketerIntentTimerMode? = nil,
        projectIdentifier: String? = nil,
        projectTitle: String? = nil
    ) {
        self.destination = destination
        self.bracketPreset = bracketPreset
        self.requestedAt = requestedAt
        self.timerMode = timerMode
        self.projectIdentifier = projectIdentifier
        self.projectTitle = projectTitle
    }

    var capturePlan: BracketPlan {
        BracketPlan(
            evStep: bracketPreset.evStep,
            requestedShotCount: bracketPreset.shotCount
        )
    }

    var accessibilityValue: String {
        var parts = [
            "Destination: \(destination.handoffTitle)",
            "Bracket: \(bracketPreset.handoffTitle)"
        ]
        if let timerMode {
            parts.append("Timer: \(timerMode.handoffTitle)")
            parts.append("Timer-prepared handoff only; capture still requires the photographer in the app.")
        }
        if let projectTitle {
            parts.append("Project: \(projectTitle)")
        } else if let projectIdentifier {
            parts.append("Project: \(projectIdentifier)")
        }
        if let projectIdentifier {
            parts.append("Project ID: \(projectIdentifier)")
        }
        return parts.joined(separator: " | ")
    }

    var routingIdentifier: String {
        [
            destination.rawValue,
            bracketPreset.rawValue,
            timerMode?.rawValue ?? "current-timer",
            projectIdentifier ?? "latest",
            "\(Int(requestedAt.timeIntervalSince1970 * 1_000))"
        ].joined(separator: "|")
    }
}

@MainActor
final class BracketerAppIntentRouter: ObservableObject {
    static let shared = BracketerAppIntentRouter()

    @Published private(set) var lastHandoff: BracketerAppIntentHandoff?

    private init() {}

    func handle(_ handoff: BracketerAppIntentHandoff) {
        lastHandoff = handoff
    }
}

struct OpenBracketerIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Bracketer"
    static let description = IntentDescription("Open Bracketer to a camera workflow.")
    static let openAppWhenRun = true

    @Parameter(title: "Destination", default: BracketerIntentDestination.camera)
    var destination: BracketerIntentDestination

    @Parameter(title: "Bracket Preset", default: BracketerIntentBracketPreset.threeShotOneEV)
    var bracketPreset: BracketerIntentBracketPreset

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let handoff = BracketerAppIntentHandoff(
            destination: destination,
            bracketPreset: bracketPreset,
            requestedAt: Date()
        )
        await BracketerAppIntentRouter.shared.handle(handoff)
        return .result(dialog: "Opening Bracketer to \(destination.handoffTitle).")
    }
}

struct PrepareTimedBracketCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Prepare Timed Bracketer Capture"
    static let description = IntentDescription("Open Bracketer with a bracket preset and timer ready. This does not capture photos in the background.")
    static let openAppWhenRun = true

    @Parameter(title: "Bracket Preset", default: BracketerIntentBracketPreset.fiveShotTwoEV)
    var bracketPreset: BracketerIntentBracketPreset

    @Parameter(title: "Timer", default: BracketerIntentTimerMode.threeSeconds)
    var timer: BracketerIntentTimerMode

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let handoff = BracketerAppIntentHandoff(
            destination: .camera,
            bracketPreset: bracketPreset,
            requestedAt: Date(),
            timerMode: timer
        )
        await BracketerAppIntentRouter.shared.handle(handoff)
        return .result(dialog: "Preparing \(bracketPreset.handoffTitle) in Bracketer with \(timer.handoffTitle) timer. Open the app to review and start capture.")
    }
}

struct SummarizeLatestBracketProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Latest Bracketer Project"
    static let description = IntentDescription("Summarize the latest saved Bracketer project without opening the camera.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try LatestBracketProjectSummaryProvider().summary()
        return .result(dialog: "\(summary.dialogText)")
    }
}

struct LatestBracketProjectReviewHandoffResult: Equatable {
    let summary: LatestBracketProjectSummary
    let handoff: BracketerAppIntentHandoff
    let dialogText: String
}

struct LatestBracketProjectReviewHandoffProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func handoff(requestedAt: Date = Date()) throws -> LatestBracketProjectReviewHandoffResult {
        let summary = try LatestBracketProjectSummaryProvider(store: store).summary()
        let handoff = BracketerAppIntentHandoff(
            destination: summary.hasProject ? .review : .camera,
            bracketPreset: .threeShotOneEV,
            requestedAt: requestedAt,
            projectTitle: summary.hasProject ? summary.title : nil
        )
        let dialog: String
        if summary.hasProject {
            dialog = "Opening \(summary.title) in Bracketer review. \(summary.suggestedAction)"
        } else {
            dialog = "Opening Bracketer camera. No saved project is available yet; capture a bracket before review."
        }
        return LatestBracketProjectReviewHandoffResult(
            summary: summary,
            handoff: handoff,
            dialogText: dialog
        )
    }
}

struct OpenLatestBracketProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Latest Bracketer Review"
    static let description = IntentDescription("Open Bracketer to the latest saved project review when one exists.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try LatestBracketProjectReviewHandoffProvider().handoff()
        await BracketerAppIntentRouter.shared.handle(result.handoff)
        return .result(dialog: "\(result.dialogText)")
    }
}

struct BracketProjectEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bracket Project")
    static var defaultQuery = BracketProjectEntityQuery()

    let id: String
    let title: String
    let detail: String
    let privacy: String
    let finalOutputActionPlanSummary: String

    init(project: BracketProject) {
        id = project.id
        title = project.displayTitle
        detail = project.displaySubtitle
        privacy = project.privacy.accessibilityValue
        finalOutputActionPlanSummary = project.finalOutputActionPlanSummary
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(detail)"
        )
    }

    var accessibilityValue: String {
        [
            title,
            detail,
            privacy,
            "Final output action plan: \(finalOutputActionPlanSummary)",
            "Identifier \(id)"
        ].joined(separator: " | ")
    }
}

struct BracketProjectEntityQuery: EntityStringQuery {
    let rootURL: URL?

    init() {
        rootURL = nil
    }

    init(store: FileBracketProjectStore) {
        rootURL = store.rootURL
    }

    private var resolvedStore: FileBracketProjectStore {
        if let rootURL {
            return FileBracketProjectStore(rootURL: rootURL)
        }
        return .defaultStore()
    }

    func entities(for identifiers: [BracketProjectEntity.ID]) async throws -> [BracketProjectEntity] {
        let store = resolvedStore
        return try identifiers.compactMap { id in
            try store.load(id: id).map(BracketProjectEntity.init(project:))
        }
    }

    func suggestedEntities() async throws -> [BracketProjectEntity] {
        let store = resolvedStore
        return try store.loadAll()
            .prefix(5)
            .map(BracketProjectEntity.init(project:))
    }

    func entities(matching string: String) async throws -> [BracketProjectEntity] {
        let store = resolvedStore
        return try store.search(string)
            .prefix(5)
            .map(BracketProjectEntity.init(project:))
    }
}

enum BracketProjectLibraryIntentCollection: String, AppEnum {
    case all
    case reviewable
    case needsReview
    case favorites
    case rawAvailable
    case recoveryIdentifiers
    case generatedNotes
    case exported

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project Collection"

    static var caseDisplayRepresentations: [BracketProjectLibraryIntentCollection: DisplayRepresentation] {
        [
            .all: "All Projects",
            .reviewable: "Reviewable",
            .needsReview: "Needs Review",
            .favorites: "Favorites",
            .rawAvailable: "RAW Available",
            .recoveryIdentifiers: "Recovery IDs",
            .generatedNotes: "Generated Notes",
            .exported: "Exported"
        ]
    }

    var smartCollectionKind: BracketProjectSmartCollection.Kind? {
        switch self {
        case .all:
            return nil
        case .reviewable:
            return .reviewable
        case .needsReview:
            return .needsReview
        case .favorites:
            return .favorites
        case .rawAvailable:
            return .rawAvailable
        case .recoveryIdentifiers:
            return .recoveryIdentifiers
        case .generatedNotes:
            return .generatedNotes
        case .exported:
            return .exported
        }
    }
}

enum BracketProjectLibraryIntentFacet: String, AppEnum {
    case all
    case rawAvailable
    case highDynamicRange
    case qualityReady
    case finalOutputBlocked
    case exported

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project Facet"

    static var caseDisplayRepresentations: [BracketProjectLibraryIntentFacet: DisplayRepresentation] {
        [
            .all: "All Facets",
            .rawAvailable: "RAW Available",
            .highDynamicRange: "Dynamic Range",
            .qualityReady: "Quality Ready",
            .finalOutputBlocked: "Output Blocked",
            .exported: "Exported"
        ]
    }

    var facetFilter: BracketProjectLibraryFacetFilter? {
        switch self {
        case .all:
            return nil
        case .rawAvailable:
            return .rawAvailable
        case .highDynamicRange:
            return .highDynamicRange
        case .qualityReady:
            return .qualityReady
        case .finalOutputBlocked:
            return .finalOutputBlocked
        case .exported:
            return .exported
        }
    }
}

struct BracketProjectLibrarySearchIntentResult {
    let route: BracketProjectLibrarySearchRoute
    let entities: [BracketProjectEntity]

    var dialogText: String {
        "Found \(route.dialogText)."
    }
}

struct BracketProjectLibrarySearchProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func search(
        text: String,
        collection: BracketProjectLibraryIntentCollection,
        facet: BracketProjectLibraryIntentFacet = .all,
        capturedDay: String = "",
        lensID: String = "",
        locationPolicyID: String = ""
    ) throws -> BracketProjectLibrarySearchIntentResult {
        let route = try store.librarySearchRoute(
            searchText: text,
            smartCollectionKind: collection.smartCollectionKind,
            facetFilter: facet.facetFilter,
            capturedDay: capturedDay,
            lensID: lensID,
            locationPolicyID: locationPolicyID
        )
        let entities = try route.resultProjectIDs.compactMap { id in
            try store.load(id: id).map(BracketProjectEntity.init(project:))
        }
        return BracketProjectLibrarySearchIntentResult(route: route, entities: entities)
    }
}

struct QueryBracketProjectsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Bracketer Projects"
    static let description = IntentDescription("Search saved Bracketer projects by text and project collection.")
    static let openAppWhenRun = false

    @Parameter(title: "Search Text", default: "")
    var searchText: String

    @Parameter(title: "Collection", default: BracketProjectLibraryIntentCollection.all)
    var collection: BracketProjectLibraryIntentCollection

    @Parameter(title: "Facet", default: BracketProjectLibraryIntentFacet.all)
    var facet: BracketProjectLibraryIntentFacet

    @Parameter(title: "Captured Day", default: "")
    var capturedDay: String

    @Parameter(title: "Lens ID", default: "")
    var lensID: String

    @Parameter(title: "Location Policy ID", default: "")
    var locationPolicyID: String

    func perform() async throws -> some IntentResult & ReturnsValue<[BracketProjectEntity]> & ProvidesDialog {
        let result = try BracketProjectLibrarySearchProvider().search(
            text: searchText,
            collection: collection,
            facet: facet,
            capturedDay: capturedDay,
            lensID: lensID,
            locationPolicyID: locationPolicyID
        )
        return .result(value: result.entities, dialog: "\(result.dialogText)")
    }
}

struct OpenBracketProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Bracketer Project"
    static let description = IntentDescription("Open Bracketer to a saved bracket project handoff.")
    static let openAppWhenRun = true

    @Parameter(title: "Project")
    var project: BracketProjectEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let handoff = BracketerAppIntentHandoff(
            destination: .review,
            bracketPreset: .threeShotOneEV,
            requestedAt: Date(),
            projectIdentifier: project.id,
            projectTitle: project.title
        )
        await BracketerAppIntentRouter.shared.handle(handoff)
        return .result(dialog: "Opening \(project.title) in Bracketer.")
    }
}

enum BracketProjectExportIntentPrivacy: String, AppEnum {
    case metadataOnly
    case recoveryIdentifiers

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project Export Privacy"

    static var caseDisplayRepresentations: [BracketProjectExportIntentPrivacy: DisplayRepresentation] {
        [
            .metadataOnly: "Metadata Only",
            .recoveryIdentifiers: "Recovery Identifiers",
        ]
    }

    var projectPrivacyLevel: BracketProjectExportPrivacyLevel {
        switch self {
        case .metadataOnly:
            return .metadataOnly
        case .recoveryIdentifiers:
            return .recoveryIdentifiers
        }
    }
}

enum BracketProjectExportIntentGeneratedContent: String, AppEnum {
    case omit
    case include

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project Export Generated Content"

    static var caseDisplayRepresentations: [BracketProjectExportIntentGeneratedContent: DisplayRepresentation] {
        [
            .omit: "Omit Generated",
            .include: "Include Generated",
        ]
    }

    var projectGeneratedContentPolicy: BracketProjectExportGeneratedContentPolicy {
        switch self {
        case .omit:
            return .omit
        case .include:
            return .include
        }
    }
}

enum BracketProjectExportIntentFilenameTemplate: String, AppEnum {
    case projectIdentifier
    case datedSummary
    case privacyAudit

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project Export Filename"

    static var caseDisplayRepresentations: [BracketProjectExportIntentFilenameTemplate: DisplayRepresentation] {
        [
            .projectIdentifier: "Project ID",
            .datedSummary: "Dated Summary",
            .privacyAudit: "Privacy Audit",
        ]
    }

    var projectFilenameTemplate: BracketProjectExportFilenameTemplate {
        switch self {
        case .projectIdentifier:
            return .projectIdentifier
        case .datedSummary:
            return .datedSummary
        case .privacyAudit:
            return .privacyAudit
        }
    }
}

struct LatestBracketProjectExportFile: Equatable, Sendable {
    let projectID: String
    let filename: String
    let archiveText: String
    let finalOutputActionPlanSummary: String?
    let dialogText: String
    let accessibilityValue: String

    var data: Data {
        Data(archiveText.utf8)
    }

    var intentFile: IntentFile {
        IntentFile(data: data, filename: filename, type: .plainText)
    }
}

struct LatestBracketManifestExportFile: Equatable, Sendable {
    let projectID: String
    let filename: String
    let manifestJSON: String
    let dialogText: String
    let accessibilityValue: String

    var data: Data {
        Data(manifestJSON.utf8)
    }

    var intentFile: IntentFile {
        IntentFile(data: data, filename: filename, type: .json)
    }
}

enum LatestBracketProjectExportError: LocalizedError {
    case noProject

    var errorDescription: String? {
        switch self {
        case .noProject:
            return "No saved Bracketer project is available to export."
        }
    }
}

enum BracketProjectExportFileError: LocalizedError {
    case projectNotFound(String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let projectID):
            return "Saved Bracketer project \(projectID) could not be found for export."
        }
    }
}

struct BracketProjectExportFileProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func exportFile(
        projectID: String,
        privacy: BracketProjectExportIntentPrivacy = .metadataOnly,
        filenameTemplate: BracketProjectExportIntentFilenameTemplate = .projectIdentifier,
        generatedContent: BracketProjectExportIntentGeneratedContent = .omit,
        createdAt: Date = Date()
    ) throws -> LatestBracketProjectExportFile {
        guard let project = try store.load(id: projectID) else {
            throw BracketProjectExportFileError.projectNotFound(projectID)
        }
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: privacy.projectPrivacyLevel,
            filenameTemplate: filenameTemplate.projectFilenameTemplate,
            generatedContentPolicy: generatedContent.projectGeneratedContentPolicy,
            createdAt: createdAt
        )
        return LatestBracketProjectExportFile(
            projectID: bundle.projectID,
            filename: bundle.archiveFilename,
            archiveText: bundle.archiveText,
            finalOutputActionPlanSummary: bundle.finalOutputActionPlanSummary,
            dialogText: "Exported \(project.displayTitle) as a \(bundle.privacyLevel.displayName) Bracketer project bundle with \(bundle.generatedContentPolicy.displayName.lowercased()).",
            accessibilityValue: bundle.accessibilityValue
        )
    }
}

struct LatestBracketProjectExportFileProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func exportFile(
        privacy: BracketProjectExportIntentPrivacy = .metadataOnly,
        filenameTemplate: BracketProjectExportIntentFilenameTemplate = .projectIdentifier,
        generatedContent: BracketProjectExportIntentGeneratedContent = .omit,
        createdAt: Date = Date()
    ) throws -> LatestBracketProjectExportFile {
        guard let project = try store.latest() else {
            throw LatestBracketProjectExportError.noProject
        }
        return try BracketProjectExportFileProvider(store: store).exportFile(
            projectID: project.id,
            privacy: privacy,
            filenameTemplate: filenameTemplate,
            generatedContent: generatedContent,
            createdAt: createdAt
        )
    }
}

struct LatestBracketManifestExportFileProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func exportFile(
        privacy: BracketProjectExportIntentPrivacy = .metadataOnly,
        filenameTemplate: BracketProjectExportIntentFilenameTemplate = .datedSummary
    ) throws -> LatestBracketManifestExportFile {
        guard let project = try store.latest() else {
            throw LatestBracketProjectExportError.noProject
        }
        let privacyLevel = privacy.projectPrivacyLevel
        let manifest = project.exportCopy(
            privacyLevel: privacyLevel,
            generatedContentPolicy: .omit
        ).manifest
        let manifestJSON = try manifest.jsonString()
        let baseName = filenameTemplate.projectFilenameTemplate
            .payloadBaseName(project: project, privacyLevel: privacyLevel)
        let filename = "\(baseName)-manifest.json"
        let boundary = "Manifest only; no raw photo bytes, Photos resource fetches, RAW decoding, final rendered output, or physical proof."
        return LatestBracketManifestExportFile(
            projectID: project.id,
            filename: filename,
            manifestJSON: manifestJSON,
            dialogText: "Exported latest Bracketer manifest as \(privacyLevel.displayName). \(boundary)",
            accessibilityValue: [
                "Latest Bracketer Manifest",
                "Project \(project.displayTitle)",
                privacyLevel.displayName,
                filename,
                boundary
            ].joined(separator: " | ")
        )
    }
}

struct ExportLatestBracketProjectBundleIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Latest Bracketer Project Bundle"
    static let description = IntentDescription("Export the latest saved Bracketer project as a provenance-preserving metadata bundle.")
    static let openAppWhenRun = false

    @Parameter(title: "Privacy", default: BracketProjectExportIntentPrivacy.metadataOnly)
    var privacy: BracketProjectExportIntentPrivacy

    @Parameter(title: "Filename", default: BracketProjectExportIntentFilenameTemplate.projectIdentifier)
    var filenameTemplate: BracketProjectExportIntentFilenameTemplate

    @Parameter(title: "Generated Content", default: BracketProjectExportIntentGeneratedContent.omit)
    var generatedContent: BracketProjectExportIntentGeneratedContent

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try LatestBracketProjectExportFileProvider().exportFile(
            privacy: privacy,
            filenameTemplate: filenameTemplate,
            generatedContent: generatedContent
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

struct ExportLatestBracketManifestIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Latest Bracketer Manifest"
    static let description = IntentDescription("Export only the latest saved Bracketer manifest JSON with explicit privacy redaction.")
    static let openAppWhenRun = false

    @Parameter(title: "Privacy", default: BracketProjectExportIntentPrivacy.metadataOnly)
    var privacy: BracketProjectExportIntentPrivacy

    @Parameter(title: "Filename", default: BracketProjectExportIntentFilenameTemplate.datedSummary)
    var filenameTemplate: BracketProjectExportIntentFilenameTemplate

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try LatestBracketManifestExportFileProvider().exportFile(
            privacy: privacy,
            filenameTemplate: filenameTemplate
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

struct ExportBracketProjectBundleIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Bracketer Project Bundle"
    static let description = IntentDescription("Export a selected Bracketer project as a provenance-preserving metadata bundle.")
    static let openAppWhenRun = false

    @Parameter(title: "Project")
    var project: BracketProjectEntity

    @Parameter(title: "Privacy", default: BracketProjectExportIntentPrivacy.metadataOnly)
    var privacy: BracketProjectExportIntentPrivacy

    @Parameter(title: "Filename", default: BracketProjectExportIntentFilenameTemplate.projectIdentifier)
    var filenameTemplate: BracketProjectExportIntentFilenameTemplate

    @Parameter(title: "Generated Content", default: BracketProjectExportIntentGeneratedContent.omit)
    var generatedContent: BracketProjectExportIntentGeneratedContent

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try BracketProjectExportFileProvider().exportFile(
            projectID: project.id,
            privacy: privacy,
            filenameTemplate: filenameTemplate,
            generatedContent: generatedContent
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

enum BracketProjectImportIntentConflictPolicy: String, AppEnum {
    case keepBoth
    case replaceExisting
    case rejectDuplicate

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project Import Duplicate Policy"

    static var caseDisplayRepresentations: [BracketProjectImportIntentConflictPolicy: DisplayRepresentation] {
        [
            .keepBoth: "Keep Both",
            .replaceExisting: "Replace Existing",
            .rejectDuplicate: "Reject Duplicate",
        ]
    }

    var projectConflictPolicy: BracketProjectImportConflictPolicy {
        switch self {
        case .keepBoth:
            return .keepBoth
        case .replaceExisting:
            return .replaceExisting
        case .rejectDuplicate:
            return .rejectDuplicate
        }
    }
}

struct ImportedBracketProjectFile: Equatable, Sendable {
    let projectID: String
    let title: String
    let filename: String
    let payloadKinds: [String]
    let finalOutputActionPlanSummary: String?
    let conflictSummary: String?
    let dialogText: String
    let accessibilityValue: String
}

enum BracketProjectImportFileError: LocalizedError {
    case unreadableArchive(filename: String)

    var errorDescription: String? {
        switch self {
        case .unreadableArchive(let filename):
            return "The Bracketer project bundle \(filename) is not valid UTF-8 archive text."
        }
    }
}

struct BracketProjectImportFileProvider {
    let store: FileBracketProjectStore

    init(store: FileBracketProjectStore = .defaultStore()) {
        self.store = store
    }

    func importFile(
        _ file: IntentFile,
        conflictPolicy: BracketProjectImportIntentConflictPolicy = .keepBoth,
        importedAt: Date = Date()
    ) throws -> ImportedBracketProjectFile {
        try importData(
            file.data,
            filename: file.filename,
            conflictPolicy: conflictPolicy,
            importedAt: importedAt
        )
    }

    func importData(
        _ data: Data,
        filename: String,
        conflictPolicy: BracketProjectImportIntentConflictPolicy = .keepBoth,
        importedAt: Date = Date()
    ) throws -> ImportedBracketProjectFile {
        guard let archiveText = String(data: data, encoding: .utf8) else {
            throw BracketProjectImportFileError.unreadableArchive(filename: filename)
        }
        let importBundle = try store.importArchiveText(
            archiveText,
            importedAt: importedAt,
            conflictPolicy: conflictPolicy.projectConflictPolicy
        )
        let title = importBundle.project.displayTitle
        let conflictSummary = importBundle.conflictResolution
        var dialog = "Imported \(title) from \(filename) with \(importBundle.payloadKinds.count) payloads."
        if let conflictSummary {
            dialog += " \(conflictSummary)."
        }
        let accessibilityValue = [
            "Imported Bracketer Project",
            title,
            "Project ID: \(importBundle.project.id)",
            "Filename: \(filename)",
            "Duplicate policy: \(conflictPolicy.projectConflictPolicy.displayName)",
            "\(importBundle.payloadKinds.count) payloads",
            importBundle.project.privacy.accessibilityValue,
            importBundle.finalOutputActionPlanSummary.map { "Final output action plan: \($0)" },
            conflictSummary
        ]
            .compactMap { $0 }
            .joined(separator: " | ")
        return ImportedBracketProjectFile(
            projectID: importBundle.project.id,
            title: title,
            filename: filename,
            payloadKinds: importBundle.payloadKinds,
            finalOutputActionPlanSummary: importBundle.finalOutputActionPlanSummary,
            conflictSummary: conflictSummary,
            dialogText: dialog,
            accessibilityValue: accessibilityValue
        )
    }
}

struct ImportBracketProjectBundleIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Bracketer Project Bundle"
    static let description = IntentDescription("Import a saved Bracketer project bundle from a Shortcuts file.")
    static let openAppWhenRun = false

    @Parameter(title: "Archive File")
    var archiveFile: IntentFile

    @Parameter(title: "Duplicate Projects", default: BracketProjectImportIntentConflictPolicy.keepBoth)
    var conflictPolicy: BracketProjectImportIntentConflictPolicy

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let importResult = try BracketProjectImportFileProvider().importFile(
            archiveFile,
            conflictPolicy: conflictPolicy
        )
        return .result(dialog: "\(importResult.dialogText)")
    }
}

enum BracketerPhysicalRunbookIntentScenario: String, AppEnum {
    case dynamicRangeInteriorWindow
    case lensProRAWResourceSweep
    case handheldMotionRecovery
    case photosPermissionLocationSweep
    case storagePressurePartialSave
    case liveFoundationModelsCoach
    case filesShortcutsSpotlightRoundTrip
    case multiDeviceOSRegression

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Physical Runbook Scenario"

    static var caseDisplayRepresentations: [BracketerPhysicalRunbookIntentScenario: DisplayRepresentation] {
        [
            .dynamicRangeInteriorWindow: "Interior Window Dynamic Range",
            .lensProRAWResourceSweep: "Lens ProRAW Resource Sweep",
            .handheldMotionRecovery: "Handheld Motion Recovery",
            .photosPermissionLocationSweep: "Photos Permission Location Sweep",
            .storagePressurePartialSave: "Storage Pressure Partial Save",
            .liveFoundationModelsCoach: "Live Foundation Models Coach",
            .filesShortcutsSpotlightRoundTrip: "Files Shortcuts Spotlight Round Trip",
            .multiDeviceOSRegression: "Multi-Device OS Regression",
        ]
    }

    var runbookID: String {
        rawValue
    }
}

struct BracketerPhysicalResultBundleCommandPlanFile: Equatable, Sendable {
    let scenarioID: String
    let filename: String
    let documentText: String
    let dialogText: String
    let accessibilityValue: String

    var data: Data {
        Data(documentText.utf8)
    }

    var intentFile: IntentFile {
        IntentFile(data: data, filename: filename, type: .plainText)
    }
}

enum BracketerPhysicalResultBundleCommandPlanFileProviderError: LocalizedError, Equatable {
    case runbookNotFound(String)

    var errorDescription: String? {
        switch self {
        case .runbookNotFound(let scenarioID):
            return "Physical runbook scenario \(scenarioID) could not be found for command-plan export."
        }
    }
}

struct BracketerPhysicalResultBundleCommandPlanFileProvider {
    let catalog: BracketerPhysicalCaptureRunbookCatalog

    init(catalog: BracketerPhysicalCaptureRunbookCatalog = .make()) {
        self.catalog = catalog
    }

    func exportFile(
        scenario: BracketerPhysicalRunbookIntentScenario,
        includeMetricsExtraction: Bool = true,
        resultBundlePath: String = ""
    ) throws -> BracketerPhysicalResultBundleCommandPlanFile {
        guard let runbook = catalog.runbooks.first(where: { $0.id == scenario.runbookID }) else {
            throw BracketerPhysicalResultBundleCommandPlanFileProviderError.runbookNotFound(scenario.runbookID)
        }
        let trimmedResultBundlePath = resultBundlePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = try BracketerPhysicalResultBundleCommandPlanDocument(
            runbook: runbook,
            resultBundlePath: trimmedResultBundlePath.isEmpty ? nil : trimmedResultBundlePath,
            includeMetricsExtraction: includeMetricsExtraction
        )
        return BracketerPhysicalResultBundleCommandPlanFile(
            scenarioID: runbook.id,
            filename: document.filename,
            documentText: document.documentText,
            dialogText: "Exported a copy/share-only physical result-bundle command plan for \(runbook.scenarioTitle). No physical proof count changed.",
            accessibilityValue: document.accessibilityValue
        )
    }
}

struct ExportBracketerPhysicalResultBundleCommandPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Bracketer Physical Result Bundle Command Plan"
    static let description = IntentDescription("Export non-executing result-bundle digest and xcresulttool commands for a physical proof runbook. Optional custom result-bundle paths must end in .xcresult and keep the Bracketer-scenario-physical filename prefix.")
    static let openAppWhenRun = false

    @Parameter(title: "Scenario", default: BracketerPhysicalRunbookIntentScenario.dynamicRangeInteriorWindow)
    var scenario: BracketerPhysicalRunbookIntentScenario

    @Parameter(title: "Include Metrics Command", default: true)
    var includeMetricsExtraction: Bool

    @Parameter(title: "Result Bundle Path", default: "")
    var resultBundlePath: String

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
            scenario: scenario,
            includeMetricsExtraction: includeMetricsExtraction,
            resultBundlePath: resultBundlePath
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

struct BracketerPhysicalProofTemplateFile: Equatable, Sendable {
    let scenarioID: String
    let filename: String
    let documentText: String
    let dialogText: String
    let accessibilityValue: String

    var data: Data {
        Data(documentText.utf8)
    }

    var intentFile: IntentFile {
        IntentFile(data: data, filename: filename, type: .json)
    }
}

enum BracketerPhysicalProofTemplateFileProviderError: LocalizedError, Equatable {
    case runbookNotFound(String)

    var errorDescription: String? {
        switch self {
        case .runbookNotFound(let scenarioID):
            return "Physical runbook scenario \(scenarioID) could not be found for seeded proof-template export."
        }
    }
}

struct BracketerPhysicalProofTemplateFileProvider {
    let catalog: BracketerPhysicalCaptureRunbookCatalog

    init(catalog: BracketerPhysicalCaptureRunbookCatalog = .make()) {
        self.catalog = catalog
    }

    func exportFile(
        scenario: BracketerPhysicalRunbookIntentScenario,
        compactSummaryData: Data,
        attachmentByteCount: Int
    ) throws -> BracketerPhysicalProofTemplateFile {
        guard let runbook = catalog.runbooks.first(where: { $0.id == scenario.runbookID }) else {
            throw BracketerPhysicalProofTemplateFileProviderError.runbookNotFound(scenario.runbookID)
        }
        let document = try BracketerPhysicalProofSubmissionDocument(
            prefillingTemplateFor: runbook,
            compactXCResultSummaryJSON: compactSummaryData,
            attachmentByteCount: attachmentByteCount
        )
        return BracketerPhysicalProofTemplateFile(
            scenarioID: runbook.id,
            filename: document.filename,
            documentText: document.documentText,
            dialogText: "Exported a preview-only physical proof template for \(runbook.scenarioTitle). Replace placeholders after a real iPhone run before ingest. No physical proof count changed.",
            accessibilityValue: document.accessibilityValue
        )
    }
}

struct ExportBracketerPhysicalProofTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Bracketer Physical Proof Template"
    static let description = IntentDescription("Export a preview-only physical proof template from compact xcresult summary JSON.")
    static let openAppWhenRun = false

    @Parameter(title: "Scenario", default: BracketerPhysicalRunbookIntentScenario.dynamicRangeInteriorWindow)
    var scenario: BracketerPhysicalRunbookIntentScenario

    @Parameter(title: "Compact Summary JSON")
    var compactSummaryFile: IntentFile

    @Parameter(title: "Attachment Byte Count")
    var attachmentByteCount: Int

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try BracketerPhysicalProofTemplateFileProvider().exportFile(
            scenario: scenario,
            compactSummaryData: compactSummaryFile.data,
            attachmentByteCount: attachmentByteCount
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

struct BracketerPhysicalLabWorkspaceFile: Equatable, Sendable {
    let scenarioID: String
    let filename: String
    let documentText: String
    let dialogText: String
    let accessibilityValue: String

    var data: Data {
        Data(documentText.utf8)
    }

    var intentFile: IntentFile {
        IntentFile(data: data, filename: filename, type: .plainText)
    }
}

enum BracketerPhysicalLabWorkspaceFileProviderError: LocalizedError, Equatable {
    case runbookNotFound(String)

    var errorDescription: String? {
        switch self {
        case .runbookNotFound(let scenarioID):
            return "Physical runbook scenario \(scenarioID) could not be found for lab workspace export."
        }
    }
}

struct BracketerPhysicalLabWorkspaceFileProvider {
    let catalog: BracketerPhysicalCaptureRunbookCatalog

    init(catalog: BracketerPhysicalCaptureRunbookCatalog = .make()) {
        self.catalog = catalog
    }

    func exportFile(
        scenario: BracketerPhysicalRunbookIntentScenario,
        compactSummaryData: Data,
        attachmentByteCount: Int,
        includeMetricsExtraction: Bool = true,
        resultBundlePath: String = ""
    ) throws -> BracketerPhysicalLabWorkspaceFile {
        guard let runbook = catalog.runbooks.first(where: { $0.id == scenario.runbookID }) else {
            throw BracketerPhysicalLabWorkspaceFileProviderError.runbookNotFound(scenario.runbookID)
        }
        let trimmedResultBundlePath = resultBundlePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = try BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            resultBundlePath: trimmedResultBundlePath.isEmpty ? nil : trimmedResultBundlePath,
            includeMetricsExtraction: includeMetricsExtraction,
            compactXCResultSummaryJSON: compactSummaryData,
            attachmentByteCount: attachmentByteCount
        )
        return BracketerPhysicalLabWorkspaceFile(
            scenarioID: runbook.id,
            filename: document.filename,
            documentText: document.documentText,
            dialogText: "Exported a copy/share-only physical lab workspace for \(runbook.scenarioTitle). Run commands and replace proof placeholders after a real iPhone run. No physical proof count changed.",
            accessibilityValue: document.accessibilityValue
        )
    }
}

struct ExportBracketerPhysicalLabWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Bracketer Physical Lab Workspace"
    static let description = IntentDescription("Export a copy/share-only physical lab workspace that bundles a runbook, command plan, expected artifacts, output paths, and seeded proof template.")
    static let openAppWhenRun = false

    @Parameter(title: "Scenario", default: BracketerPhysicalRunbookIntentScenario.dynamicRangeInteriorWindow)
    var scenario: BracketerPhysicalRunbookIntentScenario

    @Parameter(title: "Compact Summary JSON")
    var compactSummaryFile: IntentFile

    @Parameter(title: "Attachment Byte Count")
    var attachmentByteCount: Int

    @Parameter(title: "Include Metrics Command", default: true)
    var includeMetricsExtraction: Bool

    @Parameter(title: "Result Bundle Path", default: "")
    var resultBundlePath: String

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try BracketerPhysicalLabWorkspaceFileProvider().exportFile(
            scenario: scenario,
            compactSummaryData: compactSummaryFile.data,
            attachmentByteCount: attachmentByteCount,
            includeMetricsExtraction: includeMetricsExtraction,
            resultBundlePath: resultBundlePath
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

struct BracketerPhysicalLabWorkspacePreviewFile: Equatable, Sendable {
    let preview: BracketerPhysicalLabWorkspaceReviewPreview

    var dialogText: String {
        preview.dialogText
    }

    var accessibilityValue: String {
        preview.accessibilityValue
    }
}

struct BracketerPhysicalLabWorkspacePreviewFileProvider {
    func previewFile(
        _ workspaceFile: IntentFile,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make()
    ) throws -> BracketerPhysicalLabWorkspacePreviewFile {
        let preview = try BracketerPhysicalLabWorkspaceReviewPreviewProvider().previewData(
            workspaceFile.data,
            filename: workspaceFile.filename,
            catalog: catalog
        )
        return BracketerPhysicalLabWorkspacePreviewFile(preview: preview)
    }
}

struct PreviewBracketerPhysicalLabWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Preview Bracketer Physical Lab Workspace"
    static let description = IntentDescription("Preview a Bracketer physical lab workspace manifest as a review checklist without counting physical proof.")
    static let openAppWhenRun = false

    @Parameter(title: "Workspace File")
    var workspaceFile: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let preview = try BracketerPhysicalLabWorkspacePreviewFileProvider().previewFile(workspaceFile)
        return .result(dialog: "\(preview.dialogText)")
    }
}

struct BracketerPhysicalLabReviewHandoffPackageExportFile: Equatable, Sendable {
    let scenarioID: String
    let filename: String
    let documentText: String
    let dialogText: String
    let accessibilityValue: String

    var data: Data {
        Data(documentText.utf8)
    }

    var intentFile: IntentFile {
        IntentFile(data: data, filename: filename, type: .plainText)
    }
}

enum BracketerPhysicalLabReviewHandoffPackageFileProviderError: LocalizedError, Equatable {
    case runbookNotFound(String)

    var errorDescription: String? {
        switch self {
        case .runbookNotFound(let scenarioID):
            return "Physical runbook scenario \(scenarioID) could not be found for lab review handoff package export."
        }
    }
}

struct BracketerPhysicalLabReviewHandoffPackageFileProvider {
    let catalog: BracketerPhysicalCaptureRunbookCatalog

    init(catalog: BracketerPhysicalCaptureRunbookCatalog = .make()) {
        self.catalog = catalog
    }

    func exportFile(
        scenario: BracketerPhysicalRunbookIntentScenario,
        compactSummaryData: Data,
        attachmentByteCount: Int,
        includeMetricsExtraction: Bool = true,
        resultBundlePath: String = ""
    ) throws -> BracketerPhysicalLabReviewHandoffPackageExportFile {
        guard let runbook = catalog.runbooks.first(where: { $0.id == scenario.runbookID }) else {
            throw BracketerPhysicalLabReviewHandoffPackageFileProviderError.runbookNotFound(scenario.runbookID)
        }
        let trimmedResultBundlePath = resultBundlePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspaceDocument = try BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            resultBundlePath: trimmedResultBundlePath.isEmpty ? nil : trimmedResultBundlePath,
            includeMetricsExtraction: includeMetricsExtraction,
            compactXCResultSummaryJSON: compactSummaryData,
            attachmentByteCount: attachmentByteCount
        )
        let package = BracketerPhysicalLabReviewHandoffPackage(workspaceDocument: workspaceDocument)
        return BracketerPhysicalLabReviewHandoffPackageExportFile(
            scenarioID: runbook.id,
            filename: package.filename,
            documentText: package.documentText,
            dialogText: "Exported a copy/share-only physical lab review handoff package for \(runbook.scenarioTitle). It includes a manifest, workspace, command plan, seeded proof template, output paths, and reviewer checklist. No physical proof count changed.",
            accessibilityValue: package.accessibilityValue
        )
    }
}

struct ExportBracketerPhysicalLabReviewHandoffPackageIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Bracketer Physical Lab Review Handoff Package"
    static let description = IntentDescription("Export a copy/share-only package that separates a physical lab workspace into manifest, command plan, seeded proof template, output paths, and reviewer checklist payloads.")
    static let openAppWhenRun = false

    @Parameter(title: "Scenario", default: BracketerPhysicalRunbookIntentScenario.dynamicRangeInteriorWindow)
    var scenario: BracketerPhysicalRunbookIntentScenario

    @Parameter(title: "Compact Summary JSON")
    var compactSummaryFile: IntentFile

    @Parameter(title: "Attachment Byte Count")
    var attachmentByteCount: Int

    @Parameter(title: "Include Metrics Command", default: true)
    var includeMetricsExtraction: Bool

    @Parameter(title: "Result Bundle Path", default: "")
    var resultBundlePath: String

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let export = try BracketerPhysicalLabReviewHandoffPackageFileProvider().exportFile(
            scenario: scenario,
            compactSummaryData: compactSummaryFile.data,
            attachmentByteCount: attachmentByteCount,
            includeMetricsExtraction: includeMetricsExtraction,
            resultBundlePath: resultBundlePath
        )
        return .result(value: export.intentFile, dialog: "\(export.dialogText)")
    }
}

struct BracketerPhysicalLabReviewHandoffPackagePreviewFile: Equatable, Sendable {
    let preview: BracketerPhysicalLabReviewHandoffPackageReviewPreview

    var dialogText: String {
        preview.dialogText
    }

    var accessibilityValue: String {
        preview.accessibilityValue
    }
}

struct BracketerPhysicalLabReviewHandoffPackagePreviewFileProvider {
    func previewFile(
        _ packageFile: IntentFile,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make()
    ) throws -> BracketerPhysicalLabReviewHandoffPackagePreviewFile {
        let preview = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
            packageFile.data,
            filename: packageFile.filename,
            catalog: catalog
        )
        return BracketerPhysicalLabReviewHandoffPackagePreviewFile(preview: preview)
    }
}

struct PreviewBracketerPhysicalLabReviewHandoffPackageIntent: AppIntent {
    static let title: LocalizedStringResource = "Preview Bracketer Physical Lab Review Handoff Package"
    static let description = IntentDescription("Preview a Bracketer physical lab review handoff package without counting physical proof.")
    static let openAppWhenRun = false

    @Parameter(title: "Handoff Package File")
    var packageFile: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let preview = try BracketerPhysicalLabReviewHandoffPackagePreviewFileProvider().previewFile(packageFile)
        return .result(dialog: "\(preview.dialogText)")
    }
}

struct BracketerPhysicalProofPreviewFile: Equatable, Sendable {
    let filename: String
    let preview: BracketerPhysicalProofIngestPreview
    let documentAccessibilityValue: String
    let sourceKind: String

    var dialogText: String {
        let state = preview.accepted ? "accepted candidate" : "rejected candidate"
        var parts = [
            "physical-device-proof preview only",
            sourceKind,
            state,
            "Scenario \(preview.scenarioID)",
            "No physical proof count changed"
        ]
        if !preview.rejectionReasons.isEmpty {
            parts.append("Rejections: \(preview.rejectionReasons.joined(separator: " | "))")
        }
        return parts.joined(separator: ". ")
    }

    var accessibilityValue: String {
        [
            "Physical Proof Submission Preview File",
            sourceKind,
            filename,
            documentAccessibilityValue,
            preview.accessibilityValue
        ].joined(separator: " | ")
    }
}

enum BracketerPhysicalProofPreviewFileProviderError: LocalizedError, Equatable, Sendable {
    case missingRunbookIDForProofInput(filename: String)

    var errorDescription: String? {
        switch self {
        case .missingRunbookIDForProofInput(let filename):
            return "\(filename) is parsed result-bundle proof input, but its filename does not include a known physical runbook id."
        }
    }
}

struct BracketerPhysicalProofPreviewFileProvider {
    func previewFile(
        _ file: IntentFile,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make(),
        resultBundleIndex: BracketerPhysicalResultBundleIndex? = nil
    ) throws -> BracketerPhysicalProofPreviewFile {
        try previewData(
            file.data,
            filename: file.filename,
            catalog: catalog,
            resultBundleIndex: resultBundleIndex
        )
    }

    func previewData(
        _ data: Data,
        filename: String,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make(),
        resultBundleIndex: BracketerPhysicalResultBundleIndex? = nil
    ) throws -> BracketerPhysicalProofPreviewFile {
        do {
            let document = try BracketerPhysicalProofSubmissionDocument(
                data: data,
                filename: filename
            )
            let preview = BracketerPhysicalProofIngestor.preview(
                document.submission,
                catalog: catalog,
                resultBundleIndex: resultBundleIndex
            )
            return BracketerPhysicalProofPreviewFile(
                filename: filename,
                preview: preview,
                documentAccessibilityValue: document.accessibilityValue,
                sourceKind: "physical proof submission document"
            )
        } catch {
            guard let proofInput = try? JSONDecoder().decode(
                BracketerPhysicalResultBundleProofInput.self,
                from: data
            ) else {
                throw error
            }
            return try previewProofInput(
                proofInput,
                filename: filename,
                catalog: catalog,
                resultBundleIndex: resultBundleIndex
            )
        }
    }

    private func previewProofInput(
        _ proofInput: BracketerPhysicalResultBundleProofInput,
        filename: String,
        catalog: BracketerPhysicalCaptureRunbookCatalog,
        resultBundleIndex: BracketerPhysicalResultBundleIndex?
    ) throws -> BracketerPhysicalProofPreviewFile {
        let lowercasedFilename = filename.lowercased()
        guard let runbook = catalog.runbooks.first(where: { lowercasedFilename.contains($0.id.lowercased()) }) else {
            throw BracketerPhysicalProofPreviewFileProviderError.missingRunbookIDForProofInput(filename: filename)
        }
        let seededSubmission = try BracketerPhysicalProofSubmission.template(
            for: runbook,
            proofInput: proofInput
        ).signed()
        let document = try BracketerPhysicalProofSubmissionDocument(
            submission: seededSubmission,
            filename: "Bracketer-\(runbook.id)-physical-proof-seeded-template.json"
        )
        let preview = BracketerPhysicalProofIngestor.preview(
            document.submission,
            catalog: catalog,
            resultBundleIndex: resultBundleIndex
        )
        return BracketerPhysicalProofPreviewFile(
            filename: document.filename,
            preview: preview,
            documentAccessibilityValue: document.accessibilityValue,
            sourceKind: "parsed result-bundle proof input seeded physical proof submission template"
        )
    }
}

struct PreviewBracketerPhysicalProofSubmissionIntent: AppIntent {
    static let title: LocalizedStringResource = "Preview Bracketer Physical Proof Submission"
    static let description = IntentDescription("Preview a Bracketer physical proof submission file without counting it as captured proof.")
    static let openAppWhenRun = false

    @Parameter(title: "Submission File")
    var submissionFile: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let preview = try BracketerPhysicalProofPreviewFileProvider().previewFile(submissionFile)
        return .result(dialog: "\(preview.dialogText)")
    }
}

struct BracketerShortcutTileInventory: Equatable {
    static let platformLimit = 10
    static let deferredIntentTitles = [
        "Prepare Timed Bracketer Capture",
        "Open Latest Bracketer Review",
        "Export Latest Bracketer Manifest"
    ]

    let registeredTileCount: Int
    let platformLimit: Int
    let deferredIntentTitles: [String]

    static var current: BracketerShortcutTileInventory {
        BracketerShortcutTileInventory(
            registeredTileCount: BracketerShortcuts.appShortcuts.count,
            platformLimit: Self.platformLimit,
            deferredIntentTitles: Self.deferredIntentTitles
        )
    }

    var hasHeadroom: Bool {
        registeredTileCount < platformLimit
    }

    var accessibilityValue: String {
        let deferredList = deferredIntentTitles.joined(separator: ", ")
        return [
            "Shortcut tiles: \(registeredTileCount) of \(platformLimit)",
            hasHeadroom ? "Headroom available" : "No shortcut tile headroom",
            "Deferred App Intents: \(deferredList)",
            "Deferred intents remain available as App Intents but are not registered as App Shortcut tiles."
        ].joined(separator: " | ")
    }
}

struct BracketerShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenBracketerIntent(),
            phrases: [
                "Open \(.applicationName) camera",
                "Prepare a bracket in \(.applicationName)",
                "Open \(.applicationName) Apple Intelligence",
            ],
            shortTitle: "Open Camera",
            systemImageName: "camera.aperture"
        )
        AppShortcut(
            intent: SummarizeLatestBracketProjectIntent(),
            phrases: [
                "Summarize the latest \(.applicationName) project",
                "What did \(.applicationName) capture last",
                "Show my latest \(.applicationName) bracket summary",
            ],
            shortTitle: "Latest Project",
            systemImageName: "doc.text.magnifyingglass"
        )
        AppShortcut(
            intent: ExportLatestBracketProjectBundleIntent(),
            phrases: [
                "Export my latest \(.applicationName) project",
                "Export the latest \(.applicationName) bracket bundle",
                "Create a \(.applicationName) project bundle",
            ],
            shortTitle: "Export Project",
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: ExportBracketProjectBundleIntent(),
            phrases: [
                "Export a \(.applicationName) project",
                "Export a selected \(.applicationName) project",
                "Create a selected \(.applicationName) project bundle",
            ],
            shortTitle: "Export Selected",
            systemImageName: "doc.badge.arrow.up"
        )
        AppShortcut(
            intent: ImportBracketProjectBundleIntent(),
            phrases: [
                "Import a \(.applicationName) project",
                "Restore a \(.applicationName) bracket bundle",
                "Import a \(.applicationName) project bundle",
            ],
            shortTitle: "Import Project",
            systemImageName: "square.and.arrow.down"
        )
        AppShortcut(
            intent: PreviewBracketerPhysicalProofSubmissionIntent(),
            phrases: [
                "Preview a \(.applicationName) physical proof submission",
                "Check a \(.applicationName) proof submission",
                "Validate a \(.applicationName) physical proof file",
            ],
            shortTitle: "Preview Proof",
            systemImageName: "doc.text.magnifyingglass"
        )
        AppShortcut(
            intent: ExportBracketerPhysicalResultBundleCommandPlanIntent(),
            phrases: [
                "Export a \(.applicationName) physical command plan",
                "Create a \(.applicationName) physical result bundle command plan",
                "Export \(.applicationName) result bundle commands",
            ],
            shortTitle: "Command Plan",
            systemImageName: "terminal"
        )
        AppShortcut(
            intent: ExportBracketerPhysicalProofTemplateIntent(),
            phrases: [
                "Export a \(.applicationName) physical proof template",
                "Create a \(.applicationName) physical proof template",
                "Make a \(.applicationName) proof template from xcresult summary",
            ],
            shortTitle: "Proof Template",
            systemImageName: "doc.badge.plus"
        )
        AppShortcut(
            intent: ExportBracketerPhysicalLabWorkspaceIntent(),
            phrases: [
                "Export a \(.applicationName) physical lab workspace",
                "Create a \(.applicationName) physical proof workspace",
                "Bundle a \(.applicationName) runbook command plan and proof template",
            ],
            shortTitle: "Lab Workspace",
            systemImageName: "folder.badge.gearshape"
        )
        AppShortcut(
            intent: QueryBracketProjectsIntent(),
            phrases: [
                "Search \(.applicationName) projects",
                "Find my \(.applicationName) bracket projects",
                "Query \(.applicationName) project library",
            ],
            shortTitle: "Search Projects",
            systemImageName: "line.3.horizontal.decrease.circle"
        )
    }
}
