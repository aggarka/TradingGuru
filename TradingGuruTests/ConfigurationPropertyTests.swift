//
//  ConfigurationPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for strategy configuration validation.
//  Tests the correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 5: Premium Percentage Valid Range Acceptance
// **Validates: Requirements 4.4**
//
// *For any* decimal value within the range [0.1, 5.0] that aligns with 0.1 step
// increments (0.1, 0.2, 0.3, ..., 4.9, 5.0), setting PREMIUM_PCT to that value
// SHALL succeed and the configuration SHALL contain that value.

@Suite("Property 5: Premium Percentage Valid Range Acceptance - Validates Requirements 4.4")
struct PremiumPercentageValidRangePropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    let validationService = ConfigurationValidationService()
    
    // MARK: - Valid Value Generation
    
    /// All valid premium percentage values at 0.1 step increments within [0.1, 5.0]
    /// This generates: 0.1, 0.2, 0.3, ..., 4.9, 5.0 (50 values total)
    static let allValidStepValues: [Double] = {
        var values: [Double] = []
        var current = 0.1
        while current <= 5.0 + 0.001 { // Add small epsilon for floating point comparison
            values.append((current * 10).rounded() / 10) // Round to handle floating point precision
            current += 0.1
        }
        return values
    }()
    
    /// Generates random valid premium percentage values within the valid range
    static func generateRandomValidPremiumValues(count: Int) -> [Double] {
        return (0..<count).map { _ in
            // Generate values aligned to 0.1 step increments
            let stepCount = Int.random(in: 1...50) // 0.1 to 5.0 in 0.1 increments = 50 steps
            return Double(stepCount) / 10.0
        }
    }
    
    /// Generates random valid premium values within range (not necessarily on step)
    static func generateRandomValidContinuousValues(count: Int) -> [Double] {
        return (0..<count).map { _ in
            Double.random(in: 0.1...5.0)
        }
    }
    
    // MARK: - Property Tests: All Valid Step Values Are Accepted
    
    @Test("Property: All valid 0.1 step increment values from 0.1 to 5.0 are accepted",
          arguments: allValidStepValues)
    func testAllValidStepValuesAccepted(validValue: Double) {
        // Precondition: Value should be within valid range [0.1, 5.0]
        #expect(validValue >= 0.1 && validValue <= 5.0,
                "Value \(validValue) should be within valid range [0.1, 5.0]")
        
        // Act: Validate the premium percentage
        let result = validationService.validatePremiumPct(validValue, currentValue: 0.5)
        
        // Assert: Validation SHALL succeed
        switch result {
        case .success(let validatedValue):
            // Configuration SHALL contain that value
            #expect(abs(validatedValue - validValue) < 0.001,
                    "Validated value \(validatedValue) should equal input \(validValue)")
        case .failure(let error):
            Issue.record("Expected success for valid value \(validValue), but got error: \(error)")
        }
    }
    
    @Test("Property: Random valid premium values are accepted",
          arguments: generateRandomValidPremiumValues(count: 10))
    func testRandomValidPremiumValuesAccepted(validValue: Double) {
        // Precondition: Value should be within valid range
        #expect(validValue >= 0.1 && validValue <= 5.0,
                "Generated value \(validValue) should be within valid range")
        
        // Act
        let result = validationService.validatePremiumPct(validValue, currentValue: 1.0)
        
        // Assert
        switch result {
        case .success(let validatedValue):
            #expect(abs(validatedValue - validValue) < 0.001,
                    "Validated value should equal input value")
        case .failure(let error):
            Issue.record("Expected success for \(validValue), got error: \(error)")
        }
    }
    
    // MARK: - Property Tests: Configuration Update with Valid Values
    
    @Test("Property: Configuration is updated with valid premium value",
          arguments: allValidStepValues)
    func testConfigurationUpdatedWithValidValue(validValue: Double) {
        var config = WeeklyOptionConfiguration(premiumPct: 0.5)
        
        // Act: Update configuration with valid value
        let result = validationService.updatePremiumPct(validValue, in: &config)
        
        // Assert: Update SHALL succeed and configuration SHALL contain the value
        switch result {
        case .success:
            #expect(abs(config.premiumPct - validValue) < 0.001,
                    "Configuration should contain value \(validValue), but got \(config.premiumPct)")
        case .failure(let error):
            Issue.record("Expected success for \(validValue), got error: \(error)")
        }
    }
    
    @Test("Property: Random valid values update configuration correctly",
          arguments: generateRandomValidPremiumValues(count: 10))
    func testRandomValidValuesUpdateConfiguration(validValue: Double) {
        // Start with different initial values to ensure the update actually changes it
        let initialValue = validValue == 0.5 ? 1.0 : 0.5
        var config = WeeklyOptionConfiguration(premiumPct: initialValue)
        
        // Act
        let result = validationService.updatePremiumPct(validValue, in: &config)
        
        // Assert
        switch result {
        case .success:
            #expect(abs(config.premiumPct - validValue) < 0.001,
                    "Configuration should be updated to \(validValue)")
        case .failure(let error):
            Issue.record("Expected success for \(validValue), got error: \(error)")
        }
    }
    
    // MARK: - Property Tests: WeeklyOptionConfiguration Static Validation
    
    @Test("Property: WeeklyOptionConfiguration.validatePremiumPct accepts valid values",
          arguments: allValidStepValues)
    func testStaticValidationAcceptsValidValues(validValue: Double) {
        // Act
        let error = WeeklyOptionConfiguration.validatePremiumPct(validValue)
        
        // Assert: No error for valid values
        #expect(error == nil,
                "Expected no error for valid value \(validValue), but got: \(String(describing: error))")
    }
    
    @Test("Property: Valid configuration passes full validation",
          arguments: allValidStepValues)
    func testValidConfigurationPassesFullValidation(validPremium: Double) {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: validPremium,
            onlyOrders: false
        )
        
        // Act
        let result = validationService.validateConfiguration(config)
        
        // Assert
        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            Issue.record("Expected valid config with premium \(validPremium) to pass, got: \(error)")
        }
    }
    
    // MARK: - Property Tests: Boundary Values
    
    @Test("Property: Lower boundary value (0.1) is accepted")
    func testLowerBoundaryAccepted() {
        let lowerBoundary = 0.1
        
        let result = validationService.validatePremiumPct(lowerBoundary, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(abs(value - lowerBoundary) < 0.001)
        case .failure(let error):
            Issue.record("Expected lower boundary \(lowerBoundary) to be accepted, got: \(error)")
        }
    }
    
    @Test("Property: Upper boundary value (5.0) is accepted")
    func testUpperBoundaryAccepted() {
        let upperBoundary = 5.0
        
        let result = validationService.validatePremiumPct(upperBoundary, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(abs(value - upperBoundary) < 0.001)
        case .failure(let error):
            Issue.record("Expected upper boundary \(upperBoundary) to be accepted, got: \(error)")
        }
    }
    
    // MARK: - Property Tests: Values Between Steps Are Also Valid
    
    @Test("Property: Continuous values within range are accepted",
          arguments: generateRandomValidContinuousValues(count: 10))
    func testContinuousValuesWithinRangeAccepted(validValue: Double) {
        // Even values not exactly on 0.1 increments should be valid
        // as long as they're within the range [0.1, 5.0]
        #expect(validValue >= 0.1 && validValue <= 5.0)
        
        let result = validationService.validatePremiumPct(validValue, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            #expect(abs(value - validValue) < 0.001)
        case .failure(let error):
            Issue.record("Expected continuous value \(validValue) to be accepted, got: \(error)")
        }
    }
    
    // MARK: - Property Tests: Variety of Initial Values
    
    @Test("Property: Valid values accepted regardless of current configuration value",
          arguments: [
            (0.1, 5.0), (0.5, 0.1), (2.5, 4.0), (1.0, 3.0), (4.9, 0.2),
            (5.0, 0.1), (0.3, 2.7), (3.3, 1.5), (0.2, 4.8), (4.5, 0.5)
          ])
    func testValidValueAcceptedRegardlessOfCurrentValue(newValue: Double, currentValue: Double) {
        let result = validationService.validatePremiumPct(newValue, currentValue: currentValue)
        
        switch result {
        case .success(let value):
            #expect(abs(value - newValue) < 0.001,
                    "New value \(newValue) should be returned regardless of current \(currentValue)")
        case .failure(let error):
            Issue.record("Expected \(newValue) to be accepted with current \(currentValue), got: \(error)")
        }
    }
    
    // MARK: - Property Tests: Configuration isValid Check
    
    @Test("Property: Configuration with valid premium reports isValid = true",
          arguments: allValidStepValues)
    func testConfigurationIsValidWithValidPremium(validPremium: Double) {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: validPremium,
            onlyOrders: false
        )
        
        #expect(config.isValid,
                "Configuration with valid premium \(validPremium) should be valid")
    }
    
    // MARK: - Property Tests: Value Preservation After Successful Validation
    
    @Test("Property: Successful validation preserves exact value",
          arguments: allValidStepValues)
    func testSuccessfulValidationPreservesExactValue(validValue: Double) {
        var config = WeeklyOptionConfiguration(premiumPct: 0.5)
        
        _ = validationService.updatePremiumPct(validValue, in: &config)
        
        // The stored value should match the input with floating point tolerance
        #expect(abs(config.premiumPct - validValue) < 0.001,
                "Value should be preserved exactly: expected \(validValue), got \(config.premiumPct)")
    }
    
    // MARK: - Edge Cases: Special Valid Values
    
    @Test("Property: Quarter percent increments within range are valid",
          arguments: [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0])
    func testQuarterPercentIncrementsValid(value: Double) {
        guard value >= 0.1 && value <= 5.0 else { return } // Skip values outside range
        
        let result = validationService.validatePremiumPct(value, currentValue: 0.5)
        
        switch result {
        case .success:
            // Expected for values within range
            break
        case .failure(let error):
            Issue.record("Expected \(value) to be valid, got: \(error)")
        }
    }
    
    @Test("Property: Common real-world premium values are valid",
          arguments: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
    func testCommonRealWorldValuesValid(value: Double) {
        var config = WeeklyOptionConfiguration(premiumPct: 0.5)
        
        let result = validationService.updatePremiumPct(value, in: &config)
        
        switch result {
        case .success:
            #expect(abs(config.premiumPct - value) < 0.001)
        case .failure(let error):
            Issue.record("Expected common value \(value) to be valid, got: \(error)")
        }
    }
}

