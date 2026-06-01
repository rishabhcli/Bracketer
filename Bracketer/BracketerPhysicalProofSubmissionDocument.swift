import Foundation
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

enum BracketerPhysicalProofSubmissionDocumentError: LocalizedError, Equatable, Sendable {
    case missingRegularFile
    case unreadableUTF8(filename: String)
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .missingRegularFile:
            return "The selected physical proof submission is not a regular file."
        case .unreadableUTF8(let filename):
            return "\(filename) is not a readable UTF-8 Bracketer physical proof submission."
        case .unsupportedSchemaVersion(let version):
            return "Physical proof submission schema \(version) is not supported."
        }
    }
}

struct BracketerPhysicalProofSubmissionDocument: FileDocument, Equatable, Sendable {
    static var readableContentTypes: [UTType] { [.plainText, .json] }
    static var writableContentTypes: [UTType] { [.json] }

    let submission: BracketerPhysicalProofSubmission
    let filename: String

    init(
        submission: BracketerPhysicalProofSubmission,
        filename: String? = nil
    ) throws {
        guard submission.schemaVersion == BracketerPhysicalProofSubmission.schemaVersion else {
            throw BracketerPhysicalProofSubmissionDocumentError.unsupportedSchemaVersion(submission.schemaVersion)
        }
        self.submission = submission
        self.filename = filename ?? Self.filename(for: submission)
    }

    init(
        templateFor runbook: BracketerPhysicalCaptureRunbook
    ) throws {
        try self.init(
            submission: BracketerPhysicalProofSubmission.template(for: runbook),
            filename: "Bracketer-\(runbook.id)-physical-proof-template.json"
        )
    }

    init(
        templateFor runbook: BracketerPhysicalCaptureRunbook,
        proofInput: BracketerPhysicalResultBundleProofInput
    ) throws {
        try self.init(
            submission: BracketerPhysicalProofSubmission.template(
                for: runbook,
                proofInput: proofInput
            ),
            filename: "Bracketer-\(runbook.id)-physical-proof-seeded-template.json"
        )
    }

    init(
        prefillingTemplateFor runbook: BracketerPhysicalCaptureRunbook,
        compactXCResultSummaryJSON: Data,
        attachmentByteCount: Int
    ) throws {
        let proofInput = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
            compactXCResultSummaryJSON,
            attachmentByteCount: attachmentByteCount
        )
        try self.init(
            templateFor: runbook,
            proofInput: proofInput
        )
    }

    init(
        data: Data,
        filename: String = "bracketer-physical-proof-submission.json"
    ) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw BracketerPhysicalProofSubmissionDocumentError.unreadableUTF8(filename: filename)
        }
        try self.init(documentText: text, filename: filename)
    }

    init(
        documentText: String,
        filename: String = "bracketer-physical-proof-submission.json"
    ) throws {
        let data = Data(documentText.utf8)
        let submission = try JSONDecoder().decode(BracketerPhysicalProofSubmission.self, from: data)
        try self.init(submission: submission, filename: filename)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BracketerPhysicalProofSubmissionDocumentError.missingRegularFile
        }
        try self.init(
            data: data,
            filename: configuration.file.preferredFilename ?? "bracketer-physical-proof-submission.json"
        )
    }

    var documentText: String {
        let encoder = JSONEncoder.bracketerPhysicalProofCanonical
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? String(data: encoder.encode(submission), encoding: .utf8))
            ?? "{}"
    }

    var data: Data {
        Data(documentText.utf8)
    }

    var accessibilityValue: String {
        [
            "Bracketer Physical Proof Submission Document",
            filename,
            "Scenario: \(submission.scenarioID)",
            submission.attachmentStatusValue,
            "physical-device-proof preview only",
            "Does not capture or count physical proof by itself"
        ].joined(separator: " | ")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = filename
        return wrapper
    }

    private static func filename(for submission: BracketerPhysicalProofSubmission) -> String {
        "Bracketer-\(submission.scenarioID)-physical-proof-submission.json"
    }
}

struct BracketerPhysicalResultBundleCommandPlanDocument: Equatable, Sendable {
    let plan: BracketerPhysicalResultBundleCommandPlan
    let filename: String

    init(
        plan: BracketerPhysicalResultBundleCommandPlan,
        filename: String? = nil
    ) {
        self.plan = plan
        self.filename = filename ?? "Bracketer-\(plan.scenarioID)-physical-command-plan.txt"
    }

    init(
        runbook: BracketerPhysicalCaptureRunbook,
        resultBundlePath: String? = nil,
        includeMetricsExtraction: Bool = true
    ) throws {
        self.init(
            plan: try BracketerPhysicalResultBundleCommandPlan.make(
                for: runbook,
                resultBundlePath: resultBundlePath,
                includeMetricsExtraction: includeMetricsExtraction
            )
        )
    }

    var documentText: String {
        [
            "# Bracketer Physical Result Bundle Command Plan",
            "",
            "schemaVersion: \(plan.schemaVersion)",
            "scenarioID: \(plan.scenarioID)",
            "resultBundlePath: \(plan.resultBundlePath)",
            "",
            "## Output Artifacts",
            "result-bundle.sha256: \(plan.resultBundleDigestPath)",
            "xcresult-summary.compact.json: \(plan.compactSummaryJSONPath)",
            "xcresult-summary.compact.json.sha256: \(plan.compactSummaryDigestPath)",
            "xcresult-metrics.compact.json: \(plan.compactMetricsJSONPath)",
            "xcodebuild-version.txt: \(plan.xcodebuildVersionPath)",
            "xcresulttool-version.txt: \(plan.xcresulttoolVersionPath)",
            "",
            "## Commands",
            commandText,
            "",
            "## Reviewer Evidence",
            plan.reviewerEvidenceLines.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Boundaries",
            "- \(plan.privacyBoundary)",
            "- \(plan.physicalProofBoundary)",
            "- Copy/share only. Does not execute commands or count physical proof."
        ].joined(separator: "\n")
    }

