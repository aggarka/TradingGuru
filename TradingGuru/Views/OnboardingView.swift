//
//  OnboardingView.swift
//  TradingGuru
//
//  Onboarding tutorial shown to first-time users after sign-in.
//

import SwiftUI

/// A swipeable onboarding tutorial for first-time users.
struct OnboardingView: View {
    
    // MARK: - Properties
    
    /// Callback when onboarding is completed or skipped
    let onComplete: () -> Void
    
    // MARK: - State
    
    @State private var currentPage = 0
    
    // MARK: - Constants
    
    private let pages = OnboardingPage.allPages
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicator and buttons
                VStack(spacing: 24) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                    
                    // Action button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Page View
    
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: page.iconName)
                .font(.system(size: 80))
                .foregroundStyle(page.iconColor)
                .padding(.bottom, 20)
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func completeOnboarding() {
        // Mark onboarding as completed
        OnboardingManager.shared.markOnboardingCompleted()
        onComplete()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    
    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            iconName: "chart.line.uptrend.xyaxis.circle.fill",
            iconColor: .blue,
            title: "Welcome to TradingGuru",
            description: "Your smart companion for weekly options analysis. Find potential trading opportunities based on your custom criteria."
        ),
        OnboardingPage(
            iconName: "list.bullet.rectangle.fill",
            iconColor: .green,
            title: "Build Your Watchlist",
            description: "Search and add stocks you want to track. Simply type a symbol or company name and tap to add it to your watchlist."
        ),
        OnboardingPage(
            iconName: "waveform.path.ecg.rectangle.fill",
            iconColor: .orange,
            title: "Analyze Opportunities",
            description: "Run analysis on your watchlist to find weekly options opportunities. Configure your criteria and let TradingGuru do the work."
        ),
        OnboardingPage(
            iconName: "bell.badge.fill",
            iconColor: .purple,
            title: "Stay Informed",
            description: "Enable scheduled analysis to automatically scan your watchlist and get notified when ORDER signals are found."
        )
    ]
}

// MARK: - Onboarding Manager

/// Manages onboarding state persistence.
final class OnboardingManager {
    
    static let shared = OnboardingManager()
    
    private let hasCompletedOnboardingKey = "com.tradingguru.hasCompletedOnboarding"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    /// Whether the user has completed onboarding.
    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: hasCompletedOnboardingKey)
    }
    
    /// Marks onboarding as completed.
    func markOnboardingCompleted() {
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }
    
    /// Resets onboarding state (for testing).
    func resetOnboarding() {
        defaults.removeObject(forKey: hasCompletedOnboardingKey)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Onboarding") {
    OnboardingView {
        print("Onboarding completed")
    }
}
#endif
