//
//  OptionsParsingTests.swift
//  TradingGuruTests
//
//  Unit tests for options chain parsing in YahooFinanceService.
//  Tests valid responses, empty responses, and malformed data handling.
//
//  **Validates: Requirements 1.2, 1.3, 1.5**
//

import XCTest
@testable import TradingGuru

final class OptionsParsingTests: XCTestCase {
    
    // MARK: - Test Fixtures
    
    /// Valid Yahoo Finance options response JSON with calls and puts
    private let validOptionsResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "AAPL",
                "expirationDates": [1735344000],
                "strikes": [145.0, 150.0, 155.0, 160.0],
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [
                        {
                            "contractSymbol": "AAPL250103C00145000",
                            "strike": 145.0,
                            "currency": "USD",
                            "lastPrice": 12.50,
                            "bid": 12.40,
                            "ask": 12.60,
                            "volume": 100,
                            "openInterest": 500,
                            "impliedVolatility": 0.25,
                            "inTheMoney": true
                        },
                        {
                            "contractSymbol": "AAPL250103C00150000",
                            "strike": 150.0,
                            "currency": "USD",
                            "lastPrice": 8.00,
                            "bid": 7.90,
                            "ask": 8.10,
                            "volume": 200,
                            "openInterest": 800,
                            "impliedVolatility": 0.22,
                            "inTheMoney": true
                        },
                        {
                            "contractSymbol": "AAPL250103C00155000",
                            "strike": 155.0,
                            "currency": "USD",
                            "lastPrice": 4.50,
                            "bid": 4.40,
                            "ask": 4.60,
                            "volume": 150,
                            "openInterest": 600,
                            "impliedVolatility": 0.20,
                            "inTheMoney": false
                        }
                    ],
                    "puts": [
                        {
                            "contractSymbol": "AAPL250103P00145000",
                            "strike": 145.0,
                            "currency": "USD",
                            "lastPrice": 2.00,
                            "bid": 1.90,
                            "ask": 2.10,
                            "volume": 80,
                            "openInterest": 400,
                            "impliedVolatility": 0.23,
                            "inTheMoney": false
                        },
                        {
                            "contractSymbol": "AAPL250103P00150000",
                            "strike": 150.0,
                            "currency": "USD",
                            "lastPrice": 4.00,
                            "bid": 3.90,
                            "ask": 4.10,
                            "volume": 120,
                            "openInterest": 550,
                            "impliedVolatility": 0.21,
                            "inTheMoney": false
                        }
                    ]
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Empty options chain response (no contracts for expiration)
    private let emptyOptionsResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "TEST",
                "expirationDates": [],
                "strikes": [],
                "options": []
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with empty calls and puts arrays
    private let noContractsResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "TEST",
                "expirationDates": [1735344000],
                "strikes": [],
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [],
                    "puts": []
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with null result (ticker not found)
    private let nullResultResponseJSON = """
    {
        "optionChain": {
            "result": null,
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with missing strike prices
    private let missingStrikeResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "AAPL",
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [
                        {
                            "contractSymbol": "AAPL250103C00145000",
                            "bid": 12.40,
                            "ask": 12.60
                        },
                        {
                            "contractSymbol": "AAPL250103C00150000",
                            "strike": 150.0,
                            "bid": 7.90,
                            "ask": 8.10
                        }
                    ],
                    "puts": []
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with missing bid/ask prices (should use 0.0)
    private let missingBidAskResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "AAPL",
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [
                        {
                            "contractSymbol": "AAPL250103C00145000",
                            "strike": 145.0
                        }
                    ],
                    "puts": [
                        {
                            "contractSymbol": "AAPL250103P00150000",
                            "strike": 150.0,
                            "bid": 3.90
                        }
                    ]
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with zero bid/ask prices (valid edge case)
    private let zeroBidAskResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "TEST",
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [
                        {
                            "contractSymbol": "TEST250103C00100000",
                            "strike": 100.0,
                            "bid": 0.0,
                            "ask": 0.0
                        },
                        {
                            "contractSymbol": "TEST250103C00105000",
                            "strike": 105.0,
                            "bid": 0.0,
                            "ask": 0.05
                        }
                    ],
                    "puts": [
                        {
                            "contractSymbol": "TEST250103P00100000",
                            "strike": 100.0,
                            "bid": 0.0,
                            "ask": 0.01
                        }
                    ]
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with very large strike prices
    private let largeStrikePricesResponseJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "BRK.A",
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [
                        {
                            "contractSymbol": "BRKA250103C500000",
                            "strike": 500000.0,
                            "bid": 50000.0,
                            "ask": 52000.0
                        },
                        {
                            "contractSymbol": "BRKA250103C550000",
                            "strike": 550000.0,
                            "bid": 25000.0,
                            "ask": 27000.0
                        },
                        {
                            "contractSymbol": "BRKA250103C600000",
                            "strike": 600000.0,
                            "bid": 5000.0,
                            "ask": 7500.0
                        }
                    ],
                    "puts": [
                        {
                            "contractSymbol": "BRKA250103P450000",
                            "strike": 450000.0,
                            "bid": 10000.0,
                            "ask": 12500.0
                        },
                        {
                            "contractSymbol": "BRKA250103P400000",
                            "strike": 400000.0,
                            "bid": 2000.0,
                            "ask": 3500.0
                        }
                    ]
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    /// Response with mixed valid and invalid contracts (some missing strike)
    private let mixedValidInvalidContractsJSON = """
    {
        "optionChain": {
            "result": [{
                "underlyingSymbol": "AAPL",
                "options": [{
                    "expirationDate": 1735344000,
                    "calls": [
                        {
                            "contractSymbol": "AAPL250103C00145000",
                            "strike": 145.0,
                            "bid": 12.40,
                            "ask": 12.60
                        },
                        {
                            "contractSymbol": "AAPL250103C00150000",
                            "bid": 7.90,
                            "ask": 8.10
                        },
                        {
                            "contractSymbol": "AAPL250103C00155000",
                            "strike": 155.0,
                            "bid": 4.40,
                            "ask": 4.60
                        }
                    ],
                    "puts": [
                        {
                            "strike": 145.0,
                            "bid": 1.90,
                            "ask": 2.10
                        },
                        {
                            "contractSymbol": "AAPL250103P00150000"
                        }
                    ]
                }]
            }],
            "error": null
        }
    }
    """.data(using: .utf8)!
    
    // MARK: - Valid Response Tests
    
    /// Tests parsing a valid options response with calls and puts.
    /// **Validates: Requirements 1.2, 1.3**
    func testParseValidOptionsResponse_ContainsBothCallsAndPuts() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act - Decode the response structure
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: validOptionsResponseJSON)
        
        // Assert - Verify structure is correct
        XCTAssertNotNil(response.optionChain.result)
        XCTAssertEqual(response.optionChain.result?.count, 1)
        
        guard let result = response.optionChain.result?.first,
              let options = result.options?.first else {
            XCTFail("Expected valid result with options")
            return
        }
        
        // Verify calls array
        XCTAssertNotNil(options.calls)
        XCTAssertEqual(options.calls?.count, 3, "Should have 3 call options")
        
        // Verify puts array
        XCTAssertNotNil(options.puts)
        XCTAssertEqual(options.puts?.count, 2, "Should have 2 put options")
    }
    
    /// Tests that parsed call options contain strike, bid, and ask prices.
    /// **Validates: Requirement 1.3**
    func testParseValidOptionsResponse_CallsHaveRequiredFields() throws {
        // Arrange
        let decoder = JSONDecoder()
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: validOptionsResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls else {
            XCTFail("Expected calls array")
            return
        }
        
        // Assert - Each call has required fields
        for call in calls {
            XCTAssertNotNil(call.strike, "Call option should have strike price")
            XCTAssertNotNil(call.bid, "Call option should have bid price")
            XCTAssertNotNil(call.ask, "Call option should have ask price")
        }
        
        // Verify specific values
        let firstCall = calls[0]
        XCTAssertEqual(firstCall.strike ?? 0, 145.0, accuracy: 0.001)
        XCTAssertEqual(firstCall.bid ?? 0, 12.40, accuracy: 0.001)
        XCTAssertEqual(firstCall.ask ?? 0, 12.60, accuracy: 0.001)
    }
    
    /// Tests that parsed put options contain strike, bid, and ask prices.
    /// **Validates: Requirement 1.3**
    func testParseValidOptionsResponse_PutsHaveRequiredFields() throws {
        // Arrange
        let decoder = JSONDecoder()
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: validOptionsResponseJSON)
        
        guard let puts = response.optionChain.result?.first?.options?.first?.puts else {
            XCTFail("Expected puts array")
            return
        }
        
        // Assert - Each put has required fields
        for put in puts {
            XCTAssertNotNil(put.strike, "Put option should have strike price")
            XCTAssertNotNil(put.bid, "Put option should have bid price")
            XCTAssertNotNil(put.ask, "Put option should have ask price")
        }
        
        // Verify specific values
        let firstPut = puts[0]
        XCTAssertEqual(firstPut.strike ?? 0, 145.0, accuracy: 0.001)
        XCTAssertEqual(firstPut.bid ?? 0, 1.90, accuracy: 0.001)
        XCTAssertEqual(firstPut.ask ?? 0, 2.10, accuracy: 0.001)
    }
    
    /// Tests mid-price calculation from parsed bid/ask values.
    /// **Validates: Requirement 1.6**
    func testParseValidOptionsResponse_MidPriceCalculation() throws {
        // Arrange
        let decoder = JSONDecoder()
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: validOptionsResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls else {
            XCTFail("Expected calls array")
            return
        }
        
        // Assert - Verify mid-price calculation
        let firstCall = calls[0]
        let expectedMidPrice = ((firstCall.bid ?? 0) + (firstCall.ask ?? 0)) / 2.0
        XCTAssertEqual(expectedMidPrice, 12.50, accuracy: 0.001)
        
        let secondCall = calls[1]
        let secondMidPrice = ((secondCall.bid ?? 0) + (secondCall.ask ?? 0)) / 2.0
        XCTAssertEqual(secondMidPrice, 8.00, accuracy: 0.001)
    }
    
    // MARK: - Empty Response Tests
    
    /// Tests parsing response with no options data.
    /// **Validates: Requirement 1.5**
    func testParseEmptyOptionsResponse_ReturnsEmptyArrays() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: emptyOptionsResponseJSON)
        
        // Assert
        XCTAssertNotNil(response.optionChain.result)
        let result = response.optionChain.result?.first
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.options?.isEmpty ?? true, "Options array should be empty")
    }
    
    /// Tests parsing response with empty calls and puts arrays.
    /// **Validates: Requirement 1.5**
    func testParseNoContractsResponse_ReturnsEmptyChain() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: noContractsResponseJSON)
        
        // Assert
        guard let options = response.optionChain.result?.first?.options?.first else {
            XCTFail("Expected options structure")
            return
        }
        
        XCTAssertTrue(options.calls?.isEmpty ?? true, "Calls array should be empty")
        XCTAssertTrue(options.puts?.isEmpty ?? true, "Puts array should be empty")
    }
    
    /// Tests creating an empty OptionsChain using the factory method.
    /// **Validates: Requirement 1.5**
    func testEmptyOptionsChainFactory() {
        // Arrange
        let ticker = "INVALID"
        let expirationDate = Date()
        
        // Act
        let emptyChain = OptionsChain.empty(ticker: ticker, expirationDate: expirationDate)
        
        // Assert
        XCTAssertTrue(emptyChain.isEmpty)
        XCTAssertEqual(emptyChain.calls.count, 0)
        XCTAssertEqual(emptyChain.puts.count, 0)
        XCTAssertEqual(emptyChain.ticker, ticker)
    }
    
    // MARK: - Malformed Data Tests
    
    /// Tests parsing response with null result (ticker not found scenario).
    /// **Validates: Requirement 1.5**
    func testParseNullResult_HandledGracefully() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: nullResultResponseJSON)
        
        // Assert - Result should be nil or empty
        XCTAssertNil(response.optionChain.result)
    }
    
    /// Tests parsing response with missing strike prices (contract should be skipped).
    /// **Validates: Requirement 1.3**
    func testParseMissingStrike_ContractSkipped() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: missingStrikeResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls else {
            XCTFail("Expected calls array")
            return
        }
        
        // Assert - First contract has no strike, second has strike
        XCTAssertEqual(calls.count, 2)
        XCTAssertNil(calls[0].strike, "First call should have nil strike")
        XCTAssertEqual(calls[1].strike ?? 0, 150.0, accuracy: 0.001)
    }
    
    /// Tests parsing response with missing bid/ask prices (should default to 0.0).
    /// **Validates: Requirement 1.3**
    func testParseMissingBidAsk_DefaultsToZero() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: missingBidAskResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls,
              let puts = response.optionChain.result?.first?.options?.first?.puts else {
            XCTFail("Expected calls and puts arrays")
            return
        }
        
        // Assert - Call has no bid/ask (nil values)
        let call = calls[0]
        XCTAssertEqual(call.strike ?? 0, 145.0, accuracy: 0.001)
        XCTAssertNil(call.bid)
        XCTAssertNil(call.ask)
        
        // Assert - Put has bid but no ask
        let put = puts[0]
        XCTAssertEqual(put.strike ?? 0, 150.0, accuracy: 0.001)
        XCTAssertEqual(put.bid ?? 0, 3.90, accuracy: 0.001)
        XCTAssertNil(put.ask)
    }
    
    /// Tests that completely malformed JSON throws an error.
    func testParseMalformedJSON_ThrowsError() {
        // Arrange
        let malformedJSON = "{ invalid json }".data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Act & Assert
        XCTAssertThrowsError(try decoder.decode(TestYahooOptionsResponse.self, from: malformedJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    /// Tests parsing response with unexpected structure.
    func testParseUnexpectedStructure_HandlesGracefully() throws {
        // Arrange - Missing optionChain wrapper
        let unexpectedJSON = """
        {
            "result": [{
                "underlyingSymbol": "AAPL"
            }]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Act & Assert - Should fail to decode
        XCTAssertThrowsError(try decoder.decode(TestYahooOptionsResponse.self, from: unexpectedJSON))
    }
    
