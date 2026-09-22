//
//  AnalysisViewModel.swift
//  TradingGuru
//
//  ViewModel for strategy selection and configuration management.
//  Manages strategy selection state, configuration persistence, and validation.
//

import Foundation
import Observation

/// Represents an available trading strategy for selection.
///
/// Contains display information and identifier for strategy selection dropdown.
struct AvailableStrategy: Identifiable, Hashable {
    /// Unique identifier for the strategy
    let id: String
    
    /// Display name shown in the dropdown
    let name: String
    
    /// Short name for compact display
    let shortName: String
    
    /// Description of the strategy
    let description: String
    
    /// Factory method for Weekly Option Strategy
    /// - Validates: Requirement 3.2 (Include Weekly_Option_Strategy as available option)
    static let weeklyOption = AvailableStrategy(
        id: WeeklyOptionConfiguration.strategyId,
        name: "Weekly Option Strategy",
        shortName: "Weekly Option",
        description: "Analyzes rolling window returns to identify CALL and PUT opportunities"
    )
}

// MARK: - Analysis Execution State

/// Represents the state of analysis execution for display purposes.
/// - Validates: Requirements 5.5, 5.6, 5.7 (Analysis execution UI)
struct AnalysisExecutionState: Equatable {
    /// The total number of tickers being analyzed
    let total: Int
    
    /// The number of tickers completed so far
    let completed: Int
    
    /// The current ticker being analyzed (nil when complete)
    let currentTicker: String?
    
    /// Progress description for display
    /// - Validates: Requirement 5.7 (Show progress n/total)
    var progressDescription: String {
        if let ticker = currentTicker {
            return "Analyzing \(ticker)... (\(completed + 1)/\(total))"
        } else if completed == total && total > 0 {
            return "Analysis complete"
        } else {
            return "Analyzing \(completed)/\(total) tickers..."
        }
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    /// Creates a new AnalysisExecutionState.
    init(total: Int = 0, completed: Int = 0, currentTicker: String? = nil) {
        self.total = total
        self.completed = completed
        self.currentTicker = currentTicker
    }
    
    /// Initial/idle state
    static let idle = AnalysisExecutionState()
}

/// Represents an error encountered during analysis of a specific ticker.
/// - Validates: Requirements 5.5, 5.6 (Error indicators and insufficient data messages)
struct TickerAnalysisError: Identifiable, Equatable {
    let id = UUID()
    
    /// The ticker symbol that failed
    let ticker: String
    
    /// The error type
    let errorType: TickerErrorType
    
    /// User-friendly error message using the error catalog.
    /// - Validates: Requirements 5.5, 5.6 (Display appropriate error messages)
    var message: String {
        switch errorType {
        case .fetchFailed:
            return ErrorMessageCatalog.AnalysisExecution.dataFetchFailed(ticker)
        case .insufficientData:
            return ErrorMessageCatalog.AnalysisExecution.insufficientData(ticker)
        case .unknown:
            return ErrorMessageCatalog.AnalysisExecution.dataFetchFailed(ticker)
        }
    }
    
    /// Detailed message for logging purposes.
    var detailedMessage: String {
        switch errorType {
        case .fetchFailed(let reason):
            return "\(ticker): Unable to fetch data - \(reason)"
        case .insufficientData(let available, let required):
            return "\(ticker): Insufficient price history (\(available) days available, \(required) required)"
        case .unknown(let reason):
            return "\(ticker): \(reason)"
        }
    }
    
    /// Creates a TickerAnalysisError from a MarketDataError.
    init(ticker: String, error: MarketDataError) {
        self.ticker = ticker
        switch error {
        case .fetchFailed(_, let reason):
            self.errorType = .fetchFailed(reason: reason)
        case .insufficientData(_, let required, let available):
            self.errorType = .insufficientData(available: available, required: required)
        case .invalidTicker:
            self.errorType = .fetchFailed(reason: "Invalid ticker symbol")
        case .networkError(let underlying):
            self.errorType = .fetchFailed(reason: underlying)
        case .rateLimitExceeded:
            self.errorType = .fetchFailed(reason: "Rate limit exceeded")
        case .invalidDataFormat:
            self.errorType = .fetchFailed(reason: "Invalid data format")
        }
    }
    
