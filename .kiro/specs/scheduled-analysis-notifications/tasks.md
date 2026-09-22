# Implementation Plan: Scheduled Analysis Notifications

## Overview

This implementation plan enables automated background analysis execution on iOS using BGProcessingTask, combined with local push notifications to alert users when ORDER signals are found. The feature integrates with the existing `WeeklyOptionStrategy.analyzeBatch()` analysis engine, `LocalResultsRepository` for persistence, and `ScheduledAnalysisUserFilter` for eligibility verification.

The implementation follows the existing protocol-oriented architecture and adds new components for scheduling, notification management, and user settings extensions.

## Tasks

- [x] 1. Set up data models and types
  - [x] 1.1 Create ScheduleTime model
    - Create `TradingGuru/Models/ScheduleTime.swift`
    - Implement ScheduleTime struct with hour and minute properties
    - Add factory method `create(hour:minute:)` that validates 15-minute increments (0, 15, 30, 45) and hour range (0-23)
    - Implement Codable, Equatable, Hashable conformance
    - Add `displayString` (HH:MM) and `displayStringWithPeriod` (h:MM AM/PM) computed properties
    - Add static `validMinutes` array [0, 15, 30, 45]
    - _Requirements: 2.2_

  - [x] 1.2 Create NotificationFrequency enum
    - Create `TradingGuru/Models/NotificationFrequency.swift`
    - Implement enum with cases: everyTime, atMostOncePerThirtyMinutes, atMostOncePerHour, atMostOncePerTwoHours, atMostOncePerFourHours, atMostOncePerDay
    - Add raw String values for persistence
    - Add `minimumInterval` computed property returning TimeInterval in seconds
    - Add `displayLabel` computed property for UI display
    - Add static `default` returning `.atMostOncePerHour`
    - Implement Codable, CaseIterable conformance
    - _Requirements: 4.1, 4.2_

  - [x] 1.3 Create ScheduleTimeError enum
    - Create `TradingGuru/Models/ScheduleTimeError.swift`
    - Implement enum with cases: maximumLimitReached(max: Int), invalidTime, duplicateTime, minimumRequired
    - Conform to Error and LocalizedError with appropriate error descriptions
    - _Requirements: 2.6, 2.8_

  - [x] 1.4 Extend UserSettings with schedule and notification properties
    - Modify `TradingGuru/Models/UserSettings.swift`
    - Add `scheduleTimes: [ScheduleTime]` property with default of [6:30 AM, 12:30 PM]
    - Add `notificationFrequency: NotificationFrequency` property with default of `.atMostOncePerHour`
    - Update `default` static property to include new defaults
    - Add static `maxScheduleTimes = 8`
    - Add static `defaultScheduleTimes` returning [ScheduleTime(hour: 6, minute: 30), ScheduleTime(hour: 12, minute: 30)]
    - Add `addScheduleTime(_:)` method returning `Result<Void, ScheduleTimeError>`
    - Add `removeScheduleTime(_:)` method returning Bool
    - Update Codable implementation to handle new properties with backwards compatibility
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 2.7, 4.6, 5.6_

- [x] 2. Implement schedule time calculation
  - [x] 2.1 Create ScheduleTimeCalculating protocol and implementation
    - Create `TradingGuru/Services/ScheduleTimeCalculator.swift`
    - Define `ScheduleTimeCalculating` protocol with `calculateNextOccurrence(from:scheduleTimes:) -> Date` method
    - Implement `ScheduleTimeCalculator` struct conforming to the protocol
    - Algorithm: For each schedule time, calculate when it next occurs; if time passed today, use tomorrow; return earliest
    - Use Calendar for date calculations in user's local timezone
    - Handle empty scheduleTimes array with fallback to tomorrow at 6:30 AM
    - _Requirements: 1.3_

  - [ ]* 2.2 Write property test for next schedule time calculation
    - **Property 1: Next Schedule Time Calculation**
    - Test that for any current time and non-empty schedule times array, the result is greater than current time, matches one of the configured times (hour/minute), and is the minimum among all possible next occurrences
    - **Validates: Requirements 1.3**

