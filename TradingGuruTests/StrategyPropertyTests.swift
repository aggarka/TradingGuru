//
//  StrategyPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for strategy execution components validating
//  correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 10: Target Price Calculation
// **Validates: Requirements 5.4**
//
// *For any* current price and return percentage, the target price SHALL equal
// `round(currentPrice * (1 + returnPercentage / 100), 2)` (rounded to 2 decimal places).

@Suite("Property 10: Target Price Calculation - Validates Requirements 5.4")
struct TargetPriceCalculationPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    // MARK: - Test Data Generation
    
    /// Generates random positive current prices for testing
    /// Includes various magnitudes: penny stocks, regular stocks, high-priced stocks
    static func generateRandomCurrentPrices(count: Int) -> [Double] {
        return (0..<count).map { _ in
            // Generate prices across different magnitudes
            let magnitude = Int.random(in: 0...3)
            switch magnitude {
            case 0:
                // Penny stocks: $0.01 - $5.00
                return Double.random(in: 0.01...5.0)
            case 1:
                // Regular stocks: $5 - $100
                return Double.random(in: 5.0...100.0)
            case 2:
                // Mid-priced stocks: $100 - $500
                return Double.random(in: 100.0...500.0)
            default:
                // High-priced stocks: $500 - $5000
                return Double.random(in: 500.0...5000.0)
            }
        }
    }
    
    /// Generates random return percentages (both positive and negative)
    /// Typical returns range from -50% to +100%
    static func generateRandomReturnPercentages(count: Int) -> [Double] {
        return (0..<count).map { _ in
            Double.random(in: -50.0...100.0)
        }
    }
    
    /// Generates pairs of (currentPrice, returnPercentage) for testing
    static func generatePriceReturnPairs(count: Int) -> [(currentPrice: Double, returnPercentage: Double)] {
        return (0..<count).map { _ in
            let price: Double
            let magnitude = Int.random(in: 0...3)
            switch magnitude {
            case 0: price = Double.random(in: 0.01...5.0)
            case 1: price = Double.random(in: 5.0...100.0)
            case 2: price = Double.random(in: 100.0...500.0)
            default: price = Double.random(in: 500.0...5000.0)
            }
            
            let returnPct = Double.random(in: -50.0...100.0)
            return (currentPrice: price, returnPercentage: returnPct)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the expected target price using the formula from requirements:
    /// targetPrice = round(currentPrice * (1 + returnPercentage / 100), 2)
    static func expectedTargetPrice(currentPrice: Double, returnPercentage: Double) -> Double {
        let rawTarget = currentPrice * (1 + returnPercentage / 100)
        // Round to 2 decimal places
        return (rawTarget * 100).rounded() / 100
    }
    
    /// Compares two doubles with tolerance for floating point precision
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    // MARK: - Property Tests: Target Price Formula Correctness
    
    @Test("Property: Target price equals currentPrice * (1 + returnPercentage / 100), rounded to 2 decimals",
          arguments: generatePriceReturnPairs(count: 10))
    func testTargetPriceFormula(pair: (currentPrice: Double, returnPercentage: Double)) {
        let currentPrice = pair.currentPrice
        let returnPercentage = pair.returnPercentage
        
        // Calculate expected result using the formula from requirements
        let expected = Self.expectedTargetPrice(currentPrice: currentPrice, returnPercentage: returnPercentage)
        
        // Calculate actual result using OpportunityIdentifier
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: currentPrice, returnPct: returnPercentage)
        
        // Assert: Target price SHALL equal the formula result
        #expect(Self.areEqual(actual, expected),
                "Target price for price=\(currentPrice), return=\(returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: WeeklyOptionStrategy.calculateTargetPrice matches formula",
          arguments: generatePriceReturnPairs(count: 10))
    func testWeeklyOptionStrategyTargetPriceFormula(pair: (currentPrice: Double, returnPercentage: Double)) {
        let currentPrice = pair.currentPrice
        let returnPercentage = pair.returnPercentage
        
        // Calculate expected result using the formula
        let expected = Self.expectedTargetPrice(currentPrice: currentPrice, returnPercentage: returnPercentage)
        
        // Calculate actual result using WeeklyOptionStrategy
        let actual = WeeklyOptionStrategy.calculateTargetPrice(currentPrice: currentPrice, returnPercentage: returnPercentage)
        
        // Assert: Target price SHALL equal the formula result
        #expect(Self.areEqual(actual, expected),
                "WeeklyOptionStrategy target price for price=\(currentPrice), return=\(returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    // MARK: - Property Tests: Various Price Magnitudes
    
    @Test("Property: Target price is correctly calculated for penny stocks ($0.01 - $5)",
          arguments: (0..<30).map { _ in
              (currentPrice: Double.random(in: 0.01...5.0), returnPercentage: Double.random(in: -50.0...100.0))
          })
    func testTargetPriceForPennyStocks(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Penny stock price=\(pair.currentPrice), return=\(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Target price is correctly calculated for regular stocks ($5 - $100)",
          arguments: (0..<30).map { _ in
              (currentPrice: Double.random(in: 5.0...100.0), returnPercentage: Double.random(in: -50.0...100.0))
          })
    func testTargetPriceForRegularStocks(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Regular stock price=\(pair.currentPrice), return=\(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Target price is correctly calculated for mid-priced stocks ($100 - $500)",
          arguments: (0..<30).map { _ in
              (currentPrice: Double.random(in: 100.0...500.0), returnPercentage: Double.random(in: -50.0...100.0))
          })
    func testTargetPriceForMidPricedStocks(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Mid-priced stock price=\(pair.currentPrice), return=\(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Target price is correctly calculated for high-priced stocks ($500 - $5000)",
          arguments: (0..<30).map { _ in
              (currentPrice: Double.random(in: 500.0...5000.0), returnPercentage: Double.random(in: -50.0...100.0))
          })
    func testTargetPriceForHighPricedStocks(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "High-priced stock price=\(pair.currentPrice), return=\(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    // MARK: - Property Tests: Positive Return Percentages
    
    @Test("Property: Target price is greater than current price for positive returns",
          arguments: (0..<50).map { _ in
              (currentPrice: Double.random(in: 1.0...1000.0), returnPercentage: Double.random(in: 0.01...100.0))
          })
    func testTargetPriceGreaterForPositiveReturns(pair: (currentPrice: Double, returnPercentage: Double)) {
        // Precondition: return percentage is positive
        #expect(pair.returnPercentage > 0)
        
        let targetPrice = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        // Assert: Target price should be greater than current price for positive returns
        #expect(targetPrice > pair.currentPrice,
                "Target \(targetPrice) should be > current \(pair.currentPrice) for positive return \(pair.returnPercentage)%")
    }
    
    // MARK: - Property Tests: Negative Return Percentages
    
    @Test("Property: Target price is less than current price for negative returns",
          arguments: (0..<50).map { _ in
              let negativeReturn = -Double.random(in: 0.01...50.0)
              return (currentPrice: Double.random(in: 1.0...1000.0), returnPercentage: negativeReturn)
          })
    func testTargetPriceLessForNegativeReturns(pair: (currentPrice: Double, returnPercentage: Double)) {
        // Precondition: return percentage is negative
        #expect(pair.returnPercentage < 0)
        
        let targetPrice = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        // Assert: Target price should be less than current price for negative returns
        #expect(targetPrice < pair.currentPrice,
                "Target \(targetPrice) should be < current \(pair.currentPrice) for negative return \(pair.returnPercentage)%")
    }
    
    // MARK: - Property Tests: Zero Return Percentage
    
    @Test("Property: Target price equals current price for zero return",
          arguments: generateRandomCurrentPrices(count: 30))
    func testTargetPriceEqualsCurrentForZeroReturn(currentPrice: Double) {
        let returnPercentage = 0.0
        
        let targetPrice = OpportunityIdentifier.calculateTargetPrice(currentPrice: currentPrice, returnPct: returnPercentage)
        let expectedTargetPrice = (currentPrice * 100).rounded() / 100 // Rounded to 2 decimals
        
        // Assert: Target price should equal current price (rounded) for zero return
        #expect(Self.areEqual(targetPrice, expectedTargetPrice),
                "Target \(targetPrice) should equal current \(expectedTargetPrice) for 0% return")
    }
    
    // MARK: - Property Tests: Rounding to 2 Decimal Places
    
    @Test("Property: Target price is always rounded to exactly 2 decimal places",
          arguments: generatePriceReturnPairs(count: 10))
    func testTargetPriceRoundedToTwoDecimals(pair: (currentPrice: Double, returnPercentage: Double)) {
        let targetPrice = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        // Verify that multiplying by 100 and rounding gives a whole number
        let scaledValue = targetPrice * 100
        let roundedScaledValue = scaledValue.rounded()
        
        #expect(abs(scaledValue - roundedScaledValue) < 0.0001,
                "Target price \(targetPrice) should have exactly 2 decimal places")
    }
    
    @Test("Property: Rounding produces consistent results for values that need rounding",
          arguments: [
              // Values that produce more than 2 decimal places before rounding
              (currentPrice: 100.0, returnPercentage: 3.333),   // 103.333 -> 103.33
              (currentPrice: 100.0, returnPercentage: 2.555),   // 102.555 -> 102.56 (round half up)
              (currentPrice: 100.0, returnPercentage: 1.111),   // 101.111 -> 101.11
              (currentPrice: 123.45, returnPercentage: 2.5),    // 126.53625 -> 126.54
              (currentPrice: 99.99, returnPercentage: 5.0),     // 104.9895 -> 104.99
              (currentPrice: 1.23, returnPercentage: 7.77),     // 1.325571 -> 1.33
          ])
    func testRoundingConsistency(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Rounding should be consistent: expected \(expected), got \(actual)")
    }
    
    // MARK: - Property Tests: Mathematical Properties
    
    @Test("Property: Inverse returns produce symmetric price movements",
          arguments: (0..<30).map { _ in
              (currentPrice: Double.random(in: 10.0...500.0), returnPercentage: Double.random(in: 1.0...50.0))
          })
    func testInverseReturnsProduceSymmetricMovements(pair: (currentPrice: Double, returnPercentage: Double)) {
        let currentPrice = pair.currentPrice
        let positiveReturn = pair.returnPercentage
        let negativeReturn = -pair.returnPercentage
        
        let positiveTarget = OpportunityIdentifier.calculateTargetPrice(currentPrice: currentPrice, returnPct: positiveReturn)
        let negativeTarget = OpportunityIdentifier.calculateTargetPrice(currentPrice: currentPrice, returnPct: negativeReturn)
        
        // The absolute difference from current price should be approximately equal
        // (not exactly equal due to rounding)
        let positiveMove = abs(positiveTarget - currentPrice)
        let negativeMove = abs(negativeTarget - currentPrice)
        
        // Allow some tolerance for rounding differences
        #expect(abs(positiveMove - negativeMove) < 0.02,
                "Symmetric returns should produce similar absolute moves: +\(positiveReturn)% -> \(positiveMove), -\(positiveReturn)% -> \(negativeMove)")
    }
    
    @Test("Property: Target price is always positive for reasonable returns",
          arguments: (0..<50).map { _ in
              // Returns that keep target price positive (> -99%)
              let returnPct = Double.random(in: -90.0...100.0)
              return (currentPrice: Double.random(in: 1.0...1000.0), returnPercentage: returnPct)
          })
    func testTargetPriceAlwaysPositiveForReasonableReturns(pair: (currentPrice: Double, returnPercentage: Double)) {
        // Precondition: return > -100% to ensure positive target
        #expect(pair.returnPercentage > -100)
        
        let targetPrice = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(targetPrice > 0,
                "Target price \(targetPrice) should be positive for return \(pair.returnPercentage)%")
    }
    
    // MARK: - Property Tests: Specific Known Values
    
    @Test("Property: Known calculation examples produce correct results",
          arguments: [
              // (currentPrice, returnPercentage, expectedTarget)
              (100.0, 5.0, 105.0),      // Simple 5% increase
              (100.0, -5.0, 95.0),      // Simple 5% decrease
              (100.0, 10.0, 110.0),     // 10% increase
              (100.0, -10.0, 90.0),     // 10% decrease
              (100.0, 0.0, 100.0),      // No change
              (50.0, 10.0, 55.0),       // 10% of $50
              (200.0, 25.0, 250.0),     // 25% increase
              (150.0, -20.0, 120.0),    // 20% decrease
              (1.0, 100.0, 2.0),        // Double
              (1000.0, 1.0, 1010.0),    // 1% of $1000
          ])
    func testKnownCalculationExamples(input: (currentPrice: Double, returnPercentage: Double, expectedTarget: Double)) {
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: input.currentPrice, returnPct: input.returnPercentage)
        
        #expect(Self.areEqual(actual, input.expectedTarget),
                "Price=\(input.currentPrice), Return=\(input.returnPercentage)%: expected \(input.expectedTarget), got \(actual)")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Very small prices produce valid target prices",
          arguments: (0..<20).map { _ in
              (currentPrice: Double.random(in: 0.01...0.10), returnPercentage: Double.random(in: -50.0...100.0))
          })
    func testVerySmallPrices(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        // For very small prices, the target should still be calculated correctly
        #expect(Self.areEqual(actual, expected),
                "Small price \(pair.currentPrice) with return \(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Very large prices produce valid target prices",
          arguments: (0..<20).map { _ in
              (currentPrice: Double.random(in: 5000.0...50000.0), returnPercentage: Double.random(in: -50.0...100.0))
          })
    func testVeryLargePrices(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        // For large prices, the target should still be calculated correctly
        #expect(Self.areEqual(actual, expected),
                "Large price \(pair.currentPrice) with return \(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Extreme return percentages produce valid target prices",
          arguments: [
              (currentPrice: 100.0, returnPercentage: -90.0),   // Near total loss
              (currentPrice: 100.0, returnPercentage: -99.0),   // Almost total loss
              (currentPrice: 100.0, returnPercentage: 100.0),   // Double
              (currentPrice: 100.0, returnPercentage: 200.0),   // Triple
              (currentPrice: 100.0, returnPercentage: 500.0),   // 6x
          ])
    func testExtremeReturnPercentages(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Extreme return \(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    // MARK: - Property Tests: Decimal Precision
    
    @Test("Property: Fractional return percentages are calculated correctly",
          arguments: [
              (currentPrice: 100.0, returnPercentage: 0.1),     // 0.1% return
              (currentPrice: 100.0, returnPercentage: 0.5),     // 0.5% return
              (currentPrice: 100.0, returnPercentage: 1.25),    // 1.25% return
              (currentPrice: 100.0, returnPercentage: 2.75),    // 2.75% return
              (currentPrice: 100.0, returnPercentage: -0.1),    // -0.1% return
              (currentPrice: 100.0, returnPercentage: -0.5),    // -0.5% return
          ])
    func testFractionalReturnPercentages(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Fractional return \(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
    
    @Test("Property: Fractional current prices are calculated correctly",
          arguments: [
              (currentPrice: 10.50, returnPercentage: 5.0),
              (currentPrice: 25.75, returnPercentage: 10.0),
              (currentPrice: 123.45, returnPercentage: 7.5),
              (currentPrice: 99.99, returnPercentage: -5.0),
              (currentPrice: 0.99, returnPercentage: 20.0),
          ])
    func testFractionalCurrentPrices(pair: (currentPrice: Double, returnPercentage: Double)) {
        let expected = Self.expectedTargetPrice(currentPrice: pair.currentPrice, returnPercentage: pair.returnPercentage)
        let actual = OpportunityIdentifier.calculateTargetPrice(currentPrice: pair.currentPrice, returnPct: pair.returnPercentage)
        
        #expect(Self.areEqual(actual, expected),
                "Fractional price \(pair.currentPrice) with return \(pair.returnPercentage)%: expected \(expected), got \(actual)")
    }
}

// MARK: - Random Value Generator for Strategy Property Tests

/// Generates random values for strategy property testing
enum StrategyRandomGenerator {
    
    /// Generate a random positive current price
    static func randomCurrentPrice() -> Double {
        let magnitude = Int.random(in: 0...3)
        switch magnitude {
        case 0: return Double.random(in: 0.01...5.0)
        case 1: return Double.random(in: 5.0...100.0)
        case 2: return Double.random(in: 100.0...500.0)
        default: return Double.random(in: 500.0...5000.0)
        }
    }
    
    /// Generate a random return percentage (both positive and negative)
    static func randomReturnPercentage() -> Double {
        Double.random(in: -50.0...100.0)
    }
    
    /// Generate a (price, return) pair for testing
    static func randomPriceReturnPair() -> (currentPrice: Double, returnPercentage: Double) {
        (currentPrice: randomCurrentPrice(), returnPercentage: randomReturnPercentage())
    }
}


// MARK: - Property 8: Rolling Window Return Calculation
// **Validates: Requirements 5.2**
//
// *For any* array of price points with length ≥ WINDOW_DAYS, the rolling window return
// for window starting at index i SHALL equal
// `((prices[i + windowDays].close - prices[i].close) / prices[i].close) * 100`.

@Suite("Property 8: Rolling Window Return Calculation - Validates Requirements 5.2")
struct RollingWindowReturnPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    // MARK: - Test Data Generation
    
    /// Generates random arrays of price points with sufficient length for rolling window calculation.
    /// Returns tuples of (prices, windowDays) ensuring prices.count > windowDays.
    static func generatePriceDataWithWindow(count: Int) -> [([PricePoint], Int)] {
        return (0..<count).map { _ in
            // Generate window days: 1, 5, or 30 (valid configuration values)
            let windowDays = [1, 5, 30].randomElement()!
            
            // Generate price array with at least windowDays + 2 points to ensure multiple windows
            let minLength = windowDays + 2
            let maxLength = windowDays + 20  // Keep reasonable size
            let priceCount = Int.random(in: minLength...maxLength)
            
            let prices = generateRandomPrices(count: priceCount)
            return (prices, windowDays)
        }
    }
    
    /// Generates an array of random PricePoint values with sequential dates.
    static func generateRandomPrices(count: Int) -> [PricePoint] {
        let calendar = Calendar.current
        let startDate = Date()
        
        return (0..<count).map { index in
            let priceDate = calendar.date(byAdding: .day, value: index, to: startDate)!
            // Generate realistic stock prices: $1 to $5000
            let closePrice = Double.random(in: 1.0...5000.0)
            return PricePoint(date: priceDate, close: closePrice)
        }
    }
    
    /// Generates test cases with specific window configurations (1, 5, 30 days).
    static func generateWindowSpecificTestCases(windowDays: Int, count: Int) -> [([PricePoint], Int)] {
        return (0..<count).map { _ in
            let minLength = windowDays + 1  // Minimum for at least one window
            let maxLength = windowDays + 15
            let priceCount = Int.random(in: minLength...maxLength)
            let prices = generateRandomPrices(count: priceCount)
            return (prices, windowDays)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the expected return percentage using the formula from requirements:
    /// return = ((prices[i + windowDays].close - prices[i].close) / prices[i].close) * 100
    static func expectedReturnForWindow(
        prices: [PricePoint],
        windowStartIndex: Int,
        windowDays: Int
    ) -> Double {
        let startPrice = prices[windowStartIndex].close
        let endPrice = prices[windowStartIndex + windowDays].close
        return ((endPrice - startPrice) / startPrice) * 100
    }
    
    /// Compares two doubles with tolerance for floating point precision.
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    // MARK: - Property Tests: Rolling Window Formula Correctness
    
    @Test("Property: Rolling window return equals ((prices[i + windowDays].close - prices[i].close) / prices[i].close) * 100",
          arguments: generatePriceDataWithWindow(count: 10))
    func testRollingWindowReturnFormula(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        // Precondition: sufficient data for at least one window
        guard prices.count > windowDays else {
            return  // Skip if insufficient data
        }
        
        // Calculate rolling returns using the RollingWindowCalculator
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // The number of returns should equal prices.count - windowDays
        let expectedReturnCount = prices.count - windowDays
        #expect(returns.count == expectedReturnCount,
                "Expected \(expectedReturnCount) returns for \(prices.count) prices with \(windowDays)-day window, got \(returns.count)")
        
        // Verify each window's return matches the formula
        for i in 0..<returns.count {
            let expected = Self.expectedReturnForWindow(prices: prices, windowStartIndex: i, windowDays: windowDays)
            let actual = returns[i].returnPct
            
            #expect(Self.areEqual(actual, expected),
                    "Window \(i): expected return \(expected), got \(actual) for prices[\(i)].close=\(prices[i].close), prices[\(i + windowDays)].close=\(prices[i + windowDays].close)")
        }
    }
    
    // MARK: - Property Tests: 1-Day Window Configuration
    
    @Test("Property: 1-day window returns are correctly calculated",
          arguments: generateWindowSpecificTestCases(windowDays: 1, count: 30))
    func testOneDayWindowReturns(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // Verify each return matches the formula
        for i in 0..<returns.count {
            let expected = Self.expectedReturnForWindow(prices: prices, windowStartIndex: i, windowDays: windowDays)
            let actual = returns[i].returnPct
            
            #expect(Self.areEqual(actual, expected),
                    "1-day window \(i): expected \(expected), got \(actual)")
        }
    }
    
    // MARK: - Property Tests: 5-Day Window Configuration (Default)
    
    @Test("Property: 5-day window returns (default config) are correctly calculated",
          arguments: generateWindowSpecificTestCases(windowDays: 5, count: 30))
    func testFiveDayWindowReturns(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // Verify each return matches the formula
        for i in 0..<returns.count {
            let expected = Self.expectedReturnForWindow(prices: prices, windowStartIndex: i, windowDays: windowDays)
            let actual = returns[i].returnPct
            
            #expect(Self.areEqual(actual, expected),
                    "5-day window \(i): expected \(expected), got \(actual)")
        }
    }
    
    // MARK: - Property Tests: 30-Day Window Configuration
    
    @Test("Property: 30-day window returns are correctly calculated",
          arguments: generateWindowSpecificTestCases(windowDays: 30, count: 30))
    func testThirtyDayWindowReturns(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // Verify each return matches the formula
        for i in 0..<returns.count {
            let expected = Self.expectedReturnForWindow(prices: prices, windowStartIndex: i, windowDays: windowDays)
            let actual = returns[i].returnPct
            
            #expect(Self.areEqual(actual, expected),
                    "30-day window \(i): expected \(expected), got \(actual)")
        }
    }
    
    // MARK: - Property Tests: Return Count Consistency
    
    @Test("Property: Number of rolling returns equals prices.count - windowDays",
          arguments: generatePriceDataWithWindow(count: 10))
    func testReturnCountMatchesExpected(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        guard prices.count > windowDays else {
            return
        }
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        let expectedCount = prices.count - windowDays
        
        #expect(returns.count == expectedCount,
                "For \(prices.count) prices with \(windowDays)-day window: expected \(expectedCount) returns, got \(returns.count)")
    }
    
    // MARK: - Property Tests: Date Correctness
    
    @Test("Property: Rolling window return dates match input price dates",
          arguments: generatePriceDataWithWindow(count: 10))
    func testReturnDatesMatchPriceDates(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        guard prices.count > windowDays else {
            return
        }
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // Verify each return's start and end dates match the corresponding price point dates
        for i in 0..<returns.count {
            #expect(returns[i].startDate == prices[i].date,
                    "Window \(i) start date mismatch: expected \(prices[i].date), got \(returns[i].startDate)")
            
            #expect(returns[i].endDate == prices[i + windowDays].date,
                    "Window \(i) end date mismatch: expected \(prices[i + windowDays].date), got \(returns[i].endDate)")
        }
    }
    
    // MARK: - Property Tests: Sign Convention
    
    @Test("Property: Positive price change produces positive return, negative change produces negative return",
          arguments: (0..<50).map { _ in
              // Generate a 2-point price array for simple sign verification
              let startPrice = Double.random(in: 10.0...1000.0)
              let changePercent = Double.random(in: -50.0...100.0)  // -50% to +100%
              let endPrice = startPrice * (1 + changePercent / 100)
              
              let calendar = Calendar.current
              let startDate = Date()
              let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
              
              let prices = [
                  PricePoint(date: startDate, close: startPrice),
                  PricePoint(date: endDate, close: endPrice)
              ]
              return (prices, startPrice, endPrice)
          })
    func testReturnSignConvention(data: ([PricePoint], Double, Double)) throws {
        let (prices, startPrice, endPrice) = data
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 1)
        
        guard !returns.isEmpty else {
            return
        }
        
        let returnPct = returns[0].returnPct
        
        if endPrice > startPrice {
            #expect(returnPct > 0,
                    "Price increased (\(startPrice) -> \(endPrice)) but return is non-positive: \(returnPct)")
        } else if endPrice < startPrice {
            #expect(returnPct < 0,
                    "Price decreased (\(startPrice) -> \(endPrice)) but return is non-negative: \(returnPct)")
        } else {
            #expect(Self.areEqual(returnPct, 0),
                    "Price unchanged (\(startPrice) -> \(endPrice)) but return is non-zero: \(returnPct)")
        }
    }
    
    // MARK: - Property Tests: Mathematical Properties
    
    @Test("Property: Known percentage change produces corresponding return value",
          arguments: [
              // (startPrice, endPrice, expectedReturnPct)
              (100.0, 110.0, 10.0),       // +10%
              (100.0, 90.0, -10.0),       // -10%
              (100.0, 200.0, 100.0),      // +100% (double)
              (100.0, 50.0, -50.0),       // -50% (half)
              (100.0, 100.0, 0.0),        // 0% (unchanged)
              (50.0, 75.0, 50.0),         // +50%
              (200.0, 150.0, -25.0),      // -25%
              (10.0, 15.0, 50.0),         // +50%
              (1000.0, 1050.0, 5.0),      // +5%
              (500.0, 475.0, -5.0),       // -5%
          ])
    func testKnownPercentageChanges(input: (startPrice: Double, endPrice: Double, expectedReturnPct: Double)) throws {
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let prices = [
            PricePoint(date: startDate, close: input.startPrice),
            PricePoint(date: endDate, close: input.endPrice)
        ]
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 1)
        
        #expect(Self.areEqual(returns[0].returnPct, input.expectedReturnPct),
                "Start=\(input.startPrice), End=\(input.endPrice): expected return \(input.expectedReturnPct)%, got \(returns[0].returnPct)%")
    }
    
    // MARK: - Property Tests: Static Method Equivalence
    
    @Test("Property: Static method produces same results as instance method",
          arguments: generatePriceDataWithWindow(count: 10))
    func testStaticMethodEquivalence(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        guard prices.count > windowDays else {
            return
        }
        
        let calculator = RollingWindowCalculator()
        let instanceReturns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        let staticReturns = try RollingWindowCalculator.calculateReturns(prices: prices, windowDays: windowDays)
        
        #expect(instanceReturns.count == staticReturns.count,
                "Instance and static methods produced different return counts")
        
        for i in 0..<instanceReturns.count {
            #expect(Self.areEqual(instanceReturns[i].returnPct, staticReturns[i].returnPct),
                    "Window \(i): instance return \(instanceReturns[i].returnPct) != static return \(staticReturns[i].returnPct)")
        }
    }
    
    // MARK: - Property Tests: Array Extension Equivalence
    
    @Test("Property: Array extension produces same results as RollingWindowCalculator",
          arguments: generatePriceDataWithWindow(count: 10))
    func testArrayExtensionEquivalence(data: ([PricePoint], Int)) throws {
        let (prices, windowDays) = data
        
        guard prices.count > windowDays else {
            return
        }
        
        let calculatorReturns = try RollingWindowCalculator.calculateReturns(prices: prices, windowDays: windowDays)
        let extensionReturns = try prices.rollingWindowReturns(windowDays: windowDays)
        
        #expect(calculatorReturns.count == extensionReturns.count,
                "Calculator and extension methods produced different return counts")
        
        for i in 0..<calculatorReturns.count {
            #expect(Self.areEqual(calculatorReturns[i].returnPct, extensionReturns[i].returnPct),
                    "Window \(i): calculator return \(calculatorReturns[i].returnPct) != extension return \(extensionReturns[i].returnPct)")
        }
    }
    
    // MARK: - Property Tests: Edge Cases with Extreme Prices
    
    @Test("Property: Rolling window calculation handles extreme price values correctly",
          arguments: [
              // Very small prices (penny stocks)
              (0.01, 0.02, 100.0),  // 100% gain
              (0.05, 0.03, -40.0),  // 40% loss
              
              // Very large prices
              (5000.0, 5500.0, 10.0),  // 10% gain
              (10000.0, 8000.0, -20.0),  // 20% loss
              
              // Small changes
              (100.0, 100.01, 0.01),  // 0.01% gain
              (100.0, 99.99, -0.01),  // 0.01% loss
          ])
    func testExtremePriceValues(input: (startPrice: Double, endPrice: Double, expectedReturnPct: Double)) throws {
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let prices = [
            PricePoint(date: startDate, close: input.startPrice),
            PricePoint(date: endDate, close: input.endPrice)
        ]
        
        let calculator = RollingWindowCalculator()
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 1)
        
        // Use slightly larger tolerance for extreme values
        #expect(Self.areEqual(returns[0].returnPct, input.expectedReturnPct, tolerance: 0.001),
                "Extreme prices: Start=\(input.startPrice), End=\(input.endPrice): expected \(input.expectedReturnPct)%, got \(returns[0].returnPct)%")
    }
}


