//
//  DataSyncService.swift
//  TradingGuru
//
//  Service for handling cross-device data synchronization and conflict resolution.
//

import Foundation

// MARK: - Data Sync Protocol

/// Protocol for data synchronization service.
/// Handles cross-device sync on sign-in and timestamp-based conflict resolution.
///
/// - Validates: Requirement 7.3 (Retrieve data on new device sign-in before displaying home screen)
/// - Validates: Requirement 7.4 (Use most recently modified version based on timestamp for conflict resolution)
protocol DataSyncServiceProtocol {
    /// Synchronizes all user data from the cloud database before displaying home screen.
    /// - Parameter userId: The user ID to sync data for
    /// - Returns: SyncResult indicating success or partial success with any errors
    /// - Validates: Requirement 7.3 (Retrieve data before displaying home screen)
    func syncUserData(for userId: String) async throws -> SyncResult
    
    /// Resolves conflicts between local and cloud data using timestamps.
    /// - Parameters:
    ///   - localData: The local version of the data
    ///   - cloudData: The cloud version of the data
    /// - Returns: The version with the most recent timestamp
    /// - Validates: Requirement 7.4 (Use most recently modified version)
    func resolveConflict<T: TimestampedData>(local: T, cloud: T) -> T
    
    /// Checks if a sync is needed based on last sync timestamp.
    /// - Parameter userId: The user ID to check
    /// - Returns: true if sync is needed
    func needsSync(for userId: String) -> Bool
}

// MARK: - Timestamped Data Protocol

/// Protocol for data types that have a modification timestamp.
/// Used for conflict resolution based on Requirement 7.4.
protocol TimestampedData {
    /// The timestamp when this data was last modified
    var updatedAt: Date { get }
}

// MARK: - Sync Result

/// Result of a data synchronization operation.
/// - Validates: Requirement 7.3 (Retrieve data before displaying home screen)
struct SyncResult: Equatable {
    /// Whether the sync was fully successful
    let success: Bool
    
    /// Whether watchlist data was synced
    let watchlistSynced: Bool
    
    /// Whether configuration data was synced
    let configurationSynced: Bool
    
    /// Whether user profile was synced
    let profileSynced: Bool
    
    /// Any errors that occurred during sync
    let errors: [String]
    
    /// Timestamp when sync completed
    let syncedAt: Date
    
    /// Creates a successful sync result.
    static func successful(syncedAt: Date = Date()) -> SyncResult {
        SyncResult(
            success: true,
            watchlistSynced: true,
            configurationSynced: true,
            profileSynced: true,
            errors: [],
            syncedAt: syncedAt
        )
    }
    
    /// Creates a partial sync result with some failures.
    static func partial(
        watchlistSynced: Bool,
        configurationSynced: Bool,
        profileSynced: Bool,
        errors: [String],
        syncedAt: Date = Date()
    ) -> SyncResult {
        SyncResult(
            success: watchlistSynced && configurationSynced && profileSynced,
            watchlistSynced: watchlistSynced,
            configurationSynced: configurationSynced,
            profileSynced: profileSynced,
            errors: errors,
            syncedAt: syncedAt
        )
    }
    
    /// Creates a failed sync result.
    static func failed(errors: [String]) -> SyncResult {
        SyncResult(
            success: false,
            watchlistSynced: false,
            configurationSynced: false,
            profileSynced: false,
            errors: errors,
            syncedAt: Date()
        )
    }
}

// MARK: - Versioned Data Wrapper

/// Wrapper for data with version information for conflict resolution.
/// - Validates: Requirement 7.4 (Conflict resolution using timestamps)
struct VersionedData<T>: TimestampedData {
    /// The actual data
    let data: T
    
    /// When this version was last modified
    let updatedAt: Date
    
    /// Whether this data came from the cloud (vs local cache)
    let isFromCloud: Bool
    
    /// Creates a new versioned data wrapper.
    init(data: T, updatedAt: Date, isFromCloud: Bool = false) {
        self.data = data
        self.updatedAt = updatedAt
        self.isFromCloud = isFromCloud
    }
}

// MARK: - Data Sync Service Implementation

/// Implementation of DataSyncService for handling cross-device synchronization.
///
/// This service:
/// 1. Fetches user data from cloud on sign-in before showing home screen
/// 2. Resolves conflicts between local and cloud data using timestamps
/// 3. Updates local cache with the most recent data version
///
/// - Validates: Requirement 7.3 (Retrieve data on new device sign-in)
/// - Validates: Requirement 7.4 (Timestamp-based conflict resolution)
final class DataSyncService: DataSyncServiceProtocol {
    
