import AppKit

/// CLIDE color theme constants.
enum Theme {
    static let bgPrimary = NSColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
    static let bgSecondary = NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)
    static let bgTertiary = NSColor(red: 0.129, green: 0.149, blue: 0.176, alpha: 1.0)
    static let bgHover = NSColor(red: 0.188, green: 0.212, blue: 0.239, alpha: 1.0)
    static let border = NSColor(red: 0.188, green: 0.212, blue: 0.239, alpha: 1.0)
    static let textPrimary = NSColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
    static let textSecondary = NSColor(red: 0.545, green: 0.580, blue: 0.620, alpha: 1.0)
    static let textMuted = NSColor(red: 0.282, green: 0.310, blue: 0.345, alpha: 1.0)
    static let accentGold = NSColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1.0)
    static let accentAmber = NSColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1.0)
    static let accentGreen = NSColor(red: 0.247, green: 0.725, blue: 0.314, alpha: 1.0)
    static let accentRed = NSColor(red: 0.973, green: 0.318, blue: 0.286, alpha: 1.0)
    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let fontSmall = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let fontTiny = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
}
