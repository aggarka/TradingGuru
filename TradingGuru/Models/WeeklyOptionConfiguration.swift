//
//  WeeklyOptionConfiguration.swift
//  TradingGuru
//
//  Configuration model specific to the Weekly Option Strategy.
//

import Foundation

/// Filter for option type display in results.
/// Controls whether to show CALL options, PUT options, or both.
enum OptionTypeFilter: String, Codable, CaseIterable {
    /// Show only CALL options
    case call = "CALL"
    
    /// Show only PUT options
    case put = "PUT"
    
    /// Show both CALL and PUT options
    case both = "BOTH"
    
    /// Display label for the filter option
    var displayLabel: String {
        switch self {
        case .call: return "Call Only"
        case .put: return "Put Only"
        case .both: return "Both"
        }
    }
    
    /// Converts to OpportunityType for filtering (nil means show all)
    var opportunityType: OpportunityType? {
        switch self {
        case .call: return .call
        case .put: return .put
        case .both: return nil
        }
    }
}

/// Configuration parameters for the Weekly Option Strategy.
/// Includes validation logic and default values as specified in requirements.
/// - Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.8 (Strategy configuration)
/// - Validates: Requirement 3 (User expiration date override)
struct WeeklyOptionConfiguration: Codable, Equatable {
    
    // MARK: - Properties
    
    /// Number of days for the rolling return window calculation.
    /// Valid values: 1, 5, or 30
    var windowDays: Int
    
    /// Number of historical days to analyze.
    /// Valid values: 30, 60, 90, 180, or 360
    var lookbackDays: Int
    
    /// Target option premium as a percentage of current stock price.
    /// Valid range: 0.1 to 5.0 (step 0.1)
    var premiumPct: Double
    
    /// Filter to show only ORDER signals when true.
    /// When false, shows all results (both ORDER and HOLD)
    var onlyOrders: Bool
    
    /// Filter for option type display (CALL, PUT, or Both).
    /// Controls which option types are shown in the results.
    var optionTypeFilter: OptionTypeFilter
    
    /// User-selected expiration date override (session-scoped, not persisted).
    ///
    /// When set, this date will be used instead of the calculated default expiration date.
    /// This value is intentionally excluded from Codable encoding/decoding to ensure
    /// it resets to `nil` when the app is terminated and relaunched.
    ///
    /// - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
    /// - Validates: Requirement 3.4 (Reset on app restart)
    var expirationOverride: Date?
    
    // MARK: - CodingKeys
    
    /// Custom coding keys to exclude expirationOverride from persistence.
    ///
    /// The expirationOverride property is session-scoped and should not be saved
    /// to persistent storage. By excluding it from CodingKeys, the property
    /// will always be `nil` when decoding from stored data.
    ///
    /// - Validates: Requirement 3.4 (Reset on app restart)
    enum CodingKeys: String, CodingKey {
        case windowDays
        case lookbackDays
        case premiumPct
        case onlyOrders
        case optionTypeFilter
    }
    
    // MARK: - Static Constants
    
    /// Valid options for WINDOW_DAYS parameter
    static let validWindowDays = [1, 5, 30]
    
    /// Valid options for LOOKBACK_DAYS parameter
    static let validLookbackDays = [30, 60, 90, 180, 360]
    
    /// Valid range for PREMIUM_PCT parameter
    static let premiumPctRange = 0.1...5.0
    
    /// Step increment for PREMIUM_PCT parameter
    static let premiumPctStep = 0.1
    
    /// Default configuration values
    static let `default` = WeeklyOptionConfiguration(
        windowDays: 5,
        lookbackDays: 180,
        premiumPct: 0.5,
        onlyOrders: false,
        optionTypeFilter: .both,
        expirationOverride: nil
    )
    
    /// Strategy identifier for the Weekly Option Strategy
    static let strategyId = "weekly_option"
    
    // MARK: - Initialization
    
    /// Creates a new WeeklyOptionConfiguration with the specified parameters.
    /// - Parameters:
    ///   - windowDays: Rolling window days (1, 5, or 30)
    ///   - lookbackDays: Historical lookback days (30, 60, 90, 180, or 360)
    ///   - premiumPct: Target premium percentage (0.1 to 5.0)
    ///   - onlyOrders: Whether to filter to only ORDER signals
    ///   - optionTypeFilter: Filter for option type display (CALL, PUT, or Both)
    ///   - expirationOverride: Optional user-selected expiration date (session-scoped)
    init(
        windowDays: Int = 5,
        lookbackDays: Int = 180,
        premiumPct: Double = 0.5,
        onlyOrders: Bool = false,
        optionTypeFilter: OptionTypeFilter = .both,
        expirationOverride: Date? = nil
    ) {
        self.windowDays = windowDays
        self.lookbackDays = lookbackDays
        self.premiumPct = premiumPct
        self.onlyOrders = onlyOrders
        self.optionTypeFilter = optionTypeFilter
        self.expirationOverride = expirationOverride
    }
    
