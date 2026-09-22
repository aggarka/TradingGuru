# Requirements Document: Covered Call Strategy

## Introduction

The Covered Call Strategy extends TradingGuru with a portfolio-aware options strategy for users who own at least 100 shares of an eligible security.

Unlike the existing Weekly Option Strategy, which analyzes watchlist securities and historical price movement, the Covered Call Strategy evaluates CALL options against positions actually owned by the user. It applies configurable stock-quality, event-risk, option-liquidity, volatility, strike-distance, premium, and assignment-risk criteria before ranking candidate contracts.

TradingGuru remains an educational and analysis tool. This feature does not execute trades.

## Goals

1. Identify covered-call opportunities only for securities the user owns.
2. Prevent high premium alone from causing a risky contract to rank highly.
3. Apply configurable hard filters before scoring candidates.
4. Rank passing candidates using a transparent 0-100 Covered Call Setup Score.
5. Reuse TradingGuru's existing Yahoo Finance, options-chain, configuration, authentication, persistence, and strategy architecture.
6. Build shared components that can later support Cash-Secured Put and Wheel strategies.

## Glossary

- **Portfolio_Position**: A user-owned security position containing ticker, share quantity, optional average cost basis, and optional target sale price.
- **Covered_Call_Strategy**: A strategy that evaluates CALL contracts against securities the user owns.
- **DTE**: Calendar days to option expiration.
- **Estimated_Delta**: TradingGuru-calculated call delta used for screening when broker-provided Greeks are unavailable.
- **Premium_Yield**: Option premium per share divided by current underlying price.
- **Expected_Move**: Estimated price movement derived from implied volatility and time to expiration.
- **Expected_Move_Multiple**: Distance from current stock price to strike divided by Expected_Move.
- **ATR**: Average True Range over a configurable historical period.
- **ATR_Distance**: Distance from current stock price to strike divided by ATR.
- **Hard_Filter**: A rule that excludes a candidate before scoring.
- **Warning**: A condition surfaced to the user but not necessarily excluding a trade.
- **Covered_Call_Setup_Score**: A 0-100 score calculated only after all enabled hard filters pass.
- **Effective_Sale_Price**: Strike price plus option premium per share.
- **Assignment_Risk**: A descriptive low/medium/high indicator based on transparent strategy metrics; it is not a guarantee of assignment probability.
- **Strategy_Configuration**: User-specific configuration persisted through TradingGuru's existing generic configuration repository.

## Requirements

### Requirement 1: Portfolio Position Management

**User Story:** As a user, I want to record the securities I own so that TradingGuru can analyze legitimate covered-call opportunities.

#### Acceptance Criteria

1. THE App SHALL provide a Portfolio containing user-owned positions.
2. EACH Portfolio_Position SHALL contain ticker and share quantity.
3. EACH Portfolio_Position SHOULD contain average cost basis per share.
4. EACH Portfolio_Position MAY contain an optional target sale price.
5. A position SHALL require at least 100 shares to be eligible for a covered-call recommendation.
6. ONE standard option contract SHALL represent 100 shares.
7. THE App SHALL calculate the maximum eligible contract count as floor(shares / 100).
8. THE App SHALL initially support manual position entry and editing.
9. Portfolio storage SHALL be abstracted behind a repository interface so brokerage synchronization can be added later without changing strategy logic.
10. Portfolio positions SHALL be persisted per authenticated user.
11. IF cost basis is unavailable, THEN cost-basis-dependent filters SHALL be skipped and the UI SHALL indicate that cost basis was unavailable.

### Requirement 2: Covered Call Strategy Registration

**User Story:** As a user, I want Covered Call Strategy to appear as a distinct TradingGuru strategy so that I can analyze my owned positions separately from the existing Weekly Option Strategy.

#### Acceptance Criteria

1. THE App SHALL register a strategy named "Covered Call Strategy".
2. THE strategy identifier SHALL be "covered_call".
3. THE existing Weekly Option Strategy SHALL remain available.
4. THE Covered Call Strategy SHALL operate on Portfolio positions rather than the general Watchlist.
5. THE Analysis screen SHOULD obtain available strategies from the existing StrategyRegistry rather than a hard-coded strategy array.
6. THE strategy architecture SHALL permit future Cash-Secured Put and Wheel strategies without duplicating the complete execution pipeline.

### Requirement 3: Configurable Underlying Filters

**User Story:** As a user, I want stock-quality thresholds to be configurable so that I can adjust how conservative the Covered Call Strategy is.

#### Acceptance Criteria