// MARK: - Property 6: Premium Percentage Invalid Range Rejection
// **Validates: Requirements 4.11**
//
// *For any* decimal value less than 0.1 or greater than 5.0, attempting to set
// PREMIUM_PCT to that value SHALL fail with a validation error, and the
// configuration SHALL retain its previous value.

@Suite("Property 6: Premium Percentage Invalid Range Rejection - Validates Requirements 4.11")
struct PremiumPercentageInvalidRangePropertyTests {
    
    let validationService = ConfigurationValidationService()
    
    // MARK: - Invalid Value Generation
    
    /// Values below the valid range (< 0.1)
    static let invalidValuesBelowRange: [Double] = [
        0.0,          // Zero
        0.05,         // Just below minimum
        0.09,         // Very close to minimum
        0.099,        // Even closer to minimum
        0.01,         // Small positive
        -0.1,         // Negative
        -1.0,         // More negative
        -5.0,         // Significantly negative
        -100.0,       // Large negative
        -0.5,         // Mid negative
        0.001,        // Tiny positive
        -0.001,       // Tiny negative
        Double.leastNonzeroMagnitude  // Smallest representable positive
    ]
    
    /// Values above the valid range (> 5.0)
    static let invalidValuesAboveRange: [Double] = [
        5.01,         // Just above maximum
        5.1,          // Slightly above maximum
        5.5,          // Half step above maximum
        6.0,          // One whole number above
        10.0,         // Double the maximum
        100.0,        // Large value
        1000.0,       // Very large value
        5.001,        // Very close to maximum
        5.0001,       // Even closer to maximum
        50.0,         // Ten times maximum
        Double.greatestFiniteMagnitude / 2  // Very large finite value
    ]
    
