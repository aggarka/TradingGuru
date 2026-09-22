//
//  StrategyProtocols.swift
//  TradingGuru
//
//  Protocol definitions for trading strategies and configuration schemas.
//  Designed for extensibility without modifying existing code (Requirement 3.5).
//

import Foundation

// MARK: - Supporting Types

/// Represents a single price data point with date and closing price.
struct PricePoint: Codable, Equatable {
    /// The date of the price data
    let date: Date
    
    /// The closing price for the date
    let close: Double
    
    /// Creates a new PricePoint instance.
    init(date: Date, close: Double) {
        self.date = date
        self.close = close
    }
}

/// Type of trading opportunity identified by analysis.
enum OpportunityType: String, Codable, CaseIterable {
    /// Call option opportunity (positive return expectation)
    case call = "CALL"
    
    /// Put option opportunity (negative return expectation)
    case put = "PUT"
}

/// Signal indicating recommended action for an opportunity.
enum Signal: String, Codable, CaseIterable {
    /// Order signal - opportunity meets criteria for entry
    case order = "ORDER"
    
    /// Hold signal - opportunity exists but doesn't meet entry criteria
    case hold = "HOLD"
}

/// Result of a strategy analysis for a single ticker.
/// - Validates: Requirement 6.1 (Analysis result structure)
/// - Validates: Requirement 6 (Enhanced results display with options data)
struct AnalysisResult: Codable, Identifiable, Equatable {
    /// Unique identifier for the result
    let id: UUID
    
    /// The ticker symbol analyzed
    let ticker: String
    
    /// The type of opportunity (CALL or PUT)
    let type: OpportunityType
    
    /// The expected return percentage
    let returnPercentage: Double
    
    /// The current price of the stock
    let currentPrice: Double
    
    /// The target price based on historical analysis
    let targetPrice: Double
    
    /// The trading signal (ORDER or HOLD)
    let signal: Signal
    
    /// The next earnings date if available
    let nextEarningsDate: Date?
    
    /// Whether earnings date poses a risk (on or before expiration)
    /// - Validates: Requirement 6.4 (Earnings risk indicator)
    let hasEarningsRisk: Bool
    
    /// Timestamp when the analysis was performed
    let analyzedAt: Date
    
    // MARK: - Options-specific Fields
    
    /// The expiration date of the selected option
    /// - Validates: Requirement 6.1 (Expiration Date column)
    let expirationDate: Date?
    
    /// The strike price of the selected option contract
    /// - Validates: Requirement 6.2 (Strike Price column)
    let strikePrice: Double?
    
    /// The bid price of the selected option
    /// - Validates: Requirement 6.3 (Bid Premium column)
    let bidPremium: Double?
    
    /// The ask price of the selected option
    /// - Validates: Requirement 6.4 (Ask Premium column)
    let askPremium: Double?
    
    /// The mid-price premium: (bid + ask) / 2
    /// - Validates: Requirement 6.5 (Mid Premium column)
    let midPremium: Double?
    
    /// The selected option contract (for reference)
    let selectedOption: OptionContract?
    
    /// Creates a new AnalysisResult instance.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - ticker: The ticker symbol analyzed
    ///   - type: The type of opportunity (CALL or PUT)
    ///   - returnPercentage: The expected return percentage
    ///   - currentPrice: The current price of the stock
    ///   - targetPrice: The target price based on historical analysis
    ///   - signal: The trading signal (ORDER or HOLD)
    ///   - nextEarningsDate: The next earnings date if available
    ///   - hasEarningsRisk: Whether earnings date poses a risk
    ///   - analyzedAt: Timestamp when the analysis was performed (defaults to now)
    ///   - expirationDate: The expiration date of the selected option (defaults to nil)
    ///   - strikePrice: The strike price of the selected option (defaults to nil)
    ///   - bidPremium: The bid price of the selected option (defaults to nil)
    ///   - askPremium: The ask price of the selected option (defaults to nil)
    ///   - midPremium: The mid-price premium (defaults to nil)
    ///   - selectedOption: The selected option contract (defaults to nil)
    init(
        id: UUID = UUID(),
        ticker: String,
        type: OpportunityType,
        returnPercentage: Double,
        currentPrice: Double,
        targetPrice: Double,
        signal: Signal,
        nextEarningsDate: Date?,
        hasEarningsRisk: Bool,
        analyzedAt: Date = Date(),
        expirationDate: Date? = nil,
        strikePrice: Double? = nil,
        bidPremium: Double? = nil,
        askPremium: Double? = nil,
        midPremium: Double? = nil,
        selectedOption: OptionContract? = nil
    ) {
        self.id = id
        self.ticker = ticker
        self.type = type
        self.returnPercentage = returnPercentage
        self.currentPrice = currentPrice
        self.targetPrice = targetPrice
        self.signal = signal
        self.nextEarningsDate = nextEarningsDate
        self.hasEarningsRisk = hasEarningsRisk
        self.analyzedAt = analyzedAt
        self.expirationDate = expirationDate
        self.strikePrice = strikePrice
        self.bidPremium = bidPremium
        self.askPremium = askPremium
        self.midPremium = midPremium
        self.selectedOption = selectedOption
    }
}

