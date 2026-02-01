import SwiftUI

/// A themed button component with multiple visual styles.
public struct TOYButton: View {
    public enum Style {
        case primary      // Solid background, main CTA
        case secondary    // Outlined, secondary action
        case text         // Text only, tertiary action
        case destructive  // Red/warning style for delete actions
    }

    public enum Size {
        case small   // Compact buttons
        case medium  // Default size
        case large   // Full-width CTAs
    }

    private let title: String
    private let style: Style
    private let size: Size
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .medium,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(fontSize)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: size == .large ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1.5 : 0)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        switch style {
        case .primary: return .toyPrimary
        case .secondary: return .clear
        case .text: return .clear
        case .destructive: return Color.red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .toyPrimary
        case .text: return .toyPrimary
        case .destructive: return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary: return .toyPrimary
        default: return .clear
        }
    }

    private var fontSize: Font {
        switch size {
        case .small: return .toyCaption()
        case .medium: return .toyBody()
        case .large: return .toyBody()
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 20
        case .large: return 24
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        }
    }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: 20) {
        TOYButton("Primary Button", style: .primary) {}
        TOYButton("Secondary Button", style: .secondary) {}
        TOYButton("Text Button", style: .text) {}
        TOYButton("Delete", style: .destructive) {}
        TOYButton("Loading...", style: .primary, isLoading: true) {}
        TOYButton("Large CTA", style: .primary, size: .large) {}
    }
    .padding()
}
