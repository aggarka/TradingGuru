# Implementation Plan: Covered Call Strategy

## Overview

This implementation plan adds a portfolio-aware Covered Call Strategy to TradingGuru while preserving the existing Weekly Option Strategy. The work intentionally separates reusable market/option analytics from covered-call-specific filtering and scoring so future Cash-Secured Put and Wheel strategies can share the same foundation.

All tasks are initially unchecked. Implement in dependency order and keep existing Weekly Option tests passing throughout.

## Tasks

- [ ] 1. Extend market and option domain models without breaking existing behavior
  - [ ] 1.1 Extend PricePoint with optional OHLCV fields
    - Add optional open, high, low, and volume properties
    - Preserve the current date and close API
    - Provide default nil values in initializers to retain source compatibility
    - Update Codable behavior as needed
    - _Requirements: 8.1, 8.2, 8.4_

  - [ ] 1.2 Extend OptionContract with Yahoo liquidity and volatility fields
    - Add optional contractSymbol, lastPrice, volume, openInterest, impliedVolatility, inTheMoney, and lastTradeDate
    - Preserve current midPrice calculation
    - Provide backward-compatible initializer defaults
    - _Requirements: 9.1-9.8_

  - [ ] 1.3 Add SecurityMetadata model
    - Include ticker, quoteType, marketCap, firstTradeDate, exDividendDate, dividendYield, and leveraged-ETF classification state
    - Keep supplementary values optional
    - _Requirements: 10.1-10.6_

  - [ ] 1.4 Add model regression tests
    - Verify existing PricePoint and OptionContract construction still compiles and behaves as before
    - Verify Codable round trips for new optional fields
    - _Requirements: 8.2, 9.8_

- [ ] 2. Preserve additional data already returned by Yahoo Finance
  - [ ] 2.1 Update historical chart parsing to preserve OHLCV
    - Align timestamp, open, high, low, close, and volume arrays
    - Represent missing observations as nil rather than fabricated zero values
    - Preserve chronological ordering
    - _Requirements: 8.1, 8.3, 8.4, 8.5_

  - [ ] 2.2 Update option parsing to preserve liquidity and IV fields
    - Copy contractSymbol, lastPrice, volume, openInterest, impliedVolatility, inTheMoney, and lastTradeDate from YahooOptionData into OptionContract
    - Convert lastTradeDate timestamp to Date
    - _Requirements: 9.1-9.9_

  - [ ] 2.3 Expose available expiration dates through OptionsDataService
    - Add fetchAvailableExpirations(ticker:) async API
    - Reuse existing Yahoo expiration-fetch logic instead of duplicating requests
    - Return Date values in normalized timezone handling
    - _Requirements: 14.1-14.3_

  - [ ] 2.4 Add Yahoo security metadata retrieval
    - Fetch only required quote-summary or quote modules
    - Parse market cap, quote type, first trade date when available, ex-dividend date, and dividend yield
    - Handle partial metadata without failing the primary quote/history fetch
    - _Requirements: 10.1-10.6_

  - [ ] 2.5 Write Yahoo parsing tests
    - Test OHLCV alignment
    - Test missing OHLCV values
    - Test option OI/volume/IV parsing
    - Test metadata partial-data behavior
    - Test available expiration parsing
    - _Requirements: 8, 9, 10, 14_

- [ ] 3. Checkpoint - Data foundation
  - Ensure existing Weekly Option tests pass
  - Ensure new model and Yahoo parsing tests pass before building Covered Call logic

- [ ] 4. Implement reusable technical-indicator calculations
  - [ ] 4.1 Define TechnicalIndicatorCalculating protocol
    - Add averageDailyVolume, averageTrueRange, historicalVolatility, recentHigh, and trendMetrics operations
    - Keep calculations independent from network services
    - _Requirements: 3.4-3.9, 12.5, 12.6_

  - [ ] 4.2 Implement average daily volume
    - Use the configured most-recent non-nil observations
    - Return nil when insufficient valid observations exist
    - _Requirements: 3.4, 3.5, 13.3_

  - [ ] 4.3 Implement ATR
    - Use standard True Range from high, low, and previous close
    - Average over configurable ATR period
    - Calculate ATR as percentage of current price
    - _Requirements: 3.8, 3.9, 12.5_

  - [ ] 4.4 Implement historical volatility
    - Use daily log returns
    - Calculate standard deviation over configured lookback
    - Annualize using sqrt(252)
    - _Requirements: 3.6, 3.7, 12.6_

  - [ ] 4.5 Implement simple resistance and trend metrics
    - Calculate recent 20-day high
    - Provide moving-average direction or equivalent transparent trend indicators
    - Keep breakout detection advisory, not mandatory
    - _Requirements: 15.10, 16.5_

  - [ ] 4.6 Add indicator property/unit tests
    - Validate ATR on known sequences
    - Validate flat-price ATR/volatility behavior
    - Validate volume lookback boundaries
    - Validate historical-volatility annualization
    - _Requirements: 3, 12_

