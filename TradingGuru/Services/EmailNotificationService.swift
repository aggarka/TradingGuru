//
//  EmailNotificationService.swift
//  TradingGuru
//
//  Service for sending email notifications with analysis results.
//  Integrates with backend email provider (SendGrid/SES) via API.
//

import Foundation

// MARK: - Email Service Error

/// Errors that can occur during email operations.
/// Provides detailed error types for handling different failure scenarios.
enum EmailServiceError: Error, LocalizedError, Equatable {
    /// Email address is not configured
    case noEmailConfigured
    
    /// Email notifications are disabled
    case notificationsDisabled
    
    /// Invalid email address format
    case invalidEmailFormat
    
    /// Network error during email send
    case networkError(reason: String)
    
    /// Backend API error
    case apiError(statusCode: Int, message: String)
    
    /// Email delivery failed
    case deliveryFailed(reason: String)
    
    /// Timeout while sending email
    case timeout
    
    /// Unknown error
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noEmailConfigured:
            return "No email address configured for notifications."
        case .notificationsDisabled:
            return "Email notifications are disabled."
        case .invalidEmailFormat:
            return "The configured email address is invalid."
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .deliveryFailed(let reason):
            return "Email delivery failed: \(reason)"
        case .timeout:
            return "Email send request timed out."
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    /// User-friendly error message for display.
    var userMessage: String {
        switch self {
        case .noEmailConfigured:
            return "Please configure an email address in settings."
        case .notificationsDisabled:
            return "Enable email notifications in settings to receive results."
        case .invalidEmailFormat:
            return "Please enter a valid email address in settings."
        case .networkError:
            return "Network error. Please check your connection."
        case .apiError:
            return "Failed to send email. Please try again later."
        case .deliveryFailed:
            return "Email delivery failed. Please try again."
        case .timeout:
            return "Request timed out. Please try again."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
}

// MARK: - Email Service Protocol

/// Protocol defining the interface for email notification services.
///
/// This protocol abstracts the email sending functionality to allow
/// for different implementations (e.g., SendGrid, SES, mock for testing).
///
/// - Validates: Requirement 9.3 (Send email within 5 minutes of scheduled analysis)
/// - Validates: Requirement 9.7 (Gate sending on configured email address)
/// - Validates: Requirement 9.11 (Gate sending on emailNotificationsEnabled)
protocol EmailServiceProtocol {
    /// Sends an email with the specified content.
    ///
    /// - Parameters:
    ///   - to: The recipient email address
    ///   - subject: The email subject line
    ///   - htmlBody: The HTML content of the email
    /// - Throws: EmailServiceError if sending fails
    func sendEmail(to: String, subject: String, htmlBody: String) async throws
    
    /// Checks if email can be sent for the given user settings.
    ///
    /// Email can only be sent if:
    /// 1. `notificationEmail` is configured (non-nil, non-empty)
    /// 2. `emailNotificationsEnabled` is true
    ///
    /// - Parameter userSettings: The user's notification settings
    /// - Returns: true if email can be sent, false otherwise
    /// - Validates: Requirement 9.7 (Gate on configured email)
    /// - Validates: Requirement 9.11 (Gate on emailNotificationsEnabled)
    func canSendEmail(for userSettings: UserSettings) -> Bool
    
    /// Sends analysis results email if conditions are met.
    ///
    /// This is a convenience method that checks gating conditions
    /// and sends the email with formatted results content.
    ///
    /// - Parameters:
    ///   - results: The analysis results to include in the email
    ///   - userSettings: The user's notification settings
    ///   - htmlContent: Pre-formatted HTML content for the email body
    ///   - subject: The email subject line
    /// - Throws: EmailServiceError if gating fails or sending fails
    /// - Validates: Requirement 9.3 (Send within 5 minutes of completion)
    func sendAnalysisResults(
        results: [AnalysisResult],
        userSettings: UserSettings,
        htmlContent: String,
        subject: String
    ) async throws
}

// MARK: - Email Request Model

/// Request model for the backend email API.
struct EmailSendRequest: Codable {
    /// Recipient email address
    let to: String
    
    /// Email subject line
    let subject: String
    
    /// HTML body content
    let htmlBody: String
    
    /// Analysis metadata
    let metadata: EmailMetadata?
    
    /// Metadata about the analysis results
    struct EmailMetadata: Codable {
        let callCount: Int
        let putCount: Int
        let analysisTimestamp: Date
        let source: String
    }
}

/// Response model from the backend email API.
struct EmailSendResponse: Codable {
    /// Whether the email was accepted for delivery
    let success: Bool
    
    /// Message ID from the email provider
    let messageId: String?
    
    /// Error message if failed
    let error: String?
}

// MARK: - Email Notification Service

/// Service for sending email notifications with analysis results.
///
/// This service implements the `EmailServiceProtocol` and communicates
/// with the backend API to send emails via SendGrid or SES.
///
/// The service enforces gating logic:
/// - Email is only sent if `notificationEmail` is configured
/// - Email is only sent if `emailNotificationsEnabled` is true
///
/// - Validates: Requirement 9.3 (Send email within 5 minutes of scheduled analysis)
/// - Validates: Requirement 9.7 (Gate sending on configured email address)
/// - Validates: Requirement 9.11 (Gate sending on emailNotificationsEnabled)
final class EmailNotificationService: EmailServiceProtocol {
    
    // MARK: - Configuration
    
    /// Base URL for the backend email API.
    private let baseURL: URL
    
    /// URL session for network requests.
    private let session: URLSession
    
    /// Timeout interval for email requests (5 minutes to meet SLA).
    private let timeoutInterval: TimeInterval
    
    /// JSON encoder for request serialization.
    private let encoder: JSONEncoder
    
    /// JSON decoder for response deserialization.
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    /// Creates a new EmailNotificationService instance.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the backend email API
    ///   - session: The URL session to use for requests (defaults to shared)
    ///   - timeoutInterval: Request timeout in seconds (defaults to 60)
    init(
        baseURL: URL = URL(string: "https://api.tradingguru.app/v1/email")!,
        session: URLSession = .shared,
        timeoutInterval: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.session = session
        self.timeoutInterval = timeoutInterval
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - EmailServiceProtocol Implementation
    
    /// Checks if email can be sent for the given user settings.
    ///
    /// Implements the gating logic per Requirements 9.7 and 9.11:
    /// - Email address must be configured (non-nil, non-empty)
    /// - Email notifications must be enabled
    ///
    /// - Parameter userSettings: The user's notification settings
    /// - Returns: true if both conditions are met, false otherwise
    /// - Validates: Requirement 9.7 (Gate on configured email)
    /// - Validates: Requirement 9.11 (Gate on emailNotificationsEnabled)
    func canSendEmail(for userSettings: UserSettings) -> Bool {
        // Check if email address is configured (non-nil, non-empty)
        guard let email = userSettings.notificationEmail,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Check if email notifications are enabled
        guard userSettings.emailNotificationsEnabled else {
            return false
        }
        
        return true
    }
    
    /// Sends an email with the specified content.
    ///
    /// Makes an API call to the backend email service for delivery.
    ///
    /// - Parameters:
    ///   - to: The recipient email address
    ///   - subject: The email subject line
    ///   - htmlBody: The HTML content of the email
    /// - Throws: EmailServiceError if sending fails
    func sendEmail(to: String, subject: String, htmlBody: String) async throws {
        // Validate email format
        guard to.isValidEmail else {
            throw EmailServiceError.invalidEmailFormat
        }
        
        // Create request
        let request = EmailSendRequest(
            to: to,
            subject: subject,
            htmlBody: htmlBody,
            metadata: nil
        )
        
        try await performEmailRequest(request)
    }
    
    /// Sends analysis results email if conditions are met.
    ///
    /// Enforces gating logic before attempting to send:
    /// 1. Checks if email is configured
    /// 2. Checks if notifications are enabled
    /// 3. Validates email format
    /// 4. Sends the email via backend API
    ///
    /// - Parameters:
    ///   - results: The analysis results (used for metadata)
    ///   - userSettings: The user's notification settings
    ///   - htmlContent: Pre-formatted HTML content for the email body
    ///   - subject: The email subject line
    /// - Throws: EmailServiceError if gating fails or sending fails
    /// - Validates: Requirement 9.3 (Send within 5 minutes of completion)
    /// - Validates: Requirement 9.7 (Gate on configured email)
    /// - Validates: Requirement 9.11 (Gate on emailNotificationsEnabled)
    func sendAnalysisResults(
        results: [AnalysisResult],
        userSettings: UserSettings,
        htmlContent: String,
        subject: String
    ) async throws {
        // Gate 1: Check if email is configured
        guard let email = userSettings.notificationEmail,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmailServiceError.noEmailConfigured
        }
        
        // Gate 2: Check if notifications are enabled
        guard userSettings.emailNotificationsEnabled else {
            throw EmailServiceError.notificationsDisabled
        }
        
        // Validate email format
        guard email.isValidEmail else {
            throw EmailServiceError.invalidEmailFormat
        }
        
        // Calculate metadata
        let callCount = results.filter { $0.type == .call }.count
        let putCount = results.filter { $0.type == .put }.count
        let analysisTimestamp = results.first?.analyzedAt ?? Date()
        
        // Create request with metadata
        let request = EmailSendRequest(
            to: email,
            subject: subject,
            htmlBody: htmlContent,
            metadata: EmailSendRequest.EmailMetadata(
                callCount: callCount,
                putCount: putCount,
                analysisTimestamp: analysisTimestamp,
                source: "scheduled"
            )
        )
        
        try await performEmailRequest(request)
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual HTTP request to send the email.
    ///
    /// - Parameter emailRequest: The email request to send
    /// - Throws: EmailServiceError on failure
    private func performEmailRequest(_ emailRequest: EmailSendRequest) async throws {
        // Build URL request
        let url = baseURL.appendingPathComponent("send")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeoutInterval
        
        // Encode request body
        do {
            urlRequest.httpBody = try encoder.encode(emailRequest)
        } catch {
            throw EmailServiceError.unknown("Failed to encode request: \(error.localizedDescription)")
        }
        
        // Perform request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            if error.code == .timedOut {
                throw EmailServiceError.timeout
            }
            throw EmailServiceError.networkError(reason: error.localizedDescription)
        } catch {
            throw EmailServiceError.networkError(reason: error.localizedDescription)
        }
        
        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailServiceError.unknown("Invalid response type")
        }
        
        // Handle error status codes
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error response
            if let errorResponse = try? decoder.decode(EmailSendResponse.self, from: data),
               let errorMessage = errorResponse.error {
                throw EmailServiceError.apiError(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage
                )
            }
            throw EmailServiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: "Unknown API error"
            )
        }
        
        // Parse success response
        let emailResponse: EmailSendResponse
        do {
            emailResponse = try decoder.decode(EmailSendResponse.self, from: data)
        } catch {
            // If we got a 2xx status but can't parse response, consider it success
            return
        }
        
        // Check response success flag
        if !emailResponse.success {
            throw EmailServiceError.deliveryFailed(
                reason: emailResponse.error ?? "Email provider rejected the request"
            )
        }
    }
}

