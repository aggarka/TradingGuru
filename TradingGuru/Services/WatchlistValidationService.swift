//
//  WatchlistValidationService.swift
//  TradingGuru
//
//  Validation service for watchlist operations including symbol format,
//  duplicate detection, and capacity limit enforcement.
//

import Foundation

/// Concrete implementation of WatchlistValidation protocol.
/// 
/// Provides validation logic for ticker symbol format, duplicates,
/// and watchlist capacity limits.
/// 
/// - Validates: Requirements 2.2, 2.3, 2.4, 2.5 (Watchlist validation rules)
final class WatchlistValidationService: WatchlistValidation {
    
    // MARK: - Symbol Validation
    
    /// Validates a ticker symbol format and normalizes it to uppercase.
    /// - Parameter symbol: The ticker symbol to validate
    /// - Returns: Result with normalized symbol on success, or WatchlistError on failure
    /// - Validates: Requirements 2.2, 2.3 (1-5 uppercase letters validation)
    func validateSymbol(_ symbol: String) -> Result<String, WatchlistError> {
        // Normalize the symbol: trim whitespace and convert to uppercase
        let normalizedSymbol = symbol.normalizedTickerSymbol
        
        // Validate against the required format (1-5 uppercase letters)
        guard normalizedSymbol.isValidTickerSymbol else {
            return .failure(.invalidFormat)
        }
        
        return .success(normalizedSymbol)
    }
    
    // MARK: - Capacity Check
    
    /// Checks if a symbol can be added to the watchlist based on capacity.
    /// - Parameter watchlist: The current watchlist array
    /// - Returns: True if the watchlist has capacity for more symbols
    /// - Validates: Requirement 2.5 (50-symbol limit)
    func canAddSymbol(to watchlist: [String]) -> Bool {
        return watchlist.count < WatchlistConstants.maxSymbols
    }
    
    // MARK: - Duplicate Check
    
    /// Checks if a symbol already exists in the watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to check
    ///   - watchlist: The current watchlist array
    /// - Returns: True if the symbol is a duplicate (case-insensitive comparison)
    /// - Validates: Requirement 2.4 (Duplicate detection)
    func isDuplicate(_ symbol: String, in watchlist: [String]) -> Bool {
        // Normalize the symbol for comparison
        let normalizedSymbol = symbol.normalizedTickerSymbol
        
        // Check if the normalized symbol exists in the watchlist
        // Watchlist symbols should already be normalized, but we compare case-insensitively
        return watchlist.contains { $0.uppercased() == normalizedSymbol }
    }
    
    // MARK: - Combined Validation
    
    /// Validates all conditions for adding a symbol to a watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to add
    ///   - watchlist: The current watchlist array
    /// - Returns: Result with normalized symbol on success, or the first WatchlistError encountered
    /// - Validates: Requirements 2.2, 2.3, 2.4, 2.5
    func validateAddition(_ symbol: String, to watchlist: [String]) -> Result<String, WatchlistError> {
        // First validate the symbol format
        let validationResult = validateSymbol(symbol)
        
        switch validationResult {
        case .failure(let error):
            return .failure(error)
        case .success(let normalizedSymbol):
            // Check for duplicates
            if isDuplicate(normalizedSymbol, in: watchlist) {
                return .failure(.duplicateSymbol)
            }
            
            // Check capacity
            if !canAddSymbol(to: watchlist) {
                return .failure(.limitReached(max: WatchlistConstants.maxSymbols))
            }
            
            return .success(normalizedSymbol)
        }
    }
}
