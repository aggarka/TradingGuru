//
//  WeeklyOptionStrategy.swift
//  TradingGuru
//
//  Implementation of the Weekly Option Strategy for analyzing CALL and PUT opportunities.
//  Calculates rolling window returns from historical price data to identify optimal entry points.
//

import Foundation

// MARK: - Weekly Option Strategy

/// Implementation of the Weekly Option Strategy.
///
/// This strategy analyzes historical price data to identify CALL and PUT opportunities
/// by calculating rolling window returns over the configured lookback period.
///
/// Algorithm:
/// 1. Fetch historical prices for LOOKBACK_DAYS
/// 2. Calculate rolling window returns over WINDOW_DAYS
/// 3. Best return window → CALL opportunity
/// 4. Worst return window → PUT opportunity
/// 5. Compute target prices using: target = current × (1 + return/100)
///
/// - Validates: Requirements 5.1-5.7 (Strategy execution)
/// - Validates: Requirement 3.5 (Common strategy interface for extensibility)
final class WeeklyOptionStrategy: TradingStrategy {
    
    // MARK: - TradingStrategy Protocol
    
    /// The display name of the strategy.
    let name = "Weekly Option Strategy"
    
    /// The unique identifier for the strategy.
    let identifier = "weekly_option"
    
    /// The configuration schema for this strategy.
    var configurationSchema: StrategyConfigurationSchema {
        WeeklyOptionConfigSchema()
    }
    
    // MARK: - Dependencies
    
    /// Market data service for fetching prices and earnings dates
    private let marketDataService: MarketDataService
    
    /// Options data service for fetching options chains
    /// - Validates: Requirement 1.1 (Fetch options chain for ticker and expiration)
    private let optionsDataService: OptionsDataService
    
    /// Calculator for rolling window returns
    private let rollingWindowCalculator: RollingWindowCalculation
    
    /// Calculator for options expiration dates with holiday awareness
    /// - Validates: Requirement 2.1, 2.2, 2.6 (Expiration date calculation)
    private let expirationDateCalculator: ExpirationDateCalculation
    
    /// Algorithm for matching options to target premium
    /// - Validates: Requirement 4.2, 4.3, 4.4 (Premium matching)
    private let premiumMatcher: PremiumMatching
    
    /// Logger for monitoring options chain errors
    /// - Validates: Requirement 1.4, 6.10 (Log errors for monitoring)
    private let optionsErrorLogger: OptionsErrorLogger
    
    // MARK: - Initialization
    
    /// Creates a new WeeklyOptionStrategy instance.
    /// - Parameters:
    ///   - marketDataService: Service for fetching market data (defaults to YahooFinanceService)
    ///   - optionsDataService: Service for fetching options chain data (defaults to YahooFinanceService)
    ///   - rollingWindowCalculator: Calculator for rolling returns (defaults to RollingWindowCalculator)
    ///   - expirationDateCalculator: Calculator for expiration dates (defaults to ExpirationDateCalculator)
    ///   - premiumMatcher: Algorithm for premium matching (defaults to PremiumMatchingAlgorithm)
    ///   - optionsErrorLogger: Logger for options errors (defaults to DefaultOptionsErrorLogger)
    init(
        marketDataService: MarketDataService? = nil,
        optionsDataService: OptionsDataService? = nil,
        rollingWindowCalculator: RollingWindowCalculation? = nil,
        expirationDateCalculator: ExpirationDateCalculation? = nil,
        premiumMatcher: PremiumMatching? = nil,
        optionsErrorLogger: OptionsErrorLogger? = nil
    ) {
        let yahooService = YahooFinanceService()
        self.marketDataService = marketDataService ?? yahooService
        self.optionsDataService = optionsDataService ?? yahooService
        self.rollingWindowCalculator = rollingWindowCalculator ?? RollingWindowCalculator()
        self.expirationDateCalculator = expirationDateCalculator ?? ExpirationDateCalculator()
        self.premiumMatcher = premiumMatcher ?? PremiumMatchingAlgorithm()
        self.optionsErrorLogger = optionsErrorLogger ?? DefaultOptionsErrorLogger()
    }
    
    // MARK: - TradingStrategy Implementation
    
