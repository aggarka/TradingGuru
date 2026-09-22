//
//  Watchlist.swift
//  TradingGuru
//
//  Watchlist model for managing user's stock symbol collections.
//

import Foundation

/// Represents a user's stock watchlist containing ticker symbols to analyze.
/// - Validates: Requirements 2.1 (Watchlist management)
struct Watchlist: Codable, Equatable {
    /// User ID this watchlist belongs to
    let userId: String
    
    /// Array of stock ticker symbols
    var symbols: [String]
    
    /// Timestamp when the watchlist was last updated
    var updatedAt: Date
    
    /// Maximum number of symbols allowed in a watchlist
    static let maxSymbols = 50
    
    /// Creates a new Watchlist instance.
    /// - Parameters:
    ///   - userId: The user ID this watchlist belongs to
    ///   - symbols: Array of ticker symbols
    ///   - updatedAt: Last update timestamp
    init(
        userId: String,
        symbols: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.symbols = symbols
        self.updatedAt = updatedAt
    }
    
    /// Checks if the watchlist has reached its maximum capacity.
    var isAtCapacity: Bool {
        symbols.count >= Self.maxSymbols
    }
    
    /// Checks if a symbol already exists in the watchlist.
    /// - Parameter symbol: The ticker symbol to check
    /// - Returns: True if the symbol exists in the watchlist
    func contains(_ symbol: String) -> Bool {
        symbols.contains(symbol.uppercased())
    }
    
    /// Validates and adds a symbol to the watchlist.
    /// - Parameter symbol: The ticker symbol to add
    /// - Returns: Result indicating success or the specific error
    mutating func addSymbol(_ symbol: String) -> Result<Void, WatchlistError> {
        let normalizedSymbol = symbol.uppercased()
        
        // Validate symbol format
        guard normalizedSymbol.isValidTickerSymbol else {
            return .failure(.invalidFormat)
        }
        
        // Check for duplicates
        guard !contains(normalizedSymbol) else {
            return .failure(.duplicateSymbol)
        }
        
        // Check capacity
        guard !isAtCapacity else {
            return .failure(.limitReached(max: Self.maxSymbols))
        }
        
        symbols.append(normalizedSymbol)
        updatedAt = Date()
        return .success(())
    }
    
    /// Removes a symbol from the watchlist.
    /// - Parameter symbol: The ticker symbol to remove
    /// - Returns: True if the symbol was removed, false if not found
    @discardableResult
    mutating func removeSymbol(_ symbol: String) -> Bool {
        let normalizedSymbol = symbol.uppercased()
        if let index = symbols.firstIndex(of: normalizedSymbol) {
            symbols.remove(at: index)
            updatedAt = Date()
            return true
        }
        return false
    }
}
