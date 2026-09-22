//
//  WatchlistViewModel.swift
//  TradingGuru
//
//  ViewModel connecting WatchlistView to WatchlistRepository and validation.
//  Manages watchlist state, add/remove operations, and error handling.
//

import Foundation
import Observation

/// ViewModel for managing watchlist state and coordinating symbol operations.
///
/// Connects the WatchlistView to the WatchlistRepository and WatchlistValidation,
/// handling:
/// - Loading and displaying the user's watchlist
/// - Adding symbols with validation and error handling
/// - Removing symbols with database persistence
/// - Managing loading, error, and empty states
/// - Fetching and displaying real-time quote data
///
/// - Validates: Requirement 2.1 (Display loading indicator and watchlist)
/// - Validates: Requirement 2.2 (Add valid symbol and persist)
/// - Validates: Requirement 2.3 (Invalid format shows error)
/// - Validates: Requirement 2.4 (Duplicate symbol shows error)
/// - Validates: Requirement 2.5 (50-symbol limit with error)
/// - Validates: Requirement 2.6 (Remove symbol and update database)
/// - Validates: Requirement 2.7 (Display symbols with remove option)
/// - Validates: Requirement 2.8 (Empty state message)
/// - Validates: Requirement 2.9 (Database unavailability shows error)
@Observable
final class WatchlistViewModel {
    
    // MARK: - Published State
    
    /// The list of ticker symbols in the user's watchlist
    private(set) var symbols: [String] = []
    
    /// Quote data for each symbol, keyed by ticker
    private(set) var quotes: [String: StockQuote] = [:]
    
    /// Whether quotes are currently loading
    private(set) var isLoadingQuotes = false
    
    /// Whether the watchlist is currently loading
    /// - Validates: Requirement 2.1 (Display loading indicator while retrieving data)
    private(set) var isLoading = false
    
    /// Whether a symbol is currently being added
    private(set) var isAdding = false
    
    /// Set of symbols currently being removed (for UI feedback)
    private var removingSymbols: Set<String> = []
    
    /// The current error to display, if any
    private(set) var currentError: WatchlistError?
    
    /// Whether to show the error alert
    var showError = false
    
    /// Text input for new symbol entry
    var newSymbolText: String = ""
    
    /// The selected search result from autocomplete
    var selectedSearchResult: StockSearchResult?
    
    // MARK: - Computed Properties
    
    /// Whether the watchlist is empty
    /// - Validates: Requirement 2.8 (Display empty state message)
    var isEmpty: Bool {
        symbols.isEmpty
    }
    
    /// The number of symbols in the watchlist
    var symbolCount: Int {
        symbols.count
    }
    
    /// Whether the watchlist has reached its maximum capacity
    /// - Validates: Requirement 2.5 (50-symbol limit)
    var isAtCapacity: Bool {
        symbols.count >= WatchlistConstants.maxSymbols
    }
    
    /// Whether a new symbol can be added (must have selected a valid symbol from search and not adding/at capacity)
    var canAddSymbol: Bool {
        selectedSearchResult != nil && !isAdding && !isAtCapacity
    }
    
    // MARK: - Dependencies
    
    /// The repository for watchlist data persistence
    private let repository: WatchlistRepository
    
    /// The validation service for symbol and watchlist validation
    private let validation: WatchlistValidation
    
    /// The market data service for fetching quotes
    private let marketDataService: YahooFinanceService
    
    /// The user ID for the current authenticated user
    private let userId: String
    
    // MARK: - Initialization
    
    /// Creates a new WatchlistViewModel instance.
    /// - Parameters:
    ///   - repository: The repository for watchlist persistence operations
    ///   - validation: The validation service for symbol validation
    ///   - marketDataService: The service for fetching quote data
    ///   - userId: The authenticated user's ID
    init(
        repository: WatchlistRepository,
        validation: WatchlistValidation,
        marketDataService: YahooFinanceService = YahooFinanceService(),
        userId: String
    ) {
        self.repository = repository
        self.validation = validation
        self.marketDataService = marketDataService
        self.userId = userId
    }
    
    // MARK: - Load Watchlist
    