// MARK: - Strategy Configuration Types

/// Flexible configuration value storage supporting multiple types.
enum ConfigValue: Codable, Equatable {
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)
    case string(String)
    
    /// Returns the value as an Int if applicable.
    var intValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as a Double if applicable.
    var doubleValue: Double? {
        if case .decimal(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as a Bool if applicable.
    var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as a String if applicable.
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

/// Configuration for a trading strategy.
struct StrategyConfiguration: Codable, Equatable {
    /// The identifier of the strategy this configuration applies to
    let strategyId: String
    
    /// The parameter values for the strategy
    var parameters: [String: ConfigValue]
    
    /// Timestamp when the configuration was last updated
    var updatedAt: Date
    
    /// Creates a new StrategyConfiguration instance.
    init(strategyId: String, parameters: [String: ConfigValue] = [:], updatedAt: Date = Date()) {
        self.strategyId = strategyId
        self.parameters = parameters
        self.updatedAt = updatedAt
    }
    
    /// Gets a parameter value by key.
    /// - Parameter key: The parameter key
    /// - Returns: The ConfigValue if found, nil otherwise
    func getValue(for key: String) -> ConfigValue? {
        parameters[key]
    }
    
    /// Sets a parameter value by key.
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The parameter key
    mutating func setValue(_ value: ConfigValue, for key: String) {
        parameters[key] = value
        updatedAt = Date()
    }
    
    /// Gets an integer parameter value.
    /// - Parameters:
    ///   - key: The parameter key
    ///   - defaultValue: Default value if not found or wrong type
    /// - Returns: The integer value or default
    func getInt(_ key: String, default defaultValue: Int) -> Int {
        parameters[key]?.intValue ?? defaultValue
    }
    
    /// Gets a double parameter value.
    /// - Parameters:
    ///   - key: The parameter key
    ///   - defaultValue: Default value if not found or wrong type
    /// - Returns: The double value or default
    func getDouble(_ key: String, default defaultValue: Double) -> Double {
        parameters[key]?.doubleValue ?? defaultValue
    }
    
    /// Gets a boolean parameter value.
    /// - Parameters:
    ///   - key: The parameter key
    ///   - defaultValue: Default value if not found or wrong type
    /// - Returns: The boolean value or default
    func getBool(_ key: String, default defaultValue: Bool) -> Bool {
        parameters[key]?.boolValue ?? defaultValue
    }
    
    /// Gets a string parameter value.
    /// - Parameters:
    ///   - key: The parameter key
    ///   - defaultValue: Default value if not found or wrong type
    /// - Returns: The string value or default
    func getString(_ key: String, default defaultValue: String) -> String {
        parameters[key]?.stringValue ?? defaultValue
    }
}

// MARK: - Configuration Parameter Types

/// Type of a configuration parameter.
enum ParameterType: Equatable {
    /// Integer parameter with optional predefined options
    case integer(options: [Int]?)
    
    /// Decimal parameter with range and step constraints
    case decimal(range: ClosedRange<Double>, step: Double)
    
    /// Boolean parameter
    case boolean
}

/// Constraints for a configuration parameter.
struct ParameterConstraints: Equatable {
    /// Minimum value (for numeric types)
    let minValue: Double?
    
    /// Maximum value (for numeric types)
    let maxValue: Double?
    
    /// Step increment (for decimal types)
    let step: Double?
    
    /// Allowed values (for integer types)
    let allowedValues: [Int]?
    
    /// Creates a new ParameterConstraints instance.
    init(
        minValue: Double? = nil,
        maxValue: Double? = nil,
        step: Double? = nil,
        allowedValues: [Int]? = nil
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.allowedValues = allowedValues
    }
}

/// Describes a single configuration parameter for a strategy.
/// - Validates: Requirement 4.1 (Configuration options)
struct ConfigurationParameter: Equatable {
    /// The parameter key used in configuration storage
    let key: String
    
    /// The display name shown to users
    let displayName: String
    
    /// The type of the parameter
    let type: ParameterType
    
    /// The default value for the parameter
    let defaultValue: ConfigValue
    
    /// Optional constraints for the parameter
    let constraints: ParameterConstraints?
    
    /// Creates a new ConfigurationParameter instance.
    init(
        key: String,
        displayName: String,
        type: ParameterType,
        defaultValue: ConfigValue,
        constraints: ParameterConstraints? = nil
    ) {
        self.key = key
        self.displayName = displayName
        self.type = type
        self.defaultValue = defaultValue
        self.constraints = constraints
    }
}

/// Errors that can occur during configuration validation.
enum ConfigurationError: Error, Equatable {
    /// A parameter value is out of its allowed range
    case valueOutOfRange(parameter: String, message: String)
    
    /// A required parameter is missing
    case missingParameter(parameter: String)
    
    /// The parameter value type doesn't match the expected type
    case invalidType(parameter: String)
}

extension ConfigurationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .valueOutOfRange(_, let message):
            return message
        case .missingParameter(let parameter):
            return "Missing required parameter: \(parameter)"
        case .invalidType(let parameter):
            return "Invalid value type for parameter: \(parameter)"
        }
    }
}