    var accessibilityValue: String {
        [
            "Physical Result Bundle Command Plan Document",
            filename,
            plan.summaryValue,
            "Copy/share only",
            "Does not execute commands or count physical proof"
        ].joined(separator: " | ")
    }

    private var commandText: String {
        plan.commands.enumerated()
            .map { index, command in
                [
                    "\(index + 1). \(command.title)",
                    "   \(command.invocation)",
                    command.outputPath.map { "   output: \($0)" },
                    "   boundary: \(command.proofBoundary)"
                ]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            }
            .joined(separator: "\n")
    }
}

struct BracketerPhysicalLabWorkspaceDocument: Equatable, Sendable {
    static let schemaVersion = 1
    static let manifestFenceStart = "```json bracketer-physical-lab-workspace-manifest"

    let schemaVersion: Int
    let runbook: BracketerPhysicalCaptureRunbook
    let commandPlanDocument: BracketerPhysicalResultBundleCommandPlanDocument
    let proofTemplateDocument: BracketerPhysicalProofSubmissionDocument
    let requiredPhysicalScenarioCount: Int
    let filename: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        runbook: BracketerPhysicalCaptureRunbook,
        resultBundlePath: String? = nil,
        includeMetricsExtraction: Bool = true,
        compactXCResultSummaryJSON: Data,
        attachmentByteCount: Int,
        requiredPhysicalScenarioCount: Int = BracketerPhysicalCaptureRunbookCatalog.make().requiredRunbookCount
    ) throws {
        self.schemaVersion = schemaVersion
        self.runbook = runbook
        self.commandPlanDocument = try BracketerPhysicalResultBundleCommandPlanDocument(
            runbook: runbook,
            resultBundlePath: resultBundlePath,
            includeMetricsExtraction: includeMetricsExtraction
        )
        self.proofTemplateDocument = try BracketerPhysicalProofSubmissionDocument(
            prefillingTemplateFor: runbook,
            compactXCResultSummaryJSON: compactXCResultSummaryJSON,
            attachmentByteCount: attachmentByteCount
        )
        self.requiredPhysicalScenarioCount = requiredPhysicalScenarioCount
        self.filename = "Bracketer-\(runbook.id)-physical-lab-workspace.md"
    }

    var documentText: String {
        [
            "# Bracketer Physical Lab Workspace",
            "",
            "schemaVersion: \(schemaVersion)",
            "scenarioID: \(runbook.id)",
            "scenarioTitle: \(runbook.scenarioTitle)",
            "physicalProofStatus: \(physicalProofStatus)",
            "resultBundlePath: \(commandPlanDocument.plan.resultBundlePath)",
            "commandPlanFilename: \(commandPlanDocument.filename)",
            "seededTemplateFilename: \(proofTemplateDocument.filename)",
            "",
            "## Workspace Manifest",
            Self.manifestFenceStart,
            manifestJSONText,
            "```",
            "",
            "## Expected Artifacts",
            expectedArtifactText,
            "",
            "## Output Paths",
            outputPathText,
            "",
            "## Preparation",
            runbook.preparationSteps.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Capture",
            runbook.captureSteps.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Evidence",
            runbook.evidenceSteps.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Command Plan",
            commandPlanDocument.documentText,
            "",
            "## Seeded Physical Proof Template",
            "```json",
            proofTemplateDocument.documentText,
            "```",
            "",
            "## Boundaries",
            "- \(runbook.privacyBoundary)",
            "- \(commandPlanDocument.plan.physicalProofBoundary)",
            "- Preview template keeps real hashes, device identifiers, reviewer-run evidence, and per-artifact hashes as placeholders.",
            "- Preview template keeps per-artifact byte counts at zero; parsed attachment totals remain only in result-bundle metrics.",
            "- Workspace export is copy/share only. It does not execute commands, authenticate a device, inspect Photos assets, or count physical proof."
        ].joined(separator: "\n")
    }

    var data: Data {
        Data(documentText.utf8)
    }

    var accessibilityValue: String {
        [
            "Bracketer Physical Lab Workspace",
            filename,
            "Scenario: \(runbook.scenarioTitle)",
            "physicalProofStatus: \(physicalProofStatus)",
            "Expected artifacts: \(runbook.expectedArtifacts.joined(separator: ", "))",
            "Command plan: \(commandPlanDocument.filename)",
            "Seeded template: \(proofTemplateDocument.filename)",
            "Copy/share only",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var physicalProofStatusValue: String {
        physicalProofStatus
    }

    var manifest: BracketerPhysicalLabWorkspaceManifest {
        let plan = commandPlanDocument.plan
        return BracketerPhysicalLabWorkspaceManifest(
            scenarioID: runbook.id,
            scenarioTitle: runbook.scenarioTitle,
            physicalProofStatus: physicalProofStatus,
            resultBundlePath: plan.resultBundlePath,
            commandPlanFilename: commandPlanDocument.filename,
            seededTemplateFilename: proofTemplateDocument.filename,
            expectedArtifacts: runbook.expectedArtifacts,
            outputArtifactPaths: outputArtifactPaths,
            commandCount: plan.commands.count,
            includesMetricsExtractionCommand: plan.commands.contains { $0.step == .extractCompactMetricsJSON },
            requiredPhysicalScenarioCount: requiredPhysicalScenarioCount,
            privacyBoundary: runbook.privacyBoundary,
            noPhysicalProofBoundary: "Workspace export is copy/share only. It does not execute commands, authenticate a device, inspect Photos assets, or count physical proof."
        )
    }

    static func decodeManifest(from documentText: String) throws -> BracketerPhysicalLabWorkspaceManifest {
        guard let fenceStartRange = documentText.range(of: "\(Self.manifestFenceStart)\n") else {
            throw BracketerPhysicalLabWorkspaceReviewError.missingManifest
        }
        let manifestAndRemainder = documentText[fenceStartRange.upperBound...]
        guard let fenceEndRange = manifestAndRemainder.range(of: "\n```") else {
            throw BracketerPhysicalLabWorkspaceReviewError.missingManifest
        }
        let manifestText = String(manifestAndRemainder[..<fenceEndRange.lowerBound])
        guard let data = manifestText.data(using: .utf8) else {
            throw BracketerPhysicalLabWorkspaceReviewError.unreadableManifest
        }
        do {
            let manifest = try JSONDecoder().decode(BracketerPhysicalLabWorkspaceManifest.self, from: data)
            guard manifest.schemaVersion == BracketerPhysicalLabWorkspaceManifest.schemaVersion else {
                throw BracketerPhysicalLabWorkspaceReviewError.unsupportedSchemaVersion(manifest.schemaVersion)
            }
            return manifest
        } catch let error as BracketerPhysicalLabWorkspaceReviewError {
            throw error
        } catch {
            throw BracketerPhysicalLabWorkspaceReviewError.unreadableManifest
        }
    }

    private var expectedArtifactText: String {
        runbook.expectedArtifacts.map { "- \($0)" }.joined(separator: "\n")
    }

    private var outputPathText: String {
        outputArtifactPaths
            .keys
            .sorted()
            .map { artifactID in "- \(artifactID): \(outputArtifactPaths[artifactID] ?? "")" }
            .joined(separator: "\n")
    }

    private var outputArtifactPaths: [String: String] {
        [
            "result-bundle.sha256": commandPlanDocument.plan.resultBundleDigestPath,
            "seeded-template.json": proofTemplateDocument.filename,
            "xcresult-metrics.compact.json": commandPlanDocument.plan.compactMetricsJSONPath,
            "xcresult-summary.compact.json": commandPlanDocument.plan.compactSummaryJSONPath,
            "xcresult-summary.compact.json.sha256": commandPlanDocument.plan.compactSummaryDigestPath,
            "xcresulttool-version.txt": commandPlanDocument.plan.xcresulttoolVersionPath,
            "xcodebuild-version.txt": commandPlanDocument.plan.xcodebuildVersionPath
        ]
    }

    private var manifestJSONText: String {
        let encoder = JSONEncoder.bracketerPhysicalProofCanonical
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? String(data: encoder.encode(manifest), encoding: .utf8)) ?? "{}"
    }

    private var physicalProofStatus: String {
        if runbook.recordedProofs.isEmpty {
            return "no physical proof captured; workspace export keeps physical proof count at 0 of \(requiredPhysicalScenarioCount); recordedProofEntries=0"
        }
        return "\(runbook.recordedProofs.count) recorded proof entries already present; workspace export adds 0 physical proofs"
    }
}

