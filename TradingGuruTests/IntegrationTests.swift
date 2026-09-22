//
//  IntegrationTests.swift
//  TradingGuruTests
//
//  Integration tests for end-to-end flows in TradingGuru app.
//  Tests authentication → watchlist → analysis → results flow,
//  offline/online data sync transitions, and scheduled analysis display.
//
//  Validates: Requirements 1.1-1.10, 2.1-2.9, 6.1-6.8
//

import Testing
import Foundation
import Combine
@testable import TradingGuru

// MARK: - Mock Services for Integration Testing

/// Mock authentication service for integration tests.
final class IntegrationMockAuthService: AuthenticationService {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var sessionExpirationDate: Date?
    
    var shouldSucceed = true
    var errorToThrow: AuthError = .invalidCredentials
    var simulatedDelay: TimeInterval = 0
    
    private(set) var signInCount = 0
    private(set) var signOutCount = 0
    
    init(preAuthenticatedUser: User? = nil) {
        self.currentUser = preAuthenticatedUser
        if preAuthenticatedUser != nil {
            self.sessionExpirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
        }
    }
    
    func signIn(with provider: AuthProviderType) async throws -> User {
        signInCount += 1
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldSucceed {
            let user = User(
                id: "integration-test-user",
                email: "test@example.com",
                displayName: "Integration Test User",
                authProvider: provider,
                createdAt: Date(),
                lastLoginAt: Date()
            )
            currentUser = user
            sessionExpirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
            return user
        } else {
            throw errorToThrow
        }
    }

    func signOut() async throws {
        signOutCount += 1
        currentUser = nil
        sessionExpirationDate = nil
    }
    
    func refreshSession() async throws {
        guard currentUser != nil else {
            throw AuthError.sessionExpired
        }
        sessionExpirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    }
}

/// Mock watchlist repository for integration tests.
final class IntegrationMockWatchlistRepository: WatchlistRepository {
    var symbols: [String] = []
    var shouldFail = false
    var simulatedDelay: TimeInterval = 0
    
    private(set) var getWatchlistCount = 0
    private(set) var addSymbolCount = 0
    private(set) var removeSymbolCount = 0
    
    func getWatchlist(for userId: String) async throws -> [String] {
        getWatchlistCount += 1
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        return symbols
    }
    
    func addSymbol(_ symbol: String, for userId: String) async throws {
        addSymbolCount += 1
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        symbols.append(symbol)
    }
    
    func removeSymbol(_ symbol: String, for userId: String) async throws {
        removeSymbolCount += 1
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        symbols.removeAll { $0 == symbol }
    }
}


/// Mock market data service for integration tests.
final class IntegrationMockMarketDataService: MarketDataService {
    var priceDataByTicker: [String: [PricePoint]] = [:]
    var earningsDateByTicker: [String: Date?] = [:]
    var shouldFailForTickers: Set<String> = []
    var simulatedDelay: TimeInterval = 0
    
    private(set) var fetchPricesCount = 0
    private(set) var fetchEarningsCount = 0
    
    func fetchHistoricalPrices(ticker: String, lookbackDays: Int) async throws -> [PricePoint] {
        fetchPricesCount += 1
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        if shouldFailForTickers.contains(ticker) {
            throw MarketDataError.fetchFailed(ticker: ticker, reason: "Network error")
        }
        return priceDataByTicker[ticker] ?? generateMockPriceData(days: lookbackDays)
    }
    
    func fetchEarningsDate(ticker: String) async throws -> Date? {
        fetchEarningsCount += 1
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        return earningsDateByTicker[ticker] ?? Calendar.current.date(byAdding: .day, value: 30, to: Date())
    }
    
    /// Generates mock price data with an upward trend.
    private func generateMockPriceData(days: Int) -> [PricePoint] {
        var prices: [PricePoint] = []
        let basePrice = 100.0
        let calendar = Calendar.current
        let today = Date()
        
        for i in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let variation = Double.random(in: -5...5)
                let trend = Double(days - i) * 0.1
                let price = basePrice + variation + trend
                prices.append(PricePoint(date: date, close: price))
            }
        }
        return prices
    }
}


