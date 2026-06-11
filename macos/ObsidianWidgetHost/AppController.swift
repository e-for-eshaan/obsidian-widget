import AppKit
import SwiftUI

@MainActor
final class AppController: ObservableObject {
    static weak var shared: AppController?

    @Published var settingsOpen = false
    @Published var pendingMainWindowOpen = false

    let configStore: ConfigStore
    let scheduler: NoteScheduler
    let navigation: NoteNavigation

    init() {
        let configStore = ConfigStore()
        self.configStore = configStore
        self.scheduler = NoteScheduler(configStore: configStore)
        self.navigation = NoteNavigation()
        Self.shared = self
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        _ = VaultAccess.beginAccess(configVaultPath: configStore.config.vaultFolderPath)
        scheduler.start()
    }

    private var didBootstrap = false

    func bootstrap() {
        bootstrapIfNeeded()
    }

    func chooseVaultFolder() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Vault"
        panel.message = "Select your Obsidian vault folder"
        panel.directoryURL = vaultDirectoryHint()

        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                guard response == .OK, let url = panel.url else { return }

                try? VaultAccess.storeBookmark(for: url)

                self.configStore.setVaultFolder(url.path)
                self.navigation.clearHistory()
                self.scheduler.refreshNow()
            }
        }
    }

    private func vaultDirectoryHint() -> URL? {
        let path = configStore.config.vaultFolderPath
        guard !path.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        return URL(fileURLWithPath: path)
    }

    func requestMainWindowOpen() {
        if pendingMainWindowOpen { return }
        pendingMainWindowOpen = true
    }

    func clearPendingMainWindowOpen() {
        pendingMainWindowOpen = false
    }

    func openNoteViewer() {
        requestMainWindowOpen()
    }

    func openInObsidian(filePath: String) {
        guard !filePath.isEmpty else { return }

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: filePath)]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    func openCurrentNoteInObsidian() {
        if let filePath = scheduler.currentNote?.filePath {
            openInObsidian(filePath: filePath)
        }
    }

    func updateSettings(_ partial: SettingsUpdate) {
        _ = configStore.update(partial)
    }

    func toggleSubfolder(_ folder: String) {
        let included = configStore.config.includedSubfolders
        let nextIncluded = included.contains(folder)
            ? included.filter { $0 != folder }
            : included + [folder]

        updateSettings(SettingsUpdate(includedSubfolders: nextIncluded))
    }
}