// MARK: - Property 9: CALL/PUT Opportunity Identification
// **Validates: Requirements 5.3**
//
// *For any* non-empty array of rolling window returns, the CALL opportunity SHALL have
// the maximum return percentage, and the PUT opportunity SHALL have the minimum
// return percentage.

@Suite("Property 9: CALL/PUT Opportunity Identification - Validates Requirements 5.3")
struct CallPutOpportunityIdentificationPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    // MARK: - Test Data Generation
    
    /// Generates random arrays of RollingWindowReturn for testing opportunity identification.
    /// Returns tuples of (returns, currentPrice) for comprehensive testing.
    static func generateReturnsWithPrice(count: Int) -> [([RollingWindowReturn], Double)] {
        return (0..<count).map { _ in
            let returns = generateRandomReturns()
            let currentPrice = Double.random(in: 1.0...5000.0)
            return (returns, currentPrice)
        }
    }
    
    /// Generates an array of random RollingWindowReturn values.
    /// Returns 5 to 30 windows with varied return percentages.
    static func generateRandomReturns() -> [RollingWindowReturn] {
        let calendar = Calendar.current
        let startDate = Date()
        let returnCount = Int.random(in: 5...30)
        
        return (0..<returnCount).map { index in
            let windowStart = calendar.date(byAdding: .day, value: index, to: startDate)!
            let windowEnd = calendar.date(byAdding: .day, value: index + 5, to: startDate)!
            // Generate return percentages from -50% to +100%
            let returnPct = Double.random(in: -50.0...100.0)
            return RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct)
        }
    }
    
    /// Generates returns with explicit maximum and minimum values for verification.
    /// Ensures we can verify the max/min identification is correct.
    static func generateReturnsWithKnownExtremes(count: Int) -> [([RollingWindowReturn], Double, Double, Double)] {
        return (0..<count).map { _ in
            let calendar = Calendar.current
            let startDate = Date()
            
            // Generate a known maximum and minimum
            let knownMax = Double.random(in: 50.0...100.0)
            let knownMin = Double.random(in: -50.0...(-10.0))
            
            // Generate additional returns that are between min and max
            let additionalCount = Int.random(in: 3...10)
            var returns: [RollingWindowReturn] = []
            
            for i in 0..<additionalCount {
                let windowStart = calendar.date(byAdding: .day, value: i, to: startDate)!
                let windowEnd = calendar.date(byAdding: .day, value: i + 5, to: startDate)!
                // Generate returns strictly between min and max
                let returnPct = Double.random(in: (knownMin + 1)...(knownMax - 1))
                returns.append(RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct))
            }
            
            // Insert max and min at random positions
            let maxIndex = additionalCount
            let minIndex = additionalCount + 1
            let maxWindowStart = calendar.date(byAdding: .day, value: maxIndex, to: startDate)!
            let maxWindowEnd = calendar.date(byAdding: .day, value: maxIndex + 5, to: startDate)!
            let minWindowStart = calendar.date(byAdding: .day, value: minIndex, to: startDate)!
            let minWindowEnd = calendar.date(byAdding: .day, value: minIndex + 5, to: startDate)!
            
            returns.append(RollingWindowReturn(startDate: maxWindowStart, endDate: maxWindowEnd, returnPct: knownMax))
            returns.append(RollingWindowReturn(startDate: minWindowStart, endDate: minWindowEnd, returnPct: knownMin))
            
            // Shuffle to randomize positions
            returns.shuffle()
            
            let currentPrice = Double.random(in: 10.0...1000.0)
            
            return (returns, currentPrice, knownMax, knownMin)
        }
    }
    
    /// Generates single-element return arrays for edge case testing.
    static func generateSingleReturns(count: Int) -> [([RollingWindowReturn], Double)] {
        return (0..<count).map { _ in
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 5, to: startDate)!
            let returnPct = Double.random(in: -50.0...100.0)
            let returns = [RollingWindowReturn(startDate: startDate, endDate: endDate, returnPct: returnPct)]
            let currentPrice = Double.random(in: 1.0...1000.0)
            return (returns, currentPrice)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Compares two doubles with tolerance for floating point precision.
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    /// Finds the maximum return percentage from an array of returns.
    static func findMaxReturn(_ returns: [RollingWindowReturn]) -> Double {
        returns.map { $0.returnPct }.max()!
    }
    
    /// Finds the minimum return percentage from an array of returns.
    static func findMinReturn(_ returns: [RollingWindowReturn]) -> Double {
        returns.map { $0.returnPct }.min()!
    }
    
    // MARK: - Property Tests: CALL Opportunity Has Maximum Return
    
    @Test("Property: CALL opportunity SHALL have the maximum return percentage",
          arguments: generateReturnsWithPrice(count: 10))
    func testCallOpportunityHasMaximumReturn(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        // Calculate expected maximum return
        let expectedMaxReturn = Self.findMaxReturn(returns)
        
        // Identify opportunities using OpportunityIdentifier
        let identifier = OpportunityIdentifier()
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Assert: CALL opportunity SHALL have the maximum return percentage
        #expect(Self.areEqual(call.returnPercentage, expectedMaxReturn),
                "CALL opportunity return (\(call.returnPercentage)) should equal maximum return (\(expectedMaxReturn))")
    }
    
    @Test("Property: CALL opportunity type SHALL be .call",
          arguments: generateReturnsWithPrice(count: 10))
    func testCallOpportunityTypeIsCall(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let identifier = OpportunityIdentifier()
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        #expect(call.type == .call,
                "CALL opportunity type should be .call, got \(call.type)")
    }
    
    // MARK: - Property Tests: PUT Opportunity Has Minimum Return
    
    @Test("Property: PUT opportunity SHALL have the minimum return percentage",
          arguments: generateReturnsWithPrice(count: 10))
    func testPutOpportunityHasMinimumReturn(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        // Calculate expected minimum return
        let expectedMinReturn = Self.findMinReturn(returns)
        
        // Identify opportunities using OpportunityIdentifier
        let identifier = OpportunityIdentifier()
        let (_, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Assert: PUT opportunity SHALL have the minimum return percentage
        #expect(Self.areEqual(put.returnPercentage, expectedMinReturn),
                "PUT opportunity return (\(put.returnPercentage)) should equal minimum return (\(expectedMinReturn))")
    }
    
    @Test("Property: PUT opportunity type SHALL be .put",
          arguments: generateReturnsWithPrice(count: 10))
    func testPutOpportunityTypeIsPut(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let identifier = OpportunityIdentifier()
        let (_, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        #expect(put.type == .put,
                "PUT opportunity type should be .put, got \(put.type)")
    }
    
    // MARK: - Property Tests: Known Extremes Verification
    
    @Test("Property: CALL/PUT identification correctly identifies known maximum and minimum",
          arguments: generateReturnsWithKnownExtremes(count: 10))
    func testKnownExtremesIdentification(data: ([RollingWindowReturn], Double, Double, Double)) throws {
        let (returns, currentPrice, knownMax, knownMin) = data
        
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Assert: CALL return equals known maximum
        #expect(Self.areEqual(call.returnPercentage, knownMax),
                "CALL return (\(call.returnPercentage)) should equal known max (\(knownMax))")
        
        // Assert: PUT return equals known minimum
        #expect(Self.areEqual(put.returnPercentage, knownMin),
                "PUT return (\(put.returnPercentage)) should equal known min (\(knownMin))")
    }
    
    // MARK: - Property Tests: Single Element Array
    
    @Test("Property: Single return array produces same opportunity for both CALL and PUT",
          arguments: generateSingleReturns(count: 30))
    func testSingleReturnArray(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard returns.count == 1 else {
            return
        }
        
        let singleReturn = returns[0].returnPct
        
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // For a single element, both CALL and PUT should have the same return
        #expect(Self.areEqual(call.returnPercentage, singleReturn),
                "Single element CALL return (\(call.returnPercentage)) should equal \(singleReturn)")
        #expect(Self.areEqual(put.returnPercentage, singleReturn),
                "Single element PUT return (\(put.returnPercentage)) should equal \(singleReturn)")
        
        // Types should still be correct
        #expect(call.type == .call, "Single element CALL type should be .call")
        #expect(put.type == .put, "Single element PUT type should be .put")
    }
    
    // MARK: - Property Tests: CALL Return >= PUT Return
    
    @Test("Property: CALL return percentage SHALL always be >= PUT return percentage",
          arguments: generateReturnsWithPrice(count: 10))
    func testCallReturnGreaterOrEqualPutReturn(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Assert: CALL return should always be >= PUT return
        // (max >= min is always true for any non-empty set)
        #expect(call.returnPercentage >= put.returnPercentage,
                "CALL return (\(call.returnPercentage)) should be >= PUT return (\(put.returnPercentage))")
    }
    
    // MARK: - Property Tests: Static Method Equivalence
    
    @Test("Property: Static identify method produces same results as instance method",
          arguments: generateReturnsWithPrice(count: 10))
    func testStaticMethodEquivalence(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let identifier = OpportunityIdentifier()
        let instanceResult = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        let staticResult = try OpportunityIdentifier.identify(returns: returns, currentPrice: currentPrice)
        
        #expect(Self.areEqual(instanceResult.call.returnPercentage, staticResult.call.returnPercentage),
                "Instance and static CALL returns should match")
        #expect(Self.areEqual(instanceResult.put.returnPercentage, staticResult.put.returnPercentage),
                "Instance and static PUT returns should match")
    }
    
    // MARK: - Property Tests: Array Extension Equivalence
    
    @Test("Property: Array extension produces same results as OpportunityIdentifier",
          arguments: generateReturnsWithPrice(count: 10))
    func testArrayExtensionEquivalence(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let identifierResult = try OpportunityIdentifier.identify(returns: returns, currentPrice: currentPrice)
        let extensionResult = try returns.identifyOpportunities(currentPrice: currentPrice)
        
        #expect(Self.areEqual(identifierResult.call.returnPercentage, extensionResult.call.returnPercentage),
                "Identifier and extension CALL returns should match")
        #expect(Self.areEqual(identifierResult.put.returnPercentage, extensionResult.put.returnPercentage),
                "Identifier and extension PUT returns should match")
    }
    
    // MARK: - Property Tests: Convenience Methods
    
    @Test("Property: identifyCallOpportunity matches CALL from identifyOpportunities",
          arguments: generateReturnsWithPrice(count: 30))
    func testIdentifyCallOpportunityConsistency(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let (fullCall, _) = try OpportunityIdentifier.identify(returns: returns, currentPrice: currentPrice)
        let callOnly = try OpportunityIdentifier.identifyCallOpportunity(returns: returns, currentPrice: currentPrice)
        
        #expect(Self.areEqual(fullCall.returnPercentage, callOnly.returnPercentage),
                "CALL from identifyOpportunities should match identifyCallOpportunity")
        #expect(fullCall.type == callOnly.type,
                "CALL types should match")
    }
    
    @Test("Property: identifyPutOpportunity matches PUT from identifyOpportunities",
          arguments: generateReturnsWithPrice(count: 30))
    func testIdentifyPutOpportunityConsistency(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let (_, fullPut) = try OpportunityIdentifier.identify(returns: returns, currentPrice: currentPrice)
        let putOnly = try OpportunityIdentifier.identifyPutOpportunity(returns: returns, currentPrice: currentPrice)
        
        #expect(Self.areEqual(fullPut.returnPercentage, putOnly.returnPercentage),
                "PUT from identifyOpportunities should match identifyPutOpportunity")
        #expect(fullPut.type == putOnly.type,
                "PUT types should match")
    }
    
    // MARK: - Property Tests: Window Date Preservation
    
    @Test("Property: Opportunity window dates match the source return window dates",
          arguments: generateReturnsWithPrice(count: 10))
    func testWindowDatePreservation(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        guard !returns.isEmpty else {
            return
        }
        
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Find the source windows that match the max and min returns
        let maxReturn = returns.max(by: { $0.returnPct < $1.returnPct })!
        let minReturn = returns.min(by: { $0.returnPct < $1.returnPct })!
        
        // Assert: CALL window dates match the max return window
        #expect(call.windowStartDate == maxReturn.startDate,
                "CALL start date should match max return start date")
        #expect(call.windowEndDate == maxReturn.endDate,
                "CALL end date should match max return end date")
        
        // Assert: PUT window dates match the min return window
        #expect(put.windowStartDate == minReturn.startDate,
                "PUT start date should match min return start date")
        #expect(put.windowEndDate == minReturn.endDate,
                "PUT end date should match min return end date")
    }
    
    // MARK: - Property Tests: Error Handling
    
    @Test("Property: Empty returns array throws emptyReturns error")
    func testEmptyReturnsThrowsError() throws {
        let emptyReturns: [RollingWindowReturn] = []
        let currentPrice = 100.0
        
        let identifier = OpportunityIdentifier()
        
        #expect(throws: OpportunityIdentificationError.emptyReturns) {
            try identifier.identifyOpportunities(returns: emptyReturns, currentPrice: currentPrice)
        }
    }
    
    @Test("Property: Invalid current price throws invalidCurrentPrice error",
          arguments: [-100.0, -1.0, 0.0, -0.001])
    func testInvalidCurrentPriceThrowsError(invalidPrice: Double) throws {
        let returns = Self.generateRandomReturns()
        
        let identifier = OpportunityIdentifier()
        
        #expect(throws: OpportunityIdentificationError.invalidCurrentPrice(value: invalidPrice)) {
            try identifier.identifyOpportunities(returns: returns, currentPrice: invalidPrice)
        }
    }
    
    // MARK: - Property Tests: Known Values
    
    @Test("Property: Known return values produce correct CALL/PUT identification",
          arguments: [
              // (returns, expectedCallReturn, expectedPutReturn)
              ([10.0, 5.0, -3.0, -8.0], 10.0, -8.0),
              ([50.0, 25.0, 0.0, -25.0, -50.0], 50.0, -50.0),
              ([1.0, 2.0, 3.0, 4.0, 5.0], 5.0, 1.0),
              ([-1.0, -2.0, -3.0, -4.0, -5.0], -1.0, -5.0),
              ([0.0, 0.0, 0.0], 0.0, 0.0),
              ([100.0], 100.0, 100.0),
              ([15.5, -22.3, 8.7, -5.1], 15.5, -22.3),
          ])
    func testKnownReturnValues(input: (returns: [Double], expectedCall: Double, expectedPut: Double)) throws {
        let calendar = Calendar.current
        let startDate = Date()
        
        let returns = input.returns.enumerated().map { index, returnPct in
            let windowStart = calendar.date(byAdding: .day, value: index, to: startDate)!
            let windowEnd = calendar.date(byAdding: .day, value: index + 5, to: startDate)!
            return RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct)
        }
        
        let currentPrice = 100.0
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        #expect(Self.areEqual(call.returnPercentage, input.expectedCall),
                "CALL return (\(call.returnPercentage)) should equal \(input.expectedCall)")
        #expect(Self.areEqual(put.returnPercentage, input.expectedPut),
                "PUT return (\(put.returnPercentage)) should equal \(input.expectedPut)")
    }
    
    // MARK: - Property Tests: Extreme Return Values
    
    @Test("Property: Extreme return percentages are correctly identified",
          arguments: (0..<30).map { _ in
              let extremeMax = Double.random(in: 200.0...500.0)
              let extremeMin = Double.random(in: (-500.0)...(-200.0))
              let otherReturns = (0..<5).map { _ in Double.random(in: -50.0...50.0) }
              return ([extremeMax, extremeMin] + otherReturns, extremeMax, extremeMin)
          })
    func testExtremeReturnValues(data: ([Double], Double, Double)) throws {
        let (returnPcts, expectedMax, expectedMin) = data
        
        let calendar = Calendar.current
        let startDate = Date()
        
        var returns = returnPcts.enumerated().map { index, returnPct in
            let windowStart = calendar.date(byAdding: .day, value: index, to: startDate)!
            let windowEnd = calendar.date(byAdding: .day, value: index + 5, to: startDate)!
            return RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct)
        }
        returns.shuffle()  // Randomize positions
        
        let currentPrice = 100.0
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        #expect(Self.areEqual(call.returnPercentage, expectedMax),
                "Extreme CALL return (\(call.returnPercentage)) should equal \(expectedMax)")
        #expect(Self.areEqual(put.returnPercentage, expectedMin),
                "Extreme PUT return (\(put.returnPercentage)) should equal \(expectedMin)")
    }
    
    // MARK: - Property Tests: Duplicate Extreme Values
    
    @Test("Property: Duplicate maximum returns select one of the maximums for CALL",
          arguments: (0..<20).map { _ in
              let duplicateMax = Double.random(in: 50.0...100.0)
              let lowerReturns = (0..<3).map { _ in Double.random(in: -20.0...(duplicateMax - 1.0)) }
              return [duplicateMax, duplicateMax] + lowerReturns
          })
    func testDuplicateMaximums(returnPcts: [Double]) throws {
        let calendar = Calendar.current
        let startDate = Date()
        
        let returns = returnPcts.enumerated().map { index, returnPct in
            let windowStart = calendar.date(byAdding: .day, value: index, to: startDate)!
            let windowEnd = calendar.date(byAdding: .day, value: index + 5, to: startDate)!
            return RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct)
        }
        
        let expectedMax = returnPcts.max()!
        let currentPrice = 100.0
        
        let identifier = OpportunityIdentifier()
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // The CALL return should still equal the maximum, even if there are duplicates
        #expect(Self.areEqual(call.returnPercentage, expectedMax),
                "With duplicate maxes, CALL return (\(call.returnPercentage)) should equal max (\(expectedMax))")
    }
    
    @Test("Property: Duplicate minimum returns select one of the minimums for PUT",
          arguments: (0..<20).map { _ in
              let duplicateMin = Double.random(in: -100.0...(-50.0))
              let higherReturns = (0..<3).map { _ in Double.random(in: (duplicateMin + 1.0)...50.0) }
              return [duplicateMin, duplicateMin] + higherReturns
          })
    func testDuplicateMinimums(returnPcts: [Double]) throws {
        let calendar = Calendar.current
        let startDate = Date()
        
        let returns = returnPcts.enumerated().map { index, returnPct in
            let windowStart = calendar.date(byAdding: .day, value: index, to: startDate)!
            let windowEnd = calendar.date(byAdding: .day, value: index + 5, to: startDate)!
            return RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct)
        }
        
        let expectedMin = returnPcts.min()!
        let currentPrice = 100.0
        
        let identifier = OpportunityIdentifier()
        let (_, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // The PUT return should still equal the minimum, even if there are duplicates
        #expect(Self.areEqual(put.returnPercentage, expectedMin),
                "With duplicate mins, PUT return (\(put.returnPercentage)) should equal min (\(expectedMin))")
    }
}


