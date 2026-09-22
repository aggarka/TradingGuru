//
//  EndToEndIntegrationTests.swift
//  TradingGuruTests
//
//  End-to-end integration tests for the Live Options Chain Integration feature.
//  Tests the complete flow from configuration through analysis to results display.
//
//  Validates: Requirements 1.1-6.11, 7.1-7.4 (Complete feature integration)
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - End-to-End Integration Test Suite

@Suite("End-to-End Integration Tests: Live Options Chain")
struct EndToEndIntegrationTests {
    
    // MARK: - Test 1: Complete Flow - Configure Expiration → Run Analysis → View Results
    
    @Test("Complete flow: configure expiration, run analysis, view results with options data")
    @MainActor
    func testCompleteFlowWithExpirationConfiguration() async throws {
        // Validates: Requirements 1.1-1.6, 2.1-2.6, 3.1-3.4, 4.1-4.5, 5.1-5.6, 6.1-6.11
        
        // --- Setup Mock Services ---
        let mockOptionsService = E2EMockOptionsDataService()
        let mockExpirationCalculator = E2EMockExpirationDateCalculator()
        let mockResultsRepo = E2EMockResultsRepository()
        
        // Configure a predictable expiration date (Friday)
        let calendar = Calendar.current
        let expirationDate = nextFriday(from: Date())
        mockExpirationCalculator.defaultExpiration = expirationDate
        mockExpirationCalculator.validExpirationResult = true
        
        // Set up mock price data for AAPL and MSFT
        let aaplPriceData = createMockPriceData(ticker: "AAPL", days: 30, basePrice: 180.0)
        let msftPriceData = createMockPriceData(ticker: "MSFT", days: 30, basePrice: 400.0)
        mockOptionsService.priceDataByTicker["AAPL"] = aaplPriceData
        mockOptionsService.priceDataByTicker["MSFT"] = msftPriceData

        // Set up mock options chains with valid contracts
        let aaplOptionsChain = createMockOptionsChain(
            ticker: "AAPL",
            expirationDate: expirationDate,
            currentPrice: 180.0,
            callStrike: 190.0,  // Above call target - should generate ORDER
            putStrike: 170.0   // Below put target - should generate ORDER
        )
        let msftOptionsChain = createMockOptionsChain(
            ticker: "MSFT",
            expirationDate: expirationDate,
            currentPrice: 400.0,
            callStrike: 415.0,
            putStrike: 385.0
        )
        mockOptionsService.optionsChainByTicker["AAPL"] = aaplOptionsChain
        mockOptionsService.optionsChainByTicker["MSFT"] = msftOptionsChain
        
        // --- Create Strategy with Dependencies ---
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockOptionsService,
            optionsDataService: mockOptionsService,
            rollingWindowCalculator: RollingWindowCalculator(),
            expirationDateCalculator: mockExpirationCalculator,
            premiumMatcher: PremiumMatchingAlgorithm()
        )
        