- [ ] 5. Implement reusable option analytics
  - [ ] 5.1 Define OptionAnalyticsCalculating protocol
    - Include premiumYield, spreadPercent, expectedMove, and estimatedCallDelta
    - Keep implementation free of UI/network dependencies
    - _Requirements: 11, 12_

  - [ ] 5.2 Implement premium yield
    - premiumYield = midPrice / stockPrice
    - Reject invalid/non-positive stock prices
    - _Requirements: 12.1_

  - [ ] 5.3 Implement bid/ask spread percentage
    - spreadPct = (ask - bid) / ((ask + bid) / 2)
    - Return nil for non-positive midpoint
    - _Requirements: 4.8, 4.12, 12.2_

  - [ ] 5.4 Implement expected move and distance
    - expectedMove = stockPrice * IV * sqrt(DTE / 365)
    - expectedMoveMultiple = (strike - stockPrice) / expectedMove
    - _Requirements: 5.1, 5.2, 12.3, 12.4_

  - [ ] 5.5 Implement ATR distance and upside calculations
    - atrDistance = (strike - stockPrice) / ATR
    - upsidePct = (strike - stockPrice) / stockPrice
    - _Requirements: 5.3-5.5, 12.5, 12.7_

  - [ ] 5.6 Implement effective sale price calculations
    - effectiveSalePrice = strike + premium per share
    - assignmentGainPerShare = effectiveSalePrice - averageCostBasis when available
    - _Requirements: 12.8, 12.9, 17.8_

  - [ ] 5.7 Implement BlackScholesGreeksCalculator
    - Add replaceable protocol for estimated Greeks
    - Support S, K, T, sigma, risk-free rate, and dividend yield
    - Calculate dividend-adjusted estimated call delta
    - Keep risk-free rate supplied externally/configurably
    - Label domain property estimatedDelta
    - _Requirements: 11.1-11.6_

  - [ ] 5.8 Add option analytics tests
    - Test known Black-Scholes delta values
    - Test monotonic delta behavior as strike changes
    - Test premium yield
    - Test spread edge cases
    - Test expected move
    - Test DTE = 0 / IV = 0 invalid handling
    - _Requirements: 11, 12_

- [ ] 6. Add portfolio domain and persistence
  - [ ] 6.1 Create PortfolioPosition model
    - Add id, ticker, shares, optional averageCostBasis, optional targetSalePrice, updatedAt
    - Conform to Codable, Identifiable, Equatable
    - _Requirements: 1.1-1.4_

  - [ ] 6.2 Add PortfolioPosition validation
    - Validate ticker format using existing stock validation where possible
    - Validate positive share quantity
    - Validate positive optional prices
    - _Requirements: 1.2-1.4_

  - [ ] 6.3 Define PortfolioRepository protocol
    - Add loadPositions, savePosition, and deletePosition
    - Scope all persistence by userId
    - _Requirements: 1.8-1.10_

  - [ ] 6.4 Implement local PortfolioRepository
    - Follow existing local repository patterns
    - Preserve positions across app sessions
    - _Requirements: 1.8-1.10_

  - [ ] 6.5 Add cloud-compatible PortfolioRepository implementation or adapter
    - Reuse FirestoreClient patterns when cloud persistence is enabled
    - Keep local fallback behavior consistent with existing repositories
    - _Requirements: 1.9, 1.10_

  - [ ] 6.6 Implement contract eligibility calculations
    - eligibleContracts = floor(shares / 100)
    - Apply configured maximumCoveragePct
    - For 500 shares at 50%, recommend 2 contracts
    - Never exceed eligibleContracts
    - _Requirements: 1.5-1.7, 7.1-7.5_

  - [ ] 6.7 Add portfolio tests
    - Test 99, 100, 199, 200, and 500 share boundaries
    - Test 50%, 75%, and 100% coverage settings
    - Test missing cost basis
    - _Requirements: 1, 7_

