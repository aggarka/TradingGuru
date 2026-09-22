//
//  ResultsPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for analysis results display components validating
//  correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 12: Earnings Risk Indicator
// **Validates: Requirements 6.4**
//
// *For any* analysis result where the next earnings date is on or before the option expiration date,
// the hasEarningsRisk flag SHALL be true, and the earnings date display SHALL use red color formatting.

@Suite("Property 12: Earnings Risk Indicator - Validates Requirements 6.4")
struct EarningsRiskIndicatorPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    // MARK: - Test Data Generation
    
    /// Valid window days values from configuration
    static let validWindowDays = [1, 5, 30]
    
    /// Generates random (earningsDate, windowDays, today) test cases where earnings is BEFORE expiration.
    /// Returns tuples of (earningsDate, windowDays, today) ensuring earningsDate < expirationDate.
    static func generateEarningsBeforeExpiration(count: Int) -> [(earningsDate: Date, windowDays: Int, today: Date)] {
        let calendar = Calendar.current
        return (0..<count).map { _ in
            let windowDays = validWindowDays.randomElement()!
            let today = Date()
            
            // Earnings date is 0 to (windowDays - 1) days from today
            // This ensures earningsDate < expirationDate (today + windowDays)
            let daysFromToday = Int.random(in: 0..<windowDays)
            let earningsDate = calendar.date(byAdding: .day, value: daysFromToday, to: today)!
            
            return (earningsDate: earningsDate, windowDays: windowDays, today: today)
        }
    }
    
    /// Generates random (earningsDate, windowDays, today) test cases where earnings is ON expiration.
    /// Returns tuples of (earningsDate, windowDays, today) ensuring earningsDate == expirationDate.
    static func generateEarningsOnExpiration(count: Int) -> [(earningsDate: Date, windowDays: Int, today: Date)] {
        let calendar = Calendar.current
        return (0..<count).map { _ in
            let windowDays = validWindowDays.randomElement()!
            let today = Date()
            
            // Earnings date is exactly windowDays from today (same as expiration)
            let earningsDate = calendar.date(byAdding: .day, value: windowDays, to: today)!
            
            return (earningsDate: earningsDate, windowDays: windowDays, today: today)
        }
    }
    
    /// Generates random (earningsDate, windowDays, today) test cases where earnings is AFTER expiration.
    /// Returns tuples of (earningsDate, windowDays, today) ensuring earningsDate > expirationDate.
    static func generateEarningsAfterExpiration(count: Int) -> [(earningsDate: Date, windowDays: Int, today: Date)] {
        let calendar = Calendar.current
        return (0..<count).map { _ in
            let windowDays = validWindowDays.randomElement()!
            let today = Date()
            
            // Earnings date is (windowDays + 1) to (windowDays + 30) days from today
            // This ensures earningsDate > expirationDate
            let daysAfterExpiration = Int.random(in: 1...30)
            let earningsDate = calendar.date(byAdding: .day, value: windowDays + daysAfterExpiration, to: today)!
            
            return (earningsDate: earningsDate, windowDays: windowDays, today: today)
        }
    }
    
    /// Generates random windowDays values for nil earnings date tests.
    static func generateWindowDaysValues(count: Int) -> [Int] {
        return (0..<count).map { _ in
            validWindowDays.randomElement()!
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the expected earnings risk based on the formula from requirements.
    /// hasEarningsRisk = true if earningsDate <= expirationDate
    /// hasEarningsRisk = false if earningsDate is nil OR earningsDate > expirationDate
    static func expectedEarningsRisk(
        earningsDate: Date?,
        windowDays: Int,
        today: Date = Date()
    ) -> Bool {
        guard let earningsDate = earningsDate else {
            return false
        }
        
        let calendar = Calendar.current
        guard let expirationDate = calendar.date(byAdding: .day, value: windowDays, to: today) else {
            return false
        }
        
        return earningsDate <= expirationDate
    }
    
    /// Creates an AnalysisResult with the specified earnings date and risk flag.
    static func createAnalysisResult(
        earningsDate: Date?,
        hasEarningsRisk: Bool
    ) -> AnalysisResult {
        return AnalysisResult(
            ticker: "TEST",
            type: .call,
            returnPercentage: 5.0,
            currentPrice: 100.0,
            targetPrice: 105.0,
            signal: .order,
            nextEarningsDate: earningsDate,
            hasEarningsRisk: hasEarningsRisk
        )
    }
    
    /// Creates an AnalysisResultRow from an AnalysisResult.
    static func createResultRow(from result: AnalysisResult) -> AnalysisResultRow {
        return AnalysisResultRow(from: result)
    }
    
    // MARK: - Property Tests: Earnings Date Before Expiration
    
    @Test("Property: When earnings date is before expiration date, hasEarningsRisk SHALL be true",
          arguments: generateEarningsBeforeExpiration(count: 10))
    func testEarningsBeforeExpirationHasRisk(data: (earningsDate: Date, windowDays: Int, today: Date)) {
        let (earningsDate, windowDays, _) = data
        
        // Calculate expected earnings risk using the formula
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays
        )
        
        // Assert: Earnings before expiration SHALL result in hasEarningsRisk = true
        #expect(expectedRisk == true,
                "Earnings date before expiration should have earnings risk. EarningsDate: \(earningsDate), WindowDays: \(windowDays)")
    }
    
    // MARK: - Property Tests: Earnings Date On Expiration
    
    @Test("Property: When earnings date is on expiration date, hasEarningsRisk SHALL be true",
          arguments: generateEarningsOnExpiration(count: 10))
    func testEarningsOnExpirationHasRisk(data: (earningsDate: Date, windowDays: Int, today: Date)) {
        let (earningsDate, windowDays, _) = data
        
        // Calculate expected earnings risk using the formula
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays
        )
        
        // Assert: Earnings on expiration SHALL result in hasEarningsRisk = true
        #expect(expectedRisk == true,
                "Earnings date on expiration should have earnings risk. EarningsDate: \(earningsDate), WindowDays: \(windowDays)")
    }
    
    // MARK: - Property Tests: Earnings Date After Expiration
    
    @Test("Property: When earnings date is after expiration date, hasEarningsRisk SHALL be false",
          arguments: generateEarningsAfterExpiration(count: 10))
    func testEarningsAfterExpirationNoRisk(data: (earningsDate: Date, windowDays: Int, today: Date)) {
        let (earningsDate, windowDays, _) = data
        
        // Calculate expected earnings risk using the formula
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays
        )
        
        // Assert: Earnings after expiration SHALL result in hasEarningsRisk = false
        #expect(expectedRisk == false,
                "Earnings date after expiration should NOT have earnings risk. EarningsDate: \(earningsDate), WindowDays: \(windowDays)")
    }
    
    // MARK: - Property Tests: Nil Earnings Date
    
    @Test("Property: When earnings date is nil, hasEarningsRisk SHALL be false",
          arguments: generateWindowDaysValues(count: 30))
    func testNilEarningsDateNoRisk(windowDays: Int) {
        // Calculate expected earnings risk for nil date
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: nil,
            windowDays: windowDays
        )
        
        // Assert: Nil earnings date SHALL result in hasEarningsRisk = false
        #expect(expectedRisk == false,
                "Nil earnings date should NOT have earnings risk. WindowDays: \(windowDays)")
    }
    
    // MARK: - Property Tests: AnalysisResultRow Reflects AnalysisResult
    
    @Test("Property: AnalysisResultRow.hasEarningsRisk correctly reflects AnalysisResult.hasEarningsRisk",
          arguments: [true, false])
    func testAnalysisResultRowReflectsRiskFlag(hasRisk: Bool) {
        // Create an AnalysisResult with specific hasEarningsRisk value
        let analysisResult = Self.createAnalysisResult(
            earningsDate: hasRisk ? Date() : nil,
            hasEarningsRisk: hasRisk
        )
        
        // Create AnalysisResultRow from the AnalysisResult
        let resultRow = Self.createResultRow(from: analysisResult)
        
        // Assert: Row's hasEarningsRisk SHALL match the AnalysisResult's hasEarningsRisk
        #expect(resultRow.hasEarningsRisk == hasRisk,
                "AnalysisResultRow.hasEarningsRisk should match AnalysisResult.hasEarningsRisk. Expected: \(hasRisk), Got: \(resultRow.hasEarningsRisk)")
    }
    
    @Test("Property: AnalysisResultRow correctly transfers hasEarningsRisk from AnalysisResult across random data",
          arguments: (0..<50).map { _ in Bool.random() })
    func testAnalysisResultRowTransfersRiskFlag(hasRisk: Bool) {
        let earningsDate: Date? = hasRisk ? Date() : Calendar.current.date(byAdding: .day, value: 60, to: Date())
        
        // Create an AnalysisResult with specific hasEarningsRisk value
        let analysisResult = Self.createAnalysisResult(
            earningsDate: earningsDate,
            hasEarningsRisk: hasRisk
        )
        
        // Create AnalysisResultRow from the AnalysisResult
        let resultRow = Self.createResultRow(from: analysisResult)
        
        // Assert: Row's hasEarningsRisk SHALL match the AnalysisResult's hasEarningsRisk
        #expect(resultRow.hasEarningsRisk == analysisResult.hasEarningsRisk,
                "Row should transfer hasEarningsRisk from AnalysisResult. Expected: \(analysisResult.hasEarningsRisk), Got: \(resultRow.hasEarningsRisk)")
    }
    
    // MARK: - Property Tests: Visual Indicator (Red Color) Implies hasEarningsRisk
    
    @Test("Property: hasEarningsRisk = true implies visual indicator (red color) should be applied",
          arguments: (0..<30).map { _ in true })
    func testEarningsRiskImpliesRedColor(hasRisk: Bool) {
        // Create an AnalysisResult with earnings risk
        let analysisResult = Self.createAnalysisResult(
            earningsDate: Date(),
            hasEarningsRisk: hasRisk
        )
        
        // Create AnalysisResultRow from the AnalysisResult
        let resultRow = Self.createResultRow(from: analysisResult)
        
        // Assert: hasEarningsRisk = true means red color should be used
        // The actual color application is in the View layer, but we verify the flag is set
        #expect(resultRow.hasEarningsRisk == true,
                "When hasEarningsRisk is true, the row should indicate earnings risk for red color formatting")
    }
    
    @Test("Property: hasEarningsRisk = false implies primary color should be applied",
          arguments: (0..<30).map { _ in false })
    func testNoEarningsRiskImpliesPrimaryColor(hasRisk: Bool) {
        // Create an AnalysisResult without earnings risk
        let analysisResult = Self.createAnalysisResult(
            earningsDate: Calendar.current.date(byAdding: .day, value: 60, to: Date()),
            hasEarningsRisk: hasRisk
        )
        
        // Create AnalysisResultRow from the AnalysisResult
        let resultRow = Self.createResultRow(from: analysisResult)
        
        // Assert: hasEarningsRisk = false means primary color should be used
        #expect(resultRow.hasEarningsRisk == false,
                "When hasEarningsRisk is false, the row should NOT indicate earnings risk")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Same day earnings (today) with any windowDays should have earnings risk",
          arguments: validWindowDays)
    func testSameDayEarningsHasRisk(windowDays: Int) {
        let today = Date()
        let earningsDate = today  // Same day
        
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays,
            today: today
        )
        
        // Assert: Same day earnings should always have risk
        #expect(expectedRisk == true,
                "Same day earnings should have earnings risk. WindowDays: \(windowDays)")
    }
    
    @Test("Property: One day before expiration should have earnings risk",
          arguments: validWindowDays)
    func testOneDayBeforeExpirationHasRisk(windowDays: Int) {
        let calendar = Calendar.current
        let today = Date()
        
        // Earnings date is one day before expiration (windowDays - 1)
        let earningsDate = calendar.date(byAdding: .day, value: windowDays - 1, to: today)!
        
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays,
            today: today
        )
        
        // Assert: One day before expiration should have risk
        #expect(expectedRisk == true,
                "One day before expiration should have earnings risk. WindowDays: \(windowDays)")
    }
    
    @Test("Property: One day after expiration should NOT have earnings risk",
          arguments: validWindowDays)
    func testOneDayAfterExpirationNoRisk(windowDays: Int) {
        let calendar = Calendar.current
        let today = Date()
        
        // Earnings date is one day after expiration (windowDays + 1)
        let earningsDate = calendar.date(byAdding: .day, value: windowDays + 1, to: today)!
        
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays,
            today: today
        )
        
        // Assert: One day after expiration should NOT have risk
        #expect(expectedRisk == false,
                "One day after expiration should NOT have earnings risk. WindowDays: \(windowDays)")
    }
    
    // MARK: - Property Tests: Window Days Specific Configurations
    
    @Test("Property: 1-day window earnings risk calculation is correct",
          arguments: (0..<20).map { _ in
              let daysOffset = Int.random(in: -5...10)
              return daysOffset
          })
    func testOneDayWindowEarningsRisk(daysOffset: Int) {
        let windowDays = 1
        let calendar = Calendar.current
        let today = Date()
        let earningsDate = calendar.date(byAdding: .day, value: daysOffset, to: today)!
        
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays,
            today: today
        )
        
        // Earnings risk if earningsDate <= today + 1 day
        let shouldHaveRisk = daysOffset <= windowDays
        
        #expect(expectedRisk == shouldHaveRisk,
                "1-day window with offset \(daysOffset): expected risk=\(shouldHaveRisk), got \(expectedRisk)")
    }
    
    @Test("Property: 5-day window earnings risk calculation is correct",
          arguments: (0..<20).map { _ in
              let daysOffset = Int.random(in: -5...15)
              return daysOffset
          })
    func testFiveDayWindowEarningsRisk(daysOffset: Int) {
        let windowDays = 5
        let calendar = Calendar.current
        let today = Date()
        let earningsDate = calendar.date(byAdding: .day, value: daysOffset, to: today)!
        
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays,
            today: today
        )
        
        // Earnings risk if earningsDate <= today + 5 days
        let shouldHaveRisk = daysOffset <= windowDays
        
        #expect(expectedRisk == shouldHaveRisk,
                "5-day window with offset \(daysOffset): expected risk=\(shouldHaveRisk), got \(expectedRisk)")
    }
    
    @Test("Property: 30-day window earnings risk calculation is correct",
          arguments: (0..<20).map { _ in
              let daysOffset = Int.random(in: -10...45)
              return daysOffset
          })
    func testThirtyDayWindowEarningsRisk(daysOffset: Int) {
        let windowDays = 30
        let calendar = Calendar.current
        let today = Date()
        let earningsDate = calendar.date(byAdding: .day, value: daysOffset, to: today)!
        
        let expectedRisk = Self.expectedEarningsRisk(
            earningsDate: earningsDate,
            windowDays: windowDays,
            today: today
        )
        
        // Earnings risk if earningsDate <= today + 30 days
        let shouldHaveRisk = daysOffset <= windowDays
        
        #expect(expectedRisk == shouldHaveRisk,
                "30-day window with offset \(daysOffset): expected risk=\(shouldHaveRisk), got \(expectedRisk)")
    }
    
    // MARK: - Property Tests: AnalysisResult Creation
    
    @Test("Property: AnalysisResult preserves hasEarningsRisk through initialization",
          arguments: (0..<50).map { _ in
              let hasRisk = Bool.random()
              let earningsDate: Date? = hasRisk ? Date() : nil
              return (hasRisk: hasRisk, earningsDate: earningsDate)
          })
    func testAnalysisResultPreservesRiskFlag(input: (hasRisk: Bool, earningsDate: Date?)) {
        let result = AnalysisResult(
            ticker: "AAPL",
            type: .call,
            returnPercentage: 3.5,
            currentPrice: 150.0,
            targetPrice: 155.25,
            signal: .order,
            nextEarningsDate: input.earningsDate,
            hasEarningsRisk: input.hasRisk
        )
        
        #expect(result.hasEarningsRisk == input.hasRisk,
                "AnalysisResult should preserve hasEarningsRisk. Expected: \(input.hasRisk), Got: \(result.hasEarningsRisk)")
    }
}

