//
//  AppDelegate.swift
//  TradingGuru
//
//  AppDelegate implementation for background task registration and notification handling.
//

import UIKit
import UserNotifications

// MARK: - Notification Name Extension

extension Notification.Name {
    /// Posted when the user taps on an analysis complete notification.
    /// Observers should navigate to the analysis results screen.
    /// - Validates: Requirement 3.6 (Deep linking to results screen)
    static let showAnalysisResults = Notification.Name("showAnalysisResults")
}

// MARK: - App Delegate

/// UIApplicationDelegate implementation for handling app lifecycle events
/// related to background tasks and notifications.
///
/// Responsibilities:
/// - Register background tasks on app launch
/// - Handle notification delegate events for deep linking
///
/// - Validates: Requirement 1.1 (Register BGProcessingTask on app launch)
/// - Validates: Requirement 3.6 (Navigate to results on notification tap)
class AppDelegate: NSObject, UIApplicationDelegate {
    
    // MARK: - UIApplicationDelegate
    
    /// Called when the app finishes launching.
    ///
    /// This method:
    /// 1. Registers the background analysis task with iOS BackgroundTasks framework
    /// 2. Sets up the notification center delegate for handling notification interactions
    ///
    /// - Validates: Requirement 1.1 (Register BGProcessingTask before didFinishLaunchingWithOptions returns)
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background task
        BackgroundAnalysisScheduler.shared.registerBackgroundTask()
        
        // Set up notification delegate for deep linking
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    /// Called when the user interacts with a notification (e.g., taps on it).
    ///
    /// This method checks if the notification is an analysis complete notification
    /// and posts a notification to trigger navigation to the results screen.
    ///
    /// - Parameters:
    ///   - center: The notification center
    ///   - response: The user's response to the notification
    ///   - completionHandler: Must be called when processing is complete
    /// - Validates: Requirement 3.6 (Navigate to analysis results screen on notification tap)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Check if this is an analysis complete notification
        if response.notification.request.content.categoryIdentifier == LocalNotificationManager.analysisCategoryId {
            // Post notification to trigger navigation to results screen
            NotificationCenter.default.post(name: .showAnalysisResults, object: nil)
        }
        
        completionHandler()
    }
    
    /// Called when a notification is about to be presented while the app is in the foreground.
    ///
    /// This allows the notification to be displayed with a banner, sound, badge,
    /// and persisted to Notification Center even when the app is active.
    ///
    /// - Parameters:
    ///   - center: The notification center
    ///   - notification: The notification about to be presented
    ///   - completionHandler: Call with the presentation options
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        // Include .list to add notification to Notification Center
        completionHandler([.banner, .sound, .badge, .list])
    }
}
