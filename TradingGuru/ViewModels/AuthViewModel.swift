//
//  AuthViewModel.swift
//  TradingGuru
//
//  ViewModel connecting AuthenticationView to AuthenticationService.
//  Manages authentication state transitions and profile creation/retrieval.
//

import Foundation
import Observation

/// ViewModel for managing authentication state and coordinating sign-in flows.
///
/// Connects the AuthenticationView to the AuthenticationService, handling:
/// - Authentication state transitions (loading, authenticated, error)
/// - Profile creation/retrieval after successful authentication
/// - Cross-device data synchronization before showing home screen
/// - Navigation state for post-auth flow
///
/// - Validates: Requirement 1.5 (Authentication succeeds → create/retrieve user profile, navigate to home)
/// - Validates: Requirement 1.8 (If profile creation/retrieval fails → display error, allow retry)
/// - Validates: Requirement 7.3 (Retrieve data on new device sign-in before displaying home screen)
@Observable
final class AuthViewModel {
    
    // MARK: - Authentication State
    
    /// Whether authentication is currently in progress
    private(set) var isLoading = false
    
    /// Whether data sync is currently in progress
    private(set) var isSyncing = false
    
    /// The currently authenticated user, if any
    private(set) var currentUser: User?
    
    /// The current error to display, if any
    private(set) var currentError: AuthError?
    
    /// Whether to show the error alert
    var showError = false
    
    /// The selected authentication provider being used
    private(set) var selectedProvider: AuthProviderType?
    
    /// Status message for sync progress
    private(set) var syncStatusMessage: String?
    
    // MARK: - Navigation State
    
    /// Flag indicating successful authentication - triggers navigation to home
    /// - Validates: Requirement 1.5 (navigate to home screen after successful auth)
    /// - Validates: Requirement 7.3 (retrieve data before displaying home screen)
    private(set) var shouldNavigateToHome = false
    
    // MARK: - Dependencies
    
    /// The authentication service for handling sign-in/sign-out
    private let authenticationService: AuthenticationService
    
    /// The data sync service for cross-device synchronization
    /// - Validates: Requirement 7.3 (Retrieve data on new device sign-in)
    private let dataSyncService: DataSyncServiceProtocol?
    
    // MARK: - Computed Properties
    
    /// Whether a user is currently authenticated
    var isAuthenticated: Bool {
        return authenticationService.isAuthenticated
    }
    
    /// The session expiration date, if a session exists
    var sessionExpirationDate: Date? {
        return authenticationService.sessionExpirationDate
    }
    
    /// Whether any loading operation is in progress
    var isProcessing: Bool {
        return isLoading || isSyncing
    }
    
    // MARK: - Initialization
    
    /// Creates a new AuthViewModel instance.
    /// - Parameters:
    ///   - authenticationService: The authentication service to use for sign-in operations
    ///   - dataSyncService: The data sync service for cross-device synchronization (optional)
    init(
        authenticationService: AuthenticationService,
        dataSyncService: DataSyncServiceProtocol? = nil
    ) {
        self.authenticationService = authenticationService
        self.dataSyncService = dataSyncService
        
        // Check if there's an existing authenticated user
        if let existingUser = authenticationService.currentUser {
            self.currentUser = existingUser
            self.shouldNavigateToHome = true
            
            // Set the user ID for background analysis scheduler so scheduled
            // analysis can access the correct user's watchlist and settings
            BackgroundAnalysisScheduler.shared.setCurrentUserId(existingUser.id)
            
            // Start foreground scheduled analysis monitoring
            ForegroundScheduledAnalysisService.shared.setCurrentUserId(existingUser.id)
        }
    }
    
    // MARK: - Sign In
    
