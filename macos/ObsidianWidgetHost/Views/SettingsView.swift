import SwiftUI

struct SettingsView: View {
    let settings: WidgetSettings
    let canRegenerateSummary: Bool
    let onChooseFolder: () -> Void
    let onToggleSubfolder: (String) -> Void
    let onFontSizeChange: (Int) -> Void
    let onRefreshNow: () -> Void
    let onRegenerateSummary: () -> Void
    let onClose: () -> Void

    @State private var subfoldersOpen = false

    private var allSubfoldersAllowed: Bool {
        settings.includedSubfolders.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }

            HStack {
                Text(folderLabel(settings.vaultFolderPath))
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(settings.vaultFolderPath)
                Spacer()
                Button("Browse", action: onChooseFolder)
            }

            DisclosureGroup(isExpanded: $subfoldersOpen) {
                if settings.availableSubfolders.isEmpty {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(settings.availableSubfolders, id: \.self) { folder in
                                subfolderRow(folder)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            } label: {
                HStack {
                    Text("Subfolders")
                    Spacer()
                    Text(allSubfoldersAllowed ? "All folders" : "\(settings.includedSubfolders.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Font size")
                    .font(.caption)
                Spacer()
                Button("−") {
                    onFontSizeChange(max(AppConfig.minFontSizePx, settings.fontSizePx - 1))
                }
                .disabled(settings.fontSizePx <= AppConfig.minFontSizePx)
                Slider(
                    value: Binding(
                        get: { Double(settings.fontSizePx) },
                        set: { onFontSizeChange(Int($0.rounded())) }
                    ),
                    in: Double(AppConfig.minFontSizePx)...Double(AppConfig.maxFontSizePx),
                    step: 1
                )
                .frame(width: 120)
                Button("+") {
                    onFontSizeChange(min(AppConfig.maxFontSizePx, settings.fontSizePx + 1))
                }
                .disabled(settings.fontSizePx >= AppConfig.maxFontSizePx)
                Text("\(settings.fontSizePx)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 24)
            }

            Text("Refreshes every \(settings.refreshIntervalHours) hours")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh", action: onRefreshNow)
                    .buttonStyle(.borderedProminent)
                Button("Regenerate", action: onRegenerateSummary)
                    .disabled(!canRegenerateSummary)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func subfolderRow(_ folder: String) -> some View {
        let depth = folder == "(root)" ? 0 : folder.components(separatedBy: "/").count - 1
        let checked = settings.includedSubfolders.contains(folder)

        return Toggle(isOn: Binding(
            get: { checked },
            set: { _ in onToggleSubfolder(folder) }
        )) {
            Text(folder)
                .font(.caption)
        }
        .padding(.leading, CGFloat(depth * 12))
    }

    private func folderLabel(_ vaultFolderPath: String) -> String {
        if vaultFolderPath.isEmpty {
            return "No folder"
        }

        let parts = vaultFolderPath.split(separator: "/").map(String.init)
        if parts.count <= 2 {
            return vaultFolderPath
        }

        return "…/\(parts.suffix(2).joined(separator: "/"))"
    }
}
