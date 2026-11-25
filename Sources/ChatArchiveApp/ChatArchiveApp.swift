import AppKit
import SwiftUI

@main
struct ChatArchiveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("微信记录", id: "main") {
            ContentView()
        }
        .defaultSize(width: 660, height: 480)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private static func showMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) else {
            return
        }
        let isOnVisibleScreen = NSScreen.screens.contains {
            $0.visibleFrame.intersects(window.frame)
        }
        if !isOnVisibleScreen {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
