//
//  OptionsProtocols.swift
//  TradingGuru
//
//  Protocol definitions for options chain data and premium matching.
//

import Foundation

// MARK: - Options Error Logging Protocol

/// Protocol for logging options chain errors for monitoring.
///
/// This protocol enables logging of options data fetch errors
/// to support graceful degradation monitoring. When options fetch
/// fails, the analysis continues with N/A values and HOLD signals,
/// but errors are logged for troubleshooting and monitoring.
///
/// - Validates: Requirement 1.4 (Error handling for options data)
/// - Validates: Requirement 6.10 (Graceful degradation with logging)
protocol OptionsErrorLogger: Sendable {
    
    /// Logs when options chain fetch fails for a ticker.
    ///
    /// Called when the options data service throws an error during
    /// fetchOptionsChain. The analysis continues with graceful degradation.
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol that failed
    ///   - expirationDate: The expiration date that was requested
    ///   - error: The underlying error that occurred
    func logOptionsChainFetchError(
        ticker: String,
        expirationDate: Date,
        error: Error
    )
    
    /// Logs when no options service is available.
    ///
    /// Called when the strategy is initialized without an options service.
    /// This is informational logging for monitoring purposes.
    ///
    /// - Parameter ticker: The stock ticker symbol being analyzed
    func logNoOptionsServiceAvailable(ticker: String)
    
    /// Logs when options chain is empty (no contracts for expiration).
    ///
    /// Called when the options chain returns successfully but contains
    /// no call or put contracts for the specified expiration date.
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol
    ///   - expirationDate: The expiration date that had no contracts
    func logEmptyOptionsChain(
        ticker: String,
        expirationDate: Date
    )
}

// MARK: - Default Options Error Logger

/// Default implementation of OptionsErrorLogger that prints to console.
///
/// In production, this should be replaced with a proper logging service
/// (e.g., OSLog, Firebase Crashlytics, or custom analytics).
///
/// - Validates: Requirement 1.4, 6.10 (Log errors for monitoring)
final class DefaultOptionsErrorLogger: OptionsErrorLogger, @unchecked Sendable {
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private let expirationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
    
    /// Creates a timestamp string for log entries.
    private func timestamp() -> String {
        dateFormatter.string(from: Date())
    }
    
    func logOptionsChainFetchError(
        ticker: String,
        expirationDate: Date,
        error: Error
    ) {
        let expDateStr = expirationDateFormatter.string(from: expirationDate)
        print("[\(timestamp())] [OptionsChain] ERROR: Failed to fetch options for \(ticker) (exp: \(expDateStr)): \(error.localizedDescription)")
    }
    
    func logNoOptionsServiceAvailable(ticker: String) {
        print("[\(timestamp())] [OptionsChain] INFO: No options service available for \(ticker), proceeding with N/A values")
    }
    
    func logEmptyOptionsChain(
        ticker: String,
        expirationDate: Date
    ) {
        let expDateStr = expirationDateFormatter.string(from: expirationDate)
        print("[\(timestamp())] [OptionsChain] INFO: Empty options chain for \(ticker) (exp: \(expDateStr)), using N/A values")
    }
}

// MARK: - Premium Matching Protocol
// Note: ExpirationDateCalculation protocol is defined in ConfigurationProtocols.swift

/// Protocol for matching options to target premium.
///
/// This protocol defines the algorithm for finding option contracts
/// with premiums closest to a target premium amount. It supports
/// tiebreaker logic for call and put options.
///
/// - Validates: Requirement 4.2 (Find call option with mid-price closest to target premium)
/// - Validates: Requirement 4.3 (Find put option with mid-price closest to target premium)
/// - Validates: Requirement 4.4 (Tiebreaker: lower strike for puts, higher strike for calls)
protocol PremiumMatching {
    
    /// Finds the call option with mid-price closest to target premium.
    ///
    /// When multiple options have the same distance from the target premium,
    /// the option with the **higher** strike price is selected.
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
    ) -> OptionContract?
    
    /// Finds the put option with mid-price closest to target premium.
    ///
    /// When multiple options have the same distance from the target premium,
    /// the option with the **lower** strike price is selected.
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
    ) -> OptionContract?
}
