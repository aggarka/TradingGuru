//
//  AuthenticationServiceImpl.swift
//  TradingGuru
//
//  Concrete implementation of AuthenticationService with session management.
//

import Foundation

/// Concrete implementation of the AuthenticationService protocol.
/// Manages user authentication, session lifecycle, and provider coordination.
///
/// - Validates: Requirements 1.2, 1.3, 1.4 (Sign-in flows for Google, Apple, Passkey)
/// - Validates: Requirement 1.5 (Create or retrieve user profile after auth)
/// - Validates: Requirement 1.7 (60-second timeout for authentication flow)
/// - Validates: Requirement 1.9 (30-day session maintenance)
/// - Validates: Requirement 1.10 (Sign-out clears session)
final class AuthenticationServiceImpl: AuthenticationService {
    
    // MARK: - Constants
    
    /// Session expiration duration: 30 days in seconds
    /// - Validates: Requirement 1.9
    private static let sessionDurationSeconds: TimeInterval = 30 * 24 * 60 * 60
    
    /// Authentication timeout duration: 60 seconds
    /// - Validates: Requirement 1.7
    private static let authTimeoutSeconds: TimeInterval = 60
    
    // MARK: - UserDefaults Keys
    
    /// Keys for persisting session data
    /// Note: For production use, consider migrating to Keychain for secure storage
    private enum StorageKeys {
        static let currentUser = "com.tradingguru.auth.currentUser"
        static let sessionExpiration = "com.tradingguru.auth.sessionExpiration"
        static let lastActivityDate = "com.tradingguru.auth.lastActivity"
    }
    
    // MARK: - Properties
    
    /// Storage for session data
    /// Note: In production, sensitive data should be stored in Keychain
    private let storage: UserDefaults
    
    /// Registered authentication providers keyed by type
    private var providers: [AuthProviderType: AuthenticationProvider] = [:]
    
    /// Optional callback for creating/retrieving user profile from database
    /// This would typically be injected for backend integration
    var userProfileHandler: ((AuthCredential, AuthProviderType) async throws -> User)?
    
    /// Optional callback for deleting user data from the database
    /// This should remove all user data (profile, watchlist, configurations, results)
    var userDeletionHandler: ((String) async throws -> Void)?
    
    // MARK: - AuthenticationService Protocol Properties
    
    /// The currently authenticated user, or nil if not authenticated.
    private(set) var currentUser: User? {
        get {
            guard let data = storage.data(forKey: StorageKeys.currentUser) else {
                return nil
            }
            return try? JSONDecoder().decode(User.self, from: data)
        }
        set {
            if let user = newValue {
                let data = try? JSONEncoder().encode(user)
                storage.set(data, forKey: StorageKeys.currentUser)
            } else {
                storage.removeObject(forKey: StorageKeys.currentUser)
            }
        }
    }
    
    /// Whether a user is currently authenticated with a valid session.
    var isAuthenticated: Bool {
        guard currentUser != nil else { return false }
        
        // Check if session has expired
        if let expiration = sessionExpirationDate, Date() > expiration {
            // Session expired, clear it
            clearSession()
            return false
        }
        
        return true
    }
    