    /// Creates a TickerAnalysisError from a generic error.
    init(ticker: String, genericError: Error) {
        self.ticker = ticker
        self.errorType = .unknown(reason: genericError.localizedDescription)
    }
}

/// Type of error encountered during ticker analysis.
enum TickerErrorType: Equatable {
    /// Failed to fetch data for the ticker
    /// - Validates: Requirement 5.5 (Display error indicator for failed tickers)
    case fetchFailed(reason: String)
    
    /// Insufficient data available for analysis
    /// - Validates: Requirement 5.6 (Display message indicating insufficient data)
    case insufficientData(available: Int, required: Int)
    
    /// Unknown error
    case unknown(reason: String)
    
    /// Whether this is an insufficient data error
    var isInsufficientData: Bool {
        if case .insufficientData = self { return true }
        return false
    }
}

/// ViewModel for managing strategy selection and configuration.
///
/// Connects the AnalysisView to strategy selection logic, configuration display,
/// and persistence through ConfigurationRepository.
/// Handles:
/// - Strategy dropdown population and selection
/// - Configuration interface loading
/// - Configuration persistence with validation
/// - Run analysis button state management
/// - Analysis execution with progress tracking
///
/// - Validates: Requirement 3.1 (Display strategy selection dropdown with placeholder)
/// - Validates: Requirement 3.2 (Include Weekly_Option_Strategy as available option)
/// - Validates: Requirement 3.3 (Load configuration interface within 2 seconds)
/// - Validates: Requirement 3.6 (Disable run analysis button when no strategy selected)
/// - Validates: Requirement 4.6 (Persist configuration to database with confirmation)
/// - Validates: Requirement 4.7 (Load previously saved configuration values)
/// - Validates: Requirement 4.8 (Apply default values if no saved config)
/// - Validates: Requirement 4.9 (Display error on save failure, retain user values)
/// - Validates: Requirement 4.10 (Display error on load failure, apply defaults)
/// - Validates: Requirement 4.11 (Validation with error message, retain previous value)
/// - Validates: Requirement 5.5 (Display error indicator for failed tickers, continue processing)
/// - Validates: Requirement 5.6 (Display message for insufficient data tickers)
/// - Validates: Requirement 5.7 (Display loading indicator with progress n/total)
@Observable
final class AnalysisViewModel {
    
    // MARK: - Dependencies
    
    /// Repository for configuration persistence
    private let configurationRepository: ConfigurationRepository
    
    /// Service for configuration validation
    private let validationService: ConfigurationValidation
    
    /// The strategy for analysis execution
    private let strategy: WeeklyOptionStrategy
    
    /// Calculator for expiration date validation
    /// - Validates: Requirement 3.6 (Valid trading day validation)
    private let expirationDateCalculator: ExpirationDateCalculation
    
    /// Current user ID for configuration storage
    private var userId: String
    
    // MARK: - Published State
    
    /// The currently selected strategy, or nil if none selected
    /// - Validates: Requirement 3.1 (Placeholder prompt when no strategy selected)
    private(set) var selectedStrategy: AvailableStrategy?
    
    /// Whether the configuration interface is currently loading
    /// - Validates: Requirement 3.3 (Load configuration interface within 2 seconds)
    private(set) var isLoadingConfiguration = false
    
    /// Whether the analysis is currently running
    /// - Validates: Requirement 5.7 (Display loading indicator while running)
    private(set) var isRunningAnalysis = false
    
    /// Current error to display, if any
    private(set) var currentError: AnalysisError?
    
    /// Whether to show the error alert
    var showError = false
    
    /// Whether the configuration interface has been loaded successfully
    private(set) var isConfigurationLoaded = false
    
