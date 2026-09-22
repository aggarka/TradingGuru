//
//  BackgroundTaskLogger.swift
//  TradingGuru
//
//  Protocol and implementation for logging background task operations.
//  Implements comprehensive logging per Requirement 6.6.
//

import Foundation

// MARK: - Background Task Logger Protocol

/// Protocol for logging background task operations.
/// - Validates: Requirement 6.6 (Log all task operations)
protocol BackgroundTaskLogger {
    /// Logs when a background task is registered with the system.
    /// - Parameter taskId: The unique identifier of the registered task
    func logRegistration(taskId: String)
    
    /// Logs when a background task is scheduled for future execution.
    /// - Parameters:
    ///   - taskId: The unique identifier of the scheduled task
    ///   - scheduledFor: The date/time when the task is scheduled to run
    func logScheduled(taskId: String, scheduledFor: Date)
    
    /// Logs when there's an error scheduling a background task.
    /// - Parameters:
    ///   - taskId: The unique identifier of the task that failed to schedule
    ///   - error: The error that occurred during scheduling
    func logSchedulingError(taskId: String, error: Error)
    
    /// Logs when a background task is cancelled.
    /// - Parameter taskId: The unique identifier of the cancelled task
    func logCancellation(taskId: String)
    
    /// Logs when a background task begins execution.
    /// - Parameter taskId: The unique identifier of the executing task
    func logExecutionStarted(taskId: String)
    
    /// Logs when a background task completes execution.
    /// - Parameters:
    ///   - taskId: The unique identifier of the completed task
    ///   - resultsCount: The number of results produced
    ///   - errorsCount: The number of errors encountered
    func logExecutionCompleted(taskId: String, resultsCount: Int, errorsCount: Int)
    
    /// Logs when a background task fails during execution.
    /// - Parameters:
    ///   - taskId: The unique identifier of the failed task
    ///   - error: The error that caused the failure
    func logExecutionFailed(taskId: String, error: Error)
    
    /// Logs when a background task is skipped due to eligibility criteria.
    /// - Parameters:
    ///   - taskId: The unique identifier of the skipped task
    ///   - reason: The reason for skipping the task
    func logEligibilitySkipped(taskId: String, reason: String)
    
    /// Logs when partial results are saved during task execution.
    /// - Parameters:
    ///   - taskId: The unique identifier of the task
    ///   - savedCount: The number of partial results saved
    func logPartialResultsSaved(taskId: String, savedCount: Int)
}

// MARK: - Default Background Task Logger

/// Default implementation using print statements for background task logging.
/// In production, this could be extended to use os_log or other logging frameworks.
struct DefaultBackgroundTaskLogger: BackgroundTaskLogger {
    
    private let subsystem = "com.tradingguru"
    private let category = "BackgroundTask"
    
    func logRegistration(taskId: String) {
        print("[BGTask] Registered: \(taskId)")
    }
    
    func logScheduled(taskId: String, scheduledFor: Date) {
        let formatter = ISO8601DateFormatter()
        print("[BGTask] Scheduled \(taskId) for \(formatter.string(from: scheduledFor))")
    }
    
    func logSchedulingError(taskId: String, error: Error) {
        print("[BGTask] Scheduling error for \(taskId): \(error.localizedDescription)")
    }
    
    func logCancellation(taskId: String) {
        print("[BGTask] Cancelled: \(taskId)")
    }
    
    func logExecutionStarted(taskId: String) {
        print("[BGTask] Execution started: \(taskId)")
    }
    
    func logExecutionCompleted(taskId: String, resultsCount: Int, errorsCount: Int) {
        print("[BGTask] Execution completed: \(taskId) - Results: \(resultsCount), Errors: \(errorsCount)")
    }
    
    func logExecutionFailed(taskId: String, error: Error) {
        print("[BGTask] Execution failed: \(taskId) - \(error.localizedDescription)")
    }
    
    func logEligibilitySkipped(taskId: String, reason: String) {
        print("[BGTask] Skipped \(taskId): \(reason)")
    }
    
    func logPartialResultsSaved(taskId: String, savedCount: Int) {
        print("[BGTask] Partial results saved for \(taskId): \(savedCount) items")
    }
}
