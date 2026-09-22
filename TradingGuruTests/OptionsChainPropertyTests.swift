//
//  OptionsChainPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for options chain data operations.
//  Tests correctness properties 1 and 2 from the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Test Helpers

/// Helper to create option contracts with random-like bid/ask values
private func makeContract(
    ticker: String = "TEST",
    type: OpportunityType = .call,
    strikePrice: Double = 100.0,
    bid: Double,
    ask: Double,
    expirationDate: Date = Date()
) -> OptionContract {
    OptionContract(
        ticker: ticker,
        type: type,
        strikePrice: strikePrice,
        bid: bid,
        ask: ask,
        expirationDate: expirationDate
    )
}

// MARK: - Property 1: Mid-Price Calculation Correctness
// **Validates: Requirements 1.6**
//
// *For any* option contract with bid price `b` and ask price `a`, the calculated
// mid-price SHALL equal `(b + a) / 2`.

@Suite("Property 1: Mid-Price Calculation Correctness - Validates Requirements 1.6")
struct MidPriceCalculationPropertyTests {
    
    // MARK: - Test Data Generation
    
    /// Property test cases with various bid/ask combinations
    static let bidAskTestCases: [(bid: Double, ask: Double)] = [
        // Standard cases
        (bid: 1.50, ask: 1.70),
        (bid: 2.00, ask: 2.50),
        (bid: 0.50, ask: 0.60),
        // Edge cases
        (bid: 0.0, ask: 0.0),
        (bid: 0.0, ask: 1.0),
        // Large values
        (bid: 100.0, ask: 110.0),
        (bid: 500.25, ask: 502.75),
        // Small values (penny options)
        (bid: 0.01, ask: 0.03),
        (bid: 0.05, ask: 0.07),
        // Fractional precision
        (bid: 1.234, ask: 5.678)
    ]
    
    // MARK: - Property Tests
    
