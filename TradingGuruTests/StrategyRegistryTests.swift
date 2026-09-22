//
//  StrategyRegistryTests.swift
//  TradingGuruTests
//
//  Unit tests for StrategyRegistry functionality.
//  Tests Requirement 3.4 (Configuration interface load failures) and
//  Requirement 3.5 (Extensible strategy architecture).
//

import Foundation
import Testing
@testable import TradingGuru

// MARK: - Mock Strategy for Testing

/// A mock trading strategy for testing the registry.
struct MockTradingStrategy: TradingStrategy {
    let name: String
    let identifier: String
    let configurationSchema: StrategyConfigurationSchema
    
    init(name: String = "Mock Strategy", identifier: String = "mock_strategy") {
        self.name = name
        self.identifier = identifier
        self.configurationSchema = MockConfigurationSchema()
    }
    
    func analyze(priceData: [PricePoint], configuration: StrategyConfiguration) -> AnalysisResult {
        AnalysisResult(
            ticker: "TEST",
            type: .call,
            returnPercentage: 5.0,
            currentPrice: 100.0,
            targetPrice: 105.0,
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
    }
}

/// A mock configuration schema for testing.
struct MockConfigurationSchema: StrategyConfigurationSchema {
    var parameters: [ConfigurationParameter] {
        [
            ConfigurationParameter(
                key: "testParam",
                displayName: "Test Parameter",
                type: .integer(options: [1, 2, 3]),
                defaultValue: .integer(1)
            )
        ]
    }
    
    func validate(_ configuration: StrategyConfiguration) -> Result<Void, ConfigurationError> {
        .success(())
    }
    
    func createDefaultConfiguration() -> StrategyConfiguration {
        StrategyConfiguration(
            strategyId: "mock_strategy",
            parameters: ["testParam": .integer(1)]
        )
    }
}

/// A mock configuration schema with no parameters (for testing failures).
struct EmptyConfigurationSchema: StrategyConfigurationSchema {
    var parameters: [ConfigurationParameter] { [] }
    
    func validate(_ configuration: StrategyConfiguration) -> Result<Void, ConfigurationError> {
        .success(())
    }
    
    func createDefaultConfiguration() -> StrategyConfiguration {
        StrategyConfiguration(strategyId: "empty_strategy")
    }
}

/// A mock strategy with an empty configuration schema.
struct EmptyConfigStrategy: TradingStrategy {
    let name = "Empty Config Strategy"
    let identifier = "empty_config_strategy"
    let configurationSchema: StrategyConfigurationSchema = EmptyConfigurationSchema()
    
    func analyze(priceData: [PricePoint], configuration: StrategyConfiguration) -> AnalysisResult {
        AnalysisResult(
            ticker: "TEST",
            type: .call,
            returnPercentage: 0,
            currentPrice: 100,
            targetPrice: 100,
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
    }
}

// MARK: - Strategy Registration Tests

/// Tests for basic strategy registration functionality.
/// - Validates: Requirement 3.5 (Strategies implemented through common interface)
@Suite("Strategy Registration Tests")
struct StrategyRegistrationTests {
    
    /// Tests that a strategy can be registered successfully.
    @Test("Strategy can be registered")
    func testRegisterStrategy() throws {
        let registry = StrategyRegistry.shared
        registry.reset() // Clean state
        
        let strategy = MockTradingStrategy()
        try registry.register(strategy)
        
        #expect(registry.isRegistered("mock_strategy"))
        #expect(registry.count == 1)
    }
    
    /// Tests that duplicate registration is rejected.
    @Test("Duplicate registration fails with error")
    func testDuplicateRegistrationFails() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy1 = MockTradingStrategy()
        try registry.register(strategy1)
        
        let strategy2 = MockTradingStrategy()
        
        #expect(throws: StrategyRegistryError.self) {
            try registry.register(strategy2)
        }
    }
    
    /// Tests that multiple different strategies can be registered.
    @Test("Multiple strategies can be registered")
    func testMultipleStrategyRegistration() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy1 = MockTradingStrategy(name: "Strategy 1", identifier: "strategy_1")
        let strategy2 = MockTradingStrategy(name: "Strategy 2", identifier: "strategy_2")
        
        try registry.registerAll([strategy1, strategy2])
        
