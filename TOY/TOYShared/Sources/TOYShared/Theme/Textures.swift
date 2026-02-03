import SwiftUI

/// Texture overlay types for the "Intimate Raw" design system
public enum TOYTextureType {
    /// Subtle paper grain for light mode - tactile, like quality stationery
    case paperGrain

    /// Film grain for dark mode - cinematic, adds life to pure black
    case filmGrain
}

// MARK: - Noise Generator

/// Generates procedural noise texture
struct NoiseGenerator {
    static func generateNoise(width: Int, height: Int, seed: Int = 0) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        var randomState = UInt64(seed == 0 ? Int.random(in: 0..<Int.max) : seed)

        for y in 0..<height {
            for x in 0..<width {
                // Simple xorshift random for performance
                randomState ^= randomState << 13
                randomState ^= randomState >> 7
                randomState ^= randomState << 17

                let noise = UInt8(randomState & 0xFF)
                let index = (y * width + x) * bytesPerPixel

                pixels[index] = noise     // R
                pixels[index + 1] = noise // G
                pixels[index + 2] = noise // B
                pixels[index + 3] = 255   // A
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }
}

// MARK: - Texture Overlay View

/// A subtle texture overlay that adds tactile quality to backgrounds
public struct TOYTextureOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    private let opacity: Double

    public init(opacity: Double = 0.03) {
        self.opacity = opacity
    }

    public var body: some View {
        GeometryReader { geometry in
            if let noiseImage = NoiseGenerator.generateNoise(
                width: Int(geometry.size.width / 2),
                height: Int(geometry.size.height / 2)
            ) {
                Image(decorative: noiseImage, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .blendMode(colorScheme == .dark ? .softLight : .multiply)
                    .opacity(opacity)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Background with Texture

/// A background view with integrated texture overlay
public struct TOYBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private let showTexture: Bool

    public init(showTexture: Bool = true) {
        self.showTexture = showTexture
    }

    public var body: some View {
        ZStack {
            Color.toyBackground
                .ignoresSafeArea()

            if showTexture {
                TOYTextureOverlay(
                    opacity: colorScheme == .dark ? 0.04 : 0.03
                )
            }
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Apply the themed background with optional texture
    func toyBackground(showTexture: Bool = true) -> some View {
        self.background(TOYBackground(showTexture: showTexture))
    }

    /// Apply texture overlay only
    func toyTextureOverlay(opacity: Double = 0.03) -> some View {
        self.overlay(TOYTextureOverlay(opacity: opacity))
    }
}

// MARK: - Preview

#Preview("Texture Overlays") {
    VStack(spacing: 0) {
        // Light mode simulation
        ZStack {
            Color.warmCream
            TOYTextureOverlay(opacity: 0.03)
            Text("Paper Grain")
                .font(.toyTitle())
                .foregroundStyle(Color.warmBlack)
        }
        .frame(height: 200)

        // Dark mode simulation
        ZStack {
            Color.black
            TOYTextureOverlay(opacity: 0.04)
                .environment(\.colorScheme, .dark)
            Text("Film Grain")
                .font(.toyTitle())
                .foregroundStyle(Color.warmCream)
        }
        .frame(height: 200)
    }
}
