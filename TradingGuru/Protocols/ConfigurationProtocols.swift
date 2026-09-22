//
//  ConfigurationProtocols.swift
//  TradingGuru
//
//  Protocol definitions for strategy configuration repository and related services.
//

import Foundation

// MARK: - Configuration Repository Protocol

/// Protocol for strategy configuration data persistence operations.
///
/// The repository handles save and load operations for user strategy configurations,
/// abstracting the underlying data source (Firestore, local cache, etc.).
///
/// - Validates: Requirements 4.6, 4.7, 4.8, 4.9, 4.10 (Configuration persistence)
protocol ConfigurationRepository {
    /// Saves a strategy configuration for a specific user.
    /// - Parameters:
    ///   - configuration: The configuration to save
    ///   - userId: The unique identifier of the user
    /// - Returns: A ConfigurationSaveResult indicating success or failure with feedback
    /// - Throws: ConfigurationRepositoryError if the operation fails
    /// - Validates: Requirement 4.6 (Persist configuration to database with confirmation)
    /// - Validates: Requirement 4.9 (Retain user's values on save failure)
    func save(configuration: StrategyConfiguration, for userId: String) async throws -> ConfigurationSaveResult
    
    /// Loads a strategy configuration for a specific user.
    /// - Parameters:
    ///   - strategyId: The identifier of the strategy to load configuration for
    ///   - userId: The unique identifier of the user
    /// - Returns: The loaded configuration or default values if none exists
    /// - Throws: ConfigurationRepositoryError if retrieval fails
    /// - Validates: Requirement 4.7 (Load previously saved configuration)
    /// - Validates: Requirement 4.8 (Apply defaults if no saved config)
    /// - Validates: Requirement 4.10 (Apply defaults on load failure)
    func load(strategyId: String, for userId: String) async throws -> StrategyConfiguration
    
    /// Deletes a strategy configuration for a specific user.
    /// - Parameters:
    ///   - strategyId: The identifier of the strategy to delete configuration for
    ///   - userId: The unique identifier of the user
    /// - Throws: ConfigurationRepositoryError if deletion fails
    func delete(strategyId: String, for userId: String) async throws
}

// MARK: - Configuration Save Result

/// Result of a configuration save operation.
/// - Validates: Requirement 4.6 (Display confirmation on successful save)
struct ConfigurationSaveResult {
    /// Whether the save operation was successful
    let success: Bool
    
    /// Timestamp when the configuration was saved
    let savedAt: Date?
    
    /// Message describing the result (for UI display)
    let message: String
    
    /// Creates a successful save result.
    static func success(savedAt: Date = Date()) -> ConfigurationSaveResult {
        ConfigurationSaveResult(
            success: true,
            savedAt: savedAt,
            message: "Configuration saved successfully."
        )
    }
    
    /// Creates a failed save result.
    /// - Parameter error: The error that caused the failure
    static func failure(error: ConfigurationRepositoryError) -> ConfigurationSaveResult {
        ConfigurationSaveResult(
            success: false,
            savedAt: nil,
            message: error.errorDescription ?? "Failed to save configuration."
        )
    }
}

// MARK: - Configuration Repository Error

/// Errors that can occur during configuration repository operations.
/// - Validates: Requirements 4.9, 4.10 (Configuration error handling)
enum ConfigurationRepositoryError: Error, Equatable {
    /// The database is unavailable for save operations.
    /// - Validates: Requirement 4.9 (Display error if save fails)
    case saveFailed(reason: String)
    
    /// The database is unavailable for load operations.
    /// - Validates: Requirement 4.10 (Display error if load fails)
    case loadFailed(reason: String)
    
    /// The database is unavailable for any operation.
    case databaseUnavailable
    
    /// The configuration data is corrupted or invalid.
    case invalidData
    
    /// The operation timed out.
    case timeout
    
    /// A general network error occurred.
    case networkError(underlying: String)
}

// MARK: - Error Descriptions

extension ConfigurationRepositoryError: LocalizedError {
    /// Detailed error description for logging.
    var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Unable to save configuration: \(reason)"
        case .loadFailed(let reason):
            return "Unable to load saved settings: \(reason)"
        case .databaseUnavailable:
            return "Database is currently unavailable. Please try again."
        case .invalidData:
            return "Configuration data is invalid."
        case .timeout:
            return "Operation timed out. Please check your connection."
        case .networkError(let underlying):
            return "Network error: \(underlying)"
        }
    }
    
    /// User-friendly error message for display.
    /// Uses ErrorMessageCatalog for consistent messaging.
    /// - Validates: Requirements 4.9, 4.10 (Display appropriate error messages)
    var userMessage: String {
        return catalogMessage
    }
    
    /// User-friendly error message from the error catalog.
    /// - Validates: Requirements 4.9, 4.10
    var catalogMessage: String {
        switch self {
        case .saveFailed:
            return ErrorMessageCatalog.StrategyConfiguration.saveFailed
        case .loadFailed:
            return ErrorMessageCatalog.StrategyConfiguration.loadFailed
        case .databaseUnavailable, .networkError, .timeout:
            return ErrorMessageCatalog.Database.retriesExhausted
        case .invalidData:
            return ErrorMessageCatalog.StrategyConfiguration.loadFailed
        }
    }
}

// MARK: - Configuration Data Load State

/// Represents the state of a configuration data load operation from repository.
/// This is different from ConfigurationLoadState in StrategyProtocols which handles UI schema loading.
enum ConfigurationDataLoadState: Equatable {
    /// Initial state, not yet loaded
    case idle
    
