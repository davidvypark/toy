import SwiftUI

public extension Color {
    // MARK: - Core Palette (Monochrome)

    /// Primary background - warm cream in light, true black in dark
    static let toyBackground = Color("TOYBackground")

    /// Primary text - warm black in light, cream in dark
    static let toyText = Color("TOYText")

    /// Secondary text - warm gray
    static let toyTextSecondary = Color("TOYTextSecondary")

    /// Dividers and subtle borders
    static let toyDivider = Color("TOYDivider")

    /// Video container - always true black
    static let toyVideoContainer = Color.black

    // MARK: - Semantic Colors

    /// Destructive actions
    static let toyDestructive = Color("TOYDestructive")
}

// MARK: - Hardcoded Colors (for views that need direct values)

public extension Color {
    /// Warm cream background - light mode
    static let warmCream = Color(red: 253/255, green: 248/255, blue: 243/255) // #FDF8F3

    /// Warm black text - light mode
    static let warmBlack = Color(red: 28/255, green: 25/255, blue: 23/255) // #1C1917

    /// Warm gray secondary text - light mode
    static let warmGrayLight = Color(red: 120/255, green: 113/255, blue: 108/255) // #78716C

    /// Warm gray secondary text - dark mode
    static let warmGrayDark = Color(red: 168/255, green: 162/255, blue: 158/255) // #A8A29E

    /// Divider - light mode
    static let dividerLight = Color(red: 231/255, green: 229/255, blue: 228/255) // #E7E5E4

    /// Divider - dark mode
    static let dividerDark = Color(red: 41/255, green: 37/255, blue: 36/255) // #292524
}

// MARK: - Environment-Aware Colors

public extension Color {
    /// Returns the appropriate text color based on color scheme
    static func adaptiveText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .warmCream : .warmBlack
    }

    /// Returns the appropriate background color based on color scheme
    static func adaptiveBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .warmCream
    }

    /// Returns the appropriate secondary text color based on color scheme
    static func adaptiveTextSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .warmGrayDark : .warmGrayLight
    }

    /// Returns the appropriate divider color based on color scheme
    static func adaptiveDivider(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .dividerDark : .dividerLight
    }
}