struct BracketerPhysicalLabReviewHandoffPackageFile: Equatable, Sendable, Identifiable {
    let kind: String
    let filename: String
    let contents: String

    var id: String { "\(kind)-\(filename)" }

    var byteCount: Int {
        Data(contents.utf8).count
    }

    var sha256Hex: String {
        Self.sha256Hex(Data(contents.utf8))
    }

    var archiveBlock: String {
        [
            "----- BEGIN \(filename) -----",
            "Kind: \(kind)",
            "Bytes: \(byteCount)",
            "SHA-256: \(sha256Hex)",
            "",
            contents,
            "----- END \(filename) -----"
        ].joined(separator: "\n")
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

struct BracketerPhysicalLabReviewHandoffPackage: Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let workspaceDocument: BracketerPhysicalLabWorkspaceDocument
    let filename: String
    let manifestFilename: String
    let payloadFiles: [BracketerPhysicalLabReviewHandoffPackageFile]
    let files: [BracketerPhysicalLabReviewHandoffPackageFile]

    init(
        schemaVersion: Int = Self.schemaVersion,
        workspaceDocument: BracketerPhysicalLabWorkspaceDocument
    ) {
        self.schemaVersion = schemaVersion
        self.workspaceDocument = workspaceDocument
        self.filename = "Bracketer-\(workspaceDocument.runbook.id)-physical-lab-review-handoff.txt"
        let manifestFilename = "Bracketer-\(workspaceDocument.runbook.id)-physical-package-manifest.json"
        self.manifestFilename = manifestFilename
        let payloadFiles = Self.makePayloadFiles(workspaceDocument: workspaceDocument)
        let manifestFile = BracketerPhysicalLabReviewHandoffPackageFile(
            kind: "package-manifest",
            filename: manifestFilename,
            contents: Self.manifestJSON(
                schemaVersion: schemaVersion,
                workspaceDocument: workspaceDocument,
                payloads: payloadFiles
            )
        )
        self.payloadFiles = payloadFiles
        self.files = [manifestFile] + payloadFiles
    }

    var documentText: String {
        [
            "# Bracketer Physical Lab Review Handoff Package",
            "",
            "schemaVersion: \(schemaVersion)",
            "scenarioID: \(workspaceDocument.runbook.id)",
            "scenarioTitle: \(workspaceDocument.runbook.scenarioTitle)",
            "physicalProofStatus: \(workspaceDocument.physicalProofStatusValue)",
            "payloadCount: \(payloadFiles.count)",
            "manifestFilename: \(manifestFilename)",
            "packageBoundary: Copy/share only. Does not execute commands or count physical proof.",
            "",
            files.map(\.archiveBlock).joined(separator: "\n\n")
        ].joined(separator: "\n")
    }

    var data: Data {
        Data(documentText.utf8)
    }

    var accessibilityValue: String {
        [
            "Bracketer Physical Lab Review Handoff Package",
            filename,
            "Scenario: \(workspaceDocument.runbook.scenarioTitle)",
            "physicalProofStatus: \(workspaceDocument.physicalProofStatusValue)",
            "Manifest: \(manifestFilename)",
            "Payload files: \(payloadFiles.count)",
            "Copy/share only",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var filenames: [String] {
        files.map(\.filename)
    }

    private static func makePayloadFiles(
        workspaceDocument: BracketerPhysicalLabWorkspaceDocument
    ) -> [BracketerPhysicalLabReviewHandoffPackageFile] {
        let scenarioID = workspaceDocument.runbook.id
        return [
            BracketerPhysicalLabReviewHandoffPackageFile(
                kind: "lab-workspace",
                filename: workspaceDocument.filename,
                contents: workspaceDocument.documentText
            ),
            BracketerPhysicalLabReviewHandoffPackageFile(
                kind: "command-plan",
                filename: workspaceDocument.commandPlanDocument.filename,
                contents: workspaceDocument.commandPlanDocument.documentText
            ),
            BracketerPhysicalLabReviewHandoffPackageFile(
                kind: "seeded-proof-template",
                filename: workspaceDocument.proofTemplateDocument.filename,
                contents: workspaceDocument.proofTemplateDocument.documentText
            ),
            BracketerPhysicalLabReviewHandoffPackageFile(
                kind: "output-paths",
                filename: "Bracketer-\(scenarioID)-physical-output-paths.md",
                contents: outputPathsDocumentText(workspaceDocument: workspaceDocument)
            ),
            BracketerPhysicalLabReviewHandoffPackageFile(
                kind: "reviewer-checklist",
                filename: "Bracketer-\(scenarioID)-physical-reviewer-checklist.md",
                contents: reviewerChecklistDocumentText(workspaceDocument: workspaceDocument)
            )
        ]
    }

    private static func outputPathsDocumentText(
        workspaceDocument: BracketerPhysicalLabWorkspaceDocument
    ) -> String {
        let plan = workspaceDocument.commandPlanDocument.plan
        return [
            "# Bracketer Physical Output Paths",
            "",
            "scenarioID: \(workspaceDocument.runbook.id)",
            "resultBundlePath: \(plan.resultBundlePath)",
            "",
            "- result-bundle.sha256: \(plan.resultBundleDigestPath)",
            "- xcresult-summary.compact.json: \(plan.compactSummaryJSONPath)",
            "- xcresult-summary.compact.json.sha256: \(plan.compactSummaryDigestPath)",
            "- xcresult-metrics.compact.json: \(plan.compactMetricsJSONPath)",
            "- xcodebuild-version.txt: \(plan.xcodebuildVersionPath)",
            "- xcresulttool-version.txt: \(plan.xcresulttoolVersionPath)",
            "- seeded-template.json: \(workspaceDocument.proofTemplateDocument.filename)",
            "",
            "Boundary: Copy/share only. Bracketer does not execute commands or count physical proof from this package."
        ].joined(separator: "\n")
    }

    private static func reviewerChecklistDocumentText(
        workspaceDocument: BracketerPhysicalLabWorkspaceDocument
    ) -> String {
        [
            "# Bracketer Physical Reviewer Checklist",
            "",
            "scenarioID: \(workspaceDocument.runbook.id)",
            "physicalProofStatus: \(workspaceDocument.physicalProofStatusValue)",
            "",
            "- [ ] Confirm the result bundle was produced from a physical iPhone, not a simulator.",
            "- [ ] Run the command-plan digest and compact-summary commands exactly once for the selected scenario.",
            "- [ ] Replace every seeded proof-template placeholder with signed lab evidence.",
            "- [ ] Confirm each expected artifact exists before ingesting the proof submission.",
            "- [ ] Keep Photos identifiers, raw image bytes, and precise coordinates out of the handoff.",
            "- [ ] Import only after the reviewer evidence echoes result-bundle, device, timing, metrics, and artifact tokens.",
            "",
            "Boundary: Copy/share only. This checklist does not authenticate a device or increment the 0 of \(workspaceDocument.requiredPhysicalScenarioCount) physical proof count."
        ].joined(separator: "\n")
    }

    private static func manifestJSON(
        schemaVersion: Int,
        workspaceDocument: BracketerPhysicalLabWorkspaceDocument,
        payloads: [BracketerPhysicalLabReviewHandoffPackageFile]
    ) -> String {
        let manifest = BracketerPhysicalLabReviewHandoffPackageManifest(
            schemaVersion: schemaVersion,
            scenarioID: workspaceDocument.runbook.id,
            scenarioTitle: workspaceDocument.runbook.scenarioTitle,
            physicalProofStatus: workspaceDocument.physicalProofStatusValue,
            payloadCount: payloads.count,
            privacyBoundary: workspaceDocument.runbook.privacyBoundary,
            proofBoundary: workspaceDocument.commandPlanDocument.plan.physicalProofBoundary,
            packageBoundary: "Copy/share only. Does not execute commands or count physical proof.",
            payloads: payloads.map {
                BracketerPhysicalLabReviewHandoffPackageManifestPayload(
                    kind: $0.kind,
                    filename: $0.filename,
                    byteCount: $0.byteCount,
                    sha256Hex: $0.sha256Hex
                )
            }
        )
        let encoder = JSONEncoder.bracketerPhysicalProofCanonical
        return (try? String(data: encoder.encode(manifest), encoding: .utf8)) ?? "{}"
    }
}

struct BracketerPhysicalLabReviewHandoffPackageManifestPayload: Codable, Equatable, Sendable {
    let kind: String
    let filename: String
    let byteCount: Int
    let sha256Hex: String
}

struct BracketerPhysicalLabReviewHandoffPackageManifest: Codable, Equatable, Sendable {
    static let schemaVersion = BracketerPhysicalLabReviewHandoffPackage.schemaVersion

    let schemaVersion: Int
    let scenarioID: String
    let scenarioTitle: String
    let physicalProofStatus: String
    let payloadCount: Int
    let privacyBoundary: String
    let proofBoundary: String
    let packageBoundary: String
    let payloads: [BracketerPhysicalLabReviewHandoffPackageManifestPayload]
}

struct BracketerPhysicalLabReviewHandoffPackageArchiveBlock: Equatable, Sendable {
    let kind: String
    let filename: String
    let byteCount: Int
    let sha256Hex: String
    let contents: String

    var actualByteCount: Int {
        Data(contents.utf8).count
    }

    var actualSHA256Hex: String {
        SHA256.hash(data: Data(contents.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

enum BracketerPhysicalLabReviewHandoffPackageReviewError: Error, Equatable, Sendable, CustomStringConvertible {
    case unreadableArchive
    case missingPackageBoundary
    case missingManifestBlock
    case unreadableManifest
    case malformedArchiveBlock(String)
    case duplicateFilename(String)
    case byteCountMismatch(filename: String, expected: Int, actual: Int)
    case sha256Mismatch(filename: String)
    case payloadInventoryMismatch(expected: [String], actual: [String])
    case unsupportedSchemaVersion(Int)
    case embeddedWorkspacePreviewFailed(String)
    case workspaceScenarioMismatch(package: String, workspace: String)

    var description: String {
        switch self {
        case .unreadableArchive:
            return "Physical lab review handoff package is not readable UTF-8 archive text."
        case .missingPackageBoundary:
            return "Physical lab review handoff package must preserve the copy/share-only no-execution boundary."
        case .missingManifestBlock:
            return "Physical lab review handoff package is missing its package-manifest payload."
        case .unreadableManifest:
            return "Physical lab review handoff package manifest is not readable JSON."
        case .malformedArchiveBlock(let filename):
            return "Physical lab review handoff package archive block is malformed: \(filename)."
        case .duplicateFilename(let filename):
            return "Physical lab review handoff package contains duplicate payload filename: \(filename)."
        case .byteCountMismatch(let filename, let expected, let actual):
            return "Physical lab review handoff package byte count mismatch for \(filename): expected \(expected), got \(actual)."
        case .sha256Mismatch(let filename):
            return "Physical lab review handoff package SHA-256 mismatch for \(filename)."
        case .payloadInventoryMismatch(let expected, let actual):
            return "Physical lab review handoff package payload inventory mismatch. Expected \(expected.joined(separator: ", ")), got \(actual.joined(separator: ", "))."
        case .unsupportedSchemaVersion(let version):
            return "Physical lab review handoff package schema \(version) is not supported."
        case .embeddedWorkspacePreviewFailed(let reason):
            return "Embedded physical lab workspace preview failed: \(reason)"
        case .workspaceScenarioMismatch(let package, let workspace):
            return "Physical lab review handoff package scenario \(package) does not match embedded workspace scenario \(workspace)."
        }
    }
}

struct BracketerPhysicalLabReviewHandoffPackageReviewChecklist: Equatable, Sendable {
    let manifest: BracketerPhysicalLabReviewHandoffPackageManifest
    let payloadKinds: [String]
    let checklistItems: [String]
    let proofCategory: String

    var summaryValue: String {
        [
            "Physical Lab Review Handoff Package Preview",
            "scenario=\(manifest.scenarioID)",
            "\(payloadKinds.count) payloads",
            "\(checklistItems.count) checklist items",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            manifest.physicalProofStatus,
            "Payload kinds: \(payloadKinds.joined(separator: ", "))",
            manifest.packageBoundary,
            "Proof category: \(proofCategory)"
        ].joined(separator: " | ")
    }

    static func make(
        manifest: BracketerPhysicalLabReviewHandoffPackageManifest,
        payloadBlocks: [BracketerPhysicalLabReviewHandoffPackageArchiveBlock],
        workspacePreview: BracketerPhysicalLabWorkspaceReviewPreview
    ) -> BracketerPhysicalLabReviewHandoffPackageReviewChecklist {
        let payloadKinds = payloadBlocks.map(\.kind).sorted()
        let checklistItems = [
            "Package manifest decoded for \(manifest.scenarioTitle)",
            "Payload inventory matches package manifest",
            "Payload byte counts match archive blocks",
            "Payload SHA-256 digests match archive blocks",
            "Embedded workspace preview passed: \(workspacePreview.checklist.summaryValue)",
            "No physical proof captured by package preview"
        ]
        return BracketerPhysicalLabReviewHandoffPackageReviewChecklist(
            manifest: manifest,
            payloadKinds: payloadKinds,
            checklistItems: checklistItems,
            proofCategory: "pure-model-proof"
        )
    }
}

struct BracketerPhysicalLabReviewHandoffPackageReviewPreview: Equatable, Sendable {
    let filename: String
    let manifest: BracketerPhysicalLabReviewHandoffPackageManifest
    let workspacePreview: BracketerPhysicalLabWorkspaceReviewPreview
    let checklist: BracketerPhysicalLabReviewHandoffPackageReviewChecklist

    var dialogText: String {
        [
            "physical-lab-review-handoff preview only",
            checklist.summaryValue,
            manifest.physicalProofStatus,
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            filename,
            checklist.accessibilityValue,
            "Embedded workspace: \(workspacePreview.accessibilityValue)",
            "Import preview does not mutate runbooks or result-bundle indexes"
        ].joined(separator: " | ")
    }
}

struct BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider {
    private static let requiredPayloadKinds = [
        "command-plan",
        "lab-workspace",
        "output-paths",
        "reviewer-checklist",
        "seeded-proof-template"
    ]

    func previewData(
        _ data: Data,
        filename: String = "bracketer-physical-lab-review-handoff.txt",
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make()
    ) throws -> BracketerPhysicalLabReviewHandoffPackageReviewPreview {
        guard let documentText = String(data: data, encoding: .utf8) else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.unreadableArchive
        }
        let manifestFilename = try manifestFilename(in: documentText)
        try validatePackageBoundary(in: documentText)
        let blocks = try parseArchiveBlocks(from: documentText)
        try validateUniqueFilenames(blocks)
        for block in blocks {
            try validateDigestAndByteCount(block)
        }
        guard let manifestBlock = blocks.first(where: {
            $0.filename == manifestFilename && $0.kind == "package-manifest"
        }) else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.missingManifestBlock
        }
        let manifest = try decodeManifest(from: manifestBlock.contents)
        let payloadBlocks = blocks.filter { $0.filename != manifestBlock.filename }
        try validatePayloadInventory(manifest: manifest, payloadBlocks: payloadBlocks)
        guard boundaryIsPreserved(manifest.packageBoundary) else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.missingPackageBoundary
        }
        guard let workspaceBlock = payloadBlocks.first(where: { $0.kind == "lab-workspace" }) else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.payloadInventoryMismatch(
                expected: Self.requiredPayloadKinds,
                actual: payloadBlocks.map(\.kind).sorted()
            )
        }
        let workspacePreview: BracketerPhysicalLabWorkspaceReviewPreview
        do {
            workspacePreview = try BracketerPhysicalLabWorkspaceReviewPreviewProvider().previewData(
                Data(workspaceBlock.contents.utf8),
                filename: workspaceBlock.filename,
                catalog: catalog
            )
        } catch let error as BracketerPhysicalLabWorkspaceReviewError {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.embeddedWorkspacePreviewFailed(error.description)
        } catch {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.embeddedWorkspacePreviewFailed(error.localizedDescription)
        }
        let workspaceScenarioID = workspacePreview.checklist.manifest.scenarioID
        guard workspaceScenarioID == manifest.scenarioID else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.workspaceScenarioMismatch(
                package: manifest.scenarioID,
                workspace: workspaceScenarioID
            )
        }
        let checklist = BracketerPhysicalLabReviewHandoffPackageReviewChecklist.make(
            manifest: manifest,
            payloadBlocks: payloadBlocks,
            workspacePreview: workspacePreview
        )
        return BracketerPhysicalLabReviewHandoffPackageReviewPreview(
            filename: filename,
            manifest: manifest,
            workspacePreview: workspacePreview,
            checklist: checklist
        )
    }

    private func manifestFilename(in documentText: String) throws -> String {
        guard let value = headerValue(named: "manifestFilename", in: documentText),
              !value.isEmpty else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.missingManifestBlock
        }
        return value
    }

    private func validatePackageBoundary(in documentText: String) throws {
        guard let boundary = headerValue(named: "packageBoundary", in: documentText),
              boundaryIsPreserved(boundary) else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.missingPackageBoundary
        }
    }

