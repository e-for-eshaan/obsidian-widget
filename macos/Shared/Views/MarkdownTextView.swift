import SwiftUI

struct MarkdownTextView: View {
    let content: String
    var fontSize: CGFloat = 13
    var isError: Bool = false
    var onWikiLinkTap: ((String) -> Void)?

    var body: some View {
        if onWikiLinkTap == nil {
            plainMarkdownText
        } else {
            wikiLinkText
        }
    }

    private var plainMarkdownText: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
            } else {
                Text(content)
            }
        }
        .font(.system(size: fontSize, design: .monospaced))
        .foregroundStyle(isError ? Color.red.opacity(0.85) : .primary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wikiLinkText: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                wikiLinkLine(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wikiLinkLine(_ line: String) -> some View {
        let segments = parseWikiLinkSegments(line)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let value):
                    if let attributed = try? AttributedString(
                        markdown: value,
                        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                            .font(.system(size: fontSize, design: .monospaced))
                    } else {
                        Text(value)
                            .font(.system(size: fontSize, design: .monospaced))
                    }
                case .wikiLink(let target, let label):
                    Button(label) {
                        onWikiLinkTap?(target)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(Color(red: 0.49, green: 0.45, blue: 1.0))
                    .underline()
                }
            }
        }
    }

    private enum WikiSegment {
        case text(String)
        case wikiLink(target: String, label: String)
    }

    private func parseWikiLinkSegments(_ line: String) -> [WikiSegment] {
        let pattern = #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(line)]
        }

        let nsRange = NSRange(line.startIndex..., in: line)
        var segments: [WikiSegment] = []
        var lastIndex = line.startIndex

        regex.enumerateMatches(in: line, range: nsRange) { match, _, _ in
            guard let match, let fullRange = Range(match.range(at: 0), in: line),
                  let targetRange = Range(match.range(at: 1), in: line) else {
                return
            }

            if lastIndex < fullRange.lowerBound {
                segments.append(.text(String(line[lastIndex..<fullRange.lowerBound])))
            }

            let target = String(line[targetRange])
            let label: String
            if match.numberOfRanges > 2, let aliasRange = Range(match.range(at: 2), in: line) {
                label = String(line[aliasRange])
            } else {
                label = target.split(separator: "#", maxSplits: 1).first.map(String.init) ?? target
            }

            segments.append(.wikiLink(target: target, label: label))
            lastIndex = fullRange.upperBound
        }

        if lastIndex < line.endIndex {
            segments.append(.text(String(line[lastIndex...])))
        }

        return segments.isEmpty ? [.text(line)] : segments
    }
}

struct WidgetMarkdownText: View {
    let content: String
    var font: Font = .body
    var lineLimit: Int?

    init(_ content: String, font: Font = .body, lineLimit: Int? = nil) {
        self.content = content
        self.font = font
        self.lineLimit = lineLimit
    }

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
            } else {
                Text(content)
            }
        }
        .font(font)
        .lineLimit(lineLimit)
    }
}

enum WidgetFont {
    static var headline: Font {
        .system(.headline, design: .monospaced)
    }

    static func body(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }
}
