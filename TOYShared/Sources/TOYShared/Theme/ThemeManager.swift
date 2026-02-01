import SwiftUI

public enum AppTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
public final class ThemeManager: Sendable {
    @ObservationIgnored
    @AppStorage("selectedTheme") private var storedTheme: String = AppTheme.system.rawValue

    public var selectedTheme: AppTheme {
        get { AppTheme(rawValue: storedTheme) ?? .system }
        set { storedTheme = newValue.rawValue }
    }

    public var colorScheme: ColorScheme? {
        selectedTheme.colorScheme
    }

    public init() {}
}
