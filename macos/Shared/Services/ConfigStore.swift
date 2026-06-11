import Foundation

@MainActor
final class ConfigStore: ObservableObject {
    @Published private(set) var config: AppConfig

    private let fileManager = FileManager.default

    init() {
        config = Self.loadConfigFromDisk()
    }

    var settings: WidgetSettings {
        Self.widgetSettings(from: config)
    }

    func reload() {
        config = Self.loadConfigFromDisk()
    }

    func update(_ partial: SettingsUpdate) -> WidgetSettings {
        var next = config

        if let includedSubfolders = partial.includedSubfolders {
            next.includedSubfolders = includedSubfolders
        }

        if let refreshIntervalHours = partial.refreshIntervalHours {
            next.refreshIntervalHours = refreshIntervalHours
        }

        if let contentView = partial.contentView {
            next.contentView = contentView
        }

        if let fontSizePx = partial.fontSizePx {
            next.fontSizePx = Self.normalizeFontSizePx(fontSizePx)
        }

        save(next)
        return settings
    }

    func setVaultFolder(_ vaultFolderPath: String) {
        var next = config
        next.vaultFolderPath = Self.expandPath(vaultFolderPath)
        next.includedSubfolders = []
        next.lastPickAt = nil
        next.currentFilePath = nil
        save(next)
    }

    func updateConfig(_ mutate: (inout AppConfig) -> Void) {
        var next = config
        mutate(&next)
        save(next)
    }

    func save(_ next: AppConfig) {
        config = next
        Self.saveConfigToDisk(next)
    }

    nonisolated static func userDataDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("obsidian-widget", isDirectory: true)
    }

    nonisolated static func configPath() -> URL {
        userDataDirectory().appendingPathComponent("config.json")
    }

    nonisolated static func refreshIntervalMs(for config: AppConfig) -> TimeInterval {
        TimeInterval(config.refreshIntervalHours * 60 * 60)
    }

    nonisolated static func summaryCacheDirectory(for config: AppConfig) -> URL {
        let cacheDir: URL
        if config.summaryCacheDir.hasPrefix(".") {
            cacheDir = userDataDirectory().appendingPathComponent(config.summaryCacheDir, isDirectory: true)
        } else {
            cacheDir = URL(fileURLWithPath: expandPath(config.summaryCacheDir), isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }

    nonisolated static func widgetSettings(from config: AppConfig) -> WidgetSettings {
        let availableSubfolders: [String]
        if let vaultPath = VaultAccess.beginAccess(configVaultPath: config.vaultFolderPath) {
            availableSubfolders = VaultScanner.listSubfolders(vaultPath: vaultPath)
        } else {
            availableSubfolders = []
        }

        return WidgetSettings(
            vaultFolderPath: config.vaultFolderPath,
            includedSubfolders: config.includedSubfolders,
            refreshIntervalHours: config.refreshIntervalHours,
            contentView: config.contentView,
            fontSizePx: config.fontSizePx,
            availableSubfolders: availableSubfolders
        )
    }

    nonisolated private static func loadConfigFromDisk() -> AppConfig {
        let path = configPath()
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let parsed = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            saveConfigToDisk(AppConfig.defaults)
            return AppConfig.defaults
        }

        var merged = AppConfig.defaults
        merged.vaultFolderPath = expandPath(parsed.vaultFolderPath.isEmpty ? AppConfig.defaultVaultPath : parsed.vaultFolderPath)
        merged.includedSubfolders = parsed.includedSubfolders
        merged.refreshIntervalHours = parsed.refreshIntervalHours
        merged.contentView = parsed.contentView == .original ? .original : .summary
        merged.fontSizePx = normalizeFontSizePx(parsed.fontSizePx)
        merged.claudeBinary = parsed.claudeBinary.isEmpty ? AppConfig.defaults.claudeBinary : parsed.claudeBinary
        merged.summaryCacheDir = expandPath(parsed.summaryCacheDir.isEmpty ? AppConfig.defaults.summaryCacheDir : parsed.summaryCacheDir)
        merged.lastPickAt = parsed.lastPickAt
        merged.currentFilePath = parsed.currentFilePath
        return merged
    }

    nonisolated private static func saveConfigToDisk(_ config: AppConfig) {
        let directory = userDataDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configPath())
        }
    }

    nonisolated private static func expandPath(_ inputPath: String) -> String {
        guard !inputPath.isEmpty else { return "" }
        if inputPath.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(inputPath.dropFirst(2)))
                .path
        }
        return inputPath
    }

    nonisolated private static func normalizeFontSizePx(_ value: Int) -> Int {
        min(AppConfig.maxFontSizePx, max(AppConfig.minFontSizePx, value))
    }
}
