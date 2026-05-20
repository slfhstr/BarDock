import AppKit

@MainActor
final class BarDockWindowController: NSWindowController {
    var onOpenSettings: (() -> Void)?

    private let barView = BarDockView()
    private let workspace = NSWorkspace.shared
    private var observerTokens: [NSObjectProtocol] = []

    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = barView
        panel.contentView?.wantsLayer = true

        super.init(window: panel)

        barView.onOpenSettings = { [weak self] in self?.onOpenSettings?() }
        barView.onActivateApp = { [weak self] app in self?.activate(app) }
        startObserving()
        refreshApps()
        refreshAppearanceAndLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshApps()
        refreshAppearanceAndLayout()
        window?.setIsVisible(true)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func stop() {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        observerTokens.removeAll()
    }

    func refreshAppearanceAndLayout() {
        barView.applyPreferences()
        updateFrame()
    }

    private func startObserving() {
        let center = workspace.notificationCenter
        let events: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        observerTokens = events.map { event in
            center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshApps()
                }
            }
        }

        observerTokens.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.updateFrame() }
            }
        )
    }

    private func refreshApps() {
        let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
        let runningApps = workspace.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                !app.isTerminated &&
                app.processIdentifier != ownProcessIdentifier
            }
            .sorted { left, right in
                let comparison = displayName(for: left).localizedStandardCompare(displayName(for: right))
                if comparison == .orderedSame {
                    return left.processIdentifier < right.processIdentifier
                }
                return comparison == .orderedAscending
            }

        barView.setApps(runningApps, activeApp: workspace.frontmostApplication)
        updateFrame()
    }

    private func updateFrame() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let preferences = Preferences.shared
        let width = max(220, screen.visibleFrame.width * 0.90)
        let height = preferences.stripHeight
        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.maxY - height

        window?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func activate(_ app: NSRunningApplication) {
        app.unhide()
        app.activate(options: [.activateAllWindows])
    }

    private func displayName(for app: NSRunningApplication) -> String {
        app.localizedName ?? app.bundleIdentifier ?? ""
    }
}
