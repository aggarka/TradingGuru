# Requirements Document

## Introduction

This feature enables automated background analysis execution on iOS devices using BGProcessingTask, combined with local push notifications to alert users when ORDER signals are found. Users can configure their preferred schedule times and notification frequency through the app settings. The feature integrates with the existing `scheduledAnalysisEnabled` toggle, `ScheduledAnalysisUserFilter` eligibility logic, `WeeklyOptionStrategy.analyzeBatch()` analysis engine, and `LocalResultsRepository` for result persistence.

## Glossary

- **Background_Analysis_Scheduler**: The component responsible for registering, scheduling, and managing iOS BGProcessingTask executions for running automated analysis
- **BGProcessingTask**: An iOS BackgroundTasks framework task type designed for deferrable, long-running operations that iOS schedules opportunistically based on device conditions
- **Local_Notification_Manager**: The component responsible for requesting notification permissions, composing notification content, and delivering local push notifications to the user
- **Schedule_Time**: A user-selected time of day when the background analysis task should be scheduled to run
- **Notification_Frequency**: A user-configurable setting that controls the minimum time interval between consecutive local notifications to prevent notification fatigue
- **ORDER_Signal**: A trading signal indicating an actionable opportunity identified by the analysis, as opposed to HOLD signals which indicate no action
- **User_Settings**: The existing settings model containing user preferences including `scheduledAnalysisEnabled` and the new schedule and notification configuration fields
- **Scheduled_Analysis_User_Filter**: The existing service that determines user eligibility for scheduled analysis based on `scheduledAnalysisEnabled` and watchlist presence
- **Local_Results_Repository**: The existing persistence layer for storing and retrieving analysis results locally on the device

## Requirements

### Requirement 1: Background Task Registration and Scheduling

**User Story:** As a user, I want the app to register and schedule background analysis tasks, so that my watchlist is analyzed automatically at my preferred times without manual intervention.

#### Acceptance Criteria

1. WHEN the app launches, THE Background_Analysis_Scheduler SHALL register a BGProcessingTask with the identifier "com.tradingguru.scheduledAnalysis" with the iOS BackgroundTasks framework
2. WHEN the user enables scheduledAnalysisEnabled in settings and has configured at least one schedule time, THE Background_Analysis_Scheduler SHALL submit a BGProcessingTaskRequest to the iOS system scheduler
3. THE BGProcessingTaskRequest SHALL set the earliestBeginDate to the next occurrence of the user-configured schedule time
4. THE Background_Analysis_Scheduler SHALL set requiresNetworkConnectivity to true on the task request since analysis requires fetching market data
5. WHEN a scheduled background task begins execution, THE Background_Analysis_Scheduler SHALL invoke the existing WeeklyOptionStrategy.analyzeBatch() method with the user's watchlist and configuration
6. WHEN the user disables scheduledAnalysisEnabled in settings, THE Background_Analysis_Scheduler SHALL cancel any pending BGProcessingTaskRequest for the scheduled analysis
7. IF the BGProcessingTask is terminated by iOS before completion, THEN THE Background_Analysis_Scheduler SHALL reschedule the task for the next configured schedule time
8. WHEN analysis completes successfully during a background task, THE Background_Analysis_Scheduler SHALL persist results using the existing LocalResultsRepository and schedule the next task occurrence

### Requirement 2: User-Configurable Schedule Times

**User Story:** As a user, I want to select specific times for the background analysis to run, so that I receive trading signals at times that align with my trading schedule.

#### Acceptance Criteria

1. THE App SHALL provide a settings interface where users can configure one or more schedule times for background analysis execution
2. THE schedule time picker SHALL allow users to select times in 15-minute increments from 00:00 to 23:45 in the user's local timezone
3. WHEN a user adds a new schedule time, THE User_Settings SHALL persist the schedule time to local storage and update the background task scheduling
4. WHEN a user removes a schedule time, THE User_Settings SHALL remove the time from local storage and update the background task scheduling
5. THE App SHALL allow users to configure between 1 and 8 schedule times
6. IF a user attempts to add more than 8 schedule times, THEN THE App SHALL display an error message indicating the maximum limit has been reached
7. THE default schedule times for new users SHALL be 6:30 AM and 12:30 PM in the user's local timezone
8. WHEN the user has no schedule times configured and scheduledAnalysisEnabled is true, THE App SHALL display a message prompting the user to add at least one schedule time

### Requirement 3: Local Notification Permission and Delivery

**User Story:** As a user, I want to receive local push notifications when ORDER signals are found, so that I am alerted to actionable trading opportunities without opening the app.

#### Acceptance Criteria

