//
//  ForegroundScheduledAnalysisService.swift
//  TradingGuru
//
//  Service that runs scheduled analysis when app is in foreground at scheduled times
//  or when app returns to foreground after a scheduled time was missed.
//

import Foundation
import UserNotifications
import Combine

/// Service that handles scheduled analysis execution in the foreground.
///
/// Since iOS BGProcessingTask does not guarantee execution at exact times,
/// this service provides a reliable alternative by:
/// 1. Running analysis when scheduled time arrives while app is in foreground
/// 2. Running missed analysis when app returns to foreground
///
/// Usage: Initialize with dependencies and call `startMonitoring()` when user authenticates.
final class ForegroundScheduledAnalysisService {
    
    // MARK: - Singleton
    
    static let shared = ForegroundScheduledAnalysisService()
    
    // MARK: - Dependencies
    
    private let settingsRepository: SettingsRepository
    private let watchlistRepository: WatchlistRepository
    private let resultsRepository: ResultsRepository
    private let strategy: WeeklyOptionStrategy
    private let notificationManager: LocalNotificationManaging
    
    // MARK: - State
    
    private var currentUserId: String?
    private var timer: Timer?
    private var lastAnalysisDate: Date?
    private var isRunningAnalysis = false
    
    /// Key for storing last analysis date in UserDefaults
    private let lastAnalysisKey = "ForegroundScheduledAnalysis.lastAnalysisDate"
    
    // MARK: - Initialization
    
    private init() {
        self.settingsRepository = LocalSettingsRepository()
        self.watchlistRepository = LocalWatchlistRepository()
        self.resultsRepository = LocalResultsRepository()
        self.strategy = WeeklyOptionStrategy()
        self.notificationManager = LocalNotificationManager()
        
        // Load last analysis date from UserDefaults
        if let savedDate = UserDefaults.standard.object(forKey: lastAnalysisKey) as? Date {
            lastAnalysisDate = savedDate
        }
    }
    
    // MARK: - Public API
    
    /// Sets the current user ID and starts monitoring for scheduled times.
    /// - Parameter userId: The authenticated user's ID
    func setCurrentUserId(_ userId: String) {
        currentUserId = userId
        startMonitoring()
    }
    
    /// Stops monitoring and clears state (call on sign out).
    func stop() {
        stopTimer()
        currentUserId = nil
    }
    
