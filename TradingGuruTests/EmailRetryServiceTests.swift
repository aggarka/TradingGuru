//
//  EmailRetryServiceTests.swift
//  TradingGuruTests
//
//  Unit tests for EmailRetryService retry logic.
//  Tests validate Requirements 9.8 and 9.9.
//

import XCTest
@testable import TradingGuru

// MARK: - Mock Email Service for Testing

/// Mock email service that can be configured to succeed or fail.
final class MockEmailServiceForRetry: EmailServiceProtocol {
    /// Number of times sendEmail was called
    private(set) var sendEmailCallCount = 0
    
    /// Number of times sendAnalysisResults was called
    private(set) var sendAnalysisResultsCallCount = 0
    
    /// Number of failures before success (0 = always succeed, -1 = always fail)
    var failuresBeforeSuccess: Int = 0
    
    /// The error to throw when failing
    var errorToThrow: EmailServiceError = .networkError(reason: "Test network error")
    
    /// Simulated delay for operations
    var simulatedDelay: TimeInterval = 0
    
    /// Record of sent emails for verification
    private(set) var sentEmails: [(to: String, subject: String, htmlBody: String)] = []
    
    func sendEmail(to: String, subject: String, htmlBody: String) async throws {
        sendEmailCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        // Check if we should fail this attempt
        if failuresBeforeSuccess < 0 || sendEmailCallCount <= failuresBeforeSuccess {
            throw errorToThrow
        }
        
        sentEmails.append((to: to, subject: subject, htmlBody: htmlBody))
    }
    
    func canSendEmail(for userSettings: UserSettings) -> Bool {
        guard let email = userSettings.notificationEmail,
              !email.isEmpty else {
            return false
        }
        return userSettings.emailNotificationsEnabled
    }
    
    func sendAnalysisResults(
        results: [AnalysisResult],
        userSettings: UserSettings,
        htmlContent: String,
        subject: String
    ) async throws {
        sendAnalysisResultsCallCount += 1
        
        guard canSendEmail(for: userSettings) else {
            if userSettings.notificationEmail == nil || userSettings.notificationEmail?.isEmpty == true {
                throw EmailServiceError.noEmailConfigured
            }
            throw EmailServiceError.notificationsDisabled
        }
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        // Check if we should fail this attempt
        if failuresBeforeSuccess < 0 || sendAnalysisResultsCallCount <= failuresBeforeSuccess {
            throw errorToThrow
        }
        
        sentEmails.append((
            to: userSettings.notificationEmail!,
            subject: subject,
            htmlBody: htmlContent
        ))
    }
    
    /// Resets the mock state
    func reset() {
        sendEmailCallCount = 0
        sendAnalysisResultsCallCount = 0
        failuresBeforeSuccess = 0
        sentEmails = []
    }
}

// MARK: - Email Retry Service Tests

final class EmailRetryServiceTests: XCTestCase {
    
    var retryService: EmailRetryService!
    var mockEmailService: MockEmailServiceForRetry!
    var mockLogger: MockEmailRetryLogger!
    
    override func setUp() {
        super.setUp()
        mockLogger = MockEmailRetryLogger()
        retryService = EmailRetryService.forUnitTesting(logger: mockLogger)
        mockEmailService = MockEmailServiceForRetry()
    }
    
    override func tearDown() {
        retryService = nil
        mockEmailService = nil
        mockLogger = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfigurationHas3RetryAttempts() {
        let defaultConfig = EmailRetryConfiguration.default
        XCTAssertEqual(defaultConfig.maxRetryAttempts, 3)
    }
    
    func testDefaultConfigurationHas60SecondInterval() {
        let defaultConfig = EmailRetryConfiguration.default
        XCTAssertEqual(defaultConfig.retryIntervalSeconds, 60.0)
    }
    
    // MARK: - Successful Delivery Tests
    
    /// Validates: Requirement 9.8 - successful delivery on first attempt
    func testSendWithRetry_SuccessOnFirstAttempt() async {
        // Given: Email service will succeed
        mockEmailService.failuresBeforeSuccess = 0
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should succeed with 1 attempt
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.attemptsMade, 1)
        XCTAssertNil(result.error)
        XCTAssertEqual(mockEmailService.sendEmailCallCount, 1)
    }
    
