import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        if !CommandLine.arguments.contains("--background") { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func windowWillClose(_ notification: Notification) {
        model.settingsVisible = false
        // Only show up in the Dock while the window is open; the covers keep running in the background.
        NSApp.setActivationPolicy(.accessory)
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "MenuBar Cover"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        model.refreshEnvironment()
        model.settingsVisible = true
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

private func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit MenuBar Cover", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

    let menu = NSMenu()
    for (title, submenu) in [("MenuBar Cover", appMenu), ("Window", windowMenu)] {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }
    return menu
}

let app = NSApplication.shared
app.mainMenu = makeMainMenu()
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
