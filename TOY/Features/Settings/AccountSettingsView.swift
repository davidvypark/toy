import SwiftUI
import TOYShared

struct AccountSettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    let onSignedOut: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showFirstDeleteConfirmation = false
    @State private var showSecondDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            TOYBackground()

            VStack(alignment: .leading, spacing: TOYSpacing.xxl) {
                // Sign Out
                Button {
                    Task {
                        await authViewModel.signOut()
                        onSignedOut()
                    }
                } label: {
                    Text("Sign Out")
                        .font(.toyBody())
                        .foregroundColor(.toyDestructive)
                        .underline()
                }

                // Delete Account
                Button {
                    showFirstDeleteConfirmation = true
                } label: {
                    HStack(spacing: TOYSpacing.sm) {
                        if isDeleting {
                            ProgressView()
                                .tint(.toyDestructive)
                                .scaleEffect(0.8)
                        }
                        Text("Delete Account")
                            .font(.toyBody())
                            .foregroundColor(.toyDestructive)
                            .underline()
                    }
                }
                .disabled(isDeleting)

                Spacer()
            }
            .padding(.horizontal, TOYSpacing.lg)
            .padding(.top, TOYSpacing.xl)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showFirstDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                showSecondDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your account?")
        }
        .alert("This Cannot Be Undone", isPresented: $showSecondDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your data including videos and cannot be recovered.")
        }
        .alert("Error", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            if let deleteError {
                Text(deleteError)
            }
        }
    }

    private func performDeletion() async {
        isDeleting = true
        await authViewModel.deleteAccount()

        if authViewModel.errorMessage != nil {
            deleteError = authViewModel.errorMessage
            authViewModel.errorMessage = nil
            isDeleting = false
        } else {
            onSignedOut()
        }
    }
}