    /// Initiates sign-in with the specified authentication provider.
    ///
    /// This method:
    /// 1. Sets loading state
    /// 2. Calls the authentication service to sign in
    /// 3. Syncs user data from cloud before displaying home screen
    /// 4. On success: stores the user and sets navigation flag
    /// 5. On failure: captures the error for display
    ///
    /// - Parameter provider: The authentication provider to use (Google, Apple, or Passkey)
    /// - Returns: The authenticated User on success
    /// - Throws: AuthError if authentication fails
    ///
    /// - Validates: Requirement 1.5 (create or retrieve user profile, navigate to home)
    /// - Validates: Requirement 1.8 (display error and allow retry on profile operation failure)
    /// - Validates: Requirement 7.3 (retrieve data on new device sign-in before displaying home screen)
    @MainActor
    func signIn(with provider: AuthProviderType) async throws -> User {
        guard !isLoading else {
            throw AuthError.providerUnavailable
        }
        
        // Set loading state
        isLoading = true
        selectedProvider = provider
        currentError = nil
        showError = false
        syncStatusMessage = nil
        
        do {
            // Attempt sign-in through the authentication service
            // This handles profile creation/retrieval internally
            let user = try await authenticationService.signIn(with: provider)
            
            // Store the user immediately
            currentUser = user
            
            // Set the user ID for background analysis scheduler so scheduled
            // analysis can access the correct user's watchlist and settings
            BackgroundAnalysisScheduler.shared.setCurrentUserId(user.id)
            
            // Start foreground scheduled analysis monitoring
            ForegroundScheduledAnalysisService.shared.setCurrentUserId(user.id)
            
            // Sync user data from cloud before displaying home screen
            // - Validates: Requirement 7.3 (retrieve data before displaying home screen)
            await syncUserDataAfterSignIn(userId: user.id)
            
            // Success - navigate to home
            shouldNavigateToHome = true
            isLoading = false
            isSyncing = false
            selectedProvider = nil
            syncStatusMessage = nil
            
            return user
            
        } catch let error as AuthError {
            // Handle authentication errors
            isLoading = false
            isSyncing = false
            selectedProvider = nil
            syncStatusMessage = nil
            currentError = error
            showError = true
            throw error
            
        } catch {
            // Handle unexpected errors as network errors
            isLoading = false
            isSyncing = false
            selectedProvider = nil
            syncStatusMessage = nil
            currentError = .networkError(underlying: error.localizedDescription)
            showError = true
            throw AuthError.networkError(underlying: error.localizedDescription)
        }
    }
    
    /// Syncs user data from cloud after sign-in.
    /// This ensures data is retrieved before displaying the home screen.
    ///
    /// - Parameter userId: The user ID to sync data for
    /// - Validates: Requirement 7.3 (retrieve existing watchlist and configurations from database before displaying home screen)
    @MainActor
    private func syncUserDataAfterSignIn(userId: String) async {
        guard let syncService = dataSyncService else {
            // No sync service available - proceed without sync
            return
        }
        
        // Check if sync is needed (new device or stale data)
        guard syncService.needsSync(for: userId) else {
            // Data is fresh, no sync needed
            return
        }
        
        // Set syncing state
        isSyncing = true
        syncStatusMessage = "Syncing your data..."
        
        do {
            // Perform sync - this retrieves watchlist and configurations
            let result = try await syncService.syncUserData(for: userId)
            
            // Update status based on result
            if result.success {
                syncStatusMessage = "Data synced successfully"
            } else if !result.errors.isEmpty {
                // Partial sync - continue with available data
                syncStatusMessage = "Some data could not be synced"
            }
            
        } catch {
            // Sync failed - log but continue to home screen
            // User will see cached data or defaults
            syncStatusMessage = "Sync failed, using cached data"
        }
        
        isSyncing = false
    }
    
    // MARK: - Sign Out
    
    /// Signs out the current user and resets authentication state.
    ///
    /// This method:
    /// 1. Calls the authentication service to sign out
    /// 2. Clears local user state
    /// 3. Resets navigation flag
    /// 4. Cancels scheduled background analysis tasks
    ///
    /// - Throws: AuthError if sign-out fails
    /// - Validates: Requirement 1.10 (sign-out clears session)
    @MainActor
    func signOut() async throws {
        do {
            try await authenticationService.signOut()
            
            // Cancel any pending background analysis tasks and clear user ID
            BackgroundAnalysisScheduler.shared.cancelPendingTasks()
            
            // Stop foreground scheduled analysis monitoring
            ForegroundScheduledAnalysisService.shared.stop()
            
            // Reset all state
            currentUser = nil
            shouldNavigateToHome = false
            currentError = nil
            showError = false
            
        } catch let error as AuthError {
            currentError = error
            showError = true
            throw error
        } catch {
            let authError = AuthError.networkError(underlying: error.localizedDescription)
            currentError = authError
            showError = true
            throw authError
        }
    }
    
    // MARK: - Account Deletion
    
    /// Whether account deletion is currently in progress
    private(set) var isDeletingAccount = false
    
    /// Deletes the current user's account and all associated data.
    ///
    /// This method:
    /// 1. Sets deletion in progress state
    /// 2. Calls the authentication service to delete the account
    /// 3. Clears local user state
    /// 4. Resets navigation flag
    /// 5. Cancels scheduled background analysis tasks
    ///
    /// This action is irreversible.
    ///
    /// - Throws: AuthError if account deletion fails
    /// - Note: Required for App Store compliance (account deletion requirement)
    @MainActor
    func deleteAccount() async throws {
        guard !isDeletingAccount else { return }
        
        isDeletingAccount = true
        currentError = nil
        showError = false
        
        do {
            try await authenticationService.deleteAccount()
            
            // Cancel any pending background analysis tasks and clear user ID
            BackgroundAnalysisScheduler.shared.cancelPendingTasks()
            
            // Stop foreground scheduled analysis monitoring
            ForegroundScheduledAnalysisService.shared.stop()
            
            // Reset all state
            currentUser = nil
            shouldNavigateToHome = false
            isDeletingAccount = false
            
        } catch let error as AuthError {
            isDeletingAccount = false
            currentError = error
            showError = true
            throw error
        } catch {
            isDeletingAccount = false
            let authError = AuthError.accountDeletionFailed
            currentError = authError
            showError = true
            throw authError
        }
    }
    
