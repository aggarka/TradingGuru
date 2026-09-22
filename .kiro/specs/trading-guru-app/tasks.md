# Implementation Plan: TradingGuru iOS App

## Overview

This implementation plan covers the TradingGuru iOS stock trading analysis application built with SwiftUI. The app follows MVVM architecture with a Repository layer for data access, Protocol-oriented strategy design for extensibility, and a backend service for scheduled analysis and email notifications. Implementation uses Swift for the iOS client and includes property-based tests for all 19 correctness properties defined in the design.

## Tasks

- [x] 1. Set up project foundation and core architecture
  - [x] 1.1 Create directory structure for MVVM architecture
    - Create folders: Models/, Views/, ViewModels/, Services/, Repositories/, Utilities/, Protocols/
    - Add TradingGuruTests/ and TradingGuruUITests/ test target directories
    - Set up SwiftCheck package dependency for property-based testing
    - _Requirements: 3.5 (common strategy interface for extensibility)_

  - [x] 1.2 Define core domain models
    - Implement User, UserSettings, Watchlist, StrategyConfiguration models
    - Implement PricePoint, AnalysisResult, OpportunityType, Signal models
    - Implement WeeklyOptionConfiguration with validation and defaults
    - Add ConfigValue enum for flexible parameter storage
    - _Requirements: 2.1, 4.1, 4.8, 6.1_

  - [x] 1.3 Define protocol interfaces for services
    - Create AuthenticationProvider and AuthenticationService protocols
    - Create WatchlistRepository and WatchlistValidation protocols
    - Create TradingStrategy and StrategyConfigurationSchema protocols
    - Create MarketDataService protocol for Yahoo Finance integration
    - Create ResultsDisplay protocol for results presentation
    - _Requirements: 1.1-1.10, 2.1-2.9, 3.5, 5.1-5.7_

  - [x] 1.4 Write unit tests for domain models
    - Test User and UserSettings initialization and encoding/decoding
    - Test Watchlist constraints (maxSymbols = 50)
    - Test WeeklyOptionConfiguration defaults and validation
    - _Requirements: 2.5, 4.8_

- [x] 2. Implement Authentication Module
  - [x] 2.1 Create AuthenticationView UI
    - Display Google Sign-In, Apple Sign-In, and Passkey buttons
    - Add loading indicator during authentication
    - Display error messages for failure categories
    - _Requirements: 1.1, 1.6, 1.7_

  - [x] 2.2 Implement AuthenticationService
    - Create concrete AuthenticationService with session management
    - Implement 30-day session expiration tracking
    - Implement sign-in flow with 60-second timeout
    - Implement sign-out with session clearing
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.7, 1.9, 1.10_

  - [x] 2.3 Implement Google OAuth provider
    - Integrate Google Sign-In SDK
    - Handle OAuth credential exchange
    - Implement error handling for network/provider issues
    - _Requirements: 1.2, 1.6_

  - [x] 2.4 Implement Apple Sign-In provider
    - Integrate Apple Authentication Services
    - Handle credential exchange and token storage
    - Implement error handling for authentication failures
    - _Requirements: 1.3, 1.6_

  - [x] 2.5 Implement Passkey/WebAuthn provider
    - Integrate Passkey authentication framework
    - Handle credential creation and assertion
    - Implement error handling for unavailable provider
    - _Requirements: 1.4, 1.6_

  - [x] 2.6 Implement AuthViewModel
    - Connect AuthenticationView to AuthenticationService
    - Handle authentication state transitions
    - Manage profile creation/retrieval after successful auth
    - _Requirements: 1.5, 1.8_

  - [x] 2.7 Write unit tests for authentication flows
    - Test session expiration logic
    - Test timeout handling (60 seconds)
    - Test error message display for each failure type
    - _Requirements: 1.6, 1.7, 1.9_

- [x] 3. Checkpoint - Authentication complete
  - Ensure all authentication tests pass, ask the user if questions arise.