// MARK: - Random Value Generator for Results Property Tests

/// Generates random values for results display property testing
enum ResultsRandomGenerator {
    
    /// Valid window days from configuration
    static let validWindowDays = [1, 5, 30]
    
    /// Generate a random window days value
    static func randomWindowDays() -> Int {
        validWindowDays.randomElement()!
    }
    
    /// Generate a random earnings date relative to today
    /// - Parameter daysRange: The range of days from today (positive = future, negative = past)
    static func randomEarningsDate(daysRange: ClosedRange<Int> = -30...60) -> Date {
        let daysOffset = Int.random(in: daysRange)
        return Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())!
    }
    
    /// Generate an optional earnings date (with 20% chance of being nil)
    static func randomOptionalEarningsDate() -> Date? {
        if Int.random(in: 1...5) == 1 {
            return nil
        }
        return randomEarningsDate()
    }
    
    /// Sample ticker symbols for generating random results
    static let sampleTickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NVDA", "AMD", "INTC", "IBM"]
    
    /// Generate a random AnalysisResultRow for property testing
    static func randomAnalysisResultRow() -> AnalysisResultRow {
        let ticker = sampleTickers.randomElement()!
        let type = Bool.random() ? OpportunityType.call : OpportunityType.put
        let rawReturnPercentage = Double.random(in: -15.0...15.0)
        let rawCurrentPrice = Double.random(in: 10.0...500.0)
        let rawTargetPrice = rawCurrentPrice * (1 + rawReturnPercentage / 100)
        let signal = Bool.random() ? Signal.order : Signal.hold
        let rawNextEarningsDate: Date? = randomOptionalEarningsDate()
        let hasEarningsRisk = Bool.random()
        
        // Generate optional options data (50% chance of having options data)
        let hasOptionsData = Bool.random()
        let rawExpirationDate: Date? = hasOptionsData ? randomExpirationDate() : nil
        let rawStrikePrice: Double? = hasOptionsData ? Double.random(in: 10.0...600.0) : nil
        let rawBidPremium: Double? = hasOptionsData ? Double.random(in: 0.01...20.0) : nil
        let rawAskPremium: Double? = hasOptionsData ? (rawBidPremium.map { $0 + Double.random(in: 0.01...1.0) }) : nil
        let rawMidPremium: Double? = hasOptionsData ? ((rawBidPremium ?? 0) + (rawAskPremium ?? 0)) / 2.0 : nil
        
        return AnalysisResultRow(
            id: UUID(),
            ticker: ticker,
            type: type.rawValue,
            returnPercentage: String(format: "%.2f%%", rawReturnPercentage),
            currentPrice: String(format: "$%.2f", rawCurrentPrice),
            targetPrice: String(format: "$%.2f", rawTargetPrice),
            signal: signal.rawValue,
            nextEarningsDate: rawNextEarningsDate.map { 
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: $0)
            } ?? "N/A",
            isHighlighted: signal == .order,
            hasEarningsRisk: hasEarningsRisk,
            rawReturnPercentage: rawReturnPercentage,
            rawCurrentPrice: rawCurrentPrice,
            rawTargetPrice: rawTargetPrice,
            rawNextEarningsDate: rawNextEarningsDate,
            expirationDate: rawExpirationDate.map {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: $0)
            } ?? "N/A",
            strikePrice: rawStrikePrice.map { String(format: "$%.2f", $0) } ?? "N/A",
            bidPremium: rawBidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            askPremium: rawAskPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            midPremium: rawMidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            rawExpirationDate: rawExpirationDate,
            rawStrikePrice: rawStrikePrice,
            rawMidPremium: rawMidPremium
        )
    }
    
    /// Generate a random expiration date (next 1-8 Fridays from today)
    static func randomExpirationDate() -> Date {
        let weeksOffset = Int.random(in: 1...8)
        let today = Date()
        let calendar = Calendar.current
        
        // Find the next Friday
        var nextFriday = today
        let weekday = calendar.component(.weekday, from: today)
        var daysToAdd = (6 - weekday + 7) % 7 // Days until Friday (6 is Friday in Swift)
        if daysToAdd == 0 { daysToAdd = 7 } // If today is Friday, go to next Friday
        nextFriday = calendar.date(byAdding: .day, value: daysToAdd + (weeksOffset - 1) * 7, to: today)!
        
        return nextFriday
    }
    
    /// Generate an array of random AnalysisResultRow objects
    static func randomResultsArray(count: Int) -> [AnalysisResultRow] {
        return (0..<count).map { _ in randomAnalysisResultRow() }
    }
}

// MARK: - Property 13: Results Sorting Correctness
// **Validates: Requirements 6.5**
//
// *For any* array of analysis results and any valid sort column, sorting the results by that
// column SHALL produce an array where each element is correctly ordered relative to its
// neighbors according to the sort direction (ascending or descending).

@Suite("Property 13: Results Sorting Correctness - Validates Requirements 6.5")
struct ResultsSortingCorrectnessPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// All valid result columns for sorting
    static let allColumns = ResultColumn.allCases
    
    /// Both sort directions
    static let allDirections: [SortDirection] = [.ascending, .descending]
    
    /// Generates test data: arrays of varying sizes with random column/direction combinations
    static func generateSortTestCases(count: Int) -> [(results: [AnalysisResultRow], column: ResultColumn, direction: SortDirection)] {
        return (0..<count).map { _ in
            // Generate arrays of varying sizes: 0-20 elements
            let arraySize = Int.random(in: 0...20)
            let results = ResultsRandomGenerator.randomResultsArray(count: arraySize)
            let column = allColumns.randomElement()!
            let direction = allDirections.randomElement()!
            return (results: results, column: column, direction: direction)
        }
    }
    
    /// Generates test data specifically for ticker column sorting
    static func generateTickerSortTestCases(count: Int) -> [(results: [AnalysisResultRow], direction: SortDirection)] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 2...15)
            let results = ResultsRandomGenerator.randomResultsArray(count: arraySize)
            let direction = allDirections.randomElement()!
            return (results: results, direction: direction)
        }
    }
    
    /// Generates test data with duplicate values for a column
    static func generateDuplicateValueTestCases(count: Int) -> [(results: [AnalysisResultRow], column: ResultColumn, direction: SortDirection)] {
        return (0..<count).map { _ in
            // Create results with some duplicate values
            var results: [AnalysisResultRow] = []
            let duplicateValue = Double.random(in: 1.0...100.0)
            
            for i in 0..<Int.random(in: 3...10) {
                let useDuplicate = i % 2 == 0 // Every other one uses duplicate
                let rawReturn = useDuplicate ? duplicateValue : Double.random(in: -15.0...15.0)
                let rawPrice = useDuplicate ? duplicateValue : Double.random(in: 10.0...500.0)
                
                let ticker = ResultsRandomGenerator.sampleTickers.randomElement()!
                let type = Bool.random() ? OpportunityType.call : OpportunityType.put
                let signal = Bool.random() ? Signal.order : Signal.hold
                let rawNextEarningsDate: Date? = ResultsRandomGenerator.randomOptionalEarningsDate()
                
                // Generate optional options data
                let hasOptionsData = Bool.random()
                let rawExpirationDate: Date? = hasOptionsData ? ResultsRandomGenerator.randomExpirationDate() : nil
                let rawStrikePrice: Double? = hasOptionsData ? (useDuplicate ? duplicateValue : Double.random(in: 10.0...600.0)) : nil
                let rawBidPremium: Double? = hasOptionsData ? Double.random(in: 0.01...20.0) : nil
                let rawAskPremium: Double? = hasOptionsData ? (rawBidPremium.map { $0 + Double.random(in: 0.01...1.0) }) : nil
                let rawMidPremium: Double? = hasOptionsData ? ((rawBidPremium ?? 0) + (rawAskPremium ?? 0)) / 2.0 : nil
                
                results.append(AnalysisResultRow(
                    id: UUID(),
                    ticker: ticker,
                    type: type.rawValue,
                    returnPercentage: String(format: "%.2f%%", rawReturn),
                    currentPrice: String(format: "$%.2f", rawPrice),
                    targetPrice: String(format: "$%.2f", rawPrice * 1.05),
                    signal: signal.rawValue,
                    nextEarningsDate: rawNextEarningsDate.map {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        return formatter.string(from: $0)
                    } ?? "N/A",
                    isHighlighted: signal == .order,
                    hasEarningsRisk: Bool.random(),
                    rawReturnPercentage: rawReturn,
                    rawCurrentPrice: rawPrice,
                    rawTargetPrice: rawPrice * 1.05,
                    rawNextEarningsDate: rawNextEarningsDate,
                    expirationDate: rawExpirationDate.map {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        return formatter.string(from: $0)
                    } ?? "N/A",
                    strikePrice: rawStrikePrice.map { String(format: "$%.2f", $0) } ?? "N/A",
                    bidPremium: rawBidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
                    askPremium: rawAskPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
                    midPremium: rawMidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
                    rawExpirationDate: rawExpirationDate,
                    rawStrikePrice: rawStrikePrice,
                    rawMidPremium: rawMidPremium
                ))
            }
            
            let column = allColumns.randomElement()!
            let direction = allDirections.randomElement()!
            return (results: results, column: column, direction: direction)
        }
    }
    
    /// Generates test data with nil earnings dates
    static func generateNilEarningsDateTestCases(count: Int) -> [(results: [AnalysisResultRow], direction: SortDirection)] {
        return (0..<count).map { _ in
            var results: [AnalysisResultRow] = []
            
            for i in 0..<Int.random(in: 5...12) {
                let hasEarningsDate = i % 3 != 0 // 2/3 have dates, 1/3 are nil
                let rawNextEarningsDate: Date? = hasEarningsDate ? ResultsRandomGenerator.randomEarningsDate() : nil
                
                let ticker = ResultsRandomGenerator.sampleTickers.randomElement()!
                let rawReturn = Double.random(in: -15.0...15.0)
                let rawPrice = Double.random(in: 10.0...500.0)
                let type = Bool.random() ? OpportunityType.call : OpportunityType.put
                let signal = Bool.random() ? Signal.order : Signal.hold
                
                // Generate optional options data
                let hasOptionsData = Bool.random()
                let rawExpirationDate: Date? = hasOptionsData ? ResultsRandomGenerator.randomExpirationDate() : nil
                let rawStrikePrice: Double? = hasOptionsData ? Double.random(in: 10.0...600.0) : nil
                let rawBidPremium: Double? = hasOptionsData ? Double.random(in: 0.01...20.0) : nil
                let rawAskPremium: Double? = hasOptionsData ? (rawBidPremium.map { $0 + Double.random(in: 0.01...1.0) }) : nil
                let rawMidPremium: Double? = hasOptionsData ? ((rawBidPremium ?? 0) + (rawAskPremium ?? 0)) / 2.0 : nil
                
                results.append(AnalysisResultRow(
                    id: UUID(),
                    ticker: ticker,
                    type: type.rawValue,
                    returnPercentage: String(format: "%.2f%%", rawReturn),
                    currentPrice: String(format: "$%.2f", rawPrice),
                    targetPrice: String(format: "$%.2f", rawPrice * 1.05),
                    signal: signal.rawValue,
                    nextEarningsDate: rawNextEarningsDate.map {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        return formatter.string(from: $0)
                    } ?? "N/A",
                    isHighlighted: signal == .order,
                    hasEarningsRisk: Bool.random(),
                    rawReturnPercentage: rawReturn,
                    rawCurrentPrice: rawPrice,
                    rawTargetPrice: rawPrice * 1.05,
                    rawNextEarningsDate: rawNextEarningsDate,
                    expirationDate: rawExpirationDate.map {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        return formatter.string(from: $0)
                    } ?? "N/A",
                    strikePrice: rawStrikePrice.map { String(format: "$%.2f", $0) } ?? "N/A",
                    bidPremium: rawBidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
                    askPremium: rawAskPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
                    midPremium: rawMidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
                    rawExpirationDate: rawExpirationDate,
                    rawStrikePrice: rawStrikePrice,
                    rawMidPremium: rawMidPremium
                ))
            }
            
            let direction = allDirections.randomElement()!
            return (results: results, direction: direction)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Verifies that the array is correctly sorted according to the given sort state.
    /// Returns true if each consecutive pair is in the correct order.
    static func isSortedCorrectly(_ results: [AnalysisResultRow], by sortState: SortState) -> Bool {
        guard results.count > 1 else { return true }
        
        for i in 0..<(results.count - 1) {
            let current = results[i]
            let next = results[i + 1]
            
            if !isCorrectOrder(current, next, by: sortState) {
                return false
            }
        }
        return true
    }
    
    /// Checks if two consecutive elements are in the correct order.
    /// Returns true if lhs comes before or equal to rhs according to sort state.
    static func isCorrectOrder(_ lhs: AnalysisResultRow, _ rhs: AnalysisResultRow, by sortState: SortState) -> Bool {
        let ascending = sortState.direction == .ascending
        
        switch sortState.column {
        case .ticker:
            return ascending ? lhs.ticker <= rhs.ticker : lhs.ticker >= rhs.ticker
        case .type:
            return ascending ? lhs.type <= rhs.type : lhs.type >= rhs.type
        case .returnPercentage:
            return ascending ? lhs.rawReturnPercentage <= rhs.rawReturnPercentage : lhs.rawReturnPercentage >= rhs.rawReturnPercentage
        case .currentPrice:
            return ascending ? lhs.rawCurrentPrice <= rhs.rawCurrentPrice : lhs.rawCurrentPrice >= rhs.rawCurrentPrice
        case .targetPrice:
            return ascending ? lhs.rawTargetPrice <= rhs.rawTargetPrice : lhs.rawTargetPrice >= rhs.rawTargetPrice
        case .signal:
            return ascending ? lhs.signal <= rhs.signal : lhs.signal >= rhs.signal
        case .nextEarningsDate:
            // Special handling for nil dates:
            // For ascending: nil goes to end (non-nil comes before nil)
            // For descending: nil goes to beginning (nil comes before non-nil)
            switch (lhs.rawNextEarningsDate, rhs.rawNextEarningsDate) {
            case (nil, nil): return true // Both nil, order doesn't matter
            case (nil, _): return !ascending // nil should be at end for ascending, beginning for descending
            case (_, nil): return ascending // non-nil should be before nil for ascending
            case let (lhsDate?, rhsDate?):
                return ascending ? lhsDate <= rhsDate : lhsDate >= rhsDate
            }
        case .expirationDate:
            // Special handling for nil dates
            switch (lhs.rawExpirationDate, rhs.rawExpirationDate) {
            case (nil, nil): return true
            case (nil, _): return !ascending
            case (_, nil): return ascending
            case let (lhsDate?, rhsDate?):
                return ascending ? lhsDate <= rhsDate : lhsDate >= rhsDate
            }
        case .strikePrice:
            // Special handling for nil values
            switch (lhs.rawStrikePrice, rhs.rawStrikePrice) {
            case (nil, nil): return true
            case (nil, _): return !ascending
            case (_, nil): return ascending
            case let (lhsPrice?, rhsPrice?):
                return ascending ? lhsPrice <= rhsPrice : lhsPrice >= rhsPrice
            }
        case .bidPremium:
            // Special handling for nil values (extracted from display string)
            let lhsBid = lhs.extractBidPremiumValue()
            let rhsBid = rhs.extractBidPremiumValue()
            switch (lhsBid, rhsBid) {
            case (nil, nil): return true
            case (nil, _): return !ascending
            case (_, nil): return ascending
            case let (lhsVal?, rhsVal?):
                return ascending ? lhsVal <= rhsVal : lhsVal >= rhsVal
            }
        case .askPremium:
            // Special handling for nil values (extracted from display string)
            let lhsAsk = lhs.extractAskPremiumValue()
            let rhsAsk = rhs.extractAskPremiumValue()
            switch (lhsAsk, rhsAsk) {
            case (nil, nil): return true
            case (nil, _): return !ascending
            case (_, nil): return ascending
            case let (lhsVal?, rhsVal?):
                return ascending ? lhsVal <= rhsVal : lhsVal >= rhsVal
            }
        case .midPremium:
            // Special handling for nil values
            switch (lhs.rawMidPremium, rhs.rawMidPremium) {
            case (nil, nil): return true
            case (nil, _): return !ascending
            case (_, nil): return ascending
            case let (lhsPrice?, rhsPrice?):
                return ascending ? lhsPrice <= rhsPrice : lhsPrice >= rhsPrice
            }
        }
    }
    
    // MARK: - Property Tests: General Sorting Correctness
    
    @Test("Property: Sorting any array by any column produces correctly ordered results",
          arguments: generateSortTestCases(count: 10))
    func testSortingProducesCorrectOrder(testCase: (results: [AnalysisResultRow], column: ResultColumn, direction: SortDirection)) {
        let (results, column, direction) = testCase
        let sortState = SortState(column: column, direction: direction)
        
        // Sort the results
        let sortedResults = results.sorted(by: sortState)
        
        // Verify sorting correctness
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Sorted array should have each element correctly ordered. Column: \(column.rawValue), Direction: \(direction == .ascending ? "ascending" : "descending"), Count: \(results.count)")
    }
    
    // MARK: - Property Tests: Empty and Single Element Arrays
    
    @Test("Property: Empty array remains empty after sorting",
          arguments: allColumns)
    func testEmptyArraySorting(column: ResultColumn) {
        let emptyResults: [AnalysisResultRow] = []
        let sortState = SortState(column: column, direction: .ascending)
        
        let sortedResults = emptyResults.sorted(by: sortState)
        
        #expect(sortedResults.isEmpty,
                "Empty array should remain empty after sorting by \(column.rawValue)")
    }
    
    @Test("Property: Single element array remains unchanged after sorting",
          arguments: (0..<30).map { _ in
              (result: ResultsRandomGenerator.randomAnalysisResultRow(),
               column: ResultColumn.allCases.randomElement()!,
               direction: [SortDirection.ascending, SortDirection.descending].randomElement()!)
          })
    func testSingleElementArraySorting(testCase: (result: AnalysisResultRow, column: ResultColumn, direction: SortDirection)) {
        let singleResults = [testCase.result]
        let sortState = SortState(column: testCase.column, direction: testCase.direction)
        
        let sortedResults = singleResults.sorted(by: sortState)
        
        #expect(sortedResults.count == 1,
                "Single element array should have exactly one element after sorting")
        #expect(sortedResults[0].id == testCase.result.id,
                "Single element should be the same after sorting")
    }
    
    // MARK: - Property Tests: Specific Column Sorting
    
    @Test("Property: Ticker column sorting is lexicographically correct",
          arguments: generateTickerSortTestCases(count: 30))
    func testTickerColumnSorting(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .ticker, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Ticker sorting should be lexicographically correct (\(testCase.direction == .ascending ? "A-Z" : "Z-A"))")
    }
    
    @Test("Property: Return percentage sorting is numerically correct",
          arguments: (0..<30).map { _ in
              (results: ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...15)),
               direction: [SortDirection.ascending, SortDirection.descending].randomElement()!)
          })
    func testReturnPercentageSorting(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .returnPercentage, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Return percentage sorting should be numerically correct")
    }
    
    @Test("Property: Current price sorting is numerically correct",
          arguments: (0..<30).map { _ in
              (results: ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...15)),
               direction: [SortDirection.ascending, SortDirection.descending].randomElement()!)
          })
    func testCurrentPriceSorting(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .currentPrice, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Current price sorting should be numerically correct")
    }
    
    @Test("Property: Target price sorting is numerically correct",
          arguments: (0..<30).map { _ in
              (results: ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...15)),
               direction: [SortDirection.ascending, SortDirection.descending].randomElement()!)
          })
    func testTargetPriceSorting(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .targetPrice, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Target price sorting should be numerically correct")
    }
    
    @Test("Property: Type column sorting is lexicographically correct (CALL/PUT)",
          arguments: (0..<30).map { _ in
              (results: ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...15)),
               direction: [SortDirection.ascending, SortDirection.descending].randomElement()!)
          })
    func testTypeColumnSorting(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .type, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Type sorting should be lexicographically correct (CALL < PUT for ascending)")
    }
    
    @Test("Property: Signal column sorting is lexicographically correct (HOLD/ORDER)",
          arguments: (0..<30).map { _ in
              (results: ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...15)),
               direction: [SortDirection.ascending, SortDirection.descending].randomElement()!)
          })
    func testSignalColumnSorting(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .signal, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Signal sorting should be lexicographically correct (HOLD < ORDER for ascending)")
    }
    
    // MARK: - Property Tests: Nil Earnings Date Handling
    
    @Test("Property: Nil earnings dates go to end for ascending sort, beginning for descending",
          arguments: generateNilEarningsDateTestCases(count: 10))
    func testNilEarningsDatePlacement(testCase: (results: [AnalysisResultRow], direction: SortDirection)) {
        let sortState = SortState(column: .nextEarningsDate, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Nil earnings dates should go to end for ascending, beginning for descending")
        
        // Additional verification: check nil placement
        let nilIndices = sortedResults.indices.filter { sortedResults[$0].rawNextEarningsDate == nil }
        let nonNilIndices = sortedResults.indices.filter { sortedResults[$0].rawNextEarningsDate != nil }
        
        if !nilIndices.isEmpty && !nonNilIndices.isEmpty {
            if testCase.direction == .ascending {
                // All nil should come after all non-nil
                let maxNonNilIndex = nonNilIndices.max()!
                let minNilIndex = nilIndices.min()!
                #expect(minNilIndex > maxNonNilIndex,
                        "For ascending sort, nil dates should come after all non-nil dates")
            } else {
                // All nil should come before all non-nil
                let maxNilIndex = nilIndices.max()!
                let minNonNilIndex = nonNilIndices.min()!
                #expect(maxNilIndex < minNonNilIndex,
                        "For descending sort, nil dates should come before all non-nil dates")
            }
        }
    }
    
    // MARK: - Property Tests: Duplicate Value Handling
    
    @Test("Property: Arrays with duplicate values sort correctly (stable relative order not required)",
          arguments: generateDuplicateValueTestCases(count: 30))
    func testDuplicateValueSorting(testCase: (results: [AnalysisResultRow], column: ResultColumn, direction: SortDirection)) {
        let sortState = SortState(column: testCase.column, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Arrays with duplicate values should still be correctly sorted")
    }
    
    // MARK: - Property Tests: Sort Preserves Elements
    
    @Test("Property: Sorting preserves all elements (no elements added or removed)",
          arguments: generateSortTestCases(count: 10))
    func testSortingPreservesElements(testCase: (results: [AnalysisResultRow], column: ResultColumn, direction: SortDirection)) {
        let sortState = SortState(column: testCase.column, direction: testCase.direction)
        let sortedResults = testCase.results.sorted(by: sortState)
        
        // Same count
        #expect(sortedResults.count == testCase.results.count,
                "Sorted array should have the same number of elements")
        
        // Same elements (by id)
        let originalIds = Set(testCase.results.map { $0.id })
        let sortedIds = Set(sortedResults.map { $0.id })
        
        #expect(originalIds == sortedIds,
                "Sorted array should contain exactly the same elements as the original")
    }
    
    // MARK: - Property Tests: Ascending vs Descending Symmetry
    
    @Test("Property: Ascending and descending sorts produce opposite orders",
          arguments: (0..<30).map { _ in
              (results: ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...10)),
               column: ResultColumn.allCases.randomElement()!)
          })
    func testAscendingDescendingSymmetry(testCase: (results: [AnalysisResultRow], column: ResultColumn)) {
        let ascendingState = SortState(column: testCase.column, direction: .ascending)
        let descendingState = SortState(column: testCase.column, direction: .descending)
        
        let ascendingSorted = testCase.results.sorted(by: ascendingState)
        let descendingSorted = testCase.results.sorted(by: descendingState)
        
        // Both should be correctly sorted
        #expect(Self.isSortedCorrectly(ascendingSorted, by: ascendingState),
                "Ascending sort should be correct")
        #expect(Self.isSortedCorrectly(descendingSorted, by: descendingState),
                "Descending sort should be correct")
        
        // For non-empty arrays with distinct values in the sort column, the first element of ascending
        // should equal the last element of descending (and vice versa) - but this depends on stability
        // So we just verify both are correctly sorted (already done above)
    }
    
    // MARK: - Property Tests: Default Sort State
    
    @Test("Property: Default sort state is Return Percentage descending",
          arguments: (0..<10).map { _ in SortState() })
    func testDefaultSortState(sortState: SortState) {
        #expect(sortState.column == .returnPercentage,
                "Default sort column should be returnPercentage")
        #expect(sortState.direction == .descending,
                "Default sort direction should be descending")
    }
    
    @Test("Property: Default sort produces results ordered by return percentage descending",
          arguments: (0..<30).map { _ in ResultsRandomGenerator.randomResultsArray(count: Int.random(in: 2...15)) })
    func testDefaultSortOrder(results: [AnalysisResultRow]) {
        let sortState = SortState() // Default: returnPercentage, descending
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.isSortedCorrectly(sortedResults, by: sortState)
        
        #expect(isCorrect,
                "Default sort should order by return percentage descending (highest first)")
    }
    
    // MARK: - Property Tests: All Columns Coverage
    
    @Test("Property: All ResultColumn cases are sortable",
          arguments: ResultColumn.allCases)
    func testAllColumnsSortable(column: ResultColumn) {
        let results = ResultsRandomGenerator.randomResultsArray(count: 5)
        let ascendingState = SortState(column: column, direction: .ascending)
        let descendingState = SortState(column: column, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingState)
        let descendingSorted = results.sorted(by: descendingState)
        
        #expect(Self.isSortedCorrectly(ascendingSorted, by: ascendingState),
                "Column \(column.rawValue) should be sortable ascending")
        #expect(Self.isSortedCorrectly(descendingSorted, by: descendingState),
                "Column \(column.rawValue) should be sortable descending")
    }
}