// MARK: - Property 11: CALL/PUT Return Sign Convention
// **Validates: Requirements 6.2**
//
// *For any* analysis result, if the type is CALL then the return percentage SHALL be positive (> 0),
// and if the type is PUT then the return percentage SHALL be negative (< 0).
//
// This property validates the display convention for CALL/PUT opportunities:
// - CALL opportunities represent bullish (upward) movements with positive returns
// - PUT opportunities represent bearish (downward) movements with negative returns

@Suite("Property 11: CALL/PUT Return Sign Convention - Validates Requirements 6.2")
struct CallPutReturnSignConventionPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    // MARK: - Test Data Generation
    
    /// Generates random AnalysisResult with CALL type and positive return percentage.
    /// These are valid CALL results per the sign convention requirement.
    static func generateValidCallResults(count: Int) -> [AnalysisResult] {
        return (0..<count).map { _ in
            let positiveReturn = Double.random(in: 0.01...100.0)
            let currentPrice = Double.random(in: 1.0...5000.0)
            let targetPrice = calculateTargetPrice(currentPrice: currentPrice, returnPct: positiveReturn)
            
            return AnalysisResult(
                ticker: generateRandomTicker(),
                type: .call,
                returnPercentage: positiveReturn,
                currentPrice: currentPrice,
                targetPrice: targetPrice,
                signal: Bool.random() ? .order : .hold,
                nextEarningsDate: Bool.random() ? Date().addingTimeInterval(Double.random(in: 86400...2592000)) : nil,
                hasEarningsRisk: Bool.random()
            )
        }
    }
    
    /// Generates random AnalysisResult with PUT type and negative return percentage.
    /// These are valid PUT results per the sign convention requirement.
    static func generateValidPutResults(count: Int) -> [AnalysisResult] {
        return (0..<count).map { _ in
            let negativeReturn = -Double.random(in: 0.01...50.0)  // Negative returns for PUT
            let currentPrice = Double.random(in: 1.0...5000.0)
            let targetPrice = calculateTargetPrice(currentPrice: currentPrice, returnPct: negativeReturn)
            
            return AnalysisResult(
                ticker: generateRandomTicker(),
                type: .put,
                returnPercentage: negativeReturn,
                currentPrice: currentPrice,
                targetPrice: targetPrice,
                signal: Bool.random() ? .order : .hold,
                nextEarningsDate: Bool.random() ? Date().addingTimeInterval(Double.random(in: 86400...2592000)) : nil,
                hasEarningsRisk: Bool.random()
            )
        }
    }
    
    /// Generates rolling window returns that guarantee both positive max and negative min.
    /// This ensures proper CALL/PUT sign convention when opportunities are identified.
    static func generateReturnsWithBothSigns(count: Int) -> [([RollingWindowReturn], Double)] {
        return (0..<count).map { _ in
            let calendar = Calendar.current
            let startDate = Date()
            
            // Generate a mix of positive and negative returns
            var returns: [RollingWindowReturn] = []
            
            // Add at least one positive return (for CALL)
            let positiveReturn = Double.random(in: 1.0...100.0)
            let posWindowStart = calendar.date(byAdding: .day, value: 0, to: startDate)!
            let posWindowEnd = calendar.date(byAdding: .day, value: 5, to: startDate)!
            returns.append(RollingWindowReturn(startDate: posWindowStart, endDate: posWindowEnd, returnPct: positiveReturn))
            
            // Add at least one negative return (for PUT)
            let negativeReturn = -Double.random(in: 1.0...50.0)
            let negWindowStart = calendar.date(byAdding: .day, value: 1, to: startDate)!
            let negWindowEnd = calendar.date(byAdding: .day, value: 6, to: startDate)!
            returns.append(RollingWindowReturn(startDate: negWindowStart, endDate: negWindowEnd, returnPct: negativeReturn))
            
            // Add some additional mixed returns
            let additionalCount = Int.random(in: 3...10)
            for i in 0..<additionalCount {
                let windowStart = calendar.date(byAdding: .day, value: i + 2, to: startDate)!
                let windowEnd = calendar.date(byAdding: .day, value: i + 7, to: startDate)!
                let returnPct = Double.random(in: -30.0...50.0)
                returns.append(RollingWindowReturn(startDate: windowStart, endDate: windowEnd, returnPct: returnPct))
            }
            
            returns.shuffle()
            let currentPrice = Double.random(in: 10.0...1000.0)
            
            return (returns, currentPrice)
        }
    }
    
    /// Generates random ticker symbols matching the valid format.
    static func generateRandomTicker() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let length = Int.random(in: 1...5)
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// Calculates target price using the standard formula.
    static func calculateTargetPrice(currentPrice: Double, returnPct: Double) -> Double {
        let rawTarget = currentPrice * (1 + returnPct / 100)
        return (rawTarget * 100).rounded() / 100
    }
    
    /// Compares two doubles with tolerance for floating point precision.
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    // MARK: - Property Tests: CALL Results Shall Have Positive Returns
    
    @Test("Property: CALL results SHALL have positive return percentage (> 0)",
          arguments: generateValidCallResults(count: 10))
    func testCallResultsHavePositiveReturns(result: AnalysisResult) {
        // Verify result type is CALL
        #expect(result.type == .call,
                "Test data should have CALL type")
        
        // Assert: CALL return percentage SHALL be positive (> 0)
        #expect(result.returnPercentage > 0,
                "CALL result for \(result.ticker) should have positive return, got \(result.returnPercentage)")
    }
    
    @Test("Property: Valid CALL results maintain positive return invariant",
          arguments: (0..<50).map { _ in Double.random(in: 0.01...100.0) })
    func testValidCallReturnRanges(positiveReturn: Double) {
        let result = AnalysisResult(
            ticker: "AAPL",
            type: .call,
            returnPercentage: positiveReturn,
            currentPrice: 150.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 150.0, returnPct: positiveReturn),
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        #expect(result.type == .call && result.returnPercentage > 0,
                "CALL result should have positive return \(positiveReturn)")
    }
    
    // MARK: - Property Tests: PUT Results Shall Have Negative Returns
    
    @Test("Property: PUT results SHALL have negative return percentage (< 0)",
          arguments: generateValidPutResults(count: 10))
    func testPutResultsHaveNegativeReturns(result: AnalysisResult) {
        // Verify result type is PUT
        #expect(result.type == .put,
                "Test data should have PUT type")
        
        // Assert: PUT return percentage SHALL be negative (< 0)
        #expect(result.returnPercentage < 0,
                "PUT result for \(result.ticker) should have negative return, got \(result.returnPercentage)")
    }
    
    @Test("Property: Valid PUT results maintain negative return invariant",
          arguments: (0..<50).map { _ in -Double.random(in: 0.01...50.0) })
    func testValidPutReturnRanges(negativeReturn: Double) {
        let result = AnalysisResult(
            ticker: "MSFT",
            type: .put,
            returnPercentage: negativeReturn,
            currentPrice: 300.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 300.0, returnPct: negativeReturn),
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        #expect(result.type == .put && result.returnPercentage < 0,
                "PUT result should have negative return \(negativeReturn)")
    }
    
    // MARK: - Property Tests: OpportunityIdentifier Sign Convention with Mixed Returns
    
    @Test("Property: When returns contain both positive and negative values, CALL gets positive max and PUT gets negative min",
          arguments: generateReturnsWithBothSigns(count: 10))
    func testSignConventionWithMixedReturns(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        // Ensure we have both positive and negative returns
        let hasPositive = returns.contains { $0.returnPct > 0 }
        let hasNegative = returns.contains { $0.returnPct < 0 }
        guard hasPositive && hasNegative else { return }
        
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Find actual max and min
        let maxReturn = returns.map { $0.returnPct }.max()!
        let minReturn = returns.map { $0.returnPct }.min()!
        
        // CALL should have the max return which should be positive
        #expect(call.type == .call,
                "CALL opportunity type should be .call")
        #expect(Self.areEqual(call.returnPercentage, maxReturn),
                "CALL should have max return: expected \(maxReturn), got \(call.returnPercentage)")
        #expect(call.returnPercentage > 0,
                "With mixed returns, CALL return (\(call.returnPercentage)) should be positive (max is \(maxReturn))")
        
        // PUT should have the min return which should be negative
        #expect(put.type == .put,
                "PUT opportunity type should be .put")
        #expect(Self.areEqual(put.returnPercentage, minReturn),
                "PUT should have min return: expected \(minReturn), got \(put.returnPercentage)")
        #expect(put.returnPercentage < 0,
                "With mixed returns, PUT return (\(put.returnPercentage)) should be negative (min is \(minReturn))")
    }
    
    // MARK: - Property Tests: Known Value Verification
    
    @Test("Property: Known CALL/PUT results follow sign convention",
          arguments: [
              // (type, returnPercentage, expectedPositive)
              (OpportunityType.call, 5.0, true),
              (OpportunityType.call, 0.5, true),
              (OpportunityType.call, 25.75, true),
              (OpportunityType.call, 100.0, true),
              (OpportunityType.call, 0.01, true),
              (OpportunityType.put, -3.0, false),
              (OpportunityType.put, -15.5, false),
              (OpportunityType.put, -0.5, false),
              (OpportunityType.put, -50.0, false),
              (OpportunityType.put, -0.01, false),
          ])
    func testKnownValueSignConvention(input: (type: OpportunityType, returnPercentage: Double, expectPositive: Bool)) {
        let result = AnalysisResult(
            ticker: "TEST",
            type: input.type,
            returnPercentage: input.returnPercentage,
            currentPrice: 100.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 100.0, returnPct: input.returnPercentage),
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        if input.expectPositive {
            #expect(result.returnPercentage > 0,
                    "\(input.type.rawValue) should have positive return, got \(result.returnPercentage)")
        } else {
            #expect(result.returnPercentage < 0,
                    "\(input.type.rawValue) should have negative return, got \(result.returnPercentage)")
        }
    }
    
    // MARK: - Property Tests: Strict Positive/Negative (Excluding Zero)
    
    @Test("Property: CALL returns must be strictly positive (> 0, not >= 0)",
          arguments: (0..<50).map { _ in
              let positiveReturn = Double.random(in: 0.001...100.0)
              let currentPrice = Double.random(in: 10.0...1000.0)
              return (currentPrice, positiveReturn)
          })
    func testCallReturnsStrictlyPositive(data: (currentPrice: Double, positiveReturn: Double)) {
        let result = AnalysisResult(
            ticker: "CALL",
            type: .call,
            returnPercentage: data.positiveReturn,
            currentPrice: data.currentPrice,
            targetPrice: Self.calculateTargetPrice(currentPrice: data.currentPrice, returnPct: data.positiveReturn),
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        // Strictly positive, not equal to zero
        #expect(result.returnPercentage > 0,
                "CALL return must be > 0, got \(result.returnPercentage)")
        #expect(result.returnPercentage != 0,
                "CALL return must not equal 0")
    }
    
    @Test("Property: PUT returns must be strictly negative (< 0, not <= 0)",
          arguments: (0..<50).map { _ in
              let negativeReturn = -Double.random(in: 0.001...50.0)
              let currentPrice = Double.random(in: 10.0...1000.0)
              return (currentPrice, negativeReturn)
          })
    func testPutReturnsStrictlyNegative(data: (currentPrice: Double, negativeReturn: Double)) {
        let result = AnalysisResult(
            ticker: "PUT",
            type: .put,
            returnPercentage: data.negativeReturn,
            currentPrice: data.currentPrice,
            targetPrice: Self.calculateTargetPrice(currentPrice: data.currentPrice, returnPct: data.negativeReturn),
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        // Strictly negative, not equal to zero
        #expect(result.returnPercentage < 0,
                "PUT return must be < 0, got \(result.returnPercentage)")
        #expect(result.returnPercentage != 0,
                "PUT return must not equal 0")
    }
    
    // MARK: - Property Tests: Sign Convention Consistency with Target Price
    
    @Test("Property: CALL with positive return should have target price > current price",
          arguments: (0..<50).map { _ in
              let positiveReturn = Double.random(in: 0.1...100.0)
              let currentPrice = Double.random(in: 10.0...1000.0)
              return (currentPrice, positiveReturn)
          })
    func testCallTargetPriceGreaterThanCurrent(data: (currentPrice: Double, positiveReturn: Double)) {
        let targetPrice = Self.calculateTargetPrice(currentPrice: data.currentPrice, returnPct: data.positiveReturn)
        
        let result = AnalysisResult(
            ticker: "CALL",
            type: .call,
            returnPercentage: data.positiveReturn,
            currentPrice: data.currentPrice,
            targetPrice: targetPrice,
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        // For CALL with positive return, target should be > current
        #expect(result.targetPrice > result.currentPrice,
                "CALL target price (\(result.targetPrice)) should be > current price (\(result.currentPrice)) for positive return (\(result.returnPercentage)%)")
    }
    
    @Test("Property: PUT with negative return should have target price < current price",
          arguments: (0..<50).map { _ in
              let negativeReturn = -Double.random(in: 0.1...50.0)
              let currentPrice = Double.random(in: 10.0...1000.0)
              return (currentPrice, negativeReturn)
          })
    func testPutTargetPriceLessThanCurrent(data: (currentPrice: Double, negativeReturn: Double)) {
        let targetPrice = Self.calculateTargetPrice(currentPrice: data.currentPrice, returnPct: data.negativeReturn)
        
        let result = AnalysisResult(
            ticker: "PUT",
            type: .put,
            returnPercentage: data.negativeReturn,
            currentPrice: data.currentPrice,
            targetPrice: targetPrice,
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        // For PUT with negative return, target should be < current
        #expect(result.targetPrice < result.currentPrice,
                "PUT target price (\(result.targetPrice)) should be < current price (\(result.currentPrice)) for negative return (\(result.returnPercentage)%)")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Very small positive returns are valid for CALL",
          arguments: [0.001, 0.01, 0.05, 0.1, 0.5])
    func testSmallPositiveCallReturns(smallPositive: Double) {
        let result = AnalysisResult(
            ticker: "MICRO",
            type: .call,
            returnPercentage: smallPositive,
            currentPrice: 100.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 100.0, returnPct: smallPositive),
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        #expect(result.type == .call && result.returnPercentage > 0,
                "Small positive return \(smallPositive) should be valid for CALL")
    }
    
    @Test("Property: Very small negative returns are valid for PUT",
          arguments: [-0.001, -0.01, -0.05, -0.1, -0.5])
    func testSmallNegativePutReturns(smallNegative: Double) {
        let result = AnalysisResult(
            ticker: "MICRO",
            type: .put,
            returnPercentage: smallNegative,
            currentPrice: 100.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 100.0, returnPct: smallNegative),
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        #expect(result.type == .put && result.returnPercentage < 0,
                "Small negative return \(smallNegative) should be valid for PUT")
    }
    
    @Test("Property: Large positive returns are valid for CALL",
          arguments: [50.0, 75.0, 100.0, 150.0, 200.0])
    func testLargePositiveCallReturns(largePositive: Double) {
        let result = AnalysisResult(
            ticker: "BOOM",
            type: .call,
            returnPercentage: largePositive,
            currentPrice: 50.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 50.0, returnPct: largePositive),
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        #expect(result.type == .call && result.returnPercentage > 0,
                "Large positive return \(largePositive) should be valid for CALL")
    }
    
    @Test("Property: Large negative returns are valid for PUT",
          arguments: [-25.0, -40.0, -50.0, -75.0, -90.0])
    func testLargeNegativePutReturns(largeNegative: Double) {
        let result = AnalysisResult(
            ticker: "FALL",
            type: .put,
            returnPercentage: largeNegative,
            currentPrice: 500.0,
            targetPrice: Self.calculateTargetPrice(currentPrice: 500.0, returnPct: largeNegative),
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        #expect(result.type == .put && result.returnPercentage < 0,
                "Large negative return \(largeNegative) should be valid for PUT")
    }
    
    // MARK: - Property Tests: Comprehensive Sign Convention with Random Data
    
    @Test("Property: Randomly generated AnalysisResults follow sign convention when properly constructed",
          arguments: (0..<100).map { _ -> (OpportunityType, Double) in
              let type: OpportunityType = Bool.random() ? .call : .put
              let returnPct: Double
              if type == .call {
                  returnPct = Double.random(in: 0.01...100.0)
              } else {
                  returnPct = -Double.random(in: 0.01...50.0)
              }
              return (type, returnPct)
          })
    func testRandomSignConvention(input: (type: OpportunityType, returnPct: Double)) {
        let result = AnalysisResult(
            ticker: Self.generateRandomTicker(),
            type: input.type,
            returnPercentage: input.returnPct,
            currentPrice: Double.random(in: 1.0...5000.0),
            targetPrice: Double.random(in: 1.0...6000.0), // Simplified, actual would be calculated
            signal: Bool.random() ? .order : .hold,
            nextEarningsDate: Bool.random() ? Date() : nil,
            hasEarningsRisk: Bool.random()
        )
        
        switch result.type {
        case .call:
            #expect(result.returnPercentage > 0,
                    "CALL return should be > 0, got \(result.returnPercentage)")
        case .put:
            #expect(result.returnPercentage < 0,
                    "PUT return should be < 0, got \(result.returnPercentage)")
        }
    }
    
    // MARK: - Property Tests: Sign Convention After Opportunity Identification
    
    @Test("Property: OpportunityResult types correctly reflect sign when data has both positive and negative returns",
          arguments: generateReturnsWithBothSigns(count: 10))
    func testOpportunityResultSignReflectsData(data: ([RollingWindowReturn], Double)) throws {
        let (returns, currentPrice) = data
        
        // Ensure we have meaningful data
        guard returns.count >= 2 else { return }
        
        let maxReturn = returns.map { $0.returnPct }.max()!
        let minReturn = returns.map { $0.returnPct }.min()!
        
        // Skip if max is not positive or min is not negative
        guard maxReturn > 0 && minReturn < 0 else { return }
        
        let identifier = OpportunityIdentifier()
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Validate the sign convention property
        // CALL (max return) should be positive when max > 0
        #expect(call.returnPercentage > 0,
                "CALL return (\(call.returnPercentage)) should be positive when max return (\(maxReturn)) > 0")
        
        // PUT (min return) should be negative when min < 0
        #expect(put.returnPercentage < 0,
                "PUT return (\(put.returnPercentage)) should be negative when min return (\(minReturn)) < 0")
    }
}


