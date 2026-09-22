//
//  User.swift
//  TradingGuru
//
//  User model representing an authenticated user in the system.
//

import Foundation

/// Represents an authenticated user in the TradingGuru application.
/// - Validates: Requirements 2.1, 4.1 (User profile management)
struct User: Codable, Identifiable, Equatable {
    /// Unique identifier for the user
    let id: String
    
    /// User's email address (may be nil for some auth providers)
    let email: String?
    
    /// User's display name
    let displayName: String?
    
    /// The authentication provider used to sign in
    let authProvider: AuthProviderType
    
    /// Timestamp when the user account was created
    let createdAt: Date
    
    /// Timestamp of the user's most recent login
    var lastLoginAt: Date
    
    /// Creates a new User instance.
    /// - Parameters:
    ///   - id: Unique identifier for the user
    ///   - email: User's email address (optional)
    ///   - displayName: User's display name (optional)
    ///   - authProvider: The authentication provider used
    ///   - createdAt: Account creation timestamp
    ///   - lastLoginAt: Last login timestamp
    init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        authProvider: AuthProviderType,
        createdAt: Date = Date(),
        lastLoginAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.authProvider = authProvider
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }
}
