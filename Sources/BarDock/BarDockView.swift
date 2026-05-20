import AppKit

@MainActor
final class BarDockView: NSView {
    var onOpenSettings: (() -> Void)?
    var onActivateApp: ((NSRunningApplication) -> Void)?

    private let barDockOrange = NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.18, alpha: 1.0)
    private let effectView = NSVisualEffectView()
    private let tintView = NSView()
    private let settingsButton = IconButton()
    private let separatorView = NSView()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let overflowButton = IconButton()
    private let tooltip = HoverTooltipController()
    private var runningApps: [NSRunningApplication] = []
    private var activeProcessIdentifier: pid_t?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
        applyPreferences()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        tintView.frame = bounds

        let inset: CGFloat = 6
        let buttonSide = Preferences.shared.iconSize + 8
        let contentBounds = bounds.insetBy(dx: inset, dy: 3)
        settingsButton.frame = NSRect(
            x: contentBounds.minX,
            y: contentBounds.midY - buttonSide / 2,
            width: buttonSide,
            height: buttonSide
        )
        separatorView.frame = NSRect(
            x: settingsButton.frame.maxX + 6,
            y: contentBounds.midY - max(12, Preferences.shared.iconSize - 4) / 2,
            width: 1,
            height: max(12, Preferences.shared.iconSize - 4)
        )
        overflowButton.frame = NSRect(
            x: contentBounds.maxX - buttonSide,
            y: contentBounds.midY - buttonSide / 2,
            width: buttonSide,
            height: buttonSide
        )
        let availableScrollX = separatorView.frame.maxX + 8
        let availableScrollWidth = max(0, overflowButton.frame.minX - separatorView.frame.maxX - 16)
        let appWidth = appContentWidth()
        let shouldCenterApps = appWidth > 0 && appWidth < availableScrollWidth
        let scrollWidth = shouldCenterApps ? appWidth : availableScrollWidth
        let scrollX = shouldCenterApps
            ? availableScrollX + (availableScrollWidth - appWidth) / 2
            : availableScrollX

        scrollView.frame = NSRect(
            x: scrollX,
            y: contentBounds.minY,
            width: scrollWidth,
            height: contentBounds.height
        )
        stackView.frame.size = NSSize(width: max(appWidth, scrollWidth), height: scrollView.contentView.bounds.height)
        stackView.frame.origin = .zero
        updateOverflowState()
    }

    func applyPreferences() {
        let preferences = Preferences.shared

        switch preferences.backgroundStyle {
        case .system:
            effectView.isHidden = false
            effectView.material = .hudWindow
            tintView.layer?.backgroundColor = NSColor.clear.cgColor
        case .barDock:
            effectView.isHidden = false
            effectView.material = .hudWindow
            tintView.layer?.backgroundColor = barDockOrange.withAlphaComponent(0.18).cgColor
        case .graphite:
            effectView.isHidden = false
            effectView.material = .underWindowBackground
            tintView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.72).cgColor
        case .clear:
            effectView.isHidden = true
            tintView.layer?.backgroundColor = NSColor.clear.cgColor
        }

        layer?.cornerRadius = max(10, preferences.stripHeight / 2)
        layer?.masksToBounds = true
        configureStaticControls()
        rebuildButtons()
    }

    func setApps(_ apps: [NSRunningApplication], activeApp: NSRunningApplication?) {
        runningApps = apps
        activeProcessIdentifier = activeApp?.processIdentifier
        rebuildButtons()
    }

    private func setupViews() {
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        addSubview(effectView)

        tintView.wantsLayer = true
        addSubview(tintView)

        configureStaticControls()
        addSubview(settingsButton)

        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        addSubview(separatorView)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = stackView
        addSubview(scrollView)

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 6
        stackView.distribution = .gravityAreas

        addSubview(overflowButton)
    }

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for app in runningApps {
            stackView.addArrangedSubview(appButton(for: app))
        }

        stackView.frame.size = stackView.fittingSize
        needsLayout = true
        updateOverflowState()
    }

    private func configureStaticControls() {
        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")
        settingsButton.hoverText = "BarDock Settings"
        settingsButton.symbolScale = 0.8
        settingsButton.contentTintColor = barDockOrange
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.onHoverChanged = { [weak self] button, isHovering in
            self?.updateTooltip(for: button, isHovering: isHovering)
        }
        configureAppearance(settingsButton)

        overflowButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "More apps")
        overflowButton.hoverText = "More apps to the right"
        overflowButton.symbolScale = 1.0
        overflowButton.contentTintColor = barDockOrange
        overflowButton.target = self
        overflowButton.action = #selector(scrollRight)
        overflowButton.onHoverChanged = { [weak self] button, isHovering in
            self?.updateTooltip(for: button, isHovering: isHovering)
        }
        configureAppearance(overflowButton)
    }

    private func appButton(for app: NSRunningApplication) -> NSButton {
        let button = AppButton(app: app)
        button.image = app.icon
        if Preferences.shared.showAppNamesInTooltips {
            button.hoverText = app.localizedName
        }
        button.onHoverChanged = { [weak self] button, isHovering in
            self?.updateTooltip(for: button, isHovering: isHovering)
        }
        button.target = self
        button.action = #selector(activateApp(_:))
        button.isActiveApp = app.processIdentifier == activeProcessIdentifier
        configureStackButton(button)
        return button
    }

    private func configureAppearance(_ button: NSButton) {
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.translatesAutoresizingMaskIntoConstraints = true
        if let iconButton = button as? IconButton, button.image?.isTemplate == true {
            let pointSize = Preferences.shared.iconSize * iconButton.symbolScale
            let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            button.image = button.image?.withSymbolConfiguration(configuration)
        }
    }

    private func configureStackButton(_ button: NSButton) {
        let side = Preferences.shared.iconSize + 8
        configureAppearance(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.frame.size = NSSize(width: side, height: side)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: side),
            button.heightAnchor.constraint(equalToConstant: side)
        ])
    }

    private func updateOverflowState() {
        let visibleMaxX = scrollView.contentView.bounds.maxX
        let contentWidth = appContentWidth()
        let hasOverflowRight = contentWidth - visibleMaxX > 2

        overflowButton.isEnabled = hasOverflowRight
        overflowButton.alphaValue = hasOverflowRight ? 1.0 : 0.45
        overflowButton.hoverText = hasOverflowRight ? "More apps to the right" : "All apps visible"
    }

    private func appContentWidth() -> CGFloat {
        guard !runningApps.isEmpty else { return 0 }

        let buttonSide = Preferences.shared.iconSize + 8
        let iconsWidth = CGFloat(runningApps.count) * buttonSide
        let gapsWidth = CGFloat(max(0, runningApps.count - 1)) * stackView.spacing
        return iconsWidth + gapsWidth
    }

    private func updateTooltip(for button: IconButton, isHovering: Bool) {
        guard Preferences.shared.showAppNamesInTooltips else {
            tooltip.hide()
            return
        }

        guard isHovering, let text = button.hoverText, !text.isEmpty else {
            tooltip.hide()
            return
        }

        tooltip.show(text: text, near: button)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func activateApp(_ sender: NSButton) {
        guard let button = sender as? AppButton else { return }
        onActivateApp?(button.app)
    }

    @objc private func scrollRight() {
        let bounds = scrollView.contentView.bounds
        let contentWidth = stackView.fittingSize.width
        let maxOriginX = max(0, contentWidth - bounds.width)
        let nextOriginX = min(maxOriginX, bounds.origin.x + max(96, bounds.width * 0.75))
        scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: nextOriginX, y: bounds.origin.y))
        reflectScrolledClipView(scrollView.contentView)
    }
}

