//
//  InvalidLinkView.swift
//  TOYClip
//
//  Shown when the App Clip is invoked with an invalid or unrecognized URL.
//

import SwiftUI

struct InvalidLinkView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Invalid Invite Link")
                .font(.title)
                .fontWeight(.bold)

            Text("This link doesn't appear to be a valid TOY card invite. Please check the link and try again.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

#Preview {
    InvalidLinkView()
}
