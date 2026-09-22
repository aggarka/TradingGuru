//
//  DatabaseRetryService.swift
//  TradingGuru
//
//  Service providing retry logic with exponential backoff for database operations.
//

import Foundation

// MARK: - Database Retry Result

/// Result of a database operation with retry information.
/// - Validates: Requirement 7.6 (Track retry attempts)
/// - Validates: Requirement 7.7 (Provide appropriate messages after exhausting retries)
struct DatabaseRetryResult<T> {
    /// The result value if successful
    let value: T?
    
    /// Whether the operation ultimately succeeded
    let success: Bool
    
    /// Number of attempts made (1 = first try, 2-4 = retries)
    let attemptsMade: Int
    
    /// The final error if operation failed
    let error: DatabaseRetryError?
    
    /// Creates a successful result.
    static func success(_ value: T, attempts: Int) -> DatabaseRetryResult<T> {
        DatabaseRetryResult(
            value: value,
            success: true,
            attemptsMade: attempts,
            error: nil
        )
    }
    
    /// Creates a failed result after exhausting retries.
    static func failure(error: DatabaseRetryError, attempts: Int) -> DatabaseRetryResult<T> {
        DatabaseRetryResult(
            value: nil,
            success: false,
            attemptsMade: attempts,
            error: error
        )
    }
}

// MARK: - Database Retry Error

/// Errors specific to database retry operations.
/// - Validates: Requirement 7.6 (Display error message indicating operation that failed)
/// - Validates: Requirement 7.7 (Suggest checking network connectivity after exhausting retries)
enum DatabaseRetryError: Error, Equatable {
    /// All retry attempts exhausted.
    /// Contains the operation name and underlying error description.
    case retriesExhausted(operation: String, lastError: String)
    
    /// Operation was cancelled before completion.
    case cancelled
    
    /// A specific operation failed with retryable error.
    case operationFailed(operation: String, reason: String)
    
    /// User-friendly error message for display.
    /// - Validates: Requirement 7.7 (Display message suggesting network check)
    var userMessage: String {
        switch self {
        case .retriesExhausted:
            return "Operation could not be completed. Please check your connection and try again."
        case .cancelled:
            return "Operation was cancelled."
        case .operationFailed(let operation, let reason):
            return "\(operation) failed: \(reason)"
        }
    }
    
    /// Detailed error message for logging.
    var detailedMessage: String {
        switch self {
        case .retriesExhausted(let operation, let lastError):
            return "Operation '\(operation)' failed after maximum retry attempts. Last error: \(lastError)"
        case .cancelled:
            return "Operation was cancelled by user or system."
        case .operationFailed(let operation, let reason):
            return "Operation '\(operation)' failed: \(reason)"
        }
    }
}

extension DatabaseRetryError: LocalizedError {
    var errorDescription: String? {
        return userMessage
    }
}

// MARK: - Database Retry Configuration

/// Configuration for retry behavior.
/// - Validates: Design doc (Exponential backoff: 1s, 2s, 4s with max 3 attempts)
struct DatabaseRetryConfiguration {
    /// Maximum number of retry attempts (not including initial attempt).
    /// Total attempts = 1 initial + maxRetryAttempts
    let maxRetryAttempts: Int
    
    /// Base delay in seconds for exponential backoff.
    let baseDelaySeconds: TimeInterval
    
    /// Maximum delay in seconds (cap for exponential growth).
    let maxDelaySeconds: TimeInterval
    
    /// Multiplier for exponential backoff (delay * multiplier^attempt).
    let backoffMultiplier: Double
    
    /// Default configuration per design document.
    /// Exponential backoff: 1s, 2s, 4s (max 3 retry attempts after initial)
    /// - Validates: Design doc (1s, 2s, 4s delays, max 3 attempts)
    static let `default` = DatabaseRetryConfiguration(
        maxRetryAttempts: 3,
        baseDelaySeconds: 1.0,
        maxDelaySeconds: 4.0,
        backoffMultiplier: 2.0
    )
    
    /// Calculates delay for a given retry attempt (0-indexed).
    /// - Parameter attempt: The retry attempt number (0 for first retry, 1 for second, etc.)
    /// - Returns: Delay in seconds before the retry
    func delay(for attempt: Int) -> TimeInterval {
        // Exponential backoff: base * multiplier^attempt
        // Attempt 0: 1.0 * 2^0 = 1.0s
        // Attempt 1: 1.0 * 2^1 = 2.0s
        // Attempt 2: 1.0 * 2^2 = 4.0s
        let calculatedDelay = baseDelaySeconds * pow(backoffMultiplier, Double(attempt))
        return min(calculatedDelay, maxDelaySeconds)
    }
}

