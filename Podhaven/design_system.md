# Podhaven Design System

This document defines the consistent design language for the Podhaven podcast app, following Apple's Liquid Glass design principles.

---

## Color Palette

### Primary Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Accent** | `#FF3B30` | Primary actions, highlights, active states, progress indicators |
| **AccentLight** | `#FF6B61` | Hover states, lighter accent needs |
| **AccentDark** | `#D32F2F` | Pressed states |

### Semantic Colors

| Name | Usage |
|------|-------|
| `.primary` | Main text, titles |
| `.secondary` | Subtitles, metadata, captions |
| `.tertiary` | Hints, placeholders, disabled states |

### Status Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Success** | `#34C759` | Completed states, downloads finished, mark as played |
| **Warning** | `#FF9500` | Unplayed indicators, attention needed |
| **Error** | `#FF3B30` | Destructive actions, failures |
| **Info** | `#5856D6` | Queue actions, informational badges |

### Material Backgrounds

| Name | Usage |
|------|-------|
| `.ultraThinMaterial` | Primary glass effect (mini player, controls overlay, cards) |
| `.thinMaterial` | Secondary glass effect (stat cards, containers) |
| `.regularMaterial` | Heavier blur for modal backgrounds |

---

## Typography

### Font Weights

- **Bold** (`.fontWeight(.bold)`): Section titles, podcast names, main headings
- **Semibold** (`.fontWeight(.semibold)`): Episode titles, button labels
- **Medium** (`.fontWeight(.medium)`): Subheadings, list item titles
- **Regular**: Body text, descriptions

### Text Styles

| Style | SwiftUI | Usage |
|-------|---------|-------|
| Large Title | `.largeTitle` | Main screen headers |
| Title 2 | `.title2` | Section headers (e.g., "Continue Listening") |
| Headline | `.headline` | Card titles, podcast names in lists |
| Subheadline | `.subheadline` | Episode titles, secondary headers |
| Body | `.body` | Show notes, descriptions |
| Caption | `.caption` | Metadata (duration, date) |
| Caption 2 | `.caption2` | Tertiary info (progress percentages) |

### Special Typography

- **Monospaced Digits**: Use `.monospacedDigit()` for time displays to prevent layout shift
- **Line Limits**:
  - Episode titles: 2 lines
  - Podcast names: 1 line
  - Descriptions: 3 lines (unless expanded)

---

## Spacing

Follow a consistent 4-point grid system:

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4pt | Tight spacing within components |
| `sm` | 8pt | Standard internal spacing |
| `md` | 12pt | Between related elements |
| `lg` | 16pt | Standard padding, between sections |
| `xl` | 24pt | Major section gaps |
| `xxl` | 32pt | Screen padding, large gaps |

---

## Corner Radius

Standardized corner radius values:

| Size | Value | Usage |
|------|-------|-------|
| **Small** | 8pt | Small thumbnails (48-64px), buttons, badges |
| **Medium** | 12pt | Cards, artwork (80-150px), containers |
| **Large** | 20pt | Large artwork (>200px), sheets, modals |

Always use `.continuous` style for natural curves:
```swift
RoundedRectangle(cornerRadius: 12, style: .continuous)
```

---

## Shadows

### Glass Card Shadow
```swift
.shadow(color: .black.opacity(0.08), radius: 8, y: 4)
```
Usage: Stat cards, list items with depth

### Elevated Shadow
```swift
.shadow(color: .black.opacity(0.15), radius: 16, y: 8)
```
Usage: Now playing artwork, floating elements

### Mini Player Shadow
```swift
.shadow(color: .black.opacity(0.15), radius: 12, y: -4)
```
Usage: Bottom-anchored floating elements

---

## Liquid Glass Effects

### Glass Background
```swift
.background(.ultraThinMaterial)
```

### Glass Container
```swift
.background {
    ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)

        // Subtle gradient highlight
        LinearGradient(
            colors: [Color.white.opacity(0.05), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
.overlay {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
}
```

### Glass Card (Full Pattern)
```swift
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
.overlay {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
}
.shadow(color: .black.opacity(0.08), radius: 8, y: 4)
```

