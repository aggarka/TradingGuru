//
//  SettingsViewModel.swift
//  TradingGuru
//
//  ViewModel for managing user settings state and persistence.
//

import Foundation
import Observation

// MARK: - Settings Repository Protocol

/// Protocol for user settings persistence operations.
/// - Validates: Requirement 8.8 (Settings option for scheduled analysis)
protocol SettingsRepository {
    /// Retrieves user settings for a specific user.
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: The user's settings
    /// - Throws: SettingsError if retrieval fails
    func getUserSettings(for userId: String) async throws -> UserSettings
    
    /// Updates user settings for a specific user.
    /// - Parameters:
    ///   - settings: The settings to save
    ///   - userId: The unique identifier of the user
    /// - Throws: SettingsError if persistence fails
    func updateUserSettings(_ settings: UserSettings, for userId: String) async throws
}

// MARK: - Settings Error

/// Errors that can occur during settings operations.
enum SettingsError: Error, LocalizedError, Equatable {
    case loadFailed(reason: String)
    case saveFailed(reason: String)
    case databaseUnavailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return "Unable to load settings: \(reason)"
        case .saveFailed(let reason):
            return "Unable to save settings: \(reason)"
        case .databaseUnavailable:
            return "Database is currently unavailable. Please try again."
        case .networkError:
            return "Network error occurred. Please check your connection."
        }
    }
    
    /// User-friendly error message for display using catalog.
    var userMessage: String {
        return catalogMessage
    }
    
    /// User-friendly error message from the error catalog.
    var catalogMessage: String {
        switch self {
        case .loadFailed:
            return ErrorMessageCatalog.Settings.loadFailed
        case .saveFailed:
            return ErrorMessageCatalog.Settings.saveFailed
        case .databaseUnavailable, .networkError:
            return ErrorMessageCatalog.Database.retriesExhausted
        }
    }
}

// MARK: - Settings Save State

/// Represents the state of a settings save operation.
enum SettingsSaveState: Equatable {
    case idle
    case saving
    case saved(at: Date)
    case failed(error: String)
    
    var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }
    
    var statusMessage: String? {
        switch self {
        case .idle:
            return nil
        case .saving:
            return "Saving..."
        case .saved(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Saved at \(formatter.string(from: date))"
        case .failed(let error):
            return error
        }
    }
}

// MARK: - Settings ViewModel

/// ViewModel for managing user settings state and coordinating persistence.
///
/// Handles loading and saving user settings including the scheduled analysis toggle.
/// Settings changes are persisted to the database when modified.
///
/// - Validates: Requirement 8.8 (Settings option to enable/disable scheduled analysis)
/// - Validates: Requirement 1.2, 1.6 (Schedule/cancel background tasks on toggle)
/// - Validates: Requirement 3.1, 3.2 (Request notification permission on first enable)
/// - Validates: Requirement 5.1, 5.7 (Respect scheduledAnalysisEnabled toggle)
@Observable
final class SettingsViewModel {
    
    // MARK: - Published State
    
    /// Whether scheduled analysis is enabled for the user.
    /// - Validates: Requirement 8.8 (Default is enabled)
    private(set) var scheduledAnalysisEnabled: Bool = true
    
    /// Whether email notifications are enabled.
    private(set) var emailNotificationsEnabled: Bool = true
    
    /// The notification email address.
    private(set) var notificationEmail: String?
    
    /// Whether settings are currently loading.
    private(set) var isLoading = false
    
    /// The current save state.
    private(set) var saveState: SettingsSaveState = .idle
    
    /// The current error, if any.
    private(set) var currentError: SettingsError?
    
    /// Whether to show the error alert.
    var showError = false
    
    /// Whether to show the notification permission denied guidance.
    /// - Validates: Requirement 3.2 (Show guidance when permission denied)
    var showNotificationPermissionGuidance = false
    
    /// The current notification authorization status.
    private(set) var notificationAuthorizationStatus: NotificationAuthorizationStatus = .notDetermined
    
    // MARK: - Dependencies
    
    /// The repository for settings persistence.
    /// Exposed internally for creating ScheduleSettingsViewModel.
    let repository: SettingsRepository
    
    /// The user ID for the current authenticated user.
    /// Exposed internally for creating ScheduleSettingsViewModel.
    let userId: String
    
    /// The background analysis scheduler for managing scheduled tasks.
    /// - Validates: Requirement 1.2, 1.6 (Background task scheduling)
    private let backgroundScheduler: BackgroundAnalysisScheduling
    
