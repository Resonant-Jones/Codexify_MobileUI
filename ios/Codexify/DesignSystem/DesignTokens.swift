//
//  DesignTokens.swift
//  Codexify:Scout
//
//  Design token system adapted from Codexify:Vault (AppShell.tsx)
//  Provides consistent spacing, colors, typography, and layout across the mobile app
//

import SwiftUI

// MARK: - Spacing

/// Spacing tokens for consistent padding, margins, and gaps
enum Spacing {
    /// Extra small spacing: 4pt
    static let xs: CGFloat = 4

    /// Small spacing: 8pt
    static let sm: CGFloat = 8

    /// Medium spacing: 16pt (default)
    static let md: CGFloat = 16

    /// Large spacing: 24pt
    static let lg: CGFloat = 24

    /// Extra large spacing: 32pt
    static let xl: CGFloat = 32

    /// Extra extra large spacing: 48pt
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

/// Corner radius tokens for consistent border rounding
enum CornerRadius {
    /// Extra small radius: 2pt
    static let xs: CGFloat = 2

    /// Small radius: 4pt
    static let sm: CGFloat = 4

    /// Medium radius: 8pt
    static let md: CGFloat = 8

    /// Large radius: 12pt
    static let lg: CGFloat = 12

    /// Extra large radius: 16pt
    static let xl: CGFloat = 16

    /// Extra extra large radius: 24pt (pill-shaped)
    static let xxl: CGFloat = 24

    /// Full circle/pill
    static let full: CGFloat = 999
}

// MARK: - Colors

/// Semantic color tokens that adapt to light/dark mode
struct ColorTokens {
    // MARK: Background Colors

    /// Primary background color (light: white, dark: black)
    static let background = Color("Background")

    /// Secondary background for cards and surfaces
    static let surface = Color("Surface")

    /// Elevated surface (slightly lighter/darker than surface)
    static let surfaceElevated = Color("SurfaceElevated")

    /// Overlay background for modals and sheets
    static let overlay = Color("Overlay")

    // MARK: Border Colors

    /// Subtle border color for separators
    static let borderSubtle = Color("BorderSubtle")

    /// Default border color
    static let border = Color("Border")

    /// Emphasized border for focus states
    static let borderEmphasis = Color("BorderEmphasis")

    // MARK: Text Colors

    /// Primary text color (high contrast)
    static let textPrimary = Color("TextPrimary")

    /// Secondary text color (medium contrast)
    static let textSecondary = Color("TextSecondary")

    /// Tertiary text color (low contrast)
    static let textTertiary = Color("TextTertiary")

    /// Disabled text color
    static let textDisabled = Color("TextDisabled")

    // MARK: Brand Colors

    /// Primary brand color (accent)
    static let brandPrimary = Color("BrandPrimary")

    /// Secondary brand color
    static let brandSecondary = Color("BrandSecondary")

    /// Tertiary brand color
    static let brandTertiary = Color("BrandTertiary")

    // MARK: Semantic Colors

    /// Success/positive color
    static let success = Color("Success")

    /// Warning color
    static let warning = Color("Warning")

    /// Error/destructive color
    static let error = Color("Error")

    /// Info/neutral color
    static let info = Color("Info")

    // MARK: System Colors (Fallbacks)

    /// System background (fallback if custom not defined)
    static let systemBackground = Color(.systemBackground)

    /// System secondary background
    static let systemSecondaryBackground = Color(.secondarySystemBackground)

    /// System tertiary background
    static let systemTertiaryBackground = Color(.tertiarySystemBackground)

    /// System grouped background
    static let systemGroupedBackground = Color(.systemGroupedBackground)

    /// System label (text)
    static let systemLabel = Color(.label)

    /// System secondary label
    static let systemSecondaryLabel = Color(.secondaryLabel)
}

// MARK: - Typography

/// Font size tokens for consistent text hierarchy
enum FontSize {
    /// Extra small: 10pt (caption 2)
    static let xs: CGFloat = 10

    /// Small: 12pt (caption)
    static let sm: CGFloat = 12

    /// Medium: 16pt (body, default)
    static let md: CGFloat = 16

    /// Large: 20pt (title 3)
    static let lg: CGFloat = 20

    /// Extra large: 24pt (title 2)
    static let xl: CGFloat = 24

    /// Extra extra large: 32pt (title 1)
    static let xxl: CGFloat = 32

    /// Display: 40pt (large title)
    static let display: CGFloat = 40
}

/// Font weight tokens
enum FontWeight {
    /// Ultralight weight
    static let ultralight = Font.Weight.ultralight

    /// Thin weight
    static let thin = Font.Weight.thin

    /// Light weight
    static let light = Font.Weight.light

    /// Regular weight (default)
    static let regular = Font.Weight.regular

    /// Medium weight
    static let medium = Font.Weight.medium

    /// Semibold weight
    static let semibold = Font.Weight.semibold

    /// Bold weight
    static let bold = Font.Weight.bold

    /// Heavy weight
    static let heavy = Font.Weight.heavy

