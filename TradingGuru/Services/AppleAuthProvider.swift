//
//  AppleAuthProvider.swift
//  TradingGuru
//
//  Apple Sign-In authentication provider implementation.
//

import Foundation
import AuthenticationServices

/// Apple Sign-In authentication provider.
///
/// Implements the `AuthenticationProvider` protocol to handle Apple Sign-In flow
/// using AuthenticationServices framework. Extracts user credentials from
/// `ASAuthorizationAppleIDCredential` and maps Apple Sign-In errors to `AuthError`.
///
/// - Validates: Requirement 1.3 (Initiate Apple Sign-In flow and return credentials within 60s)
/// - Validates: Requirement 1.6 (Handle errors: invalid credentials, network error, provider unavailable)
final class AppleAuthProvider: NSObject, AuthenticationProvider {
    
    // MARK: - AuthenticationProvider Protocol
    
    /// The type of authentication provider.
    var providerType: AuthProviderType {
        return .apple
    }
    
    // MARK: - Private Properties
    
    /// Continuation for bridging delegate callbacks to async/await.
    private var signInContinuation: CheckedContinuation<AuthCredential, Error>?
    
    /// The presentation anchor for the authorization controller.
    private weak var presentationAnchor: ASPresentationAnchor?
    
    /// Flag to enable mock mode for development and testing
    private let useMockMode: Bool
    
    /// Mock delay to simulate network latency in mock mode (in seconds)
    private let mockDelay: TimeInterval
    
    // MARK: - Initialization
    
    /// Creates a new AppleAuthProvider instance.
    /// - Parameters:
    ///   - presentationAnchor: The window to present the Apple Sign-In sheet.
    ///                         If nil, uses the first key window scene window.
    ///   - useMockMode: Whether to use mock authentication (default: false)
    ///   - mockDelay: Simulated network delay in mock mode (default: 1.0 seconds)
    init(
        presentationAnchor: ASPresentationAnchor? = nil,
        useMockMode: Bool = false,
        mockDelay: TimeInterval = 1.0
    ) {
        self.presentationAnchor = presentationAnchor
        self.useMockMode = useMockMode
        self.mockDelay = mockDelay
        super.init()
    }
    
    // MARK: - AuthenticationProvider Protocol Methods
    
    /// Initiates the Apple Sign-In flow and returns credentials on success.
    ///
    /// This method presents the Apple Sign-In sheet, handles user authentication,
    /// and extracts the identity token and user information from the credential.
    ///
    /// - Returns: `AuthCredential` containing the identity token and user info
    /// - Throws: `AuthError` if sign-in fails or times out
    /// - Note: The 60-second timeout is enforced by `AuthenticationServiceImpl`
    /// - Validates: Requirement 1.3 (Apple Sign-In flow returns credentials)
    /// - Validates: Requirement 1.6 (Error handling for authentication failures)
    func signIn() async throws -> AuthCredential {
        // Use mock mode for development/testing
        if useMockMode {
            return try await performMockSignIn()
        }
        
        // Check if Apple Sign-In is available
        guard isAppleSignInAvailable() else {
            throw AuthError.providerUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            
            // Create Apple ID authorization request
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            // Create and configure the authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            // Perform the authorization request on the main thread
            DispatchQueue.main.async {
                authorizationController.performRequests()
            }
        }
    }
    
    /// Signs out the current user from Apple Sign-In.
    ///
    /// Note: Apple Sign-In doesn't have a server-side sign-out mechanism.
    /// The local session is cleared by the `AuthenticationServiceImpl`.
    ///
    /// - Throws: `AuthError` if sign-out fails (not applicable for Apple)
    func signOut() async throws {
        // Apple Sign-In doesn't require explicit sign-out.
        // The session management is handled by AuthenticationServiceImpl.
        // Users can revoke access through Settings > Apple ID > Sign-In with Apple.
    }
    
    // MARK: - Private Helper Methods
    
    /// Checks if Apple Sign-In is available on the current device.
    /// - Returns: true if Apple Sign-In can be used
    private func isAppleSignInAvailable() -> Bool {
        // Apple Sign-In requires iOS 13+ and a valid Apple ID configuration.
        // ASAuthorizationAppleIDProvider is always available on iOS 13+,
        // but the sign-in may fail if the device isn't configured properly.
        return true
    }
    
