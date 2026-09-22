//
//  EmailRetryService.swift
//  TradingGuru
//
//  Service providing retry logic for email delivery operations.
//  Implements retry up to 3 times with 1-minute intervals between attempts.
//
//  - Validates: Requirement 9.8 (Retry email up to 3 times with 1-minute intervals)
//  - Validates: Requirement 9.9 (Log failures for monitoring and continue processing other users)
//

import Foundation

// MARK: - Email Retry Result

/// Result of an email delivery attempt with retry tracking information.
/// - Validates: Requirement 9.8 (Track retry attempts)
/// - Validates: Requirement 9.9 (Track failures for monitoring)
struct EmailRetryResult: Equatable {
    /// The user ID the email was sent for
    let userId: String
    
    /// The recipient email address
    let recipientEmail: String
    
    /// Whether the email was ultimately delivered successfully
    let success: Bool
    
    /// Number of attempts made (1 = first try, 2-4 = with retries)
    let attemptsMade: Int
    
    /// The final error if delivery failed after all retries
    let error: EmailRetryError?
    
    /// Timestamp when the operation started
    let startedAt: Date
    
    /// Timestamp when the operation completed (success or final failure)
    let completedAt: Date
    
    /// Duration of all attempts in seconds
    var totalDuration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
    
    /// Creates a successful result.
    static func success(
        userId: String,
        email: String,
        attempts: Int,
        startedAt: Date,
        completedAt: Date = Date()
    ) -> EmailRetryResult {
        EmailRetryResult(
            userId: userId,
            recipientEmail: email,
            success: true,
            attemptsMade: attempts,
            error: nil,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
    
    /// Creates a failed result after exhausting retries.
    static func failure(
        userId: String,
        email: String,
        error: EmailRetryError,
        attempts: Int,
        startedAt: Date,
        completedAt: Date = Date()
    ) -> EmailRetryResult {
        EmailRetryResult(
            userId: userId,
            recipientEmail: email,
            success: false,
            attemptsMade: attempts,
            error: error,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}

// MARK: - Email Retry Error

/// Errors specific to email retry operations.
/// - Validates: Requirement 9.9 (Log failure details for monitoring)
enum EmailRetryError: Error, Equatable {
    /// All retry attempts exhausted.
    /// Contains the underlying error description for logging.
    case retriesExhausted(lastError: String)
    
    /// Operation was cancelled before completion.
    case cancelled
    
    /// Email delivery failed with specific reason.
    case deliveryFailed(reason: String)
    
    /// Email gating check failed (no email or notifications disabled).
    case gatingFailed(reason: String)
    
    /// Detailed error message for logging/monitoring.
    /// - Validates: Requirement 9.9 (Log failures for monitoring)
    var logMessage: String {
        switch self {
        case .retriesExhausted(let lastError):
            return "Email delivery failed after maximum retry attempts. Last error: \(lastError)"
        case .cancelled:
            return "Email delivery operation was cancelled."
        case .deliveryFailed(let reason):
            return "Email delivery failed: \(reason)"
        case .gatingFailed(let reason):
            return "Email gating check failed: \(reason)"
        }
    }
}

extension EmailRetryError: LocalizedError {
    var errorDescription: String? {
        return logMessage
    }
}

// MARK: - Email Retry Configuration

/// Configuration for email retry behavior.
/// - Validates: Requirement 9.8 (3 retries with 1-minute intervals)
struct EmailRetryConfiguration: Equatable {
    /// Maximum number of retry attempts (not including initial attempt).
    /// Total attempts = 1 initial + maxRetryAttempts
    let maxRetryAttempts: Int
    
    /// Fixed delay in seconds between retry attempts.
    let retryIntervalSeconds: TimeInterval
    
    /// Default configuration per Requirement 9.8.
    /// - 3 retry attempts after initial (4 total attempts)
    /// - 1-minute (60 seconds) interval between attempts
    static let `default` = EmailRetryConfiguration(
        maxRetryAttempts: 3,
        retryIntervalSeconds: 60.0
    )
    
    /// Configuration for testing with shorter delays.
    static let forTesting = EmailRetryConfiguration(
        maxRetryAttempts: 3,
        retryIntervalSeconds: 0.1
    )
    
    /// Configuration for unit testing with no delays.
    static let forUnitTesting = EmailRetryConfiguration(
        maxRetryAttempts: 3,
        retryIntervalSeconds: 0.0
    )
}

// MARK: - Email Retry Logger Protocol

/// Protocol for logging email retry operations.
/// - Validates: Requirement 9.9 (Log failures for monitoring)
protocol EmailRetryLogger: Sendable {
    /// Logs when an email delivery attempt starts.
    func logAttemptStarted(userId: String, email: String, attemptNumber: Int, maxAttempts: Int)
    
    /// Logs when an email delivery attempt succeeds.
    func logAttemptSucceeded(userId: String, email: String, attemptNumber: Int)
    
    /// Logs when an email delivery attempt fails.
    func logAttemptFailed(userId: String, email: String, attemptNumber: Int, error: Error)
    
    /// Logs when all retry attempts are exhausted.
    func logRetriesExhausted(userId: String, email: String, totalAttempts: Int, finalError: Error)
    
    /// Logs a batch processing summary.
    func logBatchSummary(totalUsers: Int, successCount: Int, failureCount: Int, results: [EmailRetryResult])
}

// MARK: - Default Email Retry Logger

/// Default implementation of EmailRetryLogger that prints to console.
/// In production, this should be replaced with a proper logging service.
/// - Validates: Requirement 9.9 (Log failures for monitoring)
final class DefaultEmailRetryLogger: EmailRetryLogger, @unchecked Sendable {
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }()
    
    private func timestamp() -> String {
        return dateFormatter.string(from: Date())
    }
    
    func logAttemptStarted(userId: String, email: String, attemptNumber: Int, maxAttempts: Int) {
        print("[\(timestamp())] [EmailRetry] Starting attempt \(attemptNumber)/\(maxAttempts) for user \(userId) (\(email))")
    }
    
    func logAttemptSucceeded(userId: String, email: String, attemptNumber: Int) {
        print("[\(timestamp())] [EmailRetry] SUCCESS: Email delivered to \(email) for user \(userId) on attempt \(attemptNumber)")
    }
    
    func logAttemptFailed(userId: String, email: String, attemptNumber: Int, error: Error) {
        print("[\(timestamp())] [EmailRetry] FAILED: Attempt \(attemptNumber) failed for user \(userId) (\(email)): \(error.localizedDescription)")
    }
    
    func logRetriesExhausted(userId: String, email: String, totalAttempts: Int, finalError: Error) {
        print("[\(timestamp())] [EmailRetry] EXHAUSTED: All \(totalAttempts) attempts failed for user \(userId) (\(email)). Final error: \(finalError.localizedDescription)")
    }
    
    func logBatchSummary(totalUsers: Int, successCount: Int, failureCount: Int, results: [EmailRetryResult]) {
        print("[\(timestamp())] [EmailRetry] BATCH SUMMARY: \(successCount)/\(totalUsers) emails delivered successfully, \(failureCount) failed")
        
        // Log details of failed deliveries for monitoring
        let failures = results.filter { !$0.success }
        for failure in failures {
            if let error = failure.error {
                print("[\(timestamp())] [EmailRetry]   - User \(failure.userId): \(error.logMessage)")
            }
        }
    }
}

// MARK: - Email Retry Service Protocol

/// Protocol for email retry service.
/// - Validates: Requirement 9.8 (Retry up to 3 times with 1-minute intervals)
/// - Validates: Requirement 9.9 (Log failures and continue processing other users)
protocol EmailRetryServiceProtocol {
    /// The current retry configuration.
    var configuration: EmailRetryConfiguration { get }
    
    /// The logger for monitoring.
    var logger: EmailRetryLogger { get }
    
    /// Sends an email with automatic retry on failure.
    /// - Parameters:
    ///   - emailService: The email service to use for sending
    ///   - to: Recipient email address
    ///   - subject: Email subject line
    ///   - htmlBody: HTML content of the email
    ///   - userId: User ID for logging purposes
    /// - Returns: EmailRetryResult containing success/failure status and attempt count
    func sendWithRetry(
        using emailService: EmailServiceProtocol,
        to: String,
        subject: String,
        htmlBody: String,
        userId: String
    ) async -> EmailRetryResult
    
    /// Sends analysis results email with automatic retry on failure.
    /// - Parameters:
    ///   - emailService: The email service to use for sending
    ///   - results: Analysis results to include in the email
    ///   - userSettings: User's notification settings
    ///   - htmlContent: Pre-formatted HTML content
    ///   - subject: Email subject line
    ///   - userId: User ID for logging purposes
    /// - Returns: EmailRetryResult containing success/failure status and attempt count
    func sendAnalysisResultsWithRetry(
        using emailService: EmailServiceProtocol,
        results: [AnalysisResult],
        userSettings: UserSettings,
        htmlContent: String,
        subject: String,
        userId: String
    ) async -> EmailRetryResult
    
    /// Sends emails to multiple users, continuing on individual failures.
    /// - Parameters:
    ///   - emailService: The email service to use for sending
    ///   - userEmails: Array of (userId, userSettings, results) tuples to process
    ///   - generateContent: Closure to generate email content for each user
    /// - Returns: Array of EmailRetryResults, one per user
    /// - Validates: Requirement 9.9 (Continue processing other users on failure)
    func sendBatchWithRetry(
        using emailService: EmailServiceProtocol,
        userEmails: [(userId: String, settings: UserSettings, results: [AnalysisResult])],
        generateContent: (String, [AnalysisResult]) -> (subject: String, htmlBody: String)
    ) async -> [EmailRetryResult]
}

// MARK: - Email Retry Service Implementation

/// Service providing retry logic for email delivery operations.
///
/// This service wraps email sending operations and automatically retries them
/// on failure up to 3 times with 1-minute intervals between attempts.
///
/// Usage:
/// ```swift
/// let retryService = EmailRetryService()
/// let result = await retryService.sendWithRetry(
///     using: emailService,
///     to: "user@example.com",
///     subject: "Analysis Results",
///     htmlBody: htmlContent,
///     userId: "user123"
/// )
/// if result.success {
///     // Email delivered
/// } else {
///     // All retries failed - error logged for monitoring
/// }
/// ```
///
/// - Validates: Requirement 9.8 (Retry up to 3 times with 1-minute intervals)
/// - Validates: Requirement 9.9 (Log failures for monitoring and continue processing other users)
final class EmailRetryService: EmailRetryServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The retry configuration.
    let configuration: EmailRetryConfiguration
    
    /// The logger for monitoring email operations.
    let logger: EmailRetryLogger
    
    // MARK: - Initialization
    
    /// Creates a new EmailRetryService instance.
    /// - Parameters:
    ///   - configuration: The retry configuration (defaults to 3 retries with 1-minute intervals)
    ///   - logger: The logger for monitoring (defaults to console logger)
    init(
        configuration: EmailRetryConfiguration = .default,
        logger: EmailRetryLogger = DefaultEmailRetryLogger()
    ) {
        self.configuration = configuration
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Sends an email with automatic retry on failure.
    ///
    /// Implements fixed-interval retry logic per Requirement 9.8:
    /// - Attempt 1: Execute immediately
    /// - Attempt 2: Wait 1 minute, then retry
    /// - Attempt 3: Wait 1 minute, then retry
    /// - Attempt 4: Wait 1 minute, then retry
    ///
    /// - Parameters:
    ///   - emailService: The email service to use for sending
    ///   - to: Recipient email address
    ///   - subject: Email subject line
    ///   - htmlBody: HTML content of the email
    ///   - userId: User ID for logging purposes
    /// - Returns: EmailRetryResult containing success/failure status and attempt count
    /// - Validates: Requirement 9.8 (Retry up to 3 times with 1-minute intervals)
    /// - Validates: Requirement 9.9 (Log failures for monitoring)
    func sendWithRetry(
        using emailService: EmailServiceProtocol,
        to: String,
        subject: String,
        htmlBody: String,
        userId: String
    ) async -> EmailRetryResult {
        let startedAt = Date()
        let maxAttempts = 1 + configuration.maxRetryAttempts // 1 initial + 3 retries = 4 total
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            // Log attempt start
            logger.logAttemptStarted(
                userId: userId,
                email: to,
                attemptNumber: attempt,
                maxAttempts: maxAttempts
            )
            
            do {
                // Execute the email send operation
                try await emailService.sendEmail(to: to, subject: subject, htmlBody: htmlBody)
                
                // Success!
                logger.logAttemptSucceeded(userId: userId, email: to, attemptNumber: attempt)
                
                return .success(
                    userId: userId,
                    email: to,
                    attempts: attempt,
                    startedAt: startedAt
                )
                
            } catch {
                lastError = error
                
                // Log the failed attempt
                logger.logAttemptFailed(userId: userId, email: to, attemptNumber: attempt, error: error)
                
                // Check if we should retry
                let isLastAttempt = attempt == maxAttempts
                let canRetry = !isLastAttempt && shouldRetry(error: error)
                
                if canRetry {
                    // Wait before retrying (1-minute interval per Requirement 9.8)
                    try? await Task.sleep(nanoseconds: UInt64(configuration.retryIntervalSeconds * 1_000_000_000))
                    
                } else if isLastAttempt {
                    // All retries exhausted - log for monitoring per Requirement 9.9
                    logger.logRetriesExhausted(
                        userId: userId,
                        email: to,
                        totalAttempts: attempt,
                        finalError: error
                    )
                    
                    return .failure(
                        userId: userId,
                        email: to,
                        error: .retriesExhausted(lastError: error.localizedDescription),
                        attempts: attempt,
                        startedAt: startedAt
                    )
                    
                } else {
                    // Error is not retryable - fail immediately
                    logger.logRetriesExhausted(
                        userId: userId,
                        email: to,
                        totalAttempts: attempt,
                        finalError: error
                    )
                    
                    return .failure(
                        userId: userId,
                        email: to,
                        error: .deliveryFailed(reason: error.localizedDescription),
                        attempts: attempt,
                        startedAt: startedAt
                    )
                }
            }
        }
        
        // Should not reach here, but handle it gracefully
        return .failure(
            userId: userId,
            email: to,
            error: .retriesExhausted(lastError: lastError?.localizedDescription ?? "Unknown error"),
            attempts: maxAttempts,
            startedAt: startedAt
        )
    }
    
    /// Sends analysis results email with automatic retry on failure.
    ///
    /// This method first checks gating conditions (email configured, notifications enabled)
    /// and then sends the email with retry logic.
    ///
    /// - Parameters:
    ///   - emailService: The email service to use for sending
    ///   - results: Analysis results to include in the email
    ///   - userSettings: User's notification settings
    ///   - htmlContent: Pre-formatted HTML content
    ///   - subject: Email subject line
    ///   - userId: User ID for logging purposes
    /// - Returns: EmailRetryResult containing success/failure status and attempt count
    /// - Validates: Requirement 9.8 (Retry up to 3 times with 1-minute intervals)
    /// - Validates: Requirement 9.9 (Log failures for monitoring)
    func sendAnalysisResultsWithRetry(
        using emailService: EmailServiceProtocol,
        results: [AnalysisResult],
        userSettings: UserSettings,
        htmlContent: String,
        subject: String,
        userId: String
    ) async -> EmailRetryResult {
        let startedAt = Date()
        
        // Check gating conditions first
        guard emailService.canSendEmail(for: userSettings) else {
            let reason: String
            if userSettings.notificationEmail == nil || userSettings.notificationEmail?.isEmpty == true {
                reason = "No email address configured"
            } else if !userSettings.emailNotificationsEnabled {
                reason = "Email notifications disabled"
            } else {
                reason = "Email gating check failed"
            }
            
            return .failure(
                userId: userId,
                email: userSettings.notificationEmail ?? "none",
                error: .gatingFailed(reason: reason),
                attempts: 0,
                startedAt: startedAt
            )
        }
        
        let recipientEmail = userSettings.notificationEmail!
        let maxAttempts = 1 + configuration.maxRetryAttempts
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            logger.logAttemptStarted(
                userId: userId,
                email: recipientEmail,
                attemptNumber: attempt,
                maxAttempts: maxAttempts
            )
            
            do {
                try await emailService.sendAnalysisResults(
                    results: results,
                    userSettings: userSettings,
                    htmlContent: htmlContent,
                    subject: subject
                )
                
                logger.logAttemptSucceeded(userId: userId, email: recipientEmail, attemptNumber: attempt)
                
                return .success(
                    userId: userId,
                    email: recipientEmail,
                    attempts: attempt,
                    startedAt: startedAt
                )
                
            } catch {
                lastError = error
                logger.logAttemptFailed(userId: userId, email: recipientEmail, attemptNumber: attempt, error: error)
                
                let isLastAttempt = attempt == maxAttempts
                let canRetry = !isLastAttempt && shouldRetry(error: error)
                
                if canRetry {
                    try? await Task.sleep(nanoseconds: UInt64(configuration.retryIntervalSeconds * 1_000_000_000))
                } else if isLastAttempt {
                    logger.logRetriesExhausted(
                        userId: userId,
                        email: recipientEmail,
                        totalAttempts: attempt,
                        finalError: error
                    )
                    
                    return .failure(
                        userId: userId,
                        email: recipientEmail,
                        error: .retriesExhausted(lastError: error.localizedDescription),
                        attempts: attempt,
                        startedAt: startedAt
                    )
                } else {
                    logger.logRetriesExhausted(
                        userId: userId,
                        email: recipientEmail,
                        totalAttempts: attempt,
                        finalError: error
                    )
                    
                    return .failure(
                        userId: userId,
                        email: recipientEmail,
                        error: .deliveryFailed(reason: error.localizedDescription),
                        attempts: attempt,
                        startedAt: startedAt
                    )
                }
            }
        }
        
        return .failure(
            userId: userId,
            email: recipientEmail,
            error: .retriesExhausted(lastError: lastError?.localizedDescription ?? "Unknown error"),
            attempts: maxAttempts,
            startedAt: startedAt
        )
    }
    
    /// Sends emails to multiple users, continuing on individual failures.
    ///
    /// This method processes each user independently, ensuring that a failure
    /// for one user does not prevent emails from being sent to other users.
    ///
    /// - Parameters:
    ///   - emailService: The email service to use for sending
    ///   - userEmails: Array of (userId, userSettings, results) tuples to process
    ///   - generateContent: Closure to generate email content for each user
    /// - Returns: Array of EmailRetryResults, one per user
    /// - Validates: Requirement 9.9 (Continue processing other users on failure)
    func sendBatchWithRetry(
        using emailService: EmailServiceProtocol,
        userEmails: [(userId: String, settings: UserSettings, results: [AnalysisResult])],
        generateContent: (String, [AnalysisResult]) -> (subject: String, htmlBody: String)
    ) async -> [EmailRetryResult] {
        var results: [EmailRetryResult] = []
        
        // Process each user independently
        // Failures for one user do not affect others (Requirement 9.9)
        for userEmail in userEmails {
            let content = generateContent(userEmail.userId, userEmail.results)
            
            let result = await sendAnalysisResultsWithRetry(
                using: emailService,
                results: userEmail.results,
                userSettings: userEmail.settings,
                htmlContent: content.htmlBody,
                subject: content.subject,
                userId: userEmail.userId
            )
            
            results.append(result)
        }
        
        // Log batch summary for monitoring
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count
        logger.logBatchSummary(
            totalUsers: userEmails.count,
            successCount: successCount,
            failureCount: failureCount,
            results: results
        )
        
        return results
    }
    
    // MARK: - Private Methods
    
    /// Determines if an email error should trigger a retry.
    /// - Parameter error: The error to evaluate
    /// - Returns: true if the operation should be retried
    private func shouldRetry(error: Error) -> Bool {
        // Check for EmailServiceError
        if let emailError = error as? EmailServiceError {
            switch emailError {
            case .networkError, .timeout, .apiError, .deliveryFailed:
                // Retry network-related and delivery errors
                return true
            case .noEmailConfigured, .notificationsDisabled, .invalidEmailFormat:
                // Don't retry configuration/validation errors
                return false
            case .unknown:
                // Retry unknown errors (might be transient)
                return true
            }
        }
        
        // Check for common error types by description (fallback)
        let errorDescription = error.localizedDescription.lowercased()
        let retryableKeywords = ["network", "timeout", "connection", "unavailable", "offline", "temporary"]
        
        return retryableKeywords.contains { errorDescription.contains($0) }
    }
}

// MARK: - Convenience Extensions

extension EmailRetryService {
    