    /// Currently loading configuration
    case loading
    
    /// Successfully loaded configuration
    case loaded(StrategyConfiguration)
    
    /// Load failed, using defaults
    /// - Validates: Requirement 4.10 (Apply defaults on load failure)
    case failedWithDefaults(StrategyConfiguration, error: String)
    
    /// Whether the state has a usable configuration
    var hasConfiguration: Bool {
        switch self {
        case .loaded, .failedWithDefaults:
            return true
        case .idle, .loading:
            return false
        }
    }
    
    /// Gets the configuration if available
    var configuration: StrategyConfiguration? {
        switch self {
        case .loaded(let config):
            return config
        case .failedWithDefaults(let config, _):
            return config
        case .idle, .loading:
            return nil
        }
    }
    
    /// Whether the load encountered an error
    var hasError: Bool {
        if case .failedWithDefaults = self {
            return true
        }
        return false
    }
    
    /// The error message if load failed
    var errorMessage: String? {
        if case .failedWithDefaults(_, let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Configuration Save State

/// Represents the state of a configuration save operation.
/// - Validates: Requirement 4.6 (Display confirmation on save)
/// - Validates: Requirement 4.9 (Display error on save failure)
enum ConfigurationSaveState: Equatable {
    /// Initial state, no save in progress
    case idle
    
    /// Currently saving configuration
    case saving
    
    /// Successfully saved
    case saved(at: Date)
    
    /// Save failed
    /// - Validates: Requirement 4.9 (Retain user's values on failure)
    case failed(error: String)
    
    /// Whether a save operation is in progress
    var isSaving: Bool {
        if case .saving = self {
            return true
        }
        return false
    }
    
    /// Whether the last save was successful
    var isSuccess: Bool {
        if case .saved = self {
            return true
        }
        return false
    }
    
    /// Whether the last save failed
    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    /// The error message if save failed
    var errorMessage: String? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    /// User-friendly status message for display
    var statusMessage: String? {
        switch self {
        case .idle:
            return nil
        case .saving:
            return "Saving..."
        case .saved(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Saved at \(formatter.string(from: date))"
        case .failed(let error):
            return error
        }
    }
}

// MARK: - Configuration Constants

/// Constants related to configuration functionality.
enum ConfigurationConstants {
    /// Maximum time to wait for database operations (5 seconds per Requirement 7.2)
    static let operationTimeoutSeconds: TimeInterval = 5.0
    
    /// Collection name for configurations in Firestore
    static let configurationsCollection = "configurations"
}

// MARK: - Expiration Date Calculation Protocol

/// Protocol for calculating options expiration dates with US market holiday awareness.
///
/// This protocol defines the contract for components that determine valid weekly
/// options expiration dates. Implementations must handle:
/// - Calculating the next Friday as the default expiration date
/// - Detecting US market holidays that affect Friday expirations
/// - Falling back to Thursday when Friday is a market holiday
/// - Validating user-selected dates as valid trading days
///
/// - Validates: Requirement 2.1 (Default expiration as next Friday)
/// - Validates: Requirement 2.2 (Holiday fallback to Thursday)
/// - Validates: Requirement 2.6 (Skip to following week from weekend)
/// - Validates: Requirement 3.6 (Valid trading day validation)
protocol ExpirationDateCalculation {
    /// Calculates the default weekly expiration date from a reference date.
    ///
    /// The default expiration is typically the next Friday from the reference date.
    /// If Friday is a US market holiday, returns the immediately preceding Thursday.
    /// If the reference date is Saturday or Sunday, skips to the following week's Friday.
    ///
    /// - Parameter referenceDate: The date to calculate from (typically today)
    /// - Returns: The next valid expiration date (Friday, or Thursday if Friday is a holiday)
    /// - Validates: Requirement 2.1 (Default expiration as next Friday)
    /// - Validates: Requirement 2.2 (Holiday fallback to Thursday)
    /// - Validates: Requirement 2.6 (Skip to following week from weekend)
    func calculateDefaultExpiration(from referenceDate: Date) -> Date
    
    /// Validates whether a date is a valid options expiration date.
    ///
    /// A valid expiration date must be:
    /// - A weekday (Monday through Friday)
    /// - Not a US market holiday
    /// - On a day when the exchange is open for trading
    ///
    /// - Parameter date: The date to validate
    /// - Returns: `true` if the date is a valid trading day for options expiration, `false` otherwise
    /// - Validates: Requirement 3.6 (Valid trading day validation)
    func isValidExpirationDate(_ date: Date) -> Bool
    
    /// Checks whether a date is a US market holiday.
    ///
    /// Market holidays include:
    /// - New Year's Day (January 1, or December 31 if January 1 is Saturday)
    /// - Good Friday (varies by year)
    /// - Independence Day (July 4, or July 3 if July 4 is Saturday)
    /// - Thanksgiving Day (fourth Thursday of November)
    /// - Christmas Day (December 25, or December 24 if December 25 is Saturday)
    ///
    /// - Parameter date: The date to check
    /// - Returns: `true` if the date is a US market holiday, `false` otherwise
    /// - Validates: Requirement 2.3 (Recognized market holidays on Fridays)
    /// - Validates: Requirement 2.4 (July 4 and Christmas on Saturday handling)
    /// - Validates: Requirement 2.5 (New Year's Day on Saturday handling)
    func isMarketHoliday(_ date: Date) -> Bool
}
