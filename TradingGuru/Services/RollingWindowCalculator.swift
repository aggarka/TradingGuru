//
//  RollingWindowCalculator.swift
//  TradingGuru
//
//  Service for calculating rolling window returns from historical price data.
//  Implements the rolling window return calculation algorithm for the Weekly Option Strategy.
//

import Foundation

// MARK: - Rolling Window Return

/// Represents a single rolling window return calculation result.
/// Contains the start date, end date, and percentage return for the window.
/// - Validates: Requirement 5.2 (Rolling window return calculation)
struct RollingWindowReturn: Equatable {
    /// The start date of the rolling window
    let startDate: Date
    
    /// The end date of the rolling window
    let endDate: Date
    
    /// The percentage return over the window period
    /// Calculated as: ((endPrice - startPrice) / startPrice) * 100
    let returnPct: Double
}

// MARK: - Insufficient Data Error

/// Error thrown when there is insufficient price data for rolling window calculation.
/// - Validates: Requirement 5.6 (Handle insufficient data scenarios)
enum RollingWindowError: Error, Equatable {
    /// The price data has fewer trading days than the configured WINDOW_DAYS
    case insufficientData(available: Int, required: Int, ticker: String?)
    
    /// The price data array is empty
    case emptyPriceData(ticker: String?)
    
    /// Invalid window days value (must be positive)
    case invalidWindowDays(value: Int)
}

extension RollingWindowError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .insufficientData(let available, let required, let ticker):
            if let ticker = ticker {
                return "\(ticker): Insufficient price history. Available: \(available) days, Required: \(required) days."
            }
            return "Insufficient price history. Available: \(available) days, Required: \(required) days."
            
        case .emptyPriceData(let ticker):
            if let ticker = ticker {
                return "\(ticker): No price data available."
            }
            return "No price data available."
            
        case .invalidWindowDays(let value):
            return "Invalid window days value: \(value). Window days must be positive."
        }
    }
}

// MARK: - Rolling Window Calculator Protocol

/// Protocol for rolling window return calculation.
/// Enables different implementations and testability through dependency injection.
protocol RollingWindowCalculation {
    
    /// Calculates rolling window returns for the given price data.
    ///
    /// For each valid window starting at index i, the return is calculated as:
    /// `return = ((prices[i + windowDays].close - prices[i].close) / prices[i].close) * 100`
    ///
    /// - Parameters:
    ///   - prices: Array of price points sorted by date (oldest first)
    ///   - windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns
    /// - Throws: RollingWindowError if insufficient data or invalid parameters
    /// - Validates: Requirement 5.2 (Rolling window return calculation)
    func calculateRollingReturns(
        prices: [PricePoint],
        windowDays: Int
    ) throws -> [RollingWindowReturn]
    
    /// Calculates rolling window returns, returning empty array for insufficient data.
    ///
    /// This is a convenience method that returns an empty array instead of throwing
    /// when there is insufficient data. Useful when processing multiple tickers
    /// and wanting to continue on insufficient data.
    ///
    /// - Parameters:
    ///   - prices: Array of price points sorted by date (oldest first)
    ///   - windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns, or empty array if insufficient data
    /// - Validates: Requirement 5.6 (Skip ticker with insufficient data)
    func calculateRollingReturnsOrEmpty(
        prices: [PricePoint],
        windowDays: Int
    ) -> [RollingWindowReturn]
}

// MARK: - Rolling Window Calculator

/// Concrete implementation of rolling window return calculation.
///
/// This calculator processes historical price data to compute percentage changes
/// over a specified window period. It is a core component of the Weekly Option Strategy.
///
/// Usage:
/// ```swift
/// let calculator = RollingWindowCalculator()
/// let prices = [PricePoint(date: date1, close: 100.0), ...]
/// let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
/// ```
///
/// - Validates: Requirement 5.2 (Calculate rolling window returns)
/// - Validates: Requirement 5.6 (Handle insufficient data scenarios)
final class RollingWindowCalculator: RollingWindowCalculation {
    
    // MARK: - Properties
    
    /// Optional ticker symbol for error messages
    private let ticker: String?
    
    // MARK: - Initialization
    
    /// Creates a new RollingWindowCalculator.
    /// - Parameter ticker: Optional ticker symbol for error messages
    init(ticker: String? = nil) {
        self.ticker = ticker
    }
    
    // MARK: - Rolling Returns Calculation
    