// MARK: - Database Retry Delegate

/// Delegate protocol for receiving retry status updates.
/// Useful for updating UI with retry progress.
protocol DatabaseRetryDelegate: AnyObject {
    /// Called when a retry attempt is about to start.
    /// - Parameters:
    ///   - attemptNumber: The attempt number (2 = first retry, 3 = second retry, etc.)
    ///   - maxAttempts: Total maximum attempts (initial + retries)
    ///   - operation: Name of the operation being retried
    func retryWillStart(attemptNumber: Int, maxAttempts: Int, operation: String)
    
    /// Called when all retry attempts have been exhausted.
    /// - Parameters:
    ///   - operation: Name of the operation that failed
    ///   - error: The final error
    func retriesExhausted(operation: String, error: Error)
}

// MARK: - Database Retry Service Protocol

/// Protocol for database retry service.
/// - Validates: Requirement 7.6 (Retry failed operations up to 3 times)
/// - Validates: Requirement 7.7 (Display appropriate message after exhausting retries)
protocol DatabaseRetryServiceProtocol {
    /// The current retry configuration.
    var configuration: DatabaseRetryConfiguration { get }
    
    /// Delegate for receiving retry status updates.
    var delegate: DatabaseRetryDelegate? { get set }
    
    /// Executes an async operation with automatic retry on failure.
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - operationName: Human-readable name for the operation (for error messages)
    ///   - shouldRetry: Closure to determine if a specific error should trigger retry
    /// - Returns: DatabaseRetryResult containing the result or error
    func execute<T>(
        operation: @escaping () async throws -> T,
        operationName: String,
        shouldRetry: @escaping (Error) -> Bool
    ) async -> DatabaseRetryResult<T>
    
    /// Executes an async operation with automatic retry, using default retry criteria.
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - operationName: Human-readable name for the operation
    /// - Returns: DatabaseRetryResult containing the result or error
    func execute<T>(
        operation: @escaping () async throws -> T,
        operationName: String
    ) async -> DatabaseRetryResult<T>
}

// MARK: - Database Retry Service Implementation

/// Service providing retry logic with exponential backoff for database operations.
///
/// This service wraps async database operations and automatically retries them
/// on failure using exponential backoff delays (1s, 2s, 4s).
///
/// Usage:
/// ```swift
/// let retryService = DatabaseRetryService()
/// let result = await retryService.execute(
///     operation: { try await repository.getWatchlist(for: userId) },
///     operationName: "Fetch watchlist"
/// )
/// if result.success, let watchlist = result.value {
///     // Use watchlist
/// } else if let error = result.error {
///     // Display error.userMessage to user
/// }
/// ```
///
/// - Validates: Requirement 7.6 (Retry up to 3 times with error message)
/// - Validates: Requirement 7.7 (Display message suggesting network check after exhausting retries)
final class DatabaseRetryService: DatabaseRetryServiceProtocol {
    
    // MARK: - Properties
    
    /// The retry configuration.
    let configuration: DatabaseRetryConfiguration
    
    /// Delegate for receiving retry status updates.
    weak var delegate: DatabaseRetryDelegate?
    
    // MARK: - Initialization
    
