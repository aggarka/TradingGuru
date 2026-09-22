//
//  OpportunityIdentifierTests.swift
//  TradingGuruTests
//
//  Unit tests for the OpportunityIdentifier service.
//

import XCTest
@testable import TradingGuru

final class OpportunityIdentifierTests: XCTestCase {
    
    var identifier: OpportunityIdentifier!
    
    override func setUp() {
        super.setUp()
        identifier = OpportunityIdentifier()
    }
    
    override func tearDown() {
        identifier = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a RollingWindowReturn for testing.
    private func makeReturn(startDaysAgo: Int, returnPct: Double) -> RollingWindowReturn {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -startDaysAgo, to: Date())!
        let endDate = calendar.date(byAdding: .day, value: -startDaysAgo + 5, to: Date())!
        return RollingWindowReturn(startDate: startDate, endDate: endDate, returnPct: returnPct)
    }
    
    // MARK: - Basic Functionality Tests
    
    func testIdentifyOpportunities_FindsMaxReturnForCall() throws {
        // Given: Returns with known max value
        let returns = [
            makeReturn(startDaysAgo: 30, returnPct: 2.5),
            makeReturn(startDaysAgo: 25, returnPct: 5.0),  // Max
            makeReturn(startDaysAgo: 20, returnPct: 1.0),
            makeReturn(startDaysAgo: 15, returnPct: -2.0)
        ]
        let currentPrice = 100.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: CALL should have the maximum return
        XCTAssertEqual(call.type, .call)
        XCTAssertEqual(call.returnPercentage, 5.0)
    }
    
