//
//  WatchlistRepositoryImpl.swift
//  TradingGuru
//
//  Firestore-backed implementation of WatchlistRepository with local caching.
//

import Foundation

// MARK: - Cloud Database Protocol

/// Protocol for abstracting cloud database operations.
/// This allows for different implementations (Firestore, mock, etc.)
protocol CloudDatabaseClient {
    func getDocuments(collection: String, userId: String) async throws -> [[String: Any]]
    func setDocument(collection: String, userId: String, documentId: String, data: [String: Any]) async throws
    func deleteDocument(collection: String, userId: String, documentId: String) async throws
}

// MARK: - WatchlistRepositoryImpl

/// Implementation of WatchlistRepository with cloud database and local caching.
/// Provides CRUD operations for user watchlists with offline support.
///
/// - Validates: Requirement 2.1 (Retrieve watchlist from database)
/// - Validates: Requirement 2.2 (Add symbol and persist to database)
/// - Validates: Requirement 2.6 (Remove symbol and update database)
/// - Validates: Requirement 2.9 (Handle database unavailability and preserve local state)
/// - Validates: Requirement 7.1 (Store watchlists in cloud database)
/// - Validates: Requirement 7.2 (Persist changes within 5 seconds of modification)
final class WatchlistRepositoryImpl: WatchlistRepository {
    
    // MARK: - Constants
    
    /// Collection name for watchlist items
    private static let watchlistCollection = "watchlist"
    
    /// Maximum time to wait for database operations (5 seconds per Requirement 7.2)
    private static let operationTimeoutSeconds: TimeInterval = 5.0
    
    // MARK: - UserDefaults Keys for Local Cache
    
    private enum CacheKeys {
        static func watchlistKey(for userId: String) -> String {
            "com.tradingguru.watchlist.\(userId)"
        }
        static func lastUpdatedKey(for userId: String) -> String {
            "com.tradingguru.watchlist.lastUpdated.\(userId)"
        }
    }

    // MARK: - Properties
    
    /// Cloud database client for remote operations
    private let cloudClient: CloudDatabaseClient?
    
    /// Local storage for caching watchlist data
    private let localStorage: UserDefaults
    
    /// In-memory cache for faster access
    private var memoryCache: [String: [String]] = [:]
    
    // MARK: - Initialization
    
    /// Creates a new WatchlistRepositoryImpl instance.
    /// - Parameters:
    ///   - cloudClient: Cloud database client (optional, nil for local-only mode)
    ///   - localStorage: UserDefaults instance for local caching (defaults to .standard)
    init(
        cloudClient: CloudDatabaseClient? = nil,
        localStorage: UserDefaults = .standard
    ) {
        self.cloudClient = cloudClient
        self.localStorage = localStorage
    }
    
    // MARK: - WatchlistRepository Protocol Methods
    
    /// Retrieves the watchlist for a specific user.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: Array of ticker symbols in the user's watchlist
    /// - Throws: WatchlistError.databaseUnavailable if retrieval fails
    /// - Note: Falls back to local cache if cloud database is unavailable
    /// - Validates: Requirement 2.1 (Retrieve watchlist from database)
    /// - Validates: Requirement 2.9 (Handle database unavailability)
    func getWatchlist(for userId: String) async throws -> [String] {
        do {
            let symbols = try await fetchFromCloud(userId: userId)
            
            // Update local cache with fresh data
            updateLocalCache(userId: userId, symbols: symbols)
            
            return symbols
        } catch {
            // Attempt to retrieve from local cache on failure
            if let cachedSymbols = getFromLocalCache(userId: userId) {
                return cachedSymbols
            }
            
            // No cached data available, throw database unavailable error
            throw WatchlistError.databaseUnavailable
        }
    }