- [x] 3. Implement notification frequency enforcement
  - [x] 3.1 Create NotificationFrequencyEnforcing protocol and implementation
    - Create `TradingGuru/Services/NotificationFrequencyEnforcer.swift`
    - Define `NotificationFrequencyEnforcing` protocol with `shouldDeliver(lastNotificationTime:frequency:currentTime:) -> Bool` method
    - Implement `NotificationFrequencyEnforcer` struct conforming to the protocol
    - Return true for `.everyTime` frequency without checking time
    - Return true if lastNotificationTime is nil (first notification)
    - Return true if elapsed time >= frequency.minimumInterval
    - Return false if elapsed time < frequency.minimumInterval (suppress notification)
    - _Requirements: 4.3, 4.4, 4.7_

  - [ ]* 3.2 Write property test for notification frequency enforcement
    - **Property 8: Notification Frequency Enforcement**
    - Test that notifications are suppressed when elapsed time < minimumInterval (except for everyTime)
    - Test that everyTime never suppresses notifications
    - **Validates: Requirements 4.4, 4.7**

- [x] 4. Implement local notification manager
  - [x] 4.1 Create LocalNotificationManaging protocol
    - Create `TradingGuru/Protocols/NotificationProtocols.swift`
    - Define `LocalNotificationManaging` protocol with:
      - `requestAuthorization() async -> Bool`
      - `checkAuthorizationStatus() async -> NotificationAuthorizationStatus`
      - `notifyIfAllowed(orderCount:settings:) async -> Bool`
    - Define `NotificationAuthorizationStatus` enum with cases: authorized, denied, notDetermined, provisional
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 4.2 Implement LocalNotificationManager
    - Create `TradingGuru/Services/LocalNotificationManager.swift`
    - Implement `LocalNotificationManager` class conforming to `LocalNotificationManaging`
    - Inject dependencies: UNUserNotificationCenter, NotificationFrequencyEnforcing, UserDefaults
    - Implement `requestAuthorization()` requesting alert, sound, and badge options
    - Implement `checkAuthorizationStatus()` mapping UNAuthorizationStatus to NotificationAuthorizationStatus
    - Implement `notifyIfAllowed()` that:
      - Returns false if orderCount <= 0
      - Checks frequency enforcement before delivering
      - Creates notification content with title "TradingGuru Analysis Complete"
      - Sets body to "[N] ORDER signals found! Tap to review."
      - Sets badge to orderCount
      - Uses default sound
      - Sets category identifier for deep linking
      - Persists delivery timestamp to UserDefaults
    - Add static `analysisCategoryId = "ANALYSIS_COMPLETE"`
    - Add static `lastNotificationKey = "tradingguru.lastNotificationTimestamp"`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 4.3, 4.4, 4.5_

  - [ ]* 4.3 Write property test for notification delivery based on ORDER count
    - **Property 6: Notification Delivery Based on ORDER Count**
    - Test that notification is created if and only if orderCount > 0
    - **Validates: Requirements 3.3, 3.7**

  - [ ]* 4.4 Write property test for notification content format
    - **Property 7: Notification Content Format**
    - Test that title equals "TradingGuru Analysis Complete"
    - Test that body matches "[N] ORDER signals found! Tap to review." pattern
    - Test that badge equals orderCount
    - **Validates: Requirements 3.4, 3.5**

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement background task logger
  - [x] 6.1 Create BackgroundTaskLogger protocol and implementation
    - Create `TradingGuru/Services/BackgroundTaskLogger.swift`
    - Define `BackgroundTaskLogger` protocol with methods:
      - `logRegistration(taskId:)`
      - `logScheduled(taskId:scheduledFor:)`
      - `logSchedulingError(taskId:error:)`
      - `logCancellation(taskId:)`
      - `logExecutionStarted(taskId:)`
      - `logExecutionCompleted(taskId:resultsCount:errorsCount:)`
      - `logExecutionFailed(taskId:error:)`
      - `logEligibilitySkipped(taskId:reason:)`
      - `logPartialResultsSaved(taskId:savedCount:)`
    - Implement `DefaultBackgroundTaskLogger` struct using os_log or print statements
    - _Requirements: 6.6_