    // MARK: - Callback Handlers for AuthenticationView
    
    /// Provides a callback closure for the AuthenticationView's onSignIn handler.
    ///
    /// This bridges the callback-based pattern expected by AuthenticationView
    /// with the ViewModel's async sign-in method.
    ///
    /// - Returns: A closure that can be assigned to AuthenticationView.onSignIn
    func makeSignInHandler() -> ((AuthProviderType) async throws -> User) {
        return { [weak self] provider in
            guard let self = self else {
                throw AuthError.providerUnavailable
            }
            return try await self.signIn(with: provider)
        }
    }
    
    /// Provides a callback closure for the AuthenticationView's onAuthenticationSuccess handler.
    ///
    /// This is called after successful authentication to trigger any additional
    /// actions like navigation or state updates.
    ///
    /// - Returns: A closure that can be assigned to AuthenticationView.onAuthenticationSuccess
    func makeAuthenticationSuccessHandler() -> ((User) -> Void) {
        return { [weak self] user in
            self?.handleAuthenticationSuccess(user: user)
        }
    }
    
    /// Handles successful authentication by updating state.
    ///
    /// - Parameter user: The authenticated user
    /// - Validates: Requirement 1.5 (navigate to home screen)
    /// - Validates: Requirement for scheduled analysis (set user ID for background scheduler)
    @MainActor
    private func handleAuthenticationSuccess(user: User) {
        currentUser = user
        shouldNavigateToHome = true
        
        // Set the user ID for background analysis scheduler so scheduled
        // analysis can access the correct user's watchlist and settings
        BackgroundAnalysisScheduler.shared.setCurrentUserId(user.id)
        
        // Start foreground scheduled analysis monitoring
        ForegroundScheduledAnalysisService.shared.setCurrentUserId(user.id)
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error state.
    ///
    /// Call this when the user dismisses an error alert to allow retry.
    /// - Validates: Requirement 1.8 (allow retry after error)
    @MainActor
    func clearError() {
        currentError = nil
        showError = false
    }
    
    /// Retry authentication with the last used provider.
    ///
    /// - Returns: The authenticated User on success
    /// - Throws: AuthError if no previous provider was selected or authentication fails
    /// - Validates: Requirement 1.8 (allow retry after profile operation failure)
    @MainActor
    func retryAuthentication() async throws -> User {
        guard let provider = selectedProvider else {
            // If no provider selected, throw error
            throw AuthError.providerUnavailable
        }
        
        clearError()
        return try await signIn(with: provider)
    }
    
    // MARK: - Navigation Handling
    
    /// Resets the navigation flag after navigation has occurred.
    ///
    /// Call this after handling navigation to prevent repeated navigation attempts.
    @MainActor
    func didNavigateToHome() {
        shouldNavigateToHome = false
    }
    
    /// Resets the ViewModel to its initial state for showing the authentication screen.
    ///
    /// Useful when returning to the auth screen after sign-out.
    @MainActor
    func resetToAuthenticationScreen() {
        shouldNavigateToHome = false
        currentUser = nil
        currentError = nil
        showError = false
        isLoading = false
        selectedProvider = nil
    }
}

// MARK: - Preview Support

#if DEBUG
/// Mock authentication service for SwiftUI previews
final class MockAuthenticationService: AuthenticationService {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var sessionExpirationDate: Date?
    
    var shouldSucceed = true
    var simulatedDelay: TimeInterval = 0.5
    
    func signIn(with provider: AuthProviderType) async throws -> User {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        if shouldSucceed {
            let user = User(
                id: "mock-user-id",
                email: "test@example.com",
                displayName: "Test User",
                authProvider: provider
            )
            currentUser = user
            return user
        } else {
            throw AuthError.invalidCredentials
        }
    }
    
    func signOut() async throws {
        currentUser = nil
    }
    
    func refreshSession() async throws {
        guard currentUser != nil else {
            throw AuthError.sessionExpired
        }
    }
    
    func deleteAccount() async throws {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        if shouldSucceed {
            currentUser = nil
        } else {
            throw AuthError.accountDeletionFailed
        }
    }
}

extension AuthViewModel {
    /// Creates a preview instance with a mock authentication service
    static var preview: AuthViewModel {
        AuthViewModel(
            authenticationService: MockAuthenticationService(),
            dataSyncService: nil
        )
    }
    
    /// Creates a preview instance with a pre-authenticated user
    static var authenticatedPreview: AuthViewModel {
        let mockService = MockAuthenticationService()
        mockService.currentUser = User(
            id: "preview-user",
            email: "preview@example.com",
            displayName: "Preview User",
            authProvider: .google
        )
        return AuthViewModel(
            authenticationService: mockService,
            dataSyncService: nil
        )
    }
}
#endif
