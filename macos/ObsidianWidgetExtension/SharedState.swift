import Foundation

enum WidgetStatus: String, Codable {
    case loading
    case ready
    case error
    case needsSetup
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

    static let placeholder = WidgetSharedState(
        version: 1,
        updatedAt: ISO8601DateFormatter().string(from: Date()),
        status: .needsSetup,
        title: "Obsidian Widget",
        summary: "Open the menu bar app and choose your vault folder.",
        filePath: "",
        parentFolder: "",
        nextRefreshAt: ISO8601DateFormatter().string(from: Date()),
        fontSizePx: 11,
        errorMessage: nil
    )

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

enum SharedStateReader {
    static func load() -> WidgetSharedState {
        guard let url = AppGroup.stateFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return .placeholder
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(WidgetSharedState.self, from: data)
        } catch {
            return WidgetSharedState(
                version: 1,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                status: .error,
                title: "Obsidian Widget",
                summary: "Could not read widget state.",
                filePath: "",
                parentFolder: "",
                nextRefreshAt: ISO8601DateFormatter().string(from: Date()),
                fontSizePx: 11,
                errorMessage: error.localizedDescription
            )
        }
    }

    static func parseBullets(from summary: String, limit: Int) -> [String] {
        summary
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("- ") {
                    return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if trimmed.hasPrefix("• ") {
                    return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return trimmed.isEmpty ? nil : trimmed
            }
            .prefix(limit)
            .map { String($0) }
    }

    static func obsidianURL(for filePath: String) -> URL? {
        guard !filePath.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "path", value: filePath),
        ]
        return components.url
    }

    static func nextRefreshDate(from state: WidgetSharedState) -> Date {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: state.nextRefreshAt) {
            return date
        }
        return Date().addingTimeInterval(900)
    }
}