    /// Creates a service configured for testing with shorter delays.
    /// - Parameter logger: Optional custom logger for testing
    /// - Returns: An EmailRetryService with minimal delays
    static func forTesting(logger: EmailRetryLogger = DefaultEmailRetryLogger()) -> EmailRetryService {
        return EmailRetryService(
            configuration: .forTesting,
            logger: logger
        )
    }
    
    /// Creates a service with no delays (for unit tests).
    /// - Parameter logger: Optional custom logger for testing
    /// - Returns: An EmailRetryService with zero delays
    static func forUnitTesting(logger: EmailRetryLogger = DefaultEmailRetryLogger()) -> EmailRetryService {
        return EmailRetryService(
            configuration: .forUnitTesting,
            logger: logger
        )
    }
}

// MARK: - Mock Logger for Testing

#if DEBUG
/// Mock logger that captures log entries for testing.
final class MockEmailRetryLogger: EmailRetryLogger, @unchecked Sendable {
    struct LogEntry: Equatable {
        let type: LogType
        let userId: String
        let email: String
        let attemptNumber: Int?
        let maxAttempts: Int?
        let errorMessage: String?
        
        enum LogType: Equatable {
            case attemptStarted
            case attemptSucceeded
            case attemptFailed
            case retriesExhausted
            case batchSummary
        }
    }
    