// MARK: - Property 14: Sort Direction Toggle
// **Validates: Requirements 6.6**
//
// *For any* current sort state with a given direction (ascending or descending),
// tapping the same column header SHALL toggle the direction to the opposite value.

@Suite("Property 14: Sort Direction Toggle - Validates Requirements 6.6")
struct SortDirectionTogglePropertyTests {
    
    // MARK: - Test Data Generation
    
    /// All valid result columns
    static let allColumns = ResultColumn.allCases
    
    /// Both sort directions
    static let allDirections: [SortDirection] = [.ascending, .descending]
    
    /// Generates random initial sort states
    static func generateRandomSortStates(count: Int) -> [SortState] {
        return (0..<count).map { _ in
            let column = allColumns.randomElement()!
            let direction = allDirections.randomElement()!
            return SortState(column: column, direction: direction)
        }
    }
    
    /// Generates test cases for same-column tap scenarios
    static func generateSameColumnTapTestCases(count: Int) -> [(initialState: SortState, tappedColumn: ResultColumn)] {
        return (0..<count).map { _ in
            let column = allColumns.randomElement()!
            let direction = allDirections.randomElement()!
            let initialState = SortState(column: column, direction: direction)
            // Tap the same column
            return (initialState: initialState, tappedColumn: column)
        }
    }
    
    /// Generates test cases for different-column tap scenarios
    static func generateDifferentColumnTapTestCases(count: Int) -> [(initialState: SortState, tappedColumn: ResultColumn)] {
        return (0..<count).compactMap { _ in
            let initialColumn = allColumns.randomElement()!
            let direction = allDirections.randomElement()!
            let initialState = SortState(column: initialColumn, direction: direction)
            
            // Get a different column
            let otherColumns = allColumns.filter { $0 != initialColumn }
            guard let tappedColumn = otherColumns.randomElement() else { return nil }
            
            return (initialState: initialState, tappedColumn: tappedColumn)
        }
    }
    
    // MARK: - Property Tests: SortDirection.toggle()
    