    func testIdentifyOpportunities_FindsMinReturnForPut() throws {
        // Given: Returns with known min value
        let returns = [
            makeReturn(startDaysAgo: 30, returnPct: 2.5),
            makeReturn(startDaysAgo: 25, returnPct: 5.0),
            makeReturn(startDaysAgo: 20, returnPct: 1.0),
            makeReturn(startDaysAgo: 15, returnPct: -3.5)  // Min
        ]
        let currentPrice = 100.0
        
        // When
        let (_, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: PUT should have the minimum return
        XCTAssertEqual(put.type, .put)
        XCTAssertEqual(put.returnPercentage, -3.5)
    }
    
    // MARK: - Target Price Calculation Tests
    
    func testTargetPriceCalculation_PositiveReturn() throws {
        // Given: Current price of 100 and 5% return
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 5.0)]
        let currentPrice = 100.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Target = 100 × (1 + 5/100) = 105.00
        XCTAssertEqual(call.targetPrice, 105.0)
    }
    
    func testTargetPriceCalculation_NegativeReturn() throws {
        // Given: Current price of 100 and -5% return
        let returns = [makeReturn(startDaysAgo: 10, returnPct: -5.0)]
        let currentPrice = 100.0
        
        // When
        let (_, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Target = 100 × (1 + (-5)/100) = 95.00
        XCTAssertEqual(put.targetPrice, 95.0)
    }
    
    func testTargetPriceCalculation_RoundsToTwoDecimals() throws {
        // Given: Values that would produce more than 2 decimal places
        // Current price of 100 and 3.333% return
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 3.333)]
        let currentPrice = 100.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Target = 100 × (1 + 3.333/100) = 103.333, rounded to 103.33
        XCTAssertEqual(call.targetPrice, 103.33)
    }
    
    func testTargetPriceCalculation_RoundsHalfUp() throws {
        // Given: Values that test rounding at the boundary
        // 100 * (1 + 2.555/100) = 102.555, which should round to 102.56
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 2.555)]
        let currentPrice = 100.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: 102.555 rounds to 102.56 (standard rounding)
        XCTAssertEqual(call.targetPrice, 102.56)
    }
    
    func testTargetPriceCalculation_ZeroReturn() throws {
        // Given: 0% return
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 0.0)]
        let currentPrice = 150.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Target should equal current price
        XCTAssertEqual(call.targetPrice, 150.0)
    }
    
    func testTargetPriceCalculation_ComplexPrice() throws {
        // Given: Non-round price and return
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 7.5)]
        let currentPrice = 156.78
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Target = 156.78 × 1.075 = 168.5385, rounded to 168.54
        XCTAssertEqual(call.targetPrice, 168.54)
    }
    
    // MARK: - Edge Cases
    
    func testIdentifyOpportunities_SingleReturn() throws {
        // Given: Only one return
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 3.0)]
        let currentPrice = 100.0
        
        // When
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Both CALL and PUT should use the same return
        XCTAssertEqual(call.returnPercentage, 3.0)
        XCTAssertEqual(put.returnPercentage, 3.0)
        XCTAssertEqual(call.targetPrice, put.targetPrice)
    }
    
    func testIdentifyOpportunities_AllPositiveReturns() throws {
        // Given: All positive returns
        let returns = [
            makeReturn(startDaysAgo: 30, returnPct: 1.0),
            makeReturn(startDaysAgo: 25, returnPct: 2.0),
            makeReturn(startDaysAgo: 20, returnPct: 3.0)  // Max
        ]
        let currentPrice = 100.0
        
        // When
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(call.returnPercentage, 3.0)  // Max positive
        XCTAssertEqual(put.returnPercentage, 1.0)   // Min positive
    }
    
    func testIdentifyOpportunities_AllNegativeReturns() throws {
        // Given: All negative returns
        let returns = [
            makeReturn(startDaysAgo: 30, returnPct: -1.0),  // Max (least negative)
            makeReturn(startDaysAgo: 25, returnPct: -2.0),
            makeReturn(startDaysAgo: 20, returnPct: -5.0)  // Min (most negative)
        ]
        let currentPrice = 100.0
        
        // When
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(call.returnPercentage, -1.0)  // Max (least negative)
        XCTAssertEqual(put.returnPercentage, -5.0)   // Min (most negative)
    }
    
    func testIdentifyOpportunities_DuplicateMaxReturns() throws {
        // Given: Multiple returns with the same max value
        let returns = [
            makeReturn(startDaysAgo: 30, returnPct: 5.0),
            makeReturn(startDaysAgo: 25, returnPct: 5.0),
            makeReturn(startDaysAgo: 20, returnPct: 2.0)
        ]
        let currentPrice = 100.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Should pick one of the 5.0 returns (doesn't matter which)
        XCTAssertEqual(call.returnPercentage, 5.0)
    }
    
    func testIdentifyOpportunities_PreservesWindowDates() throws {
        // Given
        let calendar = Calendar.current
        let expectedStartDate = calendar.date(byAdding: .day, value: -25, to: Date())!
        let expectedEndDate = calendar.date(byAdding: .day, value: -20, to: Date())!
        
        let maxReturn = RollingWindowReturn(
            startDate: expectedStartDate,
            endDate: expectedEndDate,
            returnPct: 10.0
        )
        let returns = [
            makeReturn(startDaysAgo: 30, returnPct: 2.0),
            maxReturn,
            makeReturn(startDaysAgo: 15, returnPct: -3.0)
        ]
        let currentPrice = 100.0
        
        // When
        let (call, _) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then: Window dates should be preserved
        XCTAssertEqual(call.windowStartDate, expectedStartDate)
        XCTAssertEqual(call.windowEndDate, expectedEndDate)
    }
    
    // MARK: - Error Handling Tests
    
    func testIdentifyOpportunities_ThrowsOnEmptyReturns() {
        // Given
        let returns: [RollingWindowReturn] = []
        let currentPrice = 100.0
        
        // When/Then
        XCTAssertThrowsError(try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)) { error in
            XCTAssertEqual(error as? OpportunityIdentificationError, .emptyReturns)
        }
    }
    
    func testIdentifyOpportunities_ThrowsOnZeroPrice() {
        // Given
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 5.0)]
        let currentPrice = 0.0
        
        // When/Then
        XCTAssertThrowsError(try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)) { error in
            XCTAssertEqual(error as? OpportunityIdentificationError, .invalidCurrentPrice(value: 0.0))
        }
    }
    
    func testIdentifyOpportunities_ThrowsOnNegativePrice() {
        // Given
        let returns = [makeReturn(startDaysAgo: 10, returnPct: 5.0)]
        let currentPrice = -50.0
        
        // When/Then
        XCTAssertThrowsError(try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)) { error in
            XCTAssertEqual(error as? OpportunityIdentificationError, .invalidCurrentPrice(value: -50.0))
        }
    }
    
    // MARK: - Static Method Tests
    
    func testStaticCalculateTargetPrice() {
        // Test the static helper method directly
        XCTAssertEqual(OpportunityIdentifier.calculateTargetPrice(currentPrice: 100.0, returnPct: 10.0), 110.0)
        XCTAssertEqual(OpportunityIdentifier.calculateTargetPrice(currentPrice: 100.0, returnPct: -10.0), 90.0)
        XCTAssertEqual(OpportunityIdentifier.calculateTargetPrice(currentPrice: 50.0, returnPct: 5.0), 52.5)
        XCTAssertEqual(OpportunityIdentifier.calculateTargetPrice(currentPrice: 123.45, returnPct: 2.5), 126.54)
    }
    
    func testStaticIdentify() throws {
        // Given
        let returns = [
            makeReturn(startDaysAgo: 20, returnPct: 8.0),
            makeReturn(startDaysAgo: 15, returnPct: -4.0)
        ]
        let currentPrice = 100.0
        
        // When
        let (call, put) = try OpportunityIdentifier.identify(returns: returns, currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(call.returnPercentage, 8.0)
        XCTAssertEqual(put.returnPercentage, -4.0)
    }
    
    func testStaticIdentifyCallOpportunity() throws {
        // Given
        let returns = [
            makeReturn(startDaysAgo: 20, returnPct: 12.0),
            makeReturn(startDaysAgo: 15, returnPct: -4.0)
        ]
        let currentPrice = 100.0
        
        // When
        let call = try OpportunityIdentifier.identifyCallOpportunity(returns: returns, currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(call.type, .call)
        XCTAssertEqual(call.returnPercentage, 12.0)
        XCTAssertEqual(call.targetPrice, 112.0)
    }
    
    func testStaticIdentifyPutOpportunity() throws {
        // Given
        let returns = [
            makeReturn(startDaysAgo: 20, returnPct: 12.0),
            makeReturn(startDaysAgo: 15, returnPct: -6.0)
        ]
        let currentPrice = 100.0
        
        // When
        let put = try OpportunityIdentifier.identifyPutOpportunity(returns: returns, currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(put.type, .put)
        XCTAssertEqual(put.returnPercentage, -6.0)
        XCTAssertEqual(put.targetPrice, 94.0)
    }
    
    // MARK: - Array Extension Tests
    
    func testArrayExtension_IdentifyOpportunities() throws {
        // Given
        let returns = [
            makeReturn(startDaysAgo: 20, returnPct: 7.0),
            makeReturn(startDaysAgo: 15, returnPct: -3.0)
        ]
        let currentPrice = 100.0
        
        // When
        let (call, put) = try returns.identifyOpportunities(currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(call.returnPercentage, 7.0)
        XCTAssertEqual(put.returnPercentage, -3.0)
    }
    
    // MARK: - Large Data Set Tests
    
    func testIdentifyOpportunities_LargeDataSet() throws {
        // Given: Many returns with known max and min
        var returns: [RollingWindowReturn] = []
        for i in 0..<100 {
            let returnPct = Double(i - 50)  // -50 to 49
            returns.append(makeReturn(startDaysAgo: 100 - i, returnPct: returnPct))
        }
        let currentPrice = 100.0
        
        // When
        let (call, put) = try identifier.identifyOpportunities(returns: returns, currentPrice: currentPrice)
        
        // Then
        XCTAssertEqual(call.returnPercentage, 49.0)   // Max
        XCTAssertEqual(put.returnPercentage, -50.0)   // Min
        XCTAssertEqual(call.targetPrice, 149.0)       // 100 × 1.49
        XCTAssertEqual(put.targetPrice, 50.0)         // 100 × 0.50
    }
}
