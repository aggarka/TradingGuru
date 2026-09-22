//
//  WeeklyOptionStrategyTests.swift
//  TradingGuruTests
//
//  Property-based tests for WeeklyOptionStrategy target calculations.
//  Tests correctness properties 11 and 12 from the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 12: Put Target Calculation
// **Validates: Requirements 5.2**
//
// *For any* positive currentPrice `P` and worstReturnPct `R`, the put target
// SHALL equal `P × (1 + R/100)`.
// Note: worstReturnPct is typically negative (e.g., -10 for a 10% loss)
// Edge case: Non-positive currentPrice should return 0

@Suite("Property 12: Put Target Calculation - Validates Requirements 5.2")
struct PutTargetCalculationPropertyTests {
    
    // MARK: - Helper Methods
    
    /// Calculates the expected put target using the formula from requirements:
    /// putTarget = currentPrice × (1 + worstReturnPct / 100)
    static func expectedPutTarget(currentPrice: Double, worstReturnPct: Double) -> Double {
        guard currentPrice > 0 else { return 0 }
        return currentPrice * (1 + worstReturnPct / 100.0)
    }
    
    /// Compares two doubles with tolerance for floating point precision
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.000001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    // MARK: - Property Tests: Put Target Formula Correctness
    
    @Test("Property: Put target equals currentPrice × (1 + worstReturnPct / 100) for standard prices",
          arguments: [
              // Standard prices with various negative return percentages
              (currentPrice: 100.0, worstReturnPct: -5.0),
              (currentPrice: 100.0, worstReturnPct: -10.0),
              (currentPrice: 100.0, worstReturnPct: -15.0),
              (currentPrice: 100.0, worstReturnPct: -20.0),
              (currentPrice: 150.0, worstReturnPct: -5.0),
              (currentPrice: 150.0, worstReturnPct: -10.0),
              (currentPrice: 200.0, worstReturnPct: -15.0),
              (currentPrice: 200.0, worstReturnPct: -20.0),
          ])
    func testPutTargetFormulaWithStandardPrices(currentPrice: Double, worstReturnPct: Double) {
        // Calculate expected result using the formula from requirements
        let expected = Self.expectedPutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        // Calculate actual result using WeeklyOptionStrategy
        let actual = WeeklyOptionStrategy.calculatePutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        // Assert: Put target SHALL equal the formula result
        #expect(Self.areEqual(actual, expected),
                "Put target for price=\(currentPrice), worstReturn=\(worstReturnPct)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Put target is below current price for negative return percentages",
          arguments: [
              (currentPrice: 100.0, worstReturnPct: -5.0),
              (currentPrice: 100.0, worstReturnPct: -10.0),
              (currentPrice: 150.0, worstReturnPct: -15.0),
              (currentPrice: 200.0, worstReturnPct: -20.0),
              (currentPrice: 50.0, worstReturnPct: -8.0),
          ])
    func testPutTargetBelowCurrentPriceForNegativeReturns(currentPrice: Double, worstReturnPct: Double) {
        // Precondition: worst return percentage is negative
        #expect(worstReturnPct < 0)
        
        let putTarget = WeeklyOptionStrategy.calculatePutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        // Assert: Put target should be below current price for negative returns
        #expect(putTarget < currentPrice,
                "Put target \(putTarget) should be < current price \(currentPrice) for negative return \(worstReturnPct)%")
    }
    
    // MARK: - Edge Case: Zero Current Price
    
    @Test("Property: Put target returns 0 when currentPrice is 0")
    func testPutTargetReturnsZeroForZeroPrice() {
        let currentPrice = 0.0
        let worstReturnPct = -10.0
        
        let putTarget = WeeklyOptionStrategy.calculatePutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        #expect(putTarget == 0,
                "Put target should be 0 when currentPrice is 0, got \(putTarget)")
    }
    
    // MARK: - Edge Case: Negative Current Price
    
    @Test("Property: Put target returns 0 when currentPrice is negative",
          arguments: [
              (currentPrice: -1.0, worstReturnPct: -10.0),
              (currentPrice: -50.0, worstReturnPct: -5.0),
              (currentPrice: -100.0, worstReturnPct: -20.0),
          ])
    func testPutTargetReturnsZeroForNegativePrice(currentPrice: Double, worstReturnPct: Double) {
        // Precondition: price is negative
        #expect(currentPrice < 0)
        
        let putTarget = WeeklyOptionStrategy.calculatePutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        #expect(putTarget == 0,
                "Put target should be 0 when currentPrice is negative (\(currentPrice)), got \(putTarget)")
    }
    
    // MARK: - Property Tests: Mathematical Correctness
    
    @Test("Property: Put target calculation produces mathematically correct results",
          arguments: [
              // (currentPrice, worstReturnPct, expectedTarget)
              (100.0, -10.0, 90.0),      // 100 × (1 + (-10/100)) = 100 × 0.9 = 90
              (100.0, -5.0, 95.0),       // 100 × (1 + (-5/100)) = 100 × 0.95 = 95
              (200.0, -20.0, 160.0),     // 200 × (1 + (-20/100)) = 200 × 0.8 = 160
              (150.0, -15.0, 127.5),     // 150 × (1 + (-15/100)) = 150 × 0.85 = 127.5
              (50.0, -8.0, 46.0),        // 50 × (1 + (-8/100)) = 50 × 0.92 = 46
          ])
    func testPutTargetKnownCalculations(input: (currentPrice: Double, worstReturnPct: Double, expectedTarget: Double)) {
        let actual = WeeklyOptionStrategy.calculatePutTarget(
            currentPrice: input.currentPrice,
            worstReturnPct: input.worstReturnPct
        )
        
        #expect(Self.areEqual(actual, input.expectedTarget),
                "Price=\(input.currentPrice), Return=\(input.worstReturnPct)%: expected \(input.expectedTarget), got \(actual)")
    }
    
    // MARK: - Property Tests: Positive Return Percentage (Edge Case)
    
    @Test("Property: Put target is above current price when worst return is positive (unusual case)",
          arguments: [
              (currentPrice: 100.0, worstReturnPct: 5.0),
              (currentPrice: 100.0, worstReturnPct: 10.0),
          ])
    func testPutTargetWithPositiveReturn(currentPrice: Double, worstReturnPct: Double) {
        // Note: A positive "worst" return is unusual but the formula should still work
        #expect(worstReturnPct > 0)
        
        let putTarget = WeeklyOptionStrategy.calculatePutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        // For positive return, put target should be above current price
        #expect(putTarget > currentPrice,
                "Put target \(putTarget) should be > current price \(currentPrice) for positive return \(worstReturnPct)%")
        
        // Verify formula correctness
        let expected = Self.expectedPutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        #expect(Self.areEqual(putTarget, expected),
                "Put target should match formula: expected \(expected), got \(putTarget)")
    }
    
    // MARK: - Property Tests: Zero Return Percentage
    
    @Test("Property: Put target equals current price when worst return is 0%")
    func testPutTargetEqualsCurrentPriceForZeroReturn() {
        let currentPrice = 100.0
        let worstReturnPct = 0.0
        
        let putTarget = WeeklyOptionStrategy.calculatePutTarget(currentPrice: currentPrice, worstReturnPct: worstReturnPct)
        
        #expect(Self.areEqual(putTarget, currentPrice),
                "Put target should equal current price for 0% return: expected \(currentPrice), got \(putTarget)")
    }
}