    private(set) var entries: [LogEntry] = []
    private(set) var batchSummaries: [(total: Int, success: Int, failure: Int)] = []
    
    func logAttemptStarted(userId: String, email: String, attemptNumber: Int, maxAttempts: Int) {
        entries.append(LogEntry(
            type: .attemptStarted,
            userId: userId,
            email: email,
            attemptNumber: attemptNumber,
            maxAttempts: maxAttempts,
            errorMessage: nil
        ))
    }
    
    func logAttemptSucceeded(userId: String, email: String, attemptNumber: Int) {
        entries.append(LogEntry(
            type: .attemptSucceeded,
            userId: userId,
            email: email,
            attemptNumber: attemptNumber,
            maxAttempts: nil,
            errorMessage: nil
        ))
    }
    
    func logAttemptFailed(userId: String, email: String, attemptNumber: Int, error: Error) {
        entries.append(LogEntry(
            type: .attemptFailed,
            userId: userId,
            email: email,
            attemptNumber: attemptNumber,
            maxAttempts: nil,
            errorMessage: error.localizedDescription
        ))
    }
    
    func logRetriesExhausted(userId: String, email: String, totalAttempts: Int, finalError: Error) {
        entries.append(LogEntry(
            type: .retriesExhausted,
            userId: userId,
            email: email,
            attemptNumber: totalAttempts,
            maxAttempts: nil,
            errorMessage: finalError.localizedDescription
        ))
    }
    
    func logBatchSummary(totalUsers: Int, successCount: Int, failureCount: Int, results: [EmailRetryResult]) {
        batchSummaries.append((total: totalUsers, success: successCount, failure: failureCount))
        entries.append(LogEntry(
            type: .batchSummary,
            userId: "",
            email: "",
            attemptNumber: nil,
            maxAttempts: nil,
            errorMessage: nil
        ))
    }
    
    /// Resets the mock state.
    func reset() {
        entries = []
        batchSummaries = []
    }
}
#endif