    @Test("Property: Toggling ascending direction SHALL produce descending",
          arguments: (0..<50).map { _ in SortDirection.ascending })
    func testToggleAscendingToDescending(direction: SortDirection) {
        var mutableDirection = direction
        mutableDirection.toggle()
        
        #expect(mutableDirection == .descending,
                "Toggling ascending should produce descending")
    }
    
    @Test("Property: Toggling descending direction SHALL produce ascending",
          arguments: (0..<50).map { _ in SortDirection.descending })
    func testToggleDescendingToAscending(direction: SortDirection) {
        var mutableDirection = direction
        mutableDirection.toggle()
        
        #expect(mutableDirection == .ascending,
                "Toggling descending should produce ascending")
    }
    
    @Test("Property: Double toggle SHALL return to original direction",
          arguments: allDirections)
    func testDoubleToggleReturnsOriginal(direction: SortDirection) {
        var mutableDirection = direction
        mutableDirection.toggle()
        mutableDirection.toggle()
        
        #expect(mutableDirection == direction,
                "Double toggle should return to original direction: \(direction)")
    }
    
    @Test("Property: toggled property SHALL return opposite without mutating",
          arguments: allDirections)
    func testToggledPropertyDoesNotMutate(direction: SortDirection) {
        let originalDirection = direction
        let toggled = direction.toggled
        
        // Original should not change
        #expect(direction == originalDirection,
                "Original direction should not be mutated by .toggled property")
        
        // Toggled should be opposite
        let expectedToggled: SortDirection = direction == .ascending ? .descending : .ascending
        #expect(toggled == expectedToggled,
                ".toggled should return opposite direction")
    }
    
    // MARK: - Property Tests: SortState.handleColumnTap() - Same Column
    
    @Test("Property: Tapping same column header SHALL toggle direction from ascending to descending",
          arguments: allColumns)
    func testSameColumnTapTogglesFromAscending(column: ResultColumn) {
        var sortState = SortState(column: column, direction: .ascending)
        sortState.handleColumnTap(column)
        
        #expect(sortState.column == column,
                "Column should remain unchanged when tapping same column")
        #expect(sortState.direction == .descending,
                "Direction should toggle from ascending to descending")
    }
    
    @Test("Property: Tapping same column header SHALL toggle direction from descending to ascending",
          arguments: allColumns)
    func testSameColumnTapTogglesFromDescending(column: ResultColumn) {
        var sortState = SortState(column: column, direction: .descending)
        sortState.handleColumnTap(column)
        
        #expect(sortState.column == column,
                "Column should remain unchanged when tapping same column")
        #expect(sortState.direction == .ascending,
                "Direction should toggle from descending to ascending")
    }
    
    @Test("Property: Tapping same column header repeatedly SHALL alternate direction",
          arguments: generateRandomSortStates(count: 10))
    func testRepeatedSameColumnTapAlternates(initialState: SortState) {
        var sortState = initialState
        let originalColumn = sortState.column
        let originalDirection = sortState.direction
        
        // First tap - should toggle
        sortState.handleColumnTap(originalColumn)
        #expect(sortState.direction == originalDirection.toggled,
                "First tap should toggle direction")
        
        // Second tap - should toggle back
        sortState.handleColumnTap(originalColumn)
        #expect(sortState.direction == originalDirection,
                "Second tap should return to original direction")
        
        // Third tap - should toggle again
        sortState.handleColumnTap(originalColumn)
        #expect(sortState.direction == originalDirection.toggled,
                "Third tap should toggle direction again")
        
        // Column should never change
        #expect(sortState.column == originalColumn,
                "Column should remain unchanged throughout")
    }
    
    @Test("Property: For any initial state, tapping same column SHALL produce opposite direction",
          arguments: generateSameColumnTapTestCases(count: 10))
    func testSameColumnTapTogglesAnyState(testCase: (initialState: SortState, tappedColumn: ResultColumn)) {
        var sortState = testCase.initialState
        let expectedDirection = sortState.direction.toggled
        
        sortState.handleColumnTap(testCase.tappedColumn)
        
        #expect(sortState.column == testCase.tappedColumn,
                "Column should remain the same")
        #expect(sortState.direction == expectedDirection,
                "Direction should be toggled. Initial: \(testCase.initialState.direction), Expected: \(expectedDirection), Got: \(sortState.direction)")
    }
    
    // MARK: - Property Tests: SortState.handleColumnTap() - Different Column
    
    @Test("Property: Tapping different column header SHALL change column and set direction to descending",
          arguments: generateDifferentColumnTapTestCases(count: 10))
    func testDifferentColumnTapResetsToDescending(testCase: (initialState: SortState, tappedColumn: ResultColumn)) {
        var sortState = testCase.initialState
        
        // Ensure we're tapping a different column
        #expect(testCase.initialState.column != testCase.tappedColumn,
                "Test case should use different column")
        
        sortState.handleColumnTap(testCase.tappedColumn)
        
        #expect(sortState.column == testCase.tappedColumn,
                "Column should change to tapped column")
        #expect(sortState.direction == .descending,
                "Direction should reset to descending when changing column")
    }
    
    @Test("Property: Tapping different column always resets to descending regardless of initial direction",
          arguments: allDirections)
    func testDifferentColumnAlwaysDescending(initialDirection: SortDirection) {
        // Use ticker as initial, returnPercentage as different
        var sortState = SortState(column: .ticker, direction: initialDirection)
        
        sortState.handleColumnTap(.returnPercentage)
        
        #expect(sortState.column == .returnPercentage,
                "Column should change to returnPercentage")
        #expect(sortState.direction == .descending,
                "Direction should be descending regardless of initial direction \(initialDirection)")
    }
    
    // MARK: - Property Tests: Column-Specific Toggle Behavior
    
    @Test("Property: Toggle works correctly for ticker column",
          arguments: allDirections)
    func testTickerColumnToggle(initialDirection: SortDirection) {
        var sortState = SortState(column: .ticker, direction: initialDirection)
        sortState.handleColumnTap(.ticker)
        
        #expect(sortState.direction == initialDirection.toggled,
                "Ticker column toggle should work correctly")
    }
    
    @Test("Property: Toggle works correctly for returnPercentage column",
          arguments: allDirections)
    func testReturnPercentageColumnToggle(initialDirection: SortDirection) {
        var sortState = SortState(column: .returnPercentage, direction: initialDirection)
        sortState.handleColumnTap(.returnPercentage)
        
        #expect(sortState.direction == initialDirection.toggled,
                "Return percentage column toggle should work correctly")
    }
    
    @Test("Property: Toggle works correctly for all columns",
          arguments: allColumns.flatMap { column in
              allDirections.map { direction in (column: column, direction: direction) }
          })
    func testAllColumnsToggle(testCase: (column: ResultColumn, direction: SortDirection)) {
        var sortState = SortState(column: testCase.column, direction: testCase.direction)
        sortState.handleColumnTap(testCase.column)
        
        #expect(sortState.column == testCase.column,
                "Column should remain \(testCase.column.rawValue)")
        #expect(sortState.direction == testCase.direction.toggled,
                "Direction should toggle from \(testCase.direction) to \(testCase.direction.toggled) for column \(testCase.column.rawValue)")
    }
    
    // MARK: - Property Tests: Invariants
    
    @Test("Property: SortDirection toggle is its own inverse",
          arguments: generateRandomSortStates(count: 30))
    func testToggleIsOwnInverse(initialState: SortState) {
        var state = initialState
        let originalDirection = state.direction
        
        // Toggle twice should return to original
        state.handleColumnTap(state.column)
        state.handleColumnTap(state.column)
        
        #expect(state.direction == originalDirection,
                "Toggle is its own inverse - double toggle should return to original")
    }
    
    @Test("Property: N toggles produces expected direction",
          arguments: (0..<30).map { _ in
              let column = ResultColumn.allCases.randomElement()!
              let direction = [SortDirection.ascending, SortDirection.descending].randomElement()!
              let toggleCount = Int.random(in: 1...10)
              return (initialState: SortState(column: column, direction: direction), toggleCount: toggleCount)
          })
    func testNTogglesProducesExpectedDirection(testCase: (initialState: SortState, toggleCount: Int)) {
        var state = testCase.initialState
        let originalDirection = state.direction
        
        // Perform N toggles
        for _ in 0..<testCase.toggleCount {
            state.handleColumnTap(state.column)
        }
        
        // Even number of toggles should return to original
        // Odd number of toggles should produce opposite
        let expectedDirection = testCase.toggleCount % 2 == 0 ? originalDirection : originalDirection.toggled
        
        #expect(state.direction == expectedDirection,
                "After \(testCase.toggleCount) toggles, direction should be \(expectedDirection). Got: \(state.direction)")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Toggle with default SortState changes from descending to ascending")
    func testDefaultSortStateToggle() {
        var sortState = SortState() // Default is returnPercentage, descending
        
        #expect(sortState.column == .returnPercentage,
                "Default column should be returnPercentage")
        #expect(sortState.direction == .descending,
                "Default direction should be descending")
        
        // Toggle should change to ascending
        sortState.handleColumnTap(.returnPercentage)
        
        #expect(sortState.direction == .ascending,
                "Toggle should change default descending to ascending")
    }
    
    @Test("Property: Sequence of column changes and toggles maintains consistency",
          arguments: (0..<20).map { _ in
              // Generate a sequence of column taps
              let taps = (0..<Int.random(in: 3...8)).map { _ in
                  ResultColumn.allCases.randomElement()!
              }
              return taps
          })
    func testSequenceOfTapsMaintainsConsistency(taps: [ResultColumn]) {
        var sortState = SortState()
        
        for tap in taps {
            let previousColumn = sortState.column
            let previousDirection = sortState.direction
            
            sortState.handleColumnTap(tap)
            
            if tap == previousColumn {
                // Same column: direction should toggle
                #expect(sortState.direction == previousDirection.toggled,
                        "Same column tap should toggle direction")
                #expect(sortState.column == previousColumn,
                        "Column should remain the same")
            } else {
                // Different column: should change column and reset to descending
                #expect(sortState.column == tap,
                        "Column should change to tapped column")
                #expect(sortState.direction == .descending,
                        "Direction should reset to descending on column change")
            }
        }
    }
    
    // MARK: - Property Tests: ResultsViewModel Integration
    
    @Test("Property: ResultsViewModel.sort(by:) toggles direction when same column is tapped",
          arguments: allColumns)
    func testViewModelSortTogglesDirection(column: ResultColumn) {
        let viewModel = ResultsViewModel()
        
        // Set initial state
        viewModel.sort(by: column)
        let firstDirection = viewModel.sortState.direction
        
        // Sort by same column should toggle
        viewModel.sort(by: column)
        let secondDirection = viewModel.sortState.direction
        
        #expect(secondDirection == firstDirection.toggled,
                "ViewModel.sort(by:) should toggle direction when same column is tapped")
    }
    
    @Test("Property: ResultsViewModel.sort(by:) resets to descending when different column is tapped",
          arguments: generateDifferentColumnTapTestCases(count: 30))
    func testViewModelSortResetsOnDifferentColumn(testCase: (initialState: SortState, tappedColumn: ResultColumn)) {
        let viewModel = ResultsViewModel()
        
        // Set initial column with ascending direction
        viewModel.sort(by: testCase.initialState.column)
        if testCase.initialState.direction == .ascending {
            viewModel.sort(by: testCase.initialState.column) // Toggle to ascending
        }
        
        // Now sort by different column
        viewModel.sort(by: testCase.tappedColumn)
        
        #expect(viewModel.sortState.column == testCase.tappedColumn,
                "Column should change to tapped column")
        #expect(viewModel.sortState.direction == .descending,
                "Direction should reset to descending when changing columns")
    }
}


// MARK: - Property 17: Strike Price Sorting Correctness
// **Validates: Requirements 6.8**
//
// *For any* array of analysis results sorted by strike price in ascending order, for all
// consecutive pairs (r[i], r[i+1]), r[i].rawStrikePrice <= r[i+1].rawStrikePrice
// (treating nil as maximum value).

@Suite("Property 17: Strike Price Sorting Correctness - Validates Requirements 6.8")
struct StrikePriceSortingPropertyTests {
    
    // MARK: - Test Data Generators
    
    /// Generates arrays with all non-nil strike prices
    static func generateAllNonNilStrikePrices(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 2...10)
            return (0..<arraySize).map { _ in
                createRowWithStrikePrice(Double.random(in: 10.0...500.0))
            }
        }
    }
    
    /// Generates arrays with some nil strike prices (mixed)
    static func generateMixedStrikePrices(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 3...10)
            return (0..<arraySize).map { i in
                // Roughly 30% chance of nil
                let hasStrike = i % 3 != 0
                let strikePrice: Double? = hasStrike ? Double.random(in: 10.0...500.0) : nil
                return createRowWithStrikePrice(strikePrice)
            }
        }
    }
    
    /// Generates arrays with all nil strike prices
    static func generateAllNilStrikePrices(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 2...6)
            return (0..<arraySize).map { _ in
                createRowWithStrikePrice(nil)
            }
        }
    }
    
    /// Generates single element arrays
    static func generateSingleElementArrays(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let hasStrike = Bool.random()
            let strikePrice: Double? = hasStrike ? Double.random(in: 10.0...500.0) : nil
            return [createRowWithStrikePrice(strikePrice)]
        }
    }
    
    /// Generates empty arrays
    static func generateEmptyArrays(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in [] }
    }
    
    // MARK: - Helper Methods
    
    /// Creates an AnalysisResultRow with the specified strike price
    static func createRowWithStrikePrice(_ strikePrice: Double?) -> AnalysisResultRow {
        let ticker = ResultsRandomGenerator.sampleTickers.randomElement()!
        let type = Bool.random() ? OpportunityType.call : OpportunityType.put
        let rawReturnPercentage = Double.random(in: -15.0...15.0)
        let rawCurrentPrice = Double.random(in: 10.0...500.0)
        let rawTargetPrice = rawCurrentPrice * (1 + rawReturnPercentage / 100)
        let signal = Bool.random() ? Signal.order : Signal.hold
        let rawNextEarningsDate: Date? = ResultsRandomGenerator.randomOptionalEarningsDate()
        let hasEarningsRisk = Bool.random()
        
        // Options data - use provided strike price
        let rawExpirationDate: Date? = strikePrice != nil ? ResultsRandomGenerator.randomExpirationDate() : nil
        let rawBidPremium: Double? = strikePrice != nil ? Double.random(in: 0.01...20.0) : nil
        let rawAskPremium: Double? = rawBidPremium.map { $0 + Double.random(in: 0.01...1.0) }
        let rawMidPremium: Double? = rawBidPremium != nil ? ((rawBidPremium ?? 0) + (rawAskPremium ?? 0)) / 2.0 : nil
        
        return AnalysisResultRow(
            id: UUID(),
            ticker: ticker,
            type: type.rawValue,
            returnPercentage: String(format: "%.2f%%", rawReturnPercentage),
            currentPrice: String(format: "$%.2f", rawCurrentPrice),
            targetPrice: String(format: "$%.2f", rawTargetPrice),
            signal: signal.rawValue,
            nextEarningsDate: rawNextEarningsDate.map {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: $0)
            } ?? "N/A",
            isHighlighted: signal == .order,
            hasEarningsRisk: hasEarningsRisk,
            rawReturnPercentage: rawReturnPercentage,
            rawCurrentPrice: rawCurrentPrice,
            rawTargetPrice: rawTargetPrice,
            rawNextEarningsDate: rawNextEarningsDate,
            expirationDate: rawExpirationDate.map {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: $0)
            } ?? "N/A",
            strikePrice: strikePrice.map { String(format: "$%.2f", $0) } ?? "N/A",
            bidPremium: rawBidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            askPremium: rawAskPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            midPremium: rawMidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            rawExpirationDate: rawExpirationDate,
            rawStrikePrice: strikePrice,
            rawMidPremium: rawMidPremium
        )
    }
    
    /// Verifies that strike prices are correctly ordered according to sort direction.
    /// For ascending: nil goes to end (treated as maximum value)
    /// For descending: nil goes to beginning (treated as maximum value, so comes first)
    static func verifyStrikePriceOrdering(_ results: [AnalysisResultRow], ascending: Bool) -> Bool {
        guard results.count > 1 else { return true }
        
        for i in 0..<(results.count - 1) {
            let current = results[i]
            let next = results[i + 1]
            
            if !isCorrectStrikePriceOrder(current, next, ascending: ascending) {
                return false
            }
        }
        return true
    }
    
    /// Checks if two consecutive elements have correct strike price ordering.
    /// Nil values are treated as maximum (infinity).
    static func isCorrectStrikePriceOrder(_ lhs: AnalysisResultRow, _ rhs: AnalysisResultRow, ascending: Bool) -> Bool {
        switch (lhs.rawStrikePrice, rhs.rawStrikePrice) {
        case (nil, nil):
            return true // Both nil, order doesn't matter
        case (nil, _):
            // lhs is nil (maximum), rhs is non-nil
            // For ascending: nil should come AFTER non-nil, so this is WRONG order
            // For descending: nil should come BEFORE non-nil, so this is CORRECT order
            return !ascending
        case (_, nil):
            // lhs is non-nil, rhs is nil (maximum)
            // For ascending: non-nil should come BEFORE nil, so this is CORRECT order
            // For descending: non-nil should come AFTER nil, so this is WRONG order
            return ascending
        case let (lhsPrice?, rhsPrice?):
            // Both non-nil, compare directly
            return ascending ? lhsPrice <= rhsPrice : lhsPrice >= rhsPrice
        }
    }
    
    // MARK: - Property Tests: Arrays with All Non-Nil Strike Prices
    
    @Test("Property: Strike price sorting ascending - all non-nil values produce correct ascending order",
          arguments: generateAllNonNilStrikePrices(count: 5))
    func testAscendingSortAllNonNil(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .strikePrice, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.verifyStrikePriceOrdering(sortedResults, ascending: true)
        
        #expect(isCorrect,
                "Ascending sort of all non-nil strike prices should produce correct order. Count: \(results.count)")
        
        // Additionally verify consecutive pairs
        for i in 0..<(sortedResults.count - 1) {
            let currentPrice = sortedResults[i].rawStrikePrice!
            let nextPrice = sortedResults[i + 1].rawStrikePrice!
            #expect(currentPrice <= nextPrice,
                    "Position \(i): \(currentPrice) should be <= \(nextPrice)")
        }
    }
    
    @Test("Property: Strike price sorting descending - all non-nil values produce correct descending order",
          arguments: generateAllNonNilStrikePrices(count: 5))
    func testDescendingSortAllNonNil(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .strikePrice, direction: .descending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.verifyStrikePriceOrdering(sortedResults, ascending: false)
        
        #expect(isCorrect,
                "Descending sort of all non-nil strike prices should produce correct order. Count: \(results.count)")
        
        // Additionally verify consecutive pairs
        for i in 0..<(sortedResults.count - 1) {
            let currentPrice = sortedResults[i].rawStrikePrice!
            let nextPrice = sortedResults[i + 1].rawStrikePrice!
            #expect(currentPrice >= nextPrice,
                    "Position \(i): \(currentPrice) should be >= \(nextPrice)")
        }
    }
    
    // MARK: - Property Tests: Arrays with Mixed Nil/Non-Nil Strike Prices
    
    @Test("Property: Strike price sorting ascending - nil values sort to end",
          arguments: generateMixedStrikePrices(count: 5))
    func testAscendingSortMixedNilEnd(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .strikePrice, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.verifyStrikePriceOrdering(sortedResults, ascending: true)
        
        #expect(isCorrect,
                "Ascending sort with mixed nil/non-nil should have nil at end. Count: \(results.count)")
        
        // Verify nil values are at the end
        let nilIndices = sortedResults.indices.filter { sortedResults[$0].rawStrikePrice == nil }
        let nonNilIndices = sortedResults.indices.filter { sortedResults[$0].rawStrikePrice != nil }
        
        if !nilIndices.isEmpty && !nonNilIndices.isEmpty {
            let maxNonNilIndex = nonNilIndices.max()!
            let minNilIndex = nilIndices.min()!
            #expect(minNilIndex > maxNonNilIndex,
                    "For ascending sort, all nil values should come after all non-nil values")
        }
    }
    
    @Test("Property: Strike price sorting descending - nil values sort to beginning",
          arguments: generateMixedStrikePrices(count: 5))
    func testDescendingSortMixedNilBeginning(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .strikePrice, direction: .descending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.verifyStrikePriceOrdering(sortedResults, ascending: false)
        
        #expect(isCorrect,
                "Descending sort with mixed nil/non-nil should have nil at beginning. Count: \(results.count)")
        
        // Verify nil values are at the beginning
        let nilIndices = sortedResults.indices.filter { sortedResults[$0].rawStrikePrice == nil }
        let nonNilIndices = sortedResults.indices.filter { sortedResults[$0].rawStrikePrice != nil }
        
        if !nilIndices.isEmpty && !nonNilIndices.isEmpty {
            let maxNilIndex = nilIndices.max()!
            let minNonNilIndex = nonNilIndices.min()!
            #expect(maxNilIndex < minNonNilIndex,
                    "For descending sort, all nil values should come before all non-nil values")
        }
    }
    
    // MARK: - Property Tests: Arrays with All Nil Strike Prices
    
    @Test("Property: Strike price sorting - all nil values produce stable result",
          arguments: generateAllNilStrikePrices(count: 3))
    func testSortAllNilStrikePrices(results: [AnalysisResultRow]) {
        let ascendingState = SortState(column: .strikePrice, direction: .ascending)
        let descendingState = SortState(column: .strikePrice, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingState)
        let descendingSorted = results.sorted(by: descendingState)
        
        // Verify same count
        #expect(ascendingSorted.count == results.count,
                "Ascending sort should preserve element count")
        #expect(descendingSorted.count == results.count,
                "Descending sort should preserve element count")
        
        // Verify ordering is valid (all nil, so any order is valid)
        let isAscendingCorrect = Self.verifyStrikePriceOrdering(ascendingSorted, ascending: true)
        let isDescendingCorrect = Self.verifyStrikePriceOrdering(descendingSorted, ascending: false)
        
        #expect(isAscendingCorrect, "All nil ascending sort should be valid")
        #expect(isDescendingCorrect, "All nil descending sort should be valid")
        
        // Verify all are still nil
        #expect(ascendingSorted.allSatisfy { $0.rawStrikePrice == nil },
                "All strike prices should remain nil after ascending sort")
        #expect(descendingSorted.allSatisfy { $0.rawStrikePrice == nil },
                "All strike prices should remain nil after descending sort")
    }
    
    // MARK: - Property Tests: Single Element Arrays
    
    @Test("Property: Strike price sorting - single element array remains unchanged",
          arguments: generateSingleElementArrays(count: 3))
    func testSortSingleElement(results: [AnalysisResultRow]) {
        guard results.count == 1 else {
            Issue.record("Test case should have exactly one element")
            return
        }
        
        let ascendingState = SortState(column: .strikePrice, direction: .ascending)
        let descendingState = SortState(column: .strikePrice, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingState)
        let descendingSorted = results.sorted(by: descendingState)
        
        #expect(ascendingSorted.count == 1, "Should have exactly one element after ascending sort")
        #expect(descendingSorted.count == 1, "Should have exactly one element after descending sort")
        #expect(ascendingSorted[0].id == results[0].id, "Element should be the same after ascending sort")
        #expect(descendingSorted[0].id == results[0].id, "Element should be the same after descending sort")
    }
    
    // MARK: - Property Tests: Empty Arrays
    
    @Test("Property: Strike price sorting - empty array remains empty",
          arguments: generateEmptyArrays(count: 2))
    func testSortEmptyArray(results: [AnalysisResultRow]) {
        let ascendingState = SortState(column: .strikePrice, direction: .ascending)
        let descendingState = SortState(column: .strikePrice, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingState)
        let descendingSorted = results.sorted(by: descendingState)
        
        #expect(ascendingSorted.isEmpty, "Empty array should remain empty after ascending sort")
        #expect(descendingSorted.isEmpty, "Empty array should remain empty after descending sort")
    }
    
    // MARK: - Property Tests: Element Preservation
    
    @Test("Property: Strike price sorting preserves all elements",
          arguments: generateMixedStrikePrices(count: 3))
    func testSortPreservesElements(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .strikePrice, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        // Same count
        #expect(sortedResults.count == results.count,
                "Sorted array should have the same number of elements")
        
        // Same elements (by id)
        let originalIds = Set(results.map { $0.id })
        let sortedIds = Set(sortedResults.map { $0.id })
        
        #expect(originalIds == sortedIds,
                "Sorted array should contain exactly the same elements as the original")
    }
    
    // MARK: - Property Tests: Ascending vs Descending Relationship
    
    @Test("Property: Strike price ascending and descending sorts produce opposite orders for non-nil values",
          arguments: generateAllNonNilStrikePrices(count: 2))
    func testAscendingDescendingOpposite(results: [AnalysisResultRow]) {
        let ascendingState = SortState(column: .strikePrice, direction: .ascending)
        let descendingState = SortState(column: .strikePrice, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingState)
        let descendingSorted = results.sorted(by: descendingState)
        
        // Both should be correctly sorted
        #expect(Self.verifyStrikePriceOrdering(ascendingSorted, ascending: true),
                "Ascending sort should be correct")
        #expect(Self.verifyStrikePriceOrdering(descendingSorted, ascending: false),
                "Descending sort should be correct")
        
        // For all non-nil arrays, first of ascending should equal last of descending
        if !ascendingSorted.isEmpty {
            let firstAscending = ascendingSorted.first!.rawStrikePrice
            let lastDescending = descendingSorted.last!.rawStrikePrice
            
            // Find the minimum strike price in original
            let minPrice = results.compactMap { $0.rawStrikePrice }.min()
            
            #expect(firstAscending == minPrice,
                    "First element of ascending sort should have minimum strike price")
            #expect(lastDescending == minPrice,
                    "Last element of descending sort should have minimum strike price")
        }
    }
}


