import SwiftUI

/// A themed text field component with consistent styling.
public struct TOYTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let icon: String?
    private let errorMessage: String?

    @FocusState private var isFocused: Bool

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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.toyBody())
                .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.toySurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1.5)
            )

            if let error = errorMessage {
                Text(error)
                    .font(.toyCaption())
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return .red
        } else if isFocused {
            return .toyPrimary
        } else {
            return Color.gray.opacity(0.3)
        }
    }

    private var iconColor: Color {
        if isFocused {
            return .toyPrimary
        } else {
            return .toyTextSecondary
        }
    }
}

// MARK: - Previews

#Preview("Text Fields") {
    VStack(spacing: 20) {
        TOYTextField("Email", text: .constant(""), icon: "envelope")
        TOYTextField("Password", text: .constant(""), isSecure: true, icon: "lock")
        TOYTextField("With Error", text: .constant("bad@email"), icon: "envelope", errorMessage: "Invalid email format")
        TOYTextField("Filled", text: .constant("hello@example.com"), icon: "envelope")
    }
    .padding()
}
