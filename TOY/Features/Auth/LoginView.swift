//
//  LoginView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import AuthenticationServices
import TOYShared

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and tagline
            VStack(spacing: 16) {
                TOYLabel.largeTitle("Thinking Of You")

                TOYLabel("Group video cards for the people who matter", style: .subheadline, color: .toyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Sign in with Apple button
            VStack(spacing: 16) {
                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = viewModel.generateNonce()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = viewModel.sha256(nonce)
                    },
                    onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(12)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.toyCaption())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            // Terms
            TOYLabel("By signing in, you agree to our Terms of Service and Privacy Policy", style: .caption, color: .toyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.toyBackground)
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
