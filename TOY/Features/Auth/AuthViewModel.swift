//
//  AuthViewModel.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import TOYShared

@Observable @MainActor
final class AuthViewModel {
    // MARK: - State

    var isLoading = false
    var errorMessage: String?
    var authState: AuthState = .unknown

    /// Locally selected avatar image for optimistic UI display
    var pendingAvatarImage: UIImage?

    // For Apple Sign-In nonce
    private var currentNonce: String?

    // MARK: - Dependencies

    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol = SupabaseAuthService()) {
        self.authService = authService
    }

    // MARK: - Apple Sign-In

    /// Generates a random nonce for Apple Sign-In
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    /// Returns SHA256 hash of the nonce for Apple Sign-In request
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Handles the Apple Sign-In authorization result
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential type"
                isLoading = false
                return
            }

            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = AuthError.missingIdentityToken.errorDescription
                isLoading = false
                return
            }

            guard let nonce = currentNonce else {
                errorMessage = "Missing nonce for Apple Sign-In"
                isLoading = false
                return
            }

            do {
                let user = try await authService.signInWithApple(
                    idToken: identityToken,
                    nonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                authState = .signedIn(user)
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User cancelled, don't show error
                errorMessage = nil
            } else {
                errorMessage = AuthError.appleSignInFailed.errorDescription
            }
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true

        do {
            try await authService.signOut()
            authState = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        isLoading = true

        do {
            try await authService.deleteAccount()
            authState = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Profile Updates

    /// Updates user's display name with optimistic UI
    func updateDisplayName(_ name: String) {
        guard case .signedIn(let user) = authState else { return }

        // Optimistic update - update UI immediately
        let updatedUser = User(
            id: user.id,
            email: user.email,
            displayName: name,
            avatarURL: user.avatarURL,
            createdAt: user.createdAt
        )
        authState = .signedIn(updatedUser)

        // Background server call
        Task {
            do {
                try await authService.updateDisplayName(name, for: user.id)
            } catch {
                // Revert on failure
                authState = .signedIn(user)
                errorMessage = "Failed to update name"
            }
        }
    }

    /// Updates user's avatar with optimistic UI
    func updateAvatar(_ imageData: Data) {
        guard case .signedIn(let user) = authState else {
            #if DEBUG
            print("📸 [ViewModel] Cannot update avatar - user not signed in")
            #endif
            return
        }

        #if DEBUG
        print("📸 [ViewModel] Starting avatar update for user: \(user.id)")
        print("📸 [ViewModel] Image data size: \(imageData.count) bytes")
        #endif

        // Optimistic UI - show the image immediately
        if let uiImage = UIImage(data: imageData) {
            pendingAvatarImage = uiImage
            #if DEBUG
            print("📸 [ViewModel] Pending image set for optimistic UI")
            #endif
        }

        // Background server call
        Task {
            do {
                let avatarURL = try await authService.updateAvatar(imageData, for: user.id)
                #if DEBUG
                print("📸 [ViewModel] Upload succeeded, URL: \(avatarURL.absoluteString)")
                #endif

                // Add cache-busting timestamp to URL
                let cacheBustedURL = avatarURL.appending(queryItems: [
                    URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))
                ])
                #if DEBUG
                print("📸 [ViewModel] Cache-busted URL: \(cacheBustedURL.absoluteString)")
                #endif

                // Update state with new avatar URL
                let updatedUser = User(
                    id: user.id,
                    email: user.email,
                    displayName: user.displayName,
                    avatarURL: cacheBustedURL,
                    createdAt: user.createdAt
                )
                authState = .signedIn(updatedUser)
                #if DEBUG
                print("📸 [ViewModel] Auth state updated with new avatar URL")
                #endif
                // DON'T clear pendingAvatarImage - keep it as fallback while AsyncImage loads
                // It will be replaced next time user selects a photo
            } catch {
                // DON'T clear pendingAvatarImage on failure - keep showing selected image
                errorMessage = "Failed to upload photo"
                #if DEBUG
                print("📸 [ViewModel] Avatar upload FAILED: \(error)")
                print("📸 [ViewModel] Error details: \(String(describing: error))")
                #endif
            }
        }
    }

    // MARK: - Auth State

    func checkAuthState() async {
        if let user = await authService.getCurrentUser() {
            authState = .signedIn(user)
        } else {
            authState = .signedOut
        }
    }

    func observeAuthChanges() async {
        for await state in authService.observeAuthState() {
            authState = state
        }
    }

    // MARK: - Private Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
}
