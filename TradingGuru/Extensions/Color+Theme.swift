//
//  Color+Theme.swift
//  TradingGuru
//
//  Theme color extensions for consistent styling across the app.
//

import SwiftUI

// MARK: - TradingGuru Theme Colors

extension Color {
    
    // MARK: - Brand Colors
    
    /// Primary brand color - used for main accents, buttons, and important UI elements.
    /// A professional deep blue that conveys trust and reliability.
    static let tradingPrimary = Color("OrderBlue")
    
    /// Alias for tradingPrimary for clearer intent in button contexts.
    static let tradingAccent = Color.accentColor
    
    // MARK: - Semantic Colors (Trading)
    
    /// Bullish/positive color - used for CALL options, positive returns, gains.
    /// A vibrant green that stands out in both light and dark modes.
    static let bullish = Color("BullishGreen")
    
    /// Bearish/negative color - used for PUT options, negative returns, losses.
    /// A clear red that indicates caution or negative sentiment.
    static let bearish = Color("BearishRed")
    
    /// Order signal highlight color - used to emphasize ORDER signals in results.
    static let orderHighlight = Color("OrderBlue")
    
    // MARK: - Background Colors
    
    /// Card/elevated surface background - used for cards, lists, and elevated surfaces.
    static let tradingCardBackground = Color("CardBackground")
    
    /// Page/screen background - slightly darker than card background for depth.
    static let tradingPageBackground = Color(.systemGroupedBackground)
    
    /// Highlighted row background - subtle tint for ORDER signal rows.
    static let highlightedRow = Color("OrderBlue").opacity(0.1)
    
    /// Alternating row background (even rows) - slightly tinted for visual separation.
    static let alternatingRowEven = Color(.systemBackground)
    
    /// Alternating row background (odd rows) - subtle gray tint for zebra striping.
    static let alternatingRowOdd = Color(.systemGray6).opacity(0.5)
    
    // MARK: - Text Colors
    
    /// Primary text color - used for main content, headings.
    static let tradingTextPrimary = Color("PrimaryText")
    
    /// Secondary text color - used for captions, hints, less important text.
    static let tradingTextSecondary = Color("SecondaryText")
    
    // MARK: - Status Colors
    
    /// Warning color - used for earnings risk indicators, caution states.
    static let warning = Color.orange
    
    /// Error color - used for failed operations, critical errors.
    static let error = Color.red
    
    /// Success color - used for completed operations, confirmations.
    static let success = Color("BullishGreen")
}

// MARK: - Theme-Aware View Modifiers

extension View {
    
    /// Applies the standard card styling with rounded corners and shadow.
    func tradingCard() -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    /// Applies the standard button styling for primary actions.
    func tradingPrimaryButton() -> some View {
        self
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.tradingAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Applies the standard button styling for secondary actions.
    func tradingSecondaryButton() -> some View {
        self
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.tradingAccent.opacity(0.1))
            .foregroundStyle(Color.tradingAccent)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    /// Applies styling for bullish (positive) values.
    func bullishStyle() -> some View {
        self.foregroundStyle(Color.bullish)
    }
    
    /// Applies styling for bearish (negative) values.
    func bearishStyle() -> some View {
        self.foregroundStyle(Color.bearish)
    }
    
    /// Applies conditional styling based on a positive/negative value.
    func valueStyle(isPositive: Bool) -> some View {
        self.foregroundStyle(isPositive ? Color.bullish : Color.bearish)
    }
}

// MARK: - Signal Badge Style

/// A styled badge view for displaying trading signals (ORDER/HOLD).
struct SignalBadge: View {
    let signal: String
    
    private var isOrder: Bool {
        signal.uppercased() == "ORDER"
    }
    
    var body: some View {
        Text(signal)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOrder ? Color.orderHighlight : Color.tradingTextSecondary.opacity(0.2))
            .foregroundStyle(isOrder ? .white : Color.tradingTextSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Option Type Badge Style

/// A styled badge view for displaying option types (CALL/PUT).
struct OptionTypeBadge: View {
    let type: String
    
    private var isCall: Bool {
        type.uppercased() == "CALL"
    }
    
    var body: some View {
        Text(type)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isCall ? Color.bullish.opacity(0.15) : Color.bearish.opacity(0.15))
            .foregroundStyle(isCall ? Color.bullish : Color.bearish)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview("Theme Colors") {
    VStack(spacing: 20) {
        // Brand colors
        HStack(spacing: 12) {
            ColorSwatch(color: .tradingPrimary, name: "Primary")
            ColorSwatch(color: .tradingAccent, name: "Accent")
        }
        
        // Trading colors
        HStack(spacing: 12) {
            ColorSwatch(color: .bullish, name: "Bullish")
            ColorSwatch(color: .bearish, name: "Bearish")
        }
        
        // Signal badges
        HStack(spacing: 12) {
            SignalBadge(signal: "ORDER")
            SignalBadge(signal: "HOLD")
        }
        
        // Option type badges
        HStack(spacing: 12) {
            OptionTypeBadge(type: "CALL")
            OptionTypeBadge(type: "PUT")
        }
        
        // Buttons
        VStack(spacing: 12) {
            Button("Primary Action") {}
                .tradingPrimaryButton()
            
            Button("Secondary Action") {}
                .tradingSecondaryButton()
        }
        .padding(.horizontal)
    }
    .padding()
    .background(Color.tradingPageBackground)
}

// Helper for preview
private struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
            Text(name)
                .font(.caption2)
        }
    }
}