    /// Called when app enters foreground - checks for missed scheduled analysis.
    func checkForMissedAnalysis() async {
        guard let userId = currentUserId else {
            print("[ForegroundScheduledAnalysis] No user ID set, skipping")
            return
        }
        
        do {
            let settings = try await settingsRepository.getUserSettings(for: userId)
            
            guard settings.scheduledAnalysisEnabled else {
                print("[ForegroundScheduledAnalysis] Scheduled analysis disabled")
                return
            }
            
            guard !settings.scheduleTimes.isEmpty else {
                print("[ForegroundScheduledAnalysis] No schedule times configured")
                return
            }
            
            // Check if a scheduled time has passed since last analysis
            if let missedTime = findMissedScheduleTime(settings: settings) {
                print("[ForegroundScheduledAnalysis] Found missed schedule time: \(missedTime)")
                await runAnalysis(for: userId, settings: settings, reason: "missed schedule at \(missedTime.displayString)")
            }
        } catch {
            print("[ForegroundScheduledAnalysis] Error checking for missed analysis: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Starts the timer that checks for scheduled times while app is in foreground.
    private func startMonitoring() {
        stopTimer()
        
        // Check every minute if we've reached a scheduled time
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.checkScheduledTime()
            }
        }
        
        // Also check immediately
        Task {
            await checkForMissedAnalysis()
        }
        
        print("[ForegroundScheduledAnalysis] Started monitoring")
    }
    
    /// Stops the monitoring timer.
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Checks if current time matches any scheduled time.
    private func checkScheduledTime() async {
        guard let userId = currentUserId else { return }
        
        do {
            let settings = try await settingsRepository.getUserSettings(for: userId)
            
            guard settings.scheduledAnalysisEnabled else { return }
            
            let now = Date()
            let calendar = Calendar.current
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            
            // Check if current time matches any schedule time (within the same minute)
            for scheduleTime in settings.scheduleTimes {
                if scheduleTime.hour == currentHour && scheduleTime.minute == currentMinute {
                    // Check if we already ran analysis this minute
                    if let lastRun = lastAnalysisDate {
                        let minutesSinceLastRun = calendar.dateComponents([.minute], from: lastRun, to: now).minute ?? 0
                        if minutesSinceLastRun < 1 {
                            print("[ForegroundScheduledAnalysis] Already ran analysis within this minute, skipping")
                            return
                        }
                    }
                    
                    print("[ForegroundScheduledAnalysis] Schedule time reached: \(scheduleTime.displayString)")
                    await runAnalysis(for: userId, settings: settings, reason: "scheduled at \(scheduleTime.displayString)")
                    break
                }
            }
        } catch {
            print("[ForegroundScheduledAnalysis] Error checking scheduled time: \(error)")
        }
    }
    
    /// Finds if any scheduled time has been missed since the last analysis.
    /// - Parameter settings: The user's settings
    /// - Returns: The missed schedule time, if any
    private func findMissedScheduleTime(settings: UserSettings) -> ScheduleTime? {
        let now = Date()
        let calendar = Calendar.current
        
        // If we've never run analysis, check if any schedule time has passed today
        let referenceDate = lastAnalysisDate ?? calendar.startOfDay(for: now)
        
        for scheduleTime in settings.scheduleTimes {
            // Create a date for this schedule time today
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = scheduleTime.hour
            components.minute = scheduleTime.minute
            components.second = 0
            
            guard let scheduledDate = calendar.date(from: components) else { continue }
            
            // If the scheduled time is after the reference date but before now,
            // and we're within a reasonable window (e.g., last 2 hours), it's a missed time
            if scheduledDate > referenceDate && scheduledDate <= now {
                let hoursSinceScheduled = calendar.dateComponents([.hour], from: scheduledDate, to: now).hour ?? 0
                if hoursSinceScheduled <= 2 { // Only catch up within 2 hours
                    return scheduleTime
                }
            }
        }
        
        return nil
    }
    
    /// Runs the scheduled analysis.
    private func runAnalysis(for userId: String, settings: UserSettings, reason: String) async {
        guard !isRunningAnalysis else {
            print("[ForegroundScheduledAnalysis] Analysis already running, skipping")
            return
        }
        
        isRunningAnalysis = true
        print("[ForegroundScheduledAnalysis] Starting analysis (\(reason))")
        
        defer {
            isRunningAnalysis = false
        }
        
        do {
            // Get watchlist
            let symbols = try await watchlistRepository.getWatchlist(for: userId)
            
            guard !symbols.isEmpty else {
                print("[ForegroundScheduledAnalysis] Watchlist is empty, skipping")
                return
            }
            
            print("[ForegroundScheduledAnalysis] Analyzing \(symbols.count) symbols: \(symbols)")
            
            // Run analysis
            let configuration = WeeklyOptionConfiguration.default
            let results = await strategy.analyzeBatch(
                tickers: symbols,
                configuration: configuration
            ) { progress in
                print("[ForegroundScheduledAnalysis] Progress: \(progress)")
            }
            
            // Collect successful results
            var allResults: [AnalysisResult] = []
            for (ticker, result) in results {
                switch result {
                case .success(let tickerResults):
                    allResults.append(contentsOf: tickerResults)
                case .failure(let error):
                    print("[ForegroundScheduledAnalysis] Failed to analyze \(ticker): \(error)")
                }
            }
            
            guard !allResults.isEmpty else {
                print("[ForegroundScheduledAnalysis] No results, skipping save and notification")
                return
            }
            
            print("[ForegroundScheduledAnalysis] Got \(allResults.count) results")
            
            // Save results
            let metadata = ResultsMetadata(
                timestamp: Date(),
                source: .scheduled,
                strategyId: strategy.identifier,
                scheduledRunId: UUID().uuidString
            )
            
            try await resultsRepository.saveResults(allResults, metadata: metadata, for: userId)
            print("[ForegroundScheduledAnalysis] Results saved")
            
            // Update last analysis date
            lastAnalysisDate = Date()
            UserDefaults.standard.set(lastAnalysisDate, forKey: lastAnalysisKey)
            
            // Send notification for ORDER signals
            let orderCount = allResults.filter { $0.signal == .order }.count
            print("[ForegroundScheduledAnalysis] Found \(orderCount) ORDER signals")
            
            if orderCount > 0 {
                let sent = await notificationManager.notifyIfAllowed(orderCount: orderCount, settings: settings)
                print("[ForegroundScheduledAnalysis] Notification sent: \(sent)")
            }
            
            // Post notification to refresh results view
            await MainActor.run {
                NotificationCenter.default.post(name: .scheduledAnalysisCompleted, object: nil, userInfo: [
                    "resultsCount": allResults.count,
                    "orderCount": orderCount
                ])
            }
            
            print("[ForegroundScheduledAnalysis] Analysis complete")
            
        } catch {
            print("[ForegroundScheduledAnalysis] Error running analysis: \(error)")
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    /// Posted when scheduled analysis completes in foreground.
    static let scheduledAnalysisCompleted = Notification.Name("scheduledAnalysisCompleted")
}
