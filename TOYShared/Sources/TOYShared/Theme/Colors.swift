import SwiftUI

public extension Color {
    // Primary brand color - warm coral/salmon
    static let toyPrimary = Color("TOYPrimary")

    // Secondary accent color
    static let toySecondary = Color("TOYSecondary")

    // Background colors
    static let toyBackground = Color("TOYBackground")
    static let toySurface = Color("TOYSurface")

    // Text colors
    static let toyText = Color("TOYText")
    static let toyTextSecondary = Color("TOYTextSecondary")
}

// Fallback colors for when asset catalog colors aren't available (e.g., previews)
public extension Color {
    static let toyPrimaryFallback = Color(red: 0.91, green: 0.45, blue: 0.42) // Coral
    static let toySecondaryFallback = Color(red: 0.36, green: 0.42, blue: 0.55) // Slate blue
}
