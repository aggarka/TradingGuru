//
//  PremiumMatchingAlgorithmTests.swift
//  TradingGuruTests
//
//  Property-based tests for Premium Matching Algorithm.
//  Tests the correctness properties 8, 9, and 10 defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Test Helpers

/// Helper to create option contracts for testing
private func makeCallOption(
    strikePrice: Double,
    bid: Double,
    ask: Double
) -> OptionContract {
    OptionContract(
        ticker: "TEST",
        type: .call,
        strikePrice: strikePrice,
        bid: bid,
        ask: ask,
        expirationDate: Date()
    )
}

private func makePutOption(
    strikePrice: Double,
    bid: Double,
    ask: Double
) -> OptionContract {
    OptionContract(
        ticker: "TEST",
        type: .put,
        strikePrice: strikePrice,
        bid: bid,
        ask: ask,
        expirationDate: Date()
    )
}

// MARK: - Property 8: Premium Matching Minimum Distance
// **Validates: Requirements 4.2**
//
// *For any* non-empty set of call options and target premium `t`, the selected
// call option SHALL have the minimum `|midPrice - t|` among all options.

@Suite("Property 8: Premium Matching Minimum Distance - Validates Requirements 4.2")
struct PremiumMatchingMinimumDistanceTests {
    
    let algorithm = PremiumMatchingAlgorithm()
    
    // MARK: - Test Data Generation
    
