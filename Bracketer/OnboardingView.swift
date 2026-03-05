import SwiftUI

/// Multi-page onboarding flow shown on first launch
/// Explains bracketing, ProRAW, and key controls to new users
@available(iOS 26.0, *)
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.aperture",
            title: "Welcome to Bracketer",
            subtitle: "Professional bracketed photography",
            description: "Capture multiple exposures automatically to create stunning HDR images and ensure you never miss the perfect shot."
        ),
        OnboardingPage(
            icon: "rectangle.stack.fill",
            title: "Exposure Bracketing",
            subtitle: "What is EV?",
            description: "EV (Exposure Value) controls brightness. Bracketing captures the same scene at different exposures — darker, normal, and brighter — so you can merge them later or pick the best one."
        ),
        OnboardingPage(
            icon: "r.square.on.square",
            title: "ProRAW Capture",
            subtitle: "Maximum quality",
            description: "ProRAW preserves all sensor data from the 48MP camera. This gives you full control in post-processing — adjust white balance, recover highlights, and pull shadow detail without quality loss."
        ),
        OnboardingPage(
            icon: "dial.medium.fill",
            title: "Pro Controls",
            subtitle: "Full manual control",
            description: "Tap PRO to access ISO, shutter speed, white balance, and manual focus. Use focus peaking to confirm sharpness. All settings are saved between sessions."
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Ready to Shoot",
            subtitle: "Let's get started",
            description: "Swipe between shooting modes at the top. Long-press any control label for a quick explanation. Your settings are always saved."
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.yellow : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(Color.yellow)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                // Skip button (not on last page)
                if currentPage < pages.count - 1 {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                } else {
                    Spacer().frame(height: 52)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .yellow.opacity(0.3), radius: 20)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(page.subtitle)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.yellow.opacity(0.9))
            }

            Text(page.description)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
}
