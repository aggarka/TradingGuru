//
//  PremiumMatchingAlgorithm.swift
//  TradingGuru
//
//  Algorithm for finding options closest to target premium.
//

import Foundation

// MARK: - Premium Matching Algorithm

/// Finds options closest to target premium.
/// - Validates: Requirement 4 (Target premium matching)
final class PremiumMatchingAlgorithm: PremiumMatching {
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - PremiumMatching Protocol
    
    /// Finds the call option with mid-price closest to target premium.
    ///
    /// When multiple options have the same distance from the target premium,
    /// the option with the **higher** strike price is selected.
    /// Options with bid = 0 are excluded (no market).
    ///
    /// - Parameters:
    ///   - options: Array of call options to search
    ///   - targetPremium: The target premium amount in dollars
    /// - Returns: The best matching call option, or nil if no options available
    /// - Validates: Requirement 4.2 (Best call match by mid-price distance)
    /// - Validates: Requirement 4.4 (Tiebreaker: higher strike price for calls)
    func findBestCallMatch(
        from options: [OptionContract],
        targetPremium: Double
    ) -> OptionContract? {
        // Filter out options with bid = 0 (no market) - matching Python logic
        let validOptions = options.filter { $0.bid > 0 }
        guard !validOptions.isEmpty else { return nil }
        
        // Sort by distance from target, then by strike (higher for calls on tie)
        let sorted = validOptions.sorted { lhs, rhs in
            let lhsDistance = abs(lhs.midPrice - targetPremium)
            let rhsDistance = abs(rhs.midPrice - targetPremium)
            
            // If distances are different (beyond floating-point tolerance), sort by distance
            if abs(lhsDistance - rhsDistance) > 0.0001 {
                return lhsDistance < rhsDistance
            }
            // Tiebreaker: higher strike for calls
            return lhs.strikePrice > rhs.strikePrice
        }
        
        return sorted.first
    }
    
    /// Finds the put option with mid-price closest to target premium.
    ///
    /// When multiple options have the same distance from the target premium,
    /// the option with the **lower** strike price is selected.
    /// Options with bid = 0 are excluded (no market).
    ///
    /// - Parameters:
    ///   - options: Array of put options to search
    ///   - targetPremium: The target premium amount in dollars
    /// - Returns: The best matching put option, or nil if no options available
    /// - Validates: Requirement 4.3 (Best put match by mid-price distance)
    /// - Validates: Requirement 4.4 (Tiebreaker: lower strike price for puts)
    func findBestPutMatch(
        from options: [OptionContract],
        targetPremium: Double
    ) -> OptionContract? {
        // Filter out options with bid = 0 (no market) - matching Python logic
        let validOptions = options.filter { $0.bid > 0 }
        guard !validOptions.isEmpty else { return nil }
        
        // Sort by distance from target, then by strike (lower for puts on tie)
        let sorted = validOptions.sorted { lhs, rhs in
            let lhsDistance = abs(lhs.midPrice - targetPremium)
            let rhsDistance = abs(rhs.midPrice - targetPremium)
            
            // If distances are different (beyond floating-point tolerance), sort by distance
            if abs(lhsDistance - rhsDistance) > 0.0001 {
                return lhsDistance < rhsDistance
            }
            // Tiebreaker: lower strike for puts
            return lhs.strikePrice < rhs.strikePrice
        }
        
        return sorted.first
    }
}
