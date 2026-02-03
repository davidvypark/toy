import SwiftUI

public extension Font {
    // MARK: - Display (DM Serif Display - Oversized, Cropped)

    /// Display - 72pt DM Serif Display for hero headlines that crop at edges
    static func toyDisplay(_ size: CGFloat = 72) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .largeTitle)
    }

    /// Display Medium - 56pt DM Serif Display
    static func toyDisplayMedium(_ size: CGFloat = 56) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .largeTitle)
    }

    /// Display Small - 48pt DM Serif Display
    static func toyDisplaySmall(_ size: CGFloat = 48) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .largeTitle)
    }

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

    // MARK: - Body Text (SF Pro Rounded)

    /// Body - 17pt SF Pro Rounded
    static func toyBody(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    /// Body Medium - 17pt SF Pro Rounded Medium
    static func toyBodyMedium(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Subheadline - 15pt SF Pro Rounded Medium
    static func toySubheadline(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Footnote - 13pt SF Pro Rounded
    static func toyFootnote(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    /// Caption - 12pt SF Pro Rounded
    static func toyCaption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    /// Caption 2 - 11pt SF Pro Rounded
    static func toyCaption2(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    // MARK: - Deprecated (keeping for compatibility)

    @available(*, deprecated, renamed: "toySubheadline")
    static func toyCallout(_ size: CGFloat = 16) -> Font {
        .system(size: size, design: .rounded)
    }

    // MARK: - Special (Italic for emphasis)

    /// Italic heading - DM Serif Display Italic
    static func toyItalicTitle(_ size: CGFloat = 28) -> Font {
        .custom("DMSerifDisplay-Italic", size: size, relativeTo: .title)
    }

    /// Italic display - DM Serif Display Italic for large emphasis
    static func toyItalicDisplay(_ size: CGFloat = 56) -> Font {
        .custom("DMSerifDisplay-Italic", size: size, relativeTo: .largeTitle)
    }
}

// MARK: - Text Style Modifiers

public extension View {
    /// Apply generous letter spacing for smaller text
    func toyLetterSpacing(_ spacing: CGFloat = 0.5) -> some View {
        self.tracking(spacing)
    }
}