- [ ] 7. Build Portfolio UI
  - [ ] 7.1 Create PortfolioViewModel
    - Load positions for current authenticated user
    - Add/edit/delete positions
    - Expose covered-call eligibility and maximum contract count
    - Handle repository failures consistently with other ViewModels
    - _Requirements: 1_

  - [ ] 7.2 Create PortfolioView
    - Show ticker, shares, cost basis, target sale price, and eligibility
    - Add position flow
    - Edit and delete flows
    - Empty-state guidance
    - _Requirements: 1.1-1.10_

  - [ ] 7.3 Integrate Portfolio into navigation
    - Prefer a Portfolio tab if layout remains clear
    - Otherwise provide a dedicated navigation destination without coupling strategy logic to UI placement
    - _Requirements: 1, 2.4_

- [ ] 8. Refactor strategy execution to support multiple async strategies
  - [ ] 8.1 Define ExecutableStrategy abstraction
    - Include identifier, name, configuration schema, async execute, progress reporting
    - Define StrategyExecutionContext and StrategyRunResult
    - _Requirements: 2.5, 2.6_

  - [ ] 8.2 Create WeeklyOptionExecutableAdapter
    - Convert generic StrategyConfiguration to WeeklyOptionConfiguration
    - Read watchlist tickers from StrategyExecutionContext
    - Delegate to existing WeeklyOptionStrategy batch analysis
    - Preserve current Weekly Option output and behavior
    - _Requirements: 2.3, 2.5_

  - [ ] 8.3 Register executable strategies through StrategyRegistry or a compatible registry layer
    - Register weekly_option
    - Prepare registration for covered_call
    - Avoid hard-coded strategy lists in AnalysisViewModel
    - _Requirements: 2.1-2.6_

  - [ ] 8.4 Refactor AnalysisViewModel
    - Remove direct dependency on a single WeeklyOptionStrategy where practical
    - Load configuration based on selected strategy
    - Execute selected strategy through registry/factory abstraction
    - Remove assumptions that every ticker returns exactly two rows
    - _Requirements: 2.5, 2.6_

  - [ ] 8.5 Refactor default configuration resolution
    - Allow ConfigurationRepository defaults to come from strategy registration/configuration schemas
    - Avoid adding per-strategy if/else branches for future strategies
    - _Requirements: 18.1-18.5_

  - [ ] 8.6 Add multi-strategy regression tests
    - Verify Weekly Option selection still works
    - Verify configuration save/load still works
    - Verify registry produces strategy picker entries
    - Verify Weekly Option result count assumptions are removed safely
    - _Requirements: 2, 18_

- [ ] 9. Checkpoint - Multi-strategy foundation
  - Run the complete existing Weekly Option test suite
  - Fix regressions before implementing CoveredCallStrategy

- [ ] 10. Implement CoveredCallConfiguration
  - [ ] 10.1 Create strongly typed CoveredCallConfiguration
    - Add all default underlying, option, strike-safety, event, position, and scoring parameters
    - Add enable/disable flags for applicable filters
    - strategyId = "covered_call"
    - _Requirements: 3-7, 18_

  - [ ] 10.2 Add conversion to/from StrategyConfiguration
    - Persist every configurable field through existing generic configuration storage
    - Maintain sensible defaults for missing fields during version upgrades
    - _Requirements: 18.1-18.5_

  - [ ] 10.3 Add configuration validation
    - Validate ranges and relationships, including minDTE <= maxDTE and minDelta <= maxDelta
    - Validate 0-100% coverage
    - Validate non-negative thresholds
    - _Requirements: 3-7_

  - [ ] 10.4 Add conservative reset defaults
    - Implement reset to documented defaults
    - _Requirements: 18.4_

  - [ ] 10.5 Add configuration tests
    - Test all defaults exactly
    - Test invalid ranges
    - Test round-trip persistence
    - Test backward-compatible missing parameters
    - _Requirements: 3-7, 18_