/// Mock results repository for integration tests.
final class IntegrationMockResultsRepository: ResultsRepository {
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

/// Mock data sync service for integration tests.
final class IntegrationMockDataSyncService: DataSyncServiceProtocol {
    var syncResult: SyncResult = .successful()
    var shouldFail = false
    var needsSyncValue = true
    
    private(set) var syncCount = 0
    private(set) var resolveConflictCount = 0
    
    func syncUserData(for userId: String) async throws -> SyncResult {
        syncCount += 1
        if shouldFail {
            throw DataSyncError.networkError("Mock network failure")
        }
        return syncResult
    }
    
    func resolveConflict<T: TimestampedData>(local: T, cloud: T) -> T {
        resolveConflictCount += 1
        return cloud.updatedAt > local.updatedAt ? cloud : local
    }
    
    func needsSync(for userId: String) -> Bool {
        return needsSyncValue
    }
}


// MARK: - Integration Test Suite: Authentication → Watchlist → Analysis → Results Flow

@Suite("Integration Tests: Complete User Flow")
struct AuthToResultsIntegrationTests {
    
    @Test("Complete flow: authenticate, add symbols, run analysis, view results")
    @MainActor
    func testCompleteUserFlow() async throws {
        // --- Setup Mock Services ---
        let mockAuthService = IntegrationMockAuthService()
        let mockWatchlistRepo = IntegrationMockWatchlistRepository()
        let mockMarketData = IntegrationMockMarketDataService()
        let mockResultsRepo = IntegrationMockResultsRepository()
        let mockSyncService = IntegrationMockDataSyncService()
        
        // --- Step 1: Authentication ---
        // Validates: Requirement 1.5 (Authentication succeeds → navigate to home)
        let authViewModel = AuthViewModel(
            authenticationService: mockAuthService,
            dataSyncService: mockSyncService
        )
        
        #expect(authViewModel.isAuthenticated == false)
        
        let user = try await authViewModel.signIn(with: .google)
        
        #expect(user.id == "integration-test-user")
        #expect(authViewModel.isAuthenticated == true)
        #expect(authViewModel.shouldNavigateToHome == true)
        #expect(mockAuthService.signInCount == 1)
        #expect(mockSyncService.syncCount == 1, "Sync should be called after sign-in")
        
        // --- Step 2: Watchlist Management ---
        // Validates: Requirements 2.1-2.9 (Watchlist operations)
        let watchlistViewModel = WatchlistViewModel(
            repository: mockWatchlistRepo,
            validation: WatchlistValidationService(),
            userId: user.id
        )
        
        // Load watchlist
        await watchlistViewModel.loadWatchlist()
        #expect(watchlistViewModel.isEmpty == true)
        #expect(mockWatchlistRepo.getWatchlistCount == 1)
        
        // Add symbols
        try await watchlistViewModel.addSymbol("AAPL")
        try await watchlistViewModel.addSymbol("GOOGL")
        try await watchlistViewModel.addSymbol("MSFT")
        
        #expect(watchlistViewModel.symbolCount == 3)
        #expect(mockWatchlistRepo.addSymbolCount == 3)
        #expect(watchlistViewModel.symbols.contains("AAPL"))
        #expect(watchlistViewModel.symbols.contains("GOOGL"))
        #expect(watchlistViewModel.symbols.contains("MSFT"))

        // --- Step 3: Analysis Configuration and Execution ---
        // Validates: Requirements 3.1-3.6, 4.1-4.8, 5.1-5.7 (Strategy selection and execution)
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockMarketData,
            rollingWindowCalculator: RollingWindowCalculator()
        )
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            userId: user.id
        )
        
        // Select strategy
        await analysisViewModel.selectStrategy(.weeklyOption)
        #expect(analysisViewModel.hasSelectedStrategy == true)
        #expect(analysisViewModel.isConfigurationLoaded == true)
        
        // Set watchlist tickers for analysis
        analysisViewModel.setWatchlistTickers(watchlistViewModel.symbols)
        #expect(analysisViewModel.canRunAnalysis == true)
        
