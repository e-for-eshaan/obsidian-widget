import Foundation

enum ContentView: String, Codable {
    case summary
    case original
}

struct AppConfig: Codable, Equatable {
    var vaultFolderPath: String
    var includedSubfolders: [String]
    var refreshIntervalHours: Int
    var contentView: ContentView
    var fontSizePx: Int
    var claudeBinary: String
    var summaryCacheDir: String
    var lastPickAt: String?
    var currentFilePath: String?

    static let defaultVaultPath =
        "/Users/eshaanyadav/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mind"

    static let defaults = AppConfig(
        vaultFolderPath: defaultVaultPath,
        includedSubfolders: [],
        refreshIntervalHours: 4,
        contentView: .summary,
        fontSizePx: 11,
        claudeBinary: "claude",
        summaryCacheDir: ".cache/summaries",
        lastPickAt: nil,
        currentFilePath: nil
    )

    static let minFontSizePx = 9
    static let maxFontSizePx = 16
}

struct WidgetSettings: Equatable {
    var vaultFolderPath: String
    var includedSubfolders: [String]
    var refreshIntervalHours: Int
    var contentView: ContentView
    var fontSizePx: Int
    var availableSubfolders: [String]
}

struct SettingsUpdate {
    var includedSubfolders: [String]?
    var refreshIntervalHours: Int?
    var contentView: ContentView?
    var fontSizePx: Int?
}
