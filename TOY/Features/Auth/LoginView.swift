//
//  LoginView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        TOYLabel.largeTitle("Welcome Back")
                        TOYLabel("Sign in to continue", style: .subheadline, color: .toyTextSecondary)
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 16) {
                        TOYTextField("Email", text: $viewModel.email, icon: "envelope")
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)

                        TOYTextField("Password", text: $viewModel.password, isSecure: true, icon: "lock")
                            .textContentType(.password)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.toyCaption())
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Sign In Button
                    TOYButton("Sign In", style: .primary, size: .large, isLoading: viewModel.isLoading) {
                        Task { await viewModel.signIn() }
                    }

                    // Sign Up Link
                    HStack {
                        TOYLabel("Don't have an account?", style: .footnote, color: .toyTextSecondary)
                        Button("Sign Up") {
                            showSignUp = true
                        }
                        .font(.toyFootnote())
                        .foregroundColor(.toyPrimary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .background(Color.toyBackground)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(viewModel: viewModel)
            }
        }
    }
}
