//
//  ConfigurationValidationService.swift
//  TradingGuru
//
//  Validation service for strategy configuration parameters.
//  Validates values against defined constraints and retains previous values on failure.
//

import Foundation

// MARK: - Configuration Validation Protocol

/// Protocol for validating strategy configuration parameters.
/// Implementations should validate individual parameters and return
/// the validated value or an error with an appropriate message.
/// 
/// - Validates: Requirement 4.11 (Configuration validation with error messages)
protocol ConfigurationValidation {
    
    /// Validates a PREMIUM_PCT value.
    /// - Parameters:
    ///   - newValue: The new value to validate
    ///   - currentValue: The current value to retain on validation failure
    /// - Returns: Result with validated value on success, or ConfigurationError on failure
    /// - Validates: Requirement 4.11 (PREMIUM_PCT validation 0.1% to 5.0%)
    func validatePremiumPct(_ newValue: Double, currentValue: Double) -> Result<Double, ConfigurationError>
    
    /// Validates a WINDOW_DAYS value.
    /// - Parameters:
    ///   - newValue: The new value to validate
    ///   - currentValue: The current value to retain on validation failure
    /// - Returns: Result with validated value on success, or ConfigurationError on failure
    func validateWindowDays(_ newValue: Int, currentValue: Int) -> Result<Int, ConfigurationError>
    
    /// Validates a LOOKBACK_DAYS value.
    /// - Parameters:
    ///   - newValue: The new value to validate
    ///   - currentValue: The current value to retain on validation failure
    /// - Returns: Result with validated value on success, or ConfigurationError on failure
    func validateLookbackDays(_ newValue: Int, currentValue: Int) -> Result<Int, ConfigurationError>
    
    /// Validates an entire WeeklyOptionConfiguration.
    /// - Parameter configuration: The configuration to validate
    /// - Returns: Result indicating success or the first validation error
    func validateConfiguration(_ configuration: WeeklyOptionConfiguration) -> Result<Void, ConfigurationError>
}

// MARK: - Configuration Validation Service

/// Concrete implementation of ConfigurationValidation protocol.
/// 
/// Provides validation logic for strategy configuration parameters with
/// appropriate error messages and value retention on validation failure.
/// 
/// - Validates: Requirement 4.11 (PREMIUM_PCT validation with error message, retain previous value)
final class ConfigurationValidationService: ConfigurationValidation {
    
    // MARK: - Premium Percentage Validation
    
    /// Validates a PREMIUM_PCT value against the allowed range.
    /// 
    /// The valid range is 0.1% to 5.0% (inclusive). Values outside this range
    /// are rejected with an error message indicating the valid range.
    /// 
    /// - Parameters:
    ///   - newValue: The new premium percentage value to validate
    ///   - currentValue: The current value to retain on validation failure
    /// - Returns: Result with validated value (newValue) on success, or ConfigurationError on failure
    /// - Validates: Requirement 4.11 (PREMIUM_PCT validation 0.1% to 5.0%)
    func validatePremiumPct(_ newValue: Double, currentValue: Double) -> Result<Double, ConfigurationError> {
        let range = WeeklyOptionConfiguration.premiumPctRange
        
        guard range.contains(newValue) else {
            return .failure(.valueOutOfRange(
                parameter: "premiumPct",
                message: "Premium must be between \(range.lowerBound)% and \(range.upperBound)%. Please enter a value within this range."
            ))
        }
        
        return .success(newValue)
    }
    
    // MARK: - Window Days Validation
    
    /// Validates a WINDOW_DAYS value against the allowed options.
    /// 
    /// Valid values are: 1, 5, or 30 days.
    /// 
    /// - Parameters:
    ///   - newValue: The new window days value to validate
    ///   - currentValue: The current value to retain on validation failure
    /// - Returns: Result with validated value on success, or ConfigurationError on failure
    func validateWindowDays(_ newValue: Int, currentValue: Int) -> Result<Int, ConfigurationError> {
        guard WeeklyOptionConfiguration.validWindowDays.contains(newValue) else {
            let options = WeeklyOptionConfiguration.validWindowDays.map(String.init).joined(separator: ", ")
            return .failure(.valueOutOfRange(
                parameter: "windowDays",
                message: "Window days must be one of: \(options)."
            ))
        }
        
        return .success(newValue)
    }
    
    // MARK: - Lookback Days Validation
    
