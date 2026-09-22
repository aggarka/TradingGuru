//
//  ScheduleTime.swift
//  TradingGuru
//
//  Represents a scheduled time for background analysis.
//

import Foundation

/// Represents a scheduled time for background analysis.
/// Times are constrained to 15-minute increments (0, 15, 30, 45 minutes) within hours 0-23.
/// - Validates: Requirement 2.2 (15-minute increments, 00:00-23:45)
struct ScheduleTime: Codable, Equatable, Hashable {
    
    // MARK: - Properties
    
    /// Hour component (0-23)
    let hour: Int
    
    /// Minute component (0, 15, 30, or 45)
    let minute: Int
    
    // MARK: - Static Properties
    
    /// Valid minute increments for schedule times.
    static let validMinutes = [0, 15, 30, 45]
    
    // MARK: - Factory Method
    
    /// Creates a ScheduleTime with validation.
    /// - Parameters:
    ///   - hour: Hour (0-23)
    ///   - minute: Minute (must be 0, 15, 30, or 45)
    /// - Returns: ScheduleTime if valid, nil otherwise
    static func create(hour: Int, minute: Int) -> ScheduleTime? {
        guard (0...23).contains(hour) else { return nil }
        guard validMinutes.contains(minute) else { return nil }
        return ScheduleTime(hour: hour, minute: minute)
    }
    
    // MARK: - Computed Properties
    
    /// Display string in HH:MM format (24-hour).
    var displayString: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    /// Display string with AM/PM format (12-hour).
    var displayStringWithPeriod: String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
    
    // MARK: - Private Initializer
    
    /// Private initializer - use `create(hour:minute:)` factory method to ensure validation.
    private init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}