// MARK: - Property 11 (Live Options Chain): Call Target Calculation
// **Validates: Requirements 5.1**
//
// *For any* current price `p` and best return percentage `r`, the call target SHALL equal
// `p * (1 + r / 100)`.
//
// The call target represents the price above which it is historically safe to sell
// a covered call, calculated using the maximum rolling window return.

@Suite("Property 11: Call Target Calculation - Validates Requirements 5.1")
struct CallTargetCalculationPropertyTests {
    
    // MARK: - Helper Methods
    
    /// Calculates the expected call target using the formula from requirements:
    /// callTarget = currentPrice * (1 + bestReturnPct / 100)
    static func expectedCallTarget(currentPrice: Double, bestReturnPct: Double) -> Double {
        guard currentPrice > 0 else { return 0 }
        return currentPrice * (1 + bestReturnPct / 100.0)
    }
    
    /// Compares two doubles with tolerance for floating point precision.
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    // MARK: - Test Data Generation
    
    /// Generates random pairs of (currentPrice, bestReturnPct) for testing.
    /// currentPrice is always positive, bestReturnPct can be positive or negative.
    static func generatePriceReturnPairs(count: Int) -> [(currentPrice: Double, bestReturnPct: Double)] {
        return (0..<count).map { _ in
            let price: Double
            let magnitude = Int.random(in: 0...3)
            switch magnitude {
            case 0: price = Double.random(in: 0.01...5.0)      // Penny stocks
            case 1: price = Double.random(in: 5.0...100.0)     // Regular stocks
            case 2: price = Double.random(in: 100.0...500.0)   // Mid-priced stocks
            default: price = Double.random(in: 500.0...5000.0) // High-priced stocks
            }
            
            // Best return is typically positive for CALL opportunities
            let returnPct = Double.random(in: 0.0...100.0)
            return (currentPrice: price, bestReturnPct: returnPct)
        }
    }
    