    /// The local notification manager for permission handling.
    /// - Validates: Requirement 3.1 (Request notification permission)
    private let notificationManager: LocalNotificationManaging
    
    /// The current user settings (internal state).
    private var userSettings: UserSettings = .default
    
    /// Tracks whether scheduled analysis has been enabled before (for first-time permission request).
    private var hasRequestedNotificationPermission = false
    
    // MARK: - Initialization
    
    /// Creates a new SettingsViewModel instance.
    /// - Parameters:
    ///   - repository: The repository for settings persistence operations
    ///   - userId: The authenticated user's ID
    ///   - backgroundScheduler: The scheduler for background analysis tasks (defaults to shared instance)
    ///   - notificationManager: The manager for local notifications (defaults to LocalNotificationManager)
    init(
        repository: SettingsRepository,
        userId: String,
        backgroundScheduler: BackgroundAnalysisScheduling = BackgroundAnalysisScheduler.shared,
        notificationManager: LocalNotificationManaging = LocalNotificationManager()
    ) {
        self.repository = repository
        self.userId = userId
        self.backgroundScheduler = backgroundScheduler
        self.notificationManager = notificationManager
        
        // Apply defaults - Validates: Requirement 8.8 (default enabled)
        self.scheduledAnalysisEnabled = UserSettings.default.scheduledAnalysisEnabled
        self.emailNotificationsEnabled = UserSettings.default.emailNotificationsEnabled
        self.notificationEmail = UserSettings.default.notificationEmail
    }
    
    // MARK: - Load Settings
    
    /// Loads user settings from the repository.
    ///
    /// If loading fails, default values are applied and local state is preserved.
    /// - Validates: Requirement 7.5 (Display cached data when offline)
    @MainActor
    func loadSettings() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentError = nil
        
