import SwiftUI

/// A themed label component with preset typography styles.
public struct TOYLabel: View {
    public enum Style {
        case display       // 72pt - Hero headlines, cropped
        case displayMedium // 56pt - Large headlines
        case displaySmall  // 48pt - Section headers
        case largeTitle    // 34pt
        case title         // 28pt
        case title2        // 22pt
        case title3        // 20pt
        case headline      // 17pt serif
        case body          // 17pt rounded
        case subheadline   // 15pt rounded
        case footnote      // 13pt rounded
        case caption       // 12pt rounded
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
        case .display: return .toyDisplay()
        case .displayMedium: return .toyDisplayMedium()
        case .displaySmall: return .toyDisplaySmall()
        case .largeTitle: return .toyLargeTitle()
        case .title: return .toyTitle()
        case .title2: return .toyTitle2()
        case .title3: return .toyTitle3()
        case .headline: return .toyHeadline()
        case .body: return .toyBody()
        case .subheadline: return .toySubheadline()
        case .footnote: return .toyFootnote()
        case .caption: return .toyCaption()
        }
    }

    private var textColor: Color {
        switch style {
        case .footnote, .caption:
            return .toyTextSecondary
        default:
            return .toyText
        }
    }
}

// MARK: - Convenience Initializers

public extension TOYLabel {
    /// Creates a display label (DM Serif Display, 72pt) - for hero headlines
    static func display(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .display, color: color)
    }

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

    /// Creates a subheadline label (System Rounded, 15pt medium)
    static func subheadline(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .subheadline, color: color)
    }

    /// Creates a caption label (System Rounded, 12pt, secondary color)
    static func caption(_ text: String, color: Color? = nil) -> TOYLabel {
        TOYLabel(text, style: .caption, color: color)
    }
}

// MARK: - Previews

#Preview("Label Styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            TOYLabel.display("Display")
            TOYLabel("Display Medium", style: .displayMedium)
            TOYLabel("Display Small", style: .displaySmall)

            Divider()

            TOYLabel.largeTitle("Large Title")
            TOYLabel.title("Title")
            TOYLabel("Title 2", style: .title2)
            TOYLabel("Title 3", style: .title3)
            TOYLabel.headline("Headline")

            Divider()

            TOYLabel.body("Body text goes here with more content.")
            TOYLabel.subheadline("Subheadline")
            TOYLabel("Footnote", style: .footnote)
            TOYLabel.caption("Caption text")
        }
        .padding(TOYSpacing.lg)
    }
    .toyBackground()
}
