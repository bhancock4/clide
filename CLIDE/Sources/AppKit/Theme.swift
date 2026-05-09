import AppKit

/// CLIDE color theme with dark and light mode support.
enum Theme {
    enum Mode: String {
        case dark, light, system
    }

    static var mode: Mode = .dark

    /// Whether the effective appearance is currently dark.
    static var isDark: Bool {
        switch mode {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    static var bgPrimary: NSColor {
        isDark ? NSColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
               : NSColor(red: 0.965, green: 0.965, blue: 0.975, alpha: 1.0)
    }
    static var bgSecondary: NSColor {
        isDark ? NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)
               : NSColor(red: 0.925, green: 0.925, blue: 0.935, alpha: 1.0)
    }
    static var bgTertiary: NSColor {
        isDark ? NSColor(red: 0.129, green: 0.149, blue: 0.176, alpha: 1.0)
               : NSColor(red: 0.885, green: 0.885, blue: 0.900, alpha: 1.0)
    }
    static var bgHover: NSColor {
        isDark ? NSColor(red: 0.188, green: 0.212, blue: 0.239, alpha: 1.0)
               : NSColor(red: 0.845, green: 0.845, blue: 0.860, alpha: 1.0)
    }
    static var border: NSColor {
        isDark ? NSColor(red: 0.188, green: 0.212, blue: 0.239, alpha: 1.0)
               : NSColor(red: 0.800, green: 0.800, blue: 0.820, alpha: 1.0)
    }
    static var textPrimary: NSColor {
        isDark ? NSColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
               : NSColor(red: 0.110, green: 0.110, blue: 0.130, alpha: 1.0)
    }
    static var textSecondary: NSColor {
        isDark ? NSColor(red: 0.545, green: 0.580, blue: 0.620, alpha: 1.0)
               : NSColor(red: 0.400, green: 0.400, blue: 0.430, alpha: 1.0)
    }
    static var textMuted: NSColor {
        isDark ? NSColor(red: 0.282, green: 0.310, blue: 0.345, alpha: 1.0)
               : NSColor(red: 0.600, green: 0.600, blue: 0.630, alpha: 1.0)
    }

    // Accents stay the same in both modes
    static let accentGold = NSColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1.0)
    static let accentAmber = NSColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1.0)
    static let accentGreen = NSColor(red: 0.247, green: 0.725, blue: 0.314, alpha: 1.0)
    static let accentRed = NSColor(red: 0.973, green: 0.318, blue: 0.286, alpha: 1.0)

    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let fontSmall = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let fontTiny = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    /// Notification posted when the theme mode changes.
    static let didChangeNotification = Notification.Name("ThemeDidChange")

    /// Update theme mode and notify observers.
    static func setMode(_ newMode: Mode) {
        mode = newMode
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Terminal foreground/background for SwiftTerm
    static var terminalBackground: NSColor {
        isDark ? NSColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
               : NSColor(red: 0.965, green: 0.965, blue: 0.975, alpha: 1.0)
    }
    static var terminalForeground: NSColor {
        isDark ? NSColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
               : NSColor(red: 0.110, green: 0.110, blue: 0.130, alpha: 1.0)
    }
}
