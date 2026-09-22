# Requirements Document

## Introduction

TradingGuru is an iOS stock trading analysis application that enables users to run customizable trading strategies on their personal stock watchlists. The app supports multiple authentication providers (Google, Apple, Passkey), allows users to manage stock symbols, configure strategy parameters, and view analysis results in tabular format. The first supported strategy is the Weekly Option Strategy, which analyzes historical price data to identify CALL and PUT opportunities based on rolling window returns.

## Glossary

- **User**: An authenticated individual using the TradingGuru application
- **Strategy**: A trading algorithm that analyzes stock data to generate trading signals (CALL/PUT recommendations)
- **Stock_Watchlist**: A user-defined list of stock ticker symbols to analyze
- **Weekly_Option_Strategy**: A strategy that calculates rolling window returns over historical price data to identify optimal CALL and PUT entry points
- **WINDOW_DAYS**: Configuration parameter specifying the number of days for the rolling return calculation (1, 5, or 30)
- **LOOKBACK_DAYS**: Configuration parameter specifying the historical period to analyze (30, 60, 90, 180, or 360 days)
- **PREMIUM_PCT**: Configuration parameter specifying the target option premium as a percentage of the current stock price (0.1% to 5.0%, default 0.5%), used to find options with premiums closest to this target value
- **ONLY_ORDERS**: Configuration parameter (boolean toggle) that when enabled filters the analysis results to display only rows with ORDER signals, hiding HOLD results (default: false, showing all results)
- **Analysis_Result**: The output of a strategy execution containing ticker, type (CALL/PUT), return percentage, current price, target price, signal, and next earnings date
- **Next_Earnings_Date**: The upcoming earnings announcement date for a stock ticker, retrieved from Yahoo Finance; displayed in red if it falls on or before the option expiration date to warn of potential volatility risk
- **Authentication_Provider**: External identity service (Google, Apple, or Passkey) used to verify user identity
- **Strategy_Configuration**: User-specific parameter settings for a particular strategy
- **Data_Service**: Component responsible for fetching stock price data from Yahoo Finance
- **Scheduled_Analysis**: Automated execution of strategy analysis at predefined times (6:30 AM, 6:45 AM, 7:00 AM, 9:00 AM, 11:00 AM, 12:30 PM, 12:45 PM PST)
- **Email_Notification**: An email message sent to users containing the formatted analysis results table after each scheduled analysis run
- **Notification_Email_Address**: User-configured email address for receiving analysis result notifications

## Requirements

### Requirement 1: User Authentication

**User Story:** As a user, I want to sign in using my Google, Apple, or Passkey credentials, so that I can securely access my personal data without creating a new account.

#### Acceptance Criteria

1. WHEN the app launches for an unauthenticated user, THE App SHALL display authentication options for Google Sign-In, Apple Sign-In, and Passkey authentication
2. WHEN a user selects Google Sign-In, THE Authentication_Provider SHALL initiate the Google OAuth flow and return user credentials upon success within 60 seconds
3. WHEN a user selects Apple Sign-In, THE Authentication_Provider SHALL initiate the Apple Sign-In flow and return user credentials upon success within 60 seconds
4. WHEN a user selects Passkey authentication, THE Authentication_Provider SHALL initiate the Passkey authentication flow and return user credentials upon success within 60 seconds
5. WHEN authentication succeeds, THE App SHALL create or retrieve the user profile from the database and navigate to the home screen
6. IF authentication fails, THEN THE App SHALL display an error message indicating the failure category (invalid credentials, network error, or provider unavailable) and remain on the authentication screen
7. IF the authentication flow does not complete within 60 seconds, THEN THE App SHALL cancel the authentication attempt, display an error message indicating timeout, and return to the authentication screen
8. IF user profile creation or retrieval fails after successful authentication, THEN THE App SHALL display an error message indicating the profile operation failed and allow the user to retry
9. WHILE a user is authenticated, THE App SHALL maintain the session for up to 30 days of inactivity and provide access to protected features
10. WHEN a user taps the sign-out button, THE App SHALL clear the session and return to the authentication screen

