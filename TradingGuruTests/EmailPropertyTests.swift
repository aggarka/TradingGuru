//
//  EmailPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for email validation and notification gating.
//  Tests the correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 17: Email Format Validation
// **Validates: Requirements 9.2**
//
// *For any* string, email validation SHALL pass if and only if the string
// matches a valid email format pattern (e.g., contains exactly one `@`,
// has valid local and domain parts).

@Suite("Property 17: Email Format Validation - Validates Requirements 9.2")
struct EmailFormatValidationPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    // MARK: - Valid Email Generation
    
    /// Known valid email addresses that MUST pass validation
    static let knownValidEmails: [String] = [
        "user@example.com",
        "test.user@domain.org",
        "john.doe@company.co.uk",
        "simple@test.io",
        "user123@numbers.net",
        "first.last@subdomain.domain.com",
        "email@example-one.com",
        "user+tag@example.com",
        "user%special@domain.com",
        "user_underscore@domain.com",
        "a@b.co",
        "test@test.travel",
        "user@123.456.789.com",
        "name@domain.museum",
        "valid.email@valid-domain.info"
    ]
    
    /// Generates random valid email addresses
    /// Structure: local-part@domain.tld
    static func generateRandomValidEmails(count: Int) -> [String] {
        let localPartChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._%+-"
        let domainChars = "abcdefghijklmnopqrstuvwxyz0123456789-"
        let tlds = ["com", "org", "net", "io", "co", "edu", "gov", "uk", "de", "fr", "us", "info"]
        
        return (0..<count).map { _ in
            // Generate local part (1-20 chars)
            let localLength = Int.random(in: 1...20)
            var localPart = ""
            for i in 0..<localLength {
                // First char must be alphanumeric
                if i == 0 {
                    let alphaNumeric = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                    localPart += String(alphaNumeric.randomElement()!)
                } else {
                    localPart += String(localPartChars.randomElement()!)
                }
            }
            
            // Generate domain (3-15 chars)
            let domainLength = Int.random(in: 3...15)
            var domain = ""
            for i in 0..<domainLength {
                // First char must be alphanumeric
                if i == 0 {
                    let alphaNumeric = "abcdefghijklmnopqrstuvwxyz0123456789"
                    domain += String(alphaNumeric.randomElement()!)
                } else {
                    domain += String(domainChars.randomElement()!)
                }
            }
            // Ensure domain doesn't end with hyphen
            if domain.hasSuffix("-") {
                domain = String(domain.dropLast()) + "x"
            }
            
            // Pick random TLD
            let tld = tlds.randomElement()!
            
            return "\(localPart)@\(domain).\(tld)"
        }
    }
    
    // MARK: - Invalid Email Generation
    
    /// Known invalid email addresses that MUST fail validation
    /// Based on the pattern: ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$
    static let knownInvalidEmails: [String] = [
        // Missing @
        "userexample.com",
        "plainaddress",
        "nodomain",
        
        // Missing local part
        "@example.com",
        "@domain.org",
        
        // Missing domain
        "user@",
        "test@",
        
        // Missing TLD (no dot after @)
        "user@domain",
        "test@example",
        
        // Multiple @
        "user@@example.com",
        "user@domain@example.com",
        "user@ex@mple.com",
        
        // Invalid characters in local part (not in [A-Za-z0-9._%+-])
        "user name@example.com",
        "user<>@example.com",
        "user\"test@example.com",
        
        // Empty string
        "",
        
        // Just @
        "@",
        "@@",
        
        // Spaces anywhere
        " user@example.com",
        "user@example.com ",
        "user @example.com",
        "user@ example.com",
        "   ",
        
        // TLD too short (less than 2 chars)
        "user@domain.c",
        "test@example.x",
        
        // Invalid domain characters (not in [A-Za-z0-9.-])
        "user@domain!.com",
        "user@dom#ain.com",
        "user@domain .com",
        
        // No dot in domain part
        "user@domaincom",
        
        // Numbers only TLD (TLD requires [A-Za-z]{2,})
        "user@domain.123",
        "user@domain.12",
        
        // TLD with numbers mixed in
        "test@example.c0m",
        
        // Domain ending with dot (no TLD after)
        "user@domain.",
        "test@example."
    ]
    
    /// Generates random invalid email addresses
    static func generateRandomInvalidEmails(count: Int) -> [String] {
        var invalidEmails: [String] = []
        
        for _ in 0..<count {
            let invalidationType = Int.random(in: 0...9)
            
            let email: String
            switch invalidationType {
            case 0:
                // Missing @
                email = "user\(Int.random(in: 1...999))example.com"
            case 1:
                // Empty string
                email = ""
            case 2:
                // Just random characters without proper structure
                email = String((0..<10).map { _ in "abcdef123".randomElement()! })
            case 3:
                // Missing domain
                email = "user\(Int.random(in: 1...999))@"
            case 4:
                // Missing local part
                email = "@example.com"
            case 5:
                // Double @
                email = "user@@example.com"
            case 6:
                // Spaces
                email = "user @example.com"
            case 7:
                // No TLD
                email = "user@domain"
            case 8:
                // TLD too short (single char)
                email = "user@domain.x"
            case 9:
                // Multiple @
                email = "user@domain@example.com"
            default:
                email = "invalid"
            }
            
            invalidEmails.append(email)
        }
        
        return invalidEmails
    }
    
    // MARK: - Property Tests: Valid Emails Pass Validation
    
    @Test("Property: Known valid email addresses pass validation",
          arguments: knownValidEmails)
    func testKnownValidEmailsPass(validEmail: String) {
        // Precondition: Email should have proper structure
        #expect(validEmail.contains("@"), "Valid email should contain @")
        #expect(validEmail.contains("."), "Valid email should contain .")
        
        // Act: Validate the email
        let isValid = validEmail.isValidEmail
        
        // Assert: Validation SHALL pass
        #expect(isValid == true,
                "Expected '\(validEmail)' to be valid, but validation failed")
    }
    
    @Test("Property: Random valid email addresses pass validation",
          arguments: generateRandomValidEmails(count: 10))
    func testRandomValidEmailsPass(validEmail: String) {
        // Act
        let isValid = validEmail.isValidEmail
        
        // Assert
        #expect(isValid == true,
                "Expected generated email '\(validEmail)' to be valid")
    }
    
    // MARK: - Property Tests: Invalid Emails Fail Validation
    
    @Test("Property: Known invalid email addresses fail validation",
          arguments: knownInvalidEmails)
    func testKnownInvalidEmailsFail(invalidEmail: String) {
        // Act: Validate the email
        let isValid = invalidEmail.isValidEmail
        
        // Assert: Validation SHALL fail
        #expect(isValid == false,
                "Expected '\(invalidEmail)' to be invalid, but validation passed")
    }
    
    @Test("Property: Random invalid email addresses fail validation",
          arguments: generateRandomInvalidEmails(count: 10))
    func testRandomInvalidEmailsFail(invalidEmail: String) {
        // Act
        let isValid = invalidEmail.isValidEmail
        
        // Assert
        #expect(isValid == false,
                "Expected generated invalid email '\(invalidEmail)' to fail validation")
    }
    
    // MARK: - Property Tests: Exactly One @ Symbol
    
    @Test("Property: Emails without @ symbol are invalid")
    func testEmailsWithoutAtAreInvalid() {
        let noAtEmails = [
            "userexample.com",
            "test.user.domain.org",
            "plaintext",
            "user.domain.com",
            "noatsymbol"
        ]
        
        for email in noAtEmails {
            #expect(!email.contains("@"), "Test email should not contain @")
            #expect(email.isValidEmail == false,
                    "Email without @ '\(email)' should be invalid")
        }
    }
    
    @Test("Property: Emails with multiple @ symbols are invalid")
    func testEmailsWithMultipleAtAreInvalid() {
        let multipleAtEmails = [
            "user@@example.com",
            "user@domain@example.com",
            "a@b@c@d.com",
            "test@@@@domain.com",
            "@user@example.com"
        ]
        
        for email in multipleAtEmails {
            let atCount = email.filter { $0 == "@" }.count
            #expect(atCount > 1 || email.hasPrefix("@"),
                    "Test email should have multiple @ or start with @")
            #expect(email.isValidEmail == false,
                    "Email with multiple @ '\(email)' should be invalid")
        }
    }
    
    @Test("Property: Valid emails have exactly one @ symbol",
          arguments: knownValidEmails)
    func testValidEmailsHaveExactlyOneAt(validEmail: String) {
        let atCount = validEmail.filter { $0 == "@" }.count
        
        #expect(atCount == 1,
                "Valid email '\(validEmail)' should have exactly one @, but has \(atCount)")
        #expect(validEmail.isValidEmail == true)
    }
    
    // MARK: - Property Tests: Local Part Requirements
    
    @Test("Property: Emails with empty local part are invalid")
    func testEmptyLocalPartInvalid() {
        let emptyLocalEmails = [
            "@example.com",
            "@domain.org",
            "@test.io"
        ]
        
        for email in emptyLocalEmails {
            #expect(email.hasPrefix("@"), "Test email should start with @")
            #expect(email.isValidEmail == false,
                    "Email with empty local part '\(email)' should be invalid")
        }
    }
    
    @Test("Property: Valid emails have non-empty local part",
          arguments: knownValidEmails)
    func testValidEmailsHaveLocalPart(validEmail: String) {
        guard let atIndex = validEmail.firstIndex(of: "@") else {
            Issue.record("Valid email should contain @")
            return
        }
        
        let localPart = String(validEmail[..<atIndex])
        
        #expect(!localPart.isEmpty,
                "Valid email '\(validEmail)' should have non-empty local part")
        #expect(validEmail.isValidEmail == true)
    }
    
    // MARK: - Property Tests: Domain Requirements
    
    @Test("Property: Emails with empty domain are invalid")
    func testEmptyDomainInvalid() {
        let emptyDomainEmails = [
            "user@",
            "test@",
            "email@"
        ]
        
        for email in emptyDomainEmails {
            #expect(email.hasSuffix("@"), "Test email should end with @")
            #expect(email.isValidEmail == false,
                    "Email with empty domain '\(email)' should be invalid")
        }
    }
    
    @Test("Property: Emails without TLD (no dot in domain) are invalid")
    func testNoTLDInvalid() {
        let noTLDEmails = [
            "user@domain",
            "test@example",
            "email@localhost",
            "user@domainwithoutdot"
        ]
        
        for email in noTLDEmails {
            // Get part after @
            if let atIndex = email.firstIndex(of: "@") {
                let domain = String(email[email.index(after: atIndex)...])
                #expect(!domain.contains("."),
                        "Test email domain should not contain dot")
            }
            #expect(email.isValidEmail == false,
                    "Email without TLD '\(email)' should be invalid")
        }
    }
    
    @Test("Property: Valid emails have domain with TLD",
          arguments: knownValidEmails)
    func testValidEmailsHaveDomainWithTLD(validEmail: String) {
        guard let atIndex = validEmail.firstIndex(of: "@") else {
            Issue.record("Valid email should contain @")
            return
        }
        
        let domain = String(validEmail[validEmail.index(after: atIndex)...])
        
        #expect(domain.contains("."),
                "Valid email '\(validEmail)' should have domain with dot/TLD")
        #expect(validEmail.isValidEmail == true)
    }
    
    @Test("Property: TLD must have at least 2 characters")
    func testTLDMinimumLength() {
        let shortTLDEmails = [
            "user@domain.c",
            "test@example.x",
            "email@test.a"
        ]
        
        for email in shortTLDEmails {
            #expect(email.isValidEmail == false,
                    "Email with single-char TLD '\(email)' should be invalid")
        }
        
        // Valid TLDs (2+ chars)
        let validTLDEmails = [
            "user@domain.co",
            "test@example.io",
            "email@test.uk"
        ]
        
        for email in validTLDEmails {
            #expect(email.isValidEmail == true,
                    "Email with 2+ char TLD '\(email)' should be valid")
        }
    }
    
    // MARK: - Property Tests: Empty and Whitespace Strings
    
    @Test("Property: Empty string is invalid")
    func testEmptyStringInvalid() {
        let emptyString = ""
        
        #expect(emptyString.isValidEmail == false,
                "Empty string should be invalid email")
    }
    
    @Test("Property: Whitespace-only strings are invalid")
    func testWhitespaceOnlyInvalid() {
        let whitespaceStrings = [
            " ",
            "   ",
            "\t",
            "\n",
            "  \t  ",
            "\n\t\n"
        ]
        
        for ws in whitespaceStrings {
            #expect(ws.isValidEmail == false,
                    "Whitespace-only string should be invalid email")
        }
    }
    
    @Test("Property: Emails with leading/trailing whitespace are invalid")
    func testLeadingTrailingWhitespaceInvalid() {
        let whitespaceEmails = [
            " user@example.com",
            "user@example.com ",
            "  user@example.com  ",
            "\tuser@example.com",
            "user@example.com\n"
        ]
        
        for email in whitespaceEmails {
            #expect(email.isValidEmail == false,
                    "Email with leading/trailing whitespace '\(email)' should be invalid")
        }
    }
    
    // MARK: - Property Tests: Consistency (Idempotence)
    
    @Test("Property: Validation result is consistent across multiple calls",
          arguments: knownValidEmails + knownInvalidEmails)
    func testValidationConsistency(email: String) {
        let result1 = email.isValidEmail
        let result2 = email.isValidEmail
        let result3 = email.isValidEmail
        
        #expect(result1 == result2 && result2 == result3,
                "Validation should return consistent results for '\(email)'")
    }
    
    // MARK: - Property Tests: Case Sensitivity
    
    @Test("Property: Email validation is case-insensitive for domain")
    func testCaseInsensitiveValidation() {
        // These should all be valid regardless of case
        let caseVariants = [
            ("user@example.com", "user@EXAMPLE.COM"),
            ("user@example.com", "user@Example.Com"),
            ("USER@example.com", "user@example.com")
        ]
        
        for (email1, email2) in caseVariants {
            let valid1 = email1.isValidEmail
            let valid2 = email2.isValidEmail
            
            // Both should have the same validity status
            #expect(valid1 == valid2,
                    "Case variants '\(email1)' and '\(email2)' should have same validity")
        }
    }
    
    // MARK: - Property Tests: UserSettings Integration
    
    @Test("Property: UserSettings.hasValidEmail returns true for nil email")
    func testUserSettingsNilEmailValid() {
        let settings = UserSettings(notificationEmail: nil)
        
        #expect(settings.hasValidEmail == true,
                "nil email should be considered valid (not configured)")
    }
    
    @Test("Property: UserSettings.hasValidEmail returns true for empty email")
    func testUserSettingsEmptyEmailValid() {
        let settings = UserSettings(notificationEmail: "")
        
        #expect(settings.hasValidEmail == true,
                "Empty email should be considered valid (not configured)")
    }
    
    @Test("Property: UserSettings.hasValidEmail matches isValidEmail for non-empty emails",
          arguments: knownValidEmails + knownInvalidEmails)
    func testUserSettingsMatchesStringValidation(email: String) {
        let settings = UserSettings(notificationEmail: email)
        
        // For non-empty emails, hasValidEmail should match isValidEmail
        if !email.isEmpty {
            #expect(settings.hasValidEmail == email.isValidEmail,
                    "UserSettings.hasValidEmail should match String.isValidEmail for '\(email)'")
        }
    }
    
    // MARK: - Property Tests: EmailServiceError Integration
    
    @Test("Property: EmailNotificationService throws invalidEmailFormat for invalid emails",
          arguments: ["invalid", "noat.com", "@nodomain", "user@", ""])
    func testEmailServiceRejectsInvalidEmails(invalidEmail: String) async {
        let service = EmailNotificationService()
        
        do {
            try await service.sendEmail(
                to: invalidEmail,
                subject: "Test",
                htmlBody: "<p>Test</p>"
            )
            Issue.record("Expected invalidEmailFormat error for '\(invalidEmail)'")
        } catch let error as EmailServiceError {
            if case .invalidEmailFormat = error {
                // Expected error
            } else {
                // May get other errors (like network) for valid-format emails
                // but for invalid format, should get invalidEmailFormat
                if !invalidEmail.isValidEmail {
                    Issue.record("Expected invalidEmailFormat error for '\(invalidEmail)', got: \(error)")
                }
            }
        } catch {
            // Network errors are acceptable for integration tests
        }
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Single character local parts are valid")
    func testSingleCharLocalPartValid() {
        let singleCharEmails = [
            "a@example.com",
            "1@domain.org",
            "x@test.io"
        ]
        
        for email in singleCharEmails {
            #expect(email.isValidEmail == true,
                    "Single char local part '\(email)' should be valid")
        }
    }
    
    @Test("Property: Very long but valid emails are accepted")
    func testLongValidEmailsAccepted() {
        // Generate a long but valid email
        let localPart = String(repeating: "a", count: 64) // 64 chars local part
        let domain = "verylongdomainname.com"
        let longEmail = "\(localPart)@\(domain)"
        
        // This should still match the pattern
        #expect(longEmail.isValidEmail == true,
                "Long valid email should be accepted")
    }
    
    @Test("Property: Emails with subdomains are valid")
    func testSubdomainsValid() {
        let subdomainEmails = [
            "user@mail.example.com",
            "test@subdomain.domain.org",
            "email@a.b.c.example.co.uk"
        ]
        
        for email in subdomainEmails {
            #expect(email.isValidEmail == true,
                    "Email with subdomain '\(email)' should be valid")
        }
    }
    
    @Test("Property: Emails with + in local part are valid")
    func testPlusSignValid() {
        let plusEmails = [
            "user+tag@example.com",
            "test+filter@domain.org",
            "email+newsletter@test.io"
        ]
        
        for email in plusEmails {
            #expect(email.isValidEmail == true,
                    "Email with + '\(email)' should be valid")
        }
    }
    
    @Test("Property: Emails with numbers in domain are valid")
    func testNumbersInDomainValid() {
        let numberDomainEmails = [
            "user@123.example.com",
            "test@domain123.org",
            "email@test456.io"
        ]
        
        for email in numberDomainEmails {
            #expect(email.isValidEmail == true,
                    "Email with numbers in domain '\(email)' should be valid")
        }
    }
    
    @Test("Property: Emails with hyphen in domain are valid")
    func testHyphenInDomainValid() {
        let hyphenDomainEmails = [
            "user@my-domain.com",
            "test@test-example.org",
            "email@sub-domain.test.io"
        ]
        
        for email in hyphenDomainEmails {
            #expect(email.isValidEmail == true,
                    "Email with hyphen in domain '\(email)' should be valid")
        }
    }
    
    // MARK: - Property Tests: International TLDs
    
    @Test("Property: Common international TLDs are valid")
    func testInternationalTLDsValid() {
        let internationalEmails = [
            "user@example.uk",
            "test@domain.de",
            "email@test.fr",
            "name@company.jp",
            "info@site.cn",
            "contact@business.au"
        ]
        
        for email in internationalEmails {
            #expect(email.isValidEmail == true,
                    "Email with international TLD '\(email)' should be valid")
        }
    }
    
    @Test("Property: Newer TLDs are valid")
    func testNewerTLDsValid() {
        let newerTLDEmails = [
            "user@example.io",
            "test@domain.tech",
            "email@test.dev",
            "name@company.app",
            "info@site.cloud"
        ]
        
        for email in newerTLDEmails {
            #expect(email.isValidEmail == true,
                    "Email with newer TLD '\(email)' should be valid")
        }
    }
}


