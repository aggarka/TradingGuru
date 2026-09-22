# Technical Design Document: Covered Call Strategy

## Overview

The Covered Call Strategy will be implemented as a new portfolio-aware strategy within the existing TradingGuru SwiftUI/MVVM architecture.

The design reuses the current YahooFinanceService, options-chain integration, expiration-date logic, generic StrategyConfiguration storage, authentication, repository patterns, Results concepts, and StrategyRegistry infrastructure.

A key architectural goal is to avoid adding another hard-coded strategy path. The repository already contains TradingStrategy and StrategyRegistry abstractions, while AnalysisViewModel currently depends directly on WeeklyOptionStrategy and WeeklyOptionConfiguration. Covered Calls should be the feature that completes the intended multi-strategy architecture.

## Key Design Goals

1. Reuse existing market-data and persistence infrastructure.
2. Preserve all existing Weekly Option Strategy behavior and tests.
3. Separate hard filtering from scoring.
4. Keep calculations pure and independently testable.
5. Preserve transparency: every exclusion, warning, metric, and score component should be explainable.
6. Build shared analytics that Cash-Secured Put and Wheel strategies can reuse later.
7. Keep Version 1 analysis-only and manual-scan focused.

## Current Architecture Findings

### Existing reusable components

- StrategyProtocols.swift defines StrategyConfiguration, StrategyConfigurationSchema, TradingStrategy, StrategyFactory, and StrategyRegistry.
- WeeklyOptionStrategy.swift already depends on protocols for market data, options data, expiration calculation, rolling-window calculation, and premium matching.
- YahooFinanceService.swift already receives option volume, open interest, implied volatility, last price, in-the-money status, and OHLCV chart arrays.
- ConfigurationRepositoryImpl.swift already stores arbitrary strategy configurations by strategyId.
- AnalysisViewModel.swift handles strategy selection, configuration persistence, progress, and results but is currently hard-coded to WeeklyOptionStrategy.
- HomeView currently wires Watchlist, Analysis, Results, and Settings tabs.
- Existing Kiro specs and tests establish a strong protocol-oriented and property-test-driven pattern.

### Current gaps relevant to Covered Calls

1. No Portfolio/Position domain model.
2. No PortfolioRepository.
3. AnalysisViewModel hard-codes the Weekly Option Strategy.
4. PricePoint stores only close, discarding OHLCV needed for ATR and volume calculations.
5. OptionContract stores only strike, bid, ask, type, ticker, and expiration, discarding Yahoo liquidity/IV fields.
6. Yahoo does not currently provide broker/exchange Greeks through the parsed options model.
7. Security metadata such as market cap and ex-dividend date is not represented in the domain model.
8. The current strategy assumes a single selected expiration; Covered Calls require discovery across a DTE range.
9. Current Results models are Weekly-Option-specific and should not absorb every Covered Call field.

## High-Level Architecture

    Portfolio UI
        |
        v
    PortfolioViewModel
        |
        v
    PortfolioRepository
        |
        v
    Strategy Execution
        |
        +--> CoveredCallStrategy
                |
                +--> MarketDataService / YahooFinanceService
                |       +--> Quote
                |       +--> Historical OHLCV
                |       +--> Earnings
                |       +--> Security Metadata
                |       +--> Available Expirations
                |       +--> Options Chains
                |
                +--> TechnicalIndicatorCalculating
                |       +--> Average Volume
                |       +--> ATR
                |       +--> Historical Volatility
                |       +--> Recent High / Trend
                |
                +--> OptionAnalyticsCalculating
                |       +--> Estimated Delta
                |       +--> Premium Yield
                |       +--> Spread %
                |       +--> Expected Move
                |       +--> Expected-Move Multiple
                |       +--> ATR Distance
                |
                +--> CoveredCallFiltering
                |
                +--> CoveredCallScoring
                        |
                        v
                CoveredCallCandidate[]
                        |
                        v
                Strategy-aware Results UI

## Strategy Architecture Refactor

### Problem

AnalysisViewModel currently owns:

- a WeeklyOptionStrategy dependency
- WeeklyOptionConfiguration state
- a hard-coded availableStrategies array
- switch logic for WeeklyOptionConfiguration.strategyId
- assumptions that each successful ticker returns two rows

This undermines the existing StrategyRegistry abstraction.

### Proposed execution abstraction