    /// Analyzes price data using the Weekly Option Strategy.
    ///
    /// This method is synchronous and works with pre-fetched price data.
    /// For a complete async analysis pipeline, use `analyzeAsync`.
    ///
    /// - Parameters:
    ///   - priceData: Historical price data points sorted by date (oldest first)
    ///   - configuration: The strategy configuration to use
    /// - Returns: The analysis result for the best opportunity
    /// - Validates: Requirements 5.2, 5.3, 5.4 (Rolling returns, CALL/PUT identification, target price)
    func analyze(
        priceData: [PricePoint],
        configuration: StrategyConfiguration
    ) -> AnalysisResult {
        let config = WeeklyOptionConfiguration.from(configuration)
        
        // Calculate rolling window returns
        let returns = rollingWindowCalculator.calculateRollingReturnsOrEmpty(
            prices: priceData,
            windowDays: config.windowDays
        )
        
        // Get current price (last price in the data)
        let currentPrice = priceData.last?.close ?? 0
        
        // Identify CALL opportunity (best return)
        // Return the CALL opportunity by default; full implementation provides both
        let bestReturn = returns.max(by: { $0.returnPct < $1.returnPct })
        let returnPct = bestReturn?.returnPct ?? 0
        
        let targetPrice = Self.calculateTargetPrice(
            currentPrice: currentPrice,
            returnPercentage: returnPct
        )
        
        let type: OpportunityType = returnPct >= 0 ? .call : .put
        let signal = determineSignal(returnPercentage: returnPct, premiumPct: config.premiumPct)
        
        return AnalysisResult(
            ticker: "UNKNOWN",
            type: type,
            returnPercentage: returnPct,
            currentPrice: currentPrice,
            targetPrice: targetPrice,
            signal: signal,
            nextEarningsDate: nil,
            hasEarningsRisk: false
        )
    }
    
    // MARK: - Async Analysis Pipeline
    