        do {
            let settings = try await repository.getUserSettings(for: userId)
            userSettings = settings
            scheduledAnalysisEnabled = settings.scheduledAnalysisEnabled
            emailNotificationsEnabled = settings.emailNotificationsEnabled
            notificationEmail = settings.notificationEmail
            isLoading = false
        } catch {
            isLoading = false
            // Apply defaults on load failure - preserve local state
            let defaultSettings = UserSettings.default
            scheduledAnalysisEnabled = defaultSettings.scheduledAnalysisEnabled
            emailNotificationsEnabled = defaultSettings.emailNotificationsEnabled
            notificationEmail = defaultSettings.notificationEmail
            
            let settingsError = (error as? SettingsError) ?? .loadFailed(reason: error.localizedDescription)
            currentError = settingsError
            showError = true
        }
    }
    
    // MARK: - Toggle Scheduled Analysis
    
    /// Toggles the scheduled analysis setting and persists to database.
    ///
    /// When enabled:
    /// - Requests notification permission on first enable
    /// - Updates background task scheduling
    ///
    /// When disabled:
    /// - Cancels all pending background tasks
    ///
    /// - Parameter enabled: Whether scheduled analysis should be enabled
    /// - Validates: Requirement 8.8 (Enable/disable scheduled analysis)
    /// - Validates: Requirement 1.2 (Submit task request when enabled)
    /// - Validates: Requirement 1.6 (Cancel pending tasks when disabled)
    /// - Validates: Requirement 3.1 (Request notification permission on first enable)
    /// - Validates: Requirement 3.2 (Handle permission denial)
    /// - Validates: Requirement 5.1 (Respect scheduledAnalysisEnabled toggle)
    /// - Validates: Requirement 5.7 (Cancel tasks when disabled)
    @MainActor
    func setScheduledAnalysisEnabled(_ enabled: Bool) async {
        let previousValue = scheduledAnalysisEnabled
        scheduledAnalysisEnabled = enabled
        
        // Update internal settings model
        var updatedSettings = userSettings
        updatedSettings.scheduledAnalysisEnabled = enabled
        updatedSettings.updatedAt = Date()
        
        saveState = .saving
        
        do {
            try await repository.updateUserSettings(updatedSettings, for: userId)
            userSettings = updatedSettings
            saveState = .saved(at: Date())
            
            // Handle background scheduling based on enabled state
            if enabled {
                // Request notification permission on first enable
                // - Validates: Requirement 3.1 (Request authorization on first enable)
                await requestNotificationPermissionIfNeeded()
                
                // Update background scheduling with the new settings
                // - Validates: Requirement 1.2 (Submit BGProcessingTaskRequest)
                // - Validates: Requirement 5.1 (Respect scheduledAnalysisEnabled toggle)
                backgroundScheduler.updateScheduling(for: updatedSettings)
            } else {
                // Cancel all pending background tasks when disabled
                // - Validates: Requirement 1.6 (Cancel pending BGProcessingTaskRequest)
                // - Validates: Requirement 5.7 (Cancel when disabled)
                backgroundScheduler.cancelPendingTasks()
            }
            
            // Reset save state after a delay
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if case .saved = saveState {
                saveState = .idle
            }
        } catch {
            // Revert to previous value on failure - preserve local state
            scheduledAnalysisEnabled = previousValue
            let settingsError = (error as? SettingsError) ?? .saveFailed(reason: error.localizedDescription)
            saveState = .failed(error: settingsError.catalogMessage)
            currentError = settingsError
            showError = true
        }
    }
    
    // MARK: - Notification Permission
    
    /// Requests notification permission if not already requested.
    /// Shows guidance to the user if permission is denied.
    /// - Validates: Requirement 3.1 (Request notification authorization)
    /// - Validates: Requirement 3.2 (Handle permission denial with guidance)
    @MainActor
    private func requestNotificationPermissionIfNeeded() async {
        // Check current authorization status first
        let status = await notificationManager.checkAuthorizationStatus()
        notificationAuthorizationStatus = status
        
        switch status {
        case .notDetermined:
            // First time - request permission
            let granted = await notificationManager.requestAuthorization()
            notificationAuthorizationStatus = granted ? .authorized : .denied
            
            // Show guidance if denied
            // - Validates: Requirement 3.2 (Show guidance when permission denied)
            if !granted {
                showNotificationPermissionGuidance = true
            }
            hasRequestedNotificationPermission = true
            
        case .denied:
            // Already denied - show guidance to enable in Settings
            // - Validates: Requirement 3.2 (Provide instructions to enable in iOS Settings)
            showNotificationPermissionGuidance = true
            
        case .authorized, .provisional:
            // Already authorized - no action needed
            break
        }
    }
    
    /// Refreshes the notification authorization status.
    /// Call this when the app returns from Settings to check if user enabled notifications.
    @MainActor
    func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await notificationManager.checkAuthorizationStatus()
        
        // Hide guidance if now authorized
        if notificationAuthorizationStatus == .authorized || notificationAuthorizationStatus == .provisional {
            showNotificationPermissionGuidance = false
        }
    }
    
    /// Requests notification permission from the user.
    /// Updates the authorization status after requesting.
    /// - Validates: Requirement 3.1 (Request notification authorization)
    /// - Validates: Requirement 3.2 (Handle permission denial with guidance)
    @MainActor
    func requestNotificationPermission() async {
        await requestNotificationPermissionIfNeeded()
    }
    
    /// Dismisses the notification permission guidance.
    @MainActor
    func dismissNotificationPermissionGuidance() {
        showNotificationPermissionGuidance = false
    }
    
    /// Sends a test notification to verify notification delivery is working.
    /// - Returns: True if the test notification was successfully sent
    @MainActor
    func sendTestNotification() async -> Bool {
        // First check if notifications are authorized
        let status = await notificationManager.checkAuthorizationStatus()
        notificationAuthorizationStatus = status
        
        guard status == .authorized || status == .provisional else {
            // Show permission guidance if not authorized
            showNotificationPermissionGuidance = true
            return false
        }
        
        return await notificationManager.sendTestNotification()
    }
    
    /// Toggles the email notifications setting and persists to database.
    ///
    /// - Parameter enabled: Whether email notifications should be enabled
    @MainActor
    func setEmailNotificationsEnabled(_ enabled: Bool) async {
        let previousValue = emailNotificationsEnabled
        emailNotificationsEnabled = enabled
        
        var updatedSettings = userSettings
        updatedSettings.emailNotificationsEnabled = enabled
        updatedSettings.updatedAt = Date()
        
        saveState = .saving
        
        do {
            try await repository.updateUserSettings(updatedSettings, for: userId)
            userSettings = updatedSettings
            saveState = .saved(at: Date())
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .saved = saveState {
                saveState = .idle
            }
        } catch {
            // Revert to previous value on failure - preserve local state
            emailNotificationsEnabled = previousValue
            let settingsError = (error as? SettingsError) ?? .saveFailed(reason: error.localizedDescription)
            saveState = .failed(error: settingsError.catalogMessage)
            currentError = settingsError
            showError = true
        }
    }
    
    /// Updates the notification email and persists to database.
    ///
    /// - Parameter email: The notification email address (nil to clear)
    @MainActor
    func setNotificationEmail(_ email: String?) async {
        let previousValue = notificationEmail
        notificationEmail = email
        
        var updatedSettings = userSettings
        updatedSettings.notificationEmail = email
        updatedSettings.updatedAt = Date()
        
        saveState = .saving
        
        do {
            try await repository.updateUserSettings(updatedSettings, for: userId)
            userSettings = updatedSettings
            saveState = .saved(at: Date())
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .saved = saveState {
                saveState = .idle
            }
        } catch {
            // Revert to previous value on failure - preserve local state
            notificationEmail = previousValue
            let settingsError = (error as? SettingsError) ?? .saveFailed(reason: error.localizedDescription)
            saveState = .failed(error: settingsError.catalogMessage)
            currentError = settingsError
            showError = true
        }
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error state.
    @MainActor
    func clearError() {
        currentError = nil
        showError = false
    }
}

