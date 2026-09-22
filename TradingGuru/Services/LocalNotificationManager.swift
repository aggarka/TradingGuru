//
//  LocalNotificationManager.swift
//  TradingGuru
//
//  Implementation of local notification management using UNUserNotificationCenter.
//

import Foundation
import UserNotifications

// MARK: - Local Notification Manager Implementation

/// Implementation of local notification management using UNUserNotificationCenter.
///
/// Handles:
/// - Permission requests with alert, sound, and badge options
/// - Notification content formatting
/// - Frequency-based delivery suppression
/// - Deep linking to results screen
///
/// - Validates: Requirements 3.1-3.8 (Notification delivery)
/// - Validates: Requirements 4.1-4.7 (Frequency control)
final class LocalNotificationManager: LocalNotificationManaging {
    
    // MARK: - Constants
    
    /// Notification category identifier for analysis complete notifications.
    static let analysisCategoryId = "ANALYSIS_COMPLETE"
    
    /// Key for storing last notification timestamp.
    static let lastNotificationKey = "tradingguru.lastNotificationTimestamp"
    
    // MARK: - Dependencies
    
    private let notificationCenter: UNUserNotificationCenter
    private let frequencyEnforcer: NotificationFrequencyEnforcing
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    /// Creates a new LocalNotificationManager with the specified dependencies.
    /// - Parameters:
    ///   - notificationCenter: The notification center to use (defaults to .current())
    ///   - frequencyEnforcer: The frequency enforcer for delivery decisions (defaults to NotificationFrequencyEnforcer())
    ///   - userDefaults: The UserDefaults instance for timestamp persistence (defaults to .standard)
    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        frequencyEnforcer: NotificationFrequencyEnforcing = NotificationFrequencyEnforcer(),
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationCenter = notificationCenter
        self.frequencyEnforcer = frequencyEnforcer
        self.userDefaults = userDefaults
    }
    
    // MARK: - Authorization
    
    /// Requests notification authorization with alert, sound, and badge options.
    /// - Returns: True if authorization was granted
    /// - Validates: Requirement 3.1 (Request authorization on first enable)
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            return false
        }
    }
    
    /// Checks current authorization status.
    /// - Returns: The mapped NotificationAuthorizationStatus
    /// - Validates: Requirement 3.2 (Handle permission denial)
    func checkAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .provisional: return .provisional
        @unknown default: return .notDetermined
        }
    }
    
    // MARK: - Notification Delivery
    
    /// Delivers a notification if allowed by frequency settings.
    ///
    /// This method performs the following checks:
    /// 1. Returns false immediately if orderCount <= 0 (no ORDER signals)
    /// 2. Checks frequency enforcement to avoid notification fatigue
    /// 3. Creates and delivers the notification if allowed
    /// 4. Persists the delivery timestamp for future frequency checks
    ///
    /// - Parameters:
    ///   - orderCount: Number of ORDER signals found in analysis
    ///   - settings: Current user settings containing frequency preference
    /// - Returns: True if notification was successfully delivered
    /// - Validates: Requirement 3.3, 3.7 (Deliver only when ORDER signals found)
    /// - Validates: Requirement 4.3, 4.4, 4.5 (Frequency enforcement)
    @discardableResult
    func notifyIfAllowed(orderCount: Int, settings: UserSettings) async -> Bool {
        // Don't notify if no ORDER signals
        guard orderCount > 0 else { return false }
        
        // Check frequency enforcement
        let lastNotification = getLastNotificationTimestamp()
        guard frequencyEnforcer.shouldDeliver(
            lastNotificationTime: lastNotification,
            frequency: settings.notificationFrequency,
            currentTime: Date()
        ) else {
            return false
        }
        
        // Create and deliver notification
        let content = createNotificationContent(orderCount: orderCount)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await notificationCenter.add(request)
            persistNotificationTimestamp(Date())
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Content Creation
    
    /// Creates notification content for analysis results.
    ///
    /// The notification content includes:
    /// - Title: "TradingGuru Analysis Complete"
    /// - Body: "[N] ORDER signals found! Tap to review."
    /// - Badge: Set to the orderCount
    /// - Sound: Default iOS notification sound
    /// - Category: ANALYSIS_COMPLETE for deep linking
    /// - UserInfo: Contains action key for navigation
    ///
    /// - Parameter orderCount: Number of ORDER signals to display
    /// - Returns: Configured UNMutableNotificationContent
    /// - Validates: Requirement 3.4, 3.5, 3.8 (Content format, badge, sound)
    private func createNotificationContent(orderCount: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "TradingGuru Analysis Complete"
        content.body = "\(orderCount) ORDER signals found! Tap to review."
        content.badge = NSNumber(value: orderCount)
        content.sound = .default
        content.categoryIdentifier = Self.analysisCategoryId
        content.userInfo = ["action": "showResults"]
        return content
    }
    
    // MARK: - Test Notification
    
    /// Sends a test notification immediately, bypassing frequency checks.
    /// Use this for debugging and verifying notification delivery works.
    /// - Returns: True if the test notification was successfully scheduled
    func sendTestNotification() async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = "TradingGuru Test Notification"
        content.body = "🎉 Notifications are working! You'll receive alerts when ORDER signals are found."
        content.badge = NSNumber(value: 1)
        content.sound = .default
        content.categoryIdentifier = Self.analysisCategoryId
        content.userInfo = ["action": "showResults", "isTest": true]
        
        let request = UNNotificationRequest(
            identifier: "test-notification-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("Failed to send test notification: \(error)")
            return false
        }
    }
    
    // MARK: - Timestamp Persistence
    
    /// Gets the last notification delivery timestamp.
    /// - Returns: The Date when the last notification was delivered, or nil if never delivered
    private func getLastNotificationTimestamp() -> Date? {
        userDefaults.object(forKey: Self.lastNotificationKey) as? Date
    }
    
    /// Persists the notification delivery timestamp.
    /// - Parameter date: The timestamp to persist
    /// - Validates: Requirement 4.5 (Persist delivery timestamp)
    private func persistNotificationTimestamp(_ date: Date) {
        userDefaults.set(date, forKey: Self.lastNotificationKey)
    }
}
