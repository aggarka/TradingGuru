# Implementation Plan: Live Options Chain Integration

## Overview

This implementation plan integrates live options chain data into the TradingGuru Weekly Option Strategy. The feature extends the existing `YahooFinanceService` to fetch real-time options data, adds expiration date calculation with US market holiday awareness, implements premium matching algorithms, and updates the UI to display options-specific fields. Implementation uses Swift following the existing MVVM architecture and includes property-based tests for all 21 correctness properties defined in the design.

## Tasks

- [x] 1. Create new data models and protocols for options chain
  - [x] 1.1 Define OptionContract model
    - Create `OptionContract` struct in `Models/` with id, ticker, type, strikePrice, bid, ask, expirationDate
    - Implement computed property `midPrice` as `(bid + ask) / 2`
    - Conform to Codable, Identifiable, Equatable
    - _Requirements: 1.3, 1.6_

  - [x] 1.2 Define OptionsChain model
    - Create `OptionsChain` struct with ticker, expirationDate, calls, puts arrays, fetchedAt timestamp
    - Implement `isEmpty` computed property
    - Add static `empty(ticker:expirationDate:)` factory method for error cases
    - _Requirements: 1.2, 1.5_

  - [x] 1.3 Define OptionsDataError enum
    - Create error cases: optionsUnavailable, noOptionsForExpiration, invalidOptionsData, networkError, invalidExpirationDate
    - Conform to Error and Equatable protocols
    - _Requirements: 1.4, 3.7_

  - [x] 1.4 Define OptionsDataService protocol in MarketDataProtocols.swift
    - Extend MarketDataService with `fetchOptionsChain(ticker:expirationDate:)` async method
    - Document protocol with requirement references
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 1.5 Define ExpirationDateCalculation protocol
    - Create protocol with `calculateDefaultExpiration(from:)`, `isValidExpirationDate(_:)`, `isMarketHoliday(_:)` methods
    - _Requirements: 2.1, 2.2, 2.6, 3.6_

  - [x] 1.6 Define PremiumMatching protocol
    - Create protocol with `findBestCallMatch(from:targetPremium:)` and `findBestPutMatch(from:targetPremium:)` methods
    - _Requirements: 4.2, 4.3, 4.4_

  - [x] 1.7 Write unit tests for OptionContract.midPrice calculation
    - Test various bid/ask combinations
    - Test edge cases (zero, very small values)
    - _Requirements: 1.6_

- [x] 2. Extend existing models with options fields
  - [x] 2.1 Extend AnalysisResult with options fields
    - Add optional properties: expirationDate, strikePrice, bidPremium, askPremium, midPremium, selectedOption
    - Update existing initializer to include new fields with defaults of nil
    - Maintain backward compatibility with existing code
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 2.2 Extend WeeklyOptionConfiguration with expirationOverride
    - Add `expirationOverride: Date?` property (session-scoped, not persisted)
    - Implement custom CodingKeys to exclude expirationOverride from persistence
    - Add `effectiveExpirationDate(using:)` method
    - _Requirements: 3.2, 3.4_

  - [x] 2.3 Extend AnalysisResultRow with options display fields
    - Add expirationDate, strikePrice, bidPremium, askPremium, midPremium formatted strings
    - Add rawExpirationDate, rawStrikePrice, rawMidPremium for sorting
    - Update `init(from:)` to populate new fields
    - _Requirements: 6.1-6.5, 6.10_

  - [x] 2.4 Extend ResultColumn enum with new columns
    - Add cases: expirationDate, strikePrice, bidPremium, askPremium, midPremium
    - _Requirements: 6.8, 6.9_

- [x] 3. Checkpoint - Models complete
  - Ensure all model tests pass, ask the user if questions arise.