    /// Current save state for configuration
    /// - Validates: Requirement 4.6 (Display confirmation indicator on successful save)
    /// - Validates: Requirement 4.9 (Display error on save failure)
    private(set) var saveState: ConfigurationSaveState = .idle
    
    /// Current load state for configuration data
    /// - Validates: Requirement 4.10 (Display error on load failure, apply defaults)
    private(set) var loadState: ConfigurationDataLoadState = .idle
    
    /// Validation error message for current configuration
    /// - Validates: Requirement 4.11 (Display error message for invalid values)
    private(set) var validationError: String?
    
    // MARK: - Analysis Execution State
    
    /// The current analysis execution state for progress display
    /// - Validates: Requirement 5.7 (Show progress n/total)
    private(set) var analysisExecutionState: AnalysisExecutionState = .idle
    
    /// Errors encountered during analysis for individual tickers
    /// - Validates: Requirements 5.5, 5.6 (Error indicators and insufficient data messages)
    private(set) var tickerErrors: [TickerAnalysisError] = []
    
    /// The latest analysis results (stored for potential future use/display)
    private(set) var analysisResults: [AnalysisResult] = []
    
    /// The tickers to analyze (from watchlist)
    var watchlistTickers: [String] = []
    
    // MARK: - Expiration Override State
    
    /// User-selected expiration date override for the current session.
    ///
    /// When set, this date will be used instead of the calculated default expiration date
    /// for all subsequent analyses in the session. The override is session-scoped and
    /// resets to `nil` when the app is terminated and relaunched.
    ///
    /// - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
    /// - Validates: Requirement 3.4 (Reset on app restart)
    private(set) var expirationOverride: Date?
    
    /// Validation error message for expiration date selection.
    /// - Validates: Requirement 3.7 (Display error for invalid expiration dates)
    private(set) var expirationValidationError: String?
    
    // MARK: - Available Strategies
    
    /// List of all available trading strategies.
    /// - Validates: Requirement 3.2 (Include Weekly_Option_Strategy as available option)
    let availableStrategies: [AvailableStrategy] = [
        .weeklyOption
    ]
    
    // MARK: - Computed Properties
    
    /// Whether the user has selected a strategy.
    var hasSelectedStrategy: Bool {
        selectedStrategy != nil
    }
    
    /// Whether the run analysis button should be enabled.
    /// - Validates: Requirement 3.6 (Disable run analysis button when no strategy selected)
    var canRunAnalysis: Bool {
        hasSelectedStrategy && isConfigurationLoaded && !isRunningAnalysis && !isLoadingConfiguration && validationError == nil && !watchlistTickers.isEmpty
    }
    
    /// The identifier of the currently selected strategy, or nil.
    var selectedStrategyId: String? {
        selectedStrategy?.id
    }
    
    /// Whether save operation is in progress
    var isSaving: Bool {
        saveState.isSaving
    }
    
    /// Whether the last save was successful
    var saveWasSuccessful: Bool {
        saveState.isSuccess
    }
    
    /// Error message from save operation
    var saveErrorMessage: String? {
        saveState.errorMessage
    }
    
    /// Error message from load operation
    var loadErrorMessage: String? {
        loadState.errorMessage
    }
    
    /// Whether there are errors from the last analysis run
    var hasTickerErrors: Bool {
        !tickerErrors.isEmpty
    }
    
    /// Number of successful ticker analyses
    var successfulTickerCount: Int {
        analysisResults.count / 2 // Each ticker generates 2 results (CALL and PUT)
    }
    
    /// Number of failed ticker analyses
    var failedTickerCount: Int {
        tickerErrors.count
    }
    
    // MARK: - Configuration State
    
    /// The Weekly Option configuration (used when Weekly Option Strategy is selected)
    var weeklyOptionConfiguration: WeeklyOptionConfiguration = .default
    
    // MARK: - Initialization
    