    /// Creates a new DatabaseRetryService instance.
    /// - Parameter configuration: The retry configuration (defaults to standard exponential backoff)
    init(configuration: DatabaseRetryConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Executes an async operation with automatic retry on failure.
    ///
    /// Implements exponential backoff retry logic:
    /// - Attempt 1: Execute immediately
    /// - Attempt 2: Wait 1 second, then retry
    /// - Attempt 3: Wait 2 seconds, then retry
    /// - Attempt 4: Wait 4 seconds, then retry
    ///
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - operationName: Human-readable name for the operation (for error messages)
    ///   - shouldRetry: Closure to determine if a specific error should trigger retry
    /// - Returns: DatabaseRetryResult containing the result or error
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    nonisolated func execute<T>(
        operation: @escaping () async throws -> T,
        operationName: String,
        shouldRetry: @escaping (Error) -> Bool
    ) async -> DatabaseRetryResult<T> {
        
        let maxAttempts = 1 + configuration.maxRetryAttempts // 1 initial + 3 retries = 4 total
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                // Execute the operation
                let result = try await operation()
                return .success(result, attempts: attempt)
                
            } catch {
                lastError = error
                
                // Check if we should retry
                let isLastAttempt = attempt == maxAttempts
                let canRetry = !isLastAttempt && shouldRetry(error)
                
                if canRetry {
                    // Calculate delay for this retry (attempt - 1 because delays are 0-indexed)
                    let retryNumber = attempt - 1 // 0 for first retry, 1 for second, etc.
                    let delay = configuration.delay(for: retryNumber)
                    
                    // Notify delegate about upcoming retry
                    await MainActor.run {
                        delegate?.retryWillStart(
                            attemptNumber: attempt + 1,
                            maxAttempts: maxAttempts,
                            operation: operationName
                        )
                    }
                    
                    // Wait before retrying
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                } else if isLastAttempt {
                    // All retries exhausted
                    let retryError = DatabaseRetryError.retriesExhausted(
                        operation: operationName,
                        lastError: error.localizedDescription
                    )
                    
                    // Notify delegate
                    await MainActor.run {
                        delegate?.retriesExhausted(operation: operationName, error: error)
                    }
                    
                    return .failure(error: retryError, attempts: attempt)
                    
                } else {
                    // Error is not retryable - fail immediately
                    let retryError = DatabaseRetryError.operationFailed(
                        operation: operationName,
                        reason: error.localizedDescription
                    )
                    return .failure(error: retryError, attempts: attempt)
                }
            }
        }
        
        // Should not reach here, but handle it gracefully
        let error = DatabaseRetryError.retriesExhausted(
            operation: operationName,
            lastError: lastError?.localizedDescription ?? "Unknown error"
        )
        return .failure(error: error, attempts: maxAttempts)
    }
    
    /// Executes an async operation with automatic retry, using default retry criteria.
    ///
    /// By default, retries on network-related errors (database unavailable, timeout, network errors).
    ///
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - operationName: Human-readable name for the operation
    /// - Returns: DatabaseRetryResult containing the result or error
    nonisolated func execute<T>(
        operation: @escaping () async throws -> T,
        operationName: String
    ) async -> DatabaseRetryResult<T> {
        return await execute(
            operation: operation,
            operationName: operationName,
            shouldRetry: Self.defaultShouldRetry
        )
    }
    
    // MARK: - Default Retry Criteria
    
    /// Default criteria for determining if an error should trigger a retry.
    /// Retries on database unavailable, timeout, and network errors.
    /// - Parameter error: The error to evaluate
    /// - Returns: true if the operation should be retried
    nonisolated static func defaultShouldRetry(_ error: Error) -> Bool {
        // Check for WatchlistError
        if let watchlistError = error as? WatchlistError {
            switch watchlistError {
            case .databaseUnavailable:
                return true
            case .invalidFormat, .duplicateSymbol, .limitReached:
                return false // Don't retry validation errors
            }
        }
        
        // Check for ConfigurationRepositoryError
        if let configError = error as? ConfigurationRepositoryError {
            switch configError {
            case .databaseUnavailable, .timeout, .networkError:
                return true
            case .saveFailed, .loadFailed:
                return true // Retry failed operations
            case .invalidData:
                return false // Don't retry data corruption errors
            }
        }
        
        // Check for DataSyncError
        if let syncError = error as? DataSyncError {
            switch syncError {
            case .clientUnavailable, .networkError, .timeout:
                return true
            case .parsingError, .partialFailure:
                return false
            }
        }
        
        // Check for common error types by description (fallback)
        let errorDescription = error.localizedDescription.lowercased()
        let retryableKeywords = ["network", "timeout", "connection", "unavailable", "offline"]
        
        return retryableKeywords.contains { errorDescription.contains($0) }
    }
}

// MARK: - Convenience Extensions

extension DatabaseRetryService {
    
    /// Creates a service configured for testing with shorter delays.
    /// - Returns: A DatabaseRetryService with minimal delays
    static func forTesting() -> DatabaseRetryService {
        let testConfig = DatabaseRetryConfiguration(
            maxRetryAttempts: 3,
            baseDelaySeconds: 0.01, // Very short delays for tests
            maxDelaySeconds: 0.05,
            backoffMultiplier: 2.0
        )
        return DatabaseRetryService(configuration: testConfig)
    }
    
