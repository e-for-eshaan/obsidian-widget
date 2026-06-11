import Foundation

enum SummaryFormat {
    static func formatSummaryBullets(_ summary: String) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }

        let lines = trimmed
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if hasBulletLines(lines) {
            return lines.map { line in
                if line.hasPrefix("* ") || line.hasPrefix("+ ") || line.hasPrefix("• ") {
                    return "- " + String(line.dropFirst(2))
                }
                return line
            }.joined(separator: "\n")
        }

        let paragraph = lines.joined(separator: " ")
        let sentences = splitSummarySentences(paragraph)

        if sentences.count == 1 {
            return "- \(sentences[0])"
        }

        return sentences.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func splitSummarySentences(_ text: String) -> [String] {
        let pattern = "(?<=[.!?])\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        var sentences: [String] = []
        var lastIndex = text.startIndex

        regex.enumerateMatches(in: text, range: nsRange) { match, _, _ in
            guard let match, let range = Range(match.range, in: text) else { return }
            let sentence = String(text[lastIndex..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            lastIndex = range.upperBound
        }

        let tail = String(text[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }

        return sentences.isEmpty ? [text.trimmingCharacters(in: .whitespacesAndNewlines)] : sentences
    }

    private static func hasBulletLines(_ lines: [String]) -> Bool {
        lines.contains { line in
            line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") || line.hasPrefix("• ")
        }
    }
}