// MARK: - Preview Support

#if DEBUG
/// Mock repository for SwiftUI previews
final class MockSettingsRepository: SettingsRepository {
    var settings: UserSettings = .default
    var shouldFail = false
    var simulatedDelay: TimeInterval = 0.3
    
    func getUserSettings(for userId: String) async throws -> UserSettings {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldFail {
            throw SettingsError.databaseUnavailable
        }
        return settings
    }
    
    func updateUserSettings(_ settings: UserSettings, for userId: String) async throws {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldFail {
            throw SettingsError.saveFailed(reason: "Mock failure")
        }
        self.settings = settings
    }
}

/// Mock background scheduler for SwiftUI previews
final class MockBackgroundScheduler: BackgroundAnalysisScheduling {
    var registeredTask = false
    var lastScheduledSettings: UserSettings?
    var cancelledTasks = false
    
    func registerBackgroundTask() {
        registeredTask = true
    }
    
    func updateScheduling(for settings: UserSettings) {
        lastScheduledSettings = settings
    }
    
    func cancelPendingTasks() {
        cancelledTasks = true
    }
    
    func handleBackgroundTask(_ task: Any) {
        // No-op for previews
    }
}

/// Mock notification manager for SwiftUI previews
final class MockNotificationManager: LocalNotificationManaging {
    var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    var authorizationGranted = true
    var lastNotifiedOrderCount: Int?
    var testNotificationSent = false
    
    func requestAuthorization() async -> Bool {
        return authorizationGranted
    }
    
    func checkAuthorizationStatus() async -> NotificationAuthorizationStatus {
        return authorizationStatus
    }
    
    func notifyIfAllowed(orderCount: Int, settings: UserSettings) async -> Bool {
        lastNotifiedOrderCount = orderCount
        return orderCount > 0
    }
    
    func sendTestNotification() async -> Bool {
        testNotificationSent = true
        return true
    }
}

extension SettingsViewModel {
    /// Creates a preview instance with mock dependencies
    static var preview: SettingsViewModel {
        let mockRepo = MockSettingsRepository()
        let mockScheduler = MockBackgroundScheduler()
        let mockNotificationManager = MockNotificationManager()
        return SettingsViewModel(
            repository: mockRepo,
            userId: "preview-user",
            backgroundScheduler: mockScheduler,
            notificationManager: mockNotificationManager
        )
    }
    
    /// Creates a preview instance with scheduled analysis disabled
    static var disabledPreview: SettingsViewModel {
        let mockRepo = MockSettingsRepository()
        mockRepo.settings.scheduledAnalysisEnabled = false
        let mockScheduler = MockBackgroundScheduler()
        let mockNotificationManager = MockNotificationManager()
        return SettingsViewModel(
            repository: mockRepo,
            userId: "preview-user",
            backgroundScheduler: mockScheduler,
            notificationManager: mockNotificationManager
        )
    }
    
    /// Creates a preview instance with notification permission denied
    static var notificationDeniedPreview: SettingsViewModel {
        let mockRepo = MockSettingsRepository()
        let mockScheduler = MockBackgroundScheduler()
        let mockNotificationManager = MockNotificationManager()
        mockNotificationManager.authorizationStatus = .denied
        mockNotificationManager.authorizationGranted = false
        return SettingsViewModel(
            repository: mockRepo,
            userId: "preview-user",
            backgroundScheduler: mockScheduler,
            notificationManager: mockNotificationManager
        )
    }
}
#endif
