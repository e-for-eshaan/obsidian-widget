import SwiftUI
import WidgetKit

@main
struct ObsidianWidgetBundle: WidgetBundle {
    var body: some Widget {
        ObsidianWidget()
    }
}

struct ObsidianWidget: Widget {
    let kind: String = "ObsidianWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ObsidianWidgetProvider()) { entry in
            ObsidianWidgetView(entry: entry)
                .widgetURL(URL(string: "obsidianwidget://open"))
        }
        .configurationDisplayName("Obsidian Note")
        .description("Shows the current random note summary from your vault.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
