import SwiftUI

@main
struct ObsidianWidgetHostApp: App {
    var body: some Scene {
        WindowGroup {
            HostContentView()
        }
    }
}

struct HostContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Obsidian Widget Host")
                .font(.title2.bold())
            Text("Run the Electron menu bar app to sync note summaries. Add the widget from Desktop & Dock settings.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 220)
    }
}