    /// Calculates rolling window returns for the given price data.
    ///
    /// The algorithm processes each trading day in the lookback period:
    /// - For each window starting at index i:
    ///   `return = ((prices[i + windowDays].close - prices[i].close) / prices[i].close) * 100`
    ///
    /// The prices array should be sorted chronologically with the oldest price first.
    ///
    /// - Parameters:
    ///   - prices: Array of price points sorted by date (oldest first)
    ///   - windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns
    /// - Throws: RollingWindowError.insufficientData if prices.count < windowDays
    /// - Throws: RollingWindowError.emptyPriceData if prices is empty
    /// - Throws: RollingWindowError.invalidWindowDays if windowDays <= 0
    /// - Validates: Requirement 5.2 (Rolling window return calculation formula)
    /// - Validates: Requirement 5.6 (Handle insufficient data scenarios)
    func calculateRollingReturns(
        prices: [PricePoint],
        windowDays: Int
    ) throws -> [RollingWindowReturn] {
        // Validate window days
        guard windowDays > 0 else {
            throw RollingWindowError.invalidWindowDays(value: windowDays)
        }
        
        // Check for empty data
        guard !prices.isEmpty else {
            throw RollingWindowError.emptyPriceData(ticker: ticker)
        }
        
        // Check for sufficient data
        // Need at least windowDays + 1 data points to calculate one return
        // (start price at index 0, end price at index windowDays)
        guard prices.count > windowDays else {
            throw RollingWindowError.insufficientData(
                available: prices.count,
                required: windowDays + 1,
                ticker: ticker
            )
        }
        
        var returns: [RollingWindowReturn] = []
        
        // Calculate rolling returns for each valid window
        // For window starting at index i, we need prices[i] and prices[i + windowDays]
        // So i can range from 0 to (prices.count - windowDays - 1)
        for i in 0..<(prices.count - windowDays) {
            let startPrice = prices[i].close
            let endPrice = prices[i + windowDays].close
            
            // Avoid division by zero (should not happen with valid price data)
            guard startPrice != 0 else {
                continue
            }
            
            // Calculate percentage return: ((end - start) / start) * 100
            let returnPct = ((endPrice - startPrice) / startPrice) * 100
            
            let windowReturn = RollingWindowReturn(
                startDate: prices[i].date,
                endDate: prices[i + windowDays].date,
                returnPct: returnPct
            )
            
            returns.append(windowReturn)
        }
        
        return returns
    }
    
    /// Calculates rolling window returns, returning empty array for insufficient data.
    ///
    /// This is a convenience method for scenarios where you want to skip tickers
    /// with insufficient data rather than handling errors.
    ///
    /// - Parameters:
    ///   - prices: Array of price points sorted by date (oldest first)
    ///   - windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns, or empty array if insufficient data
    /// - Validates: Requirement 5.6 (Skip ticker and display insufficient data message)
    func calculateRollingReturnsOrEmpty(
        prices: [PricePoint],
        windowDays: Int
    ) -> [RollingWindowReturn] {
        do {
            return try calculateRollingReturns(prices: prices, windowDays: windowDays)
        } catch {
            return []
        }
    }
    
    // MARK: - Static Convenience Methods
    
    /// Calculates rolling window returns using a static method.
    ///
    /// This is a convenience method when you don't need to configure the calculator.
    ///
    /// - Parameters:
    ///   - prices: Array of price points sorted by date (oldest first)
    ///   - windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns
    /// - Throws: RollingWindowError if insufficient data or invalid parameters
    /// - Validates: Requirement 5.2 (Rolling window return calculation)
    static func calculateReturns(
        prices: [PricePoint],
        windowDays: Int
    ) throws -> [RollingWindowReturn] {
        let calculator = RollingWindowCalculator()
        return try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
    }
    
    /// Calculates rolling window returns returning empty array for insufficient data.
    ///
    /// - Parameters:
    ///   - prices: Array of price points sorted by date (oldest first)
    ///   - windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns, or empty array if insufficient data
    /// - Validates: Requirement 5.6 (Handle insufficient data)
    static func calculateReturnsOrEmpty(
        prices: [PricePoint],
        windowDays: Int
    ) -> [RollingWindowReturn] {
        let calculator = RollingWindowCalculator()
        return calculator.calculateRollingReturnsOrEmpty(prices: prices, windowDays: windowDays)
    }
    
    // MARK: - Validation Helpers
    
    /// Checks if there is sufficient data for the given window size.
    ///
    /// - Parameters:
    ///   - priceCount: The number of available price points
    ///   - windowDays: The required window size
    /// - Returns: true if there is sufficient data, false otherwise
    /// - Validates: Requirement 5.6 (Check for insufficient data)
    static func hasSufficientData(priceCount: Int, windowDays: Int) -> Bool {
        return priceCount > windowDays && windowDays > 0
    }
    
    /// Returns the minimum number of price points required for a given window size.
    ///
    /// - Parameter windowDays: The window size in days
    /// - Returns: The minimum number of price points needed
    static func minimumPricePointsRequired(for windowDays: Int) -> Int {
        return windowDays + 1
    }
}

// MARK: - Array Extension for Convenience

extension Array where Element == PricePoint {
    
    /// Calculates rolling window returns for this array of price points.
    ///
    /// - Parameter windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns
    /// - Throws: RollingWindowError if insufficient data or invalid parameters
    /// - Validates: Requirement 5.2 (Rolling window return calculation)
    func rollingWindowReturns(windowDays: Int) throws -> [RollingWindowReturn] {
        try RollingWindowCalculator.calculateReturns(prices: self, windowDays: windowDays)
    }
    
    /// Calculates rolling window returns, returning empty array for insufficient data.
    ///
    /// - Parameter windowDays: The number of trading days for each rolling window
    /// - Returns: Array of rolling window returns, or empty array if insufficient data
    /// - Validates: Requirement 5.6 (Handle insufficient data)
    func rollingWindowReturnsOrEmpty(windowDays: Int) -> [RollingWindowReturn] {
        RollingWindowCalculator.calculateReturnsOrEmpty(prices: self, windowDays: windowDays)
    }
}
