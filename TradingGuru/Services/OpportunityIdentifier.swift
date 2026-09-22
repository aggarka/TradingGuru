//
//  OpportunityIdentifier.swift
//  TradingGuru
//
//  Service for identifying CALL and PUT opportunities from rolling window returns.
//  Implements the opportunity identification algorithm for the Weekly Option Strategy.
//

import Foundation

// MARK: - Opportunity Result

/// Represents an identified trading opportunity (CALL or PUT).
/// Contains the opportunity type, return percentage, and target price.
/// - Validates: Requirements 5.3, 5.4 (CALL/PUT identification and target price calculation)
struct OpportunityResult: Equatable {
    /// The type of opportunity (CALL or PUT)
    let type: OpportunityType
    
    /// The return percentage from the identified window
    let returnPercentage: Double
    
    /// The target price calculated from current price and return
    /// Formula: targetPrice = currentPrice × (1 + returnPercentage / 100), rounded to 2 decimals
    let targetPrice: Double
    
    /// The start date of the identified window
    let windowStartDate: Date
    
    /// The end date of the identified window
    let windowEndDate: Date
}

// MARK: - Opportunity Identification Error

/// Errors that can occur during opportunity identification.
enum OpportunityIdentificationError: Error, Equatable {
    /// No rolling window returns provided
    case emptyReturns
    
    /// Invalid current price (must be positive)
    case invalidCurrentPrice(value: Double)
}

extension OpportunityIdentificationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyReturns:
            return "Cannot identify opportunities from empty returns array."
        case .invalidCurrentPrice(let value):
            return "Invalid current price: \(value). Price must be positive."
        }
    }
}

// MARK: - Opportunity Identifier Protocol

/// Protocol for opportunity identification from rolling window returns.
/// Enables different implementations and testability through dependency injection.
protocol OpportunityIdentification {
    
    /// Identifies CALL and PUT opportunities from rolling window returns.
    ///
    /// - CALL opportunity: The window with the maximum (best) return percentage
    /// - PUT opportunity: The window with the minimum (worst) return percentage
    /// - Target price formula: currentPrice × (1 + returnPercentage / 100), rounded to 2 decimals
    ///
    /// - Parameters:
    ///   - returns: Array of rolling window returns from the RollingWindowCalculator
    ///   - currentPrice: The current price of the stock
    /// - Returns: Tuple containing the CALL opportunity and PUT opportunity
    /// - Throws: OpportunityIdentificationError if returns is empty or currentPrice is invalid
    /// - Validates: Requirements 5.3 (CALL/PUT identification), 5.4 (Target price calculation)
    func identifyOpportunities(
        returns: [RollingWindowReturn],
        currentPrice: Double
    ) throws -> (call: OpportunityResult, put: OpportunityResult)
}

// MARK: - Opportunity Identifier

/// Concrete implementation of opportunity identification.
///
/// This calculator processes rolling window returns to identify the best (CALL)
/// and worst (PUT) return windows, computing target prices for each.
///
/// Usage:
/// ```swift
/// let identifier = OpportunityIdentifier()
/// let returns = [...] // from RollingWindowCalculator
/// let currentPrice = 150.0
/// let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
/// ```
///
/// - Validates: Requirement 5.3 (Identify best/worst return windows)
/// - Validates: Requirement 5.4 (Compute target price with formula)
final class OpportunityIdentifier: OpportunityIdentification {
    
    // MARK: - Opportunity Identification
    
    /// Identifies CALL and PUT opportunities from rolling window returns.
    ///
    /// The algorithm:
    /// 1. Find the window with maximum return percentage → CALL opportunity
    /// 2. Find the window with minimum return percentage → PUT opportunity
    /// 3. Calculate target prices: currentPrice × (1 + return / 100), rounded to 2 decimals
    ///
    /// - Parameters:
    ///   - returns: Array of rolling window returns (must not be empty)
    ///   - currentPrice: The current stock price (must be positive)
    /// - Returns: Tuple containing the identified CALL and PUT opportunities
    /// - Throws: OpportunityIdentificationError.emptyReturns if returns array is empty
    /// - Throws: OpportunityIdentificationError.invalidCurrentPrice if currentPrice <= 0
    /// - Validates: Requirements 5.3 (CALL/PUT identification), 5.4 (Target price calculation)
    func identifyOpportunities(
        returns: [RollingWindowReturn],
        currentPrice: Double
    ) throws -> (call: OpportunityResult, put: OpportunityResult) {
        // Validate inputs
        guard !returns.isEmpty else {
            throw OpportunityIdentificationError.emptyReturns
        }
        
        guard currentPrice > 0 else {
            throw OpportunityIdentificationError.invalidCurrentPrice(value: currentPrice)
        }
        
        // Find best return (maximum) for CALL opportunity
        // Using force unwrap is safe here because we've validated returns is not empty
        let bestReturn = returns.max(by: { $0.returnPct < $1.returnPct })!
        
        // Find worst return (minimum) for PUT opportunity
        let worstReturn = returns.min(by: { $0.returnPct < $1.returnPct })!
        
        // Calculate target prices using the formula:
        // targetPrice = currentPrice × (1 + returnPercentage / 100), rounded to 2 decimals
        let callTargetPrice = Self.calculateTargetPrice(currentPrice: currentPrice, returnPct: bestReturn.returnPct)
        let putTargetPrice = Self.calculateTargetPrice(currentPrice: currentPrice, returnPct: worstReturn.returnPct)
        
        // Create opportunity results
        let callOpportunity = OpportunityResult(
            type: .call,
            returnPercentage: bestReturn.returnPct,
            targetPrice: callTargetPrice,
            windowStartDate: bestReturn.startDate,
            windowEndDate: bestReturn.endDate
        )
        
        let putOpportunity = OpportunityResult(
            type: .put,
            returnPercentage: worstReturn.returnPct,
            targetPrice: putTargetPrice,
            windowStartDate: worstReturn.startDate,
            windowEndDate: worstReturn.endDate
        )
        
        return (call: callOpportunity, put: putOpportunity)
    }
    
