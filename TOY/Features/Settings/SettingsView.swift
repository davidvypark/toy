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
            List {
                // Account Section
                Section {
                    if let user = authViewModel.authState.user {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundColor(.toyPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayNameOrEmail)
                                    .font(.headline)
                                if let email = user.email, user.displayName != nil {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.toyTextSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Account")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Configuration.appVersion)
                            .foregroundColor(.toyTextSecondary)
                    }
                } header: {
                    Text("About")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