        #expect(registry.count == 2)
        #expect(registry.isRegistered("strategy_1"))
        #expect(registry.isRegistered("strategy_2"))
    }
    
    /// Tests that a strategy can be unregistered.
    @Test("Strategy can be unregistered")
    func testUnregisterStrategy() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy = MockTradingStrategy()
        try registry.register(strategy)
        #expect(registry.isRegistered("mock_strategy"))
        
        let removed = registry.unregister("mock_strategy")
        #expect(removed)
        #expect(!registry.isRegistered("mock_strategy"))
        #expect(registry.count == 0)
    }
    
    /// Tests that unregistering a non-existent strategy returns false.
    @Test("Unregistering non-existent strategy returns false")
    func testUnregisterNonExistent() {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let removed = registry.unregister("non_existent")
        #expect(!removed)
    }
}

// MARK: - Strategy Retrieval Tests

/// Tests for strategy retrieval functionality.
@Suite("Strategy Retrieval Tests")
struct StrategyRetrievalTests {
    
    /// Tests that a registered strategy can be retrieved.
    @Test("Registered strategy can be retrieved")
    func testGetStrategy() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy = MockTradingStrategy(name: "Test Strategy", identifier: "test_strategy")
        try registry.register(strategy)
        
        let retrieved = try registry.getStrategy(withId: "test_strategy")
        #expect(retrieved.name == "Test Strategy")
        #expect(retrieved.identifier == "test_strategy")
    }
    
    /// Tests that retrieving a non-existent strategy throws an error.
    @Test("Retrieving non-existent strategy throws strategyNotFound")
    func testGetNonExistentStrategy() {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        #expect {
            try registry.getStrategy(withId: "non_existent")
        } throws: { error in
            guard case StrategyRegistryError.strategyNotFound = error else {
                return false
            }
            return true
        }
    }
    
    /// Tests that available strategies list is correct.
    @Test("Available strategies list is populated correctly")
    func testAvailableStrategies() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy1 = MockTradingStrategy(name: "Strategy A", identifier: "strategy_a")
        let strategy2 = MockTradingStrategy(name: "Strategy B", identifier: "strategy_b")
        
        try registry.register(strategy1)
        try registry.register(strategy2)
        
        let available = registry.availableStrategies
        #expect(available.count == 2)
        
        let identifiers = registry.availableStrategyIdentifiers
        #expect(identifiers.contains("strategy_a"))
        #expect(identifiers.contains("strategy_b"))
    }
    
    /// Tests that strategy display info is correct.
    @Test("Strategy display info is formatted correctly")
    func testStrategyDisplayInfo() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy = MockTradingStrategy(name: "Display Test Strategy", identifier: "display_test")
        try registry.register(strategy)
        
        let displayInfo = registry.strategyDisplayInfo
        #expect(displayInfo.count == 1)
        #expect(displayInfo.first?.identifier == "display_test")
        #expect(displayInfo.first?.name == "Display Test Strategy")
    }
}

// MARK: - Configuration Interface Load Tests

/// Tests for configuration interface loading functionality.
/// - Validates: Requirement 3.4 (Handle configuration interface load failures)
@Suite("Configuration Interface Load Tests")
struct ConfigurationInterfaceLoadTests {
    
    /// Tests that configuration interface loads successfully.
    @Test("Configuration interface loads successfully")
    func testLoadConfigurationInterface() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy = MockTradingStrategy()
        try registry.register(strategy)
        
        let result = registry.loadConfigurationInterface(for: "mock_strategy")
        
        switch result {
        case .success(let schema):
            #expect(schema.parameters.count > 0)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    /// Tests that loading configuration for non-existent strategy fails.
    @Test("Loading configuration for non-existent strategy fails")
    func testLoadConfigurationForNonExistent() {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let result = registry.loadConfigurationInterface(for: "non_existent")
        
        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            guard case .strategyNotFound(let identifier) = error else {
                Issue.record("Expected strategyNotFound error")
                return
            }
            #expect(identifier == "non_existent")
        }
    }
    
    /// Tests that loading configuration with empty schema fails.
    @Test("Loading configuration with empty schema fails")
    func testLoadConfigurationWithEmptySchema() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let strategy = EmptyConfigStrategy()
        try registry.register(strategy)
        
        let result = registry.loadConfigurationInterface(for: "empty_config_strategy")
        
        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            guard case .configurationLoadFailed = error else {
                Issue.record("Expected configurationLoadFailed error but got: \(error)")
                return
            }
            // Success - error is retryable
            #expect(error.isRetryable)
        }
    }
}

// MARK: - Strategy Factory Tests

/// Tests for strategy factory and lazy loading functionality.
@Suite("Strategy Factory Tests")
struct StrategyFactoryTests {
    
    /// Tests that strategies can be registered via factory.
    @Test("Strategy can be registered via factory")
    func testFactoryRegistration() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let factory = DefaultStrategyFactory(identifier: "factory_strategy") {
            MockTradingStrategy(name: "Factory Created Strategy", identifier: "factory_strategy")
        }
        