    /// Black weight
    static let black = Font.Weight.black
}

/// Pre-configured text styles for common use cases
enum TextStyle {
    /// Display heading style
    static let display = Font.system(size: FontSize.display, weight: FontWeight.bold)

    /// H1 heading style
    static let h1 = Font.system(size: FontSize.xxl, weight: FontWeight.bold)

    /// H2 heading style
    static let h2 = Font.system(size: FontSize.xl, weight: FontWeight.semibold)

    /// H3 heading style
    static let h3 = Font.system(size: FontSize.lg, weight: FontWeight.semibold)

    /// Body text style (default)
    static let body = Font.system(size: FontSize.md, weight: FontWeight.regular)

    /// Body emphasized style
    static let bodyEmphasis = Font.system(size: FontSize.md, weight: FontWeight.medium)

    /// Caption style
    static let caption = Font.system(size: FontSize.sm, weight: FontWeight.regular)

    /// Caption emphasized style
    static let captionEmphasis = Font.system(size: FontSize.sm, weight: FontWeight.medium)

    /// Small text style
    static let small = Font.system(size: FontSize.xs, weight: FontWeight.regular)
}

// MARK: - Shadows

/// Shadow style configuration
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// Shadow tokens for elevation and depth
enum Shadows {
    /// No shadow
    static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)

    /// Small shadow (subtle elevation)
    static let sm = ShadowStyle(
        color: .black.opacity(0.05),
        radius: 2,
        x: 0,
        y: 1
    )

    /// Medium shadow (default elevation)
    static let md = ShadowStyle(
        color: .black.opacity(0.1),
        radius: 6,
        x: 0,
        y: 2
    )

    /// Large shadow (prominent elevation)
    static let lg = ShadowStyle(
        color: .black.opacity(0.15),
        radius: 12,
        x: 0,
        y: 4
    )

    /// Extra large shadow (high elevation)
    static let xl = ShadowStyle(
        color: .black.opacity(0.2),
        radius: 20,
        x: 0,
        y: 8
    )
}

// MARK: - Layout

/// Layout tokens for consistent positioning and sizing
enum Layout {
    // MARK: Z-Index

    /// Base content z-index
    static let zIndexBase: Double = 0

    /// Elevated content z-index
    static let zIndexElevated: Double = 1

    /// Dropdown/popover z-index
    static let zIndexDropdown: Double = 5

    /// Navbar z-index
    static let zIndexNavbar: Double = 10

    /// Modal z-index
    static let zIndexModal: Double = 20

    /// Tooltip z-index
    static let zIndexTooltip: Double = 30

    /// Toast/notification z-index
    static let zIndexToast: Double = 40

    // MARK: Content Width

    /// Maximum content width for readability
    static let maxContentWidth: CGFloat = 600

    /// Maximum compact width (narrow screens)
    static let maxCompactWidth: CGFloat = 375

    /// Maximum regular width (iPad, landscape)
    static let maxRegularWidth: CGFloat = 768

    // MARK: Breakpoints

    /// Small device breakpoint (iPhone SE)
    static let breakpointSmall: CGFloat = 375

    /// Medium device breakpoint (iPhone standard)
    static let breakpointMedium: CGFloat = 414

    /// Large device breakpoint (iPhone Plus/Max)
    static let breakpointLarge: CGFloat = 480

    /// Extra large device breakpoint (iPad)
    static let breakpointXLarge: CGFloat = 768

    // MARK: Safe Areas

    /// Minimum horizontal padding
    static let horizontalPadding: CGFloat = Spacing.md

    /// Minimum vertical padding
    static let verticalPadding: CGFloat = Spacing.md

    // MARK: Component Heights

    /// Navigation bar height
    static let navbarHeight: CGFloat = 44

    /// Tab bar height
    static let tabBarHeight: CGFloat = 49

    /// Button minimum height
    static let buttonHeight: CGFloat = 44

    /// Small button height
    static let buttonHeightSmall: CGFloat = 32

    /// Large button height
    static let buttonHeightLarge: CGFloat = 56

    /// Text field height
    static let textFieldHeight: CGFloat = 44

    /// Card minimum height
    static let cardMinHeight: CGFloat = 100

    // MARK: Icon Sizes

    /// Small icon size
    static let iconSizeSmall: CGFloat = 16

    /// Medium icon size (default)
    static let iconSizeMedium: CGFloat = 24

    /// Large icon size
    static let iconSizeLarge: CGFloat = 32

    /// Extra large icon size
    static let iconSizeXLarge: CGFloat = 48
}

// MARK: - Animation

/// Animation tokens for consistent motion
enum Animation {
    /// Quick animation duration
    static let quick: Double = 0.2

    /// Default animation duration
    static let normal: Double = 0.3

    /// Slow animation duration
    static let slow: Double = 0.5

    /// Standard easing
    static let easeInOut = SwiftUI.Animation.easeInOut(duration: normal)

