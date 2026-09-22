//
//  ResultsView.swift
//  TradingGuru
//
//  Results display screen showing analysis results in summary cards or table format.
//

import SwiftUI

/// View mode for results display
enum ResultsViewMode: String, CaseIterable {
    case summary = "Summary"
    case table = "Table"
}

/// View displaying analysis results in a table format.
///
/// Displays the results of strategy analysis in a scrollable table with columns for
/// Ticker, Type, Return %, Current Price, Target Price, Signal, and Next Earnings Date.
/// Shows "Last updated" timestamp when results exist, and an empty state when no results.
///
/// - Validates: Requirement 6.1 (Display results in table with specified columns)
/// - Validates: Requirement 6.7 (Display empty state message when no results)
/// - Validates: Requirement 6.8 (Display "N/A" for missing earnings dates)
/// - Validates: Requirement 8.6 (Display "Last updated: [time] PST" above results)
struct ResultsView: View {
    // MARK: - ViewModel
    
    /// The ViewModel managing results state and operations
    @Bindable var viewModel: ResultsViewModel
    
    // MARK: - State
    
    /// Current view mode (Summary or Table)
    @State private var viewMode: ResultsViewMode = .summary
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        // Loading state
                        loadingStateView
                    } else if let error = viewModel.loadError {
                        // Error state
                        errorStateView(error: error)
                    } else if viewModel.hasResults {
                        // View mode picker
                        viewModePicker
                        
                        // Last updated header
                        lastUpdatedHeader
                        
                        // Content based on view mode
                        if viewMode == .summary {
                            summaryView
                        } else {
                            resultsTableView
                        }
                    } else {
                        // Empty state
                        emptyStateView
                    }
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - View Mode Picker
    
    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(ResultsViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Summary View (Card-based)
    
    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats summary
                summaryStatsSection
                
                // Results list
                summaryResultsList
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Summary Stats Section
    
    private var summaryStatsSection: some View {
        HStack(spacing: 12) {
            // ORDER signals count
            StatCard(
                title: "ORDER",
                count: viewModel.filteredSortedResults.filter { $0.signal == "ORDER" }.count,
                color: .orderHighlight,
                icon: "checkmark.circle.fill"
            )
            
            // WATCH signals count
            StatCard(
                title: "WATCH",
                count: viewModel.filteredSortedResults.filter { $0.signal != "ORDER" }.count,
                color: .secondary,
                icon: "eye.fill"
            )
            
            // Calls count
            StatCard(
                title: "CALL",
                count: viewModel.filteredSortedResults.filter { $0.type == "CALL" }.count,
                color: .bullish,
                icon: "arrow.up.circle.fill"
            )
            
            // Puts count
            StatCard(
                title: "PUT",
                count: viewModel.filteredSortedResults.filter { $0.type == "PUT" }.count,
                color: .bearish,
                icon: "arrow.down.circle.fill"
            )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Summary Results List
    
    private var summaryResultsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredSortedResults) { result in
                ResultSummaryCard(result: result)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Last Updated Header
    
    /// Header displaying the last updated timestamp.
    /// - Validates: Requirement 8.6 (Display "Last updated: [time] PST")
    private var lastUpdatedHeader: some View {
        VStack(spacing: 0) {
            if let lastUpdated = viewModel.lastUpdatedDisplay {
                HStack {
                    Text(lastUpdated)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .accessibilityLabel(lastUpdated)
            }
            
            Divider()
        }
    }
    
    // MARK: - Results Table View
    
    /// Table view displaying analysis results.
    /// The entire table scrolls together horizontally, and the header stays pinned when scrolling vertically.
    /// - Validates: Requirement 6.1 (Display results in table with columns)
    /// - Validates: Requirement 6.8 (Display "N/A" for missing dates)
    /// - Validates: Requirement 4.5 (ONLY_ORDERS filter applied)
    private var resultsTableView: some View {
        // Outer horizontal scroll - this makes header + all rows scroll together horizontally
        ScrollView(.horizontal, showsIndicators: true) {
            // Inner vertical scroll with pinned header
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        // Data rows (using filtered and sorted results) with alternating colors
                        ForEach(Array(viewModel.filteredSortedResults.enumerated()), id: \.element.id) { index, result in
                            ResultRowView(result: result, rowIndex: index)
                            
                            Divider()
                        }
                    } header: {
                        // Column headers - pinned at top during vertical scroll
                        tableHeaderRow
                        
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
            }
        }
    }
    
    // MARK: - Table Header Row
    
    /// Header row displaying column titles with sort functionality.
    /// Column order per Requirement 6.7: Signal, Ticker, Type, Expiration Date, Strike Price, 
    /// Bid Premium, Ask Premium, Mid Premium, Return Percentage, Current Price, Target Price, Next Earnings Date
    /// - Validates: Requirement 6.5 (Sort by any column)
    /// - Validates: Requirement 6.6 (Toggle sort direction on tap)
    /// - Validates: Requirements 6.1-6.5, 6.7, 6.8, 6.9 (Options columns with sorting)
    private var tableHeaderRow: some View {
        HStack(spacing: 8) {
            // Signal column (FIRST)
            sortableHeaderButton(for: .signal, title: "Signal", width: 55, alignment: .center)
            
            // Ticker column
            sortableHeaderButton(for: .ticker, title: "Ticker", width: 60, alignment: .leading)
            
            // Type column
            sortableHeaderButton(for: .type, title: "Type", width: 45, alignment: .center)
            
            // NEW: Expiration Date column
            // - Validates: Requirement 6.1 (Expiration Date column)
            // - Validates: Requirement 6.8 (Sort by Expiration Date)
            sortableHeaderButton(for: .expirationDate, title: "Exp Date", width: 80, alignment: .center)
            
            // NEW: Strike Price column
            // - Validates: Requirement 6.2 (Strike Price column)
            // - Validates: Requirement 6.8 (Sort by Strike Price)
            sortableHeaderButton(for: .strikePrice, title: "Strike", width: 60, alignment: .trailing)
            
            // NEW: Bid Premium column
            // - Validates: Requirement 6.3 (Bid Premium column)
            sortableHeaderButton(for: .bidPremium, title: "Bid", width: 55, alignment: .trailing)
            
            // NEW: Ask Premium column
            // - Validates: Requirement 6.4 (Ask Premium column)
            sortableHeaderButton(for: .askPremium, title: "Ask", width: 55, alignment: .trailing)
            
            // NEW: Mid Premium column
            // - Validates: Requirement 6.5 (Mid Premium column)
            // - Validates: Requirement 6.9 (Sort by Mid Premium)
            sortableHeaderButton(for: .midPremium, title: "Mid", width: 55, alignment: .trailing)
            
            // Return % column
            sortableHeaderButton(for: .returnPercentage, title: "Return %", width: 70, alignment: .trailing)
            
            // Current Price column
            sortableHeaderButton(for: .currentPrice, title: "Current", width: 65, alignment: .trailing)
            
            // Target Price column
            sortableHeaderButton(for: .targetPrice, title: "Target", width: 65, alignment: .trailing)
            
            // Next Earnings column (uses minWidth)
            sortableHeaderButtonWithMinWidth(for: .nextEarningsDate, title: "Earnings", minWidth: 80, alignment: .trailing)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Results table header: Signal, Ticker, Type, Expiration Date, Strike Price, Bid Premium, Ask Premium, Mid Premium, Return Percentage, Current Price, Target Price, Next Earnings Date. Tap column to sort.")
    }
    
    /// Creates a sortable header button for a column with fixed width.
    /// - Parameters:
    ///   - column: The column this header represents
    ///   - title: Display title for the column
    ///   - width: Fixed width for the column
    ///   - alignment: Text alignment
    /// - Returns: A tappable button with optional sort indicator
    private func sortableHeaderButton(
        for column: ResultColumn,
        title: String,
        width: CGFloat,
        alignment: Alignment
    ) -> some View {
        Button {
            viewModel.sort(by: column)
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if viewModel.sortState.column == column {
                    Text(viewModel.sortState.direction.symbol)
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(viewModel.sortState.column == column ? "sorted \(viewModel.sortState.direction == .ascending ? "ascending" : "descending")" : "tap to sort")")
    }
    
    /// Creates a sortable header button for a column with minimum width.
    /// - Parameters:
    ///   - column: The column this header represents
    ///   - title: Display title for the column
    ///   - minWidth: Minimum width for the column
    ///   - alignment: Text alignment
    /// - Returns: A tappable button with optional sort indicator
    private func sortableHeaderButtonWithMinWidth(
        for column: ResultColumn,
        title: String,
        minWidth: CGFloat,
        alignment: Alignment
    ) -> some View {
        Button {
            viewModel.sort(by: column)
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if viewModel.sortState.column == column {
                    Text(viewModel.sortState.direction.symbol)
                        .foregroundStyle(.blue)
                }
            }
            .frame(minWidth: minWidth, alignment: alignment)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(viewModel.sortState.column == column ? "sorted \(viewModel.sortState.direction == .ascending ? "ascending" : "descending")" : "tap to sort")")
    }
    
    // MARK: - Loading State View
    
    /// Loading state displayed while results are being fetched.
    private var loadingStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading results...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading results")
    }
    
    // MARK: - Error State View
    
    /// Error state displayed when results fail to load.
    /// - Parameter error: The error message to display
    private func errorStateView(error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            
            Text("Unable to Load Results")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                Task {
                    await viewModel.loadResults()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading results. \(error). Double tap to try again.")
    }
    
    // MARK: - Empty State View
    
    /// Empty state displayed when no results are available.
    /// - Validates: Requirement 6.7 (Display message when no results available)
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chart.bar.xaxis")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)
            
            Text("No Results Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Run an analysis on your watchlist to see trading opportunities here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No results yet. Run an analysis on your watchlist to see trading opportunities here.")
    }
}

// MARK: - Result Row View

/// A row displaying a single analysis result with visual indicators.
///
/// Displays formatted values for each column (per Requirement 6.7 column order):
/// - Signal: ORDER (blue) or HOLD (secondary color) - FIRST COLUMN
/// - Ticker: Stock symbol
/// - Type: CALL (green) or PUT (red)
/// - Expiration Date: Formatted as YYYY-MM-DD or "N/A" (Requirement 6.1)
/// - Strike Price: Formatted as currency with 2 decimal places or "N/A" (Requirement 6.2)
/// - Bid Premium: Formatted as currency with 2 decimal places or "N/A" (Requirement 6.3)
/// - Ask Premium: Formatted as currency with 2 decimal places or "N/A" (Requirement 6.4)
/// - Mid Premium: Formatted as currency with 2 decimal places or "N/A" (Requirement 6.5)
/// - Return %: Formatted to 2 decimal places with % symbol, green for positive, red for negative
/// - Current Price: Formatted as currency with 2 decimal places
/// - Target Price: Formatted as currency with 2 decimal places
/// - Next Earnings: YYYY-MM-DD format (red if earnings risk) or "N/A"
///
/// Visual Indicators:
/// - ORDER signal rows have a blue tinted background (Requirement 6.3)
/// - CALL types display with green text, PUT types display with red text (Requirement 6.2)
/// - Positive returns display in green, negative returns display in red (Requirement 6.2)
/// - Next Earnings Date displays in red when hasEarningsRisk is true (Requirement 6.4)
/// - N/A values display in secondary color to indicate missing data (Requirement 6.10)
///
/// - Validates: Requirement 6.1 (Expiration Date column)
/// - Validates: Requirement 6.2 (Strike Price column)
/// - Validates: Requirement 6.3 (Bid Premium column)
/// - Validates: Requirement 6.4 (Ask Premium column)
/// - Validates: Requirement 6.5 (Mid Premium column)
/// - Validates: Requirement 6.10 (N/A for missing options data)
/// - Validates: Requirement 6.11 (Display data as-is for invalid/malformed data)
struct ResultRowView: View {
    /// The analysis result row to display
    let result: AnalysisResultRow
    
    /// Row index for alternating background colors (0-based)
    var rowIndex: Int = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Signal (FIRST COLUMN)
            Text(result.signal)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(signalColor)
                .frame(width: 55, alignment: .center)
            
            // Ticker
            Text(result.ticker)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            
            // Type (CALL/PUT)
            Text(result.type)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(typeColor)
                .frame(width: 45, alignment: .center)
            
            // NEW: Expiration Date (width: 80)
            // - Validates: Requirement 6.1 (Expiration Date column, formatted as YYYY-MM-DD)
            // - Validates: Requirement 6.10 (Display "N/A" when options chain is empty)
            Text(result.expirationDate)
                .font(.caption.monospacedDigit())
                .foregroundStyle(optionsFieldColor(result.expirationDate))
                .frame(width: 80, alignment: .center)
            
            // NEW: Strike Price (width: 60)
            // - Validates: Requirement 6.2 (Strike Price column, currency format)
            // - Validates: Requirement 6.10 (Display "N/A" when options chain is empty)
            Text(result.strikePrice)
                .font(.caption.monospacedDigit())
                .foregroundStyle(optionsFieldColor(result.strikePrice))
                .frame(width: 60, alignment: .trailing)
            
            // NEW: Bid Premium (width: 55)
            // - Validates: Requirement 6.3 (Bid Premium column, currency format)
            // - Validates: Requirement 6.10 (Display "N/A" when options chain is empty)
            Text(result.bidPremium)
                .font(.caption.monospacedDigit())
                .foregroundStyle(optionsFieldColor(result.bidPremium))
                .frame(width: 55, alignment: .trailing)
            
            // NEW: Ask Premium (width: 55)
            // - Validates: Requirement 6.4 (Ask Premium column, currency format)
            // - Validates: Requirement 6.10 (Display "N/A" when options chain is empty)
            Text(result.askPremium)
                .font(.caption.monospacedDigit())
                .foregroundStyle(optionsFieldColor(result.askPremium))
                .frame(width: 55, alignment: .trailing)
            
            // NEW: Mid Premium (width: 55)
            // - Validates: Requirement 6.5 (Mid Premium column, currency format)
            // - Validates: Requirement 6.10 (Display "N/A" when options chain is empty)
            Text(result.midPremium)
                .font(.caption.monospacedDigit())
                .foregroundStyle(optionsFieldColor(result.midPremium))
                .frame(width: 55, alignment: .trailing)
            
            // Return %
            Text(result.returnPercentage)
                .font(.caption.monospacedDigit())
                .foregroundStyle(returnColor)
                .frame(width: 70, alignment: .trailing)
            
            // Current Price
            Text(result.currentPrice)
                .font(.caption.monospacedDigit())
                .frame(width: 65, alignment: .trailing)
            
            // Target Price
            Text(result.targetPrice)
                .font(.caption.monospacedDigit())
                .frame(width: 65, alignment: .trailing)
            
            // Next Earnings Date
            Text(result.nextEarningsDate)
                .font(.caption.monospacedDigit())
                .foregroundStyle(earningsDateColor)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackgroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    // MARK: - Visual Indicator Properties
    
    /// Color for the opportunity type (CALL/PUT).
    /// - CALL opportunities display in bullish green to indicate positive opportunity
    /// - PUT opportunities display in bearish red to indicate negative opportunity
    /// - Validates: Requirement 6.2 (CALL with positive, PUT with negative visual distinction)
    private var typeColor: Color {
        result.type == "CALL" ? .bullish : .bearish
    }
    
    /// Color for the return percentage based on positive/negative value.
    /// - Positive returns (>= 0) display in bullish green to indicate gain
    /// - Negative returns (< 0) display in bearish red to indicate loss
    /// - Validates: Requirement 6.2 (CALL with positive return, PUT with negative return)
    private var returnColor: Color {
        result.rawReturnPercentage >= 0 ? .bullish : .bearish
    }
    
    /// Color for the signal (ORDER is highlighted).
    /// - ORDER signals display in order highlight blue to draw attention
    /// - HOLD signals display in secondary color (less prominent)
    private var signalColor: Color {
        result.signal == "ORDER" ? .orderHighlight : .secondary
    }
    
    /// Color for the earnings date (red when there's earnings risk).
    /// - Bearish red color indicates the earnings date is on or before option expiration date
    /// - Primary color indicates no earnings risk
    /// - Validates: Requirement 6.4 (Red color for earnings risk)
    private var earningsDateColor: Color {
        result.hasEarningsRisk ? .bearish : .primary
    }
    
    /// Background color for the row (highlighted for ORDER signals, alternating for others).
    /// - Highlighted row color indicates ORDER signal row
    /// - Alternating colors for non-highlighted rows provide visual separation
    /// - Validates: Requirement 6.3 (Distinct background for ORDER rows)
    private var rowBackgroundColor: Color {
        if result.isHighlighted {
            return Color.highlightedRow
        } else {
            // Alternating row colors for non-highlighted rows
            return rowIndex.isMultiple(of: 2) ? Color.alternatingRowEven : Color.alternatingRowOdd
        }
    }
    
    /// Color for options fields based on value presence.
    /// - N/A values display in secondary color to indicate missing data
    /// - Actual values display in primary color
    /// - Validates: Requirement 6.10 (Visual distinction for N/A values)
    private func optionsFieldColor(_ value: String) -> Color {
        value == "N/A" ? .secondary : .primary
    }
    
    /// Accessibility description for the row.
    /// Provides a complete, screen reader-friendly description of all columns.
    /// Labels clearly describe the column name and value (e.g., "Strike Price: $150.00").
    /// - Validates: Requirement 6.1-6.5 (Accessibility for all columns including options data)
    private var accessibilityDescription: String {
        // Signal first
        var description = "Signal: \(result.signal)"
        
        description += ", \(result.ticker): \(result.type) opportunity"
        
        // Options data - Always include column name for VoiceOver clarity
        // Format: "Column Name: value" or "Column Name: not available"
        // - Validates: Requirement 6.1 (Expiration Date column accessibility)
        if result.expirationDate == "N/A" {
            description += ", Expiration Date: not available"
        } else {
            description += ", Expiration Date: \(result.expirationDate)"
        }
        
        // - Validates: Requirement 6.2 (Strike Price column accessibility)
        if result.strikePrice == "N/A" {
            description += ", Strike Price: not available"
        } else {
            description += ", Strike Price: \(result.strikePrice)"
        }
        
        // - Validates: Requirement 6.3 (Bid Premium column accessibility)
        if result.bidPremium == "N/A" {
            description += ", Bid Premium: not available"
        } else {
            description += ", Bid Premium: \(result.bidPremium)"
        }
        
        // - Validates: Requirement 6.4 (Ask Premium column accessibility)
        if result.askPremium == "N/A" {
            description += ", Ask Premium: not available"
        } else {
            description += ", Ask Premium: \(result.askPremium)"
        }
        
        // - Validates: Requirement 6.5 (Mid Premium column accessibility)
        if result.midPremium == "N/A" {
            description += ", Mid Premium: not available"
        } else {
            description += ", Mid Premium: \(result.midPremium)"
        }
        
        // Existing fields
        description += ", Return: \(result.returnPercentage)"
        description += ", Current Price: \(result.currentPrice)"
        description += ", Target Price: \(result.targetPrice)"
        
        if result.nextEarningsDate == "N/A" {
            description += ", Next Earnings Date: not available"
        } else {
            description += ", Next Earnings Date: \(result.nextEarningsDate)"
            if result.hasEarningsRisk {
                description += " - Warning: earnings risk"
            }
        }
        
        return description
    }
}

// MARK: - Stat Card

/// A small card displaying a count statistic
private struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Result Summary Card

/// A card displaying a single result with actionable guidance
private struct ResultSummaryCard: View {
    let result: AnalysisResultRow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Ticker + Signal badge
            HStack {
                Text(result.ticker)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Signal badge
                Text(result.signal)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(result.signal == "ORDER" ? Color.orderHighlight : Color.secondary)
                    .cornerRadius(12)
            }
            
            // Action guidance in plain English
            HStack(spacing: 4) {
                Image(systemName: result.type == "CALL" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(result.type == "CALL" ? Color.bullish : Color.bearish)
                
                Text(actionText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            
            // Key details row
            HStack(spacing: 16) {
                // Premium
                if result.midPremium != "N/A" {
                    DetailItem(label: "Premium", value: result.midPremium, icon: "dollarsign.circle")
                }
                
                // Expiration
                if result.expirationDate != "N/A" {
                    DetailItem(label: "Expires", value: formatShortDate(result.expirationDate), icon: "calendar")
                }
                
                // Current price
                DetailItem(label: "Price", value: result.currentPrice, icon: "chart.line.uptrend.xyaxis")
                
                Spacer()
            }
            
            // Earnings warning if applicable
            if result.hasEarningsRisk && result.nextEarningsDate != "N/A" {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Earnings on \(formatShortDate(result.nextEarningsDate))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }
    
    /// Plain English action text
    private var actionText: String {
        let strikeText = result.strikePrice != "N/A" ? result.strikePrice : ""
        if result.type == "CALL" {
            return "Sell \(strikeText) Call".trimmingCharacters(in: .whitespaces)
        } else {
            return "Sell \(strikeText) Put".trimmingCharacters(in: .whitespaces)
        }
    }
    
    /// Background color based on signal
    private var cardBackground: Color {
        if result.signal == "ORDER" {
            return Color.orderHighlight.opacity(0.08)
        }
        return Color(.systemBackground)
    }
    
    /// Format date string to shorter format (MMM dd)
    private func formatShortDate(_ dateString: String) -> String {
        // Input is YYYY-MM-DD, convert to MMM dd
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return dateString
        }
        
        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        if month >= 1 && month <= 12 {
            return "\(monthNames[month]) \(day)"
        }
        return dateString
    }
}

// MARK: - Detail Item

/// A small detail item with icon, label, and value
private struct DetailItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview("Results View - With Data") {
    ResultsView(viewModel: ResultsViewModel.preview)
}

#Preview("Results View - Empty") {
    ResultsView(viewModel: ResultsViewModel.emptyPreview)
}
