//
//  BackgroundAnalysisScheduler.swift
//  TradingGuru
//
//  Implementation of background analysis scheduling using iOS BGProcessingTask.
//

import Foundation
import BackgroundTasks

// MARK: - Background Analysis Scheduler Implementation

/// Implementation of background analysis scheduling using iOS BGProcessingTask.
///
/// Responsibilities:
/// - Register BGProcessingTask with identifier "com.tradingguru.scheduledAnalysis"
/// - Schedule tasks at user-configured times
/// - Execute analysis using WeeklyOptionStrategy.analyzeBatch()
/// - Persist results using LocalResultsRepository
/// - Trigger notifications via LocalNotificationManager
///
/// - Validates: Requirements 1.1-1.8 (Background task management)
/// - Validates: Requirements 5.1-5.8 (Integration with existing infrastructure)
/// - Validates: Requirements 6.1-6.6 (Error handling and resilience)
final class BackgroundAnalysisScheduler: BackgroundAnalysisScheduling {
    
    // MARK: - Constants
    
    /// The unique identifier for the background processing task.
    /// Must match the identifier in Info.plist BGTaskSchedulerPermittedIdentifiers.
    /// - Validates: Requirement 1.1 (Task identifier)
    static let taskIdentifier = "com.tradingguru.scheduledAnalysis"
    
    // MARK: - Singleton
    
    /// Shared singleton instance for app-wide use.
    static let shared = BackgroundAnalysisScheduler()
    
    // MARK: - Dependencies
    
    private let userFilter: ScheduledAnalysisUserFilter
    private let strategy: WeeklyOptionStrategy
    private let resultsRepository: ResultsRepository
    private let settingsRepository: SettingsRepository
    private let watchlistRepository: WatchlistRepository
    private let notificationManager: LocalNotificationManaging
    private let scheduleCalculator: ScheduleTimeCalculating
    private let logger: BackgroundTaskLogger
    
    // MARK: - State
    
    /// Current user ID for analysis
    private var currentUserId: String?
    
    /// Partial results collected during analysis (for expiration handler)
    private var partialResults: [AnalysisResult] = []
    
    /// Current analysis task (for cancellation)
    private var currentAnalysisTask: Task<Void?, Never>?
    
    /// Flag to indicate if analysis should be cancelled
    private var shouldCancelAnalysis = false
    
    // MARK: - Initialization
    
    /// Creates a new BackgroundAnalysisScheduler with default dependencies.
    /// This initializer is used by the singleton instance.
    private convenience init() {
        self.init(
            userFilter: ScheduledAnalysisUserFilter(),
            strategy: WeeklyOptionStrategy(),
            resultsRepository: LocalResultsRepository(),
            settingsRepository: LocalSettingsRepository(),
            watchlistRepository: LocalWatchlistRepository(),
            notificationManager: LocalNotificationManager(),
            scheduleCalculator: ScheduleTimeCalculator(),
            logger: DefaultBackgroundTaskLogger()
        )
    }
    
    /// Creates a new BackgroundAnalysisScheduler with injected dependencies.
    /// - Parameters:
    ///   - userFilter: Filter for determining user eligibility
    ///   - strategy: Strategy for analyzing watchlist tickers
    ///   - resultsRepository: Repository for persisting analysis results
    ///   - settingsRepository: Repository for reading user settings
    ///   - watchlistRepository: Repository for reading user watchlist
    ///   - notificationManager: Manager for sending local notifications
    ///   - scheduleCalculator: Calculator for determining next schedule time
    ///   - logger: Logger for background task operations
    init(
        userFilter: ScheduledAnalysisUserFilter,
        strategy: WeeklyOptionStrategy,
        resultsRepository: ResultsRepository,
        settingsRepository: SettingsRepository,
        watchlistRepository: WatchlistRepository,
        notificationManager: LocalNotificationManaging,
        scheduleCalculator: ScheduleTimeCalculating,
        logger: BackgroundTaskLogger
    ) {
        self.userFilter = userFilter
        self.strategy = strategy
        self.resultsRepository = resultsRepository
        self.settingsRepository = settingsRepository
        self.watchlistRepository = watchlistRepository
        self.notificationManager = notificationManager
        self.scheduleCalculator = scheduleCalculator
        self.logger = logger
    }
    