        try registry.registerFactory(factory)
        #expect(registry.isRegistered("factory_strategy"))
        
        // Strategy should be lazily created on retrieval
        let strategy = try registry.getStrategy(withId: "factory_strategy")
        #expect(strategy.name == "Factory Created Strategy")
    }
    
    /// Tests that factory-registered strategies appear in available identifiers.
    @Test("Factory strategies appear in available identifiers")
    func testFactoryStrategiesInIdentifiers() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let factory = DefaultStrategyFactory(identifier: "lazy_strategy") {
            MockTradingStrategy(identifier: "lazy_strategy")
        }
        
        try registry.registerFactory(factory)
        
        // Should appear in identifiers without instantiating
        let identifiers = registry.availableStrategyIdentifiers
        #expect(identifiers.contains("lazy_strategy"))
    }
    
    /// Tests that duplicate factory registration fails.
    @Test("Duplicate factory registration fails")
    func testDuplicateFactoryRegistration() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        let factory1 = DefaultStrategyFactory(identifier: "dup_factory") {
            MockTradingStrategy(identifier: "dup_factory")
        }
        let factory2 = DefaultStrategyFactory(identifier: "dup_factory") {
            MockTradingStrategy(identifier: "dup_factory")
        }
        
        try registry.registerFactory(factory1)
        
        #expect(throws: StrategyRegistryError.self) {
            try registry.registerFactory(factory2)
        }
    }
}

// MARK: - Strategy Registry Error Tests

/// Tests for StrategyRegistryError error messages and properties.
@Suite("Strategy Registry Error Tests")
struct StrategyRegistryErrorTests {
    
    /// Tests that strategyNotFound error has correct message.
    @Test("strategyNotFound error message is descriptive")
    func testStrategyNotFoundMessage() {
        let error = StrategyRegistryError.strategyNotFound(identifier: "test_id")
        let message = error.localizedDescription
        
        #expect(message.contains("test_id"))
        #expect(message.contains("not found"))
        #expect(!error.isRetryable)
    }
    
    /// Tests that configurationLoadFailed error has correct message.
    @Test("configurationLoadFailed error message includes retry")
    func testConfigurationLoadFailedMessage() {
        let error = StrategyRegistryError.configurationLoadFailed(
            strategyId: "strategy_x",
            reason: "Network error"
        )
        let message = error.localizedDescription
        
        #expect(message.contains("strategy_x"))
        #expect(message.contains("Network error"))
        #expect(message.lowercased().contains("retry"))
        #expect(error.isRetryable)
    }
    
    /// Tests that duplicateStrategy error is not retryable.
    @Test("duplicateStrategy error is not retryable")
    func testDuplicateStrategyNotRetryable() {
        let error = StrategyRegistryError.duplicateStrategy(identifier: "dup_id")
        #expect(!error.isRetryable)
    }
    
    /// Tests that unknown error is retryable.
    @Test("unknown error is retryable")
    func testUnknownErrorRetryable() {
        let error = StrategyRegistryError.unknown("Something went wrong")
        #expect(error.isRetryable)
    }
}

// MARK: - Interface Load State Tests

/// Tests for InterfaceLoadState enum.
@Suite("Interface Load State Tests")
struct InterfaceLoadStateTests {
    
    /// Tests idle state properties.
    @Test("Idle state cannot retry and is not ready")
    func testIdleState() {
        let state = InterfaceLoadState.idle
        #expect(!state.canRetry)
        #expect(!state.isReady)
    }
    
    /// Tests loading state properties.
    @Test("Loading state cannot retry and is not ready")
    func testLoadingState() {
        let state = InterfaceLoadState.loading
        #expect(!state.canRetry)
        #expect(!state.isReady)
    }
    
    /// Tests loaded state properties.
    @Test("Loaded state cannot retry but is ready")
    func testLoadedState() {
        let state = InterfaceLoadState.loaded(strategyId: "test")
        #expect(!state.canRetry)
        #expect(state.isReady)
    }
    
    /// Tests failed state with retryable error.
    @Test("Failed state with retryable error can retry")
    func testFailedStateRetryable() {
        let error = StrategyRegistryError.configurationLoadFailed(
            strategyId: "test",
            reason: "Network error"
        )
        let state = InterfaceLoadState.failed(error: error)
        
        #expect(state.canRetry)
        #expect(!state.isReady)
    }
    
    /// Tests failed state with non-retryable error.
    @Test("Failed state with non-retryable error cannot retry")
    func testFailedStateNotRetryable() {
        let error = StrategyRegistryError.strategyNotFound(identifier: "test")
        let state = InterfaceLoadState.failed(error: error)
        
        #expect(!state.canRetry)
        #expect(!state.isReady)
    }
    
