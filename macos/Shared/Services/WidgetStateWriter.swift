import Foundation

enum WidgetStateWriter {
    static func syncWidgetState(from note: NotePayload, fontSizePx: Int) {
        writeWidgetState(WidgetSharedState.from(note: note, fontSizePx: fontSizePx))
        reloadNativeWidget()
    }

    static func writeWidgetState(_ state: WidgetSharedState) {
        guard let data = try? JSONEncoder().encode(state),
              let payload = String(data: data, encoding: .utf8) else {
            return
        }

        for containerPath in appGroupContainerPaths() {
            try? FileManager.default.createDirectory(at: containerPath, withIntermediateDirectories: true)
            let statePath = containerPath.appendingPathComponent(AppGroup.stateFileName)
            let tempPath = containerPath.appendingPathComponent("\(AppGroup.stateFileName).tmp")

            do {
                try payload.write(to: tempPath, atomically: true, encoding: .utf8)
                if FileManager.default.fileExists(atPath: statePath.path) {
                    try FileManager.default.removeItem(at: statePath)
                }
                try FileManager.default.moveItem(at: tempPath, to: statePath)
            } catch {
                continue
            }
        }
    }

    static func reloadNativeWidget() {
        guard let helperPath = widgetReloadHelperPath() else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: helperPath)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
    }

    private static func widgetReloadHelperPath() -> String? {
        let bundledPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/WidgetReload")
            .path

        if FileManager.default.isExecutableFile(atPath: bundledPath) {
            return bundledPath
        }

        let devPath = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("WidgetReload")
            .path

        if FileManager.default.isExecutableFile(atPath: devPath) {
            return devPath
        }

        let buildPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/Release/WidgetReload")
            .path

        if FileManager.default.isExecutableFile(atPath: buildPath) {
            return buildPath
        }

        return nil
    }

    private static func appGroupContainerPaths() -> [URL] {
        var paths = Set<URL>()

        let groupContainersRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers", isDirectory: true)

        paths.insert(groupContainersRoot.appendingPathComponent(AppGroup.groupSuffix, isDirectory: true))

        for candidate in AppGroup.containerIdentifierCandidates() {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) {
                paths.insert(url)
            }
        }

        if let entries = try? FileManager.default.contentsOfDirectory(atPath: groupContainersRoot.path) {
            for entry in entries where entry.contains(AppGroup.groupSuffix) {
                paths.insert(groupContainersRoot.appendingPathComponent(entry, isDirectory: true))
            }
        }

        return Array(paths)
    }
}
