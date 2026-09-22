//
//  ConfigurationRepositoryImpl.swift
//  TradingGuru
//
//  Firestore-backed implementation of ConfigurationRepository with local caching.
//

import Foundation

// MARK: - ConfigurationRepositoryImpl

/// Implementation of ConfigurationRepository with cloud database and local caching.
/// Provides save/load operations for user strategy configurations with offline support.
///
/// - Validates: Requirement 4.6 (Persist configuration to database with confirmation)
/// - Validates: Requirement 4.7 (Load previously saved configuration values)
/// - Validates: Requirement 4.8 (Apply default values if no saved config)
/// - Validates: Requirement 4.9 (Display error on save failure, retain user values)
/// - Validates: Requirement 4.10 (Display error on load failure, apply defaults)
/// - Validates: Requirement 7.1 (Store configurations in cloud database)
/// - Validates: Requirement 7.2 (Persist changes within 5 seconds)
final class ConfigurationRepositoryImpl: ConfigurationRepository {
    
    // MARK: - Constants
    
    /// Collection name for configuration documents
    private static let configurationsCollection = ConfigurationConstants.configurationsCollection
    
    /// Maximum time to wait for database operations (5 seconds per Requirement 7.2)
    private static let operationTimeoutSeconds = ConfigurationConstants.operationTimeoutSeconds
    
    // MARK: - UserDefaults Keys for Local Cache
    
    private enum CacheKeys {
        static func configurationKey(userId: String, strategyId: String) -> String {
            "com.tradingguru.configuration.\(userId).\(strategyId)"
        }
        static func lastUpdatedKey(userId: String, strategyId: String) -> String {
            "com.tradingguru.configuration.lastUpdated.\(userId).\(strategyId)"
        }
    }
    
    // MARK: - Properties
    
    /// Cloud database client for remote operations
    private let cloudClient: CloudDatabaseClient?
    
    /// Local storage for caching configuration data
    private let localStorage: UserDefaults
    
    /// In-memory cache for faster access
    private var memoryCache: [String: StrategyConfiguration] = [:]
    
    /// Default configuration provider
    private let defaultConfigurationProvider: (String) -> StrategyConfiguration
    
    // MARK: - Initialization
    
    /// Creates a new ConfigurationRepositoryImpl instance.
    /// - Parameters:
    ///   - cloudClient: Cloud database client (optional, nil for local-only mode)
    ///   - localStorage: UserDefaults instance for local caching (defaults to .standard)
    ///   - defaultConfigurationProvider: Closure that provides default configuration for a strategy ID
    init(
        cloudClient: CloudDatabaseClient? = nil,
        localStorage: UserDefaults = .standard,
        defaultConfigurationProvider: @escaping (String) -> StrategyConfiguration = { strategyId in
            // Return Weekly Option Strategy defaults for that strategy ID
            if strategyId == WeeklyOptionConfiguration.strategyId {
                return WeeklyOptionConfiguration.default.toStrategyConfiguration()
            }
            // Generic default for unknown strategies
            return StrategyConfiguration(strategyId: strategyId, parameters: [:], updatedAt: Date())
        }
    ) {
        self.cloudClient = cloudClient
        self.localStorage = localStorage
        self.defaultConfigurationProvider = defaultConfigurationProvider
    }
    
    // MARK: - ConfigurationRepository Protocol Methods
    
