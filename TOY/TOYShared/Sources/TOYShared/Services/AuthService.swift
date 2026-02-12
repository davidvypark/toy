import Foundation
import Supabase
import Auth

// MARK: - Auth State

/// Represents the current authentication state
public enum AuthState: Equatable, Sendable {
    case unknown
    case signedOut
    case signedIn(User)

    public var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    public var user: User? {
        if case .signedIn(let user) = self { return user }
        return nil
    }
}

// MARK: - Auth Error

public enum AuthError: LocalizedError, Sendable {
    case appleSignInFailed
    case appleSignInCancelled
    case missingIdentityToken
    case networkError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .appleSignInFailed:
            return "Apple Sign-In failed. Please try again."
        case .appleSignInCancelled:
            return "Apple Sign-In was cancelled."
        case .missingIdentityToken:
            return "Could not retrieve identity token from Apple."
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Protocol

/// Protocol defining authentication operations
public protocol AuthServiceProtocol: Sendable {
    /// Sign in with Apple identity token
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> User

    /// Sign out the current user
    func signOut() async throws

    /// Get the currently signed in user, if any
    func getCurrentUser() async -> User?

    /// Stream of auth state changes
    func observeAuthState() -> AsyncStream<AuthState>

    /// Update user's display name
    func updateDisplayName(_ name: String, for userId: UUID) async throws

    /// Update user's avatar image
    func updateAvatar(_ imageData: Data, for userId: UUID) async throws -> URL

    /// Delete the current user's account
    func deleteAccount() async throws

    /// Link anonymous App Clip clips to the current authenticated user
    func linkAnonymousClips(anonymousUserIds: [UUID]) async throws -> Int
}

// MARK: - Supabase Implementation

/// Supabase-backed authentication service
public final class SupabaseAuthService: AuthServiceProtocol {
    public init() {}

    public func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> User {
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            let authUser = session.user

            // Update profile with name if provided (Apple only sends name on first sign-in)
            if let fullName = fullName {
                try await updateProfile(for: authUser, fullName: fullName)
            }

            return User(authUser: authUser, fullName: fullName)
        } catch {
            throw mapSupabaseError(error)
        }
    }

    public func signOut() async throws {
        try await supabase.auth.signOut()
    }

    public func getCurrentUser() async -> User? {
        do {
            let session = try await supabase.auth.session
            let authUser = session.user

            #if DEBUG
            print("📱 [Auth] Getting current user: \(authUser.id)")
            #endif

            // Fetch profile data to get display_name and avatar_url
            let profile = try? await fetchProfile(for: authUser.id)

            #if DEBUG
            print("📱 [Auth] Profile data loaded:")
            print("   - displayName: \(profile?.displayName ?? "nil")")
            print("   - avatarURL: \(profile?.avatarURL?.absoluteString ?? "nil")")
            #endif

            let user = User(
                id: authUser.id,
                email: authUser.email,
                displayName: profile?.displayName
                    ?? authUser.userMetadata["display_name"]?.stringValue
                    ?? authUser.userMetadata["full_name"]?.stringValue,
                avatarURL: profile?.avatarURL
                    ?? authUser.userMetadata["avatar_url"]?.stringValue.flatMap { URL(string: $0) },
                createdAt: authUser.createdAt
            )

            #if DEBUG
            print("📱 [Auth] Final user avatarURL: \(user.avatarURL?.absoluteString ?? "nil")")
            #endif

            return user
        } catch {
            #if DEBUG
            print("📱 [Auth] Failed to get current user: \(error)")
            #endif
            return nil
        }
    }

    /// Fetches profile data from the profiles table
    private func fetchProfile(for userId: UUID) async throws -> (displayName: String?, avatarURL: URL?) {
        struct ProfileRow: Decodable {
            let displayName: String?
            let avatarURL: URL?

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case avatarURL = "avatar_url"
            }
        }

        #if DEBUG
        print("📱 [Profile] Fetching profile for user: \(userId)")
        #endif

        let profile: ProfileRow = try await supabase
            .from("profiles")
            .select("display_name, avatar_url")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        #if DEBUG
        print("📱 [Profile] Fetched - displayName: \(profile.displayName ?? "nil"), avatarURL: \(profile.avatarURL?.absoluteString ?? "nil")")
        #endif