        // --- Step 1: Configure AnalysisViewModel with expiration override ---
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            expirationDateCalculator: mockExpirationCalculator,
            userId: "e2e-test-user"
        )

        // Select strategy and configure watchlist
        await analysisViewModel.selectStrategy(.weeklyOption)
        analysisViewModel.setWatchlistTickers(["AAPL", "MSFT"])
        
        // Verify strategy is selected and ready
        #expect(analysisViewModel.hasSelectedStrategy == true)
        #expect(analysisViewModel.isConfigurationLoaded == true)
        
        // --- Step 2: Set custom expiration date override ---
        // Validates: Requirements 3.1-3.4 (Expiration override)
        let customExpiration = expirationDate
        analysisViewModel.setExpirationOverride(customExpiration)
        
        #expect(analysisViewModel.hasExpirationOverride == true)
        #expect(analysisViewModel.expirationValidationError == nil)
        #expect(analysisViewModel.canRunAnalysis == true)
        
        // --- Step 3: Run Analysis ---
        await analysisViewModel.runAnalysis()
        
        // Verify analysis completed
        #expect(analysisViewModel.isRunningAnalysis == false)
        #expect(analysisViewModel.analysisResults.count > 0)
        
        // Each ticker produces 2 results (CALL and PUT)
        #expect(analysisViewModel.analysisResults.count == 4)
        
        // --- Step 4: Verify Results Have Options Data Populated ---
        // Validates: Requirements 6.1-6.5 (Options columns in results)
        let aaplCallResult = analysisViewModel.analysisResults.first {
            $0.ticker == "AAPL" && $0.type == .call
        }
        let aaplPutResult = analysisViewModel.analysisResults.first {
            $0.ticker == "AAPL" && $0.type == .put
        }

        // AAPL call should have options data
        #expect(aaplCallResult != nil, "Should have AAPL CALL result")
        #expect(aaplCallResult?.expirationDate != nil, "Call should have expiration date")
        #expect(aaplCallResult?.strikePrice == 190.0, "Call strike should be 190.0")
        #expect(aaplCallResult?.bidPremium != nil, "Call should have bid premium")
        #expect(aaplCallResult?.askPremium != nil, "Call should have ask premium")
        #expect(aaplCallResult?.midPremium != nil, "Call should have mid premium")
        
        // AAPL put should have options data
        #expect(aaplPutResult != nil, "Should have AAPL PUT result")
        #expect(aaplPutResult?.strikePrice == 170.0, "Put strike should be 170.0")
        #expect(aaplPutResult?.expirationDate != nil, "Put should have expiration date")
        
        // --- Step 5: Display Results in ResultsViewModel ---
        // Validates: Requirements 6.1-6.11 (Results display)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: mockResultsRepo,
            userId: "e2e-test-user"
        )
        
        let metadata = ResultsMetadata(
            timestamp: Date(),
            source: .manual,
            strategyId: "weekly_option"
        )
        resultsViewModel.updateResults(analysisViewModel.analysisResults, metadata: metadata)
        
        #expect(resultsViewModel.hasResults == true)
        #expect(resultsViewModel.results.count == 4)
        
        // Verify display formatting
        let displayRows = resultsViewModel.results
        let aaplCallRow = displayRows.first { $0.ticker == "AAPL" && $0.type == "CALL" }
        
        #expect(aaplCallRow != nil, "Should have AAPL CALL display row")
        #expect(aaplCallRow?.expirationDate != "N/A", "Expiration should not be N/A")
        #expect(aaplCallRow?.strikePrice != "N/A", "Strike should not be N/A")
        #expect(aaplCallRow?.midPremium != "N/A", "Mid premium should not be N/A")

        
        // --- Step 6: Verify Sorting Works with New Columns ---
        // Validates: Requirements 6.8, 6.9 (Sort by new columns)
        resultsViewModel.sort(by: .strikePrice)
        #expect(resultsViewModel.sortState.column == .strikePrice)
        
        resultsViewModel.sort(by: .midPremium)
        #expect(resultsViewModel.sortState.column == .midPremium)
        
        // Verify service calls
        #expect(mockOptionsService.fetchPricesCallCount >= 2)
        #expect(mockOptionsService.fetchOptionsChainCallCount >= 2)
    }
    
    // MARK: - Test 2: Network Failure → Graceful Degradation
    
    @Test("Network failure produces graceful degradation with N/A in options columns")
    @MainActor
    func testNetworkFailureGracefulDegradation() async throws {
        // Validates: Requirements 1.4, 1.5, 6.10 (Graceful degradation)
        
        // --- Setup Mock Services ---
        let mockOptionsService = E2EMockOptionsDataService()
        let mockExpirationCalculator = E2EMockExpirationDateCalculator()
        
        let calendar = Calendar.current
        let expirationDate = nextFriday(from: Date())
        mockExpirationCalculator.defaultExpiration = expirationDate
        
        // Set up price data (this succeeds)
        mockOptionsService.priceDataByTicker["AAPL"] = createMockPriceData(
            ticker: "AAPL",
            days: 30,
            basePrice: 180.0
        )
        
        // Configure OPTIONS FETCH TO FAIL (simulating network error)
        mockOptionsService.shouldFailOptionsForTickers = ["AAPL"]
        
        // --- Create Strategy ---
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockOptionsService,
            optionsDataService: mockOptionsService,
            rollingWindowCalculator: RollingWindowCalculator(),
            expirationDateCalculator: mockExpirationCalculator,
            premiumMatcher: PremiumMatchingAlgorithm()
        )

        
        // --- Create AnalysisViewModel ---
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            expirationDateCalculator: mockExpirationCalculator,
            userId: "e2e-test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        analysisViewModel.setWatchlistTickers(["AAPL"])
        
        // --- Run Analysis (should NOT throw despite options failure) ---
        await analysisViewModel.runAnalysis()
        
        // Analysis should complete successfully via graceful degradation
        #expect(analysisViewModel.isRunningAnalysis == false)
        #expect(analysisViewModel.analysisResults.count == 2, "Should have CALL and PUT results")
        
        // --- Verify Graceful Degradation ---
        // Validates: Requirement 6.10 (N/A when options unavailable)
        let callResult = analysisViewModel.analysisResults.first { $0.type == .call }
        let putResult = analysisViewModel.analysisResults.first { $0.type == .put }
        
        // Options data should be nil (graceful degradation)
        #expect(callResult?.strikePrice == nil, "Strike should be nil when options fail")
        #expect(callResult?.bidPremium == nil, "Bid should be nil when options fail")
        #expect(callResult?.askPremium == nil, "Ask should be nil when options fail")
        #expect(callResult?.midPremium == nil, "Mid should be nil when options fail")
        #expect(callResult?.expirationDate == nil, "Expiration should be nil when options fail")
        
        // Signals should be HOLD when no options data
        #expect(callResult?.signal == .hold, "Call should be HOLD without options data")
        #expect(putResult?.signal == .hold, "Put should be HOLD without options data")
        
        // But historical analysis data should still be present
        #expect(callResult?.currentPrice != nil, "Current price should be set")
        #expect(callResult?.targetPrice != nil, "Target price should be calculated")
        #expect(callResult?.returnPercentage != nil, "Return percentage should be calculated")

        
        // --- Verify Display Shows N/A ---
        let resultsViewModel = ResultsViewModel(
            resultsRepository: E2EMockResultsRepository(),
            userId: "e2e-test-user"
        )
        resultsViewModel.updateResults(analysisViewModel.analysisResults)
        
        let displayRows = resultsViewModel.results
        let callRow = displayRows.first { $0.type == "CALL" }
        
        // Options columns should display "N/A"
        #expect(callRow?.strikePrice == "N/A", "Strike should show N/A")
        #expect(callRow?.bidPremium == "N/A", "Bid should show N/A")
        #expect(callRow?.askPremium == "N/A", "Ask should show N/A")
        #expect(callRow?.midPremium == "N/A", "Mid should show N/A")
        #expect(callRow?.expirationDate == "N/A", "Expiration should show N/A")
        
        // Non-options fields should still display normally
        #expect(callRow?.currentPrice != "N/A", "Current price should not be N/A")
        #expect(callRow?.targetPrice != "N/A", "Target price should not be N/A")
    }
    
    // MARK: - Test 3: Batch Analysis with Mix of Successful and Failed Tickers
    
    @Test("Batch analysis handles mix of successful and failed tickers")
    @MainActor
    func testBatchAnalysisWithMixedResults() async throws {
        // Validates: Requirements 1.4, 5.5 (Continue processing on ticker failures)
        
        // --- Setup Mock Services ---
        let mockOptionsService = E2EMockOptionsDataService()
        let mockExpirationCalculator = E2EMockExpirationDateCalculator()
        
        let expirationDate = nextFriday(from: Date())
        mockExpirationCalculator.defaultExpiration = expirationDate
        
        // --- Configure Mixed Results ---
        // AAPL: Full success (prices + options)
        mockOptionsService.priceDataByTicker["AAPL"] = createMockPriceData(
            ticker: "AAPL", days: 30, basePrice: 180.0
        )
        mockOptionsService.optionsChainByTicker["AAPL"] = createMockOptionsChain(
            ticker: "AAPL",
            expirationDate: expirationDate,
            currentPrice: 180.0,
            callStrike: 190.0,
            putStrike: 170.0
        )

        
        // GOOGL: Price fetch fails completely
        mockOptionsService.shouldFailPriceForTickers = ["GOOGL"]
        
        // MSFT: Prices succeed, options fail (graceful degradation)
        mockOptionsService.priceDataByTicker["MSFT"] = createMockPriceData(
            ticker: "MSFT", days: 30, basePrice: 400.0
        )
        mockOptionsService.shouldFailOptionsForTickers = ["MSFT"]
        
        // NVDA: Full success (prices + options)
        mockOptionsService.priceDataByTicker["NVDA"] = createMockPriceData(
            ticker: "NVDA", days: 30, basePrice: 500.0
        )
        mockOptionsService.optionsChainByTicker["NVDA"] = createMockOptionsChain(
            ticker: "NVDA",
            expirationDate: expirationDate,
            currentPrice: 500.0,
            callStrike: 520.0,
            putStrike: 480.0
        )
        
        // --- Create Strategy ---
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockOptionsService,
            optionsDataService: mockOptionsService,
            rollingWindowCalculator: RollingWindowCalculator(),
            expirationDateCalculator: mockExpirationCalculator,
            premiumMatcher: PremiumMatchingAlgorithm()
        )
        
        // --- Create AnalysisViewModel ---
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            expirationDateCalculator: mockExpirationCalculator,
            userId: "e2e-test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        analysisViewModel.setWatchlistTickers(["AAPL", "GOOGL", "MSFT", "NVDA"])
        
        // --- Run Batch Analysis ---
        await analysisViewModel.runAnalysis()

        
        // --- Verify Batch Analysis Results ---
        #expect(analysisViewModel.isRunningAnalysis == false)
        
        // Should have ticker errors for GOOGL (price fetch failed)
        #expect(analysisViewModel.hasTickerErrors == true)
        #expect(analysisViewModel.tickerErrors.count == 1, "Only GOOGL should fail completely")
        #expect(analysisViewModel.tickerErrors[0].ticker == "GOOGL")
        
        // Should have results for: AAPL (2), MSFT (2), NVDA (2) = 6 results
        // GOOGL fails completely and produces no results
        #expect(analysisViewModel.analysisResults.count == 6)
        
        // --- Verify AAPL: Full success with options data ---
        let aaplCall = analysisViewModel.analysisResults.first {
            $0.ticker == "AAPL" && $0.type == .call
        }
        #expect(aaplCall?.strikePrice == 190.0, "AAPL call should have strike price")
        #expect(aaplCall?.expirationDate != nil, "AAPL should have expiration")
        #expect(aaplCall?.midPremium != nil, "AAPL should have mid premium")
        
        // --- Verify MSFT: Graceful degradation (prices ok, options failed) ---
        let msftCall = analysisViewModel.analysisResults.first {
            $0.ticker == "MSFT" && $0.type == .call
        }
        #expect(msftCall?.currentPrice != nil, "MSFT should have current price")
        #expect(msftCall?.strikePrice == nil, "MSFT strike should be nil (options failed)")
        #expect(msftCall?.signal == .hold, "MSFT should be HOLD without options")
        
        // --- Verify NVDA: Full success with options data ---
        let nvdaCall = analysisViewModel.analysisResults.first {
            $0.ticker == "NVDA" && $0.type == .call
        }
        #expect(nvdaCall?.strikePrice == 520.0, "NVDA call should have strike price")
        #expect(nvdaCall?.expirationDate != nil, "NVDA should have expiration")
        
        // --- Verify Display Reflects Mixed Results ---
        let resultsViewModel = ResultsViewModel(
            resultsRepository: E2EMockResultsRepository(),
            userId: "e2e-test-user"
        )
        resultsViewModel.updateResults(analysisViewModel.analysisResults)
        
        // Results should include both successful and degraded results
        #expect(resultsViewModel.results.count == 6, "Should have 6 display rows")
        
        // MSFT should show N/A for options fields in display
        let msftDisplayRow = resultsViewModel.results.first {
            $0.ticker == "MSFT" && $0.type == "CALL"
        }
        #expect(msftDisplayRow?.strikePrice == "N/A", "MSFT strike should display as N/A")
        #expect(msftDisplayRow?.expirationDate == "N/A", "MSFT expiration should display as N/A")
        
        // AAPL and NVDA should have actual values
        let aaplDisplayRow = resultsViewModel.results.first {
            $0.ticker == "AAPL" && $0.type == "CALL"
        }
        #expect(aaplDisplayRow?.strikePrice != "N/A", "AAPL strike should have value")
    }
    
    // MARK: - Test 4: ONLY_ORDERS Filter with New Signal Logic
    
    @Test("ONLY_ORDERS filter works correctly with options-based signals")
    @MainActor
    func testOnlyOrdersFilterWithOptionsSignals() async throws {
        // Validates: Requirements 7.1-7.4 (ONLY_ORDERS filter compatibility)
        
        // --- Setup Mock Services ---
        let mockOptionsService = E2EMockOptionsDataService()
        let mockExpirationCalculator = E2EMockExpirationDateCalculator()
        
        let expirationDate = nextFriday(from: Date())
        mockExpirationCalculator.defaultExpiration = expirationDate
        
        // AAPL: Configure to produce ORDER signals (strikes beyond targets)
        mockOptionsService.priceDataByTicker["AAPL"] = createMockPriceData(
            ticker: "AAPL", days: 30, basePrice: 100.0
        )
        // Call strike above call target, put strike below put target
        mockOptionsService.optionsChainByTicker["AAPL"] = createMockOptionsChain(
            ticker: "AAPL",
            expirationDate: expirationDate,
            currentPrice: 100.0,
            callStrike: 120.0,  // Well above target, should generate ORDER
            putStrike: 80.0    // Well below target, should generate ORDER
        )
        
        // MSFT: Configure to produce HOLD signals (strikes within targets)
        mockOptionsService.priceDataByTicker["MSFT"] = createMockPriceData(
            ticker: "MSFT", days: 30, basePrice: 100.0
        )
        mockOptionsService.optionsChainByTicker["MSFT"] = createMockOptionsChain(
            ticker: "MSFT",
            expirationDate: expirationDate,
            currentPrice: 100.0,
            callStrike: 101.0,  // Close to current, likely HOLD
            putStrike: 99.0    // Close to current, likely HOLD
        )

        
        // --- Create Strategy and Run Analysis ---
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockOptionsService,
            optionsDataService: mockOptionsService,
            rollingWindowCalculator: RollingWindowCalculator(),
            expirationDateCalculator: mockExpirationCalculator,
            premiumMatcher: PremiumMatchingAlgorithm()
        )
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            expirationDateCalculator: mockExpirationCalculator,
            userId: "e2e-test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        analysisViewModel.setWatchlistTickers(["AAPL", "MSFT"])
        await analysisViewModel.runAnalysis()
        
        // --- Setup ResultsViewModel ---
        let resultsViewModel = ResultsViewModel(
            resultsRepository: E2EMockResultsRepository(),
            userId: "e2e-test-user"
        )
        resultsViewModel.updateResults(analysisViewModel.analysisResults)
        
        // All 4 results should be present
        #expect(resultsViewModel.results.count == 4)
        
        // Count ORDER signals
        let orderCount = analysisViewModel.analysisResults.filter { $0.signal == .order }.count
        let holdCount = analysisViewModel.analysisResults.filter { $0.signal == .hold }.count
        
        // --- Test ONLY_ORDERS Filter Disabled ---
        // Validates: Requirement 7.3 (Display all results when disabled)
        resultsViewModel.setOnlyOrdersFilter(false)
        #expect(resultsViewModel.filteredSortedResults.count == 4)
        
        // --- Test ONLY_ORDERS Filter Enabled ---
        // Validates: Requirement 7.1 (Only ORDER signals when enabled)
        resultsViewModel.setOnlyOrdersFilter(true)
        let filteredResults = resultsViewModel.filteredSortedResults
        
        // All filtered results should be ORDER signals
        for row in filteredResults {
            #expect(row.signal == "ORDER", "Filtered result should be ORDER")
        }
        
        // Validates: Requirement 7.2 (All ORDER signals are preserved)
        #expect(filteredResults.count == orderCount, "All ORDER signals should appear")
    }

}

