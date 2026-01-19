import SwiftUI

// MARK: - Spacing Constants

/// Consistent spacing values based on a 4-point grid system
enum Spacing {
    /// 4pt - Tight spacing within components
    static let xs: CGFloat = 4

    /// 8pt - Standard internal spacing
    static let sm: CGFloat = 8

    /// 12pt - Between related elements
    static let md: CGFloat = 12

    /// 16pt - Standard padding, between sections
    static let lg: CGFloat = 16

    /// 24pt - Major section gaps
    static let xl: CGFloat = 24

    /// 32pt - Screen padding, large gaps
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius Constants

/// Standardized corner radius values
enum CornerRadius {
    /// 8pt - Small thumbnails (48-64px), buttons, badges
    static let small: CGFloat = 8

    /// 12pt - Cards, artwork (80-150px), containers
    static let medium: CGFloat = 12

    /// 20pt - Large artwork (>200px), sheets, modals
    static let large: CGFloat = 20
}

// MARK: - Shadow Definitions

extension View {
    /// Standard glass card shadow for elevated cards
    func glassCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    /// Elevated shadow for floating elements like now playing artwork
    func elevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }

    /// Shadow for bottom-anchored floating elements
    func miniPlayerShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 12, y: -4)
    }

    /// Subtle shadow for list items
    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Animation Constants

enum AnimationDuration {
    /// 0.15s - Micro-interactions, toggles
    static let fast: Double = 0.15

    /// 0.3s - Standard transitions
    static let normal: Double = 0.3

    /// 0.5s - Large content changes
    static let slow: Double = 0.5
}