    /// Combined list of all invalid values
    static var allInvalidValues: [Double] {
        invalidValuesBelowRange + invalidValuesAboveRange
    }
    
    /// Generates random invalid premium values below the valid range
    static func generateRandomInvalidBelowValues(count: Int) -> [Double] {
        return (0..<count).map { _ in
            // Generate values in range (-100, 0.1)
            let random = Double.random(in: -100.0..<0.1)
            return random
        }
    }
    
    /// Generates random invalid premium values above the valid range
    static func generateRandomInvalidAboveValues(count: Int) -> [Double] {
        return (0..<count).map { _ in
            // Generate values in range (5.0, 1000)
            let random = Double.random(in: 5.001...1000.0)
            return random
        }
    }
    
    // MARK: - Property Tests: Values Below Range Are Rejected
    
    @Test("Property: Values below 0.1 are rejected with validation error",
          arguments: invalidValuesBelowRange)
    func testValuesBelowRangeRejected(invalidValue: Double) {
        // Precondition: Value should be below valid range
        #expect(invalidValue < 0.1,
                "Value \(invalidValue) should be below 0.1")
        
        // Act: Attempt to validate the premium percentage
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 0.5)
        
        // Assert: Validation SHALL fail with error
        switch result {
        case .success(let value):
            Issue.record("Expected failure for invalid value \(invalidValue), but got success with \(value)")
        case .failure(let error):
            // Error should be valueOutOfRange for premiumPct
            if case .valueOutOfRange(let parameter, _) = error {
                #expect(parameter == "premiumPct",
                        "Error should be for premiumPct parameter")
            } else {
                Issue.record("Expected valueOutOfRange error, got: \(error)")
            }
        }
    }
    
    @Test("Property: Values above 5.0 are rejected with validation error",
          arguments: invalidValuesAboveRange)
    func testValuesAboveRangeRejected(invalidValue: Double) {
        // Precondition: Value should be above valid range
        #expect(invalidValue > 5.0,
                "Value \(invalidValue) should be above 5.0")
        
        // Act: Attempt to validate the premium percentage
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 0.5)
        
        // Assert: Validation SHALL fail with error
        switch result {
        case .success(let value):
            Issue.record("Expected failure for invalid value \(invalidValue), but got success with \(value)")
        case .failure(let error):
            // Error should be valueOutOfRange for premiumPct
            if case .valueOutOfRange(let parameter, _) = error {
                #expect(parameter == "premiumPct",
                        "Error should be for premiumPct parameter")
            } else {
                Issue.record("Expected valueOutOfRange error, got: \(error)")
            }
        }
    }
    
    @Test("Property: All invalid values are rejected",
          arguments: allInvalidValues)
    func testAllInvalidValuesRejected(invalidValue: Double) {
        // Precondition: Value should be outside valid range [0.1, 5.0]
        #expect(invalidValue < 0.1 || invalidValue > 5.0,
                "Value \(invalidValue) should be outside valid range [0.1, 5.0]")
        
        // Act
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 1.0)
        
        // Assert
        switch result {
        case .success(let value):
            Issue.record("Expected failure for \(invalidValue), got success with \(value)")
        case .failure:
            // Expected - validation should fail
            break
        }
    }
    
    @Test("Property: Random values below range are rejected",
          arguments: generateRandomInvalidBelowValues(count: 10))
    func testRandomBelowRangeRejected(invalidValue: Double) {
        #expect(invalidValue < 0.1)
        
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 2.5)
        
        switch result {
        case .success(let value):
            Issue.record("Expected failure for \(invalidValue), got success with \(value)")
        case .failure:
            break // Expected
        }
    }
    
    @Test("Property: Random values above range are rejected",
          arguments: generateRandomInvalidAboveValues(count: 10))
    func testRandomAboveRangeRejected(invalidValue: Double) {
        #expect(invalidValue > 5.0)
        
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 2.5)
        
        switch result {
        case .success(let value):
            Issue.record("Expected failure for \(invalidValue), got success with \(value)")
        case .failure:
            break // Expected
        }
    }
    
    // MARK: - Property Tests: Configuration Retains Previous Value on Failure
    
    @Test("Property: Configuration retains previous value when invalid value below range is rejected",
          arguments: invalidValuesBelowRange)
    func testConfigurationRetainsPreviousValueForBelowRange(invalidValue: Double) {
        let previousValue = 2.0
        var config = WeeklyOptionConfiguration(premiumPct: previousValue)
        
        // Act: Attempt to update with invalid value
        let result = validationService.updatePremiumPct(invalidValue, in: &config)
        
        // Assert: Update SHALL fail and configuration SHALL retain previous value
        switch result {
        case .success:
            Issue.record("Expected failure for invalid value \(invalidValue)")
        case .failure:
            // Configuration should retain previous value
            #expect(abs(config.premiumPct - previousValue) < 0.001,
                    "Configuration should retain \(previousValue), but got \(config.premiumPct)")
        }
    }
    
    @Test("Property: Configuration retains previous value when invalid value above range is rejected",
          arguments: invalidValuesAboveRange)
    func testConfigurationRetainsPreviousValueForAboveRange(invalidValue: Double) {
        let previousValue = 3.5
        var config = WeeklyOptionConfiguration(premiumPct: previousValue)
        
        // Act: Attempt to update with invalid value
        let result = validationService.updatePremiumPct(invalidValue, in: &config)
        
        // Assert: Update SHALL fail and configuration SHALL retain previous value
        switch result {
        case .success:
            Issue.record("Expected failure for invalid value \(invalidValue)")
        case .failure:
            // Configuration should retain previous value
            #expect(abs(config.premiumPct - previousValue) < 0.001,
                    "Configuration should retain \(previousValue), but got \(config.premiumPct)")
        }
    }
    
    @Test("Property: Configuration retains various previous values on invalid input",
          arguments: [
            (0.0, 0.5), (0.0, 1.0), (0.0, 5.0), // Zero with various previous
            (-1.0, 0.1), (-1.0, 2.5), (-1.0, 4.9), // Negative with various previous
            (5.1, 0.1), (5.1, 2.5), (5.1, 5.0), // Just above max with various previous
            (10.0, 1.0), (100.0, 3.0), (0.05, 4.0) // Various invalid with various previous
          ])
    func testConfigurationRetainsVariousPreviousValues(invalidValue: Double, previousValue: Double) {
        var config = WeeklyOptionConfiguration(premiumPct: previousValue)
        
        // Act
        let result = validationService.updatePremiumPct(invalidValue, in: &config)
        
        // Assert
        switch result {
        case .success:
            Issue.record("Expected failure for invalid value \(invalidValue)")
        case .failure:
            #expect(abs(config.premiumPct - previousValue) < 0.001,
                    "Configuration should retain \(previousValue) after invalid \(invalidValue), but got \(config.premiumPct)")
        }
    }
    
    // MARK: - Property Tests: Error Message Contains Valid Range Information
    
    @Test("Property: Error message indicates valid range for values below range",
          arguments: invalidValuesBelowRange)
    func testErrorMessageIndicatesValidRangeForBelowValues(invalidValue: Double) {
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 0.5)
        
        if case .failure(let error) = result {
            if case .valueOutOfRange(_, let message) = error {
                // Error message should mention the valid range boundaries
                #expect(message.contains("0.1") && message.contains("5.0"),
                        "Error message should indicate valid range [0.1, 5.0]: \(message)")
            }
        }
    }
    
    @Test("Property: Error message indicates valid range for values above range",
          arguments: invalidValuesAboveRange)
    func testErrorMessageIndicatesValidRangeForAboveValues(invalidValue: Double) {
        let result = validationService.validatePremiumPct(invalidValue, currentValue: 0.5)
        
        if case .failure(let error) = result {
            if case .valueOutOfRange(_, let message) = error {
                // Error message should mention the valid range boundaries
                #expect(message.contains("0.1") && message.contains("5.0"),
                        "Error message should indicate valid range [0.1, 5.0]: \(message)")
            }
        }
    }
    
    // MARK: - Property Tests: WeeklyOptionConfiguration Static Validation
    
    @Test("Property: WeeklyOptionConfiguration.validatePremiumPct rejects invalid values",
          arguments: allInvalidValues)
    func testStaticValidationRejectsInvalidValues(invalidValue: Double) {
        // Act
        let error = WeeklyOptionConfiguration.validatePremiumPct(invalidValue)
        
        // Assert: Error should be present for invalid values
        #expect(error != nil,
                "Expected error for invalid value \(invalidValue), but got nil")
    }
    
    @Test("Property: Invalid configuration fails full validation",
          arguments: allInvalidValues)
    func testInvalidConfigurationFailsFullValidation(invalidPremium: Double) {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: invalidPremium,
            onlyOrders: false
        )
        
        // Act
        let result = validationService.validateConfiguration(config)
        
        // Assert
        switch result {
        case .success:
            Issue.record("Expected invalid config with premium \(invalidPremium) to fail validation")
        case .failure:
            // Expected - validation should fail
            break
        }
    }
    
    // MARK: - Property Tests: Boundary Conditions
    
    @Test("Property: Value just below lower boundary (0.099) is rejected")
    func testJustBelowLowerBoundaryRejected() {
        let justBelow = 0.099
        
        let result = validationService.validatePremiumPct(justBelow, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            Issue.record("Expected failure for \(justBelow), got success with \(value)")
        case .failure:
            // Expected
            break
        }
    }
    
    @Test("Property: Value just above upper boundary (5.001) is rejected")
    func testJustAboveUpperBoundaryRejected() {
        let justAbove = 5.001
        
        let result = validationService.validatePremiumPct(justAbove, currentValue: 0.5)
        
        switch result {
        case .success(let value):
            Issue.record("Expected failure for \(justAbove), got success with \(value)")
        case .failure:
            // Expected
            break
        }
    }
    
    @Test("Property: Zero is rejected")
    func testZeroRejected() {
        let zero = 0.0
        var config = WeeklyOptionConfiguration(premiumPct: 1.0)
        
        let result = validationService.updatePremiumPct(zero, in: &config)
        
        switch result {
        case .success:
            Issue.record("Expected zero to be rejected")
        case .failure:
            #expect(abs(config.premiumPct - 1.0) < 0.001,
                    "Configuration should retain 1.0 after rejecting zero")
        }
    }
    
    @Test("Property: Negative values are rejected")
    func testNegativeValuesRejected() {
        let negativeValues = [-0.1, -1.0, -5.0, -100.0, -0.5]
        var config = WeeklyOptionConfiguration(premiumPct: 2.5)
        
        for negValue in negativeValues {
            let result = validationService.updatePremiumPct(negValue, in: &config)
            
            switch result {
            case .success:
                Issue.record("Expected negative value \(negValue) to be rejected")
            case .failure:
                #expect(abs(config.premiumPct - 2.5) < 0.001,
                        "Configuration should retain 2.5 after rejecting \(negValue)")
            }
        }
    }
    
    // MARK: - Property Tests: Configuration isValid Check
    
    @Test("Property: Configuration with invalid premium reports isValid = false",
          arguments: allInvalidValues)
    func testConfigurationIsInvalidWithInvalidPremium(invalidPremium: Double) {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: invalidPremium,
            onlyOrders: false
        )
        
        #expect(!config.isValid,
                "Configuration with invalid premium \(invalidPremium) should not be valid")
    }
    
    // MARK: - Property Tests: Special Edge Cases
    
    @Test("Property: Infinity values are rejected")
    func testInfinityValuesRejected() {
        let infinityValues = [Double.infinity, -Double.infinity]
        var config = WeeklyOptionConfiguration(premiumPct: 1.0)
        
        for infValue in infinityValues {
            let result = validationService.updatePremiumPct(infValue, in: &config)
            
            switch result {
            case .success:
                Issue.record("Expected infinity value \(infValue) to be rejected")
            case .failure:
                #expect(abs(config.premiumPct - 1.0) < 0.001,
                        "Configuration should retain 1.0 after rejecting infinity")
            }
        }
    }
    
    @Test("Property: NaN is rejected")
    func testNaNRejected() {
        let nanValue = Double.nan
        var config = WeeklyOptionConfiguration(premiumPct: 1.0)
        
        let result = validationService.updatePremiumPct(nanValue, in: &config)
        
        switch result {
        case .success:
            Issue.record("Expected NaN to be rejected")
        case .failure:
            #expect(abs(config.premiumPct - 1.0) < 0.001,
                    "Configuration should retain 1.0 after rejecting NaN")
        }
    }
}