// MARK: - Mock Services for End-to-End Testing

/// Mock options data service that supports both price and options chain fetching
/// with configurable failure scenarios for end-to-end testing.
final class E2EMockOptionsDataService: OptionsDataService {
    
    // MARK: - Data Storage
    
    var priceDataByTicker: [String: [PricePoint]] = [:]
    var earningsDateByTicker: [String: Date?] = [:]
    var optionsChainByTicker: [String: OptionsChain] = [:]
    
    // MARK: - Failure Configuration
    
    var shouldFailPriceForTickers: Set<String> = []
    var shouldFailOptionsForTickers: Set<String> = []
    
    // MARK: - Call Tracking
    
    private(set) var fetchPricesCallCount = 0
    private(set) var fetchEarningsCallCount = 0
    private(set) var fetchOptionsChainCallCount = 0
    
    // MARK: - MarketDataService Implementation
    
    func fetchHistoricalPrices(ticker: String, lookbackDays: Int) async throws -> [PricePoint] {
        fetchPricesCallCount += 1
        
        if shouldFailPriceForTickers.contains(ticker) {
            throw MarketDataError.fetchFailed(ticker: ticker, reason: "Network error")
        }
        
        if let data = priceDataByTicker[ticker] {
            return data
        }
        
        // Generate default mock data if not configured
        return createDefaultMockPriceData(days: lookbackDays)
    }
    