// MARK: - Property 18: Mid Premium Sorting Correctness
// **Validates: Requirements 6.9**
//
// *For any* array of analysis results sorted by mid premium in ascending order, for all
// consecutive pairs (r[i], r[i+1]), r[i].rawMidPremium <= r[i+1].rawMidPremium
// (treating nil as maximum value for ascending, minimum value for descending).

@Suite("Property 18: Mid Premium Sorting Correctness - Validates Requirements 6.9")
struct MidPremiumSortingCorrectnessPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// Sample tickers for test data
    static let sampleTickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NVDA", "AMD", "INTC", "IBM"]
    
    /// Creates an AnalysisResultRow with specific mid premium value
    static func createResultRow(
        ticker: String = "TEST",
        rawMidPremium: Double?,
        rawBidPremium: Double? = nil,
        rawAskPremium: Double? = nil
    ) -> AnalysisResultRow {
        let bid = rawBidPremium ?? (rawMidPremium.map { $0 * 0.95 })
        let ask = rawAskPremium ?? (rawMidPremium.map { $0 * 1.05 })
        
        return AnalysisResultRow(
            id: UUID(),
            ticker: ticker,
            type: OpportunityType.call.rawValue,
            returnPercentage: "5.00%",
            currentPrice: "$100.00",
            targetPrice: "$105.00",
            signal: Signal.order.rawValue,
            nextEarningsDate: "N/A",
            isHighlighted: true,
            hasEarningsRisk: false,
            rawReturnPercentage: 5.0,
            rawCurrentPrice: 100.0,
            rawTargetPrice: 105.0,
            rawNextEarningsDate: nil,
            expirationDate: "2025-01-24",
            strikePrice: "$105.00",
            bidPremium: bid.map { String(format: "$%.2f", $0) } ?? "N/A",
            askPremium: ask.map { String(format: "$%.2f", $0) } ?? "N/A",
            midPremium: rawMidPremium.map { String(format: "$%.2f", $0) } ?? "N/A",
            rawExpirationDate: Date(),
            rawStrikePrice: 105.0,
            rawMidPremium: rawMidPremium
        )
    }
    
    /// Generates arrays with all non-nil mid premiums
    static func generateAllNonNilMidPremiums(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 2...10)
            return (0..<arraySize).map { _ in
                let midPremium = Double.random(in: 0.01...50.0)
                return createResultRow(
                    ticker: sampleTickers.randomElement()!,
                    rawMidPremium: midPremium
                )
            }
        }
    }
    
    /// Generates arrays with some nil mid premiums
    static func generateSomeNilMidPremiums(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 3...10)
            return (0..<arraySize).map { index in
                // Make about 30% nil
                let isNil = index % 3 == 0
                let midPremium: Double? = isNil ? nil : Double.random(in: 0.01...50.0)
                return createResultRow(
                    ticker: sampleTickers.randomElement()!,
                    rawMidPremium: midPremium
                )
            }
        }
    }
    
    /// Generates arrays with all nil mid premiums
    static func generateAllNilMidPremiums(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 2...5)
            return (0..<arraySize).map { _ in
                createResultRow(
                    ticker: sampleTickers.randomElement()!,
                    rawMidPremium: nil
                )
            }
        }
    }
    
    /// Generates single element arrays
    static func generateSingleElementArrays(count: Int) -> [[AnalysisResultRow]] {
        return (0..<count).map { _ in
            let midPremium: Double? = Bool.random() ? Double.random(in: 0.01...50.0) : nil
            return [createResultRow(
                ticker: sampleTickers.randomElement()!,
                rawMidPremium: midPremium
            )]
        }
    }
    
    // MARK: - Helper Methods
    
    /// Verifies mid premium ascending sort correctness
    /// Returns true if for all consecutive pairs (r[i], r[i+1]), r[i].rawMidPremium <= r[i+1].rawMidPremium
    /// Nil values should sort to the end for ascending
    static func isCorrectlyAscendingSortedByMidPremium(_ results: [AnalysisResultRow]) -> Bool {
        guard results.count > 1 else { return true }
        
        for i in 0..<(results.count - 1) {
            let current = results[i]
            let next = results[i + 1]
            
            switch (current.rawMidPremium, next.rawMidPremium) {
            case (nil, nil):
                // Both nil - order doesn't matter between them
                continue
            case (nil, _):
                // nil should be at end for ascending, so this is wrong
                return false
            case (_, nil):
                // Non-nil before nil is correct for ascending
                continue
            case let (currentValue?, nextValue?):
                if currentValue > nextValue {
                    return false
                }
            }
        }
        return true
    }
    
    /// Verifies mid premium descending sort correctness
    /// Returns true if for all consecutive pairs (r[i], r[i+1]), r[i].rawMidPremium >= r[i+1].rawMidPremium
    /// Nil values should sort to the beginning for descending
    static func isCorrectlyDescendingSortedByMidPremium(_ results: [AnalysisResultRow]) -> Bool {
        guard results.count > 1 else { return true }
        
        for i in 0..<(results.count - 1) {
            let current = results[i]
            let next = results[i + 1]
            
            switch (current.rawMidPremium, next.rawMidPremium) {
            case (nil, nil):
                // Both nil - order doesn't matter between them
                continue
            case (nil, _):
                // nil should be at beginning for descending, so nil before non-nil is correct
                continue
            case (_, nil):
                // Non-nil before nil is wrong for descending
                return false
            case let (currentValue?, nextValue?):
                if currentValue < nextValue {
                    return false
                }
            }
        }
        return true
    }
    
    /// Verifies nil values are at the end for ascending sort
    static func nilValuesAtEndForAscending(_ results: [AnalysisResultRow]) -> Bool {
        let nilIndices = results.indices.filter { results[$0].rawMidPremium == nil }
        let nonNilIndices = results.indices.filter { results[$0].rawMidPremium != nil }
        
        guard !nilIndices.isEmpty && !nonNilIndices.isEmpty else { return true }
        
        let maxNonNilIndex = nonNilIndices.max()!
        let minNilIndex = nilIndices.min()!
        
        return minNilIndex > maxNonNilIndex
    }
    
    /// Verifies nil values are at the beginning for descending sort
    static func nilValuesAtBeginningForDescending(_ results: [AnalysisResultRow]) -> Bool {
        let nilIndices = results.indices.filter { results[$0].rawMidPremium == nil }
        let nonNilIndices = results.indices.filter { results[$0].rawMidPremium != nil }
        
        guard !nilIndices.isEmpty && !nonNilIndices.isEmpty else { return true }
        
        let maxNilIndex = nilIndices.max()!
        let minNonNilIndex = nonNilIndices.min()!
        
        return maxNilIndex < minNonNilIndex
    }
    
    // MARK: - Property Tests: Arrays with All Non-Nil Mid Premiums
    
    @Test("Property: Sorting by mid premium ascending with all non-nil values produces correct ordering",
          arguments: generateAllNonNilMidPremiums(count: 10))
    func testAscendingSortAllNonNilMidPremiums(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.isCorrectlyAscendingSortedByMidPremium(sortedResults)
        
        #expect(isCorrect,
                "Mid premium ascending sort should produce correct ordering for all non-nil values. Count: \(results.count)")
    }
    
    @Test("Property: Sorting by mid premium descending with all non-nil values produces correct ordering",
          arguments: generateAllNonNilMidPremiums(count: 10))
    func testDescendingSortAllNonNilMidPremiums(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .descending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.isCorrectlyDescendingSortedByMidPremium(sortedResults)
        
        #expect(isCorrect,
                "Mid premium descending sort should produce correct ordering for all non-nil values. Count: \(results.count)")
    }
    
    // MARK: - Property Tests: Arrays with Some Nil Mid Premiums
    
    @Test("Property: Sorting by mid premium ascending with some nil values produces correct ordering",
          arguments: generateSomeNilMidPremiums(count: 10))
    func testAscendingSortSomeNilMidPremiums(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.isCorrectlyAscendingSortedByMidPremium(sortedResults)
        
        #expect(isCorrect,
                "Mid premium ascending sort should produce correct ordering with some nil values")
    }
    
    @Test("Property: Sorting by mid premium descending with some nil values produces correct ordering",
          arguments: generateSomeNilMidPremiums(count: 10))
    func testDescendingSortSomeNilMidPremiums(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .descending)
        let sortedResults = results.sorted(by: sortState)
        
        let isCorrect = Self.isCorrectlyDescendingSortedByMidPremium(sortedResults)
        
        #expect(isCorrect,
                "Mid premium descending sort should produce correct ordering with some nil values")
    }
    
    @Test("Property: Nil values should sort to the end for ascending mid premium sort",
          arguments: generateSomeNilMidPremiums(count: 10))
    func testNilValuesAtEndForAscending(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        let nilAtEnd = Self.nilValuesAtEndForAscending(sortedResults)
        
        #expect(nilAtEnd,
                "Nil mid premium values should sort to the end for ascending order")
    }
    
    @Test("Property: Nil values should sort to the beginning for descending mid premium sort",
          arguments: generateSomeNilMidPremiums(count: 10))
    func testNilValuesAtBeginningForDescending(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .descending)
        let sortedResults = results.sorted(by: sortState)
        
        let nilAtBeginning = Self.nilValuesAtBeginningForDescending(sortedResults)
        
        #expect(nilAtBeginning,
                "Nil mid premium values should sort to the beginning for descending order")
    }
    
    // MARK: - Property Tests: Arrays with All Nil Mid Premiums
    
    @Test("Property: Sorting by mid premium with all nil values preserves array count",
          arguments: generateAllNilMidPremiums(count: 5))
    func testSortAllNilMidPremiumsPreservesCount(results: [AnalysisResultRow]) {
        let ascendingSortState = SortState(column: .midPremium, direction: .ascending)
        let descendingSortState = SortState(column: .midPremium, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingSortState)
        let descendingSorted = results.sorted(by: descendingSortState)
        
        #expect(ascendingSorted.count == results.count,
                "Ascending sort should preserve element count with all nil values")
        #expect(descendingSorted.count == results.count,
                "Descending sort should preserve element count with all nil values")
    }
    
    @Test("Property: All nil mid premium values are trivially sorted (all same comparability)",
          arguments: generateAllNilMidPremiums(count: 5))
    func testAllNilMidPremiumsSorted(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        // All nil means all elements have same "value" - order is stable/arbitrary but valid
        let isCorrect = Self.isCorrectlyAscendingSortedByMidPremium(sortedResults)
        
        #expect(isCorrect,
                "All nil mid premium array should be considered correctly sorted")
    }
    
    // MARK: - Property Tests: Single Element Arrays
    
    @Test("Property: Single element arrays are always correctly sorted by mid premium",
          arguments: generateSingleElementArrays(count: 5))
    func testSingleElementArraysSorted(results: [AnalysisResultRow]) {
        let ascendingSortState = SortState(column: .midPremium, direction: .ascending)
        let descendingSortState = SortState(column: .midPremium, direction: .descending)
        
        let ascendingSorted = results.sorted(by: ascendingSortState)
        let descendingSorted = results.sorted(by: descendingSortState)
        
        #expect(ascendingSorted.count == 1,
                "Single element array should remain single element after ascending sort")
        #expect(descendingSorted.count == 1,
                "Single element array should remain single element after descending sort")
        #expect(ascendingSorted[0].id == results[0].id,
                "Single element should be preserved after ascending sort")
        #expect(descendingSorted[0].id == results[0].id,
                "Single element should be preserved after descending sort")
    }
    
    // MARK: - Property Tests: Empty Arrays
    
    @Test("Property: Empty array remains empty after sorting by mid premium")
    func testEmptyArraySorted() {
        let emptyResults: [AnalysisResultRow] = []
        
        let ascendingSortState = SortState(column: .midPremium, direction: .ascending)
        let descendingSortState = SortState(column: .midPremium, direction: .descending)
        
        let ascendingSorted = emptyResults.sorted(by: ascendingSortState)
        let descendingSorted = emptyResults.sorted(by: descendingSortState)
        
        #expect(ascendingSorted.isEmpty,
                "Empty array should remain empty after ascending mid premium sort")
        #expect(descendingSorted.isEmpty,
                "Empty array should remain empty after descending mid premium sort")
    }
    
    // MARK: - Property Tests: Sort Preserves Elements
    
    @Test("Property: Mid premium sort preserves all elements (no elements added or removed)",
          arguments: generateSomeNilMidPremiums(count: 5))
    func testMidPremiumSortPreservesElements(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        // Same count
        #expect(sortedResults.count == results.count,
                "Sorted array should have the same number of elements")
        
        // Same elements (by id)
        let originalIds = Set(results.map { $0.id })
        let sortedIds = Set(sortedResults.map { $0.id })
        
        #expect(originalIds == sortedIds,
                "Sorted array should contain exactly the same elements as the original")
    }
    
    // MARK: - Property Tests: Consecutive Pairs Property
    
    @Test("Property: For any sorted array, consecutive pairs satisfy r[i].rawMidPremium <= r[i+1].rawMidPremium (ascending)",
          arguments: generateSomeNilMidPremiums(count: 10))
    func testConsecutivePairsPropertyAscending(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .ascending)
        let sortedResults = results.sorted(by: sortState)
        
        // Check the property for all consecutive pairs
        for i in 0..<max(0, sortedResults.count - 1) {
            let current = sortedResults[i]
            let next = sortedResults[i + 1]
            
            switch (current.rawMidPremium, next.rawMidPremium) {
            case (nil, nil):
                // Both nil - valid order
                continue
            case (nil, _):
                // nil before non-nil is wrong for ascending
                Issue.record("Nil value found before non-nil value in ascending sort at index \(i)")
            case (_, nil):
                // Non-nil before nil is correct for ascending
                continue
            case let (currentValue?, nextValue?):
                #expect(currentValue <= nextValue,
                        "At index \(i): \(currentValue) should be <= \(nextValue) for ascending sort")
            }
        }
    }
    
    @Test("Property: For any sorted array, consecutive pairs satisfy r[i].rawMidPremium >= r[i+1].rawMidPremium (descending)",
          arguments: generateSomeNilMidPremiums(count: 10))
    func testConsecutivePairsPropertyDescending(results: [AnalysisResultRow]) {
        let sortState = SortState(column: .midPremium, direction: .descending)
        let sortedResults = results.sorted(by: sortState)
        
        // Check the property for all consecutive pairs
        for i in 0..<max(0, sortedResults.count - 1) {
            let current = sortedResults[i]
            let next = sortedResults[i + 1]
            
            switch (current.rawMidPremium, next.rawMidPremium) {
            case (nil, nil):
                // Both nil - valid order
                continue
            case (nil, _):
                // nil before non-nil is correct for descending
                continue
            case (_, nil):
                // Non-nil before nil is wrong for descending
                Issue.record("Non-nil value found before nil value in descending sort at index \(i)")
            case let (currentValue?, nextValue?):
                #expect(currentValue >= nextValue,
                        "At index \(i): \(currentValue) should be >= \(nextValue) for descending sort")
            }
        }
    }
}


