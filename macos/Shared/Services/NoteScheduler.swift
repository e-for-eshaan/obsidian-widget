import Foundation

@MainActor
final class NoteScheduler: ObservableObject {
    @Published private(set) var currentNote: NotePayload?
    @Published private(set) var isRefreshing = false

    private let configStore: ConfigStore
    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?

    init(configStore: ConfigStore) {
        self.configStore = configStore
        currentNote = emptyLoadingNote()
    }

    func start() {
        _ = VaultAccess.beginAccess(configVaultPath: configStore.config.vaultFolderPath)
        Task { @MainActor in
            await refresh(forceNewPick: false, bypassCache: false)
            scheduleNext()
        }
    }

    func refreshNow() {
        runRefresh(forceNewPick: true, bypassCache: false)
    }

    func forceRefreshNow() {
        runRefresh(forceNewPick: true, bypassCache: true)
    }

    func regenerateSummary() {
        guard !isRefreshing else { return }

        let config = configStore.config
        guard !config.vaultFolderPath.isEmpty,
              let filePath = config.currentFilePath,
              FileManager.default.fileExists(atPath: filePath) else {
            return
        }

        runLoadNote(at: filePath, bypassCache: true, updateLastPick: false)
    }

    func loadNote(_ filePath: String) {
        guard !isRefreshing else { return }

        let config = configStore.config
        guard !config.vaultFolderPath.isEmpty,
              FileManager.default.fileExists(atPath: filePath) else {
            return
        }

        runLoadNote(at: filePath, bypassCache: false, updateLastPick: false)
    }

    func resolveWikiLink(_ target: String) -> String? {
        let config = configStore.config
        guard let vaultPath = VaultAccess.beginAccess(configVaultPath: config.vaultFolderPath) else { return nil }

        let vaultFiles = VaultScanner.listMarkdownFiles(
            vaultPath: vaultPath,
            includedSubfolders: config.includedSubfolders
        )

        return RelatedNotesResolver.resolveWikiLinkTarget(
            vaultFolderPath: vaultPath,
            target: target,
            vaultFiles: vaultFiles
        )
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
    }