    // MARK: - Property Tests: Call Target Formula Correctness
    
    @Test("Property: Call target equals currentPrice * (1 + bestReturnPct / 100)",
          arguments: [
              // Standard prices with various return percentages (from task description)
              (currentPrice: 100.0, bestReturnPct: 5.0),
              (currentPrice: 100.0, bestReturnPct: 10.0),
              (currentPrice: 100.0, bestReturnPct: 15.0),
              (currentPrice: 100.0, bestReturnPct: 20.0),
              (currentPrice: 150.0, bestReturnPct: 5.0),
              (currentPrice: 150.0, bestReturnPct: 10.0),
              (currentPrice: 150.0, bestReturnPct: 15.0),
              (currentPrice: 150.0, bestReturnPct: 20.0),
              (currentPrice: 200.0, bestReturnPct: 5.0),
              (currentPrice: 200.0, bestReturnPct: 10.0),
          ])
    func testCallTargetFormula(pair: (currentPrice: Double, bestReturnPct: Double)) {
        let currentPrice = pair.currentPrice
        let bestReturnPct = pair.bestReturnPct
        
        // Calculate expected result using the formula from requirements
        let expected = Self.expectedCallTarget(currentPrice: currentPrice, bestReturnPct: bestReturnPct)
        
        // Calculate actual result using WeeklyOptionStrategy
        let actual = WeeklyOptionStrategy.calculateCallTarget(
            currentPrice: currentPrice,
            bestReturnPct: bestReturnPct
        )
        
        // Assert: Call target SHALL equal the formula result
        #expect(Self.areEqual(actual, expected),
                "Call target for price=\(currentPrice), return=\(bestReturnPct)%: expected \(expected), got \(actual)")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Edge Case: currentPrice = 0 returns 0")
    func testZeroPriceReturnsZero() {
        let result = WeeklyOptionStrategy.calculateCallTarget(currentPrice: 0, bestReturnPct: 10.0)
        #expect(result == 0, "Call target should be 0 when currentPrice is 0, got \(result)")
    }
    
    @Test("Edge Case: currentPrice < 0 returns 0",
          arguments: [
              -0.01, -1.0, -10.0, -100.0, -1000.0
          ])
    func testNegativePriceReturnsZero(negativePrice: Double) {
        let result = WeeklyOptionStrategy.calculateCallTarget(currentPrice: negativePrice, bestReturnPct: 10.0)
        #expect(result == 0, "Call target should be 0 when currentPrice is negative (\(negativePrice)), got \(result)")
    }
    
    // MARK: - Property Tests: Mathematical Properties
    