1. WHEN the user enables scheduledAnalysisEnabled for the first time, THE Local_Notification_Manager SHALL request notification authorization from the user with alert, sound, and badge options
2. IF the user denies notification permission, THEN THE App SHALL display a message explaining that notifications are disabled and providing instructions to enable them in iOS Settings
3. WHEN a background analysis completes and at least one ORDER signal is found, THE Local_Notification_Manager SHALL create and schedule a local notification
4. THE notification content SHALL include a title of "TradingGuru Analysis Complete" and a body in the format "[N] ORDER signals found! Tap to review." where N is the count of ORDER signals
5. THE notification SHALL include a badge count equal to the number of ORDER signals found
6. WHEN the user taps the notification, THE App SHALL launch and navigate to the analysis results screen displaying the latest results
7. IF no ORDER signals are found in the analysis results, THEN THE Local_Notification_Manager SHALL not deliver a notification for that analysis run
8. THE notification sound SHALL use the default iOS notification sound

### Requirement 4: User-Configurable Notification Frequency

**User Story:** As a user, I want to control how often I receive notifications, so that I am not overwhelmed by frequent alerts while still staying informed of trading opportunities.

#### Acceptance Criteria

1. THE App SHALL provide a settings option for users to configure notification frequency with the following options: "Every time", "At most once per 30 minutes", "At most once per hour", "At most once per 2 hours", "At most once per 4 hours", and "At most once per day"
2. THE default notification frequency for new users SHALL be "At most once per hour"
3. WHEN a background analysis completes with ORDER signals, THE Local_Notification_Manager SHALL check the timestamp of the last delivered notification
4. IF the time elapsed since the last notification is less than the configured notification frequency interval, THEN THE Local_Notification_Manager SHALL suppress the notification and not deliver it
5. WHEN a notification is delivered, THE Local_Notification_Manager SHALL persist the delivery timestamp to local storage for frequency enforcement
6. THE notification frequency setting SHALL be persisted to User_Settings and synchronized with local storage
7. WHEN the notification frequency is set to "Every time", THE Local_Notification_Manager SHALL deliver notifications for every analysis run that finds ORDER signals without any suppression

### Requirement 5: Integration with Existing Infrastructure

**User Story:** As a developer, I want the background analysis feature to integrate seamlessly with existing components, so that the implementation is maintainable and consistent with the current architecture.

#### Acceptance Criteria

1. THE Background_Analysis_Scheduler SHALL respect the existing scheduledAnalysisEnabled toggle in User_Settings to determine whether background tasks should be scheduled
2. THE Background_Analysis_Scheduler SHALL use the existing ScheduledAnalysisUserFilter.isEligible() method to verify user eligibility before executing analysis
3. WHEN executing background analysis, THE Background_Analysis_Scheduler SHALL invoke WeeklyOptionStrategy.analyzeBatch() with the user's current watchlist and strategy configuration
4. THE Background_Analysis_Scheduler SHALL persist analysis results using the existing LocalResultsRepository.saveResults() method
5. WHEN the app returns to the foreground after a background analysis, THE App SHALL refresh the results display using the existing results refresh mechanism
6. THE schedule times and notification frequency settings SHALL be added as new fields to the existing UserSettings model
7. IF scheduledAnalysisEnabled is false, THEN THE Background_Analysis_Scheduler SHALL not submit any BGProcessingTaskRequest and shall cancel any pending requests
8. IF the user's watchlist is empty when a background task executes, THEN THE Background_Analysis_Scheduler SHALL skip the analysis, log the skip reason, and reschedule for the next configured time

### Requirement 6: Error Handling and Resilience

**User Story:** As a user, I want the background analysis to handle errors gracefully, so that temporary failures do not prevent future analysis runs or corrupt my data.

#### Acceptance Criteria

1. IF network connectivity is unavailable when a background task executes, THEN THE Background_Analysis_Scheduler SHALL mark the task as failed and allow iOS to reschedule based on system conditions
2. IF the WeeklyOptionStrategy.analyzeBatch() method throws an error for individual tickers, THEN THE Background_Analysis_Scheduler SHALL continue processing remaining tickers and include partial results
3. IF the LocalResultsRepository.saveResults() method fails, THEN THE Background_Analysis_Scheduler SHALL log the error and attempt to save results on the next successful analysis run
4. THE Background_Analysis_Scheduler SHALL implement a task expiration handler that gracefully terminates analysis and saves any partial results before iOS terminates the background task
5. IF all tickers fail during analysis, THEN THE Background_Analysis_Scheduler SHALL not deliver a notification and shall reschedule for the next configured time
6. THE Background_Analysis_Scheduler SHALL log all background task executions, completions, and failures for debugging purposes
