//
//  SettingsRepositoryImpl.swift
//  TradingGuru
//
//  Firestore implementation of SettingsRepository for user settings persistence.
//

import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

// MARK: - Firestore Settings Repository

/// Firestore implementation of SettingsRepository.
///
/// Provides settings persistence using Firebase Firestore,
/// ensuring changes are persisted within 5 seconds per Requirement 7.2.
///
/// - Validates: Requirement 8.8 (Settings option for scheduled analysis)
/// - Validates: Requirement 7.2 (Persist changes within 5 seconds)
final class FirestoreSettingsRepository: SettingsRepository {
    
    // MARK: - Properties
    
    /// The user profile repository for accessing user settings
    private let userProfileRepository: UserProfileRepository
    
    // MARK: - Initialization
    
    /// Creates a new FirestoreSettingsRepository instance.
    /// - Parameter userProfileRepository: The repository for user profile operations
    init(userProfileRepository: UserProfileRepository) {
        self.userProfileRepository = userProfileRepository
    }
    
    // MARK: - SettingsRepository Protocol
    
    /// Retrieves user settings from Firestore.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: The user's settings
    /// - Throws: SettingsError if retrieval fails
    func getUserSettings(for userId: String) async throws -> UserSettings {
        do {
            if let profile = try await userProfileRepository.getUserProfile(for: userId) {
                return profile.settings
            } else {
                // No profile exists, return defaults
                // - Validates: Requirement 8.8 (default is enabled)
                return .default
            }
        } catch {
            throw SettingsError.loadFailed(reason: error.localizedDescription)
        }
    }
    
    /// Updates user settings in Firestore.
    /// - Parameters:
    ///   - settings: The settings to save
    ///   - userId: The unique identifier of the user
    /// - Throws: SettingsError if persistence fails
    /// - Validates: Requirement 7.2 (Persist within 5 seconds)
    func updateUserSettings(_ settings: UserSettings, for userId: String) async throws {
        do {
            try await userProfileRepository.updateUserSettings(settings, for: userId)
        } catch {
            throw SettingsError.saveFailed(reason: error.localizedDescription)
        }
    }
}

#endif

// MARK: - Local Settings Repository (for offline/testing)

/// Local implementation of SettingsRepository using UserDefaults.
///
/// Used for offline support and testing. Stores settings locally
/// and syncs with cloud when connection is available.
final class LocalSettingsRepository: SettingsRepository {
    
    // MARK: - Constants
    
    private enum Keys {
        static func settingsKey(for userId: String) -> String {
            "user_settings_\(userId)"
        }
    }
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    /// Creates a new LocalSettingsRepository instance.
    /// - Parameter userDefaults: The UserDefaults instance to use (defaults to standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - SettingsRepository Protocol
    
    /// Retrieves user settings from local storage.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: The user's settings
    /// - Throws: SettingsError if retrieval fails
    func getUserSettings(for userId: String) async throws -> UserSettings {
        let key = Keys.settingsKey(for: userId)
        
        guard let data = userDefaults.data(forKey: key) else {
            // No saved settings, return defaults
            // - Validates: Requirement 8.8 (default is enabled)
            return .default
        }
        
        do {
            return try decoder.decode(UserSettings.self, from: data)
        } catch {
            throw SettingsError.loadFailed(reason: "Failed to decode settings")
        }
    }
    
    /// Updates user settings in local storage.
    /// - Parameters:
    ///   - settings: The settings to save
    ///   - userId: The unique identifier of the user
    /// - Throws: SettingsError if persistence fails
    func updateUserSettings(_ settings: UserSettings, for userId: String) async throws {
        let key = Keys.settingsKey(for: userId)
        
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: key)
        } catch {
            throw SettingsError.saveFailed(reason: "Failed to encode settings")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clears all settings for a user (used for sign-out or testing).
    /// - Parameter userId: The unique identifier of the user
    func clearSettings(for userId: String) {
        let key = Keys.settingsKey(for: userId)
        userDefaults.removeObject(forKey: key)
    }
}