    func fetchEarningsDate(ticker: String) async throws -> Date? {
        fetchEarningsCallCount += 1
        return earningsDateByTicker[ticker] ?? Calendar.current.date(byAdding: .day, value: 30, to: Date())
    }

    
    // MARK: - OptionsDataService Implementation
    
    func fetchOptionsChain(ticker: String, expirationDate: Date) async throws -> OptionsChain {
        fetchOptionsChainCallCount += 1
        
        if shouldFailOptionsForTickers.contains(ticker) {
            throw OptionsDataError.networkError(underlying: "Network error for \(ticker)")
        }
        
        if let chain = optionsChainByTicker[ticker] {
            return chain
        }
        
        // Return empty chain if not configured (triggers graceful degradation)
        return OptionsChain.empty(ticker: ticker, expirationDate: expirationDate)
    }
    
    // MARK: - Default Data Generation
    
    private func createDefaultMockPriceData(days: Int) -> [PricePoint] {
        var prices: [PricePoint] = []
        let basePrice = 100.0
        let calendar = Calendar.current
        let today = Date()
        
        for i in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let variation = Double.random(in: -2...2)
                let trend = Double(days - i) * 0.05
                let price = basePrice + variation + trend
                prices.append(PricePoint(date: date, close: price))
            }
        }
        return prices
    }
}