### Requirement 2: Stock Watchlist Management

**User Story:** As a user, I want to create and manage my personal stock watchlist, so that I can track and analyze the stocks I am interested in.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to the watchlist screen, THE App SHALL display a loading indicator while retrieving data, then display the user's current stock watchlist retrieved from the database
2. WHEN a user enters a stock ticker symbol consisting of 1 to 5 uppercase letters and taps add, THE Stock_Watchlist SHALL add the symbol to the user's watchlist and persist it to the database
3. IF a user attempts to add an invalid ticker symbol that does not match the 1 to 5 uppercase letter format, THEN THE App SHALL display an error message indicating the invalid format and not modify the watchlist
4. IF a user attempts to add a ticker symbol that already exists in the watchlist, THEN THE App SHALL display an error message indicating the symbol is a duplicate and not modify the watchlist
5. IF the user's watchlist contains 50 symbols and the user attempts to add another symbol, THEN THE App SHALL display an error message indicating the watchlist limit has been reached and not modify the watchlist
6. WHEN a user swipes to delete a stock symbol, THE Stock_Watchlist SHALL remove the symbol from the user's watchlist and update the database
7. THE Stock_Watchlist SHALL display each ticker symbol in a list format with the option to remove individual items
8. WHEN the watchlist is empty, THE App SHALL display an empty state message prompting the user to add stocks
9. IF the database is unavailable when retrieving or modifying the watchlist, THEN THE App SHALL display an error message indicating the operation failed and preserve any local watchlist state

### Requirement 3: Strategy Selection

**User Story:** As a user, I want to select a trading strategy from a dropdown, so that I can run different analysis algorithms on my watchlist.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to the analysis screen, THE App SHALL display a strategy selection dropdown populated with available strategies and a placeholder prompt indicating no strategy is selected
2. THE App SHALL include Weekly_Option_Strategy as an available strategy option
3. WHEN a user selects a strategy from the dropdown, THE App SHALL load and display the configuration interface for that strategy within 2 seconds
4. IF the configuration interface fails to load after a user selects a strategy, THEN THE App SHALL display an error message indicating the failure and allow the user to retry or select a different strategy
5. THE App SHALL implement strategies through a common strategy interface, enabling new strategies to be added by creating a new implementation without modifying existing strategy code
6. WHEN no strategy is selected, THE App SHALL disable the run analysis button

### Requirement 4: Strategy Configuration

**User Story:** As a user, I want to configure strategy parameters like WINDOW_DAYS, LOOKBACK_DAYS, PREMIUM_PCT, and ONLY_ORDERS, so that I can customize the analysis to my trading preferences.

#### Acceptance Criteria

1. WHEN a user selects Weekly_Option_Strategy, THE App SHALL display configuration options for WINDOW_DAYS, LOOKBACK_DAYS, PREMIUM_PCT, and ONLY_ORDERS as user-selectable controls
2. THE App SHALL provide WINDOW_DAYS options of 1, 5, and 30 days as selectable values
3. THE App SHALL provide LOOKBACK_DAYS options of 30, 60, 90, 180, and 360 days as selectable values
4. THE App SHALL provide PREMIUM_PCT as a numeric input field accepting values from 0.1% to 5.0% in 0.1% increments, representing the target option premium as a percentage of the current stock price
5. THE App SHALL provide ONLY_ORDERS as a toggle switch that when enabled filters the results to show only rows with ORDER signals, and when disabled shows all results
6. WHEN a user modifies a configuration value, THE Strategy_Configuration SHALL persist the new value to the database for that user and display a confirmation indicator upon successful save
7. WHEN a user returns to the configuration screen, THE App SHALL load previously saved configuration values from the database
8. IF no saved configuration exists for a user, THEN THE App SHALL apply default values of WINDOW_DAYS=5, LOOKBACK_DAYS=180, PREMIUM_PCT=0.5%, and ONLY_ORDERS=false
9. IF the database save operation fails, THEN THE App SHALL display an error message indicating the save failed and retain the user's selected values in the interface
10. IF the database load operation fails, THEN THE App SHALL display an error message indicating configuration could not be loaded and apply default values of WINDOW_DAYS=5, LOOKBACK_DAYS=180, PREMIUM_PCT=0.5%, and ONLY_ORDERS=false
11. IF a user enters a PREMIUM_PCT value outside the valid range of 0.1% to 5.0%, THEN THE App SHALL display an error message indicating the valid range and not save the invalid value