    private func headerValue(named name: String, in documentText: String) -> String? {
        let prefix = "\(name): "
        return documentText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .lazy
            .map(String.init)
            .prefix { !$0.hasPrefix("----- BEGIN ") }
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func parseArchiveBlocks(
        from documentText: String
    ) throws -> [BracketerPhysicalLabReviewHandoffPackageArchiveBlock] {
        let lines = documentText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var blocks: [BracketerPhysicalLabReviewHandoffPackageArchiveBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard line.hasPrefix("----- BEGIN ") else {
                index += 1
                continue
            }
            guard line.hasSuffix(" -----") else {
                throw BracketerPhysicalLabReviewHandoffPackageReviewError.malformedArchiveBlock(line)
            }
            let filename = String(line.dropFirst("----- BEGIN ".count).dropLast(" -----".count))
            guard index + 4 < lines.count,
                  lines[index + 1].hasPrefix("Kind: "),
                  lines[index + 2].hasPrefix("Bytes: "),
                  lines[index + 3].hasPrefix("SHA-256: "),
                  lines[index + 4].isEmpty else {
                throw BracketerPhysicalLabReviewHandoffPackageReviewError.malformedArchiveBlock(filename)
            }
            let kind = String(lines[index + 1].dropFirst("Kind: ".count))
            guard let byteCount = Int(lines[index + 2].dropFirst("Bytes: ".count)) else {
                throw BracketerPhysicalLabReviewHandoffPackageReviewError.malformedArchiveBlock(filename)
            }
            let sha256Hex = String(lines[index + 3].dropFirst("SHA-256: ".count))
            let endLine = "----- END \(filename) -----"
            var endIndex = index + 5
            while endIndex < lines.count && lines[endIndex] != endLine {
                endIndex += 1
            }
            guard endIndex < lines.count else {
                throw BracketerPhysicalLabReviewHandoffPackageReviewError.malformedArchiveBlock(filename)
            }
            let contents = lines[(index + 5)..<endIndex].joined(separator: "\n")
            blocks.append(BracketerPhysicalLabReviewHandoffPackageArchiveBlock(
                kind: kind,
                filename: filename,
                byteCount: byteCount,
                sha256Hex: sha256Hex,
                contents: contents
            ))
            index = endIndex + 1
        }
        guard !blocks.isEmpty else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.unreadableArchive
        }
        return blocks
    }

