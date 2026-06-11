import Foundation
import SwiftUI

enum MarkdownDisplayLine: Equatable {
    case spacer
    case bullet(String)
    case text(String)
    case heading(level: Int, text: String)
    case codeBlock(language: String, code: String)
}

enum MarkdownLineParser {
    static func lines(from content: String, wikiLinksEnabled: Bool) -> [MarkdownDisplayLine] {
        let source = wikiLinksEnabled ? ObsidianMarkdown.preprocessObsidianContent(content) : content
        var result: [MarkdownDisplayLine] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index...].hasPrefix("```") {
                if let codeBlock = parseCodeBlock(from: source, start: &index) {
                    result.append(codeBlock)
                }
                continue
            }

            let lineEnd = source[index...].firstIndex(of: "\n") ?? source.endIndex
            let line = String(source[index..<lineEnd]).trimmingCharacters(in: .whitespaces)

            if lineEnd < source.endIndex {
                index = source.index(after: lineEnd)
            } else {
                index = lineEnd
            }

            if line.isEmpty {
                if result.last != .spacer {
                    result.append(.spacer)
                }
                continue
            }

            if let heading = parseHeading(line) {
                result.append(.heading(level: heading.level, text: heading.text))
            } else if isBulletLine(line) {
                result.append(.bullet(stripBulletPrefix(line)))
            } else {
                result.append(.text(line))
            }
        }

        return result
    }

    private static func parseCodeBlock(from source: String, start: inout String.Index) -> MarkdownDisplayLine? {
        guard source[start...].hasPrefix("```") else { return nil }

        let languageStart = source.index(start, offsetBy: 3)
        let firstLineEnd = source[languageStart...].firstIndex(of: "\n") ?? source.endIndex
        let language = String(source[languageStart..<firstLineEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard firstLineEnd < source.endIndex else { return nil }

        var searchStart = source.index(after: firstLineEnd)
        while searchStart < source.endIndex {
            if source[searchStart...].hasPrefix("```") {
                let codeEnd = searchStart
                let code = String(source[source.index(after: firstLineEnd)..<codeEnd])
                    .trimmingCharacters(in: .newlines)
                start = source.index(searchStart, offsetBy: 3)
                if start < source.endIndex, source[start] == "\n" {
                    start = source.index(after: start)
                }
                return .codeBlock(language: language, code: code)
            }
            guard let nextNewline = source[searchStart...].firstIndex(of: "\n") else { break }
            searchStart = source.index(after: nextNewline)
        }

        return nil
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }

        guard level > 0, level <= 6, line.count > level else { return nil }
        let afterHashes = line.index(line.startIndex, offsetBy: level)
        guard afterHashes < line.endIndex, line[afterHashes] == " " else { return nil }

        let text = String(line[line.index(after: afterHashes)...]).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func isBulletLine(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") || line.hasPrefix("• ")
    }

    private static func stripBulletPrefix(_ line: String) -> String {
        String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }
}

enum ObsidianMarkdown {
    private static let wikiLinkPattern = #"\[\[([^\]|#]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]"#

    static func appAttributedString(
        from content: String,
        fontSizePx: Int,
        wikiLinksEnabled: Bool = false,
        isError: Bool = false
    ) -> AttributedString {
        inlineAttributedString(
            from: content,
            fontSizePx: fontSizePx,
            baseForeground: isError ? Color.red.opacity(0.85) : .primary
        )
    }

    static func attributedString(from content: String, wikiLinksEnabled: Bool = false) -> AttributedString {
        appAttributedString(from: content, fontSizePx: 13, wikiLinksEnabled: wikiLinksEnabled)
    }

    static func widgetAttributedString(from content: String, fontSizePx: Int) -> AttributedString {
        inlineAttributedString(
            from: content,
            fontSizePx: fontSizePx,
            baseForeground: .secondary
        )
    }

    static func inlineAttributedString(
        from content: String,
        fontSizePx: Int,
        baseForeground: Color
    ) -> AttributedString {
        var parsed = parseMarkdown(content)
        applyDisplayStyle(to: &parsed, fontSizePx: fontSizePx, baseForeground: baseForeground)
        return parsed
    }

    static func headingAttributedString(
        from content: String,
        level: Int,
        fontSizePx: Int,
        baseForeground: Color
    ) -> AttributedString {
        let scale: CGFloat = switch level {
        case 1: 1.15
        case 2: 1.08
        case 3: 1.02
        default: 1.0
        }
        var parsed = parseMarkdown(content)
        applyDisplayStyle(to: &parsed, fontSizePx: fontSizePx, baseForeground: baseForeground)
        for run in parsed.runs {
            parsed[run.range].font = .system(size: CGFloat(fontSizePx) * scale, weight: .semibold, design: .monospaced)
        }
        return parsed
    }

    private static func parseMarkdown(_ source: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }

        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return attributed
        }

        return AttributedString(source)
    }

    private static func applyDisplayStyle(
        to attributed: inout AttributedString,
        fontSizePx: Int,
        baseForeground: Color
    ) {
        let fontSize = CGFloat(fontSizePx)

        for run in attributed.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                attributed[run.range].foregroundColor = WidgetCodeStyle.inlineForeground
                attributed[run.range].backgroundColor = WidgetCodeStyle.inlineBackground
                attributed[run.range].font = .system(size: fontSize * 0.88, weight: .medium, design: .monospaced)
                continue
            }

            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                attributed[run.range].font = .system(size: fontSize, weight: .bold, design: .monospaced)
                if attributed[run.range].foregroundColor == nil {
                    attributed[run.range].foregroundColor = baseForeground
                }
                continue
            }

            if run.inlinePresentationIntent?.contains(.emphasized) == true {
                attributed[run.range].font = .system(size: fontSize, weight: .regular, design: .monospaced).italic()
                if attributed[run.range].foregroundColor == nil {
                    attributed[run.range].foregroundColor = baseForeground
                }
                continue
            }

            if run.link != nil {
                attributed[run.range].foregroundColor = AppMarkdownStyle.linkForeground
                if attributed[run.range].font == nil {
                    attributed[run.range].font = .system(size: fontSize, weight: .medium, design: .monospaced)
                }
                continue
            }

            if attributed[run.range].font == nil {
                attributed[run.range].font = .system(size: fontSize, design: .monospaced)
            }
            if attributed[run.range].foregroundColor == nil {
                attributed[run.range].foregroundColor = baseForeground
            }
        }
    }

    static func preprocessObsidianContent(_ content: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(```[\s\S]*?```|`[^`\n]+`)"#, options: []) else {
            return transformTextSegment(content)
        }

        let nsRange = NSRange(content.startIndex..., in: content)
        var segments: [String] = []
        var lastIndex = content.startIndex

        regex.enumerateMatches(in: content, range: nsRange) { match, _, _ in
            guard let match, let fullRange = Range(match.range(at: 0), in: content) else { return }

            if lastIndex < fullRange.lowerBound {
                segments.append(transformTextSegment(String(content[lastIndex..<fullRange.lowerBound])))
            }

            segments.append(String(content[fullRange]))
            lastIndex = fullRange.upperBound
        }

        if lastIndex < content.endIndex {
            segments.append(transformTextSegment(String(content[lastIndex...])))
        }

        if segments.isEmpty {
            return transformTextSegment(content)
        }

        return segments.joined()
    }

    private static func transformTextSegment(_ segment: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: wikiLinkPattern, options: []) else {
            return segment
        }

        let nsRange = NSRange(segment.startIndex..., in: segment)
        var output = segment

        var replacements: [(NSRange, String)] = []
        regex.enumerateMatches(in: segment, range: nsRange) { match, _, _ in
            guard let match, Range(match.range(at: 0), in: segment) != nil,
                  let targetRange = Range(match.range(at: 1), in: segment) else {
                return
            }

            let target = String(segment[targetRange])
            let heading = match.numberOfRanges > 2 ? Range(match.range(at: 2), in: segment).map { String(segment[$0]) } : nil
            let alias = match.numberOfRanges > 3 ? Range(match.range(at: 3), in: segment).map { String(segment[$0]) } : nil
            let replacement = wrapWikiLink(target: target, heading: heading, alias: alias)

            replacements.append((match.range(at: 0), replacement))
        }

        for (range, replacement) in replacements.reversed() {
            if let swiftRange = Range(range, in: output) {
                output.replaceSubrange(swiftRange, with: replacement)
            }
        }

        return output
    }

    private static func wrapWikiLink(target: String, heading: String?, alias: String?) -> String {
        let display = wikiDisplayText(target: target, alias: alias)
        var linkTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if let heading, !heading.isEmpty {
            linkTarget += "#\(heading.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        let encoded = linkTarget.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.union(.urlHostAllowed)) ?? linkTarget
        return "[\(display)](obsidian-wiki://\(encoded))"
    }

    private static func wikiDisplayText(target: String, alias: String?) -> String {
        if let alias, !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return alias.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let basename = target.split(separator: "/").last.map(String.init) ?? target
        return basename.replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
    }

    static func wikiTarget(from url: URL) -> String? {
        guard url.scheme == "obsidian-wiki" else { return nil }

        let rawTarget = [url.host, url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        guard !rawTarget.isEmpty else { return nil }
        return rawTarget.removingPercentEncoding ?? rawTarget
    }
}

private enum WidgetCodeStyle {
    static let inlineForeground = Color(red: 1.0, green: 0.624, blue: 0.353)
    static let inlineBackground = Color(red: 1.0, green: 0.624, blue: 0.353, opacity: 0.14)
}

private enum AppMarkdownStyle {
    static let linkForeground = Color(red: 0.72, green: 0.69, blue: 1.0)
}

struct MarkdownBodyView: View {
    let content: String
    var fontSizePx: Int = 13
    var wikiLinksEnabled: Bool = false
    var isError: Bool = false
    var baseForeground: Color = .primary
    var lineSpacing: CGFloat = 6
    var lineLimit: Int?

    private var baseColor: Color {
        isError ? Color.red.opacity(0.85) : baseForeground
    }

    private var displayLines: [MarkdownDisplayLine] {
        MarkdownLineParser.lines(from: content, wikiLinksEnabled: wikiLinksEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(limitedLines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var limitedLines: [MarkdownDisplayLine] {
        guard let lineLimit else { return displayLines }
        return Array(displayLines.prefix(lineLimit))
    }

    @ViewBuilder
    private func lineView(_ line: MarkdownDisplayLine) -> some View {
        switch line {
        case .spacer:
            Color.clear.frame(height: 4)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(size: CGFloat(fontSizePx), design: .monospaced))
                    .foregroundStyle(AppMarkdownStyle.bulletMarker)
                inlineText(text)
            }
        case .text(let text):
            inlineText(text)
        case .heading(let level, let text):
            Text(
                ObsidianMarkdown.headingAttributedString(
                    from: text,
                    level: level,
                    fontSizePx: fontSizePx,
                    baseForeground: baseColor
                )
            )
        case .codeBlock(let language, let code):
            Text(
                SyntaxHighlighter.highlight(
                    code: code,
                    language: language,
                    fontSize: CGFloat(fontSizePx) * 0.92
                )
            )
        }
    }

    private func inlineText(_ text: String) -> some View {
        Text(
            ObsidianMarkdown.inlineAttributedString(
                from: text,
                fontSizePx: fontSizePx,
                baseForeground: baseColor
            )
        )
    }
}

private extension AppMarkdownStyle {
    static let bulletMarker = Color(red: 0.62, green: 0.57, blue: 1.0)
}

struct WidgetMarkdownText: View {
    let content: String
    var fontSizePx: Int = 11
    var lineLimit: Int?

    init(_ content: String, fontSizePx: Int = 11, lineLimit: Int? = nil, foregroundStyle: Color = .secondary) {
        self.content = content
        self.fontSizePx = fontSizePx
        self.lineLimit = lineLimit
        _ = foregroundStyle
    }

    var body: some View {
        MarkdownBodyView(
            content: content,
            fontSizePx: fontSizePx,
            baseForeground: .secondary,
            lineSpacing: 4,
            lineLimit: lineLimit
        )
    }
}

enum WidgetFont {
    static var headline: Font {
        .system(.headline, design: .monospaced).weight(.semibold)
    }

    static func body(_ fontSizePx: Int) -> Font {
        .system(size: CGFloat(fontSizePx), design: .monospaced)
    }

    static func body(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }
}