Introduce an async execution protocol separate from the existing synchronous TradingStrategy protocol.

    protocol ExecutableStrategy {
        var identifier: String { get }
        var name: String { get }
        var configurationSchema: StrategyConfigurationSchema { get }

        func execute(
            context: StrategyExecutionContext,
            configuration: StrategyConfiguration,
            progress: @escaping (StrategyProgress) -> Void
        ) async -> StrategyRunResult
    }

StrategyExecutionContext should contain user-specific inputs needed by a strategy without making AnalysisViewModel know their concrete type.

Examples:

- userId
- watchlist tickers
- portfolio positions
- reference date
- optional session expiration override

StrategyRunResult should support strategy-specific result payloads while preserving common metadata such as strategyId, timestamp, warnings, and errors.

### Weekly Option compatibility

Do not rewrite the tested WeeklyOptionStrategy business logic.

Create a WeeklyOptionExecutableAdapter that:

1. Converts StrategyConfiguration to WeeklyOptionConfiguration.
2. Reads watchlist tickers from StrategyExecutionContext.
3. Calls the existing WeeklyOptionStrategy batch API.
4. Wraps results into StrategyRunResult.

### Covered Call implementation

CoveredCallStrategy conforms to ExecutableStrategy and reads portfolio positions from StrategyExecutionContext.

### Strategy registration

StrategyRegistry should become the source used to populate the Analysis strategy picker.

The registry should register:

- weekly_option through WeeklyOptionExecutableAdapter
- covered_call through CoveredCallStrategy

If keeping TradingStrategy and ExecutableStrategy separate creates unnecessary duplication, introduce a common descriptor protocol for identifier, name, and configuration schema.

## Data Models

### PricePoint extension

Current PricePoint:

- date
- close

Extend with backward-compatible optional values:

    struct PricePoint: Codable, Equatable {
        let date: Date
        let close: Double
        let open: Double?
        let high: Double?
        let low: Double?
        let volume: Int?
    }

Provide defaults of nil in the initializer so existing tests and call sites remain source-compatible.

### OptionContract extension

Extend the existing model:

    struct OptionContract: Codable, Identifiable, Equatable {
        let id: UUID
        let ticker: String
        let type: OpportunityType
        let strikePrice: Double
        let bid: Double
        let ask: Double
        let expirationDate: Date

        let contractSymbol: String?
        let lastPrice: Double?
        let volume: Int?
        let openInterest: Int?
        let impliedVolatility: Double?
        let inTheMoney: Bool?
        let lastTradeDate: Date?

        var midPrice: Double { ... }
    }

All new fields should default to nil for backward compatibility.

### PortfolioPosition

    struct PortfolioPosition: Codable, Identifiable, Equatable {
        let id: UUID
        let ticker: String
        var shares: Int
        var averageCostBasis: Double?
        var targetSalePrice: Double?
        var updatedAt: Date
    }

Validation:

- ticker must pass existing ticker validation rules
- shares must be positive
- cost basis, when supplied, must be positive
- target sale price, when supplied, must be positive

### SecurityMetadata

    struct SecurityMetadata: Codable, Equatable {
        let ticker: String
        let quoteType: String?
        let marketCap: Double?
        let firstTradeDate: Date?
        let exDividendDate: Date?
        let dividendYield: Double?
        let isLeveragedETF: Bool?
    }

Do not infer leveraged ETF status solely from volatility. Prefer provider metadata or an explicit maintained classification rule.

### CoveredCallConfiguration

Use a strongly typed model for strategy code and convert to/from StrategyConfiguration for persistence.

Suggested parameter groups:

- underlying
- option
- strikeSafety
- events
- position
- scoring
- technical

Representative fields:

    minimumMarketCap = 10_000_000_000
    minimumStockPrice = 20
    minimumAverageDailyVolume = 1_000_000
    averageVolumeLookback = 30
    maximumHistoricalVolatility = 0.60
    historicalVolatilityLookback = 30
    atrPeriod = 14
    maximumAtrPercent = 0.05

    minimumDTE = 7
    maximumDTE = 14
    minimumDelta = 0.10
    maximumDelta = 0.20
    requireOTM = true
    minimumOpenInterest = 500
    minimumOptionVolume = 50
    maximumBidAskSpreadPct = 0.10
    preferredBidAskSpreadPct = 0.05
    minimumPremiumYield = 0.002
    preferredPremiumYield = 0.003

    minimumExpectedMoveMultiple = 1.0
    preferredExpectedMoveMultiple = 1.25
    minimumAtrDistance = 1.0
    preferredAtrDistance = 1.25
    minimumUpsidePct = 0.03

    excludeEarnings = true
    earningsBufferTradingDays = 1
    warnExDividend = true

    maximumCoveragePct = 0.50
    protectCostBasis = true
    respectTargetSalePrice = true