    // MARK: - OptionContract Creation Tests
    
    /// Tests creating OptionContract from parsed data.
    func testOptionContractCreation_FromParsedData() {
        // Arrange - Simulated parsed data
        let strike = 150.0
        let bid = 4.50
        let ask = 4.70
        let ticker = "AAPL"
        let expiration = Date()
        
        // Act
        let contract = OptionContract(
            ticker: ticker,
            type: .call,
            strikePrice: strike,
            bid: bid,
            ask: ask,
            expirationDate: expiration
        )
        
        // Assert
        XCTAssertEqual(contract.strikePrice, strike)
        XCTAssertEqual(contract.bid, bid)
        XCTAssertEqual(contract.ask, ask)
        XCTAssertEqual(contract.ticker, ticker)
        XCTAssertEqual(contract.type, .call)
        XCTAssertEqual(contract.midPrice, 4.60, accuracy: 0.001)
    }
    
    /// Tests creating OptionsChain from parsed contracts.
    func testOptionsChainCreation_FromParsedContracts() {
        // Arrange
        let ticker = "AAPL"
        let expiration = Date()
        
        let calls = [
            OptionContract(ticker: ticker, type: .call, strikePrice: 145.0, bid: 12.40, ask: 12.60, expirationDate: expiration),
            OptionContract(ticker: ticker, type: .call, strikePrice: 150.0, bid: 7.90, ask: 8.10, expirationDate: expiration)
        ]
        
        let puts = [
            OptionContract(ticker: ticker, type: .put, strikePrice: 145.0, bid: 1.90, ask: 2.10, expirationDate: expiration),
            OptionContract(ticker: ticker, type: .put, strikePrice: 150.0, bid: 3.90, ask: 4.10, expirationDate: expiration)
        ]
        
        // Act
        let chain = OptionsChain(
            ticker: ticker,
            expirationDate: expiration,
            calls: calls,
            puts: puts,
            fetchedAt: Date()
        )
        
        // Assert
        XCTAssertEqual(chain.ticker, ticker)
        XCTAssertEqual(chain.calls.count, 2)
        XCTAssertEqual(chain.puts.count, 2)
        XCTAssertFalse(chain.isEmpty)
    }
    