1. THE strategy SHALL support an enabled/disabled state for applicable filters.
2. THE default minimum market capitalization SHALL be $10 billion for individual equities.
3. THE default minimum stock price SHALL be $20.
4. THE default minimum average daily share volume SHALL be 1,000,000.
5. THE default average-volume lookback SHALL be 30 trading days.
6. THE default maximum annualized historical volatility SHALL be 60%.
7. THE default historical-volatility lookback SHALL be 30 trading days.
8. THE default ATR period SHALL be 14 trading days.
9. THE default maximum ATR as a percentage of stock price SHALL be 5%.
10. Leveraged ETFs SHALL be excluded by default.
11. Individual stocks SHALL be allowed by default.
12. Non-leveraged ETFs SHALL be allowed by default.
13. Market-cap filtering SHALL apply to individual equities and SHALL NOT fail an ETF solely because market capitalization is not applicable.

### Requirement 4: Configurable Option Filters

**User Story:** As a user, I want option-contract liquidity and risk parameters to be configurable so that I can control the types of contracts TradingGuru considers.

#### Acceptance Criteria

1. THE default minimum DTE SHALL be 7 days.
2. THE default maximum DTE SHALL be 14 days.
3. THE default minimum absolute call delta SHALL be 0.10.
4. THE default maximum absolute call delta SHALL be 0.20.
5. THE strategy SHALL require OTM calls by default.
6. THE default minimum open interest SHALL be 500 contracts.
7. THE default minimum daily option volume SHALL be 50 contracts.
8. THE default maximum bid/ask spread percentage SHALL be 10%.
9. THE preferred bid/ask spread SHALL be 5% or less.
10. THE default minimum premium yield SHALL be 0.20%.
11. THE preferred premium yield SHALL be 0.30% or greater.
12. Contracts with a zero or invalid midpoint SHALL fail liquidity validation.

### Requirement 5: Configurable Strike-Safety Filters

**User Story:** As a user, I want strikes to provide sufficient upside and statistical distance so that I do not sell calls too close to normal stock movement.

#### Acceptance Criteria

1. THE default minimum Expected_Move_Multiple SHALL be 1.00x.
2. THE preferred Expected_Move_Multiple SHALL be 1.25x or greater.
3. THE default minimum ATR_Distance SHALL be 1.00x.
4. THE preferred ATR_Distance SHALL be 1.25x or greater.
5. THE default minimum upside from current stock price to strike SHALL be 3%.
6. "Do not suggest strikes below cost basis" SHALL be enabled by default.
7. WHEN a Portfolio_Position has a target sale price, "respect target sale price" SHALL be enabled by default.
8. WHEN cost-basis protection is enabled and cost basis exists, calls with strike below average cost basis SHALL fail the hard filter.
9. WHEN target-sale-price protection is enabled and a target exists, calls with strike below target sale price SHALL fail the hard filter.

### Requirement 6: Configurable Event-Risk Filters

**User Story:** As a user, I want TradingGuru to account for known events before expiration so that event-driven price risk is not hidden by premium.

#### Acceptance Criteria

1. Earnings between the analysis date and expiration SHALL be excluded by default.
2. THE default earnings buffer SHALL be 1 trading day.
3. An ex-dividend date before expiration SHALL produce a warning by default.
4. WHEN major corporate-event data is available, THE App SHALL surface a warning or exclusion according to configuration.
5. Failure to retrieve optional event metadata SHALL NOT terminate analysis of other positions.
6. Event-risk status SHALL be shown in candidate details.

### Requirement 7: Position Coverage Parameters

**User Story:** As a user, I want to limit how much of my position is overwritten so that I can preserve some upside exposure.

#### Acceptance Criteria

1. THE default target maximum shares covered SHALL be 50%.
2. THE strategy SHALL never recommend more contracts than floor(shares / 100).
3. Recommended contract quantity SHALL respect the configured coverage percentage as closely as possible without exceeding it.
4. THE UI SHALL clearly indicate when the configured coverage percentage results in zero recommended contracts even though the position has at least 100 shares.
5. THE user MAY configure coverage up to 100%.

### Requirement 8: Enhanced Historical Market Data

**User Story:** As the strategy engine, I need OHLCV data so that ATR, volume, volatility, and technical metrics can be calculated reliably.

#### Acceptance Criteria

1. Historical price data SHALL support date, open, high, low, close, and volume when available.
2. Existing components that depend only on closing price SHALL continue to work.
3. YahooFinanceService SHALL preserve OHLCV values already present in the Yahoo chart response.
4. Missing optional OHLCV fields SHALL be represented explicitly rather than silently replaced with fabricated values.
5. Historical calculations SHALL document how missing observations are handled.

### Requirement 9: Enhanced Option Contract Data

**User Story:** As the strategy engine, I need option liquidity and volatility fields so that covered-call candidates can be filtered and scored.

#### Acceptance Criteria

