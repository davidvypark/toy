import Foundation

/// Stores anonymous user IDs from App Clip sessions in a shared App Group container
/// so the main app can link those clips to the authenticated user after Apple Sign-In.
public enum AppClipIdentityStore {

    private static let suiteName = "group.com.kindauseful.TOY"
    private static let key = "app_clip_anonymous_user_ids"

    /// Appends an anonymous user ID to the shared store.
    /// Called by the App Clip after `signInAnonymously()`.
    public static func storeAnonymousUserId(_ userId: UUID) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #if DEBUG
            print("[AppClipIdentityStore] Failed to access shared UserDefaults")
            #endif
            return
        }
        var existing = defaults.stringArray(forKey: key) ?? []
        let idString = userId.uuidString
        if !existing.contains(idString) {
            existing.append(idString)
            defaults.set(existing, forKey: key)
            #if DEBUG
            print("[AppClipIdentityStore] Stored anonymous ID: \(idString). Total: \(existing.count)")
            #endif
        }
    }

    /// Retrieves all stored anonymous user IDs.
    /// Called by the main app after Apple Sign-In.
    public static func retrieveAnonymousUserIds() -> [UUID] {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return [] }
        let strings = defaults.stringArray(forKey: key) ?? []
        return strings.compactMap { UUID(uuidString: $0) }
    }

    /// Clears all stored anonymous user IDs.
    /// Called by the main app after successfully linking clips.
    public static func clearAnonymousUserIds() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: key)
        #if DEBUG
        print("[AppClipIdentityStore] Cleared all stored anonymous IDs")
        #endif
    }
}
