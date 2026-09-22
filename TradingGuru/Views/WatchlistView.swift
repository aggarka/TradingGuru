//
//  WatchlistView.swift
//  TradingGuru
//
//  Watchlist screen for managing user's stock ticker symbols.
//

import SwiftUI

/// View displaying the user's watchlist with add/remove functionality.
///
/// Displays the list of ticker symbols with delete capability, provides
/// a text field for adding new symbols, shows loading indicators during
/// data retrieval, and displays appropriate empty state and error messages.
///
/// - Validates: Requirement 2.1 (Display loading indicator and watchlist)
/// - Validates: Requirement 2.7 (Display symbols in list with remove option)
/// - Validates: Requirement 2.8 (Display empty state message)
/// - Validates: Requirement 2.9 (Display error messages for failures)
struct WatchlistView: View {
    // MARK: - ViewModel
    
    /// The ViewModel managing watchlist state and operations
    @Bindable var viewModel: WatchlistViewModel
    
    // MARK: - Focus State
    
    /// Tracks focus on the symbol input text field
    @FocusState private var isSymbolFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - tap to dismiss keyboard
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissKeyboard()
                    }
                
                VStack(spacing: 0) {
                    // Add symbol section
                    addSymbolSection
                    
                    // Content area
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.isEmpty {
                        emptyStateView
                    } else {
                        symbolListView
                    }
                }
            }
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Watchlist Error", isPresented: $viewModel.showError, presenting: viewModel.currentError) { _ in
                Button("OK") {
                    viewModel.clearError()
                }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
            .task {
                await viewModel.loadWatchlist()
            }
        }
    }
    
    // MARK: - Keyboard Dismissal
    
    /// Dismisses the keyboard by removing focus from any text field.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Add Symbol Section
    
    /// Stock search field with autocomplete dropdown.
    /// Users must select a valid symbol from search results to add to watchlist.
    private var addSymbolSection: some View {
        VStack(spacing: 0) {
            StockSearchField(
                text: $viewModel.newSymbolText,
                onSymbolSelected: { result in
                    viewModel.selectedSearchResult = result
                },
                onAddTapped: {
                    Task {
                        await viewModel.addSelectedSymbol()
                    }
                },
                isAdding: viewModel.isAdding
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.tradingCardBackground)
            
            Divider()
        }
    }
    
    // MARK: - Loading View
    
    /// - Validates: Requirement 2.1 (Display loading indicator while retrieving data)
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading watchlist...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading watchlist, please wait")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Empty State View
    
    /// - Validates: Requirement 2.8 (Display empty state message prompting user to add stocks)
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.tradingAccent.opacity(0.4))
                .accessibilityHidden(true)
            
            Text("Your Watchlist is Empty")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Add stock ticker symbols to start tracking and analyzing your favorite stocks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your watchlist is empty. Add stock ticker symbols to start tracking and analyzing your favorite stocks.")
        .onTapGesture {
            dismissKeyboard()
        }
    }
    
    // MARK: - Symbol List View
    
    /// - Validates: Requirement 2.7 (Display each ticker symbol in list format with remove option)
    private var symbolListView: some View {
        List {
            Section {
                ForEach(Array(viewModel.symbols.enumerated()), id: \.element) { index, symbol in
                    SymbolRow(
                        symbol: symbol,
                        quote: viewModel.quote(for: symbol),
                        isRemoving: viewModel.isRemoving(symbol),
                        rowIndex: index
                    )
                }
                .onDelete { offsets in
                    Task {
                        await viewModel.removeSymbols(at: offsets)
                    }
                }
            } header: {
                HStack {
                    Text("\(viewModel.symbolCount) symbol\(viewModel.symbolCount == 1 ? "" : "s")")
                    Spacer()
                    if viewModel.isLoadingQuotes {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if viewModel.isAtCapacity {
                        Text("Limit reached")
                            .foregroundStyle(Color.warning)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
        // Dismiss keyboard when scrolling the list
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Keyboard Dismissal Extension

extension View {
    /// Hides the keyboard by resigning first responder
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Symbol Row Component

/// A row displaying a single ticker symbol in the watchlist with quote data.
struct SymbolRow: View {
    let symbol: String
    let quote: StockQuote?
    var isRemoving: Bool = false
    var rowIndex: Int = 0
    
    var body: some View {
        HStack {
            // Symbol name
            Text(symbol)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.tradingTextPrimary)
            
            Spacer()
            
            if isRemoving {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let quote = quote {
                // Quote data
                VStack(alignment: .trailing, spacing: 2) {
                    // Current price
                    Text(quote.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.tradingTextPrimary)
                    
                    // Change and percent change
                    HStack(spacing: 4) {
                        Text(quote.formattedChange)
                            .font(.caption)
                        Text("(\(quote.formattedChangePercent))")
                            .font(.caption)
                    }
                    .foregroundStyle(quote.isPositive ? Color.bullish : Color.bearish)
                }
            } else {
                // Loading placeholder
                VStack(alignment: .trailing, spacing: 2) {
                    Text("--")
                        .font(.subheadline)
                        .foregroundStyle(Color.tradingTextSecondary)
                    Text("--")
                        .font(.caption)
                        .foregroundStyle(Color.tradingTextSecondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 4)
        .opacity(isRemoving ? 0.5 : 1.0)
        .listRowBackground(rowIndex.isMultiple(of: 2) ? Color.alternatingRowEven : Color.alternatingRowOdd)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Swipe left to delete")
    }
    
    private var accessibilityLabel: String {
        if let quote = quote {
            let direction = quote.isPositive ? "up" : "down"
            return "\(symbol), price \(quote.formattedPrice), \(direction) \(quote.formattedChange), \(quote.formattedChangePercent)"
        }
        return symbol
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Watchlist View - With Symbols") {
    let viewModel = WatchlistViewModel.preview
    Task {
        await viewModel.loadWatchlist()
    }
    return WatchlistView(viewModel: viewModel)
}

#Preview("Watchlist View - Empty") {
    let viewModel = WatchlistViewModel.emptyPreview
    Task {
        await viewModel.loadWatchlist()
    }
    return WatchlistView(viewModel: viewModel)
}

#Preview("Watchlist View - At Capacity") {
    let viewModel = WatchlistViewModel.fullPreview
    Task {
        await viewModel.loadWatchlist()
    }
    return WatchlistView(viewModel: viewModel)
}
#endif