Percentages should be stored internally as decimal fractions unless an existing TradingGuru convention strongly favors percentage points. The UI should clearly format them as percentages.

### CoveredCallMetrics

    struct CoveredCallMetrics: Equatable {
        let dte: Int
        let estimatedDelta: Double?
        let premiumYield: Double
        let bidAskSpreadPct: Double?
        let expectedMove: Double?
        let expectedMoveMultiple: Double?
        let atr: Double?
        let atrPct: Double?
        let atrDistance: Double?
        let historicalVolatility: Double?
        let averageDailyVolume: Double?
        let upsidePct: Double
        let effectiveSalePrice: Double
        let assignmentGainPerShare: Double?
        let ivToHvRatio: Double?
    }

### CoveredCallScoreBreakdown

    struct CoveredCallScoreBreakdown: Codable, Equatable {
        let assignmentSafety: Double
        let liquidity: Double
        let underlyingQuality: Double
        let premiumEfficiency: Double
        let technicalCushion: Double
        let volatilityQuality: Double

        var total: Double {
            min(100, max(0,
                assignmentSafety +
                liquidity +
                underlyingQuality +
                premiumEfficiency +
                technicalCushion +
                volatilityQuality
            ))
        }
    }

### CandidateExclusionReason

Use an enum instead of free-form strings.

Suggested cases:

- insufficientShares
- belowMinimumStockPrice
- belowMinimumMarketCap
- insufficientUnderlyingVolume
- excludedLeveragedETF
- dteOutOfRange
- notOTM
- deltaUnavailable
- deltaOutOfRange
- earningsBlackout
- openInterestUnavailable
- openInterestTooLow
- optionVolumeUnavailable
- optionVolumeTooLow
- invalidMidpoint
- spreadTooWide
- premiumYieldTooLow
- expectedMoveUnavailable
- expectedMoveTooClose
- atrUnavailable
- atrDistanceTooClose
- insufficientUpside
- strikeBelowCostBasis
- strikeBelowTargetSalePrice
- metadataUnavailable
- marketDataUnavailable

### CoveredCallWarning

Suggested warnings:

- exDividendBeforeExpiration
- elevatedVolatility
- veryHighPremium
- missingCostBasis
- missingTargetSalePrice
- incompleteMetadata
- strongBullishBreakout

### CoveredCallCandidate

A candidate contains:

- PortfolioPosition
- SecurityMetadata
- current stock price
- OptionContract
- CoveredCallMetrics
- filter result
- warnings
- CoveredCallScoreBreakdown
- recommended contract quantity
- classification role when selected as lower-risk / primary / higher-income

## Repository Design

### PortfolioRepository

    protocol PortfolioRepository {
        func loadPositions(for userId: String) async throws -> [PortfolioPosition]
        func savePosition(_ position: PortfolioPosition, for userId: String) async throws
        func deletePosition(id: UUID, for userId: String) async throws
    }

Follow the existing repository pattern.

Version 1 can use local persistence first if that matches the current production path, but keep a cloud-compatible implementation boundary.

Suggested Firestore shape:

    users/{userId}/portfolio/{positionId}

or the equivalent structure consistent with the existing FirestoreClient abstraction.

## Market Data Changes

### Historical OHLCV

YahooFinanceService already decodes open/high/low/close/volume arrays in QuoteData but parseChartResponse currently surfaces only close through PricePoint.

Update parsing to align timestamp and OHLCV arrays and preserve available values.

### Option fields

YahooOptionData already contains:

- contractSymbol
- lastPrice
- volume
- openInterest
- impliedVolatility
- inTheMoney
- lastTradeDate

Update parseOptionContracts to copy these values into OptionContract.

### Available expiration dates

Covered Calls require a DTE range rather than one configured expiration.

Extend OptionsDataService:

    func fetchAvailableExpirations(ticker: String) async throws -> [Date]

YahooFinanceService already contains logic that obtains available expiration timestamps internally. Promote or reuse that logic rather than duplicating Yahoo requests.

Execution should:

