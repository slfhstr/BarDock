import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var barController: BarDockWindowController?
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBarItem()

        let controller = BarDockWindowController()
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        controller.show()
        barController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        barController?.stop()
    }

    private func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "BarDock")
        item.button?.toolTip = "BarDock"

        let menu = NSMenu()
        menu.addItem(withTitle: "Show BarDock", action: #selector(showBarDock), keyEquivalent: "")
        menu.addItem(withTitle: "Hide BarDock", action: #selector(hideBarDock), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit BarDock", action: #selector(quit), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    @objc private func showBarDock() {
        barController?.show()
    }

    @objc private func hideBarDock() {
        barController?.hide()
    }

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
            settingsController?.onPreferencesChanged = { [weak self] in
                self?.barController?.refreshAppearanceAndLayout()
            }
        }

        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
