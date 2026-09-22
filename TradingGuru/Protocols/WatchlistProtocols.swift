//
//  WatchlistProtocols.swift
//  TradingGuru
//
//  Protocol definitions for watchlist repository and validation services.
//

import Foundation

// MARK: - Watchlist Repository Protocol

/// Protocol for watchlist data persistence operations.
/// 
/// The repository handles CRUD operations for user watchlists,
/// abstracting the underlying data source (Firestore, local cache, etc.).
/// 
/// - Validates: Requirements 2.1, 2.2, 2.6, 2.9 (Watchlist management)
protocol WatchlistRepository {
    /// Retrieves the watchlist for a specific user.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: Array of ticker symbols in the user's watchlist
    /// - Throws: WatchlistError if retrieval fails
    /// - Validates: Requirement 2.1 (Retrieve watchlist from database)
    func getWatchlist(for userId: String) async throws -> [String]
    
    /// Adds a ticker symbol to the user's watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to add (should be validated first)
    ///   - userId: The unique identifier of the user
    /// - Throws: WatchlistError if the operation fails
    /// - Validates: Requirement 2.2 (Add symbol to watchlist)
    func addSymbol(_ symbol: String, for userId: String) async throws
    
    /// Removes a ticker symbol from the user's watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to remove
    ///   - userId: The unique identifier of the user
    /// - Throws: WatchlistError if the operation fails
    /// - Validates: Requirement 2.6 (Remove symbol from watchlist)
    func removeSymbol(_ symbol: String, for userId: String) async throws
}

// MARK: - Watchlist Validation Protocol

/// Protocol for validating watchlist operations.
/// 
/// Provides validation logic for ticker symbol format, duplicates,
/// and watchlist capacity limits.
/// 
/// - Validates: Requirements 2.2, 2.3, 2.4, 2.5 (Watchlist validation rules)
protocol WatchlistValidation {
    /// Validates a ticker symbol format.
    /// - Parameter symbol: The ticker symbol to validate
    /// - Returns: Result with normalized symbol on success, or WatchlistError on failure
    /// - Validates: Requirements 2.2, 2.3 (1-5 uppercase letters validation)
    func validateSymbol(_ symbol: String) -> Result<String, WatchlistError>
    
    /// Checks if a symbol can be added to the watchlist.
    /// - Parameter watchlist: The current watchlist
    /// - Returns: True if the watchlist has capacity for more symbols
    /// - Validates: Requirement 2.5 (50-symbol limit)
    func canAddSymbol(to watchlist: [String]) -> Bool
    
    /// Checks if a symbol already exists in the watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to check
    ///   - watchlist: The current watchlist
    /// - Returns: True if the symbol is a duplicate
    /// - Validates: Requirement 2.4 (Duplicate detection)
    func isDuplicate(_ symbol: String, in watchlist: [String]) -> Bool
}

// MARK: - Watchlist Error

/// Errors that can occur during watchlist operations.
/// - Validates: Requirements 2.3, 2.4, 2.5, 2.9 (Watchlist error handling)
enum WatchlistError: Error, Equatable {
    /// The ticker symbol format is invalid (not 1-5 uppercase letters).
    /// - Validates: Requirement 2.3 (Invalid format error)
    case invalidFormat
    
    /// The ticker symbol already exists in the watchlist.
    /// - Validates: Requirement 2.4 (Duplicate symbol error)
    case duplicateSymbol
    
    /// The watchlist has reached its maximum capacity.
    /// - Validates: Requirement 2.5 (Limit reached error)
    case limitReached(max: Int)
    
    /// The database is unavailable.
    /// - Validates: Requirement 2.9 (Database unavailability)
    case databaseUnavailable
}

// MARK: - Error Descriptions

extension WatchlistError: LocalizedError {
    /// Returns the error description using the catalog message.
    /// - Validates: Requirements 2.3, 2.4, 2.5, 2.9
    var errorDescription: String? {
        return catalogMessage(symbol: nil)
    }
    
    /// User-friendly error message from the error catalog.
    /// - Parameter symbol: The ticker symbol for symbol-specific messages
    /// - Validates: Requirements 2.3, 2.4, 2.5, 2.9
    func catalogMessage(symbol: String? = nil) -> String {
        switch self {
        case .invalidFormat:
            return ErrorMessageCatalog.Watchlist.invalidFormat
        case .duplicateSymbol:
            if let symbol = symbol {
                return ErrorMessageCatalog.Watchlist.duplicateSymbol(symbol)
            }
            return "This symbol is already in your watchlist."
        case .limitReached:
            return ErrorMessageCatalog.Watchlist.limitReached
        case .databaseUnavailable:
            return ErrorMessageCatalog.Watchlist.databaseUnavailable
        }
    }
}

// MARK: - Ticker Symbol Validation Extension

extension String {
    /// Validates if the string is a valid ticker symbol (1-5 uppercase letters).
    /// - Returns: True if the string matches the ticker symbol format
    /// - Validates: Requirements 2.2, 2.3 (Ticker format validation)
    var isValidTickerSymbol: Bool {
        let pattern = "^[A-Z]{1,5}$"
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Normalizes a ticker symbol to uppercase.
    /// - Returns: The symbol converted to uppercase
    var normalizedTickerSymbol: String {
        return uppercased().trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Watchlist Constants

/// Constants related to watchlist functionality.
enum WatchlistConstants {
    /// Maximum number of symbols allowed in a watchlist.
    /// - Validates: Requirement 2.5 (50-symbol limit)
    static let maxSymbols = 50
}