    /// Validates: Requirement 9.8 - retry up to 3 times
    func testSendWithRetry_SuccessOnSecondAttempt() async {
        // Given: Email service fails once then succeeds
        mockEmailService.failuresBeforeSuccess = 1
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should succeed with 2 attempts
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.attemptsMade, 2)
        XCTAssertNil(result.error)
        XCTAssertEqual(mockEmailService.sendEmailCallCount, 2)
    }
    
    /// Validates: Requirement 9.8 - retry up to 3 times
    func testSendWithRetry_SuccessOnThirdAttempt() async {
        // Given: Email service fails twice then succeeds
        mockEmailService.failuresBeforeSuccess = 2
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should succeed with 3 attempts
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.attemptsMade, 3)
        XCTAssertNil(result.error)
        XCTAssertEqual(mockEmailService.sendEmailCallCount, 3)
    }
    
    /// Validates: Requirement 9.8 - retry up to 3 times (4 total attempts)
    func testSendWithRetry_SuccessOnFourthAttempt() async {
        // Given: Email service fails 3 times then succeeds
        mockEmailService.failuresBeforeSuccess = 3
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should succeed with 4 attempts (1 initial + 3 retries)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.attemptsMade, 4)
        XCTAssertNil(result.error)
        XCTAssertEqual(mockEmailService.sendEmailCallCount, 4)
    }
    
    // MARK: - Failed Delivery Tests
    
    /// Validates: Requirement 9.8, 9.9 - fail after all retries exhausted
    func testSendWithRetry_FailsAfterAllRetriesExhausted() async {
        // Given: Email service always fails
        mockEmailService.failuresBeforeSuccess = -1
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should fail with 4 attempts (1 initial + 3 retries)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.attemptsMade, 4)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(mockEmailService.sendEmailCallCount, 4)
        
        // Verify error is retriesExhausted
        if case .retriesExhausted = result.error! {
            // Expected
        } else {
            XCTFail("Expected retriesExhausted error, got \(String(describing: result.error))")
        }
    }
    
    // MARK: - Logging Tests
    
    /// Validates: Requirement 9.9 - log failures for monitoring
    func testSendWithRetry_LogsFailuresForMonitoring() async {
        // Given: Email service always fails
        mockEmailService.failuresBeforeSuccess = -1
        
        // When: Sending email
        _ = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should have logged all attempts and final failure
        let startedEntries = mockLogger.entries.filter { $0.type == .attemptStarted }
        let failedEntries = mockLogger.entries.filter { $0.type == .attemptFailed }
        let exhaustedEntries = mockLogger.entries.filter { $0.type == .retriesExhausted }
        
        XCTAssertEqual(startedEntries.count, 4) // 4 total attempts
        XCTAssertEqual(failedEntries.count, 4) // All 4 failed
        XCTAssertEqual(exhaustedEntries.count, 1) // Final exhausted log
    }
    
    /// Validates: Requirement 9.9 - log success
    func testSendWithRetry_LogsSuccess() async {
        // Given: Email service succeeds
        mockEmailService.failuresBeforeSuccess = 0
        
        // When: Sending email
        _ = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should have logged attempt start and success
        let startedEntries = mockLogger.entries.filter { $0.type == .attemptStarted }
        let succeededEntries = mockLogger.entries.filter { $0.type == .attemptSucceeded }
        
        XCTAssertEqual(startedEntries.count, 1)
        XCTAssertEqual(succeededEntries.count, 1)
    }
    
    // MARK: - Batch Processing Tests
    
    /// Validates: Requirement 9.9 - continue processing other users on failure
    func testSendBatchWithRetry_ContinuesOnIndividualFailure() async {
        // Given: Multiple users, one will fail
        let user1Settings = UserSettings(
            notificationEmail: "user1@example.com",
            emailNotificationsEnabled: true,
            scheduledAnalysisEnabled: true,
            updatedAt: Date()
        )
        let user2Settings = UserSettings(
            notificationEmail: "user2@example.com",
            emailNotificationsEnabled: true,
            scheduledAnalysisEnabled: true,
            updatedAt: Date()
        )
        let user3Settings = UserSettings(
            notificationEmail: "user3@example.com",
            emailNotificationsEnabled: true,
            scheduledAnalysisEnabled: true,
            updatedAt: Date()
        )
        
        let users: [(userId: String, settings: UserSettings, results: [AnalysisResult])] = [
            ("user1", user1Settings, []),
            ("user2", user2Settings, []),
            ("user3", user3Settings, [])
        ]
        
        // First user's emails fail, others succeed
        var callCount = 0
        let customEmailService = MockEmailServiceForRetry()
        customEmailService.failuresBeforeSuccess = 4 // First 4 calls fail (user1's 4 attempts)
        
        // When: Sending batch
        let results = await retryService.sendBatchWithRetry(
            using: customEmailService,
            userEmails: users,
            generateContent: { userId, _ in
                ("Subject for \(userId)", "<p>Body for \(userId)</p>")
            }
        )
        
        // Then: Should have 3 results (one per user)
        XCTAssertEqual(results.count, 3)
        
        // First user failed (all 4 attempts exhausted)
        let user1Result = results.first { $0.userId == "user1" }
        XCTAssertNotNil(user1Result)
        XCTAssertFalse(user1Result!.success)
        
        // Second and third users should have succeeded (after user1's 4 failures)
        let user2Result = results.first { $0.userId == "user2" }
        let user3Result = results.first { $0.userId == "user3" }
        
        XCTAssertNotNil(user2Result)
        XCTAssertNotNil(user3Result)
        XCTAssertTrue(user2Result!.success)
        XCTAssertTrue(user3Result!.success)
    }
    
    /// Validates: Requirement 9.9 - log batch summary
    func testSendBatchWithRetry_LogsBatchSummary() async {
        // Given: Multiple users
        let userSettings = UserSettings(
            notificationEmail: "user@example.com",
            emailNotificationsEnabled: true,
            scheduledAnalysisEnabled: true,
            updatedAt: Date()
        )
        
        let users: [(userId: String, settings: UserSettings, results: [AnalysisResult])] = [
            ("user1", userSettings, []),
            ("user2", userSettings, [])
        ]
        
        mockEmailService.failuresBeforeSuccess = 0
        
        // When: Sending batch
        _ = await retryService.sendBatchWithRetry(
            using: mockEmailService,
            userEmails: users,
            generateContent: { userId, _ in
                ("Subject", "<p>Body</p>")
            }
        )
        
        // Then: Should have logged batch summary
        XCTAssertEqual(mockLogger.batchSummaries.count, 1)
        XCTAssertEqual(mockLogger.batchSummaries[0].total, 2)
        XCTAssertEqual(mockLogger.batchSummaries[0].success, 2)
        XCTAssertEqual(mockLogger.batchSummaries[0].failure, 0)
    }
    
    // MARK: - Non-Retryable Error Tests
    
    func testSendWithRetry_DoesNotRetryValidationErrors() async {
        // Given: Email service fails with validation error
        mockEmailService.failuresBeforeSuccess = -1
        mockEmailService.errorToThrow = .invalidEmailFormat
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "invalid-email",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should fail immediately without retrying
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.attemptsMade, 1) // Only 1 attempt, no retries
        XCTAssertEqual(mockEmailService.sendEmailCallCount, 1)
    }
    
    // MARK: - Result Tracking Tests
    
    func testEmailRetryResult_TracksTimingInformation() async {
        // Given: Email service with small delay
        mockEmailService.failuresBeforeSuccess = 0
        mockEmailService.simulatedDelay = 0.01
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should track timing
        XCTAssertTrue(result.totalDuration >= 0)
        XCTAssertTrue(result.completedAt >= result.startedAt)
    }
    
    func testEmailRetryResult_TracksRecipientEmail() async {
        // Given: Email service succeeds
        mockEmailService.failuresBeforeSuccess = 0
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "specific@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "user123"
        )
        
        // Then: Should track recipient email
        XCTAssertEqual(result.recipientEmail, "specific@example.com")
    }
    
    func testEmailRetryResult_TracksUserId() async {
        // Given: Email service succeeds
        mockEmailService.failuresBeforeSuccess = 0
        
        // When: Sending email
        let result = await retryService.sendWithRetry(
            using: mockEmailService,
            to: "user@example.com",
            subject: "Test Subject",
            htmlBody: "<p>Test body</p>",
            userId: "specificUser456"
        )
        
        // Then: Should track user ID
        XCTAssertEqual(result.userId, "specificUser456")
    }
    
    // MARK: - Gating Tests
    
    func testSendAnalysisResultsWithRetry_FailsWhenEmailNotConfigured() async {
        // Given: User settings without email
        let userSettings = UserSettings(
            notificationEmail: nil,
            emailNotificationsEnabled: true,
            scheduledAnalysisEnabled: true,
            updatedAt: Date()
        )
        
        // When: Sending analysis results
        let result = await retryService.sendAnalysisResultsWithRetry(
            using: mockEmailService,
            results: [],
            userSettings: userSettings,
            htmlContent: "<p>Test</p>",
            subject: "Test",
            userId: "user123"
        )
        
        // Then: Should fail with gating error
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.attemptsMade, 0) // No attempts made
        
        if case .gatingFailed(let reason) = result.error! {
            XCTAssertTrue(reason.contains("No email"))
        } else {
            XCTFail("Expected gatingFailed error")
        }
    }
    
    func testSendAnalysisResultsWithRetry_FailsWhenNotificationsDisabled() async {
        // Given: User settings with notifications disabled
        let userSettings = UserSettings(
            notificationEmail: "user@example.com",
            emailNotificationsEnabled: false,
            scheduledAnalysisEnabled: true,
            updatedAt: Date()
        )
        
        // When: Sending analysis results
        let result = await retryService.sendAnalysisResultsWithRetry(
            using: mockEmailService,
            results: [],
            userSettings: userSettings,
            htmlContent: "<p>Test</p>",
            subject: "Test",
            userId: "user123"
        )
        
        // Then: Should fail with gating error
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.attemptsMade, 0) // No attempts made
        
        if case .gatingFailed(let reason) = result.error! {
            XCTAssertTrue(reason.contains("disabled"))
        } else {
            XCTFail("Expected gatingFailed error")
        }
    }
}
