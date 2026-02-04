//
//  SettingsView.swift
//  TOY
//
//  Profile screen with account options.
//

import Kingfisher
import PhotosUI
import SwiftUI
import TOYShared

struct SettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var isNameFieldFocused: Bool

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
                                    // Tappable avatar
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        avatarView(for: user)
                                    }

                                    // Tappable/editable name
                                    if isEditingName {
                                        nameEditView(for: user)
                                    } else {
                                        nameDisplayView(for: user)
                                    }

                                    Spacer()
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
            .navigationTitle("Profile")
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadAndUploadPhoto(from: newItem)
                }
            }
        }
    }

    // MARK: - Avatar View

    @ViewBuilder
    private func avatarView(for user: User) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar image - prefer pending image for optimistic UI
            Group {
                if let pendingImage = authViewModel.pendingAvatarImage {
                    // Show locally selected image immediately
                    Image(uiImage: pendingImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let avatarURL = user.avatarURL {
                    KFImage(avatarURL)
                        .placeholder {
                            avatarPlaceholder(for: user)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder(for: user)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.toyDivider, lineWidth: 1)
            }

            // Edit indicator - positioned outside the clip
            Image(systemName: "camera.fill")
                .font(.system(size: 10))
                .foregroundColor(.toyBackground)
                .padding(5)
                .background(Color.toyText)
                .clipShape(Circle())
                .offset(x: 2, y: 2)
        }
    }

    @ViewBuilder
    private func avatarPlaceholder(for user: User) -> some View {
        Circle()
            .fill(Color.toyDivider.opacity(0.3))
            .overlay {
                Text(String(user.displayNameOrEmail.prefix(1)).uppercased())
                    .font(.toyTitle3())
                    .foregroundColor(.toyText)
            }
    }

    // MARK: - Name Views

    @ViewBuilder
    private func nameDisplayView(for user: User) -> some View {
        Button {
            editedName = user.displayName ?? ""
            isEditingName = true
            isNameFieldFocused = true
        } label: {
            HStack(spacing: TOYSpacing.xs) {
                Text(user.displayNameOrEmail)
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.toyTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func nameEditView(for user: User) -> some View {
        HStack(spacing: TOYSpacing.md) {
            TextField("Name", text: $editedName)
                .font(.toyBodyMedium())
                .foregroundColor(.toyText)
                .textFieldStyle(.plain)
                .focused($isNameFieldFocused)
                .onSubmit {
                    saveName()
                }

            Button {
                saveName()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.toyText)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())

            Button {
                isEditingName = false
                isNameFieldFocused = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.toyTextSecondary)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Actions

    private func saveName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            isEditingName = false
            isNameFieldFocused = false
            return
        }

        authViewModel.updateDisplayName(trimmedName)
        isEditingName = false
        isNameFieldFocused = false
    }

    private func loadAndUploadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // Compress the image
                if let uiImage = UIImage(data: data),
                   let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                    authViewModel.updateAvatar(compressedData)
                }
            }
        } catch {
            #if DEBUG
            print("Failed to load photo: \(error)")
            #endif
        }
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
