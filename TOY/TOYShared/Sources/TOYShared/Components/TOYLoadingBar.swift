import SwiftUI

/// A thin pulsing loading bar (like TikTok's video loading indicator).
/// Shows at the bottom of video frames during loading — subtle, non-anxious.
public struct TOYLoadingBar: View {
    @State private var animating = false

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * 0.4)
                .offset(x: animating ? geometry.size.width * 0.8 : -geometry.size.width * 0.3)
        }
        .frame(height: 3)
        .background(Color.white.opacity(0.15))
        .clipped()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                animating = true
            }
        }
    }
}