// MARK: - Strategy Configuration Schema Protocol

/// Protocol for defining the configuration schema of a trading strategy.
/// 
/// Each strategy defines its own schema that describes available parameters
/// and validation rules.
/// 
/// - Validates: Requirements 4.1-4.5 (Strategy configuration options)
protocol StrategyConfigurationSchema {
    /// The parameters available for this strategy.
    var parameters: [ConfigurationParameter] { get }
    
    /// Validates a configuration against the schema.
    /// - Parameter configuration: The configuration to validate
    /// - Returns: Success if valid, or ConfigurationError if invalid
    /// - Validates: Requirement 4.11 (Configuration validation)
    func validate(_ configuration: StrategyConfiguration) -> Result<Void, ConfigurationError>
    
    /// Creates a default configuration for this strategy.
    /// - Returns: A configuration with all default values
    /// - Validates: Requirement 4.8 (Default values)
    func createDefaultConfiguration() -> StrategyConfiguration
}

// MARK: - Trading Strategy Protocol

/// Protocol for trading strategy implementations.
/// 
/// This protocol enables extensibility without modifying existing code.
/// New strategies can be added by implementing this protocol.
/// 
/// - Validates: Requirement 3.5 (Common strategy interface for extensibility)
protocol TradingStrategy {
    /// The display name of the strategy.
    var name: String { get }
    
    /// The unique identifier for the strategy.
    var identifier: String { get }
    
    /// The configuration schema for this strategy.
    var configurationSchema: StrategyConfigurationSchema { get }
    
    /// Analyzes price data using this strategy.
    /// - Parameters:
    ///   - priceData: Historical price data points
    ///   - configuration: The strategy configuration to use
    /// - Returns: The analysis result for the data
    /// - Validates: Requirements 5.1-5.4 (Strategy analysis)
    func analyze(
        priceData: [PricePoint],
        configuration: StrategyConfiguration
    ) -> AnalysisResult
}

// MARK: - Strategy Registry Errors

/// Errors that can occur during strategy registry operations.
/// - Validates: Requirement 3.4 (Handle configuration interface load failures)
enum StrategyRegistryError: Error, Equatable {
    /// Strategy with the given identifier was not found in the registry
    case strategyNotFound(identifier: String)
    
    /// Failed to load the configuration interface for a strategy
    case configurationLoadFailed(strategyId: String, reason: String)
    
    /// Strategy with the same identifier is already registered
    case duplicateStrategy(identifier: String)
    
    /// The registry has not been initialized
    case registryNotInitialized
    