// MARK: - Email Gating Result

/// Result type for email gating check, providing detailed reason for failure.
enum EmailGatingResult: Equatable {
    /// Email can be sent
    case canSend
    
    /// Email cannot be sent - no email configured
    case noEmailConfigured
    
    /// Email cannot be sent - notifications disabled
    case notificationsDisabled
    
    /// Email cannot be sent - invalid email format
    case invalidEmailFormat
    
    /// Whether email can be sent
    var canSend: Bool {
        if case .canSend = self { return true }
        return false
    }
    
    /// User-friendly description of why email cannot be sent
    var reason: String? {
        switch self {
        case .canSend:
            return nil
        case .noEmailConfigured:
            return "No email address configured"
        case .notificationsDisabled:
            return "Email notifications are disabled"
        case .invalidEmailFormat:
            return "Email address format is invalid"
        }
    }
}

// MARK: - Email Notification Service Extension

extension EmailNotificationService {
    
    /// Checks email gating conditions and returns detailed result.
    ///
    /// Use this method when you need to know the specific reason
    /// why email cannot be sent.
    ///
    /// - Parameter userSettings: The user's notification settings
    /// - Returns: Detailed gating result
    /// - Validates: Requirement 9.7 (Gate on configured email)
    /// - Validates: Requirement 9.11 (Gate on emailNotificationsEnabled)
    func checkEmailGating(for userSettings: UserSettings) -> EmailGatingResult {
        // Check if email address is configured
        guard let email = userSettings.notificationEmail,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .noEmailConfigured
        }
        