- [x] 4. Implement Watchlist Module
  - [x] 4.1 Create WatchlistView UI
    - Display list of ticker symbols with delete option
    - Add text field for new symbol entry with add button
    - Display loading indicator while retrieving data
    - Show empty state message when watchlist is empty
    - Display error messages for validation failures
    - _Requirements: 2.1, 2.7, 2.8, 2.9_

  - [x] 4.2 Implement WatchlistRepository
    - Create Firestore-backed WatchlistRepository implementation
    - Implement getWatchlist, addSymbol, removeSymbol operations
    - Handle database unavailability with local caching
    - _Requirements: 2.1, 2.2, 2.6, 2.9, 7.1, 7.2_

  - [x] 4.3 Implement WatchlistValidation service
    - Validate ticker symbol format (1-5 uppercase letters, regex: ^[A-Z]{1,5}$)
    - Check for duplicate symbols in watchlist
    - Enforce 50-symbol limit
    - _Requirements: 2.2, 2.3, 2.4, 2.5_

  - [x] 4.4 Implement WatchlistViewModel
    - Connect WatchlistView to WatchlistRepository and validation
    - Handle add/remove operations with UI feedback
    - Manage loading and error states
    - _Requirements: 2.1-2.9_

  - [x] 4.5 Write property test for valid ticker symbol acceptance
    - **Property 1: Valid Ticker Symbol Acceptance**
    - **Validates: Requirements 2.2**

  - [x] 4.6 Write property test for invalid ticker symbol rejection
    - **Property 2: Invalid Ticker Symbol Rejection**
    - **Validates: Requirements 2.3**

  - [x] 4.7 Write property test for duplicate symbol prevention
    - **Property 3: Duplicate Symbol Prevention**
    - **Validates: Requirements 2.4**

  - [x] 4.8 Write property test for symbol removal
    - **Property 4: Symbol Removal**
    - **Validates: Requirements 2.6**

- [x] 5. Checkpoint - Watchlist complete
  - Ensure all watchlist tests pass, ask the user if questions arise.

- [x] 6. Implement Strategy Framework and Configuration
  - [x] 6.1 Create strategy selection UI
    - Display strategy dropdown with placeholder prompt
    - Show Weekly Option Strategy as available option
    - Disable run analysis button when no strategy selected
    - Display configuration interface on strategy selection
    - _Requirements: 3.1, 3.2, 3.3, 3.6_

  - [x] 6.2 Implement TradingStrategy protocol and registration
    - Create strategy registry for extensible architecture
    - Enable new strategies to be added without modifying existing code
    - Handle configuration interface load failures
    - _Requirements: 3.4, 3.5_

  - [x] 6.3 Create WeeklyOptionStrategy configuration UI
    - Display WINDOW_DAYS picker with options 1, 5, 30
    - Display LOOKBACK_DAYS picker with options 30, 60, 90, 180, 360
    - Display PREMIUM_PCT numeric input (0.1% to 5.0%, 0.1% increments)
    - Display ONLY_ORDERS toggle switch
    - Show confirmation indicator on successful save
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 6.4 Implement ConfigurationRepository
    - Create Firestore-backed configuration storage
    - Implement save with confirmation feedback
    - Implement load with default fallback
    - Handle save/load failures with appropriate error messages
    - _Requirements: 4.6, 4.7, 4.8, 4.9, 4.10_

  - [x] 6.5 Implement configuration validation
    - Validate PREMIUM_PCT range (0.1% to 5.0%)
    - Reject values outside valid range with error message
    - Retain previous value on validation failure
    - _Requirements: 4.11_

  - [x] 6.6 Implement AnalysisViewModel
    - Connect strategy selection and configuration UIs
    - Manage configuration state and persistence
    - Handle validation errors and display feedback
    - _Requirements: 3.1-3.6, 4.1-4.11_

  - [x] 6.7 Write property test for premium percentage valid range
    - **Property 5: Premium Percentage Valid Range Acceptance**
    - **Validates: Requirements 4.4**

  - [x] 6.8 Write property test for premium percentage invalid range
    - **Property 6: Premium Percentage Invalid Range Rejection**
    - **Validates: Requirements 4.11**

  - [x] 6.9 Write property test for configuration persistence round trip
    - **Property 7: Configuration Persistence Round Trip**
    - **Validates: Requirements 4.6, 4.7**

