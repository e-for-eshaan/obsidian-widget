import Foundation

enum DebugSessionLog {
    private static let sessionId = "d3133d"
    private static let workspaceLogPath = "/Users/eshaanyadav/Desktop/MyProjects/obsidian-widget/.cursor/debug-d3133d.log"
    private static let appSupportLogPath: String = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("obsidian-widget/debug-d3133d.log").path
    }()

    static func write(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String] = [:],
        runId: String = "pre-fix"
    ) {
        // #region agent log
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: jsonData, encoding: .utf8) else {
            return
        }

        appendLine(line, to: workspaceLogPath)
        appendLine(line, to: appSupportLogPath)
        postToIngest(jsonData)
        // #endregion
    }

    private static func appendLine(_ line: String, to path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            handle.seekToEndOfFile()
            if let data = (line + "\n").data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        }
    }

    private static func postToIngest(_ jsonData: Data) {
        guard let url = URL(string: "http://127.0.0.1:7832/ingest/f7cbcc4c-edc2-4a93-8774-b4019823c7ce") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request).resume()
    }
}