1. fetch available expirations
2. compute DTE relative to analysis date
3. retain dates between minimumDTE and maximumDTE
4. fetch option chains only for those expirations

### Security metadata

Extend YahooFinanceService or a dedicated SecurityMetadataService to request only the modules required for:

- market capitalization
- quote type
- first trade date where available
- ex-dividend date
- dividend yield

Keep metadata fetching independent from core historical-price fetching so failure degrades gracefully.

## Technical Indicators

Create a TechnicalIndicatorCalculating protocol.

    protocol TechnicalIndicatorCalculating {
        func averageDailyVolume(prices: [PricePoint], lookback: Int) -> Double?
        func averageTrueRange(prices: [PricePoint], period: Int) -> Double?
        func historicalVolatility(prices: [PricePoint], lookback: Int) -> Double?
        func recentHigh(prices: [PricePoint], lookback: Int) -> Double?
        func trendMetrics(prices: [PricePoint]) -> TrendMetrics
    }

### Average daily volume

Average the most recent configured number of non-nil daily volume observations.

### ATR

Use standard True Range:

    max(
        high - low,
        abs(high - previousClose),
        abs(low - previousClose)
    )

ATR is the average True Range over the configured period.

### Historical volatility

1. Calculate daily log returns from consecutive closes.
2. Calculate standard deviation over the configured lookback.
3. Annualize using sqrt(252).

### Technical resistance / trend

Version 1 should keep technical scoring simple and explainable.

Suggested inputs:

- recent 20-trading-day high
- strike above recent high
- 20-day vs 50-day moving-average direction
- optional breakout warning when price exceeds recent resistance with unusually high volume

Do not make opaque technical scoring a hard dependency for Version 1.

## Option Analytics

Create OptionAnalyticsCalculating.

    protocol OptionAnalyticsCalculating {
        func premiumYield(midPrice: Double, stockPrice: Double) -> Double
        func spreadPercent(bid: Double, ask: Double) -> Double?
        func expectedMove(stockPrice: Double, impliedVolatility: Double, dte: Int) -> Double
        func estimatedCallDelta(input: DeltaInput) -> Double?
    }

### Premium yield

    midPrice / stockPrice

### Spread percentage

    (ask - bid) / ((ask + bid) / 2)

Return nil when midpoint is non-positive.

### Expected move

    stockPrice * impliedVolatility * sqrt(Double(dte) / 365.0)

Use implied volatility as a decimal, not percentage points.

### Expected-move multiple

    (strike - stockPrice) / expectedMove

### ATR distance

    (strike - stockPrice) / atr

### Estimated delta

Implement a BlackScholesGreeksCalculator conforming to a replaceable Greeks protocol.

Inputs:

- S = stock price
- K = strike
- T = DTE / 365
- sigma = implied volatility
- r = risk-free rate
- q = dividend yield

For a dividend-adjusted Black-Scholes call:

    d1 = [ln(S/K) + (r - q + sigma^2/2)T] / [sigma * sqrt(T)]
    callDelta = exp(-qT) * N(d1)

The UI must label this value "Estimated Delta".

Version 1 may use a documented default risk-free rate supplied through configuration or a provider abstraction. Do not hard-code it inside the math function.

## Event Risk

### Earnings

Reuse existing fetchEarningsDate.

Create EventRiskEvaluating to centralize:

- earnings blackout
- earnings buffer
- ex-dividend warning
- future corporate-event extension

### Earnings buffer

The buffer should be measured in trading days, not simple calendar days.

### Ex-dividend

Version 1 warning behavior:

- warn when ex-dividend date is on or before expiration
- optionally elevate warning when call is ITM or remaining extrinsic value is small

Do not implement forced exclusion unless the user changes configuration to do so.

## Hard Filter Engine

Create CoveredCallFiltering.

    protocol CoveredCallFiltering {
        func evaluate(
            input: CoveredCallCandidateInput,
            configuration: CoveredCallConfiguration
        ) -> CoveredCallFilterResult
    }

CoveredCallFilterResult:

- passed: Bool
- exclusionReasons: [CandidateExclusionReason]
- warnings: [CoveredCallWarning]

Important rule: scoring never compensates for a failed enabled hard filter.

## Scoring Engine

Create CoveredCallScoring.

    protocol CoveredCallScoring {
        func score(
            input: CoveredCallCandidateInput,
            configuration: CoveredCallConfiguration
        ) -> CoveredCallScoreBreakdown
    }