    private func runRefresh(forceNewPick: Bool, bypassCache: Bool) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            await refresh(forceNewPick: forceNewPick, bypassCache: bypassCache)
            scheduleNext()
        }
    }

    private func runLoadNote(at filePath: String, bypassCache: Bool, updateLastPick: Bool) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            isRefreshing = true
            defer { isRefreshing = false }

            let config = configStore.config
            do {
                try await loadNoteAtPath(
                    filePath,
                    vaultPath: VaultAccess.beginAccess(configVaultPath: config.vaultFolderPath) ?? config.vaultFolderPath,
                    bypassCache: bypassCache,
                    updateLastPick: updateLastPick
                )
            } catch {
                publishEmptyState(
                    status: .error,
                    title: "Summary failed",
                    summary: error.localizedDescription,
                    filePath: filePath,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    private func refresh(forceNewPick: Bool, bypassCache: Bool) async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        let config = configStore.config

        guard let vaultPath = VaultAccess.beginAccess(configVaultPath: config.vaultFolderPath),
              !vaultPath.isEmpty else {
            publishEmptyState(
                status: .needsSetup,
                title: "Obsidian Widget",
                summary: "Choose an Obsidian folder below or from the menu bar tray."
            )
            return
        }

        publishLoadingState()

        do {
            let shouldPickNew = forceNewPick || isRefreshDue(config)
            let filePath: String?

            if shouldPickNew {
                filePath = VaultScanner.pickRandomMarkdownFile(
                    vaultPath: vaultPath,
                    includedSubfolders: config.includedSubfolders,
                    excluding: config.currentFilePath
                )
            } else if let currentFilePath = config.currentFilePath,
                      FileManager.default.fileExists(atPath: currentFilePath) {
                filePath = currentFilePath
            } else {
                filePath = VaultScanner.pickRandomMarkdownFile(
                    vaultPath: vaultPath,
                    includedSubfolders: config.includedSubfolders,
                    excluding: nil
                )
            }

            guard let selectedPath = filePath else {
                if !VaultAccess.hasStoredBookmark() {
                    publishEmptyState(
                        status: .needsSetup,
                        title: "Obsidian Widget",
                        summary: "Choose your vault folder again (Settings → Browse) to grant read access.",
                        errorMessage: "Sandbox requires vault folder selection in this app."
                    )
                } else {
                    publishEmptyState(
                        status: .error,
                        title: "No notes found",
                        summary: "No markdown files were found in the selected folder.",
                        errorMessage: "Vault folder has no readable .md files."
                    )
                }
                return
            }

            try await loadNoteAtPath(
                selectedPath,
                vaultPath: vaultPath,
                bypassCache: bypassCache,
                updateLastPick: shouldPickNew || config.lastPickAt == nil
            )
        } catch {
            publishEmptyState(
                status: .error,
                title: "Summary failed",
                summary: error.localizedDescription,
                filePath: config.currentFilePath ?? "",
                errorMessage: error.localizedDescription
            )
        }
    }

    private func loadNoteAtPath(_ filePath: String, vaultPath: String, bypassCache: Bool, updateLastPick: Bool) async throws {
        let config = configStore.config
        let note = VaultScanner.readMarkdownNote(vaultPath: vaultPath, filePath: filePath)
        publishNoteAwaitingSummary(note)

        let summaryResult = try await SummaryService.summarizeNote(
            config: config,
            title: note.title,
            content: note.content,
            filePath: note.filePath,
            bypassCache: bypassCache
        )

        let vaultFiles = VaultScanner.listMarkdownFiles(
            vaultPath: vaultPath,
            includedSubfolders: config.includedSubfolders
        )

        let relatedNotes = RelatedNotesResolver.resolveRelatedNoteTitles(
            vaultFolderPath: vaultPath,
            titles: summaryResult.relatedNotes.map(\.title),
            vaultFiles: vaultFiles,
            excludeFilePath: note.filePath
        )

        configStore.updateConfig { next in
            if updateLastPick {
                next.lastPickAt = ISO8601DateFormatter().string(from: Date())
            }
            next.currentFilePath = filePath
        }

        publish(NotePayload(
            title: note.title,
            summary: summaryResult.summary,
            content: note.content,
            relativePath: note.relativePath,
            filePath: note.filePath,
            parentFolder: VaultScanner.parentFolder(relativePath: note.relativePath),
            relatedNotes: relatedNotes,
            nextRefreshAt: nextRefreshAt().ISO8601Format(),
            status: .ready
        ))
    }

    private func scheduleNext() {
        refreshTimer?.invalidate()

        let config = configStore.config
        let interval = ConfigStore.refreshIntervalMs(for: config)
        let lastPickAt = config.lastPickAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        let elapsed = Date().timeIntervalSince(lastPickAt)
        let delay = max(interval - elapsed, 0)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh(forceNewPick: true, bypassCache: false)
                self?.scheduleNext()
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func isRefreshDue(_ config: AppConfig) -> Bool {
        guard let lastPickAt = config.lastPickAt,
              let date = ISO8601DateFormatter().date(from: lastPickAt) else {
            return true
        }

        return Date().timeIntervalSince(date) >= ConfigStore.refreshIntervalMs(for: config)
    }

    private func nextRefreshAt() -> Date {
        let config = configStore.config
        let lastPickAt = config.lastPickAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        return lastPickAt.addingTimeInterval(ConfigStore.refreshIntervalMs(for: config))
    }

    private func publish(_ note: NotePayload) {
        currentNote = note
        WidgetStateWriter.syncWidgetState(from: note, fontSizePx: configStore.config.fontSizePx)
    }

    private func publishLoadingState() {
        publish(NotePayload(
            title: "Loading note…",
            summary: "Picking a random note from your vault.",
            content: "",
            relativePath: "",
            filePath: "",
            parentFolder: "",
            relatedNotes: [],
            nextRefreshAt: nextRefreshAt().ISO8601Format(),
            status: .loading
        ))
    }

    private func publishNoteAwaitingSummary(_ note: MarkdownNote) {
        publish(NotePayload(
            title: note.title,
            summary: "Generating summary…",
            content: note.content,
            relativePath: note.relativePath,
            filePath: note.filePath,
            parentFolder: VaultScanner.parentFolder(relativePath: note.relativePath),
            relatedNotes: [],
            nextRefreshAt: nextRefreshAt().ISO8601Format(),
            status: .loading
        ))
    }

    private func publishEmptyState(
        status: WidgetStatus,
        title: String,
        summary: String,
        filePath: String = "",
        errorMessage: String? = nil
    ) {
        publish(NotePayload(
            title: title,
            summary: summary,
            content: "",
            relativePath: "",
            filePath: filePath,
            parentFolder: "",
            relatedNotes: [],
            nextRefreshAt: nextRefreshAt().ISO8601Format(),
            status: status,
            errorMessage: errorMessage
        ))
    }

    private func emptyLoadingNote() -> NotePayload {
        NotePayload(
            title: "Obsidian Widget",
            summary: "Loading your note…",
            content: "",
            relativePath: "",
            filePath: "",
            parentFolder: "",
            relatedNotes: [],
            nextRefreshAt: Date().ISO8601Format(),
            status: .loading
        )
    }
}