// MARK: - Random Value Generator for Property Tests

/// Generates random values for configuration property testing
enum ConfigurationRandomGenerator {
    
    /// Generate a random valid premium percentage (0.1 to 5.0)
    static func randomValidPremiumPct() -> Double {
        let stepCount = Int.random(in: 1...50)
        return Double(stepCount) / 10.0
    }
    
    /// Generate a random invalid premium percentage (below range)
    static func randomInvalidPremiumPctBelow() -> Double {
        let options: [Double] = [
            0.0,
            -0.1,
            -1.0,
            0.05,
            0.09,
            0.01,
            -5.0,
            -100.0,
            Double.random(in: -100.0..<0.1)
        ]
        return options.randomElement()!
    }
    
    /// Generate a random invalid premium percentage (above range)
    static func randomInvalidPremiumPctAbove() -> Double {
        let options: [Double] = [
            5.1,
            5.01,
            6.0,
            10.0,
            100.0,
            Double.random(in: 5.001...100.0)
        ]
        return options.randomElement()!
    }
    
    /// Generate a batch of valid premium values
    static func generateValidPremiumBatch(count: Int) -> [Double] {
        return (0..<count).map { _ in randomValidPremiumPct() }
    }
    
    /// Generate a batch of invalid premium values (below range)
    static func generateInvalidBelowBatch(count: Int) -> [Double] {
        return (0..<count).map { _ in randomInvalidPremiumPctBelow() }
    }
    
