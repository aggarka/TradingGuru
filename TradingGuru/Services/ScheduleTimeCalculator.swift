//
//  ScheduleTimeCalculator.swift
//  TradingGuru
//
//  Calculates the next occurrence of user-configured schedule times.
//

import Foundation

// MARK: - Schedule Time Calculator Protocol

/// Protocol for calculating next schedule time occurrences.
protocol ScheduleTimeCalculating {
    /// Calculates the next occurrence of any configured schedule time.
    /// - Parameters:
    ///   - now: The current date/time
    ///   - scheduleTimes: Array of configured schedule times
    /// - Returns: The next Date when analysis should run
    func calculateNextOccurrence(from now: Date, scheduleTimes: [ScheduleTime]) -> Date
}

// MARK: - Schedule Time Calculator Implementation

/// Calculates next occurrences of user-configured schedule times.
///
/// Algorithm:
/// 1. For each schedule time, calculate when it next occurs
/// 2. If the time has passed today, use tomorrow
/// 3. Return the earliest of all calculated times
///
/// - Validates: Requirement 1.3 (earliestBeginDate calculation)
struct ScheduleTimeCalculator: ScheduleTimeCalculating {
    
    // MARK: - Properties
    
    private let calendar: Calendar
    
    // MARK: - Initialization
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    // MARK: - ScheduleTimeCalculating
    
    /// Calculates the next occurrence of any scheduled time.
    /// - Parameters:
    ///   - now: The current date/time
    ///   - scheduleTimes: Array of configured schedule times
    /// - Returns: The next Date when analysis should run
    /// - Validates: Requirement 1.3 (Next occurrence of user-configured schedule time)
    func calculateNextOccurrence(from now: Date, scheduleTimes: [ScheduleTime]) -> Date {
        guard !scheduleTimes.isEmpty else {
            // Fallback: schedule for tomorrow at 6:30 AM
            return fallbackTomorrowAt630AM(from: now)
        }
        
        let nextOccurrences = scheduleTimes.map { scheduleTime in
            calculateNextOccurrence(for: scheduleTime, from: now)
        }
        
        return nextOccurrences.min() ?? now
    }
    
    // MARK: - Private Methods
    
    /// Calculates the next occurrence for a single schedule time.
    /// - Parameters:
    ///   - scheduleTime: The schedule time to calculate for
    ///   - now: The current date/time
    /// - Returns: The next Date when this schedule time occurs
    private func calculateNextOccurrence(for scheduleTime: ScheduleTime, from now: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = scheduleTime.hour
        components.minute = scheduleTime.minute
        components.second = 0
        
        guard let candidateDate = calendar.date(from: components) else {
            return now
        }
        
        // If the time has already passed today, schedule for tomorrow
        if candidateDate <= now {
            return calendar.date(byAdding: .day, value: 1, to: candidateDate) ?? candidateDate
        }
        
        return candidateDate
    }
    
    /// Creates a fallback date for tomorrow at 6:30 AM.
    /// - Parameter now: The current date/time
    /// - Returns: Tomorrow at 6:30 AM in the user's local timezone
    private func fallbackTomorrowAt630AM(from now: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 30
        components.second = 0
        
        guard let todayAt630 = calendar.date(from: components) else {
            // Last resort fallback: add one day to current time
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }
        
        // Always return tomorrow at 6:30 AM for empty schedule times
        return calendar.date(byAdding: .day, value: 1, to: todayAt630) ?? todayAt630
    }
}