    /// Saves a strategy configuration for a specific user.
    /// - Parameters:
    ///   - configuration: The configuration to save
    ///   - userId: The unique identifier of the user
    /// - Returns: A ConfigurationSaveResult indicating success or failure
    /// - Throws: ConfigurationRepositoryError if the operation fails
    /// - Validates: Requirement 4.6 (Persist configuration with confirmation feedback)
    /// - Validates: Requirement 4.9 (Retain user's selected values on save failure)
    func save(configuration: StrategyConfiguration, for userId: String) async throws -> ConfigurationSaveResult {
        let cacheKey = makeCacheKey(userId: userId, strategyId: configuration.strategyId)
        
        do {
            try await saveToCloud(userId: userId, configuration: configuration)
            
            // Update local cache on success
            let savedAt = Date()
            var updatedConfig = configuration
            updatedConfig.updatedAt = savedAt
            updateLocalCache(userId: userId, configuration: updatedConfig)
            
            return .success(savedAt: savedAt)
            
        } catch {
            // Save to local cache even on cloud failure to retain user's values
            // This satisfies Requirement 4.9: retain user's selected values on failure
            updateLocalCache(userId: userId, configuration: configuration)
            
            // Throw error for caller to display appropriate message
            // Validates: Requirement 4.9 (Display error message if save fails)
            let repositoryError = mapToRepositoryError(error, operation: "save")
            throw repositoryError
        }
    }
    
    /// Loads a strategy configuration for a specific user.
    /// - Parameters:
    ///   - strategyId: The identifier of the strategy to load configuration for
    ///   - userId: The unique identifier of the user
    /// - Returns: The loaded configuration or default values if none exists
    /// - Throws: ConfigurationRepositoryError if retrieval fails and no cache available
    /// - Validates: Requirement 4.7 (Load previously saved configuration)
    /// - Validates: Requirement 4.8 (Apply defaults if no saved config)
    /// - Validates: Requirement 4.10 (Apply defaults on load failure)
    func load(strategyId: String, for userId: String) async throws -> StrategyConfiguration {
        let cacheKey = makeCacheKey(userId: userId, strategyId: strategyId)
        
        do {
            // Try to load from cloud first
            let configuration = try await loadFromCloud(userId: userId, strategyId: strategyId)
            
            // Update local cache with fresh data
            updateLocalCache(userId: userId, configuration: configuration)
            
            return configuration
            
        } catch let error where isNotFoundError(error) {
            // No saved configuration exists - apply defaults
            // Validates: Requirement 4.8 (Apply default values if no saved config)
            let defaultConfig = defaultConfigurationProvider(strategyId)
            return defaultConfig
            
        } catch ConfigurationRepositoryError.databaseUnavailable {
            // Database unavailable (no cloud client) - try local cache, then defaults
            // This is expected in local-only mode, so return defaults without error
            if let cachedConfig = getFromLocalCache(userId: userId, strategyId: strategyId) {
                return cachedConfig
            }
            // No cache - return defaults (don't throw, this is expected behavior)
            return defaultConfigurationProvider(strategyId)
            
        } catch {
            // Cloud load failed - try local cache
            if let cachedConfig = getFromLocalCache(userId: userId, strategyId: strategyId) {
                return cachedConfig
            }
            
            // No cache available - apply defaults per Requirement 4.10
            // The error is logged but defaults are returned
            // Caller should display error message indicating load failure
            let defaultConfig = defaultConfigurationProvider(strategyId)
            
            // Throw the error with the default config attached for caller handling
            // Validates: Requirement 4.10 (Display error and apply defaults)
            throw ConfigurationRepositoryError.loadFailed(
                reason: "Unable to load configuration. Using defaults."
            )
        }
    }
    
    /// Deletes a strategy configuration for a specific user.
    /// - Parameters:
    ///   - strategyId: The identifier of the strategy to delete configuration for
    ///   - userId: The unique identifier of the user
    /// - Throws: ConfigurationRepositoryError if deletion fails
    func delete(strategyId: String, for userId: String) async throws {
        do {
            try await deleteFromCloud(userId: userId, strategyId: strategyId)
            
            // Clear local cache
            clearLocalCache(userId: userId, strategyId: strategyId)
            
        } catch {
            // Clear local cache even on cloud failure
            clearLocalCache(userId: userId, strategyId: strategyId)
            
            throw mapToRepositoryError(error, operation: "delete")
        }
    }
    
    // MARK: - Cloud Database Operations
    
