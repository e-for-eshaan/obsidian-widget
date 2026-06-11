import CryptoKit
import Foundation

enum VaultScanner {
    private static let skipDirs: Set<String> = [".obsidian", ".git", ".trash", "templates", "node_modules"]

    static func listSubfolders(vaultPath: String) -> [String] {
        let vaultURL = URL(fileURLWithPath: vaultPath)
        guard FileManager.default.fileExists(atPath: vaultPath) else { return [] }

        var folders: [String] = []
        if let entries = try? FileManager.default.contentsOfDirectory(at: vaultURL, includingPropertiesForKeys: nil) {
            let hasRootMarkdown = entries.contains { url in
                url.pathExtension.lowercased() == "md" && !url.hasDirectoryPath
            }
            if hasRootMarkdown {
                folders.append("(root)")
            }
        }

        folders.append(contentsOf: collectFolderPaths(currentDir: vaultURL, relativePrefix: ""))

        return folders.sorted { left, right in
            if left == "(root)" { return true }
            if right == "(root)" { return false }
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }

    static func listMarkdownFiles(vaultPath: String, includedSubfolders: [String]) -> [String] {
        collectMarkdownFiles(rootDir: vaultPath)
            .filter { filePath in
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                      let fileSize = attrs[.size] as? NSNumber,
                      fileSize.intValue > 0 else {
                    return false
                }

                let relativePath = relativePath(from: vaultPath, to: filePath)
                return isFileIncluded(relativePath: relativePath, includedSubfolders: includedSubfolders)
            }
    }

    static func pickRandomMarkdownFile(
        vaultPath: String,
        includedSubfolders: [String],
        excluding excludePath: String?
    ) -> String? {
        let files = listMarkdownFiles(vaultPath: vaultPath, includedSubfolders: includedSubfolders)
        guard !files.isEmpty else { return nil }

        let candidates = excludePath.map { exclude in files.filter { $0 != exclude } } ?? files
        let pool = candidates.isEmpty ? files : candidates
        return pool.randomElement()
    }

    static func readMarkdownNote(vaultPath: String, filePath: String) -> MarkdownNote {
        let rawContent = (try? String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)) ?? ""
        let content = stripFrontmatter(rawContent)
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

        return MarkdownNote(
            filePath: filePath,
            relativePath: relativePath(from: vaultPath, to: filePath),
            title: extractTitle(from: content, filePath: filePath),
            content: content,
            mtimeMs: mtime
        )
    }

    static func parentFolder(relativePath: String) -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard let lastSlash = normalized.lastIndex(of: "/") else {
            return "(root)"
        }
        return String(normalized[..<lastSlash])
    }

    static func contentHash(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func summaryCacheKey(for filePath: String) -> String {
        contentHash(for: filePath)
    }

    private static func shouldSkipDir(_ name: String) -> Bool {
        name.hasPrefix(".") || skipDirs.contains(name)
    }

    private static func normalizePath(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func isFileIncluded(relativePath: String, includedSubfolders: [String]) -> Bool {
        if includedSubfolders.isEmpty { return true }

        let normalizedPath = normalizePath(relativePath)
        return includedSubfolders.contains { folder in
            let normalizedFolder = normalizePath(folder)
            if normalizedFolder == "(root)" {
                return !normalizedPath.contains("/")
            }
            return normalizedPath == normalizedFolder || normalizedPath.hasPrefix("\(normalizedFolder)/")
        }
    }

    private static func collectMarkdownFiles(rootDir: String, currentDir: String? = nil) -> [String] {
        let directory = currentDir ?? rootDir
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }

        var files: [String] = []
        for entry in entries {
            let fullPath = (directory as NSString).appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                if !shouldSkipDir(entry) {
                    files.append(contentsOf: collectMarkdownFiles(rootDir: rootDir, currentDir: fullPath))
                }
            } else if entry.lowercased().hasSuffix(".md") {
                files.append(fullPath)
            }
        }

        return files
    }

    private static func collectFolderPaths(currentDir: URL, relativePrefix: String) -> [String] {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: currentDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        var folders: [String] = []
        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if shouldSkipDir(entry.lastPathComponent) { continue }

            let relPath = relativePrefix.isEmpty ? entry.lastPathComponent : "\(relativePrefix)/\(entry.lastPathComponent)"
            folders.append(relPath)
            folders.append(contentsOf: collectFolderPaths(currentDir: entry, relativePrefix: relPath))
        }

        return folders
    }

    private static func stripFrontmatter(_ content: String) -> String {
        guard content.hasPrefix("---\n") else { return content.trimmingCharacters(in: .whitespacesAndNewlines) }

        let searchStart = content.index(content.startIndex, offsetBy: 4)
        guard searchStart < content.endIndex,
              let closingRange = content.range(of: "\n---\n", range: searchStart..<content.endIndex) else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(content[closingRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractTitle(from content: String, filePath: String) -> String {
        let pattern = "^#\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ((filePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    static func relativePath(from vaultPath: String, to filePath: String) -> String {
        URL(fileURLWithPath: filePath)
            .path
            .replacingOccurrences(of: URL(fileURLWithPath: vaultPath).path + "/", with: "")
    }
}
