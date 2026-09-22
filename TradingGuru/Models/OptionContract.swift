//
//  OptionContract.swift
//  TradingGuru
//
//  Option contract model for live options chain data.
//

import Foundation

// MARK: - Option Contract Model

/// Represents a single option contract with pricing data.
/// - Validates: Requirement 1.3 (Option contract data with strike, bid, ask)
/// - Validates: Requirement 1.6 (Mid-price calculation)
struct OptionContract: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for the contract
    let id: UUID
    
    /// The underlying stock ticker
    let ticker: String
    
    /// Option type (CALL or PUT)
    let type: OpportunityType
    
    /// The strike price
    let strikePrice: Double
    
    /// The bid price
    let bid: Double
    
    /// The ask price
    let ask: Double
    
    /// The expiration date
    let expirationDate: Date
    
    // MARK: - Computed Properties
    
    /// Calculated mid-price: (bid + ask) / 2
    /// - Validates: Requirement 1.6 (Mid-price calculation)
    var midPrice: Double {
        (bid + ask) / 2.0
    }
    
    // MARK: - Initialization
    
    /// Creates an OptionContract with the specified values.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - ticker: The underlying stock ticker symbol
    ///   - type: Option type (CALL or PUT)
    ///   - strikePrice: The strike price of the option
    ///   - bid: The bid price
    ///   - ask: The ask price
    ///   - expirationDate: The expiration date of the option
    init(
        id: UUID = UUID(),
        ticker: String,
        type: OpportunityType,
        strikePrice: Double,
        bid: Double,
        ask: Double,
        expirationDate: Date
    ) {
        self.id = id
        self.ticker = ticker
        self.type = type
        self.strikePrice = strikePrice
        self.bid = bid
        self.ask = ask
        self.expirationDate = expirationDate
    }
}