- [x] 4. Implement ExpirationDateCalculator service
  - [x] 4.1 Create ExpirationDateCalculator class
    - Implement `calculateDefaultExpiration(from:)` to find next Friday
    - Handle Friday after market close case (move to next Friday)
    - Implement weekend skip logic (Saturday/Sunday → next week's Friday)
    - _Requirements: 2.1, 2.6_

  - [x] 4.2 Implement US market holiday detection
    - Implement `isMarketHoliday(_:)` for Friday holidays
    - Handle New Year's Day (Jan 1 on Friday, or Dec 31 if Jan 1 is Saturday)
    - Handle Good Friday (calculate Easter Sunday, subtract 2 days)
    - Handle Independence Day (July 4 on Friday, or July 3 if July 4 is Saturday)
    - Handle Christmas Day (Dec 25 on Friday, or Dec 24 if Dec 25 is Saturday)
    - _Requirements: 2.2, 2.3, 2.4, 2.5_

  - [x] 4.3 Implement holiday fallback logic
    - When Friday is a holiday, return Thursday
    - _Requirements: 2.2_

  - [x] 4.4 Implement isValidExpirationDate validation
    - Return true only for weekdays (Mon-Fri) that are not market holidays
    - _Requirements: 3.6_

  - [x] 4.5 Write property test for default expiration always being Friday
    - **Property 3: Default Expiration Is Always a Friday**
    - **Validates: Requirements 2.1**

  - [x] 4.6 Write property test for holiday fallback to Thursday
    - **Property 4: Holiday Fallback to Thursday**
    - **Validates: Requirements 2.2**

  - [x] 4.7 Write property test for weekend skip to next Friday
    - **Property 5: Weekend Skip to Next Friday**
    - **Validates: Requirements 2.6**

  - [x] 4.8 Write property test for valid expiration date criteria
    - **Property 6: Valid Expiration Date Criteria**
    - **Validates: Requirements 3.6**

  - [x] 4.9 Write unit tests for specific holiday dates
    - Test Good Friday 2025, July 4 on Friday, Christmas on Friday
    - Test Dec 31 when Jan 1 is Saturday
    - _Requirements: 2.3, 2.4, 2.5_

- [x] 5. Checkpoint - Expiration calculator complete
  - Ensure all expiration calculator tests pass, ask the user if questions arise.

- [x] 6. Implement PremiumMatchingAlgorithm service
  - [x] 6.1 Create PremiumMatchingAlgorithm class
    - Implement `findBestCallMatch(from:targetPremium:)` 
    - Sort by distance from target premium (ascending)
    - Apply tiebreaker: higher strike for calls
    - _Requirements: 4.2, 4.4_

  - [x] 6.2 Implement findBestPutMatch
    - Implement `findBestPutMatch(from:targetPremium:)`
    - Sort by distance from target premium (ascending)
    - Apply tiebreaker: lower strike for puts
    - _Requirements: 4.3, 4.4_

  - [x] 6.3 Write property test for premium matching minimum distance
    - **Property 8: Premium Matching Minimum Distance**
    - **Validates: Requirements 4.2**

  - [x] 6.4 Write property test for call tiebreaker (higher strike)
    - **Property 9: Premium Matching Tiebreaker for Calls**
    - **Validates: Requirements 4.4**

  - [x] 6.5 Write property test for put tiebreaker (lower strike)
    - **Property 10: Premium Matching Tiebreaker for Puts**
    - **Validates: Requirements 4.4**

- [x] 7. Checkpoint - Premium matching complete
  - Ensure all premium matching tests pass, ask the user if questions arise.

- [x] 8. Extend YahooFinanceService with options chain fetching
  - [x] 8.1 Add options API URL building
    - Add `optionsBaseURL` constant for Yahoo Finance options API
    - Implement `buildOptionsURL(ticker:expiration:)` method
    - Use Unix timestamp for expiration date query parameter
    - _Requirements: 1.1_

  - [x] 8.2 Implement fetchOptionsChain method
    - Make YahooFinanceService conform to OptionsDataService
    - Implement `fetchOptionsChain(ticker:expirationDate:)` async throws
    - Handle HTTP response validation and error cases
    - _Requirements: 1.1, 1.4_

  - [x] 8.3 Implement options response parsing
    - Create response models for Yahoo Finance options API structure
    - Parse calls and puts arrays into OptionContract objects
    - Handle empty response gracefully
    - _Requirements: 1.2, 1.3, 1.5_

  - [x] 8.4 Write property test for mid-price calculation correctness
    - **Property 1: Mid-Price Calculation Correctness**
    - **Validates: Requirements 1.6**

  - [x] 8.5 Write property test for options chain parsing completeness
    - **Property 2: Options Chain Parsing Completeness**
    - **Validates: Requirements 1.2, 1.3**

  - [x] 8.6 Write unit tests for options parsing
    - Test valid response with calls and puts
    - Test empty response handling
    - Test malformed data handling
    - _Requirements: 1.2, 1.3, 1.5_

- [x] 9. Checkpoint - Options data fetching complete
  - Ensure all options fetching tests pass, ask the user if questions arise.

- [x] 10. Implement signal generation logic in WeeklyOptionStrategy
  - [x] 10.1 Add target price calculation methods
    - Implement `calculateCallTarget(currentPrice:bestReturnPct:)` static method
    - Implement `calculatePutTarget(currentPrice:worstReturnPct:)` static method
    - _Requirements: 5.1, 5.2_

  - [x] 10.2 Implement call signal generation
    - Implement `generateCallSignal(strikePrice:callTarget:)` method
    - Return .order when strike >= callTarget, .hold otherwise
    - Handle nil strike price (return .hold)
    - _Requirements: 5.3, 5.4_

  - [x] 10.3 Implement put signal generation
    - Implement `generatePutSignal(strikePrice:putTarget:)` method
    - Return .order when strike <= putTarget, .hold otherwise
    - Handle nil strike price (return .hold)
    - _Requirements: 5.5, 5.6_

  - [x] 10.4 Write property test for target premium calculation
    - **Property 7: Target Premium Calculation**
    - **Validates: Requirements 4.1**

  - [x] 10.5 Write property test for call target calculation
    - **Property 11: Call Target Calculation**
    - **Validates: Requirements 5.1**

  - [x] 10.6 Write property test for put target calculation
    - **Property 12: Put Target Calculation**
    - **Validates: Requirements 5.2**

  - [x] 10.7 Write property test for call signal ORDER
    - **Property 13: Call Signal Generation - ORDER**
    - **Validates: Requirements 5.3**

  - [x] 10.8 Write property test for call signal HOLD
    - **Property 14: Call Signal Generation - HOLD**
    - **Validates: Requirements 5.4**

  - [x] 10.9 Write property test for put signal ORDER
    - **Property 15: Put Signal Generation - ORDER**
    - **Validates: Requirements 5.5**

  - [x] 10.10 Write property test for put signal HOLD
    - **Property 16: Put Signal Generation - HOLD**
    - **Validates: Requirements 5.6**

- [x] 11. Checkpoint - Signal generation complete
  - Ensure all signal generation tests pass, ask the user if questions arise.

- [x] 12. Integrate options chain into WeeklyOptionStrategy analysis pipeline
  - [x] 12.1 Update analyzeAsync to fetch options chain
    - Inject ExpirationDateCalculator and PremiumMatchingAlgorithm dependencies
    - Calculate effective expiration date from configuration
    - Fetch options chain for ticker and expiration
    - Handle options fetch errors with graceful degradation
    - _Requirements: 1.1, 1.4, 1.5_

  - [x] 12.2 Integrate premium matching into analysis
    - Calculate target premium from current price and PREMIUM_PCT
    - Find best call match and best put match from options chain
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 12.3 Update signal generation with options data
    - Calculate call_target and put_target from historical returns
    - Generate signals using strike price comparison
    - _Requirements: 5.1-5.6_

  - [x] 12.4 Update AnalysisResult creation with options fields
    - Populate expirationDate, strikePrice, bidPremium, askPremium, midPremium
    - Set fields to nil when options data unavailable
    - _Requirements: 6.1-6.5, 6.10_

  - [x] 12.5 Write integration test for full analysis pipeline
    - Test fetch prices → calculate returns → fetch options → generate results
    - Verify all result fields populated correctly
    - _Requirements: 1.1-1.6, 4.1-4.5, 5.1-5.6_

- [x] 13. Checkpoint - Strategy integration complete
  - Ensure all strategy integration tests pass, ask the user if questions arise.

- [x] 14. Update ResultsViewModel with new column sorting
  - [x] 14.1 Extend sorting logic for new columns
    - Add sorting cases for expirationDate, strikePrice, bidPremium, askPremium, midPremium
    - Handle nil values by treating as maximum (sort to end)
    - _Requirements: 6.8, 6.9_

  - [x] 14.2 Update AnalysisResultRow sorting extension
    - Implement comparison for rawExpirationDate, rawStrikePrice, rawMidPremium
    - _Requirements: 6.8, 6.9_

  - [x] 14.3 Write property test for strike price sorting correctness
    - **Property 17: Strike Price Sorting Correctness**
    - **Validates: Requirements 6.8**

  - [x] 14.4 Write property test for mid premium sorting correctness
    - **Property 18: Mid Premium Sorting Correctness**
    - **Validates: Requirements 6.9**

- [x] 15. Update ResultsView with new columns
  - [x] 15.1 Add new column headers to table
    - Add Expiration Date, Strike Price, Bid Premium, Ask Premium, Mid Premium headers
    - Make new headers sortable like existing columns
    - Update column order per Requirement 6.7
    - _Requirements: 6.1-6.5, 6.7, 6.8, 6.9_

  - [x] 15.2 Update ResultRowView with new column display
    - Add display cells for expirationDate (YYYY-MM-DD format)
    - Add display cells for strikePrice, bidPremium, askPremium, midPremium (currency format)
    - Display "N/A" when values are nil
    - _Requirements: 6.1-6.5, 6.10, 6.11_

  - [x] 15.3 Update accessibility labels for new columns
    - Add accessibility descriptions for options columns
    - Update row accessibility label to include options data
    - _Requirements: 6.1-6.5_

- [x] 16. Verify ONLY_ORDERS filter compatibility
  - [x] 16.1 Verify filter works with new signal logic
    - Confirm ONLY_ORDERS filter shows only ORDER signals (CALL_ORDER, PUT_ORDER)
    - Verify filter does not incorrectly exclude ORDER rows
    - _Requirements: 7.1, 7.2_

  - [x] 16.2 Write property test for ONLY_ORDERS filter completeness
    - **Property 19: ONLY_ORDERS Filter Completeness**
    - **Validates: Requirements 7.1**

  - [x] 16.3 Write property test for ONLY_ORDERS preserves all orders
    - **Property 20: ONLY_ORDERS Filter Preserves All Orders**
    - **Validates: Requirements 7.2**

  - [x] 16.4 Write property test for filter disabled shows all signals
    - **Property 21: Filter Disabled Shows All Signals**
    - **Validates: Requirements 7.3**

- [x] 17. Checkpoint - Results display complete
  - Ensure all results display tests pass, ask the user if questions arise.

- [x] 18. Create ExpirationDatePicker UI component
  - [x] 18.1 Create ExpirationDatePicker view
    - Create SwiftUI view with DatePicker bound to selectedDate
    - Add "Reset" button when custom date selected
    - Display description text (default vs custom)
    - _Requirements: 3.1, 3.3_

  - [x] 18.2 Implement date validation in picker
    - Validate selected date using ExpirationDateCalculator.isValidExpirationDate
    - Display error message for invalid dates (weekends, holidays)
    - Reject invalid date and don't update selection
    - _Requirements: 3.6, 3.7_

- [x] 19. Update AnalysisViewModel with expiration override
  - [x] 19.1 Add expirationOverride state management
    - Add `expirationOverride: Date?` property
    - Implement `setExpirationOverride(_:)` method with validation
    - Implement `clearExpirationOverride()` method
    - _Requirements: 3.2, 3.4_

  - [x] 19.2 Integrate expiration override into analysis
    - Update `runAnalysis()` to use effectiveExpirationDate
    - Pass expiration date to WeeklyOptionStrategy
    - _Requirements: 3.2_

  - [x] 19.3 Reset expiration override on app restart
    - Ensure expirationOverride is nil on ViewModel initialization
    - Session-scoped state not persisted
    - _Requirements: 3.4_

  - [x] 19.4 Write integration test for session-scoped override
    - Test set override → run analysis → verify override used
    - Test app restart simulation → verify override cleared
    - _Requirements: 3.2, 3.4_

- [x] 20. Update AnalysisView with expiration picker
  - [x] 20.1 Add ExpirationDatePicker to configuration interface
    - Add picker below existing configuration options
    - Display currently selected expiration date
    - _Requirements: 3.1, 3.3_

  - [x] 20.2 Wire picker to AnalysisViewModel
    - Connect picker selection to setExpirationOverride
    - Display validation errors from ViewModel
    - _Requirements: 3.1, 3.2, 3.7_

- [x] 21. Final integration and wiring
  - [x] 21.1 Wire all new components together
    - Inject ExpirationDateCalculator into WeeklyOptionStrategy
    - Inject PremiumMatchingAlgorithm into WeeklyOptionStrategy
    - Connect AnalysisViewModel to updated strategy
    - _Requirements: 1.1-1.6, 2.1-2.6, 3.1-3.7, 4.1-4.5, 5.1-5.6_

  - [x] 21.2 Handle graceful degradation for options errors
    - When options fetch fails, continue with N/A in options columns
    - Revert signal to premium-based logic when no options data
    - Log errors for monitoring
    - _Requirements: 1.4, 1.5, 6.10_

  - [x] 21.3 Write end-to-end integration tests
    - Test complete flow: configure expiration → run analysis → view results
    - Test error handling: network failure → graceful degradation
    - Test batch analysis with mix of successful and failed tickers
    - _Requirements: 1.1-6.11, 7.1-7.4_

- [x] 22. Final checkpoint - All tests pass
  - Ensure all unit, property, and integration tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after major feature completions
- Property tests validate the 21 universal correctness properties defined in the design
- Unit tests validate specific examples, edge cases, and component behavior
- SwiftCheck or swift-testing with custom property harness used for property-based testing
- Existing MVVM architecture maintained; new services follow protocol-oriented design
- Session-scoped expiration override resets on app restart (not persisted)
- Graceful degradation ensures existing analysis flow works when options data unavailable

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["1.4", "1.5", "1.6", "1.7"] },
    { "id": 2, "tasks": ["2.1", "2.2", "2.3", "2.4"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["4.2", "4.3", "4.4"] },
    { "id": 5, "tasks": ["4.5", "4.6", "4.7", "4.8", "4.9"] },
    { "id": 6, "tasks": ["6.1"] },
    { "id": 7, "tasks": ["6.2"] },
    { "id": 8, "tasks": ["6.3", "6.4", "6.5"] },
    { "id": 9, "tasks": ["8.1"] },
    { "id": 10, "tasks": ["8.2", "8.3"] },
    { "id": 11, "tasks": ["8.4", "8.5", "8.6"] },
    { "id": 12, "tasks": ["10.1"] },
    { "id": 13, "tasks": ["10.2", "10.3"] },
    { "id": 14, "tasks": ["10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "10.10"] },
    { "id": 15, "tasks": ["12.1"] },
    { "id": 16, "tasks": ["12.2", "12.3"] },
    { "id": 17, "tasks": ["12.4"] },
    { "id": 18, "tasks": ["12.5"] },
    { "id": 19, "tasks": ["14.1", "14.2"] },
    { "id": 20, "tasks": ["14.3", "14.4"] },
    { "id": 21, "tasks": ["15.1"] },
    { "id": 22, "tasks": ["15.2", "15.3"] },
    { "id": 23, "tasks": ["16.1"] },
    { "id": 24, "tasks": ["16.2", "16.3", "16.4"] },
    { "id": 25, "tasks": ["18.1"] },
    { "id": 26, "tasks": ["18.2"] },
    { "id": 27, "tasks": ["19.1"] },
    { "id": 28, "tasks": ["19.2", "19.3"] },
    { "id": 29, "tasks": ["19.4"] },
    { "id": 30, "tasks": ["20.1"] },
    { "id": 31, "tasks": ["20.2"] },
    { "id": 32, "tasks": ["21.1"] },
    { "id": 33, "tasks": ["21.2"] },
    { "id": 34, "tasks": ["21.3"] }
  ]
}
```