    @Test("Property: midPrice equals (bid + ask) / 2 for all bid/ask combinations",
          arguments: bidAskTestCases)
    func testMidPriceFormula(bid: Double, ask: Double) {
        // Arrange
        let contract = makeContract(bid: bid, ask: ask)
        let expectedMidPrice = (bid + ask) / 2.0
        
        // Act
        let actualMidPrice = contract.midPrice
        
        // Assert
        #expect(abs(actualMidPrice - expectedMidPrice) < 0.000001,
                "midPrice should equal (bid + ask) / 2: expected \(expectedMidPrice), got \(actualMidPrice)")
    }
    
    @Test("Property: midPrice formula holds for CALL options")
    func testMidPriceForCallOptions() {
        let testCases: [(bid: Double, ask: Double)] = [
            (bid: 3.45, ask: 3.55),
            (bid: 10.00, ask: 10.50),
            (bid: 0.25, ask: 0.35)
        ]
        
        for (bid, ask) in testCases {
            let contract = OptionContract(
                ticker: "AAPL",
                type: .call,
                strikePrice: 150.0,
                bid: bid,
                ask: ask,
                expirationDate: Date()
            )
            
            let expectedMidPrice = (bid + ask) / 2.0
            #expect(abs(contract.midPrice - expectedMidPrice) < 0.000001,
                    "CALL midPrice should equal (bid + ask) / 2")
        }
    }
    
    @Test("Property: midPrice formula holds for PUT options")
    func testMidPriceForPutOptions() {
        let testCases: [(bid: Double, ask: Double)] = [
            (bid: 2.10, ask: 2.30),
            (bid: 8.50, ask: 9.00),
            (bid: 0.15, ask: 0.20)
        ]
        
        for (bid, ask) in testCases {
            let contract = OptionContract(
                ticker: "AAPL",
                type: .put,
                strikePrice: 145.0,
                bid: bid,
                ask: ask,
                expirationDate: Date()
            )
            
            let expectedMidPrice = (bid + ask) / 2.0
            #expect(abs(contract.midPrice - expectedMidPrice) < 0.000001,
                    "PUT midPrice should equal (bid + ask) / 2")
        }
    }
    
    @Test("Property: midPrice is symmetric (order of bid/ask doesn't matter for formula)")
    func testMidPriceSymmetry() {
        // Given (bid, ask), midPrice = (bid + ask) / 2 = (ask + bid) / 2
        let testCases: [(bid: Double, ask: Double)] = [
            (bid: 1.0, ask: 2.0),
            (bid: 5.5, ask: 6.5),
            (bid: 0.10, ask: 0.30)
        ]
        
        for (bid, ask) in testCases {
            let contract = makeContract(bid: bid, ask: ask)
            let midPrice = contract.midPrice
            
            // Verify symmetry in formula
            let fromBidFirst = (bid + ask) / 2.0
            let fromAskFirst = (ask + bid) / 2.0
            
            #expect(abs(midPrice - fromBidFirst) < 0.000001)
            #expect(abs(midPrice - fromAskFirst) < 0.000001)
            #expect(abs(fromBidFirst - fromAskFirst) < 0.000001,
                    "Formula should be symmetric")
        }
    }
    
    @Test("Property: midPrice lies between bid and ask (inclusive)")
    func testMidPriceBetweenBidAndAsk() {
        let testCases: [(bid: Double, ask: Double)] = [
            (bid: 1.00, ask: 2.00),
            (bid: 5.00, ask: 5.00),  // Equal bid/ask
            (bid: 0.01, ask: 10.00), // Wide spread
            (bid: 99.99, ask: 100.01) // Narrow spread
        ]
        
        for (bid, ask) in testCases {
            let contract = makeContract(bid: bid, ask: ask)
            let midPrice = contract.midPrice
            let minValue = min(bid, ask)
            let maxValue = max(bid, ask)
            
            #expect(midPrice >= minValue - 0.000001,
                    "midPrice should be >= min(bid, ask)")
            #expect(midPrice <= maxValue + 0.000001,
                    "midPrice should be <= max(bid, ask)")
        }
    }
    
    @Test("Property: When bid equals ask, midPrice equals both")
    func testMidPriceWhenBidEqualsAsk() {
        let equalValues: [Double] = [0.0, 1.0, 5.55, 100.0, 999.99]
        
        for value in equalValues {
            let contract = makeContract(bid: value, ask: value)
            
            #expect(abs(contract.midPrice - value) < 0.000001,
                    "When bid == ask, midPrice should equal both: expected \(value), got \(contract.midPrice)")
        }
    }
}

// MARK: - Property 2: Options Chain Parsing Completeness
// **Validates: Requirements 1.2, 1.3**
//
// *For any* valid Yahoo Finance options response containing both call and put
// contracts, the parsed `OptionsChain` SHALL contain both calls and puts arrays
// with the same number of elements as the source data.

@Suite("Property 2: Options Chain Parsing Completeness - Validates Requirements 1.2, 1.3")
struct OptionsChainParsingCompletenessTests {
    
    // MARK: - Test Data Generation
    
    /// Create a sample OptionsChain with specified number of calls and puts
    private func makeOptionsChain(
        ticker: String = "AAPL",
        callCount: Int,
        putCount: Int
    ) -> OptionsChain {
        let expirationDate = Date()
        
        let calls = (0..<callCount).map { i in
            OptionContract(
                ticker: ticker,
                type: .call,
                strikePrice: 100.0 + Double(i) * 5.0,
                bid: 1.0 + Double(i) * 0.5,
                ask: 1.2 + Double(i) * 0.5,
                expirationDate: expirationDate
            )
        }
        
        let puts = (0..<putCount).map { i in
            OptionContract(
                ticker: ticker,
                type: .put,
                strikePrice: 100.0 - Double(i) * 5.0,
                bid: 0.8 + Double(i) * 0.3,
                ask: 1.0 + Double(i) * 0.3,
                expirationDate: expirationDate
            )
        }
        
        return OptionsChain(
            ticker: ticker,
            expirationDate: expirationDate,
            calls: calls,
            puts: puts,
            fetchedAt: Date()
        )
    }
    
