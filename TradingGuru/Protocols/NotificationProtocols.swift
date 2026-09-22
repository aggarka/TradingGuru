//
//  NotificationProtocols.swift
//  TradingGuru
//
//  Protocol definitions for local notification management.
//

import Foundation

// MARK: - Notification Authorization Status

/// Notification authorization status.
/// Maps to UNAuthorizationStatus values for abstraction and testability.
enum NotificationAuthorizationStatus {
    /// The user has granted authorization to receive notifications.
    case authorized
    
    /// The user has denied authorization to receive notifications.
    case denied
    
    /// The user has not yet made a choice about notification authorization.
    case notDetermined
    
    /// The app has provisional authorization to post non-interruptive notifications.
    case provisional
}

// MARK: - Local Notification Managing Protocol

/// Protocol for local notification management.
/// Handles permission requests, authorization status checks, and notification delivery.
///
/// - Validates: Requirements 3.1-3.8 (Local notification permission and delivery)
/// - Validates: Requirements 4.1-4.7 (Notification frequency control)
protocol LocalNotificationManaging {
    
    /// Requests notification authorization from the user.
    /// Requests alert, sound, and badge options.
    /// - Returns: True if authorization was granted
    /// - Validates: Requirement 3.1 (Request authorization on first enable)
    func requestAuthorization() async -> Bool
    
    /// Checks if notifications are currently authorized.
    /// - Returns: The current notification authorization status
    /// - Validates: Requirement 3.2 (Handle permission denial)
    func checkAuthorizationStatus() async -> NotificationAuthorizationStatus
    
    /// Attempts to deliver a notification for analysis results.
    /// Respects notification frequency settings.
    /// - Parameters:
    ///   - orderCount: Number of ORDER signals found
    ///   - settings: Current user settings with frequency preference
    /// - Returns: True if notification was delivered
    /// - Validates: Requirement 3.3 (Deliver notification when ORDER signals found)
    /// - Validates: Requirement 3.7 (No notification if no ORDER signals)
    /// - Validates: Requirement 4.3, 4.4 (Frequency enforcement)
    @discardableResult
    func notifyIfAllowed(orderCount: Int, settings: UserSettings) async -> Bool
    
    /// Sends a test notification immediately, bypassing frequency checks.
    /// Use this for debugging and verifying notification delivery works.
    /// - Returns: True if the test notification was successfully scheduled
    func sendTestNotification() async -> Bool
}