    private func validateUniqueFilenames(
        _ blocks: [BracketerPhysicalLabReviewHandoffPackageArchiveBlock]
    ) throws {
        var seen: Set<String> = []
        for block in blocks {
            guard seen.insert(block.filename).inserted else {
                throw BracketerPhysicalLabReviewHandoffPackageReviewError.duplicateFilename(block.filename)
            }
        }
    }

    private func validateDigestAndByteCount(
        _ block: BracketerPhysicalLabReviewHandoffPackageArchiveBlock
    ) throws {
        guard block.byteCount == block.actualByteCount else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.byteCountMismatch(
                filename: block.filename,
                expected: block.byteCount,
                actual: block.actualByteCount
            )
        }
        guard block.sha256Hex == block.actualSHA256Hex else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.sha256Mismatch(filename: block.filename)
        }
    }

    private func decodeManifest(
        from manifestText: String
    ) throws -> BracketerPhysicalLabReviewHandoffPackageManifest {
        guard let data = manifestText.data(using: .utf8),
              let manifest = try? JSONDecoder().decode(
                BracketerPhysicalLabReviewHandoffPackageManifest.self,
                from: data
              ) else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.unreadableManifest
        }
        guard manifest.schemaVersion == BracketerPhysicalLabReviewHandoffPackageManifest.schemaVersion else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        return manifest
    }

    private func validatePayloadInventory(
        manifest: BracketerPhysicalLabReviewHandoffPackageManifest,
        payloadBlocks: [BracketerPhysicalLabReviewHandoffPackageArchiveBlock]
    ) throws {
        let expectedFilenames = manifest.payloads.map(\.filename).sorted()
        let actualFilenames = payloadBlocks.map(\.filename).sorted()
        guard manifest.payloadCount == manifest.payloads.count,
              expectedFilenames == actualFilenames else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.payloadInventoryMismatch(
                expected: expectedFilenames,
                actual: actualFilenames
            )
        }
        let expectedKinds = Self.requiredPayloadKinds
        let actualKinds = payloadBlocks.map(\.kind).sorted()
        guard expectedKinds == actualKinds else {
            throw BracketerPhysicalLabReviewHandoffPackageReviewError.payloadInventoryMismatch(
                expected: expectedKinds,
                actual: actualKinds
            )
        }
        for payload in manifest.payloads {
            guard let block = payloadBlocks.first(where: { $0.filename == payload.filename }),
                  block.kind == payload.kind,
                  block.byteCount == payload.byteCount,
                  block.sha256Hex == payload.sha256Hex else {
                throw BracketerPhysicalLabReviewHandoffPackageReviewError.payloadInventoryMismatch(
                    expected: expectedFilenames,
                    actual: actualFilenames
                )
            }
        }
    }

    private func boundaryIsPreserved(_ boundary: String) -> Bool {
        let lowercasedBoundary = boundary.lowercased()
        return lowercasedBoundary.contains("copy/share only")
            && lowercasedBoundary.contains("does not execute")
            && lowercasedBoundary.contains("physical proof")
    }
}