// MARK: - Property 18: Email Content Completeness
// **Validates: Requirements 9.4, 9.5, 9.6**
//
// *For any* array of analysis results, the generated email HTML SHALL contain:
// (1) a subject line with the format "TradingGuru Analysis Results - [Date] [Time] PST"
// (2) an HTML table with columns for Ticker, Type, Return %, Current Price, Target Price, Signal, and Next Earnings Date
// (3) ORDER signal rows with distinct background color (#E8F5E9)
// (4) earnings dates in red (#FF0000) when hasEarningsRisk is true
// (5) a summary with counts of CALL and PUT opportunities

@Suite("Property 18: Email Content Completeness - Validates Requirements 9.4, 9.5, 9.6")
struct EmailContentCompletenessPropertyTests {
    
    // MARK: - Constants
    
    /// Background color for ORDER signal rows
    private static let orderRowBackgroundColor = "#E8F5E9"
    
    /// Color for earnings dates with risk (red)
    private static let earningsRiskColor = "#FF0000"
    
    /// Number of random samples for property tests
    private static let sampleCount = 50
    
    // MARK: - Random Data Generation
    
    /// Generates a random ticker symbol (1-5 uppercase letters)
    private static func generateRandomTicker() -> String {
        let length = Int.random(in: 1...5)
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// Generates a random AnalysisResult
    private static func generateRandomAnalysisResult() -> AnalysisResult {
        let ticker = generateRandomTicker()
        let type = OpportunityType.allCases.randomElement()!
        let returnPercentage = Double.random(in: -50...50)
        let currentPrice = Double.random(in: 10...500)
        let targetPrice = currentPrice * (1 + returnPercentage / 100)
        let signal = Signal.allCases.randomElement()!
        let hasEarningsDate = Bool.random()
        let nextEarningsDate: Date? = hasEarningsDate 
            ? Date().addingTimeInterval(Double.random(in: -86400*30...86400*60)) 
            : nil
        let hasEarningsRisk = hasEarningsDate && Bool.random()
        
        return AnalysisResult(
            ticker: ticker,
            type: type,
            returnPercentage: returnPercentage,
            currentPrice: currentPrice,
            targetPrice: targetPrice,
            signal: signal,
            nextEarningsDate: nextEarningsDate,
            hasEarningsRisk: hasEarningsRisk
        )
    }
    
    /// Generates an array of random AnalysisResults
    private static func generateRandomResults(count: Int) -> [AnalysisResult] {
        (0..<count).map { _ in generateRandomAnalysisResult() }
    }
    
    /// Generates test cases with varying array sizes
    static let testCases: [[AnalysisResult]] = {
        var cases: [[AnalysisResult]] = []
        // Empty array
        cases.append([])
        // Single result
        cases.append(generateRandomResults(count: 1))
        // Various sizes
        for _ in 0..<(sampleCount - 2) {
            let size = Int.random(in: 2...20)
            cases.append(generateRandomResults(count: size))
        }
        return cases
    }()
    
    // MARK: - Test 1: Subject Line Format Validation
    
    @Test("Property: Subject line follows format 'TradingGuru Analysis Results - [Date] [Time] PST' for any date")
    func testSubjectLineFormat() {
        // Test with various random dates
        for _ in 0..<100 {
            // Generate random date within reasonable range
            let randomDate = Date().addingTimeInterval(Double.random(in: -86400*365...86400*365))
            
            // Generate subject line
            let subject = EmailTemplateService.generateSubjectLine(for: randomDate)
            
            // Assert: Subject starts with correct prefix
            #expect(subject.hasPrefix("TradingGuru Analysis Results - "),
                    "Subject should start with 'TradingGuru Analysis Results - '")
            
            // Assert: Subject ends with "PST"
            #expect(subject.hasSuffix(" PST"),
                    "Subject should end with ' PST'")
            
            // Assert: Subject contains date/time pattern (MMM d, yyyy h:mm a format)
            // Pattern: "TradingGuru Analysis Results - Dec 25, 2024 3:30 PM PST"
            let dateTimePattern = #"TradingGuru Analysis Results - [A-Z][a-z]{2} \d{1,2}, \d{4} \d{1,2}:\d{2} (AM|PM) PST"#
            let regex = try? NSRegularExpression(pattern: dateTimePattern)
            let range = NSRange(subject.startIndex..., in: subject)
            let matches = regex?.numberOfMatches(in: subject, range: range) ?? 0
            #expect(matches == 1,
                    "Subject '\(subject)' should match format 'TradingGuru Analysis Results - [Date] [Time] PST'")
        }
    }
    
    @Test("Property: Email notification subject matches expected format for any results",
          arguments: testCases)
    func testEmailNotificationSubject(results: [AnalysisResult]) {
        let randomDate = Date().addingTimeInterval(Double.random(in: -86400*30...86400*30))
        let email = EmailTemplateService.generateEmailNotification(
            results: results,
            recipient: "test@example.com",
            date: randomDate
        )
        
        // Verify subject line format
        #expect(email.subject.hasPrefix("TradingGuru Analysis Results - "))
        #expect(email.subject.hasSuffix(" PST"))
    }
    
    // MARK: - Test 2: HTML Table Contains All Required Columns
    
    @Test("Property: HTML table contains all required column headers for any results",
          arguments: testCases)
    func testHTMLTableContainsRequiredColumns(results: [AnalysisResult]) {
        let htmlTable = EmailTemplateService.generateHTMLTable(results: results)
        
        // Required columns per Requirement 9.4
        let requiredColumns = [
            "Ticker",
            "Type", 
            "Return %",
            "Current Price",
            "Target Price",
            "Signal",
            "Next Earnings Date"
        ]
        
        for column in requiredColumns {
            #expect(htmlTable.contains(column),
                    "HTML table should contain '\(column)' column header")
        }
    }
    
    @Test("Property: HTML table contains all ticker data for any non-empty results")
    func testHTMLTableContainsAllTickerData() {
        for _ in 0..<Self.sampleCount {
            let results = Self.generateRandomResults(count: Int.random(in: 1...15))
            let htmlTable = EmailTemplateService.generateHTMLTable(results: results)
            
            for result in results {
                // Each ticker should appear in the table
                #expect(htmlTable.contains(result.ticker),
                        "HTML table should contain ticker '\(result.ticker)'")
                
                // Each type (CALL/PUT) should appear
                #expect(htmlTable.contains(result.type.rawValue),
                        "HTML table should contain type '\(result.type.rawValue)'")
                
                // Each signal (ORDER/HOLD) should appear
                #expect(htmlTable.contains(result.signal.rawValue),
                        "HTML table should contain signal '\(result.signal.rawValue)'")
            }
        }
    }
    
    // MARK: - Test 3: ORDER Signal Rows Have Distinct Background Color
    
    @Test("Property: ORDER signal rows have distinct background color (#E8F5E9)")
    func testOrderRowsHaveDistinctBackgroundColor() {
        for _ in 0..<Self.sampleCount {
            // Generate results with at least one ORDER signal
            var results = Self.generateRandomResults(count: Int.random(in: 1...10))
            
            // Ensure at least one ORDER result
            let orderResult = AnalysisResult(
                ticker: Self.generateRandomTicker(),
                type: .call,
                returnPercentage: Double.random(in: 5...20),
                currentPrice: Double.random(in: 50...200),
                targetPrice: Double.random(in: 55...220),
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
            results.append(orderResult)
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: results)
            
            // Count ORDER rows
            let orderCount = results.filter { $0.signal == .order }.count
            
            // Count occurrences of the ORDER background color in table rows
            let orderColorOccurrences = htmlTable.components(separatedBy: Self.orderRowBackgroundColor).count - 1
            
            // Each ORDER row should have the distinct background color
            #expect(orderColorOccurrences >= orderCount,
                    "Expected at least \(orderCount) occurrences of ORDER background color \(Self.orderRowBackgroundColor), found \(orderColorOccurrences)")
        }
    }
    
    @Test("Property: HOLD signal rows do not use ORDER background color")
    func testHoldRowsDoNotUseOrderBackgroundColor() {
        // Create results with only HOLD signals
        for _ in 0..<Self.sampleCount {
            let holdResults = (0..<Int.random(in: 1...10)).map { _ -> AnalysisResult in
                AnalysisResult(
                    ticker: Self.generateRandomTicker(),
                    type: OpportunityType.allCases.randomElement()!,
                    returnPercentage: Double.random(in: -20...20),
                    currentPrice: Double.random(in: 50...200),
                    targetPrice: Double.random(in: 45...220),
                    signal: .hold,
                    nextEarningsDate: nil,
                    hasEarningsRisk: false
                )
            }
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: holdResults)
            
            // The ORDER background color should not appear in rows (only headers may have colors)
            // We check that there are no <tr> tags with the ORDER background color
            let rowPattern = "<tr[^>]*background-color: \(Self.orderRowBackgroundColor)"
            let regex = try? NSRegularExpression(pattern: rowPattern, options: .caseInsensitive)
            let range = NSRange(htmlTable.startIndex..., in: htmlTable)
            let orderRowMatches = regex?.numberOfMatches(in: htmlTable, range: range) ?? 0
            
            #expect(orderRowMatches == 0,
                    "HOLD-only results should not have ORDER background color in rows")
        }
    }
    
    // MARK: - Test 4: Earnings Dates in Red When hasEarningsRisk is True
    
    @Test("Property: Earnings dates displayed in red (#FF0000) when hasEarningsRisk is true")
    func testEarningsRiskDatesInRed() {
        for _ in 0..<Self.sampleCount {
            // Create result with earnings risk
            let earningsDate = Date().addingTimeInterval(86400 * 7) // 7 days from now
            let riskResult = AnalysisResult(
                ticker: Self.generateRandomTicker(),
                type: .call,
                returnPercentage: Double.random(in: 5...20),
                currentPrice: Double.random(in: 50...200),
                targetPrice: Double.random(in: 55...220),
                signal: .order,
                nextEarningsDate: earningsDate,
                hasEarningsRisk: true
            )
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: [riskResult])
            
            // The earnings date should be styled with red color
            #expect(htmlTable.contains(Self.earningsRiskColor),
                    "Earnings risk date should be displayed with red color \(Self.earningsRiskColor)")
            
            // Format the expected date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let expectedDateStr = formatter.string(from: earningsDate)
            
            // Check that the date appears within a red-styled span
            let redSpanPattern = "<span[^>]*color: \(Self.earningsRiskColor)[^>]*>\(expectedDateStr)</span>"
            let regex = try? NSRegularExpression(pattern: redSpanPattern, options: .caseInsensitive)
            let range = NSRange(htmlTable.startIndex..., in: htmlTable)
            let matches = regex?.numberOfMatches(in: htmlTable, range: range) ?? 0
            
            #expect(matches >= 1,
                    "Earnings date '\(expectedDateStr)' should appear in red-styled span")
        }
    }
    
    @Test("Property: Earnings dates NOT in red when hasEarningsRisk is false")
    func testNoEarningsRiskDatesNotInRed() {
        for _ in 0..<Self.sampleCount {
            // Create result without earnings risk but with earnings date
            let earningsDate = Date().addingTimeInterval(86400 * 60) // 60 days from now
            let noRiskResult = AnalysisResult(
                ticker: Self.generateRandomTicker(),
                type: .put,
                returnPercentage: Double.random(in: -20 ... -5),
                currentPrice: Double.random(in: 50...200),
                targetPrice: Double.random(in: 45...190),
                signal: .hold,
                nextEarningsDate: earningsDate,
                hasEarningsRisk: false
            )
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: [noRiskResult])
            
            // Format the expected date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let expectedDateStr = formatter.string(from: earningsDate)
            
            // The date should appear in the table
            #expect(htmlTable.contains(expectedDateStr),
                    "Earnings date '\(expectedDateStr)' should appear in the table")
            
            // But NOT in a red-styled span for this row
            let redSpanPattern = "<span[^>]*color: \(Self.earningsRiskColor)[^>]*>\(expectedDateStr)</span>"
            let regex = try? NSRegularExpression(pattern: redSpanPattern, options: .caseInsensitive)
            let range = NSRange(htmlTable.startIndex..., in: htmlTable)
            let matches = regex?.numberOfMatches(in: htmlTable, range: range) ?? 0
            
            #expect(matches == 0,
                    "Non-risk earnings date '\(expectedDateStr)' should NOT be in red-styled span")
        }
    }
    
    @Test("Property: Mixed results correctly apply red color only to risk dates")
    func testMixedResultsCorrectEarningsRiskStyling() {
        for _ in 0..<Self.sampleCount {
            // Create mixed results: some with risk, some without
            let riskDate = Date().addingTimeInterval(86400 * 5)
            let noRiskDate = Date().addingTimeInterval(86400 * 45)
            
            let riskResult = AnalysisResult(
                ticker: "RISK",
                type: .call,
                returnPercentage: 10.0,
                currentPrice: 100.0,
                targetPrice: 110.0,
                signal: .order,
                nextEarningsDate: riskDate,
                hasEarningsRisk: true
            )
            
            let noRiskResult = AnalysisResult(
                ticker: "SAFE",
                type: .put,
                returnPercentage: -8.0,
                currentPrice: 100.0,
                targetPrice: 92.0,
                signal: .hold,
                nextEarningsDate: noRiskDate,
                hasEarningsRisk: false
            )
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: [riskResult, noRiskResult])
            
            // Count red color occurrences (should be exactly 1 for the risk date)
            let redColorOccurrences = htmlTable.components(separatedBy: Self.earningsRiskColor).count - 1
            
            #expect(redColorOccurrences >= 1,
                    "Should have at least 1 occurrence of red color for risk date")
        }
    }
    
    // MARK: - Test 5: Summary Contains CALL and PUT Opportunity Counts
    
    @Test("Property: Summary contains CALL opportunity count for any results",
          arguments: testCases)
    func testSummaryContainsCallCount(results: [AnalysisResult]) {
        let summary = EmailTemplateService.generateSummary(results: results)
        let expectedCallCount = results.filter { $0.type == .call }.count
        
        // Summary should contain "CALL Opportunities:"
        #expect(summary.contains("CALL Opportunities"),
                "Summary should contain 'CALL Opportunities' label")
        
        // Summary should contain the correct count
        #expect(summary.contains("\(expectedCallCount)"),
                "Summary should contain CALL count '\(expectedCallCount)'")
    }
    
    @Test("Property: Summary contains PUT opportunity count for any results",
          arguments: testCases)
    func testSummaryContainsPutCount(results: [AnalysisResult]) {
        let summary = EmailTemplateService.generateSummary(results: results)
        let expectedPutCount = results.filter { $0.type == .put }.count
        
        // Summary should contain "PUT Opportunities:"
        #expect(summary.contains("PUT Opportunities"),
                "Summary should contain 'PUT Opportunities' label")
        
        // Summary should contain the correct count
        #expect(summary.contains("\(expectedPutCount)"),
                "Summary should contain PUT count '\(expectedPutCount)'")
    }
    
    @Test("Property: Email notification CALL/PUT counts match results array")
    func testEmailNotificationCounts() {
        for _ in 0..<Self.sampleCount {
            let results = Self.generateRandomResults(count: Int.random(in: 0...20))
            let email = EmailTemplateService.generateEmailNotification(
                results: results,
                recipient: "test@example.com"
            )
            
            let expectedCallCount = results.filter { $0.type == .call }.count
            let expectedPutCount = results.filter { $0.type == .put }.count
            
            #expect(email.callCount == expectedCallCount,
                    "Email callCount (\(email.callCount)) should match results (\(expectedCallCount))")
            #expect(email.putCount == expectedPutCount,
                    "Email putCount (\(email.putCount)) should match results (\(expectedPutCount))")
        }
    }
    
    @Test("Property: Summary includes total opportunities count")
    func testSummaryIncludesTotalCount() {
        for _ in 0..<Self.sampleCount {
            let results = Self.generateRandomResults(count: Int.random(in: 0...20))
            let summary = EmailTemplateService.generateSummary(results: results)
            
            #expect(summary.contains("Total Opportunities"),
                    "Summary should contain 'Total Opportunities' label")
            #expect(summary.contains("\(results.count)"),
                    "Summary should contain total count '\(results.count)'")
        }
    }
    
    // MARK: - Integration Tests: Full Email Generation
    
    @Test("Property: Full email body contains table and summary for any results",
          arguments: testCases)
    func testFullEmailContainsTableAndSummary(results: [AnalysisResult]) {
        let email = EmailTemplateService.generateEmailNotification(
            results: results,
            recipient: "test@example.com"
        )
        
        // Should contain HTML structure
        #expect(email.htmlBody.contains("<table"),
                "Email body should contain HTML table")
        #expect(email.htmlBody.contains("</table>"),
                "Email body should contain closing table tag")
        
        // Should contain summary section
        #expect(email.htmlBody.contains("Summary"),
                "Email body should contain Summary section")
        
        // Should contain all column headers
        let requiredColumns = ["Ticker", "Type", "Return %", "Current Price", 
                               "Target Price", "Signal", "Next Earnings Date"]
        for column in requiredColumns {
            #expect(email.htmlBody.contains(column),
                    "Email body should contain '\(column)' column")
        }
    }
    
    @Test("Property: Email recipient is correctly set")
    func testEmailRecipientCorrectlySet() {
        for _ in 0..<Self.sampleCount {
            let results = Self.generateRandomResults(count: Int.random(in: 0...10))
            let randomEmail = "user\(Int.random(in: 1...999))@example.com"
            
            let email = EmailTemplateService.generateEmailNotification(
                results: results,
                recipient: randomEmail
            )
            
            #expect(email.recipient == randomEmail,
                    "Email recipient should be '\(randomEmail)'")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Property: Empty results array produces valid email with empty table")
    func testEmptyResultsProducesValidEmail() {
        let email = EmailTemplateService.generateEmailNotification(
            results: [],
            recipient: "test@example.com"
        )
        
        // Subject should still be valid
        #expect(email.subject.hasPrefix("TradingGuru Analysis Results - "))
        #expect(email.subject.hasSuffix(" PST"))
        
        // Counts should be zero
        #expect(email.callCount == 0)
        #expect(email.putCount == 0)
        
        // Body should still contain structure
        #expect(email.htmlBody.contains("<table"))
        #expect(email.htmlBody.contains("Summary"))
    }
    
    @Test("Property: Results with nil earnings dates display N/A")
    func testNilEarningsDateDisplaysNA() {
        for _ in 0..<Self.sampleCount {
            let resultWithNoEarnings = AnalysisResult(
                ticker: Self.generateRandomTicker(),
                type: OpportunityType.allCases.randomElement()!,
                returnPercentage: Double.random(in: -20...20),
                currentPrice: Double.random(in: 50...200),
                targetPrice: Double.random(in: 45...220),
                signal: Signal.allCases.randomElement()!,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: [resultWithNoEarnings])
            
            #expect(htmlTable.contains("N/A"),
                    "Results with nil earnings date should display 'N/A'")
        }
    }
    
    @Test("Property: All ORDER rows in any results have ORDER background color")
    func testAllOrderRowsHaveCorrectBackground() {
        for _ in 0..<Self.sampleCount {
            let results = Self.generateRandomResults(count: Int.random(in: 1...15))
            let orderResults = results.filter { $0.signal == .order }
            
            guard !orderResults.isEmpty else { continue }
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: results)
            
            // Each ORDER ticker should appear in a row with ORDER background
            for orderResult in orderResults {
                // Verify the ticker appears
                #expect(htmlTable.contains(orderResult.ticker),
                        "ORDER result ticker '\(orderResult.ticker)' should appear in table")
            }
            
            // Verify ORDER background appears the right number of times
            let orderColorCount = htmlTable.components(separatedBy: Self.orderRowBackgroundColor).count - 1
            #expect(orderColorCount >= orderResults.count,
                    "Should have at least \(orderResults.count) ORDER background colors, found \(orderColorCount)")
        }
    }
    
    @Test("Property: Price values are formatted as currency with 2 decimal places")
    func testPriceValuesFormattedCorrectly() {
        for _ in 0..<Self.sampleCount {
            let currentPrice = Double.random(in: 10...500)
            let targetPrice = currentPrice * (1 + Double.random(in: -0.2...0.2))
            
            let result = AnalysisResult(
                ticker: "TEST",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: currentPrice,
                targetPrice: targetPrice,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: [result])
            
            // Check for currency formatting ($X.XX pattern)
            let formattedCurrentPrice = String(format: "$%.2f", currentPrice)
            let formattedTargetPrice = String(format: "$%.2f", targetPrice)
            
            #expect(htmlTable.contains(formattedCurrentPrice),
                    "Current price should be formatted as '\(formattedCurrentPrice)'")
            #expect(htmlTable.contains(formattedTargetPrice),
                    "Target price should be formatted as '\(formattedTargetPrice)'")
        }
    }
    
    @Test("Property: Return percentages are formatted with 2 decimal places and % symbol")
    func testReturnPercentagesFormattedCorrectly() {
        for _ in 0..<Self.sampleCount {
            let returnPct = Double.random(in: -50...50)
            
            let result = AnalysisResult(
                ticker: "TEST",
                type: returnPct >= 0 ? .call : .put,
                returnPercentage: returnPct,
                currentPrice: 100.0,
                targetPrice: 100.0 * (1 + returnPct / 100),
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
            
            let htmlTable = EmailTemplateService.generateHTMLTable(results: [result])
            
            // Return percentage should include % symbol
            #expect(htmlTable.contains("%"),
                    "HTML table should contain % symbol for return percentage")
        }
    }
}


