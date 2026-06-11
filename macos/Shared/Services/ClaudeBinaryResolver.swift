import Foundation

enum ClaudeBinaryResolver {
    static func resolve(configuredBinary: String) -> URL? {
        let trimmed = configuredBinary.trimmingCharacters(in: .whitespacesAndNewlines)
        let binaryName = trimmed.isEmpty ? "claude" : trimmed

        if binaryName.hasPrefix("/") || binaryName.hasPrefix("~/") {
            if let resolved = resolvedExecutableURL(for: expandPath(binaryName)) {
                return resolved
            }
        }

        for candidate in candidatePaths(for: binaryName) {
            if let resolved = resolvedExecutableURL(for: candidate) {
                return resolved
            }
        }

        // #region agent log
        DebugSessionLog.write(
            hypothesisId: "H-claude-sandbox",
            location: "ClaudeBinaryResolver.swift:resolve",
            message: "Claude binary not resolved",
            data: probeReport(for: binaryName),
            runId: "claude-fix-2"
        )
        // #endregion

        return nil
    }

    static func augmentedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extra = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin"
        let currentPath = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = currentPath.contains("/opt/homebrew/bin") ? currentPath : "\(currentPath):\(extra)"
        environment["CC_HEADLESS"] = "1"
        return environment
    }

    private static func candidatePaths(for binaryName: String) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let directories = pathEntries + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
        ]

        var seen = Set<String>()
        return directories.compactMap { directory in
            guard !directory.isEmpty, seen.insert(directory).inserted else { return nil }
            return (directory as NSString).appendingPathComponent(binaryName)
        }
    }

    private static func resolvedExecutableURL(for path: String) -> URL? {
        let fileManager = FileManager.default
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path

        guard fileManager.fileExists(atPath: resolvedPath) else { return nil }

        if fileManager.isExecutableFile(atPath: resolvedPath) {
            return URL(fileURLWithPath: resolvedPath)
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory),
           !isDirectory.boolValue,
           fileManager.isReadableFile(atPath: resolvedPath) {
            return URL(fileURLWithPath: resolvedPath)
        }

        return nil
    }

    private static func probeReport(for binaryName: String) -> [String: String] {
        let fileManager = FileManager.default
        let probes = candidatePaths(for: binaryName).prefix(6).map { candidate -> String in
            let resolved = URL(fileURLWithPath: candidate).resolvingSymlinksInPath().path
            let exists = fileManager.fileExists(atPath: resolved)
            let executable = fileManager.isExecutableFile(atPath: resolved)
            let readable = fileManager.isReadableFile(atPath: resolved)
            return "\(resolved)|exists:\(exists)|exec:\(executable)|read:\(readable)"
        }
        return [
            "configuredBinary": binaryName,
            "probes": probes.joined(separator: " ; "),
        ]
    }

    private static func expandPath(_ inputPath: String) -> String {
        if inputPath.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(inputPath.dropFirst(2)))
                .path
        }
        return inputPath
    }
}
