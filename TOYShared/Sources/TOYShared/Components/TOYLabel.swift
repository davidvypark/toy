import SwiftUI

/// A themed label component with preset typography styles.
public struct TOYLabel: View {
    public enum Style {
        case largeTitle
        case title
        case title2
        case title3
        case headline
        case body
        case callout
        case subheadline
        case footnote
        case caption
    }

    private let text: String
    private let style: Style
    private let color: Color?

    public init(
        _ text: String,
        style: Style = .body,
        color: Color? = nil
    ) {
        self.text = text
        self.style = style
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color ?? textColor)
    }

    private var font: Font {
        switch style {
        case .largeTitle: return .toyLargeTitle()
        case .title: return .toyTitle()
        case .title2: return .toyTitle2()
        case .title3: return .toyTitle3()
        case .headline: return .toyHeadline()
        case .body: return .toyBody()
        case .callout: return .toyCallout()
        case .subheadline: return .toySubheadline()
        case .footnote: return .toyFootnote()
        case .caption: return .toyCaption()
        }
    }

    private var textColor: Color {
        switch style {
        case .largeTitle, .title, .title2, .title3, .headline, .body:
            return .toyText
        case .callout, .subheadline:
            return .toyText
        case .footnote, .caption:
            return .toyTextSecondary
        }
    }
}

// MARK: - Convenience Initializers

public extension TOYLabel {
    /// Creates a large title label (DM Serif Display, 34pt)
    static func largeTitle(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .largeTitle, color: color)
    }

    /// Creates a title label (DM Serif Display, 28pt)
    static func title(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .title, color: color)
    }

    /// Creates a headline label (DM Serif Display, 17pt)
    static func headline(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .headline, color: color)
    }

    /// Creates a body label (System Rounded, 17pt)
    static func body(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .body, color: color)
    }

    /// Creates a caption label (System Rounded, 12pt, secondary color)
    static func caption(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .caption, color: color)
    }
}

// MARK: - Previews

#Preview("Label Styles") {
    VStack(alignment: .leading, spacing: 16) {
        TOYLabel.largeTitle("Large Title")
        TOYLabel.title("Title")
        TOYLabel("Title 2", style: .title2)
        TOYLabel("Title 3", style: .title3)
        TOYLabel.headline("Headline")
        TOYLabel.body("Body text goes here with more content.")
        TOYLabel("Callout", style: .callout)
        TOYLabel("Subheadline", style: .subheadline)
        TOYLabel("Footnote", style: .footnote)
        TOYLabel.caption("Caption text")
        TOYLabel.body("Custom Color", color: .toyPrimary)
    }
    .padding()
}