    /// Spring animation
    static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Bouncy spring animation
    static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - Opacity

/// Opacity tokens for consistent transparency
enum Opacity {
    /// Invisible (0%)
    static let invisible: Double = 0.0

    /// Subtle (5%)
    static let subtle: Double = 0.05

    /// Light (10%)
    static let light: Double = 0.1

    /// Medium (50%)
    static let medium: Double = 0.5

    /// Heavy (80%)
    static let heavy: Double = 0.8

    /// Opaque (100%)
    static let opaque: Double = 1.0

    /// Disabled state (40%)
    static let disabled: Double = 0.4
}

// MARK: - View Extensions

extension View {
    /// Apply a shadow style to the view
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }

    /// Apply a card style (surface background with shadow and corner radius)
    func cardStyle(elevation: ShadowStyle = Shadows.md) -> some View {
        self
            .background(ColorTokens.surface)
            .cornerRadius(CornerRadius.lg)
            .shadow(elevation)
    }

    /// Apply responsive padding based on screen size
    func responsivePadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, Layout.horizontalPadding)
    }

    /// Apply maximum content width constraint
    func maxContentWidth() -> some View {
        self.frame(maxWidth: Layout.maxContentWidth)
    }
}

// MARK: - Button Styles

/// Pre-configured button styles using design tokens
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TextStyle.bodyEmphasis)
            .foregroundColor(.white)
            .frame(height: Layout.buttonHeight)
            .padding(.horizontal, Spacing.lg)
            .background(ColorTokens.brandPrimary)
            .cornerRadius(CornerRadius.lg)
            .opacity(configuration.isPressed ? Opacity.heavy : Opacity.opaque)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Animation.spring, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TextStyle.bodyEmphasis)
            .foregroundColor(ColorTokens.brandPrimary)
            .frame(height: Layout.buttonHeight)
            .padding(.horizontal, Spacing.lg)
            .background(ColorTokens.surface)
            .cornerRadius(CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? Opacity.heavy : Opacity.opaque)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Animation.spring, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TextStyle.bodyEmphasis)
            .foregroundColor(ColorTokens.brandPrimary)
            .frame(height: Layout.buttonHeight)
            .padding(.horizontal, Spacing.lg)
            .background(Color.clear)
            .opacity(configuration.isPressed ? Opacity.medium : Opacity.opaque)
    }
}

// MARK: - Example Usage

#if DEBUG
struct DesignTokensPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Typography Examples
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Typography")
                        .font(TextStyle.h2)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Display Heading")
                        .font(TextStyle.display)

                    Text("Heading 1")
                        .font(TextStyle.h1)

                    Text("Heading 2")
                        .font(TextStyle.h2)

                    Text("Body Text - Regular weight for comfortable reading")
                        .font(TextStyle.body)
                        .foregroundColor(ColorTokens.textSecondary)

                    Text("Caption text for supplementary information")
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                }
                .cardStyle()
                .padding(.horizontal, Spacing.md)

                // Button Examples
                VStack(spacing: Spacing.md) {
                    Text("Buttons")
                        .font(TextStyle.h2)
                        .foregroundColor(ColorTokens.textPrimary)

                    Button("Primary Button") {}
                        .buttonStyle(PrimaryButtonStyle())

                    Button("Secondary Button") {}
                        .buttonStyle(SecondaryButtonStyle())

                    Button("Ghost Button") {}
                        .buttonStyle(GhostButtonStyle())
                }
                .cardStyle()
                .padding(.horizontal, Spacing.md)

                // Spacing Examples
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Spacing")
                        .font(TextStyle.h2)
                        .foregroundColor(ColorTokens.textPrimary)

                    HStack(spacing: Spacing.xs) {
                        spacingBox("XS")
                        spacingBox("XS")
                    }

                    HStack(spacing: Spacing.sm) {
                        spacingBox("SM")
                        spacingBox("SM")
                    }

                    HStack(spacing: Spacing.md) {
                        spacingBox("MD")
                        spacingBox("MD")
                    }
                }
                .cardStyle()
                .padding(.horizontal, Spacing.md)

                // Color Examples
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Colors")
                        .font(TextStyle.h2)
                        .foregroundColor(ColorTokens.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        colorSwatch(ColorTokens.brandPrimary, "Primary")
                        colorSwatch(ColorTokens.success, "Success")
                        colorSwatch(ColorTokens.warning, "Warning")
                        colorSwatch(ColorTokens.error, "Error")
                    }
                }
                .cardStyle()
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.lg)
        }
        .background(ColorTokens.background)
    }

    private func spacingBox(_ label: String) -> some View {
        Text(label)
            .font(TextStyle.caption)
            .foregroundColor(ColorTokens.textSecondary)
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .cornerRadius(CornerRadius.sm)
    }

    private func colorSwatch(_ color: Color, _ label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(color)
                .frame(height: 40)

            Text(label)
                .font(TextStyle.small)
                .foregroundColor(ColorTokens.textTertiary)
        }
    }
}

struct DesignTokensPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DesignTokensPreview()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            DesignTokensPreview()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