- [ ] 11. Implement event-risk evaluation
  - [ ] 11.1 Define EventRiskEvaluating protocol
    - Evaluate earnings blackout and ex-dividend warnings
    - Return structured exclusions/warnings
    - _Requirements: 6_

  - [ ] 11.2 Implement trading-day earnings buffer
    - Reuse market-calendar/expiration logic where possible
    - Do not treat calendar weekends as trading days
    - _Requirements: 6.1, 6.2_

  - [ ] 11.3 Implement ex-dividend warning
    - Warn when ex-dividend date is on or before expiration
    - Preserve future extension for early-assignment risk logic
    - _Requirements: 6.3, 6.6_

  - [ ] 11.4 Add event-risk tests
    - Earnings exactly on expiration
    - Earnings one trading day after expiration with buffer
    - Weekend boundaries
    - Missing event metadata
    - Ex-dividend before/after expiration
    - _Requirements: 6_

- [ ] 12. Implement Covered Call hard-filter engine
  - [ ] 12.1 Define CandidateExclusionReason and CoveredCallWarning enums
    - Use machine-readable cases with user-facing descriptions
    - _Requirements: 13.4, 13.5, 17.11_

  - [ ] 12.2 Define CoveredCallFilterResult
    - passed
    - exclusionReasons
    - warnings
    - _Requirements: 13_

  - [ ] 12.3 Implement position and underlying filters
    - share eligibility
    - stock price
    - market cap for equities
    - average volume
    - leveraged ETF exclusion
    - historical volatility / ATR limits where configured
    - _Requirements: 3, 7, 13_

  - [ ] 12.4 Implement option liquidity filters
    - DTE
    - OTM
    - open interest
    - option volume
    - midpoint validity
    - spread
    - minimum premium yield
    - _Requirements: 4, 13_

  - [ ] 12.5 Implement strike-safety filters
    - delta
    - Expected_Move_Multiple
    - ATR_Distance
    - minimum upside
    - cost-basis protection
    - target-sale-price protection
    - _Requirements: 5, 11, 13_

  - [ ] 12.6 Implement event filters
    - earnings blackout
    - event warnings
    - _Requirements: 6, 13_

  - [ ] 12.7 Handle missing required data explicitly
    - Never convert missing OI/volume/IV/delta/ATR/market-cap dependencies to zero and pass
    - Emit exclusion reason or warning based on configuration
    - _Requirements: 10.5, 10.6, 11.4, 13_

  - [ ] 12.8 Add boundary/property tests for every hard filter
    - Exactly at threshold passes where specified
    - Just below/above threshold behaves correctly
    - Multiple exclusion reasons are retained
    - _Requirements: 13_

- [ ] 13. Implement Covered Call scoring engine
  - [ ] 13.1 Define CoveredCallScoreBreakdown
    - Assignment Safety
    - Liquidity
    - Underlying Quality
    - Premium Efficiency
    - Technical Cushion
    - Volatility Quality
    - Bound total to 0-100
    - _Requirements: 15.1-15.13_

  - [ ] 13.2 Implement assignment/strike-safety scoring
    - Delta up to 12 points
    - Expected-move distance up to 13 points
    - Keep curve centralized and testable
    - _Requirements: 15.4, 15.5_

  - [ ] 13.3 Implement liquidity scoring
    - OI up to 7
    - option volume up to 5
    - bid/ask spread up to 8
    - _Requirements: 15.6_

  - [ ] 13.4 Implement underlying-quality scoring
    - market cap when applicable
    - underlying liquidity
    - historical volatility
    - ATR stability
    - do not penalize ETFs solely for non-applicable market cap
    - _Requirements: 15.7_

  - [ ] 13.5 Implement premium-efficiency scoring
    - Normalize appropriately for DTE
    - Reward useful premium
    - Plateau/reduce score for unusually high premium
    - _Requirements: 15.8, 15.9_

  - [ ] 13.6 Implement technical-cushion scoring
    - ATR distance
    - recent-high/resistance relationship
    - transparent trend state
    - _Requirements: 15.10_

  - [ ] 13.7 Implement volatility-quality scoring
    - Use current IV relative to realized volatility in Version 1
    - Keep interface replaceable with IV Rank/Percentile later
    - _Requirements: 15.11, 15.12_

  - [ ] 13.8 Add scoring tests
    - Score total always 0-100
    - Monotonic behavior for intended ranges
    - High premium does not always dominate
    - Failed hard-filter candidates are never scored as recommendations
    - _Requirements: 15_

