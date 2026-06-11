import Foundation

@MainActor
final class NoteNavigation: ObservableObject {
    @Published private(set) var canGoBack = false

    private var history: [String] = []
    private var currentFilePath: String?

    func syncCurrentFilePath(_ filePath: String) {
        currentFilePath = filePath.isEmpty ? nil : filePath
    }

    func handleExternalNoteUpdate(_ filePath: String) {
        guard !filePath.isEmpty else { return }

        if let current = currentFilePath, current != filePath, history.last != current {
            history.append(current)
            canGoBack = true
        }

        currentFilePath = filePath
    }

    func navigateToRelated(from currentPath: String, to filePath: String, loadNote: (String) -> Void) {
        guard filePath != currentPath else { return }

        if !currentPath.isEmpty {
            history.append(currentPath)
            canGoBack = true
        }

        currentFilePath = filePath
        loadNote(filePath)
    }

    func goBack(loadNote: (String) -> Void) {
        guard let previous = history.popLast() else { return }
        canGoBack = !history.isEmpty
        currentFilePath = previous
        loadNote(previous)
    }

    func goBackToTop(loadNote: (String) -> Void) {
        guard let first = history.first else { return }
        history.removeAll()
        canGoBack = false
        currentFilePath = first
        loadNote(first)
    }

    func clearHistory() {
        history.removeAll()
        canGoBack = false
    }
}
