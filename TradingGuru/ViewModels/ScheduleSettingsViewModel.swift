//
//  ScheduleSettingsViewModel.swift
//  TradingGuru
//
//  ViewModel for managing schedule time and notification frequency settings.
//

import Foundation
import Combine

/// ViewModel for managing schedule time and notification frequency settings.
///
/// Handles:
/// - Adding and removing schedule times with validation
/// - Updating notification frequency preferences
/// - Coordinating with BackgroundAnalysisScheduler for task scheduling
/// - Persisting settings to SettingsRepository
///
/// - Validates: Requirements 2.3, 2.4, 2.5, 2.6, 2.8 (Schedule time management)
/// - Validates: Requirement 4.6 (Notification frequency setting)
final class ScheduleSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The list of configured schedule times for background analysis.
    /// - Validates: Requirement 2.5 (1-8 schedule times)
    @Published private(set) var scheduleTimes: [ScheduleTime] = []
    
    /// The notification frequency preference.
    /// - Validates: Requirement 4.6 (Notification frequency setting)
    @Published var notificationFrequency: NotificationFrequency = .default {
        didSet {
            if oldValue != notificationFrequency {
                Task { @MainActor in
                    await saveSettings()
                }
            }
        }
    }
    
    /// Whether to show the time picker sheet.
    @Published var showTimePicker = false
    
    /// The current error message to display, if any.
    /// - Validates: Requirement 2.6 (Display error message for maximum limit)
    /// - Validates: Requirement 2.8 (Display message for minimum required)
    @Published var errorMessage: String?
    
    /// Whether settings are currently being saved.
    @Published private(set) var isSaving = false
    
    // MARK: - Computed Properties
    
    /// Whether more schedule times can be added.
    /// - Validates: Requirement 2.5 (Maximum of 8 schedule times)
    /// - Validates: Requirement 2.6 (Error when maximum reached)
    var canAddMoreTimes: Bool {
        scheduleTimes.count < UserSettings.maxScheduleTimes
    }
    
    /// The number of schedule times that can still be added.
    var remainingSlots: Int {
        max(0, UserSettings.maxScheduleTimes - scheduleTimes.count)
    }
    
    /// Whether the schedule times list is empty.
    var hasNoScheduleTimes: Bool {
        scheduleTimes.isEmpty
    }
    
    // MARK: - Dependencies
    
    /// The repository for settings persistence.
    private let settingsRepository: SettingsRepository
    
    /// The scheduler for background analysis tasks.
    private let scheduler: BackgroundAnalysisScheduling
    
    /// The user ID for the current authenticated user.
    private let userId: String
    
    /// Internal copy of user settings for modification.
    private var userSettings: UserSettings = .default
    
    // MARK: - Initialization
    
    /// Creates a new ScheduleSettingsViewModel instance.
    /// - Parameters:
    ///   - settingsRepository: The repository for settings persistence operations
    ///   - scheduler: The scheduler for background analysis tasks
    ///   - userId: The authenticated user's ID
    init(
        settingsRepository: SettingsRepository,
        scheduler: BackgroundAnalysisScheduling = BackgroundAnalysisScheduler.shared,
        userId: String
    ) {
        self.settingsRepository = settingsRepository
        self.scheduler = scheduler
        self.userId = userId
    }
    
    // MARK: - Load Settings
    
    /// Loads the schedule settings from the repository.
    @MainActor
    func loadSettings() async {
        do {
            let settings = try await settingsRepository.getUserSettings(for: userId)
            userSettings = settings
            scheduleTimes = settings.scheduleTimes
            notificationFrequency = settings.notificationFrequency
            errorMessage = nil
        } catch {
            // On load failure, use defaults
            scheduleTimes = UserSettings.defaultScheduleTimes
            notificationFrequency = .default
            errorMessage = "Unable to load settings. Using defaults."
        }
    }
    
    // MARK: - Add Schedule Time
    
    /// Adds a new schedule time to the list.
    ///
    /// Validates the time, checks for duplicates and capacity limits,
    /// then persists to the repository and updates background scheduling.
    ///
    /// - Parameter time: The schedule time to add
    /// - Validates: Requirement 2.3 (Add schedule time and persist)
    /// - Validates: Requirement 2.5 (Maximum of 8 schedule times)
    /// - Validates: Requirement 2.6 (Error when maximum reached)
    @MainActor
    func addScheduleTime(_ time: ScheduleTime) async {
        errorMessage = nil
        
        // Attempt to add the time to user settings
        let result = userSettings.addScheduleTime(time)
        
        switch result {
        case .success:
            scheduleTimes = userSettings.scheduleTimes
            await saveSettings()
            await updateBackgroundScheduling()
            
        case .failure(let error):
            // Display appropriate error message
            // - Validates: Requirement 2.6 (Error for maximum limit)
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Remove Schedule Time
    
    /// Removes a schedule time from the list.
    ///
    /// Removes the time from storage and updates background scheduling.
    ///
    /// - Parameter time: The schedule time to remove
    /// - Validates: Requirement 2.4 (Remove schedule time and update scheduling)
    @MainActor
    func removeScheduleTime(_ time: ScheduleTime) async {
        errorMessage = nil
        
        let removed = userSettings.removeScheduleTime(time)
        
        if removed {
            scheduleTimes = userSettings.scheduleTimes
            await saveSettings()
            await updateBackgroundScheduling()
        }
    }
    
    /// Removes schedule times at the specified offsets.
    ///
    /// - Parameter offsets: The index set of schedule times to remove
    /// - Validates: Requirement 2.4 (Remove schedule time and update scheduling)
    @MainActor
    func removeScheduleTimes(at offsets: IndexSet) async {
        let timesToRemove = offsets.map { scheduleTimes[$0] }
        
        for time in timesToRemove {
            _ = userSettings.removeScheduleTime(time)
        }
        
        scheduleTimes = userSettings.scheduleTimes
        await saveSettings()
        await updateBackgroundScheduling()
    }
    
    // MARK: - Update Background Scheduling
    
    /// Updates the background task scheduling based on current settings.
    ///
    /// Loads the current settings and calls the scheduler to update
    /// the background task registration.
    @MainActor
    func updateBackgroundScheduling() async {
        do {
            let settings = try await settingsRepository.getUserSettings(for: userId)
            scheduler.updateScheduling(for: settings)
        } catch {
            // If we can't load settings, use our local copy
            scheduler.updateScheduling(for: userSettings)
        }
    }
    
    // MARK: - Save Settings
    
    /// Persists the current settings to the repository.
    ///
    /// - Validates: Requirement 4.6 (Persist notification frequency)
    @MainActor
    func saveSettings() async {
        isSaving = true
        
        // Update the settings model
        userSettings.notificationFrequency = notificationFrequency
        userSettings.updatedAt = Date()
        
        do {
            try await settingsRepository.updateUserSettings(userSettings, for: userId)
            isSaving = false
        } catch {
            isSaving = false
            errorMessage = "Unable to save settings. Please try again."
        }
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error message.
    @MainActor
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Preview Support

#if DEBUG
extension ScheduleSettingsViewModel {
    /// Creates a preview instance with mock dependencies.
    static var preview: ScheduleSettingsViewModel {
        let mockRepo = MockSettingsRepository()
        return ScheduleSettingsViewModel(
            settingsRepository: mockRepo,
            scheduler: MockBackgroundAnalysisScheduler(),
            userId: "preview-user"
        )
    }
    
    /// Creates a preview instance with full schedule times (8).
    static var fullPreview: ScheduleSettingsViewModel {
        let mockRepo = MockSettingsRepository()
        // Create settings with 8 schedule times
        var settings = UserSettings.default
        settings.scheduleTimes = [
            ScheduleTime.create(hour: 6, minute: 0)!,
            ScheduleTime.create(hour: 8, minute: 0)!,
            ScheduleTime.create(hour: 10, minute: 0)!,
            ScheduleTime.create(hour: 12, minute: 0)!,
            ScheduleTime.create(hour: 14, minute: 0)!,
            ScheduleTime.create(hour: 16, minute: 0)!,
            ScheduleTime.create(hour: 18, minute: 0)!,
            ScheduleTime.create(hour: 20, minute: 0)!
        ]
        mockRepo.settings = settings
        
        let viewModel = ScheduleSettingsViewModel(
            settingsRepository: mockRepo,
            scheduler: MockBackgroundAnalysisScheduler(),
            userId: "preview-user"
        )
        viewModel.scheduleTimes = settings.scheduleTimes
        return viewModel
    }
    
    /// Creates a preview instance with empty schedule times.
    static var emptyPreview: ScheduleSettingsViewModel {
        let mockRepo = MockSettingsRepository()
        var settings = UserSettings.default
        settings.scheduleTimes = []
        mockRepo.settings = settings
        
        let viewModel = ScheduleSettingsViewModel(
            settingsRepository: mockRepo,
            scheduler: MockBackgroundAnalysisScheduler(),
            userId: "preview-user"
        )
        viewModel.scheduleTimes = []
        return viewModel
    }
}

/// Mock implementation of BackgroundAnalysisScheduling for testing.
final class MockBackgroundAnalysisScheduler: BackgroundAnalysisScheduling {
    var registeredTaskId: String?
    var lastSettings: UserSettings?
    var pendingTasksCancelled = false
    var handleBackgroundTaskCalled = false
    
    func registerBackgroundTask() {
        registeredTaskId = BackgroundAnalysisScheduler.taskIdentifier
    }
    
    func updateScheduling(for settings: UserSettings) {
        lastSettings = settings
    }
    
    func cancelPendingTasks() {
        pendingTasksCancelled = true
    }
    
    func handleBackgroundTask(_ task: Any) {
        handleBackgroundTaskCalled = true
    }
}
#endif