- [ ] 14. Implement CoveredCallStrategy candidate discovery
  - [ ] 14.1 Create CoveredCallCandidate and CoveredCallMetrics
    - Include position, metadata, option contract, analytics, warnings, score, and quantity
    - _Requirements: 12, 15, 17_

  - [ ] 14.2 Implement per-position analysis
    - Fetch quote, OHLCV, metadata, earnings/dividend data, and expirations
    - Calculate underlying metrics once per position
    - _Requirements: 14_

  - [ ] 14.3 Evaluate eligible expiration dates
    - Compute DTE from reference date
    - Keep only configured range
    - Fetch each eligible options chain
    - _Requirements: 4.1, 4.2, 14.1-14.3_

  - [ ] 14.4 Evaluate all eligible CALL contracts
    - Keep calls
    - Calculate analytics
    - Apply filters
    - Score passing candidates
    - _Requirements: 14.3-14.7_

  - [ ] 14.5 Sort passing candidates
    - Highest score first
    - Stable deterministic tie-breakers
    - _Requirements: 14.7_

  - [ ] 14.6 Continue after per-position or per-expiration failures
    - Preserve structured errors
    - Do not terminate unrelated positions
    - _Requirements: 14.9_

  - [ ] 14.7 Add integration tests for multi-position analysis
    - Multiple positions
    - mixed successes/failures
    - multiple expirations
    - no passing candidates
    - _Requirements: 14_

- [ ] 15. Implement candidate classification and alternatives
  - [ ] 15.1 Select primary candidate
    - Highest Covered Call Setup Score
    - _Requirements: 16.1_

  - [ ] 15.2 Select Lower Assignment Risk alternative
    - Prefer lower delta, greater Expected_Move_Multiple, and greater upside among passing candidates
    - Require meaningful differentiation from primary
    - _Requirements: 16.2, 16.3_

  - [ ] 15.3 Select Higher Income alternative
    - Prefer greater DTE-normalized premium yield among passing candidates
    - Keep mandatory filters intact
    - _Requirements: 16.2, 16.3_

  - [ ] 15.4 Implement assignment-risk classification
    - Low / Medium / High using documented transparent thresholds
    - Do not use "safe" terminology
    - _Requirements: 16.4, 16.5_

  - [ ] 15.5 Add alternative-selection tests
    - one candidate
    - three differentiated candidates
    - ties
    - no qualifying lower-risk or higher-income alternative
    - _Requirements: 16_

- [ ] 16. Build Covered Call configuration UI
  - [ ] 16.1 Add Covered Call Strategy to Analysis strategy picker
    - Source picker data from registry
    - Display strategy description
    - _Requirements: 2_

  - [ ] 16.2 Build grouped configuration sections
    - Position
    - Underlying Quality
    - Option
    - Strike Safety
    - Events
    - Advanced / Scoring
    - _Requirements: 3-7_

  - [ ] 16.3 Add filter enable/disable controls
    - Pair toggles with thresholds where applicable
    - Explain units and defaults
    - _Requirements: 3.1_

  - [ ] 16.4 Add Reset to Conservative Defaults
    - Restore CoveredCallConfiguration.default
    - Persist reset values
    - _Requirements: 18.4_

  - [ ] 16.5 Add configuration validation feedback
    - Reuse existing error/persistence interaction patterns
    - _Requirements: 18_

- [ ] 17. Build strategy-aware Covered Call results UI
  - [ ] 17.1 Introduce strategy-aware result routing
    - Keep existing Weekly Option ResultsView behavior
    - Route Covered Call results to dedicated cards/details
    - _Requirements: 17.12_

  - [ ] 17.2 Build Covered Call summary card
    - ticker / shares
    - score
    - strike / expiration / DTE
    - Estimated Delta
    - premium and premium yield
    - upside
    - recommended contracts
    - earnings/event status
    - _Requirements: 17_

  - [ ] 17.3 Build expanded detail view
    - cost basis / target price
    - effective sale price / assignment gain
    - OI / volume / spread
    - IV / realized volatility
    - Expected Move / multiple
    - ATR / distance
    - technical metrics
    - score breakdown
    - warnings
    - _Requirements: 17_

  - [ ] 17.4 Display alternatives
    - Lower Assignment Risk
    - Highest Score
    - Higher Income
    - _Requirements: 16, 17_

  - [ ] 17.5 Add terminology safeguards
    - Use "setup", "candidate", "risk", and "estimated"
    - Do not label candidates "safe"
    - _Requirements: 16.4_

