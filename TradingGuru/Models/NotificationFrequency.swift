//
//  NotificationFrequency.swift
//  TradingGuru
//
//  Frequency options for notification delivery.
//

import Foundation

/// Frequency options for notification delivery.
/// Controls the minimum time interval between consecutive local notifications to prevent notification fatigue.
/// - Validates: Requirement 4.1 (Frequency options)
enum NotificationFrequency: String, Codable, CaseIterable {
    case everyTime = "every_time"
    case atMostOncePerThirtyMinutes = "30_minutes"
    case atMostOncePerHour = "1_hour"
    case atMostOncePerTwoHours = "2_hours"
    case atMostOncePerFourHours = "4_hours"
    case atMostOncePerDay = "24_hours"
    
    /// Minimum interval in seconds before next notification.
    var minimumInterval: TimeInterval {
        switch self {
        case .everyTime:
            return 0
        case .atMostOncePerThirtyMinutes:
            return 30 * 60
        case .atMostOncePerHour:
            return 60 * 60
        case .atMostOncePerTwoHours:
            return 2 * 60 * 60
        case .atMostOncePerFourHours:
            return 4 * 60 * 60
        case .atMostOncePerDay:
            return 24 * 60 * 60
        }
    }
    
    /// Display label for UI.
    var displayLabel: String {
        switch self {
        case .everyTime:
            return "Every time"
        case .atMostOncePerThirtyMinutes:
            return "At most once per 30 minutes"
        case .atMostOncePerHour:
            return "At most once per hour"
        case .atMostOncePerTwoHours:
            return "At most once per 2 hours"
        case .atMostOncePerFourHours:
            return "At most once per 4 hours"
        case .atMostOncePerDay:
            return "At most once per day"
        }
    }
    
    /// Default frequency for new users.
    /// - Validates: Requirement 4.2 (Default is once per hour)
    static let `default` = NotificationFrequency.atMostOncePerHour
}