    // MARK: - Target Price Calculation
    
    /// Calculates the target price from current price and return percentage.
    ///
    /// Formula: targetPrice = currentPrice × (1 + returnPercentage / 100)
    /// The result is rounded to 2 decimal places.
    ///
    /// - Parameters:
    ///   - currentPrice: The current stock price
    ///   - returnPct: The return percentage
    /// - Returns: The target price rounded to 2 decimal places
    /// - Validates: Requirement 5.4 (Target price calculation formula)
    static func calculateTargetPrice(currentPrice: Double, returnPct: Double) -> Double {
        let rawTargetPrice = currentPrice * (1 + returnPct / 100)
        return roundToTwoDecimals(rawTargetPrice)
    }
    
    /// Rounds a value to 2 decimal places.
    ///
    /// Uses standard rounding (round half up).
    ///
    /// - Parameter value: The value to round
    /// - Returns: The value rounded to 2 decimal places
    private static func roundToTwoDecimals(_ value: Double) -> Double {
        return (value * 100).rounded() / 100
    }
    
    // MARK: - Static Convenience Methods
    
    /// Identifies opportunities using a static method.
    ///
    /// This is a convenience method when you don't need to configure the identifier.
    ///
    /// - Parameters:
    ///   - returns: Array of rolling window returns
    ///   - currentPrice: The current stock price
    /// - Returns: Tuple containing CALL and PUT opportunities
    /// - Throws: OpportunityIdentificationError if inputs are invalid
    /// - Validates: Requirements 5.3, 5.4
    static func identify(
        returns: [RollingWindowReturn],
        currentPrice: Double
    ) throws -> (call: OpportunityResult, put: OpportunityResult) {
        let identifier = OpportunityIdentifier()
        return try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
    }
    
    /// Identifies only the CALL opportunity (best return).
    ///
    /// - Parameters:
    ///   - returns: Array of rolling window returns
    ///   - currentPrice: The current stock price
    /// - Returns: The CALL opportunity
    /// - Throws: OpportunityIdentificationError if inputs are invalid
    /// - Validates: Requirement 5.3 (Best return = CALL)
    static func identifyCallOpportunity(
        returns: [RollingWindowReturn],
        currentPrice: Double
    ) throws -> OpportunityResult {
        let (call, _) = try identify(returns: returns, currentPrice: currentPrice)
        return call
    }
    
    /// Identifies only the PUT opportunity (worst return).
    ///
    /// - Parameters:
    ///   - returns: Array of rolling window returns
    ///   - currentPrice: The current stock price
    /// - Returns: The PUT opportunity
    /// - Throws: OpportunityIdentificationError if inputs are invalid
    /// - Validates: Requirement 5.3 (Worst return = PUT)
    static func identifyPutOpportunity(
        returns: [RollingWindowReturn],
        currentPrice: Double
    ) throws -> OpportunityResult {
        let (_, put) = try identify(returns: returns, currentPrice: currentPrice)
        return put
    }
}

// MARK: - Array Extension for Convenience

extension Array where Element == RollingWindowReturn {
    
    /// Identifies CALL and PUT opportunities from this array of returns.
    ///
    /// - Parameter currentPrice: The current stock price
    /// - Returns: Tuple containing CALL and PUT opportunities
    /// - Throws: OpportunityIdentificationError if inputs are invalid
    /// - Validates: Requirements 5.3, 5.4
    func identifyOpportunities(
        currentPrice: Double
    ) throws -> (call: OpportunityResult, put: OpportunityResult) {
        try OpportunityIdentifier.identify(returns: self, currentPrice: currentPrice)
    }
}