struct BracketerPhysicalLabWorkspaceManifest: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let scenarioID: String
    let scenarioTitle: String
    let physicalProofStatus: String
    let resultBundlePath: String
    let commandPlanFilename: String
    let seededTemplateFilename: String
    let expectedArtifacts: [String]
    let outputArtifactPaths: [String: String]
    let commandCount: Int
    let includesMetricsExtractionCommand: Bool
    let requiredPhysicalScenarioCount: Int
    let privacyBoundary: String
    let noPhysicalProofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        scenarioID: String,
        scenarioTitle: String,
        physicalProofStatus: String,
        resultBundlePath: String,
        commandPlanFilename: String,
        seededTemplateFilename: String,
        expectedArtifacts: [String],
        outputArtifactPaths: [String: String],
        commandCount: Int,
        includesMetricsExtractionCommand: Bool,
        requiredPhysicalScenarioCount: Int,
        privacyBoundary: String,
        noPhysicalProofBoundary: String
    ) {
        self.schemaVersion = schemaVersion
        self.scenarioID = scenarioID
        self.scenarioTitle = scenarioTitle
        self.physicalProofStatus = physicalProofStatus
        self.resultBundlePath = resultBundlePath
        self.commandPlanFilename = commandPlanFilename
        self.seededTemplateFilename = seededTemplateFilename
        self.expectedArtifacts = expectedArtifacts
        self.outputArtifactPaths = outputArtifactPaths
        self.commandCount = commandCount
        self.includesMetricsExtractionCommand = includesMetricsExtractionCommand
        self.requiredPhysicalScenarioCount = requiredPhysicalScenarioCount
        self.privacyBoundary = privacyBoundary
        self.noPhysicalProofBoundary = noPhysicalProofBoundary
    }
}

