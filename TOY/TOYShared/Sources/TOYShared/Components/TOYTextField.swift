import SwiftUI

/// A minimal text field with bottom-border styling.
///
/// Editorial design: no box, just a subtle bottom line that emphasizes on focus.
public struct TOYTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let icon: String?
    private let errorMessage: String?

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        icon: String? = nil,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.icon = icon
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.xs) {
            HStack(spacing: TOYSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(iconColor)
                        .frame(width: 24)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.toyBody())
                .foregroundColor(.toyText)
                .tint(.toyText)
                .focused($isFocused)
            }
            .padding(.vertical, TOYSpacing.md)

            // Bottom border only
            Rectangle()
                .fill(borderColor)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            if let error = errorMessage {
                Text(error)
                    .font(.toyCaption())
                    .foregroundColor(.toyDestructive)
                    .padding(.top, TOYSpacing.xs)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return .toyDestructive
        } else if isFocused {
            return .toyText
        } else {
            return .toyDivider
        }
    }

    private var iconColor: Color {
        if isFocused {
            return .toyText
        } else {
            return .toyTextSecondary
        }
    }
}

// MARK: - Label Variant

/// Text field with a floating label above
public struct TOYLabeledTextField: View {
    private let label: String
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let errorMessage: String?

    @FocusState private var isFocused: Bool

    public init(
        label: String,
        placeholder: String = "",
        text: Binding<String>,
        isSecure: Bool = false,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder.isEmpty ? label : placeholder
        self._text = text
        self.isSecure = isSecure
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.sm) {
            Text(label)
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(0.5)

            TOYTextField(
                placeholder,
                text: $text,
                isSecure: isSecure,
                errorMessage: errorMessage
            )
        }
    }
}

// MARK: - Previews

#Preview("Text Fields") {
    VStack(spacing: TOYSpacing.xl) {
        TOYTextField("Enter your name", text: .constant(""))

        TOYTextField("Email address", text: .constant(""), icon: "envelope")

        TOYTextField("Filled field", text: .constant("hello@example.com"), icon: "envelope")

        TOYTextField("With error", text: .constant("bad"), icon: "exclamationmark.circle", errorMessage: "Please enter a valid email")

        TOYLabeledTextField(label: "RECIPIENT NAME", text: .constant(""))
    }
    .padding(TOYSpacing.lg)
    .toyBackground()
}