    /// Tests state equality.
    @Test("Interface load states are equatable")
    func testStateEquality() {
        #expect(InterfaceLoadState.idle == InterfaceLoadState.idle)
        #expect(InterfaceLoadState.loading == InterfaceLoadState.loading)
        #expect(InterfaceLoadState.loaded(strategyId: "a") == InterfaceLoadState.loaded(strategyId: "a"))
        #expect(InterfaceLoadState.loaded(strategyId: "a") != InterfaceLoadState.loaded(strategyId: "b"))
    }
}

// MARK: - Open/Closed Principle Tests

/// Tests demonstrating the Open/Closed Principle implementation.
/// - Validates: Requirement 3.5 (New strategies added without modifying existing code)
@Suite("Open/Closed Principle Tests")
struct OpenClosedPrincipleTests {
    
    /// Tests that new strategies can be added without modifying existing code.
    @Test("New strategies can be added without modifying existing code")
    func testExtensibilityWithoutModification() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        // Register initial strategy
        let existingStrategy = MockTradingStrategy(name: "Existing Strategy", identifier: "existing")
        try registry.register(existingStrategy)
        
        // A "new" strategy can be added without modifying MockTradingStrategy or the registry
        struct NewCustomStrategy: TradingStrategy {
            let name = "New Custom Strategy"
            let identifier = "new_custom"
            var configurationSchema: StrategyConfigurationSchema { MockConfigurationSchema() }
            
            func analyze(priceData: [PricePoint], configuration: StrategyConfiguration) -> AnalysisResult {
                AnalysisResult(
                    ticker: "CUSTOM",
                    type: .put,
                    returnPercentage: -3.0,
                    currentPrice: 50.0,
                    targetPrice: 48.5,
                    signal: .hold,
                    nextEarningsDate: nil,
                    hasEarningsRisk: false
                )
            }
        }
        
        let newStrategy = NewCustomStrategy()
        try registry.register(newStrategy)
        
        // Both strategies are now available
        #expect(registry.count == 2)
        #expect(registry.isRegistered("existing"))
        #expect(registry.isRegistered("new_custom"))
        
        // Each strategy works independently
        let retrievedExisting = try registry.getStrategy(withId: "existing")
        let retrievedNew = try registry.getStrategy(withId: "new_custom")
        
        #expect(retrievedExisting.name == "Existing Strategy")
        #expect(retrievedNew.name == "New Custom Strategy")
    }
    
    /// Tests that the registry works with any TradingStrategy implementation.
    @Test("Registry accepts any TradingStrategy implementation")
    func testRegistryAcceptsAnyImplementation() throws {
        let registry = StrategyRegistry.shared
        registry.reset()
        
        // Different implementations of TradingStrategy
        struct MinimalStrategy: TradingStrategy {
            let name = "Minimal"
            let identifier = "minimal"
            var configurationSchema: StrategyConfigurationSchema { MockConfigurationSchema() }
            
            func analyze(priceData: [PricePoint], configuration: StrategyConfiguration) -> AnalysisResult {
                AnalysisResult(
                    ticker: "MIN",
                    type: .call,
                    returnPercentage: 1.0,
                    currentPrice: 100.0,
                    targetPrice: 101.0,
                    signal: .hold,
                    nextEarningsDate: nil,
                    hasEarningsRisk: false
                )
            }
        }
        
        struct ComplexStrategy: TradingStrategy {
            let name = "Complex"
            let identifier = "complex"
            var configurationSchema: StrategyConfigurationSchema { MockConfigurationSchema() }
            
            // This strategy might have complex internal logic
            private let multiplier: Double = 2.0
            
            func analyze(priceData: [PricePoint], configuration: StrategyConfiguration) -> AnalysisResult {
                let baseReturn = 5.0 * multiplier
                return AnalysisResult(
                    ticker: "CPLX",
                    type: .call,
                    returnPercentage: baseReturn,
                    currentPrice: 100.0,
                    targetPrice: 110.0,
                    signal: .order,
                    nextEarningsDate: Date(),
                    hasEarningsRisk: true
                )
            }
        }
        
        try registry.register(MinimalStrategy())
        try registry.register(ComplexStrategy())
        
        #expect(registry.count == 2)
        
        // Both work through the common interface
        let strategies = registry.availableStrategies
        for strategy in strategies {
            let result = strategy.analyze(priceData: [], configuration: StrategyConfiguration(strategyId: strategy.identifier))
            #expect(!result.ticker.isEmpty)
        }
    }
}