    /// Generate test cases with options and target premiums
    static let testCases: [(options: [OptionContract], targetPremium: Double)] = [
        // Case 1: Simple case with clear minimum
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 1.0, ask: 1.2),  // midPrice = 1.1
                makeCallOption(strikePrice: 105, bid: 2.0, ask: 2.2),  // midPrice = 2.1
                makeCallOption(strikePrice: 110, bid: 3.0, ask: 3.2)   // midPrice = 3.1
            ],
            targetPremium: 1.0  // Closest to 1.1
        ),
        // Case 2: Target in the middle
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 0.8, ask: 1.0),  // midPrice = 0.9
                makeCallOption(strikePrice: 105, bid: 1.9, ask: 2.1),  // midPrice = 2.0
                makeCallOption(strikePrice: 110, bid: 3.8, ask: 4.0)   // midPrice = 3.9
            ],
            targetPremium: 2.0  // Exactly matches 2.0
        ),
        // Case 3: Target premium below all options
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 2.0, ask: 2.2),  // midPrice = 2.1
                makeCallOption(strikePrice: 105, bid: 3.0, ask: 3.2),  // midPrice = 3.1
                makeCallOption(strikePrice: 110, bid: 4.0, ask: 4.2)   // midPrice = 4.1
            ],
            targetPremium: 0.5  // Below all, closest to 2.1
        ),
        // Case 4: Target premium above all options
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 0.5, ask: 0.7),  // midPrice = 0.6
                makeCallOption(strikePrice: 105, bid: 1.0, ask: 1.2),  // midPrice = 1.1
                makeCallOption(strikePrice: 110, bid: 1.5, ask: 1.7)   // midPrice = 1.6
            ],
            targetPremium: 5.0  // Above all, closest to 1.6
        ),
        // Case 5: Single option
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 1.5, ask: 1.7)   // midPrice = 1.6
            ],
            targetPremium: 2.0
        )
    ]
    
    // MARK: - Property Tests
    
    @Test("Property: Selected option has minimum distance from target premium",
          arguments: testCases)
    func testSelectedOptionHasMinimumDistance(
        options: [OptionContract],
        targetPremium: Double
    ) {
        // Act
        let selectedOption = algorithm.findBestCallMatch(from: options, targetPremium: targetPremium)
        
        // Assert: Selection should exist for non-empty options
        guard let selected = selectedOption else {
            Issue.record("Expected a selection for non-empty options")
            return
        }
        
        let selectedDistance = abs(selected.midPrice - targetPremium)
        
        // Verify no other option has a smaller distance
        for option in options {
            let optionDistance = abs(option.midPrice - targetPremium)
            #expect(selectedDistance <= optionDistance + 0.0001,
                    "Selected option distance (\(selectedDistance)) should be <= option distance (\(optionDistance))")
        }
    }
    
    @Test("Property: Put option selection also has minimum distance",
          arguments: [
            ([makePutOption(strikePrice: 90, bid: 1.0, ask: 1.2),
              makePutOption(strikePrice: 85, bid: 2.0, ask: 2.2),
              makePutOption(strikePrice: 80, bid: 3.0, ask: 3.2)], 2.0),
            ([makePutOption(strikePrice: 95, bid: 0.5, ask: 0.7),
              makePutOption(strikePrice: 90, bid: 1.4, ask: 1.6)], 1.0)
          ])
    func testPutOptionMinimumDistance(
        options: [OptionContract],
        targetPremium: Double
    ) {
        let selected = algorithm.findBestPutMatch(from: options, targetPremium: targetPremium)
        
        guard let selected = selected else {
            Issue.record("Expected a selection for non-empty options")
            return
        }
        
        let selectedDistance = abs(selected.midPrice - targetPremium)
        
        for option in options {
            let optionDistance = abs(option.midPrice - targetPremium)
            #expect(selectedDistance <= optionDistance + 0.0001,
                    "Selected put distance (\(selectedDistance)) should be <= option distance (\(optionDistance))")
        }
    }
    
    @Test("Property: Empty options returns nil")
    func testEmptyOptionsReturnsNil() {
        let emptyOptions: [OptionContract] = []
        
        let callResult = algorithm.findBestCallMatch(from: emptyOptions, targetPremium: 1.0)
        let putResult = algorithm.findBestPutMatch(from: emptyOptions, targetPremium: 1.0)
        
        #expect(callResult == nil, "Empty call options should return nil")
        #expect(putResult == nil, "Empty put options should return nil")
    }
    
    @Test("Property: Exact match is selected")
    func testExactMatchIsSelected() {
        let options = [
            makeCallOption(strikePrice: 100, bid: 0.9, ask: 1.1),  // midPrice = 1.0
            makeCallOption(strikePrice: 105, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makeCallOption(strikePrice: 110, bid: 2.9, ask: 3.1)   // midPrice = 3.0
        ]
        let targetPremium = 2.0  // Exact match with second option
        
        let selected = algorithm.findBestCallMatch(from: options, targetPremium: targetPremium)
        
        #expect(selected != nil)
        #expect(abs(selected!.midPrice - targetPremium) < 0.0001,
                "Exact match should be selected")
    }
}

// MARK: - Property 9: Premium Matching Tiebreaker for Calls
// **Validates: Requirements 4.4**
//
// *For any* set of call options where multiple options have the same distance
// from the target premium, the selected option SHALL have the highest strike
// price among tied options.

@Suite("Property 9: Call Tiebreaker (Higher Strike) - Validates Requirements 4.4")
struct CallTiebreakerHigherStrikeTests {
    
    let algorithm = PremiumMatchingAlgorithm()
    
    // MARK: - Test Data Generation
    
