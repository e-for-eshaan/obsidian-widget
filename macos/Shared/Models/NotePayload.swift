import Foundation

enum WidgetStatus: String, Codable {
    case loading
    case ready
    case error
    case needsSetup
}

struct RelatedNote: Codable, Equatable, Identifiable {
    var id: String { filePath }
    let title: String
    let filePath: String
}

struct NotePayload: Equatable {
    var title: String
    var summary: String
    var content: String
    var relativePath: String
    var filePath: String
    var parentFolder: String
    var relatedNotes: [RelatedNote]
    var nextRefreshAt: String
    var status: WidgetStatus
    var errorMessage: String?
}

struct WidgetSharedState: Codable {
    let version: Int
    let updatedAt: String
    let status: WidgetStatus
    let title: String
    let summary: String
    let filePath: String
    let parentFolder: String
    let nextRefreshAt: String
    let fontSizePx: Int
    let errorMessage: String?

    static func from(note: NotePayload, fontSizePx: Int) -> WidgetSharedState {
        WidgetSharedState(
            version: 1,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            status: note.status,
            title: note.title,
            summary: note.summary,
            filePath: note.filePath,
            parentFolder: note.parentFolder,
            nextRefreshAt: note.nextRefreshAt,
            fontSizePx: fontSizePx,
            errorMessage: note.errorMessage
        )
    }

    init(
        version: Int,
        updatedAt: String,
        status: WidgetStatus,
        title: String,
        summary: String,
        filePath: String,
        parentFolder: String,
        nextRefreshAt: String,
        fontSizePx: Int = 11,
        errorMessage: String?
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.status = status
        self.title = title
        self.summary = summary
        self.filePath = filePath
        self.parentFolder = parentFolder
        self.nextRefreshAt = nextRefreshAt
        self.fontSizePx = fontSizePx
        self.errorMessage = errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        status = try container.decode(WidgetStatus.self, forKey: .status)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        filePath = try container.decode(String.self, forKey: .filePath)
        parentFolder = try container.decode(String.self, forKey: .parentFolder)
        nextRefreshAt = try container.decode(String.self, forKey: .nextRefreshAt)
        fontSizePx = try container.decodeIfPresent(Int.self, forKey: .fontSizePx) ?? 11
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}

struct MarkdownNote {
    let filePath: String
    let relativePath: String
    let title: String
    let content: String
    let mtimeMs: TimeInterval
}

struct NoteSummaryResult {
    let summary: String
    let relatedNotes: [LlmRelatedNote]
}

struct LlmRelatedNote: Codable {
    let title: String
}