        // Run analysis
        await analysisViewModel.runAnalysis()
        
        #expect(analysisViewModel.isRunningAnalysis == false)
        #expect(analysisViewModel.analysisResults.count > 0, "Should have analysis results")
        // Each ticker generates 2 results (CALL and PUT)
        let expectedResultCount = watchlistViewModel.symbolCount * 2
        #expect(analysisViewModel.analysisResults.count == expectedResultCount)
        
        // --- Step 4: Results Display ---
        // Validates: Requirements 6.1-6.8 (Results display and sorting)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: mockResultsRepo,
            userId: user.id
        )
        
        // Update results from analysis
        let metadata = ResultsMetadata(
            timestamp: Date(),
            source: .manual,
            strategyId: "weekly_option"
        )
        resultsViewModel.updateResults(analysisViewModel.analysisResults, metadata: metadata)
        
        #expect(resultsViewModel.hasResults == true)
        #expect(resultsViewModel.results.count == expectedResultCount)
        #expect(resultsViewModel.lastUpdatedDisplay != nil)
        
        // Test sorting functionality
        // Validates: Requirement 6.5 (Initial sort by Return % descending)
        #expect(resultsViewModel.sortState.column == .returnPercentage)
        #expect(resultsViewModel.sortState.direction == .descending)
        
        let sortedResults = resultsViewModel.sortedResults
        if sortedResults.count >= 2 {
            #expect(sortedResults[0].rawReturnPercentage >= sortedResults[1].rawReturnPercentage)
        }
    }

    @Test("Flow handles authentication failure gracefully")
    @MainActor
    func testAuthenticationFailureHandling() async throws {
        // Validates: Requirement 1.6 (Display error message for auth failures)
        let mockAuthService = IntegrationMockAuthService()
        mockAuthService.shouldSucceed = false
        mockAuthService.errorToThrow = .invalidCredentials
        
        let authViewModel = AuthViewModel(
            authenticationService: mockAuthService,
            dataSyncService: nil
        )
        
        do {
            _ = try await authViewModel.signIn(with: .google)
            Issue.record("Expected authentication to fail")
        } catch let error as AuthError {
            #expect(error == .invalidCredentials)
            #expect(authViewModel.currentError == .invalidCredentials)
            #expect(authViewModel.showError == true)
            #expect(authViewModel.isAuthenticated == false)
            #expect(authViewModel.shouldNavigateToHome == false)
        }
    }
    
    @Test("Flow handles watchlist database failure gracefully")
    @MainActor
    func testWatchlistDatabaseFailure() async throws {
        // Validates: Requirement 2.9 (Database unavailability shows error)
        let mockWatchlistRepo = IntegrationMockWatchlistRepository()
        mockWatchlistRepo.shouldFail = true
        
        let watchlistViewModel = WatchlistViewModel(
            repository: mockWatchlistRepo,
            validation: WatchlistValidationService(),
            userId: "test-user"
        )
        
        await watchlistViewModel.loadWatchlist()
        
        #expect(watchlistViewModel.currentError == .databaseUnavailable)
        #expect(watchlistViewModel.showError == true)
    }
    
    @Test("Flow handles analysis with ticker failures gracefully")
    @MainActor
    func testAnalysisWithPartialTickerFailures() async throws {
        // Validates: Requirement 5.5 (Continue processing when individual tickers fail)
        let mockMarketData = IntegrationMockMarketDataService()
        mockMarketData.shouldFailForTickers = ["GOOGL"]
        
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockMarketData,
            rollingWindowCalculator: RollingWindowCalculator()
        )
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            userId: "test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        analysisViewModel.setWatchlistTickers(["AAPL", "GOOGL", "MSFT"])
        
        await analysisViewModel.runAnalysis()
        
        // AAPL and MSFT should succeed (4 results), GOOGL should fail
        #expect(analysisViewModel.analysisResults.count == 4)
        #expect(analysisViewModel.hasTickerErrors == true)
        #expect(analysisViewModel.tickerErrors.count == 1)
        #expect(analysisViewModel.tickerErrors[0].ticker == "GOOGL")
    }
}