    /// Creates a new AnalysisViewModel instance with injected dependencies.
    /// - Parameters:
    ///   - configurationRepository: Repository for configuration persistence
    ///   - validationService: Service for configuration validation
    ///   - strategy: The Weekly Option Strategy for analysis execution
    ///   - expirationDateCalculator: Calculator for expiration date validation (defaults to ExpirationDateCalculator)
    ///   - userId: Current user ID (defaults to "current_user" for testing)
    /// - Validates: Requirement 3.4 (Reset on app restart - expirationOverride is nil on initialization)
    init(
        configurationRepository: ConfigurationRepository? = nil,
        validationService: ConfigurationValidation? = nil,
        strategy: WeeklyOptionStrategy? = nil,
        expirationDateCalculator: ExpirationDateCalculation? = nil,
        userId: String = "current_user"
    ) {
        // Use provided dependencies or create defaults
        self.configurationRepository = configurationRepository ?? ConfigurationRepositoryImpl.forTesting()
        self.validationService = validationService ?? ConfigurationValidationService()
        self.strategy = strategy ?? WeeklyOptionStrategy()
        self.expirationDateCalculator = expirationDateCalculator ?? ExpirationDateCalculator()
        self.userId = userId
        
        // Start with no strategy selected
        self.selectedStrategy = nil
        self.isConfigurationLoaded = false
        
        // Session-scoped state starts as nil (reset on app restart)
        // - Validates: Requirement 3.4 (Reset on app restart)
        self.expirationOverride = nil
    }
    
    // MARK: - User Management
    
    /// Updates the current user ID.
    /// - Parameter newUserId: The new user ID
    func setUserId(_ newUserId: String) {
        self.userId = newUserId
    }
    
    /// Sets the watchlist tickers for analysis.
    /// - Parameter tickers: Array of ticker symbols to analyze
    func setWatchlistTickers(_ tickers: [String]) {
        self.watchlistTickers = tickers
    }
    
    // MARK: - Expiration Override Management
    
    /// Sets the expiration date override for the current session.
    ///
    /// Validates the date before setting. If the date is invalid (weekend or market holiday),
    /// displays an error message and does not update the override.
    ///
    /// - Parameter date: The date to use as the expiration override
    /// - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
    /// - Validates: Requirement 3.6 (Valid trading day validation)
    /// - Validates: Requirement 3.7 (Display error for invalid dates)
    @MainActor
    func setExpirationOverride(_ date: Date) {
        // Validate the date using the expiration date calculator
        if expirationDateCalculator.isValidExpirationDate(date) {
            // Clear any previous validation error
            expirationValidationError = nil
            
            // Set the override
            expirationOverride = date
            
            // Also update the weeklyOptionConfiguration so it's used in analysis
            weeklyOptionConfiguration.expirationOverride = date
        } else {
            // Invalid date - set error message
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            
            if weekday == 1 || weekday == 7 {
                // Weekend
                let dayName = weekday == 1 ? "Sunday" : "Saturday"
                expirationValidationError = "Market is closed on \(dayName). Please select a weekday."
            } else {
                // Market holiday
                expirationValidationError = "Market is closed on this date (holiday). Please select another date."
            }
            
            // Don't update the override
        }
    }
    
    /// Clears the expiration date override, returning to automatic calculation.
    ///
    /// After clearing, the system will use the calculated default expiration date
    /// (typically the next Friday, or Thursday if Friday is a market holiday).
    ///
    /// - Validates: Requirement 3.2 (Return to automatic calculation when override is cleared)
    @MainActor
    func clearExpirationOverride() {
        expirationOverride = nil
        expirationValidationError = nil
        weeklyOptionConfiguration.expirationOverride = nil
    }
    
    /// Returns the effective expiration date that will be used for analysis.
    ///
    /// If an override is set, returns the override date. Otherwise, returns the
    /// calculated default expiration date.
    ///
    /// - Returns: The expiration date that will be used for analysis
    var effectiveExpirationDate: Date {
        expirationOverride ?? expirationDateCalculator.calculateDefaultExpiration(from: Date())
    }
    
    /// Whether a custom expiration override is currently set.
    var hasExpirationOverride: Bool {
        expirationOverride != nil
    }
    
    // MARK: - Strategy Selection
    
