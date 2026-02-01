//
//  SignUpView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    TOYLabel.largeTitle("Create Account")
                    TOYLabel("Join TOY to create heartfelt video messages", style: .subheadline, color: .toyTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    TOYTextField("Email", text: $viewModel.email, icon: "envelope")
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    TOYTextField("Password", text: $viewModel.password, isSecure: true, icon: "lock")
                        .textContentType(.newPassword)

                    TOYTextField("Confirm Password", text: $viewModel.confirmPassword, isSecure: true, icon: "lock")
                        .textContentType(.newPassword)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.toyCaption())
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Sign Up Button
                TOYButton("Create Account", style: .primary, size: .large, isLoading: viewModel.isLoading) {
                    Task { await viewModel.signUp() }
                }

                // Terms
                TOYLabel("By signing up, you agree to our Terms of Service and Privacy Policy", style: .caption, color: .toyTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .background(Color.toyBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}
