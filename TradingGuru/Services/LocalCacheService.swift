//
//  LocalCacheService.swift
//  TradingGuru
//
//  Service for local data caching to support offline access.
//  Caches watchlist, configurations, and user profile data.
//

import Foundation

// MARK: - Cache Keys

/// Keys used for local cache storage.
private enum CacheKeys {
    static let cachePrefix = "com.tradingguru.cache"
    
    static func watchlist(for userId: String) -> String {
        "\(cachePrefix).watchlist.\(userId)"
    }
    
    static func configuration(strategyId: String, for userId: String) -> String {
        "\(cachePrefix).config.\(userId).\(strategyId)"
    }
    
    static func userProfile(for userId: String) -> String {
        "\(cachePrefix).profile.\(userId)"
    }
    
    static func analysisResults(for userId: String) -> String {
        "\(cachePrefix).results.\(userId)"
    }
    
    static func lastSyncTimestamp(for userId: String) -> String {
        "\(cachePrefix).lastSync.\(userId)"
    }
}

// MARK: - Cached Data Wrapper

/// Wrapper for cached data that includes metadata.
struct CachedData<T: Codable>: Codable {
    /// The cached data
    let data: T
    
    /// When the data was cached
    let cachedAt: Date
    
    /// Optional timestamp from the source (e.g., server updatedAt)
    let sourceTimestamp: Date?
    
    /// Creates a new cached data wrapper.
    init(data: T, cachedAt: Date = Date(), sourceTimestamp: Date? = nil) {
        self.data = data
        self.cachedAt = cachedAt
        self.sourceTimestamp = sourceTimestamp
    }
    
    /// Whether the cache is considered stale (older than the given interval).
    func isStale(after interval: TimeInterval) -> Bool {
        Date().timeIntervalSince(cachedAt) > interval
    }
}

// MARK: - Local Cache Service Protocol

/// Protocol for local caching operations.
/// - Validates: Requirement 7.5 (Display cached data when offline)
protocol LocalCacheServiceProtocol {
    // MARK: - Watchlist Caching
    
    /// Caches the watchlist for a user.
    func cacheWatchlist(_ symbols: [String], for userId: String) throws
    
    /// Retrieves the cached watchlist for a user.
    func getCachedWatchlist(for userId: String) -> CachedData<[String]>?
    
    // MARK: - Configuration Caching
    
    /// Caches a strategy configuration for a user.
    func cacheConfiguration(_ configuration: StrategyConfiguration, strategyId: String, for userId: String) throws
    
    /// Retrieves the cached configuration for a user and strategy.
    func getCachedConfiguration(strategyId: String, for userId: String) -> CachedData<StrategyConfiguration>?
    
    // MARK: - User Profile Caching
    
    /// Caches the user profile.
    func cacheUserProfile(_ profile: UserProfile, for userId: String) throws
    
    /// Retrieves the cached user profile.
    func getCachedUserProfile(for userId: String) -> CachedData<UserProfile>?
    
    // MARK: - Analysis Results Caching
    
    /// Caches analysis results for a user.
    func cacheAnalysisResults(_ results: [AnalysisResult], for userId: String) throws
    
    /// Retrieves cached analysis results for a user.
    func getCachedAnalysisResults(for userId: String) -> CachedData<[AnalysisResult]>?
    
    // MARK: - Sync Tracking
    
    /// Records the last successful sync timestamp.
    func recordSync(for userId: String)
    
    /// Gets the last sync timestamp for a user.
    func getLastSyncTimestamp(for userId: String) -> Date?
    
    // MARK: - Cache Management
    
    /// Clears all cached data for a user.
    func clearCache(for userId: String)
    
    /// Clears all cached data (for sign-out).
    func clearAllCache()
    
    /// Whether cached data exists for a user.
    func hasCachedData(for userId: String) -> Bool
}

// MARK: - Local Cache Service Implementation

/// Service for caching data locally using UserDefaults.
/// Provides offline access to previously fetched data.
///
/// This service acts as a secondary cache alongside Firestore's built-in
/// offline persistence, providing:
/// - Explicit cache management
/// - Cache timestamps for freshness checking
/// - Independent access without Firestore dependency
///
/// - Validates: Requirement 7.5 (Display cached data when network unavailable)
final class LocalCacheService: LocalCacheServiceProtocol {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide caching
    static let shared = LocalCacheService()
    
    // MARK: - Constants
    
    /// Default cache expiration interval (24 hours)
    static let defaultCacheExpiration: TimeInterval = 24 * 60 * 60
    
    // MARK: - Properties
    
    /// UserDefaults instance for storage
    private let storage: UserDefaults
    
    /// JSON encoder for serialization
    private let encoder: JSONEncoder
    
