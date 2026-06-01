//
//  BracketerPhysicalProofIngestor.swift
//  Bracketer
//
//  Created by Codex on 5/28/26.
//

import Foundation
import CryptoKit

struct BracketerPhysicalResultBundleMetrics: Codable, Equatable, Sendable {
    let totalTestCount: Int
    let passedTests: Int
    let failedTests: Int
    let durationMilliseconds: Int
    let attachmentByteCount: Int

    var summaryValue: String {
        [
            "metrics.totalTestCount=\(totalTestCount)",
            "metrics.passedTests=\(passedTests)",
            "metrics.failedTests=\(failedTests)",
            "metrics.durationMilliseconds=\(durationMilliseconds)",
            "metrics.attachmentByteCount=\(attachmentByteCount)"
        ].joined(separator: ", ")
    }

    var reviewerEvidenceTokens: [String] {
        [
            "metrics.totaltestcount=\(totalTestCount)",
            "metrics.passedtests=\(passedTests)",
            "metrics.failedtests=\(failedTests)",
            "metrics.durationmilliseconds=\(durationMilliseconds)",
            "metrics.attachmentbytecount=\(attachmentByteCount)"
        ]
    }
}

struct BracketerPhysicalResultBundleSummary: Codable, Equatable, Sendable {
    enum Status: String, Codable, Equatable, Sendable {
        case passed = "Passed"
        case failed = "Failed"
        case mixed = "Mixed"
        case skipped = "Skipped"
        case expectedFailure = "ExpectedFailure"
        case unknown = "Unknown"
    }

    let status: Status
    let title: String
    let totalTestCount: Int
    let passedTestCount: Int
    let failedTestCount: Int
    let expectedFailureCount: Int
    let skippedTestCount: Int

    var summaryValue: String {
        [
            "summary.status=\(status.rawValue)",
            "summary.title=\(title)",
            "summary.totalTestCount=\(totalTestCount)",
            "summary.passedTests=\(passedTestCount)",
            "summary.failedTests=\(failedTestCount)",
            "summary.expectedFailures=\(expectedFailureCount)",
            "summary.skippedTests=\(skippedTestCount)"
        ].joined(separator: ", ")
    }

    var reviewerEvidenceTokens: [String] {
        [
            "summary.status=\(status.rawValue.lowercased())",
            "summary.title=\(Self.compactEvidenceValue(title))",
            "summary.totaltestcount=\(totalTestCount)",
            "summary.passedtests=\(passedTestCount)",
            "summary.failedtests=\(failedTestCount)",
            "summary.expectedfailures=\(expectedFailureCount)",
            "summary.skippedtests=\(skippedTestCount)"
        ]
    }

    private static func compactEvidenceValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
    }
}

struct BracketerPhysicalResultBundleTiming: Codable, Equatable, Sendable {
    let summaryStartTime: Date
    let summaryFinishTime: Date
    let testStartTime: Date
    let testFinishTime: Date

    var summaryValue: String {
        [
            "timing.summaryStart=\(Self.timestamp(summaryStartTime))",
            "timing.summaryFinish=\(Self.timestamp(summaryFinishTime))",
            "timing.testStart=\(Self.timestamp(testStartTime))",
            "timing.testFinish=\(Self.timestamp(testFinishTime))"
        ].joined(separator: ", ")
    }

    var reviewerEvidenceTokens: [String] {
        [
            "timing.summarystart=\(Self.timestamp(summaryStartTime).lowercased())",
            "timing.summaryfinish=\(Self.timestamp(summaryFinishTime).lowercased())",
            "timing.teststart=\(Self.timestamp(testStartTime).lowercased())",
            "timing.testfinish=\(Self.timestamp(testFinishTime).lowercased())"
        ]
    }

    static func window(around capturedAt: Date) -> BracketerPhysicalResultBundleTiming {
        BracketerPhysicalResultBundleTiming(
            summaryStartTime: capturedAt.addingTimeInterval(-60),
            summaryFinishTime: capturedAt.addingTimeInterval(60),
            testStartTime: capturedAt.addingTimeInterval(-30),
            testFinishTime: capturedAt.addingTimeInterval(30)
        )
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

enum BracketerPhysicalResultBundleProofInputError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidAttachmentByteCount(Int)
    case invalidXCResultTimeRange(startTime: Double, finishTime: Double)
    case missingTestPlanConfiguration

    var description: String {
        switch self {
            case .invalidAttachmentByteCount(let byteCount):
                return "Physical proof result-bundle attachment byte count \(byteCount) must be greater than 0."
            case .invalidXCResultTimeRange(let startTime, let finishTime):
                return "Physical proof xcresult summary finish time \(finishTime) must be after start time \(startTime)."
            case .missingTestPlanConfiguration:
                return "Physical proof xcresult summary must include a test plan configuration."
        }
    }
}

struct BracketerPhysicalResultBundleProofInput: Codable, Equatable, Sendable {
    let resultBundleSummary: BracketerPhysicalResultBundleSummary
    let resultBundleMetrics: BracketerPhysicalResultBundleMetrics
    let resultBundleTiming: BracketerPhysicalResultBundleTiming
    let testPlanConfigurationName: String
    let environmentDescription: String?
    let deviceName: String?
    let deviceModelName: String?
    let osVersion: String?
    let osBuildNumber: String?
    let platform: String?

    var resultBundleDevice: BracketerPhysicalResultBundleDevice? {
        guard let deviceModelName,
              let platform else {
            return nil
        }
        return BracketerPhysicalResultBundleDevice(
            modelName: deviceModelName,
            osVersion: osVersion,
            osBuildNumber: osBuildNumber,
            platform: platform
        )
    }

    var deviceSummaryValue: String {
        resultBundleDevice?.summaryValue ?? "xcresult.device=unavailable"
    }

    var summaryValue: String {
        [
            "xcresult.title=\(resultBundleSummary.title)",
            "xcresult.result=\(resultBundleSummary.status.rawValue)",
            "xcresult.plan=\(testPlanConfigurationName)",
            environmentDescription.map { "xcresult.environment=\($0)" },
            deviceSummaryValue
        ].compactMap { $0 }.joined(separator: ", ")
    }

    var reviewerEvidenceLines: [String] {
        var lines = [
            "Result bundle summary: \(resultBundleSummary.summaryValue)",
            "Result bundle metrics: \(resultBundleMetrics.summaryValue)",
            "Result bundle timing: \(resultBundleTiming.summaryValue)",
            "Result bundle xcresult: \(summaryValue)"
        ]
        if let resultBundleDevice {
            lines.append("Result bundle device: \(resultBundleDevice.summaryValue)")
        }
        return lines
    }

    static func decodeCompactXCResultSummaryJSON(
        _ data: Data,
        attachmentByteCount: Int
    ) throws -> BracketerPhysicalResultBundleProofInput {
        let decoder = JSONDecoder()
        let summary = try decoder.decode(BracketerPhysicalXCResultTestResultsSummary.self, from: data)
        return try summary.proofInput(attachmentByteCount: attachmentByteCount)
    }

    func testContract(
        xcodebuildVersion: String,
        xcresulttoolVersion: String,
        testIdentifier: String,
        testName: String
    ) -> BracketerPhysicalResultBundleTestContract {
        BracketerPhysicalResultBundleTestContract(
            xcodebuildVersion: xcodebuildVersion,
            xcresulttoolVersion: xcresulttoolVersion,
            testPlanConfigurationName: testPlanConfigurationName,
            testIdentifier: testIdentifier,
            testName: testName
        )
    }
}

enum BracketerPhysicalResultBundleCommandPlanError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyResultBundlePath
    case resultBundlePathNotXCResult(String)
    case unsafeResultBundlePath(String)
    case scenarioBundleNameMismatch(expectedPrefix: String, actual: String)

    var description: String {
        switch self {
            case .emptyResultBundlePath:
                return "Physical proof result-bundle command plan requires a non-empty result-bundle path."
            case .resultBundlePathNotXCResult(let path):
                return "Physical proof result-bundle command plan path must end in .xcresult: \(path)"
            case .unsafeResultBundlePath(let path):
                return "Physical proof result-bundle command plan path contains shell-unsafe characters: \(path)"
            case .scenarioBundleNameMismatch(let expectedPrefix, let actual):
                return "Physical proof result-bundle command plan expected filename prefix \(expectedPrefix), got \(actual)."
        }
    }
}

struct BracketerPhysicalResultBundleCommandPlan: Codable, Equatable, Sendable {
    enum Step: String, Codable, Equatable, Sendable {
        case digestResultBundle
        case extractCompactSummaryJSON
        case digestCompactSummaryJSON
        case extractCompactMetricsJSON
        case captureXcodebuildVersion
        case captureXCResultToolVersion
    }

    struct Command: Codable, Equatable, Identifiable, Sendable {
        let step: Step
        let title: String
        let executable: String
        let arguments: [String]
        let outputPath: String?
        let invocation: String
        let outputArtifactID: String
        let proofBoundary: String

        var id: String {
            step.rawValue
        }

        var accessibilityValue: String {
            [
                title,
                "Step: \(step.rawValue)",
                "Command: \(invocation)",
                outputPath.map { "Output: \($0)" },
                "Artifact: \(outputArtifactID)",
                "Boundary: \(proofBoundary)"
            ]
                .compactMap { $0 }
                .joined(separator: " | ")
        }
    }

    static let schemaVersion = 1

