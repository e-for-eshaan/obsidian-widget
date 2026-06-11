import SwiftUI

struct NoteViewerView: View {
    @EnvironmentObject private var appController: AppController
    @ObservedObject private var scheduler: NoteScheduler
    @ObservedObject private var navigation: NoteNavigation

    init(scheduler: NoteScheduler, navigation: NoteNavigation) {
        self.scheduler = scheduler
        self.navigation = navigation
    }

    private var note: NotePayload {
        scheduler.currentNote ?? NotePayload(
            title: "Obsidian Widget",
            summary: "Loading your note…",
            content: "",
            relativePath: "",
            filePath: "",
            parentFolder: "",
            relatedNotes: [],
            nextRefreshAt: Date().ISO8601Format(),
            status: .loading
        )
    }

    private var settings: WidgetSettings {
        appController.configStore.settings
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            noteSection
        }
        .frame(minWidth: 520, minHeight: 560)
        .onChange(of: note.filePath) { _, newPath in
            appController.settingsOpen = false
            navigation.syncCurrentFilePath(newPath)
        }
        .onChange(of: scheduler.currentNote?.filePath) { _, newPath in
            if let newPath {
                navigation.handleExternalNoteUpdate(newPath)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Spacer()

            Button {
                navigation.clearHistory()
                appController.scheduler.forceRefreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Force refresh — new note, new summary")
            .disabled(note.status == .loading)

            Button {
                appController.openInObsidian(filePath: note.filePath)
            } label: {
                Image(systemName: "diamond")
            }
            .help("Open in Obsidian")
            .disabled(note.filePath.isEmpty || note.status == .loading)

            Button {
                appController.settingsOpen.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            .symbolVariant(appController.settingsOpen ? .fill : .none)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var noteSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                navRow

                if appController.settingsOpen {
                    SettingsView(
                        settings: settings,
                        canRegenerateSummary: !note.filePath.isEmpty && note.status != .loading,
                        onChooseFolder: { appController.chooseVaultFolder() },
                        onToggleSubfolder: { appController.toggleSubfolder($0) },
                        onFontSizeChange: { appController.updateSettings(SettingsUpdate(fontSizePx: $0)) },
                        onRefreshNow: {
                            navigation.clearHistory()
                            appController.scheduler.refreshNow()
                        },
                        onRegenerateSummary: { appController.scheduler.regenerateSummary() },
                        onClose: { appController.settingsOpen = false }
                    )
                }

                Text(note.title)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)

                contentBody

                footer
            }
            .padding(20)
        }
    }

    private var navRow: some View {
        HStack(spacing: 12) {
            if navigation.canGoBack {
                HStack(spacing: 4) {
                    Button {
                        navigation.goBack { appController.scheduler.loadNote($0) }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Back to previous note")

                    Button("Top") {
                        navigation.goBackToTop { appController.scheduler.loadNote($0) }
                    }
                    .font(.caption)
                    .help("Back to top")
                }
                .buttonStyle(.borderless)
            }

            Picker("View", selection: contentViewBinding) {
                Text("Summary").tag(ContentView.summary)
                Text("Original").tag(ContentView.original)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)
        }
    }

    private var contentViewBinding: Binding<ContentView> {
        Binding(
            get: { settings.contentView },
            set: { appController.updateSettings(SettingsUpdate(contentView: $0)) }
        )
    }

    @ViewBuilder
    private var contentBody: some View {
        let isLoading = note.status == .loading
        let hasOriginal = !note.content.isEmpty
        let showOriginal = settings.contentView == .original && hasOriginal
        let showSummaryLoader = isLoading && settings.contentView == .summary

        if showOriginal {
            MarkdownTextView(
                content: note.content,
                fontSize: CGFloat(settings.fontSizePx),
                onWikiLinkTap: { target in
                    handleWikiLink(target)
                }
            )
        } else if showSummaryLoader {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(note.summary)
                    .font(.system(size: CGFloat(settings.fontSizePx), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        } else {
            MarkdownTextView(
                content: note.summary,
                fontSize: CGFloat(settings.fontSizePx),
                isError: note.status == .error,
                onWikiLinkTap: { target in
                    handleWikiLink(target)
                }
            )

            if note.status == .ready {
                relatedNotesSection
            }
        }
    }

    private var relatedNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !note.parentFolder.isEmpty {
                Text(note.parentFolder)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !note.relatedNotes.isEmpty {
                Text("Related")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(note.relatedNotes) { related in
                        Button(related.title) {
                            navigation.navigateToRelated(
                                from: note.filePath,
                                to: related.filePath
                            ) { appController.scheduler.loadNote($0) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var footer: some View {
        Group {
            if note.status != .loading || !note.content.isEmpty {
                Text(formatRefreshLabel(note.nextRefreshAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleWikiLink(_ target: String) {
        guard let filePath = appController.scheduler.resolveWikiLink(target),
              filePath != note.filePath else {
            return
        }

        navigation.navigateToRelated(from: note.filePath, to: filePath) { appController.scheduler.loadNote($0) }
    }

    private func formatRefreshLabel(_ nextRefreshAt: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: nextRefreshAt) else {
            return "Refreshing soon"
        }

        let diffMs = date.timeIntervalSinceNow
        if diffMs <= 0 {
            return "Refreshing soon"
        }

        let hours = Int(diffMs) / 3600
        let minutes = (Int(diffMs) % 3600) / 60

        if hours > 0 {
            return "Refreshes in \(hours)h \(minutes)m"
        }

        return "Refreshes in \(minutes)m"
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions,
            sizes: sizes
        )
    }

    private struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