    /// JSON decoder for deserialization
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    /// Creates a new LocalCacheService instance.
    /// - Parameter storage: UserDefaults instance for persistence (defaults to .standard)
    init(storage: UserDefaults = .standard) {
        self.storage = storage
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Watchlist Caching
    
    /// Caches the watchlist for a user.
    /// - Parameters:
    ///   - symbols: The ticker symbols to cache
    ///   - userId: The user ID
    /// - Throws: Encoding error if serialization fails
    func cacheWatchlist(_ symbols: [String], for userId: String) throws {
        let cachedData = CachedData(data: symbols)
        let data = try encoder.encode(cachedData)
        storage.set(data, forKey: CacheKeys.watchlist(for: userId))
    }
    
    /// Retrieves the cached watchlist for a user.
    /// - Parameter userId: The user ID
    /// - Returns: Cached watchlist data with metadata, or nil if not cached
    func getCachedWatchlist(for userId: String) -> CachedData<[String]>? {
        guard let data = storage.data(forKey: CacheKeys.watchlist(for: userId)),
              let cached = try? decoder.decode(CachedData<[String]>.self, from: data) else {
            return nil
        }
        return cached
    }
    
    // MARK: - Configuration Caching
    
    /// Caches a strategy configuration for a user.
    /// - Parameters:
    ///   - configuration: The configuration to cache
    ///   - strategyId: The strategy identifier
    ///   - userId: The user ID
    /// - Throws: Encoding error if serialization fails
    func cacheConfiguration(_ configuration: StrategyConfiguration, strategyId: String, for userId: String) throws {
        let cachedData = CachedData(data: configuration, sourceTimestamp: configuration.updatedAt)
        let data = try encoder.encode(cachedData)
        storage.set(data, forKey: CacheKeys.configuration(strategyId: strategyId, for: userId))
    }
    
    /// Retrieves the cached configuration for a user and strategy.
    /// - Parameters:
    ///   - strategyId: The strategy identifier
    ///   - userId: The user ID
    /// - Returns: Cached configuration data with metadata, or nil if not cached
    func getCachedConfiguration(strategyId: String, for userId: String) -> CachedData<StrategyConfiguration>? {
        guard let data = storage.data(forKey: CacheKeys.configuration(strategyId: strategyId, for: userId)),
              let cached = try? decoder.decode(CachedData<StrategyConfiguration>.self, from: data) else {
            return nil
        }
        return cached
    }
    
    // MARK: - User Profile Caching
    
    /// Caches the user profile.
    /// - Parameters:
    ///   - profile: The user profile to cache
    ///   - userId: The user ID
    /// - Throws: Encoding error if serialization fails
    func cacheUserProfile(_ profile: UserProfile, for userId: String) throws {
        let cachedData = CachedData(data: profile, sourceTimestamp: profile.lastLoginAt)
        let data = try encoder.encode(cachedData)
        storage.set(data, forKey: CacheKeys.userProfile(for: userId))
    }
    
    /// Retrieves the cached user profile.
    /// - Parameter userId: The user ID
    /// - Returns: Cached profile data with metadata, or nil if not cached
    func getCachedUserProfile(for userId: String) -> CachedData<UserProfile>? {
        guard let data = storage.data(forKey: CacheKeys.userProfile(for: userId)),
              let cached = try? decoder.decode(CachedData<UserProfile>.self, from: data) else {
            return nil
        }
        return cached
    }
    
    // MARK: - Analysis Results Caching
    
    /// Caches analysis results for a user.
    /// - Parameters:
    ///   - results: The analysis results to cache
    ///   - userId: The user ID
    /// - Throws: Encoding error if serialization fails
    func cacheAnalysisResults(_ results: [AnalysisResult], for userId: String) throws {
        let cachedData = CachedData(data: results)
        let data = try encoder.encode(cachedData)
        storage.set(data, forKey: CacheKeys.analysisResults(for: userId))
    }
    
    /// Retrieves cached analysis results for a user.
    /// - Parameter userId: The user ID
    /// - Returns: Cached results data with metadata, or nil if not cached
    func getCachedAnalysisResults(for userId: String) -> CachedData<[AnalysisResult]>? {
        guard let data = storage.data(forKey: CacheKeys.analysisResults(for: userId)),
              let cached = try? decoder.decode(CachedData<[AnalysisResult]>.self, from: data) else {
            return nil
        }
        return cached
    }
    
    // MARK: - Sync Tracking
    
    /// Records the last successful sync timestamp.
    /// - Parameter userId: The user ID
    func recordSync(for userId: String) {
        storage.set(Date(), forKey: CacheKeys.lastSyncTimestamp(for: userId))
    }
    
    /// Gets the last sync timestamp for a user.
    /// - Parameter userId: The user ID
    /// - Returns: The last sync timestamp, or nil if never synced
    func getLastSyncTimestamp(for userId: String) -> Date? {
        return storage.object(forKey: CacheKeys.lastSyncTimestamp(for: userId)) as? Date
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached data for a user.
    /// - Parameter userId: The user ID
    func clearCache(for userId: String) {
        storage.removeObject(forKey: CacheKeys.watchlist(for: userId))
        storage.removeObject(forKey: CacheKeys.userProfile(for: userId))
        storage.removeObject(forKey: CacheKeys.analysisResults(for: userId))
        storage.removeObject(forKey: CacheKeys.lastSyncTimestamp(for: userId))
        
        // Clear all configuration caches for this user
        // Note: This clears configurations for known strategy IDs
        let knownStrategyIds = ["weekly_option"]
        for strategyId in knownStrategyIds {
            storage.removeObject(forKey: CacheKeys.configuration(strategyId: strategyId, for: userId))
        }
    }
    
    /// Clears all cached data (for sign-out).
    func clearAllCache() {
        // Get all keys with our cache prefix and remove them
        let allKeys = storage.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(CacheKeys.cachePrefix) {
            storage.removeObject(forKey: key)
        }
    }
    
    /// Whether cached data exists for a user.
    /// - Parameter userId: The user ID
    /// - Returns: True if any cached data exists for the user
    func hasCachedData(for userId: String) -> Bool {
        // Check if watchlist or profile is cached
        return getCachedWatchlist(for: userId) != nil ||
               getCachedUserProfile(for: userId) != nil
    }
}

// MARK: - Mock Local Cache Service for Testing

/// Mock implementation of LocalCacheServiceProtocol for testing.
final class MockLocalCacheService: LocalCacheServiceProtocol {
    
    // MARK: - Storage
    
    private var watchlistCache: [String: CachedData<[String]>] = [:]
    private var configurationCache: [String: CachedData<StrategyConfiguration>] = [:]
    private var profileCache: [String: CachedData<UserProfile>] = [:]
    private var resultsCache: [String: CachedData<[AnalysisResult]>] = [:]
    private var syncTimestamps: [String: Date] = [:]
    
    // MARK: - Watchlist Caching
    
    func cacheWatchlist(_ symbols: [String], for userId: String) throws {
        watchlistCache[userId] = CachedData(data: symbols)
    }
    
    func getCachedWatchlist(for userId: String) -> CachedData<[String]>? {
        return watchlistCache[userId]
    }
    
    // MARK: - Configuration Caching
    
    func cacheConfiguration(_ configuration: StrategyConfiguration, strategyId: String, for userId: String) throws {
        let key = "\(userId).\(strategyId)"
        configurationCache[key] = CachedData(data: configuration, sourceTimestamp: configuration.updatedAt)
    }
    
    func getCachedConfiguration(strategyId: String, for userId: String) -> CachedData<StrategyConfiguration>? {
        let key = "\(userId).\(strategyId)"
        return configurationCache[key]
    }
    
    // MARK: - User Profile Caching
    
    func cacheUserProfile(_ profile: UserProfile, for userId: String) throws {
        profileCache[userId] = CachedData(data: profile, sourceTimestamp: profile.lastLoginAt)
    }
    
    func getCachedUserProfile(for userId: String) -> CachedData<UserProfile>? {
        return profileCache[userId]
    }
    
    // MARK: - Analysis Results Caching
    
    func cacheAnalysisResults(_ results: [AnalysisResult], for userId: String) throws {
        resultsCache[userId] = CachedData(data: results)
    }
    
    func getCachedAnalysisResults(for userId: String) -> CachedData<[AnalysisResult]>? {
        return resultsCache[userId]
    }
    
    // MARK: - Sync Tracking
    
    func recordSync(for userId: String) {
        syncTimestamps[userId] = Date()
    }
    
    func getLastSyncTimestamp(for userId: String) -> Date? {
        return syncTimestamps[userId]
    }
    
    // MARK: - Cache Management
    
    func clearCache(for userId: String) {
        watchlistCache.removeValue(forKey: userId)
        profileCache.removeValue(forKey: userId)
        resultsCache.removeValue(forKey: userId)
        syncTimestamps.removeValue(forKey: userId)
        
        // Clear configuration caches
        let keysToRemove = configurationCache.keys.filter { $0.hasPrefix("\(userId).") }
        for key in keysToRemove {
            configurationCache.removeValue(forKey: key)
        }
    }
    
    func clearAllCache() {
        watchlistCache.removeAll()
        configurationCache.removeAll()
        profileCache.removeAll()
        resultsCache.removeAll()
        syncTimestamps.removeAll()
    }
    
    func hasCachedData(for userId: String) -> Bool {
        return watchlistCache[userId] != nil || profileCache[userId] != nil
    }
}