- [x] 7. Checkpoint - Strategy framework complete
  - Ensure all strategy configuration tests pass, ask the user if questions arise.

- [x] 8. Implement Weekly Option Strategy Execution
  - [x] 8.1 Implement YahooFinanceService
    - Fetch historical closing prices for configured LOOKBACK_DAYS
    - Fetch next earnings date for each ticker
    - Handle API errors per ticker with continuation
    - _Requirements: 5.1, 6.8_

  - [x] 8.2 Implement rolling window return calculation
    - Calculate percentage change over WINDOW_DAYS period
    - Process each trading day in the lookback period
    - Handle insufficient data scenarios
    - _Requirements: 5.2, 5.6_

  - [x] 8.3 Implement CALL/PUT opportunity identification
    - Identify best return window as CALL opportunity (maximum return)
    - Identify worst return window as PUT opportunity (minimum return)
    - Compute target price: target = current × (1 + return/100), rounded to 2 decimals
    - _Requirements: 5.3, 5.4_

  - [x] 8.4 Implement WeeklyOptionStrategy class
    - Implement TradingStrategy protocol
    - Execute complete analysis pipeline for each ticker
    - Generate AnalysisResult objects with all fields
    - _Requirements: 5.1-5.7_

  - [x] 8.5 Implement analysis execution UI
    - Display loading indicator with progress (n/total tickers)
    - Show error indicators for failed tickers
    - Handle insufficient data messages per ticker
    - _Requirements: 5.5, 5.6, 5.7_

  - [x] 8.6 Write property test for rolling window return calculation
    - **Property 8: Rolling Window Return Calculation**
    - **Validates: Requirements 5.2**

  - [x] 8.7 Write property test for CALL/PUT opportunity identification
    - **Property 9: CALL/PUT Opportunity Identification**
    - **Validates: Requirements 5.3**

  - [x] 8.8 Write property test for target price calculation
    - **Property 10: Target Price Calculation**
    - **Validates: Requirements 5.4**

  - [x] 8.9 Write property test for CALL/PUT return sign convention
    - **Property 11: CALL/PUT Return Sign Convention**
    - **Validates: Requirements 6.2**

- [x] 9. Checkpoint - Strategy execution complete
  - Ensure all strategy execution tests pass, ask the user if questions arise.

- [x] 10. Implement Results Display Module
  - [x] 10.1 Create ResultsView UI with table layout
    - Display columns: Ticker, Type, Return %, Current Price, Target Price, Signal, Next Earnings Date
    - Format Return % to 2 decimal places with % symbol
    - Format prices as currency with 2 decimal places
    - Format dates as YYYY-MM-DD, display "N/A" for missing dates
    - _Requirements: 6.1, 6.8_

  - [x] 10.2 Implement visual indicators for results
    - Highlight ORDER signal rows with distinct background color
    - Display Next Earnings Date in red when <= option expiration date
    - Show CALL with positive return, PUT with negative return
    - _Requirements: 6.2, 6.3, 6.4_

  - [x] 10.3 Implement results sorting functionality
    - Enable sorting by any column via header tap
    - Set initial sort to Return Percentage descending
    - Toggle sort direction on same column tap
    - _Requirements: 6.5, 6.6_

  - [x] 10.4 Implement ResultsViewModel
    - Manage results array and sort state
    - Connect to ResultsRepository for persistence
    - Handle empty state display
    - _Requirements: 6.1-6.8_

  - [x] 10.5 Write property test for earnings risk indicator
    - **Property 12: Earnings Risk Indicator**
    - **Validates: Requirements 6.4**

  - [x] 10.6 Write property test for results sorting correctness
    - **Property 13: Results Sorting Correctness**
    - **Validates: Requirements 6.5**

  - [x] 10.7 Write property test for sort direction toggle
    - **Property 14: Sort Direction Toggle**
    - **Validates: Requirements 6.6**