### Requirement 5: Weekly Option Strategy Execution

**User Story:** As a user, I want to run the Weekly Option Strategy on my watchlist, so that I can identify potential CALL and PUT opportunities.

#### Acceptance Criteria

1. WHEN a user taps run analysis with Weekly_Option_Strategy selected, THE Data_Service SHALL fetch historical price data from Yahoo Finance for each ticker in the user's watchlist, retrieving closing prices for the configured LOOKBACK_DAYS period (default: 180 days)
2. WHEN price data is retrieved for a ticker, THE Weekly_Option_Strategy SHALL calculate rolling window returns by computing the percentage change in closing price over the configured WINDOW_DAYS period (default: 5 days) for each trading day in the lookback period
3. WHEN rolling window returns are calculated for a ticker, THE Weekly_Option_Strategy SHALL identify the best return window (CALL opportunity) as the window with the maximum percentage return, and the worst return window (PUT opportunity) as the window with the minimum percentage return
4. WHEN a CALL or PUT opportunity is identified, THE Weekly_Option_Strategy SHALL compute the target price using the formula: target_price = current_price × (1 + historical_return_percentage / 100), rounded to 2 decimal places
5. IF the Data_Service fails to retrieve data for a ticker, THEN THE App SHALL display an error indicator for that ticker showing the ticker symbol and a message indicating data retrieval failed, and continue processing remaining tickers
6. IF a ticker has fewer trading days of data than the configured WINDOW_DAYS, THEN THE Weekly_Option_Strategy SHALL skip that ticker and display a message indicating insufficient data
7. WHILE analysis is running, THE App SHALL display a loading indicator showing the number of tickers processed out of the total watchlist count

### Requirement 6: Analysis Results Display

**User Story:** As a user, I want to view the analysis results in a clear table format, so that I can quickly identify trading opportunities.

#### Acceptance Criteria

1. WHEN analysis completes, THE App SHALL display results in a table with columns for Ticker, Type (CALL/PUT), Return Percentage (formatted to 2 decimal places with % symbol), Current Price (formatted as currency with 2 decimal places), Target Price (formatted as currency with 2 decimal places), Signal (displaying HOLD or ORDER), and Next Earnings Date (formatted as YYYY-MM-DD)
2. THE App SHALL display CALL results with positive return percentages and PUT results with negative return percentages
3. WHEN a result has an ORDER signal, THE App SHALL display that row with a visually distinct background color differentiating it from non-ORDER rows
4. WHEN the Next Earnings Date for a ticker is on or before the configured option expiration date, THE App SHALL display the Next Earnings Date cell in red color to indicate earnings risk
5. THE App SHALL allow users to sort results by any column, with the table initially sorted by Return Percentage in descending order
6. WHEN a user taps a sortable column header, THE App SHALL toggle the sort direction between ascending and descending for that column
7. WHEN no results are available, THE App SHALL display a message indicating no analysis has been run
8. IF the Next Earnings Date cannot be retrieved for a ticker, THEN THE App SHALL display "N/A" in the Next Earnings Date column for that ticker

### Requirement 7: Data Persistence

**User Story:** As a user, I want my watchlist and configurations to be saved to a cloud database, so that my data persists across sessions and devices.