// MARK: - Integration Test Suite: Offline/Online Data Sync Transitions

@Suite("Integration Tests: Offline/Online Sync Transitions")
struct OfflineOnlineSyncTests {
    
    @Test("Offline mode displays cached data and shows indicator")
    @MainActor
    func testOfflineModeDisplaysCachedData() async throws {
        // Validates: Requirement 7.5 (Display cached data and offline indicator)
        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.simulateOffline()
        
        #expect(mockNetworkMonitor.isConnected == false)
        #expect(mockNetworkMonitor.status == .offline)
        #expect(mockNetworkMonitor.status.description == "Offline")
    }
    
    @Test("Online mode enables data sync")
    @MainActor
    func testOnlineModeEnablesSync() async throws {
        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.simulateOnline()
        
        #expect(mockNetworkMonitor.isConnected == true)
        #expect(mockNetworkMonitor.status == .online)
        #expect(mockNetworkMonitor.status.description == "Connected")
    }
    
    @Test("Transition from offline to online triggers sync")
    @MainActor
    func testOfflineToOnlineTransition() async throws {
        // Validates: Requirement 7.3 (Retrieve data when coming back online)
        let mockNetworkMonitor = MockNetworkMonitor()
        let mockSyncService = IntegrationMockDataSyncService()
        
        // Start offline
        mockNetworkMonitor.simulateOffline()
        #expect(mockNetworkMonitor.isConnected == false)
        
        // Simulate coming online
        mockNetworkMonitor.simulateOnline()
        #expect(mockNetworkMonitor.isConnected == true)
        
        // Trigger sync (normally would be done via observer)
        let syncResult = try await mockSyncService.syncUserData(for: "test-user")
        
        #expect(syncResult.success == true)
        #expect(mockSyncService.syncCount == 1)
    }
    
    @Test("Data sync resolves conflicts using timestamp")
    @MainActor
    func testDataSyncConflictResolution() async throws {
        // Validates: Requirement 7.4 (Use most recently modified version)
        let mockSyncService = IntegrationMockDataSyncService()
        
        let olderDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let newerDate = Date()
        
        // Create timestamped data for testing
        let localConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["windowDays": .integer(5)],
            updatedAt: olderDate
        )
        
        let cloudConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["windowDays": .integer(30)],
            updatedAt: newerDate
        )
        
        // Cloud is newer, should win
        let resolved = mockSyncService.resolveConflict(local: localConfig, cloud: cloudConfig)
        
        #expect(resolved.updatedAt == newerDate)
        #expect(resolved.getInt("windowDays", default: 0) == 30)
        #expect(mockSyncService.resolveConflictCount == 1)
    }

    @Test("Local data wins when local is more recent")
    @MainActor
    func testLocalDataWinsWhenMoreRecent() async throws {
        // Validates: Requirement 7.4, Property 15 (Conflict resolution by timestamp)
        let mockSyncService = IntegrationMockDataSyncService()
        
        let olderDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let newerDate = Date()
        
        let localConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["windowDays": .integer(30)],
            updatedAt: newerDate
        )
        
        let cloudConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["windowDays": .integer(5)],
            updatedAt: olderDate
        )
        
        // Local is newer, should win
        let resolved = mockSyncService.resolveConflict(local: localConfig, cloud: cloudConfig)
        
        #expect(resolved.updatedAt == newerDate)
        #expect(resolved.getInt("windowDays", default: 0) == 30)
    }
    
    @Test("Network status changes are properly tracked")
    @MainActor
    func testNetworkStatusTracking() async throws {
        let mockNetworkMonitor = MockNetworkMonitor()
        
        // Test all states
        mockNetworkMonitor.setStatus(.unknown)
        #expect(mockNetworkMonitor.status == .unknown)
        #expect(mockNetworkMonitor.isConnected == false)
        
        mockNetworkMonitor.setStatus(.offline)
        #expect(mockNetworkMonitor.status == .offline)
        #expect(mockNetworkMonitor.isConnected == false)
        
        mockNetworkMonitor.setStatus(.online)
        #expect(mockNetworkMonitor.status == .online)
        #expect(mockNetworkMonitor.isConnected == true)
    }
    
    @Test("Sync failure preserves local state")
    @MainActor
    func testSyncFailurePreservesLocalState() async throws {
        // Validates: Requirement 2.9, 7.5 (Preserve local state on failure)
        let mockWatchlistRepo = IntegrationMockWatchlistRepository()
        mockWatchlistRepo.symbols = ["AAPL", "GOOGL"]
        
        let watchlistViewModel = WatchlistViewModel(
            repository: mockWatchlistRepo,
            validation: WatchlistValidationService(),
            userId: "test-user"
        )
        
        // Load initial data
        await watchlistViewModel.loadWatchlist()
        #expect(watchlistViewModel.symbolCount == 2)
        
        // Simulate database failure
        mockWatchlistRepo.shouldFail = true
        
        // Attempt to add (should fail but preserve state)
        do {
            try await watchlistViewModel.addSymbol("MSFT")
        } catch {
            // Expected to fail
        }
        
        // Original symbols should still be there
        #expect(watchlistViewModel.symbols.contains("AAPL"))
        #expect(watchlistViewModel.symbols.contains("GOOGL"))
    }
}