    let schemaVersion: Int
    let scenarioID: String
    let resultBundlePath: String
    let resultBundleDigestPath: String
    let compactSummaryJSONPath: String
    let compactSummaryDigestPath: String
    let compactMetricsJSONPath: String
    let xcodebuildVersionPath: String
    let xcresulttoolVersionPath: String
    let commands: [Command]
    let privacyBoundary: String
    let physicalProofBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        scenarioID: String,
        resultBundlePath: String,
        resultBundleDigestPath: String,
        compactSummaryJSONPath: String,
        compactSummaryDigestPath: String,
        compactMetricsJSONPath: String,
        xcodebuildVersionPath: String,
        xcresulttoolVersionPath: String,
        commands: [Command],
        privacyBoundary: String = "Physical Result Bundle Command Plan stores command text and derived artifact paths only; it does not execute commands or store Photos identifiers, image bytes, thumbnails, decoded RAW data, final rendered output bytes, precise coordinates, or device unique identifiers.",
        physicalProofBoundary: String = "Command plans do not prove physical iPhone capture; they only describe how a real lab runner should produce result-bundle digests, compact xcresult JSON, and tool-version evidence before a signed submission is reviewed."
    ) {
        self.schemaVersion = schemaVersion
        self.scenarioID = scenarioID
        self.resultBundlePath = resultBundlePath
        self.resultBundleDigestPath = resultBundleDigestPath
        self.compactSummaryJSONPath = compactSummaryJSONPath
        self.compactSummaryDigestPath = compactSummaryDigestPath
        self.compactMetricsJSONPath = compactMetricsJSONPath
        self.xcodebuildVersionPath = xcodebuildVersionPath
        self.xcresulttoolVersionPath = xcresulttoolVersionPath
        self.commands = commands
        self.privacyBoundary = privacyBoundary
        self.physicalProofBoundary = physicalProofBoundary
    }

    static func make(
        for runbook: BracketerPhysicalCaptureRunbook,
        resultBundlePath: String? = nil,
        includeMetricsExtraction: Bool = true
    ) throws -> BracketerPhysicalResultBundleCommandPlan {
        let resolvedResultBundlePath = (resultBundlePath ?? runbook.resultBundlePath)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(resultBundlePath: resolvedResultBundlePath, scenarioID: runbook.id)

        let stem = String(resolvedResultBundlePath.dropLast(".xcresult".count))
        let resultBundleDigestPath = "\(resolvedResultBundlePath).sha256"
        let compactSummaryJSONPath = "\(stem)-summary.json"
        let compactSummaryDigestPath = "\(compactSummaryJSONPath).sha256"
        let compactMetricsJSONPath = "\(stem)-metrics.json"
        let xcodebuildVersionPath = "\(stem)-xcodebuild-version.txt"
        let xcresulttoolVersionPath = "\(stem)-xcresulttool-version.txt"
        var commands = [
            command(
                step: .digestResultBundle,
                title: "Digest Result Bundle",
                executable: "/usr/bin/shasum",
                arguments: ["-a", "256", resolvedResultBundlePath],
                outputPath: resultBundleDigestPath,
                outputArtifactID: "result-bundle.sha256",
                proofBoundary: "Hashes an existing .xcresult bundle path; it does not create or validate physical proof."
            ),
            command(
                step: .extractCompactSummaryJSON,
                title: "Extract Compact Result Bundle Summary JSON",
                executable: "/usr/bin/xcrun",
                arguments: ["xcresulttool", "get", "test-results", "summary", "--path", resolvedResultBundlePath, "--compact"],
                outputPath: compactSummaryJSONPath,
                outputArtifactID: "xcresult-summary.compact.json",
                proofBoundary: "Extracts compact XCTest summary JSON from an existing bundle; result must still be parsed and reviewed."
            ),
            command(
                step: .digestCompactSummaryJSON,
                title: "Digest Compact Result Bundle Summary JSON",
                executable: "/usr/bin/shasum",
                arguments: ["-a", "256", compactSummaryJSONPath],
                outputPath: compactSummaryDigestPath,
                outputArtifactID: "xcresult-summary.compact.json.sha256",
                proofBoundary: "Hashes the compact summary JSON; it does not prove the bundle came from a real iPhone."
            )
        ]

        if includeMetricsExtraction {
            commands.append(
                command(
                    step: .extractCompactMetricsJSON,
                    title: "Extract Compact Result Bundle Metrics JSON",
                    executable: "/usr/bin/xcrun",
                    arguments: ["xcresulttool", "get", "test-results", "metrics", "--path", resolvedResultBundlePath, "--compact"],
                    outputPath: compactMetricsJSONPath,
                    outputArtifactID: "xcresult-metrics.compact.json",
                    proofBoundary: "Extracts XCTest metrics from an existing bundle; simulator or missing metrics remain insufficient for physical proof."
                )
            )
        }

        commands.append(contentsOf: [
            command(
                step: .captureXcodebuildVersion,
                title: "Capture xcodebuild Version",
                executable: "/usr/bin/xcodebuild",
                arguments: ["-version"],
                outputPath: xcodebuildVersionPath,
                outputArtifactID: "xcodebuild-version.txt",
                proofBoundary: "Captures tool version text for reviewer evidence; it does not authenticate a device."
            ),
            command(
                step: .captureXCResultToolVersion,
                title: "Capture xcresulttool Version",
                executable: "/usr/bin/xcrun",
                arguments: ["xcresulttool", "version"],
                outputPath: xcresulttoolVersionPath,
                outputArtifactID: "xcresulttool-version.txt",
                proofBoundary: "Captures xcresulttool version text for reviewer evidence; it does not authenticate a device."
            )
        ])

        return BracketerPhysicalResultBundleCommandPlan(
            scenarioID: runbook.id,
            resultBundlePath: resolvedResultBundlePath,
            resultBundleDigestPath: resultBundleDigestPath,
            compactSummaryJSONPath: compactSummaryJSONPath,
            compactSummaryDigestPath: compactSummaryDigestPath,
            compactMetricsJSONPath: compactMetricsJSONPath,
            xcodebuildVersionPath: xcodebuildVersionPath,
            xcresulttoolVersionPath: xcresulttoolVersionPath,
            commands: commands
        )
    }

    var summaryValue: String {
        [
            "Physical Result Bundle Command Plan",
            "scenario=\(scenarioID)",
            "bundle=\(resultBundlePath)",
            "\(commands.count) commands",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    var reviewerEvidenceLines: [String] {
        [
            "Command plan scenario: \(scenarioID)",
            "Command plan result bundle: \(resultBundlePath)",
            "Command plan result-bundle SHA-256 path: \(resultBundleDigestPath)",
            "Command plan compact summary JSON path: \(compactSummaryJSONPath)",
            "Command plan compact summary SHA-256 path: \(compactSummaryDigestPath)",
            "Command plan compact metrics JSON path: \(compactMetricsJSONPath)",
            "Command plan xcodebuild version path: \(xcodebuildVersionPath)",
            "Command plan xcresulttool version path: \(xcresulttoolVersionPath)"
        ] + commands.map { "Command plan step \($0.step.rawValue): \($0.invocation)" }
    }

    var accessibilityValue: String {
        [
            summaryValue,
            "schema v\(schemaVersion)",
            commands.map(\.accessibilityValue).joined(separator: " | "),
            privacyBoundary,
            physicalProofBoundary
        ].joined(separator: " | ")
    }

    static func decodeProofInput(
        compactSummaryJSON: Data,
        attachmentByteCount: Int
    ) throws -> BracketerPhysicalResultBundleProofInput {
        try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
            compactSummaryJSON,
            attachmentByteCount: attachmentByteCount
        )
    }

    private static func validate(resultBundlePath: String, scenarioID: String) throws {
        let trimmedPath = resultBundlePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw BracketerPhysicalResultBundleCommandPlanError.emptyResultBundlePath
        }
        guard trimmedPath.hasSuffix(".xcresult") else {
            throw BracketerPhysicalResultBundleCommandPlanError.resultBundlePathNotXCResult(resultBundlePath)
        }
        guard !containsUnsafeShellCharacter(trimmedPath) else {
            throw BracketerPhysicalResultBundleCommandPlanError.unsafeResultBundlePath(resultBundlePath)
        }
        let expectedPrefix = "Bracketer-\(scenarioID)-physical"
        let filename = trimmedPath.split(separator: "/").last.map(String.init) ?? trimmedPath
        guard filename.hasPrefix(expectedPrefix) else {
            throw BracketerPhysicalResultBundleCommandPlanError.scenarioBundleNameMismatch(
                expectedPrefix: expectedPrefix,
                actual: filename
            )
        }
    }

    private static func command(
        step: Step,
        title: String,
        executable: String,
        arguments: [String],
        outputPath: String,
        outputArtifactID: String,
        proofBoundary: String
    ) -> Command {
        Command(
            step: step,
            title: title,
            executable: executable,
            arguments: arguments,
            outputPath: outputPath,
            invocation: shellLine(executable: executable, arguments: arguments, outputPath: outputPath),
            outputArtifactID: outputArtifactID,
            proofBoundary: proofBoundary
        )
    }

    private static func shellLine(
        executable: String,
        arguments: [String],
        outputPath: String
    ) -> String {
        let prefix = executable.contains("xcrun") || executable.contains("xcodebuild")
            ? "\(developerDirPrefix) "
            : ""
        let body = ([executable] + arguments).map(shellQuote).joined(separator: " ")
        return "\(prefix)\(body) > \(shellQuote(outputPath))"
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value)'"
    }

    private static func containsUnsafeShellCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            switch scalar {
            case ";", "&", "|", "$", "`", "\"", "'", "\n", "\r", "\t", "\\":
                return true
            default:
                return false
            }
        }
    }

    private static var developerDirPrefix: String {
        "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
    }
}

struct BracketerPhysicalResultBundleDevice: Codable, Equatable, Sendable {
    let modelName: String
    let osVersion: String?
    let osBuildNumber: String?
    let platform: String

    var summaryValue: String {
        [
            "xcresult.model=\(modelName)",
            osVersion.map { "xcresult.osVersion=\($0)" },
            osBuildNumber.map { "xcresult.osBuild=\($0)" },
            "xcresult.platform=\(platform)"
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    var reviewerEvidenceTokens: [String] {
        [
            "xcresult.model=\(Self.compactEvidenceValue(modelName))",
            osVersion.map { "xcresult.osversion=\(Self.compactEvidenceValue($0))" },
            osBuildNumber.map { "xcresult.osbuild=\(Self.compactEvidenceValue($0))" },
            "xcresult.platform=\(Self.compactEvidenceValue(platform))"
        ]
            .compactMap { $0 }
    }

    private static func compactEvidenceValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
    }
}

private struct BracketerPhysicalXCResultTestResultsSummary: Decodable, Equatable, Sendable {
    struct DeviceConfiguration: Decodable, Equatable, Sendable {
        struct Device: Decodable, Equatable, Sendable {
            let deviceName: String?
            let modelName: String?
            let osVersion: String?
            let osBuildNumber: String?
            let platform: String?
        }

        struct TestPlanConfiguration: Decodable, Equatable, Sendable {
            let configurationName: String?
        }

        let device: Device?
        let testPlanConfiguration: TestPlanConfiguration?
    }

    let title: String
    let result: String
    let totalTestCount: Int
    let passedTests: Int
    let failedTests: Int
    let expectedFailures: Int
    let skippedTests: Int
    let startTime: Double
    let finishTime: Double
    let environmentDescription: String?
    let devicesAndConfigurations: [DeviceConfiguration]

    func proofInput(attachmentByteCount: Int) throws -> BracketerPhysicalResultBundleProofInput {
        guard attachmentByteCount > 0 else {
            throw BracketerPhysicalResultBundleProofInputError.invalidAttachmentByteCount(attachmentByteCount)
        }
        guard finishTime > startTime else {
            throw BracketerPhysicalResultBundleProofInputError.invalidXCResultTimeRange(
                startTime: startTime,
                finishTime: finishTime
            )
        }
        guard let testPlanConfigurationName = devicesAndConfigurations
            .compactMap({ $0.testPlanConfiguration?.configurationName?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            throw BracketerPhysicalResultBundleProofInputError.missingTestPlanConfiguration
        }

        let startDate = Date(timeIntervalSince1970: startTime)
        let finishDate = Date(timeIntervalSince1970: finishTime)
        let durationMilliseconds = Int(((finishTime - startTime) * 1_000).rounded())
        let firstDevice = devicesAndConfigurations.first?.device
        return BracketerPhysicalResultBundleProofInput(
            resultBundleSummary: BracketerPhysicalResultBundleSummary(
                status: status,
                title: title,
                totalTestCount: totalTestCount,
                passedTestCount: passedTests,
                failedTestCount: failedTests,
                expectedFailureCount: expectedFailures,
                skippedTestCount: skippedTests
            ),
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: totalTestCount,
                passedTests: passedTests,
                failedTests: failedTests,
                durationMilliseconds: durationMilliseconds,
                attachmentByteCount: attachmentByteCount
            ),
            resultBundleTiming: BracketerPhysicalResultBundleTiming(
                summaryStartTime: startDate,
                summaryFinishTime: finishDate,
                testStartTime: startDate,
                testFinishTime: finishDate
            ),
            testPlanConfigurationName: testPlanConfigurationName,
            environmentDescription: environmentDescription,
            deviceName: firstDevice?.deviceName,
            deviceModelName: firstDevice?.modelName,
            osVersion: firstDevice?.osVersion,
            osBuildNumber: firstDevice?.osBuildNumber,
            platform: firstDevice?.platform
        )
    }

    private var status: BracketerPhysicalResultBundleSummary.Status {
        switch result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "") {
            case "passed":
                return .passed
            case "failed":
                return .failed
            case "mixed":
                return .mixed
            case "skipped":
                return .skipped
            case "expectedfailure":
                return .expectedFailure
            default:
                return .unknown
        }
    }
}

struct BracketerPhysicalAttachmentManifest: Codable, Equatable, Sendable {
    let resultBundleFilename: String
    let resultBundleTestIdentifier: String
    let testStartTime: Date
    let testFinishTime: Date
    let artifactSHA256ByID: [String: String]
    let artifactByteCountByID: [String: Int]

    var contextValue: String {
        [
            "attachment.bundle=\(resultBundleFilename)",
            "attachment.testIdentifier=\(resultBundleTestIdentifier)",
            "attachment.testStart=\(Self.timestamp(testStartTime))",
            "attachment.testFinish=\(Self.timestamp(testFinishTime))"
        ].joined(separator: ", ")
    }

    var contextReviewerEvidenceTokens: [String] {
        [
            "attachment.bundle=\(Self.compactEvidenceValue(resultBundleFilename))",
            "attachment.testidentifier=\(Self.compactEvidenceValue(resultBundleTestIdentifier))",
            "attachment.teststart=\(Self.timestamp(testStartTime).lowercased())",
            "attachment.testfinish=\(Self.timestamp(testFinishTime).lowercased())"
        ]
    }

    var summaryValue: String {
        [
            contextValue,
            artifactSummaryValue
        ].joined(separator: ", ")
    }

    var artifactReviewerEvidenceTokens: [String] {
        artifactSHA256ByID
            .sorted { $0.key < $1.key }
            .map { artifactID, digest in
                "artifact.\(Self.compactEvidenceValue(artifactID)).sha256=\(digest.lowercased())"
            }
    }

    var artifactByteCountReviewerEvidenceTokens: [String] {
        artifactByteCountByID
            .sorted { $0.key < $1.key }
            .map { artifactID, byteCount in
                "artifact.\(Self.compactEvidenceValue(artifactID)).bytes=\(byteCount)"
            }
    }

    var totalArtifactByteCount: Int {
        artifactByteCountByID.values.reduce(0, +)
    }