/// Mock expiration date calculator for testing expiration logic.
final class E2EMockExpirationDateCalculator: ExpirationDateCalculation {
    
    var defaultExpiration: Date = Date()
    var validExpirationResult = true
    var isHolidayResult = false
    
    func calculateDefaultExpiration(from referenceDate: Date) -> Date {
        return defaultExpiration
    }
    
    func isValidExpirationDate(_ date: Date) -> Bool {
        return validExpirationResult
    }
    
    func isMarketHoliday(_ date: Date) -> Bool {
        return isHolidayResult
    }
}



/// Mock results repository for end-to-end testing.
final class E2EMockResultsRepository: ResultsRepository {
    
    var storedResults: [AnalysisResult]?
    var storedMetadata: ResultsMetadata?
    var shouldFail = false
    
    private(set) var saveResultsCount = 0
    private(set) var getResultsCount = 0
    
    func saveResults(_ results: [AnalysisResult], metadata: ResultsMetadata, for userId: String) async throws {
        saveResultsCount += 1
        if shouldFail {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        }
        storedResults = results
        storedMetadata = metadata
    }
    
    func getLatestResults(for userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)? {
        getResultsCount += 1
        if shouldFail {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Load failed"])
        }
        guard let results = storedResults, let metadata = storedMetadata else {
            return nil
        }
        return (results, metadata)
    }
    