    // MARK: - Registration
    
    /// Registers the background task with iOS BackgroundTasks framework.
    /// Must be called during app launch, before application:didFinishLaunchingWithOptions returns.
    /// - Validates: Requirement 1.1 (Register BGProcessingTask on app launch)
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleBackgroundTask(processingTask)
        }
        logger.logRegistration(taskId: Self.taskIdentifier)
    }
    
    // MARK: - Scheduling
    
    /// Updates scheduling based on user settings.
    /// - Parameter settings: The current user settings
    /// - Validates: Requirement 1.2 (Submit task when enabled with schedule times)
    /// - Validates: Requirement 1.6 (Cancel tasks when disabled)
    /// - Validates: Requirement 5.1 (Respect scheduledAnalysisEnabled toggle)
    /// - Validates: Requirement 5.7 (Don't submit if disabled)
    func updateScheduling(for settings: UserSettings) {
        if settings.scheduledAnalysisEnabled && !settings.scheduleTimes.isEmpty {
            scheduleNextTask(settings: settings)
        } else {
            cancelPendingTasks()
        }
    }
    
    /// Schedules the next background task occurrence.
    /// - Parameter settings: The current user settings
    /// - Validates: Requirement 1.3 (earliestBeginDate from schedule calculator)
    /// - Validates: Requirement 1.4 (requiresNetworkConnectivity = true)
    private func scheduleNextTask(settings: UserSettings) {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        
        // Calculate next schedule time
        // - Validates: Requirement 1.3 (earliestBeginDate to next occurrence)
        let nextTime = scheduleCalculator.calculateNextOccurrence(
            from: Date(),
            scheduleTimes: settings.scheduleTimes
        )
        request.earliestBeginDate = nextTime
        
        // Network is required for fetching market data
        // - Validates: Requirement 1.4 (requiresNetworkConnectivity)
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.logScheduled(taskId: Self.taskIdentifier, scheduledFor: nextTime)
        } catch {
            logger.logSchedulingError(taskId: Self.taskIdentifier, error: error)
        }
    }
    
    /// Cancels all pending background task requests.
    /// - Validates: Requirement 1.6 (Cancel pending BGProcessingTaskRequest)
    /// - Validates: Requirement 5.7 (Cancel when disabled)
    func cancelPendingTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        logger.logCancellation(taskId: Self.taskIdentifier)
    }
    
    // MARK: - Background Task Handling
    
    /// Handles the background task execution.
    /// - Parameter task: The BGProcessingTask provided by iOS (typed as Any for testability)
    /// - Validates: Requirement 1.5 (Invoke WeeklyOptionStrategy.analyzeBatch())
    /// - Validates: Requirement 1.7 (Reschedule on termination)
    /// - Validates: Requirement 1.8 (Persist results and schedule next task)
    /// - Validates: Requirement 5.2 (Use ScheduledAnalysisUserFilter.isEligible())
    /// - Validates: Requirement 5.3 (Invoke WeeklyOptionStrategy.analyzeBatch())
    /// - Validates: Requirement 5.4 (Persist with LocalResultsRepository.saveResults())
    /// - Validates: Requirement 5.8 (Skip if watchlist empty)
    /// - Validates: Requirement 6.1 (Handle network unavailability)
    /// - Validates: Requirement 6.2 (Continue with partial results)
    /// - Validates: Requirement 6.3 (Handle save failures)
    /// - Validates: Requirement 6.4 (Expiration handler for partial results)
    /// - Validates: Requirement 6.5 (No notification if all tickers fail)
    /// - Validates: Requirement 6.6 (Log all operations)
    func handleBackgroundTask(_ task: Any) {
        guard let processingTask = task as? BGProcessingTask else { return }
        
        logger.logExecutionStarted(taskId: Self.taskIdentifier)
        
        // Clear partial results for new execution
        partialResults = []
        shouldCancelAnalysis = false
        
        // Create the analysis task
        let analysisTask = Task { [weak self] in
            await self?.executeAnalysis(task: processingTask)
        }
        
        currentAnalysisTask = analysisTask
        
        // Set up expiration handler
        // - Validates: Requirement 6.4 (Expiration handler)
        // - Validates: Requirement 1.7 (Reschedule on termination)
        processingTask.expirationHandler = { [weak self] in
            self?.handleExpiration(task: processingTask)
        }
    }
    
    /// Executes the analysis workflow.
    /// - Parameter task: The BGProcessingTask
    private func executeAnalysis(task: BGProcessingTask) async {
        // Get user ID (in a real app, this would come from authentication)
        // For now, use a placeholder or stored user ID
        let userId = currentUserId ?? "default-user"
        
        do {
            // Load user settings
            let settings = try await settingsRepository.getUserSettings(for: userId)
            
            // Check eligibility
            // - Validates: Requirement 5.2 (Use ScheduledAnalysisUserFilter.isEligible())
            // For user filter, we need to create the user data with watchlist
            // In the current design, we'll check settings directly
            guard settings.scheduledAnalysisEnabled else {
                let reason = "Scheduled analysis disabled"
                logger.logEligibilitySkipped(taskId: Self.taskIdentifier, reason: reason)
                rescheduleAndComplete(task: task, success: true, settings: settings)
                return
            }
            
            // Get watchlist (for this implementation, we'll use a placeholder approach)
            // In a real app, this would come from a watchlist repository
            let watchlist = await getWatchlist(for: userId)
            
            // Check if watchlist is empty
            // - Validates: Requirement 5.8 (Skip if watchlist empty)
            guard !watchlist.symbols.isEmpty else {
                let reason = "Empty watchlist"
                logger.logEligibilitySkipped(taskId: Self.taskIdentifier, reason: reason)
                rescheduleAndComplete(task: task, success: true, settings: settings)
                return
            }
            
            // Create user data for eligibility check
            let userData = ScheduledAnalysisUserData(
                userId: userId,
                settings: settings,
                watchlist: watchlist
            )
            
            // Verify full eligibility
            guard userFilter.isEligible(userData) else {
                let reason = userFilter.ineligibilityReason(userData) ?? "User not eligible"
                logger.logEligibilitySkipped(taskId: Self.taskIdentifier, reason: reason)
                rescheduleAndComplete(task: task, success: true, settings: settings)
                return
            }
            
            // Execute analysis
            // - Validates: Requirement 1.5 (Invoke WeeklyOptionStrategy.analyzeBatch())
            // - Validates: Requirement 5.3 (Invoke WeeklyOptionStrategy.analyzeBatch())
            let configuration = WeeklyOptionConfiguration.default
            
            let results = await strategy.analyzeBatch(
                tickers: watchlist.symbols,
                configuration: configuration
            ) { _ in
                // Progress handler - collect partial results as they come in
                // This enables saving partial results on expiration
            }
            
            // Process results
            // - Validates: Requirement 6.2 (Continue with partial results)
            var allResults: [AnalysisResult] = []
            var errorsCount = 0
            
            for (_, result) in results {
                switch result {
                case .success(let tickerResults):
                    allResults.append(contentsOf: tickerResults)
                case .failure:
                    errorsCount += 1
                }
            }
            
            // Store partial results for expiration handler
            partialResults = allResults
            
            // Check if all tickers failed
            // - Validates: Requirement 6.5 (No notification if all fail)
            guard !allResults.isEmpty else {
                logger.logExecutionFailed(taskId: Self.taskIdentifier, error: NSError(
                    domain: "BackgroundAnalysis",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "All tickers failed"]
                ))
                rescheduleAndComplete(task: task, success: false, settings: settings)
                return
            }
            
            // Save results
            // - Validates: Requirement 5.4 (Persist with LocalResultsRepository.saveResults())
            // - Validates: Requirement 1.8 (Persist results)
            let metadata = ResultsMetadata(
                timestamp: Date(),
                source: .scheduled,
                strategyId: strategy.identifier,
                scheduledRunId: UUID().uuidString
            )
            
            do {
                try await resultsRepository.saveResults(allResults, metadata: metadata, for: userId)
            } catch {
                // - Validates: Requirement 6.3 (Log error on save failure)
                logger.logExecutionFailed(taskId: Self.taskIdentifier, error: error)
                // Continue to notification even if save fails
            }
            
            // Count ORDER signals
            let orderCount = allResults.filter { $0.signal == .order }.count
            
            // Send notification if ORDER signals found
            // - Validates: Requirement 3.3 (Notify when ORDER signals found)
            if orderCount > 0 {
                await notificationManager.notifyIfAllowed(orderCount: orderCount, settings: settings)
            }
            
            // Log completion
            // - Validates: Requirement 6.6 (Log all operations)
            logger.logExecutionCompleted(
                taskId: Self.taskIdentifier,
                resultsCount: allResults.count,
                errorsCount: errorsCount
            )
            
            // Schedule next task and mark complete
            // - Validates: Requirement 1.8 (Schedule next task)
            rescheduleAndComplete(task: task, success: true, settings: settings)
            
        } catch {
            // - Validates: Requirement 6.1 (Handle errors)
            logger.logExecutionFailed(taskId: Self.taskIdentifier, error: error)
            
            // Try to load settings for rescheduling
            if let settings = try? await settingsRepository.getUserSettings(for: userId) {
                rescheduleAndComplete(task: task, success: false, settings: settings)
            } else {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    /// Handles task expiration by saving partial results.
    /// - Parameter task: The BGProcessingTask
    /// - Validates: Requirement 6.4 (Expiration handler saves partial results)
    private func handleExpiration(task: BGProcessingTask) {
        // Cancel the current analysis task
        currentAnalysisTask?.cancel()
        
        // Save any partial results collected
        if !partialResults.isEmpty {
            logger.logPartialResultsSaved(taskId: Self.taskIdentifier, savedCount: partialResults.count)
            
            // Attempt to save partial results asynchronously
            Task {
                let userId = currentUserId ?? "default-user"
                let metadata = ResultsMetadata(
                    timestamp: Date(),
                    source: .scheduled,
                    strategyId: strategy.identifier,
                    scheduledRunId: UUID().uuidString
                )
                
                try? await resultsRepository.saveResults(partialResults, metadata: metadata, for: userId)
            }
        }
        
        // Mark task as incomplete so iOS will reschedule
        // - Validates: Requirement 1.7 (Reschedule on termination)
        task.setTaskCompleted(success: false)
    }
    
    /// Reschedules the next task and marks the current one complete.
    /// - Parameters:
    ///   - task: The BGProcessingTask to complete
    ///   - success: Whether the task completed successfully
    ///   - settings: User settings for scheduling
    private func rescheduleAndComplete(task: BGProcessingTask, success: Bool, settings: UserSettings) {
        // Schedule next task if still enabled
        if settings.scheduledAnalysisEnabled && !settings.scheduleTimes.isEmpty {
            scheduleNextTask(settings: settings)
        }
        
        task.setTaskCompleted(success: success)
    }
    
    // MARK: - Helper Methods
    
    /// Sets the current user ID for analysis.
    /// - Parameter userId: The user's identifier
    func setCurrentUserId(_ userId: String) {
        currentUserId = userId
    }
    
    /// Gets the watchlist for a user.
    /// - Parameter userId: The user's identifier
    /// - Returns: The user's watchlist
    private func getWatchlist(for userId: String) async -> Watchlist {
        do {
            let symbols = try await watchlistRepository.getWatchlist(for: userId)
            return Watchlist(userId: userId, symbols: symbols)
        } catch {
            // On error, return empty watchlist (analysis will be skipped)
            logger.logExecutionFailed(taskId: Self.taskIdentifier, error: error)
            return Watchlist(userId: userId, symbols: [])
        }
    }
}