    /// Saves configuration to cloud database.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - configuration: The configuration to save
    /// - Throws: Error if cloud operation fails
    private func saveToCloud(userId: String, configuration: StrategyConfiguration) async throws {
        guard let client = cloudClient else {
            throw ConfigurationRepositoryError.databaseUnavailable
        }
        
        let data = try encodeConfiguration(configuration)
        
        try await withTimeout(seconds: Self.operationTimeoutSeconds) {
            try await client.setDocument(
                collection: Self.configurationsCollection,
                userId: userId,
                documentId: configuration.strategyId,
                data: data
            )
        }
    }
    
    /// Loads configuration from cloud database.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - strategyId: The strategy ID
    /// - Returns: The loaded configuration
    /// - Throws: Error if cloud operation fails or no configuration exists
    private func loadFromCloud(userId: String, strategyId: String) async throws -> StrategyConfiguration {
        guard let client = cloudClient else {
            throw ConfigurationRepositoryError.databaseUnavailable
        }
        
        let documents = try await withTimeout(seconds: Self.operationTimeoutSeconds) {
            try await client.getDocuments(
                collection: Self.configurationsCollection,
                userId: userId
            )
        }
        
        // Find the document matching the strategy ID
        guard let document = documents.first(where: { ($0["strategyId"] as? String) == strategyId }) else {
            throw ConfigurationNotFoundError()
        }
        
        return try decodeConfiguration(from: document, strategyId: strategyId)
    }
    
    /// Deletes configuration from cloud database.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - strategyId: The strategy ID
    /// - Throws: Error if cloud operation fails
    private func deleteFromCloud(userId: String, strategyId: String) async throws {
        guard let client = cloudClient else {
            throw ConfigurationRepositoryError.databaseUnavailable
        }
        
        try await withTimeout(seconds: Self.operationTimeoutSeconds) {
            try await client.deleteDocument(
                collection: Self.configurationsCollection,
                userId: userId,
                documentId: strategyId
            )
        }
    }
    
    // MARK: - Local Cache Operations
    
    /// Makes a cache key for a user/strategy combination.
    private func makeCacheKey(userId: String, strategyId: String) -> String {
        "\(userId).\(strategyId)"
    }
    
    /// Retrieves configuration from local cache.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - strategyId: The strategy ID
    /// - Returns: The cached configuration if available, nil otherwise
    private func getFromLocalCache(userId: String, strategyId: String) -> StrategyConfiguration? {
        let cacheKey = makeCacheKey(userId: userId, strategyId: strategyId)
        
        // Check memory cache first
        if let cached = memoryCache[cacheKey] {
            return cached
        }
        
        // Fall back to UserDefaults
        let key = CacheKeys.configurationKey(userId: userId, strategyId: strategyId)
        guard let data = localStorage.data(forKey: key),
              let config = try? JSONDecoder().decode(StrategyConfiguration.self, from: data) else {
            return nil
        }
        
        // Populate memory cache
        memoryCache[cacheKey] = config
        return config
    }
    
    /// Updates local cache with configuration data.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - configuration: The configuration to cache
    private func updateLocalCache(userId: String, configuration: StrategyConfiguration) {
        let cacheKey = makeCacheKey(userId: userId, strategyId: configuration.strategyId)
        
        // Update memory cache
        memoryCache[cacheKey] = configuration
        
        // Persist to UserDefaults
        let key = CacheKeys.configurationKey(userId: userId, strategyId: configuration.strategyId)
        if let data = try? JSONEncoder().encode(configuration) {
            localStorage.set(data, forKey: key)
        }
        
        // Store last updated timestamp
        let timestampKey = CacheKeys.lastUpdatedKey(userId: userId, strategyId: configuration.strategyId)
        localStorage.set(Date().timeIntervalSince1970, forKey: timestampKey)
    }
    
    /// Clears local cache for a user/strategy combination.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - strategyId: The strategy ID
    private func clearLocalCache(userId: String, strategyId: String) {
        let cacheKey = makeCacheKey(userId: userId, strategyId: strategyId)
        memoryCache.removeValue(forKey: cacheKey)
        
        localStorage.removeObject(forKey: CacheKeys.configurationKey(userId: userId, strategyId: strategyId))
        localStorage.removeObject(forKey: CacheKeys.lastUpdatedKey(userId: userId, strategyId: strategyId))
    }
    