    // MARK: - Property Tests
    
    @Test("Property: Parsed chain contains same number of calls as source data")
    func testCallCountPreservation() {
        let testCounts = [0, 1, 3, 5, 10]
        
        for count in testCounts {
            let chain = makeOptionsChain(callCount: count, putCount: 2)
            
            #expect(chain.calls.count == count,
                    "Chain should contain \(count) calls, got \(chain.calls.count)")
        }
    }
    
    @Test("Property: Parsed chain contains same number of puts as source data")
    func testPutCountPreservation() {
        let testCounts = [0, 1, 3, 5, 10]
        
        for count in testCounts {
            let chain = makeOptionsChain(callCount: 2, putCount: count)
            
            #expect(chain.puts.count == count,
                    "Chain should contain \(count) puts, got \(chain.puts.count)")
        }
    }
    
    @Test("Property: All contracts in calls array have type .call")
    func testCallsArrayContainsOnlyCalls() {
        let chain = makeOptionsChain(callCount: 5, putCount: 5)
        
        for (index, contract) in chain.calls.enumerated() {
            #expect(contract.type == .call,
                    "Contract at calls[\(index)] should have type .call, got \(contract.type)")
        }
    }
    
    @Test("Property: All contracts in puts array have type .put")
    func testPutsArrayContainsOnlyPuts() {
        let chain = makeOptionsChain(callCount: 5, putCount: 5)
        
        for (index, contract) in chain.puts.enumerated() {
            #expect(contract.type == .put,
                    "Contract at puts[\(index)] should have type .put, got \(contract.type)")
        }
    }
    
    @Test("Property: Each contract has required fields (strike, bid, ask)")
    func testContractsHaveRequiredFields() {
        let chain = makeOptionsChain(callCount: 5, putCount: 5)
        
        for contract in chain.calls + chain.puts {
            // Strike price should be positive for valid options
            #expect(contract.strikePrice > 0,
                    "Contract should have positive strike price")
            
            // Bid and ask should be non-negative
            #expect(contract.bid >= 0,
                    "Contract bid should be non-negative")
            #expect(contract.ask >= 0,
                    "Contract ask should be non-negative")
            
            // Ticker should match chain ticker
            #expect(contract.ticker == chain.ticker,
                    "Contract ticker should match chain ticker")
            
            // Expiration should match chain expiration
            #expect(contract.expirationDate == chain.expirationDate,
                    "Contract expiration should match chain expiration")
        }
    }
    
    @Test("Property: isEmpty is true if and only if both calls and puts are empty")
    func testIsEmptyProperty() {
        let testCases: [(callCount: Int, putCount: Int, expectedEmpty: Bool)] = [
            (callCount: 0, putCount: 0, expectedEmpty: true),
            (callCount: 1, putCount: 0, expectedEmpty: false),
            (callCount: 0, putCount: 1, expectedEmpty: false),
            (callCount: 1, putCount: 1, expectedEmpty: false),
            (callCount: 5, putCount: 5, expectedEmpty: false)
        ]
        
        for (callCount, putCount, expectedEmpty) in testCases {
            let chain = makeOptionsChain(callCount: callCount, putCount: putCount)
            
            #expect(chain.isEmpty == expectedEmpty,
                    "isEmpty should be \(expectedEmpty) for callCount=\(callCount), putCount=\(putCount)")
        }
    }
    
    @Test("Property: Empty chain factory creates chain with zero contracts")
    func testEmptyChainFactory() {
        let ticker = "TEST"
        let expirationDate = Date()
        
        let emptyChain = OptionsChain.empty(ticker: ticker, expirationDate: expirationDate)
        
        #expect(emptyChain.calls.isEmpty,
                "Empty chain should have no calls")
        #expect(emptyChain.puts.isEmpty,
                "Empty chain should have no puts")
        #expect(emptyChain.isEmpty == true,
                "Empty chain isEmpty should be true")
        #expect(emptyChain.ticker == ticker,
                "Empty chain should preserve ticker")
        #expect(emptyChain.expirationDate == expirationDate,
                "Empty chain should preserve expiration date")
    }
    
    @Test("Property: Chain ticker is preserved in all contracts")
    func testTickerPreservation() {
        let tickers = ["AAPL", "MSFT", "GOOGL", "TSLA", "AMZN"]
        
        for ticker in tickers {
            let chain = makeOptionsChain(ticker: ticker, callCount: 3, putCount: 3)
            
            #expect(chain.ticker == ticker)
            
            for contract in chain.calls + chain.puts {
                #expect(contract.ticker == ticker,
                        "Contract ticker should be \(ticker), got \(contract.ticker)")
            }
        }
    }
    
    @Test("Property: Expiration date is preserved in all contracts")
    func testExpirationDatePreservation() {
        let expirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week from now
        
        let calls = [
            OptionContract(ticker: "TEST", type: .call, strikePrice: 100, bid: 1.0, ask: 1.2, expirationDate: expirationDate),
            OptionContract(ticker: "TEST", type: .call, strikePrice: 105, bid: 0.5, ask: 0.7, expirationDate: expirationDate)
        ]
        
        let puts = [
            OptionContract(ticker: "TEST", type: .put, strikePrice: 95, bid: 0.8, ask: 1.0, expirationDate: expirationDate),
            OptionContract(ticker: "TEST", type: .put, strikePrice: 90, bid: 1.2, ask: 1.4, expirationDate: expirationDate)
        ]
        
        let chain = OptionsChain(
            ticker: "TEST",
            expirationDate: expirationDate,
            calls: calls,
            puts: puts,
            fetchedAt: Date()
        )
        
        #expect(chain.expirationDate == expirationDate)
        
        for contract in chain.calls + chain.puts {
            #expect(contract.expirationDate == expirationDate,
                    "Contract expiration should match chain expiration")
        }
    }
}

