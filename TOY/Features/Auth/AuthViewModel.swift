//
//  AuthViewModel.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

@Observable @MainActor
final class AuthViewModel {
    // MARK: - State

    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var authState: AuthState = .unknown

    // MARK: - Dependencies

    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol = SupabaseAuthService()) {
        self.authService = authService
    }

    // MARK: - Actions

    func signIn() async {
        guard validateSignInInput() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signIn(email: email, password: password)
            authState = .signedIn(user)
            clearForm()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signUp() async {
        guard validateSignUpInput() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signUp(email: email, password: password)
            authState = .signedIn(user)
            clearForm()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

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

    // MARK: - Validation

    private func validateSignInInput() -> Bool {
        if email.isEmpty {
            errorMessage = "Email is required"
            return false
        }
        if password.isEmpty {
            errorMessage = "Password is required"
            return false
        }
        return true
    }

    private func validateSignUpInput() -> Bool {
        if email.isEmpty {
            errorMessage = "Email is required"
            return false
        }
        if !email.contains("@") {
            errorMessage = "Please enter a valid email"
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        return true
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
    }
}