    /// Generic error for unexpected failures
    case unknown(String)
}

extension StrategyRegistryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .strategyNotFound(let identifier):
            return "Strategy '\(identifier)' was not found. Please try selecting a different strategy."
        case .configurationLoadFailed(let strategyId, let reason):
            return "Failed to load configuration for '\(strategyId)': \(reason). Tap retry to try again."
        case .duplicateStrategy(let identifier):
            return "Strategy '\(identifier)' is already registered."
        case .registryNotInitialized:
            return "The strategy registry has not been initialized."
        case .unknown(let message):
            return message
        }
    }
    
    /// Whether this error is retryable
    var isRetryable: Bool {
        switch self {
        case .configurationLoadFailed, .registryNotInitialized, .unknown:
            return true
        case .strategyNotFound, .duplicateStrategy:
            return false
        }
    }
}

// MARK: - Strategy Factory Protocol

/// Protocol for strategy factories that can create strategy instances.
/// This enables dependency injection and lazy loading of strategies.
protocol StrategyFactory {
    /// The identifier of the strategy this factory creates.
    var strategyIdentifier: String { get }
    
    /// Creates an instance of the strategy.
    /// - Returns: A TradingStrategy instance
    /// - Throws: StrategyRegistryError if creation fails
    func createStrategy() throws -> any TradingStrategy
}

// MARK: - Strategy Registry

/// Registry for managing available trading strategies.
/// 
/// This class implements the Open/Closed Principle:
/// - Open for extension: New strategies can be registered without modifying existing code
/// - Closed for modification: Existing strategy implementations don't need to change
/// 
/// Usage:
/// ```swift
/// // Register a strategy
/// StrategyRegistry.shared.register(MyStrategy())
/// 
/// // Get a strategy by identifier
/// let strategy = StrategyRegistry.shared.getStrategy(withId: "my_strategy")
/// 
/// // List all available strategies
/// let strategies = StrategyRegistry.shared.availableStrategies
/// ```
/// 
/// - Validates: Requirement 3.5 (Common strategy interface enabling new strategies without modifying existing code)
final class StrategyRegistry {
    
    // MARK: - Singleton
    
    /// The shared singleton instance of the strategy registry.
    static let shared = StrategyRegistry()
    
    // MARK: - Private Properties
    
    /// Dictionary mapping strategy identifiers to their implementations.
    private var strategies: [String: any TradingStrategy] = [:]
    
    /// Dictionary mapping strategy identifiers to their factories for lazy loading.
    private var factories: [String: StrategyFactory] = [:]
    
    /// Lock for thread-safe access to the strategies dictionary.
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern.
    private init() {}
    
    // MARK: - Registration
    
    /// Registers a trading strategy in the registry.
    /// 
    /// This is the primary method for adding new strategies.
    /// New strategies are registered without modifying existing code.
    /// 
    /// - Parameter strategy: The strategy to register
    /// - Throws: StrategyRegistryError.duplicateStrategy if a strategy with the same identifier exists
    /// - Validates: Requirement 3.5 (New strategies added without modifying existing code)
    func register(_ strategy: any TradingStrategy) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard strategies[strategy.identifier] == nil else {
            throw StrategyRegistryError.duplicateStrategy(identifier: strategy.identifier)
        }
        
