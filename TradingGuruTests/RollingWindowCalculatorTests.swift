//
//  RollingWindowCalculatorTests.swift
//  TradingGuruTests
//
//  Unit tests for the RollingWindowCalculator service.
//  Tests rolling window return calculation and insufficient data handling.
//

import XCTest
@testable import TradingGuru

final class RollingWindowCalculatorTests: XCTestCase {
    
    // MARK: - Properties
    
    private var calculator: RollingWindowCalculator!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        calculator = RollingWindowCalculator()
    }
    
    override func tearDown() {
        calculator = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a date from a string in yyyy-MM-dd format.
    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)!
    }
    
    /// Creates an array of price points with sequential dates and specified prices.
    private func createPrices(_ closePrices: [Double], startDate: String = "2024-01-01") -> [PricePoint] {
        let calendar = Calendar.current
        let start = date(startDate)
        
        return closePrices.enumerated().map { index, close in
            let priceDate = calendar.date(byAdding: .day, value: index, to: start)!
            return PricePoint(date: priceDate, close: close)
        }
    }
    
    // MARK: - Basic Calculation Tests
    
    /// Tests basic rolling window return calculation with a simple case.
    /// Validates: Requirement 5.2 (Rolling window return calculation formula)
    func testBasicRollingReturnCalculation() throws {
        // Arrange: 6 prices with 5-day window
        // Price goes from 100 to 110 (+10%)
        let prices = createPrices([100.0, 102.0, 104.0, 106.0, 108.0, 110.0])
        let windowDays = 5
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
        
        // Return should be ((110 - 100) / 100) * 100 = 10%
        XCTAssertEqual(returns[0].returnPct, 10.0, accuracy: 0.0001)
    }
    
    /// Tests the rolling window formula: ((endPrice - startPrice) / startPrice) * 100
    /// Validates: Requirement 5.2 (Specific formula validation)
    func testRollingReturnFormula() throws {
        // Arrange: Simple case with known values
        let startPrice = 50.0
        let endPrice = 60.0
        let expectedReturn = ((endPrice - startPrice) / startPrice) * 100 // 20%
        
        let prices = createPrices([startPrice, 52.0, 54.0, 56.0, 58.0, endPrice])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns[0].returnPct, expectedReturn, accuracy: 0.0001)
    }
    
    /// Tests calculation with multiple rolling windows.
    /// Validates: Requirement 5.2 (Process each trading day in lookback period)
    func testMultipleRollingWindows() throws {
        // Arrange: 8 prices with 5-day window should give 3 returns
        // Window 1: index 0-5 (100 -> 105)
        // Window 2: index 1-6 (101 -> 106)
        // Window 3: index 2-7 (102 -> 107)
        let prices = createPrices([100.0, 101.0, 102.0, 103.0, 104.0, 105.0, 106.0, 107.0])
        let windowDays = 5
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: windowDays)
        
        // Assert
        XCTAssertEqual(returns.count, 3)
        
        // Window 1: ((105 - 100) / 100) * 100 = 5%
        XCTAssertEqual(returns[0].returnPct, 5.0, accuracy: 0.0001)
        
        // Window 2: ((106 - 101) / 101) * 100 ≈ 4.95%
        let expectedReturn2 = ((106.0 - 101.0) / 101.0) * 100
        XCTAssertEqual(returns[1].returnPct, expectedReturn2, accuracy: 0.0001)
        
        // Window 3: ((107 - 102) / 102) * 100 ≈ 4.90%
        let expectedReturn3 = ((107.0 - 102.0) / 102.0) * 100
        XCTAssertEqual(returns[2].returnPct, expectedReturn3, accuracy: 0.0001)
    }
    
    /// Tests that negative returns are calculated correctly for PUT opportunities.
    func testNegativeReturns() throws {
        // Arrange: Price drops from 100 to 90 (-10%)
        let prices = createPrices([100.0, 98.0, 96.0, 94.0, 92.0, 90.0])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
        XCTAssertEqual(returns[0].returnPct, -10.0, accuracy: 0.0001)
    }
    
    /// Tests with 1-day window.
    func testOneDayWindow() throws {
        // Arrange
        let prices = createPrices([100.0, 105.0, 103.0, 108.0])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 1)
        
        // Assert: Should have 3 returns for 4 prices with 1-day window
        XCTAssertEqual(returns.count, 3)
        
        // Return 1: ((105 - 100) / 100) * 100 = 5%
        XCTAssertEqual(returns[0].returnPct, 5.0, accuracy: 0.0001)
        
        // Return 2: ((103 - 105) / 105) * 100 ≈ -1.90%
        let expectedReturn2 = ((103.0 - 105.0) / 105.0) * 100
        XCTAssertEqual(returns[1].returnPct, expectedReturn2, accuracy: 0.0001)
        
        // Return 3: ((108 - 103) / 103) * 100 ≈ 4.85%
        let expectedReturn3 = ((108.0 - 103.0) / 103.0) * 100
        XCTAssertEqual(returns[2].returnPct, expectedReturn3, accuracy: 0.0001)
    }
    
    /// Tests with 30-day window.
    func testThirtyDayWindow() throws {
        // Arrange: 31 prices for 30-day window
        var closePrices = [Double]()
        for i in 0..<31 {
            closePrices.append(100.0 + Double(i))
        }
        let prices = createPrices(closePrices)
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 30)
        
        // Assert: Should have 1 return
        XCTAssertEqual(returns.count, 1)
        
        // Return: ((130 - 100) / 100) * 100 = 30%
        XCTAssertEqual(returns[0].returnPct, 30.0, accuracy: 0.0001)
    }
    
    // MARK: - Date Tracking Tests
    
    /// Tests that return objects contain correct start and end dates.
    func testReturnDatesAreCorrect() throws {
        // Arrange
        let prices = createPrices([100.0, 102.0, 104.0, 106.0, 108.0, 110.0], startDate: "2024-01-01")
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns[0].startDate, date("2024-01-01"))
        XCTAssertEqual(returns[0].endDate, date("2024-01-06"))
    }
    
    /// Tests dates with multiple windows.
    func testMultipleWindowDates() throws {
        // Arrange
        let prices = createPrices([100.0, 101.0, 102.0, 103.0, 104.0, 105.0, 106.0], startDate: "2024-01-01")
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 2)
        
        XCTAssertEqual(returns[0].startDate, date("2024-01-01"))
        XCTAssertEqual(returns[0].endDate, date("2024-01-06"))
        
        XCTAssertEqual(returns[1].startDate, date("2024-01-02"))
        XCTAssertEqual(returns[1].endDate, date("2024-01-07"))
    }
    
    // MARK: - Insufficient Data Tests
    
    /// Tests that insufficient data throws appropriate error.
    /// Validates: Requirement 5.6 (Handle insufficient data scenarios)
    func testInsufficientDataThrowsError() {
        // Arrange: 5 prices but need 6 for 5-day window
        let prices = createPrices([100.0, 101.0, 102.0, 103.0, 104.0])
        
        // Act & Assert
        XCTAssertThrowsError(try calculator.calculateRollingReturns(prices: prices, windowDays: 5)) { error in
            guard case RollingWindowError.insufficientData(let available, let required, _) = error else {
                XCTFail("Expected insufficientData error")
                return
            }
            XCTAssertEqual(available, 5)
            XCTAssertEqual(required, 6)
        }
    }
    
    /// Tests that empty price array throws appropriate error.
    /// Validates: Requirement 5.6 (Handle insufficient data)
    func testEmptyPricesThrowsError() {
        // Arrange
        let prices: [PricePoint] = []
        
        // Act & Assert
        XCTAssertThrowsError(try calculator.calculateRollingReturns(prices: prices, windowDays: 5)) { error in
            guard case RollingWindowError.emptyPriceData(_) = error else {
                XCTFail("Expected emptyPriceData error")
                return
            }
        }
    }
    
    /// Tests that exactly sufficient data works correctly.
    func testExactlyEnoughDataSucceeds() throws {
        // Arrange: 6 prices is exactly enough for 5-day window (1 return)
        let prices = createPrices([100.0, 101.0, 102.0, 103.0, 104.0, 105.0])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
    }
    
    /// Tests invalid window days (zero) throws error.
    func testZeroWindowDaysThrowsError() {
        // Arrange
        let prices = createPrices([100.0, 101.0, 102.0])
        
        // Act & Assert
        XCTAssertThrowsError(try calculator.calculateRollingReturns(prices: prices, windowDays: 0)) { error in
            guard case RollingWindowError.invalidWindowDays(let value) = error else {
                XCTFail("Expected invalidWindowDays error")
                return
            }
            XCTAssertEqual(value, 0)
        }
    }
    
    /// Tests invalid window days (negative) throws error.
    func testNegativeWindowDaysThrowsError() {
        // Arrange
        let prices = createPrices([100.0, 101.0, 102.0])
        
        // Act & Assert
        XCTAssertThrowsError(try calculator.calculateRollingReturns(prices: prices, windowDays: -5)) { error in
            guard case RollingWindowError.invalidWindowDays(_) = error else {
                XCTFail("Expected invalidWindowDays error")
                return
            }
        }
    }
    
    // MARK: - calculateRollingReturnsOrEmpty Tests
    
    /// Tests that calculateRollingReturnsOrEmpty returns empty array for insufficient data.
    /// Validates: Requirement 5.6 (Skip ticker with insufficient data)
    func testOrEmptyReturnsEmptyForInsufficientData() {
        // Arrange
        let prices = createPrices([100.0, 101.0])
        
        // Act
        let returns = calculator.calculateRollingReturnsOrEmpty(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertTrue(returns.isEmpty)
    }
    
    /// Tests that calculateRollingReturnsOrEmpty works for valid data.
    func testOrEmptyReturnsResultsForValidData() {
        // Arrange
        let prices = createPrices([100.0, 102.0, 104.0, 106.0, 108.0, 110.0])
        
        // Act
        let returns = calculator.calculateRollingReturnsOrEmpty(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
        XCTAssertEqual(returns[0].returnPct, 10.0, accuracy: 0.0001)
    }
    
    // MARK: - Static Method Tests
    
    /// Tests the static convenience method.
    func testStaticCalculateReturns() throws {
        // Arrange
        let prices = createPrices([100.0, 105.0, 110.0, 115.0, 120.0, 125.0])
        
        // Act
        let returns = try RollingWindowCalculator.calculateReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
        XCTAssertEqual(returns[0].returnPct, 25.0, accuracy: 0.0001)
    }
    
    /// Tests the static calculateReturnsOrEmpty method.
    func testStaticCalculateReturnsOrEmpty() {
        // Arrange
        let prices = createPrices([100.0, 101.0])
        
        // Act
        let returns = RollingWindowCalculator.calculateReturnsOrEmpty(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertTrue(returns.isEmpty)
    }
    
    // MARK: - Array Extension Tests
    
    /// Tests the array extension convenience method.
    func testArrayExtensionRollingWindowReturns() throws {
        // Arrange
        let prices = createPrices([100.0, 105.0, 110.0, 115.0, 120.0, 125.0])
        
        // Act
        let returns = try prices.rollingWindowReturns(windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
    }
    
    /// Tests the array extension orEmpty method.
    func testArrayExtensionOrEmpty() {
        // Arrange
        let prices = createPrices([100.0])
        
        // Act
        let returns = prices.rollingWindowReturnsOrEmpty(windowDays: 5)
        
        // Assert
        XCTAssertTrue(returns.isEmpty)
    }
    
    // MARK: - Helper Method Tests
    
    /// Tests the hasSufficientData helper method.
    func testHasSufficientData() {
        XCTAssertTrue(RollingWindowCalculator.hasSufficientData(priceCount: 6, windowDays: 5))
        XCTAssertFalse(RollingWindowCalculator.hasSufficientData(priceCount: 5, windowDays: 5))
        XCTAssertFalse(RollingWindowCalculator.hasSufficientData(priceCount: 4, windowDays: 5))
        XCTAssertFalse(RollingWindowCalculator.hasSufficientData(priceCount: 10, windowDays: 0))
        XCTAssertFalse(RollingWindowCalculator.hasSufficientData(priceCount: 10, windowDays: -1))
    }
    
    /// Tests the minimumPricePointsRequired helper.
    func testMinimumPricePointsRequired() {
        XCTAssertEqual(RollingWindowCalculator.minimumPricePointsRequired(for: 5), 6)
        XCTAssertEqual(RollingWindowCalculator.minimumPricePointsRequired(for: 1), 2)
        XCTAssertEqual(RollingWindowCalculator.minimumPricePointsRequired(for: 30), 31)
    }
    
    // MARK: - Error Message Tests
    
    /// Tests that error messages are descriptive.
    func testErrorMessages() {
        let insufficientError = RollingWindowError.insufficientData(available: 5, required: 6, ticker: "AAPL")
        XCTAssertTrue(insufficientError.localizedDescription.contains("AAPL"))
        XCTAssertTrue(insufficientError.localizedDescription.contains("5"))
        XCTAssertTrue(insufficientError.localizedDescription.contains("6"))
        
        let emptyError = RollingWindowError.emptyPriceData(ticker: "GOOG")
        XCTAssertTrue(emptyError.localizedDescription.contains("GOOG"))
        
        let invalidError = RollingWindowError.invalidWindowDays(value: -1)
        XCTAssertTrue(invalidError.localizedDescription.contains("-1"))
    }
    
    /// Tests ticker in calculator initialization.
    func testCalculatorWithTicker() {
        // Arrange
        let calculatorWithTicker = RollingWindowCalculator(ticker: "AAPL")
        let prices = createPrices([100.0])
        
        // Act & Assert
        XCTAssertThrowsError(try calculatorWithTicker.calculateRollingReturns(prices: prices, windowDays: 5)) { error in
            guard case RollingWindowError.insufficientData(_, _, let ticker) = error else {
                XCTFail("Expected insufficientData error")
                return
            }
            XCTAssertEqual(ticker, "AAPL")
        }
    }
    
    // MARK: - Edge Cases
    
    /// Tests with very small price changes.
    func testSmallPriceChanges() throws {
        // Arrange
        let prices = createPrices([100.0, 100.01, 100.02, 100.03, 100.04, 100.05])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns.count, 1)
        let expectedReturn = ((100.05 - 100.0) / 100.0) * 100
        XCTAssertEqual(returns[0].returnPct, expectedReturn, accuracy: 0.0001)
    }
    
    /// Tests with large price changes.
    func testLargePriceChanges() throws {
        // Arrange: Price doubles
        let prices = createPrices([100.0, 120.0, 140.0, 160.0, 180.0, 200.0])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns[0].returnPct, 100.0, accuracy: 0.0001)
    }
    
    /// Tests with unchanged price.
    func testUnchangedPrice() throws {
        // Arrange
        let prices = createPrices([100.0, 100.0, 100.0, 100.0, 100.0, 100.0])
        
        // Act
        let returns = try calculator.calculateRollingReturns(prices: prices, windowDays: 5)
        
        // Assert
        XCTAssertEqual(returns[0].returnPct, 0.0, accuracy: 0.0001)
    }
}