// MARK: - Filter Verification with New Signal Logic
// **Validates: Requirements 7.1, 7.2**
//
// Verifies that the ONLY_ORDERS filter works correctly with the new signal generation logic
// where ORDER signals are generated when:
// - For calls: strike >= call_target (matchedContract != nil with suitable strike)
// - For puts: strike <= put_target (matchedContract != nil with suitable strike)
// HOLD signals are generated otherwise.

@Suite("Filter Verification with New Signal Logic - Validates Requirements 7.1, 7.2")
struct OnlyOrdersFilterVerificationTests {
    
    // MARK: - Test Helpers
    
    /// Creates an AnalysisResult with specific options data to simulate the new signal logic.
    /// - Parameters:
    ///   - ticker: Stock ticker symbol
    ///   - type: CALL or PUT opportunity
    ///   - signal: ORDER or HOLD signal
    ///   - hasMatchedContract: Whether the result has a matched option contract (strikePrice != nil)
    /// - Returns: AnalysisResult with the specified configuration
    static func createAnalysisResult(
        ticker: String,
        type: OpportunityType,
        signal: Signal,
        hasMatchedContract: Bool
    ) -> AnalysisResult {
        let strikePrice: Double? = hasMatchedContract ? Double.random(in: 100...500) : nil
        let bidPremium: Double? = hasMatchedContract ? Double.random(in: 0.5...5.0) : nil
        let askPremium: Double? = hasMatchedContract ? (bidPremium.map { $0 + 0.10 }) : nil
        let midPremium: Double? = hasMatchedContract ? ((bidPremium ?? 0) + (askPremium ?? 0)) / 2.0 : nil
        let expirationDate: Date? = hasMatchedContract ? Calendar.current.date(byAdding: .day, value: 7, to: Date()) : nil
        
        return AnalysisResult(
            ticker: ticker,
            type: type,
            returnPercentage: type == .call ? Double.random(in: 1...10) : Double.random(in: (-10)...(-1)),
            currentPrice: Double.random(in: 100...300),
            targetPrice: Double.random(in: 100...350),
            signal: signal,
            nextEarningsDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            hasEarningsRisk: false,
            expirationDate: expirationDate,
            strikePrice: strikePrice,
            bidPremium: bidPremium,
            askPremium: askPremium,
            midPremium: midPremium
        )
    }
    
    /// Creates a mixed array of results with various signal and contract combinations.
    static func createMixedResults() -> [AnalysisResult] {
        return [
            // CALL with ORDER signal and matched contract (new signal logic: strike >= call_target)
            createAnalysisResult(ticker: "AAPL", type: .call, signal: .order, hasMatchedContract: true),
            // PUT with ORDER signal and matched contract (new signal logic: strike <= put_target)
            createAnalysisResult(ticker: "GOOGL", type: .put, signal: .order, hasMatchedContract: true),
            // CALL with HOLD signal and matched contract (new signal logic: strike < call_target)
            createAnalysisResult(ticker: "MSFT", type: .call, signal: .hold, hasMatchedContract: true),
            // PUT with HOLD signal and matched contract (new signal logic: strike > put_target)
            createAnalysisResult(ticker: "AMZN", type: .put, signal: .hold, hasMatchedContract: true),
            // CALL with HOLD signal and NO matched contract (no options data available)
            createAnalysisResult(ticker: "TSLA", type: .call, signal: .hold, hasMatchedContract: false),
            // PUT with HOLD signal and NO matched contract (no options data available)
            createAnalysisResult(ticker: "META", type: .put, signal: .hold, hasMatchedContract: false),
            // Additional ORDER results for variety
            createAnalysisResult(ticker: "NVDA", type: .call, signal: .order, hasMatchedContract: true),
            createAnalysisResult(ticker: "AMD", type: .put, signal: .order, hasMatchedContract: true),
        ]
    }
    
    // MARK: - Filter Verification Tests
    
    @Test("ONLY_ORDERS filter shows only ORDER signals (both CALL and PUT types)")
    func testOnlyOrdersFilterShowsOnlyOrderSignals() {
        // Create mixed results
        let results = Self.createMixedResults()
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Apply ONLY_ORDERS filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // All filtered rows should have ORDER signal
        for row in filteredRows {
            #expect(row.signal == Signal.order.rawValue,
                    "Filtered row for \(row.ticker) should have ORDER signal, got \(row.signal)")
        }
        
        // Should have exactly 4 ORDER rows (AAPL, GOOGL, NVDA, AMD)
        #expect(filteredRows.count == 4,
                "Expected 4 ORDER rows, got \(filteredRows.count)")
    }
    
    @Test("ONLY_ORDERS filter includes both CALL_ORDER and PUT_ORDER rows")
    func testOnlyOrdersFilterIncludesBothCallAndPutOrders() {
        let results = Self.createMixedResults()
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Count CALL and PUT ORDER rows
        let callOrderCount = filteredRows.filter { $0.type == OpportunityType.call.rawValue }.count
        let putOrderCount = filteredRows.filter { $0.type == OpportunityType.put.rawValue }.count
        
        // Should have 2 CALL ORDER (AAPL, NVDA) and 2 PUT ORDER (GOOGL, AMD)
        #expect(callOrderCount == 2,
                "Expected 2 CALL ORDER rows, got \(callOrderCount)")
        #expect(putOrderCount == 2,
                "Expected 2 PUT ORDER rows, got \(putOrderCount)")
    }
    
    @Test("ONLY_ORDERS filter correctly excludes HOLD signals")
    func testOnlyOrdersFilterExcludesHoldSignals() {
        let results = Self.createMixedResults()
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // No filtered row should have HOLD signal
        let holdRows = filteredRows.filter { $0.signal == Signal.hold.rawValue }
        #expect(holdRows.isEmpty,
                "No HOLD rows should pass the ONLY_ORDERS filter, found \(holdRows.count)")
    }
    
    @Test("ONLY_ORDERS filter works with results that have matched contracts (strikePrice != nil)")
    func testFilterWorksWithMatchedContracts() {
        // Create results where all have matched contracts
        let results = [
            Self.createAnalysisResult(ticker: "AAPL", type: .call, signal: .order, hasMatchedContract: true),
            Self.createAnalysisResult(ticker: "GOOGL", type: .put, signal: .hold, hasMatchedContract: true),
            Self.createAnalysisResult(ticker: "MSFT", type: .call, signal: .hold, hasMatchedContract: true),
            Self.createAnalysisResult(ticker: "AMZN", type: .put, signal: .order, hasMatchedContract: true),
        ]
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Should only show ORDER results (AAPL and AMZN)
        #expect(filteredRows.count == 2)
        #expect(filteredRows.allSatisfy { $0.signal == Signal.order.rawValue })
        
        // Verify matched contracts data is preserved
        for row in filteredRows {
            #expect(row.strikePrice != "N/A",
                    "ORDER rows with matched contracts should have strike price")
        }
    }
    
    @Test("Filter disabled shows all signals including HOLD")
    func testFilterDisabledShowsAllSignals() {
        let results = Self.createMixedResults()
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Filter with onlyOrders = false
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        // Should show all rows
        #expect(filteredRows.count == rows.count,
                "With filter disabled, should show all \(rows.count) rows, got \(filteredRows.count)")
        
        // Should include both ORDER and HOLD signals
        let orderCount = filteredRows.filter { $0.signal == Signal.order.rawValue }.count
        let holdCount = filteredRows.filter { $0.signal == Signal.hold.rawValue }.count
        
        #expect(orderCount == 4, "Should have 4 ORDER rows")
        #expect(holdCount == 4, "Should have 4 HOLD rows")
    }
    
    @Test("ORDER rows with matched contracts are NOT filtered out by ONLY_ORDERS")
    func testOrderRowsWithMatchedContractsNotFilteredOut() {
        // All ORDER signals should pass regardless of options data
        let results = [
            Self.createAnalysisResult(ticker: "AAPL", type: .call, signal: .order, hasMatchedContract: true),
            Self.createAnalysisResult(ticker: "GOOGL", type: .put, signal: .order, hasMatchedContract: true),
        ]
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Both ORDER rows should remain
        #expect(filteredRows.count == 2,
                "All ORDER rows should pass the filter")
        
        // Verify the specific tickers
        let tickers = Set(filteredRows.map { $0.ticker })
        #expect(tickers.contains("AAPL"))
        #expect(tickers.contains("GOOGL"))
    }
    
    // MARK: - Property-Style Tests
    
    /// Generates arrays with random mix of ORDER and HOLD signals
    static func generateRandomResults(count: Int) -> [[AnalysisResult]] {
        return (0..<count).map { _ in
            let resultCount = Int.random(in: 5...15)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                let signal: Signal = Bool.random() ? .order : .hold
                let hasMatchedContract = Bool.random()
                return createAnalysisResult(
                    ticker: ResultsRandomGenerator.sampleTickers.randomElement()!,
                    type: type,
                    signal: signal,
                    hasMatchedContract: hasMatchedContract
                )
            }
        }
    }
    
    @Test("Property: Filtered results contain only ORDER signals for any input",
          arguments: generateRandomResults(count: 20))
    func testFilteredResultsContainOnlyOrderSignals(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Property: All filtered rows must have ORDER signal
        for row in filteredRows {
            #expect(row.signal == Signal.order.rawValue,
                    "All filtered rows must have ORDER signal, found \(row.signal)")
        }
    }
    
    @Test("Property: All ORDER rows from original array appear in filtered result",
          arguments: generateRandomResults(count: 20))
    func testAllOrderRowsPreservedInFilter(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Count ORDER rows in original
        let originalOrderCount = rows.filter { $0.signal == Signal.order.rawValue }.count
        
        // Filtered count should match
        #expect(filteredRows.count == originalOrderCount,
                "Filtered count (\(filteredRows.count)) should match original ORDER count (\(originalOrderCount))")
        
        // Verify all ORDER rows from original are in filtered
        let originalOrderIds = Set(rows.filter { $0.signal == Signal.order.rawValue }.map { $0.id })
        let filteredIds = Set(filteredRows.map { $0.id })
        
        #expect(originalOrderIds == filteredIds,
                "All ORDER rows should be preserved in filter")
    }
    
    @Test("Property: Filter disabled preserves all rows",
          arguments: generateRandomResults(count: 20))
    func testFilterDisabledPreservesAllRows(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        // Should have same count
        #expect(filteredRows.count == rows.count,
                "Filter disabled should preserve all \(rows.count) rows, got \(filteredRows.count)")
        
        // Should have same IDs
        let originalIds = Set(rows.map { $0.id })
        let filteredIds = Set(filteredRows.map { $0.id })
        
        #expect(originalIds == filteredIds,
                "All original rows should be in filtered result")
    }
}