---

## Icons

### SF Symbols Guidelines

- Use **filled** variants for active/selected states
- Use **outline** variants for inactive/unselected states
- Standard weights: `.regular` for UI, `.medium` for emphasis

### Common Icons

| Action | Icon |
|--------|------|
| Play | `play.fill` |
| Pause | `pause.fill` |
| Skip Forward | `goforward.30` |
| Skip Backward | `gobackward.15` |
| Download | `arrow.down.circle` |
| Downloaded | `arrow.down.circle.fill` |
| Queue Add | `text.badge.plus` |
| Mark Played | `checkmark.circle.fill` |
| Mark Unplayed | `circle` |
| Settings | `gear` |
| Search | `magnifyingglass` |
| Library | `books.vertical` |
| Dashboard | `house` |
| Playlist | `music.note.list` |

### Symbol Effects

```swift
// Playing animation
.symbolEffect(.variableColor.iterative)

// State change transition
.contentTransition(.symbolEffect(.replace))

// Bounce on tap
.symbolEffect(.bounce, value: trigger)
```

---

## Animations

### Duration Tokens

| Name | Value | Usage |
|------|-------|-------|
| Fast | 0.15s | Micro-interactions, toggles |
| Normal | 0.3s | Standard transitions |
| Slow | 0.5s | Large content changes |

### Animation Curves

```swift
// Standard smooth
.animation(.smooth(duration: 0.3), value: state)

// Spring for bouncy interactions
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)

// Ease in/out for fades
.animation(.easeInOut(duration: 0.2), value: state)
```

### Common Transitions

```swift
// Fade
.transition(.opacity)

// Slide from bottom
.transition(.move(edge: .bottom).combined(with: .opacity))

// Scale
.transition(.scale.combined(with: .opacity))
```

---

## Component Patterns

### Swipe Actions

**Leading (Swipe Right):**
- Primary action (e.g., Mark as Played)
- Allow full swipe: `allowsFullSwipe: true`
- Color: Success green for positive, Warning orange for toggle

**Trailing (Swipe Left):**
- Secondary actions (Queue, Download, Delete)
- Allow full swipe: `allowsFullSwipe: false`
- Colors: `.indigo` for queue, `.blue` for download, `.red` for delete

### Progress Indicators

**Linear Progress Bar:**
```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        Capsule()
            .fill(Color.secondary.opacity(0.2))
        Capsule()
            .fill(Color.accentColor)
            .frame(width: geo.size.width * progress)
    }
}
.frame(height: 3)
```

**Circular Progress:**
```swift
ZStack {
    Circle()
        .stroke(Color.black.opacity(0.2), lineWidth: 3)
    Circle()
        .trim(from: 0, to: progress)
        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90))
}
```

### Empty States

- Centered vertically
- Large SF Symbol icon (`.largeTitle`)
- Title in `.headline`
- Description in `.subheadline`, `.secondary` color
- Optional CTA button with `.borderedProminent`

---

## Accessibility

### Dynamic Type
- All text should respect Dynamic Type
- Use semantic text styles (`.headline`, `.body`) not fixed sizes

### Color Contrast
- Ensure 4.5:1 minimum contrast for normal text
- 3:1 minimum for large text and UI components

### Hit Targets
- Minimum 44×44pt touch targets
- Use `.contentShape(Rectangle())` to expand hit areas

### VoiceOver
- Add meaningful labels to icon-only buttons
- Use `.accessibilityLabel()` and `.accessibilityHint()`

---

## File Structure

```
Podhaven/
├── Core/
│   └── DesignSystem/
│       ├── PodheavenColors.swift      # Color definitions
│       ├── PodheavenTypography.swift  # Text style modifiers
│       ├── PodheavenSpacing.swift     # Spacing constants
│       └── Components/
│           ├── GlassCard.swift        # Reusable glass container
│           ├── ProgressBar.swift      # Linear progress bar
│           ├── CircularProgress.swift # Circular progress indicator
│           └── ArtworkView.swift      # Consistent artwork display
```