    /// Loads the watchlist from the repository.
    ///
    /// - Validates: Requirement 2.1 (Display loading indicator while retrieving data, then display watchlist)
    /// - Validates: Requirement 2.9 (Database unavailability shows error and preserves local state)
    @MainActor
    func loadWatchlist() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentError = nil
        
        do {
            let fetchedSymbols = try await repository.getWatchlist(for: userId)
            symbols = fetchedSymbols.sorted()
            isLoading = false
            
            // Load quotes for all symbols
            await loadQuotes()
        } catch let error as WatchlistError {
            isLoading = false
            currentError = error
            showError = true
        } catch {
            isLoading = false
            currentError = .databaseUnavailable
            showError = true
        }
    }
    
    /// Refreshes the watchlist (pull-to-refresh).
    @MainActor
    func refresh() async {
        // Don't show loading indicator for refresh - just reload
        do {
            let fetchedSymbols = try await repository.getWatchlist(for: userId)
            symbols = fetchedSymbols.sorted()
            
            // Refresh quotes as well
            await loadQuotes()
        } catch let error as WatchlistError {
            currentError = error
            showError = true
        } catch {
            currentError = .databaseUnavailable
            showError = true
        }
    }
    
    // MARK: - Load Quotes
    
    /// Loads real-time quote data for all symbols in the watchlist.
    ///
    /// Fetches current price, change, and percent change for each ticker.
    /// Errors are silently ignored per-symbol (quotes are supplementary data).
    @MainActor
    func loadQuotes() async {
        guard !symbols.isEmpty else {
            quotes = [:]
            return
        }
        
        isLoadingQuotes = true
        
        let results = await marketDataService.fetchQuotes(tickers: symbols)
        
        // Extract successful quotes
        var newQuotes: [String: StockQuote] = [:]
        for (ticker, result) in results {
            if case .success(let quote) = result {
                newQuotes[ticker] = quote
            }
        }
        
        quotes = newQuotes
        isLoadingQuotes = false
    }
    
    /// Gets the quote for a specific symbol, if available.
    ///
    /// - Parameter symbol: The ticker symbol to look up
    /// - Returns: The StockQuote if available, nil otherwise
    func quote(for symbol: String) -> StockQuote? {
        quotes[symbol]
    }
    
    // MARK: - Add Symbol
    
    /// Adds a symbol to the watchlist using the current text input.
    ///
    /// Validates the symbol format, checks for duplicates and capacity,
    /// then persists to the database. Preserves local state on database failures.
    ///
    /// - Validates: Requirement 2.2 (Add valid symbol and persist to database)
    /// - Validates: Requirement 2.3 (Invalid format shows error and doesn't modify watchlist)
    /// - Validates: Requirement 2.4 (Duplicate symbol shows error and doesn't modify watchlist)
    /// - Validates: Requirement 2.5 (50-symbol limit with error when reached)
    /// - Validates: Requirement 2.9 (Database unavailability shows error and preserves local state)
    @MainActor
    func addSymbol() async {
        guard !isAdding else { return }
        guard !newSymbolText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isAdding = true
        currentError = nil
        
        // Validate symbol format
        let symbolResult = validation.validateSymbol(newSymbolText)
        
        switch symbolResult {
        case .failure(let error):
            // Validates: Requirement 2.3 (Invalid format shows error)
            isAdding = false
            currentError = error
            showError = true
            return
            
        case .success(let normalizedSymbol):
            // Check for duplicate
            // Validates: Requirement 2.4 (Duplicate symbol shows error)
            if validation.isDuplicate(normalizedSymbol, in: symbols) {
                isAdding = false
                currentError = .duplicateSymbol
                showError = true
                return
            }
            
            // Check capacity
            // Validates: Requirement 2.5 (50-symbol limit with error)
            if !validation.canAddSymbol(to: symbols) {
                isAdding = false
                currentError = .limitReached(max: WatchlistConstants.maxSymbols)
                showError = true
                return
            }
            
            // Optimistically add to local state for immediate UI feedback
            // - Validates: Requirement 2.9 (Preserve local watchlist state)
            let previousSymbols = symbols
            symbols.append(normalizedSymbol)
            symbols.sort()
            
            // Persist to database
            do {
                try await repository.addSymbol(normalizedSymbol, for: userId)
                
                // Success - clear input
                newSymbolText = ""
                isAdding = false
                
            } catch let error as WatchlistError {
                // Validates: Requirement 2.9 (Database unavailability shows error, preserve local state)
                // Revert to previous state on failure
                symbols = previousSymbols
                isAdding = false
                currentError = error
                showError = true
            } catch {
                // Revert to previous state on failure
                symbols = previousSymbols
                isAdding = false
                currentError = .databaseUnavailable
                showError = true
            }
        }
    }
    
    /// Adds a specific symbol to the watchlist.
    ///
    /// - Parameter symbol: The ticker symbol to add
    /// - Throws: WatchlistError if validation or persistence fails
    @MainActor
    func addSymbol(_ symbol: String) async throws {
        // Validate using the combined validation method
        let validationResult = validation.validateSymbol(symbol)
        
        switch validationResult {
        case .failure(let error):
            currentError = error
            showError = true
            throw error
            
        case .success(let normalizedSymbol):
            // Check for duplicate
            if validation.isDuplicate(normalizedSymbol, in: symbols) {
                let error = WatchlistError.duplicateSymbol
                currentError = error
                showError = true
                throw error
            }
            
            // Check capacity
            if !validation.canAddSymbol(to: symbols) {
                let error = WatchlistError.limitReached(max: WatchlistConstants.maxSymbols)
                currentError = error
                showError = true
                throw error
            }
            
            // Persist to database
            do {
                try await repository.addSymbol(normalizedSymbol, for: userId)
                symbols.append(normalizedSymbol)
                symbols.sort()
            } catch {
                let watchlistError = (error as? WatchlistError) ?? .databaseUnavailable
                currentError = watchlistError
                showError = true
                throw watchlistError
            }
        }
    }
    
    // MARK: - Add Selected Symbol (from Search)
    
    /// Adds the selected search result symbol to the watchlist.
    ///
    /// This method is used when the user selects a symbol from the autocomplete
    /// dropdown. The symbol has already been validated by Yahoo Finance.
    ///
    /// - Validates: Requirement 2.4 (Duplicate symbol shows error)
    /// - Validates: Requirement 2.5 (50-symbol limit with error)
    /// - Validates: Requirement 2.9 (Database unavailability shows error and preserves local state)
    @MainActor
    func addSelectedSymbol() async {
        guard !isAdding else { return }
        guard let searchResult = selectedSearchResult else { return }
        
        isAdding = true
        currentError = nil
        
        let symbol = searchResult.symbol.uppercased()
        
        // Check for duplicate
        if validation.isDuplicate(symbol, in: symbols) {
            isAdding = false
            currentError = .duplicateSymbol
            showError = true
            return
        }
        
        // Check capacity
        if !validation.canAddSymbol(to: symbols) {
            isAdding = false
            currentError = .limitReached(max: WatchlistConstants.maxSymbols)
            showError = true
            return
        }
        
        // Optimistically add to local state for immediate UI feedback
        let previousSymbols = symbols
        symbols.append(symbol)
        symbols.sort()
        
        // Persist to database
        do {
            try await repository.addSymbol(symbol, for: userId)
            
            // Success - clear input and selection
            newSymbolText = ""
            selectedSearchResult = nil
            isAdding = false
            
            // Load quote for the new symbol
            await loadQuoteForSymbol(symbol)
            
        } catch let error as WatchlistError {
            // Revert to previous state on failure
            symbols = previousSymbols
            isAdding = false
            currentError = error
            showError = true
        } catch {
            // Revert to previous state on failure
            symbols = previousSymbols
            isAdding = false
            currentError = .databaseUnavailable
            showError = true
        }
    }
    
    /// Loads quote data for a single symbol.
    @MainActor
    private func loadQuoteForSymbol(_ symbol: String) async {
        let results = await marketDataService.fetchQuotes(tickers: [symbol])
        if let result = results[symbol], case .success(let quote) = result {
            quotes[symbol] = quote
        }
    }
    
    // MARK: - Remove Symbol
    
    /// Removes a symbol at the specified offsets from the watchlist.
    ///
    /// - Parameter offsets: The index set of symbols to remove
    /// - Validates: Requirement 2.6 (Remove symbol and update database)
    @MainActor
    func removeSymbols(at offsets: IndexSet) async {
        for index in offsets {
            guard index < symbols.count else { continue }
            let symbol = symbols[index]
            await removeSymbol(symbol)
        }
    }
    
    /// Removes a specific symbol from the watchlist.
    ///
    /// - Parameter symbol: The ticker symbol to remove
    /// - Validates: Requirement 2.6 (Remove symbol and update database)
    /// - Validates: Requirement 2.9 (Database unavailability shows error and preserves local state)
    @MainActor
    func removeSymbol(_ symbol: String) async {
        guard symbols.contains(symbol) else { return }
        
        removingSymbols.insert(symbol)
        
        // Optimistically remove from local state for immediate UI feedback
        // - Validates: Requirement 2.9 (Preserve local watchlist state)
        let previousSymbols = symbols
        symbols.removeAll { $0 == symbol }
        
        do {
            try await repository.removeSymbol(symbol, for: userId)
            
            // Success - removal already reflected in local state
            removingSymbols.remove(symbol)
            
        } catch let error as WatchlistError {
            // Validates: Requirement 2.9 (Database unavailability shows error, preserve local state)
            // Revert to previous state on failure
            symbols = previousSymbols
            removingSymbols.remove(symbol)
            currentError = error
            showError = true
        } catch {
            // Revert to previous state on failure
            symbols = previousSymbols
            removingSymbols.remove(symbol)
            currentError = .databaseUnavailable
            showError = true
        }
    }
    
    /// Checks if a specific symbol is currently being removed.
    ///
    /// - Parameter symbol: The symbol to check
    /// - Returns: True if the symbol is currently being removed
    func isRemoving(_ symbol: String) -> Bool {
        removingSymbols.contains(symbol)
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error state.
    ///
    /// Call this when the user dismisses an error alert.
    @MainActor
    func clearError() {
        currentError = nil
        showError = false
    }
}