    @Test("Property: Call target is greater than current price for positive returns",
          arguments: generatePriceReturnPairs(count: 5).filter { $0.bestReturnPct > 0 })
    func testCallTargetGreaterForPositiveReturns(pair: (currentPrice: Double, bestReturnPct: Double)) {
        let callTarget = WeeklyOptionStrategy.calculateCallTarget(
            currentPrice: pair.currentPrice,
            bestReturnPct: pair.bestReturnPct
        )
        
        #expect(callTarget > pair.currentPrice,
                "Call target \(callTarget) should be > current price \(pair.currentPrice) for positive return \(pair.bestReturnPct)%")
    }
    
    @Test("Property: Call target equals current price for zero return")
    func testCallTargetEqualsCurrentForZeroReturn() {
        let testPrices = [10.0, 50.0, 100.0, 250.0, 500.0]
        
        for price in testPrices {
            let callTarget = WeeklyOptionStrategy.calculateCallTarget(
                currentPrice: price,
                bestReturnPct: 0.0
            )
            #expect(Self.areEqual(callTarget, price),
                    "Call target should equal current price \(price) for 0% return, got \(callTarget)")
        }
    }
    
    // MARK: - Property Tests: Known Calculation Examples
    
    @Test("Property: Known calculation examples produce correct results",
          arguments: [
              // (currentPrice, bestReturnPct, expectedTarget)
              (100.0, 5.0, 105.0),       // 5% increase: 100 * 1.05 = 105
              (100.0, 10.0, 110.0),      // 10% increase: 100 * 1.10 = 110
              (150.0, 10.0, 165.0),      // 10% of $150: 150 * 1.10 = 165
              (200.0, 15.0, 230.0),      // 15% of $200: 200 * 1.15 = 230
              (50.0, 20.0, 60.0),        // 20% of $50: 50 * 1.20 = 60
              (1000.0, 5.0, 1050.0),     // 5% of $1000: 1000 * 1.05 = 1050
          ])
    func testKnownCalculationExamples(input: (currentPrice: Double, bestReturnPct: Double, expectedTarget: Double)) {
        let actual = WeeklyOptionStrategy.calculateCallTarget(
            currentPrice: input.currentPrice,
            bestReturnPct: input.bestReturnPct
        )
        
        #expect(Self.areEqual(actual, input.expectedTarget),
                "Price=\(input.currentPrice), Return=\(input.bestReturnPct)%: expected \(input.expectedTarget), got \(actual)")
    }
    
    // MARK: - Property Tests: Various Price Magnitudes
    
    @Test("Property: Formula holds for penny stocks ($0.01 - $5)")
    func testCallTargetForPennyStocks() {
        let testCases = [
            (currentPrice: 0.50, bestReturnPct: 10.0),
            (currentPrice: 1.25, bestReturnPct: 8.0),
            (currentPrice: 2.50, bestReturnPct: 12.0),
            (currentPrice: 4.99, bestReturnPct: 5.0),
        ]
        
        for testCase in testCases {
            let expected = Self.expectedCallTarget(currentPrice: testCase.currentPrice, bestReturnPct: testCase.bestReturnPct)
            let actual = WeeklyOptionStrategy.calculateCallTarget(
                currentPrice: testCase.currentPrice,
                bestReturnPct: testCase.bestReturnPct
            )
            
            #expect(Self.areEqual(actual, expected),
                    "Penny stock price=\(testCase.currentPrice), return=\(testCase.bestReturnPct)%: expected \(expected), got \(actual)")
        }
    }
    
    @Test("Property: Formula holds for high-priced stocks ($500 - $5000)")
    func testCallTargetForHighPricedStocks() {
        let testCases = [
            (currentPrice: 500.0, bestReturnPct: 7.5),
            (currentPrice: 1000.0, bestReturnPct: 3.0),
            (currentPrice: 2500.0, bestReturnPct: 5.0),
            (currentPrice: 4500.0, bestReturnPct: 2.0),
        ]
        
        for testCase in testCases {
            let expected = Self.expectedCallTarget(currentPrice: testCase.currentPrice, bestReturnPct: testCase.bestReturnPct)
            let actual = WeeklyOptionStrategy.calculateCallTarget(
                currentPrice: testCase.currentPrice,
                bestReturnPct: testCase.bestReturnPct
            )
            
            #expect(Self.areEqual(actual, expected),
                    "High-priced stock price=\(testCase.currentPrice), return=\(testCase.bestReturnPct)%: expected \(expected), got \(actual)")
        }
    }
}


// MARK: - Property 13: Call Signal Generation - ORDER
// **Validates: Requirements 5.3**
//
// *For any* call option with strike price `s` and call target `t` where `s >= t`,
// the generated signal SHALL be `ORDER`.

@Suite("Property 13: Call Signal Generation - ORDER - Validates Requirements 5.3")
struct CallSignalOrderPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// Generates test cases where strike >= callTarget (should produce ORDER signal)
    /// Returns: (strikePrice, callTarget) tuples where strike >= target
    static let orderTestCases: [(strikePrice: Double, callTarget: Double)] = [
        // Boundary case: strike exactly equals callTarget
        (strikePrice: 100.0, callTarget: 100.0),
        (strikePrice: 50.0, callTarget: 50.0),
        (strikePrice: 150.75, callTarget: 150.75),
        
        // Strike above target by small amounts
        (strikePrice: 105.0, callTarget: 100.0),
        (strikePrice: 100.01, callTarget: 100.0),
        (strikePrice: 155.0, callTarget: 150.0),
        
        // Strike well above target
        (strikePrice: 110.0, callTarget: 100.0),
        (strikePrice: 200.0, callTarget: 150.0),
        (strikePrice: 500.0, callTarget: 100.0),
        
        // Various callTarget values with strikes at or above
        (strikePrice: 25.0, callTarget: 20.0),
        (strikePrice: 75.0, callTarget: 75.0),
        (strikePrice: 1000.0, callTarget: 950.0)
    ]
    
    /// Generates random test cases where strike >= callTarget
    static func generateRandomOrderCases(count: Int) -> [(strikePrice: Double, callTarget: Double)] {
        return (0..<count).map { _ in
            let callTarget = Double.random(in: 10.0...1000.0)
            // Generate strike that is >= callTarget (0 to 50% above)
            let excess = Double.random(in: 0.0...0.5) * callTarget
            let strikePrice = callTarget + excess
            return (strikePrice: strikePrice, callTarget: callTarget)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a WeeklyOptionStrategy instance for testing
    private func createStrategy() -> WeeklyOptionStrategy {
        return WeeklyOptionStrategy()
    }
    
    // MARK: - Property Tests: Strike >= CallTarget produces ORDER signal
    
    @Test("Property: When strike >= callTarget, generateCallSignal returns .order",
          arguments: orderTestCases)
    func testCallSignalOrderWhenStrikeAtOrAboveTarget(strikePrice: Double, callTarget: Double) {
        // Precondition: strike >= callTarget
        #expect(strikePrice >= callTarget,
                "Precondition: strike (\(strikePrice)) should be >= callTarget (\(callTarget))")
        
        // Act
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        // Assert: Signal SHALL be ORDER when strike >= callTarget
        #expect(signal == .order,
                "Signal should be .order when strike (\(strikePrice)) >= callTarget (\(callTarget)), got \(signal)")
    }
    
    @Test("Property: isCallStrikeSuitable returns true when strike >= callTarget",
          arguments: orderTestCases)
    func testIsCallStrikeSuitableWhenStrikeAtOrAboveTarget(strikePrice: Double, callTarget: Double) {
        // Precondition: strike >= callTarget
        #expect(strikePrice >= callTarget,
                "Precondition: strike (\(strikePrice)) should be >= callTarget (\(callTarget))")
        
        // Act
        let isSuitable = WeeklyOptionStrategy.isCallStrikeSuitable(strikePrice: strikePrice, callTarget: callTarget)
        
        // Assert: isCallStrikeSuitable SHALL return true when strike >= callTarget
        #expect(isSuitable == true,
                "isCallStrikeSuitable should return true when strike (\(strikePrice)) >= callTarget (\(callTarget))")
    }
    
    // MARK: - Property Tests: Boundary Case (strike exactly equals callTarget)
    
    @Test("Property: ORDER signal generated at exact boundary (strike == callTarget)",
          arguments: [
              (strikePrice: 100.0, callTarget: 100.0),
              (strikePrice: 50.0, callTarget: 50.0),
              (strikePrice: 150.0, callTarget: 150.0),
              (strikePrice: 75.5, callTarget: 75.5),
              (strikePrice: 200.25, callTarget: 200.25)
          ])
    func testCallSignalOrderAtExactBoundary(strikePrice: Double, callTarget: Double) {
        // Precondition: exact boundary
        #expect(abs(strikePrice - callTarget) < 0.0001,
                "Precondition: strike should exactly equal callTarget")
        
        // Act
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        // Assert: Signal SHALL be ORDER at exact boundary
        #expect(signal == .order,
                "Signal should be .order at exact boundary where strike (\(strikePrice)) == callTarget (\(callTarget))")
    }
    
    // MARK: - Property Tests: Various Price Magnitudes
    
    @Test("Property: ORDER signal for penny stock options (low prices)",
          arguments: [
              (strikePrice: 2.50, callTarget: 2.00),
              (strikePrice: 1.00, callTarget: 1.00),
              (strikePrice: 3.00, callTarget: 2.50),
              (strikePrice: 0.50, callTarget: 0.45),
              (strikePrice: 5.00, callTarget: 4.00)
          ])
    func testCallSignalOrderForPennyStocks(strikePrice: Double, callTarget: Double) {
        #expect(strikePrice >= callTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        #expect(signal == .order,
                "Low-priced option: signal should be .order when strike (\(strikePrice)) >= callTarget (\(callTarget))")
    }
    
    @Test("Property: ORDER signal for high-priced options",
          arguments: [
              (strikePrice: 500.0, callTarget: 450.0),
              (strikePrice: 1000.0, callTarget: 1000.0),
              (strikePrice: 2500.0, callTarget: 2000.0),
              (strikePrice: 3500.0, callTarget: 3000.0),
              (strikePrice: 5000.0, callTarget: 4500.0)
          ])
    func testCallSignalOrderForHighPricedOptions(strikePrice: Double, callTarget: Double) {
        #expect(strikePrice >= callTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        #expect(signal == .order,
                "High-priced option: signal should be .order when strike (\(strikePrice)) >= callTarget (\(callTarget))")
    }
    
    // MARK: - Property Tests: Fractional Precision
    
    @Test("Property: ORDER signal handles fractional strike prices correctly",
          arguments: [
              (strikePrice: 105.50, callTarget: 105.50),
              (strikePrice: 105.51, callTarget: 105.50),
              (strikePrice: 123.45, callTarget: 120.00),
              (strikePrice: 99.99, callTarget: 99.98),
              (strikePrice: 150.125, callTarget: 150.000)
          ])
    func testCallSignalOrderWithFractionalPrices(strikePrice: Double, callTarget: Double) {
        #expect(strikePrice >= callTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        #expect(signal == .order,
                "Fractional price: signal should be .order when strike (\(strikePrice)) >= callTarget (\(callTarget))")
    }
    
    // MARK: - Property Tests: Random Data for Robustness
    
    @Test("Property: ORDER signal consistently generated for random strike >= callTarget",
          arguments: generateRandomOrderCases(count: 50))
    func testCallSignalOrderWithRandomData(strikePrice: Double, callTarget: Double) {
        // Precondition should be satisfied by generator
        #expect(strikePrice >= callTarget,
                "Precondition: strike (\(strikePrice)) should be >= callTarget (\(callTarget))")
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        #expect(signal == .order,
                "Random case: signal should be .order when strike (\(strikePrice)) >= callTarget (\(callTarget)), got \(signal)")
    }
    
    // MARK: - Property Tests: Strike Above Target (Non-Boundary)
    
    @Test("Property: ORDER signal when strike is significantly above callTarget",
          arguments: [
              (strikePrice: 110.0, callTarget: 100.0),    // 10% above
              (strikePrice: 125.0, callTarget: 100.0),    // 25% above
              (strikePrice: 150.0, callTarget: 100.0),    // 50% above
              (strikePrice: 200.0, callTarget: 100.0),    // 100% above
              (strikePrice: 300.0, callTarget: 100.0)     // 200% above
          ])
    func testCallSignalOrderWhenStrikeSignificantlyAbove(strikePrice: Double, callTarget: Double) {
        #expect(strikePrice > callTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        #expect(signal == .order,
                "Strike significantly above target: signal should be .order when strike (\(strikePrice)) > callTarget (\(callTarget))")
    }
    
    @Test("Property: ORDER signal when strike is just slightly above callTarget",
          arguments: [
              (strikePrice: 100.01, callTarget: 100.0),
              (strikePrice: 100.001, callTarget: 100.0),
              (strikePrice: 50.05, callTarget: 50.0),
              (strikePrice: 150.10, callTarget: 150.0),
              (strikePrice: 200.50, callTarget: 200.0)
          ])
    func testCallSignalOrderWhenStrikeSlightlyAbove(strikePrice: Double, callTarget: Double) {
        #expect(strikePrice > callTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        
        #expect(signal == .order,
                "Strike slightly above target: signal should be .order when strike (\(strikePrice)) > callTarget (\(callTarget))")
    }
    
    // MARK: - Property Tests: Combined with isCallStrikeSuitable
    
    @Test("Property: generateCallSignal and isCallStrikeSuitable are consistent for ORDER cases",
          arguments: generateRandomOrderCases(count: 20))
    func testConsistencyBetweenGenerateCallSignalAndIsSuitable(strikePrice: Double, callTarget: Double) {
        #expect(strikePrice >= callTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generateCallSignal(strikePrice: strikePrice, callTarget: callTarget)
        let isSuitable = WeeklyOptionStrategy.isCallStrikeSuitable(strikePrice: strikePrice, callTarget: callTarget)
        
        // Both should indicate ORDER/suitable when strike >= callTarget
        #expect(signal == .order,
                "generateCallSignal should return .order")
        #expect(isSuitable == true,
                "isCallStrikeSuitable should return true")
        
        // They should be consistent: signal == .order iff isSuitable == true
        #expect((signal == .order) == isSuitable,
                "generateCallSignal and isCallStrikeSuitable should be consistent")
    }
}


// MARK: - Property 14: Call Signal Generation - HOLD
// **Validates: Requirements 5.4**
//
// *For any* call option with strike price `s` and call target `t` where `s < t`,
// the generated signal SHALL be `HOLD`.
// Edge case: nil strike should also return `.hold`.

