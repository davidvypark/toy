import Foundation

public enum Configuration {
    // MARK: - Supabase

    public static var supabaseURL: String {
        // Hardcoded for now - TODO: restore Info.plist logic later
        return "https://wlsaolscclwarmxzqjqs.supabase.co"
    }

    public static var supabaseAnonKey: String {
        // Hardcoded for now - TODO: restore Info.plist logic later
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indsc2FvbHNjY2x3YXJteHpxanFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NTExMDksImV4cCI6MjA4NTUyNzEwOX0.jByHR8TuH6ghNI6-zq7giusgvcAN8CRebTUtBFmUYhc"
    }

    // MARK: - App Info

    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.unknown.TOY"
    }

    // MARK: - Feature Flags

    public static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - RevenueCat (main app only)

    /// RevenueCat API key - replace with your key from RevenueCat Dashboard
    /// Dashboard -> API Keys -> Public App-Specific API Keys -> iOS
    public static let revenueCatAPIKey = "test_DPeFpcaJgDSjkeMkilxMVppyqqf"
}