1. OptionContract SHALL retain contract symbol when available.
2. OptionContract SHALL retain last price when available.
3. OptionContract SHALL retain daily volume when available.
4. OptionContract SHALL retain open interest when available.
5. OptionContract SHALL retain implied volatility when available.
6. OptionContract SHALL retain in-the-money status when available.
7. OptionContract SHALL retain last trade date when available.
8. Existing strike, bid, ask, expiration, ticker, type, and mid-price behavior SHALL remain backward compatible.
9. YahooFinanceService SHALL preserve these fields from the existing Yahoo options response.

### Requirement 10: Security Metadata

**User Story:** As the strategy engine, I need basic security metadata so that stock-quality, asset-type, and dividend-related filters can be evaluated.

#### Acceptance Criteria

1. TradingGuru SHALL support market capitalization for individual equities when available.
2. TradingGuru SHALL support security or quote type when available.
3. TradingGuru SHOULD support first trade date when available.
4. TradingGuru SHOULD support ex-dividend date and dividend yield when available.
5. Missing supplementary metadata SHALL NOT terminate the entire strategy run.
6. IF a hard filter depends on unavailable required data, THEN the candidate SHALL be excluded with a machine-readable reason rather than silently passing.

### Requirement 11: Estimated Delta Calculation

**User Story:** As a user, I want delta-based filtering even when Yahoo does not provide option Greeks directly.

#### Acceptance Criteria

1. TradingGuru SHALL calculate an estimated call delta when sufficient inputs are available.
2. The calculation SHALL use underlying price, strike price, time to expiration, implied volatility, risk-free rate, and dividend yield when available.
3. The UI SHALL identify the value as "Estimated Delta".
4. IF delta cannot be calculated and the delta filter is enabled, THEN the contract SHALL fail the hard filter.
5. The delta calculation SHALL be isolated behind a protocol so broker- or provider-supplied Greeks can replace it later.
6. The risk-free-rate input SHALL be configurable or supplied by a replaceable provider; Version 1 MAY use a documented default rate.

### Requirement 12: Derived Risk Metrics

**User Story:** As a user, I want transparent metrics explaining why a covered-call candidate passed or failed.

#### Acceptance Criteria

1. Premium_Yield SHALL equal option midpoint divided by current stock price.
2. Bid/Ask Spread % SHALL equal (ask - bid) / ((ask + bid) / 2).
3. Expected_Move SHALL equal currentPrice × IV × sqrt(DTE / 365) using an appropriate implied-volatility input.
4. Expected_Move_Multiple SHALL equal (strike - currentPrice) / Expected_Move.
5. ATR_Distance SHALL equal (strike - currentPrice) / ATR.
6. Historical volatility SHALL be calculated from daily returns over the configured lookback and annualized.
7. Upside to strike SHALL equal (strike - currentPrice) / currentPrice.
8. Effective_Sale_Price SHALL equal strike plus option premium per share.
9. WHEN cost basis exists, assignment gain per share SHALL equal Effective_Sale_Price minus average cost basis.
10. Metric calculations SHALL be unit-testable independently from network access.

### Requirement 13: Hard Filtering

**User Story:** As a user, I want clearly unacceptable trades removed before scoring so that a high premium cannot compensate for a failed safety rule.

#### Acceptance Criteria

1. Hard filters SHALL execute before the score is calculated.
2. An option SHALL be excluded when any enabled hard filter fails.
3. Default hard filters SHALL include:
   - insufficient shares
   - stock price below minimum
   - equity market cap below minimum when applicable
   - average daily volume below minimum
   - excluded leveraged ETF
   - DTE outside configured range
   - call not OTM
   - estimated delta outside configured range
   - earnings within blackout period
   - open interest below minimum
   - option volume below minimum
   - bid/ask spread above maximum
   - premium yield below minimum
   - Expected_Move_Multiple below minimum
   - ATR_Distance below minimum
   - upside to strike below minimum
   - strike below cost basis when enabled
   - strike below target sale price when enabled
4. EACH rejected candidate SHALL retain one or more machine-readable exclusion reasons.
5. The UI SHALL be able to present a user-readable explanation for each exclusion reason.

### Requirement 14: Candidate Discovery

**User Story:** As a user, I want TradingGuru to evaluate all relevant calls for my positions rather than choosing a contract only by premium.

#### Acceptance Criteria

1. FOR EACH eligible Portfolio_Position, TradingGuru SHALL identify available expirations within the configured DTE range.
2. TradingGuru SHALL fetch CALL option chains only for eligible expirations.
3. TradingGuru SHALL evaluate all eligible OTM CALL contracts returned for those expirations.
4. TradingGuru SHALL calculate required analytics for each candidate.
5. TradingGuru SHALL apply enabled hard filters.
6. TradingGuru SHALL score all passing candidates.
7. TradingGuru SHALL sort passing candidates by Covered_Call_Setup_Score descending by default.
8. Multiple passing contracts MAY be returned for one ticker.
9. Failure analyzing one position SHALL NOT terminate analysis of other positions.

