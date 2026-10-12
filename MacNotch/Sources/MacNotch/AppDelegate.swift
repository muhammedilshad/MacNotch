import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var mainWindow: NSWindow?
    private let mainState = MainViewState()
    private var titleObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        NowPlayingMonitor.shared.start()
        BatteryMonitor.shared.start()
        AudioController.shared.start()
        NotchController.shared.start()
        HotKey.register(.toggleNotch) { AppDelegate.toggleNotch() }
        HotKey.register(.screenText) { NotchController.shared.captureScreenText() }
        showMainWindow()
    }

    static func toggleNotch() {
        AppSettings.shared.notchEnabled.toggle()
    }

    @objc func toggleNotch(_ sender: Any?) {
        Self.toggleNotch()
    }

    @objc func captureScreenText(_ sender: Any?) {
        NotchController.shared.captureScreenText()
    }

    @objc func openMainWindow(_ sender: Any?) {
        showMainWindow()
    }

    // Right-click on the Dock icon.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let enabled = AppSettings.shared.notchEnabled
        let toggle = NSMenuItem(title: enabled ? "Turn Notch Off" : "Turn Notch On",
                                action: #selector(toggleNotch(_:)), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        return menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // The notch panel is always "visible", so always bring the main window back on Dock click.
        showMainWindow()
        return true
    }

    // Closing the main window keeps the notch running; quit from the menu or Cmd+Q.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleNotch(_:)) {
            menuItem.state = AppSettings.shared.notchEnabled ? .on : .off
        }
        return true
    }

    func showMainWindow(pane: Pane) {
        mainState.pane = pane
        showMainWindow()
    }

    func showMainWindow() {
        if mainWindow == nil {
            let root = MainView(state: mainState).notchEnvironment(NotchController.shared.model)
            let host = NSHostingController(rootView: root)
            host.sizingOptions = []

            let window = NSWindow(contentViewController: host)
            window.title = "MacNotch"
            // Unified toolbar with the sidebar running to the top, like System Settings.
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.toolbar = NSToolbar()
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 960, height: 720))
            window.minSize = NSSize(width: 820, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("MacNotchMainWindow")
            mainWindow = window
            // The title bar names the open section, as in System Settings.
            titleObserver = mainState.$pane.sink { [weak window] pane in
                window?.title = (pane ?? .overview) == .overview ? "MacNotch" : (pane ?? .overview).title
            }
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MacNotch",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide MacNotch", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MacNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(appMenu, title: "MacNotch", to: main)

        let notch = NSMenu(title: "Notch")
        let toggle = NSMenuItem(title: "Show Notch", action: #selector(AppDelegate.toggleNotch(_:)), keyEquivalent: "n")
        toggle.keyEquivalentModifierMask = [.control, .option, .command]
        notch.addItem(toggle)
        let ocr = NSMenuItem(title: "Copy Text from Screen…", action: #selector(AppDelegate.captureScreenText(_:)), keyEquivalent: "t")
        ocr.keyEquivalentModifierMask = [.control, .option, .command]
        notch.addItem(ocr)
        notch.addItem(.separator())
        notch.addItem(withTitle: "Open MacNotch Window", action: #selector(AppDelegate.openMainWindow(_:)), keyEquivalent: "0")
        add(notch, title: "Notch", to: main)

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(edit, title: "Edit", to: main)

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        add(window, title: "Window", to: main)
        NSApp.windowsMenu = window

        return main
    }

    private static func add(_ menu: NSMenu, title: String, to main: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
