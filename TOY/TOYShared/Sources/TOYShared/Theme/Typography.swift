import SwiftUI

public extension Font {
    // MARK: - Headings (DM Serif Display)

    /// Large title - 34pt DM Serif Display
    static func toyLargeTitle(_ size: CGFloat = 34) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .largeTitle)
    }

    /// Title - 28pt DM Serif Display
    static func toyTitle(_ size: CGFloat = 28) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .title)
    }

    /// Title 2 - 22pt DM Serif Display
    static func toyTitle2(_ size: CGFloat = 22) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .title2)
    }

    /// Title 3 - 20pt DM Serif Display
    static func toyTitle3(_ size: CGFloat = 20) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .title3)
    }

    /// Headline - 17pt DM Serif Display
    static func toyHeadline(_ size: CGFloat = 17) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .headline)
    }

    // MARK: - Body Text (System Rounded)

    /// Body - 17pt System Rounded
    static func toyBody(_ size: CGFloat = 17) -> Font {
        .system(size: size, design: .rounded)
    }

    /// Callout - 16pt System Rounded
    static func toyCallout(_ size: CGFloat = 16) -> Font {
        .system(size: size, design: .rounded)
    }

    /// Subheadline - 15pt System Rounded
    static func toySubheadline(_ size: CGFloat = 15) -> Font {
        .system(size: size, design: .rounded)
    }

    /// Footnote - 13pt System Rounded
    static func toyFootnote(_ size: CGFloat = 13) -> Font {
        .system(size: size, design: .rounded)
    }

    /// Caption - 12pt System Rounded
    static func toyCaption(_ size: CGFloat = 12) -> Font {
        .system(size: size, design: .rounded)
    }

    /// Caption 2 - 11pt System Rounded
    static func toyCaption2(_ size: CGFloat = 11) -> Font {
        .system(size: size, design: .rounded)
    }

    // MARK: - Special (Italic for emphasis)

    /// Italic heading - DM Serif Display Italic
    static func toyItalicTitle(_ size: CGFloat = 28) -> Font {
        .custom("DMSerifDisplay-Italic", size: size, relativeTo: .title)
    }
}