    var reviewerEvidenceTokens: [String] {
        contextReviewerEvidenceTokens
            + artifactReviewerEvidenceTokens
            + artifactByteCountReviewerEvidenceTokens
    }

    private var artifactSummaryValue: String {
        [
            artifactSHA256ByID
                .sorted { $0.key < $1.key }
                .map { artifactID, digest in
                    "artifact.\(artifactID).sha256=\(digest)"
                }
                .joined(separator: ", "),
            artifactByteCountByID
                .sorted { $0.key < $1.key }
                .map { artifactID, byteCount in
                    "artifact.\(artifactID).bytes=\(byteCount)"
                }
                .joined(separator: ", "),
            "attachment.totalBytes=\(totalArtifactByteCount)"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private static func compactEvidenceValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

struct BracketerPhysicalResultBundleTestContract: Codable, Equatable, Sendable {
    let xcodebuildVersion: String
    let xcresulttoolVersion: String
    let testPlanConfigurationName: String
    let testIdentifier: String
    let testName: String

    var summaryValue: String {
        [
            "test.xcodebuildVersion=\(xcodebuildVersion)",
            "test.xcresulttoolVersion=\(xcresulttoolVersion)",
            "test.plan=\(testPlanConfigurationName)",
            "test.identifier=\(testIdentifier)",
            "test.name=\(testName)"
        ].joined(separator: ", ")
    }

    var reviewerEvidenceTokens: [String] {
        [
            "test.xcodebuildversion=\(Self.compactEvidenceValue(xcodebuildVersion))",
            "test.xcresulttoolversion=\(Self.compactEvidenceValue(xcresulttoolVersion))",
            "test.plan=\(Self.compactEvidenceValue(testPlanConfigurationName))",
            "test.identifier=\(Self.compactEvidenceValue(testIdentifier))",
            "test.name=\(Self.compactEvidenceValue(testName))"
        ]
    }

    private static func compactEvidenceValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
    }
}

struct BracketerPhysicalProofSubmission: Codable, Equatable, Sendable {
    static let schemaVersion = 5

    let schemaVersion: Int
    let scenarioID: String
    let resultBundleFilename: String
    let resultBundleSHA256: String
    let resultBundleSummarySHA256: String?
    let resultBundleSummary: BracketerPhysicalResultBundleSummary?
    let resultBundleMetrics: BracketerPhysicalResultBundleMetrics?
    let resultBundleTestContract: BracketerPhysicalResultBundleTestContract?
    let resultBundleTiming: BracketerPhysicalResultBundleTiming?
    let resultBundleDevice: BracketerPhysicalResultBundleDevice?
    let attachmentManifest: BracketerPhysicalAttachmentManifest?
    let xcodeDestination: String
    let deviceModelIdentifier: String
    let hashedDeviceIdentifier: String
    let iosBuild: String
    let capturedAt: Date
    let lensID: String?
    let manifestSnapshotSHA256: String?
    let providedArtifactIDs: [String]
    let reviewerEvidence: [String]
    let notes: String?
    let attachmentSignature: String?

    init(
        schemaVersion: Int = Self.schemaVersion,
        scenarioID: String,
        resultBundleFilename: String,
        resultBundleSHA256: String,
        resultBundleSummarySHA256: String? = nil,
        resultBundleSummary: BracketerPhysicalResultBundleSummary? = nil,
        resultBundleMetrics: BracketerPhysicalResultBundleMetrics? = nil,
        resultBundleTestContract: BracketerPhysicalResultBundleTestContract? = nil,
        resultBundleTiming: BracketerPhysicalResultBundleTiming? = nil,
        resultBundleDevice: BracketerPhysicalResultBundleDevice? = nil,
        attachmentManifest: BracketerPhysicalAttachmentManifest? = nil,
        xcodeDestination: String,
        deviceModelIdentifier: String,
        hashedDeviceIdentifier: String,
        iosBuild: String,
        capturedAt: Date,
        lensID: String? = nil,
        manifestSnapshotSHA256: String? = nil,
        providedArtifactIDs: [String],
        reviewerEvidence: [String],
        notes: String? = nil,
        attachmentSignature: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.scenarioID = scenarioID
        self.resultBundleFilename = resultBundleFilename
        self.resultBundleSHA256 = resultBundleSHA256
        self.resultBundleSummarySHA256 = resultBundleSummarySHA256
        self.resultBundleSummary = resultBundleSummary
        self.resultBundleMetrics = resultBundleMetrics
        self.resultBundleTestContract = resultBundleTestContract
        self.resultBundleTiming = resultBundleTiming
        self.resultBundleDevice = resultBundleDevice
        self.attachmentManifest = attachmentManifest
        self.xcodeDestination = xcodeDestination
        self.deviceModelIdentifier = deviceModelIdentifier
        self.hashedDeviceIdentifier = hashedDeviceIdentifier
        self.iosBuild = iosBuild
        self.capturedAt = capturedAt
        self.lensID = lensID
        self.manifestSnapshotSHA256 = manifestSnapshotSHA256
        self.providedArtifactIDs = providedArtifactIDs
        self.reviewerEvidence = reviewerEvidence
        self.notes = notes
        self.attachmentSignature = attachmentSignature
    }

    static func template(
        for runbook: BracketerPhysicalCaptureRunbook,
        capturedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> BracketerPhysicalProofSubmission {
        let resultBundleFilename = "Bracketer-\(runbook.id)-physical.xcresult"
        let resultBundleTestContract = BracketerPhysicalResultBundleTestContract(
            xcodebuildVersion: "REPLACE_WITH_XCODEBUILD_VERSION",
            xcresulttoolVersion: "REPLACE_WITH_XCRESULTTOOL_VERSION",
            testPlanConfigurationName: "REPLACE_WITH_TEST_PLAN_CONFIGURATION",
            testIdentifier: "REPLACE_WITH_SCENARIO_BOUND_TEST_IDENTIFIER",
            testName: "REPLACE_WITH_TEST_NAME"
        )
        let resultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "REPLACE_AFTER_PHYSICAL_RUN_RESULT_BUNDLE_TITLE",
            totalTestCount: 0,
            passedTestCount: 0,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let resultBundleTiming = BracketerPhysicalResultBundleTiming(
            summaryStartTime: capturedAt,
            summaryFinishTime: capturedAt,
            testStartTime: capturedAt,
            testFinishTime: capturedAt
        )
        let resultBundleDevice = BracketerPhysicalResultBundleDevice(
            modelName: "REPLACE_AFTER_PHYSICAL_RUN_XCRESULT_DEVICE_MODEL",
            osVersion: "REPLACE_WITH_XCRESULT_OS_VERSION",
            osBuildNumber: "REPLACE_WITH_XCRESULT_OS_BUILD_OR_REMOVE",
            platform: "REPLACE_WITH_XCRESULT_PLATFORM"
        )
        return BracketerPhysicalProofSubmission(
            scenarioID: runbook.id,
            resultBundleFilename: resultBundleFilename,
            resultBundleSHA256: "REPLACE_WITH_64_HEX_RESULT_BUNDLE_SHA256",
            resultBundleSummarySHA256: "REPLACE_WITH_64_HEX_RESULT_BUNDLE_SUMMARY_SHA256",
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 0,
                passedTests: 0,
                failedTests: 0,
                durationMilliseconds: 0,
                attachmentByteCount: 0
            ),
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: resultBundleTiming,
            resultBundleDevice: resultBundleDevice,
            attachmentManifest: BracketerPhysicalAttachmentManifest(
                resultBundleFilename: resultBundleFilename,
                resultBundleTestIdentifier: resultBundleTestContract.testIdentifier,
                testStartTime: resultBundleTiming.testStartTime,
                testFinishTime: resultBundleTiming.testFinishTime,
                artifactSHA256ByID: Dictionary(
                    uniqueKeysWithValues: runbook.expectedArtifacts.map {
                        ($0, "REPLACE_WITH_64_HEX_\($0.uppercased())_SHA256")
                    }
                ),
                artifactByteCountByID: Dictionary(
                    uniqueKeysWithValues: runbook.expectedArtifacts.map { ($0, 0) }
                )
            ),
            xcodeDestination: "platform=iOS,id=<DEVICE-UDID>",
            deviceModelIdentifier: "REPLACE_WITH_IPHONE_MODEL_IDENTIFIER_LIKE_iPhone17,1",
            hashedDeviceIdentifier: "REPLACE_WITH_HASHED_DEVICE_IDENTIFIER",
            iosBuild: "REPLACE_WITH_IOS_BUILD",
            capturedAt: capturedAt,
            lensID: "REPLACE_WITH_LENS_ID_OR_REMOVE",
            manifestSnapshotSHA256: nil,
            providedArtifactIDs: runbook.expectedArtifacts,
            reviewerEvidence: runbook.evidenceSteps.map { "REPLACE_AFTER_PHYSICAL_RUN: \($0)" },
            notes: "physical-device-proof preview only template; replace placeholders after a real iPhone run before ingest."
        )
    }

    static func template(
        for runbook: BracketerPhysicalCaptureRunbook,
        proofInput: BracketerPhysicalResultBundleProofInput,
        capturedAt: Date? = nil
    ) -> BracketerPhysicalProofSubmission {
        let resultBundleFilename = "Bracketer-\(runbook.id)-physical.xcresult"
        let resolvedCapturedAt = capturedAt ?? midpoint(
            start: proofInput.resultBundleTiming.testStartTime,
            finish: proofInput.resultBundleTiming.testFinishTime
        )
        let resultBundleTestContract = proofInput.testContract(
            xcodebuildVersion: "REPLACE_WITH_XCODEBUILD_VERSION",
            xcresulttoolVersion: "REPLACE_WITH_XCRESULTTOOL_VERSION",
            testIdentifier: "BracketerPhysicalCaptureTests/test\(runbook.id)PhysicalCapture",
            testName: "test\(runbook.id)PhysicalCapture"
        )
        let attachmentManifest = BracketerPhysicalAttachmentManifest(
            resultBundleFilename: resultBundleFilename,
            resultBundleTestIdentifier: resultBundleTestContract.testIdentifier,
            testStartTime: proofInput.resultBundleTiming.testStartTime,
            testFinishTime: proofInput.resultBundleTiming.testFinishTime,
            artifactSHA256ByID: Dictionary(
                uniqueKeysWithValues: runbook.expectedArtifacts.map {
                    ($0, "REPLACE_WITH_64_HEX_\($0.uppercased())_SHA256")
                }
            ),
            artifactByteCountByID: Dictionary(
                uniqueKeysWithValues: runbook.expectedArtifacts.map { ($0, 0) }
            )
        )
        let iosBuildSeed = proofInput.resultBundleDevice?.osVersion
            ?? proofInput.resultBundleDevice?.osBuildNumber
            ?? "REPLACE_WITH_IOS_BUILD"
        let reviewerEvidence = [
            "Captured at: \(timestamp(resolvedCapturedAt))",
            "Result bundle: \(resultBundleFilename)",
            "Result bundle SHA-256: REPLACE_WITH_64_HEX_RESULT_BUNDLE_SHA256",
            "Result bundle summary SHA-256: REPLACE_WITH_64_HEX_RESULT_BUNDLE_SUMMARY_SHA256"
        ] + proofInput.reviewerEvidenceLines + [
            "Result bundle test contract: \(resultBundleTestContract.summaryValue)",
            "Attachment manifest hashes: \(attachmentManifest.summaryValue)",
            "Hashed device identifier: REPLACE_WITH_HASHED_DEVICE_IDENTIFIER",
            "Device model: REPLACE_WITH_IPHONE_MODEL_IDENTIFIER_LIKE_iPhone17,1",
            "iOS build: \(iosBuildSeed)"
        ] + runbook.evidenceSteps.map { "REPLACE_AFTER_PHYSICAL_RUN: \($0)" }

        return BracketerPhysicalProofSubmission(
            scenarioID: runbook.id,
            resultBundleFilename: resultBundleFilename,
            resultBundleSHA256: "REPLACE_WITH_64_HEX_RESULT_BUNDLE_SHA256",
            resultBundleSummarySHA256: "REPLACE_WITH_64_HEX_RESULT_BUNDLE_SUMMARY_SHA256",
            resultBundleSummary: proofInput.resultBundleSummary,
            resultBundleMetrics: proofInput.resultBundleMetrics,
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: proofInput.resultBundleTiming,
            resultBundleDevice: proofInput.resultBundleDevice,
            attachmentManifest: attachmentManifest,
            xcodeDestination: "platform=iOS,id=<DEVICE-UDID>",
            deviceModelIdentifier: "REPLACE_WITH_IPHONE_MODEL_IDENTIFIER_LIKE_iPhone17,1",
            hashedDeviceIdentifier: "REPLACE_WITH_HASHED_DEVICE_IDENTIFIER",
            iosBuild: iosBuildSeed,
            capturedAt: resolvedCapturedAt,
            lensID: "REPLACE_WITH_LENS_ID_OR_REMOVE",
            manifestSnapshotSHA256: nil,
            providedArtifactIDs: runbook.expectedArtifacts,
            reviewerEvidence: reviewerEvidence,
            notes: "physical-device-proof preview only seeded from parsed result-bundle proof input; replace placeholders after a real iPhone run before ingest."
        )
    }

    private static func midpoint(start: Date, finish: Date) -> Date {
        Date(timeIntervalSince1970: (start.timeIntervalSince1970 + finish.timeIntervalSince1970) / 2)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    func signed() throws -> BracketerPhysicalProofSubmission {
        try replacingAttachmentSignature(attachmentSignatureValue())
    }

    func replacingAttachmentSignature(_ signature: String?) -> BracketerPhysicalProofSubmission {
        BracketerPhysicalProofSubmission(
            schemaVersion: schemaVersion,
            scenarioID: scenarioID,
            resultBundleFilename: resultBundleFilename,
            resultBundleSHA256: resultBundleSHA256,
            resultBundleSummarySHA256: resultBundleSummarySHA256,
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: resultBundleMetrics,
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: resultBundleTiming,
            resultBundleDevice: resultBundleDevice,
            attachmentManifest: attachmentManifest,
            xcodeDestination: xcodeDestination,
            deviceModelIdentifier: deviceModelIdentifier,
            hashedDeviceIdentifier: hashedDeviceIdentifier,
            iosBuild: iosBuild,
            capturedAt: capturedAt,
            lensID: lensID,
            manifestSnapshotSHA256: manifestSnapshotSHA256,
            providedArtifactIDs: providedArtifactIDs,
            reviewerEvidence: reviewerEvidence,
            notes: notes,
            attachmentSignature: signature
        )
    }

    func attachmentSignatureValue() throws -> String {
        let payload = BracketerPhysicalProofSubmissionSignaturePayload(submission: self)
        let encoder = JSONEncoder.bracketerPhysicalProofCanonical
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    var hasValidAttachmentSignature: Bool {
        guard let attachmentSignature else { return false }
        return (try? attachmentSignatureValue()) == attachmentSignature
    }

    var attachmentStatusValue: String {
        if attachmentSignature == nil {
            return "Unsigned physical proof submission attachment"
        }
        return hasValidAttachmentSignature
            ? "Signed physical proof submission attachment"
            : "Invalid physical proof submission attachment signature"
    }
}

private struct BracketerPhysicalProofSubmissionSignaturePayload: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let scenarioID: String
    let resultBundleFilename: String
    let resultBundleSHA256: String
    let resultBundleSummarySHA256: String?
    let resultBundleSummary: BracketerPhysicalResultBundleSummary?
    let resultBundleMetrics: BracketerPhysicalResultBundleMetrics?
    let resultBundleTestContract: BracketerPhysicalResultBundleTestContract?
    let resultBundleTiming: BracketerPhysicalResultBundleTiming?
    let resultBundleDevice: BracketerPhysicalResultBundleDevice?
    let attachmentManifest: BracketerPhysicalAttachmentManifest?
    let xcodeDestination: String
    let deviceModelIdentifier: String
    let hashedDeviceIdentifier: String
    let iosBuild: String
    let capturedAt: Date
    let lensID: String?
    let manifestSnapshotSHA256: String?
    let providedArtifactIDs: [String]
    let reviewerEvidence: [String]
    let notes: String?

    init(submission: BracketerPhysicalProofSubmission) {
        schemaVersion = submission.schemaVersion
        scenarioID = submission.scenarioID
        resultBundleFilename = submission.resultBundleFilename
        resultBundleSHA256 = submission.resultBundleSHA256
        resultBundleSummarySHA256 = submission.resultBundleSummarySHA256
        resultBundleSummary = submission.resultBundleSummary
        resultBundleMetrics = submission.resultBundleMetrics
        resultBundleTestContract = submission.resultBundleTestContract
        resultBundleTiming = submission.resultBundleTiming
        resultBundleDevice = submission.resultBundleDevice
        attachmentManifest = submission.attachmentManifest
        xcodeDestination = submission.xcodeDestination
        deviceModelIdentifier = submission.deviceModelIdentifier
        hashedDeviceIdentifier = submission.hashedDeviceIdentifier
        iosBuild = submission.iosBuild
        capturedAt = submission.capturedAt
        lensID = submission.lensID
        manifestSnapshotSHA256 = submission.manifestSnapshotSHA256
        providedArtifactIDs = submission.providedArtifactIDs
        reviewerEvidence = submission.reviewerEvidence
        notes = submission.notes
    }
}

extension JSONEncoder {
    static var bracketerPhysicalProofCanonical: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

struct BracketerPhysicalProofIngestResult: Codable, Equatable, Sendable {
    let catalog: BracketerPhysicalCaptureRunbookCatalog
    let resultBundleIndex: BracketerPhysicalResultBundleIndex
    let recordedProof: BracketerPhysicalCaptureRunbook.RecordedProof
    let indexEntry: BracketerPhysicalResultBundleIndex.Entry
    let proofCategory: String

    var summaryValue: String {
        [
            "Physical Proof Ingest",
            proofCategory,
            "\(catalog.capturedRunbookCount) of \(catalog.requiredRunbookCount) runbooks captured",
            resultBundleIndex.summaryValue
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            recordedProof.accessibilityValue,
            indexEntry.accessibilityValue
        ].joined(separator: " | ")
    }
}

struct BracketerPhysicalProofIngestPreview: Codable, Equatable, Sendable {
    let scenarioID: String
    let accepted: Bool
    let recordedProofPreview: BracketerPhysicalCaptureRunbook.RecordedProof?
    let indexEntryPreview: BracketerPhysicalResultBundleIndex.Entry?
    let rejectionReasons: [String]
    let proofCategory: String

    init(
        scenarioID: String,
        accepted: Bool,
        recordedProofPreview: BracketerPhysicalCaptureRunbook.RecordedProof? = nil,
        indexEntryPreview: BracketerPhysicalResultBundleIndex.Entry? = nil,
        rejectionReasons: [String] = [],
        proofCategory: String = "physical-device-proof preview only"
    ) {
        self.scenarioID = scenarioID
        self.accepted = accepted
        self.recordedProofPreview = recordedProofPreview
        self.indexEntryPreview = indexEntryPreview
        self.rejectionReasons = rejectionReasons
        self.proofCategory = proofCategory
    }

    var summaryValue: String {
        [
            "Physical Proof Submission Preview",
            accepted ? "Accepted candidate" : "Rejected candidate",
            proofCategory
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        var parts = [
            summaryValue,
            "Scenario: \(scenarioID)"
        ]
        if let recordedProofPreview {
            parts.append(recordedProofPreview.accessibilityValue)
        }
        if let indexEntryPreview {
            parts.append(indexEntryPreview.accessibilityValue)
        }
        if !rejectionReasons.isEmpty {
            parts.append("Rejections: \(rejectionReasons.joined(separator: " | "))")
        }
        parts.append("Preview does not mutate runbooks, result-bundle indexes, or physical proof counts.")
        return parts.joined(separator: " | ")
    }
}

struct BracketerPhysicalProofIngestReadiness: Codable, Equatable, Sendable {
    static let schemaVersion = 26

    let schemaVersion: Int
    let acceptedScenarioCount: Int
    let requiredScenarioCount: Int
    let requiredSubmissionFields: [String]
    let rejectionRules: [String]
    let privacyBoundary: String

    init(
        schemaVersion: Int = Self.schemaVersion,
        acceptedScenarioCount: Int,
        requiredScenarioCount: Int,
        requiredSubmissionFields: [String] = Self.defaultRequiredSubmissionFields,
        rejectionRules: [String] = Self.defaultRejectionRules,
        privacyBoundary: String = "Physical Proof Ingest Readiness stores contract text only; accepted proof records must still avoid Photos identifiers, raw image bytes, thumbnail pixels, decoded RAW data, final rendered output bytes, precise coordinates, and hashed device identifiers."
    ) {
        self.schemaVersion = schemaVersion
        self.acceptedScenarioCount = acceptedScenarioCount
        self.requiredScenarioCount = requiredScenarioCount
        self.requiredSubmissionFields = requiredSubmissionFields
        self.rejectionRules = rejectionRules
        self.privacyBoundary = privacyBoundary
    }

    static func make(
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make(),
        resultBundleIndex: BracketerPhysicalResultBundleIndex? = nil
    ) -> BracketerPhysicalProofIngestReadiness {
        let index = resultBundleIndex ?? BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks)
        return BracketerPhysicalProofIngestReadiness(
            acceptedScenarioCount: index.indexedCount,
            requiredScenarioCount: catalog.requiredRunbookCount
        )
    }

    var summaryValue: String {
        [
            "Physical Proof Ingestor",
            "\(acceptedScenarioCount) of \(requiredScenarioCount) physical submissions accepted",
            "Real iPhone artifacts required"
        ].joined(separator: " | ")
    }

    var accessibilityValue: String {
        [
            summaryValue,
            "schema v\(schemaVersion)",
            "Required fields: \(requiredSubmissionFields.joined(separator: ", "))",
            "Rejects: \(rejectionRules.joined(separator: ", "))",
            privacyBoundary
        ].joined(separator: " | ")
    }

    private static let defaultRequiredSubmissionFields = [
        "scenario id",
        "valid attachment signature",
        "physical platform=iOS destination id",
        "scenario-bound result-bundle filename",
        "result-bundle SHA-256",
        "result-bundle summary SHA-256",
        "typed result-bundle summary",
        "result-bundle summary status",
        "result-bundle summary title",
        "result-bundle summary total test count",
        "result-bundle summary passed test count",
        "result-bundle summary failed test count",
        "result-bundle summary counts match metrics",
        "xcresulttool compact test-results summary JSON",
        "parsed result-bundle proof input",
        "xcresulttool command plan",
        "result-bundle digest command plan",
        "scenario-bound result-bundle path",
        "top-level xcresult summary counts",
        "result-bundle metrics",
        "result-bundle test contract",
        "result-bundle timing metadata",
        "result-bundle device/platform metadata",
        "physical xcresult platform",
        "result-bundle iOS build matches submission",
        "per-artifact attachment manifest SHA-256 values",
        "per-artifact attachment manifest byte counts",
        "attachment manifest result-bundle filename",
        "attachment manifest scenario test identifier",
        "attachment manifest test start and finish time",
        "xcodebuild version",
        "xcresulttool version",
        "scenario-bound test identifier",
        "result-bundle summary start and finish time",
        "scenario test start and finish time",
        "capturedAt inside result-bundle test window",
        "manifest snapshot SHA-256",
        "physical capturedAt timestamp",
        "capturedAt timestamp in reviewer evidence",
        "result-bundle filename in reviewer evidence",
        "result-bundle SHA-256 in reviewer evidence",
        "result-bundle summary SHA-256 in reviewer evidence",
        "typed result-bundle summary in reviewer evidence",
        "result-bundle metrics in reviewer evidence",
        "result-bundle test contract in reviewer evidence",
        "result-bundle timing metadata in reviewer evidence",
        "result-bundle device metadata in reviewer evidence",
        "attachment manifest result-bundle context in reviewer evidence",
        "attachment manifest hashes in reviewer evidence",
        "attachment manifest byte counts in reviewer evidence",
        "passing result-bundle summary in reviewer evidence",
        "hashed device identifier in reviewer evidence",
        "device model identifier in reviewer evidence",
        "iOS build label in reviewer evidence",
        "iPhone model identifier (iPhoneN,M)",
        "hashed device identifier",
        "iOS version or build label",
        "all expected artifact ids",
        "scenario-bound reviewer evidence"
    ]

    private static let defaultRejectionRules = [
        "invalid attachment signature",
        "simulator destination",
        "result-bundle filename for a different scenario",
        "missing expected artifacts",
        "missing device labels",
        "missing result-bundle summary SHA-256",
        "missing typed result-bundle summary",
        "missing result-bundle metrics",
        "missing result-bundle test contract",
        "missing result-bundle timing metadata",
        "missing result-bundle device metadata",
        "missing attachment manifest hashes",
        "missing manifest snapshot SHA-256",
        "stale capturedAt timestamp",
        "future capturedAt timestamp",
        "non-iPhone model identifier",
        "missing hashed device identifier",
        "invalid iOS build label",
        "invalid SHA-256",
        "invalid typed result-bundle summary",
        "result-bundle summary counts disagree with metrics",
        "invalid xcresulttool compact summary JSON",
        "xcresulttool summary timing window invalid",
        "non-.xcresult result-bundle path",
        "unsafe result-bundle path",
        "scenario bundle name mismatch",
        "invalid result-bundle metrics",
        "invalid result-bundle test contract",
        "invalid result-bundle timing metadata",
        "invalid result-bundle device metadata",
        "simulator result-bundle platform",
        "result-bundle device metadata disagrees with submission",
        "result-bundle duration disagrees with test window",
        "invalid attachment manifest context",
        "invalid attachment manifest hashes",
        "invalid attachment manifest byte counts",
        "attachment manifest byte count disagrees with result-bundle metrics",
        "capturedAt outside result-bundle test window",
        "result-bundle summary SHA-256 equals bundle SHA-256",
        "reviewer evidence missing scenario descriptors",
        "reviewer evidence missing capturedAt timestamp",
        "reviewer evidence missing result-bundle filename",
        "reviewer evidence missing result-bundle SHA-256",
        "reviewer evidence missing result-bundle summary SHA-256",
        "reviewer evidence missing typed result-bundle summary",
        "reviewer evidence missing result-bundle metrics",
        "reviewer evidence missing result-bundle test contract",
        "reviewer evidence missing result-bundle timing metadata",
        "reviewer evidence missing result-bundle device metadata",
        "reviewer evidence missing attachment manifest context",
        "reviewer evidence missing attachment manifest hashes",
        "reviewer evidence missing attachment manifest byte counts",
        "reviewer evidence missing passing result-bundle summary",
        "reviewer evidence missing hashed device identifier",
        "reviewer evidence missing device model identifier",
        "reviewer evidence missing iOS build label",
        "unreplaced template placeholder",
        "Photos local identifiers",
        "raw image bytes",
        "precise coordinates"
    ]
}

struct BracketerPhysicalProofIngestor: Sendable {
    private static let minimumPhysicalProofCapturedAt = Date(timeIntervalSince1970: 1_779_926_400)
    private static let futureCaptureTolerance: TimeInterval = 5 * 60

    enum ValidationFailure: Error, Equatable, Sendable, CustomStringConvertible {
        case unsupportedSchemaVersion(Int)
        case unknownScenario(String)
        case simulatorDestination(String)
        case physicalDestinationMissing(String)
        case invalidAttachmentSignature
        case missingDeviceModelIdentifier
        case deviceModelIdentifierNotIPhone(String)
        case missingHashedDeviceIdentifier
        case missingResultBundleSummarySHA256
        case missingResultBundleSummary
        case missingResultBundleMetrics
        case missingResultBundleTestContract
        case missingResultBundleTiming
        case missingResultBundleDeviceMetadata
        case missingAttachmentManifest
        case missingManifestSnapshotSHA256
        case capturedAtBeforePhysicalLabWindow(Date)
        case capturedAtInFuture(Date)
        case missingIOSBuild
        case invalidIOSBuildLabel(String)
        case invalidResultBundleFilename(String)
        case resultBundleFilenameScenarioMismatch(filename: String, expectedPrefix: String)
        case invalidSHA256(field: String)
        case invalidResultBundleSummary(String)
        case resultBundleSummaryMetricsMismatch(field: String, summaryCount: Int, metricsCount: Int)
        case invalidResultBundleMetrics(String)
        case invalidResultBundleTestContract(String)
        case invalidResultBundleTiming(String)
        case invalidResultBundleDeviceMetadata(String)
        case resultBundleTimingDurationMismatch(expectedMilliseconds: Int, metricsMilliseconds: Int)
        case invalidAttachmentManifestContext(String)
        case invalidAttachmentManifest(String)
        case invalidAttachmentManifestByteCounts(String)
        case attachmentManifestByteCountMismatch(expectedBytes: Int, manifestBytes: Int)
        case resultBundleSummarySHA256MatchesBundleSHA256
        case missingExpectedArtifacts([String])
        case missingReviewerEvidence
        case reviewerEvidenceMissingScenarioDescriptors([String])
        case reviewerEvidenceMissingCapturedAtTimestamp(String)
        case reviewerEvidenceMissingResultBundleFilename(String)
        case reviewerEvidenceMissingResultBundleSHA256(String)
        case reviewerEvidenceMissingResultBundleSummarySHA256(String)
        case reviewerEvidenceMissingResultBundleSummary([String])
        case reviewerEvidenceMissingResultBundleMetrics([String])
        case reviewerEvidenceMissingResultBundleTestContract([String])
        case reviewerEvidenceMissingResultBundleTiming([String])
        case reviewerEvidenceMissingResultBundleDeviceMetadata([String])
        case reviewerEvidenceMissingAttachmentManifestContext([String])
        case reviewerEvidenceMissingAttachmentManifest([String])
        case reviewerEvidenceMissingAttachmentManifestByteCounts([String])
        case reviewerEvidenceMissingPassingResultBundleSummary
        case reviewerEvidenceMissingHashedDeviceIdentifier(String)
        case reviewerEvidenceMissingDeviceModelIdentifier(String)
        case reviewerEvidenceMissingIOSBuild(String)
        case templatePlaceholderRetained(field: String, marker: String)
        case privacyBoundaryViolation(String)

        var description: String {
            switch self {
            case .unsupportedSchemaVersion(let version):
                return "Unsupported physical proof submission schema \(version)."
            case .unknownScenario(let scenarioID):
                return "Unknown physical capture scenario \(scenarioID)."
            case .simulatorDestination(let destination):
                return "Simulator destination cannot be ingested as physical proof: \(destination)."
            case .physicalDestinationMissing(let destination):
                return "Physical proof requires a platform=iOS device destination with id=: \(destination)."
            case .invalidAttachmentSignature:
                return "Physical proof submission requires a valid attachment signature."
            case .missingDeviceModelIdentifier:
                return "Physical proof requires a device model identifier."
            case .deviceModelIdentifierNotIPhone(let identifier):
                return "Physical proof device model identifier must be an iPhone hardware identifier like iPhone17,1: \(identifier)."
            case .missingHashedDeviceIdentifier:
                return "Physical proof requires a hashed device identifier."
            case .missingResultBundleSummarySHA256:
                return "Physical proof requires a result-bundle summary SHA-256."
            case .missingResultBundleSummary:
                return "Physical proof requires a typed result-bundle summary."
            case .missingResultBundleMetrics:
                return "Physical proof requires result-bundle metrics."
            case .missingResultBundleTestContract:
                return "Physical proof requires a result-bundle test contract."
            case .missingResultBundleTiming:
                return "Physical proof requires result-bundle timing metadata."
            case .missingResultBundleDeviceMetadata:
                return "Physical proof requires result-bundle device metadata."
            case .missingAttachmentManifest:
                return "Physical proof requires per-artifact attachment manifest hashes."
            case .missingManifestSnapshotSHA256:
                return "Physical proof requires a manifest snapshot SHA-256."
            case .capturedAtBeforePhysicalLabWindow:
                return "Physical proof capturedAt must be on or after \(BracketerPhysicalProofIngestor.capturedAtEvidenceTimestamp(BracketerPhysicalProofIngestor.minimumPhysicalProofCapturedAt))."
            case .capturedAtInFuture(let capturedAt):
                return "Physical proof capturedAt cannot be in the future beyond the ingest tolerance: \(BracketerPhysicalProofIngestor.capturedAtEvidenceTimestamp(capturedAt))."
            case .missingIOSBuild:
                return "Physical proof requires an iOS build label."
            case .invalidIOSBuildLabel(let label):
                return "Physical proof iOS build label must be a dotted iOS version or Apple build number: \(label)."
            case .invalidResultBundleFilename(let filename):
                return "Physical proof requires a single .xcresult result bundle filename: \(filename)."
            case .resultBundleFilenameScenarioMismatch(let filename, let expectedPrefix):
                return "Physical proof result bundle filename \(filename) must start with \(expectedPrefix) for the selected scenario."
            case .invalidSHA256(let field):
                return "Physical proof field \(field) must be a SHA-256 hex digest."
            case .invalidResultBundleSummary(let reason):
                return "Physical proof result-bundle summary is invalid: \(reason)."
            case .resultBundleSummaryMetricsMismatch(let field, let summaryCount, let metricsCount):
                return "Physical proof result-bundle summary \(field) count \(summaryCount) must equal result-bundle metrics count \(metricsCount)."
            case .invalidResultBundleMetrics(let reason):
                return "Physical proof result-bundle metrics are invalid: \(reason)."
            case .invalidResultBundleTestContract(let reason):
                return "Physical proof result-bundle test contract is invalid: \(reason)."
            case .invalidResultBundleTiming(let reason):
                return "Physical proof result-bundle timing metadata is invalid: \(reason)."
            case .invalidResultBundleDeviceMetadata(let reason):
                return "Physical proof result-bundle device metadata is invalid: \(reason)."
            case .resultBundleTimingDurationMismatch(let expectedMilliseconds, let metricsMilliseconds):
                return "Physical proof result-bundle metrics duration \(metricsMilliseconds)ms must equal test window duration \(expectedMilliseconds)ms."
            case .invalidAttachmentManifestContext(let reason):
                return "Physical proof attachment manifest context is invalid: \(reason)."
            case .invalidAttachmentManifest(let reason):
                return "Physical proof attachment manifest hashes are invalid: \(reason)."
            case .invalidAttachmentManifestByteCounts(let reason):
                return "Physical proof attachment manifest byte counts are invalid: \(reason)."
            case .attachmentManifestByteCountMismatch(let expectedBytes, let manifestBytes):
                return "Physical proof attachment manifest byte count \(manifestBytes) must equal result-bundle attachment byte count \(expectedBytes)."
            case .resultBundleSummarySHA256MatchesBundleSHA256:
                return "Physical proof result-bundle summary SHA-256 must be distinct from the result-bundle SHA-256."
            case .missingExpectedArtifacts(let artifacts):
                return "Physical proof is missing expected artifacts: \(artifacts.joined(separator: ", "))."
            case .missingReviewerEvidence:
                return "Physical proof requires reviewer evidence strings."
            case .reviewerEvidenceMissingScenarioDescriptors(let descriptors):
                return "Physical proof reviewer evidence must include scenario runbook descriptors: \(descriptors.joined(separator: ", "))."
            case .reviewerEvidenceMissingCapturedAtTimestamp(let timestamp):
                return "Physical proof reviewer evidence must echo capturedAt timestamp \(timestamp)."
            case .reviewerEvidenceMissingResultBundleFilename(let filename):
                return "Physical proof reviewer evidence must echo result-bundle filename \(filename)."
            case .reviewerEvidenceMissingResultBundleSHA256(let digest):
                return "Physical proof reviewer evidence must echo result-bundle SHA-256 \(digest)."
            case .reviewerEvidenceMissingResultBundleSummarySHA256(let digest):
                return "Physical proof reviewer evidence must echo result-bundle summary SHA-256 \(digest)."
            case .reviewerEvidenceMissingResultBundleSummary(let tokens):
                return "Physical proof reviewer evidence must echo typed result-bundle summary: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingResultBundleMetrics(let tokens):
                return "Physical proof reviewer evidence must echo result-bundle metrics: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingResultBundleTestContract(let tokens):
                return "Physical proof reviewer evidence must echo result-bundle test contract: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingResultBundleTiming(let tokens):
                return "Physical proof reviewer evidence must echo result-bundle timing metadata: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingResultBundleDeviceMetadata(let tokens):
                return "Physical proof reviewer evidence must echo result-bundle device metadata: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingAttachmentManifestContext(let tokens):
                return "Physical proof reviewer evidence must echo attachment manifest result-bundle context: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingAttachmentManifest(let tokens):
                return "Physical proof reviewer evidence must echo attachment manifest hashes: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingAttachmentManifestByteCounts(let tokens):
                return "Physical proof reviewer evidence must echo attachment manifest byte counts: \(tokens.joined(separator: ", "))."
            case .reviewerEvidenceMissingPassingResultBundleSummary:
                return "Physical proof reviewer evidence must include passing result-bundle summary with result=Passed and failedTests=0."
            case .reviewerEvidenceMissingHashedDeviceIdentifier(let digest):
                return "Physical proof reviewer evidence must echo hashed device identifier \(digest)."
            case .reviewerEvidenceMissingDeviceModelIdentifier(let identifier):
                return "Physical proof reviewer evidence must echo device model identifier \(identifier)."
            case .reviewerEvidenceMissingIOSBuild(let build):
                return "Physical proof reviewer evidence must echo iOS build label \(build)."
            case .templatePlaceholderRetained(let field, let marker):
                return "Physical proof submission retains unreplaced template placeholder in \(field): \(marker)."
            case .privacyBoundaryViolation(let marker):
                return "Physical proof submission contains forbidden private data marker: \(marker)."
            }
        }
    }

    static func ingest(
        _ submission: BracketerPhysicalProofSubmission,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make(),
        resultBundleIndex: BracketerPhysicalResultBundleIndex? = nil
    ) throws -> BracketerPhysicalProofIngestResult {
        let runbook = try validate(submission, catalog: catalog)
        let recordedProof = BracketerPhysicalCaptureRunbook.RecordedProof(
            deviceModel: submission.deviceModelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            iosBuild: submission.iosBuild.trimmingCharacters(in: .whitespacesAndNewlines),
            capturedAt: submission.capturedAt,
            resultBundleFilename: submission.resultBundleFilename,
            resultBundleSHA256: submission.resultBundleSHA256,
            resultBundleSummarySHA256: submission.resultBundleSummarySHA256,
            resultBundleSummary: submission.resultBundleSummary,
            resultBundleMetrics: submission.resultBundleMetrics,
            resultBundleTestContract: submission.resultBundleTestContract,
            resultBundleTiming: submission.resultBundleTiming,
            resultBundleDevice: submission.resultBundleDevice,
            attachmentManifest: submission.attachmentManifest,
            manifestSHA256: submission.manifestSnapshotSHA256,
            notes: notes(for: submission)
        )
        let updatedRunbook = runbook.replacingRecordedProof(recordedProof)
        let updatedCatalog = catalog.replacingRunbook(updatedRunbook)
        let entry = BracketerPhysicalResultBundleIndex.Entry(
            scenarioID: submission.scenarioID,
            runbookID: runbook.id,
            resultBundleFilename: submission.resultBundleFilename,
            recordedAt: submission.capturedAt,
            deviceModel: submission.deviceModelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            iosBuild: submission.iosBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let startingIndex = resultBundleIndex ?? BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks)
        let updatedIndex = startingIndex.replacingScenarioEntry(entry)

        return BracketerPhysicalProofIngestResult(
            catalog: updatedCatalog,
            resultBundleIndex: updatedIndex,
            recordedProof: recordedProof,
            indexEntry: entry,
            proofCategory: "physical-device-proof"
        )
    }

    static func preview(
        _ submission: BracketerPhysicalProofSubmission,
        catalog: BracketerPhysicalCaptureRunbookCatalog = .make(),
        resultBundleIndex: BracketerPhysicalResultBundleIndex? = nil
    ) -> BracketerPhysicalProofIngestPreview {
        guard submission.hasValidAttachmentSignature else {
            return BracketerPhysicalProofIngestPreview(
                scenarioID: submission.scenarioID,
                accepted: false,
                rejectionReasons: ["Physical proof submission preview requires a valid attachment signature."]
            )
        }

        do {
            let result = try ingest(
                submission,
                catalog: catalog,
                resultBundleIndex: resultBundleIndex
            )
            return BracketerPhysicalProofIngestPreview(
                scenarioID: submission.scenarioID,
                accepted: true,
                recordedProofPreview: result.recordedProof,
                indexEntryPreview: result.indexEntry
            )
        } catch let error as ValidationFailure {
            return BracketerPhysicalProofIngestPreview(
                scenarioID: submission.scenarioID,
                accepted: false,
                rejectionReasons: [error.description]
            )
        } catch {
            return BracketerPhysicalProofIngestPreview(
                scenarioID: submission.scenarioID,
                accepted: false,
                rejectionReasons: [error.localizedDescription]
            )
        }
    }

    private static func validate(
        _ submission: BracketerPhysicalProofSubmission,
        catalog: BracketerPhysicalCaptureRunbookCatalog
    ) throws -> BracketerPhysicalCaptureRunbook {
        guard submission.hasValidAttachmentSignature else {
            throw ValidationFailure.invalidAttachmentSignature
        }
        guard submission.schemaVersion == BracketerPhysicalProofSubmission.schemaVersion else {
            throw ValidationFailure.unsupportedSchemaVersion(submission.schemaVersion)
        }
        guard let runbook = catalog.runbooks.first(where: { $0.id == submission.scenarioID }) else {
            throw ValidationFailure.unknownScenario(submission.scenarioID)
        }
        let lowerDestination = submission.xcodeDestination.lowercased()
        if lowerDestination.contains("simulator") {
            throw ValidationFailure.simulatorDestination(submission.xcodeDestination)
        }
        if !lowerDestination.contains("platform=ios") || !lowerDestination.contains("id=") {
            throw ValidationFailure.physicalDestinationMissing(submission.xcodeDestination)
        }
        guard !submission.deviceModelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationFailure.missingDeviceModelIdentifier
        }
        guard !submission.hashedDeviceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationFailure.missingHashedDeviceIdentifier
        }
        guard !submission.iosBuild.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationFailure.missingIOSBuild
        }
        guard isSingleResultBundleFilename(submission.resultBundleFilename) else {
            throw ValidationFailure.invalidResultBundleFilename(submission.resultBundleFilename)
        }
        guard isScenarioResultBundleFilename(submission.resultBundleFilename, for: runbook) else {
            throw ValidationFailure.resultBundleFilenameScenarioMismatch(
                filename: submission.resultBundleFilename,
                expectedPrefix: expectedResultBundlePrefix(for: runbook)
            )
        }
        guard isSHA256(submission.resultBundleSHA256) else {
            throw ValidationFailure.invalidSHA256(field: "resultBundleSHA256")
        }
        guard let resultBundleSummarySHA256 = submission.resultBundleSummarySHA256,
              !resultBundleSummarySHA256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationFailure.missingResultBundleSummarySHA256
        }
        guard isSHA256(resultBundleSummarySHA256) else {
            throw ValidationFailure.invalidSHA256(field: "resultBundleSummarySHA256")
        }
        guard resultBundleSummarySHA256.lowercased() != submission.resultBundleSHA256.lowercased() else {
            throw ValidationFailure.resultBundleSummarySHA256MatchesBundleSHA256
        }
        guard let resultBundleMetrics = submission.resultBundleMetrics else {
            throw ValidationFailure.missingResultBundleMetrics
        }
        try validateResultBundleMetrics(resultBundleMetrics)
        guard let resultBundleSummary = submission.resultBundleSummary else {
            throw ValidationFailure.missingResultBundleSummary
        }
        try validateResultBundleSummary(resultBundleSummary, metrics: resultBundleMetrics)
        guard let resultBundleTestContract = submission.resultBundleTestContract else {
            throw ValidationFailure.missingResultBundleTestContract
        }
        try validateResultBundleTestContract(resultBundleTestContract, for: runbook)
        guard let manifestSnapshotSHA256 = submission.manifestSnapshotSHA256,
              !manifestSnapshotSHA256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationFailure.missingManifestSnapshotSHA256
        }
        guard isSHA256(manifestSnapshotSHA256) else {
            throw ValidationFailure.invalidSHA256(field: "manifestSnapshotSHA256")
        }
        guard isSHA256(submission.hashedDeviceIdentifier) else {
            throw ValidationFailure.invalidSHA256(field: "hashedDeviceIdentifier")
        }
        let missingArtifacts = runbook.expectedArtifacts.filter {
            !submission.providedArtifactIDs.contains($0)
        }
        guard missingArtifacts.isEmpty else {
            throw ValidationFailure.missingExpectedArtifacts(missingArtifacts)
        }
        guard !submission.reviewerEvidence.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }).isEmpty else {
            throw ValidationFailure.missingReviewerEvidence
        }
        if let retainedPlaceholder = forbiddenTemplatePlaceholder(in: submission) {
            throw ValidationFailure.templatePlaceholderRetained(
                field: retainedPlaceholder.field,
                marker: retainedPlaceholder.marker
            )
        }
        guard submission.capturedAt >= minimumPhysicalProofCapturedAt else {
            throw ValidationFailure.capturedAtBeforePhysicalLabWindow(submission.capturedAt)
        }
        guard submission.capturedAt <= Date().addingTimeInterval(futureCaptureTolerance) else {
            throw ValidationFailure.capturedAtInFuture(submission.capturedAt)
        }
        guard let resultBundleTiming = submission.resultBundleTiming else {
            throw ValidationFailure.missingResultBundleTiming
        }
        try validateResultBundleTiming(
            resultBundleTiming,
            capturedAt: submission.capturedAt,
            metrics: resultBundleMetrics
        )
        guard let attachmentManifest = submission.attachmentManifest else {
            throw ValidationFailure.missingAttachmentManifest
        }
        try validateAttachmentManifest(
            attachmentManifest,
            for: runbook,
            metrics: resultBundleMetrics,
            resultBundleFilename: submission.resultBundleFilename,
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: resultBundleTiming
        )
        guard isIPhoneModelIdentifier(submission.deviceModelIdentifier) else {
            throw ValidationFailure.deviceModelIdentifierNotIPhone(submission.deviceModelIdentifier)
        }
        guard isIOSBuildLabel(submission.iosBuild) else {
            throw ValidationFailure.invalidIOSBuildLabel(submission.iosBuild)
        }
        guard let resultBundleDevice = submission.resultBundleDevice else {
            throw ValidationFailure.missingResultBundleDeviceMetadata
        }
        try validateResultBundleDevice(
            resultBundleDevice,
            submissionIOSBuild: submission.iosBuild
        )
        if let forbiddenMarker = forbiddenPrivacyMarker(in: submission) {
            throw ValidationFailure.privacyBoundaryViolation(forbiddenMarker)
        }
        let missingReviewerEvidenceDescriptors = missingReviewerEvidenceDescriptors(
            in: submission.reviewerEvidence,
            for: runbook
        )
        guard missingReviewerEvidenceDescriptors.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingScenarioDescriptors(missingReviewerEvidenceDescriptors)
        }
        let capturedAtTimestamp = capturedAtEvidenceTimestamp(submission.capturedAt)
        guard reviewerEvidenceContains(capturedAtTimestamp, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingCapturedAtTimestamp(capturedAtTimestamp)
        }
        guard reviewerEvidenceContains(submission.resultBundleFilename, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleFilename(submission.resultBundleFilename)
        }
        guard reviewerEvidenceContains(submission.resultBundleSHA256, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleSHA256(submission.resultBundleSHA256)
        }
        guard reviewerEvidenceContains(resultBundleSummarySHA256, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleSummarySHA256(resultBundleSummarySHA256)
        }
        let missingSummaryTokens = missingReviewerEvidenceResultBundleSummaryTokens(
            for: resultBundleSummary,
            in: submission.reviewerEvidence
        )
        guard missingSummaryTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleSummary(missingSummaryTokens)
        }
        guard reviewerEvidenceContains(submission.hashedDeviceIdentifier, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingHashedDeviceIdentifier(submission.hashedDeviceIdentifier)
        }
        guard reviewerEvidenceContains(submission.deviceModelIdentifier, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingDeviceModelIdentifier(submission.deviceModelIdentifier)
        }
        guard reviewerEvidenceContains(submission.iosBuild, in: submission.reviewerEvidence) else {
            throw ValidationFailure.reviewerEvidenceMissingIOSBuild(submission.iosBuild)
        }
        let missingMetricsTokens = missingReviewerEvidenceMetricsTokens(
            for: resultBundleMetrics,
            in: submission.reviewerEvidence
        )
        guard missingMetricsTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleMetrics(missingMetricsTokens)
        }
        let missingTestContractTokens = missingReviewerEvidenceTestContractTokens(
            for: resultBundleTestContract,
            in: submission.reviewerEvidence
        )
        guard missingTestContractTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleTestContract(missingTestContractTokens)
        }
        let missingTimingTokens = missingReviewerEvidenceTimingTokens(
            for: resultBundleTiming,
            in: submission.reviewerEvidence
        )
        guard missingTimingTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleTiming(missingTimingTokens)
        }
        let missingDeviceTokens = missingReviewerEvidenceResultBundleDeviceTokens(
            for: resultBundleDevice,
            in: submission.reviewerEvidence
        )
        guard missingDeviceTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingResultBundleDeviceMetadata(missingDeviceTokens)
        }
        let missingAttachmentContextTokens = missingReviewerEvidenceAttachmentManifestContextTokens(
            for: attachmentManifest,
            in: submission.reviewerEvidence
        )
        guard missingAttachmentContextTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingAttachmentManifestContext(missingAttachmentContextTokens)
        }
        let missingAttachmentTokens = missingReviewerEvidenceAttachmentManifestTokens(
            for: attachmentManifest,
            in: submission.reviewerEvidence
        )
        guard missingAttachmentTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingAttachmentManifest(missingAttachmentTokens)
        }
        let missingAttachmentByteCountTokens = missingReviewerEvidenceAttachmentManifestByteCountTokens(
            for: attachmentManifest,
            in: submission.reviewerEvidence
        )
        guard missingAttachmentByteCountTokens.isEmpty else {
            throw ValidationFailure.reviewerEvidenceMissingAttachmentManifestByteCounts(missingAttachmentByteCountTokens)
        }
        return runbook
    }

    private static func validateResultBundleMetrics(
        _ metrics: BracketerPhysicalResultBundleMetrics
    ) throws {
        guard metrics.totalTestCount > 0 else {
            throw ValidationFailure.invalidResultBundleMetrics("totalTestCount must be greater than 0")
        }
        guard metrics.passedTests == metrics.totalTestCount else {
            throw ValidationFailure.invalidResultBundleMetrics("passedTests must equal totalTestCount")
        }
        guard metrics.failedTests == 0 else {
            throw ValidationFailure.invalidResultBundleMetrics("failedTests must equal 0")
        }
        guard metrics.durationMilliseconds > 0 else {
            throw ValidationFailure.invalidResultBundleMetrics("durationMilliseconds must be greater than 0")
        }
        guard metrics.attachmentByteCount > 0 else {
            throw ValidationFailure.invalidResultBundleMetrics("attachmentByteCount must be greater than 0")
        }
    }

    private static func validateResultBundleSummary(
        _ summary: BracketerPhysicalResultBundleSummary,
        metrics: BracketerPhysicalResultBundleMetrics
    ) throws {
        guard summary.status == .passed else {
            throw ValidationFailure.invalidResultBundleSummary("status must equal Passed")
        }
        guard isTrimmedNonEmpty(summary.title) else {
            throw ValidationFailure.invalidResultBundleSummary("title is required")
        }
        guard summary.totalTestCount > 0 else {
            throw ValidationFailure.invalidResultBundleSummary("totalTestCount must be greater than 0")
        }
        guard summary.passedTestCount >= 0 else {
            throw ValidationFailure.invalidResultBundleSummary("passedTestCount must not be negative")
        }
        guard summary.failedTestCount >= 0 else {
            throw ValidationFailure.invalidResultBundleSummary("failedTestCount must not be negative")
        }
        guard summary.expectedFailureCount >= 0 else {
            throw ValidationFailure.invalidResultBundleSummary("expectedFailureCount must not be negative")
        }
        guard summary.skippedTestCount >= 0 else {
            throw ValidationFailure.invalidResultBundleSummary("skippedTestCount must not be negative")
        }
        guard summary.passedTestCount == summary.totalTestCount else {
            throw ValidationFailure.invalidResultBundleSummary("passedTestCount must equal totalTestCount")
        }
        guard summary.failedTestCount == 0 else {
            throw ValidationFailure.invalidResultBundleSummary("failedTestCount must equal 0")
        }
        guard summary.expectedFailureCount == 0 else {
            throw ValidationFailure.invalidResultBundleSummary("expectedFailureCount must equal 0")
        }
        guard summary.skippedTestCount == 0 else {
            throw ValidationFailure.invalidResultBundleSummary("skippedTestCount must equal 0")
        }
        guard summary.totalTestCount == metrics.totalTestCount else {
            throw ValidationFailure.resultBundleSummaryMetricsMismatch(
                field: "totalTestCount",
                summaryCount: summary.totalTestCount,
                metricsCount: metrics.totalTestCount
            )
        }
        guard summary.passedTestCount == metrics.passedTests else {
            throw ValidationFailure.resultBundleSummaryMetricsMismatch(
                field: "passedTests",
                summaryCount: summary.passedTestCount,
                metricsCount: metrics.passedTests
            )
        }
        guard summary.failedTestCount == metrics.failedTests else {
            throw ValidationFailure.resultBundleSummaryMetricsMismatch(
                field: "failedTests",
                summaryCount: summary.failedTestCount,
                metricsCount: metrics.failedTests
            )
        }
    }

    private static func validateResultBundleTestContract(
        _ contract: BracketerPhysicalResultBundleTestContract,
        for runbook: BracketerPhysicalCaptureRunbook
    ) throws {
        guard isTrimmedNonEmpty(contract.xcodebuildVersion) else {
            throw ValidationFailure.invalidResultBundleTestContract("xcodebuildVersion is required")
        }
        guard contract.xcodebuildVersion.lowercased().contains("xcode"),
              containsASCIIDigit(contract.xcodebuildVersion) else {
            throw ValidationFailure.invalidResultBundleTestContract("xcodebuildVersion must come from xcodebuild -version")
        }
        guard isTrimmedNonEmpty(contract.xcresulttoolVersion) else {
            throw ValidationFailure.invalidResultBundleTestContract("xcresulttoolVersion is required")
        }
        guard contract.xcresulttoolVersion.lowercased().contains("xcresulttool"),
              containsASCIIDigit(contract.xcresulttoolVersion) else {
            throw ValidationFailure.invalidResultBundleTestContract("xcresulttoolVersion must come from xcresulttool --version")
        }
        guard isTrimmedNonEmpty(contract.testPlanConfigurationName) else {
            throw ValidationFailure.invalidResultBundleTestContract("testPlanConfigurationName is required")
        }
        guard isTrimmedNonEmpty(contract.testIdentifier) else {
            throw ValidationFailure.invalidResultBundleTestContract("testIdentifier is required")
        }
        let normalizedIdentifier = alphanumericLowercase(contract.testIdentifier)
        let normalizedScenario = alphanumericLowercase(runbook.id)
        guard normalizedIdentifier.contains(normalizedScenario) else {
            throw ValidationFailure.invalidResultBundleTestContract("testIdentifier must include scenario id \(runbook.id)")
        }
        guard isTrimmedNonEmpty(contract.testName) else {
            throw ValidationFailure.invalidResultBundleTestContract("testName is required")
        }
    }

    private static func validateResultBundleTiming(
        _ timing: BracketerPhysicalResultBundleTiming,
        capturedAt: Date,
        metrics: BracketerPhysicalResultBundleMetrics
    ) throws {
        guard timing.summaryStartTime >= minimumPhysicalProofCapturedAt else {
            throw ValidationFailure.invalidResultBundleTiming("summaryStartTime must be on or after the physical lab window")
        }
        guard timing.summaryFinishTime > timing.summaryStartTime else {
            throw ValidationFailure.invalidResultBundleTiming("summaryFinishTime must be after summaryStartTime")
        }
        guard timing.testStartTime >= timing.summaryStartTime else {
            throw ValidationFailure.invalidResultBundleTiming("testStartTime must be on or after summaryStartTime")
        }
        guard timing.testFinishTime > timing.testStartTime else {
            throw ValidationFailure.invalidResultBundleTiming("testFinishTime must be after testStartTime")
        }
        guard timing.testFinishTime <= timing.summaryFinishTime else {
            throw ValidationFailure.invalidResultBundleTiming("testFinishTime must be on or before summaryFinishTime")
        }
        guard timing.summaryFinishTime <= Date().addingTimeInterval(futureCaptureTolerance) else {
            throw ValidationFailure.invalidResultBundleTiming("summaryFinishTime cannot be in the future beyond the ingest tolerance")
        }
        guard capturedAt >= timing.testStartTime && capturedAt <= timing.testFinishTime else {
            throw ValidationFailure.invalidResultBundleTiming("capturedAt must fall inside result-bundle test window")
        }
        let expectedDurationMilliseconds = Int(
            (timing.testFinishTime.timeIntervalSince(timing.testStartTime) * 1000).rounded()
        )
        guard metrics.durationMilliseconds == expectedDurationMilliseconds else {
            throw ValidationFailure.resultBundleTimingDurationMismatch(
                expectedMilliseconds: expectedDurationMilliseconds,
                metricsMilliseconds: metrics.durationMilliseconds
            )
        }
    }

    private static func validateResultBundleDevice(
        _ device: BracketerPhysicalResultBundleDevice,
        submissionIOSBuild: String
    ) throws {
        let modelName = device.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("modelName is required")
        }
        guard modelName.lowercased().contains("iphone") else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("modelName must describe an iPhone device")
        }
        let platform = device.platform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !platform.isEmpty else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("platform is required")
        }
        let normalizedPlatform = platform.lowercased()
        guard normalizedPlatform.contains("ios") else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("platform must describe iOS")
        }
        guard !normalizedPlatform.contains("simulator") else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("platform must describe physical iOS, not iOS Simulator")
        }
        let labels = [
            device.osVersion,
            device.osBuildNumber
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !labels.isEmpty else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("osVersion or osBuildNumber is required")
        }
        let submittedBuild = submissionIOSBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        guard labels.contains(submittedBuild) else {
            throw ValidationFailure.invalidResultBundleDeviceMetadata("osVersion or osBuildNumber must match submission iOS build")
        }
    }

    private static func validateAttachmentManifest(
        _ manifest: BracketerPhysicalAttachmentManifest,
        for runbook: BracketerPhysicalCaptureRunbook,
        metrics: BracketerPhysicalResultBundleMetrics,
        resultBundleFilename: String,
        resultBundleTestContract: BracketerPhysicalResultBundleTestContract,
        resultBundleTiming: BracketerPhysicalResultBundleTiming
    ) throws {
        guard manifest.resultBundleFilename == resultBundleFilename else {
            throw ValidationFailure.invalidAttachmentManifestContext("resultBundleFilename must match the submitted result-bundle filename")
        }
        guard manifest.resultBundleTestIdentifier == resultBundleTestContract.testIdentifier else {
            throw ValidationFailure.invalidAttachmentManifestContext("resultBundleTestIdentifier must match the signed result-bundle test identifier")
        }
        guard manifest.testStartTime == resultBundleTiming.testStartTime else {
            throw ValidationFailure.invalidAttachmentManifestContext("testStartTime must match result-bundle timing metadata")
        }
        guard manifest.testFinishTime == resultBundleTiming.testFinishTime else {
            throw ValidationFailure.invalidAttachmentManifestContext("testFinishTime must match result-bundle timing metadata")
        }
        guard !manifest.artifactSHA256ByID.isEmpty else {
            throw ValidationFailure.invalidAttachmentManifest("artifactSHA256ByID must not be empty")
        }
        let expectedIDs = Set(runbook.expectedArtifacts)
        let providedIDs = Set(manifest.artifactSHA256ByID.keys)
        let missingIDs = runbook.expectedArtifacts.filter { !providedIDs.contains($0) }
        guard missingIDs.isEmpty else {
            throw ValidationFailure.invalidAttachmentManifest("missing expected artifact hashes: \(missingIDs.joined(separator: ", "))")
        }
        let unexpectedIDs = providedIDs.subtracting(expectedIDs).sorted()
        guard unexpectedIDs.isEmpty else {
            throw ValidationFailure.invalidAttachmentManifest("unexpected artifact ids: \(unexpectedIDs.joined(separator: ", "))")
        }
        for artifactID in runbook.expectedArtifacts {
            guard let digest = manifest.artifactSHA256ByID[artifactID],
                  isSHA256(digest) else {
                throw ValidationFailure.invalidAttachmentManifest("artifact \(artifactID) must have a SHA-256 hex digest")
            }
        }
        guard !manifest.artifactByteCountByID.isEmpty else {
            throw ValidationFailure.invalidAttachmentManifestByteCounts("artifactByteCountByID must not be empty")
        }
        let providedByteCountIDs = Set(manifest.artifactByteCountByID.keys)
        let missingByteCountIDs = runbook.expectedArtifacts.filter { !providedByteCountIDs.contains($0) }
        guard missingByteCountIDs.isEmpty else {
            throw ValidationFailure.invalidAttachmentManifestByteCounts("missing expected artifact byte counts: \(missingByteCountIDs.joined(separator: ", "))")
        }
        let unexpectedByteCountIDs = providedByteCountIDs.subtracting(expectedIDs).sorted()
        guard unexpectedByteCountIDs.isEmpty else {
            throw ValidationFailure.invalidAttachmentManifestByteCounts("unexpected artifact byte-count ids: \(unexpectedByteCountIDs.joined(separator: ", "))")
        }
        for artifactID in runbook.expectedArtifacts {
            guard let byteCount = manifest.artifactByteCountByID[artifactID],
                  byteCount > 0 else {
                throw ValidationFailure.invalidAttachmentManifestByteCounts("artifact \(artifactID) must have a positive byte count")
            }
        }
        let manifestByteCount = runbook.expectedArtifacts.reduce(0) { total, artifactID in
            total + (manifest.artifactByteCountByID[artifactID] ?? 0)
        }
        guard manifestByteCount == metrics.attachmentByteCount else {
            throw ValidationFailure.attachmentManifestByteCountMismatch(
                expectedBytes: metrics.attachmentByteCount,
                manifestBytes: manifestByteCount
            )
        }
    }

    private static func isTrimmedNonEmpty(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == value && !trimmed.isEmpty
    }

    private static func containsASCIIDigit(_ value: String) -> Bool {
        value.contains { character in
            ("0"..."9").contains(character)
        }
    }

    private static func isSingleResultBundleFilename(_ filename: String) -> Bool {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == filename
            && trimmed.hasSuffix(".xcresult")
            && !trimmed.contains("/")
            && !trimmed.contains("\\")
            && !trimmed.isEmpty
    }

    private static func isScenarioResultBundleFilename(
        _ filename: String,
        for runbook: BracketerPhysicalCaptureRunbook
    ) -> Bool {
        let expectedPrefix = expectedResultBundlePrefix(for: runbook)
        let rerunPrefix = "\(expectedPrefix)-"
        return filename == "\(expectedPrefix).xcresult"
            || (
                filename.hasPrefix(rerunPrefix)
                    && filename.count > rerunPrefix.count + ".xcresult".count
            )
    }

    private static func expectedResultBundlePrefix(
        for runbook: BracketerPhysicalCaptureRunbook
    ) -> String {
        let canonicalFilename = URL(fileURLWithPath: runbook.resultBundlePath).lastPathComponent
        return String(canonicalFilename.dropLast(".xcresult".count))
    }

    private static func isIPhoneModelIdentifier(_ identifier: String) -> Bool {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == identifier, identifier.hasPrefix("iPhone") else {
            return false
        }
        let suffix = identifier.dropFirst("iPhone".count)
        let parts = suffix.split(separator: ",", omittingEmptySubsequences: false)
        return parts.count == 2 && parts.allSatisfy(isASCIIDigits)
    }

    private static func isIOSBuildLabel(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == label else {
            return false
        }
        return isDottedIOSVersion(label) || isAppleBuildNumber(label)
    }

    private static func isDottedIOSVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return (2...3).contains(parts.count) && parts.allSatisfy(isASCIIDigits)
    }

    private static func isAppleBuildNumber(_ value: String) -> Bool {
        let characters = Array(value)
        guard characters.count >= 4,
              characters.prefix(2).allSatisfy({ ("0"..."9").contains($0) }),
              ("A"..."Z").contains(characters[2]) else {
            return false
        }
        var index = 3
        let digitStartIndex = index
        while index < characters.count,
              ("0"..."9").contains(characters[index]) {
            index += 1
        }
        guard index > digitStartIndex else {
            return false
        }
        if index == characters.count {
            return true
        }
        return index == characters.count - 1
            && ("a"..."z").contains(characters[index])
    }

    private static func isASCIIDigits(_ value: Substring) -> Bool {
        !value.isEmpty && value.allSatisfy { character in
            ("0"..."9").contains(character)
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { character in
            ("0"..."9").contains(character)
                || ("a"..."f").contains(character)
                || ("A"..."F").contains(character)
        }
    }

    private static func alphanumericLowercase(_ value: String) -> String {
        value
            .lowercased()
            .filter { character in
                ("a"..."z").contains(character) || ("0"..."9").contains(character)
            }
    }

    private static func forbiddenPrivacyMarker(
        in submission: BracketerPhysicalProofSubmission
    ) -> String? {
        let searchableValues = [
            submission.scenarioID,
            submission.resultBundleFilename,
            submission.xcodeDestination,
            submission.deviceModelIdentifier,
            submission.iosBuild,
            submission.lensID,
            submission.notes
        ]
            .compactMap { $0 }
            + submission.providedArtifactIDs
            + submission.reviewerEvidence

        let joined = searchableValues.joined(separator: " ").lowercased()
        return [
            "phasset.localidentifier",
            "localidentifier",
            "photoslocalidentifier",
            "rawimagebytes",
            "imagebytes",
            "thumbnailpixels",
            "decodedrawdata",
            "precisecoordinates",
            "latitude:",
            "longitude:"
        ].first { joined.contains($0) }
    }

    private static func missingReviewerEvidenceDescriptors(
        in reviewerEvidence: [String],
        for runbook: BracketerPhysicalCaptureRunbook
    ) -> [String] {
        let normalizedEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: " ")
        return runbook.evidenceSteps.filter { evidenceStep in
            !normalizedEvidence.contains(normalizedReviewerEvidenceText(evidenceStep))
        }
    }

    private static func normalizedReviewerEvidenceText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func reviewerEvidenceContains(
        _ expectedTimestamp: String,
        in reviewerEvidence: [String]
    ) -> Bool {
        let searchableEvidence = reviewerEvidence
            .joined(separator: " ")
            .lowercased()
        return searchableEvidence.contains(expectedTimestamp.lowercased())
    }

    private static func reviewerEvidenceContainsPassingResultBundleSummary(
        _ reviewerEvidence: [String]
    ) -> Bool {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return compactEvidence.contains("result=passed")
            && compactEvidence.contains("failedtests=0")
    }

    private static func missingReviewerEvidenceResultBundleSummaryTokens(
        for summary: BracketerPhysicalResultBundleSummary,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return summary.reviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceMetricsTokens(
        for metrics: BracketerPhysicalResultBundleMetrics,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return metrics.reviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceTestContractTokens(
        for contract: BracketerPhysicalResultBundleTestContract,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return contract.reviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceTimingTokens(
        for timing: BracketerPhysicalResultBundleTiming,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return timing.reviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceResultBundleDeviceTokens(
        for device: BracketerPhysicalResultBundleDevice,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return device.reviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceAttachmentManifestTokens(
        for manifest: BracketerPhysicalAttachmentManifest,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return manifest.artifactReviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceAttachmentManifestByteCountTokens(
        for manifest: BracketerPhysicalAttachmentManifest,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return manifest.artifactByteCountReviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func missingReviewerEvidenceAttachmentManifestContextTokens(
        for manifest: BracketerPhysicalAttachmentManifest,
        in reviewerEvidence: [String]
    ) -> [String] {
        let compactEvidence = reviewerEvidence
            .map(normalizedReviewerEvidenceText)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
        return manifest.contextReviewerEvidenceTokens.filter { token in
            !compactEvidenceContainsDelimitedToken(token, in: compactEvidence)
        }
    }

    private static func compactEvidenceContainsDelimitedToken(
        _ token: String,
        in compactEvidence: String
    ) -> Bool {
        var searchStart = compactEvidence.startIndex
        while let range = compactEvidence.range(
            of: token,
            options: [],
            range: searchStart..<compactEvidence.endIndex
        ) {
            let hasLeadingBoundary = range.lowerBound == compactEvidence.startIndex
                || isCompactEvidenceTokenBoundary(compactEvidence[compactEvidence.index(before: range.lowerBound)])
            let hasTrailingBoundary = range.upperBound == compactEvidence.endIndex
                || isCompactEvidenceTokenBoundary(compactEvidence[range.upperBound])
            if hasLeadingBoundary && hasTrailingBoundary {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }

    private static func isCompactEvidenceTokenBoundary(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first else {
            return true
        }
        let value = scalar.value
        let isLowercaseLetter = value >= 97 && value <= 122
        let isDigit = value >= 48 && value <= 57
        let isDot = value == 46
        let isEquals = value == 61
        return !(isLowercaseLetter || isDigit || isDot || isEquals)
    }

    private static func capturedAtEvidenceTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func forbiddenTemplatePlaceholder(
        in submission: BracketerPhysicalProofSubmission
    ) -> (field: String, marker: String)? {
        let optionalValues: [(field: String, value: String?)] = [
            ("scenarioID", submission.scenarioID),
            ("resultBundleFilename", submission.resultBundleFilename),
            ("resultBundleSummarySHA256", submission.resultBundleSummarySHA256),
            ("resultBundleSummary.title", submission.resultBundleSummary?.title),
            ("resultBundleTestContract.xcodebuildVersion", submission.resultBundleTestContract?.xcodebuildVersion),
            ("resultBundleTestContract.xcresulttoolVersion", submission.resultBundleTestContract?.xcresulttoolVersion),
            ("resultBundleTestContract.testPlanConfigurationName", submission.resultBundleTestContract?.testPlanConfigurationName),
            ("resultBundleTestContract.testIdentifier", submission.resultBundleTestContract?.testIdentifier),
            ("resultBundleTestContract.testName", submission.resultBundleTestContract?.testName),
            ("resultBundleDevice.modelName", submission.resultBundleDevice?.modelName),
            ("resultBundleDevice.osVersion", submission.resultBundleDevice?.osVersion),
            ("resultBundleDevice.osBuildNumber", submission.resultBundleDevice?.osBuildNumber),
            ("resultBundleDevice.platform", submission.resultBundleDevice?.platform),
            ("attachmentManifest.resultBundleFilename", submission.attachmentManifest?.resultBundleFilename),
            ("attachmentManifest.resultBundleTestIdentifier", submission.attachmentManifest?.resultBundleTestIdentifier),
            ("xcodeDestination", submission.xcodeDestination),
            ("deviceModelIdentifier", submission.deviceModelIdentifier),
            ("hashedDeviceIdentifier", submission.hashedDeviceIdentifier),
            ("iosBuild", submission.iosBuild),
            ("lensID", submission.lensID),
            ("manifestSnapshotSHA256", submission.manifestSnapshotSHA256),
            ("notes", submission.notes)
        ]

        let values = optionalValues.compactMap { field, value in
            guard let value else { return nil }
            return (field, value)
        }
            + submission.providedArtifactIDs.enumerated().map { index, value in
                ("providedArtifactIDs[\(index)]", value)
            }
            + (submission.attachmentManifest?.artifactSHA256ByID.sorted { $0.key < $1.key }.map { artifactID, digest in
                ("attachmentManifest[\(artifactID)]", digest)
            } ?? [])
            + submission.reviewerEvidence.enumerated().map { index, value in
                ("reviewerEvidence[\(index)]", value)
            }

        let markers = [
            (needle: "replace_with_", marker: "REPLACE_WITH_"),
            (needle: "replace_after_physical_run", marker: "REPLACE_AFTER_PHYSICAL_RUN"),
            (needle: "<device-udid>", marker: "<DEVICE-UDID>")
        ]

        for (field, value) in values {
            let lowercased = value.lowercased()
            if let match = markers.first(where: { lowercased.contains($0.needle) }) {
                return (field, match.marker)
            }
        }
        return nil
    }

    private static func notes(for submission: BracketerPhysicalProofSubmission) -> String {
        [
            submission.notes,
            submission.lensID.map { "Lens: \($0)" },
            "Artifacts: \(submission.providedArtifactIDs.joined(separator: ", "))",
            "Evidence: \(submission.reviewerEvidence.joined(separator: " | "))"
        ]
            .compactMap { $0 }
            .joined(separator: " | ")
    }
}

extension BracketerPhysicalCaptureRunbook {
    func replacingRecordedProof(
        _ proof: BracketerPhysicalCaptureRunbook.RecordedProof
    ) -> BracketerPhysicalCaptureRunbook {
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
            recordedProofs: [proof]
        )
    }
}

extension BracketerPhysicalCaptureRunbookCatalog {
    func replacingRunbook(
        _ runbook: BracketerPhysicalCaptureRunbook
    ) -> BracketerPhysicalCaptureRunbookCatalog {
        BracketerPhysicalCaptureRunbookCatalog(
            schemaVersion: schemaVersion,
            runbooks: runbooks.map { $0.id == runbook.id ? runbook : $0 },
            privacyBoundary: privacyBoundary
        )
    }
}

extension BracketerPhysicalResultBundleIndex {
    func replacingScenarioEntry(
        _ entry: BracketerPhysicalResultBundleIndex.Entry
    ) -> BracketerPhysicalResultBundleIndex {
        BracketerPhysicalResultBundleIndex(
            schemaVersion: schemaVersion,
            expectedScenarioIDs: expectedScenarioIDs,
            entries: entries.filter { $0.scenarioID != entry.scenarioID } + [entry],
            privacyBoundary: privacyBoundary
        )
    }
}
