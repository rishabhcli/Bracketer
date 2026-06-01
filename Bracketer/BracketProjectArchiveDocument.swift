import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum BracketProjectArchiveDocumentError: LocalizedError, Equatable, Sendable {
    case missingRegularFile
    case unreadableUTF8(filename: String)

    var errorDescription: String? {
        switch self {
        case .missingRegularFile:
            return "The selected Bracketer project archive is not a regular file."
        case .unreadableUTF8(let filename):
            return "\(filename) is not a readable UTF-8 Bracketer project archive."
        }
    }
}

struct BracketProjectArchiveDocument: FileDocument, Equatable, Sendable {
    static var readableContentTypes: [UTType] { [.plainText, .json] }
    static var writableContentTypes: [UTType] { [.plainText] }

    let archiveText: String
    let filename: String
    let importBundle: BracketProjectImportBundle

    init(
        bundle: BracketProjectExportBundle,
        importedAt: Date = Date()
    ) throws {
        try self.init(
            archiveText: bundle.archiveText,
            filename: bundle.archiveFilename,
            importedAt: importedAt
        )
    }

    init(
        data: Data,
        filename: String = "bracketer-project.txt",
        importedAt: Date = Date()
    ) throws {
        guard let archiveText = String(data: data, encoding: .utf8) else {
            throw BracketProjectArchiveDocumentError.unreadableUTF8(filename: filename)
        }
        try self.init(
            archiveText: archiveText,
            filename: filename,
            importedAt: importedAt
        )
    }

    init(
        archiveText: String,
        filename: String = "bracketer-project.txt",
        importedAt: Date = Date()
    ) throws {
        self.archiveText = archiveText
        self.filename = filename
        self.importBundle = try BracketProjectImportBundle.parse(
            archiveText: archiveText,
            importedAt: importedAt
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BracketProjectArchiveDocumentError.missingRegularFile
        }
        try self.init(
            data: data,
            filename: configuration.file.preferredFilename ?? "bracketer-project.txt"
        )
    }

    var data: Data {
        Data(archiveText.utf8)
    }

    var accessibilityValue: String {
        [
            "Bracketer Project Archive Document",
            filename,
            importBundle.project.displayTitle,
            "\(importBundle.payloadKinds.count) payloads",
            importBundle.project.privacy.accessibilityValue,
            importBundle.finalOutputActionPlanSummary.map { "Final output action plan: \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = filename
        return wrapper
    }
}