    /// Selects a strategy from the available options.
    ///
    /// Loads the configuration interface and saved configuration for the selected strategy.
    /// If loading fails, displays an error and allows retry.
    ///
    /// - Parameter strategy: The strategy to select, or nil to clear selection
    /// - Validates: Requirement 3.1 (Display placeholder when no strategy selected)
    /// - Validates: Requirement 3.3 (Load configuration interface within 2 seconds)
    /// - Validates: Requirement 3.4 (Display error and allow retry on load failure)
    /// - Validates: Requirement 4.7 (Load previously saved configuration)
    /// - Validates: Requirement 4.8 (Apply defaults if no saved config)
    /// - Validates: Requirement 4.10 (Display error on load failure, apply defaults)
    @MainActor
    func selectStrategy(_ strategy: AvailableStrategy?) async {
        // Clear previous state
        selectedStrategy = strategy
        isConfigurationLoaded = false
        currentError = nil
        validationError = nil
        saveState = .idle
        loadState = .idle
        
        guard let strategy = strategy else {
            return
        }
        
        // Load configuration interface
        isLoadingConfiguration = true
        loadState = .loading
        
        do {
            // Load configuration from repository (must complete within 2 seconds per Requirement 3.3)
            try await loadConfiguration(for: strategy)
            isConfigurationLoaded = true
            isLoadingConfiguration = false
        } catch let error as AnalysisError {
            isLoadingConfiguration = false
            currentError = error
            showError = true
        } catch {
            isLoadingConfiguration = false
            currentError = .configurationLoadFailed
            showError = true
        }
    }
    
    /// Loads the configuration for a specific strategy from the repository.
    ///
    /// - Parameter strategy: The strategy to load configuration for
    /// - Throws: AnalysisError if loading fails
    /// - Validates: Requirement 4.7 (Load previously saved configuration values)
    /// - Validates: Requirement 4.8 (Apply default values if no saved config)
    /// - Validates: Requirement 4.10 (Display error on load failure, apply defaults)
    private func loadConfiguration(for strategy: AvailableStrategy) async throws {
        switch strategy.id {
        case WeeklyOptionConfiguration.strategyId:
            do {
                // Try to load from repository
                let strategyConfig = try await configurationRepository.load(
                    strategyId: strategy.id,
                    for: userId
                )
                
                // Convert to WeeklyOptionConfiguration
                weeklyOptionConfiguration = WeeklyOptionConfiguration.from(strategyConfig)
                loadState = .loaded(strategyConfig)
                
            } catch let error as ConfigurationRepositoryError {
                // Apply defaults per Requirement 4.10
                weeklyOptionConfiguration = .default
                let defaultConfig = weeklyOptionConfiguration.toStrategyConfiguration()
                
                // Only show error for actual failures, not expected local-only mode
                switch error {
                case .databaseUnavailable:
                    // Local-only mode - silently use defaults, no error to display
                    loadState = .loaded(defaultConfig)
                default:
                    // Real error - show to user but allow them to continue with defaults
                    loadState = .failedWithDefaults(defaultConfig, error: error.catalogMessage)
                }
                
            } catch {
                // Unknown error - apply defaults
                weeklyOptionConfiguration = .default
                let defaultConfig = weeklyOptionConfiguration.toStrategyConfiguration()
                loadState = .failedWithDefaults(defaultConfig, error: ErrorMessageCatalog.StrategyConfiguration.loadFailed)
            }
            
        default:
            throw AnalysisError.unknownStrategy
        }
    }
    
    /// Retries loading the configuration for the currently selected strategy.
    ///
    /// - Validates: Requirement 3.4 (Allow retry on configuration load failure)
    @MainActor
    func retryLoadConfiguration() async {
        guard let strategy = selectedStrategy else { return }
        await selectStrategy(strategy)
    }
    
    // MARK: - Configuration Saving
    
