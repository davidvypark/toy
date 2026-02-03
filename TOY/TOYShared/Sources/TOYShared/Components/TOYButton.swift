import SwiftUI

/// A themed button component with monochrome visual hierarchy.
///
/// Hierarchy: Primary (solid) → Secondary (outlined) → Text (underlined)
public struct TOYButton: View {
    public enum Style {
        case primary      // Solid fill, main CTA
        case secondary    // Outlined, secondary action
        case text         // Underlined text, tertiary action
        case destructive  // Red/warning style for delete actions
    }

    public enum Size {
        case small   // Compact buttons
        case medium  // Default size
        case large   // Full-width CTAs
    }

    @Environment(\.colorScheme) private var colorScheme

    private let title: String
    private let style: Style
    private let size: Size
    private let isLoading: Bool
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .medium,
        isLoading: Bool = false,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.fullWidth = fullWidth || size == .large
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: TOYSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(fontSize)
                    .fontWeight(fontWeight)
                    .underline(style == .text)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: buttonHeight)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(buttonShape)
            .overlay(borderOverlay)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return colorScheme == .dark ? .warmCream : .warmBlack
        case .secondary, .text:
            return .clear
        case .destructive:
            return .toyDestructive
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return colorScheme == .dark ? .black : .warmCream
        case .secondary, .text:
            return .toyText
        case .destructive:
            return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return .toyText
        default:
            return .clear
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if style == .secondary {
            buttonShape
                .stroke(borderColor, lineWidth: 1.5)
        }
    }

    private var buttonShape: RoundedRectangle {
        // Sharp edges for editorial feel, or pill for softer variant
        RoundedRectangle(cornerRadius: TOYSpacing.cornerRadius)
    }

    private var fontSize: Font {
        switch size {
        case .small: return .toyCaption()
        case .medium: return .toyBody()
        case .large: return .toyBodyMedium()
        }
    }

    private var fontWeight: Font.Weight {
        switch size {
        case .small: return .medium
        case .medium: return .medium
        case .large: return .semibold
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return TOYSpacing.md
        case .medium: return TOYSpacing.lg
        case .large: return TOYSpacing.xl
        }
    }

    private var buttonHeight: CGFloat {
        switch size {
        case .small: return 36
        case .medium: return 48
        case .large: return TOYSpacing.buttonHeight // 56pt
        }
    }
}

// MARK: - Convenience Initializers

public extension TOYButton {
    /// Create a primary CTA button (full-width)
    static func primary(
        _ title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> TOYButton {
        TOYButton(title, style: .primary, size: .large, isLoading: isLoading, action: action)
    }

    /// Create a secondary button
    static func secondary(
        _ title: String,
        action: @escaping () -> Void
    ) -> TOYButton {
        TOYButton(title, style: .secondary, size: .medium, action: action)
    }

    /// Create a text link button
    static func text(
        _ title: String,
        action: @escaping () -> Void
    ) -> TOYButton {
        TOYButton(title, style: .text, size: .medium, action: action)
    }
}

// MARK: - Previews

#Preview("Button Hierarchy") {
    VStack(spacing: TOYSpacing.lg) {
        TOYButton.primary("Primary Action") {}

        TOYButton("Secondary Action", style: .secondary) {}

        TOYButton("Text Link", style: .text) {}

        TOYButton("Delete", style: .destructive, size: .medium) {}

        TOYButton("Loading...", style: .primary, size: .large, isLoading: true) {}
    }
    .padding(TOYSpacing.lg)
    .toyBackground()
}

#Preview("Button Sizes") {
    VStack(spacing: TOYSpacing.md) {
        TOYButton("Small", size: .small) {}
        TOYButton("Medium", size: .medium) {}
        TOYButton("Large Full Width", size: .large) {}
    }
    .padding(TOYSpacing.lg)
    .toyBackground()
}