enum BracketerPhysicalLabWorkspaceReviewError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingManifest
    case unreadableManifest
    case unsupportedSchemaVersion(Int)
    case runbookNotFound(String)
    case expectedArtifactMismatch(expected: [String], actual: [String])
    case missingNoPhysicalProofBoundary
    case missingRequiredOutputArtifacts([String])

    var description: String {
        switch self {
        case .missingManifest:
            return "Physical lab workspace preview requires an embedded workspace manifest."
        case .unreadableManifest:
            return "Physical lab workspace manifest could not be decoded."
        case .unsupportedSchemaVersion(let version):
            return "Physical lab workspace manifest schema \(version) is not supported."
        case .runbookNotFound(let scenarioID):
            return "Physical lab workspace scenario \(scenarioID) is not present in the current runbook catalog."
        case .expectedArtifactMismatch(let expected, let actual):
            return "Physical lab workspace expected artifacts mismatch. Expected \(expected.joined(separator: ", ")), got \(actual.joined(separator: ", "))."
        case .missingNoPhysicalProofBoundary:
            return "Physical lab workspace manifest must preserve the no-physical-proof boundary."
        case .missingRequiredOutputArtifacts(let artifacts):
            return "Physical lab workspace manifest is missing output artifact paths: \(artifacts.joined(separator: ", "))."
        }
    }
}