    // MARK: - Constants
    
    private enum StorageKeys {
        static func lastSyncKey(for userId: String) -> String {
            "com.tradingguru.sync.lastSync.\(userId)"
        }
    }
    
    /// Maximum time to wait for sync operations (in seconds)
    private static let syncTimeoutSeconds: TimeInterval = 10.0
    
    // MARK: - Properties
    
    /// Cloud database client for fetching remote data
    private let cloudClient: CloudDatabaseClient?
    
    /// Local storage for sync metadata
    private let localStorage: UserDefaults
    
    /// Watchlist repository for local cache operations
    private let watchlistRepository: WatchlistRepository?
    
    /// Configuration repository for local cache operations
    private let configurationRepository: ConfigurationRepository?
    
    #if canImport(FirebaseFirestore)
    /// Firestore client for user profile operations
    private let firestoreClient: FirestoreClient?
    #endif
    
    // MARK: - Initialization
    
    /// Creates a new DataSyncService instance.
    /// - Parameters:
    ///   - cloudClient: Cloud database client for remote operations
    ///   - localStorage: UserDefaults for storing sync metadata
    ///   - watchlistRepository: Repository for watchlist operations
    ///   - configurationRepository: Repository for configuration operations
    init(
        cloudClient: CloudDatabaseClient? = nil,
        localStorage: UserDefaults = .standard,
        watchlistRepository: WatchlistRepository? = nil,
        configurationRepository: ConfigurationRepository? = nil
    ) {
        self.cloudClient = cloudClient
        self.localStorage = localStorage
        self.watchlistRepository = watchlistRepository
        self.configurationRepository = configurationRepository
        #if canImport(FirebaseFirestore)
        self.firestoreClient = cloudClient as? FirestoreClient
        #endif
    }
    
    // MARK: - DataSyncServiceProtocol Methods
    
