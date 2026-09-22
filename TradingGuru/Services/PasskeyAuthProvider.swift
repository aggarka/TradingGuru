//
//  PasskeyAuthProvider.swift
//  TradingGuru
//
//  Passkey/WebAuthn authentication provider implementation.
//

import Foundation
import AuthenticationServices

/// Passkey/WebAuthn authentication provider using Apple's AuthenticationServices framework.
///
/// This provider handles Passkey credential creation (registration) and assertion (authentication)
/// flows using ASAuthorizationPlatformPublicKeyCredentialProvider.
///
/// - Validates: Requirement 1.4 (Passkey authentication flow returns credentials within 60s)
/// - Validates: Requirement 1.6 (Handle errors: invalid credentials, network error, provider unavailable)
final class PasskeyAuthProvider: NSObject, AuthenticationProvider {
    
    // MARK: - Constants
    
    /// The relying party identifier for Passkey authentication
    /// In production, this should match your app's associated domain
    private let relyingPartyIdentifier: String
    
    /// Challenge used for Passkey authentication
    /// In production, this should come from your backend server
    private var currentChallenge: Data?
    
    // MARK: - Properties
    
    /// The type of authentication provider
    let providerType: AuthProviderType = .passkey
    
    /// Continuation for async/await bridge with ASAuthorizationController delegate
    private var signInContinuation: CheckedContinuation<AuthCredential, Error>?
    
    /// The presentation context provider for displaying the authorization UI
    private weak var presentationContextProvider: ASAuthorizationControllerPresentationContextProviding?
    
    /// Flag to enable mock mode for development and testing
    private let useMockMode: Bool
    
    /// Mock delay to simulate network latency in mock mode (in seconds)
    private let mockDelay: TimeInterval
    
    // MARK: - Initialization
    
    /// Creates a new PasskeyAuthProvider instance.
    /// - Parameters:
    ///   - relyingPartyIdentifier: The relying party identifier (typically your app's domain)
    ///   - presentationContextProvider: Optional presentation context for authorization UI
    ///   - useMockMode: Whether to use mock authentication (default: false)
    ///   - mockDelay: Simulated network delay in mock mode (default: 1.0 seconds)
    init(
        relyingPartyIdentifier: String = "tradingguru.app",
        presentationContextProvider: ASAuthorizationControllerPresentationContextProviding? = nil,
        useMockMode: Bool = false,
        mockDelay: TimeInterval = 1.0
    ) {
        self.relyingPartyIdentifier = relyingPartyIdentifier
        self.presentationContextProvider = presentationContextProvider
        self.useMockMode = useMockMode
        self.mockDelay = mockDelay
        super.init()
    }
    
    // MARK: - AuthenticationProvider Protocol
    
    /// Initiates the Passkey sign-in flow and returns credentials on success.
    ///
    /// This method first checks if Passkey authentication is available on the device,
    /// then initiates the platform public key credential assertion flow.
    ///
    /// - Returns: AuthCredential containing the credential identifier
    /// - Throws: AuthError if sign-in fails
    /// - Validates: Requirement 1.4 (Passkey authentication flow)
    /// - Validates: Requirement 1.6 (Error handling for provider unavailable)
    func signIn() async throws -> AuthCredential {
        // Use mock mode for development/testing
        if useMockMode {
            return try await performMockSignIn()
        }
        
        // Check if Passkey is available on this device
        guard isPasskeyAvailable() else {
            throw AuthError.providerUnavailable
        }
        
        // Generate a challenge for the authentication request
        // In production, this should come from your backend server
        let challenge = generateChallenge()
        currentChallenge = challenge
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            
            // Create the platform public key credential provider
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: relyingPartyIdentifier
            )
            
            // Create an assertion request (for existing credentials)
            let assertionRequest = platformProvider.createCredentialAssertionRequest(
                challenge: challenge
            )
            
            // Create the authorization controller
            let authController = ASAuthorizationController(
                authorizationRequests: [assertionRequest]
            )
            
            authController.delegate = self
            
            // Set presentation context if available
            if let contextProvider = presentationContextProvider {
                authController.presentationContextProvider = contextProvider
            }
            