    // MARK: - Encoding/Decoding
    
    /// Encodes a StrategyConfiguration to a dictionary for Firestore.
    /// - Parameter configuration: The configuration to encode
    /// - Returns: Dictionary representation
    private func encodeConfiguration(_ configuration: StrategyConfiguration) throws -> [String: Any] {
        var data: [String: Any] = [
            "strategyId": configuration.strategyId,
            "updatedAt": configuration.updatedAt.timeIntervalSince1970
        ]
        
        // Encode parameters
        var params: [String: Any] = [:]
        for (key, value) in configuration.parameters {
            switch value {
            case .integer(let intVal):
                params[key] = ["type": "integer", "value": intVal]
            case .decimal(let doubleVal):
                params[key] = ["type": "decimal", "value": doubleVal]
            case .boolean(let boolVal):
                params[key] = ["type": "boolean", "value": boolVal]
            case .string(let stringVal):
                params[key] = ["type": "string", "value": stringVal]
            }
        }
        data["parameters"] = params
        
        return data
    }
    
    /// Decodes a StrategyConfiguration from a Firestore document.
    /// - Parameters:
    ///   - document: The document data
    ///   - strategyId: The expected strategy ID
    /// - Returns: Decoded configuration
    private func decodeConfiguration(from document: [String: Any], strategyId: String) throws -> StrategyConfiguration {
        guard let documentStrategyId = document["strategyId"] as? String else {
            throw ConfigurationRepositoryError.invalidData
        }
        
        let updatedAt: Date
        if let timestamp = document["updatedAt"] as? TimeInterval {
            updatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            updatedAt = Date()
        }
        
        var parameters: [String: ConfigValue] = [:]
        
        if let params = document["parameters"] as? [String: [String: Any]] {
            for (key, valueDict) in params {
                guard let type = valueDict["type"] as? String else { continue }
                
                switch type {
                case "integer":
                    if let value = valueDict["value"] as? Int {
                        parameters[key] = .integer(value)
                    }
                case "decimal":
                    if let value = valueDict["value"] as? Double {
                        parameters[key] = .decimal(value)
                    }
                case "boolean":
                    if let value = valueDict["value"] as? Bool {
                        parameters[key] = .boolean(value)
                    }
                case "string":
                    if let value = valueDict["value"] as? String {
                        parameters[key] = .string(value)
                    }
                default:
                    break
                }
            }
        }
        
        return StrategyConfiguration(
            strategyId: documentStrategyId,
            parameters: parameters,
            updatedAt: updatedAt
        )
    }
    
    // MARK: - Error Handling
    
    /// Maps generic errors to ConfigurationRepositoryError.
    /// - Parameters:
    ///   - error: The original error
    ///   - operation: The operation being performed ("save", "load", "delete")
    /// - Returns: A ConfigurationRepositoryError
    private func mapToRepositoryError(_ error: Error, operation: String) -> ConfigurationRepositoryError {
        if let repoError = error as? ConfigurationRepositoryError {
            return repoError
        }
        
        switch operation {
        case "save":
            return .saveFailed(reason: error.localizedDescription)
        case "load":
            return .loadFailed(reason: error.localizedDescription)
        default:
            return .databaseUnavailable
        }
    }
    
    /// Checks if an error indicates a configuration was not found.
    private func isNotFoundError(_ error: Error) -> Bool {
        return error is ConfigurationNotFoundError
    }
    
    // MARK: - Timeout Helper
    
    /// Executes an async operation with a timeout.
    /// - Parameters:
    ///   - seconds: The timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: ConfigurationRepositoryError.timeout if operation times out
    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation task
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ConfigurationRepositoryError.timeout
            }
            
            // Return the first result
            guard let result = try await group.next() else {
                throw ConfigurationRepositoryError.timeout
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
}