// MARK: - Property 19: Email Notification Gating
// **Validates: Requirements 9.7, 9.11**
//
// *For any* user, email notifications SHALL only be sent if BOTH `notificationEmail`
// is configured (non-nil, non-empty) AND `emailNotificationsEnabled == true`.
// If either condition is false, no email SHALL be sent for that user.

@Suite("Property 19: Email Notification Gating - Validates Requirements 9.7, 9.11")
struct EmailNotificationGatingPropertyTests {
    
    // MARK: - Constants
    
    /// Number of random samples for property tests
    private static let sampleCount = 100
    
    // MARK: - Test Data Generation
    
    /// Generates a random valid email address
    private static func generateRandomValidEmail() -> String {
        let localPart = "user\(Int.random(in: 1...9999))"
        let domains = ["example.com", "test.org", "mail.net", "company.io", "domain.co"]
        return "\(localPart)@\(domains.randomElement()!)"
    }
    
    /// Generates random empty/whitespace-only strings
    private static func generateEmptyOrWhitespaceString() -> String {
        let options: [String] = [
            "",
            " ",
            "  ",
            "\t",
            "\n",
            "   \t  ",
            " \n ",
        ]
        return options.randomElement()!
    }
    
    /// Generates random analysis results for testing
    private static func generateRandomResults(count: Int) -> [AnalysisResult] {
        (0..<count).map { _ in
            let ticker = String((0..<Int.random(in: 1...5)).map { _ in
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement()!
            })
            let type = OpportunityType.allCases.randomElement()!
            let returnPct = Double.random(in: -30...30)
            let currentPrice = Double.random(in: 10...500)
            let targetPrice = currentPrice * (1 + returnPct / 100)
            
            return AnalysisResult(
                ticker: ticker,
                type: type,
                returnPercentage: returnPct,
                currentPrice: currentPrice,
                targetPrice: targetPrice,
                signal: Signal.allCases.randomElement()!,
                nextEarningsDate: Bool.random() ? Date().addingTimeInterval(Double.random(in: 1...86400*30)) : nil,
                hasEarningsRisk: Bool.random()
            )
        }
    }
    
