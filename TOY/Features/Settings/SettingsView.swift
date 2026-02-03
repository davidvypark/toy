//
//  SettingsView.swift
//  TOY
//
//  Settings screen with account options.
//

import SwiftUI
import TOYShared

struct SettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: TOYSpacing.xxl) {
                        // Account Section
                        VStack(alignment: .leading, spacing: TOYSpacing.md) {
                            Text("ACCOUNT")
                                .font(.toyCaption())
                                .foregroundColor(.toyTextSecondary)
                                .toyLetterSpacing(1.5)

                            if let user = authViewModel.authState.user {
                                HStack(spacing: TOYSpacing.md) {
                                    Circle()
                                        .stroke(Color.toyDivider, lineWidth: 1)
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Text(String(user.displayNameOrEmail.prefix(1)).uppercased())
                                                .font(.toyTitle3())
                                                .foregroundColor(.toyText)
                                        }

                                    VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                                        Text(user.displayNameOrEmail)
                                            .font(.toyBodyMedium())
                                            .foregroundColor(.toyText)
                                        if let email = user.email, user.displayName != nil {
                                            Text(email)
                                                .font(.toyCaption())
                                                .foregroundColor(.toyTextSecondary)
                                        }
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.toyDivider)
                            .frame(height: 1)

                        // App Info Section
                        VStack(alignment: .leading, spacing: TOYSpacing.md) {
                            Text("ABOUT")
                                .font(.toyCaption())
                                .foregroundColor(.toyTextSecondary)
                                .toyLetterSpacing(1.5)

                            HStack {
                                Text("Version")
                                    .font(.toyBody())
                                    .foregroundColor(.toyText)
                                Spacer()
                                Text(Configuration.appVersion)
                                    .font(.toyBody())
                                    .foregroundColor(.toyTextSecondary)
                            }
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.toyDivider)
                            .frame(height: 1)

                        // Sign Out
                        Button {
                            Task {
                                await authViewModel.signOut()
                                dismiss()
                            }
                        } label: {
                            Text("Sign Out")
                                .font(.toyBody())
                                .foregroundColor(.toyDestructive)
                                .underline()
                        }

                        Spacer()
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.top, TOYSpacing.xl)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)
                }
            }
        }
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
