import WidgetKit

struct ObsidianWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ObsidianWidgetEntry {
        ObsidianWidgetEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ObsidianWidgetEntry) -> Void) {
        completion(ObsidianWidgetEntry(date: Date(), state: SharedStateReader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ObsidianWidgetEntry>) -> Void) {
        let state = SharedStateReader.load()
        let entry = ObsidianWidgetEntry(date: Date(), state: state)
        let refreshDate: Date

        switch state.status {
        case .ready:
            refreshDate = SharedStateReader.nextRefreshDate(from: state)
        case .loading, .error, .needsSetup:
            refreshDate = Date().addingTimeInterval(900)
        }

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}