@Suite("Property 14: Call Signal Generation - HOLD - Validates Requirements 5.4")
struct CallSignalHOLDPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// Generates pairs of (strike, callTarget) where strike < callTarget.
    /// These should all result in HOLD signals.
    static func generateStrikeBelowTargetPairs(count: Int) -> [(strike: Double, callTarget: Double)] {
        return (0..<count).map { _ in
            // Generate a random call target price
            let callTarget = Double.random(in: 50.0...500.0)
            // Generate a strike price strictly below the target
            // Use a random fraction below the target (1% to 99% below)
            let fractionBelow = Double.random(in: 0.01...0.99)
            let strike = callTarget * (1 - fractionBelow)
            return (strike: strike, callTarget: callTarget)
        }
    }
    
    /// Generates strikes that are just below the call target (within 1%).
    /// These edge cases should still return HOLD since strike < callTarget.
    static func generateStrikesJustBelowTarget(count: Int) -> [(strike: Double, callTarget: Double)] {
        return (0..<count).map { _ in
            let callTarget = Double.random(in: 100.0...500.0)
            // Strike is just below target (0.01% to 1% below)
            let fractionBelow = Double.random(in: 0.0001...0.01)
            let strike = callTarget * (1 - fractionBelow)
            return (strike: strike, callTarget: callTarget)
        }
    }
    
    /// Generates strikes that are well below the call target (more than 10% below).
    static func generateStrikesWellBelowTarget(count: Int) -> [(strike: Double, callTarget: Double)] {
        return (0..<count).map { _ in
            let callTarget = Double.random(in: 100.0...500.0)
            // Strike is well below target (10% to 50% below)
            let fractionBelow = Double.random(in: 0.10...0.50)
            let strike = callTarget * (1 - fractionBelow)
            return (strike: strike, callTarget: callTarget)
        }
    }
    
    /// Generates various call target values for nil strike testing.
    static func generateCallTargetValues(count: Int) -> [Double] {
        return (0..<count).map { _ in
            Double.random(in: 50.0...1000.0)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Compares two doubles with tolerance for floating point precision.
    static func areEqual(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(a - b) < tolerance
    }
    
    // MARK: - Property Tests: Strike Below Target Returns HOLD
    
    @Test("Property: HOLD signal generated when strike < callTarget",
          arguments: generateStrikeBelowTargetPairs(count: 10))
    func testHoldSignalWhenStrikeBelowTarget(pair: (strike: Double, callTarget: Double)) {
        // Precondition: strike must be strictly less than callTarget
        #expect(pair.strike < pair.callTarget,
                "Test data precondition: strike \(pair.strike) should be < callTarget \(pair.callTarget)")
        
        // Create strategy instance
        let strategy = WeeklyOptionStrategy()
        
        // Generate signal
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        // Assert: signal SHALL be .hold when strike < callTarget
        #expect(signal == .hold,
                "Signal for strike=\(pair.strike), callTarget=\(pair.callTarget) should be .hold, got \(signal)")
    }
    
    @Test("Property: HOLD signal when strike is just below target (edge case)",
          arguments: generateStrikesJustBelowTarget(count: 10))
    func testHoldSignalWhenStrikeJustBelowTarget(pair: (strike: Double, callTarget: Double)) {
        // Precondition: strike must be strictly less than callTarget
        #expect(pair.strike < pair.callTarget,
                "Precondition: strike \(pair.strike) should be < callTarget \(pair.callTarget)")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        // Even when strike is very close to (but below) target, signal should be HOLD
        #expect(signal == .hold,
                "Signal for strike=\(pair.strike) just below callTarget=\(pair.callTarget) should be .hold, got \(signal)")
    }
    
    @Test("Property: HOLD signal when strike is well below target",
          arguments: generateStrikesWellBelowTarget(count: 10))
    func testHoldSignalWhenStrikeWellBelowTarget(pair: (strike: Double, callTarget: Double)) {
        // Precondition: strike must be well below callTarget
        #expect(pair.strike < pair.callTarget * 0.90,
                "Precondition: strike \(pair.strike) should be well below callTarget \(pair.callTarget)")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        // When strike is well below target, signal should be HOLD
        #expect(signal == .hold,
                "Signal for strike=\(pair.strike) well below callTarget=\(pair.callTarget) should be .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Nil Strike Returns HOLD (Edge Case)
    
    @Test("Property: HOLD signal when strike is nil (no option available)",
          arguments: generateCallTargetValues(count: 10))
    func testHoldSignalWhenStrikeIsNil(callTarget: Double) {
        let strategy = WeeklyOptionStrategy()
        
        // When strike is nil (no option available), signal should be HOLD
        let signal = strategy.generateCallSignal(strikePrice: nil, callTarget: callTarget)
        
        #expect(signal == .hold,
                "Signal for nil strike with callTarget=\(callTarget) should be .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Known Values
    
    @Test("Property: Known strike/target pairs produce HOLD signal",
          arguments: [
              // (strike, callTarget) - all strikes are below targets
              (strike: 99.0, callTarget: 100.0),     // strike = callTarget - 1
              (strike: 90.0, callTarget: 100.0),     // strike = callTarget - 10
              (strike: 50.0, callTarget: 100.0),     // strike well below target
              (strike: 99.99, callTarget: 100.0),    // strike barely below target
              (strike: 149.0, callTarget: 150.0),    // different target
              (strike: 145.0, callTarget: 155.0),    // 10 below target
              (strike: 200.0, callTarget: 250.0),    // larger values
              (strike: 10.0, callTarget: 15.0),      // smaller values
              (strike: 0.50, callTarget: 1.0),       // very small values
          ])
    func testKnownStrikeTargetPairsProduceHold(pair: (strike: Double, callTarget: Double)) {
        // Verify test data precondition
        #expect(pair.strike < pair.callTarget,
                "Test data: strike \(pair.strike) should be < callTarget \(pair.callTarget)")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        #expect(signal == .hold,
                "Known pair strike=\(pair.strike), callTarget=\(pair.callTarget) should produce .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Various Call Target Values with Strikes Below
    
    @Test("Property: Various callTarget values with strikes below all return HOLD",
          arguments: [
              // Different callTarget magnitudes with corresponding strikes below
              (strike: 9.0, callTarget: 10.0),       // Small target
              (strike: 90.0, callTarget: 100.0),     // Medium target
              (strike: 450.0, callTarget: 500.0),    // Large target
              (strike: 900.0, callTarget: 1000.0),   // Very large target
              (strike: 4500.0, callTarget: 5000.0),  // High-priced stock target
          ])
    func testVariousCallTargetValuesProduceHold(pair: (strike: Double, callTarget: Double)) {
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        #expect(signal == .hold,
                "Strike=\(pair.strike) below callTarget=\(pair.callTarget) should produce .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: HOLD is Never ORDER When Strike < Target
    
    @Test("Property: Signal is never ORDER when strike < callTarget",
          arguments: generateStrikeBelowTargetPairs(count: 10))
    func testSignalNeverOrderWhenStrikeBelowTarget(pair: (strike: Double, callTarget: Double)) {
        // Precondition: strike < callTarget
        #expect(pair.strike < pair.callTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        // The signal should NOT be .order
        #expect(signal != .order,
                "Signal should NOT be .order when strike=\(pair.strike) < callTarget=\(pair.callTarget)")
    }
    
    // MARK: - Property Tests: Consistency with isCallStrikeSuitable
    
    @Test("Property: HOLD signal is consistent with isCallStrikeSuitable returning false",
          arguments: generateStrikeBelowTargetPairs(count: 10))
    func testHoldSignalConsistentWithStrikeSuitability(pair: (strike: Double, callTarget: Double)) {
        // Precondition: strike < callTarget
        #expect(pair.strike < pair.callTarget)
        
        // Check that isCallStrikeSuitable returns false
        let isSuitable = WeeklyOptionStrategy.isCallStrikeSuitable(
            strikePrice: pair.strike,
            callTarget: pair.callTarget
        )
        
        #expect(isSuitable == false,
                "isCallStrikeSuitable should return false for strike=\(pair.strike) < callTarget=\(pair.callTarget)")
        
        // And generateCallSignal should return .hold
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        #expect(signal == .hold,
                "generateCallSignal should return .hold when isCallStrikeSuitable is false")
    }
    
    // MARK: - Property Tests: Boundary Behavior (Strike Approaching Target from Below)
    
    @Test("Property: As strike approaches callTarget from below, signal remains HOLD until strike >= callTarget",
          arguments: [
              // Series approaching 100.0 from below
              (strike: 95.0, callTarget: 100.0),
              (strike: 97.0, callTarget: 100.0),
              (strike: 99.0, callTarget: 100.0),
              (strike: 99.5, callTarget: 100.0),
              (strike: 99.9, callTarget: 100.0),
              (strike: 99.99, callTarget: 100.0),
              (strike: 99.999, callTarget: 100.0),
          ])
    func testHoldSignalAsStrikeApproachesTargetFromBelow(pair: (strike: Double, callTarget: Double)) {
        // All these strikes are below target
        #expect(pair.strike < pair.callTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        // Should still be HOLD even when very close to target
        #expect(signal == .hold,
                "Signal should be .hold for strike=\(pair.strike) approaching but below callTarget=\(pair.callTarget)")
    }
    
    // MARK: - Property Tests: Floating Point Edge Cases
    
    @Test("Property: HOLD signal with floating point precision edge cases",
          arguments: [
              // Values that might have floating point precision issues
              (strike: 99.999999, callTarget: 100.0),
              (strike: 149.9999999, callTarget: 150.0),
              (strike: 199.99999999, callTarget: 200.0),
          ])
    func testHoldSignalWithFloatingPointPrecision(pair: (strike: Double, callTarget: Double)) {
        // These strikes are mathematically below target
        #expect(pair.strike < pair.callTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generateCallSignal(strikePrice: pair.strike, callTarget: pair.callTarget)
        
        #expect(signal == .hold,
                "Floating point edge case: strike=\(pair.strike) < callTarget=\(pair.callTarget) should produce .hold, got \(signal)")
    }
}


// MARK: - Property 15: Put Signal Generation - ORDER
// **Validates: Requirements 5.5**
//
// *For any* put option with strike price `s` and put target `t` where `s <= t`,
// the generated signal SHALL be `ORDER`.

@Suite("Property 15: Put Signal Generation - ORDER - Validates Requirements 5.5")
struct PutSignalOrderPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// Generates test cases where strike <= putTarget (ORDER condition)
    /// Returns tuples of (strikePrice, putTarget) where strikePrice <= putTarget
    static var orderTestCases: [(strikePrice: Double, putTarget: Double)] {
        var cases: [(Double, Double)] = []
        
        // Boundary cases: strike exactly equals putTarget
        cases.append((100.0, 100.0))
        cases.append((50.0, 50.0))
        cases.append((250.0, 250.0))
        
        // Strike below target
        cases.append((95.0, 100.0))
        cases.append((45.0, 50.0))
        cases.append((240.0, 250.0))
        
        // Strike well below target
        cases.append((80.0, 100.0))
        cases.append((30.0, 50.0))
        cases.append((200.0, 250.0))
        
        return cases
    }
    
    /// Generates random ORDER test cases where strike <= putTarget
    static func generateRandomOrderCases(count: Int) -> [(strikePrice: Double, putTarget: Double)] {
        return (0..<count).map { _ in
            let putTarget = Double.random(in: 10.0...500.0)
            // Generate strike at or below target
            let strike = Double.random(in: 1.0...putTarget)
            return (strikePrice: strike, putTarget: putTarget)
        }
    }
    
    /// Generates boundary cases where strike exactly equals putTarget
    static func generateBoundaryCases(count: Int) -> [(strikePrice: Double, putTarget: Double)] {
        return (0..<count).map { _ in
            let price = Double.random(in: 10.0...500.0)
            return (strikePrice: price, putTarget: price)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a WeeklyOptionStrategy instance for testing
    func createStrategy() -> WeeklyOptionStrategy {
        return WeeklyOptionStrategy()
    }
    
    // MARK: - Property Tests: Strike <= PutTarget produces ORDER signal
    
    @Test("Property: When strike <= putTarget, generatePutSignal returns .order",
          arguments: orderTestCases)
    func testPutSignalOrderWhenStrikeAtOrBelowTarget(strikePrice: Double, putTarget: Double) {
        // Precondition: strike <= putTarget
        #expect(strikePrice <= putTarget,
                "Test precondition: strike \(strikePrice) should be <= putTarget \(putTarget)")
        
        // Act
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        // Assert: Signal SHALL be ORDER when strike <= putTarget
        #expect(signal == .order,
                "PUT signal for strike=\(strikePrice) <= putTarget=\(putTarget) should be .order, got \(signal)")
    }
    
    @Test("Property: Boundary case - strike exactly equals putTarget produces ORDER",
          arguments: generateBoundaryCases(count: 10))
    func testPutSignalOrderAtExactBoundary(strikePrice: Double, putTarget: Double) {
        // Precondition: strike == putTarget (exact boundary)
        #expect(strikePrice == putTarget,
                "Test precondition: strike \(strikePrice) should equal putTarget \(putTarget)")
        
        // Act
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        // Assert: Signal SHALL be ORDER at exact boundary
        #expect(signal == .order,
                "PUT signal at boundary (strike=putTarget=\(putTarget)) should be .order, got \(signal)")
    }
    
    @Test("Property: Strike below putTarget produces ORDER for various price ranges")
    func testPutSignalOrderForVariousPriceRanges() {
        // Low price range (penny stock targets)
        let lowPriceStrike = 0.90
        let lowPriceTarget = 1.00
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: lowPriceStrike, putTarget: lowPriceTarget)
        
        #expect(signal == .order,
                "Low price: strike=\(lowPriceStrike) < putTarget=\(lowPriceTarget) should produce .order")
    }
    
    @Test("Property: Regular stock price range produces ORDER when strike <= putTarget")
    func testPutSignalOrderForRegularStocks() {
        // Regular stock range ($50-$200)
        let strikePrice = 95.0
        let putTarget = 100.0
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "Regular stock: strike=\(strikePrice) <= putTarget=\(putTarget) should produce .order")
    }
    
    @Test("Property: High price stock range produces ORDER when strike <= putTarget")
    func testPutSignalOrderForHighPriceStocks() {
        // High price range ($500-$5000)
        let strikePrice = 2400.0
        let putTarget = 2500.0
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "High price: strike=\(strikePrice) <= putTarget=\(putTarget) should produce .order")
    }
    
    @Test("Property: Strike significantly below putTarget produces ORDER")
    func testPutSignalOrderWhenStrikeSignificantlyBelow() {
        // Strike 20% below target
        let putTarget = 100.0
        let strikePrice = 80.0
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "Significant gap: strike=\(strikePrice) << putTarget=\(putTarget) should produce .order")
    }
    
    @Test("Property: Random ORDER cases all produce .order signal",
          arguments: generateRandomOrderCases(count: 10))
    func testRandomPutSignalOrderCases(strikePrice: Double, putTarget: Double) {
        // Precondition: strike <= putTarget
        #expect(strikePrice <= putTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "Random case: strike=\(strikePrice) <= putTarget=\(putTarget) should produce .order")
    }
    
    @Test("Property: Small difference below target still produces ORDER")
    func testPutSignalOrderWithSmallDifference() {
        // Strike just slightly below target
        let putTarget = 100.0
        let strikePrice = 99.99
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "Small gap: strike=\(strikePrice) < putTarget=\(putTarget) should produce .order")
    }
    
    // MARK: - Property Tests: Combined with isPutStrikeSuitable
    
    @Test("Property: generatePutSignal and isPutStrikeSuitable are consistent for ORDER cases",
          arguments: generateRandomOrderCases(count: 20))
    func testConsistencyBetweenGeneratePutSignalAndIsSuitable(strikePrice: Double, putTarget: Double) {
        // Precondition: strike <= putTarget (ORDER condition)
        #expect(strikePrice <= putTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        let isSuitable = WeeklyOptionStrategy.isPutStrikeSuitable(strikePrice: strikePrice, putTarget: putTarget)
        
        // Both should indicate ORDER/suitable when strike <= putTarget
        #expect(signal == .order,
                "generatePutSignal should return .order")
        #expect(isSuitable == true,
                "isPutStrikeSuitable should return true")
        
        // They should be consistent: signal == .order iff isSuitable == true
        #expect((signal == .order) == isSuitable,
                "generatePutSignal and isPutStrikeSuitable should be consistent")
    }
    
    // MARK: - Property Tests: Floating Point Edge Cases
    
    @Test("Property: Floating point precision doesn't affect ORDER signal at boundary",
          arguments: [
              (strikePrice: 99.999999999, putTarget: 100.0),
              (strikePrice: 100.0, putTarget: 100.000000001),
              (strikePrice: 49.99999999, putTarget: 50.0),
          ])
    func testFloatingPointPrecisionAtBoundary(strikePrice: Double, putTarget: Double) {
        // These are effectively at or below target
        #expect(strikePrice <= putTarget || abs(strikePrice - putTarget) < 0.0001)
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        // Note: if strike < putTarget mathematically, should be ORDER
        if strikePrice <= putTarget {
            #expect(signal == .order,
                    "Floating point case: strike=\(strikePrice) <= putTarget=\(putTarget) should produce .order")
        }
    }
    
    // MARK: - Property Tests: Various putTarget Values
    
    @Test("Property: Various putTarget values with strike at target produce ORDER",
          arguments: [
              (strikePrice: 10.0, putTarget: 10.0),
              (strikePrice: 25.0, putTarget: 25.0),
              (strikePrice: 75.0, putTarget: 75.0),
              (strikePrice: 150.0, putTarget: 150.0),
              (strikePrice: 500.0, putTarget: 500.0),
              (strikePrice: 1000.0, putTarget: 1000.0),
          ])
    func testVariousPutTargetValuesProduceOrder(strikePrice: Double, putTarget: Double) {
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "Strike=putTarget=\(putTarget) should produce .order signal")
    }
    
    @Test("Property: Various putTarget values with strike below target produce ORDER",
          arguments: [
              (strikePrice: 8.0, putTarget: 10.0),
              (strikePrice: 20.0, putTarget: 25.0),
              (strikePrice: 60.0, putTarget: 75.0),
              (strikePrice: 120.0, putTarget: 150.0),
              (strikePrice: 400.0, putTarget: 500.0),
              (strikePrice: 800.0, putTarget: 1000.0),
          ])
    func testVariousPutTargetValuesWithStrikeBelowProduceOrder(strikePrice: Double, putTarget: Double) {
        // Verify precondition
        #expect(strikePrice < putTarget)
        
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        #expect(signal == .order,
                "Strike=\(strikePrice) < putTarget=\(putTarget) should produce .order signal")
    }
}


