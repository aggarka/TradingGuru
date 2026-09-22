//
//  ConfigurationValidationTests.swift
//  TradingGuruTests
//
//  Unit tests for ConfigurationValidationService.
//  Tests PREMIUM_PCT validation (0.1% to 5.0% range) and value retention on failure.
//
//  - Validates: Requirement 4.11 (PREMIUM_PCT validation with error message)
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Configuration Validation Service Tests

@Suite("ConfigurationValidationService Tests")
struct ConfigurationValidationServiceTests {
    
    let validationService = ConfigurationValidationService()
    
    // MARK: - Premium Percentage Valid Range Tests
    // Validates: Requirement 4.11 (Valid range: 0.1% to 5.0%)
    
    @Test("Premium percentage at lower boundary (0.1) is accepted")
    func testPremiumPctAtLowerBoundary() {
        let result = validationService.validatePremiumPct(0.1, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(value == 0.1)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test("Premium percentage at upper boundary (5.0) is accepted")
    func testPremiumPctAtUpperBoundary() {
        let result = validationService.validatePremiumPct(5.0, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(value == 5.0)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test("Premium percentage at mid-range (0.5) is accepted")
    func testPremiumPctAtMidRange() {
        let result = validationService.validatePremiumPct(0.5, currentValue: 1.0)
        
        switch result {
        case .success(let value):
            #expect(value == 0.5)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test("Premium percentage at mid-range (2.5) is accepted")
    func testPremiumPctAtMidRange2() {
        let result = validationService.validatePremiumPct(2.5, currentValue: 1.0)
        
        switch result {
        case .success(let value):
            #expect(value == 2.5)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test("Premium percentage at valid value (4.9) is accepted")
    func testPremiumPctAtValidValue() {
        let result = validationService.validatePremiumPct(4.9, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(value == 4.9)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    // MARK: - Premium Percentage Invalid Range Tests (Below)
    // Validates: Requirement 4.11 (Reject values outside valid range)
    
    @Test("Premium percentage below range (0.0) is rejected")
    func testPremiumPctBelowRangeZero() {
        let result = validationService.validatePremiumPct(0.0, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for value below range")
        case .failure(let error):
            if case .valueOutOfRange(let param, let message) = error {
                #expect(param == "premiumPct")
                #expect(message.contains("0.1%"))
                #expect(message.contains("5.0%"))
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Premium percentage below range (-1.0) is rejected")
    func testPremiumPctBelowRangeNegative() {
        let result = validationService.validatePremiumPct(-1.0, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for negative value")
        case .failure(let error):
            if case .valueOutOfRange(let param, let message) = error {
                #expect(param == "premiumPct")
                #expect(message.contains("0.1%"))
                #expect(message.contains("5.0%"))
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Premium percentage below range (0.05) is rejected")
    func testPremiumPctBelowRangeSmall() {
        let result = validationService.validatePremiumPct(0.05, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for value 0.05 (below 0.1)")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "premiumPct")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Premium percentage below range (0.09) is rejected")
    func testPremiumPctJustBelowLowerBound() {
        let result = validationService.validatePremiumPct(0.09, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for value 0.09 (just below 0.1)")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "premiumPct")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    // MARK: - Premium Percentage Invalid Range Tests (Above)
    // Validates: Requirement 4.11 (Reject values outside valid range)
    
    @Test("Premium percentage above range (5.1) is rejected")
    func testPremiumPctAboveRange() {
        let result = validationService.validatePremiumPct(5.1, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for value above range")
        case .failure(let error):
            if case .valueOutOfRange(let param, let message) = error {
                #expect(param == "premiumPct")
                #expect(message.contains("0.1%"))
                #expect(message.contains("5.0%"))
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Premium percentage above range (10.0) is rejected")
    func testPremiumPctAboveRangeLarge() {
        let result = validationService.validatePremiumPct(10.0, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for value 10.0")
        case .failure(let error):
            if case .valueOutOfRange(let param, let message) = error {
                #expect(param == "premiumPct")
                #expect(message.contains("0.1%"))
                #expect(message.contains("5.0%"))
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Premium percentage above range (5.01) is rejected")
    func testPremiumPctJustAboveUpperBound() {
        let result = validationService.validatePremiumPct(5.01, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure for value 5.01 (just above 5.0)")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "premiumPct")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    // MARK: - Error Message Tests
    // Validates: Requirement 4.11 (Display error message indicating valid range)
    
    @Test("Error message indicates valid range for invalid premium percentage")
    func testErrorMessageIndicatesValidRange() {
        let result = validationService.validatePremiumPct(6.0, currentValue: 0.5)
        
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let error):
            let message = ConfigurationValidationService.errorMessage(for: error)
            #expect(message.contains("0.1%"))
            #expect(message.contains("5.0%"))
        }
    }
    
    // MARK: - Value Retention Tests
    // Validates: Requirement 4.11 (Retain previous value on validation failure)
    
    @Test("Configuration retains previous premium value on validation failure")
    func testConfigurationRetainsPreviousValueOnFailure() {
        var config = WeeklyOptionConfiguration(premiumPct: 2.5)
        let originalValue = config.premiumPct
        
        let result = validationService.updatePremiumPct(6.0, in: &config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for invalid value")
        case .failure:
            // Configuration should retain its previous value
            #expect(config.premiumPct == originalValue)
            #expect(config.premiumPct == 2.5)
        }
    }
    
    @Test("Configuration retains previous premium value for negative input")
    func testConfigurationRetainsPreviousValueForNegative() {
        var config = WeeklyOptionConfiguration(premiumPct: 1.0)
        let originalValue = config.premiumPct
        
        let result = validationService.updatePremiumPct(-5.0, in: &config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for negative value")
        case .failure:
            #expect(config.premiumPct == originalValue)
            #expect(config.premiumPct == 1.0)
        }
    }
    
    @Test("Configuration is updated on valid premium value")
    func testConfigurationIsUpdatedOnValidValue() {
        var config = WeeklyOptionConfiguration(premiumPct: 1.0)
        
        let result = validationService.updatePremiumPct(3.5, in: &config)
        
        switch result {
        case .success:
            #expect(config.premiumPct == 3.5)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    // MARK: - Window Days Validation Tests
    
    @Test("Valid window days values are accepted")
    func testValidWindowDaysAccepted() {
        for days in WeeklyOptionConfiguration.validWindowDays {
            let result = validationService.validateWindowDays(days, currentValue: 5)
            
            switch result {
            case .success(let value):
                #expect(value == days)
            case .failure(let error):
                Issue.record("Expected success for window days \(days) but got error: \(error)")
            }
        }
    }
    
    @Test("Invalid window days are rejected")
    func testInvalidWindowDaysRejected() {
        let invalidValues = [0, 2, 7, 10, 100]
        
        for days in invalidValues {
            let result = validationService.validateWindowDays(days, currentValue: 5)
            
            switch result {
            case .success:
                Issue.record("Expected failure for invalid window days \(days)")
            case .failure(let error):
                if case .valueOutOfRange(let param, _) = error {
                    #expect(param == "windowDays")
                } else {
                    Issue.record("Expected valueOutOfRange error")
                }
            }
        }
    }
    
    @Test("Configuration retains previous window days on validation failure")
    func testConfigurationRetainsPreviousWindowDaysOnFailure() {
        var config = WeeklyOptionConfiguration(windowDays: 5)
        
        let result = validationService.updateWindowDays(7, in: &config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for invalid window days")
        case .failure:
            #expect(config.windowDays == 5)
        }
    }
    
    // MARK: - Lookback Days Validation Tests
    
    @Test("Valid lookback days values are accepted")
    func testValidLookbackDaysAccepted() {
        for days in WeeklyOptionConfiguration.validLookbackDays {
            let result = validationService.validateLookbackDays(days, currentValue: 180)
            
            switch result {
            case .success(let value):
                #expect(value == days)
            case .failure(let error):
                Issue.record("Expected success for lookback days \(days) but got error: \(error)")
            }
        }
    }
    
    @Test("Invalid lookback days are rejected")
    func testInvalidLookbackDaysRejected() {
        let invalidValues = [0, 10, 45, 100, 500]
        
        for days in invalidValues {
            let result = validationService.validateLookbackDays(days, currentValue: 180)
            
            switch result {
            case .success:
                Issue.record("Expected failure for invalid lookback days \(days)")
            case .failure(let error):
                if case .valueOutOfRange(let param, _) = error {
                    #expect(param == "lookbackDays")
                } else {
                    Issue.record("Expected valueOutOfRange error")
                }
            }
        }
    }
    
    @Test("Configuration retains previous lookback days on validation failure")
    func testConfigurationRetainsPreviousLookbackDaysOnFailure() {
        var config = WeeklyOptionConfiguration(lookbackDays: 180)
        
        let result = validationService.updateLookbackDays(100, in: &config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for invalid lookback days")
        case .failure:
            #expect(config.lookbackDays == 180)
        }
    }
    
    // MARK: - Full Configuration Validation Tests
    
    @Test("Valid configuration passes full validation")
    func testValidConfigurationPassesFullValidation() {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: 1.0,
            onlyOrders: false
        )
        
        let result = validationService.validateConfiguration(config)
        
        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test("Configuration with invalid premium fails full validation")
    func testConfigurationWithInvalidPremiumFailsFullValidation() {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: 10.0,  // Invalid
            onlyOrders: false
        )
        
        let result = validationService.validateConfiguration(config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for invalid premium")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "premiumPct")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Configuration with invalid window days fails full validation")
    func testConfigurationWithInvalidWindowDaysFailsFullValidation() {
        let config = WeeklyOptionConfiguration(
            windowDays: 7,  // Invalid
            lookbackDays: 180,
            premiumPct: 1.0,
            onlyOrders: false
        )
        
        let result = validationService.validateConfiguration(config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for invalid window days")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "windowDays")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Configuration with invalid lookback days fails full validation")
    func testConfigurationWithInvalidLookbackDaysFailsFullValidation() {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 100,  // Invalid
            premiumPct: 1.0,
            onlyOrders: false
        )
        
        let result = validationService.validateConfiguration(config)
        
        switch result {
        case .success:
            Issue.record("Expected failure for invalid lookback days")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "lookbackDays")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
}

// MARK: - Premium Percentage Boundary Tests

@Suite("Premium Percentage Boundary Tests")
struct PremiumPercentageBoundaryTests {
    
    let validationService = ConfigurationValidationService()
    
    @Test("All valid step values within range are accepted")
    func testAllValidStepValuesAccepted() {
        // Test values at 0.1 step increments within valid range
        let validValues = [0.1, 0.2, 0.3, 0.4, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 4.9, 5.0]
        
        for value in validValues {
            let result = validationService.validatePremiumPct(value, currentValue: 0.5)
            
            switch result {
            case .success(let validatedValue):
                #expect(validatedValue == value, "Expected \(value) to be validated successfully")
            case .failure(let error):
                Issue.record("Expected success for value \(value) but got error: \(error)")
            }
        }
    }
    
    @Test("Value just inside lower boundary is accepted")
    func testValueJustInsideLowerBoundary() {
        // 0.1 should be accepted
        let result = validationService.validatePremiumPct(0.1, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(value == 0.1)
        case .failure:
            Issue.record("Expected 0.1 to be accepted (lower boundary)")
        }
    }
    
    @Test("Value just inside upper boundary is accepted")
    func testValueJustInsideUpperBoundary() {
        // 5.0 should be accepted
        let result = validationService.validatePremiumPct(5.0, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(value == 5.0)
        case .failure:
            Issue.record("Expected 5.0 to be accepted (upper boundary)")
        }
    }
}
