//
//  UserSettings.swift
//  TradingGuru
//
//  User settings model for notification and analysis preferences.
//

import Foundation

/// User-specific settings for notifications and scheduled analysis.
/// - Validates: Requirements 4.8, 6.1 (User settings management)
/// - Validates: Requirement 8.8 (Settings option for scheduled analysis, default enabled)
/// - Validates: Requirements 2.3, 2.4, 2.5, 2.6, 2.7 (Schedule times management)
/// - Validates: Requirement 4.6 (Notification frequency setting)
/// - Validates: Requirement 5.6 (Schedule and notification fields in UserSettings)
struct UserSettings: Equatable {
    
    // MARK: - Static Constants
    
    /// Maximum number of schedule times allowed.
    /// - Validates: Requirement 2.5 (1-8 schedule times)
    static let maxScheduleTimes = 8
    
    /// Default schedule times for new users.
    /// - Validates: Requirement 2.7 (Default is 6:30 AM and 12:30 PM)
    static var defaultScheduleTimes: [ScheduleTime] {
        [
            ScheduleTime.create(hour: 6, minute: 30)!,
            ScheduleTime.create(hour: 12, minute: 30)!
        ]
    }
    
    // MARK: - Properties
    
    /// Email address for receiving notifications
    var notificationEmail: String?
    
    /// Whether email notifications are enabled
    var emailNotificationsEnabled: Bool
    
    /// Whether scheduled analysis is enabled.
    /// - Validates: Requirement 8.8 (Default is enabled)
    var scheduledAnalysisEnabled: Bool
    
    /// Configured schedule times for background analysis.
    /// - Validates: Requirement 2.5 (1-8 schedule times)
    var scheduleTimes: [ScheduleTime]
    
    /// Notification frequency preference.
    /// - Validates: Requirement 4.6 (Persisted to settings)
    var notificationFrequency: NotificationFrequency
    
    /// Timestamp when settings were last updated
    var updatedAt: Date
    
    // MARK: - Initialization
    
    /// Creates a new UserSettings instance.
    /// - Parameters:
    ///   - notificationEmail: Email address for notifications (optional)
    ///   - emailNotificationsEnabled: Whether email notifications are enabled
    ///   - scheduledAnalysisEnabled: Whether scheduled analysis is enabled
    ///   - scheduleTimes: Configured schedule times for background analysis
    ///   - notificationFrequency: Notification frequency preference
    ///   - updatedAt: Last update timestamp
    init(
        notificationEmail: String? = nil,
        emailNotificationsEnabled: Bool = true,
        scheduledAnalysisEnabled: Bool = true,
        scheduleTimes: [ScheduleTime] = UserSettings.defaultScheduleTimes,
        notificationFrequency: NotificationFrequency = .default,
        updatedAt: Date = Date()
    ) {
        self.notificationEmail = notificationEmail
        self.emailNotificationsEnabled = emailNotificationsEnabled
        self.scheduledAnalysisEnabled = scheduledAnalysisEnabled
        self.scheduleTimes = scheduleTimes
        self.notificationFrequency = notificationFrequency
        self.updatedAt = updatedAt
    }
    
    /// Default user settings with notifications and scheduled analysis enabled.
    static let `default` = UserSettings(
        notificationEmail: nil,
        emailNotificationsEnabled: true,
        scheduledAnalysisEnabled: true,
        scheduleTimes: defaultScheduleTimes,
        notificationFrequency: .default,
        updatedAt: Date()
    )
    
    // MARK: - Computed Properties
    
    /// Validates the notification email format if provided.
    /// - Returns: True if email is nil or has a valid format
    var hasValidEmail: Bool {
        guard let email = notificationEmail, !email.isEmpty else {
            return true // nil or empty is valid (means no email configured)
        }
        return email.isValidEmail
    }
    
    // MARK: - Schedule Time Management
    
    /// Adds a schedule time to the list.
    /// - Parameter time: The schedule time to add
    /// - Returns: Success if added, failure with error otherwise
    /// - Validates: Requirement 2.3 (Add schedule time)
    /// - Validates: Requirement 2.5 (1-8 schedule times limit)
    /// - Validates: Requirement 2.6 (Maximum limit error)
    mutating func addScheduleTime(_ time: ScheduleTime) -> Result<Void, ScheduleTimeError> {
        // Check if at maximum capacity
        if scheduleTimes.count >= Self.maxScheduleTimes {
            return .failure(.maximumLimitReached(max: Self.maxScheduleTimes))
        }
        
        // Check for duplicate
        if scheduleTimes.contains(time) {
            return .failure(.duplicateTime)
        }
        
        scheduleTimes.append(time)
        return .success(())
    }
    
    /// Removes a schedule time from the list.
    /// - Parameter time: The schedule time to remove
    /// - Returns: True if the time was found and removed, false otherwise
    /// - Validates: Requirement 2.4 (Remove schedule time)
    mutating func removeScheduleTime(_ time: ScheduleTime) -> Bool {
        if let index = scheduleTimes.firstIndex(of: time) {
            scheduleTimes.remove(at: index)
            return true
        }
        return false
    }
}

// MARK: - Codable Conformance

extension UserSettings: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case notificationEmail
        case emailNotificationsEnabled
        case scheduledAnalysisEnabled
        case scheduleTimes
        case notificationFrequency
        case updatedAt
    }
    
    /// Decodes UserSettings with backwards compatibility for new properties.
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if required properties cannot be decoded
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        notificationEmail = try container.decodeIfPresent(String.self, forKey: .notificationEmail)
        emailNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .emailNotificationsEnabled) ?? true
        scheduledAnalysisEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduledAnalysisEnabled) ?? true
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        
        // Backwards compatibility: use defaults if new properties are missing
        scheduleTimes = try container.decodeIfPresent([ScheduleTime].self, forKey: .scheduleTimes) ?? UserSettings.defaultScheduleTimes
        notificationFrequency = try container.decodeIfPresent(NotificationFrequency.self, forKey: .notificationFrequency) ?? .default
    }
    
    /// Encodes UserSettings.
    /// - Parameter encoder: The encoder to write to
    /// - Throws: EncodingError if encoding fails
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(notificationEmail, forKey: .notificationEmail)
        try container.encode(emailNotificationsEnabled, forKey: .emailNotificationsEnabled)
        try container.encode(scheduledAnalysisEnabled, forKey: .scheduledAnalysisEnabled)
        try container.encode(scheduleTimes, forKey: .scheduleTimes)
        try container.encode(notificationFrequency, forKey: .notificationFrequency)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Email Validation Extension

extension String {
    /// Validates if the string is a properly formatted email address.
    /// - Returns: True if the string matches email format pattern
    var isValidEmail: Bool {
        // Basic email validation pattern
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: emailPattern, options: .regularExpression) != nil
    }
}
