import SwiftUI
import WidgetKit

struct ObsidianWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ObsidianWidgetEntry

    private var fontSizePx: Int {
        entry.state.fontSizePx
    }

    private var bulletLimit: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 3
        default:
            return 5
        }
    }

    private var bullets: [String] {
        SharedStateReader.parseBullets(from: entry.state.summary, limit: bulletLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayTitle)
                .font(WidgetFont.headline)
                .lineLimit(family == .systemSmall ? 2 : 3)
                .foregroundStyle(.primary)

            if entry.state.status == .loading {
                ProgressView()
                    .controlSize(.small)
                WidgetMarkdownText(entry.state.summary, fontSizePx: fontSizePx, lineLimit: 2)
            } else if bullets.isEmpty {
                WidgetMarkdownText(
                    entry.state.summary,
                    fontSizePx: fontSizePx,
                    lineLimit: family == .systemSmall ? 3 : 6
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(WidgetFont.body(fontSizePx - 2))
                                .foregroundStyle(Color(red: 0.49, green: 0.45, blue: 1.0))
                            WidgetMarkdownText(bullet, fontSizePx: fontSizePx)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if !entry.state.parentFolder.isEmpty {
                Text(entry.state.parentFolder)
                    .font(WidgetFont.body(.caption2))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.09, blue: 0.11),
                    Color(red: 0.14, green: 0.13, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var displayTitle: String {
        switch entry.state.status {
        case .needsSetup:
            return "Obsidian Widget"
        case .error:
            return entry.state.title.isEmpty ? "Obsidian Widget" : entry.state.title
        default:
            return entry.state.title
        }
    }
}

struct ObsidianWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        ObsidianWidgetView(
            entry: ObsidianWidgetEntry(
                date: Date(),
                state: WidgetSharedState(
                    version: 1,
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    status: .ready,
                    title: "Daily Notes",
                    summary: "- The **Singleton Pattern** ensures only one instance exists\n- **Pros:** controlled resource usage\n- **Cons:** hard to mock in tests",
                    filePath: "/tmp/note.md",
                    parentFolder: "Journal",
                    nextRefreshAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                    fontSizePx: 11,
                    errorMessage: nil
                )
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