    /// Adds a ticker symbol to the user's watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to add (should be validated first)
    ///   - userId: The unique identifier of the user
    /// - Throws: WatchlistError if the operation fails
    /// - Note: Updates both cloud database and local cache
    /// - Validates: Requirement 2.2 (Add symbol to watchlist)
    /// - Validates: Requirement 7.2 (Persist changes within 5 seconds)
    func addSymbol(_ symbol: String, for userId: String) async throws {
        let normalizedSymbol = symbol.uppercased()
        
        do {
            try await addToCloud(userId: userId, symbol: normalizedSymbol)
            
            // Update local cache on success
            var currentSymbols = getFromLocalCache(userId: userId) ?? []
            if !currentSymbols.contains(normalizedSymbol) {
                currentSymbols.append(normalizedSymbol)
                updateLocalCache(userId: userId, symbols: currentSymbols)
            }
            
            // Update memory cache
            memoryCache[userId] = currentSymbols
            
        } catch {
            // Update local cache optimistically for offline support
            var currentSymbols = getFromLocalCache(userId: userId) ?? []
            if !currentSymbols.contains(normalizedSymbol) {
                currentSymbols.append(normalizedSymbol)
                updateLocalCache(userId: userId, symbols: currentSymbols)
                memoryCache[userId] = currentSymbols
            }
            
            // Rethrow as database unavailable for callers to handle
            throw WatchlistError.databaseUnavailable
        }
    }
    
    /// Removes a ticker symbol from the user's watchlist.
    /// - Parameters:
    ///   - symbol: The ticker symbol to remove
    ///   - userId: The unique identifier of the user
    /// - Throws: WatchlistError if the operation fails
    /// - Note: Updates both cloud database and local cache
    /// - Validates: Requirement 2.6 (Remove symbol from watchlist)
    /// - Validates: Requirement 7.2 (Persist changes within 5 seconds)
    func removeSymbol(_ symbol: String, for userId: String) async throws {
        let normalizedSymbol = symbol.uppercased()
        
        do {
            try await removeFromCloud(userId: userId, symbol: normalizedSymbol)
            
            // Update local cache on success
            var currentSymbols = getFromLocalCache(userId: userId) ?? []
            currentSymbols.removeAll { $0 == normalizedSymbol }
            updateLocalCache(userId: userId, symbols: currentSymbols)
            
            // Update memory cache
            memoryCache[userId] = currentSymbols
            
        } catch {
            // Update local cache optimistically for offline support
            var currentSymbols = getFromLocalCache(userId: userId) ?? []
            currentSymbols.removeAll { $0 == normalizedSymbol }
            updateLocalCache(userId: userId, symbols: currentSymbols)
            memoryCache[userId] = currentSymbols
            
            // Rethrow as database unavailable for callers to handle
            throw WatchlistError.databaseUnavailable
        }
    }

    // MARK: - Cloud Database Operations
    
    /// Fetches watchlist symbols from cloud database.
    /// - Parameter userId: The user ID to fetch watchlist for
    /// - Returns: Array of ticker symbols
    /// - Throws: Error if cloud operation fails or client unavailable
    private func fetchFromCloud(userId: String) async throws -> [String] {
        guard let client = cloudClient else {
            throw WatchlistError.databaseUnavailable
        }
        
        let documents = try await withTimeout(seconds: Self.operationTimeoutSeconds) {
            try await client.getDocuments(
                collection: Self.watchlistCollection,
                userId: userId
            )
        }
        
        let symbols = documents.compactMap { document -> String? in
            document["symbol"] as? String
        }
        
        return symbols.sorted()
    }
    
    /// Adds a symbol to cloud database.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - symbol: The symbol to add
    /// - Throws: Error if cloud operation fails
    private func addToCloud(userId: String, symbol: String) async throws {
        guard let client = cloudClient else {
            throw WatchlistError.databaseUnavailable
        }
        
        let data: [String: Any] = [
            "symbol": symbol,
            "addedAt": Date().timeIntervalSince1970
        ]
        
        try await withTimeout(seconds: Self.operationTimeoutSeconds) {
            try await client.setDocument(
                collection: Self.watchlistCollection,
                userId: userId,
                documentId: symbol,
                data: data
            )
        }
    }
    