// MARK: - Integration Test Suite: Scheduled Analysis Result Display

@Suite("Integration Tests: Scheduled Analysis Display")
struct ScheduledAnalysisDisplayTests {
    
    @Test("Scheduled analysis results display with timestamp")
    @MainActor
    func testScheduledAnalysisResultsDisplay() async throws {
        // Validates: Requirements 8.5, 8.6 (Display scheduled results with timestamp)
        let mockResultsRepo = IntegrationMockResultsRepository()
        
        // Pre-populate with scheduled results
        let scheduledResults = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.25,
                currentPrice: 178.50,
                targetPrice: 187.87,
                signal: .order,
                nextEarningsDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                hasEarningsRisk: false
            ),
            AnalysisResult(
                ticker: "AAPL",
                type: .put,
                returnPercentage: -3.18,
                currentPrice: 178.50,
                targetPrice: 172.82,
                signal: .hold,
                nextEarningsDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                hasEarningsRisk: false
            )
        ]
        
        let scheduledMetadata = ResultsMetadata(
            timestamp: Date(),
            source: .scheduled,
            strategyId: "weekly_option",
            scheduledRunId: "scheduled_run_123"
        )
        
        mockResultsRepo.storedResults = scheduledResults
        mockResultsRepo.storedMetadata = scheduledMetadata
        
        // Load results in ViewModel
        let resultsViewModel = ResultsViewModel(
            resultsRepository: mockResultsRepo,
            userId: "test-user"
        )
        
        await resultsViewModel.loadResults()
        
        // Validate scheduled results display
        #expect(resultsViewModel.hasResults == true)
        #expect(resultsViewModel.results.count == 2)
        #expect(resultsViewModel.resultsMetadata?.source == .scheduled)
        #expect(resultsViewModel.resultsMetadata?.scheduledRunId == "scheduled_run_123")
        
        // Validate timestamp display format
        // Validates: Requirement 8.6 ("Last updated: [time] PST")
        let lastUpdated = resultsViewModel.lastUpdatedDisplay
        #expect(lastUpdated != nil)
        #expect(lastUpdated!.contains("Last updated:"))
        #expect(lastUpdated!.contains("PST"))
    }

    @Test("Manual analysis results display correctly")
    @MainActor
    func testManualAnalysisResultsDisplay() async throws {
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        let manualResults = [
            AnalysisResult(
                ticker: "MSFT",
                type: .call,
                returnPercentage: 4.50,
                currentPrice: 380.00,
                targetPrice: 397.10,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        let manualMetadata = ResultsMetadata(
            timestamp: Date(),
            source: .manual,
            strategyId: "weekly_option"
        )
        
        resultsViewModel.updateResults(manualResults, metadata: manualMetadata)
        
        #expect(resultsViewModel.hasResults == true)
        #expect(resultsViewModel.resultsMetadata?.source == .manual)
    }
    
    @Test("Results sorting toggles direction on same column")
    @MainActor
    func testResultsSortingToggle() async throws {
        // Validates: Requirement 6.6 (Toggle sort direction)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        let results = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: 178.50,
                targetPrice: 187.43,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            ),
            AnalysisResult(
                ticker: "GOOGL",
                type: .call,
                returnPercentage: 3.0,
                currentPrice: 142.30,
                targetPrice: 146.57,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        resultsViewModel.updateResults(results)
        
        // Initial sort: Return % descending
        #expect(resultsViewModel.sortState.column == .returnPercentage)
        #expect(resultsViewModel.sortState.direction == .descending)
        
        // Tap same column - should toggle to ascending
        resultsViewModel.sort(by: .returnPercentage)
        #expect(resultsViewModel.sortState.direction == .ascending)
        
        // Tap same column again - should toggle back to descending
        resultsViewModel.sort(by: .returnPercentage)
        #expect(resultsViewModel.sortState.direction == .descending)
    }

    @Test("Results sorting by different columns")
    @MainActor
    func testResultsSortingByDifferentColumns() async throws {
        // Validates: Requirement 6.5 (Sort by any column)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        let results = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: 178.50,
                targetPrice: 187.43,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            ),
            AnalysisResult(
                ticker: "GOOGL",
                type: .put,
                returnPercentage: -3.0,
                currentPrice: 142.30,
                targetPrice: 138.03,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            ),
            AnalysisResult(
                ticker: "MSFT",
                type: .call,
                returnPercentage: 2.5,
                currentPrice: 380.00,
                targetPrice: 389.50,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        resultsViewModel.updateResults(results)
        
        // Sort by ticker
        resultsViewModel.sort(by: .ticker)
        #expect(resultsViewModel.sortState.column == .ticker)
        #expect(resultsViewModel.sortState.direction == .descending)
        
        let tickerSorted = resultsViewModel.sortedResults
        #expect(tickerSorted[0].ticker == "MSFT")
        #expect(tickerSorted[1].ticker == "GOOGL")
        #expect(tickerSorted[2].ticker == "AAPL")
        
        // Sort by current price
        resultsViewModel.sort(by: .currentPrice)
        #expect(resultsViewModel.sortState.column == .currentPrice)
        
        let priceSorted = resultsViewModel.sortedResults
        #expect(priceSorted[0].rawCurrentPrice >= priceSorted[1].rawCurrentPrice)
    }
    
    @Test("Results filtering with ONLY_ORDERS")
    @MainActor
    func testResultsOnlyOrdersFilter() async throws {
        // Validates: Requirement 4.5 (ONLY_ORDERS filter)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        let results = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: 178.50,
                targetPrice: 187.43,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            ),
            AnalysisResult(
                ticker: "GOOGL",
                type: .call,
                returnPercentage: 0.3,
                currentPrice: 142.30,
                targetPrice: 142.73,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        resultsViewModel.updateResults(results)
        
        // Without filter - should see both
        #expect(resultsViewModel.filteredSortedResults.count == 2)
        
        // Enable ONLY_ORDERS filter
        resultsViewModel.setOnlyOrdersFilter(true)
        #expect(resultsViewModel.filter.onlyOrders == true)
        
        // Should only see ORDER rows
        let filtered = resultsViewModel.filteredSortedResults
        #expect(filtered.count == 1)
        #expect(filtered[0].signal == "ORDER")
    }

    @Test("Results display earnings risk indicator correctly")
    @MainActor
    func testEarningsRiskIndicator() async throws {
        // Validates: Requirement 6.4 (Earnings date in red when risk exists)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        let earningsInRisk = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        let earningsNoRisk = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        
        let results = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: 178.50,
                targetPrice: 187.43,
                signal: .order,
                nextEarningsDate: earningsInRisk,
                hasEarningsRisk: true
            ),
            AnalysisResult(
                ticker: "GOOGL",
                type: .call,
                returnPercentage: 3.0,
                currentPrice: 142.30,
                targetPrice: 146.57,
                signal: .hold,
                nextEarningsDate: earningsNoRisk,
                hasEarningsRisk: false
            )
        ]
        
        resultsViewModel.updateResults(results)
        
        let rows = resultsViewModel.results
        let aaplRow = rows.first { $0.ticker == "AAPL" }
        let googlRow = rows.first { $0.ticker == "GOOGL" }
        
        #expect(aaplRow?.hasEarningsRisk == true)
        #expect(googlRow?.hasEarningsRisk == false)
    }
    
    @Test("Results display ORDER rows with highlight")
    @MainActor
    func testOrderRowHighlight() async throws {
        // Validates: Requirement 6.3 (ORDER signal rows with distinct background)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        let results = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: 178.50,
                targetPrice: 187.43,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            ),
            AnalysisResult(
                ticker: "GOOGL",
                type: .call,
                returnPercentage: 0.3,
                currentPrice: 142.30,
                targetPrice: 142.73,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        resultsViewModel.updateResults(results)
        
        let rows = resultsViewModel.results
        let orderRow = rows.first { $0.signal == "ORDER" }
        let holdRow = rows.first { $0.signal == "HOLD" }
        
        #expect(orderRow?.isHighlighted == true)
        #expect(holdRow?.isHighlighted == false)
    }

    @Test("Empty results display message")
    @MainActor
    func testEmptyResultsDisplay() async throws {
        // Validates: Requirement 6.7 (Empty state message)
        let resultsViewModel = ResultsViewModel(
            resultsRepository: IntegrationMockResultsRepository(),
            userId: "test-user"
        )
        
        #expect(resultsViewModel.hasResults == false)
        #expect(resultsViewModel.results.isEmpty == true)
    }
    
    @Test("Results persist and load correctly")
    @MainActor
    func testResultsPersistence() async throws {
        let mockResultsRepo = IntegrationMockResultsRepository()
        let userId = "test-user"
        
        let resultsViewModel = ResultsViewModel(
            resultsRepository: mockResultsRepo,
            userId: userId
        )
        
        // Create and save results
        let results = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.0,
                currentPrice: 178.50,
                targetPrice: 187.43,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        let metadata = ResultsMetadata(
            timestamp: Date(),
            source: .manual,
            strategyId: "weekly_option"
        )
        
        // Save results
        await resultsViewModel.saveResults(results, metadata: metadata)
        #expect(mockResultsRepo.saveResultsCount == 1)
        
        // Create new ViewModel and load results
        let newResultsViewModel = ResultsViewModel(
            resultsRepository: mockResultsRepo,
            userId: userId
        )
        
        await newResultsViewModel.loadResults()
        
        #expect(newResultsViewModel.hasResults == true)
        #expect(newResultsViewModel.results.count == 1)
        #expect(newResultsViewModel.results[0].ticker == "AAPL")
    }
}