### Requirement 15: Covered Call Setup Score

**User Story:** As a user, I want passing candidates ranked by a transparent score so that I can compare tradeoffs rather than simply chasing premium.

#### Acceptance Criteria

1. Only candidates passing all enabled hard filters SHALL receive a final score.
2. The final score SHALL be bounded between 0 and 100.
3. Default category weights SHALL be:
   - Assignment / Strike Safety: 25
   - Option Liquidity: 20
   - Underlying Quality: 15
   - Premium Efficiency: 15
   - Technical Cushion: 15
   - Volatility Quality: 10
4. Delta SHALL contribute up to 12 points within Assignment / Strike Safety.
5. Expected-move distance SHALL contribute up to 13 points within Assignment / Strike Safety.
6. Option Liquidity SHALL consider open interest, option volume, and bid/ask spread.
7. Underlying Quality SHALL consider market capitalization when applicable, underlying liquidity, historical volatility, and ATR stability.
8. Premium Efficiency SHALL reward useful premium but SHALL NOT increase indefinitely with premium yield.
9. Extremely high weekly premium MAY receive a lower score than moderately high premium when it indicates elevated risk.
10. Technical Cushion SHALL consider ATR distance and MAY include resistance/trend metrics.
11. Volatility Quality SHALL use IV percentile when reliable historical IV exists.
12. Version 1 MAY use current IV relative to realized volatility when historical IV percentile is unavailable.
13. The UI SHALL expose the category score breakdown.

### Requirement 16: Candidate Classification and Alternatives

**User Story:** As a user, I want a few clearly differentiated candidates so that I can choose between lower assignment risk and higher income.

#### Acceptance Criteria

1. TradingGuru SHALL identify the highest-scoring passing contract as the primary candidate for a position.
2. WHEN sufficient candidates exist, TradingGuru SHOULD also identify:
   - Lower Assignment Risk
   - Higher Income
3. Alternative candidates SHALL pass mandatory hard filters unless the UI clearly labels an exception.
4. The UI SHALL NOT describe any candidate as guaranteed or "safe".
5. Assignment risk MAY be displayed as Low, Medium, or High using documented metric thresholds.

### Requirement 17: Results Display

**User Story:** As a user, I want enough detail to understand the economics and risks of each recommendation.

#### Acceptance Criteria

1. Covered Call results SHALL display ticker and shares owned.
2. Covered Call results SHALL display suggested contract quantity.
3. Covered Call results SHALL display current stock price.
4. Cost basis and target sale price SHALL display when available.
5. Results SHALL display expiration, DTE, strike, bid, ask, midpoint, and total estimated premium.
6. Results SHALL display premium yield, Estimated Delta, open interest, option volume, spread %, and implied volatility.
7. Results SHALL display Expected_Move, Expected_Move_Multiple, ATR, ATR_Distance, and upside to strike.
8. Results SHALL display Effective_Sale_Price and assignment gain relative to cost basis when available.
9. Results SHALL display earnings status and ex-dividend warning when applicable.
10. Results SHALL display Covered_Call_Setup_Score and category breakdown.
11. Results SHALL display warning flags and exclusion information in a user-readable format.
12. Covered Call results SHALL use a strategy-aware result presentation rather than forcing every field into the existing Weekly Option result table.

### Requirement 18: Configuration Persistence

**User Story:** As a user, I want my Covered Call settings to persist across sessions.

#### Acceptance Criteria

1. Covered Call configuration SHALL use the existing StrategyConfiguration and ConfigurationRepository architecture.
2. The strategy SHALL define default configuration values for "covered_call".
3. Configuration SHALL persist per authenticated user.
4. "Reset to Conservative Defaults" SHALL restore the documented default values.
5. Configuration loading failure SHALL fall back to defaults using existing TradingGuru persistence behavior.

### Requirement 19: Version 1 Scope

**User Story:** As a product owner, I want the first Covered Call release focused enough to validate the strategy before adding automation.

#### Acceptance Criteria

1. Version 1 SHALL support manual Covered Call analysis.
2. Version 1 SHALL NOT place brokerage orders.
3. Version 1 SHALL NOT automatically roll or close options.
4. Version 1 SHALL NOT infer that a recommended contract was actually traded.
5. Version 1 SHALL NOT require scheduled backend Covered Call analysis.
6. Brokerage synchronization, active trade management, scheduled Covered Call scans, broker-provided Greeks, Cash-Secured Puts, and Wheel automation SHALL remain future capabilities.