    // MARK: - Expiration Date
    
    /// Returns the effective expiration date to use for options analysis.
    ///
    /// If the user has set a custom expiration date override, that date is returned.
    /// Otherwise, the calculator is used to determine the default expiration date
    /// (typically the next Friday, or Thursday if Friday is a market holiday).
    ///
    /// - Parameter calculator: The expiration date calculator to use for default calculation
    /// - Returns: The user's override date if set, otherwise the calculated default expiration
    /// - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
    func effectiveExpirationDate(using calculator: ExpirationDateCalculation) -> Date {
        expirationOverride ?? calculator.calculateDefaultExpiration(from: Date())
    }
    
    // MARK: - Validation
    
    /// Validates the entire configuration.
    /// - Returns: Result indicating success or the specific validation error
    func validate() -> Result<Void, ConfigurationError> {
        // Validate windowDays
        if !Self.validWindowDays.contains(windowDays) {
            return .failure(.valueOutOfRange(
                parameter: "windowDays",
                message: "Window days must be one of: \(Self.validWindowDays.map(String.init).joined(separator: ", "))."
            ))
        }
        
        // Validate lookbackDays
        if !Self.validLookbackDays.contains(lookbackDays) {
            return .failure(.valueOutOfRange(
                parameter: "lookbackDays",
                message: "Lookback days must be one of: \(Self.validLookbackDays.map(String.init).joined(separator: ", "))."
            ))
        }
        
        // Validate premiumPct
        if !Self.premiumPctRange.contains(premiumPct) {
            return .failure(.valueOutOfRange(
                parameter: "premiumPct",
                message: "Premium must be between \(Self.premiumPctRange.lowerBound)% and \(Self.premiumPctRange.upperBound)%."
            ))
        }
        
        return .success(())
    }
    
    /// Validates a window days value.
    /// - Parameter value: The value to validate
    /// - Returns: Error if invalid, nil if valid
    static func validateWindowDays(_ value: Int) -> ConfigurationError? {
        guard Self.validWindowDays.contains(value) else {
            return .valueOutOfRange(
                parameter: "windowDays",
                message: "Window days must be one of: \(Self.validWindowDays.map(String.init).joined(separator: ", "))."
            )
        }
        return nil
    }
    
    /// Validates a lookback days value.
    /// - Parameter value: The value to validate
    /// - Returns: Error if invalid, nil if valid
    static func validateLookbackDays(_ value: Int) -> ConfigurationError? {
        guard Self.validLookbackDays.contains(value) else {
            return .valueOutOfRange(
                parameter: "lookbackDays",
                message: "Lookback days must be one of: \(Self.validLookbackDays.map(String.init).joined(separator: ", "))."
            )
        }
        return nil
    }
    
    /// Validates a premium percentage value.
    /// - Parameter value: The value to validate
    /// - Returns: Error if invalid, nil if valid
    static func validatePremiumPct(_ value: Double) -> ConfigurationError? {
        guard Self.premiumPctRange.contains(value) else {
            return .valueOutOfRange(
                parameter: "premiumPct",
                message: "Premium must be between \(Self.premiumPctRange.lowerBound)% and \(Self.premiumPctRange.upperBound)%."
            )
        }
        return nil
    }
    
    /// Checks if the configuration is valid.
    var isValid: Bool {
        if case .success = validate() {
            return true
        }
        return false
    }
    
    // MARK: - Conversion
    
    /// Converts this configuration to a generic StrategyConfiguration.
    /// - Returns: A StrategyConfiguration with the same parameter values
    func toStrategyConfiguration() -> StrategyConfiguration {
        StrategyConfiguration(
            strategyId: Self.strategyId,
            parameters: [
                "windowDays": .integer(windowDays),
                "lookbackDays": .integer(lookbackDays),
                "premiumPct": .decimal(premiumPct),
                "onlyOrders": .boolean(onlyOrders),
                "optionTypeFilter": .string(optionTypeFilter.rawValue)
            ],
            updatedAt: Date()
        )
    }
    
    /// Creates a WeeklyOptionConfiguration from a generic StrategyConfiguration.
    /// - Parameter config: The generic configuration
    /// - Returns: A WeeklyOptionConfiguration with values from the generic config
    static func from(_ config: StrategyConfiguration) -> WeeklyOptionConfiguration {
        // Parse optionTypeFilter from string
        let filterString = config.getString("optionTypeFilter", default: Self.default.optionTypeFilter.rawValue)
        let optionFilter = OptionTypeFilter(rawValue: filterString) ?? Self.default.optionTypeFilter
        
        return WeeklyOptionConfiguration(
            windowDays: config.getInt("windowDays", default: Self.default.windowDays),
            lookbackDays: config.getInt("lookbackDays", default: Self.default.lookbackDays),
            premiumPct: config.getDouble("premiumPct", default: Self.default.premiumPct),
            onlyOrders: config.getBool("onlyOrders", default: Self.default.onlyOrders),
            optionTypeFilter: optionFilter
        )
    }
}
