import SwiftUI
import WidgetKit

struct ObsidianWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ObsidianWidgetEntry

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
                .font(.headline)
                .lineLimit(family == .systemSmall ? 2 : 3)
                .foregroundStyle(.primary)

            if entry.state.status == .loading {
                ProgressView()
                    .controlSize(.small)
                Text(entry.state.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if bullets.isEmpty {
                Text(entry.state.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemSmall ? 3 : 6)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.49, green: 0.45, blue: 1.0))
                            Text(bullet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if !entry.state.parentFolder.isEmpty {
                Text(entry.state.parentFolder)
                    .font(.caption2)
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
                    summary: "- Capture ideas quickly\n- Review weekly goals\n- Link related projects",
                    filePath: "/tmp/note.md",
                    parentFolder: "Journal",
                    nextRefreshAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                    errorMessage: nil
                )
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