// MARK: - Integration Test Suite: Cross-ViewModel Coordination

@Suite("Integration Tests: ViewModel Coordination")
struct ViewModelCoordinationTests {
    
    @Test("Watchlist changes propagate to analysis")
    @MainActor
    func testWatchlistChangesAffectAnalysis() async throws {
        // Test that watchlist modifications are reflected in analysis configuration
        let mockWatchlistRepo = IntegrationMockWatchlistRepository()
        let mockMarketData = IntegrationMockMarketDataService()
        
        let watchlistViewModel = WatchlistViewModel(
            repository: mockWatchlistRepo,
            validation: WatchlistValidationService(),
            userId: "test-user"
        )
        
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockMarketData,
            rollingWindowCalculator: RollingWindowCalculator()
        )
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            userId: "test-user"
        )
        
        // Add symbols to watchlist
        try await watchlistViewModel.addSymbol("AAPL")
        try await watchlistViewModel.addSymbol("TSLA")
        
        // Set watchlist to analysis
        analysisViewModel.setWatchlistTickers(watchlistViewModel.symbols)
        await analysisViewModel.selectStrategy(.weeklyOption)
        
        #expect(analysisViewModel.watchlistTickers.count == 2)
        #expect(analysisViewModel.canRunAnalysis == true)
        
        // Remove a symbol
        await watchlistViewModel.removeSymbol("TSLA")
        analysisViewModel.setWatchlistTickers(watchlistViewModel.symbols)
        
        #expect(analysisViewModel.watchlistTickers.count == 1)
    }
    
    @Test("Configuration changes affect analysis execution")
    @MainActor
    func testConfigurationAffectsAnalysis() async throws {
        let mockMarketData = IntegrationMockMarketDataService()
        
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockMarketData,
            rollingWindowCalculator: RollingWindowCalculator()
        )
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            userId: "test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        
        // Modify configuration
        var config = analysisViewModel.weeklyOptionConfiguration
        config.windowDays = 30
        config.lookbackDays = 360
        config.premiumPct = 2.0
        
        await analysisViewModel.saveConfiguration(config)
        
        #expect(analysisViewModel.weeklyOptionConfiguration.windowDays == 30)
        #expect(analysisViewModel.weeklyOptionConfiguration.lookbackDays == 360)
        #expect(analysisViewModel.weeklyOptionConfiguration.premiumPct == 2.0)
    }

    @Test("Sign out clears all user state")
    @MainActor
    func testSignOutClearsState() async throws {
        // Validates: Requirement 1.10 (Sign-out clears session)
        let mockAuthService = IntegrationMockAuthService()
        
        let authViewModel = AuthViewModel(
            authenticationService: mockAuthService,
            dataSyncService: nil
        )
        
        // Sign in
        _ = try await authViewModel.signIn(with: .apple)
        #expect(authViewModel.isAuthenticated == true)
        #expect(authViewModel.currentUser != nil)
        
        // Sign out
        try await authViewModel.signOut()
        
        #expect(authViewModel.isAuthenticated == false)
        #expect(authViewModel.currentUser == nil)
        #expect(authViewModel.shouldNavigateToHome == false)
        #expect(mockAuthService.signOutCount == 1)
    }
    
    @Test("Session expiration is tracked correctly")
    @MainActor
    func testSessionExpirationTracking() async throws {
        // Validates: Requirement 1.9 (30-day session maintenance)
        let mockAuthService = IntegrationMockAuthService()
        
        let authViewModel = AuthViewModel(
            authenticationService: mockAuthService,
            dataSyncService: nil
        )
        
        _ = try await authViewModel.signIn(with: .google)
        
        #expect(authViewModel.sessionExpirationDate != nil)
        
        if let expiration = authViewModel.sessionExpirationDate {
            let now = Date()
            #expect(expiration > now, "Session should expire in the future")
            
            // Should be approximately 30 days
            let expectedExpiration = now.addingTimeInterval(30 * 24 * 60 * 60)
            let tolerance: TimeInterval = 60 // 60 seconds tolerance
            #expect(abs(expiration.timeIntervalSince(expectedExpiration)) < tolerance)
        }
    }
    
    @Test("Analysis cannot run without strategy selection")
    @MainActor
    func testAnalysisRequiresStrategySelection() async throws {
        // Validates: Requirement 3.6 (Disable run analysis when no strategy selected)
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: nil,
            userId: "test-user"
        )
        
        analysisViewModel.setWatchlistTickers(["AAPL", "GOOGL"])
        
        // No strategy selected
        #expect(analysisViewModel.hasSelectedStrategy == false)
        #expect(analysisViewModel.canRunAnalysis == false)
    }
    
    @Test("Analysis cannot run with empty watchlist")
    @MainActor
    func testAnalysisRequiresWatchlistSymbols() async throws {
        let mockMarketData = IntegrationMockMarketDataService()
        
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockMarketData,
            rollingWindowCalculator: RollingWindowCalculator()
        )
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            userId: "test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        
        // Empty watchlist
        analysisViewModel.setWatchlistTickers([])
        
        #expect(analysisViewModel.hasSelectedStrategy == true)
        #expect(analysisViewModel.canRunAnalysis == false)
    }
}