    /// Removes a symbol from cloud database.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - symbol: The symbol to remove
    /// - Throws: Error if cloud operation fails
    private func removeFromCloud(userId: String, symbol: String) async throws {
        guard let client = cloudClient else {
            throw WatchlistError.databaseUnavailable
        }
        
        try await withTimeout(seconds: Self.operationTimeoutSeconds) {
            try await client.deleteDocument(
                collection: Self.watchlistCollection,
                userId: userId,
                documentId: symbol
            )
        }
    }

    // MARK: - Local Cache Operations
    
    /// Retrieves watchlist from local cache.
    /// - Parameter userId: The user ID
    /// - Returns: Array of symbols if cached, nil otherwise
    /// - Validates: Requirement 2.9 (Preserve local state on database unavailability)
    private func getFromLocalCache(userId: String) -> [String]? {
        // Check memory cache first for fast access
        if let cached = memoryCache[userId] {
            return cached
        }
        
        // Fall back to UserDefaults
        let key = CacheKeys.watchlistKey(for: userId)
        guard let data = localStorage.data(forKey: key),
              let symbols = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        
        // Populate memory cache
        memoryCache[userId] = symbols
        return symbols
    }
    
    /// Updates local cache with watchlist data.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - symbols: The symbols to cache
    /// - Validates: Requirement 2.9 (Preserve local state)
    private func updateLocalCache(userId: String, symbols: [String]) {
        // Update memory cache
        memoryCache[userId] = symbols
        
        // Persist to UserDefaults
        let key = CacheKeys.watchlistKey(for: userId)
        if let data = try? JSONEncoder().encode(symbols) {
            localStorage.set(data, forKey: key)
        }
        
        // Store last updated timestamp
        let timestampKey = CacheKeys.lastUpdatedKey(for: userId)
        localStorage.set(Date().timeIntervalSince1970, forKey: timestampKey)
    }
    
    /// Clears local cache for a user.
    /// - Parameter userId: The user ID to clear cache for
    func clearLocalCache(for userId: String) {
        memoryCache.removeValue(forKey: userId)
        localStorage.removeObject(forKey: CacheKeys.watchlistKey(for: userId))
        localStorage.removeObject(forKey: CacheKeys.lastUpdatedKey(for: userId))
    }

    // MARK: - Timeout Helper
    
    /// Executes an async operation with a timeout.
    /// - Parameters:
    ///   - seconds: The timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: WatchlistError.databaseUnavailable if operation times out or fails
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
                throw WatchlistError.databaseUnavailable
            }
            
            // Return the first result (either success or timeout)
            guard let result = try await group.next() else {
                throw WatchlistError.databaseUnavailable
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
}


// MARK: - Cache Status Extension

extension WatchlistRepositoryImpl {
    
    /// Returns whether there is cached data available for a user.
    /// - Parameter userId: The user ID to check
    /// - Returns: true if cached data exists
    func hasCachedData(for userId: String) -> Bool {
        return getFromLocalCache(userId: userId) != nil
    }
    
    /// Returns the last update timestamp for cached data.
    /// - Parameter userId: The user ID
    /// - Returns: The last update date, or nil if no cache exists
    func lastCacheUpdate(for userId: String) -> Date? {
        let key = CacheKeys.lastUpdatedKey(for: userId)
        guard let timestamp = localStorage.object(forKey: key) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Testing Support

extension WatchlistRepositoryImpl {
    
    /// Creates a local-only instance for testing without cloud database.
    /// - Parameter localStorage: UserDefaults instance for local storage
    /// - Returns: A configured instance for testing
    static func forTesting(localStorage: UserDefaults = .standard) -> WatchlistRepositoryImpl {
        return WatchlistRepositoryImpl(
            cloudClient: nil,
            localStorage: localStorage
        )
    }
    
    /// Preloads cache with test data.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - symbols: The symbols to preload
    func preloadCache(userId: String, symbols: [String]) {
        updateLocalCache(userId: userId, symbols: symbols)
    }
}
