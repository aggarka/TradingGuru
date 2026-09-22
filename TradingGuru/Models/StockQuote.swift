//
//  StockQuote.swift
//  TradingGuru
//
//  Model representing real-time stock quote data.
//

import Foundation

/// Real-time quote data for a stock ticker.
///
/// Contains the current price, price change, and percentage change
/// from the previous trading day's close.
struct StockQuote: Equatable, Sendable {
    /// The stock ticker symbol (e.g., "AAPL")
    let symbol: String
    
    /// Current/last traded price
    let price: Double
    
    /// Price change from previous close (can be negative)
    let change: Double
    
    /// Percentage change from previous close (can be negative)
    let changePercent: Double
    
    /// Whether the price change is positive or zero
    var isPositive: Bool {
        change >= 0
    }
    
    /// Formatted price string with 2 decimal places
    var formattedPrice: String {
        String(format: "$%.2f", price)
    }
    
    /// Formatted change string with sign and 2 decimal places
    var formattedChange: String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f", sign, change)
    }
    
    /// Formatted percentage change with sign and 2 decimal places
    var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }
}