- [ ] 18. Persist Covered Call configuration
  - [ ] 18.1 Register covered_call default configuration
    - Integrate with generic configuration repository/default-provider refactor
    - _Requirements: 18_

  - [ ] 18.2 Verify save/load per authenticated user
    - local mode
    - cloud-enabled mode where available
    - fallback to defaults
    - _Requirements: 18.1-18.5_

  - [ ] 18.3 Add persistence tests
    - round trip
    - reset
    - missing/new fields
    - database unavailable fallback
    - _Requirements: 18_

- [ ] 19. Checkpoint - End-to-end Covered Call flow
  - Run the app through:
    - add/edit portfolio position
    - select Covered Call Strategy
    - change configuration
    - run analysis
    - view ranked candidate
    - view alternative candidates
    - inspect score breakdown
  - Verify no brokerage execution occurs
  - Verify existing Weekly Option workflow remains functional

- [ ] 20. Add comprehensive regression and property tests
  - [ ] 20.1 Run all existing TradingGuru tests
    - Fix regressions without weakening current Weekly Option requirements
    - _Requirements: all_

  - [ ] 20.2 Add property: recommended contracts never exceed owned-share coverage
    - For arbitrary valid shares and coverage %, recommendedContracts * 100 <= shares
    - _Requirements: 7_

  - [ ] 20.3 Add property: hard-filter failure prevents recommendation
    - Any enabled failed hard filter means candidate cannot become primary/alternative
    - _Requirements: 13_

  - [ ] 20.4 Add property: score is always bounded 0-100
    - _Requirements: 15.2_

  - [ ] 20.5 Add property: OTM requirement
    - When enabled, every recommended call has strike > current stock price
    - _Requirements: 4.5, 13_

  - [ ] 20.6 Add property: cost-basis protection
    - When enabled and basis exists, every recommended strike >= cost basis
    - _Requirements: 5.6, 5.8_

  - [ ] 20.7 Add property: target-price protection
    - When enabled and target exists, every recommended strike >= target sale price
    - _Requirements: 5.7, 5.9_

  - [ ] 20.8 Add property: earnings exclusion
    - With exclusion enabled, no recommendation expires inside the earnings blackout window
    - _Requirements: 6.1, 6.2_

  - [ ] 20.9 Add property: candidate ranking is deterministic
    - Same inputs/configuration produce the same ordering
    - _Requirements: 14.7_

- [ ] 21. Performance and API-behavior validation
  - [ ] 21.1 Measure Yahoo request volume
    - Avoid repeated metadata/history fetches per contract
    - Cache per-position data within one scan
    - _Requirements: 14_

  - [ ] 21.2 Add bounded concurrency
    - Prevent a large portfolio × expiration set from overwhelming Yahoo or hitting rate limits
    - Continue graceful degradation on 429 responses
    - _Requirements: 14.9_

  - [ ] 21.3 Validate scan responsiveness
    - Provide progress per position and/or expiration
    - Ensure UI remains responsive
    - _Requirements: 14, 17_

- [ ] 22. Documentation and release-scope cleanup
  - [ ] 22.1 Update How To Use content
    - Explain manual portfolio entry
    - Explain Covered Call score and estimated delta
    - Explain assignment/upside tradeoff
    - Clarify that analysis is not trade execution
    - _Requirements: 16, 17, 19_

  - [ ] 22.2 Update privacy/product docs if portfolio data collection changes disclosures
    - Review local/cloud storage statements
    - _Requirements: 1, 19_

  - [ ] 22.3 Document Version 1 exclusions
    - no brokerage order placement
    - no auto-roll/close
    - no scheduled Covered Call scans
    - no claim that a recommendation was traded
    - _Requirements: 19_

- [ ] 23. Final checkpoint
  - All Covered Call tests pass
  - All pre-existing TradingGuru tests pass
  - Manual end-to-end flow succeeds
  - Strategy picker is registry-driven
  - Portfolio is user-scoped
  - No trade execution path exists
  - Kiro requirements/design/tasks remain consistent with implementation