- [x] 11. Checkpoint - Results display complete
  - Ensure all results display tests pass, ask the user if questions arise.

- [x] 12. Implement Data Persistence and Sync
  - [x] 12.1 Implement cloud database integration with Firestore
    - Store user profiles, watchlists, configurations in Firestore
    - Implement real-time sync listeners
    - Persist changes within 5 seconds of modification
    - _Requirements: 7.1, 7.2_

  - [x] 12.2 Implement cross-device sync and conflict resolution
    - Retrieve data on new device sign-in before displaying home screen
    - Resolve conflicts using most recent timestamp
    - _Requirements: 7.3, 7.4_

  - [x] 12.3 Implement offline support with local caching
    - Cache data locally for offline access
    - Display offline status indicator when network unavailable
    - Show cached data when offline
    - _Requirements: 7.5_

  - [x] 12.4 Implement retry logic for database operations
    - Retry failed operations up to 3 times
    - Display error message after 3 failures
    - Suggest checking network connectivity
    - _Requirements: 7.6, 7.7_

  - [x] 12.5 Write property test for conflict resolution by timestamp
    - **Property 15: Conflict Resolution by Timestamp**
    - **Validates: Requirements 7.4**

- [x] 13. Checkpoint - Data persistence complete
  - Ensure all data persistence tests pass, ask the user if questions arise.

- [x] 14. Implement Backend Scheduled Analysis Service
  - [x] 14.1 Set up backend service infrastructure
    - Create Cloud Functions project for scheduled tasks
    - Configure Cloud Scheduler for 7 daily PST times (6:30, 6:45, 7:00, 9:00, 11:00, 12:30, 12:45)
    - Set up Firestore access from backend
    - _Requirements: 8.1_

  - [x] 14.2 Implement scheduled analysis execution
    - Query users with scheduledAnalysisEnabled=true AND watchlist.count > 0
    - Execute strategy analysis for each qualifying user
    - Store results with timestamp and source="scheduled"
    - _Requirements: 8.2, 8.3_

  - [x] 14.3 Implement scheduled analysis error handling
    - Log failures for monitoring
    - Retry once after 2-minute delay on data retrieval errors
    - Continue processing other users on individual failures
    - _Requirements: 8.7_

  - [x] 14.4 Implement iOS app integration with scheduled results
    - Auto-refresh results when app is open during scheduled completion
    - Display latest scheduled results on app open
    - Show "Last updated: [time] PST" above results table
    - _Requirements: 8.4, 8.5, 8.6_

  - [x] 14.5 Add settings toggle for scheduled analysis
    - Add enable/disable toggle in settings
    - Default to enabled for new users
    - Persist preference to database
    - _Requirements: 8.8_

  - [x] 14.6 Write property test for scheduled analysis user filtering
    - **Property 16: Scheduled Analysis User Filtering**
    - **Validates: Requirements 8.2**

- [x] 15. Checkpoint - Scheduled analysis complete
  - Ensure all scheduled analysis tests pass, ask the user if questions arise.

- [x] 16. Implement Email Notification Service
  - [x] 16.1 Create email settings UI
    - Add email address input field in settings
    - Validate email format before saving
    - Display error message for invalid format
    - Add email notifications enable/disable toggle
    - _Requirements: 9.1, 9.2, 9.10_

  - [x] 16.2 Implement email template generation
    - Generate subject line: "TradingGuru Analysis Results - [Date] [Time] PST"
    - Generate HTML table with all result columns
    - Highlight ORDER rows with distinct background color
    - Display earnings dates in red when hasEarningsRisk=true
    - Include summary with CALL and PUT counts
    - _Requirements: 9.4, 9.5, 9.6_

  - [x] 16.3 Implement email sending service
    - Integrate SendGrid or SES for email delivery
    - Send within 5 minutes of scheduled analysis completion
    - Gate sending on configured email AND emailNotificationsEnabled
    - _Requirements: 9.3, 9.7, 9.11_

  - [x] 16.4 Implement email retry logic
    - Retry up to 3 times with 1-minute intervals
    - Log failures for monitoring
    - Continue processing other users on failure
    - _Requirements: 9.8, 9.9_

  - [x] 16.5 Write property test for email format validation
    - **Property 17: Email Format Validation**
    - **Validates: Requirements 9.2**

  - [x] 16.6 Write property test for email content completeness
    - **Property 18: Email Content Completeness**
    - **Validates: Requirements 9.4, 9.5, 9.6**

  - [x] 16.7 Write property test for email notification gating
    - **Property 19: Email Notification Gating**
    - **Validates: Requirements 9.7, 9.11**

