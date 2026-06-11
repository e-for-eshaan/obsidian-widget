import SwiftUI

struct NoteViewerView: View {
    @EnvironmentObject private var appController: AppController

    private var scheduler: NoteScheduler { appController.scheduler }
    private var navigation: NoteNavigation { appController.navigation }

    var body: some View {
        let note = scheduler.currentNote ?? Self.placeholderNote

        VStack(spacing: 0) {
            toolbar(for: note)
            Divider()
            noteSection(for: note)
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

    private func toolbar(for note: NotePayload) -> some View {
        HStack(spacing: 8) {
            Spacer()

            Button {
                navigation.clearHistory()
                scheduler.forceRefreshNow()
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

    private func noteSection(for note: NotePayload) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                navRow(for: note)

                if appController.settingsOpen {
                    SettingsView(
                        settings: appController.configStore.settings,
                        canRegenerateSummary: !note.filePath.isEmpty && note.status != .loading,
                        onChooseFolder: { appController.chooseVaultFolder() },
                        onToggleSubfolder: { appController.toggleSubfolder($0) },
                        onFontSizeChange: { appController.updateSettings(SettingsUpdate(fontSizePx: $0)) },
                        onRefreshNow: {
                            navigation.clearHistory()
                            scheduler.refreshNow()
                        },
                        onRegenerateSummary: { scheduler.regenerateSummary() },
                        onClose: { appController.settingsOpen = false }
                    )
                }

                Text(note.title)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)

                contentBody(for: note)

                footer(for: note)
            }
            .padding(20)
        }
    }

    private func navRow(for note: NotePayload) -> some View {
        HStack(spacing: 12) {
            if navigation.canGoBack {
                HStack(spacing: 4) {
                    Button {
                        navigation.goBack { scheduler.loadNote($0) }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Back to previous note")

                    Button("Top") {
                        navigation.goBackToTop { scheduler.loadNote($0) }
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
            get: { appController.configStore.settings.contentView },
            set: { appController.updateSettings(SettingsUpdate(contentView: $0)) }
        )
    }

    @ViewBuilder
    private func contentBody(for note: NotePayload) -> some View {
        let settings = appController.configStore.settings
        let isLoading = note.status == .loading
        let hasOriginal = !note.content.isEmpty
        let showOriginal = settings.contentView == .original && hasOriginal
        let showSummaryLoader = isLoading && settings.contentView == .summary

        if showOriginal {
            MarkdownTextView(
                content: note.content,
                fontSize: CGFloat(settings.fontSizePx),
                onWikiLinkTap: { target in
                    handleWikiLink(target, currentFilePath: note.filePath)
                }
            )
        } else if showSummaryLoader {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                MarkdownTextView(
                    content: note.summary,
                    fontSize: CGFloat(settings.fontSizePx)
                )
            }
        } else {
            MarkdownTextView(
                content: note.summary,
                fontSize: CGFloat(settings.fontSizePx),
                isError: note.status == .error,
                onWikiLinkTap: { target in
                    handleWikiLink(target, currentFilePath: note.filePath)
                }
            )

            if note.status == .ready {
                relatedNotesSection(for: note)
            }
        }
    }

    private func relatedNotesSection(for note: NotePayload) -> some View {
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
                            ) { scheduler.loadNote($0) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func footer(for note: NotePayload) -> some View {
        Group {
            if note.status != .loading || !note.content.isEmpty {
                Text(formatRefreshLabel(note.nextRefreshAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleWikiLink(_ target: String, currentFilePath: String) {
        guard let filePath = scheduler.resolveWikiLink(target),
              filePath != currentFilePath else {
            return
        }

        navigation.navigateToRelated(from: currentFilePath, to: filePath) { scheduler.loadNote($0) }
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

    private static let placeholderNote = NotePayload(
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
