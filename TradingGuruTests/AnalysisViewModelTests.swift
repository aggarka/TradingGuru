//
//  AnalysisViewModelTests.swift
//  TradingGuruTests
//
//  Unit tests for AnalysisViewModel covering strategy selection,
//  configuration persistence, and validation.
//

import XCTest
@testable import TradingGuru

/// Unit tests for AnalysisViewModel
/// - Validates: Requirement 3.1-3.6 (Strategy selection)
/// - Validates: Requirement 4.6-4.11 (Configuration handling)
final class AnalysisViewModelTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var viewModel: AnalysisViewModel!
    var mockRepository: MockConfigurationRepository!
    var validationService: ConfigurationValidationService!
    
    // MARK: - Setup / Teardown
    
    override func setUp() {
        super.setUp()
        mockRepository = MockConfigurationRepository()
        validationService = ConfigurationValidationService()
        viewModel = AnalysisViewModel(
            configurationRepository: mockRepository,
            validationService: validationService,
            userId: "test_user"
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        validationService = nil
        super.tearDown()
    }
    
    // MARK: - Strategy Selection Tests
    
    /// Test: Strategy selection triggers configuration loading
    /// - Validates: Requirement 3.3 (Load configuration interface within 2 seconds)
    /// - Validates: Requirement 4.7 (Load previously saved configuration)
    @MainActor
    func testStrategySelectionTriggersConfigurationLoading() async {
        // Given: A saved configuration in the repository
        let savedConfig = WeeklyOptionConfiguration(
            windowDays: 30,
            lookbackDays: 360,
            premiumPct: 2.5,
            onlyOrders: true
        )
        mockRepository.savedConfiguration = savedConfig.toStrategyConfiguration()
        
        // When: User selects the Weekly Option Strategy
        await viewModel.selectStrategy(.weeklyOption)
        
        // Then: Configuration is loaded from repository
        XCTAssertTrue(viewModel.isConfigurationLoaded, "Configuration should be loaded")
        XCTAssertFalse(viewModel.isLoadingConfiguration, "Loading indicator should be hidden")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.windowDays, 30, "Window days should match saved value")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.lookbackDays, 360, "Lookback days should match saved value")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.premiumPct, 2.5, accuracy: 0.01, "Premium pct should match saved value")
        XCTAssertTrue(viewModel.weeklyOptionConfiguration.onlyOrders, "Only orders should match saved value")
    }
    
    /// Test: No strategy selected shows correct initial state
    /// - Validates: Requirement 3.1 (Display placeholder when no strategy selected)
    /// - Validates: Requirement 3.6 (Disable run analysis button when no strategy selected)
    @MainActor
    func testNoStrategySelectedShowsPlaceholder() async {
        // Given: Initial state with no strategy selected
        
        // Then: No strategy should be selected
        XCTAssertNil(viewModel.selectedStrategy, "No strategy should be selected initially")
        XCTAssertFalse(viewModel.hasSelectedStrategy, "hasSelectedStrategy should be false")
        XCTAssertFalse(viewModel.canRunAnalysis, "Run analysis should be disabled")
        XCTAssertFalse(viewModel.isConfigurationLoaded, "Configuration should not be loaded")
    }
    
    /// Test: Clearing strategy selection resets state
    /// - Validates: Requirement 3.1 (Display placeholder when no strategy selected)
    @MainActor
    func testClearingStrategySelectionResetsState() async {
        // Given: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        XCTAssertTrue(viewModel.hasSelectedStrategy)
        
        // When: Strategy is cleared
        await viewModel.selectStrategy(nil)
        
        // Then: State is reset
        XCTAssertNil(viewModel.selectedStrategy, "Strategy should be nil")
        XCTAssertFalse(viewModel.hasSelectedStrategy, "hasSelectedStrategy should be false")
        XCTAssertFalse(viewModel.isConfigurationLoaded, "Configuration should not be loaded")
        XCTAssertFalse(viewModel.canRunAnalysis, "Run analysis should be disabled")
    }
    
    // MARK: - Configuration Save Tests
    
    /// Test: Configuration save triggers persistence
    /// - Validates: Requirement 4.6 (Persist configuration to database with confirmation)
    @MainActor
    func testConfigurationSaveTriggersPersistence() async {
        // Given: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        
        // When: Configuration is saved
        let newConfig = WeeklyOptionConfiguration(
            windowDays: 1,
            lookbackDays: 90,
            premiumPct: 1.5,
            onlyOrders: true
        )
        await viewModel.saveConfiguration(newConfig)
        
        // Then: Configuration is persisted to repository
        XCTAssertTrue(mockRepository.saveCalled, "Repository save should be called")
        XCTAssertEqual(mockRepository.lastSavedConfiguration?.strategyId, WeeklyOptionConfiguration.strategyId)
        
        // And: Local configuration is updated
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.windowDays, 1)
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.lookbackDays, 90)
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.premiumPct, 1.5, accuracy: 0.01)
        XCTAssertTrue(viewModel.weeklyOptionConfiguration.onlyOrders)
    }
    
    /// Test: Successful save shows confirmation
    /// - Validates: Requirement 4.6 (Display confirmation indicator upon successful save)
    @MainActor
    func testSuccessfulSaveShowsConfirmation() async {
        // Given: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        mockRepository.shouldSucceed = true
        
        // When: Configuration is saved successfully
        await viewModel.saveConfiguration(viewModel.weeklyOptionConfiguration)
        
        // Then: Save state shows success
        if case .saved = viewModel.saveState {
            // Success
        } else {
            XCTFail("Save state should be .saved")
        }
        XCTAssertTrue(viewModel.saveWasSuccessful, "saveWasSuccessful should be true")
        XCTAssertNil(viewModel.saveErrorMessage, "No error message should be present")
    }
    
    /// Test: Save failure displays error and retains values
    /// - Validates: Requirement 4.9 (Display error on save failure, retain user values)
    @MainActor
    func testSaveFailureRetainsUserValues() async {
        // Given: Strategy is selected and repository will fail
        await viewModel.selectStrategy(.weeklyOption)
        mockRepository.shouldSucceed = false
        
        // And: User modified configuration
        let modifiedConfig = WeeklyOptionConfiguration(
            windowDays: 30,
            lookbackDays: 360,
            premiumPct: 4.0,
            onlyOrders: true
        )
        
        // When: Save fails
        await viewModel.saveConfiguration(modifiedConfig)
        
        // Then: Error is displayed
        if case .failed(let error) = viewModel.saveState {
            XCTAssertFalse(error.isEmpty, "Error message should not be empty")
        } else {
            XCTFail("Save state should be .failed")
        }
        
        // And: User's values are retained (not reverted)
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.windowDays, 30, "User's windowDays should be retained")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.lookbackDays, 360, "User's lookbackDays should be retained")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.premiumPct, 4.0, accuracy: 0.01, "User's premiumPct should be retained")
        XCTAssertTrue(viewModel.weeklyOptionConfiguration.onlyOrders, "User's onlyOrders should be retained")
    }
    
    // MARK: - Validation Error Tests
    
    /// Test: Validation errors prevent saving
    /// - Validates: Requirement 4.11 (PREMIUM_PCT validation, don't save invalid value)
    @MainActor
    func testValidationErrorsPreventSaving() async {
        // Given: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        let initialConfig = viewModel.weeklyOptionConfiguration
        mockRepository.saveCalled = false
        
        // When: Invalid configuration is provided
        var invalidConfig = initialConfig
        invalidConfig.premiumPct = 10.0 // Out of valid range (0.1-5.0)
        await viewModel.saveConfiguration(invalidConfig)
        
        // Then: Save is NOT called
        XCTAssertFalse(mockRepository.saveCalled, "Repository save should not be called for invalid config")
        
        // And: Validation error is displayed
        XCTAssertNotNil(viewModel.validationError, "Validation error should be set")
        XCTAssertTrue(viewModel.validationError?.contains("0.1") == true || viewModel.validationError?.contains("5.0") == true,
                      "Error message should mention valid range")
    }
    
    /// Test: Validation error retains previous value
    /// - Validates: Requirement 4.11 (Retain previous value on validation failure)
    @MainActor
    func testValidationErrorRetainsPreviousValue() async {
        // Given: Strategy is selected with valid configuration
        await viewModel.selectStrategy(.weeklyOption)
        let validConfig = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: 2.0,
            onlyOrders: false
        )
        await viewModel.saveConfiguration(validConfig)
        
        // When: Invalid premium is attempted
        var invalidConfig = validConfig
        invalidConfig.premiumPct = 0.05 // Below valid range
        await viewModel.saveConfiguration(invalidConfig)
        
        // Then: Previous valid value is retained
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.premiumPct, 2.0, accuracy: 0.01,
                       "Previous valid premiumPct should be retained")
    }
    
    // MARK: - Load Failure Tests
    
    /// Test: Load failure applies defaults
    /// - Validates: Requirement 4.10 (Display error on load failure and apply defaults)
    @MainActor
    func testLoadFailureAppliesDefaults() async {
        // Given: Repository will fail to load
        mockRepository.shouldFailLoad = true
        
        // When: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        
        // Then: Default values are applied
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.windowDays, WeeklyOptionConfiguration.default.windowDays,
                       "Default windowDays should be applied")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.lookbackDays, WeeklyOptionConfiguration.default.lookbackDays,
                       "Default lookbackDays should be applied")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.premiumPct, WeeklyOptionConfiguration.default.premiumPct,
                       accuracy: 0.01, "Default premiumPct should be applied")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.onlyOrders, WeeklyOptionConfiguration.default.onlyOrders,
                       "Default onlyOrders should be applied")
        
        // And: Load error state is set
        XCTAssertTrue(viewModel.loadState.hasError, "Load state should indicate error")
        XCTAssertNotNil(viewModel.loadErrorMessage, "Load error message should be set")
        
        // And: Configuration is still considered loaded (with defaults)
        XCTAssertTrue(viewModel.isConfigurationLoaded, "Configuration should be loaded even with defaults")
    }
    
    /// Test: No saved configuration applies defaults
    /// - Validates: Requirement 4.8 (Apply default values if no saved config)
    @MainActor
    func testNoSavedConfigurationAppliesDefaults() async {
        // Given: No configuration saved in repository
        mockRepository.savedConfiguration = nil
        mockRepository.shouldReturnNil = true
        
        // When: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        
        // Then: Default values are applied
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.windowDays, 5, "Default windowDays should be 5")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.lookbackDays, 180, "Default lookbackDays should be 180")
        XCTAssertEqual(viewModel.weeklyOptionConfiguration.premiumPct, 0.5, accuracy: 0.01, "Default premiumPct should be 0.5")
        XCTAssertFalse(viewModel.weeklyOptionConfiguration.onlyOrders, "Default onlyOrders should be false")
    }
    
    // MARK: - Run Analysis Tests
    
    /// Test: Can run analysis only when strategy selected and configuration loaded
    /// - Validates: Requirement 3.6 (Disable run analysis button when no strategy selected)
    @MainActor
    func testCanRunAnalysisRequiresLoadedConfiguration() async {
        // Given: No strategy selected
        XCTAssertFalse(viewModel.canRunAnalysis, "Should not be able to run without strategy")
        
        // When: Strategy is selected and watchlist has tickers
        viewModel.setWatchlistTickers(["AAPL", "GOOGL"])
        await viewModel.selectStrategy(.weeklyOption)
        
        // Then: Can run analysis
        XCTAssertTrue(viewModel.canRunAnalysis, "Should be able to run with strategy selected and watchlist populated")
    }
    
    /// Test: Cannot run analysis with validation error
    @MainActor
    func testCannotRunAnalysisWithValidationError() async {
        // Given: Strategy selected with valid configuration and watchlist
        viewModel.setWatchlistTickers(["AAPL", "GOOGL"])
        await viewModel.selectStrategy(.weeklyOption)
        XCTAssertTrue(viewModel.canRunAnalysis)
        
        // When: Validation error occurs
        var invalidConfig = viewModel.weeklyOptionConfiguration
        invalidConfig.premiumPct = 10.0 // Invalid
        await viewModel.saveConfiguration(invalidConfig)
        
        // Then: Cannot run analysis
        XCTAssertFalse(viewModel.canRunAnalysis, "Should not be able to run with validation error")
    }
    
    // MARK: - Error Clearing Tests
    
    /// Test: Clear error clears the current error state
    @MainActor
    func testClearErrorClearsState() async {
        // Given: An error state
        viewModel.showError = true
        
        // When: Error is cleared
        viewModel.clearError()
        
        // Then: Error state is cleared
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showError)
    }
    
    /// Test: Clear save error clears save failure state
    @MainActor
    func testClearSaveErrorClearsFailureState() async {
        // Given: Strategy is selected and save failed
        await viewModel.selectStrategy(.weeklyOption)
        mockRepository.shouldSucceed = false
        await viewModel.saveConfiguration(viewModel.weeklyOptionConfiguration)
        
        // Verify we're in failed state
        if case .failed = viewModel.saveState { } else {
            XCTFail("Should be in failed state")
        }
        
        // When: Save error is cleared
        viewModel.clearSaveError()
        
        // Then: Save state is idle
        if case .idle = viewModel.saveState { } else {
            XCTFail("Save state should be idle")
        }
    }
    
    // MARK: - Expiration Override Tests
    
    /// Test: Expiration override is nil on ViewModel initialization
    ///
    /// Verifies that when a new AnalysisViewModel is created (simulating app restart),
    /// the expiration override is nil. This ensures session-scoped behavior where
    /// the override does not persist across app restarts.
    ///
    /// - Validates: Requirement 3.4 (Reset on app restart)
    @MainActor
    func testExpirationOverrideIsNilOnInitialization() async {
        // Given: A freshly created AnalysisViewModel (simulates app restart)
        let freshViewModel = AnalysisViewModel(
            configurationRepository: mockRepository,
            validationService: validationService,
            userId: "test_user"
        )
        
        // Then: Expiration override should be nil
        XCTAssertNil(freshViewModel.expirationOverride,
                     "Expiration override should be nil on ViewModel initialization")
        XCTAssertFalse(freshViewModel.hasExpirationOverride,
                       "hasExpirationOverride should be false on initialization")
    }
    
    /// Test: Expiration override is not persisted to storage
    ///
    /// Verifies that when a configuration with an expiration override is saved and reloaded,
    /// the expiration override is not preserved. This ensures session-scoped behavior.
    ///
    /// - Validates: Requirement 3.4 (Reset on app restart)
    @MainActor
    func testExpirationOverrideIsNotPersisted() async {
        // Given: Strategy is selected
        await viewModel.selectStrategy(.weeklyOption)
        
        // And: User sets an expiration override
        let testDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week from now
        viewModel.setExpirationOverride(testDate)
        
        // Verify override is set
        XCTAssertNotNil(viewModel.expirationOverride, "Override should be set before save")
        
        // When: Configuration is saved
        await viewModel.saveConfiguration(viewModel.weeklyOptionConfiguration)
        
        // Then: The saved configuration should NOT include the expiration override
        // (verified by checking the saved StrategyConfiguration)
        if let savedConfig = mockRepository.lastSavedConfiguration {
            // expirationOverride should not be in the saved parameters
            XCTAssertNil(savedConfig.parameters["expirationOverride"],
                         "Expiration override should not be persisted in configuration parameters")
        }
        
        // And: When configuration is converted to/from StrategyConfiguration,
        // the expirationOverride should be lost
        let savedStrategyConfig = viewModel.weeklyOptionConfiguration.toStrategyConfiguration()
        let restoredConfig = WeeklyOptionConfiguration.from(savedStrategyConfig)
        
        XCTAssertNil(restoredConfig.expirationOverride,
                     "Expiration override should not survive round-trip through StrategyConfiguration")
    }
    
    /// Test: Expiration override resets when creating a new ViewModel (simulates app restart)
    ///
    /// Simulates the complete app restart cycle:
    /// 1. User sets an expiration override
    /// 2. User saves configuration
    /// 3. App "restarts" (new ViewModel created)
    /// 4. Configuration is loaded from saved data
    /// 5. Expiration override should be nil
    ///
    /// - Validates: Requirement 3.4 (Reset on app restart)
    @MainActor
    func testExpirationOverrideResetsOnAppRestart() async {
        // Given: Strategy is selected and user sets an expiration override
        await viewModel.selectStrategy(.weeklyOption)
        let testDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week from now
        viewModel.setExpirationOverride(testDate)
        
        // Save configuration
        await viewModel.saveConfiguration(viewModel.weeklyOptionConfiguration)
        
        // Verify override is set in current session
        XCTAssertNotNil(viewModel.expirationOverride, "Override should be set in current session")
        
        // When: "App restarts" - create a new ViewModel
        let restartedViewModel = AnalysisViewModel(
            configurationRepository: mockRepository,
            validationService: validationService,
            userId: "test_user"
        )
        
        // Load configuration in the "restarted" app
        await restartedViewModel.selectStrategy(.weeklyOption)
        
        // Then: Expiration override should be nil (reset on restart)
        XCTAssertNil(restartedViewModel.expirationOverride,
                     "Expiration override should be nil after app restart")
        XCTAssertFalse(restartedViewModel.hasExpirationOverride,
                       "hasExpirationOverride should be false after app restart")
        
        // But other configuration values should be preserved
        XCTAssertEqual(restartedViewModel.weeklyOptionConfiguration.windowDays,
                       viewModel.weeklyOptionConfiguration.windowDays,
                       "Other configuration values should be preserved after restart")
    }
    
    /// Test: WeeklyOptionConfiguration expirationOverride is excluded from Codable
    ///
    /// Verifies that expirationOverride is properly excluded from JSON encoding/decoding
    /// through the CodingKeys mechanism.
    ///
    /// - Validates: Requirement 3.4 (Reset on app restart)
    @MainActor
    func testWeeklyOptionConfigurationExcludesExpirationFromCodable() async {
        // Given: A configuration with expiration override set
        let testDate = Date()
        let configWithOverride = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: 0.5,
            onlyOrders: false,
            expirationOverride: testDate
        )
        
        // When: Configuration is encoded and decoded (simulating persistence)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let encodedData = try encoder.encode(configWithOverride)
            let decodedConfig = try decoder.decode(WeeklyOptionConfiguration.self, from: encodedData)
            
            // Then: expirationOverride should be nil after decoding
            XCTAssertNil(decodedConfig.expirationOverride,
                         "Expiration override should be nil after JSON decode (not persisted)")
            
            // But other values should be preserved
            XCTAssertEqual(decodedConfig.windowDays, configWithOverride.windowDays)
            XCTAssertEqual(decodedConfig.lookbackDays, configWithOverride.lookbackDays)
            XCTAssertEqual(decodedConfig.premiumPct, configWithOverride.premiumPct, accuracy: 0.01)
            XCTAssertEqual(decodedConfig.onlyOrders, configWithOverride.onlyOrders)
        } catch {
            XCTFail("Encoding/decoding should not fail: \(error)")
        }
    }
}

// MARK: - Mock Configuration Repository

/// Mock implementation of ConfigurationRepository for testing
final class MockConfigurationRepository: ConfigurationRepository {
    
    var savedConfiguration: StrategyConfiguration?
    var lastSavedConfiguration: StrategyConfiguration?
    var saveCalled = false
    var shouldSucceed = true
    var shouldFailLoad = false
    var shouldReturnNil = false
    
    func save(configuration: StrategyConfiguration, for userId: String) async throws -> ConfigurationSaveResult {
        saveCalled = true
        lastSavedConfiguration = configuration
        
        if shouldSucceed {
            return .success(savedAt: Date())
        } else {
            throw ConfigurationRepositoryError.saveFailed(reason: "Mock save failure")
        }
    }
    
    func load(strategyId: String, for userId: String) async throws -> StrategyConfiguration {
        if shouldFailLoad {
            throw ConfigurationRepositoryError.loadFailed(reason: "Mock load failure")
        }
        
        if shouldReturnNil || savedConfiguration == nil {
            // Return default configuration
            return WeeklyOptionConfiguration.default.toStrategyConfiguration()
        }
        
        return savedConfiguration!
    }
    
    func delete(strategyId: String, for userId: String) async throws {
        savedConfiguration = nil
    }
}