- [x] 7. Implement background analysis scheduler
  - [x] 7.1 Create BackgroundAnalysisScheduling protocol
    - Create `TradingGuru/Protocols/BackgroundSchedulingProtocols.swift`
    - Define `BackgroundAnalysisScheduling` protocol with:
      - `registerBackgroundTask()`
      - `updateScheduling(for settings:)`
      - `cancelPendingTasks()`
      - `handleBackgroundTask(_ task: Any)`
    - _Requirements: 1.1, 1.2, 1.6_

  - [x] 7.2 Implement BackgroundAnalysisScheduler
    - Create `TradingGuru/Services/BackgroundAnalysisScheduler.swift`
    - Implement `BackgroundAnalysisScheduler` class conforming to `BackgroundAnalysisScheduling`
    - Add static `taskIdentifier = "com.tradingguru.scheduledAnalysis"`
    - Add `shared` singleton instance
    - Inject dependencies: ScheduledAnalysisUserFilter, WeeklyOptionStrategy, ResultsRepository, SettingsRepository, LocalNotificationManaging, ScheduleTimeCalculating, BackgroundTaskLogger
    - Implement `registerBackgroundTask()`:
      - Register with BGTaskScheduler using taskIdentifier
      - Set up launch handler that calls `handleBackgroundTask()`
      - Log registration
    - Implement `updateScheduling(for:)`:
      - If scheduledAnalysisEnabled && !scheduleTimes.isEmpty, schedule next task
      - Otherwise, cancel pending tasks
    - Implement `scheduleNextTask()`:
      - Create BGProcessingTaskRequest with taskIdentifier
      - Set earliestBeginDate from scheduleCalculator
      - Set requiresNetworkConnectivity = true
      - Submit to BGTaskScheduler
      - Log scheduling
    - Implement `cancelPendingTasks()`:
      - Cancel task request with taskIdentifier
      - Log cancellation
    - Implement `handleBackgroundTask(_:)`:
      - Set up expiration handler
      - Check user eligibility with ScheduledAnalysisUserFilter
      - If not eligible, log skip reason and reschedule
      - If watchlist empty, log skip and reschedule
      - Call WeeklyOptionStrategy.analyzeBatch()
      - Save results with LocalResultsRepository
      - Count ORDER signals and call notificationManager.notifyIfAllowed()
      - Schedule next task
      - Mark task completed
    - Implement expiration handler to save partial results
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 5.1, 5.2, 5.3, 5.4, 5.7, 5.8, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [ ]* 7.3 Write property test for partial results processing
    - **Property 10: Partial Results Processing**
    - Test that when some tickers fail and some succeed, results contain entries for all successful tickers
    - **Validates: Requirements 6.2**

- [x] 8. Configure Info.plist and app integration
  - [x] 8.1 Update Info.plist with background task configuration
    - Modify `TradingGuru/Info.plist`
    - Add `BGTaskSchedulerPermittedIdentifiers` array with "com.tradingguru.scheduledAnalysis"
    - Add `UIBackgroundModes` array with "processing" entry
    - _Requirements: 1.1_

  - [x] 8.2 Integrate background task registration in AppDelegate
    - Modify `TradingGuru/TradingGuruApp.swift` or create `TradingGuru/AppDelegate.swift` if needed
    - Call `BackgroundAnalysisScheduler.shared.registerBackgroundTask()` in `application(_:didFinishLaunchingWithOptions:)`
    - Ensure registration happens before the method returns
    - _Requirements: 1.1_

  - [x] 8.3 Implement notification delegate for deep linking
    - Add UNUserNotificationCenterDelegate conformance to AppDelegate
    - Implement `userNotificationCenter(_:didReceive:withCompletionHandler:)`
    - Check for `ANALYSIS_COMPLETE` category identifier
    - Post `showAnalysisResults` notification to trigger navigation
    - Add `Notification.Name.showAnalysisResults` extension
    - _Requirements: 3.6_

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement settings UI components
  - [x] 10.1 Create ScheduleSettingsViewModel
    - Create `TradingGuru/ViewModels/ScheduleSettingsViewModel.swift`
    - Implement `ScheduleSettingsViewModel` as ObservableObject
    - Add @Published properties: scheduleTimes, notificationFrequency, showTimePicker, errorMessage
    - Add computed property `canAddMoreTimes` checking count < maxScheduleTimes
    - Inject SettingsRepository and BackgroundAnalysisScheduler dependencies
    - Implement `addScheduleTime(_:)` that updates settings and background scheduling
    - Implement `removeScheduleTime(_:)` that updates settings and background scheduling
    - Implement `updateBackgroundScheduling()` that loads settings and calls scheduler.updateScheduling()
    - Implement `saveSettings()` that persists to SettingsRepository
    - Display appropriate error messages from ScheduleTimeError
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 2.8, 4.6_

  - [x] 10.2 Create ScheduleTimePickerView
    - Create `TradingGuru/Views/Settings/ScheduleTimePickerView.swift`
    - Implement time picker with hour picker (0-23) and minute picker (0, 15, 30, 45)
    - Use Picker components in wheel style
    - Display selected time in user's local timezone
    - Add "Add" and "Cancel" buttons
    - Call viewModel.addScheduleTime() on Add
    - _Requirements: 2.1, 2.2_

  - [x] 10.3 Create ScheduleSettingsView
    - Create `TradingGuru/Views/Settings/ScheduleSettingsView.swift`
    - Implement Form with sections for Schedule Times and Notifications
    - Display list of schedule times with swipe-to-delete action
    - Add "Add Schedule Time" button that shows time picker sheet
    - Disable add button when at max schedule times (show message)
    - Add Picker for notification frequency with all frequency options
    - Observe scheduleTimes changes to call updateBackgroundScheduling()
    - Observe notificationFrequency changes to call saveSettings()
    - Display error messages in alert or banner
    - Display message when scheduledAnalysisEnabled is true but no schedule times configured
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.8, 4.1, 4.6_

  - [x] 10.4 Integrate schedule settings into main settings view
    - Modify existing settings view to include navigation to ScheduleSettingsView
    - Add section for "Scheduled Analysis" with link to schedule configuration
    - Show notification permission status and link to iOS Settings if denied
    - _Requirements: 2.1, 3.2_

