import SwiftUI

// MARK: - Podhaven Color Palette

extension Color {
    /// Podhaven brand colors
    enum Podhaven {
        /// Primary accent color - #FF3B30 (Vibrant Red)
        static let accent = Color(hex: "FF3B30")

        /// Lighter accent for hover/highlight states
        static let accentLight = Color(hex: "FF6B61")

        /// Darker accent for pressed states
        static let accentDark = Color(hex: "D32F2F")

        /// Success color for completed states
        static let success = Color(hex: "34C759")

        /// Warning color for attention states
        static let warning = Color(hex: "FF9500")

        /// Info color for queue and informational elements
        static let info = Color(hex: "5856D6")

        /// Error color (same as accent)
        static let error = accent
    }
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Semantic Swipe Action Colors

extension ShapeStyle where Self == Color {
    /// Color for queue-related swipe actions
    static var queueAction: Color { Color.Podhaven.info }

    /// Color for download swipe actions
    static var downloadAction: Color { .blue }

    /// Color for mark as played swipe actions
    static var playedAction: Color { Color.Podhaven.success }

    /// Color for mark as unplayed swipe actions
    static var unplayedAction: Color { Color.Podhaven.warning }
}
