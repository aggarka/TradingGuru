//
//  TradingGuruTests.swift
//  TradingGuruTests
//
//  Unit tests for TradingGuru iOS App Domain Models
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - User Tests

@Suite("User Model Tests")
struct UserTests {
    
    @Test("User initialization with all parameters")
    func testInitWithAllParameters() {
        let id = "user-123"
        let email = "test@example.com"
        let displayName = "Test User"
        let authProvider = AuthProviderType.google
        let createdAt = Date(timeIntervalSince1970: 1000)
        let lastLoginAt = Date(timeIntervalSince1970: 2000)
        
        let user = User(
            id: id,
            email: email,
            displayName: displayName,
            authProvider: authProvider,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt
        )
        
        #expect(user.id == id)
        #expect(user.email == email)
        #expect(user.displayName == displayName)
        #expect(user.authProvider == authProvider)
        #expect(user.createdAt == createdAt)
        #expect(user.lastLoginAt == lastLoginAt)
    }
    
    @Test("User initialization with optional parameters as nil")
    func testInitWithNilOptionals() {
        let user = User(
            id: "user-456",
            email: nil,
            displayName: nil,
            authProvider: .apple
        )
        
        #expect(user.id == "user-456")
        #expect(user.email == nil)
        #expect(user.displayName == nil)
        #expect(user.authProvider == .apple)
    }

