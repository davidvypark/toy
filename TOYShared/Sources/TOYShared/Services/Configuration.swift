import Foundation

public enum Configuration {
    // MARK: - Supabase

    public static var supabaseURL: String {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !urlString.isEmpty,
              urlString != "$(SUPABASE_URL)" else {
            #if DEBUG
            // Fallback for development - replace with your actual dev URL
            return "https://placeholder.supabase.co"
            #else
            fatalError("SUPABASE_URL not configured in Info.plist")
            #endif
        }
        return urlString
    }

    public static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              key != "$(SUPABASE_ANON_KEY)" else {
            #if DEBUG
            // Fallback for development - replace with your actual dev key
            return "placeholder-anon-key"
            #else
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist")
            #endif
        }
        return key
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
}