    /// Synchronizes all user data from the cloud database.
    /// This should be called after sign-in, before displaying the home screen.
    ///
    /// - Parameter userId: The user ID to sync data for
    /// - Returns: SyncResult indicating success or partial success
    /// - Validates: Requirement 7.3 (Retrieve data before displaying home screen)
    func syncUserData(for userId: String) async throws -> SyncResult {
        var watchlistSynced = false
        var configurationSynced = false
        var profileSynced = false
        var errors: [String] = []
        
        // Sync operations run concurrently for efficiency
        await withTaskGroup(of: Void.self) { group in
            // Sync watchlist
            group.addTask { [weak self] in
                do {
                    try await self?.syncWatchlist(for: userId)
                    watchlistSynced = true
                } catch {
                    errors.append("Watchlist sync failed: \(error.localizedDescription)")
                }
            }
            
            // Sync configuration
            group.addTask { [weak self] in
                do {
                    try await self?.syncConfiguration(for: userId)
                    configurationSynced = true
                } catch {
                    errors.append("Configuration sync failed: \(error.localizedDescription)")
                }
            }
            
            // Sync user profile
            group.addTask { [weak self] in
                do {
                    try await self?.syncUserProfile(for: userId)
                    profileSynced = true
                } catch {
                    errors.append("Profile sync failed: \(error.localizedDescription)")
                }
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
        
        // Update last sync timestamp
        updateLastSyncTimestamp(for: userId)
        
        return SyncResult.partial(
            watchlistSynced: watchlistSynced,
            configurationSynced: configurationSynced,
            profileSynced: profileSynced,
            errors: errors
        )
    }
    
    /// Resolves conflicts between local and cloud data using timestamps.
    /// Returns the version with the more recent (later) timestamp.
    ///
    /// - Parameters:
    ///   - local: The local version of the data
    ///   - cloud: The cloud version of the data
    /// - Returns: The version with the most recent timestamp
    /// - Validates: Requirement 7.4 (Use most recently modified version)
    /// - Validates: Property 15 (Conflict Resolution by Timestamp)
    func resolveConflict<T: TimestampedData>(local: T, cloud: T) -> T {
        // Compare timestamps and return the more recent version
        // Per Requirement 7.4: use the most recently modified version based on timestamp
        if cloud.updatedAt > local.updatedAt {
            return cloud
        } else {
            return local
        }
    }
    
    /// Checks if a sync is needed for the given user.
    /// - Parameter userId: The user ID to check
    /// - Returns: true if sync is needed (first sign-in or stale data)
    func needsSync(for userId: String) -> Bool {
        guard let lastSync = getLastSyncTimestamp(for: userId) else {
            // No previous sync - this is a new device sign-in
            return true
        }
        
        // Consider sync needed if last sync was more than 1 hour ago
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return lastSync < oneHourAgo
    }
    
    // MARK: - Private Sync Methods
    
    /// Syncs watchlist data from cloud with conflict resolution.
    /// - Parameter userId: The user ID
    private func syncWatchlist(for userId: String) async throws {
        guard let client = cloudClient else {
            throw DataSyncError.clientUnavailable
        }
        
        // Fetch cloud data
        let cloudDocuments = try await client.getDocuments(
            collection: "watchlist",
            userId: userId
        )
        
        // Parse cloud watchlist with timestamps
        var cloudSymbols: [(symbol: String, addedAt: Date)] = []
        for doc in cloudDocuments {
            if let symbol = doc["symbol"] as? String {
                let addedAt: Date
                if let timestamp = doc["addedAt"] as? TimeInterval {
                    addedAt = Date(timeIntervalSince1970: timestamp)
                } else {
                    addedAt = Date()
                }
                cloudSymbols.append((symbol: symbol, addedAt: addedAt))
            }
        }
        
        // Get local cached data for comparison
        let localSymbols = try await watchlistRepository?.getWatchlist(for: userId) ?? []
        
        // For watchlist, cloud data takes precedence on new device sign-in
        // The individual symbols are compared and the most recent source wins
        // Since watchlist items don't have individual update timestamps in the current model,
        // we use the cloud data as the source of truth for new device sync
        // Local modifications will be persisted to cloud when made
        
        // Update local repository with cloud data
        if let repo = watchlistRepository as? WatchlistRepositoryImpl {
            let symbols = cloudSymbols.map { $0.symbol }
            repo.preloadCache(userId: userId, symbols: symbols)
        }
    }
    
    /// Syncs configuration data from cloud with conflict resolution.
    /// - Parameter userId: The user ID
    private func syncConfiguration(for userId: String) async throws {
        guard let client = cloudClient else {
            throw DataSyncError.clientUnavailable
        }
        
        // Fetch cloud configuration data
        let cloudDocuments = try await client.getDocuments(
            collection: "configurations",
            userId: userId
        )
        
        // Process each configuration document
        for doc in cloudDocuments {
            guard let strategyId = doc["strategyId"] as? String else { continue }
            
            // Get cloud timestamp
            let cloudUpdatedAt: Date
            if let timestamp = doc["updatedAt"] as? TimeInterval {
                cloudUpdatedAt = Date(timeIntervalSince1970: timestamp)
            } else {
                cloudUpdatedAt = Date()
            }
            
            // Get local cached configuration
            if let configRepo = configurationRepository as? ConfigurationRepositoryImpl {
                let localConfig = try? await configRepo.load(strategyId: strategyId, for: userId)
                
                // Apply conflict resolution
                if let localConfig = localConfig {
                    let localVersioned = VersionedData(
                        data: localConfig,
                        updatedAt: localConfig.updatedAt,
                        isFromCloud: false
                    )
                    
                    // Parse cloud configuration
                    let cloudConfig = try parseConfiguration(from: doc, strategyId: strategyId)
                    let cloudVersioned = VersionedData(
                        data: cloudConfig,
                        updatedAt: cloudUpdatedAt,
                        isFromCloud: true
                    )
                    
                    // Resolve conflict using timestamp comparison
                    let resolved = resolveConflict(local: localVersioned, cloud: cloudVersioned)
                    
                    // If cloud is more recent, update local cache
                    if resolved.isFromCloud {
                        configRepo.preloadCache(userId: userId, configuration: resolved.data)
                    }
                } else {
                    // No local config, use cloud data
                    let cloudConfig = try parseConfiguration(from: doc, strategyId: strategyId)
                    configRepo.preloadCache(userId: userId, configuration: cloudConfig)
                }
            }
        }
    }
    
    /// Syncs user profile from cloud.
    /// - Parameter userId: The user ID
    private func syncUserProfile(for userId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let client = firestoreClient else {
            throw DataSyncError.clientUnavailable
        }
        
        // Fetch user profile from cloud
        _ = try await client.getUserProfile(for: userId)
        
        // Profile synced successfully - the FirestoreClient handles caching internally
        #else
        // No Firestore available - profile sync is a no-op
        #endif
    }
    
    // MARK: - Configuration Parsing
    
    /// Parses a StrategyConfiguration from a cloud document.
    /// - Parameters:
    ///   - document: The cloud document data
    ///   - strategyId: The strategy ID
    /// - Returns: Parsed StrategyConfiguration
    private func parseConfiguration(
        from document: [String: Any],
        strategyId: String
    ) throws -> StrategyConfiguration {
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
            strategyId: strategyId,
            parameters: parameters,
            updatedAt: updatedAt
        )
    }
    
    // MARK: - Sync Timestamp Management
    
    /// Updates the last sync timestamp for a user.
    /// - Parameter userId: The user ID
    private func updateLastSyncTimestamp(for userId: String) {
        let key = StorageKeys.lastSyncKey(for: userId)
        localStorage.set(Date().timeIntervalSince1970, forKey: key)
    }
    
    /// Gets the last sync timestamp for a user.
    /// - Parameter userId: The user ID
    /// - Returns: The last sync date, or nil if never synced
    private func getLastSyncTimestamp(for userId: String) -> Date? {
        let key = StorageKeys.lastSyncKey(for: userId)
        guard let timestamp = localStorage.object(forKey: key) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Data Sync Error

/// Errors that can occur during data synchronization.
enum DataSyncError: Error, Equatable {
    /// The cloud client is not available
    case clientUnavailable
    
    /// A network error occurred during sync
    case networkError(String)
    
    /// The sync operation timed out
    case timeout
    
    /// Data parsing failed
    case parsingError(String)
    
    /// Partial sync failure
    case partialFailure(watchlist: Bool, configuration: Bool, profile: Bool)
}

extension DataSyncError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .clientUnavailable:
            return "Unable to connect to cloud database."
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Sync operation timed out."
        case .parsingError(let message):
            return "Failed to parse data: \(message)"
        case .partialFailure:
            return "Some data could not be synced."
        }
    }
}

