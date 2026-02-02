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
    public static let revenueCatAPIKey = "appl_REPLACE_WITH_YOUR_KEY"

    // MARK: - PostHog Analytics (main app only)

    /// PostHog API key - replace with your key from PostHog Dashboard
    /// Dashboard -> Project Settings -> Project API Key
    public static let postHogAPIKey = "phc_REPLACE_WITH_YOUR_KEY"

    /// PostHog host URL
    /// Use "https://us.i.posthog.com" for US or "https://eu.i.posthog.com" for EU
    public static let postHogHost = "https://us.i.posthog.com"
}
