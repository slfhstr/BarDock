import AppKit

@MainActor
final class Preferences {
    static let shared = Preferences()

    enum BackgroundStyle: String, CaseIterable {
        case system
        case barDock
        case graphite
        case clear

        var title: String {
            switch self {
            case .system: return "System"
            case .barDock: return "BarDock"
            case .graphite: return "Graphite"
            case .clear: return "Clear"
            }
        }
    }

    private let defaults = UserDefaults.standard

    var iconSize: CGFloat {
        get { value(for: "iconSize", fallback: 24, range: 18...36) }
        set { defaults.set(Double(newValue), forKey: "iconSize") }
    }

    var stripHeight: CGFloat {
        get { value(for: "stripHeight", fallback: 32, range: 24...44) }
        set { defaults.set(Double(newValue), forKey: "stripHeight") }
    }

    var backgroundStyle: BackgroundStyle {
        get {
            guard let rawValue = defaults.string(forKey: "backgroundStyle"),
                  let style = BackgroundStyle(rawValue: rawValue) else {
                return .system
            }
            return style
        }
        set { defaults.set(newValue.rawValue, forKey: "backgroundStyle") }
    }

    var showAppNamesInTooltips: Bool {
        get { defaults.object(forKey: "showAppNamesInTooltips") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showAppNamesInTooltips") }
    }

    private func value(for key: String, fallback: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        let stored = defaults.double(forKey: key)
        guard stored > 0 else { return fallback }
        return min(max(CGFloat(stored), range.lowerBound), range.upperBound)
    }
}