@MainActor
private class IconButton: NSButton {
    var hoverText: String?
    var onHoverChanged: ((IconButton, Bool) -> Void)?
    var symbolScale: CGFloat = 1.0

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(self, true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(self, false)
    }
}

@MainActor
private final class AppButton: IconButton {
    let app: NSRunningApplication

    var isActiveApp = false {
        didSet { updateStyle() }
    }

    init(app: NSRunningApplication) {
        self.app = app
        super.init(frame: .zero)
        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        super.updateLayer()
        updateStyle()
    }

    private func updateStyle() {
        layer?.backgroundColor = isActiveApp
            ? NSColor.controlAccentColor.withAlphaComponent(0.20).cgColor
            : NSColor.clear.cgColor
        layer?.borderWidth = isActiveApp ? 1 : 0
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
    }
}

@MainActor
private final class HoverTooltipController {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var pendingShow: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 6
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 0.96).cgColor
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.20).cgColor

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.94)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        panel.contentView = contentView

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5)
        ])
    }

    func show(text: String, near view: NSView) {
        pendingShow?.cancel()

        let item = DispatchWorkItem { [weak self, weak view] in
            guard let self, let view, let sourceWindow = view.window else { return }

            label.stringValue = text
            let fittingSize = label.fittingSize
            let width = min(max(fittingSize.width + 18, 54), 220)
            let height = fittingSize.height + 12
            let buttonFrame = view.convert(view.bounds, to: nil)
            let screenFrame = sourceWindow.convertToScreen(buttonFrame)
            let x = screenFrame.midX - width / 2
            let y = screenFrame.minY - height - 6

            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            panel.orderFrontRegardless()
        }

        pendingShow = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
    }

    func hide() {
        pendingShow?.cancel()
        pendingShow = nil
        panel.orderOut(nil)
    }
}