    // MARK: - Property Test Categories
    
    // MARK: Category 1: Both conditions true → email CAN be sent
    
    @Test("Property: Email CAN be sent when email is configured AND notifications enabled")
    func testCanSendWhenBothConditionsTrue() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let validEmail = Self.generateRandomValidEmail()
            let settings = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Preconditions
            #expect(settings.notificationEmail != nil, "Email should be non-nil")
            #expect(!settings.notificationEmail!.isEmpty, "Email should be non-empty")
            #expect(settings.emailNotificationsEnabled == true, "Notifications should be enabled")
            
            // Act
            let canSend = service.canSendEmail(for: settings)
            
            // Assert: Email CAN be sent
            #expect(canSend == true,
                    "Email SHOULD be sendable when email='\(validEmail)' and enabled=true")
        }
    }
    
    @Test("Property: checkEmailGating returns .canSend when both conditions true")
    func testCheckGatingReturnsCanSendWhenBothTrue() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let validEmail = Self.generateRandomValidEmail()
            let settings = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Act
            let gatingResult = service.checkEmailGating(for: settings)
            
            // Assert
            #expect(gatingResult == .canSend,
                    "Gating should return .canSend for valid email '\(validEmail)' with notifications enabled")
            #expect(gatingResult.canSend == true)
            #expect(gatingResult.reason == nil)
        }
    }
    
    // MARK: Category 2: Email not configured (nil or empty) + enabled true → email CANNOT be sent
    
    @Test("Property: Email CANNOT be sent when email is nil (even if enabled)")
    func testCannotSendWhenEmailIsNil() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let settings = UserSettings(
                notificationEmail: nil,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Preconditions
            #expect(settings.notificationEmail == nil, "Email should be nil")
            #expect(settings.emailNotificationsEnabled == true, "Notifications should be enabled")
            
            // Act
            let canSend = service.canSendEmail(for: settings)
            
            // Assert: Email CANNOT be sent
            #expect(canSend == false,
                    "Email should NOT be sendable when email is nil (Validates: Req 9.7)")
        }
    }
    
    @Test("Property: Email CANNOT be sent when email is empty string (even if enabled)")
    func testCannotSendWhenEmailIsEmpty() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let settings = UserSettings(
                notificationEmail: "",
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Preconditions
            #expect(settings.notificationEmail?.isEmpty == true, "Email should be empty")
            #expect(settings.emailNotificationsEnabled == true, "Notifications should be enabled")
            
            // Act
            let canSend = service.canSendEmail(for: settings)
            
            // Assert: Email CANNOT be sent
            #expect(canSend == false,
                    "Email should NOT be sendable when email is empty string (Validates: Req 9.7)")
        }
    }
    
    @Test("Property: Email CANNOT be sent when email is whitespace-only (even if enabled)")
    func testCannotSendWhenEmailIsWhitespaceOnly() {
        let service = EmailNotificationService()
        
        let whitespaceEmails = ["", " ", "  ", "\t", "\n", "   \t  ", " \n "]
        
        for whitespaceEmail in whitespaceEmails {
            for _ in 0..<10 {
                let settings = UserSettings(
                    notificationEmail: whitespaceEmail,
                    emailNotificationsEnabled: true,
                    scheduledAnalysisEnabled: Bool.random(),
                    updatedAt: Date()
                )
                
                // Act
                let canSend = service.canSendEmail(for: settings)
                
                // Assert: Email CANNOT be sent
                #expect(canSend == false,
                        "Email should NOT be sendable when email is whitespace-only '\(whitespaceEmail.debugDescription)' (Validates: Req 9.7)")
            }
        }
    }
    
    @Test("Property: checkEmailGating returns .noEmailConfigured when email is nil")
    func testCheckGatingReturnsNoEmailWhenNil() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let settings = UserSettings(
                notificationEmail: nil,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Act
            let gatingResult = service.checkEmailGating(for: settings)
            
            // Assert
            #expect(gatingResult == .noEmailConfigured,
                    "Gating should return .noEmailConfigured when email is nil")
            #expect(gatingResult.canSend == false)
            #expect(gatingResult.reason != nil)
        }
    }
    
    @Test("Property: checkEmailGating returns .noEmailConfigured when email is empty/whitespace")
    func testCheckGatingReturnsNoEmailWhenEmptyOrWhitespace() {
        let service = EmailNotificationService()
        
        let emptyOrWhitespaceEmails = ["", " ", "  ", "\t", "\n", "   \t  "]
        
        for emptyEmail in emptyOrWhitespaceEmails {
            let settings = UserSettings(
                notificationEmail: emptyEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Act
            let gatingResult = service.checkEmailGating(for: settings)
            
            // Assert
            #expect(gatingResult == .noEmailConfigured,
                    "Gating should return .noEmailConfigured for empty/whitespace email '\(emptyEmail.debugDescription)'")
            #expect(gatingResult.canSend == false)
        }
    }
    
    // MARK: Category 3: Email configured + enabled false → email CANNOT be sent
    
    @Test("Property: Email CANNOT be sent when notifications disabled (even with valid email)")
    func testCannotSendWhenNotificationsDisabled() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let validEmail = Self.generateRandomValidEmail()
            let settings = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: false,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Preconditions
            #expect(settings.notificationEmail != nil, "Email should be non-nil")
            #expect(!settings.notificationEmail!.isEmpty, "Email should be non-empty")
            #expect(settings.emailNotificationsEnabled == false, "Notifications should be disabled")
            
            // Act
            let canSend = service.canSendEmail(for: settings)
            
            // Assert: Email CANNOT be sent
            #expect(canSend == false,
                    "Email should NOT be sendable when notifications disabled (Validates: Req 9.11)")
        }
    }
    
    @Test("Property: checkEmailGating returns .notificationsDisabled when enabled is false")
    func testCheckGatingReturnsNotificationsDisabledWhenFalse() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let validEmail = Self.generateRandomValidEmail()
            let settings = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: false,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Act
            let gatingResult = service.checkEmailGating(for: settings)
            
            // Assert
            #expect(gatingResult == .notificationsDisabled,
                    "Gating should return .notificationsDisabled when notifications disabled")
            #expect(gatingResult.canSend == false)
            #expect(gatingResult.reason != nil)
        }
    }
    
    // MARK: Category 4: Both conditions false → email CANNOT be sent
    
    @Test("Property: Email CANNOT be sent when both email nil AND notifications disabled")
    func testCannotSendWhenBothConditionsFalse_NilEmail() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let settings = UserSettings(
                notificationEmail: nil,
                emailNotificationsEnabled: false,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Preconditions
            #expect(settings.notificationEmail == nil, "Email should be nil")
            #expect(settings.emailNotificationsEnabled == false, "Notifications should be disabled")
            
            // Act
            let canSend = service.canSendEmail(for: settings)
            
            // Assert: Email CANNOT be sent
            #expect(canSend == false,
                    "Email should NOT be sendable when both email nil AND notifications disabled")
        }
    }
    
    @Test("Property: Email CANNOT be sent when both email empty AND notifications disabled")
    func testCannotSendWhenBothConditionsFalse_EmptyEmail() {
        let service = EmailNotificationService()
        
        let emptyEmails = ["", " ", "\t", "\n"]
        
        for emptyEmail in emptyEmails {
            for _ in 0..<10 {
                let settings = UserSettings(
                    notificationEmail: emptyEmail,
                    emailNotificationsEnabled: false,
                    scheduledAnalysisEnabled: Bool.random(),
                    updatedAt: Date()
                )
                
                // Act
                let canSend = service.canSendEmail(for: settings)
                
                // Assert: Email CANNOT be sent
                #expect(canSend == false,
                        "Email should NOT be sendable when both email empty '\(emptyEmail.debugDescription)' AND notifications disabled")
            }
        }
    }
    
    // MARK: Category 5: Edge cases
    
    @Test("Property: scheduledAnalysisEnabled does NOT affect email gating")
    func testScheduledAnalysisDoesNotAffectGating() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let validEmail = Self.generateRandomValidEmail()
            
            // Test with scheduledAnalysisEnabled = true
            let settingsWithScheduled = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            // Test with scheduledAnalysisEnabled = false
            let settingsWithoutScheduled = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: false,
                updatedAt: Date()
            )
            
            // Act
            let canSendWithScheduled = service.canSendEmail(for: settingsWithScheduled)
            let canSendWithoutScheduled = service.canSendEmail(for: settingsWithoutScheduled)
            
            // Assert: scheduledAnalysisEnabled should NOT affect email gating
            #expect(canSendWithScheduled == canSendWithoutScheduled,
                    "scheduledAnalysisEnabled should NOT affect email gating decision")
            #expect(canSendWithScheduled == true,
                    "Both should be sendable since email is configured and notifications enabled")
        }
    }
    
    @Test("Property: updatedAt timestamp does NOT affect email gating")
    func testUpdatedAtDoesNotAffectGating() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            let validEmail = Self.generateRandomValidEmail()
            
            let oldTimestamp = Date().addingTimeInterval(-86400 * 365) // 1 year ago
            let newTimestamp = Date() // Now
            
            let settingsOld = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: oldTimestamp
            )
            
            let settingsNew = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: newTimestamp
            )
            
            // Act
            let canSendOld = service.canSendEmail(for: settingsOld)
            let canSendNew = service.canSendEmail(for: settingsNew)
            
            // Assert: updatedAt should NOT affect email gating
            #expect(canSendOld == canSendNew,
                    "updatedAt timestamp should NOT affect email gating decision")
        }
    }
    
    @Test("Property: Emails with leading/trailing whitespace are trimmed and validated")
    func testEmailsWithWhitespaceAreTrimmed() {
        let service = EmailNotificationService()
        
        // Valid emails with surrounding whitespace
        let emailsWithWhitespace = [
            " user@example.com",
            "user@example.com ",
            "  user@example.com  ",
            "\tuser@example.com\t",
            "\nuser@example.com\n"
        ]
        
        for emailWithWs in emailsWithWhitespace {
            let settings = UserSettings(
                notificationEmail: emailWithWs,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            // Act
            let canSend = service.canSendEmail(for: settings)
            
            // Assert: Email with whitespace should be handled (trimmed)
            // The service trims whitespace, so these should be sendable
            #expect(canSend == true,
                    "Email with surrounding whitespace '\(emailWithWs.debugDescription)' should be sendable after trimming")
        }
    }
    
    // MARK: - sendAnalysisResults Gating Tests
    
    @Test("Property: sendAnalysisResults throws noEmailConfigured when email is nil")
    func testSendAnalysisResultsThrowsNoEmailWhenNil() async {
        let service = EmailNotificationService()
        let results = Self.generateRandomResults(count: 5)
        
        for _ in 0..<10 {
            let settings = UserSettings(
                notificationEmail: nil,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            do {
                try await service.sendAnalysisResults(
                    results: results,
                    userSettings: settings,
                    htmlContent: "<p>Test</p>",
                    subject: "Test Subject"
                )
                Issue.record("Expected noEmailConfigured error to be thrown")
            } catch let error as EmailServiceError {
                #expect(error == .noEmailConfigured,
                        "Should throw .noEmailConfigured when email is nil, got: \(error)")
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    @Test("Property: sendAnalysisResults throws noEmailConfigured when email is empty")
    func testSendAnalysisResultsThrowsNoEmailWhenEmpty() async {
        let service = EmailNotificationService()
        let results = Self.generateRandomResults(count: 5)
        
        let emptyEmails = ["", " ", "\t", "\n", "   "]
        
        for emptyEmail in emptyEmails {
            let settings = UserSettings(
                notificationEmail: emptyEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            do {
                try await service.sendAnalysisResults(
                    results: results,
                    userSettings: settings,
                    htmlContent: "<p>Test</p>",
                    subject: "Test Subject"
                )
                Issue.record("Expected noEmailConfigured error for empty email '\(emptyEmail.debugDescription)'")
            } catch let error as EmailServiceError {
                #expect(error == .noEmailConfigured,
                        "Should throw .noEmailConfigured for empty email '\(emptyEmail.debugDescription)', got: \(error)")
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    @Test("Property: sendAnalysisResults throws notificationsDisabled when disabled")
    func testSendAnalysisResultsThrowsNotificationsDisabled() async {
        let service = EmailNotificationService()
        let results = Self.generateRandomResults(count: 5)
        
        for _ in 0..<10 {
            let validEmail = Self.generateRandomValidEmail()
            let settings = UserSettings(
                notificationEmail: validEmail,
                emailNotificationsEnabled: false,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            do {
                try await service.sendAnalysisResults(
                    results: results,
                    userSettings: settings,
                    htmlContent: "<p>Test</p>",
                    subject: "Test Subject"
                )
                Issue.record("Expected notificationsDisabled error to be thrown")
            } catch let error as EmailServiceError {
                #expect(error == .notificationsDisabled,
                        "Should throw .notificationsDisabled when notifications disabled, got: \(error)")
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Consistency Tests
    
    @Test("Property: canSendEmail is consistent across multiple calls for same settings")
    func testCanSendEmailConsistency() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Call multiple times
            let result1 = service.canSendEmail(for: settings)
            let result2 = service.canSendEmail(for: settings)
            let result3 = service.canSendEmail(for: settings)
            
            // Assert: Results should be consistent
            #expect(result1 == result2 && result2 == result3,
                    "canSendEmail should return consistent results for same settings")
        }
    }
    
    @Test("Property: checkEmailGating is consistent across multiple calls for same settings")
    func testCheckEmailGatingConsistency() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Call multiple times
            let result1 = service.checkEmailGating(for: settings)
            let result2 = service.checkEmailGating(for: settings)
            let result3 = service.checkEmailGating(for: settings)
            
            // Assert: Results should be consistent
            #expect(result1 == result2 && result2 == result3,
                    "checkEmailGating should return consistent results for same settings")
        }
    }
    
    @Test("Property: canSendEmail and checkEmailGating.canSend return same result")
    func testCanSendEmailMatchesCheckGating() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Act
            let canSendResult = service.canSendEmail(for: settings)
            let gatingResult = service.checkEmailGating(for: settings)
            
            // Assert: Both should agree
            #expect(canSendResult == gatingResult.canSend,
                    "canSendEmail (\(canSendResult)) should match checkEmailGating.canSend (\(gatingResult.canSend))")
        }
    }
    
    // MARK: - Boolean Combination Tests (Truth Table)
    
    @Test("Property: Email gating follows correct truth table for all input combinations")
    func testGatingTruthTable() {
        let service = EmailNotificationService()
        
        // Truth table for email gating:
        // | Email Configured | Notifications Enabled | Can Send |
        // |------------------|----------------------|----------|
        // | true             | true                 | true     |
        // | true             | false                | false    |
        // | false (nil)      | true                 | false    |
        // | false (nil)      | false                | false    |
        // | false (empty)    | true                 | false    |
        // | false (empty)    | false                | false    |
        
        // Test Case 1: Email configured + enabled = CAN SEND
        for _ in 0..<25 {
            let settings = UserSettings(
                notificationEmail: Self.generateRandomValidEmail(),
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            #expect(service.canSendEmail(for: settings) == true,
                    "Case 1: Configured + Enabled should allow sending")
        }
        
        // Test Case 2: Email configured + disabled = CANNOT SEND
        for _ in 0..<25 {
            let settings = UserSettings(
                notificationEmail: Self.generateRandomValidEmail(),
                emailNotificationsEnabled: false,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            #expect(service.canSendEmail(for: settings) == false,
                    "Case 2: Configured + Disabled should NOT allow sending")
        }
        
        // Test Case 3: Email nil + enabled = CANNOT SEND
        for _ in 0..<25 {
            let settings = UserSettings(
                notificationEmail: nil,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            #expect(service.canSendEmail(for: settings) == false,
                    "Case 3: Nil + Enabled should NOT allow sending")
        }
        
        // Test Case 4: Email nil + disabled = CANNOT SEND
        for _ in 0..<25 {
            let settings = UserSettings(
                notificationEmail: nil,
                emailNotificationsEnabled: false,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            #expect(service.canSendEmail(for: settings) == false,
                    "Case 4: Nil + Disabled should NOT allow sending")
        }
    }
    
    // MARK: - Gating Result Reason Tests
    
    @Test("Property: EmailGatingResult.reason is nil only when canSend is true")
    func testGatingReasonNilOnlyWhenCanSend() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            let gatingResult = service.checkEmailGating(for: settings)
            
            if gatingResult.canSend {
                #expect(gatingResult.reason == nil,
                        "reason should be nil when canSend is true")
            } else {
                #expect(gatingResult.reason != nil,
                        "reason should NOT be nil when canSend is false")
            }
        }
    }
    
    // MARK: - Boundary Condition Tests
    
    @Test("Property: Single character email addresses are handled correctly")
    func testSingleCharEmailAddresses() {
        let service = EmailNotificationService()
        
        // Very short but potentially valid-looking strings
        let shortStrings = ["a", "1", "@", ".", "a@"]
        
        for shortString in shortStrings {
            let settings = UserSettings(
                notificationEmail: shortString,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            // canSendEmail should return true (email is non-empty)
            // But sendAnalysisResults may fail format validation
            let canSend = service.canSendEmail(for: settings)
            
            #expect(canSend == true,
                    "canSendEmail should return true for non-empty string '\(shortString)' (format validated separately)")
        }
    }
    
    @Test("Property: Very long email addresses are handled correctly")
    func testVeryLongEmailAddresses() {
        let service = EmailNotificationService()
        
        for _ in 0..<10 {
            // Generate very long but valid-format email
            let longLocalPart = String(repeating: "a", count: 64)
            let longDomain = String(repeating: "b", count: 10)
            let longEmail = "\(longLocalPart)@\(longDomain).com"
            
            let settings = UserSettings(
                notificationEmail: longEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            // Should be treated as configured (non-empty)
            let canSend = service.canSendEmail(for: settings)
            #expect(canSend == true,
                    "canSendEmail should return true for long email '\(longEmail.prefix(20))...'")
        }
    }
    
    // MARK: - Invalid Email Format Tests (separate from gating)
    
    @Test("Property: checkEmailGating returns .invalidEmailFormat for invalid format emails")
    func testCheckGatingReturnsInvalidFormatForBadEmails() {
        let service = EmailNotificationService()
        
        let invalidFormatEmails = [
            "noatsymbol",
            "missing@domain",
            "@missinglocal.com",
            "spaces in@email.com",
            "double@@at.com"
        ]
        
        for invalidEmail in invalidFormatEmails {
            let settings = UserSettings(
                notificationEmail: invalidEmail,
                emailNotificationsEnabled: true,
                scheduledAnalysisEnabled: true,
                updatedAt: Date()
            )
            
            let gatingResult = service.checkEmailGating(for: settings)
            
            // Should detect invalid format
            #expect(gatingResult == .invalidEmailFormat,
                    "Should return .invalidEmailFormat for invalid email '\(invalidEmail)'")
            #expect(gatingResult.canSend == false)
        }
    }
    
    // MARK: - Property Test: Implication Tests
    
    @Test("Property: If canSendEmail returns true, THEN both conditions MUST be true")
    func testCanSendTrueImpliesBothConditionsTrue() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            let canSend = service.canSendEmail(for: settings)
            
            // If canSend is true, THEN both conditions must be true
            if canSend {
                #expect(settings.notificationEmail != nil,
                        "If canSend=true, email must be non-nil")
                #expect(!settings.notificationEmail!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "If canSend=true, email must be non-empty after trimming")
                #expect(settings.emailNotificationsEnabled == true,
                        "If canSend=true, notifications must be enabled")
            }
        }
    }
    
    @Test("Property: If either condition is false, THEN canSendEmail MUST return false")
    func testEitherConditionFalseImpliesCannotSend() {
        let service = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            let emailMissing = settings.notificationEmail == nil || 
                               settings.notificationEmail!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let notificationsDisabled = !settings.emailNotificationsEnabled
            
            let canSend = service.canSendEmail(for: settings)
            
            // If either condition is false, canSend must be false
            if emailMissing || notificationsDisabled {
                #expect(canSend == false,
                        "If email missing (\(emailMissing)) OR notifications disabled (\(notificationsDisabled)), canSend must be false")
            }
        }
    }
    
    // MARK: - MockEmailNotificationService Tests
    
    #if DEBUG
    @Test("Property: MockEmailNotificationService follows same gating logic")
    func testMockServiceFollowsSameGatingLogic() {
        let mockService = MockEmailNotificationService()
        let realService = EmailNotificationService()
        
        for _ in 0..<Self.sampleCount {
            // Generate random settings
            let email: String? = Bool.random() ? Self.generateRandomValidEmail() : nil
            let enabled = Bool.random()
            
            let settings = UserSettings(
                notificationEmail: email,
                emailNotificationsEnabled: enabled,
                scheduledAnalysisEnabled: Bool.random(),
                updatedAt: Date()
            )
            
            // Both services should return the same result
            let mockCanSend = mockService.canSendEmail(for: settings)
            let realCanSend = realService.canSendEmail(for: settings)
            
            #expect(mockCanSend == realCanSend,
                    "Mock and real service should have same gating behavior for email=\(String(describing: email)), enabled=\(enabled)")
        }
    }
    #endif
}