- [x] 11. Wire settings changes to background scheduler
  - [x] 11.1 Observe settings changes and update scheduling
    - Modify SettingsRepository or create observer pattern
    - When scheduledAnalysisEnabled or scheduleTimes change, call BackgroundAnalysisScheduler.shared.updateScheduling()
    - When scheduledAnalysisEnabled is enabled for the first time, request notification permission
    - Handle permission denial by showing guidance to user
    - _Requirements: 1.2, 1.6, 3.1, 3.2, 5.1, 5.7_

  - [x] 11.2 Handle app foreground refresh
    - Observe UIApplication.willEnterForegroundNotification
    - Refresh results display using existing refresh mechanism
    - Clear badge count when app enters foreground
    - _Requirements: 5.5_

- [x] 12. Implement deep link navigation
  - [x] 12.1 Create deep link handler for results navigation
    - Create or modify navigation coordinator to handle showAnalysisResults notification
    - Navigate to analysis results screen when notification is received
    - Ensure navigation works whether app was in foreground, background, or terminated
    - _Requirements: 3.6_

- [x] 13. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 14. Write property tests for models
  - [ ]* 14.1 Write property test for schedule time validation
    - **Property 2: Schedule Time Validation**
    - Test that valid hour (0-23) and minute (0, 15, 30, 45) combinations succeed
    - Test that invalid values fail
    - **Validates: Requirements 2.2**

  - [ ]* 14.2 Write property test for schedule time persistence round trip
    - **Property 3: Schedule Time Persistence Round Trip**
    - Test that adding a ScheduleTime and retrieving returns identical values
    - **Validates: Requirements 2.3**

  - [ ]* 14.3 Write property test for schedule time removal
    - **Property 4: Schedule Time Removal**
    - Test that removing a time decreases list length by one
    - Test that the removed time no longer appears in the list
    - **Validates: Requirements 2.4**

  - [ ]* 14.4 Write property test for schedule times count constraint
    - **Property 5: Schedule Times Count Constraint**
    - Test that length is always 0-8 inclusive
    - Test that adding when count is 8 fails with maximumLimitReached
    - **Validates: Requirements 2.5, 2.6**

  - [ ]* 14.5 Write property test for notification frequency persistence
    - **Property 9: Notification Frequency Persistence Round Trip**
    - Test that saving and retrieving NotificationFrequency returns the same value
    - **Validates: Requirements 4.6**

- [x] 15. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The implementation uses the existing protocol-oriented architecture for consistency
- BGProcessingTask requires device to be charging and connected to Wi-Fi for optimal execution
- Testing background tasks requires using Xcode's debug menu to simulate task launches

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["1.4", "6.1"] },
    { "id": 2, "tasks": ["2.1", "3.1", "4.1"] },
    { "id": 3, "tasks": ["2.2", "3.2", "4.2"] },
    { "id": 4, "tasks": ["4.3", "4.4", "7.1"] },
    { "id": 5, "tasks": ["7.2"] },
    { "id": 6, "tasks": ["7.3", "8.1", "8.2", "8.3"] },
    { "id": 7, "tasks": ["10.1"] },
    { "id": 8, "tasks": ["10.2", "10.3"] },
    { "id": 9, "tasks": ["10.4", "11.1"] },
    { "id": 10, "tasks": ["11.2", "12.1"] },
    { "id": 11, "tasks": ["14.1", "14.2", "14.3", "14.4", "14.5"] }
  ]
}
```
