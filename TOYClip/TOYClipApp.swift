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
            .onOpenURL { url in
                // Fallback for simulator testing with _XCAppClipURL
                #if DEBUG
                print("[AppClip] onOpenURL received: \(url)")
                #endif
                processURL(url)
            }
            .task {
                // Check for _XCAppClipURL environment variable in simulator
                #if DEBUG
                if let envURL = ProcessInfo.processInfo.environment["_XCAppClipURL"],
                   let url = URL(string: envURL) {
                    print("[AppClip] Using _XCAppClipURL: \(envURL)")
                    // Small delay to let view settle
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        processURL(url)
                    }
                }
                #endif
            }
        }
    }

    private func handleActivity(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else {
            loadState = .invalidLink
            return
        }

        #if DEBUG
        print("[AppClip] Received activity URL: \(url)")
        #endif

        processURL(url)
    }

    private func processURL(_ url: URL) {
        #if DEBUG
        print("[AppClip] Processing URL: \(url)")
        print("[AppClip] Path components: \(url.pathComponents)")
        #endif

        let destination = DeepLinkService.parse(url)
        switch destination {
        case .card(let token):
            shareToken = token
            loadState = .ready
            #if DEBUG
            print("[AppClip] Parsed token: \(token)")
            #endif
        case .unknown:
            loadState = .invalidLink
            #if DEBUG
            print("[AppClip] URL parsing returned .unknown")
            #endif
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
