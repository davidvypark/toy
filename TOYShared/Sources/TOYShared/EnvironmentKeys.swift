import SwiftUI

// MARK: - Environment Keys

/// Environment values for dependency injection throughout the app
public extension EnvironmentValues {
    /// Auth service for authentication operations
    @Entry var authService: AuthServiceProtocol = SupabaseAuthService()
}

// Note: ThemeManager uses @Observable and is passed via .environment(themeManager)
// rather than EnvironmentValues, as it requires @MainActor isolation.
