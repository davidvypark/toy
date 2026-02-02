//
//  TOYClipApp.swift
//  TOYClip
//
//  App Clip entry point for participant recording via invite links.
//

import SwiftUI
import TOYShared

@main
struct TOYClipApp: App {
    @State private var shareToken: String?
    @State private var loadState: LoadState = .loading

    enum LoadState {
        case loading
        case ready
        case invalidLink
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch loadState {
                case .loading:
                    LoadingView()
                case .ready:
                    if let token = shareToken {
                        ParticipantRecordingFlow(shareToken: token)
                    }
                case .invalidLink:
                    InvalidLinkView()
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: handleActivity)
        }
    }

    private func handleActivity(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else {
            loadState = .invalidLink
            return
        }

        #if DEBUG
        print("[AppClip] Received URL: \(url)")
        #endif

        let destination = DeepLinkService.parse(url)
        switch destination {
        case .card(let token):
            shareToken = token
            loadState = .ready
        case .unknown:
            loadState = .invalidLink
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
    }
}