Only call the scoring engine after filtering passes.

### Default category weights

- Assignment / Strike Safety: 25
- Option Liquidity: 20
- Underlying Quality: 15
- Premium Efficiency: 15
- Technical Cushion: 15
- Volatility Quality: 10

### Assignment / Strike Safety

Delta: maximum 12 points.

Suggested curve:

- <= 0.10: 10
- 0.11-0.15: 12
- 0.16-0.18: 11
- 0.19-0.20: 8
- > 0.20: 0 under conservative defaults

Expected-move distance: maximum 13 points.

Suggested curve:

- < 0.75x: 0
- 0.75-1.00x: 4
- 1.00-1.25x: 8
- 1.25-1.50x: 11
- >= 1.50x: 13

The exact scoring curve should live in one testable component rather than being spread through UI code.

### Option Liquidity

Maximum 20:

- Open interest: 7
- Option volume: 5
- Bid/ask spread: 8

### Underlying Quality

Maximum 15.

Consider:

- market capitalization when applicable
- average daily volume
- historical volatility
- ATR stability

Do not automatically penalize ETFs for missing equity market cap.

### Premium Efficiency

Maximum 15.

Suggested weekly-equivalent premium-yield behavior:

- very low premium: low score
- useful moderate premium: increasing score
- unusually high premium: plateau or decline

This prevents "highest premium wins".

Normalize for DTE before comparing contracts with meaningfully different expirations.

### Technical Cushion

Maximum 15.

Suggested initial factors:

- ATR distance
- strike above recent high / resistance
- non-breakout trend state

### Volatility Quality

Maximum 10.

Do not require IV percentile in Version 1 because TradingGuru does not currently possess 252 days of IV history.

Use a transparent fallback such as:

    IV / historicalVolatility

Prefer useful elevated IV without rewarding extreme divergence indefinitely.

Architecture should allow later replacement with IV Rank / IV Percentile.

## Candidate Discovery Flow

    1. Load user portfolio
    2. Keep positions with at least 100 shares
    3. Fetch current quote
    4. Fetch historical OHLCV
    5. Fetch security metadata
    6. Fetch earnings and dividend metadata
    7. Calculate underlying metrics
    8. Fetch available expirations
    9. Keep expirations in configured DTE range
    10. Fetch option chains
    11. Keep CALL contracts
    12. Calculate per-contract analytics
    13. Apply hard filters
    14. Score passing candidates
    15. Sort passing candidates by score
    16. Determine suggested contract count
    17. Select primary and optional alternative contracts
    18. Return strategy-specific results

## Contract Quantity

Base eligibility:

    availableContracts = floor(shares / 100)

Coverage target:

    targetCoveredShares = shares * maximumCoveragePct

Recommended quantity should be the largest whole contract count that:

1. does not exceed availableContracts
2. does not materially exceed targetCoveredShares

For 500 shares at 50% target coverage, recommend 2 contracts rather than 3.

The UI should display both:

- eligible maximum contracts
- recommended contracts under current coverage preference

## Alternative Candidate Selection

### Primary

Highest Covered Call Setup Score.

### Lower Assignment Risk

Among passing contracts, prefer:

1. lower Estimated Delta
2. greater Expected_Move_Multiple
3. greater upside to strike

Require it to be meaningfully different from the primary candidate.

### Higher Income

Among passing contracts, prefer greater normalized premium yield while respecting all mandatory filters.

Do not simply choose the highest raw premium when expirations differ.

## UI Design

### Navigation

Recommended primary tabs:

- Watchlist
- Portfolio
- Analysis
- Results
- Settings

If five tabs make the current compact layout undesirable, Portfolio can initially be accessible from Analysis and promoted later. The domain layer should not depend on this UI decision.

### Portfolio screen

Capabilities:

- list positions
- add position
- edit shares
- edit average cost basis
- edit target sale price
- delete position
- show covered-call eligibility

### Analysis screen

Strategy picker should be registry-driven.

For Covered Call Strategy, show grouped settings:

1. Position
2. Underlying Quality
3. Option
4. Strike Safety
5. Events
6. Advanced / Scoring

Each hard filter should expose:

- enable/disable toggle where applicable
- threshold
- short explanation

Provide:

- Reset to Conservative Defaults

### Results

Do not force Covered Call output into AnalysisResultRow.

Introduce strategy-aware result rendering.

