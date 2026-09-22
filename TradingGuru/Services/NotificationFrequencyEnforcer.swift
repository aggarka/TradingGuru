//
//  NotificationFrequencyEnforcer.swift
//  TradingGuru
//
//  Enforces notification frequency limits based on user preferences.
//

import Foundation

// MARK: - Notification Frequency Enforcer Protocol

/// Protocol for enforcing notification frequency limits.
protocol NotificationFrequencyEnforcing {
    /// Determines if a notification should be delivered based on frequency settings.
    /// - Parameters:
    ///   - lastNotificationTime: When the last notification was delivered
    ///   - frequency: The configured frequency setting
    ///   - currentTime: The current time
    /// - Returns: True if notification should be delivered
    func shouldDeliver(
        lastNotificationTime: Date?,
        frequency: NotificationFrequency,
        currentTime: Date
    ) -> Bool
}

// MARK: - Notification Frequency Enforcer Implementation

/// Enforces notification frequency limits based on user preferences.
///
/// This component determines whether a notification should be delivered based on:
/// - The configured frequency setting
/// - The time elapsed since the last notification
///
/// - Validates: Requirements 4.3, 4.4, 4.7 (Frequency enforcement logic)
struct NotificationFrequencyEnforcer: NotificationFrequencyEnforcing {
    
    /// Determines if sufficient time has elapsed since the last notification.
    ///
    /// Logic:
    /// - "Every time" frequency means no frequency limiting - always deliver
    /// - First notification (lastNotificationTime is nil) is always allowed
    /// - Otherwise, deliver only if elapsed time >= configured minimum interval
    ///
    /// - Parameters:
    ///   - lastNotificationTime: When the last notification was delivered
    ///   - frequency: The configured frequency setting
    ///   - currentTime: The current time
    /// - Returns: True if notification should be delivered
    ///
    /// - Validates: Requirement 4.3 (Check timestamp of last notification)
    /// - Validates: Requirement 4.4 (Suppress if elapsed < interval)
    /// - Validates: Requirement 4.7 (No suppression for "Every time")
    func shouldDeliver(
        lastNotificationTime: Date?,
        frequency: NotificationFrequency,
        currentTime: Date
    ) -> Bool {
        // "Every time" means no frequency limiting
        guard frequency != .everyTime else { return true }
        
        // First notification always allowed
        guard let lastTime = lastNotificationTime else { return true }
        
        let elapsed = currentTime.timeIntervalSince(lastTime)
        return elapsed >= frequency.minimumInterval
    }
}