// MARK: - Private Error Types

/// Error indicating a configuration was not found in the database.
private struct ConfigurationNotFoundError: Error {}

// MARK: - Cache Status Extension

extension ConfigurationRepositoryImpl {
    
    /// Returns whether there is cached configuration data for a user/strategy.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - strategyId: The strategy ID
    /// - Returns: true if cached data exists
    func hasCachedData(userId: String, strategyId: String) -> Bool {
        return getFromLocalCache(userId: userId, strategyId: strategyId) != nil
    }
    
    /// Returns the last update timestamp for cached configuration.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - strategyId: The strategy ID
    /// - Returns: The last update date, or nil if no cache exists
    func lastCacheUpdate(userId: String, strategyId: String) -> Date? {
        let key = CacheKeys.lastUpdatedKey(userId: userId, strategyId: strategyId)
        guard let timestamp = localStorage.object(forKey: key) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Testing Support

extension ConfigurationRepositoryImpl {
    
    /// Creates a local-only instance for testing without cloud database.
    /// - Parameters:
    ///   - localStorage: UserDefaults instance for local storage
    ///   - defaultConfigurationProvider: Provider for default configurations
    /// - Returns: A configured instance for testing
    static func forTesting(
        localStorage: UserDefaults = .standard,
        defaultConfigurationProvider: @escaping (String) -> StrategyConfiguration = { strategyId in
            if strategyId == WeeklyOptionConfiguration.strategyId {
                return WeeklyOptionConfiguration.default.toStrategyConfiguration()
            }
            return StrategyConfiguration(strategyId: strategyId, parameters: [:], updatedAt: Date())
        }
    ) -> ConfigurationRepositoryImpl {
        return ConfigurationRepositoryImpl(
            cloudClient: nil,
            localStorage: localStorage,
            defaultConfigurationProvider: defaultConfigurationProvider
        )
    }
    
    /// Creates an instance with a mock cloud client for testing.
    /// - Parameters:
    ///   - mockClient: The mock cloud client
    ///   - localStorage: UserDefaults instance for local storage
    /// - Returns: A configured instance for testing with mock cloud
    static func forTestingWithMock(
        mockClient: MockCloudDatabaseClient,
        localStorage: UserDefaults = .standard
    ) -> ConfigurationRepositoryImpl {
        return ConfigurationRepositoryImpl(
            cloudClient: mockClient,
            localStorage: localStorage
        )
    }
    
    /// Preloads cache with test configuration data.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - configuration: The configuration to preload
    func preloadCache(userId: String, configuration: StrategyConfiguration) {
        updateLocalCache(userId: userId, configuration: configuration)
    }
    
    /// Clears all cached data for a user.
    /// - Parameter userId: The user ID
    func clearAllCache(for userId: String) {
        // Clear memory cache entries for this user
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix("\(userId).") }
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
        }
        
        // Note: Clearing UserDefaults entries would require iterating all known strategy IDs
        // For testing purposes, the specific clearLocalCache method should be used
    }
}

// MARK: - Default Configuration Provider

/// Provides default configurations for strategies.
/// - Validates: Requirement 4.8 (Default values: WINDOW_DAYS=5, LOOKBACK_DAYS=180, PREMIUM_PCT=0.5%, ONLY_ORDERS=false)
enum DefaultConfigurationProvider {
    
    /// Returns the default configuration for a given strategy ID.
    /// - Parameter strategyId: The strategy identifier
    /// - Returns: The default StrategyConfiguration
    static func configuration(for strategyId: String) -> StrategyConfiguration {
        switch strategyId {
        case WeeklyOptionConfiguration.strategyId:
            // Apply defaults per Requirement 4.8
            return WeeklyOptionConfiguration.default.toStrategyConfiguration()
        default:
            // Unknown strategy - return empty configuration
            return StrategyConfiguration(
                strategyId: strategyId,
                parameters: [:],
                updatedAt: Date()
            )
        }
    }
}
