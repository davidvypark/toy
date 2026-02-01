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
    case invalidCredentials
    case emailNotConfirmed
    case networkError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotConfirmed:
            return "Please confirm your email before signing in"
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
    /// Sign up a new user with email and password
    func signUp(email: String, password: String) async throws -> User

    /// Sign in an existing user
    func signIn(email: String, password: String) async throws -> User

    /// Sign out the current user
    func signOut() async throws

    /// Get the currently signed in user, if any
    func getCurrentUser() async -> User?

    /// Stream of auth state changes
    func observeAuthState() -> AsyncStream<AuthState>
}

// MARK: - Supabase Implementation

/// Supabase-backed authentication service
public final class SupabaseAuthService: AuthServiceProtocol {
    public init() {}

    public func signUp(email: String, password: String) async throws -> User {
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            let authUser = response.user

            // Create profile in database
            try await createProfile(for: authUser)

            return User(from: authUser)
        } catch let error as AuthError {
            throw error
        } catch {
            throw mapSupabaseError(error)
        }
    }

    public func signIn(email: String, password: String) async throws -> User {
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            return User(from: session.user)
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
            return User(from: session.user)
        } catch {
            return nil
        }
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
                            continuation.yield(.signedIn(User(from: authUser)))
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

    // MARK: - Private Helpers

    private func createProfile(for authUser: Auth.User) async throws {
        struct ProfileInsert: Encodable {
            let id: UUID
            let email: String?
        }

        let profile = ProfileInsert(id: authUser.id, email: authUser.email)

        try await supabase
            .from("profiles")
            .insert(profile)
            .execute()
    }

    private func mapSupabaseError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login") || message.contains("invalid credentials") {
            return .invalidCredentials
        } else if message.contains("email not confirmed") {
            return .emailNotConfirmed
        } else if message.contains("network") || message.contains("connection") {
            return .networkError(error.localizedDescription)
        } else {
            return .unknown(error.localizedDescription)
        }
    }
}
