//
//  ScheduleTimeError.swift
//  TradingGuru
//
//  Error types for schedule time management operations.
//

import Foundation

/// Errors that can occur during schedule time management.
/// - Validates: Requirement 2.6 (Maximum limit reached error)
/// - Validates: Requirement 2.8 (Minimum required error)
enum ScheduleTimeError: Error, Equatable {
    /// Maximum number of schedule times has been reached
    case maximumLimitReached(max: Int)
    
    /// The provided time is invalid (not in 15-minute increments)
    case invalidTime
    
    /// The provided time is already scheduled
    case duplicateTime
    
    /// At least one schedule time is required when scheduled analysis is enabled
    case minimumRequired
}

extension ScheduleTimeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .maximumLimitReached(let max):
            return "Maximum of \(max) schedule times allowed."
        case .invalidTime:
            return "Invalid time. Please select a time in 15-minute increments."
        case .duplicateTime:
            return "This time is already scheduled."
        case .minimumRequired:
            return "At least one schedule time is required when scheduled analysis is enabled."
        }
    }
}
