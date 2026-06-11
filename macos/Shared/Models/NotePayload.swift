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
    let errorMessage: String?

    static func from(note: NotePayload) -> WidgetSharedState {
        WidgetSharedState(
            version: 1,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            status: note.status,
            title: note.title,
            summary: note.summary,
            filePath: note.filePath,
            parentFolder: note.parentFolder,
            nextRefreshAt: note.nextRefreshAt,
            errorMessage: note.errorMessage
        )
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