Recommended Covered Call summary card:

- ticker and share count
- setup score
- strike / expiration / DTE
- Estimated Delta
- premium per share and total premium
- premium yield
- upside to strike
- recommended contracts
- earnings status
- warning badges

Expanded details:

- cost basis
- target sale price
- effective sale price
- assignment gain
- OI / volume / spread
- IV / historical volatility
- Expected Move
- Expected-Move Multiple
- ATR / ATR Distance
- technical metrics
- score breakdown
- warnings
- filter explanations

## Persistence

### Covered Call configuration

Reuse ConfigurationRepository.

Add CoveredCallConfiguration.default conversion for strategyId "covered_call".

Refactor ConfigurationRepositoryImpl's defaultConfigurationProvider so defaults can be obtained from registered strategy metadata rather than adding repeated if/else cases for every future strategy.

### Portfolio

Follow existing local/cloud repository conventions.

Do not store broker credentials in PortfolioPosition.

## Scheduled Analysis

Version 1 Covered Calls are manual only.

Do not add Covered Call Strategy to Firebase scheduled analysis until:

1. interactive candidate logic is validated
2. portfolio persistence is stable
3. scoring has been reviewed with real data
4. notification presentation is defined

The existing scheduled analysis implementation must remain unaffected.

## Error Handling and Graceful Degradation

Failures are scoped as narrowly as possible.

- one option contract failure -> skip contract
- one expiration failure -> continue other expirations when possible
- one position failure -> continue other positions
- optional metadata failure -> warning or dependent-filter failure
- complete market-data failure -> position-level error

Never silently substitute zero for missing OI, option volume, IV, ATR, market cap, or delta when those values drive a filter.

## Cash-Secured Put Compatibility

The following components must remain direction-neutral where practical:

- SecurityMetadataService
- TechnicalIndicatorCalculating
- OptionAnalyticsCalculating
- EventRiskEvaluating
- generic filter result types
- configuration controls
- strategy execution framework

Covered-call-specific logic should remain in:

- CoveredCallConfiguration
- CoveredCallFiltering
- CoveredCallScoring
- CoveredCallStrategy
- CoveredCallResult UI

A future CashSecuredPutStrategy can then reuse shared analytics without copying the full pipeline.

## Testing Strategy

Maintain the project's existing strong property-test pattern.

Add:

1. model compatibility tests
2. Yahoo parsing tests for new option fields
3. OHLCV parsing tests
4. Portfolio validation tests
5. contract-count property tests
6. ATR property and unit tests
7. historical-volatility tests
8. average-volume tests
9. premium-yield tests
10. spread tests
11. expected-move tests
12. Black-Scholes delta tests against known values
13. hard-filter boundary tests for every configurable threshold
14. missing-data behavior tests
15. earnings-buffer tests
16. cost-basis and target-price protection tests
17. score component tests
18. total-score bounded 0-100 property
19. sorting stability tests
20. alternative-selection tests
21. multi-position integration tests
22. regression tests proving Weekly Option behavior remains unchanged

## Implementation Phases

### Phase 1: Data foundation

- Extend PricePoint
- Extend OptionContract
- Preserve Yahoo OHLCV / OI / volume / IV fields
- Add SecurityMetadata
- Add available-expiration API
- Add calculation services

### Phase 2: Portfolio

- PortfolioPosition
- PortfolioRepository
- PortfolioViewModel
- Portfolio UI
- persistence

### Phase 3: Multi-strategy execution

- Introduce ExecutableStrategy abstraction
- Adapt WeeklyOptionStrategy
- Make StrategyRegistry drive AnalysisView
- remove hard-coded WeeklyOption dependencies from AnalysisViewModel where practical

### Phase 4: Covered Call strategy

- CoveredCallConfiguration
- event-risk evaluator
- filter engine
- scoring engine
- candidate discovery
- alternative selection

### Phase 5: Results and configuration UI

- Covered Call configuration form
- strategy-aware results
- score explanation
- warning/exclusion presentation

### Phase 6: Validation and regression

- unit tests
- property tests
- integration tests
- Weekly Option regression tests
- performance/rate-limit checks

## Future Work

- Cash-Secured Put Strategy
- Wheel Strategy
- brokerage synchronization
- active trade tracking
- automatic roll/close suggestions
- scheduled Covered Call scans
- broker-provided Greeks
- persisted IV history and IV Rank / Percentile