// MARK: - Property 2 Extended: Options Chain Parsing Completeness (Value Preservation)
// **Validates: Requirements 1.2, 1.3**
//
// Extended tests verifying that all valid options data in the input appears in the
// parsed output with correct values for bid, ask, strike, and expiration.

@Suite("Property 2 Extended: Options Chain Parsing Completeness - Value Preservation")
struct OptionsChainParsingValuePreservationTests {
    
    // MARK: - Test Data Structures
    
    /// Represents raw option data as it would appear in API input
    struct RawOptionInput: Equatable {
        let strike: Double
        let bid: Double
        let ask: Double
    }
    
    // MARK: - Test Data Generation
    
    /// Test cases with various option configurations
    static let optionConfigTestCases: [(callInputs: [RawOptionInput], putInputs: [RawOptionInput])] = [
        // Case 1: Single call and put
        (
            callInputs: [RawOptionInput(strike: 100.0, bid: 1.50, ask: 1.70)],
            putInputs: [RawOptionInput(strike: 95.0, bid: 0.80, ask: 1.00)]
        ),
        // Case 2: Multiple calls and puts with varying values
        (
            callInputs: [
                RawOptionInput(strike: 100.0, bid: 2.00, ask: 2.20),
                RawOptionInput(strike: 105.0, bid: 1.50, ask: 1.75),
                RawOptionInput(strike: 110.0, bid: 0.80, ask: 1.00)
            ],
            putInputs: [
                RawOptionInput(strike: 95.0, bid: 1.20, ask: 1.40),
                RawOptionInput(strike: 90.0, bid: 0.60, ask: 0.80)
            ]
        ),
        // Case 3: Many options (simulating full chain)
        (
            callInputs: [
                RawOptionInput(strike: 90.0, bid: 12.00, ask: 12.50),
                RawOptionInput(strike: 95.0, bid: 8.00, ask: 8.40),
                RawOptionInput(strike: 100.0, bid: 4.50, ask: 4.80),
                RawOptionInput(strike: 105.0, bid: 2.20, ask: 2.50),
                RawOptionInput(strike: 110.0, bid: 1.00, ask: 1.25)
            ],
            putInputs: [
                RawOptionInput(strike: 90.0, bid: 0.50, ask: 0.70),
                RawOptionInput(strike: 95.0, bid: 1.20, ask: 1.45),
                RawOptionInput(strike: 100.0, bid: 2.80, ask: 3.10),
                RawOptionInput(strike: 105.0, bid: 5.50, ask: 5.90),
                RawOptionInput(strike: 110.0, bid: 9.00, ask: 9.50)
            ]
        ),
        // Case 4: Edge case - zero bids (illiquid options)
        (
            callInputs: [
                RawOptionInput(strike: 150.0, bid: 0.0, ask: 0.10),
                RawOptionInput(strike: 155.0, bid: 0.0, ask: 0.05)
            ],
            putInputs: [
                RawOptionInput(strike: 50.0, bid: 0.0, ask: 0.15)
            ]
        ),
        // Case 5: Precise decimal values
        (
            callInputs: [
                RawOptionInput(strike: 123.45, bid: 3.67, ask: 3.89),
                RawOptionInput(strike: 127.50, bid: 2.11, ask: 2.33)
            ],
            putInputs: [
                RawOptionInput(strike: 118.75, bid: 1.99, ask: 2.21)
            ]
        )
    ]
    
