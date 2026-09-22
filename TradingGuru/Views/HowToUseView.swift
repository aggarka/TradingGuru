//
//  HowToUseView.swift
//  TradingGuru
//
//  Comprehensive guide on how to use the TradingGuru app.
//

import SwiftUI

/// A comprehensive guide view with expandable sections explaining app features.
struct HowToUseView: View {
    
    // MARK: - State
    
    @State private var expandedSections: Set<GuideSection> = []
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                headerSection
                
                // Guide sections
                ForEach(GuideSection.allCases, id: \.self) { section in
                    guideSectionView(section)
                }
                
                // Footer
                footerSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("How to Use")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Welcome to TradingGuru")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your weekly options analysis companion. Learn how to make the most of the app's features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Guide Section View
    
    private func guideSectionView(_ section: GuideSection) -> some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: section.iconName)
                        .font(.title3)
                        .foregroundStyle(section.iconColor)
                        .frame(width: 32)
                    
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: expandedSections.contains(section) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if expandedSections.contains(section) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(section.steps, id: \.self) { step in
                        stepView(step)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    
    // MARK: - Step View
    
    private func stepView(_ step: GuideStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(step.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            Text("Need more help?")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Contact us at support@tradingguru.app")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }
}

// MARK: - Guide Section Enum

enum GuideSection: CaseIterable {
    case strategyGuide
    case watchlist
    case analysis
    case results
    case scheduledAnalysis
    case settings
    
    var title: String {
        switch self {
        case .strategyGuide: return "Weekly Option Strategy"
        case .watchlist: return "Managing Your Watchlist"
        case .analysis: return "Running Analysis"
        case .results: return "Understanding Results"
        case .scheduledAnalysis: return "Scheduled Analysis"
        case .settings: return "Settings & Notifications"
        }
    }
    
    var iconName: String {
        switch self {
        case .strategyGuide: return "lightbulb.fill"
        case .watchlist: return "list.bullet.rectangle"
        case .analysis: return "waveform.path.ecg"
        case .results: return "chart.bar.doc.horizontal"
        case .scheduledAnalysis: return "clock.arrow.circlepath"
        case .settings: return "gear"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .strategyGuide: return .yellow
        case .watchlist: return .blue
        case .analysis: return .orange
        case .results: return .green
        case .scheduledAnalysis: return .purple
        case .settings: return .gray
        }
    }
    
    var steps: [GuideStep] {
        switch self {
        case .strategyGuide:
            return [
                GuideStep(number: 1, title: "What is the Strategy?", description: "The Weekly Option Strategy helps you find opportunities to sell covered calls and cash-secured puts based on historical stock price patterns."),
                GuideStep(number: 2, title: "Covered Call (CALL)", description: "When a stock shows consistent positive returns, sell call options against shares you own. You collect premium income, but may need to sell shares if the stock rises above the strike price."),
                GuideStep(number: 3, title: "Cash-Secured Put (PUT)", description: "When a stock shows negative returns and trades below its range, sell put options with cash set aside. You collect premium and may buy the stock at a lower price if assigned."),
                GuideStep(number: 4, title: "ORDER vs WATCH Signals", description: "ORDER signals meet all criteria and may be actionable. WATCH signals meet some criteria but require monitoring before trading."),
                GuideStep(number: 5, title: "Risk Disclaimer", description: "Options trading involves significant risk. Past performance does not guarantee future results. Always do your own research before trading.")
            ]
        case .watchlist:
            return [
                GuideStep(number: 1, title: "Search for Stocks", description: "Type a stock symbol or company name in the search field. Results will appear as you type."),
                GuideStep(number: 2, title: "Add to Watchlist", description: "Tap on a stock from the search results to add it to your watchlist instantly."),
                GuideStep(number: 3, title: "Remove Stocks", description: "Swipe left on any stock in your watchlist and tap Delete to remove it."),
                GuideStep(number: 4, title: "Watchlist Limit", description: "You can add up to 50 stocks to your watchlist.")
            ]
        case .analysis:
            return [
                GuideStep(number: 1, title: "Go to Analysis Tab", description: "Tap the Analysis tab to access the options analysis screen."),
                GuideStep(number: 2, title: "Configure Settings", description: "Adjust IV range, return thresholds, and other parameters to customize your analysis."),
                GuideStep(number: 3, title: "Run Analysis", description: "Tap 'Run Analysis' to analyze all stocks in your watchlist for weekly options opportunities."),
                GuideStep(number: 4, title: "Wait for Results", description: "Analysis typically takes a few seconds per stock. Results appear automatically when complete.")
            ]
        case .results:
            return [
                GuideStep(number: 1, title: "ORDER Signals", description: "Green ORDER signals indicate opportunities that meet all your criteria and may be worth trading."),
                GuideStep(number: 2, title: "WATCH Signals", description: "Yellow WATCH signals show stocks that meet some criteria but may need monitoring."),
                GuideStep(number: 3, title: "Key Metrics", description: "Review IV (Implied Volatility), Return %, Strike Price, and Expiration for each opportunity."),
                GuideStep(number: 4, title: "Filter Results", description: "Use the filter options to show only ORDER signals or specific option types (calls/puts).")
            ]
        case .scheduledAnalysis:
            return [
                GuideStep(number: 1, title: "Enable Scheduled Analysis", description: "Go to Settings and toggle on 'Scheduled Analysis' to run automatic analysis."),
                GuideStep(number: 2, title: "Configure Schedule", description: "Tap 'Configure Schedule Times' to set when analysis should run automatically."),
                GuideStep(number: 3, title: "Allow Notifications", description: "Enable notifications to receive alerts when ORDER signals are found."),
                GuideStep(number: 4, title: "View Results", description: "Tap on a notification to jump directly to your analysis results.")
            ]
        case .settings:
            return [
                GuideStep(number: 1, title: "Email Notifications", description: "Configure your email to receive analysis results after each scheduled run."),
                GuideStep(number: 2, title: "Notification Permissions", description: "Make sure notifications are enabled in iOS Settings for timely alerts."),
                GuideStep(number: 3, title: "Account Management", description: "Sign out or delete your account from the Settings screen."),
                GuideStep(number: 4, title: "Session Info", description: "View your account details and session expiration date in Settings.")
            ]
        }
    }
}

// MARK: - Guide Step Model

struct GuideStep: Hashable {
    let number: Int
    let title: String
    let description: String
}

// MARK: - Preview

#if DEBUG
#Preview("How to Use") {
    NavigationStack {
        HowToUseView()
    }
}
#endif
