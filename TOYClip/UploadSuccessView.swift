//
//  UploadSuccessView.swift
//  TOYClip
//
//  Success screen shown after participant uploads their clip.
//  Basic version - SKOverlay will be added in Plan 04.
//

import SwiftUI

struct UploadSuccessView: View {
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
            .padding(.bottom, 100) // Space for SKOverlay (added in Plan 04)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    UploadSuccessView()
}
