import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onPreferencesChanged: (() -> Void)?

    private let backgroundPopup = NSPopUpButton()
    private let iconSizeSlider = NSSlider(value: Double(Preferences.shared.iconSize), minValue: 18, maxValue: 36, target: nil, action: nil)
    private let heightSlider = NSSlider(value: Double(Preferences.shared.stripHeight), minValue: 24, maxValue: 44, target: nil, action: nil)
    private let tooltipCheckbox = NSButton(checkboxWithTitle: "Show app names in tooltips", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 285),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BarDock Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.contentView = makeContentView()
        syncControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeContentView() -> NSView {
        let contentView = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        backgroundPopup.addItems(withTitles: Preferences.BackgroundStyle.allCases.map(\.title))
        backgroundPopup.target = self
        backgroundPopup.action = #selector(preferencesChanged)

        iconSizeSlider.target = self
        iconSizeSlider.action = #selector(preferencesChanged)

        heightSlider.target = self
        heightSlider.action = #selector(preferencesChanged)

        tooltipCheckbox.target = self
        tooltipCheckbox.action = #selector(preferencesChanged)

        stack.addArrangedSubview(row(label: "Background", control: backgroundPopup))
        stack.addArrangedSubview(row(label: "Icon Size", control: iconSizeSlider))
        stack.addArrangedSubview(row(label: "Strip Height", control: heightSlider))
        stack.addArrangedSubview(tooltipCheckbox)
        stack.addArrangedSubview(aboutDetails())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])

        return contentView
    }

    private func row(label text: String, control: NSControl) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 94).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func aboutDetails() -> NSView {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let text = """
        BarDock \(version)   https://bardock.appx.uk
        (c) First Option Limited 2026
        """
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        return label
    }

    private func syncControls() {
        let preferences = Preferences.shared
        backgroundPopup.selectItem(withTitle: preferences.backgroundStyle.title)
        iconSizeSlider.doubleValue = Double(preferences.iconSize)
        heightSlider.doubleValue = Double(preferences.stripHeight)
        tooltipCheckbox.state = preferences.showAppNamesInTooltips ? .on : .off
    }

    @objc private func preferencesChanged() {
        let preferences = Preferences.shared

        if let selectedTitle = backgroundPopup.selectedItem?.title,
           let style = Preferences.BackgroundStyle.allCases.first(where: { $0.title == selectedTitle }) {
            preferences.backgroundStyle = style
        }

        preferences.iconSize = CGFloat(iconSizeSlider.doubleValue)
        preferences.stripHeight = CGFloat(heightSlider.doubleValue)
        preferences.showAppNamesInTooltips = tooltipCheckbox.state == .on
        onPreferencesChanged?()
    }
}