            // Perform the request
            authController.performRequests()
        }
    }
    
    /// Signs out the current user from Passkey.
    ///
    /// Passkey doesn't maintain a session state, so this is a no-op.
    /// The credentials remain stored in the device's keychain for future use.
    ///
    /// - Throws: AuthError if sign-out fails (never throws for Passkey)
    func signOut() async throws {
        // Passkey doesn't maintain session state - credentials are device-bound
        // No action needed for sign-out
        currentChallenge = nil
    }
    
    // MARK: - Passkey Registration
    
    /// Registers a new Passkey credential for the user.
    ///
    /// Call this method to create a new Passkey credential that can be used for future authentication.
    /// The user will be prompted to authenticate using biometrics or device passcode.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier for the user (from your backend)
    ///   - userName: The display name for the user
    /// - Returns: AuthCredential containing the newly created credential
    /// - Throws: AuthError if registration fails
    func register(userId: String, userName: String) async throws -> AuthCredential {
        // Check if Passkey is available on this device
        guard isPasskeyAvailable() else {
            throw AuthError.providerUnavailable
        }
        
        // Generate a challenge for the registration request
        let challenge = generateChallenge()
        currentChallenge = challenge
        
        // Convert userId to Data
        guard let userIdData = userId.data(using: .utf8) else {
            throw AuthError.invalidCredentials
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            
            // Create the platform public key credential provider
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: relyingPartyIdentifier
            )
            
            // Create a registration request (for new credentials)
            let registrationRequest = platformProvider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: userName,
                userID: userIdData
            )
            
            // Create the authorization controller
            let authController = ASAuthorizationController(
                authorizationRequests: [registrationRequest]
            )
            
            authController.delegate = self
            
            // Set presentation context if available
            if let contextProvider = presentationContextProvider {
                authController.presentationContextProvider = contextProvider
            }
            
            // Perform the request
            authController.performRequests()
        }
    }
    
    // MARK: - Private Helpers
    
    /// Checks if Passkey authentication is available on this device.
    ///
    /// Passkey requires iOS 15.0+ and platform authenticator support.
    ///
    /// - Returns: true if Passkey is available, false otherwise
    private func isPasskeyAvailable() -> Bool {
        // Passkey (Platform Public Key Credentials) requires iOS 15.0+
        if #available(iOS 15.0, *) {
            // ASAuthorizationPlatformPublicKeyCredentialProvider is available
            return true
        }
        return false
    }
    
    /// Performs mock sign-in for development and testing.
    /// - Returns: Mock AuthCredential
    /// - Throws: AuthError if mock is configured to fail
    private func performMockSignIn() async throws -> AuthCredential {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        // Generate mock credential
        let mockCredentialId = "mock_passkey_credential_\(UUID().uuidString)"
        let mockAuthenticatorData = "mock_authenticator_data_\(UUID().uuidString)"
        
        return AuthCredential(
            idToken: mockCredentialId,
            accessToken: mockAuthenticatorData,
            refreshToken: nil,
            email: "passkey-user@device.local",
            displayName: "Passkey User"
        )
    }
    
    /// Generates a random challenge for Passkey authentication.
    ///
    /// In production, this challenge should come from your backend server
    /// to ensure proper security and prevent replay attacks.
    ///
    /// - Returns: A random 32-byte challenge
    private func generateChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
    
    /// Maps ASAuthorizationError to AuthError.
    ///
    /// - Parameter error: The ASAuthorizationError from the framework
    /// - Returns: The corresponding AuthError
    /// - Validates: Requirement 1.6 (Error handling)
    private func mapAuthorizationError(_ error: ASAuthorizationError) -> AuthError {
        switch error.code {
        case .canceled:
            // User canceled the authorization
            return AuthError.invalidCredentials
            
        case .invalidResponse:
            // The authorization request received an invalid response
            return AuthError.invalidCredentials
            
        case .notHandled:
            // The authorization request was not handled
            return AuthError.providerUnavailable
            
        case .failed:
            // The authorization attempt failed
            return AuthError.invalidCredentials
            
        case .notInteractive:
            // The authorization request requires a user interface but cannot be presented
            return AuthError.providerUnavailable
            
        case .unknown:
            fallthrough
        @unknown default:
            return AuthError.networkError(underlying: error.localizedDescription)
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyAuthProvider: ASAuthorizationControllerDelegate {
    
    /// Called when authorization completes successfully.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { signInContinuation = nil }
        
        if #available(iOS 15.0, *) {
            // Handle platform public key credential assertion (sign-in)
            if let assertionCredential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                let credentialId = assertionCredential.credentialID.base64EncodedString()
                
                // Create AuthCredential from the assertion
                let credential = AuthCredential(
                    idToken: credentialId,
                    accessToken: assertionCredential.rawAuthenticatorData.base64EncodedString(),
                    refreshToken: nil,
                    email: nil,
                    displayName: nil
                )
                
                signInContinuation?.resume(returning: credential)
                return
            }
            
            // Handle platform public key credential registration (new credential)
            if let registrationCredential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                let credentialId = registrationCredential.credentialID.base64EncodedString()
                
                // Create AuthCredential from the registration
                let credential = AuthCredential(
                    idToken: credentialId,
                    accessToken: registrationCredential.rawAttestationObject?.base64EncodedString(),
                    refreshToken: nil,
                    email: nil,
                    displayName: nil
                )
                
                signInContinuation?.resume(returning: credential)
                return
            }
        }
        
        // Unsupported credential type
        signInContinuation?.resume(throwing: AuthError.invalidCredentials)
    }
    
    /// Called when authorization fails with an error.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { signInContinuation = nil }
        
        // Map the error to AuthError
        let authError: AuthError
        
        if let authorizationError = error as? ASAuthorizationError {
            authError = mapAuthorizationError(authorizationError)
        } else {
            // Unknown error - treat as network error
            authError = AuthError.networkError(underlying: error.localizedDescription)
        }
        
        signInContinuation?.resume(throwing: authError)
    }
}

// MARK: - Default Presentation Context Provider

/// Default presentation context provider that returns the key window.
/// Use this when you don't have a specific view controller to present from.
@available(iOS 15.0, *)
final class DefaultPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window from the active scene
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback to the first window
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first ?? ASPresentationAnchor()
        }
        return window
    }
}