    /// Creates a service with no delays (for unit tests).
    /// - Returns: A DatabaseRetryService with zero delays
    static func forUnitTesting() -> DatabaseRetryService {
        let testConfig = DatabaseRetryConfiguration(
            maxRetryAttempts: 3,
            baseDelaySeconds: 0.0,
            maxDelaySeconds: 0.0,
            backoffMultiplier: 1.0
        )
        return DatabaseRetryService(configuration: testConfig)
    }
}

// MARK: - Retryable Operation Wrapper

/// Wrapper for making database operations retryable.
/// Provides a clean interface for repositories to use retry logic.
///
/// Usage:
/// ```swift
/// let retryable = RetryableOperation(
///     service: retryService,
///     operationName: "Save configuration"
/// )
/// let result = await retryable.execute {
///     try await cloudClient.setDocument(...)
/// }
/// ```
struct RetryableOperation<T> {
    let service: DatabaseRetryServiceProtocol
    let operationName: String
    let shouldRetry: (Error) -> Bool
    
    /// Creates a new RetryableOperation.
    /// - Parameters:
    ///   - service: The retry service to use
    ///   - operationName: Human-readable name for the operation
    ///   - shouldRetry: Custom retry criteria (defaults to standard criteria)
    init(
        service: DatabaseRetryServiceProtocol,
        operationName: String,
        shouldRetry: @escaping (Error) -> Bool = DatabaseRetryService.defaultShouldRetry
    ) {
        self.service = service
        self.operationName = operationName
        self.shouldRetry = shouldRetry
    }
    
    /// Executes the operation with retry logic.
    /// - Parameter operation: The async operation to execute
    /// - Returns: DatabaseRetryResult containing the result or error
    func execute(_ operation: @escaping () async throws -> T) async -> DatabaseRetryResult<T> {
        return await service.execute(
            operation: operation,
            operationName: operationName,
            shouldRetry: shouldRetry
        )
    }
}

// MARK: - Error Message Helper

/// Helper for generating user-friendly error messages.
/// Uses ErrorMessageCatalog for consistent messaging across the app.
/// - Validates: Requirement 7.6 (Display error indicating operation that failed)
/// - Validates: Requirement 7.7 (Suggest checking network connectivity)
enum DatabaseErrorMessages {
    
    /// Message to display after an operation fails with retry option.
    /// - Parameter operationName: The name of the operation that failed
    /// - Returns: User-friendly error message
    /// - Validates: Requirement 7.6 (Display error with retry option)
    static func operationFailedWithRetry(operationName: String) -> String {
        return ErrorMessageCatalog.Database.operationFailed(operationName)
    }
    
    /// Message to display after all retries are exhausted.
    /// - Returns: User-friendly error message
    /// - Validates: Requirement 7.7 (Suggest checking network connectivity)
    static func retriesExhausted() -> String {
        return ErrorMessageCatalog.Database.retriesExhausted
    }
    
    /// Message to display during retry.
    /// - Parameters:
    ///   - attemptNumber: Current attempt number
    ///   - maxAttempts: Maximum number of attempts
    /// - Returns: User-friendly status message
    static func retrying(attemptNumber: Int, maxAttempts: Int) -> String {
        return ErrorMessageCatalog.Database.retrying(attemptNumber: attemptNumber, maxAttempts: maxAttempts)
    }
}

// MARK: - Retryable Watchlist Repository

/// Wrapper around WatchlistRepository that adds automatic retry logic with exponential backoff.
///
/// This repository decorator intercepts database operations and applies retry logic
/// using the DatabaseRetryService. It implements the WatchlistRepository protocol,
/// allowing it to be used as a drop-in replacement.
///
/// - Validates: Requirement 7.6 (Retry failed operations up to 3 times with error message)
/// - Validates: Requirement 7.7 (Display message suggesting network check after exhausting retries)
final class RetryableWatchlistRepository: WatchlistRepository {
    
    // MARK: - Properties
    
    /// The underlying repository to wrap
    private let wrappedRepository: WatchlistRepository
    
    /// The retry service providing exponential backoff
    private let retryService: DatabaseRetryServiceProtocol
    
