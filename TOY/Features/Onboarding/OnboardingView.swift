import AuthenticationServices
import SwiftUI
import TOYShared

struct OnboardingView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentPage = 0
    @State private var showSignIn = false

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            headline: "Create a Group Video Card",
            body: "Record a 7-second message and tell someone special you're thinking of them.",
            imageName: "onboarding0"
        ),
        OnboardingSlide(
            headline: "Invite friends & family",
            body: "Share the card so everyone can add their own 7-second clip.",
            imageName: "onboarding1"
        ),
        OnboardingSlide(
            headline: "Send the Card",
            body: "For birthdays, weddings, special moments, or just because... make their day",
            imageName: "onboarding2"
        ),
    ]

    private var buttonTitle: String {
        currentPage == slides.count - 1 ? "Get Started" : "Next"
    }

    var body: some View {
        ZStack {
            TOYBackground()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        showSignIn = true
                    } label: {
                        Text("Skip")
                            .font(.toyBody())
                            .foregroundColor(.toyTextSecondary)
                    }
                }
                .padding(.horizontal, TOYSpacing.lg)
                .padding(.top, TOYSpacing.md)
                .frame(height: 44)

                // Sliding content
                TabView(selection: $currentPage) {
                    ForEach(0 ..< slides.count, id: \.self) { index in
                        slideContent(slide: slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                .onAppear {
                    UIScrollView.appearance().bounces = false
                }
                .onDisappear {
                    UIScrollView.appearance().bounces = true
                }

                // Bottom controls
                VStack(spacing: TOYSpacing.lg) {
                    pageDots

                    TOYButton.primary(buttonTitle) {
                        if currentPage < slides.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            showSignIn = true
                        }
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                }
                .padding(.bottom, TOYSpacing.xxl)
            }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            signInView
        }
    }

    // MARK: - Slide Content

    private func slideContent(slide: OnboardingSlide) -> some View {
        VStack(spacing: 0) {
            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay {
                    Image(slide.imageName)
                        .resizable()
                        .scaledToFit()
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 48)

            Spacer()

            VStack(spacing: TOYSpacing.sm) {
                Text(slide.headline)
                    .font(.toyTitle())
                    .foregroundColor(.toyText)
                    .multilineTextAlignment(.center)

                Text(slide.body)
                    .font(.toyBody())
                    .foregroundColor(.toyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, TOYSpacing.lg)
            .padding(.bottom, TOYSpacing.lg)
        }
    }

    // MARK: - Sign In View (separate full-screen cover)

    private var signInView: some View {
        ZStack {
            TOYBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: TOYSpacing.sm) {
                    Text("toy")
                        .font(.custom("DMSerifDisplay-Regular", size: 192))
                        .foregroundColor(.toyText)

                    Text("Thinking Of You")
                        .font(.toyLargeTitle())
                        .foregroundColor(.toyText)

                    Text("Group video cards for the people who matter")
                        .font(.toySubheadline())
                        .foregroundColor(.toyTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: TOYSpacing.md) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            let nonce = authViewModel.generateNonce()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authViewModel.sha256(nonce)
                        },
                        onCompletion: { result in
                            Task {
                                await authViewModel.handleAppleSignIn(result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, TOYSpacing.lg)

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.toyCaption())
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    if authViewModel.isLoading {
                        ProgressView()
                    }

                    Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, TOYSpacing.xxl)
            }
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: TOYSpacing.sm) {
            ForEach(0 ..< slides.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.toyText : Color.toyDivider)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Slide Model

private struct OnboardingSlide {
    let headline: String
    let body: String
    let imageName: String
}

// MARK: - Preview

#Preview {
    OnboardingView(authViewModel: AuthViewModel())
}