    /// Saves the configuration for the currently selected strategy.
    ///
    /// Validates the configuration before saving. If validation fails,
    /// displays an error message and retains the previous value.
    ///
    /// - Parameter config: The configuration to save
    /// - Validates: Requirement 4.6 (Persist configuration to database with confirmation)
    /// - Validates: Requirement 4.9 (Display error on save failure, retain user values)
    /// - Validates: Requirement 4.11 (Don't save invalid value, retain previous)
    @MainActor
    func saveConfiguration(_ config: WeeklyOptionConfiguration) async {
        // Validate configuration before saving
        let validationResult = validationService.validateConfiguration(config)
        
        switch validationResult {
        case .success:
            // Clear any previous validation error
            validationError = nil
            
            // Update local configuration
            weeklyOptionConfiguration = config
            
            // Persist to repository
            await persistConfiguration(config)
            
        case .failure(let error):
            // Validation failed - display error and retain previous value
            // Validates: Requirement 4.11
            validationError = ConfigurationValidationService.errorMessage(for: error)
            // Don't update weeklyOptionConfiguration - retain previous valid value
        }
    }
    
    /// Persists the configuration to the repository.
    /// - Parameter config: The validated configuration to persist
    /// - Validates: Requirement 4.6 (Persist configuration with confirmation)
    /// - Validates: Requirement 4.9 (Display error on save failure, retain user values)
    private func persistConfiguration(_ config: WeeklyOptionConfiguration) async {
        saveState = .saving
        
        do {
            let strategyConfig = config.toStrategyConfiguration()
            let result = try await configurationRepository.save(
                configuration: strategyConfig,
                for: userId
            )
            
            // Update save state with success
            if let savedAt = result.savedAt {
                saveState = .saved(at: savedAt)
            } else {
                saveState = .saved(at: Date())
            }
            
            // Auto-dismiss success state after a delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if case .saved = self.saveState {
                    self.saveState = .idle
                }
            }
            
        } catch let error as ConfigurationRepositoryError {
            // Save failed - retain user's values per Requirement 4.9
            // weeklyOptionConfiguration already has the user's values
            saveState = .failed(error: error.catalogMessage)
            
        } catch {
            // Unknown error - use catalog message
            saveState = .failed(error: ErrorMessageCatalog.StrategyConfiguration.saveFailed)
        }
    }
    
    // MARK: - Validation
    
    /// Validates a premium percentage value.
    /// - Parameters:
    ///   - newValue: The new value to validate
    ///   - currentValue: The current value to retain on failure
    /// - Returns: The validated value to use
    /// - Validates: Requirement 4.11 (PREMIUM_PCT validation 0.1% to 5.0%)
    func validateAndUpdatePremiumPct(_ newValue: Double, currentValue: Double) -> Double {
        let result = validationService.validatePremiumPct(newValue, currentValue: currentValue)
        
        switch result {
        case .success(let validatedValue):
            validationError = nil
            return validatedValue
        case .failure(let error):
            validationError = ConfigurationValidationService.errorMessage(for: error)
            return currentValue // Retain previous value
        }
    }
    
    /// Clears the validation error.
    func clearValidationError() {
        validationError = nil
    }
    
    // MARK: - Run Analysis
    
    /// Initiates the analysis execution with progress tracking.
    ///
    /// Executes the Weekly Option Strategy batch analysis on the watchlist,
    /// providing real-time progress updates and collecting errors for display.
    ///
    /// - Validates: Requirement 5.5 (Display error indicator for failed tickers, continue processing)
    /// - Validates: Requirement 5.6 (Skip ticker with insufficient data, display message)
    /// - Validates: Requirement 5.7 (Display loading indicator with progress n/total)
    @MainActor
    func runAnalysis() async {
        guard canRunAnalysis else { return }
        guard !watchlistTickers.isEmpty else { return }
        
        // Ensure the expiration override is synced to the configuration
        // - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
        weeklyOptionConfiguration.expirationOverride = expirationOverride
        
        // Reset state for new analysis run
        isRunningAnalysis = true
        tickerErrors = []
        analysisResults = []
        analysisExecutionState = AnalysisExecutionState(total: watchlistTickers.count)
        
        // Execute batch analysis with progress reporting
        // - Validates: Requirement 5.7 (Show progress n/total)
        let results = await strategy.analyzeBatch(
            tickers: watchlistTickers,
            configuration: weeklyOptionConfiguration,
            progressHandler: { [weak self] progress in
                guard let self = self else { return }
                
                // Update execution state on main thread
                Task { @MainActor in
                    self.updateAnalysisProgress(progress)
                }
            }
        )
        
        // Process results and collect errors
        processAnalysisResults(results)
        
        // Update final state
        analysisExecutionState = AnalysisExecutionState(
            total: watchlistTickers.count,
            completed: watchlistTickers.count,
            currentTicker: nil
        )
        isRunningAnalysis = false
        
        // Show error alert if all tickers failed
        if tickerErrors.count == watchlistTickers.count && watchlistTickers.count > 0 {
            currentError = .analysisFailed(message: ErrorMessageCatalog.AnalysisExecution.allTickersFailed)
            showError = true
        }
    }
    
    /// Updates the analysis progress state from the progress handler.
    /// - Parameter progress: The current analysis progress
    /// - Validates: Requirement 5.7 (Show progress n/total)
    @MainActor
    private func updateAnalysisProgress(_ progress: AnalysisProgress) {
        analysisExecutionState = AnalysisExecutionState(
            total: progress.total,
            completed: progress.completed,
            currentTicker: progress.currentTicker
        )
        
        // Collect errors as they occur
        // - Validates: Requirement 5.5 (Display error indicator for failed tickers)
        // - Validates: Requirement 5.6 (Display message for insufficient data)
        for error in progress.errors {
            let tickerError = TickerAnalysisError(
                ticker: error.ticker ?? "Unknown",
                error: error
            )
            if !tickerErrors.contains(where: { $0.ticker == tickerError.ticker }) {
                tickerErrors.append(tickerError)
            }
        }
    }
    
    /// Processes the batch analysis results and collects errors.
    /// - Parameter results: Dictionary mapping tickers to their results or errors
    /// - Validates: Requirement 5.5 (Continue processing remaining tickers when individual tickers fail)
    private func processAnalysisResults(_ results: [String: Result<[AnalysisResult], Error>]) {
        for (ticker, result) in results {
            switch result {
            case .success(let tickerResults):
                analysisResults.append(contentsOf: tickerResults)
                
            case .failure(let error):
                let tickerError: TickerAnalysisError
                if let marketError = error as? MarketDataError {
                    tickerError = TickerAnalysisError(ticker: ticker, error: marketError)
                } else {
                    tickerError = TickerAnalysisError(ticker: ticker, genericError: error)
                }
                
                // Only add if not already present
                if !tickerErrors.contains(where: { $0.ticker == ticker }) {
                    tickerErrors.append(tickerError)
                }
            }
        }
    }
    
    /// Clears the ticker errors from the previous analysis run.
    @MainActor
    func clearTickerErrors() {
        tickerErrors = []
    }
    
    /// Clears the analysis results from the previous run.
    @MainActor
    func clearAnalysisResults() {
        analysisResults = []
        tickerErrors = []
        analysisExecutionState = .idle
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error state.
    @MainActor
    func clearError() {
        currentError = nil
        showError = false
    }
    
    /// Clears the save error state.
    @MainActor
    func clearSaveError() {
        if case .failed = saveState {
            saveState = .idle
        }
    }
    
    /// Resets save state to idle.
    @MainActor
    func resetSaveState() {
        saveState = .idle
    }
}