    /// Generate a batch of invalid premium values (above range)
    static func generateInvalidAboveBatch(count: Int) -> [Double] {
        return (0..<count).map { _ in randomInvalidPremiumPctAbove() }
    }
}


// MARK: - Property 7: Configuration Persistence Round Trip
// **Validates: Requirements 4.6, 4.7**
//
// *For any* valid strategy configuration (with valid WINDOW_DAYS, LOOKBACK_DAYS,
// PREMIUM_PCT, and ONLY_ORDERS values), saving the configuration and then
// retrieving it SHALL return a configuration with identical parameter values.

@Suite("Property 7: Configuration Persistence Round Trip - Validates Requirements 4.6, 4.7")
struct ConfigurationPersistenceRoundTripPropertyTests {
    
    // MARK: - Valid Value Constants
    
    /// Valid WINDOW_DAYS values: 1, 5, or 30
    static let validWindowDays = [1, 5, 30]
    
    /// Valid LOOKBACK_DAYS values: 30, 60, 90, 180, or 360
    static let validLookbackDays = [30, 60, 90, 180, 360]
    
    /// Valid ONLY_ORDERS values: true or false
    static let validOnlyOrders = [true, false]
    
    /// Sample count for random property tests
    static let sampleCount = 50
    
    // MARK: - Configuration Generation
    