struct BracketerPhysicalLabWorkspaceReviewChecklist: Equatable, Sendable {
    let manifest: BracketerPhysicalLabWorkspaceManifest
    let checklistItems: [String]
    let proofCategory: String

    var summaryValue: String {
        [
            "Physical Lab Workspace Preview",
            "scenario=\(manifest.scenarioID)",
            "\(checklistItems.count) checklist items",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            manifest.physicalProofStatus,
            "Expected artifacts: \(manifest.expectedArtifacts.joined(separator: ", "))",
            "Output artifacts: \(manifest.outputArtifactPaths.keys.sorted().joined(separator: ", "))",
            manifest.noPhysicalProofBoundary,
            "Proof category: \(proofCategory)"
        ].joined(separator: " | ")
    }

    static func make(
        manifest: BracketerPhysicalLabWorkspaceManifest,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make()
    ) throws -> BracketerPhysicalLabWorkspaceReviewChecklist {
        guard let runbook = catalog.runbooks.first(where: { $0.id == manifest.scenarioID }) else {
            throw BracketerPhysicalLabWorkspaceReviewError.runbookNotFound(manifest.scenarioID)
        }
        guard runbook.expectedArtifacts == manifest.expectedArtifacts else {
            throw BracketerPhysicalLabWorkspaceReviewError.expectedArtifactMismatch(
                expected: runbook.expectedArtifacts,
                actual: manifest.expectedArtifacts
            )
        }
        guard manifest.physicalProofStatus.contains("no physical proof captured"),
              manifest.noPhysicalProofBoundary.contains("does not execute commands") else {
            throw BracketerPhysicalLabWorkspaceReviewError.missingNoPhysicalProofBoundary
        }
        var requiredOutputArtifacts = [
            "result-bundle.sha256",
            "seeded-template.json",
            "xcresult-summary.compact.json",
            "xcresult-summary.compact.json.sha256",
            "xcresulttool-version.txt",
            "xcodebuild-version.txt"
        ]
        if manifest.includesMetricsExtractionCommand {
            requiredOutputArtifacts.append("xcresult-metrics.compact.json")
        }
        let missingOutputArtifacts = requiredOutputArtifacts.filter {
            manifest.outputArtifactPaths[$0]?.isEmpty ?? true
        }
        guard missingOutputArtifacts.isEmpty else {
            throw BracketerPhysicalLabWorkspaceReviewError.missingRequiredOutputArtifacts(missingOutputArtifacts)
        }
        let checklistItems = [
            "Runbook exists: \(runbook.scenarioTitle)",
            "Expected artifact ids match current runbook",
            "Result bundle path: \(manifest.resultBundlePath)",
            "Command plan file: \(manifest.commandPlanFilename)",
            "Seeded template file: \(manifest.seededTemplateFilename)",
            "Output paths present: \(manifest.outputArtifactPaths.keys.sorted().joined(separator: ", "))",
            "No physical proof captured by preview"
        ]
        return BracketerPhysicalLabWorkspaceReviewChecklist(
            manifest: manifest,
            checklistItems: checklistItems,
            proofCategory: "pure-model-proof"
        )
    }
}

struct BracketerPhysicalLabWorkspaceReviewPreview: Equatable, Sendable {
    let filename: String
    let checklist: BracketerPhysicalLabWorkspaceReviewChecklist

    var dialogText: String {
        [
            "physical-lab-workspace preview only",
            checklist.summaryValue,
            checklist.manifest.physicalProofStatus,
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            filename,
            checklist.accessibilityValue,
            "Import preview does not mutate runbooks or result-bundle indexes"
        ].joined(separator: " | ")
    }
}

struct BracketerPhysicalLabWorkspaceReviewPreviewProvider {
    func previewData(
        _ data: Data,
        filename: String = "bracketer-physical-lab-workspace.md",
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make()
    ) throws -> BracketerPhysicalLabWorkspaceReviewPreview {
        guard let documentText = String(data: data, encoding: .utf8) else {
            throw BracketerPhysicalLabWorkspaceReviewError.unreadableManifest
        }
        let manifest = try BracketerPhysicalLabWorkspaceDocument.decodeManifest(from: documentText)
        let checklist = try BracketerPhysicalLabWorkspaceReviewChecklist.make(
            manifest: manifest,
            catalog: catalog
        )
        return BracketerPhysicalLabWorkspaceReviewPreview(
            filename: filename,
            checklist: checklist
        )
    }
}