// MARK: - Analysis Errors

/// Errors that can occur during strategy analysis.
enum AnalysisError: Error, Equatable {
    /// Failed to load the configuration interface for a strategy
    /// - Validates: Requirement 3.4 (Display error on configuration load failure)
    case configurationLoadFailed
    
    /// The selected strategy is not recognized
    case unknownStrategy
    
    /// No strategy is selected
    case noStrategySelected
    
    /// Analysis execution failed
    case analysisFailed(message: String)
    
    /// Configuration validation failed
    /// - Validates: Requirement 4.11 (Validation error display)
    case validationFailed(message: String)
    
    /// Configuration save failed
    /// - Validates: Requirement 4.9 (Save failure display)
    case saveFailed(message: String)
}

extension AnalysisError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .configurationLoadFailed:
            return "Failed to load strategy configuration. Please try again or select a different strategy."
        case .unknownStrategy:
            return "The selected strategy is not available."
        case .noStrategySelected:
            return "Please select a strategy before running analysis."
        case .analysisFailed(let message):
            return message
        case .validationFailed(let message):
            return message
        case .saveFailed(let message):
            return message
        }
    }
    
    /// User-friendly error message from the error catalog.
    var catalogMessage: String {
        switch self {
        case .configurationLoadFailed:
            return ErrorMessageCatalog.StrategyConfiguration.loadFailed
        case .unknownStrategy:
            return "The selected strategy is not available."
        case .noStrategySelected:
            return "Please select a strategy before running analysis."
        case .analysisFailed:
            return ErrorMessageCatalog.AnalysisExecution.allTickersFailed
        case .validationFailed:
            return ErrorMessageCatalog.StrategyConfiguration.invalidPremiumRange
        case .saveFailed:
            return ErrorMessageCatalog.StrategyConfiguration.saveFailed
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension AnalysisViewModel {
    /// Creates a preview instance with no strategy selected
    static var preview: AnalysisViewModel {
        AnalysisViewModel()
    }
    
    /// Creates a preview instance with Weekly Option Strategy selected
    static var previewWithStrategy: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.watchlistTickers = ["AAPL", "GOOGL", "MSFT"]
        return viewModel
    }
    
    /// Creates a preview instance in loading state
    static var previewLoading: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isLoadingConfiguration = true
        return viewModel
    }
    
    /// Creates a preview instance with save success state
    static var previewSaveSuccess: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.saveState = .saved(at: Date())
        return viewModel
    }
    
    /// Creates a preview instance with save error state
    static var previewSaveError: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.saveState = .failed(error: "Unable to save configuration. Please try again.")
        return viewModel
    }
    
    /// Creates a preview instance with validation error
    static var previewValidationError: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.validationError = "Premium must be between 0.1% and 5.0%. Please enter a value within this range."
        return viewModel
    }
    
    /// Creates a preview instance with load error (using defaults)
    static var previewLoadError: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.loadState = .failedWithDefaults(
            WeeklyOptionConfiguration.default.toStrategyConfiguration(),
            error: "Unable to load saved settings. Using defaults."
        )
        return viewModel
    }
    
    /// Creates a preview instance showing analysis in progress
    /// - Validates: Requirement 5.7 (Preview of progress display)
    static var previewAnalysisRunning: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.isRunningAnalysis = true
        viewModel.watchlistTickers = ["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN"]
        viewModel.analysisExecutionState = AnalysisExecutionState(
            total: 5,
            completed: 2,
            currentTicker: "MSFT"
        )
        return viewModel
    }
    
    /// Creates a preview instance showing analysis with errors
    /// - Validates: Requirements 5.5, 5.6 (Preview of error display)
    static var previewAnalysisWithErrors: AnalysisViewModel {
        let viewModel = AnalysisViewModel()
        viewModel.selectedStrategy = .weeklyOption
        viewModel.isConfigurationLoaded = true
        viewModel.watchlistTickers = ["AAPL", "INVALID", "NEWCO"]
        viewModel.tickerErrors = [
            TickerAnalysisError(
                ticker: "INVALID",
                error: .fetchFailed(ticker: "INVALID", reason: "Unable to fetch data")
            ),
            TickerAnalysisError(
                ticker: "NEWCO",
                error: .insufficientData(ticker: "NEWCO", required: 180, available: 30)
            )
        ]
        viewModel.analysisExecutionState = AnalysisExecutionState(
            total: 3,
            completed: 3,
            currentTicker: nil
        )
        return viewModel
    }
}
#endif