    @Test("User Codable encoding/decoding round-trip preserves all values")
    func testCodableRoundTrip() throws {
        let original = User(
            id: "user-789",
            email: "roundtrip@test.com",
            displayName: "Round Trip",
            authProvider: .passkey,
            createdAt: Date(timeIntervalSince1970: 1700000000),
            lastLoginAt: Date(timeIntervalSince1970: 1700100000)
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(User.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("User Identifiable conformance")
    func testIdentifiable() {
        let user = User(id: "identifiable-test", authProvider: .google)
        #expect(user.id == "identifiable-test")
    }
    
    @Test("User Equatable conformance")
    func testEquatable() {
        let date = Date()
        let user1 = User(id: "eq-test", email: "eq@test.com", authProvider: .apple, createdAt: date, lastLoginAt: date)
        let user2 = User(id: "eq-test", email: "eq@test.com", authProvider: .apple, createdAt: date, lastLoginAt: date)
        let user3 = User(id: "different", authProvider: .google)
        
        #expect(user1 == user2)
        #expect(user1 != user3)
    }
}


// MARK: - UserSettings Tests

@Suite("UserSettings Model Tests")
struct UserSettingsTests {
    
    @Test("UserSettings default values are applied correctly")
    func testDefaultValues() {
        let settings = UserSettings()
        
        #expect(settings.notificationEmail == nil)
        #expect(settings.emailNotificationsEnabled == true)
        #expect(settings.scheduledAnalysisEnabled == true)
    }
    
    @Test("UserSettings static default matches expected values")
    func testStaticDefault() {
        let settings = UserSettings.default
        
        #expect(settings.notificationEmail == nil)
        #expect(settings.emailNotificationsEnabled == true)
        #expect(settings.scheduledAnalysisEnabled == true)
    }
    
    @Test("UserSettings initialization with custom values")
    func testCustomValues() {
        let customDate = Date(timeIntervalSince1970: 1600000000)
        let settings = UserSettings(
            notificationEmail: "custom@email.com",
            emailNotificationsEnabled: false,
            scheduledAnalysisEnabled: false,
            updatedAt: customDate
        )
        
        #expect(settings.notificationEmail == "custom@email.com")
        #expect(settings.emailNotificationsEnabled == false)
        #expect(settings.scheduledAnalysisEnabled == false)
        #expect(settings.updatedAt == customDate)
    }
    
    @Test("UserSettings Codable encoding/decoding round-trip")
    func testCodableRoundTrip() throws {
        let original = UserSettings(
            notificationEmail: "roundtrip@settings.com",
            emailNotificationsEnabled: false,
            scheduledAnalysisEnabled: true,
            updatedAt: Date(timeIntervalSince1970: 1700000000)
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(UserSettings.self, from: data)
        
        #expect(decoded == original)
    }

    @Test("UserSettings hasValidEmail with nil email returns true")
    func testHasValidEmailWithNil() {
        let settings = UserSettings(notificationEmail: nil)
        #expect(settings.hasValidEmail == true)
    }
    
    @Test("UserSettings hasValidEmail with empty string returns true")
    func testHasValidEmailWithEmpty() {
        let settings = UserSettings(notificationEmail: "")
        #expect(settings.hasValidEmail == true)
    }
    
    @Test("UserSettings hasValidEmail with valid email returns true")
    func testHasValidEmailWithValid() {
        let validEmails = [
            "test@example.com",
            "user.name@domain.org",
            "a@b.io"
        ]
        
        for email in validEmails {
            let settings = UserSettings(notificationEmail: email)
            #expect(settings.hasValidEmail == true, "Expected \(email) to be valid")
        }
    }
    
    @Test("UserSettings hasValidEmail with invalid email returns false")
    func testHasValidEmailWithInvalid() {
        let invalidEmails = [
            "invalid",
            "no-at-sign.com",
            "@nodomain.com"
        ]
        
        for email in invalidEmails {
            let settings = UserSettings(notificationEmail: email)
            #expect(settings.hasValidEmail == false, "Expected \(email) to be invalid")
        }
    }
    
    @Test("UserSettings Equatable conformance")
    func testEquatable() {
        let date = Date()
        let settings1 = UserSettings(notificationEmail: "eq@test.com", emailNotificationsEnabled: true, scheduledAnalysisEnabled: true, updatedAt: date)
        let settings2 = UserSettings(notificationEmail: "eq@test.com", emailNotificationsEnabled: true, scheduledAnalysisEnabled: true, updatedAt: date)
        let settings3 = UserSettings(notificationEmail: "different@test.com", emailNotificationsEnabled: false, scheduledAnalysisEnabled: false, updatedAt: date)
        
        #expect(settings1 == settings2)
        #expect(settings1 != settings3)
    }
}


// MARK: - Watchlist Tests
// Validates: Requirements 2.5

@Suite("Watchlist Model Tests")
struct WatchlistTests {
    
    @Test("Watchlist initialization")
    func testInitialization() {
        let watchlist = Watchlist(userId: "user-123", symbols: ["AAPL", "GOOGL"])
        
        #expect(watchlist.userId == "user-123")
        #expect(watchlist.symbols == ["AAPL", "GOOGL"])
    }
    
    @Test("Watchlist initialization with empty symbols")
    func testInitWithEmptySymbols() {
        let watchlist = Watchlist(userId: "user-456")
        
        #expect(watchlist.userId == "user-456")
        #expect(watchlist.symbols.isEmpty)
    }
    
    @Test("Watchlist maxSymbols equals 50 - Validates Requirement 2.5")
    func testMaxSymbolsConstant() {
        #expect(Watchlist.maxSymbols == 50)
    }
    
    @Test("Watchlist addSymbol with valid symbol succeeds")
    func testAddValidSymbol() {
        var watchlist = Watchlist(userId: "user-123")
        
        let result = watchlist.addSymbol("AAPL")
        
        switch result {
        case .success:
            #expect(watchlist.symbols.contains("AAPL"))
            #expect(watchlist.symbols.count == 1)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test("Watchlist addSymbol normalizes to uppercase")
    func testAddSymbolNormalizesCase() {
        var watchlist = Watchlist(userId: "user-123")
        
        let result = watchlist.addSymbol("aapl")
        
        switch result {
        case .success:
            #expect(watchlist.symbols.contains("AAPL"))
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test("Watchlist addSymbol with invalid format - numbers fails")
    func testAddInvalidNumbersSymbol() {
        var watchlist = Watchlist(userId: "user-123")
        
        let result = watchlist.addSymbol("123")
        
        switch result {
        case .success:
            Issue.record("Expected failure for numeric symbol")
        case .failure(let error):
            #expect(error == .invalidFormat)
        }
    }
    
    @Test("Watchlist addSymbol with invalid format - too long fails")
    func testAddTooLongSymbol() {
        var watchlist = Watchlist(userId: "user-123")
        
        let result = watchlist.addSymbol("TOOLONG")
        
        switch result {
        case .success:
            Issue.record("Expected failure for symbol longer than 5 characters")
        case .failure(let error):
            #expect(error == .invalidFormat)
        }
    }
    
    @Test("Watchlist addSymbol with invalid format - empty string fails")
    func testAddEmptySymbol() {
        var watchlist = Watchlist(userId: "user-123")
        
        let result = watchlist.addSymbol("")
        
        switch result {
        case .success:
            Issue.record("Expected failure for empty symbol")
        case .failure(let error):
            #expect(error == .invalidFormat)
        }
    }

    @Test("Watchlist addSymbol with duplicate symbol fails")
    func testAddDuplicateSymbol() {
        var watchlist = Watchlist(userId: "user-123", symbols: ["AAPL"])
        
        let result = watchlist.addSymbol("AAPL")
        
        switch result {
        case .success:
            Issue.record("Expected failure for duplicate symbol")
        case .failure(let error):
            #expect(error == .duplicateSymbol)
            #expect(watchlist.symbols.count == 1)
        }
    }
    
    @Test("Watchlist addSymbol when at capacity fails - Validates Requirement 2.5")
    func testAddSymbolAtCapacity() {
        // Generate 50 unique valid symbols
        var symbolList: [String] = []
        for i in 0..<50 {
            let first = Character(UnicodeScalar(65 + (i / 26))!)
            let second = Character(UnicodeScalar(65 + (i % 26))!)
            symbolList.append(String(first) + String(second))
        }
        
        var watchlist = Watchlist(userId: "user-123", symbols: symbolList)
        
        #expect(watchlist.symbols.count == 50)
        #expect(watchlist.isAtCapacity == true)
        
        let result = watchlist.addSymbol("NEW")
        
        switch result {
        case .success:
            Issue.record("Expected failure when at capacity")
        case .failure(let error):
            #expect(error == .limitReached(max: 50))
            #expect(watchlist.symbols.count == 50)
        }
    }
    
    @Test("Watchlist isAtCapacity returns true at exactly 50 symbols")
    func testIsAtCapacityAt50() {
        var symbolList: [String] = []
        for i in 0..<50 {
            let first = Character(UnicodeScalar(65 + (i / 26))!)
            let second = Character(UnicodeScalar(65 + (i % 26))!)
            symbolList.append(String(first) + String(second))
        }
        
        let watchlist = Watchlist(userId: "user-123", symbols: symbolList)
        
        #expect(watchlist.isAtCapacity == true)
    }
    
    @Test("Watchlist isAtCapacity returns false below 50 symbols")
    func testIsAtCapacityBelow50() {
        let watchlist = Watchlist(userId: "user-123", symbols: ["AAPL", "GOOGL"])
        
        #expect(watchlist.isAtCapacity == false)
    }

    @Test("Watchlist removeSymbol removes existing symbol")
    func testRemoveExistingSymbol() {
        var watchlist = Watchlist(userId: "user-123", symbols: ["AAPL", "GOOGL", "MSFT"])
        
        let removed = watchlist.removeSymbol("GOOGL")
        
        #expect(removed == true)
        #expect(watchlist.symbols.count == 2)
        #expect(!watchlist.symbols.contains("GOOGL"))
    }
    
    @Test("Watchlist removeSymbol returns false for non-existent symbol")
    func testRemoveNonExistentSymbol() {
        var watchlist = Watchlist(userId: "user-123", symbols: ["AAPL"])
        
        let removed = watchlist.removeSymbol("GOOGL")
        
        #expect(removed == false)
        #expect(watchlist.symbols.count == 1)
    }
    
    @Test("Watchlist contains returns true for existing symbol")
    func testContainsExistingSymbol() {
        let watchlist = Watchlist(userId: "user-123", symbols: ["AAPL", "GOOGL"])
        
        #expect(watchlist.contains("AAPL") == true)
        #expect(watchlist.contains("aapl") == true) // case insensitive
    }
    
    @Test("Watchlist Codable encoding/decoding round-trip")
    func testCodableRoundTrip() throws {
        let original = Watchlist(
            userId: "user-789",
            symbols: ["AAPL", "GOOGL", "MSFT"],
            updatedAt: Date(timeIntervalSince1970: 1700000000)
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Watchlist.self, from: data)
        
        #expect(decoded == original)
    }
}


// MARK: - WeeklyOptionConfiguration Tests
// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.8

@Suite("WeeklyOptionConfiguration Model Tests")
struct WeeklyOptionConfigurationTests {
    
    // MARK: - Default Values Tests (Requirement 4.8)
    
    @Test("Default configuration values match requirements - Validates Requirement 4.8")
    func testDefaultValues() {
        let config = WeeklyOptionConfiguration.default
        
        #expect(config.windowDays == 5)
        #expect(config.lookbackDays == 180)
        #expect(config.premiumPct == 0.5)
        #expect(config.onlyOrders == false)
    }
    
    @Test("Init with no parameters uses default values")
    func testInitWithDefaults() {
        let config = WeeklyOptionConfiguration()
        
        #expect(config.windowDays == 5)
        #expect(config.lookbackDays == 180)
        #expect(config.premiumPct == 0.5)
        #expect(config.onlyOrders == false)
    }
    
    @Test("Init with custom parameters")
    func testInitWithCustomValues() {
        let config = WeeklyOptionConfiguration(
            windowDays: 30,
            lookbackDays: 360,
            premiumPct: 2.5,
            onlyOrders: true
        )
        
        #expect(config.windowDays == 30)
        #expect(config.lookbackDays == 360)
        #expect(config.premiumPct == 2.5)
        #expect(config.onlyOrders == true)
    }
    
    // MARK: - Static Constants Tests
    
    @Test("Valid window days options - Validates Requirement 4.2")
    func testValidWindowDaysOptions() {
        #expect(WeeklyOptionConfiguration.validWindowDays == [1, 5, 30])
    }
    
    @Test("Valid lookback days options - Validates Requirement 4.3")
    func testValidLookbackDaysOptions() {
        #expect(WeeklyOptionConfiguration.validLookbackDays == [30, 60, 90, 180, 360])
    }
    
    @Test("Premium percentage range - Validates Requirement 4.4")
    func testPremiumPctRange() {
        #expect(WeeklyOptionConfiguration.premiumPctRange.lowerBound == 0.1)
        #expect(WeeklyOptionConfiguration.premiumPctRange.upperBound == 5.0)
    }
    
    @Test("Premium percentage step")
    func testPremiumPctStep() {
        #expect(WeeklyOptionConfiguration.premiumPctStep == 0.1)
    }
    
    @Test("Strategy ID is correct")
    func testStrategyId() {
        #expect(WeeklyOptionConfiguration.strategyId == "weekly_option")
    }
    
    // MARK: - Validation Tests
    
    @Test("Valid configuration passes validation")
    func testValidConfigurationPasses() {
        let config = WeeklyOptionConfiguration(
            windowDays: 5,
            lookbackDays: 180,
            premiumPct: 1.0,
            onlyOrders: false
        )
        
        let result = config.validate()
        
        switch result {
        case .success:
            #expect(config.isValid == true)
        case .failure(let error):
            Issue.record("Expected validation success but got error: \(error)")
        }
    }
    
    @Test("All valid window days pass validation")
    func testAllValidWindowDays() {
        for days in WeeklyOptionConfiguration.validWindowDays {
            let config = WeeklyOptionConfiguration(windowDays: days)
            #expect(config.isValid == true, "Window days \(days) should be valid")
        }
    }
    
    @Test("All valid lookback days pass validation")
    func testAllValidLookbackDays() {
        for days in WeeklyOptionConfiguration.validLookbackDays {
            let config = WeeklyOptionConfiguration(lookbackDays: days)
            #expect(config.isValid == true, "Lookback days \(days) should be valid")
        }
    }
    
    @Test("Premium percentage at boundaries passes validation")
    func testPremiumPctBoundaries() {
        let configMin = WeeklyOptionConfiguration(premiumPct: 0.1)
        let configMax = WeeklyOptionConfiguration(premiumPct: 5.0)
        let configMid = WeeklyOptionConfiguration(premiumPct: 2.5)
        
        #expect(configMin.isValid == true)
        #expect(configMax.isValid == true)
        #expect(configMid.isValid == true)
    }
    
    @Test("Invalid window days fails validation")
    func testInvalidWindowDaysFails() {
        let invalidValues = [0, 2, 3, 7, 10, 100]
        
        for days in invalidValues {
            let config = WeeklyOptionConfiguration(windowDays: days)
            let result = config.validate()
            
            switch result {
            case .success:
                Issue.record("Expected failure for window days \(days)")
            case .failure(let error):
                if case .valueOutOfRange(let param, _) = error {
                    #expect(param == "windowDays")
                } else {
                    Issue.record("Expected valueOutOfRange error")
                }
            }
        }
    }
    
    @Test("Invalid lookback days fails validation")
    func testInvalidLookbackDaysFails() {
        let invalidValues = [0, 10, 45, 100, 500]
        
        for days in invalidValues {
            let config = WeeklyOptionConfiguration(lookbackDays: days)
            let result = config.validate()
            
            switch result {
            case .success:
                Issue.record("Expected failure for lookback days \(days)")
            case .failure(let error):
                if case .valueOutOfRange(let param, _) = error {
                    #expect(param == "lookbackDays")
                } else {
                    Issue.record("Expected valueOutOfRange error")
                }
            }
        }
    }
    
    @Test("Premium percentage below range fails validation")
    func testPremiumPctBelowRangeFails() {
        let config = WeeklyOptionConfiguration(premiumPct: 0.05)
        let result = config.validate()
        
        switch result {
        case .success:
            Issue.record("Expected failure for premium below range")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "premiumPct")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    @Test("Premium percentage above range fails validation")
    func testPremiumPctAboveRangeFails() {
        let config = WeeklyOptionConfiguration(premiumPct: 5.5)
        let result = config.validate()
        
        switch result {
        case .success:
            Issue.record("Expected failure for premium above range")
        case .failure(let error):
            if case .valueOutOfRange(let param, _) = error {
                #expect(param == "premiumPct")
            } else {
                Issue.record("Expected valueOutOfRange error")
            }
        }
    }
    
    // MARK: - Static Validation Methods Tests
    
    @Test("validateWindowDays static method returns nil for valid values")
    func testValidateWindowDaysValid() {
        for days in WeeklyOptionConfiguration.validWindowDays {
            let error = WeeklyOptionConfiguration.validateWindowDays(days)
            #expect(error == nil, "Expected no error for valid window days \(days)")
        }
    }
    
    @Test("validateWindowDays static method returns error for invalid values")
    func testValidateWindowDaysInvalid() {
        let error = WeeklyOptionConfiguration.validateWindowDays(7)
        #expect(error != nil)
        
        if case .valueOutOfRange(let param, _) = error {
            #expect(param == "windowDays")
        } else {
            Issue.record("Expected valueOutOfRange error")
        }
    }
    
    @Test("validateLookbackDays static method returns nil for valid values")
    func testValidateLookbackDaysValid() {
        for days in WeeklyOptionConfiguration.validLookbackDays {
            let error = WeeklyOptionConfiguration.validateLookbackDays(days)
            #expect(error == nil, "Expected no error for valid lookback days \(days)")
        }
    }
    
    @Test("validateLookbackDays static method returns error for invalid values")
    func testValidateLookbackDaysInvalid() {
        let error = WeeklyOptionConfiguration.validateLookbackDays(100)
        #expect(error != nil)
        
        if case .valueOutOfRange(let param, _) = error {
            #expect(param == "lookbackDays")
        } else {
            Issue.record("Expected valueOutOfRange error")
        }
    }
    
    @Test("validatePremiumPct static method returns nil for valid values")
    func testValidatePremiumPctValid() {
        let validValues = [0.1, 1.0, 2.5, 5.0]
        
        for pct in validValues {
            let error = WeeklyOptionConfiguration.validatePremiumPct(pct)
            #expect(error == nil, "Expected no error for valid premium \(pct)")
        }
    }
    
    @Test("validatePremiumPct static method returns error for invalid values")
    func testValidatePremiumPctInvalid() {
        let invalidValues = [0.0, 0.05, 5.1, 10.0]
        
        for pct in invalidValues {
            let error = WeeklyOptionConfiguration.validatePremiumPct(pct)
            #expect(error != nil, "Expected error for invalid premium \(pct)")
        }
    }
    
    // MARK: - isValid Property Tests
    
    @Test("isValid returns true for valid configuration")
    func testIsValidTrue() {
        let config = WeeklyOptionConfiguration.default
        #expect(config.isValid == true)
    }
    
    @Test("isValid returns false for invalid configuration")
    func testIsValidFalse() {
        let config = WeeklyOptionConfiguration(windowDays: 7)
        #expect(config.isValid == false)
    }
    
    // MARK: - Codable Tests
    
    @Test("Codable encoding/decoding round-trip")
    func testCodableRoundTrip() throws {
        let original = WeeklyOptionConfiguration(
            windowDays: 30,
            lookbackDays: 360,
            premiumPct: 3.5,
            onlyOrders: true
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WeeklyOptionConfiguration.self, from: data)
        
        #expect(decoded == original)
    }
    
    // MARK: - Equatable Tests
    
    @Test("Equatable conformance")
    func testEquatable() {
        let config1 = WeeklyOptionConfiguration(windowDays: 5, lookbackDays: 180, premiumPct: 1.0, onlyOrders: false)
        let config2 = WeeklyOptionConfiguration(windowDays: 5, lookbackDays: 180, premiumPct: 1.0, onlyOrders: false)
        let config3 = WeeklyOptionConfiguration(windowDays: 30, lookbackDays: 360, premiumPct: 2.0, onlyOrders: true)
        
        #expect(config1 == config2)
        #expect(config1 != config3)
    }
    
    // MARK: - Conversion Tests
    
    @Test("toStrategyConfiguration converts correctly")
    func testToStrategyConfiguration() {
        let config = WeeklyOptionConfiguration(
            windowDays: 30,
            lookbackDays: 90,
            premiumPct: 2.0,
            onlyOrders: true
        )
        
        let strategyConfig = config.toStrategyConfiguration()
        
        #expect(strategyConfig.strategyId == "weekly_option")
        #expect(strategyConfig.getInt("windowDays", default: 0) == 30)
        #expect(strategyConfig.getInt("lookbackDays", default: 0) == 90)
        #expect(strategyConfig.getDouble("premiumPct", default: 0.0) == 2.0)
        #expect(strategyConfig.getBool("onlyOrders", default: false) == true)
    }
    
    @Test("from StrategyConfiguration converts correctly")
    func testFromStrategyConfiguration() {
        let strategyConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: [
                "windowDays": .integer(1),
                "lookbackDays": .integer(60),
                "premiumPct": .decimal(4.5),
                "onlyOrders": .boolean(true)
            ]
        )
        
        let config = WeeklyOptionConfiguration.from(strategyConfig)
        
        #expect(config.windowDays == 1)
        #expect(config.lookbackDays == 60)
        #expect(config.premiumPct == 4.5)
        #expect(config.onlyOrders == true)
    }
    
    @Test("from StrategyConfiguration uses defaults for missing parameters")
    func testFromStrategyConfigurationWithDefaults() {
        let strategyConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: [:]  // Empty parameters
        )
        
        let config = WeeklyOptionConfiguration.from(strategyConfig)
        
        #expect(config.windowDays == WeeklyOptionConfiguration.default.windowDays)
        #expect(config.lookbackDays == WeeklyOptionConfiguration.default.lookbackDays)
        #expect(config.premiumPct == WeeklyOptionConfiguration.default.premiumPct)
        #expect(config.onlyOrders == WeeklyOptionConfiguration.default.onlyOrders)
    }
}


// MARK: - Session-Scoped Expiration Override Integration Tests
// Validates: Requirements 3.2, 3.4

@Suite("Session-Scoped Expiration Override Integration Tests")
struct SessionScopedExpirationOverrideTests {
    
    // MARK: - Mock Services for Override Testing
    
    /// Mock options data service that tracks the expiration date requested.
    final class MockOptionsDataServiceForOverride: OptionsDataService {
        
        /// The last expiration date that was requested in fetchOptionsChain
        private(set) var lastRequestedExpirationDate: Date?
        
        /// Price data to return
        var priceDataByTicker: [String: [PricePoint]] = [:]
        
        /// Options chains to return (keyed by ticker)
        var optionsChainByTicker: [String: OptionsChain] = [:]
        
        private(set) var fetchOptionsChainCallCount = 0
        
        /// Resets the call counter for testing multiple analysis runs.
        func resetCallCount() {
            fetchOptionsChainCallCount = 0
        }
        
        // MARK: - MarketDataService Implementation
        
        func fetchHistoricalPrices(ticker: String, lookbackDays: Int) async throws -> [PricePoint] {
            return priceDataByTicker[ticker] ?? generateMockPriceData(days: lookbackDays)
        }
        
        func fetchEarningsDate(ticker: String) async throws -> Date? {
            return Calendar.current.date(byAdding: .day, value: 30, to: Date())
        }
        
        // MARK: - OptionsDataService Implementation
        
        func fetchOptionsChain(ticker: String, expirationDate: Date) async throws -> OptionsChain {
            fetchOptionsChainCallCount += 1
            
            // Track the requested expiration date - this is the key for our test!
            lastRequestedExpirationDate = expirationDate
            
            // Return stored chain or generate mock chain with the requested expiration date
            if let storedChain = optionsChainByTicker[ticker] {
                return storedChain
            }
            
            return generateMockOptionsChain(
                ticker: ticker,
                expirationDate: expirationDate,
                currentPrice: 100.0
            )
        }
        
        // MARK: - Mock Data Generation
        
        private func generateMockPriceData(days: Int) -> [PricePoint] {
            var prices: [PricePoint] = []
            let basePrice = 100.0
            let calendar = Calendar.current
            let today = Date()
            
            for i in (0..<days).reversed() {
                if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                    let price = basePrice + Double.random(in: -5...5) + Double(days - i) * 0.05
                    prices.append(PricePoint(date: date, close: price))
                }
            }
            return prices
        }
        
        private func generateMockOptionsChain(
            ticker: String,
            expirationDate: Date,
            currentPrice: Double
        ) -> OptionsChain {
            let calls = [
                OptionContract(
                    ticker: ticker,
                    type: .call,
                    strikePrice: currentPrice + 5.0,
                    bid: 0.50,
                    ask: 0.60,
                    expirationDate: expirationDate
                )
            ]
            
            let puts = [
                OptionContract(
                    ticker: ticker,
                    type: .put,
                    strikePrice: currentPrice - 5.0,
                    bid: 0.45,
                    ask: 0.55,
                    expirationDate: expirationDate
                )
            ]
            
            return OptionsChain(
                ticker: ticker,
                expirationDate: expirationDate,
                calls: calls,
                puts: puts,
                fetchedAt: Date()
            )
        }
    }
    
    /// Mock expiration date calculator that always returns valid for weekdays
    final class MockExpirationDateCalculatorForOverride: ExpirationDateCalculation {
        
        var defaultExpiration: Date
        
        init() {
            // Default to next Friday
            let calendar = Calendar.current
            let today = Date()
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            components.weekday = 6  // Friday
            self.defaultExpiration = calendar.date(from: components) ?? today
        }
        
        func calculateDefaultExpiration(from referenceDate: Date) -> Date {
            return defaultExpiration
        }
        
        func isValidExpirationDate(_ date: Date) -> Bool {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            // Valid if weekday (Mon-Fri: 2-6)
            return (2...6).contains(weekday)
        }
        
        func isMarketHoliday(_ date: Date) -> Bool {
            return false
        }
    }
    
    // MARK: - Integration Test: Session-Scoped Override
    
    /// Test: Setting expiration override causes analysis to use that override date.
    /// - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
    @Test("Set expiration override → run analysis → verify override date used in AnalysisResult")
    @MainActor
    func testExpirationOverrideUsedInAnalysis() async throws {
        // --- Setup ---
        let mockOptionsService = MockOptionsDataServiceForOverride()
        let mockExpirationCalculator = MockExpirationDateCalculatorForOverride()
        
        // Create a specific override date (a Monday - which is a valid weekday)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 17  // Monday, Feb 17, 2025
        let overrideDate = calendar.date(from: components)!
        
        // Verify it's a weekday (Monday = 2)
        let weekday = calendar.component(.weekday, from: overrideDate)
        #expect(weekday == 2, "Override date should be Monday")
        
        // Create strategy with mocked dependencies
        let strategy = WeeklyOptionStrategy(
            marketDataService: mockOptionsService,
            optionsDataService: mockOptionsService,
            rollingWindowCalculator: RollingWindowCalculator(),
            expirationDateCalculator: mockExpirationCalculator,
            premiumMatcher: PremiumMatchingAlgorithm()
        )
        
        // Create AnalysisViewModel with our dependencies
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            strategy: strategy,
            expirationDateCalculator: mockExpirationCalculator,
            userId: "test-user"
        )
        
        // --- Step 1: Select strategy ---
        await analysisViewModel.selectStrategy(.weeklyOption)
        #expect(analysisViewModel.isConfigurationLoaded == true)
        
        // --- Step 2: Set the expiration override ---
        // Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
        analysisViewModel.setExpirationOverride(overrideDate)
        
        // Verify override was accepted
        #expect(analysisViewModel.hasExpirationOverride == true, "Override should be set")
        #expect(analysisViewModel.expirationOverride != nil, "Override date should not be nil")
        #expect(analysisViewModel.expirationValidationError == nil, "Should have no validation error")
        
        // Verify the effective expiration date matches our override
        let effectiveDate = analysisViewModel.effectiveExpirationDate
        #expect(calendar.isDate(effectiveDate, inSameDayAs: overrideDate), 
               "Effective expiration should match override date")
        
        // --- Step 3: Set watchlist and run analysis ---
        analysisViewModel.setWatchlistTickers(["AAPL"])
        #expect(analysisViewModel.canRunAnalysis == true, "Should be able to run analysis")
        
        await analysisViewModel.runAnalysis()
        
        // --- Step 4: Verify the override date was used in the analysis ---
        #expect(analysisViewModel.isRunningAnalysis == false, "Analysis should be complete")
        #expect(analysisViewModel.analysisResults.count > 0, "Should have analysis results")
        
        // Check that the mock service received the correct expiration date
        #expect(mockOptionsService.fetchOptionsChainCallCount > 0, "Options chain should have been fetched")
        
        if let requestedDate = mockOptionsService.lastRequestedExpirationDate {
            #expect(calendar.isDate(requestedDate, inSameDayAs: overrideDate),
                   "Options fetch should use override date. Expected: \(overrideDate), Got: \(requestedDate)")
        } else {
            Issue.record("Options chain should have been fetched with an expiration date")
        }
        
        // Verify the AnalysisResult contains the correct expiration date
        // - Validates: Requirements 6.1 (Expiration Date in results)
        for result in analysisViewModel.analysisResults {
            if let resultExpirationDate = result.expirationDate {
                #expect(calendar.isDate(resultExpirationDate, inSameDayAs: overrideDate),
                       "AnalysisResult expiration date should match override. Expected: \(overrideDate), Got: \(resultExpirationDate)")
            }
        }
    }
    
    /// Test: Clearing expiration override returns to default calculation.
    /// - Validates: Requirement 3.2 (Return to automatic calculation when override is cleared)
    @Test("Clear expiration override → run analysis → verify default date used")
    @MainActor
    func testClearingOverrideUsesDefaultDate() async throws {
        // --- Setup ---
        let mockOptionsService = MockOptionsDataServiceForOverride()
        let mockExpirationCalculator = MockExpirationDateCalculatorForOverride()
        let calendar = Calendar.current
        
        // Set a specific default expiration date
        var defaultComponents = DateComponents()
        defaultComponents.year = 2025
        defaultComponents.month = 2
        defaultComponents.day = 21  // Friday, Feb 21, 2025
        let defaultDate = calendar.date(from: defaultComponents)!
        mockExpirationCalculator.defaultExpiration = defaultDate
        
        // Create a different override date
        var overrideComponents = DateComponents()
        overrideComponents.year = 2025
        overrideComponents.month = 2
        overrideComponents.day = 17  // Monday, Feb 17, 2025
        let overrideDate = calendar.date(from: overrideComponents)!
        
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
            userId: "test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        
        // --- Step 1: Set and then clear the override ---
        analysisViewModel.setExpirationOverride(overrideDate)
        #expect(analysisViewModel.hasExpirationOverride == true)
        
        analysisViewModel.clearExpirationOverride()
        #expect(analysisViewModel.hasExpirationOverride == false, "Override should be cleared")
        #expect(analysisViewModel.expirationOverride == nil, "Override should be nil")
        
        // Verify effective date is now the default
        let effectiveDate = analysisViewModel.effectiveExpirationDate
        #expect(calendar.isDate(effectiveDate, inSameDayAs: defaultDate),
               "Effective date should match default after clearing override")
        
        // --- Step 2: Run analysis and verify default date was used ---
        analysisViewModel.setWatchlistTickers(["AAPL"])
        await analysisViewModel.runAnalysis()
        
        if let requestedDate = mockOptionsService.lastRequestedExpirationDate {
            #expect(calendar.isDate(requestedDate, inSameDayAs: defaultDate),
                   "Options fetch should use default date after override cleared")
        }
    }
    