    /// Delegate for receiving retry status updates
    weak var delegate: DatabaseRetryDelegate? {
        didSet {
            if let service = retryService as? DatabaseRetryService {
                service.delegate = delegate
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new RetryableWatchlistRepository instance.
    /// - Parameters:
    ///   - repository: The underlying repository to wrap
    ///   - retryService: The retry service to use (defaults to standard exponential backoff)
    init(
        repository: WatchlistRepository,
        retryService: DatabaseRetryServiceProtocol = DatabaseRetryService()
    ) {
        self.wrappedRepository = repository
        self.retryService = retryService
    }
    
    // MARK: - WatchlistRepository Protocol Methods
    
    /// Retrieves the watchlist for a specific user with automatic retry.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: Array of ticker symbols in the user's watchlist
    /// - Throws: WatchlistError if all retry attempts fail
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    func getWatchlist(for userId: String) async throws -> [String] {
        let result = await retryService.execute(
            operation: { [wrappedRepository] in
                try await wrappedRepository.getWatchlist(for: userId)
            },
            operationName: "Fetch watchlist"
        )
        
        if let value = result.value, result.success {
            return value
        }
        
        if let error = result.error {
            throw mapRetryErrorToWatchlistError(error)
        }
        
        throw WatchlistError.databaseUnavailable
    }
    
    /// Adds a ticker symbol to the user's watchlist with automatic retry.
    /// - Parameters:
    ///   - symbol: The ticker symbol to add
    ///   - userId: The unique identifier of the user
    /// - Throws: WatchlistError if all retry attempts fail
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    func addSymbol(_ symbol: String, for userId: String) async throws {
        let result = await retryService.execute(
            operation: { [wrappedRepository] in
                try await wrappedRepository.addSymbol(symbol, for: userId)
            },
            operationName: "Add symbol '\(symbol)'",
            shouldRetry: Self.shouldRetryWatchlistOperation
        )
        
        if result.success {
            return
        }
        
        if let error = result.error {
            throw mapRetryErrorToWatchlistError(error)
        }
        
        throw WatchlistError.databaseUnavailable
    }
    
    /// Removes a ticker symbol from the user's watchlist with automatic retry.
    /// - Parameters:
    ///   - symbol: The ticker symbol to remove
    ///   - userId: The unique identifier of the user
    /// - Throws: WatchlistError if all retry attempts fail
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    func removeSymbol(_ symbol: String, for userId: String) async throws {
        let result = await retryService.execute(
            operation: { [wrappedRepository] in
                try await wrappedRepository.removeSymbol(symbol, for: userId)
            },
            operationName: "Remove symbol '\(symbol)'"
        )
        
        if result.success {
            return
        }
        
        if let error = result.error {
            throw mapRetryErrorToWatchlistError(error)
        }
        
        throw WatchlistError.databaseUnavailable
    }
    
    // MARK: - Error Mapping
    
    /// Maps DatabaseRetryError to WatchlistError for proper error handling.
    /// - Parameter error: The retry error to map
    /// - Returns: Corresponding WatchlistError
    private func mapRetryErrorToWatchlistError(_ error: DatabaseRetryError) -> WatchlistError {
        switch error {
        case .retriesExhausted, .cancelled, .operationFailed:
            return .databaseUnavailable
        }
    }
    
    /// Determines if a watchlist operation error should trigger a retry.
    /// - Parameter error: The error to evaluate
    /// - Returns: true if the operation should be retried
    private static func shouldRetryWatchlistOperation(_ error: Error) -> Bool {
        // Check for WatchlistError
        if let watchlistError = error as? WatchlistError {
            switch watchlistError {
            case .databaseUnavailable:
                return true
            case .invalidFormat, .duplicateSymbol, .limitReached:
                return false // Don't retry validation errors
            }
        }
        
        // Use default retry criteria for other errors
        return DatabaseRetryService.defaultShouldRetry(error)
    }
}

// MARK: - Retryable Configuration Repository

/// Wrapper around ConfigurationRepository that adds automatic retry logic with exponential backoff.
///
/// This repository decorator intercepts database operations and applies retry logic
/// using the DatabaseRetryService. It implements the ConfigurationRepository protocol,
/// allowing it to be used as a drop-in replacement.
///
/// - Validates: Requirement 7.6 (Retry failed operations up to 3 times with error message)
/// - Validates: Requirement 7.7 (Display message suggesting network check after exhausting retries)
final class RetryableConfigurationRepository: ConfigurationRepository {
    
    // MARK: - Properties
    
    /// The underlying repository to wrap
    private let wrappedRepository: ConfigurationRepository
    
    /// The retry service providing exponential backoff
    private let retryService: DatabaseRetryServiceProtocol
    
    /// Delegate for receiving retry status updates
    weak var delegate: DatabaseRetryDelegate? {
        didSet {
            if let service = retryService as? DatabaseRetryService {
                service.delegate = delegate
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new RetryableConfigurationRepository instance.
    /// - Parameters:
    ///   - repository: The underlying repository to wrap
    ///   - retryService: The retry service to use (defaults to standard exponential backoff)
    init(
        repository: ConfigurationRepository,
        retryService: DatabaseRetryServiceProtocol = DatabaseRetryService()
    ) {
        self.wrappedRepository = repository
        self.retryService = retryService
    }
    
    // MARK: - ConfigurationRepository Protocol Methods
    
    /// Saves a strategy configuration with automatic retry.
    /// - Parameters:
    ///   - configuration: The configuration to save
    ///   - userId: The unique identifier of the user
    /// - Returns: ConfigurationSaveResult indicating success or failure
    /// - Throws: ConfigurationRepositoryError if all retry attempts fail
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    func save(configuration: StrategyConfiguration, for userId: String) async throws -> ConfigurationSaveResult {
        let result = await retryService.execute(
            operation: { [wrappedRepository] in
                try await wrappedRepository.save(configuration: configuration, for: userId)
            },
            operationName: "Save configuration",
            shouldRetry: Self.shouldRetryConfigurationOperation
        )
        
        if let value = result.value, result.success {
            return value
        }
        
        if let error = result.error {
            throw mapRetryErrorToConfigurationError(error)
        }
        
        throw ConfigurationRepositoryError.saveFailed(reason: DatabaseErrorMessages.retriesExhausted())
    }
    
    /// Loads a strategy configuration with automatic retry.
    /// - Parameters:
    ///   - strategyId: The identifier of the strategy
    ///   - userId: The unique identifier of the user
    /// - Returns: The loaded configuration or defaults
    /// - Throws: ConfigurationRepositoryError if all retry attempts fail and no cache available
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    func load(strategyId: String, for userId: String) async throws -> StrategyConfiguration {
        // First try: attempt to load from wrapped repository
        do {
            return try await wrappedRepository.load(strategyId: strategyId, for: userId)
        } catch let error as ConfigurationRepositoryError where error == .databaseUnavailable {
            // Database unavailable is expected in local-only mode - don't retry, just rethrow
            // The caller should handle this gracefully by applying defaults
            throw error
        } catch {
            // For other errors, use retry logic
            let result = await retryService.execute(
                operation: { [wrappedRepository, strategyId, userId] in
                    try await wrappedRepository.load(strategyId: strategyId, for: userId)
                },
                operationName: "Load configuration",
                shouldRetry: Self.shouldRetryConfigurationOperation
            )
            
            if let value = result.value, result.success {
                return value
            }
            
            if let error = result.error {
                throw mapRetryErrorToConfigurationError(error)
            }
            
            throw ConfigurationRepositoryError.loadFailed(reason: DatabaseErrorMessages.retriesExhausted())
        }
    }
    
    /// Deletes a strategy configuration with automatic retry.
    /// - Parameters:
    ///   - strategyId: The identifier of the strategy
    ///   - userId: The unique identifier of the user
    /// - Throws: ConfigurationRepositoryError if all retry attempts fail
    /// - Validates: Requirement 7.6 (Retry up to 3 times)
    func delete(strategyId: String, for userId: String) async throws {
        let result = await retryService.execute(
            operation: { [wrappedRepository] in
                try await wrappedRepository.delete(strategyId: strategyId, for: userId)
            },
            operationName: "Delete configuration",
            shouldRetry: Self.shouldRetryConfigurationOperation
        )
        
        if result.success {
            return
        }
        
        if let error = result.error {
            throw mapRetryErrorToConfigurationError(error)
        }
        
        throw ConfigurationRepositoryError.databaseUnavailable
    }
    
    // MARK: - Error Mapping
    
    /// Maps DatabaseRetryError to ConfigurationRepositoryError for proper error handling.
    /// - Parameter error: The retry error to map
    /// - Returns: Corresponding ConfigurationRepositoryError
    private func mapRetryErrorToConfigurationError(_ error: DatabaseRetryError) -> ConfigurationRepositoryError {
        switch error {
        case .retriesExhausted(_, _):
            return .networkError(underlying: DatabaseErrorMessages.retriesExhausted())
        case .cancelled:
            return .databaseUnavailable
        case .operationFailed(let operation, let reason):
            if operation.contains("Save") {
                return .saveFailed(reason: reason)
            } else if operation.contains("Load") {
                return .loadFailed(reason: reason)
            }
            return .databaseUnavailable
        }
    }
    
    /// Determines if a configuration operation error should trigger a retry.
    /// - Parameter error: The error to evaluate
    /// - Returns: true if the operation should be retried
    private static func shouldRetryConfigurationOperation(_ error: Error) -> Bool {
        // Check for ConfigurationRepositoryError
        if let configError = error as? ConfigurationRepositoryError {
            switch configError {
            case .databaseUnavailable:
                // Don't retry if database is completely unavailable (no cloud client)
                // This is a configuration issue, not a transient error
                return false
            case .timeout, .networkError, .saveFailed, .loadFailed:
                // Retry transient errors
                return true
            case .invalidData:
                return false // Don't retry data corruption errors
            }
        }
        
        // Use default retry criteria for other errors
        return DatabaseRetryService.defaultShouldRetry(error)
    }
}

/// Factory for creating repository instances with retry capabilities.
///
/// This factory centralizes the creation of retryable repository wrappers,
/// ensuring consistent retry configuration across the application.
///
/// - Validates: Requirement 7.6 (Provide retry option for database operations)
/// - Validates: Requirement 7.7 (Suggest checking network after exhausting retries)
enum RetryableRepositoryFactory {
    
    /// Creates a watchlist repository with retry capabilities.
    /// - Parameters:
    ///   - baseRepository: The underlying repository to wrap
    ///   - configuration: Custom retry configuration (defaults to exponential backoff)
    /// - Returns: A WatchlistRepository with automatic retry
    static func makeWatchlistRepository(
        wrapping baseRepository: WatchlistRepository,
        configuration: DatabaseRetryConfiguration = .default
    ) -> WatchlistRepository {
        let retryService = DatabaseRetryService(configuration: configuration)
        return RetryableWatchlistRepository(
            repository: baseRepository,
            retryService: retryService
        )
    }
    
    /// Creates a configuration repository with retry capabilities.
    /// - Parameters:
    ///   - baseRepository: The underlying repository to wrap
    ///   - configuration: Custom retry configuration (defaults to exponential backoff)
    /// - Returns: A ConfigurationRepository with automatic retry
    static func makeConfigurationRepository(
        wrapping baseRepository: ConfigurationRepository,
        configuration: DatabaseRetryConfiguration = .default
    ) -> ConfigurationRepository {
        let retryService = DatabaseRetryService(configuration: configuration)
        return RetryableConfigurationRepository(
            repository: baseRepository,
            retryService: retryService
        )
    }
    
    /// Creates a watchlist repository with retry capabilities and a delegate for status updates.
    /// - Parameters:
    ///   - baseRepository: The underlying repository to wrap
    ///   - delegate: Delegate to receive retry status updates
    ///   - configuration: Custom retry configuration (defaults to exponential backoff)
    /// - Returns: A RetryableWatchlistRepository with automatic retry
    static func makeWatchlistRepository(
        wrapping baseRepository: WatchlistRepository,
        delegate: DatabaseRetryDelegate?,
        configuration: DatabaseRetryConfiguration = .default
    ) -> RetryableWatchlistRepository {
        let retryService = DatabaseRetryService(configuration: configuration)
        let repository = RetryableWatchlistRepository(
            repository: baseRepository,
            retryService: retryService
        )
        repository.delegate = delegate
        return repository
    }
    
    /// Creates a configuration repository with retry capabilities and a delegate for status updates.
    /// - Parameters:
    ///   - baseRepository: The underlying repository to wrap
    ///   - delegate: Delegate to receive retry status updates
    ///   - configuration: Custom retry configuration (defaults to exponential backoff)
    /// - Returns: A RetryableConfigurationRepository with automatic retry
    static func makeConfigurationRepository(
        wrapping baseRepository: ConfigurationRepository,
        delegate: DatabaseRetryDelegate?,
        configuration: DatabaseRetryConfiguration = .default
    ) -> RetryableConfigurationRepository {
        let retryService = DatabaseRetryService(configuration: configuration)
        let repository = RetryableConfigurationRepository(
            repository: baseRepository,
            retryService: retryService
        )
        repository.delegate = delegate
        return repository
    }
}

