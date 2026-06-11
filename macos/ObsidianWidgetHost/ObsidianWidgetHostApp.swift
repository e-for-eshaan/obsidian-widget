import SwiftUI

@main
struct ObsidianWidgetHostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra("Obsidian Widget", systemImage: "note.text") {
            MenuBarMenu(appController: appController)
        }

        WindowGroup("Obsidian Widget", id: "main") {
            ZStack {
                NoteViewerView(
                    scheduler: appController.scheduler,
                    navigation: appController.navigation
                )
                .environmentObject(appController)

                MainWindowBridge(appController: appController)
            }
            .task {
                appController.bootstrapIfNeeded()
            }
            .onOpenURL { url in
                if url.scheme == "obsidianwidget" {
                    appController.requestMainWindowOpen()
                }
            }
        }
        .defaultSize(width: 560, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct MenuBarMenu: View {
    @ObservedObject var appController: AppController

    var body: some View {
        Button("Open Note Viewer…") {
            appController.requestMainWindowOpen()
        }

        Divider()

        Button("Choose Obsidian Folder…") {
            appController.chooseVaultFolder()
        }

        Divider()

        Button("Force Refresh") {
            appController.navigation.clearHistory()
            appController.scheduler.forceRefreshNow()
        }

        Button("Refresh Now") {
            appController.navigation.clearHistory()
            appController.scheduler.refreshNow()
        }

        Button("Open Current Note") {
            appController.openCurrentNoteInObsidian()
        }
        .disabled(appController.scheduler.currentNote?.filePath.isEmpty ?? true)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .onAppear {
            appController.bootstrapIfNeeded()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppController.shared?.requestMainWindowOpen()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppController.shared?.requestMainWindowOpen()
    }
}

struct MainWindowBridge: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var appController: AppController

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: appController.pendingMainWindowOpen) { _, pending in
                guard pending else { return }
                presentMainWindow(source: "pendingFlag")
            }
            .onAppear {
                if appController.pendingMainWindowOpen {
                    presentMainWindow(source: "onAppear")
                }
            }
    }

    private func presentMainWindow(source: String) {
        appController.clearPendingMainWindowOpen()

        let noteWindows = NSApp.windows.filter { $0.title == "Obsidian Widget" }

        if let existing = noteWindows.first {
            existing.makeKeyAndOrderFront(nil)
            for duplicate in noteWindows.dropFirst() {
                duplicate.close()
            }
        } else {
            openWindow(id: "main")
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