        strategies[strategy.identifier] = strategy
    }
    
    /// Registers a strategy factory for lazy loading.
    /// 
    /// Use this method when you want to defer strategy instantiation until
    /// it's actually needed. This is useful for strategies with expensive
    /// initialization.
    /// 
    /// - Parameter factory: The factory to register
    /// - Throws: StrategyRegistryError.duplicateStrategy if a strategy with the same identifier exists
    func registerFactory(_ factory: StrategyFactory) throws {
        lock.lock()
        defer { lock.unlock() }
        
        let identifier = factory.strategyIdentifier
        guard strategies[identifier] == nil && factories[identifier] == nil else {
            throw StrategyRegistryError.duplicateStrategy(identifier: identifier)
        }
        
        factories[identifier] = factory
    }
    
    /// Registers multiple strategies at once.
    /// 
    /// - Parameter strategyList: Array of strategies to register
    /// - Throws: StrategyRegistryError if any registration fails
    func registerAll(_ strategyList: [any TradingStrategy]) throws {
        for strategy in strategyList {
            try register(strategy)
        }
    }
    
    // MARK: - Retrieval
    
    /// Retrieves a strategy by its identifier.
    /// 
    /// If the strategy was registered via a factory and hasn't been
    /// instantiated yet, this method will create it.
    /// 
    /// - Parameter identifier: The unique identifier of the strategy
    /// - Returns: The strategy if found
    /// - Throws: StrategyRegistryError.strategyNotFound if not registered
    /// - Validates: Requirement 3.4 (Handle configuration interface load failures)
    func getStrategy(withId identifier: String) throws -> any TradingStrategy {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if strategy is already instantiated
        if let strategy = strategies[identifier] {
            return strategy
        }
        
        // Check if there's a factory for lazy loading
        if let factory = factories[identifier] {
            do {
                let strategy = try factory.createStrategy()
                strategies[identifier] = strategy
                factories.removeValue(forKey: identifier)
                return strategy
            } catch {
                throw StrategyRegistryError.configurationLoadFailed(
                    strategyId: identifier,
                    reason: error.localizedDescription
                )
            }
        }
        
        throw StrategyRegistryError.strategyNotFound(identifier: identifier)
    }
    
    /// Attempts to load the configuration interface for a strategy.
    /// 
    /// This method validates that the strategy's configuration schema
    /// can be loaded and is valid.
    /// 
    /// - Parameter identifier: The strategy identifier
    /// - Returns: Result with the configuration schema or error
    /// - Validates: Requirement 3.4 (Handle configuration interface load failures with error and retry)
    func loadConfigurationInterface(for identifier: String) -> Result<StrategyConfigurationSchema, StrategyRegistryError> {
        do {
            let strategy = try getStrategy(withId: identifier)
            let schema = strategy.configurationSchema
            
            // Validate that the schema has at least one parameter
            // This acts as a basic sanity check for configuration loading
            guard !schema.parameters.isEmpty else {
                return .failure(.configurationLoadFailed(
                    strategyId: identifier,
                    reason: "Configuration schema contains no parameters"
                ))
            }
            
            return .success(schema)
        } catch let error as StrategyRegistryError {
            return .failure(error)
        } catch {
            return .failure(.configurationLoadFailed(
                strategyId: identifier,
                reason: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Query
    
    /// Returns all registered strategies.
    /// 
    /// Note: This will instantiate any strategies registered via factories
    /// that haven't been instantiated yet.
    /// 
    /// - Returns: Array of all registered strategies
    var availableStrategies: [any TradingStrategy] {
        lock.lock()
        defer { lock.unlock() }
        
        // Instantiate any strategies from factories
        for (identifier, factory) in factories {
            if let strategy = try? factory.createStrategy() {
                strategies[identifier] = strategy
            }
        }
        factories.removeAll()
        
        return Array(strategies.values)
    }
    
    /// Returns the identifiers of all registered strategies.
    /// 
    /// This doesn't instantiate factory-registered strategies.
    /// 
    /// - Returns: Array of strategy identifiers
    var availableStrategyIdentifiers: [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(strategies.keys) + Array(factories.keys)
    }
    
    /// Returns display information for all available strategies.
    /// 
    /// This is useful for populating strategy selection dropdowns.
    /// 
    /// - Returns: Array of tuples containing (identifier, name)
    var strategyDisplayInfo: [(identifier: String, name: String)] {
        availableStrategies.map { (identifier: $0.identifier, name: $0.name) }
    }
    
    /// Checks if a strategy with the given identifier is registered.
    /// 
    /// - Parameter identifier: The strategy identifier to check
    /// - Returns: true if the strategy is registered
    func isRegistered(_ identifier: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return strategies[identifier] != nil || factories[identifier] != nil
    }
    
    /// Returns the count of registered strategies.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        
        return strategies.count + factories.count
    }
    
    // MARK: - Management
    
    /// Unregisters a strategy by its identifier.
    /// 
    /// - Parameter identifier: The identifier of the strategy to remove
    /// - Returns: true if a strategy was removed, false if not found
    @discardableResult
    func unregister(_ identifier: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let removedStrategy = strategies.removeValue(forKey: identifier) != nil
        let removedFactory = factories.removeValue(forKey: identifier) != nil
        
        return removedStrategy || removedFactory
    }
    
    /// Removes all registered strategies.
    /// 
    /// Use with caution - this is primarily intended for testing.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        strategies.removeAll()
        factories.removeAll()
    }
}

// MARK: - Default Strategy Factory

/// A simple factory implementation that creates strategies via a closure.
/// 
/// Usage:
/// ```swift
/// let factory = DefaultStrategyFactory(identifier: "my_strategy") {
///     return MyStrategy()
/// }
/// try StrategyRegistry.shared.registerFactory(factory)
/// ```
struct DefaultStrategyFactory: StrategyFactory {
    /// The identifier of the strategy this factory creates.
    let strategyIdentifier: String
    
    /// The closure that creates the strategy instance.
    private let creator: () throws -> any TradingStrategy
    
    /// Creates a new factory.
    /// - Parameters:
    ///   - identifier: The strategy identifier
    ///   - creator: Closure that creates the strategy
    init(identifier: String, creator: @escaping () throws -> any TradingStrategy) {
        self.strategyIdentifier = identifier
        self.creator = creator
    }
    
    func createStrategy() throws -> any TradingStrategy {
        try creator()
    }
}

// MARK: - Interface Load State

/// Represents the state of a configuration interface loading operation.
/// - Validates: Requirement 3.4 (Handle configuration interface load failures with error and retry)
enum InterfaceLoadState: Equatable {
    /// Initial state, not yet loaded
    case idle
    
    /// Currently loading the configuration interface
    case loading
    
    /// Successfully loaded with the configuration schema
    case loaded(strategyId: String)
    
    /// Failed to load with error information
    case failed(error: StrategyRegistryError)
    
    /// Whether the state allows retrying
    var canRetry: Bool {
        if case .failed(let error) = self {
            return error.isRetryable
        }
        return false
    }
    
    /// Whether the configuration is ready for use
    var isReady: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
    
    static func == (lhs: InterfaceLoadState, rhs: InterfaceLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lId), .loaded(let rId)):
            return lId == rId
        case (.failed(let lError), .failed(let rError)):
            return lError == rError
        default:
            return false
        }
    }
}