- [x] 17. Final integration and wiring
  - [x] 17.1 Implement main navigation and app flow
    - Wire TradingGuruApp entry point to AuthenticationView
    - Implement TabView for Watchlist, Analysis, Results, Settings
    - Connect all ViewModels to their respective Views
    - _Requirements: 1.1, 1.5, 1.9_

  - [x] 17.2 Implement error handling across all modules
    - Apply exponential backoff for retries (1s, 2s, 4s)
    - Display user-friendly error messages per error catalog
    - Preserve local state on database failures
    - _Requirements: 1.6, 2.9, 4.9, 5.5, 7.6_

  - [x] 17.3 Write integration tests for end-to-end flows
    - Test authentication → watchlist → analysis → results flow
    - Test offline/online data sync transitions
    - Test scheduled analysis result display
    - _Requirements: 1.1-1.10, 2.1-2.9, 6.1-6.8_

- [x] 18. Final checkpoint - All tests pass
  - Ensure all unit, property, and integration tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after major feature completions
- Property tests validate the 19 universal correctness properties defined in the design
- Unit tests validate specific examples, edge cases, and component behavior
- SwiftCheck library is used for property-based testing in Swift
- Backend service uses Cloud Functions (TypeScript/Python) with appropriate PBT library
- MVVM architecture ensures clean separation and testability
- Repository pattern enables offline-first behavior with local caching

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "2.1"] },
    { "id": 3, "tasks": ["2.2", "4.1"] },
    { "id": 4, "tasks": ["2.3", "2.4", "2.5", "4.2", "4.3"] },
    { "id": 5, "tasks": ["2.6", "4.4"] },
    { "id": 6, "tasks": ["2.7", "4.5", "4.6", "4.7", "4.8"] },
    { "id": 7, "tasks": ["6.1", "6.2"] },
    { "id": 8, "tasks": ["6.3", "6.4", "6.5"] },
    { "id": 9, "tasks": ["6.6"] },
    { "id": 10, "tasks": ["6.7", "6.8", "6.9"] },
    { "id": 11, "tasks": ["8.1", "8.2"] },
    { "id": 12, "tasks": ["8.3", "8.4"] },
    { "id": 13, "tasks": ["8.5"] },
    { "id": 14, "tasks": ["8.6", "8.7", "8.8", "8.9"] },
    { "id": 15, "tasks": ["10.1"] },
    { "id": 16, "tasks": ["10.2", "10.3"] },
    { "id": 17, "tasks": ["10.4"] },
    { "id": 18, "tasks": ["10.5", "10.6", "10.7"] },
    { "id": 19, "tasks": ["12.1"] },
    { "id": 20, "tasks": ["12.2", "12.3"] },
    { "id": 21, "tasks": ["12.4"] },
    { "id": 22, "tasks": ["12.5"] },
    { "id": 23, "tasks": ["14.1"] },
    { "id": 24, "tasks": ["14.2", "14.3"] },
    { "id": 25, "tasks": ["14.4", "14.5"] },
    { "id": 26, "tasks": ["14.6"] },
    { "id": 27, "tasks": ["16.1"] },
    { "id": 28, "tasks": ["16.2", "16.3"] },
    { "id": 29, "tasks": ["16.4"] },
    { "id": 30, "tasks": ["16.5", "16.6", "16.7"] },
    { "id": 31, "tasks": ["17.1"] },
    { "id": 32, "tasks": ["17.2"] },
    { "id": 33, "tasks": ["17.3"] }
  ]
}
```
