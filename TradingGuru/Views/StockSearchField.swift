//
//  StockSearchField.swift
//  TradingGuru
//
//  A search field with autocomplete dropdown for stock symbols.
//

import SwiftUI

/// A text field with autocomplete dropdown for searching stock symbols.
///
/// Displays search results as user types, allowing selection of valid
/// stock symbols from Yahoo Finance.
struct StockSearchField: View {
    
    // MARK: - Properties
    
    /// Binding to the search text
    @Binding var text: String
    
    /// Callback when a symbol is selected from the dropdown
    let onSymbolSelected: (StockSearchResult) -> Void
    
    /// Callback when the add button is tapped (if symbol is valid)
    let onAddTapped: () -> Void
    
    /// Whether adding is in progress
    let isAdding: Bool
    
    // MARK: - State
    
    /// Search results from Yahoo Finance
    @State private var searchResults: [StockSearchResult] = []
    
    /// Whether a search is in progress
    @State private var isSearching = false
    
    /// Whether to show the dropdown
    @State private var showDropdown = false
    
    /// The currently selected/validated symbol
    @State private var selectedSymbol: StockSearchResult?
    
    /// Search debounce task
    @State private var searchTask: Task<Void, Never>?
    
    /// Focus state for the text field
    @FocusState private var isFocused: Bool
    
    /// The search service
    private let searchService = StockSymbolSearchService()
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Search input field
                searchTextField
                
                // Cancel button (only shown when focused)
                if isFocused {
                    cancelButton
                }
            }
            
            // Dropdown overlay
            if showDropdown && !searchResults.isEmpty {
                searchResultsDropdown
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    // MARK: - Search Text Field
    
    private var searchTextField: some View {
        HStack {
            TextField("Search stock symbol or company", text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    handleTextChange(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if focused && !text.isEmpty && !searchResults.isEmpty {
                        showDropdown = true
                    }
                }
                .onSubmit {
                    // If there's exactly one result, select it
                    if searchResults.count == 1 {
                        selectSymbol(searchResults[0])
                    } else if selectedSymbol != nil {
                        onAddTapped()
                    }
                }
            
            // Clear button
            if !text.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Loading indicator
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityLabel("Stock symbol search")
        .accessibilityHint("Type a stock symbol or company name to search")
    }
    
    // MARK: - Cancel Button
    
    private var cancelButton: some View {
        Button("Cancel") {
            cancelSearch()
        }
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Cancel search")
        .accessibilityHint("Dismisses keyboard and clears search")
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    // MARK: - Search Results Dropdown
    
    private var searchResultsDropdown: some View {
        VStack(spacing: 0) {
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { result in
                        searchResultRow(result)
                        
                        if result.id != searchResults.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(maxHeight: 250)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Search Result Row
    
    private func searchResultRow(_ result: StockSearchResult) -> some View {
        Button {
            selectSymbol(result)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.symbol)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(result.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(result.exchange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.symbol), \(result.name)")
        .accessibilityHint("Double tap to add \(result.symbol) to your watchlist")
    }
    
    // MARK: - Actions
    
    private func handleTextChange(_ newValue: String) {
        // Cancel any pending search
        searchTask?.cancel()
        
        // Clear selected symbol when text changes manually
        if selectedSymbol?.symbol != newValue.uppercased() {
            selectedSymbol = nil
        }
        
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            searchResults = []
            showDropdown = false
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await performSearch(query: trimmed)
        }
    }
    
    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        
        do {
            let results = try await searchService.search(query: query)
            
            if !Task.isCancelled {
                searchResults = results
                showDropdown = !results.isEmpty && isFocused
            }
        } catch {
            // Silently fail - just show no results
            searchResults = []
            showDropdown = false
        }
        
        isSearching = false
    }
    
    private func selectSymbol(_ result: StockSearchResult) {
        selectedSymbol = result
        text = result.symbol
        showDropdown = false
        searchResults = []
        onSymbolSelected(result)
        // Immediately add the symbol when selected from dropdown
        onAddTapped()
    }
    
    private func clearSearch() {
        text = ""
        searchResults = []
        showDropdown = false
        selectedSymbol = nil
        searchTask?.cancel()
    }
    
    private func cancelSearch() {
        clearSearch()
        isFocused = false
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Stock Search Field") {
    struct PreviewWrapper: View {
        @State private var text = ""
        
        var body: some View {
            VStack {
                StockSearchField(
                    text: $text,
                    onSymbolSelected: { result in
                        print("Selected: \(result.symbol)")
                    },
                    onAddTapped: {
                        print("Add tapped")
                    },
                    isAdding: false
                )
                .padding()
                
                Spacer()
            }
        }
    }
    
    return PreviewWrapper()
}
#endif