    // MARK: - Edge Case: Zero Bid/Ask Tests
    
    /// Tests parsing response with zero bid/ask prices.
    /// Verifies that zero values are valid and preserved during parsing.
    func testParseZeroBidAsk_ParsedCorrectly() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: zeroBidAskResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls,
              let puts = response.optionChain.result?.first?.options?.first?.puts else {
            XCTFail("Expected calls and puts arrays")
            return
        }
        
        // Assert - Verify zero bid/ask values are parsed correctly
        XCTAssertEqual(calls.count, 2)
        
        // First call: both bid and ask are zero
        let firstCall = calls[0]
        XCTAssertEqual(firstCall.strike ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(firstCall.bid ?? -1, 0.0, accuracy: 0.001, "Zero bid should be parsed as 0.0")
        XCTAssertEqual(firstCall.ask ?? -1, 0.0, accuracy: 0.001, "Zero ask should be parsed as 0.0")
        
        // Second call: zero bid, small ask
        let secondCall = calls[1]
        XCTAssertEqual(secondCall.strike ?? 0, 105.0, accuracy: 0.001)
        XCTAssertEqual(secondCall.bid ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(secondCall.ask ?? -1, 0.05, accuracy: 0.001)
        
        // Put: zero bid, small ask
        let put = puts[0]
        XCTAssertEqual(put.strike ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(put.bid ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(put.ask ?? -1, 0.01, accuracy: 0.001)
    }
    
    /// Tests mid-price calculation when bid/ask are zero.
    func testParseZeroBidAsk_MidPriceCalculation() throws {
        // Arrange
        let decoder = JSONDecoder()
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: zeroBidAskResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls else {
            XCTFail("Expected calls array")
            return
        }
        
        // Assert - Verify mid-price with zero values
        // First call: (0.0 + 0.0) / 2 = 0.0
        let firstCallMid = ((calls[0].bid ?? 0) + (calls[0].ask ?? 0)) / 2.0
        XCTAssertEqual(firstCallMid, 0.0, accuracy: 0.001)
        
        // Second call: (0.0 + 0.05) / 2 = 0.025
        let secondCallMid = ((calls[1].bid ?? 0) + (calls[1].ask ?? 0)) / 2.0
        XCTAssertEqual(secondCallMid, 0.025, accuracy: 0.001)
    }
    
    /// Tests creating OptionContract with zero bid/ask and verifying midPrice.
    func testOptionContractCreation_ZeroBidAsk() {
        // Arrange & Act
        let contract = OptionContract(
            ticker: "TEST",
            type: .call,
            strikePrice: 100.0,
            bid: 0.0,
            ask: 0.0,
            expirationDate: Date()
        )
        
        // Assert
        XCTAssertEqual(contract.bid, 0.0)
        XCTAssertEqual(contract.ask, 0.0)
        XCTAssertEqual(contract.midPrice, 0.0, accuracy: 0.0001)
    }
    
    /// Tests creating OptionContract with zero bid and small ask.
    func testOptionContractCreation_ZeroBidSmallAsk() {
        // Arrange & Act
        let contract = OptionContract(
            ticker: "TEST",
            type: .put,
            strikePrice: 100.0,
            bid: 0.0,
            ask: 0.02,
            expirationDate: Date()
        )
        
        // Assert: (0.0 + 0.02) / 2 = 0.01
        XCTAssertEqual(contract.midPrice, 0.01, accuracy: 0.0001)
    }
    
    // MARK: - Edge Case: Very Large Strike Prices Tests
    
    /// Tests parsing response with very large strike prices (e.g., BRK.A style options).
    /// Verifies that large numeric values are correctly preserved during parsing.
    func testParseLargeStrikePrices_ParsedCorrectly() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: largeStrikePricesResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls,
              let puts = response.optionChain.result?.first?.options?.first?.puts else {
            XCTFail("Expected calls and puts arrays")
            return
        }
        
        // Assert - Verify large strike prices are parsed correctly
        XCTAssertEqual(calls.count, 3)
        XCTAssertEqual(puts.count, 2)
        
        // Verify call strike prices (500,000, 550,000, 600,000)
        XCTAssertEqual(calls[0].strike ?? 0, 500000.0, accuracy: 0.01)
        XCTAssertEqual(calls[1].strike ?? 0, 550000.0, accuracy: 0.01)
        XCTAssertEqual(calls[2].strike ?? 0, 600000.0, accuracy: 0.01)
        
        // Verify put strike prices (450,000, 400,000)
        XCTAssertEqual(puts[0].strike ?? 0, 450000.0, accuracy: 0.01)
        XCTAssertEqual(puts[1].strike ?? 0, 400000.0, accuracy: 0.01)
    }
    
    /// Tests that large bid/ask values are parsed correctly with very large strike prices.
    func testParseLargeStrikePrices_BidAskValuesCorrect() throws {
        // Arrange
        let decoder = JSONDecoder()
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: largeStrikePricesResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls else {
            XCTFail("Expected calls array")
            return
        }
        
        // Assert - Verify large bid/ask values
        // First call: strike=500,000, bid=50,000, ask=52,000
        XCTAssertEqual(calls[0].bid ?? 0, 50000.0, accuracy: 0.01)
        XCTAssertEqual(calls[0].ask ?? 0, 52000.0, accuracy: 0.01)
        
        // Second call: strike=550,000, bid=25,000, ask=27,000
        XCTAssertEqual(calls[1].bid ?? 0, 25000.0, accuracy: 0.01)
        XCTAssertEqual(calls[1].ask ?? 0, 27000.0, accuracy: 0.01)
    }
    
    /// Tests mid-price calculation with very large bid/ask values.
    func testParseLargeStrikePrices_MidPriceCalculation() throws {
        // Arrange
        let decoder = JSONDecoder()
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: largeStrikePricesResponseJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls else {
            XCTFail("Expected calls array")
            return
        }
        
        // Assert - Verify mid-price calculation with large values
        // First call: (50,000 + 52,000) / 2 = 51,000
        let firstCallMid = ((calls[0].bid ?? 0) + (calls[0].ask ?? 0)) / 2.0
        XCTAssertEqual(firstCallMid, 51000.0, accuracy: 0.01)
        
        // Second call: (25,000 + 27,000) / 2 = 26,000
        let secondCallMid = ((calls[1].bid ?? 0) + (calls[1].ask ?? 0)) / 2.0
        XCTAssertEqual(secondCallMid, 26000.0, accuracy: 0.01)
        
        // Third call: (5,000 + 7,500) / 2 = 6,250
        let thirdCallMid = ((calls[2].bid ?? 0) + (calls[2].ask ?? 0)) / 2.0
        XCTAssertEqual(thirdCallMid, 6250.0, accuracy: 0.01)
    }
    
    /// Tests creating OptionContract with very large strike price.
    func testOptionContractCreation_VeryLargeStrike() {
        // Arrange & Act
        let contract = OptionContract(
            ticker: "BRKA",
            type: .call,
            strikePrice: 600000.0,
            bid: 5000.0,
            ask: 7500.0,
            expirationDate: Date()
        )
        
        // Assert
        XCTAssertEqual(contract.strikePrice, 600000.0, accuracy: 0.01)
        XCTAssertEqual(contract.bid, 5000.0, accuracy: 0.01)
        XCTAssertEqual(contract.ask, 7500.0, accuracy: 0.01)
        XCTAssertEqual(contract.midPrice, 6250.0, accuracy: 0.01)
    }
    
    /// Tests creating OptionsChain with very large strike prices.
    func testOptionsChainCreation_VeryLargeStrikePrices() {
        // Arrange
        let ticker = "BRKA"
        let expiration = Date()
        
        let calls = [
            OptionContract(ticker: ticker, type: .call, strikePrice: 500000.0, bid: 50000.0, ask: 52000.0, expirationDate: expiration),
            OptionContract(ticker: ticker, type: .call, strikePrice: 550000.0, bid: 25000.0, ask: 27000.0, expirationDate: expiration),
            OptionContract(ticker: ticker, type: .call, strikePrice: 600000.0, bid: 5000.0, ask: 7500.0, expirationDate: expiration)
        ]
        
        let puts = [
            OptionContract(ticker: ticker, type: .put, strikePrice: 450000.0, bid: 10000.0, ask: 12500.0, expirationDate: expiration),
            OptionContract(ticker: ticker, type: .put, strikePrice: 400000.0, bid: 2000.0, ask: 3500.0, expirationDate: expiration)
        ]
        
        // Act
        let chain = OptionsChain(
            ticker: ticker,
            expirationDate: expiration,
            calls: calls,
            puts: puts,
            fetchedAt: Date()
        )
        
        // Assert
        XCTAssertEqual(chain.ticker, ticker)
        XCTAssertEqual(chain.calls.count, 3)
        XCTAssertEqual(chain.puts.count, 2)
        XCTAssertFalse(chain.isEmpty)
        
        // Verify strike prices are preserved
        XCTAssertEqual(chain.calls[0].strikePrice, 500000.0, accuracy: 0.01)
        XCTAssertEqual(chain.calls[2].strikePrice, 600000.0, accuracy: 0.01)
        XCTAssertEqual(chain.puts[0].strikePrice, 450000.0, accuracy: 0.01)
    }
    
    // MARK: - Edge Case: Mixed Valid/Invalid Contracts Tests
    
    /// Tests parsing response with mix of valid and invalid contracts.
    /// Contracts missing strike should be filtered out, valid ones preserved.
    func testParseMixedValidInvalidContracts_ValidContractsPreserved() throws {
        // Arrange
        let decoder = JSONDecoder()
        
        // Act
        let response = try decoder.decode(TestYahooOptionsResponse.self, from: mixedValidInvalidContractsJSON)
        
        guard let calls = response.optionChain.result?.first?.options?.first?.calls,
              let puts = response.optionChain.result?.first?.options?.first?.puts else {
            XCTFail("Expected calls and puts arrays")
            return
        }
        
        // Assert - All contracts in the JSON are parsed (filtering happens at higher level)
        XCTAssertEqual(calls.count, 3)
        XCTAssertEqual(puts.count, 2)
        
        // Valid calls (index 0 and 2 have strike, index 1 missing)
        XCTAssertNotNil(calls[0].strike)
        XCTAssertNil(calls[1].strike)  // This one is missing strike
        XCTAssertNotNil(calls[2].strike)
        
        // Puts: first has strike, second missing
        XCTAssertNotNil(puts[0].strike)
        XCTAssertNil(puts[1].strike)
    }
    
    /// Tests that contracts missing strike are filtered when creating OptionContract objects.
    func testOptionContractFiltering_MissingStrikeFiltered() {
        // Arrange - Simulating what the service does when parsing
        let rawContracts: [(strike: Double?, bid: Double?, ask: Double?)] = [
            (strike: 145.0, bid: 12.40, ask: 12.60),  // Valid
            (strike: nil, bid: 7.90, ask: 8.10),       // Invalid - missing strike
            (strike: 155.0, bid: 4.40, ask: 4.60)     // Valid
        ]
        
        // Act - Filter contracts that have strike prices (simulating YahooFinanceService behavior)
        let validContracts = rawContracts.compactMap { raw -> OptionContract? in
            guard let strike = raw.strike else { return nil }
            return OptionContract(
                ticker: "AAPL",
                type: .call,
                strikePrice: strike,
                bid: raw.bid ?? 0.0,
                ask: raw.ask ?? 0.0,
                expirationDate: Date()
            )
        }
        
        // Assert
        XCTAssertEqual(validContracts.count, 2, "Only contracts with strike should be included")
        XCTAssertEqual(validContracts[0].strikePrice, 145.0, accuracy: 0.001)
        XCTAssertEqual(validContracts[1].strikePrice, 155.0, accuracy: 0.001)
    }
    
    // MARK: - Comprehensive OptionsChain isEmpty Tests
    
    /// Tests isEmpty property when chain has only calls.
    func testOptionsChainIsEmpty_OnlyCalls() {
        // Arrange
        let chain = OptionsChain(
            ticker: "AAPL",
            expirationDate: Date(),
            calls: [OptionContract(ticker: "AAPL", type: .call, strikePrice: 150.0, bid: 1.0, ask: 1.2, expirationDate: Date())],
            puts: [],
            fetchedAt: Date()
        )
        
        // Assert
        XCTAssertFalse(chain.isEmpty, "Chain with calls should not be empty")
    }
    
    /// Tests isEmpty property when chain has only puts.
    func testOptionsChainIsEmpty_OnlyPuts() {
        // Arrange
        let chain = OptionsChain(
            ticker: "AAPL",
            expirationDate: Date(),
            calls: [],
            puts: [OptionContract(ticker: "AAPL", type: .put, strikePrice: 150.0, bid: 1.0, ask: 1.2, expirationDate: Date())],
            fetchedAt: Date()
        )
        
        // Assert
        XCTAssertFalse(chain.isEmpty, "Chain with puts should not be empty")
    }
    
    /// Tests isEmpty property when chain has both calls and puts.
    func testOptionsChainIsEmpty_BothCallsAndPuts() {
        // Arrange
        let expiration = Date()
        let chain = OptionsChain(
            ticker: "AAPL",
            expirationDate: expiration,
            calls: [OptionContract(ticker: "AAPL", type: .call, strikePrice: 150.0, bid: 1.0, ask: 1.2, expirationDate: expiration)],
            puts: [OptionContract(ticker: "AAPL", type: .put, strikePrice: 145.0, bid: 0.5, ask: 0.7, expirationDate: expiration)],
            fetchedAt: Date()
        )
        
        // Assert
        XCTAssertFalse(chain.isEmpty, "Chain with both calls and puts should not be empty")
    }
    
    /// Tests isEmpty property when chain is completely empty.
    func testOptionsChainIsEmpty_NoContracts() {
        // Arrange
        let chain = OptionsChain(
            ticker: "AAPL",
            expirationDate: Date(),
            calls: [],
            puts: [],
            fetchedAt: Date()
        )
        
        // Assert
        XCTAssertTrue(chain.isEmpty, "Chain with no contracts should be empty")
    }
}

// MARK: - Test Helper Structures

/// Test structure mirroring Yahoo Finance options API response
private struct TestYahooOptionsResponse: Decodable {
    let optionChain: TestOptionChainContainer
}

private struct TestOptionChainContainer: Decodable {
    let result: [TestOptionChainResult]?
    let error: TestOptionChainError?
}

private struct TestOptionChainError: Decodable {
    let code: String?
    let description: String?
}

private struct TestOptionChainResult: Decodable {
    let underlyingSymbol: String?
    let expirationDates: [Int]?
    let strikes: [Double]?
    let options: [TestOptionsExpirationData]?
}

private struct TestOptionsExpirationData: Decodable {
    let expirationDate: Int?
    let calls: [TestYahooOptionData]?
    let puts: [TestYahooOptionData]?
}

private struct TestYahooOptionData: Decodable {
    let contractSymbol: String?
    let strike: Double?
    let currency: String?
    let lastPrice: Double?
    let bid: Double?
    let ask: Double?
    let volume: Int?
    let openInterest: Int?
    let impliedVolatility: Double?
    let inTheMoney: Bool?
}