    /// Performs mock sign-in for development and testing.
    /// - Returns: Mock AuthCredential
    /// - Throws: AuthError if mock is configured to fail
    private func performMockSignIn() async throws -> AuthCredential {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        // Generate mock tokens
        let mockIdToken = "mock_apple_id_token_\(UUID().uuidString)"
        let mockAuthorizationCode = "mock_apple_auth_code_\(UUID().uuidString)"
        
        return AuthCredential(
            idToken: mockIdToken,
            accessToken: mockAuthorizationCode,
            refreshToken: nil,
            email: "user@icloud.com",
            displayName: "Apple User"
        )
    }
    
    /// Extracts authentication credential from Apple ID credential.
    /// - Parameter appleCredential: The credential returned from Apple Sign-In
    /// - Returns: `AuthCredential` with extracted user information
    /// - Throws: `AuthError.invalidCredentials` if identity token is missing
    private func extractCredential(from appleCredential: ASAuthorizationAppleIDCredential) throws -> AuthCredential {
        // Extract identity token (required)
        guard let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        
        // Extract authorization code (optional, used for server-side verification)
        let authorizationCode: String?
        if let codeData = appleCredential.authorizationCode {
            authorizationCode = String(data: codeData, encoding: .utf8)
        } else {
            authorizationCode = nil
        }
        
        // Extract user information
        // Note: Apple only provides full name and email on the first sign-in.
        // Subsequent sign-ins may not include this information.
        // However, appleCredential.user is a stable, unique identifier for this user
        // that remains consistent across sign-ins.
        let email = appleCredential.email
        let displayName = formatDisplayName(from: appleCredential.fullName)
        
        // Use Apple's stable user identifier as the idToken for consistent user ID
        // This ensures the same user gets the same ID across sign-in sessions
        let stableUserId = appleCredential.user
        
        return AuthCredential(
            idToken: stableUserId,  // Use stable user ID, not the JWT token
            accessToken: authorizationCode,
            refreshToken: identityToken,  // Store the actual identity token here if needed
            email: email,
            displayName: displayName
        )
    }
    
    /// Formats the display name from PersonNameComponents.
    /// - Parameter nameComponents: The name components from Apple Sign-In
    /// - Returns: A formatted display name, or nil if no name components are available
    private func formatDisplayName(from nameComponents: PersonNameComponents?) -> String? {
        guard let nameComponents = nameComponents else {
            return nil
        }
        
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formattedName = formatter.string(from: nameComponents)
        
        // Return nil if the formatted name is empty
        return formattedName.isEmpty ? nil : formattedName
    }
    
    /// Maps Apple Sign-In errors to AuthError types.
    /// - Parameter error: The error from ASAuthorizationController
    /// - Returns: Corresponding `AuthError`
    /// - Validates: Requirement 1.6 (Error categorization)
    private func mapError(_ error: Error) -> AuthError {
        guard let authError = error as? ASAuthorizationError else {
            // Unknown error type, treat as network error
            return AuthError.networkError(underlying: error.localizedDescription)
        }
        
        switch authError.code {
        case .canceled:
            // User canceled the sign-in flow
            return AuthError.invalidCredentials
            
        case .unknown:
            // Unknown error, could be network or provider issue
            return AuthError.networkError(underlying: authError.localizedDescription)
            
        case .invalidResponse:
            // Invalid response from Apple's servers
            return AuthError.invalidCredentials
            
        case .notHandled:
            // Authorization request not handled
            return AuthError.providerUnavailable
            
        case .failed:
            // Authorization failed
            return AuthError.invalidCredentials
            
        case .notInteractive:
            // Authorization requires user interaction but wasn't allowed
            return AuthError.providerUnavailable
            
        @unknown default:
            // Handle future error codes
            return AuthError.networkError(underlying: authError.localizedDescription)
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthProvider: ASAuthorizationControllerDelegate {
    
    /// Called when authorization completes successfully.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let continuation = signInContinuation else {
            return
        }
        signInContinuation = nil
        
        // Handle Apple ID credential
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            do {
                let credential = try extractCredential(from: appleIDCredential)
                continuation.resume(returning: credential)
            } catch {
                continuation.resume(throwing: error)
            }
        } else {
            // Unexpected credential type
            continuation.resume(throwing: AuthError.invalidCredentials)
        }
    }
    
    /// Called when authorization fails with an error.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        guard let continuation = signInContinuation else {
            return
        }
        signInContinuation = nil
        
        let authError = mapError(error)
        continuation.resume(throwing: authError)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {
    
    /// Provides the window to present the Apple Sign-In sheet.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use the provided presentation anchor if available
        if let anchor = presentationAnchor {
            return anchor
        }
        
        // Otherwise, find the first key window from the active window scene
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            return window
        }
        #endif
        
        // Fallback: return a new window (this shouldn't happen in normal usage)
        return ASPresentationAnchor()
    }
}
