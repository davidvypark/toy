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
