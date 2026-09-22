//
//  OptionsChain.swift
//  TradingGuru
//
//  Contains all option contracts for a ticker at a specific expiration.
//

import Foundation

/// Contains all option contracts for a ticker at a specific expiration.
/// - Validates: Requirement 1.2 (Retrieve calls and puts at all strikes)
/// - Validates: Requirement 1.5 (Empty chain handling)
struct OptionsChain: Codable, Equatable {
    
    /// The underlying stock ticker
    let ticker: String
    
    /// The expiration date for this chain
    let expirationDate: Date
    
    /// All call options in the chain
    let calls: [OptionContract]
    
    /// All put options in the chain
    let puts: [OptionContract]
    
    /// Timestamp when the chain was fetched
    let fetchedAt: Date
    
    // MARK: - Computed Properties
    
    /// Whether the chain is empty (no contracts)
    var isEmpty: Bool {
        calls.isEmpty && puts.isEmpty
    }
    
    // MARK: - Factory Methods
    
    /// Creates an empty chain for error cases.
    /// - Parameters:
    ///   - ticker: The stock ticker symbol
    ///   - expirationDate: The expiration date for the chain
    /// - Returns: An empty OptionsChain with no contracts
    /// - Validates: Requirement 1.5 (Empty chain handling)
    static func empty(ticker: String, expirationDate: Date) -> OptionsChain {
        OptionsChain(
            ticker: ticker,
            expirationDate: expirationDate,
            calls: [],
            puts: [],
            fetchedAt: Date()
        )
    }
}