    /// Generates all valid premium percentage values at 0.1 step increments (0.1 to 5.0)
    static let allValidPremiumPctValues: [Double] = {
        var values: [Double] = []
        var current = 0.1
        while current <= 5.0 + 0.001 {
            values.append((current * 10).rounded() / 10)
            current += 0.1
        }
        return values
    }()
    
    /// Generates a random valid premium percentage value
    static func randomValidPremiumPct() -> Double {
        let stepCount = Int.random(in: 1...50)
        return Double(stepCount) / 10.0
    }
    
    /// Generates a random valid configuration with all valid parameter values
    static func generateRandomValidConfiguration() -> WeeklyOptionConfiguration {
        WeeklyOptionConfiguration(
            windowDays: validWindowDays.randomElement()!,
            lookbackDays: validLookbackDays.randomElement()!,
            premiumPct: randomValidPremiumPct(),
            onlyOrders: validOnlyOrders.randomElement()!
        )
    }
    
    /// Generates a batch of random valid configurations
    static func generateRandomConfigurations(count: Int) -> [WeeklyOptionConfiguration] {
        return (0..<count).map { _ in generateRandomValidConfiguration() }
    }
    
    /// All valid combinations of WINDOW_DAYS and LOOKBACK_DAYS
    static let allWindowLookbackCombinations: [(Int, Int)] = {
        var combinations: [(Int, Int)] = []
        for windowDay in validWindowDays {
            for lookbackDay in validLookbackDays {
                combinations.append((windowDay, lookbackDay))
            }
        }
        return combinations
    }()
    
    /// Sample configurations covering boundary values
    static let boundaryConfigurations: [WeeklyOptionConfiguration] = [
        // Minimum values
        WeeklyOptionConfiguration(windowDays: 1, lookbackDays: 30, premiumPct: 0.1, onlyOrders: false),
        // Maximum values
        WeeklyOptionConfiguration(windowDays: 30, lookbackDays: 360, premiumPct: 5.0, onlyOrders: true),
        // Mixed boundaries
        WeeklyOptionConfiguration(windowDays: 1, lookbackDays: 360, premiumPct: 0.1, onlyOrders: true),
        WeeklyOptionConfiguration(windowDays: 30, lookbackDays: 30, premiumPct: 5.0, onlyOrders: false),
        // Default values
        WeeklyOptionConfiguration(windowDays: 5, lookbackDays: 180, premiumPct: 0.5, onlyOrders: false)
    ]
    
    // MARK: - Property Tests: Round Trip with Mock Cloud Client
    
