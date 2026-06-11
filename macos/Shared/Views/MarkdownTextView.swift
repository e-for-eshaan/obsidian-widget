import SwiftUI

struct MarkdownTextView: View {
    let content: String
    var fontSize: CGFloat = 13
    var isError: Bool = false
    var onWikiLinkTap: ((String) -> Void)?

    var body: some View {
        MarkdownBodyView(
            content: content,
            fontSizePx: Int(fontSize),
            wikiLinksEnabled: onWikiLinkTap != nil,
            isError: isError
        )
        .textSelection(.enabled)
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