    /// Generate test cases with tied premiums
    static let tiebreakerTestCases: [(options: [OptionContract], targetPremium: Double, expectedStrike: Double)] = [
        // Case 1: Two options with same midPrice, different strikes
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 1.9, ask: 2.1),  // midPrice = 2.0
                makeCallOption(strikePrice: 110, bid: 1.9, ask: 2.1)   // midPrice = 2.0
            ],
            targetPremium: 2.0,
            expectedStrike: 110  // Higher strike wins
        ),
        // Case 2: Three options with same distance from target
        (
            options: [
                makeCallOption(strikePrice: 95, bid: 1.4, ask: 1.6),   // midPrice = 1.5
                makeCallOption(strikePrice: 100, bid: 1.4, ask: 1.6),  // midPrice = 1.5
                makeCallOption(strikePrice: 105, bid: 1.4, ask: 1.6)   // midPrice = 1.5
            ],
            targetPremium: 1.5,
            expectedStrike: 105  // Highest strike wins
        ),
        // Case 3: Tied distance (equidistant from target)
        (
            options: [
                makeCallOption(strikePrice: 100, bid: 0.9, ask: 1.1),  // midPrice = 1.0, dist = 0.5
                makeCallOption(strikePrice: 105, bid: 1.9, ask: 2.1)   // midPrice = 2.0, dist = 0.5
            ],
            targetPremium: 1.5,
            expectedStrike: 105  // Higher strike wins on tie
        ),
        // Case 4: Multiple groups, tied in closest group
        (
            options: [
                makeCallOption(strikePrice: 90, bid: 0.9, ask: 1.1),   // midPrice = 1.0
                makeCallOption(strikePrice: 100, bid: 1.9, ask: 2.1),  // midPrice = 2.0
                makeCallOption(strikePrice: 110, bid: 1.9, ask: 2.1),  // midPrice = 2.0
                makeCallOption(strikePrice: 120, bid: 4.9, ask: 5.1)   // midPrice = 5.0
            ],
            targetPremium: 2.0,
            expectedStrike: 110  // Tie at 2.0, higher strike wins
        ),
        // Case 5: Five options with same premium
        (
            options: [
                makeCallOption(strikePrice: 80, bid: 2.4, ask: 2.6),
                makeCallOption(strikePrice: 90, bid: 2.4, ask: 2.6),
                makeCallOption(strikePrice: 100, bid: 2.4, ask: 2.6),
                makeCallOption(strikePrice: 110, bid: 2.4, ask: 2.6),
                makeCallOption(strikePrice: 120, bid: 2.4, ask: 2.6)
            ],
            targetPremium: 2.5,
            expectedStrike: 120  // Highest strike wins
        )
    ]
    
    // MARK: - Property Tests
    
    @Test("Property: Call tiebreaker selects highest strike among tied options",
          arguments: tiebreakerTestCases)
    func testCallTiebreakerSelectsHighestStrike(
        options: [OptionContract],
        targetPremium: Double,
        expectedStrike: Double
    ) {
        // Act
        let selected = algorithm.findBestCallMatch(from: options, targetPremium: targetPremium)
        
        // Assert
        guard let selected = selected else {
            Issue.record("Expected a selection for non-empty options")
            return
        }
        
        #expect(abs(selected.strikePrice - expectedStrike) < 0.0001,
                "Expected strike \(expectedStrike), got \(selected.strikePrice)")
    }
    
    @Test("Property: Among tied options, no higher strike exists")
    func testNoHigherStrikeAmongTied() {
        let options = [
            makeCallOption(strikePrice: 100, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makeCallOption(strikePrice: 105, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makeCallOption(strikePrice: 110, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makeCallOption(strikePrice: 115, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makeCallOption(strikePrice: 120, bid: 1.9, ask: 2.1)   // midPrice = 2.0
        ]
        let targetPremium = 2.0
        
        let selected = algorithm.findBestCallMatch(from: options, targetPremium: targetPremium)
        
        guard let selected = selected else {
            Issue.record("Expected a selection")
            return
        }
        
        let selectedDistance = abs(selected.midPrice - targetPremium)
        
        // Verify no tied option has a higher strike
        for option in options {
            let optionDistance = abs(option.midPrice - targetPremium)
            if abs(optionDistance - selectedDistance) < 0.0001 {
                // This option is tied in distance
                #expect(option.strikePrice <= selected.strikePrice,
                        "No tied option should have higher strike than selected")
            }
        }
    }
    
    @Test("Property: Tiebreaker only applies when distances are equal")
    func testTiebreakerOnlyAppliesWhenDistancesEqual() {
        // Option with lower strike but closer premium should win
        let options = [
            makeCallOption(strikePrice: 120, bid: 2.9, ask: 3.1),  // midPrice = 3.0, dist = 1.0
            makeCallOption(strikePrice: 100, bid: 1.9, ask: 2.1)   // midPrice = 2.0, dist = 0.0
        ]
        let targetPremium = 2.0
        
        let selected = algorithm.findBestCallMatch(from: options, targetPremium: targetPremium)
        
        #expect(selected != nil)
        #expect(abs(selected!.strikePrice - 100) < 0.0001,
                "Closer premium should win over higher strike")
    }
}

// MARK: - Property 10: Premium Matching Tiebreaker for Puts
// **Validates: Requirements 4.4**
//
// *For any* set of put options where multiple options have the same distance
// from the target premium, the selected option SHALL have the lowest strike
// price among tied options.

@Suite("Property 10: Put Tiebreaker (Lower Strike) - Validates Requirements 4.4")
struct PutTiebreakerLowerStrikeTests {
    
    let algorithm = PremiumMatchingAlgorithm()
    
    // MARK: - Test Data Generation
    
    /// Generate test cases with tied premiums for puts
    static let tiebreakerTestCases: [(options: [OptionContract], targetPremium: Double, expectedStrike: Double)] = [
        // Case 1: Two options with same midPrice, different strikes
        (
            options: [
                makePutOption(strikePrice: 100, bid: 1.9, ask: 2.1),  // midPrice = 2.0
                makePutOption(strikePrice: 90, bid: 1.9, ask: 2.1)    // midPrice = 2.0
            ],
            targetPremium: 2.0,
            expectedStrike: 90  // Lower strike wins
        ),
        // Case 2: Three options with same distance from target
        (
            options: [
                makePutOption(strikePrice: 105, bid: 1.4, ask: 1.6),  // midPrice = 1.5
                makePutOption(strikePrice: 100, bid: 1.4, ask: 1.6),  // midPrice = 1.5
                makePutOption(strikePrice: 95, bid: 1.4, ask: 1.6)    // midPrice = 1.5
            ],
            targetPremium: 1.5,
            expectedStrike: 95  // Lowest strike wins
        ),
        // Case 3: Tied distance (equidistant from target)
        (
            options: [
                makePutOption(strikePrice: 100, bid: 0.9, ask: 1.1),  // midPrice = 1.0, dist = 0.5
                makePutOption(strikePrice: 90, bid: 1.9, ask: 2.1)    // midPrice = 2.0, dist = 0.5
            ],
            targetPremium: 1.5,
            expectedStrike: 90  // Lower strike wins on tie
        ),
        // Case 4: Multiple groups, tied in closest group
        (
            options: [
                makePutOption(strikePrice: 110, bid: 0.9, ask: 1.1),  // midPrice = 1.0
                makePutOption(strikePrice: 100, bid: 1.9, ask: 2.1),  // midPrice = 2.0
                makePutOption(strikePrice: 90, bid: 1.9, ask: 2.1),   // midPrice = 2.0
                makePutOption(strikePrice: 80, bid: 4.9, ask: 5.1)    // midPrice = 5.0
            ],
            targetPremium: 2.0,
            expectedStrike: 90  // Tie at 2.0, lower strike wins
        ),
        // Case 5: Five options with same premium
        (
            options: [
                makePutOption(strikePrice: 120, bid: 2.4, ask: 2.6),
                makePutOption(strikePrice: 110, bid: 2.4, ask: 2.6),
                makePutOption(strikePrice: 100, bid: 2.4, ask: 2.6),
                makePutOption(strikePrice: 90, bid: 2.4, ask: 2.6),
                makePutOption(strikePrice: 80, bid: 2.4, ask: 2.6)
            ],
            targetPremium: 2.5,
            expectedStrike: 80  // Lowest strike wins
        )
    ]
    
    // MARK: - Property Tests
    
    @Test("Property: Put tiebreaker selects lowest strike among tied options",
          arguments: tiebreakerTestCases)
    func testPutTiebreakerSelectsLowestStrike(
        options: [OptionContract],
        targetPremium: Double,
        expectedStrike: Double
    ) {
        // Act
        let selected = algorithm.findBestPutMatch(from: options, targetPremium: targetPremium)
        
        // Assert
        guard let selected = selected else {
            Issue.record("Expected a selection for non-empty options")
            return
        }
        
        #expect(abs(selected.strikePrice - expectedStrike) < 0.0001,
                "Expected strike \(expectedStrike), got \(selected.strikePrice)")
    }
    
    @Test("Property: Among tied put options, no lower strike exists")
    func testNoLowerStrikeAmongTied() {
        let options = [
            makePutOption(strikePrice: 120, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makePutOption(strikePrice: 110, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makePutOption(strikePrice: 100, bid: 1.9, ask: 2.1),  // midPrice = 2.0
            makePutOption(strikePrice: 90, bid: 1.9, ask: 2.1),   // midPrice = 2.0
            makePutOption(strikePrice: 80, bid: 1.9, ask: 2.1)    // midPrice = 2.0
        ]
        let targetPremium = 2.0
        
        let selected = algorithm.findBestPutMatch(from: options, targetPremium: targetPremium)
        
        guard let selected = selected else {
            Issue.record("Expected a selection")
            return
        }
        
        let selectedDistance = abs(selected.midPrice - targetPremium)
        
        // Verify no tied option has a lower strike
        for option in options {
            let optionDistance = abs(option.midPrice - targetPremium)
            if abs(optionDistance - selectedDistance) < 0.0001 {
                // This option is tied in distance
                #expect(option.strikePrice >= selected.strikePrice,
                        "No tied option should have lower strike than selected")
            }
        }
    }
    
    @Test("Property: Put tiebreaker only applies when distances are equal")
    func testPutTiebreakerOnlyAppliesWhenDistancesEqual() {
        // Option with higher strike but closer premium should win
        let options = [
            makePutOption(strikePrice: 80, bid: 2.9, ask: 3.1),   // midPrice = 3.0, dist = 1.0
            makePutOption(strikePrice: 100, bid: 1.9, ask: 2.1)   // midPrice = 2.0, dist = 0.0
        ]
        let targetPremium = 2.0
        
        let selected = algorithm.findBestPutMatch(from: options, targetPremium: targetPremium)
        
        #expect(selected != nil)
        #expect(abs(selected!.strikePrice - 100) < 0.0001,
                "Closer premium should win over lower strike")
    }
    
    @Test("Property: Opposite tiebreaker behavior for calls vs puts")
    func testOppositeBreakingBehavior() {
        // Same tied options, but call should pick higher strike, put should pick lower
        let callOptions = [
            makeCallOption(strikePrice: 90, bid: 1.9, ask: 2.1),
            makeCallOption(strikePrice: 100, bid: 1.9, ask: 2.1),
            makeCallOption(strikePrice: 110, bid: 1.9, ask: 2.1)
        ]
        
        let putOptions = [
            makePutOption(strikePrice: 90, bid: 1.9, ask: 2.1),
            makePutOption(strikePrice: 100, bid: 1.9, ask: 2.1),
            makePutOption(strikePrice: 110, bid: 1.9, ask: 2.1)
        ]
        
        let targetPremium = 2.0
        
        let selectedCall = algorithm.findBestCallMatch(from: callOptions, targetPremium: targetPremium)
        let selectedPut = algorithm.findBestPutMatch(from: putOptions, targetPremium: targetPremium)
        
        #expect(selectedCall != nil && selectedPut != nil)
        #expect(abs(selectedCall!.strikePrice - 110) < 0.0001,
                "Call should select highest strike (110)")
        #expect(abs(selectedPut!.strikePrice - 90) < 0.0001,
                "Put should select lowest strike (90)")
    }
}
