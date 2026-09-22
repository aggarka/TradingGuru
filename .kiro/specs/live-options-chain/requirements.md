# Requirements Document

## Introduction

The Live Options Chain Integration is an enhancement to the existing Weekly Option Strategy in the TradingGuru iOS app. This feature extends the Yahoo Finance service to fetch real-time options chain data, enabling the strategy to identify specific option contracts (with strike prices and premiums) that meet the user's trading criteria. The new signal logic compares live option strikes against historically-derived target prices to determine whether selling covered calls or cash-secured puts is statistically safe based on past price behavior.

## Glossary

- **Options_Chain**: A listing of all available option contracts for a given ticker symbol and expiration date, including calls and puts at various strike prices with their bid and ask prices
- **Strike_Price**: The price at which an option contract can be exercised; for calls, the price at which the holder can buy the underlying stock; for puts, the price at which the holder can sell
- **Option_Premium**: The price of an option contract, calculated as the mid-price between the bid and ask prices: `mid_price = (bid + ask) / 2`
- **EXPIRATION**: Configuration parameter specifying the options expiration date; defaults to the next weekly expiration (typically Friday), session-overridable
- **Weekly_Expiration**: The Friday of each week when weekly options contracts expire; if Friday is a market holiday, the expiration moves to the previous open market day (typically Thursday)
- **Market_Holiday**: A day when US stock markets are closed (e.g., New Year's Day, Independence Day, Thanksgiving)
- **PREMIUM_PCT**: Configuration parameter specifying the target premium as a percentage of the current stock price (default: 0.5% = 0.005); used to find options with premiums closest to this target value
- **Call_Target**: The target price above which it is historically safe to sell a covered call, calculated as: `current_price × (1 + best_return_percentage / 100)` where best_return_percentage is the maximum rolling window return
- **Put_Target**: The target price below which it is historically safe to sell a cash-secured put, calculated as: `current_price × (1 + worst_return_percentage / 100)` where worst_return_percentage is the minimum rolling window return
- **CALL_ORDER_Signal**: Generated when an option's strike price is greater than the call_target, indicating the stock has historically never gained enough to reach that strike within the lookback period
- **PUT_ORDER_Signal**: Generated when an option's strike price is less than the put_target, indicating the stock has historically never dropped enough to reach that strike within the lookback period
- **HOLD_Signal**: Generated when the option's strike price does not meet the ORDER criteria, indicating the trade may not be statistically safe
- **Session**: A single instance of app usage from launch to termination; session-specific settings reset when the app is relaunched
- **Yahoo_Finance_Service**: The existing service component that fetches market data from Yahoo Finance API, to be extended with options chain capabilities

## Requirements

### Requirement 1: Options Chain Data Fetching

**User Story:** As a user, I want the app to fetch live options chain data from Yahoo Finance, so that I can see actual option contracts with real bid/ask prices for my analysis.

#### Acceptance Criteria

1. WHEN the Weekly_Option_Strategy executes for a ticker, THE Yahoo_Finance_Service SHALL fetch the options chain data for that ticker and the configured EXPIRATION date
2. THE Yahoo_Finance_Service SHALL retrieve both call and put option contracts at all available strike prices for the specified expiration date
3. FOR EACH option contract retrieved, THE Yahoo_Finance_Service SHALL include the strike price, bid price, and ask price
4. IF the options chain data cannot be retrieved for a ticker, THEN THE Yahoo_Finance_Service SHALL return an error indicating options data unavailable and THE Strategy SHALL continue processing remaining tickers
5. IF no options contracts exist for the specified expiration date, THEN THE Yahoo_Finance_Service SHALL return an empty options chain and THE Strategy SHALL display a message indicating no options available for that expiration
6. THE Yahoo_Finance_Service SHALL calculate the mid-price for each option using the formula: `mid_price = (bid + ask) / 2`

### Requirement 2: Default Expiration Date Calculation

**User Story:** As a user, I want the app to automatically select the next weekly options expiration date, so that I don't have to manually determine which Friday to use.

#### Acceptance Criteria

1. WHEN no user override is specified, THE System SHALL calculate the default EXPIRATION as the next Friday from the current date
2. IF the next Friday is a US market holiday, THEN THE System SHALL set the default EXPIRATION to the Thursday immediately preceding that Friday
3. THE System SHALL recognize the following dates as US market holidays when they fall on a Friday: New Year's Day (January 1), Good Friday, Independence Day (July 4), Thanksgiving Day (fourth Thursday of November), and Christmas Day (December 25)
4. IF Independence Day (July 4) or Christmas Day (December 25) falls on a Saturday, THEN THE System SHALL treat the preceding Friday as a market holiday
5. IF New Year's Day (January 1) falls on a Saturday, THEN THE System SHALL treat the preceding Friday (December 31) as a market holiday
6. WHEN calculating the next weekly expiration, THE System SHALL skip to the following week's Friday if today is Saturday or Sunday

### Requirement 3: User Expiration Date Override

**User Story:** As a user, I want to override the default expiration date for my current session, so that I can analyze options for a specific expiration when needed.

#### Acceptance Criteria

1. THE App SHALL provide a date picker control allowing users to select a custom EXPIRATION date
2. WHEN a user selects a custom EXPIRATION date, THE System SHALL use that date for all subsequent analyses in the current session
3. THE App SHALL display the currently selected EXPIRATION date in the configuration interface
4. WHEN the app is terminated and relaunched, THE System SHALL reset the EXPIRATION to the calculated default value, discarding any user override from the previous session
5. IF the reference date for validation is ambiguous or unavailable, THEN THE System SHALL proceed with validation using the next available market day as the reference date
6. THE App SHALL validate that user-selected EXPIRATION dates are valid trading days by verifying the date falls on a weekday AND the exchange is open for trading (excluding market holidays and exchange closures)
7. IF a user selects an invalid EXPIRATION date (weekend, market holiday, or exchange closure), THEN THE App SHALL display an error message indicating the market is closed on that date and not accept the invalid date

### Requirement 4: Target Premium Matching

**User Story:** As a user, I want the app to find option contracts with premiums closest to my target premium percentage, so that I can identify options that meet my income goals.

#### Acceptance Criteria

1. WHEN analyzing options for a ticker, THE Strategy SHALL calculate the target premium amount using the formula: `target_premium = current_price × PREMIUM_PCT`
2. FOR EACH ticker, THE Strategy SHALL identify the call option with mid-price closest to the target premium amount
3. FOR EACH ticker, THE Strategy SHALL identify the put option with mid-price closest to the target premium amount
4. WHEN multiple options have the same distance from the target premium, THE Strategy SHALL select the option with the lower strike price for puts and the higher strike price for calls
5. THE Strategy SHALL use the PREMIUM_PCT value from the existing configuration (default: 0.5% = 0.005, range: 0.1% to 5.0%)

### Requirement 5: Signal Generation Based on Historical Targets

**User Story:** As a user, I want to see ORDER signals only when an option's strike price is beyond the historical price movement range, so that I can identify statistically safe options to sell.

#### Acceptance Criteria

1. WHEN generating signals for a call option, THE Strategy SHALL calculate the call_target using the formula: `call_target = current_price × (1 + best_return_percentage / 100)` where best_return_percentage is the maximum rolling window return from the historical analysis
2. WHEN generating signals for a put option, THE Strategy SHALL calculate the put_target using the formula: `put_target = current_price × (1 + worst_return_percentage / 100)` where worst_return_percentage is the minimum rolling window return from the historical analysis
3. IF the selected call option's strike price is greater than or equal to call_target, THEN THE Strategy SHALL generate a CALL_ORDER signal for that ticker
4. IF the selected call option's strike price is less than call_target, THEN THE Strategy SHALL generate a HOLD signal for the call opportunity
5. IF the selected put option's strike price is less than or equal to put_target, THEN THE Strategy SHALL generate a PUT_ORDER signal for that ticker
6. IF the selected put option's strike price is greater than put_target, THEN THE Strategy SHALL generate a HOLD signal for the put opportunity

### Requirement 6: Enhanced Results Display

**User Story:** As a user, I want to see the selected strike price, expiration date, and option premium details (bid, ask, mid) in the results table, so that I can quickly identify which contracts to trade.

#### Acceptance Criteria

1. THE App SHALL add an Expiration Date column to the results table displaying the option expiration date, formatted as YYYY-MM-DD
2. THE App SHALL add a Strike Price column to the results table displaying the strike price of the selected option, formatted as currency with 2 decimal places
3. THE App SHALL add a Bid Premium column to the results table displaying the bid price of the selected option, formatted as currency with 2 decimal places
4. THE App SHALL add an Ask Premium column to the results table displaying the ask price of the selected option, formatted as currency with 2 decimal places
5. THE App SHALL add a Mid Premium column to the results table displaying the mid-price of the selected option (calculated as (bid + ask) / 2), formatted as currency with 2 decimal places
6. THE results table SHALL maintain the existing columns: Ticker, Type (CALL/PUT), Return Percentage, Current Price, Target Price, Signal, and Next Earnings Date
7. THE results table column order SHALL be: Ticker, Type, Expiration Date, Strike Price, Bid Premium, Ask Premium, Mid Premium, Return Percentage, Current Price, Target Price, Signal, Next Earnings Date
8. THE App SHALL allow users to sort results by the new Strike Price column
9. THE App SHALL allow users to sort results by the new Mid Premium column
10. IF the options chain for a ticker is completely empty (no contracts returned), THEN THE App SHALL display "N/A" in the Expiration Date, Strike Price, Bid Premium, Ask Premium, and Mid Premium columns for that ticker
11. IF the options chain contains contracts but the selected option has invalid or malformed data, THEN THE App SHALL display the data as-is in the option-related columns

### Requirement 7: ONLY_ORDERS Filter Compatibility

**User Story:** As a user, I want the ONLY_ORDERS filter to work with the new signal logic, so that I can focus on actionable trading opportunities.

#### Acceptance Criteria

1. WHEN ONLY_ORDERS is enabled, THE App SHALL display only rows where the Signal column shows ORDER (either CALL_ORDER or PUT_ORDER), and this filter SHALL take precedence over all other display conditions
2. WHILE ONLY_ORDERS is enabled, THE App SHALL NOT filter out PUT_ORDER or CALL_ORDER rows based on any other filtering conditions
3. WHEN ONLY_ORDERS is disabled, THE App SHALL display all analysis results including CALL_ORDER, PUT_ORDER, and HOLD signals
4. THE existing ONLY_ORDERS toggle behavior SHALL remain unchanged from the current implementation