// MARK: - Analysis Result Row (For Display)

/// A row in the analysis results display table.
/// - Validates: Requirement 6.1 (Results table columns)
/// - Validates: Requirement 6 (New column display with options data)
struct AnalysisResultRow: Identifiable, Equatable {
    /// Unique identifier for the row
    let id: UUID
    
    /// The ticker symbol
    let ticker: String
    
    /// The opportunity type (CALL/PUT)
    let type: String
    
    /// The return percentage formatted with % symbol
    let returnPercentage: String
    
    /// The current price formatted as currency
    let currentPrice: String
    
    /// The target price formatted as currency
    let targetPrice: String
    
    /// The signal (ORDER/HOLD)
    let signal: String
    
    /// The next earnings date formatted or "N/A"
    let nextEarningsDate: String
    
    /// Whether to highlight this row (ORDER signal)
    let isHighlighted: Bool
    
    /// Whether to show earnings date in red
    let hasEarningsRisk: Bool
    
    /// The raw return value for sorting
    let rawReturnPercentage: Double
    
    /// The raw current price for sorting
    let rawCurrentPrice: Double
    
    /// The raw target price for sorting
    let rawTargetPrice: Double
    
    /// The raw earnings date for sorting
    let rawNextEarningsDate: Date?
    
    // MARK: - Options Display Fields
    
    /// Expiration date formatted as YYYY-MM-DD or "N/A"
    /// - Validates: Requirement 6.1 (Expiration Date column)
    let expirationDate: String
    
    /// Strike price formatted as currency or "N/A"
    /// - Validates: Requirement 6.2 (Strike Price column)
    let strikePrice: String
    
    /// Bid premium formatted as currency or "N/A"
    /// - Validates: Requirement 6.3 (Bid Premium column)
    let bidPremium: String
    
    /// Ask premium formatted as currency or "N/A"
    /// - Validates: Requirement 6.4 (Ask Premium column)
    let askPremium: String
    
    /// Mid premium formatted as currency or "N/A"
    /// - Validates: Requirement 6.5 (Mid Premium column)
    let midPremium: String
    
    // MARK: - Raw Values for Sorting
    