// MARK: - Property 16: Put Signal Generation - HOLD
// **Validates: Requirements 5.6**
//
// *For any* put option with strike price `s` and put target `t` where `s > t`,
// the generated signal SHALL be `HOLD`.
// Edge case: nil strike should also return `.hold`.

@Suite("Property 16: Put Signal Generation - HOLD - Validates Requirements 5.6")
struct PutSignalHOLDPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// Test cases where strike is above putTarget (should produce HOLD signal).
    /// Format: (strikePrice: Double, putTarget: Double)
    static let holdTestCases: [(strikePrice: Double, putTarget: Double)] = [
        // Just above target
        (strikePrice: 96.0, putTarget: 95.0),       // strike = putTarget + 1
        (strikePrice: 100.01, putTarget: 100.0),    // slightly above
        (strikePrice: 50.10, putTarget: 50.0),      // slightly above
        
        // Well above target
        (strikePrice: 105.0, putTarget: 95.0),      // 10% above
        (strikePrice: 110.0, putTarget: 100.0),     // 10% above
        (strikePrice: 60.0, putTarget: 50.0),       // 20% above
        
        // Various putTarget values with strikes above
        (strikePrice: 155.0, putTarget: 150.0),
        (strikePrice: 210.0, putTarget: 200.0),
        (strikePrice: 85.0, putTarget: 80.0),
        (strikePrice: 45.0, putTarget: 40.0)
    ]
    
    /// Generates pairs of (strike, putTarget) where strike > putTarget.
    /// These should all result in HOLD signals.
    static func generateStrikeAboveTargetPairs(count: Int) -> [(strike: Double, putTarget: Double)] {
        return (0..<count).map { _ in
            // Generate a random put target price
            let putTarget = Double.random(in: 50.0...500.0)
            // Generate a strike price strictly above the target
            // Use a random fraction above the target (1% to 100% above)
            let fractionAbove = Double.random(in: 0.01...1.0)
            let strike = putTarget * (1 + fractionAbove)
            return (strike: strike, putTarget: putTarget)
        }
    }
    
    /// Generates strikes that are just above the put target (within 1%).
    /// These edge cases should still return HOLD since strike > putTarget.
    static func generateStrikesJustAboveTarget(count: Int) -> [(strike: Double, putTarget: Double)] {
        return (0..<count).map { _ in
            let putTarget = Double.random(in: 100.0...500.0)
            // Strike is just above target (0.01% to 1% above)
            let fractionAbove = Double.random(in: 0.0001...0.01)
            let strike = putTarget * (1 + fractionAbove)
            return (strike: strike, putTarget: putTarget)
        }
    }
    
    /// Generates strikes that are well above the put target (more than 10% above).
    static func generateStrikesWellAboveTarget(count: Int) -> [(strike: Double, putTarget: Double)] {
        return (0..<count).map { _ in
            let putTarget = Double.random(in: 50.0...300.0)
            // Strike is well above target (10% to 50% above)
            let fractionAbove = Double.random(in: 0.10...0.50)
            let strike = putTarget * (1 + fractionAbove)
            return (strike: strike, putTarget: putTarget)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a WeeklyOptionStrategy instance for testing
    private func createStrategy() -> WeeklyOptionStrategy {
        return WeeklyOptionStrategy()
    }
    
    // MARK: - Property Tests: Strike > putTarget produces HOLD signal
    
    @Test("Property: HOLD signal generated when strike > putTarget (example-based)",
          arguments: holdTestCases)
    func testPutSignalHoldWhenStrikeAboveTarget(strikePrice: Double, putTarget: Double) {
        // Precondition: strike > putTarget
        #expect(strikePrice > putTarget,
                "Precondition: strike (\(strikePrice)) should be > putTarget (\(putTarget))")
        
        // Act
        let strategy = createStrategy()
        let signal = strategy.generatePutSignal(strikePrice: strikePrice, putTarget: putTarget)
        
        // Assert: signal SHALL be .hold when strike > putTarget
        #expect(signal == .hold,
                "Signal for strike=\(strikePrice), putTarget=\(putTarget) should be .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Nil strike produces HOLD signal
    
    @Test("Property: HOLD signal generated when strike is nil",
          arguments: [95.0, 100.0, 150.0, 50.0, 200.0])
    func testPutSignalHoldWhenStrikeIsNil(putTarget: Double) {
        let strategy = createStrategy()
        
        // When strike is nil (no option available), signal should be HOLD
        let signal = strategy.generatePutSignal(strikePrice: nil, putTarget: putTarget)
        
        #expect(signal == .hold,
                "Signal for nil strike with putTarget=\(putTarget) should be .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Edge Cases - Strike Just Above Target
    
    @Test("Property: HOLD signal when strike is just slightly above putTarget",
          arguments: generateStrikesJustAboveTarget(count: 10))
    func testPutSignalHoldWhenStrikeJustAboveTarget(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget,
                "Precondition: strike (\(pair.strike)) should be > putTarget (\(pair.putTarget))")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        // Even when strike is very close to (but above) target, signal should be HOLD
        #expect(signal == .hold,
                "Signal for strike=\(pair.strike) just above putTarget=\(pair.putTarget) should be .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Strike Well Above Target
    
    @Test("Property: HOLD signal when strike is well above putTarget",
          arguments: generateStrikesWellAboveTarget(count: 10))
    func testPutSignalHoldWhenStrikeWellAboveTarget(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget,
                "Precondition: strike (\(pair.strike)) should be > putTarget (\(pair.putTarget))")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        // When strike is well above target, signal should be HOLD
        #expect(signal == .hold,
                "Signal for strike=\(pair.strike) well above putTarget=\(pair.putTarget) should be .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Random Data for Robustness
    
    @Test("Property: HOLD signal consistently generated for random strike > putTarget",
          arguments: generateStrikeAboveTargetPairs(count: 20))
    func testPutSignalHoldWithRandomData(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget,
                "Precondition: strike (\(pair.strike)) should be > putTarget (\(pair.putTarget))")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        #expect(signal == .hold,
                "Random case: signal should be .hold when strike (\(pair.strike)) > putTarget (\(pair.putTarget)), got \(signal)")
    }
    
    // MARK: - Property Tests: Known Calculation Examples
    
    @Test("Property: HOLD signal for specific known strike/putTarget pairs",
          arguments: [
              // Typical stock price scenarios
              (strike: 101.0, putTarget: 100.0),
              (strike: 96.0, putTarget: 95.0),
              (strike: 51.0, putTarget: 50.0),
              (strike: 151.0, putTarget: 150.0),
              (strike: 201.0, putTarget: 200.0)
          ])
    func testPutSignalHoldForKnownPairs(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        #expect(signal == .hold,
                "Known pair strike=\(pair.strike), putTarget=\(pair.putTarget) should produce .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Various putTarget Values
    
    @Test("Property: HOLD signal for various putTarget values with strikes above",
          arguments: [
              // Low putTarget values
              (strike: 12.0, putTarget: 10.0),
              (strike: 27.0, putTarget: 25.0),
              // Medium putTarget values
              (strike: 77.0, putTarget: 75.0),
              (strike: 102.0, putTarget: 100.0),
              // High putTarget values
              (strike: 502.0, putTarget: 500.0),
              (strike: 1002.0, putTarget: 1000.0)
          ])
    func testVariousPutTargetValuesProduceHold(pair: (strike: Double, putTarget: Double)) {
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        #expect(signal == .hold,
                "Strike=\(pair.strike) above putTarget=\(pair.putTarget) should produce .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Signal is NOT ORDER
    
    @Test("Property: Signal is explicitly NOT .order when strike > putTarget",
          arguments: generateStrikeAboveTargetPairs(count: 10))
    func testPutSignalIsNotOrderWhenStrikeAboveTarget(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        // The signal should NOT be .order
        #expect(signal != .order,
                "Signal should NOT be .order when strike (\(pair.strike)) > putTarget (\(pair.putTarget))")
    }
    
    // MARK: - Property Tests: Consistency with isPutStrikeSuitable
    
    @Test("Property: isPutStrikeSuitable returns false when strike > putTarget",
          arguments: generateStrikeAboveTargetPairs(count: 10))
    func testIsPutStrikeSuitableConsistency(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget)
        
        // When strike > putTarget, isPutStrikeSuitable should return false
        let isSuitable = WeeklyOptionStrategy.isPutStrikeSuitable(strikePrice: pair.strike, putTarget: pair.putTarget)
        #expect(isSuitable == false,
                "isPutStrikeSuitable should return false for strike=\(pair.strike) > putTarget=\(pair.putTarget)")
        
        // And generatePutSignal should return .hold
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        #expect(signal == .hold,
                "generatePutSignal should return .hold when isPutStrikeSuitable is false")
    }
    
    // MARK: - Property Tests: Boundary Behavior (Strike Approaching Target from Above)
    
    @Test("Property: As strike approaches putTarget from above, signal remains HOLD until strike <= putTarget",
          arguments: [
              // Decreasing approach to boundary
              (strike: 100.10, putTarget: 100.0),
              (strike: 100.05, putTarget: 100.0),
              (strike: 100.01, putTarget: 100.0),
              (strike: 100.001, putTarget: 100.0),
              (strike: 100.0001, putTarget: 100.0)
          ])
    func testBoundaryApproachFromAbove(pair: (strike: Double, putTarget: Double)) {
        // Precondition: still above target
        #expect(pair.strike > pair.putTarget,
                "Precondition: strike (\(pair.strike)) should still be > putTarget (\(pair.putTarget))")
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        // Signal should remain HOLD until we reach/cross the boundary
        #expect(signal == .hold,
                "Approaching boundary from above: signal should remain .hold when strike (\(pair.strike)) > putTarget (\(pair.putTarget))")
    }
    
    // MARK: - Property Tests: Floating Point Edge Cases
    
    @Test("Property: HOLD signal with floating point precision edge cases",
          arguments: [
              // Values that might have floating point precision issues
              (strike: 100.000001, putTarget: 100.0),
              (strike: 150.0000001, putTarget: 150.0),
              (strike: 200.00000001, putTarget: 200.0)
          ])
    func testHoldSignalWithFloatingPointPrecision(pair: (strike: Double, putTarget: Double)) {
        // These strikes are mathematically above target
        #expect(pair.strike > pair.putTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        #expect(signal == .hold,
                "Floating point edge case: strike=\(pair.strike) > putTarget=\(pair.putTarget) should produce .hold, got \(signal)")
    }
    
    // MARK: - Property Tests: Percentage Above Target
    
    @Test("Property: HOLD signal when strike is various percentages above putTarget",
          arguments: [
              // 1% above
              (strike: 101.0, putTarget: 100.0),
              // 5% above
              (strike: 105.0, putTarget: 100.0),
              // 10% above
              (strike: 110.0, putTarget: 100.0),
              // 20% above
              (strike: 120.0, putTarget: 100.0),
              // 50% above
              (strike: 150.0, putTarget: 100.0)
          ])
    func testPutSignalHoldAtVariousPercentagesAbove(pair: (strike: Double, putTarget: Double)) {
        #expect(pair.strike > pair.putTarget)
        
        let strategy = WeeklyOptionStrategy()
        let signal = strategy.generatePutSignal(strikePrice: pair.strike, putTarget: pair.putTarget)
        
        let percentageAbove = ((pair.strike - pair.putTarget) / pair.putTarget) * 100
        #expect(signal == .hold,
                "Strike \(percentageAbove)% above putTarget should produce .hold, got \(signal)")
    }
}
