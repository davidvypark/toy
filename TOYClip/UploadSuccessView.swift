//
//  UploadSuccessView.swift
//  TOYClip
//
//  Success screen shown after participant uploads their clip.
//  Includes SKOverlay to prompt full app installation.
//

import SwiftUI
import StoreKit

struct UploadSuccessView: View {
    @State private var showAppStoreOverlay = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Clip Submitted!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your video message has been added to the card. The recipient will love it!")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Text("Want to create your own cards?")
                    .font(.headline)

                Text("Get the full TOY app to create cards, invite friends, and send heartfelt video messages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 100) // Space for SKOverlay

            Spacer()
        }
        .padding()
        .onAppear {
            // Delay overlay slightly for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showAppStoreOverlay = true
            }
        }
        #if !targetEnvironment(simulator)
        .appStoreOverlay(isPresented: $showAppStoreOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
        #else
        .overlay(alignment: .bottom) {
            // Simulator placeholder for SKOverlay
            if showAppStoreOverlay {
                VStack {
                    Text("App Store Overlay")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("(Visible on device only)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        #endif
    }
}

#Preview {
    UploadSuccessView()
}