    /// Analyzes a single ticker asynchronously, fetching all required data.
    ///
    /// This method executes the complete analysis pipeline:
    /// 1. Fetch historical prices from Yahoo Finance
    /// 2. Fetch next earnings date
    /// 3. Calculate rolling window returns
    /// 4. Calculate expiration date
    /// 5. Fetch options chain for the expiration date
    /// 6. Identify CALL and PUT opportunities
    /// 7. Generate AnalysisResult objects
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol
    ///   - configuration: The strategy configuration to use
    /// - Returns: Array of AnalysisResult (one CALL and one PUT opportunity)
    /// - Throws: MarketDataError or RollingWindowError if analysis fails
    /// - Validates: Requirements 1.1, 1.4, 1.5, 5.1-5.7 (Complete analysis pipeline with options)
    func analyzeAsync(
        ticker: String,
        configuration: WeeklyOptionConfiguration
    ) async throws -> [AnalysisResult] {
        // 1. Fetch historical prices
        // - Validates: Requirement 5.1 (Fetch historical prices for LOOKBACK_DAYS)
        let priceData = try await marketDataService.fetchHistoricalPrices(
            ticker: ticker,
            lookbackDays: configuration.lookbackDays
        )
        
        // Check for sufficient data
        // - Validates: Requirement 5.6 (Handle insufficient data)
        guard priceData.count > configuration.windowDays else {
            throw RollingWindowError.insufficientData(
                available: priceData.count,
                required: configuration.windowDays + 1,
                ticker: ticker
            )
        }
        
        // 2. Calculate rolling window returns
        // - Validates: Requirement 5.2 (Rolling window return calculation)
        let calculator = RollingWindowCalculator(ticker: ticker)
        let returns = try calculator.calculateRollingReturns(
            prices: priceData,
            windowDays: configuration.windowDays
        )
        
        guard !returns.isEmpty else {
            throw RollingWindowError.insufficientData(
                available: priceData.count,
                required: configuration.windowDays + 1,
                ticker: ticker
            )
        }
        
        // 3. Fetch earnings date (optional - don't fail on error)
        // - Validates: Requirement 6.8 (Fetch earnings date, N/A if unavailable)
        let earningsDate = try? await marketDataService.fetchEarningsDate(ticker: ticker)
        
        // 4. Get current price (most recent closing price)
        guard let currentPrice = priceData.last?.close else {
            throw MarketDataError.insufficientData(
                ticker: ticker,
                required: 1,
                available: 0
            )
        }
        
        // 5. Calculate expiration date using the calculator
        // - Validates: Requirement 2.1, 2.2, 2.6 (Expiration date calculation)
        let expirationDate = configuration.effectiveExpirationDate(using: expirationDateCalculator)
        
        // Debug log the expiration date being used
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        print("[WeeklyOption] Using expiration date: \(dateFormatter.string(from: expirationDate)) for \(ticker)")
        
        // 6. Fetch options chain for the ticker and expiration date
        // - Validates: Requirement 1.1 (Fetch options chain for ticker and expiration)
        // - Validates: Requirement 1.4 (Handle errors appropriately)
        // - Validates: Requirement 1.5 (Return empty chain if no contracts)
        // - Validates: Requirement 6.10 (Graceful degradation with logging)
        let optionsChain: OptionsChain
        
        // Fetch options chain from the options data service (Yahoo Finance)
        do {
            optionsChain = try await optionsDataService.fetchOptionsChain(
                ticker: ticker,
                expirationDate: expirationDate
            )
            if optionsChain.isEmpty {
                optionsErrorLogger.logEmptyOptionsChain(
                    ticker: ticker,
                    expirationDate: expirationDate
                )
            }
        } catch {
            optionsErrorLogger.logOptionsChainFetchError(
                ticker: ticker,
                expirationDate: expirationDate,
                error: error
            )
            optionsChain = OptionsChain.empty(ticker: ticker, expirationDate: expirationDate)
        }
        
        // 6a. Calculate target premium for premium matching
        // - Validates: Requirement 4.1 (Target premium calculation)
        let targetPremium = Self.calculateTargetPremium(
            currentPrice: currentPrice,
            premiumPct: configuration.premiumPct
        )
        
        // 6b. Find best matching call option from the options chain
        // - Validates: Requirement 4.2 (Find call option with mid-price closest to target)
        // - Validates: Requirement 4.4 (Tiebreaker: higher strike for calls)
        let selectedCallOption = premiumMatcher.findBestCallMatch(
            from: optionsChain.calls,
            targetPremium: targetPremium
        )
        
        // Debug logging for selected options
        print("[WeeklyOption] Target premium for \(ticker): $\(String(format: "%.2f", targetPremium))")
        if let call = selectedCallOption {
            print("[WeeklyOption] Selected CALL: strike=$\(call.strikePrice), bid=$\(call.bid), ask=$\(call.ask), mid=$\(call.midPrice)")
        } else {
            print("[WeeklyOption] No CALL option selected for \(ticker)")
        }
        
        // 6c. Find best matching put option from the options chain
        // - Validates: Requirement 4.3 (Find put option with mid-price closest to target)
        // - Validates: Requirement 4.4 (Tiebreaker: lower strike for puts)
        let selectedPutOption = premiumMatcher.findBestPutMatch(
            from: optionsChain.puts,
            targetPremium: targetPremium
        )
        
        if let put = selectedPutOption {
            print("[WeeklyOption] Selected PUT: strike=$\(put.strikePrice), bid=$\(put.bid), ask=$\(put.ask), mid=$\(put.midPrice)")
        } else {
            print("[WeeklyOption] No PUT option selected for \(ticker)")
        }
        
        // 7. Identify CALL opportunity (maximum return)
        // - Validates: Requirement 5.3 (Best return window = CALL)
        let bestReturn = returns.max(by: { $0.returnPct < $1.returnPct })!
        
        // 8. Identify PUT opportunity (minimum return)
        // - Validates: Requirement 5.3 (Worst return window = PUT)
        let worstReturn = returns.min(by: { $0.returnPct < $1.returnPct })!
        
        // 9. Calculate earnings risk using actual expiration date
        // - Validates: Requirement 6.4 (Earnings risk when earnings falls between today and expiration inclusive)
        let hasEarningsRisk = calculateEarningsRisk(
            earningsDate: earningsDate,
            expirationDate: expirationDate
        )
        
        // 10. Calculate call and put targets from historical returns
        // - Validates: Requirement 5.1 (Call target = currentPrice × (1 + bestReturnPct / 100))
        // - Validates: Requirement 5.2 (Put target = currentPrice × (1 + worstReturnPct / 100))
        let callTarget = Self.calculateCallTarget(
            currentPrice: currentPrice,
            bestReturnPct: bestReturn.returnPct
        )
        let putTarget = Self.calculatePutTarget(
            currentPrice: currentPrice,
            worstReturnPct: worstReturn.returnPct
        )
        
        // 11. Generate call signal using selected option's strike price vs call target
        // - Validates: Requirement 5.3 (CALL_ORDER when strike >= call_target)
        // - Validates: Requirement 5.4 (HOLD when strike < call_target or no option)
        let callSignal = generateCallSignal(
            strikePrice: selectedCallOption?.strikePrice,
            callTarget: callTarget
        )
        
        // 12. Generate put signal using selected option's strike price vs put target
        // - Validates: Requirement 5.5 (PUT_ORDER when strike <= put_target)
        // - Validates: Requirement 5.6 (HOLD when strike > put_target or no option)
        let putSignal = generatePutSignal(
            strikePrice: selectedPutOption?.strikePrice,
            putTarget: putTarget
        )
        
        // 13. Create CALL result with options data
        // - Validates: Requirements 5.4, 6.1-6.5 (Result structure with options fields)
        let callTargetPrice = Self.calculateTargetPrice(
            currentPrice: currentPrice,
            returnPercentage: bestReturn.returnPct
        )
        // Use the configured expiration date for display consistency across all tickers
        // Even if Yahoo Finance returns options for a slightly different date, we show the configured date
        let displayExpirationDate = optionsChain.isEmpty ? nil : expirationDate
        let callResult = AnalysisResult(
            ticker: ticker,
            type: .call,
            returnPercentage: bestReturn.returnPct,
            currentPrice: currentPrice,
            targetPrice: callTargetPrice,
            signal: callSignal,
            nextEarningsDate: earningsDate,
            hasEarningsRisk: hasEarningsRisk,
            expirationDate: displayExpirationDate,
            strikePrice: selectedCallOption?.strikePrice,
            bidPremium: selectedCallOption?.bid,
            askPremium: selectedCallOption?.ask,
            midPremium: selectedCallOption?.midPrice,
            selectedOption: selectedCallOption
        )
        
        // 14. Create PUT result with options data
        // - Validates: Requirements 5.4, 6.1-6.5 (Result structure with options fields)
        let putTargetPrice = Self.calculateTargetPrice(
            currentPrice: currentPrice,
            returnPercentage: worstReturn.returnPct
        )
        let putResult = AnalysisResult(
            ticker: ticker,
            type: .put,
            returnPercentage: worstReturn.returnPct,
            currentPrice: currentPrice,
            targetPrice: putTargetPrice,
            signal: putSignal,
            nextEarningsDate: earningsDate,
            hasEarningsRisk: hasEarningsRisk,
            expirationDate: displayExpirationDate,
            strikePrice: selectedPutOption?.strikePrice,
            bidPremium: selectedPutOption?.bid,
            askPremium: selectedPutOption?.ask,
            midPremium: selectedPutOption?.midPrice,
            selectedOption: selectedPutOption
        )
        
        return [callResult, putResult]
    }
    
