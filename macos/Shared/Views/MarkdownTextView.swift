import SwiftUI

struct MarkdownTextView: View {
    let content: String
    var fontSize: CGFloat = 13
    var isError: Bool = false
    var onWikiLinkTap: ((String) -> Void)?

    var body: some View {
        Text(ObsidianMarkdown.attributedString(from: content, wikiLinksEnabled: onWikiLinkTap != nil))
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundStyle(isError ? Color.red.opacity(0.85) : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                handleURL(url)
            })
    }

    private func handleURL(_ url: URL) -> OpenURLAction.Result {
        guard let onWikiLinkTap, let target = ObsidianMarkdown.wikiTarget(from: url) else {
            return .systemAction
        }

        onWikiLinkTap(target)
        return .handled
    }
}
