import Foundation
import SwiftUI

enum SyntaxHighlighter {
    private struct TokenRule {
        let pattern: String
        let color: Color
        let options: NSRegularExpression.Options

        init(_ pattern: String, color: Color, options: NSRegularExpression.Options = []) {
            self.pattern = pattern
            self.color = color
            self.options = options
        }
    }

    private static let languageAliases: [String: String] = [
        "js": "javascript",
        "ts": "typescript",
        "tsx": "tsx",
        "jsx": "jsx",
        "py": "python",
        "sh": "bash",
        "shell": "bash",
        "zsh": "bash",
        "yml": "yaml",
        "md": "markdown",
        "c++": "cpp",
        "cs": "csharp",
        "rs": "rust",
        "kt": "kotlin",
        "rb": "ruby",
    ]

    private static let keywordSets: [String: [String]] = [
        "javascript": ["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "import", "export", "from", "async", "await", "new", "this", "typeof", "null", "undefined", "true", "false"],
        "typescript": ["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "import", "export", "from", "async", "await", "new", "this", "typeof", "interface", "type", "enum", "implements", "extends", "null", "undefined", "true", "false"],
        "python": ["def", "class", "return", "if", "elif", "else", "for", "while", "import", "from", "as", "with", "try", "except", "finally", "raise", "pass", "lambda", "yield", "True", "False", "None", "and", "or", "not", "in", "is"],
        "swift": ["func", "var", "let", "class", "struct", "enum", "protocol", "extension", "import", "return", "if", "else", "guard", "switch", "case", "default", "for", "while", "in", "try", "catch", "throw", "async", "await", "true", "false", "nil", "self", "Self"],
        "bash": ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac", "function", "return", "export", "local", "echo", "exit"],
        "json": ["true", "false", "null"],
        "yaml": ["true", "false", "null"],
        "rust": ["fn", "let", "mut", "struct", "enum", "impl", "trait", "pub", "use", "mod", "return", "if", "else", "match", "for", "while", "loop", "true", "false", "self", "Self"],
        "go": ["func", "var", "const", "type", "struct", "interface", "package", "import", "return", "if", "else", "for", "range", "switch", "case", "default", "true", "false", "nil"],
    ]

    static func highlight(code: String, language: String, fontSize: CGFloat) -> AttributedString {
        var attributed = AttributedString(code)
        attributed.font = .system(size: fontSize, design: .monospaced)
        attributed.foregroundColor = SyntaxColor.defaultText
        attributed.backgroundColor = SyntaxColor.blockBackground

        for rule in rules(for: language) {
            apply(rule, to: &attributed, in: code)
        }

        return attributed
    }

    static func normalizedLanguage(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "text"
        }

        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return languageAliases[lower] ?? lower
    }

    private static func rules(for language: String) -> [TokenRule] {
        let normalized = normalizedLanguage(language)
        var rules: [TokenRule] = [
            TokenRule(#"/\*[\s\S]*?\*/"#, color: SyntaxColor.comment),
            TokenRule(#"(^|\s)#.*$"#, color: SyntaxColor.comment, options: [.anchorsMatchLines]),
            TokenRule(#"(^|\s)//.*$"#, color: SyntaxColor.comment, options: [.anchorsMatchLines]),
            TokenRule(#"""(?:\\.|[^"\\])*"""#, color: SyntaxColor.string),
            TokenRule(#"(?<![\\])"(?:\\.|[^"\\])*""#, color: SyntaxColor.string),
            TokenRule(#"'(?:\\.|[^'\\])*'"#, color: SyntaxColor.string),
            TokenRule(#"\b0x[0-9a-fA-F]+\b|\b\d+(?:\.\d+)?\b"#, color: SyntaxColor.number),
            TokenRule(#"\b[A-Z][A-Za-z0-9_]+\b"#, color: SyntaxColor.type),
            TokenRule(#"\b[a-zA-Z_]\w*(?=\s*\()"#, color: SyntaxColor.function),
        ]

        if let keywords = keywordSets[normalized], !keywords.isEmpty {
            let joined = keywords.joined(separator: "|")
            rules.append(TokenRule("\\b(?:\(joined))\\b", color: SyntaxColor.keyword))
        }

        return rules
    }

    private static func apply(_ rule: TokenRule, to attributed: inout AttributedString, in source: String) {
        guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else { return }

        let nsRange = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, options: [], range: nsRange)

        for match in matches.reversed() {
            guard let stringRange = Range(match.range, in: source),
                  let lowerBound = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upperBound = AttributedString.Index(stringRange.upperBound, within: attributed) else {
                continue
            }

            attributed[lowerBound..<upperBound].foregroundColor = rule.color
        }
    }
}

private enum SyntaxColor {
    static let defaultText = Color(red: 0.83, green: 0.83, blue: 0.83)
    static let keyword = Color(red: 0.34, green: 0.61, blue: 0.84)
    static let string = Color(red: 0.81, green: 0.57, blue: 0.47)
    static let comment = Color(red: 0.42, green: 0.60, blue: 0.33)
    static let number = Color(red: 0.71, green: 0.81, blue: 0.66)
    static let function = Color(red: 0.86, green: 0.86, blue: 0.67)
    static let type = Color(red: 0.31, green: 0.79, blue: 0.69)
    static let blockBackground = Color(red: 0.08, green: 0.08, blue: 0.14).opacity(0.94)
}
