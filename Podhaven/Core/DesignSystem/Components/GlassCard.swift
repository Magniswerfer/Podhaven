import SwiftUI

// MARK: - Glass Card Modifier

/// A view modifier that applies the liquid glass card styling
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.medium
    var includeShadow: Bool = true
    var includeBorder: Bool = true

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if includeBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
            }
            .modifier(ConditionalShadow(enabled: includeShadow))
    }
}

private struct ConditionalShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.glassCardShadow()
        } else {
            content
        }
    }
}

extension View {
    /// Applies liquid glass card styling
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the card (default: CornerRadius.medium)
    ///   - includeShadow: Whether to include a shadow (default: true)
    ///   - includeBorder: Whether to include the subtle border highlight (default: true)
    func glassCard(
        cornerRadius: CGFloat = CornerRadius.medium,
        includeShadow: Bool = true,
        includeBorder: Bool = true
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            includeShadow: includeShadow,
            includeBorder: includeBorder
        ))
    }
}

// MARK: - Glass Card Container

/// A container view with liquid glass styling
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = CornerRadius.medium
    var padding: CGFloat = Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassCard(cornerRadius: cornerRadius)
    }
}

// MARK: - Glass Background

/// A view modifier that applies a gradient-enhanced glass background
struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.medium

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Subtle gradient highlight
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
    }
}

extension View {
    /// Applies a gradient-enhanced glass background
    func glassBackground(cornerRadius: CGFloat = CornerRadius.medium) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Card")
                    .font(.headline)
                Text("This is a reusable glass card component")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("Content with glass modifier")
            .padding()
            .glassCard()
    }
    .padding()
    .background(Color.accentColor.opacity(0.1))
}
