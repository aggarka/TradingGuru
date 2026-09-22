//
//  ErrorMessageCatalog.swift
//  TradingGuru
//
//  Centralized error message catalog for user-friendly error display.
//  All error messages follow the design document specification.
//
//  - Validates: Requirement 1.6 (Authentication error categories)
//  - Validates: Requirement 2.9 (Watchlist database unavailability)
//  - Validates: Requirement 4.9 (Configuration save failure)
//  - Validates: Requirement 5.5 (Data retrieval failure per ticker)
//  - Validates: Requirement 7.6 (Database operation failure with retry)
//

import Foundation

// MARK: - Error Message Catalog

/// Centralized catalog of user-friendly error messages.
/// All messages are defined per the design document's Error Handling section.
enum ErrorMessageCatalog {
    
    // MARK: - Authentication Errors
    
    /// Error messages for authentication operations.
    /// - Validates: Requirement 1.6 (Display error indicating failure category)
    enum Authentication {
        /// Invalid credentials error message.
        static let invalidCredentials = "Sign-in failed. Please check your credentials and try again."
        
        /// Network error message.
        static let networkError = "Unable to connect. Please check your internet connection."
        
        /// Provider unavailable error message.
        /// - Parameter provider: The authentication provider name (e.g., "Google", "Apple")
        static func providerUnavailable(_ provider: String) -> String {
            return "\(provider) sign-in is temporarily unavailable. Please try another method."
        }
        
        /// Timeout error message (60 seconds).
        /// - Validates: Requirement 1.7
        static let timeout = "Sign-in timed out. Please try again."
        
        /// Profile operation failed error message.
        /// - Validates: Requirement 1.8
        static let profileOperationFailed = "Unable to load your profile. Please try again."
        
        /// Session expired error message.
        static let sessionExpired = "Your session has expired. Please sign in again."
    }
    
    // MARK: - Watchlist Errors
    
    /// Error messages for watchlist operations.
    /// - Validates: Requirements 2.3, 2.4, 2.5, 2.9
    enum Watchlist {
        /// Invalid format error message.
        /// - Validates: Requirement 2.3
        static let invalidFormat = "Invalid symbol. Please enter 1-5 uppercase letters."
        
        /// Duplicate symbol error message.
        /// - Parameter symbol: The duplicated ticker symbol
        /// - Validates: Requirement 2.4
        static func duplicateSymbol(_ symbol: String) -> String {
            return "\(symbol) is already in your watchlist."
        }
        
        /// Limit reached error message.
        /// - Validates: Requirement 2.5
        static let limitReached = "Watchlist limit reached (50 symbols). Remove a symbol to add more."
        
        /// Database unavailable error message.
        /// - Validates: Requirement 2.9
        static let databaseUnavailable = "Unable to save changes. Please try again."
    }
    
    // MARK: - Strategy Configuration Errors
    
    /// Error messages for strategy configuration operations.
    /// - Validates: Requirements 4.9, 4.10, 4.11
    enum StrategyConfiguration {
        /// Invalid premium range error message.
        /// - Validates: Requirement 4.11
        static let invalidPremiumRange = "Premium must be between 0.1% and 5.0%."
        
        /// Save failed error message.
        /// - Validates: Requirement 4.9
        static let saveFailed = "Unable to save configuration. Please try again."
        
        /// Load failed error message.
        /// - Validates: Requirement 4.10
        static let loadFailed = "Unable to load saved settings. Using defaults."
    }
    
    // MARK: - Analysis Execution Errors
    
    /// Error messages for analysis execution operations.
    /// - Validates: Requirements 5.5, 5.6
    enum AnalysisExecution {
        /// Data fetch failed error message for a specific ticker.
        /// - Parameter ticker: The ticker symbol that failed
        /// - Validates: Requirement 5.5
        static func dataFetchFailed(_ ticker: String) -> String {
            return "\(ticker): Unable to fetch data"
        }
        
        /// Insufficient data error message for a specific ticker.
        /// - Parameter ticker: The ticker symbol with insufficient data
        /// - Validates: Requirement 5.6
        static func insufficientData(_ ticker: String) -> String {
            return "\(ticker): Insufficient price history"
        }
        
        /// All tickers failed error message.
        static let allTickersFailed = "Unable to retrieve data for any symbols. Please try again later."
    }
    
    // MARK: - Database Operation Errors
    
    /// Error messages for general database operations.
    /// - Validates: Requirements 7.6, 7.7
    enum Database {
        /// Retries exhausted error message.
        /// - Validates: Requirement 7.7
        static let retriesExhausted = "Operation could not be completed. Please check your connection and try again."
        
        /// Operation failed with retry available.
        /// - Parameter operationName: Name of the operation that failed
        /// - Validates: Requirement 7.6
        static func operationFailed(_ operationName: String) -> String {
            return "\(operationName) failed. Tap to retry."
        }
        
        /// Retrying status message.
        /// - Parameters:
        ///   - attemptNumber: Current attempt number
        ///   - maxAttempts: Maximum number of attempts
        static func retrying(attemptNumber: Int, maxAttempts: Int) -> String {
            return "Retrying... (Attempt \(attemptNumber) of \(maxAttempts))"
        }
    }
    
    // MARK: - Email Notification Errors
    
    /// Error messages for email notification operations.
    enum EmailNotification {
        /// Invalid email format error message.
        /// - Validates: Requirement 9.2
        static let invalidFormat = "Please enter a valid email address."
        
        /// Email delivery failed error message.
        static let deliveryFailed = "Unable to send email notification. Will retry automatically."
    }
    
    // MARK: - Settings Errors
    
    /// Error messages for settings operations.
    enum Settings {
        /// Load failed error message.
        static let loadFailed = "Unable to load settings. Using defaults."
        
        /// Save failed error message.
        static let saveFailed = "Unable to save settings. Please try again."
    }
}