    /// The date when the current session expires (30 days from last activity).
    /// - Validates: Requirement 1.9 (30-day session maintenance)
    var sessionExpirationDate: Date? {
        get {
            guard let timestamp = storage.object(forKey: StorageKeys.sessionExpiration) as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let date = newValue {
                storage.set(date.timeIntervalSince1970, forKey: StorageKeys.sessionExpiration)
            } else {
                storage.removeObject(forKey: StorageKeys.sessionExpiration)
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new AuthenticationServiceImpl instance.
    /// - Parameter storage: UserDefaults instance for session persistence (defaults to .standard)
    init(storage: UserDefaults = .standard) {
        self.storage = storage
    }
    
    // MARK: - Provider Registration
    
    /// Registers an authentication provider for use in sign-in flows.
    /// - Parameter provider: The authentication provider to register
    func registerProvider(_ provider: AuthenticationProvider) {
        providers[provider.providerType] = provider
    }
    
    /// Returns the registered provider for the given type.
    /// - Parameter type: The type of authentication provider
    /// - Returns: The registered provider, or nil if not registered
    func provider(for type: AuthProviderType) -> AuthenticationProvider? {
        return providers[type]
    }
    
    // MARK: - AuthenticationService Protocol Methods
    
    /// Signs in a user using the specified authentication provider.
    /// - Parameter provider: The type of authentication provider to use
    /// - Returns: The authenticated User
    /// - Throws: AuthError if authentication fails or times out
    /// - Note: Times out after 60 seconds per Requirement 1.7
    /// - Validates: Requirements 1.2, 1.3, 1.4 (Provider sign-in flows)
    /// - Validates: Requirement 1.5 (Create or retrieve user profile)
    /// - Validates: Requirement 1.7 (60-second timeout)
    func signIn(with providerType: AuthProviderType) async throws -> User {
        // Get the registered provider
        guard let provider = providers[providerType] else {
            throw AuthError.providerUnavailable
        }
        
        // Execute sign-in with timeout
        let credential = try await withTimeout(seconds: Self.authTimeoutSeconds) {
            try await provider.signIn()
        }
        
        // Create or retrieve user profile
        let user = try await createOrRetrieveUser(from: credential, providerType: providerType)
        
        // Store session data
        currentUser = user
        updateSessionExpiration()
        
        return user
    }
    
    /// Signs out the current user and clears the session.
    /// - Throws: AuthError if sign-out fails
    /// - Validates: Requirement 1.10 (Sign-out clears session)
    func signOut() async throws {
        // Sign out from the current provider if available
        if let user = currentUser,
           let provider = providers[user.authProvider] {
            try await provider.signOut()
        }
        
        // Clear all session data
        clearSession()
    }
    
    /// Refreshes the current session to extend its validity.
    /// Updates the session expiration to 30 days from now.
    /// - Throws: AuthError if session refresh fails
    /// - Validates: Requirement 1.9 (30-day session maintenance)
    func refreshSession() async throws {
        guard currentUser != nil else {
            throw AuthError.sessionExpired
        }
        
        // Check if session is still valid before refreshing
        if let expiration = sessionExpirationDate, Date() > expiration {
            clearSession()
            throw AuthError.sessionExpired
        }
        
        // Update session expiration
        updateSessionExpiration()
    }
    
    /// Deletes the current user's account and all associated data.
    /// This action is irreversible and will remove all user data from the cloud database
    /// and sign out the user locally.
    /// - Throws: AuthError.accountDeletionFailed if the operation fails
    /// - Note: Required for App Store compliance (account deletion requirement)
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.sessionExpired
        }
        
        do {
            // Delete user data from the cloud database if handler is provided
            if let deletionHandler = userDeletionHandler {
                try await deletionHandler(user.id)
            }
            
            // Sign out from the current provider if available
            if let provider = providers[user.authProvider] {
                try await provider.signOut()
            }
            
            // Clear all local session data
            clearSession()
            
        } catch {
            throw AuthError.accountDeletionFailed
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates or retrieves a user profile from the credential.
    /// - Parameters:
    ///   - credential: The authentication credential from the provider
    ///   - providerType: The type of provider used for authentication
    /// - Returns: The user profile
    /// - Throws: AuthError.profileOperationFailed if the operation fails
    /// - Validates: Requirement 1.5 (Create or retrieve user profile from database)
    private func createOrRetrieveUser(
        from credential: AuthCredential,
        providerType: AuthProviderType
    ) async throws -> User {
        // If a custom handler is provided (for backend integration), use it
        if let handler = userProfileHandler {
            do {
                return try await handler(credential, providerType)
            } catch {
                throw AuthError.profileOperationFailed
            }
        }
        
        // Default local user creation (for development/testing)
        // In production, this would integrate with a backend service
        // Use a stable user ID to persist data across sign-in sessions:
        // - For Apple Sign-In: credential.idToken contains Apple's stable user identifier
        // - For Google/others: use email if available, otherwise fall back to idToken
        let stableUserId: String
        if providerType == .apple {
            // Apple's user identifier is already in idToken (set by AppleAuthProvider)
            stableUserId = credential.idToken
        } else if let email = credential.email, !email.isEmpty {
            // Use email as stable identifier (lowercase for consistency)
            stableUserId = email.lowercased()
        } else {
            // Fall back to idToken
            stableUserId = credential.idToken
        }
        
        let user = User(
            id: stableUserId,
            email: credential.email,
            displayName: credential.displayName,
            authProvider: providerType,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        return user
    }
    
    /// Updates the session expiration date to 30 days from now.
    /// - Validates: Requirement 1.9 (30-day session maintenance)
    private func updateSessionExpiration() {
        let expirationDate = Date().addingTimeInterval(Self.sessionDurationSeconds)
        sessionExpirationDate = expirationDate
        storage.set(Date().timeIntervalSince1970, forKey: StorageKeys.lastActivityDate)
    }
    
    /// Clears all session data from storage.
    /// - Validates: Requirement 1.10 (Sign-out clears session)
    private func clearSession() {
        storage.removeObject(forKey: StorageKeys.currentUser)
        storage.removeObject(forKey: StorageKeys.sessionExpiration)
        storage.removeObject(forKey: StorageKeys.lastActivityDate)
    }
    
    /// Executes an async operation with a timeout.
    /// - Parameters:
    ///   - seconds: The timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: AuthError.timeout if the operation exceeds the timeout, or the operation's error
    /// - Validates: Requirement 1.7 (60-second timeout)
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
                throw AuthError.timeout
            }
            
            // Return the first result (either success or timeout)
            guard let result = try await group.next() else {
                throw AuthError.timeout
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
}

// MARK: - Session Validation Extension

extension AuthenticationServiceImpl {
    
    /// Checks if the current session is valid and not expired.
    /// - Returns: true if there is a valid, non-expired session
    func hasValidSession() -> Bool {
        return isAuthenticated
    }
    
    /// Returns the time remaining until session expiration.
    /// - Returns: The time interval until expiration, or nil if no session exists
    func timeUntilSessionExpiration() -> TimeInterval? {
        guard let expiration = sessionExpirationDate else {
            return nil
        }
        let remaining = expiration.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }
    
    /// Updates the last activity timestamp to extend the session.
    /// Call this method when the user performs actions in the app.
    /// - Validates: Requirement 1.9 (30-day session from last activity)
    func recordActivity() {
        guard isAuthenticated else { return }
        updateSessionExpiration()
    }
}
