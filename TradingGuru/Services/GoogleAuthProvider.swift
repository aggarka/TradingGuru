//
//  GoogleAuthProvider.swift
//  TradingGuru
//
//  Google OAuth authentication provider implementation.
//

import Foundation

// MARK: - Google Sign-In SDK Integration
//
// To use Google Sign-In in production, add the GoogleSignIn SDK to your project:
// 1. Add to Package.swift or via Xcode: https://github.com/google/GoogleSignIn-iOS
// 2. Configure your Google Cloud Console project with OAuth 2.0 credentials
// 3. Add the reversed client ID to URL schemes in Info.plist
// 4. Import GoogleSignIn and replace the stub implementation below
//
// Example Info.plist configuration:
// <key>CFBundleURLTypes</key>
// <array>
//   <dict>
//     <key>CFBundleURLSchemes</key>
//     <array>
//       <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
//     </array>
//   </dict>
// </array>
//
// For production: import GoogleSignIn

// MARK: - Google Sign-In Error Mapping

/// Maps Google Sign-In error codes to AuthError types.
/// Used to convert SDK-specific errors to our domain errors.
/// - Validates: Requirement 1.6 (Error categories: invalid credentials, network error, provider unavailable)
enum GoogleSignInErrorCode: Int {
    // Common Google Sign-In error codes
    case canceled = -5              // User canceled the sign-in flow
    case hasNoAuthInKeychain = -4   // No previous sign-in to restore
    case keychain = -3              // Keychain access error
    case emptyResponse = -2         // Empty response from server
    case unknown = -1               // Unknown error
    case networkError = 7           // Network unavailable
    case serverError = 8            // Server returned an error
    case invalidCredentials = 9     // Invalid credentials provided
    
    /// Converts Google Sign-In error code to AuthError.
    func toAuthError() -> AuthError {
        switch self {
        case .canceled, .hasNoAuthInKeychain:
            return .invalidCredentials
        case .networkError:
            return .networkError(underlying: "Network connection unavailable")
        case .serverError, .emptyResponse, .unknown:
            return .providerUnavailable
        case .keychain:
            return .providerUnavailable
        case .invalidCredentials:
            return .invalidCredentials
        }
    }
}

// MARK: - Google Auth Provider

/// Google OAuth authentication provider implementation.
///
/// This provider integrates with Google Sign-In SDK to authenticate users
/// via their Google accounts. It implements the `AuthenticationProvider` protocol
/// to provide a consistent interface with other auth providers.
///
/// - Validates: Requirement 1.2 (Google OAuth flow returns credentials within 60 seconds)
/// - Validates: Requirement 1.6 (Error handling for invalid credentials, network error, provider unavailable)
///
/// Usage:
/// ```swift
/// let googleProvider = GoogleAuthProvider()
/// let authService = AuthenticationServiceImpl()
/// authService.registerProvider(googleProvider)
///
/// // Sign in
/// let user = try await authService.signIn(with: .google)
/// ```
final class GoogleAuthProvider: AuthenticationProvider {
    
    // MARK: - Properties
    
    /// The type of authentication provider.
    let providerType: AuthProviderType = .google
    
    /// Flag to enable mock mode for development and testing.
    /// When true, uses mock credentials instead of actual Google Sign-In.
    private let useMockMode: Bool
    
    /// Mock delay to simulate network latency in mock mode (in seconds).
    private let mockDelay: TimeInterval
    
    /// Mock user data for development/testing.
    private var mockUserEmail: String?
    private var mockUserDisplayName: String?
    
    // MARK: - Initialization
    
    /// Creates a new GoogleAuthProvider instance.
    /// - Parameters:
    ///   - useMockMode: Whether to use mock authentication (default: true for development)
    ///   - mockDelay: Simulated network delay in mock mode (default: 1.0 seconds)
    init(useMockMode: Bool = true, mockDelay: TimeInterval = 1.0) {
        self.useMockMode = useMockMode
        self.mockDelay = mockDelay
    }
    
    // MARK: - Mock Configuration
    
    /// Configures mock user data for testing.
    /// - Parameters:
    ///   - email: The mock user's email address
    ///   - displayName: The mock user's display name
    func configureMockUser(email: String, displayName: String) {
        self.mockUserEmail = email
        self.mockUserDisplayName = displayName
    }
    
    // MARK: - AuthenticationProvider Protocol
    