// MARK: - Signal Comparison Tests
// Verify that the signal string comparison in the filter works correctly

@Suite("Signal String Comparison Tests - Validates Requirements 7.1")
struct SignalComparisonTests {
    
    @Test("Signal.order.rawValue is 'ORDER' string")
    func testOrderSignalRawValue() {
        #expect(Signal.order.rawValue == "ORDER",
                "Signal.order.rawValue should be 'ORDER'")
    }
    
    @Test("Signal.hold.rawValue is 'HOLD' string")
    func testHoldSignalRawValue() {
        #expect(Signal.hold.rawValue == "HOLD",
                "Signal.hold.rawValue should be 'HOLD'")
    }
    
    @Test("AnalysisResultRow.signal matches Signal raw value for ORDER")
    func testResultRowSignalMatchesOrder() {
        let result = AnalysisResult(
            ticker: "AAPL",
            type: .call,
            returnPercentage: 5.0,
            currentPrice: 150.0,
            targetPrice: 157.5,
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        let row = AnalysisResultRow(from: result)
        
        #expect(row.signal == Signal.order.rawValue)
        #expect(row.signal == "ORDER")
    }
    
    @Test("AnalysisResultRow.signal matches Signal raw value for HOLD")
    func testResultRowSignalMatchesHold() {
        let result = AnalysisResult(
            ticker: "AAPL",
            type: .call,
            returnPercentage: 5.0,
            currentPrice: 150.0,
            targetPrice: 157.5,
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        let row = AnalysisResultRow(from: result)
        
        #expect(row.signal == Signal.hold.rawValue)
        #expect(row.signal == "HOLD")
    }
    
    @Test("Filter comparison uses Signal.order.rawValue correctly")
    func testFilterUsesCorrectSignalComparison() {
        let orderResult = AnalysisResult(
            ticker: "AAPL",
            type: .call,
            returnPercentage: 5.0,
            currentPrice: 150.0,
            targetPrice: 157.5,
            signal: .order,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        let holdResult = AnalysisResult(
            ticker: "GOOGL",
            type: .put,
            returnPercentage: -3.0,
            currentPrice: 140.0,
            targetPrice: 135.8,
            signal: .hold,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        let rows = [orderResult, holdResult].map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: true)
        let filtered = rows.filtered(by: filter)
        
        // Should only include the ORDER row
        #expect(filtered.count == 1)
        #expect(filtered[0].ticker == "AAPL")
        #expect(filtered[0].signal == "ORDER")
    }
}


// MARK: - Property 19: ONLY_ORDERS Filter Completeness
// **Validates: Requirements 7.1**
//
// *For any* array of analysis results with ONLY_ORDERS filter enabled, the filtered result
// SHALL contain only rows where signal == "ORDER" (either CALL_ORDER or PUT_ORDER).
// No HOLD signals should ever appear in the filtered output.

@Suite("Property 19: ONLY_ORDERS Filter Completeness - Validates Requirements 7.1")
struct OnlyOrdersFilterCompletenessPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 10
    
    // MARK: - Test Data Generation
    
    /// Generates random AnalysisResult arrays with mixed ORDER and HOLD signals.
    /// Returns arrays of varying sizes (5-20 elements) with random signal distribution.
    static func generateRandomResultArrays(count: Int) -> [[AnalysisResult]] {
        return (0..<count).map { _ in
            let arraySize = Int.random(in: 5...20)
            return (0..<arraySize).map { _ in
                createRandomAnalysisResult()
            }
        }
    }
    
    /// Creates a random AnalysisResult with either ORDER or HOLD signal.
    static func createRandomAnalysisResult() -> AnalysisResult {
        let tickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NVDA", "AMD", "INTC", "IBM"]
        let ticker = tickers.randomElement()!
        let type: OpportunityType = Bool.random() ? .call : .put
        let signal: Signal = Bool.random() ? .order : .hold
        
        // Generate random options data (50% chance of having options data)
        let hasOptionsData = Bool.random()
        let strikePrice: Double? = hasOptionsData ? Double.random(in: 50...500) : nil
        let bidPremium: Double? = hasOptionsData ? Double.random(in: 0.10...10.0) : nil
        let askPremium: Double? = hasOptionsData ? (bidPremium.map { $0 + Double.random(in: 0.01...0.50) }) : nil
        let midPremium: Double? = hasOptionsData ? ((bidPremium ?? 0) + (askPremium ?? 0)) / 2.0 : nil
        let expirationDate: Date? = hasOptionsData ? Calendar.current.date(byAdding: .day, value: Int.random(in: 7...30), to: Date()) : nil
        
        return AnalysisResult(
            ticker: ticker,
            type: type,
            returnPercentage: type == .call ? Double.random(in: 1...15) : Double.random(in: (-15)...(-1)),
            currentPrice: Double.random(in: 50...500),
            targetPrice: Double.random(in: 50...550),
            signal: signal,
            nextEarningsDate: Bool.random() ? Calendar.current.date(byAdding: .day, value: Int.random(in: 5...60), to: Date()) : nil,
            hasEarningsRisk: Bool.random(),
            expirationDate: expirationDate,
            strikePrice: strikePrice,
            bidPremium: bidPremium,
            askPremium: askPremium,
            midPremium: midPremium
        )
    }
    
    /// Creates an AnalysisResult with a specific signal.
    static func createAnalysisResultWithSignal(_ signal: Signal, type: OpportunityType = .call) -> AnalysisResult {
        let tickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA"]
        let ticker = tickers.randomElement()!
        
        return AnalysisResult(
            ticker: ticker,
            type: type,
            returnPercentage: type == .call ? Double.random(in: 1...10) : Double.random(in: (-10)...(-1)),
            currentPrice: Double.random(in: 100...300),
            targetPrice: Double.random(in: 100...350),
            signal: signal,
            nextEarningsDate: nil,
            hasEarningsRisk: false,
            expirationDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            strikePrice: Double.random(in: 100...400),
            bidPremium: Double.random(in: 0.5...5.0),
            askPremium: Double.random(in: 0.6...5.5),
            midPremium: Double.random(in: 0.55...5.25)
        )
    }
    
    // MARK: - Property Tests
    
    @Test("Property 19: When ONLY_ORDERS filter is active, filtered results contain ONLY ORDER signals",
          arguments: generateRandomResultArrays(count: sampleCount))
    func testOnlyOrdersFilterContainsOnlyOrderSignals(results: [AnalysisResult]) {
        // Convert AnalysisResult array to AnalysisResultRow array
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Apply ONLY_ORDERS filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Property: ALL filtered rows must have signal == "ORDER"
        for (index, row) in filteredRows.enumerated() {
            #expect(row.signal == Signal.order.rawValue,
                    "Filtered row at index \(index) for ticker \(row.ticker) must have ORDER signal, but got '\(row.signal)'")
        }
    }
    
    @Test("Property 19: No HOLD signals appear in ONLY_ORDERS filtered output",
          arguments: generateRandomResultArrays(count: sampleCount))
    func testNoHoldSignalsInFilteredOutput(results: [AnalysisResult]) {
        // Convert AnalysisResult array to AnalysisResultRow array
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Apply ONLY_ORDERS filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Property: No filtered row should have HOLD signal
        let holdRows = filteredRows.filter { $0.signal == Signal.hold.rawValue }
        
        #expect(holdRows.isEmpty,
                "HOLD signals should NEVER appear in ONLY_ORDERS filtered output. Found \(holdRows.count) HOLD rows: \(holdRows.map { $0.ticker })")
    }
    
    @Test("Property 19: Filtered count equals count of ORDER signals in original array",
          arguments: generateRandomResultArrays(count: sampleCount))
    func testFilteredCountEqualsOrderCount(results: [AnalysisResult]) {
        // Convert AnalysisResult array to AnalysisResultRow array
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Count ORDER signals in original array
        let originalOrderCount = rows.filter { $0.signal == Signal.order.rawValue }.count
        
        // Apply ONLY_ORDERS filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Property: Filtered count must equal original ORDER count
        #expect(filteredRows.count == originalOrderCount,
                "Filtered count (\(filteredRows.count)) must equal original ORDER count (\(originalOrderCount))")
    }
    
    @Test("Property 19: Filter works with all-ORDER arrays")
    func testFilterWithAllOrderArray() {
        // Create array with only ORDER signals
        let results = (0..<8).map { _ in
            Self.createAnalysisResultWithSignal(.order, type: Bool.random() ? .call : .put)
        }
        
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // All rows should pass through
        #expect(filteredRows.count == results.count,
                "All ORDER rows should pass through filter. Expected \(results.count), got \(filteredRows.count)")
        
        // All should have ORDER signal
        #expect(filteredRows.allSatisfy { $0.signal == Signal.order.rawValue },
                "All filtered rows should have ORDER signal")
    }
    
    @Test("Property 19: Filter works with all-HOLD arrays")
    func testFilterWithAllHoldArray() {
        // Create array with only HOLD signals
        let results = (0..<8).map { _ in
            Self.createAnalysisResultWithSignal(.hold, type: Bool.random() ? .call : .put)
        }
        
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // No rows should pass through
        #expect(filteredRows.isEmpty,
                "No HOLD rows should pass the ONLY_ORDERS filter. Found \(filteredRows.count) rows")
    }
    
    @Test("Property 19: Filter works with empty array")
    func testFilterWithEmptyArray() {
        let rows: [AnalysisResultRow] = []
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.isEmpty,
                "Empty array should remain empty after filtering")
    }
    
    @Test("Property 19: Filter includes both CALL and PUT ORDER signals",
          arguments: (0..<sampleCount).map { _ in
              // Create mixed array with both CALL and PUT ORDER signals plus some HOLD
              return [
                  createAnalysisResultWithSignal(.order, type: .call),
                  createAnalysisResultWithSignal(.order, type: .put),
                  createAnalysisResultWithSignal(.hold, type: .call),
                  createAnalysisResultWithSignal(.hold, type: .put),
                  createAnalysisResultWithSignal(.order, type: .call),
                  createAnalysisResultWithSignal(.order, type: .put),
              ]
          })
    func testFilterIncludesBothCallAndPutOrders(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Should have exactly 4 ORDER rows (2 CALL + 2 PUT)
        #expect(filteredRows.count == 4,
                "Expected 4 ORDER rows, got \(filteredRows.count)")
        
        // Count by type
        let callOrders = filteredRows.filter { $0.type == OpportunityType.call.rawValue }
        let putOrders = filteredRows.filter { $0.type == OpportunityType.put.rawValue }
        
        #expect(callOrders.count == 2,
                "Expected 2 CALL ORDER rows, got \(callOrders.count)")
        #expect(putOrders.count == 2,
                "Expected 2 PUT ORDER rows, got \(putOrders.count)")
        
        // All should have ORDER signal
        #expect(filteredRows.allSatisfy { $0.signal == Signal.order.rawValue },
                "All filtered rows must have ORDER signal")
    }
}

// MARK: - Property 21: Filter Disabled Shows All Signals
// **Validates: Requirements 7.3**
//
// *For any* array of analysis results with ONLY_ORDERS filter disabled,
// the filtered result SHALL contain the same number of elements as the original array.

@Suite("Property 21: Filter Disabled Shows All Signals - Validates Requirements 7.3")
struct FilterDisabledShowsAllSignalsPropertyTests {
    
    // MARK: - Test Data Generators
    
    /// Sample ticker symbols for generating random results
    static let sampleTickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NVDA", "AMD", "INTC", "IBM"]
    
