//
//  UserProfile.swift
//  TradingGuru
//
//  User profile data model for cloud storage and local caching.
//

import Foundation

// MARK: - User Profile Model

/// User profile data for cloud storage and local caching.
/// - Validates: Requirement 7.1 (Store user profiles in cloud database)
/// - Validates: Requirement 7.5 (Cache user profile data locally)
struct UserProfile: Codable, Equatable {
    /// The unique user identifier
    let userId: String
    
    /// The user's email address (optional)
    let email: String?
    
    /// The user's display name (optional)
    let displayName: String?
    
    /// The authentication provider used (google, apple, passkey)
    let authProvider: String
    
    /// When the user account was created
    let createdAt: Date
    
    /// When the user last logged in
    var lastLoginAt: Date
    
    /// User's settings for notifications and analysis
    var settings: UserSettings
    
    /// Creates a UserProfile from a User model and settings.
    /// - Parameters:
    ///   - user: The User model to create the profile from
    ///   - settings: The user settings (defaults to `.default`)
    init(from user: User, settings: UserSettings = .default) {
        self.userId = user.id
        self.email = user.email
        self.displayName = user.displayName
        self.authProvider = user.authProvider.rawValue
        self.createdAt = user.createdAt
        self.lastLoginAt = user.lastLoginAt
        self.settings = settings
    }
    
    /// Creates a UserProfile with explicit values.
    /// - Parameters:
    ///   - userId: The unique user identifier
    ///   - email: The user's email address
    ///   - displayName: The user's display name
    ///   - authProvider: The authentication provider string
    ///   - createdAt: When the account was created
    ///   - lastLoginAt: When the user last logged in
    ///   - settings: The user's settings
    init(
        userId: String,
        email: String?,
        displayName: String?,
        authProvider: String,
        createdAt: Date,
        lastLoginAt: Date,
        settings: UserSettings
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.authProvider = authProvider
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.settings = settings
    }
}
