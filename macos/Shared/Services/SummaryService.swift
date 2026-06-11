import Foundation

enum SummaryService {
    private static let summaryTimeoutSeconds: TimeInterval = 120
    private static let maxLlmRelatedNotes = 8

    private struct CachedNoteSummary: Codable {
        let contentHash: String
        let summary: String
        let relatedNotes: [LlmRelatedNote]
    }

    static func summarizeNote(
        config: AppConfig,
        title: String,
        content: String,
        filePath: String,
        bypassCache: Bool = false
    ) async throws -> NoteSummaryResult {
        let cacheDir = ConfigStore.summaryCacheDirectory(for: config)
        let contentHash = VaultScanner.contentHash(for: content)
        let cacheKey = VaultScanner.summaryCacheKey(for: filePath)

        if !bypassCache, let cached = readCachedSummary(cacheDir: cacheDir, cacheKey: cacheKey, contentHash: contentHash) {
            return NoteSummaryResult(
                summary: SummaryFormat.formatSummaryBullets(cached.summary),
                relatedNotes: cached.relatedNotes
            )
        }

        let rawResponse = try await runClaude(config: config, prompt: buildPrompt(title: title, content: content))
        let result = parseSummaryResponse(rawResponse)

        guard !isUnparseableSummary(result.summary) else {
            throw SummaryServiceError.cliFailed(
                "Summary could not be parsed from Claude response. Use Regenerate summary in settings."
            )
        }

        writeCachedSummary(
            cacheDir: cacheDir,
            cacheKey: cacheKey,
            result: CachedNoteSummary(
                contentHash: contentHash,
                summary: result.summary,
                relatedNotes: result.relatedNotes
            )
        )
        return result
    }

    private static func buildPrompt(title: String, content: String) -> String {
        let trimmedContent = String(content.prefix(12_000))
        return [
            "Return a single JSON object and nothing else — no preamble, no explanation, no markdown fences.",
            #"{"summary":"- First short point\n- Second short point\n- Third short point","relatedNotes":[{"title":"..."}]}"#,
            "",
            "Rules:",
            "- summary: Markdown bullet list ONLY. Every line must start with \"- \". Use 2-5 bullets. Keep each bullet under 12 words.",
            "- relatedNotes: up to \(maxLlmRelatedNotes) notes linked via [[wiki links]] in the note or clearly related. Use exact note titles from the note body.",
            "- If none apply, return \"relatedNotes\":[]",
            "- Do not mention permissions, vault access, or that you cannot read files.",
            "",
            "Note title: \(title)",
            "",
            trimmedContent,
        ].joined(separator: "\n")
    }

    private static func readCachedSummary(cacheDir: URL, cacheKey: String, contentHash: String) -> CachedNoteSummary? {
        let cachePath = cacheDir.appendingPathComponent("\(cacheKey).json")
        guard FileManager.default.fileExists(atPath: cachePath.path),
              let data = try? Data(contentsOf: cachePath),
              let parsed = try? JSONDecoder().decode(CachedNoteSummary.self, from: data),
              !parsed.summary.isEmpty,
              !isUnparseableSummary(parsed.summary),
              parsed.contentHash == contentHash else {
            return nil
        }

        return normalizeCachedSummary(parsed)
    }

    private static func writeCachedSummary(cacheDir: URL, cacheKey: String, result: CachedNoteSummary) {
        let cachePath = cacheDir.appendingPathComponent("\(cacheKey).json")
        if let data = try? JSONEncoder().encode(result) {
            try? data.write(to: cachePath)
        }
    }

    private static func normalizeCachedSummary(_ cached: CachedNoteSummary) -> CachedNoteSummary {
        if !looksLikeMalformedSummary(cached.summary) {
            return cached
        }

        let repaired = parseSummaryResponse(cached.summary)
        return CachedNoteSummary(
            contentHash: cached.contentHash,
            summary: repaired.summary,
            relatedNotes: repaired.relatedNotes.isEmpty ? cached.relatedNotes : repaired.relatedNotes
        )
    }

    private static func looksLikeMalformedSummary(_ summary: String) -> Bool {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.contains("\"summary\":") || trimmed.contains("\"relatedNotes\":")
    }

    private static func isUnparseableSummary(_ summary: String) -> Bool {
        summary == "Summary could not be parsed. Use Regenerate summary in settings."
    }

    private static func parseSummaryResponse(_ raw: String) -> NoteSummaryResult {
        var candidates = Set<String>()
        candidates.insert(extractJsonPayload(raw))

        if let embedded = findEmbeddedJsonObject(raw) {
            candidates.insert(embedded)
        }

        for candidate in candidates {
            if let parsed = tryParseSummaryJson(candidate) {
                return parsed
            }
        }

        let stripped = raw.replacingOccurrences(of: #"\{[\s\S]*\}"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !stripped.isEmpty {
            return NoteSummaryResult(
                summary: SummaryFormat.formatSummaryBullets(stripped),
                relatedNotes: []
            )
        }

        return NoteSummaryResult(
            summary: "Summary could not be parsed. Use Regenerate summary in settings.",
            relatedNotes: []
        )
    }

    private static func tryParseSummaryJson(_ jsonText: String) -> NoteSummaryResult? {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }

        if let parsed = try? JSONDecoder().decode(PartialSummaryResponse.self, from: data),
           let summary = parsed.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            return NoteSummaryResult(
                summary: SummaryFormat.formatSummaryBullets(summary),
                relatedNotes: normalizeRelatedNotes(parsed.relatedNotes)
            )
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summaryValue = object["summary"] as? String else {
            return nil
        }

        let summary = summaryValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return nil }

        let relatedNotes = normalizeRelatedNotesFromAny(object["relatedNotes"])
        return NoteSummaryResult(
            summary: SummaryFormat.formatSummaryBullets(summary),
            relatedNotes: relatedNotes
        )
    }

    private static func normalizeRelatedNotesFromAny(_ value: Any?) -> [LlmRelatedNote] {
        guard let entries = value as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let title = entry["title"] as? String else { return nil }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : LlmRelatedNote(title: trimmed)
        }
        .prefix(maxLlmRelatedNotes)
        .map { $0 }
    }

    private struct PartialSummaryResponse: Decodable {
        let summary: String?
        let relatedNotes: [LlmRelatedNote]?
    }

    private static func normalizeRelatedNotes(_ value: [LlmRelatedNote]?) -> [LlmRelatedNote] {
        guard let value else { return [] }
        return value
            .map { LlmRelatedNote(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.title.isEmpty }
            .prefix(maxLlmRelatedNotes)
            .map { $0 }
    }

    private static func extractJsonPayload(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"```(?:json)?\s*([\s\S]*?)\s*```"#, options: .regularExpression) {
            let match = String(trimmed[range])
            let inner = match
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty { return inner }
        }

        if let embedded = findEmbeddedJsonObject(trimmed) {
            return embedded
        }

        return trimmed
    }

    private static func findEmbeddedJsonObject(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false

        var index = start
        while index < text.endIndex {
            let char = text[index]

            if escaped {
                escaped = false
            } else if char == "\\" && inString {
                escaped = true
            } else if char == "\"" {
                inString.toggle()
            } else if !inString {
                if char == "{" { depth += 1 }
                if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    private struct ClaudeCliResponse: Decodable {
        let is_error: Bool?
        let result: String?
    }

    private static func extractClaudeStdout(_ stdout: String) throws -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(ClaudeCliResponse.self, from: data) else {
            return trimmed
        }

        if wrapper.is_error == true {
            let message = wrapper.result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw SummaryServiceError.cliFailed(
                message.isEmpty ? "Claude CLI returned an error response." : message
            )
        }

        if let result = wrapper.result?.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty {
            return result
        }

        return trimmed
    }

    private static func runClaude(config: AppConfig, prompt: String) async throws -> String {
        guard ClaudeUsageLimiter.canMakeCall() else {
            throw SummaryServiceError.dailyLimitReached(
                remaining: ClaudeUsageLimiter.remainingCallsToday,
                limit: ClaudeUsageLimiter.maxDailyCalls
            )
        }

        guard let executableURL = ClaudeBinaryResolver.resolve(configuredBinary: config.claudeBinary) else {
            throw SummaryServiceError.cliFailed(
                "Claude CLI not found. Install it or set claudeBinary in config.json to its full path (e.g. /opt/homebrew/bin/claude)."
            )
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = [
                "-p",
                "--no-session-persistence",
                "--permission-mode",
                "dontAsk",
                "--output-format",
                "json",
            ]

            process.environment = ClaudeBinaryResolver.augmentedEnvironment()

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let timeoutWorkItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                    continuation.resume(throwing: SummaryServiceError.timedOut)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + summaryTimeoutSeconds, execute: timeoutWorkItem)

            process.terminationHandler = { proc in
                timeoutWorkItem.cancel()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if proc.terminationStatus != 0 {
                    continuation.resume(throwing: SummaryServiceError.cliFailed(stderr.isEmpty ? "Claude CLI exited with code \(proc.terminationStatus)" : stderr))
                    return
                }

                if stdout.isEmpty {
                    continuation.resume(throwing: SummaryServiceError.cliFailed(
                        "Claude CLI returned empty output. Run `claude -p \"hello\"` in Terminal to verify your CLI setup."
                    ))
                    return
                }

                do {
                    let payload = try extractClaudeStdout(stdout)
                    continuation.resume(returning: payload)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            do {
                try process.run()
                ClaudeUsageLimiter.recordCall()
                if let promptData = prompt.data(using: .utf8) {
                    stdinPipe.fileHandleForWriting.write(promptData)
                }
                try stdinPipe.fileHandleForWriting.close()
            } catch {
                timeoutWorkItem.cancel()
                continuation.resume(throwing: SummaryServiceError.cliFailed("Failed to run Claude CLI (\(config.claudeBinary)): \(error.localizedDescription)"))
            }
        }
    }
}

enum SummaryServiceError: LocalizedError {
    case timedOut
    case cliFailed(String)
    case dailyLimitReached(remaining: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "Claude CLI timed out after 120 seconds"
        case .cliFailed(let message):
            return message
        case .dailyLimitReached(_, let limit):
            return "Daily Claude limit reached (\(limit) calls). Cached summaries still work. Resets at midnight."
        }
    }
}
