import Foundation

enum RelatedNotesResolver {
    private static let maxRelated = 8

    private struct FileLookup {
        var byBasename: [String: String] = [:]
        var byRelativePath: [String: String] = [:]
        var byTitle: [String: String] = [:]
    }

    static func resolveWikiLinkTarget(
        vaultFolderPath: String,
        target: String,
        vaultFiles: [String]
    ) -> String? {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !vaultFiles.isEmpty else { return nil }

        let lookup = buildFileLookup(vaultFolderPath: vaultFolderPath, files: vaultFiles)
        let fileTarget = trimmed.split(separator: "#", maxSplits: 1).first.map(String.init) ?? trimmed
        return resolveNoteTarget(fileTarget, lookup: lookup)
    }

    static func resolveRelatedNoteTitles(
        vaultFolderPath: String,
        titles: [String],
        vaultFiles: [String],
        excludeFilePath: String?
    ) -> [RelatedNote] {
        guard !titles.isEmpty, !vaultFiles.isEmpty else { return [] }

        let lookup = buildFileLookup(vaultFolderPath: vaultFolderPath, files: vaultFiles)
        var relatedByPath: [String: RelatedNote] = [:]

        for title in titles {
            guard let resolvedPath = resolveNoteTarget(title, lookup: lookup),
                  resolvedPath != excludeFilePath,
                  relatedByPath[resolvedPath] == nil else {
                continue
            }

            let note = VaultScanner.readMarkdownNote(vaultPath: vaultFolderPath, filePath: resolvedPath)
            relatedByPath[resolvedPath] = RelatedNote(title: note.title, filePath: note.filePath)

            if relatedByPath.count >= maxRelated {
                break
            }
        }

        return Array(relatedByPath.values)
    }

    private static func normalizeKey(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func buildFileLookup(vaultFolderPath: String, files: [String]) -> FileLookup {
        var lookup = FileLookup()

        for filePath in files {
            let relativePath = VaultScanner.relativePath(from: vaultFolderPath, to: filePath)
            let basenameKey = normalizeKey((filePath as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "", options: .caseInsensitive))
            let relativeKey = normalizeKey(relativePath.replacingOccurrences(of: ".md", with: "", options: .caseInsensitive))

            if lookup.byBasename[basenameKey] == nil {
                lookup.byBasename[basenameKey] = filePath
            }

            lookup.byRelativePath[relativeKey] = filePath

            let note = VaultScanner.readMarkdownNote(vaultPath: vaultFolderPath, filePath: filePath)
            let titleKey = normalizeKey(note.title)
            if lookup.byTitle[titleKey] == nil {
                lookup.byTitle[titleKey] = filePath
            }
        }

        return lookup
    }

    private static func resolveNoteTarget(_ target: String, lookup: FileLookup) -> String? {
        let normalized = normalizeKey(target)

        if let relativeMatch = lookup.byRelativePath[normalized] {
            return relativeMatch
        }

        if let titleMatch = lookup.byTitle[normalized] {
            return titleMatch
        }

        let baseSegment = normalized.split(separator: "/").last.map(String.init) ?? normalized
        return lookup.byBasename[baseSegment]
    }
}