    @Test("Property: Configuration round trip preserves all parameters with mock cloud",
          arguments: generateRandomConfigurations(count: 10))
    func testRoundTripPreservesAllParametersWithMockCloud(config: WeeklyOptionConfiguration) async throws {
        // Arrange
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-roundtrip-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "test-user-\(UUID().uuidString)"
        let strategyConfig = config.toStrategyConfiguration()
        
        // Precondition: Configuration should be valid
        #expect(config.isValid, "Test configuration must be valid")
        
        // Act: Save the configuration
        let saveResult = try await repository.save(configuration: strategyConfig, for: userId)
        
        // Assert: Save should succeed
        #expect(saveResult.success, "Save operation should succeed")
        #expect(saveResult.savedAt != nil, "Save result should include timestamp")
        
        // Act: Load the configuration back
        let loadedConfig = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        
        // Convert back to WeeklyOptionConfiguration for comparison
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert: All parameter values SHALL be identical
        #expect(loadedWeeklyConfig.windowDays == config.windowDays,
                "WINDOW_DAYS: expected \(config.windowDays), got \(loadedWeeklyConfig.windowDays)")
        #expect(loadedWeeklyConfig.lookbackDays == config.lookbackDays,
                "LOOKBACK_DAYS: expected \(config.lookbackDays), got \(loadedWeeklyConfig.lookbackDays)")
        #expect(abs(loadedWeeklyConfig.premiumPct - config.premiumPct) < 0.001,
                "PREMIUM_PCT: expected \(config.premiumPct), got \(loadedWeeklyConfig.premiumPct)")
        #expect(loadedWeeklyConfig.onlyOrders == config.onlyOrders,
                "ONLY_ORDERS: expected \(config.onlyOrders), got \(loadedWeeklyConfig.onlyOrders)")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    @Test("Property: Boundary configurations round trip correctly",
          arguments: boundaryConfigurations)
    func testBoundaryConfigurationsRoundTrip(config: WeeklyOptionConfiguration) async throws {
        // Arrange
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-boundary-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "boundary-test-user-\(UUID().uuidString)"
        let strategyConfig = config.toStrategyConfiguration()
        
        // Act: Save
        let saveResult = try await repository.save(configuration: strategyConfig, for: userId)
        #expect(saveResult.success)
        
        // Act: Load
        let loadedConfig = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert: All values identical
        #expect(loadedWeeklyConfig.windowDays == config.windowDays)
        #expect(loadedWeeklyConfig.lookbackDays == config.lookbackDays)
        #expect(abs(loadedWeeklyConfig.premiumPct - config.premiumPct) < 0.001)
        #expect(loadedWeeklyConfig.onlyOrders == config.onlyOrders)
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: Round Trip with Local Storage Only
    
    @Test("Property: Configuration round trip works with local storage only",
          arguments: generateRandomConfigurations(count: 30))
    func testRoundTripWithLocalStorageOnly(config: WeeklyOptionConfiguration) async throws {
        // Arrange: Use local-only repository (no cloud client)
        let testDefaults = UserDefaults(suiteName: "test-local-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTesting(localStorage: testDefaults)
        let userId = "local-test-user-\(UUID().uuidString)"
        
        // Preload the cache to simulate a previously saved configuration
        let strategyConfig = config.toStrategyConfiguration()
        repository.preloadCache(userId: userId, configuration: strategyConfig)
        
        // Act: Load from cache
        let loadedConfig = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert: All values identical
        #expect(loadedWeeklyConfig.windowDays == config.windowDays,
                "WINDOW_DAYS mismatch in local storage round trip")
        #expect(loadedWeeklyConfig.lookbackDays == config.lookbackDays,
                "LOOKBACK_DAYS mismatch in local storage round trip")
        #expect(abs(loadedWeeklyConfig.premiumPct - config.premiumPct) < 0.001,
                "PREMIUM_PCT mismatch in local storage round trip")
        #expect(loadedWeeklyConfig.onlyOrders == config.onlyOrders,
                "ONLY_ORDERS mismatch in local storage round trip")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: All WINDOW_DAYS and LOOKBACK_DAYS Combinations
    
    @Test("Property: All WINDOW_DAYS and LOOKBACK_DAYS combinations round trip correctly",
          arguments: allWindowLookbackCombinations)
    func testAllWindowLookbackCombinationsRoundTrip(combination: (Int, Int)) async throws {
        let (windowDays, lookbackDays) = combination
        
        // Arrange
        let config = WeeklyOptionConfiguration(
            windowDays: windowDays,
            lookbackDays: lookbackDays,
            premiumPct: 1.5,
            onlyOrders: true
        )
        
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-combo-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "combo-test-\(windowDays)-\(lookbackDays)"
        
        // Act: Save and load
        let saveResult = try await repository.save(
            configuration: config.toStrategyConfiguration(),
            for: userId
        )
        #expect(saveResult.success)
        
        let loadedConfig = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert
        #expect(loadedWeeklyConfig.windowDays == windowDays,
                "WINDOW_DAYS=\(windowDays) not preserved")
        #expect(loadedWeeklyConfig.lookbackDays == lookbackDays,
                "LOOKBACK_DAYS=\(lookbackDays) not preserved")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: All Valid PREMIUM_PCT Values
    
    @Test("Property: All valid PREMIUM_PCT step values round trip correctly",
          arguments: allValidPremiumPctValues)
    func testAllPremiumPctValuesRoundTrip(premiumPct: Double) async throws {
        // Arrange
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: premiumPct,
            onlyOrders: false
        )
        
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-premium-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "premium-test-\(premiumPct)"
        
        // Act: Save and load
        let saveResult = try await repository.save(
            configuration: config.toStrategyConfiguration(),
            for: userId
        )
        #expect(saveResult.success)
        
        let loadedConfig = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert: Premium PCT should be preserved exactly
        #expect(abs(loadedWeeklyConfig.premiumPct - premiumPct) < 0.001,
                "PREMIUM_PCT=\(premiumPct) not preserved, got \(loadedWeeklyConfig.premiumPct)")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: ONLY_ORDERS Toggle
    
    @Test("Property: ONLY_ORDERS true and false round trip correctly",
          arguments: validOnlyOrders)
    func testOnlyOrdersRoundTrip(onlyOrders: Bool) async throws {
        // Arrange
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 90,
            premiumPct: 2.5,
            onlyOrders: onlyOrders
        )
        
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-onlyorders-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "onlyorders-test-\(onlyOrders)"
        
        // Act: Save and load
        let saveResult = try await repository.save(
            configuration: config.toStrategyConfiguration(),
            for: userId
        )
        #expect(saveResult.success)
        
        let loadedConfig = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert: ONLY_ORDERS should be preserved
        #expect(loadedWeeklyConfig.onlyOrders == onlyOrders,
                "ONLY_ORDERS=\(onlyOrders) not preserved, got \(loadedWeeklyConfig.onlyOrders)")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: Multiple Save/Load Cycles
    
    @Test("Property: Multiple save/load cycles preserve configuration",
          arguments: generateRandomConfigurations(count: 20))
    func testMultipleSaveLoadCyclesPreserveConfiguration(config: WeeklyOptionConfiguration) async throws {
        // Arrange
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-multicycle-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "multicycle-test-\(UUID().uuidString)"
        
        var currentConfig = config
        
        // Act: Perform multiple save/load cycles
        for cycle in 1...3 {
            let saveResult = try await repository.save(
                configuration: currentConfig.toStrategyConfiguration(),
                for: userId
            )
            #expect(saveResult.success, "Cycle \(cycle): Save should succeed")
            
            let loadedConfig = try await repository.load(
                strategyId: WeeklyOptionConfiguration.strategyId,
                for: userId
            )
            let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
            
            // Assert: Configuration should be identical after each cycle
            #expect(loadedWeeklyConfig.windowDays == currentConfig.windowDays,
                    "Cycle \(cycle): WINDOW_DAYS mismatch")
            #expect(loadedWeeklyConfig.lookbackDays == currentConfig.lookbackDays,
                    "Cycle \(cycle): LOOKBACK_DAYS mismatch")
            #expect(abs(loadedWeeklyConfig.premiumPct - currentConfig.premiumPct) < 0.001,
                    "Cycle \(cycle): PREMIUM_PCT mismatch")
            #expect(loadedWeeklyConfig.onlyOrders == currentConfig.onlyOrders,
                    "Cycle \(cycle): ONLY_ORDERS mismatch")
            
            currentConfig = loadedWeeklyConfig
        }
        
        // Final assertion: Configuration should still match original
        #expect(currentConfig.windowDays == config.windowDays)
        #expect(currentConfig.lookbackDays == config.lookbackDays)
        #expect(abs(currentConfig.premiumPct - config.premiumPct) < 0.001)
        #expect(currentConfig.onlyOrders == config.onlyOrders)
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: Different Users Have Isolated Configurations
    
    @Test("Property: Different users have isolated configurations")
    func testDifferentUsersHaveIsolatedConfigurations() async throws {
        // Arrange
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-isolation-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        
        let user1Id = "user-1-\(UUID().uuidString)"
        let user2Id = "user-2-\(UUID().uuidString)"
        
        let user1Config = WeeklyOptionConfiguration(
            windowDays: 1,
            lookbackDays: 30,
            premiumPct: 0.5,
            onlyOrders: false
        )
        
        let user2Config = WeeklyOptionConfiguration(
            windowDays: 30,
            lookbackDays: 360,
            premiumPct: 4.5,
            onlyOrders: true
        )
        
        // Act: Save different configurations for different users
        _ = try await repository.save(
            configuration: user1Config.toStrategyConfiguration(),
            for: user1Id
        )
        _ = try await repository.save(
            configuration: user2Config.toStrategyConfiguration(),
            for: user2Id
        )
        
        // Load configurations for each user
        let loadedUser1Config = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: user1Id
        )
        let loadedUser2Config = try await repository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: user2Id
        )
        
        let loadedUser1Weekly = WeeklyOptionConfiguration.from(loadedUser1Config)
        let loadedUser2Weekly = WeeklyOptionConfiguration.from(loadedUser2Config)
        
        // Assert: Each user's configuration is independent
        #expect(loadedUser1Weekly.windowDays == user1Config.windowDays)
        #expect(loadedUser1Weekly.lookbackDays == user1Config.lookbackDays)
        #expect(abs(loadedUser1Weekly.premiumPct - user1Config.premiumPct) < 0.001)
        #expect(loadedUser1Weekly.onlyOrders == user1Config.onlyOrders)
        
        #expect(loadedUser2Weekly.windowDays == user2Config.windowDays)
        #expect(loadedUser2Weekly.lookbackDays == user2Config.lookbackDays)
        #expect(abs(loadedUser2Weekly.premiumPct - user2Config.premiumPct) < 0.001)
        #expect(loadedUser2Weekly.onlyOrders == user2Config.onlyOrders)
        
        // Assert: Configurations are different
        #expect(loadedUser1Weekly != loadedUser2Weekly,
                "Different users should have different configurations")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: Configuration Save Provides Confirmation (Req 4.6)
    
    @Test("Property: Successful save returns confirmation with timestamp",
          arguments: generateRandomConfigurations(count: 20))
    func testSuccessfulSaveReturnsConfirmation(config: WeeklyOptionConfiguration) async throws {
        // Arrange
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-confirmation-\(UUID().uuidString)")!
        let repository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        let userId = "confirmation-test-\(UUID().uuidString)"
        let beforeSave = Date()
        
        // Act: Save the configuration
        let saveResult = try await repository.save(
            configuration: config.toStrategyConfiguration(),
            for: userId
        )
        let afterSave = Date()
        
        // Assert: Confirmation indicator provided (Requirement 4.6)
        #expect(saveResult.success, "Save should succeed and provide success confirmation")
        #expect(saveResult.savedAt != nil, "Save result should include timestamp")
        
        // Timestamp should be reasonable
        if let savedAt = saveResult.savedAt {
            #expect(savedAt >= beforeSave, "Saved timestamp should be after operation start")
            #expect(savedAt <= afterSave, "Saved timestamp should be before operation end")
        }
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
    
    // MARK: - Property Tests: Previously Saved Values Loaded (Req 4.7)
    
    @Test("Property: Previously saved configuration is loaded on return",
          arguments: generateRandomConfigurations(count: 20))
    func testPreviouslySavedConfigurationLoadedOnReturn(config: WeeklyOptionConfiguration) async throws {
        // Arrange: Simulate first session - save configuration
        let mockClient = MockCloudDatabaseClient()
        let testDefaults = UserDefaults(suiteName: "test-return-\(UUID().uuidString)")!
        let userId = "return-test-\(UUID().uuidString)"
        
        // First "session" - save configuration
        let firstRepository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        _ = try await firstRepository.save(
            configuration: config.toStrategyConfiguration(),
            for: userId
        )
        
        // Second "session" - create new repository instance to simulate return
        let secondRepository = ConfigurationRepositoryImpl.forTestingWithMock(
            mockClient: mockClient,
            localStorage: testDefaults
        )
        
        // Act: Load configuration in new session
        let loadedConfig = try await secondRepository.load(
            strategyId: WeeklyOptionConfiguration.strategyId,
            for: userId
        )
        let loadedWeeklyConfig = WeeklyOptionConfiguration.from(loadedConfig)
        
        // Assert: Previously saved values are loaded (Requirement 4.7)
        #expect(loadedWeeklyConfig.windowDays == config.windowDays,
                "Previously saved WINDOW_DAYS should be loaded")
        #expect(loadedWeeklyConfig.lookbackDays == config.lookbackDays,
                "Previously saved LOOKBACK_DAYS should be loaded")
        #expect(abs(loadedWeeklyConfig.premiumPct - config.premiumPct) < 0.001,
                "Previously saved PREMIUM_PCT should be loaded")
        #expect(loadedWeeklyConfig.onlyOrders == config.onlyOrders,
                "Previously saved ONLY_ORDERS should be loaded")
        
        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
}
