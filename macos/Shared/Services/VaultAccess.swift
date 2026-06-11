import Foundation

enum VaultAccess {
    private static var scopedURL: URL?
    private static var isAccessingResource = false

    static var activeVaultPath: String? {
        scopedURL?.path
    }

    static func beginAccess(configVaultPath: String) -> String? {
        endAccess()

        if let url = resolveStoredBookmark() {
            scopedURL = url
            isAccessingResource = url.startAccessingSecurityScopedResource()
            return url.path
        }

        guard !configVaultPath.isEmpty else { return nil }

        scopedURL = URL(fileURLWithPath: configVaultPath)
        return configVaultPath
    }

    static func storeBookmark(for url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let bookmarkURL = bookmarkFileURL()
        try FileManager.default.createDirectory(
            at: bookmarkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bookmark.write(to: bookmarkURL)

        endAccess()
        scopedURL = url
        isAccessingResource = url.startAccessingSecurityScopedResource()

        // #region agent log
        DebugSessionLog.write(
            hypothesisId: "H-sandbox",
            location: "VaultAccess.swift:storeBookmark",
            message: "Stored vault bookmark",
            data: [
                "path": url.path,
                "accessGranted": String(isAccessingResource),
            ],
            runId: "vault-fix"
        )
        // #endregion
    }

    static func hasStoredBookmark() -> Bool {
        FileManager.default.fileExists(atPath: bookmarkFileURL().path)
    }

    static func endAccess() {
        if isAccessingResource, let scopedURL {
            scopedURL.stopAccessingSecurityScopedResource()
        }
        isAccessingResource = false
        scopedURL = nil
    }

    private static func bookmarkFileURL() -> URL {
        ConfigStore.userDataDirectory().appendingPathComponent("vault.bookmark")
    }

    private static func resolveStoredBookmark() -> URL? {
        let bookmarkURL = bookmarkFileURL()
        guard FileManager.default.fileExists(atPath: bookmarkURL.path),
              let data = try? Data(contentsOf: bookmarkURL) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale, let refreshed = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            try? refreshed.write(to: bookmarkURL)
        }

        return url
    }
}