    /// Analyzes multiple tickers asynchronously with progress reporting.
    ///
    /// Continues processing even if individual tickers fail.
    /// Errors for failed tickers are collected and reported via progress handler.
    ///
    /// - Parameters:
    ///   - tickers: Array of ticker symbols to analyze
    ///   - configuration: The strategy configuration to use
    ///   - progressHandler: Closure called with progress updates after each ticker
    /// - Returns: Dictionary mapping tickers to their analysis results or errors
    /// - Validates: Requirement 5.5 (Continue processing on per-ticker failures)
    /// - Validates: Requirement 5.7 (Show progress n/total)
    func analyzeBatch(
        tickers: [String],
        configuration: WeeklyOptionConfiguration,
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async -> [String: Result<[AnalysisResult], Error>] {
        var results: [String: Result<[AnalysisResult], Error>] = [:]
        var errors: [MarketDataError] = []
        let total = tickers.count
        
        for (index, ticker) in tickers.enumerated() {
            // Report progress at start of each ticker
            // - Validates: Requirement 5.7 (Progress n/total)
            let progress = AnalysisProgress(
                total: total,
                completed: index,
                currentTicker: ticker,
                errors: errors
            )
            progressHandler(progress)
            
            // Analyze this ticker
            do {
                let tickerResults = try await analyzeAsync(
                    ticker: ticker,
                    configuration: configuration
                )
                results[ticker] = .success(tickerResults)
            } catch let error as MarketDataError {
                // - Validates: Requirement 5.5 (Display error indicator, continue processing)
                results[ticker] = .failure(error)
                errors.append(error)
            } catch let error as RollingWindowError {
                // - Validates: Requirement 5.6 (Skip ticker with insufficient data, display message)
                let marketError: MarketDataError
                switch error {
                case .insufficientData(let available, let required, let tickerName):
                    marketError = .insufficientData(
                        ticker: tickerName ?? ticker,
                        required: required,
                        available: available
                    )
                case .emptyPriceData(let tickerName):
                    marketError = .insufficientData(
                        ticker: tickerName ?? ticker,
                        required: 1,
                        available: 0
                    )
                case .invalidWindowDays(let value):
                    marketError = .fetchFailed(
                        ticker: ticker,
                        reason: "Invalid window days value: \(value)"
                    )
                }
                results[ticker] = .failure(marketError)
                errors.append(marketError)
            } catch {
                // Generic error handling
                let marketError = MarketDataError.fetchFailed(
                    ticker: ticker,
                    reason: error.localizedDescription
                )
                results[ticker] = .failure(marketError)
                errors.append(marketError)
            }
        }
        
        // Report final progress
        let finalProgress = AnalysisProgress(
            total: total,
            completed: total,
            currentTicker: nil,
            errors: errors
        )
        progressHandler(finalProgress)
        
        return results
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the target price based on current price and return percentage.
    ///
    /// Formula: target = current × (1 + return/100), rounded to 2 decimal places
    ///
    /// - Parameters:
    ///   - currentPrice: The current stock price
    ///   - returnPercentage: The historical return percentage
    /// - Returns: The target price rounded to 2 decimal places
    /// - Validates: Requirement 5.4 (Target price calculation formula)
    static func calculateTargetPrice(currentPrice: Double, returnPercentage: Double) -> Double {
        let rawTarget = currentPrice * (1 + returnPercentage / 100)
        // Round to 2 decimal places
        return (rawTarget * 100).rounded() / 100
    }
    
    // MARK: - Target Strike Calculation Methods
    
    /// Calculates the target strike price for call options based on historical best return.
    ///
    /// The target strike represents the price above which it is historically safe to sell
    /// a covered call, calculated as: `currentPrice × (1 + bestReturnPct / 100)`.
    /// This is the price the stock has never exceeded within the rolling window lookback period.
    ///
    /// - Parameters:
    ///   - currentPrice: The current stock price
    ///   - bestReturnPct: The maximum rolling window return percentage (positive value)
    /// - Returns: The call target strike price
    /// - Note: Returns 0 if currentPrice is zero or negative
    /// - Validates: Requirement 5.1 (Call target calculation)
    static func calculateCallTarget(currentPrice: Double, bestReturnPct: Double) -> Double {
        guard currentPrice > 0 else { return 0 }
        return currentPrice * (1 + bestReturnPct / 100.0)
    }
    
    /// Calculates the target strike price for put options based on historical worst return.
    ///
    /// The target strike represents the price below which it is historically safe to sell
    /// a cash-secured put, calculated as: `currentPrice × (1 + worstReturnPct / 100)`.
    /// This is the price the stock has never dropped below within the rolling window lookback period.
    ///
    /// - Parameters:
    ///   - currentPrice: The current stock price
    ///   - worstReturnPct: The minimum rolling window return percentage (typically negative)
    /// - Returns: The put target strike price
    /// - Note: Returns 0 if currentPrice is zero or negative
    /// - Validates: Requirement 5.2 (Put target calculation)
    static func calculatePutTarget(currentPrice: Double, worstReturnPct: Double) -> Double {
        guard currentPrice > 0 else { return 0 }
        return currentPrice * (1 + worstReturnPct / 100.0)
    }
    
    /// Calculates the target strike price based on current price and percent gain.
    ///
    /// Generic method for calculating target strike using the formula:
    /// `targetStrike = currentPrice + percentGain * currentPrice`
    /// which is equivalent to: `currentPrice × (1 + percentGain)`
    ///
    /// - Parameters:
    ///   - currentPrice: The current stock price (must be positive)
    ///   - percentGain: The percent gain as a decimal (e.g., 0.05 for 5%)
    /// - Returns: The target strike price, or 0 if currentPrice is non-positive
    /// - Note: For negative percentGain values, returns a strike below currentPrice
    /// - Validates: Requirement 2.1 (Target strike calculation from design)
    static func calculateTargetStrike(currentPrice: Double, percentGain: Double) -> Double {
        guard currentPrice > 0 else { return 0 }
        return currentPrice + (percentGain * currentPrice)
    }
    
    /// Determines if a call option strike price is suitable for selling based on the call target.
    ///
    /// A call strike is suitable (ORDER signal) when it is greater than or equal to the call target,
    /// meaning the stock has historically never reached that price within the lookback period.
    ///
    /// - Parameters:
    ///   - strikePrice: The option's strike price
    ///   - callTarget: The calculated call target price
    /// - Returns: `true` if strike is suitable for selling (strike >= callTarget), `false` otherwise
    /// - Validates: Requirement 5.3 (CALL_ORDER when strike >= call_target)
    static func isCallStrikeSuitable(strikePrice: Double, callTarget: Double) -> Bool {
        strikePrice >= callTarget
    }
    
    /// Determines if a put option strike price is suitable for selling based on the put target.
    ///
    /// A put strike is suitable (ORDER signal) when it is less than or equal to the put target,
    /// meaning the stock has historically never dropped to that price within the lookback period.
    ///
    /// - Parameters:
    ///   - strikePrice: The option's strike price
    ///   - putTarget: The calculated put target price
    /// - Returns: `true` if strike is suitable for selling (strike <= putTarget), `false` otherwise
    /// - Validates: Requirement 5.5 (PUT_ORDER when strike <= put_target)
    static func isPutStrikeSuitable(strikePrice: Double, putTarget: Double) -> Bool {
        strikePrice <= putTarget
    }
    
    // MARK: - Signal Generation Methods
    
    /// Generates a trading signal for a call option based on strike price comparison to target.
    ///
    /// A CALL_ORDER signal is generated when the option's strike price is greater than or equal
    /// to the call target, indicating the stock has historically never gained enough to reach
    /// that strike within the lookback period. A HOLD signal is generated when the strike is
    /// below the call target or when no strike price is available.
    ///
    /// - Parameters:
    ///   - strikePrice: The option's strike price, or nil if no option available
    ///   - callTarget: The calculated call target price based on historical best return
    /// - Returns: `.order` when strike >= callTarget, `.hold` otherwise (including nil strike)
    /// - Validates: Requirements 5.3, 5.4 (CALL_ORDER and HOLD signal logic)
    func generateCallSignal(strikePrice: Double?, callTarget: Double) -> Signal {
        guard let strike = strikePrice else { return .hold }
        // CALL_ORDER when strike >= call_target
        return Self.isCallStrikeSuitable(strikePrice: strike, callTarget: callTarget) ? .order : .hold
    }
    
    /// Generates a trading signal for a put option based on strike price comparison to target.
    ///
    /// A PUT_ORDER signal is generated when the option's strike price is less than or equal
    /// to the put target, indicating the stock has historically never dropped enough to reach
    /// that strike within the lookback period. A HOLD signal is generated when the strike is
    /// above the put target or when no strike price is available.
    ///
    /// - Parameters:
    ///   - strikePrice: The option's strike price, or nil if no option available
    ///   - putTarget: The calculated put target price based on historical worst return
    /// - Returns: `.order` when strike <= putTarget, `.hold` otherwise (including nil strike)
    /// - Validates: Requirements 5.5, 5.6 (PUT_ORDER and HOLD signal logic)
    func generatePutSignal(strikePrice: Double?, putTarget: Double) -> Signal {
        guard let strike = strikePrice else { return .hold }
        // PUT_ORDER when strike <= put_target
        return Self.isPutStrikeSuitable(strikePrice: strike, putTarget: putTarget) ? .order : .hold
    }
    
    /// Generates a call signal from an options chain based on target strike comparison.
    ///
    /// This method finds the best matching call option from the chain and determines
    /// whether it meets the ORDER criteria based on the call target.
    ///
    /// - Parameters:
    ///   - optionsChain: The options chain containing call options
    ///   - callTarget: The calculated call target price
    ///   - targetPremium: The target premium for finding the best match
    ///   - premiumMatcher: The algorithm for finding the best premium match
    /// - Returns: A tuple containing the signal and the selected option contract (if any)
    /// - Validates: Requirements 5.3, 5.4 (CALL_ORDER when strike >= call_target, HOLD otherwise)
    func generateCallSignalFromChain(
        optionsChain: OptionsChain,
        callTarget: Double,
        targetPremium: Double,
        premiumMatcher: PremiumMatching
    ) -> (signal: Signal, selectedOption: OptionContract?) {
        // Handle empty options chain
        guard !optionsChain.calls.isEmpty else {
            return (.hold, nil)
        }
        
        // Find the best matching call option based on premium
        guard let selectedCall = premiumMatcher.findBestCallMatch(
            from: optionsChain.calls,
            targetPremium: targetPremium
        ) else {
            return (.hold, nil)
        }
        
        // Generate signal based on strike vs target comparison
        let signal = generateCallSignal(strikePrice: selectedCall.strikePrice, callTarget: callTarget)
        
        return (signal, selectedCall)
    }
    
    /// Generates a put signal from an options chain based on target strike comparison.
    ///
    /// This method finds the best matching put option from the chain and determines
    /// whether it meets the ORDER criteria based on the put target.
    ///
    /// - Parameters:
    ///   - optionsChain: The options chain containing put options
    ///   - putTarget: The calculated put target price
    ///   - targetPremium: The target premium for finding the best match
    ///   - premiumMatcher: The algorithm for finding the best premium match
    /// - Returns: A tuple containing the signal and the selected option contract (if any)
    /// - Validates: Requirements 5.5, 5.6 (PUT_ORDER when strike <= put_target, HOLD otherwise)
    func generatePutSignalFromChain(
        optionsChain: OptionsChain,
        putTarget: Double,
        targetPremium: Double,
        premiumMatcher: PremiumMatching
    ) -> (signal: Signal, selectedOption: OptionContract?) {
        // Handle empty options chain
        guard !optionsChain.puts.isEmpty else {
            return (.hold, nil)
        }
        
        // Find the best matching put option based on premium
        guard let selectedPut = premiumMatcher.findBestPutMatch(
            from: optionsChain.puts,
            targetPremium: targetPremium
        ) else {
            return (.hold, nil)
        }
        
        // Generate signal based on strike vs target comparison
        let signal = generatePutSignal(strikePrice: selectedPut.strikePrice, putTarget: putTarget)
        
        return (signal, selectedPut)
    }
    
    /// Calculates the target premium amount based on current price and premium percentage.
    ///
    /// The target premium is the desired option premium for finding matching contracts,
    /// calculated as: `targetPremium = currentPrice × premiumPct`
    ///
    /// - Parameters:
    ///   - currentPrice: The current stock price
    ///   - premiumPct: The target premium percentage (e.g., 0.5 for 0.5%)
    /// - Returns: The target premium amount
    /// - Note: Returns 0 if currentPrice is zero or negative
    /// - Validates: Requirement 4.1 (Target premium calculation)
    static func calculateTargetPremium(currentPrice: Double, premiumPct: Double) -> Double {
        guard currentPrice > 0 else { return 0 }
        // Convert percentage to decimal (0.5% -> 0.005)
        return currentPrice * (premiumPct / 100.0)
    }
    
    /// Determines the trading signal based on return percentage and premium threshold.
    ///
    /// A signal is ORDER when the absolute return percentage meets or exceeds
    /// the configured premium threshold. Otherwise, the signal is HOLD.
    ///
    /// - Parameters:
    ///   - returnPercentage: The historical return percentage
    ///   - premiumPct: The configured premium percentage threshold
    /// - Returns: The trading signal (ORDER or HOLD)
    private func determineSignal(returnPercentage: Double, premiumPct: Double) -> Signal {
        // Signal is ORDER when the return meets or exceeds the premium threshold
        // Use absolute value for comparison
        if abs(returnPercentage) >= premiumPct {
            return .order
        }
        return .hold
    }
    
    /// Calculates whether earnings date poses a risk for the option trade.
    ///
    /// Earnings risk exists when the next earnings date falls between today
    /// and the option expiration date (inclusive).
    ///
    /// - Parameters:
    ///   - earningsDate: The next earnings date, or nil if unavailable
    ///   - expirationDate: The actual option expiration date
    /// - Returns: true if earnings risk exists, false otherwise
    /// - Validates: Requirement 6.4 (Earnings risk indicator - red when between today and expiration)
    private func calculateEarningsRisk(earningsDate: Date?, expirationDate: Date) -> Bool {
        guard let earningsDate = earningsDate else {
            return false
        }
        
        // Get start of today for comparison
        let today = Calendar.current.startOfDay(for: Date())
        
        // Get end of expiration day for inclusive comparison
        let expirationEnd = Calendar.current.startOfDay(for: expirationDate)
        
        // Earnings risk if earnings is between today and expiration (inclusive)
        let earningsDay = Calendar.current.startOfDay(for: earningsDate)
        return earningsDay >= today && earningsDay <= expirationEnd
    }
}

// MARK: - Weekly Option Configuration Schema

/// Configuration schema for the Weekly Option Strategy.
///
/// Defines available parameters and validation rules.
/// - Validates: Requirements 4.1-4.5 (Configuration options)
struct WeeklyOptionConfigSchema: StrategyConfigurationSchema {
    
    /// The parameters available for this strategy.
    var parameters: [ConfigurationParameter] {
        [
            ConfigurationParameter(
                key: "windowDays",
                displayName: "Window Days",
                type: .integer(options: WeeklyOptionConfiguration.validWindowDays),
                defaultValue: .integer(5),
                constraints: ParameterConstraints(
                    allowedValues: WeeklyOptionConfiguration.validWindowDays
                )
            ),
            ConfigurationParameter(
                key: "lookbackDays",
                displayName: "Lookback Days",
                type: .integer(options: WeeklyOptionConfiguration.validLookbackDays),
                defaultValue: .integer(180),
                constraints: ParameterConstraints(
                    allowedValues: WeeklyOptionConfiguration.validLookbackDays
                )
            ),
            ConfigurationParameter(
                key: "premiumPct",
                displayName: "Premium %",
                type: .decimal(
                    range: WeeklyOptionConfiguration.premiumPctRange,
                    step: WeeklyOptionConfiguration.premiumPctStep
                ),
                defaultValue: .decimal(0.5),
                constraints: ParameterConstraints(
                    minValue: WeeklyOptionConfiguration.premiumPctRange.lowerBound,
                    maxValue: WeeklyOptionConfiguration.premiumPctRange.upperBound,
                    step: WeeklyOptionConfiguration.premiumPctStep
                )
            ),
            ConfigurationParameter(
                key: "onlyOrders",
                displayName: "Show Only Orders",
                type: .boolean,
                defaultValue: .boolean(false)
            )
        ]
    }
    
    /// Validates a configuration against the schema.
    /// - Parameter configuration: The configuration to validate
    /// - Returns: Success if valid, or ConfigurationError if invalid
    /// - Validates: Requirement 4.11 (Configuration validation)
    func validate(_ configuration: StrategyConfiguration) -> Result<Void, ConfigurationError> {
        let weeklyConfig = WeeklyOptionConfiguration.from(configuration)
        return weeklyConfig.validate()
    }
    
    /// Creates a default configuration for this strategy.
    /// - Returns: A configuration with all default values
    /// - Validates: Requirement 4.8 (Default values)
    func createDefaultConfiguration() -> StrategyConfiguration {
        WeeklyOptionConfiguration.default.toStrategyConfiguration()
    }
}

// MARK: - Strategy Registration Extension

extension WeeklyOptionStrategy {
    
    /// Registers this strategy with the global strategy registry.
    /// Call this during app initialization to make the strategy available.
    /// - Validates: Requirement 3.5 (New strategies added without modifying existing code)
    static func registerWithRegistry() throws {
        let strategy = WeeklyOptionStrategy()
        try StrategyRegistry.shared.register(strategy)
    }
    
    /// Creates a factory for lazy loading this strategy.
    /// - Returns: A StrategyFactory that creates WeeklyOptionStrategy instances
    static func createFactory() -> StrategyFactory {
        DefaultStrategyFactory(identifier: "weekly_option") {
            WeeklyOptionStrategy()
        }
    }
}
