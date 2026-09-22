//
//  LocalWatchlistRepository.swift
//  TradingGuru
//
//  Local-only implementation of WatchlistRepository using UserDefaults.
//  Use this for testing and development without requiring Firebase.
//

import Foundation

/// Local-only implementation of WatchlistRepository using UserDefaults.
/// 
/// This repository stores watchlist data locally on the device without
/// requiring any cloud backend. Perfect for:
/// - Development and testing
/// - Offline-first functionality
/// - Demo/preview modes
///
/// Data is persisted to UserDefaults and survives app restarts.
final class LocalWatchlistRepository: WatchlistRepository {
    
    // MARK: - Constants
    
    private enum StorageKeys {
        static func watchlistKey(for userId: String) -> String {
            "com.tradingguru.local.watchlist.\(userId)"
        }
    }
    
    // MARK: - Properties
    
    private let storage: UserDefaults
    
    /// Simulated network delay for realistic testing (optional)
    var simulatedDelay: TimeInterval = 0.2
    
    // MARK: - Initialization
    
    /// Creates a new LocalWatchlistRepository instance.
    /// - Parameter storage: UserDefaults instance for persistence (defaults to .standard)
    init(storage: UserDefaults = .standard) {
        self.storage = storage
    }
    
    // MARK: - WatchlistRepository Protocol
    
    /// Retrieves the watchlist for a specific user from local storage.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: Array of ticker symbols in the user's watchlist
    func getWatchlist(for userId: String) async throws -> [String] {
        // Simulate network delay for realistic UX
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        let key = StorageKeys.watchlistKey(for: userId)
        
        guard let data = storage.data(forKey: key),
              let symbols = try? JSONDecoder().decode([String].self, from: data) else {
            // Return empty array for new users (not an error)
            return []
        }
        
        return symbols.sorted()
    }
    
    /// Adds a ticker symbol to the user's watchlist in local storage.
    /// - Parameters:
    ///   - symbol: The ticker symbol to add
    ///   - userId: The unique identifier of the user
    func addSymbol(_ symbol: String, for userId: String) async throws {
        // Simulate network delay for realistic UX
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        let normalizedSymbol = symbol.uppercased()
        var symbols = try await getWatchlist(for: userId)
        
        // Avoid duplicates
        if !symbols.contains(normalizedSymbol) {
            symbols.append(normalizedSymbol)
            try saveWatchlist(symbols, for: userId)
        }
    }
    
    /// Removes a ticker symbol from the user's watchlist in local storage.
    /// - Parameters:
    ///   - symbol: The ticker symbol to remove
    ///   - userId: The unique identifier of the user
    func removeSymbol(_ symbol: String, for userId: String) async throws {
        // Simulate network delay for realistic UX
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        let normalizedSymbol = symbol.uppercased()
        var symbols = try await getWatchlist(for: userId)
        
        symbols.removeAll { $0 == normalizedSymbol }
        try saveWatchlist(symbols, for: userId)
    }
    
    // MARK: - Private Helpers
    
    /// Saves the watchlist to local storage.
    /// - Parameters:
    ///   - symbols: The symbols to save
    ///   - userId: The user ID
    private func saveWatchlist(_ symbols: [String], for userId: String) throws {
        let key = StorageKeys.watchlistKey(for: userId)
        let data = try JSONEncoder().encode(symbols)
        storage.set(data, forKey: key)
    }
    
    // MARK: - Testing Utilities
    
    /// Clears all watchlist data for a user.
    /// - Parameter userId: The user ID to clear data for
    func clearWatchlist(for userId: String) {
        let key = StorageKeys.watchlistKey(for: userId)
        storage.removeObject(forKey: key)
    }
    
    /// Preloads the watchlist with test data.
    /// - Parameters:
    ///   - symbols: The symbols to preload
    ///   - userId: The user ID
    func preload(symbols: [String], for userId: String) {
        do {
            try saveWatchlist(symbols, for: userId)
        } catch {
            print("Failed to preload watchlist: \(error)")
        }
    }
}