        // Check if email notifications are enabled
        guard userSettings.emailNotificationsEnabled else {
            return .notificationsDisabled
        }
        
        // Check email format validity
        guard email.isValidEmail else {
            return .invalidEmailFormat
        }
        
        return .canSend
    }
}

// MARK: - Preview Support

#if DEBUG
/// Mock email service for SwiftUI previews and testing.
final class MockEmailNotificationService: EmailServiceProtocol {
    /// Whether send operations should fail
    var shouldFail = false
    
    /// The error to throw when shouldFail is true
    var errorToThrow: EmailServiceError = .networkError(reason: "Mock failure")
    
    /// Simulated delay for operations
    var simulatedDelay: TimeInterval = 0.1
    
    /// Record of sent emails for verification
    private(set) var sentEmails: [(to: String, subject: String, htmlBody: String)] = []
    
    func sendEmail(to: String, subject: String, htmlBody: String) async throws {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        if shouldFail {
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
        guard canSendEmail(for: userSettings) else {
            if userSettings.notificationEmail == nil || userSettings.notificationEmail?.isEmpty == true {
                throw EmailServiceError.noEmailConfigured
            }
            throw EmailServiceError.notificationsDisabled
        }
        
        try await sendEmail(
            to: userSettings.notificationEmail!,
            subject: subject,
            htmlBody: htmlContent
        )
    }
    
    /// Resets the mock state
    func reset() {
        shouldFail = false
        errorToThrow = .networkError(reason: "Mock failure")
        sentEmails = []
    }
}
#endif