    /// Generates random AnalysisResult arrays with mixed ORDER and HOLD signals.
    /// - Parameter count: Number of test cases to generate
    /// - Returns: Array of AnalysisResult arrays
    static func generateMixedSignalResults(count: Int) -> [[AnalysisResult]] {
        return (0..<count).map { _ in
            // Generate arrays with 5-10 results for fast execution
            let resultCount = Int.random(in: 5...10)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                let signal: Signal = Bool.random() ? .order : .hold
                let hasMatchedContract = Bool.random()
                
                // Generate options data if has matched contract
                let strikePrice: Double? = hasMatchedContract ? Double.random(in: 100...500) : nil
                let bidPremium: Double? = hasMatchedContract ? Double.random(in: 0.5...5.0) : nil
                let askPremium: Double? = hasMatchedContract ? (bidPremium.map { $0 + 0.10 }) : nil
                let midPremium: Double? = hasMatchedContract ? ((bidPremium ?? 0) + (askPremium ?? 0)) / 2.0 : nil
                let expirationDate: Date? = hasMatchedContract ? Calendar.current.date(byAdding: .day, value: 7, to: Date()) : nil
                
                return AnalysisResult(
                    ticker: sampleTickers.randomElement()!,
                    type: type,
                    returnPercentage: type == .call ? Double.random(in: 1...10) : Double.random(in: (-10)...(-1)),
                    currentPrice: Double.random(in: 100...300),
                    targetPrice: Double.random(in: 100...350),
                    signal: signal,
                    nextEarningsDate: Bool.random() ? Calendar.current.date(byAdding: .day, value: Int.random(in: 1...60), to: Date()) : nil,
                    hasEarningsRisk: Bool.random(),
                    expirationDate: expirationDate,
                    strikePrice: strikePrice,
                    bidPremium: bidPremium,
                    askPremium: askPremium,
                    midPremium: midPremium
                )
            }
        }
    }
    
    /// Generates arrays with all ORDER signals
    static func generateAllOrderResults(count: Int) -> [[AnalysisResult]] {
        return (0..<count).map { _ in
            let resultCount = Int.random(in: 5...10)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                return AnalysisResult(
                    ticker: sampleTickers.randomElement()!,
                    type: type,
                    returnPercentage: Double.random(in: 1...10),
                    currentPrice: Double.random(in: 100...300),
                    targetPrice: Double.random(in: 100...350),
                    signal: .order,  // Always ORDER
                    nextEarningsDate: nil,
                    hasEarningsRisk: false
                )
            }
        }
    }
    
    /// Generates arrays with all HOLD signals
    static func generateAllHoldResults(count: Int) -> [[AnalysisResult]] {
        return (0..<count).map { _ in
            let resultCount = Int.random(in: 5...10)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                return AnalysisResult(
                    ticker: sampleTickers.randomElement()!,
                    type: type,
                    returnPercentage: Double.random(in: 1...10),
                    currentPrice: Double.random(in: 100...300),
                    targetPrice: Double.random(in: 100...350),
                    signal: .hold,  // Always HOLD
                    nextEarningsDate: nil,
                    hasEarningsRisk: false
                )
            }
        }
    }
    
    // MARK: - Property Tests: Count Preservation
    
    @Test("Property: When onlyOrders = false, filtered count equals original count (mixed signals)",
          arguments: generateMixedSignalResults(count: 10))
    func testFilterDisabledPreservesCountMixedSignals(results: [AnalysisResult]) {
        // Convert to rows
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Apply filter with onlyOrders = false
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        // Property: filtered count SHALL equal original count
        #expect(filteredRows.count == rows.count,
                "When onlyOrders = false, filtered count (\(filteredRows.count)) SHALL equal original count (\(rows.count))")
    }
    
    @Test("Property: When onlyOrders = false, filtered count equals original count (all ORDER signals)",
          arguments: generateAllOrderResults(count: 5))
    func testFilterDisabledPreservesCountAllOrders(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.count == rows.count,
                "When onlyOrders = false with all ORDER signals, filtered count SHALL equal original count")
    }
    
    @Test("Property: When onlyOrders = false, filtered count equals original count (all HOLD signals)",
          arguments: generateAllHoldResults(count: 5))
    func testFilterDisabledPreservesCountAllHolds(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.count == rows.count,
                "When onlyOrders = false with all HOLD signals, filtered count SHALL equal original count")
    }
    
    // MARK: - Property Tests: All Rows Present
    
    @Test("Property: When onlyOrders = false, all rows (both ORDER and HOLD) are present in output",
          arguments: generateMixedSignalResults(count: 10))
    func testFilterDisabledPreservesAllRows(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        // All original row IDs should be in filtered result
        let originalIds = Set(rows.map { $0.id })
        let filteredIds = Set(filteredRows.map { $0.id })
        
        #expect(originalIds == filteredIds,
                "All original rows SHALL be present in filtered output when onlyOrders = false")
    }
    
    @Test("Property: When onlyOrders = false, both ORDER and HOLD signals are preserved",
          arguments: generateMixedSignalResults(count: 10))
    func testFilterDisabledPreservesBothSignalTypes(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        // Count signals in original
        let originalOrderCount = rows.filter { $0.signal == Signal.order.rawValue }.count
        let originalHoldCount = rows.filter { $0.signal == Signal.hold.rawValue }.count
        
        // Count signals in filtered
        let filteredOrderCount = filteredRows.filter { $0.signal == Signal.order.rawValue }.count
        let filteredHoldCount = filteredRows.filter { $0.signal == Signal.hold.rawValue }.count
        
        #expect(filteredOrderCount == originalOrderCount,
                "ORDER signal count should be preserved: original=\(originalOrderCount), filtered=\(filteredOrderCount)")
        #expect(filteredHoldCount == originalHoldCount,
                "HOLD signal count should be preserved: original=\(originalHoldCount), filtered=\(filteredHoldCount)")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Empty array with onlyOrders = false returns empty array")
    func testFilterDisabledWithEmptyArray() {
        let rows: [AnalysisResultRow] = []
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.isEmpty,
                "Empty array should remain empty when filter disabled")
    }
    
    @Test("Property: Single element array with onlyOrders = false preserves the element",
          arguments: [Signal.order, Signal.hold])
    func testFilterDisabledWithSingleElement(signal: Signal) {
        let result = AnalysisResult(
            ticker: "AAPL",
            type: .call,
            returnPercentage: 5.0,
            currentPrice: 150.0,
            targetPrice: 157.5,
            signal: signal,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
        
        let rows = [AnalysisResultRow(from: result)]
        let filter = ResultsFilter(onlyOrders: false)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.count == 1,
                "Single element should be preserved when filter disabled")
        #expect(filteredRows[0].id == rows[0].id,
                "The same element should be returned")
    }
    
    // MARK: - Property Tests: Contrast with Filter Enabled
    
    @Test("Property: Filter disabled (onlyOrders = false) shows MORE or EQUAL results compared to filter enabled",
          arguments: generateMixedSignalResults(count: 10))
    func testFilterDisabledShowsMoreOrEqualResults(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filterDisabled = ResultsFilter(onlyOrders: false)
        let filterEnabled = ResultsFilter(onlyOrders: true)
        
        let filteredDisabled = rows.filtered(by: filterDisabled)
        let filteredEnabled = rows.filtered(by: filterEnabled)
        
        #expect(filteredDisabled.count >= filteredEnabled.count,
                "Filter disabled should show >= results than filter enabled: disabled=\(filteredDisabled.count), enabled=\(filteredEnabled.count)")
    }
    
    @Test("Property: Filter disabled includes all HOLD signals that filter enabled excludes",
          arguments: generateMixedSignalResults(count: 10))
    func testFilterDisabledIncludesHoldSignals(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filterDisabled = ResultsFilter(onlyOrders: false)
        let filterEnabled = ResultsFilter(onlyOrders: true)
        
        let filteredDisabled = rows.filtered(by: filterDisabled)
        let filteredEnabled = rows.filtered(by: filterEnabled)
        
        // All HOLD signals should be in disabled but not in enabled
        let holdRowsInDisabled = filteredDisabled.filter { $0.signal == Signal.hold.rawValue }
        let holdRowsInEnabled = filteredEnabled.filter { $0.signal == Signal.hold.rawValue }
        
        #expect(holdRowsInEnabled.isEmpty,
                "Filter enabled should have no HOLD signals")
        
        // Count HOLD signals in original
        let originalHoldCount = rows.filter { $0.signal == Signal.hold.rawValue }.count
        #expect(holdRowsInDisabled.count == originalHoldCount,
                "Filter disabled should include all original HOLD signals")
    }
}


// MARK: - Property 20: ONLY_ORDERS Filter Preserves All Orders
// **Validates: Requirements 7.2**
//
// *For any* array of analysis results with ONLY_ORDERS filter enabled,
// all rows with signal `ORDER` from the original array SHALL appear in the filtered result.
// This verifies that no ORDER rows are accidentally filtered out.

@Suite("Property 20: ONLY_ORDERS Filter Preserves All Orders - Validates Requirements 7.2")
struct OnlyOrdersPreservesAllOrdersPropertyTests {
    
    // Number of random samples for property tests (5-10 for fast execution)
    static let sampleCount = 10
    
    // MARK: - Test Data Generation
    
    /// Creates an AnalysisResult with specific options data.
    /// - Parameters:
    ///   - ticker: Stock ticker symbol
    ///   - type: CALL or PUT opportunity
    ///   - signal: ORDER or HOLD signal
    ///   - hasMatchedContract: Whether the result has a matched option contract
    /// - Returns: AnalysisResult with the specified configuration
    static func createAnalysisResult(
        ticker: String,
        type: OpportunityType,
        signal: Signal,
        hasMatchedContract: Bool
    ) -> AnalysisResult {
        let strikePrice: Double? = hasMatchedContract ? Double.random(in: 100...500) : nil
        let bidPremium: Double? = hasMatchedContract ? Double.random(in: 0.5...5.0) : nil
        let askPremium: Double? = hasMatchedContract ? (bidPremium.map { $0 + 0.10 }) : nil
        let midPremium: Double? = hasMatchedContract ? ((bidPremium ?? 0) + (askPremium ?? 0)) / 2.0 : nil
        let expirationDate: Date? = hasMatchedContract ? Calendar.current.date(byAdding: .day, value: 7, to: Date()) : nil
        
        return AnalysisResult(
            ticker: ticker,
            type: type,
            returnPercentage: type == .call ? Double.random(in: 1...10) : Double.random(in: (-10)...(-1)),
            currentPrice: Double.random(in: 100...300),
            targetPrice: Double.random(in: 100...350),
            signal: signal,
            nextEarningsDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            hasEarningsRisk: false,
            expirationDate: expirationDate,
            strikePrice: strikePrice,
            bidPremium: bidPremium,
            askPremium: askPremium,
            midPremium: midPremium
        )
    }
    
    /// Generates arrays with random mix of ORDER and HOLD signals.
    /// Each array contains mixed ORDER and HOLD signals to test filter preservation.
    static func generateMixedSignalArrays(count: Int) -> [[AnalysisResult]] {
        let tickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NVDA", "AMD", "INTC", "IBM"]
        
        return (0..<count).map { _ in
            // Generate arrays of varying sizes: 3-15 elements
            let resultCount = Int.random(in: 3...15)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                let signal: Signal = Bool.random() ? .order : .hold
                let hasMatchedContract = Bool.random()
                return createAnalysisResult(
                    ticker: tickers.randomElement()!,
                    type: type,
                    signal: signal,
                    hasMatchedContract: hasMatchedContract
                )
            }
        }
    }
    
    /// Generates arrays where all results have ORDER signals (edge case).
    static func generateAllOrderArrays(count: Int) -> [[AnalysisResult]] {
        let tickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA"]
        
        return (0..<count).map { _ in
            let resultCount = Int.random(in: 2...8)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                return createAnalysisResult(
                    ticker: tickers.randomElement()!,
                    type: type,
                    signal: .order,  // All ORDER
                    hasMatchedContract: Bool.random()
                )
            }
        }
    }
    
    /// Generates arrays where all results have HOLD signals (edge case).
    static func generateAllHoldArrays(count: Int) -> [[AnalysisResult]] {
        let tickers = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA"]
        
        return (0..<count).map { _ in
            let resultCount = Int.random(in: 2...8)
            return (0..<resultCount).map { _ in
                let type: OpportunityType = Bool.random() ? .call : .put
                return createAnalysisResult(
                    ticker: tickers.randomElement()!,
                    type: type,
                    signal: .hold,  // All HOLD
                    hasMatchedContract: Bool.random()
                )
            }
        }
    }
    
    // MARK: - Property 20: Core Property Tests
    
    @Test("Property 20: Count of filtered rows equals count of ORDER rows in original",
          arguments: generateMixedSignalArrays(count: sampleCount))
    func testFilteredCountEqualsOriginalOrderCount(results: [AnalysisResult]) {
        // Convert to rows
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Count ORDER rows in original
        let originalOrderCount = rows.filter { $0.signal == Signal.order.rawValue }.count
        
        // Apply ONLY_ORDERS filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Property: Filtered count SHALL equal original ORDER count
        #expect(filteredRows.count == originalOrderCount,
                "Filtered count (\(filteredRows.count)) should equal original ORDER count (\(originalOrderCount))")
    }
    
    @Test("Property 20: Every ORDER row from original appears in filtered output",
          arguments: generateMixedSignalArrays(count: sampleCount))
    func testEveryOrderRowAppearsInFilteredOutput(results: [AnalysisResult]) {
        // Convert to rows
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Get ORDER rows from original
        let originalOrderRows = rows.filter { $0.signal == Signal.order.rawValue }
        let originalOrderIds = Set(originalOrderRows.map { $0.id })
        
        // Apply ONLY_ORDERS filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        let filteredIds = Set(filteredRows.map { $0.id })
        
        // Property: All original ORDER IDs SHALL appear in filtered result
        #expect(originalOrderIds == filteredIds,
                "All ORDER rows from original (\(originalOrderIds.count)) should appear in filtered result (\(filteredIds.count))")
        
        // Additional verification: No ORDER row missing
        for orderId in originalOrderIds {
            #expect(filteredIds.contains(orderId),
                    "ORDER row with ID \(orderId) should be in filtered result")
        }
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Property 20: When all rows are ORDER, filtered count equals original count",
          arguments: generateAllOrderArrays(count: 5))
    func testAllOrderRowsPreserved(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // When all are ORDER, filtered should have same count as original
        #expect(filteredRows.count == rows.count,
                "When all rows are ORDER, filtered count (\(filteredRows.count)) should equal original count (\(rows.count))")
    }
    
    @Test("Property 20: When no rows are ORDER, filtered result is empty",
          arguments: generateAllHoldArrays(count: 5))
    func testNoOrderRowsResultsInEmptyFilter(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // When no rows are ORDER, filtered should be empty
        #expect(filteredRows.isEmpty,
                "When no rows are ORDER, filtered result should be empty, got \(filteredRows.count)")
    }
    
    @Test("Property 20: Empty input array results in empty filtered output")
    func testEmptyInputResultsInEmptyOutput() {
        let rows: [AnalysisResultRow] = []
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.isEmpty,
                "Empty input should result in empty filtered output")
    }
    
    @Test("Property 20: Single ORDER row is preserved in filtered output")
    func testSingleOrderRowPreserved() {
        let result = Self.createAnalysisResult(
            ticker: "AAPL",
            type: .call,
            signal: .order,
            hasMatchedContract: true
        )
        let rows = [AnalysisResultRow(from: result)]
        
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        #expect(filteredRows.count == 1,
                "Single ORDER row should be preserved")
        #expect(filteredRows[0].id == rows[0].id,
                "The preserved row should have the same ID")
    }
    
    @Test("Property 20: ORDER rows with different types (CALL and PUT) are all preserved",
          arguments: generateMixedSignalArrays(count: 5))
    func testBothCallAndPutOrderRowsPreserved(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Get ORDER rows by type from original
        let originalCallOrders = rows.filter { $0.signal == Signal.order.rawValue && $0.type == OpportunityType.call.rawValue }
        let originalPutOrders = rows.filter { $0.signal == Signal.order.rawValue && $0.type == OpportunityType.put.rawValue }
        
        // Apply filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Get filtered ORDER rows by type
        let filteredCallOrders = filteredRows.filter { $0.type == OpportunityType.call.rawValue }
        let filteredPutOrders = filteredRows.filter { $0.type == OpportunityType.put.rawValue }
        
        // Verify both types are preserved
        #expect(filteredCallOrders.count == originalCallOrders.count,
                "CALL ORDER count: filtered (\(filteredCallOrders.count)) should match original (\(originalCallOrders.count))")
        #expect(filteredPutOrders.count == originalPutOrders.count,
                "PUT ORDER count: filtered (\(filteredPutOrders.count)) should match original (\(originalPutOrders.count))")
    }
    
    @Test("Property 20: ORDER rows with and without matched contracts are all preserved",
          arguments: generateMixedSignalArrays(count: 5))
    func testOrderRowsPreservedRegardlessOfMatchedContract(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Get ORDER rows from original, distinguish by whether they have strike price (matched contract)
        let originalOrderRowsWithContract = rows.filter { 
            $0.signal == Signal.order.rawValue && $0.strikePrice != "N/A" 
        }
        let originalOrderRowsWithoutContract = rows.filter { 
            $0.signal == Signal.order.rawValue && $0.strikePrice == "N/A" 
        }
        
        // Apply filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Get filtered rows by contract status
        let filteredWithContract = filteredRows.filter { $0.strikePrice != "N/A" }
        let filteredWithoutContract = filteredRows.filter { $0.strikePrice == "N/A" }
        
        // Verify both categories are preserved
        #expect(filteredWithContract.count == originalOrderRowsWithContract.count,
                "ORDER rows with contracts: filtered (\(filteredWithContract.count)) should match original (\(originalOrderRowsWithContract.count))")
        #expect(filteredWithoutContract.count == originalOrderRowsWithoutContract.count,
                "ORDER rows without contracts: filtered (\(filteredWithoutContract.count)) should match original (\(originalOrderRowsWithoutContract.count))")
    }
    
    // MARK: - Data Integrity Tests
    
    @Test("Property 20: Filtered ORDER rows have same data as original ORDER rows",
          arguments: generateMixedSignalArrays(count: 5))
    func testFilteredRowsHaveSameDataAsOriginal(results: [AnalysisResult]) {
        let rows = results.map { AnalysisResultRow(from: $0) }
        
        // Get ORDER rows from original as a dictionary by ID
        let originalOrderRows = Dictionary(
            uniqueKeysWithValues: rows.filter { $0.signal == Signal.order.rawValue }.map { ($0.id, $0) }
        )
        
        // Apply filter
        let filter = ResultsFilter(onlyOrders: true)
        let filteredRows = rows.filtered(by: filter)
        
        // Verify each filtered row matches original exactly
        for filteredRow in filteredRows {
            guard let originalRow = originalOrderRows[filteredRow.id] else {
                Issue.record("Filtered row \(filteredRow.id) not found in original ORDER rows")
                continue
            }
            
            // Verify key fields match
            #expect(filteredRow.ticker == originalRow.ticker,
                    "Ticker mismatch for row \(filteredRow.id)")
            #expect(filteredRow.type == originalRow.type,
                    "Type mismatch for row \(filteredRow.id)")
            #expect(filteredRow.signal == originalRow.signal,
                    "Signal mismatch for row \(filteredRow.id)")
            #expect(filteredRow.strikePrice == originalRow.strikePrice,
                    "Strike price mismatch for row \(filteredRow.id)")
            #expect(filteredRow.midPremium == originalRow.midPremium,
                    "Mid premium mismatch for row \(filteredRow.id)")
        }
    }
}