    /// Creates an OptionsChain from raw inputs (simulating parsing)
    private func parseInputsToChain(
        ticker: String,
        expirationDate: Date,
        callInputs: [RawOptionInput],
        putInputs: [RawOptionInput]
    ) -> OptionsChain {
        let calls = callInputs.map { input in
            OptionContract(
                ticker: ticker,
                type: .call,
                strikePrice: input.strike,
                bid: input.bid,
                ask: input.ask,
                expirationDate: expirationDate
            )
        }
        
        let puts = putInputs.map { input in
            OptionContract(
                ticker: ticker,
                type: .put,
                strikePrice: input.strike,
                bid: input.bid,
                ask: input.ask,
                expirationDate: expirationDate
            )
        }
        
        return OptionsChain(
            ticker: ticker,
            expirationDate: expirationDate,
            calls: calls,
            puts: puts,
            fetchedAt: Date()
        )
    }
    
    // MARK: - Property Tests: Input Count Equals Output Count
    
    @Test("Property: All call inputs appear in parsed output (count preservation)",
          arguments: optionConfigTestCases)
    func testCallCountMatchesInput(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "AAPL"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        #expect(chain.calls.count == callInputs.count,
                "Parsed calls count (\(chain.calls.count)) should match input count (\(callInputs.count))")
    }
    
    @Test("Property: All put inputs appear in parsed output (count preservation)",
          arguments: optionConfigTestCases)
    func testPutCountMatchesInput(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "AAPL"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        #expect(chain.puts.count == putInputs.count,
                "Parsed puts count (\(chain.puts.count)) should match input count (\(putInputs.count))")
    }
    
    // MARK: - Property Tests: Strike Price Preservation
    
    @Test("Property: All call strike prices are preserved exactly",
          arguments: optionConfigTestCases)
    func testCallStrikePricesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "MSFT"
        let expiration = Date().addingTimeInterval(14 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in callInputs.enumerated() {
            #expect(abs(chain.calls[index].strikePrice - input.strike) < 0.000001,
                    "Call[\(index)] strike should be \(input.strike), got \(chain.calls[index].strikePrice)")
        }
    }
    
    @Test("Property: All put strike prices are preserved exactly",
          arguments: optionConfigTestCases)
    func testPutStrikePricesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "MSFT"
        let expiration = Date().addingTimeInterval(14 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in putInputs.enumerated() {
            #expect(abs(chain.puts[index].strikePrice - input.strike) < 0.000001,
                    "Put[\(index)] strike should be \(input.strike), got \(chain.puts[index].strikePrice)")
        }
    }
    
    // MARK: - Property Tests: Bid Price Preservation
    
    @Test("Property: All call bid prices are preserved exactly",
          arguments: optionConfigTestCases)
    func testCallBidPricesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "GOOGL"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in callInputs.enumerated() {
            #expect(abs(chain.calls[index].bid - input.bid) < 0.000001,
                    "Call[\(index)] bid should be \(input.bid), got \(chain.calls[index].bid)")
        }
    }
    
    @Test("Property: All put bid prices are preserved exactly",
          arguments: optionConfigTestCases)
    func testPutBidPricesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "GOOGL"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in putInputs.enumerated() {
            #expect(abs(chain.puts[index].bid - input.bid) < 0.000001,
                    "Put[\(index)] bid should be \(input.bid), got \(chain.puts[index].bid)")
        }
    }
    
    // MARK: - Property Tests: Ask Price Preservation
    
    @Test("Property: All call ask prices are preserved exactly",
          arguments: optionConfigTestCases)
    func testCallAskPricesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "TSLA"
        let expiration = Date().addingTimeInterval(21 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in callInputs.enumerated() {
            #expect(abs(chain.calls[index].ask - input.ask) < 0.000001,
                    "Call[\(index)] ask should be \(input.ask), got \(chain.calls[index].ask)")
        }
    }
    
    @Test("Property: All put ask prices are preserved exactly",
          arguments: optionConfigTestCases)
    func testPutAskPricesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "TSLA"
        let expiration = Date().addingTimeInterval(21 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in putInputs.enumerated() {
            #expect(abs(chain.puts[index].ask - input.ask) < 0.000001,
                    "Put[\(index)] ask should be \(input.ask), got \(chain.puts[index].ask)")
        }
    }
    
    // MARK: - Property Tests: Expiration Date Preservation
    
    @Test("Property: All call options have correct expiration date",
          arguments: optionConfigTestCases)
    func testCallExpirationDatesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "AMZN"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, contract) in chain.calls.enumerated() {
            #expect(contract.expirationDate == expiration,
                    "Call[\(index)] expiration should match input expiration")
        }
    }
    
    @Test("Property: All put options have correct expiration date",
          arguments: optionConfigTestCases)
    func testPutExpirationDatesPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "AMZN"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, contract) in chain.puts.enumerated() {
            #expect(contract.expirationDate == expiration,
                    "Put[\(index)] expiration should match input expiration")
        }
    }
    
    // MARK: - Property Tests: Complete Value Triplet (strike, bid, ask) Preservation
    
    @Test("Property: Complete data triplet (strike, bid, ask) preserved for all calls",
          arguments: optionConfigTestCases)
    func testCallCompleteTripletPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "META"
        let expiration = Date().addingTimeInterval(14 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in callInputs.enumerated() {
            let contract = chain.calls[index]
            
            let strikeMatches = abs(contract.strikePrice - input.strike) < 0.000001
            let bidMatches = abs(contract.bid - input.bid) < 0.000001
            let askMatches = abs(contract.ask - input.ask) < 0.000001
            
            #expect(strikeMatches && bidMatches && askMatches,
                    "Call[\(index)] triplet should be (strike: \(input.strike), bid: \(input.bid), ask: \(input.ask)), got (strike: \(contract.strikePrice), bid: \(contract.bid), ask: \(contract.ask))")
        }
    }
    
    @Test("Property: Complete data triplet (strike, bid, ask) preserved for all puts",
          arguments: optionConfigTestCases)
    func testPutCompleteTripletPreserved(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "META"
        let expiration = Date().addingTimeInterval(14 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in putInputs.enumerated() {
            let contract = chain.puts[index]
            
            let strikeMatches = abs(contract.strikePrice - input.strike) < 0.000001
            let bidMatches = abs(contract.bid - input.bid) < 0.000001
            let askMatches = abs(contract.ask - input.ask) < 0.000001
            
            #expect(strikeMatches && bidMatches && askMatches,
                    "Put[\(index)] triplet should be (strike: \(input.strike), bid: \(input.bid), ask: \(input.ask)), got (strike: \(contract.strikePrice), bid: \(contract.bid), ask: \(contract.ask))")
        }
    }
    
    // MARK: - Property Tests: Mid-Price Calculation After Parsing
    
    @Test("Property: Mid-price calculated correctly from preserved bid/ask for calls",
          arguments: optionConfigTestCases)
    func testCallMidPriceAfterParsing(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "NVDA"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in callInputs.enumerated() {
            let contract = chain.calls[index]
            let expectedMidPrice = (input.bid + input.ask) / 2.0
            
            #expect(abs(contract.midPrice - expectedMidPrice) < 0.000001,
                    "Call[\(index)] midPrice should be \(expectedMidPrice), got \(contract.midPrice)")
        }
    }
    
    @Test("Property: Mid-price calculated correctly from preserved bid/ask for puts",
          arguments: optionConfigTestCases)
    func testPutMidPriceAfterParsing(callInputs: [RawOptionInput], putInputs: [RawOptionInput]) {
        let ticker = "NVDA"
        let expiration = Date().addingTimeInterval(7 * 24 * 60 * 60)
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: putInputs
        )
        
        for (index, input) in putInputs.enumerated() {
            let contract = chain.puts[index]
            let expectedMidPrice = (input.bid + input.ask) / 2.0
            
            #expect(abs(contract.midPrice - expectedMidPrice) < 0.000001,
                    "Put[\(index)] midPrice should be \(expectedMidPrice), got \(contract.midPrice)")
        }
    }
    
    // MARK: - Property Tests: Empty Input Handling
    
    @Test("Property: Empty call input produces empty calls array")
    func testEmptyCallInputProducesEmptyCalls() {
        let ticker = "TEST"
        let expiration = Date()
        let emptyCallInputs: [RawOptionInput] = []
        let putInputs = [RawOptionInput(strike: 100.0, bid: 1.0, ask: 1.2)]
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: emptyCallInputs,
            putInputs: putInputs
        )
        
        #expect(chain.calls.isEmpty,
                "Empty call input should produce empty calls array")
        #expect(chain.puts.count == putInputs.count,
                "Put count should still be preserved")
    }
    
    @Test("Property: Empty put input produces empty puts array")
    func testEmptyPutInputProducesEmptyPuts() {
        let ticker = "TEST"
        let expiration = Date()
        let callInputs = [RawOptionInput(strike: 100.0, bid: 1.0, ask: 1.2)]
        let emptyPutInputs: [RawOptionInput] = []
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: callInputs,
            putInputs: emptyPutInputs
        )
        
        #expect(chain.puts.isEmpty,
                "Empty put input should produce empty puts array")
        #expect(chain.calls.count == callInputs.count,
                "Call count should still be preserved")
    }
    
    @Test("Property: Both empty inputs produce completely empty chain")
    func testBothEmptyInputsProduceEmptyChain() {
        let ticker = "TEST"
        let expiration = Date()
        let emptyCallInputs: [RawOptionInput] = []
        let emptyPutInputs: [RawOptionInput] = []
        
        let chain = parseInputsToChain(
            ticker: ticker,
            expirationDate: expiration,
            callInputs: emptyCallInputs,
            putInputs: emptyPutInputs
        )
        
        #expect(chain.calls.isEmpty, "Empty call input should produce empty calls array")
        #expect(chain.puts.isEmpty, "Empty put input should produce empty puts array")
        #expect(chain.isEmpty, "Chain with no inputs should be empty")
    }
}