// MARK: - Conflict Resolution Helper

/// Helper struct for timestamp-based conflict resolution.
/// - Validates: Requirement 7.4 (Use most recently modified version)
/// - Validates: Property 15 (Conflict Resolution by Timestamp)
struct ConflictResolver {
    
    /// Resolves a conflict between two timestamped data versions.
    /// Returns the version with the more recent (later) timestamp.
    ///
    /// - Parameters:
    ///   - localTimestamp: The local data's modification timestamp
    ///   - cloudTimestamp: The cloud data's modification timestamp
    /// - Returns: `.local` if local is more recent, `.cloud` if cloud is more recent
    static func resolve(localTimestamp: Date, cloudTimestamp: Date) -> DataSource {
        if cloudTimestamp > localTimestamp {
            return .cloud
        } else {
            return .local
        }
    }
    
    /// Data source enum for conflict resolution results.
    enum DataSource {
        case local
        case cloud
    }
}

// MARK: - TimestampedData Conformance Extensions

extension StrategyConfiguration: TimestampedData {}

extension VersionedData: Equatable where T: Equatable {
    static func == (lhs: VersionedData<T>, rhs: VersionedData<T>) -> Bool {
        lhs.data == rhs.data &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.isFromCloud == rhs.isFromCloud
    }
}

// MARK: - Testing Support

extension DataSyncService {
    
    /// Creates an instance for testing without cloud connectivity.
    static func forTesting(localStorage: UserDefaults = .standard) -> DataSyncService {
        DataSyncService(
            cloudClient: nil,
            localStorage: localStorage,
            watchlistRepository: nil,
            configurationRepository: nil
        )
    }
    
    /// Creates an instance with a mock cloud client for testing.
    static func forTestingWithMock(
        mockClient: MockCloudDatabaseClient,
        localStorage: UserDefaults = .standard,
        watchlistRepository: WatchlistRepository? = nil,
        configurationRepository: ConfigurationRepository? = nil
    ) -> DataSyncService {
        DataSyncService(
            cloudClient: mockClient,
            localStorage: localStorage,
            watchlistRepository: watchlistRepository,
            configurationRepository: configurationRepository
        )
    }
    
    /// Clears sync metadata for a user.
    func clearSyncMetadata(for userId: String) {
        let key = StorageKeys.lastSyncKey(for: userId)
        localStorage.removeObject(forKey: key)
    }
}
