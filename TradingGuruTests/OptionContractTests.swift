//
//  OptionContractTests.swift
//  TradingGuruTests
//
//  Unit tests for the OptionContract model.
//  Tests mid-price calculation with various bid/ask combinations.
//

import XCTest
@testable import TradingGuru

final class OptionContractTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    /// Creates an OptionContract with the specified bid and ask prices.
    /// Uses default values for other properties to simplify test setup.
    private func makeContract(bid: Double, ask: Double) -> OptionContract {
        OptionContract(
            ticker: "AAPL",
            type: .call,
            strikePrice: 150.0,
            bid: bid,
            ask: ask,
            expirationDate: Date()
        )
    }
    
    // MARK: - Mid-Price Formula Tests
    
    /// Tests basic mid-price calculation with standard bid/ask values.
    /// **Validates: Requirements 1.6** - Mid-price calculation formula: (bid + ask) / 2
    func testMidPrice_BasicCalculation() {
        // Arrange
        let contract = makeContract(bid: 2.50, ask: 2.70)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (2.50 + 2.70) / 2 = 2.60
        XCTAssertEqual(midPrice, 2.60, accuracy: 0.0001)
    }
    
    /// Tests mid-price with equal bid and ask (no spread).
    /// **Validates: Requirements 1.6**
    func testMidPrice_EqualBidAndAsk() {
        // Arrange
        let contract = makeContract(bid: 5.00, ask: 5.00)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (5.00 + 5.00) / 2 = 5.00
        XCTAssertEqual(midPrice, 5.00, accuracy: 0.0001)
    }
    
    /// Tests mid-price with wide spread between bid and ask.
    /// **Validates: Requirements 1.6**
    func testMidPrice_WideSpread() {
        // Arrange
        let contract = makeContract(bid: 1.00, ask: 3.00)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (1.00 + 3.00) / 2 = 2.00
        XCTAssertEqual(midPrice, 2.00, accuracy: 0.0001)
    }
    
    /// Tests mid-price with narrow spread (penny-wide).
    /// **Validates: Requirements 1.6**
    func testMidPrice_NarrowSpread() {
        // Arrange
        let contract = makeContract(bid: 10.50, ask: 10.51)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (10.50 + 10.51) / 2 = 10.505
        XCTAssertEqual(midPrice, 10.505, accuracy: 0.0001)
    }
    
    /// Tests mid-price with fractional cents (high precision).
    /// **Validates: Requirements 1.6**
    func testMidPrice_FractionalCents() {
        // Arrange
        let contract = makeContract(bid: 1.234, ask: 5.678)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (1.234 + 5.678) / 2 = 3.456
        XCTAssertEqual(midPrice, 3.456, accuracy: 0.0001)
    }
    
    // MARK: - Edge Cases: Zero Values
    
    /// Tests mid-price when bid is zero.
    /// **Validates: Requirements 1.6**
    func testMidPrice_ZeroBid() {
        // Arrange
        let contract = makeContract(bid: 0.00, ask: 0.10)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.00 + 0.10) / 2 = 0.05
        XCTAssertEqual(midPrice, 0.05, accuracy: 0.0001)
    }
    
    /// Tests mid-price when both bid and ask are zero.
    /// **Validates: Requirements 1.6**
    func testMidPrice_ZeroBidAndAsk() {
        // Arrange
        let contract = makeContract(bid: 0.00, ask: 0.00)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.00 + 0.00) / 2 = 0.00
        XCTAssertEqual(midPrice, 0.00, accuracy: 0.0001)
    }
    
    // MARK: - Edge Cases: Very Small Values
    
    /// Tests mid-price with very small bid/ask values.
    /// **Validates: Requirements 1.6**
    func testMidPrice_VerySmallValues() {
        // Arrange
        let contract = makeContract(bid: 0.01, ask: 0.02)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.01 + 0.02) / 2 = 0.015
        XCTAssertEqual(midPrice, 0.015, accuracy: 0.0001)
    }
    
    /// Tests mid-price with sub-penny values.
    /// **Validates: Requirements 1.6**
    func testMidPrice_SubPennyValues() {
        // Arrange
        let contract = makeContract(bid: 0.001, ask: 0.003)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.001 + 0.003) / 2 = 0.002
        XCTAssertEqual(midPrice, 0.002, accuracy: 0.000001)
    }
    
    // MARK: - Edge Cases: Large Values
    
    /// Tests mid-price with large bid/ask values.
    /// **Validates: Requirements 1.6**
    func testMidPrice_LargeValues() {
        // Arrange
        let contract = makeContract(bid: 500.00, ask: 510.00)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (500.00 + 510.00) / 2 = 505.00
        XCTAssertEqual(midPrice, 505.00, accuracy: 0.0001)
    }
    
    /// Tests mid-price with very large bid/ask values.
    /// **Validates: Requirements 1.6**
    func testMidPrice_VeryLargeValues() {
        // Arrange
        let contract = makeContract(bid: 10000.00, ask: 10100.00)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (10000.00 + 10100.00) / 2 = 10050.00
        XCTAssertEqual(midPrice, 10050.00, accuracy: 0.0001)
    }
    
    // MARK: - Realistic Market Scenarios
    
    /// Tests mid-price with typical equity option pricing.
    /// **Validates: Requirements 1.6**
    func testMidPrice_TypicalEquityOption() {
        // Arrange: Typical liquid option with $0.05 wide market
        let contract = makeContract(bid: 3.45, ask: 3.50)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (3.45 + 3.50) / 2 = 3.475
        XCTAssertEqual(midPrice, 3.475, accuracy: 0.0001)
    }
    
    /// Tests mid-price with illiquid option (wide market).
    /// **Validates: Requirements 1.6**
    func testMidPrice_IlliquidOption() {
        // Arrange: Illiquid option with $2.00 wide market
        let contract = makeContract(bid: 0.50, ask: 2.50)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.50 + 2.50) / 2 = 1.50
        XCTAssertEqual(midPrice, 1.50, accuracy: 0.0001)
    }
    
    /// Tests mid-price with deep in-the-money option.
    /// **Validates: Requirements 1.6**
    func testMidPrice_DeepInTheMoneyOption() {
        // Arrange: Deep ITM option with high premium
        let contract = makeContract(bid: 45.80, ask: 46.20)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (45.80 + 46.20) / 2 = 46.00
        XCTAssertEqual(midPrice, 46.00, accuracy: 0.0001)
    }
    
    /// Tests mid-price with out-of-the-money option (low premium).
    /// **Validates: Requirements 1.6**
    func testMidPrice_OutOfTheMoneyOption() {
        // Arrange: OTM option with low premium
        let contract = makeContract(bid: 0.03, ask: 0.05)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.03 + 0.05) / 2 = 0.04
        XCTAssertEqual(midPrice, 0.04, accuracy: 0.0001)
    }
    
    // MARK: - Precision Tests
    
    /// Tests that mid-price calculation maintains precision.
    /// **Validates: Requirements 1.6**
    func testMidPrice_MaintainsPrecision() {
        // Arrange: Values that could have floating point issues
        let contract = makeContract(bid: 0.10, ask: 0.30)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (0.10 + 0.30) / 2 = 0.20 exactly
        XCTAssertEqual(midPrice, 0.20, accuracy: 0.000001)
    }
    
    /// Tests mid-price with repeating decimal result.
    /// **Validates: Requirements 1.6**
    func testMidPrice_RepeatingDecimalResult() {
        // Arrange: (1.00 + 2.00) / 2 = 1.50 (no repeating)
        // But (1.00 + 1.01) / 2 = 1.005
        let contract = makeContract(bid: 1.00, ask: 1.01)
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert
        XCTAssertEqual(midPrice, 1.005, accuracy: 0.0001)
    }
    
    // MARK: - Option Type Tests
    
    /// Tests that mid-price calculation works for CALL options.
    /// **Validates: Requirements 1.6**
    func testMidPrice_CallOption() {
        // Arrange
        let contract = OptionContract(
            ticker: "AAPL",
            type: .call,
            strikePrice: 150.0,
            bid: 4.50,
            ask: 4.70,
            expirationDate: Date()
        )
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (4.50 + 4.70) / 2 = 4.60
        XCTAssertEqual(midPrice, 4.60, accuracy: 0.0001)
    }
    
    /// Tests that mid-price calculation works for PUT options.
    /// **Validates: Requirements 1.6**
    func testMidPrice_PutOption() {
        // Arrange
        let contract = OptionContract(
            ticker: "AAPL",
            type: .put,
            strikePrice: 150.0,
            bid: 3.20,
            ask: 3.40,
            expirationDate: Date()
        )
        
        // Act
        let midPrice = contract.midPrice
        
        // Assert: (3.20 + 3.40) / 2 = 3.30
        XCTAssertEqual(midPrice, 3.30, accuracy: 0.0001)
    }
    
    // MARK: - Multiple Contracts Tests
    
    /// Tests mid-price calculation for multiple contracts.
    /// **Validates: Requirements 1.6**
    func testMidPrice_MultipleContracts() {
        // Arrange
        let contracts = [
            makeContract(bid: 1.00, ask: 1.20),
            makeContract(bid: 2.00, ask: 2.50),
            makeContract(bid: 3.00, ask: 3.10)
        ]
        
        // Act
        let midPrices = contracts.map { $0.midPrice }
        
        // Assert
        XCTAssertEqual(midPrices[0], 1.10, accuracy: 0.0001)  // (1.00 + 1.20) / 2
        XCTAssertEqual(midPrices[1], 2.25, accuracy: 0.0001)  // (2.00 + 2.50) / 2
        XCTAssertEqual(midPrices[2], 3.05, accuracy: 0.0001)  // (3.00 + 3.10) / 2
    }
    
    // MARK: - OptionContract Initialization Tests
    
    /// Tests that OptionContract initializes with correct properties.
    func testOptionContract_Initialization() {
        // Arrange
        let ticker = "AAPL"
        let type = OpportunityType.call
        let strikePrice = 175.0
        let bid = 5.50
        let ask = 5.70
        let expirationDate = Date()
        
        // Act
        let contract = OptionContract(
            ticker: ticker,
            type: type,
            strikePrice: strikePrice,
            bid: bid,
            ask: ask,
            expirationDate: expirationDate
        )
        
        // Assert
        XCTAssertEqual(contract.ticker, ticker)
        XCTAssertEqual(contract.type, type)
        XCTAssertEqual(contract.strikePrice, strikePrice)
        XCTAssertEqual(contract.bid, bid)
        XCTAssertEqual(contract.ask, ask)
        XCTAssertEqual(contract.expirationDate, expirationDate)
    }
    
    /// Tests that OptionContract generates a unique ID by default.
    func testOptionContract_GeneratesUniqueID() {
        // Arrange & Act
        let contract1 = makeContract(bid: 1.00, ask: 1.20)
        let contract2 = makeContract(bid: 1.00, ask: 1.20)
        
        // Assert
        XCTAssertNotEqual(contract1.id, contract2.id)
    }
    
    /// Tests that OptionContract accepts a custom ID.
    func testOptionContract_CustomID() {
        // Arrange
        let customID = UUID()
        
        // Act
        let contract = OptionContract(
            id: customID,
            ticker: "AAPL",
            type: .call,
            strikePrice: 150.0,
            bid: 1.00,
            ask: 1.20,
            expirationDate: Date()
        )
        
        // Assert
        XCTAssertEqual(contract.id, customID)
    }
    
    // MARK: - Equatable Conformance Tests
    
    /// Tests that two identical OptionContracts are equal.
    func testOptionContract_Equatable() {
        // Arrange
        let id = UUID()
        let date = Date()
        
        let contract1 = OptionContract(
            id: id,
            ticker: "AAPL",
            type: .call,
            strikePrice: 150.0,
            bid: 1.00,
            ask: 1.20,
            expirationDate: date
        )
        
        let contract2 = OptionContract(
            id: id,
            ticker: "AAPL",
            type: .call,
            strikePrice: 150.0,
            bid: 1.00,
            ask: 1.20,
            expirationDate: date
        )
        
        // Assert
        XCTAssertEqual(contract1, contract2)
    }
    
    /// Tests that different OptionContracts are not equal.
    func testOptionContract_NotEqual() {
        // Arrange
        let contract1 = makeContract(bid: 1.00, ask: 1.20)
        let contract2 = makeContract(bid: 2.00, ask: 2.40)
        
        // Assert
        XCTAssertNotEqual(contract1, contract2)
    }
}