    /// Raw expiration date for sorting (nil sorts to end)
    /// - Validates: Requirement 6.8 (Sort by expiration date)
    let rawExpirationDate: Date?
    
    /// Raw strike price for sorting (nil sorts to end)
    /// - Validates: Requirement 6.8 (Sort by strike price)
    let rawStrikePrice: Double?
    
    /// Raw mid premium for sorting (nil sorts to end)
    /// - Validates: Requirement 6.9 (Sort by mid premium)
    let rawMidPremium: Double?
    
    /// Creates a row from an AnalysisResult.
    /// - Validates: Requirement 6.10 (Display "N/A" when options chain is empty)
    init(from result: AnalysisResult) {
        self.id = result.id
        self.ticker = result.ticker
        self.type = result.type.rawValue
        self.returnPercentage = String(format: "%.2f%%", result.returnPercentage)
        self.currentPrice = String(format: "$%.2f", result.currentPrice)
        self.targetPrice = String(format: "$%.2f", result.targetPrice)
        self.signal = result.signal.rawValue
        self.nextEarningsDate = result.nextEarningsDate.map { 
            Self.dateFormatter.string(from: $0) 
        } ?? "N/A"
        self.isHighlighted = result.signal == .order
        self.hasEarningsRisk = result.hasEarningsRisk
        self.rawReturnPercentage = result.returnPercentage
        self.rawCurrentPrice = result.currentPrice
        self.rawTargetPrice = result.targetPrice
        self.rawNextEarningsDate = result.nextEarningsDate
        
        // Options display fields - format as YYYY-MM-DD for date, currency for prices
        // Display "N/A" when options data is unavailable (Requirement 6.10)
        self.expirationDate = result.expirationDate.map {
            Self.dateFormatter.string(from: $0)
        } ?? "N/A"
        
        self.strikePrice = result.strikePrice.map {
            String(format: "$%.2f", $0)
        } ?? "N/A"
        
        self.bidPremium = result.bidPremium.map {
            String(format: "$%.2f", $0)
        } ?? "N/A"
        
        self.askPremium = result.askPremium.map {
            String(format: "$%.2f", $0)
        } ?? "N/A"
        
        self.midPremium = result.midPremium.map {
            String(format: "$%.2f", $0)
        } ?? "N/A"
        
        // Raw values for sorting
        self.rawExpirationDate = result.expirationDate
        self.rawStrikePrice = result.strikePrice
        self.rawMidPremium = result.midPremium
    }
    
    /// Memberwise initializer for testing and previews.
    init(
        id: UUID = UUID(),
        ticker: String,
        type: String,
        returnPercentage: String,
        currentPrice: String,
        targetPrice: String,
        signal: String,
        nextEarningsDate: String,
        isHighlighted: Bool,
        hasEarningsRisk: Bool,
        rawReturnPercentage: Double,
        rawCurrentPrice: Double,
        rawTargetPrice: Double,
        rawNextEarningsDate: Date?,
        expirationDate: String = "N/A",
        strikePrice: String = "N/A",
        bidPremium: String = "N/A",
        askPremium: String = "N/A",
        midPremium: String = "N/A",
        rawExpirationDate: Date? = nil,
        rawStrikePrice: Double? = nil,
        rawMidPremium: Double? = nil
    ) {
        self.id = id
        self.ticker = ticker
        self.type = type
        self.returnPercentage = returnPercentage
        self.currentPrice = currentPrice
        self.targetPrice = targetPrice
        self.signal = signal
        self.nextEarningsDate = nextEarningsDate
        self.isHighlighted = isHighlighted
        self.hasEarningsRisk = hasEarningsRisk
        self.rawReturnPercentage = rawReturnPercentage
        self.rawCurrentPrice = rawCurrentPrice
        self.rawTargetPrice = rawTargetPrice
        self.rawNextEarningsDate = rawNextEarningsDate
        self.expirationDate = expirationDate
        self.strikePrice = strikePrice
        self.bidPremium = bidPremium
        self.askPremium = askPremium
        self.midPremium = midPremium
        self.rawExpirationDate = rawExpirationDate
        self.rawStrikePrice = rawStrikePrice
        self.rawMidPremium = rawMidPremium
    }
    
    /// Date formatter for displaying dates in YYYY-MM-DD format.
    /// Uses UTC timezone to correctly display dates that were stored as UTC midnight.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
