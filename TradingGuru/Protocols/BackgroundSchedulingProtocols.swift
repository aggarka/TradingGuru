//
//  BackgroundSchedulingProtocols.swift
//  TradingGuru
//
//  Protocol definitions for background analysis scheduling operations.
//

import Foundation

// MARK: - Background Analysis Scheduling Protocol

/// Protocol for background analysis scheduling operations.
///
/// This protocol defines the interface for registering, scheduling, and managing
/// iOS BGProcessingTask executions for running automated analysis of the user's
/// watchlist in the background.
///
/// Implementations are responsible for:
/// - Registering background tasks with the iOS BackgroundTasks framework
/// - Scheduling tasks based on user-configured times
/// - Canceling pending tasks when the user disables scheduled analysis
/// - Handling task execution including analysis, result persistence, and notifications
///
/// - Validates: Requirement 1.1 (Register BGProcessingTask on app launch)
/// - Validates: Requirement 1.2 (Submit task when enabled with schedule times)
/// - Validates: Requirement 1.6 (Cancel tasks when disabled)
protocol BackgroundAnalysisScheduling {
    
    /// Registers the background task with the iOS BackgroundTasks framework.
    ///
    /// This method must be called during app launch, before
    /// `application(_:didFinishLaunchingWithOptions:)` returns. It registers
    /// the BGProcessingTask with the system using the task identifier
    /// "com.tradingguru.scheduledAnalysis".
    ///
    /// - Validates: Requirement 1.1 (Register BGProcessingTask with identifier)
    func registerBackgroundTask()
    
    /// Schedules or cancels background tasks based on current user settings.
    ///
    /// When `settings.scheduledAnalysisEnabled` is true and `settings.scheduleTimes`
    /// is not empty, this method submits a BGProcessingTaskRequest to the iOS system
    /// scheduler with the earliestBeginDate set to the next configured schedule time.
    ///
    /// When `settings.scheduledAnalysisEnabled` is false or `settings.scheduleTimes`
    /// is empty, this method cancels any pending task requests.
    ///
    /// - Parameter settings: The current user settings containing scheduling preferences
    /// - Validates: Requirement 1.2 (Submit task when enabled with schedule times)
    /// - Validates: Requirement 1.6 (Cancel tasks when disabled)
    func updateScheduling(for settings: UserSettings)
    
    /// Cancels all pending background task requests.
    ///
    /// This method cancels any previously submitted BGProcessingTaskRequest
    /// for the scheduled analysis task identifier.
    ///
    /// - Validates: Requirement 1.6 (Cancel pending BGProcessingTaskRequest)
    func cancelPendingTasks()
    
    /// Handles the background task execution.
    ///
    /// This method is called when iOS launches the background task. It performs
    /// the following operations:
    /// 1. Sets up an expiration handler for graceful termination
    /// 2. Verifies user eligibility using ScheduledAnalysisUserFilter
    /// 3. Executes analysis using WeeklyOptionStrategy.analyzeBatch()
    /// 4. Persists results using LocalResultsRepository
    /// 5. Triggers notifications via LocalNotificationManager if ORDER signals found
    /// 6. Schedules the next task occurrence
    ///
    /// - Parameter task: The BGProcessingTask provided by iOS. This is typed as `Any`
    ///   to allow for testing without importing BackgroundTasks framework directly.
    /// - Validates: Requirement 1.5 (Invoke WeeklyOptionStrategy.analyzeBatch())
    /// - Validates: Requirement 1.7 (Reschedule on termination)
    /// - Validates: Requirement 1.8 (Persist results and schedule next task)
    func handleBackgroundTask(_ task: Any)
}