    func getResults(forRunId runId: String, userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)? {
        return try await getLatestResults(for: userId)
    }
}


// MARK: - Helper Functions for Test Data Generation

/// Creates mock price data for a ticker with predictable pattern.
func createMockPriceData(ticker: String, days: Int, basePrice: Double) -> [PricePoint] {
    var prices: [PricePoint] = []
    let calendar = Calendar.current
    let today = Date()
    
    for i in (0..<days).reversed() {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            // Create price pattern: starts at 95% of base, ends at base
            // This creates a 5% gain over the period (best return)
            // And has a -3% dip in the middle (worst return)
            let progress = Double(days - i) / Double(days)
            var price: Double
            
            if progress < 0.3 {
                // Early: 95% of base, dropping to 92%
                price = basePrice * (0.95 - 0.03 * (progress / 0.3))
            } else if progress < 0.5 {
                // Middle: rise from 92% to 95%
                price = basePrice * (0.92 + 0.03 * ((progress - 0.3) / 0.2))
            } else {
                // Late: rise from 95% to 100%
                price = basePrice * (0.95 + 0.05 * ((progress - 0.5) / 0.5))
            }
            
            prices.append(PricePoint(date: date, close: price))
        }
    }
    return prices
}



/// Creates a mock options chain with specified strikes.
func createMockOptionsChain(
    ticker: String,
    expirationDate: Date,
    currentPrice: Double,
    callStrike: Double,
    putStrike: Double
) -> OptionsChain {
    let callOption = OptionContract(
        ticker: ticker,
        type: .call,
        strikePrice: callStrike,
        bid: 0.45,
        ask: 0.55,
        expirationDate: expirationDate
    )
    
    let putOption = OptionContract(
        ticker: ticker,
        type: .put,
        strikePrice: putStrike,
        bid: 0.40,
        ask: 0.50,
        expirationDate: expirationDate
    )
    
    return OptionsChain(
        ticker: ticker,
        expirationDate: expirationDate,
        calls: [callOption],
        puts: [putOption],
        fetchedAt: Date()
    )
}


/// Returns the next Friday from the given date.
func nextFriday(from date: Date) -> Date {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    
    // Calculate days until Friday (Friday = 6)
    var daysToAdd: Int
    switch weekday {
    case 1: daysToAdd = 5  // Sunday
    case 2: daysToAdd = 4  // Monday
    case 3: daysToAdd = 3  // Tuesday
    case 4: daysToAdd = 2  // Wednesday
    case 5: daysToAdd = 1  // Thursday
    case 6: daysToAdd = 7  // Friday - next week
    case 7: daysToAdd = 6  // Saturday
    default: daysToAdd = 0
    }
    
    return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
}
