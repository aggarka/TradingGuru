//
//  AuthenticationProtocols.swift
//  TradingGuru
//
//  Protocol definitions for authentication providers and services.
//

import Foundation

// MARK: - Auth Credential

/// Represents credentials returned from an authentication provider.
struct AuthCredential {
    /// The unique identifier token from the provider
    let idToken: String
    
    /// Optional access token for API calls
    let accessToken: String?
    
    /// Optional refresh token for session renewal
    let refreshToken: String?
    
    /// The user's email if available from the provider
    let email: String?
    
    /// The user's display name if available
    let displayName: String?
    
    /// Creates a new AuthCredential instance.
    init(
        idToken: String,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        email: String? = nil,
        displayName: String? = nil
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.email = email
        self.displayName = displayName
    }
}

// MARK: - Authentication Provider Protocol

/// Protocol for authentication providers (Google, Apple, Passkey).
/// 
/// Each provider implements the sign-in flow specific to its platform,
/// returning credentials that can be used to create or authenticate a user.
/// 
/// - Validates: Requirements 1.2, 1.3, 1.4 (Provider-specific authentication flows)
protocol AuthenticationProvider {
    /// The type of authentication provider.
    var providerType: AuthProviderType { get }
    
    /// Initiates the sign-in flow and returns credentials on success.
    /// - Returns: AuthCredential containing the authentication tokens
    /// - Throws: AuthError if sign-in fails or times out
    func signIn() async throws -> AuthCredential
    
    /// Signs out the current user from this provider.
    /// - Throws: AuthError if sign-out fails
    func signOut() async throws
}

// MARK: - Authentication Service Protocol

/// Protocol for the main authentication service that manages user sessions.
/// 
/// The authentication service coordinates between providers and manages
/// the user session lifecycle including sign-in, sign-out, and session refresh.
/// 
/// - Validates: Requirements 1.1-1.10 (User authentication flow)
protocol AuthenticationService {
    /// The currently authenticated user, or nil if not authenticated.
    var currentUser: User? { get }
    
    /// Whether a user is currently authenticated.
    var isAuthenticated: Bool { get }
    
    /// The date when the current session expires (30 days from last activity).
    /// - Validates: Requirement 1.9 (30-day session maintenance)
    var sessionExpirationDate: Date? { get }
    
    /// Signs in a user using the specified authentication provider.
    /// - Parameter provider: The type of authentication provider to use
    /// - Returns: The authenticated User
    /// - Throws: AuthError if authentication fails
    /// - Note: Times out after 60 seconds per Requirement 1.7
    func signIn(with provider: AuthProviderType) async throws -> User
    
    /// Signs out the current user and clears the session.
    /// - Throws: AuthError if sign-out fails
    /// - Validates: Requirement 1.10 (Sign-out clears session)
    func signOut() async throws
    
    /// Refreshes the current session to extend its validity.
    /// - Throws: AuthError if session refresh fails
    func refreshSession() async throws
    
    /// Deletes the current user's account and all associated data.
    /// This action is irreversible and will:
    /// - Delete user data from the cloud database
    /// - Sign out and clear the local session
    /// - Throws: AuthError if account deletion fails
    /// - Note: Required for App Store compliance (account deletion requirement)
    func deleteAccount() async throws
}

// MARK: - Authentication Error

/// Errors that can occur during authentication operations.
/// - Validates: Requirement 1.6 (Error message categories)
enum AuthError: Error, Equatable {
    /// The provided credentials are invalid.
    case invalidCredentials
    
    /// A network error occurred during authentication.
    case networkError(underlying: String)
    
    /// The selected authentication provider is unavailable.
    case providerUnavailable
    
    /// The authentication operation timed out (60 seconds).
    /// - Validates: Requirement 1.7 (60-second timeout)
    case timeout
    
    /// Failed to create or retrieve the user profile after authentication.
    /// - Validates: Requirement 1.8 (Profile operation failure)
    case profileOperationFailed
    
    /// The current session has expired.
    case sessionExpired
    
    /// Failed to delete the user account.
    case accountDeletionFailed
    
    // Equatable conformance for network error
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials),
             (.providerUnavailable, .providerUnavailable),
             (.timeout, .timeout),
             (.profileOperationFailed, .profileOperationFailed),
             (.sessionExpired, .sessionExpired),
             (.accountDeletionFailed, .accountDeletionFailed):
            return true
        case let (.networkError(lhsMessage), .networkError(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Error Descriptions

extension AuthError: LocalizedError {
    /// Returns the error description using the catalog message.
    /// - Validates: Requirement 1.6 (Error message categories)
    var errorDescription: String? {
        return catalogMessage(provider: nil)
    }
    
    /// User-friendly error message from the error catalog.
    /// - Parameter provider: The authentication provider name for provider-specific messages
    /// - Validates: Requirement 1.6 (Display error indicating failure category)
    func catalogMessage(provider: String? = nil) -> String {
        switch self {
        case .invalidCredentials:
            return ErrorMessageCatalog.Authentication.invalidCredentials
        case .networkError:
            return ErrorMessageCatalog.Authentication.networkError
        case .providerUnavailable:
            if let provider = provider {
                return ErrorMessageCatalog.Authentication.providerUnavailable(provider)
            }
            return "Sign-in is temporarily unavailable. Please try another method."
        case .timeout:
            return ErrorMessageCatalog.Authentication.timeout
        case .profileOperationFailed:
            return ErrorMessageCatalog.Authentication.profileOperationFailed
        case .sessionExpired:
            return ErrorMessageCatalog.Authentication.sessionExpired
        case .accountDeletionFailed:
            return "Unable to delete your account. Please try again or contact support."
        }
    }
}