#### Acceptance Criteria

1. THE App SHALL store user profiles, watchlists, and strategy configurations in a cloud database
2. WHEN a user modifies their watchlist or strategy configuration, THE App SHALL persist the changes to the cloud database within 5 seconds of the modification
3. WHEN a user signs in on a new device, THE App SHALL retrieve their existing watchlist and configurations from the database before displaying the home screen
4. IF data exists on both the local device and cloud database with conflicting values, THEN THE App SHALL use the most recently modified version based on timestamp
5. WHEN network connectivity is unavailable and locally cached data exists from a previous session, THE App SHALL display the cached data and show a persistent offline status indicator
6. IF a database operation fails, THEN THE App SHALL display an error message indicating the operation that failed and provide a retry option for a maximum of 3 retry attempts
7. IF all retry attempts for a database operation are exhausted, THEN THE App SHALL display a message indicating the operation could not be completed and suggest checking network connectivity

### Requirement 8: Scheduled Analysis Execution

**User Story:** As a user, I want the analysis to run automatically at specific times during trading hours, so that I receive up-to-date trading signals without manually triggering the analysis.

#### Acceptance Criteria

1. THE System SHALL automatically execute the configured strategy analysis at the following times in PST timezone: 6:30 AM, 6:45 AM, 7:00 AM, 9:00 AM, 11:00 AM, 12:30 PM, and 12:45 PM
2. WHEN a scheduled analysis executes, THE System SHALL run the analysis for each user who has enabled scheduled analysis and has at least one ticker in their watchlist
3. WHEN a scheduled analysis completes for a user, THE System SHALL store the results in the database with a timestamp indicating the scheduled run time
4. WHEN the App is open during a scheduled analysis completion, THE App SHALL automatically refresh the results table to display the latest scheduled analysis results
5. WHEN a user opens the App after a scheduled analysis has run, THE App SHALL display the most recent scheduled analysis results in the results table
6. THE App SHALL display the timestamp of the last scheduled analysis run above the results table in the format "Last updated: [time] PST"
7. IF a scheduled analysis fails for a user due to data retrieval errors, THEN THE System SHALL log the failure and retry once after a 2-minute delay
8. THE App SHALL provide a settings option for users to enable or disable scheduled analysis for their account, with the default being enabled

### Requirement 9: Email Notifications

**User Story:** As a user, I want to receive email notifications with the analysis results after each scheduled run, so that I can review trading opportunities without opening the app.

#### Acceptance Criteria

1. THE App SHALL provide a settings screen where users can configure their notification email address
2. WHEN a user enters an email address in the settings, THE App SHALL validate the email format before saving and display an error message if the format is invalid
3. WHEN a scheduled analysis completes successfully for a user with a configured email address, THE System SHALL send an email containing the analysis results table within 5 minutes of completion
4. THE email SHALL include the following content: subject line "TradingGuru Analysis Results - [Date] [Time] PST", a formatted HTML table matching the in-app results display with columns for Ticker, Type, Return Percentage, Current Price, Target Price, Signal, and Next Earnings Date, and a summary indicating the total number of CALL and PUT opportunities identified
5. THE email SHALL visually highlight rows with ORDER signals using a distinct background color in the HTML table
6. THE email SHALL display the Next Earnings Date cell in red color when the earnings date is on or before the configured option expiration date
6. IF a user has not configured an email address, THEN THE System SHALL not attempt to send email notifications for that user
7. IF email delivery fails, THEN THE System SHALL retry sending the email up to 3 times with 1-minute intervals between attempts
8. IF all email delivery attempts fail, THEN THE System SHALL log the failure for monitoring and continue processing other users
9. THE App SHALL provide a toggle in settings for users to enable or disable email notifications, with the default being enabled when an email address is configured
10. WHEN a user disables email notifications, THE System SHALL not send emails for scheduled analysis runs until the user re-enables notifications