    /// Validates a LOOKBACK_DAYS value against the allowed options.
    /// 
    /// Valid values are: 30, 60, 90, 180, or 360 days.
    /// 
    /// - Parameters:
    ///   - newValue: The new lookback days value to validate
    ///   - currentValue: The current value to retain on validation failure
    /// - Returns: Result with validated value on success, or ConfigurationError on failure
    func validateLookbackDays(_ newValue: Int, currentValue: Int) -> Result<Int, ConfigurationError> {
        guard WeeklyOptionConfiguration.validLookbackDays.contains(newValue) else {
            let options = WeeklyOptionConfiguration.validLookbackDays.map(String.init).joined(separator: ", ")
            return .failure(.valueOutOfRange(
                parameter: "lookbackDays",
                message: "Lookback days must be one of: \(options)."
            ))
        }
        
        return .success(newValue)
    }
    
    // MARK: - Full Configuration Validation
    
    /// Validates an entire WeeklyOptionConfiguration.
    /// 
    /// Validates all parameters in the configuration and returns
    /// the first error encountered, if any.
    /// 
    /// - Parameter configuration: The configuration to validate
    /// - Returns: Result indicating success or the first validation error
    func validateConfiguration(_ configuration: WeeklyOptionConfiguration) -> Result<Void, ConfigurationError> {
        // Validate window days
        if case .failure(let error) = validateWindowDays(configuration.windowDays, currentValue: configuration.windowDays) {
            return .failure(error)
        }
        
        // Validate lookback days
        if case .failure(let error) = validateLookbackDays(configuration.lookbackDays, currentValue: configuration.lookbackDays) {
            return .failure(error)
        }
        
        // Validate premium percentage
        if case .failure(let error) = validatePremiumPct(configuration.premiumPct, currentValue: configuration.premiumPct) {
            return .failure(error)
        }
        
        return .success(())
    }
    
    // MARK: - Convenience Methods
    
    /// Attempts to update a configuration's premium percentage with validation.
    /// 
    /// If validation fails, the configuration is not modified and the error is returned.
    /// If validation succeeds, the configuration is updated with the new value.
    /// 
    /// - Parameters:
    ///   - newValue: The new premium percentage value
    ///   - configuration: The configuration to update (passed inout)
    /// - Returns: Result indicating success or the validation error
    /// - Validates: Requirement 4.11 (Don't save invalid value, retain previous)
    func updatePremiumPct(_ newValue: Double, in configuration: inout WeeklyOptionConfiguration) -> Result<Void, ConfigurationError> {
        let validationResult = validatePremiumPct(newValue, currentValue: configuration.premiumPct)
        
        switch validationResult {
        case .success(let validatedValue):
            configuration.premiumPct = validatedValue
            return .success(())
        case .failure(let error):
            // Configuration retains previous value - no modification
            return .failure(error)
        }
    }
    
    /// Attempts to update a configuration's window days with validation.
    /// 
    /// - Parameters:
    ///   - newValue: The new window days value
    ///   - configuration: The configuration to update (passed inout)
    /// - Returns: Result indicating success or the validation error
    func updateWindowDays(_ newValue: Int, in configuration: inout WeeklyOptionConfiguration) -> Result<Void, ConfigurationError> {
        let validationResult = validateWindowDays(newValue, currentValue: configuration.windowDays)
        
        switch validationResult {
        case .success(let validatedValue):
            configuration.windowDays = validatedValue
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Attempts to update a configuration's lookback days with validation.
    /// 
    /// - Parameters:
    ///   - newValue: The new lookback days value
    ///   - configuration: The configuration to update (passed inout)
    /// - Returns: Result indicating success or the validation error
    func updateLookbackDays(_ newValue: Int, in configuration: inout WeeklyOptionConfiguration) -> Result<Void, ConfigurationError> {
        let validationResult = validateLookbackDays(newValue, currentValue: configuration.lookbackDays)
        
        switch validationResult {
        case .success(let validatedValue):
            configuration.lookbackDays = validatedValue
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - Validation Result Extensions

extension ConfigurationValidationService {
    
    /// Returns the error message for a configuration validation error.
    /// 
    /// This is useful for displaying user-facing error messages in the UI.
    /// 
    /// - Parameter error: The configuration error
    /// - Returns: A user-friendly error message string
    static func errorMessage(for error: ConfigurationError) -> String {
        switch error {
        case .valueOutOfRange(_, let message):
            return message
        case .missingParameter(let parameter):
            return "Missing required parameter: \(parameter)"
        case .invalidType(let parameter):
            return "Invalid value type for \(parameter)"
        }
    }
}