    /// Test: App restart simulation - override should not persist.
    /// - Validates: Requirement 3.4 (Reset on app restart)
    @Test("Simulate app restart → verify expiration override is cleared")
    @MainActor
    func testExpirationOverrideClearedOnAppRestart() async throws {
        let mockExpirationCalculator = MockExpirationDateCalculatorForOverride()
        let calendar = Calendar.current
        
        // Create override date
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 17
        let overrideDate = calendar.date(from: components)!
        
        // --- First "session" - set an override ---
        let firstSessionViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            expirationDateCalculator: mockExpirationCalculator,
            userId: "test-user"
        )
        
        await firstSessionViewModel.selectStrategy(.weeklyOption)
        firstSessionViewModel.setExpirationOverride(overrideDate)
        
        #expect(firstSessionViewModel.hasExpirationOverride == true,
               "First session should have override set")
        
        // --- Simulate app restart by creating a new ViewModel instance ---
        // This simulates what happens when the app terminates and relaunches.
        // The new ViewModel should start with no override (session-scoped state).
        // - Validates: Requirement 3.4 (Reset on app restart)
        
        let secondSessionViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            expirationDateCalculator: mockExpirationCalculator,
            userId: "test-user"
        )
        
        await secondSessionViewModel.selectStrategy(.weeklyOption)
        
        // Verify the new instance has no override
        #expect(secondSessionViewModel.hasExpirationOverride == false,
               "New session (app restart) should not have override - session-scoped state should reset")
        #expect(secondSessionViewModel.expirationOverride == nil,
               "Override should be nil after app restart simulation")
        #expect(secondSessionViewModel.expirationValidationError == nil,
               "No validation error should be present after restart")
        
        // Verify it uses the default expiration date
        let effectiveDate = secondSessionViewModel.effectiveExpirationDate
        #expect(calendar.isDate(effectiveDate, inSameDayAs: mockExpirationCalculator.defaultExpiration),
               "After restart, should use default expiration date")
    }
    
    /// Test: Invalid expiration date is rejected with error message.
    /// - Validates: Requirement 3.7 (Display error for invalid dates)
    @Test("Set invalid expiration date (weekend) → verify error displayed")
    @MainActor
    func testInvalidExpirationDateRejected() async throws {
        let mockExpirationCalculator = MockExpirationDateCalculatorForOverride()
        let calendar = Calendar.current
        
        // Create a weekend date (Saturday)
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 15  // Saturday, Feb 15, 2025
        let saturdayDate = calendar.date(from: components)!
        
        // Verify it's Saturday (weekday = 7)
        let weekday = calendar.component(.weekday, from: saturdayDate)
        #expect(weekday == 7, "Test date should be Saturday")
        
        let analysisViewModel = AnalysisViewModel(
            configurationRepository: ConfigurationRepositoryImpl.forTesting(),
            validationService: ConfigurationValidationService(),
            expirationDateCalculator: mockExpirationCalculator,
            userId: "test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        
        // Attempt to set invalid date
        analysisViewModel.setExpirationOverride(saturdayDate)
        
        // Verify error is displayed and override is NOT set
        #expect(analysisViewModel.hasExpirationOverride == false,
               "Override should NOT be set for invalid date")
        #expect(analysisViewModel.expirationOverride == nil,
               "Override should remain nil for invalid date")
        #expect(analysisViewModel.expirationValidationError != nil,
               "Validation error should be set for invalid date")
        #expect(analysisViewModel.expirationValidationError!.contains("Saturday") ||
               analysisViewModel.expirationValidationError!.contains("closed"),
               "Error message should indicate market is closed on Saturday")
    }
    
    /// Test: Multiple analyses in same session all use the override.
    /// - Validates: Requirement 3.2 (Use custom date for all subsequent analyses in session)
    @Test("Multiple analyses with override → all use same override date")
    @MainActor
    func testMultipleAnalysesUseOverride() async throws {
        let mockOptionsService = MockOptionsDataServiceForOverride()
        let mockExpirationCalculator = MockExpirationDateCalculatorForOverride()
        let calendar = Calendar.current
        
        // Create override date
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 19  // Wednesday, Feb 19, 2025
        let overrideDate = calendar.date(from: components)!
        
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
            userId: "test-user"
        )
        
        await analysisViewModel.selectStrategy(.weeklyOption)
        
        // Set override once at the beginning
        analysisViewModel.setExpirationOverride(overrideDate)
        #expect(analysisViewModel.hasExpirationOverride == true)
        
        // --- Run first analysis ---
        analysisViewModel.setWatchlistTickers(["AAPL"])
        await analysisViewModel.runAnalysis()
        
        let firstRequestedDate = mockOptionsService.lastRequestedExpirationDate
        #expect(firstRequestedDate != nil)
        #expect(calendar.isDate(firstRequestedDate!, inSameDayAs: overrideDate),
               "First analysis should use override date")
        
        // --- Run second analysis with different ticker ---
        mockOptionsService.resetCallCount()
        analysisViewModel.setWatchlistTickers(["GOOGL"])
        await analysisViewModel.runAnalysis()
        
        let secondRequestedDate = mockOptionsService.lastRequestedExpirationDate
        #expect(secondRequestedDate != nil)
        #expect(calendar.isDate(secondRequestedDate!, inSameDayAs: overrideDate),
               "Second analysis should also use override date (session-scoped)")
        
        // --- Run third analysis with multiple tickers ---
        mockOptionsService.resetCallCount()
        analysisViewModel.setWatchlistTickers(["MSFT", "TSLA"])
        await analysisViewModel.runAnalysis()
        
        let thirdRequestedDate = mockOptionsService.lastRequestedExpirationDate
        #expect(thirdRequestedDate != nil)
        #expect(calendar.isDate(thirdRequestedDate!, inSameDayAs: overrideDate),
               "Third analysis should also use override date (session-scoped)")
    }
}