// MARK: - Preview Support

#if DEBUG
/// Mock repository for SwiftUI previews
final class MockWatchlistRepository: WatchlistRepository {
    var symbols: [String] = []
    var shouldFail = false
    var simulatedDelay: TimeInterval = 0.3
    
    func getWatchlist(for userId: String) async throws -> [String] {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        return symbols
    }
    
    func addSymbol(_ symbol: String, for userId: String) async throws {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        symbols.append(symbol)
    }
    
    func removeSymbol(_ symbol: String, for userId: String) async throws {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        symbols.removeAll { $0 == symbol }
    }
}

extension WatchlistViewModel {
    /// Creates a preview instance with mock dependencies and sample data
    static var preview: WatchlistViewModel {
        let mockRepo = MockWatchlistRepository()
        mockRepo.symbols = ["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN"]
        return WatchlistViewModel(
            repository: mockRepo,
            validation: WatchlistValidationService(),
            userId: "preview-user"
        )
    }
    
    /// Creates a preview instance with an empty watchlist
    static var emptyPreview: WatchlistViewModel {
        let mockRepo = MockWatchlistRepository()
        mockRepo.symbols = []
        return WatchlistViewModel(
            repository: mockRepo,
            validation: WatchlistValidationService(),
            userId: "preview-user"
        )
    }
    
    /// Creates a preview instance with a full watchlist (50 symbols)
    static var fullPreview: WatchlistViewModel {
        let mockRepo = MockWatchlistRepository()
        // Generate 50 mock symbols (e.g., AAX, ABX, ACX, ..., BXX)
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        mockRepo.symbols = (0..<50).map { index in
            let first = letters[index / 26]
            let second = letters[index % 26]
            return "\(first)\(second)X"
        }
        return WatchlistViewModel(
            repository: mockRepo,
            validation: WatchlistValidationService(),
            userId: "preview-user"
        )
    }
}
#endif
