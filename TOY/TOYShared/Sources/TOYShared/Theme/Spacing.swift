import SwiftUI

/// Standardized spacing scale for consistent layouts
public enum TOYSpacing {
    /// 4pt - Extra small spacing
    public static let xs: CGFloat = 4

    /// 8pt - Small spacing
    public static let sm: CGFloat = 8

    /// 16pt - Medium spacing (default)
    public static let md: CGFloat = 16

    /// 24pt - Large spacing
    public static let lg: CGFloat = 24

    /// 32pt - Extra large spacing
    public static let xl: CGFloat = 32

    /// 48pt - 2x extra large spacing
    public static let xxl: CGFloat = 48

    /// 64pt - 3x extra large spacing (generous margins)
    public static let xxxl: CGFloat = 64
}

// MARK: - Layout Constants

public extension TOYSpacing {
    /// Standard horizontal screen padding - generous margins
    static let screenPadding: CGFloat = lg

    /// Extended horizontal padding for headlines
    static let headlinePadding: CGFloat = xl

    /// Standard corner radius for buttons
    static let cornerRadius: CGFloat = 12

    /// Pill button corner radius
    static let pillRadius: CGFloat = 28

    /// Standard button height
    static let buttonHeight: CGFloat = 56

    /// Divider thickness
    static let dividerHeight: CGFloat = 1
}

// MARK: - Padding Modifiers

public extension View {
    /// Apply standard screen padding
    func toyScreenPadding() -> some View {
        self.padding(.horizontal, TOYSpacing.screenPadding)
    }

    /// Apply generous padding for important sections
    func toyGenerousPadding() -> some View {
        self.padding(.horizontal, TOYSpacing.xl)
            .padding(.vertical, TOYSpacing.lg)
    }

    /// Apply asymmetric padding (more on leading side)
    func toyAsymmetricPadding() -> some View {
        self.padding(.leading, TOYSpacing.xl)
            .padding(.trailing, TOYSpacing.lg)
    }
}