    /// Initiates the Google Sign-In flow and returns credentials on success.
    ///
    /// In production mode, this method:
    /// 1. Presents the Google Sign-In UI to the user
    /// 2. Handles the OAuth 2.0 flow with Google's servers
    /// 3. Returns credentials containing the ID token and user info
    ///
    /// - Returns: AuthCredential containing the Google authentication tokens
    /// - Throws: AuthError if sign-in fails
    /// - Validates: Requirement 1.2 (Google OAuth flow returns credentials within 60 seconds)
    /// - Validates: Requirement 1.6 (Error handling)
    func signIn() async throws -> AuthCredential {
        if useMockMode {
            return try await performMockSignIn()
        } else {
            return try await performGoogleSignIn()
        }
    }
    
    /// Signs out the current user from Google.
    ///
    /// In production mode, this clears the Google Sign-In session
    /// and any cached tokens.
    ///
    /// - Throws: AuthError if sign-out fails
    func signOut() async throws {
        if useMockMode {
            // Mock mode: simulate sign-out
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            return
        }
        
        // Production implementation:
        // GIDSignIn.sharedInstance.signOut()
        //
        // For complete disconnection (revokes all tokens):
        // try await GIDSignIn.sharedInstance.disconnect()
    }
    
    // MARK: - Private Implementation
    
    /// Performs the actual Google Sign-In flow using the Google Sign-In SDK.
    /// - Returns: AuthCredential with Google tokens and user info
    /// - Throws: AuthError mapped from Google Sign-In errors
    private func performGoogleSignIn() async throws -> AuthCredential {
        // PRODUCTION IMPLEMENTATION
        //
        // To implement with Google Sign-In SDK:
        //
        // 1. Get the presenting view controller
        // guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        //       let presentingViewController = windowScene.windows.first?.rootViewController else {
        //     throw AuthError.providerUnavailable
        // }
        //
        // 2. Perform sign-in
        // do {
        //     let result = try await GIDSignIn.sharedInstance.signIn(
        //         withPresenting: presentingViewController
        //     )
        //
        //     guard let idToken = result.user.idToken?.tokenString else {
        //         throw AuthError.invalidCredentials
        //     }
        //
        //     return AuthCredential(
        //         idToken: idToken,
        //         accessToken: result.user.accessToken.tokenString,
        //         refreshToken: result.user.refreshToken?.tokenString,
        //         email: result.user.profile?.email,
        //         displayName: result.user.profile?.name
        //     )
        // } catch let error as NSError {
        //     throw mapGoogleError(error)
        // }
        
        // Placeholder for when SDK is not integrated
        throw AuthError.providerUnavailable
    }
    
    /// Performs mock sign-in for development and testing.
    /// - Returns: Mock AuthCredential
    /// - Throws: AuthError if mock is configured to fail
    private func performMockSignIn() async throws -> AuthCredential {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        // Generate mock tokens
        let mockIdToken = "mock_google_id_token_\(UUID().uuidString)"
        let mockAccessToken = "mock_google_access_token_\(UUID().uuidString)"
        let mockRefreshToken = "mock_google_refresh_token_\(UUID().uuidString)"
        
        return AuthCredential(
            idToken: mockIdToken,
            accessToken: mockAccessToken,
            refreshToken: mockRefreshToken,
            email: mockUserEmail ?? "user@gmail.com",
            displayName: mockUserDisplayName ?? "Test User"
        )
    }
    
    /// Maps Google Sign-In SDK errors to AuthError types.
    /// - Parameter error: The NSError from Google Sign-In SDK
    /// - Returns: The corresponding AuthError
    /// - Validates: Requirement 1.6 (Error categories)
    private func mapGoogleError(_ error: NSError) -> AuthError {
        // Check if it's a Google Sign-In error
        // In production, check: error.domain == GIDSignInErrorDomain
        
        if let errorCode = GoogleSignInErrorCode(rawValue: error.code) {
            return errorCode.toAuthError()
        }
        
        // Check for common network error domains
        if error.domain == NSURLErrorDomain {
            return .networkError(underlying: error.localizedDescription)
        }
        
        // Default to provider unavailable for unknown errors
        return .providerUnavailable
    }
}

// MARK: - Testing Support

extension GoogleAuthProvider {
    
    /// Creates a GoogleAuthProvider configured for unit testing.
    /// - Parameter mockCredential: Optional pre-configured credential to return
    /// - Returns: A configured test provider
    static func forTesting(
        mockEmail: String = "test@gmail.com",
        mockDisplayName: String = "Test User"
    ) -> GoogleAuthProvider {
        let provider = GoogleAuthProvider(useMockMode: true, mockDelay: 0.0)
        provider.configureMockUser(email: mockEmail, displayName: mockDisplayName)
        return provider
    }
}