        return (displayName: profile.displayName, avatarURL: profile.avatarURL)
    }

    public func observeAuthState() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            let task = Task {
                // Check initial state
                if let user = await getCurrentUser() {
                    continuation.yield(.signedIn(user))
                } else {
                    continuation.yield(.signedOut)
                }

                // Listen for changes
                for await (event, session) in supabase.auth.authStateChanges {
                    switch event {
                    case .signedIn, .tokenRefreshed:
                        if let authUser = session?.user {
                            // Fetch profile data for complete user info
                            let profile = try? await fetchProfile(for: authUser.id)
                            let user = User(
                                id: authUser.id,
                                email: authUser.email,
                                displayName: profile?.displayName
                                    ?? authUser.userMetadata["display_name"]?.stringValue
                                    ?? authUser.userMetadata["full_name"]?.stringValue,
                                avatarURL: profile?.avatarURL
                                    ?? authUser.userMetadata["avatar_url"]?.stringValue.flatMap { URL(string: $0) },
                                createdAt: authUser.createdAt
                            )
                            continuation.yield(.signedIn(user))
                        }
                    case .signedOut:
                        continuation.yield(.signedOut)
                    default:
                        break
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Profile Updates

    public func updateDisplayName(_ name: String, for userId: UUID) async throws {
        struct ProfileUpdate: Encodable {
            let display_name: String
        }

        try await supabase
            .from("profiles")
            .update(ProfileUpdate(display_name: name))
            .eq("id", value: userId)
            .execute()
    }

    public func updateAvatar(_ imageData: Data, for userId: UUID) async throws -> URL {
        let fileName = "\(userId.uuidString)/avatar.jpg"
        let bucket = supabase.storage.from("avatars")

        #if DEBUG
        print("📸 [Avatar] Starting upload for user: \(userId)")
        print("📸 [Avatar] File path: \(fileName)")
        print("📸 [Avatar] Image data size: \(imageData.count) bytes")
        #endif

        // Upload the image
        try await bucket.upload(
            fileName,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )

        #if DEBUG
        print("📸 [Avatar] Upload successful")
        #endif

        // Get the public URL
        let publicURL = try bucket.getPublicURL(path: fileName)

        #if DEBUG
        print("📸 [Avatar] Public URL: \(publicURL.absoluteString)")
        #endif

        // Update the profile with the avatar URL
        struct AvatarUpdate: Encodable {
            let avatar_url: String
        }

        try await supabase
            .from("profiles")
            .update(AvatarUpdate(avatar_url: publicURL.absoluteString))
            .eq("id", value: userId)
            .execute()

        #if DEBUG
        print("📸 [Avatar] Profile updated with avatar URL")
        #endif

        return publicURL
    }

    // MARK: - Account Deletion

    public func deleteAccount() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id

        // 1. Gather clip paths for storage cleanup (while still authenticated)
        struct ClipPaths: Decodable {
            let id: UUID
            let videoUrl: String
            let thumbnailUrl: String?
            enum CodingKeys: String, CodingKey {
                case id
                case videoUrl = "video_url"
                case thumbnailUrl = "thumbnail_url"
            }
        }
        let clips: [ClipPaths] = (try? await supabase
            .from("clips")
            .select("id, video_url, thumbnail_url")
            .eq("participant_id", value: userId)
            .execute()
            .value) ?? []

        // 2. Delete clip files from storage (best effort)
        let clipsBucket = supabase.storage.from("clips")
        for clip in clips {
            try? await clipsBucket.remove(paths: [clip.videoUrl])
            if let thumbnail = clip.thumbnailUrl {
                try? await clipsBucket.remove(paths: [thumbnail])
            }
        }

        // 3. Delete avatar from storage (best effort)
        let avatarBucket = supabase.storage.from("avatars")
        try? await avatarBucket.remove(paths: ["\(userId.uuidString)/avatar.jpg"])

        // 4. Delete DB records via RPC (transfers published cards to system user,
        //    then cascades: profile, clips, unpublished cards, participant refs)
        try await supabase.rpc("delete_own_account").execute()

        // 5. Sign out locally
        try await supabase.auth.signOut()
    }

    // MARK: - Anonymous Clip Linking

    public func linkAnonymousClips(anonymousUserIds: [UUID]) async throws -> Int {
        guard !anonymousUserIds.isEmpty else { return 0 }

        struct LinkResult: Decodable {
            let linked_clips: Int
        }

        struct LinkParams: Encodable {
            let anon_ids: [UUID]
        }

        let result: LinkResult = try await supabase
            .rpc("link_anonymous_clips", params: LinkParams(anon_ids: anonymousUserIds))
            .execute()
            .value

        #if DEBUG
        print("[Auth] Linked \(result.linked_clips) anonymous clips from \(anonymousUserIds.count) sessions")
        #endif

        return result.linked_clips
    }

    // MARK: - Private Helpers

    private func updateProfile(for authUser: Auth.User, fullName: PersonNameComponents) async throws {
        struct ProfileUpdate: Encodable {
            let display_name: String?
        }

        let displayName = [fullName.givenName, fullName.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        guard !displayName.isEmpty else { return }

        try await supabase
            .from("profiles")
            .update(ProfileUpdate(display_name: displayName))
            .eq("id", value: authUser.id)
            .execute()
    }

    private func mapSupabaseError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()

        if message.contains("network") || message.contains("connection") {
            return .networkError(error.localizedDescription)
        } else {
            return .unknown(error.localizedDescription)
        }
    }
}
