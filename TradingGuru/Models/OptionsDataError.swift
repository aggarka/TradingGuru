//
//  OptionsDataError.swift
//  TradingGuru
//
//  Error types for options chain data operations.
//

import Foundation

/// Errors specific to options data operations.
/// - Validates: Requirement 1.4 (Error handling for options data)
/// - Validates: Requirement 3.7 (Invalid date validation)
enum OptionsDataError: Error, Equatable {
    /// Options data unavailable for ticker
    case optionsUnavailable(ticker: String)
    
    /// No options exist for the specified expiration
    case noOptionsForExpiration(ticker: String, expiration: Date)
    
    /// Invalid or malformed options data
    case invalidOptionsData(ticker: String)
    
    /// Network error during options fetch
    case networkError(underlying: String)
    
    /// Invalid expiration date selected
    /// - Validates: Requirement 3.7 (Invalid date validation)
    case invalidExpirationDate(date: Date, reason: String)
}
