import Foundation
import SwiftUI

enum ObsidianMarkdown {
    private static let wikiLinkPattern = #"\[\[([^\]|#]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]"#
    private static let fencedCodePattern = #"```([^\n]*)\r?\n([\s\S]*?)```"#

    static func attributedString(from content: String, wikiLinksEnabled: Bool = false) -> AttributedString {
        let source = wikiLinksEnabled ? preprocessObsidianContent(content) : content
        return parseMarkdown(source)
    }

    static func widgetAttributedString(from content: String, fontSizePx: Int) -> AttributedString {
        var result = AttributedString()

        for segment in splitPreservingCodeBlocks(content) {
            switch segment {
            case .text(let markdown):
                var parsed = parseMarkdown(markdown)
                applyInlineCodeStyles(to: &parsed, fontSizePx: fontSizePx)
                result.append(parsed)
            case .codeBlock(let language, let code):
                if !result.characters.isEmpty {
                    result.append(AttributedString("\n"))
                }
                result.append(
                    SyntaxHighlighter.highlight(
                        code: code,
                        language: language,
                        fontSize: CGFloat(fontSizePx) * 0.92
                    )
                )
                result.append(AttributedString("\n"))
            }
        }

        return result.characters.isEmpty ? parseMarkdown(content) : result
    }

    private static func parseMarkdown(_ source: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return attributed
        }

        return AttributedString(source)
    }

    private enum MarkdownSegment {
        case text(String)
        case codeBlock(language: String, code: String)
    }

    private static func splitPreservingCodeBlocks(_ content: String) -> [MarkdownSegment] {
        guard let regex = try? NSRegularExpression(pattern: fencedCodePattern, options: []) else {
            return [.text(content)]
        }

        let nsRange = NSRange(content.startIndex..., in: content)
        var segments: [MarkdownSegment] = []
        var lastIndex = content.startIndex

        regex.enumerateMatches(in: content, range: nsRange) { match, _, _ in
            guard let match, let fullRange = Range(match.range(at: 0), in: content),
                  let languageRange = Range(match.range(at: 1), in: content),
                  let codeRange = Range(match.range(at: 2), in: content) else {
                return
            }

            if lastIndex < fullRange.lowerBound {
                segments.append(.text(String(content[lastIndex..<fullRange.lowerBound])))
            }

            let language = String(content[languageRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let code = String(content[codeRange]).trimmingCharacters(in: .newlines)
            segments.append(.codeBlock(language: language, code: code))
            lastIndex = fullRange.upperBound
        }

        if lastIndex < content.endIndex {
            segments.append(.text(String(content[lastIndex...])))
        }

        return segments.isEmpty ? [.text(content)] : segments
    }

    private static func applyInlineCodeStyles(to attributed: inout AttributedString, fontSizePx: Int) {
        let fontSize = CGFloat(fontSizePx) * 0.88

        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].foregroundColor = WidgetCodeStyle.inlineForeground
            attributed[run.range].backgroundColor = WidgetCodeStyle.inlineBackground
            attributed[run.range].font = .system(size: fontSize, weight: .medium, design: .monospaced)
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

struct WidgetMarkdownText: View {
    let content: String
    var fontSizePx: Int = 11
    var lineLimit: Int?
    var foregroundStyle: Color = .secondary

    init(_ content: String, fontSizePx: Int = 11, lineLimit: Int? = nil, foregroundStyle: Color = .secondary) {
        self.content = content
        self.fontSizePx = fontSizePx
        self.lineLimit = lineLimit
        self.foregroundStyle = foregroundStyle
    }

    var body: some View {
        Text(ObsidianMarkdown.widgetAttributedString(from: content, fontSizePx: fontSizePx))
            .font(.system(size: CGFloat(fontSizePx), design: .monospaced))
            .foregroundStyle(foregroundStyle)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
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
