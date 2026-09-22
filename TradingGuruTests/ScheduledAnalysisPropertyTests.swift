//
//  ScheduledAnalysisPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for scheduled analysis user filtering.
//  Tests the correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 16: Scheduled Analysis User Filtering
// **Validates: Requirements 8.2**
//
// *For any* set of users, the scheduled analysis SHALL only process users where
// `scheduledAnalysisEnabled == true` AND `watchlist.count > 0`. Users failing
// either condition SHALL be skipped.

@Suite("Property 16: Scheduled Analysis User Filtering - Validates Requirements 8.2")
struct ScheduledAnalysisUserFilteringPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    let filter = ScheduledAnalysisUserFilter()
    
    // MARK: - Test Data Generation
    
    /// Generates a random user ID
    static func generateRandomUserId() -> String {
        return "user-\(UUID().uuidString.prefix(8))"
    }
    
    /// Generates random user settings with specified scheduledAnalysisEnabled value
    static func generateSettings(scheduledAnalysisEnabled: Bool) -> UserSettings {
        return UserSettings(
            notificationEmail: Bool.random() ? "test@example.com" : nil,
            emailNotificationsEnabled: Bool.random(),
            scheduledAnalysisEnabled: scheduledAnalysisEnabled,
            updatedAt: Date()
        )
    }
    
    /// Generates a random watchlist with specified number of symbols
    static func generateWatchlist(userId: String, symbolCount: Int) -> Watchlist {
        var symbols: [String] = []
        for i in 0..<symbolCount {
            // Generate unique symbols: A, B, C, ..., AA, AB, etc.
            let base = i / 26
            let offset = i % 26
            let letter1 = Character(UnicodeScalar(65 + offset)!)
            if base > 0 {
                let letter0 = Character(UnicodeScalar(64 + base)!)
                symbols.append(String(letter0) + String(letter1))
            } else {
                symbols.append(String(letter1))
            }
        }
        return Watchlist(userId: userId, symbols: symbols, updatedAt: Date())
    }
    
    /// Generates a random eligible user (scheduledAnalysisEnabled=true AND watchlist.count > 0)
    static func generateEligibleUser() -> ScheduledAnalysisUserData {
        let userId = generateRandomUserId()
        let settings = generateSettings(scheduledAnalysisEnabled: true)
        let symbolCount = Int.random(in: 1...10) // At least 1 symbol
        let watchlist = generateWatchlist(userId: userId, symbolCount: symbolCount)
        
        return ScheduledAnalysisUserData(
            userId: userId,
            settings: settings,
            watchlist: watchlist
        )
    }
    
    /// Generates a user with scheduledAnalysisEnabled=false (ineligible)
    static func generateUserWithAnalysisDisabled() -> ScheduledAnalysisUserData {
        let userId = generateRandomUserId()
        let settings = generateSettings(scheduledAnalysisEnabled: false)
        // Can have any number of symbols
        let symbolCount = Int.random(in: 0...10)
        let watchlist = generateWatchlist(userId: userId, symbolCount: symbolCount)
        
        return ScheduledAnalysisUserData(
            userId: userId,
            settings: settings,
            watchlist: watchlist
        )
    }
    
    /// Generates a user with empty watchlist (ineligible)
    static func generateUserWithEmptyWatchlist() -> ScheduledAnalysisUserData {
        let userId = generateRandomUserId()
        // Can have analysis enabled or disabled
        let settings = generateSettings(scheduledAnalysisEnabled: Bool.random())
        let watchlist = generateWatchlist(userId: userId, symbolCount: 0)
        
        return ScheduledAnalysisUserData(
            userId: userId,
            settings: settings,
            watchlist: watchlist
        )
    }
    
    /// Generates a user failing both conditions (analysis disabled AND empty watchlist)
    static func generateUserFailingBothConditions() -> ScheduledAnalysisUserData {
        let userId = generateRandomUserId()
        let settings = generateSettings(scheduledAnalysisEnabled: false)
        let watchlist = generateWatchlist(userId: userId, symbolCount: 0)
        
        return ScheduledAnalysisUserData(
            userId: userId,
            settings: settings,
            watchlist: watchlist
        )
    }
    
    /// Generates a random mixed set of users
    static func generateRandomUserSet(count: Int) -> [ScheduledAnalysisUserData] {
        return (0..<count).map { _ in
            let analysisEnabled = Bool.random()
            let symbolCount = Int.random(in: 0...10)
            
            let userId = generateRandomUserId()
            let settings = generateSettings(scheduledAnalysisEnabled: analysisEnabled)
            let watchlist = generateWatchlist(userId: userId, symbolCount: symbolCount)
            
            return ScheduledAnalysisUserData(
                userId: userId,
                settings: settings,
                watchlist: watchlist
            )
        }
    }
    
    // MARK: - Property Tests: Eligible Users (Both Conditions True)
    
    @Test("Property: Users with scheduledAnalysisEnabled=true AND watchlist.count > 0 are processed",
          arguments: (0..<100).map { _ in Self.generateEligibleUser() })
    func testEligibleUsersAreProcessed(eligibleUser: ScheduledAnalysisUserData) {
        // Precondition: User has scheduledAnalysisEnabled=true AND watchlist.count > 0
        #expect(eligibleUser.settings.scheduledAnalysisEnabled == true,
                "Test precondition: scheduledAnalysisEnabled should be true")
        #expect(eligibleUser.watchlist.symbols.count > 0,
                "Test precondition: watchlist should have at least one symbol")
        
        // Act: Check eligibility
        let isEligible = filter.isEligible(eligibleUser)
        
        // Assert: User SHALL be processed (eligible)
        #expect(isEligible == true,
                "User with scheduledAnalysisEnabled=true AND watchlist.count > 0 should be eligible")
    }
    
    @Test("Property: Eligible users appear in filtered results",
          arguments: (0..<50).map { _ in Self.generateEligibleUser() })
    func testEligibleUsersAppearInFilteredResults(eligibleUser: ScheduledAnalysisUserData) {
        // Create a set with the eligible user and some ineligible users
        var users = Self.generateRandomUserSet(count: 5)
        users.append(eligibleUser)
        users.shuffle()
        
        // Act: Filter eligible users
        let eligibleUsers = filter.filterEligibleUsers(users)
        
        // Assert: The eligible user should be in the result
        #expect(eligibleUsers.contains(where: { $0.userId == eligibleUser.userId }),
                "Eligible user should appear in filtered results")
    }
    
    // MARK: - Property Tests: Ineligible Users with Analysis Disabled
    
    @Test("Property: Users with scheduledAnalysisEnabled=false are skipped regardless of watchlist",
          arguments: (0..<100).map { _ in Self.generateUserWithAnalysisDisabled() })
    func testUsersWithAnalysisDisabledAreSkipped(user: ScheduledAnalysisUserData) {
        // Precondition: User has scheduledAnalysisEnabled=false
        #expect(user.settings.scheduledAnalysisEnabled == false,
                "Test precondition: scheduledAnalysisEnabled should be false")
        
        // Act: Check eligibility
        let isEligible = filter.isEligible(user)
        
        // Assert: User SHALL be skipped (ineligible)
        #expect(isEligible == false,
                "User with scheduledAnalysisEnabled=false should be ineligible regardless of watchlist size (\(user.watchlist.symbols.count))")
    }
    
    @Test("Property: Users with analysis disabled do not appear in eligible results",
          arguments: (0..<50).map { _ in
            // Generate user with analysis disabled but with symbols in watchlist
            let userId = Self.generateRandomUserId()
            let settings = Self.generateSettings(scheduledAnalysisEnabled: false)
            let watchlist = Self.generateWatchlist(userId: userId, symbolCount: Int.random(in: 1...10))
            return ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
          })
    func testUsersWithAnalysisDisabledNotInEligibleResults(ineligibleUser: ScheduledAnalysisUserData) {
        // Precondition: User has analysis disabled but has watchlist items
        #expect(ineligibleUser.settings.scheduledAnalysisEnabled == false)
        #expect(ineligibleUser.watchlist.symbols.count > 0)
        
        // Create a set with this user and some others
        var users = Self.generateRandomUserSet(count: 5)
        users.append(ineligibleUser)
        users.shuffle()
        
        // Act: Filter eligible users
        let eligibleUsers = filter.filterEligibleUsers(users)
        
        // Assert: This user should NOT be in the eligible results
        #expect(!eligibleUsers.contains(where: { $0.userId == ineligibleUser.userId }),
                "User with scheduledAnalysisEnabled=false should not appear in eligible results")
    }
    
    // MARK: - Property Tests: Ineligible Users with Empty Watchlist
    
    @Test("Property: Users with empty watchlist are skipped regardless of scheduledAnalysisEnabled",
          arguments: (0..<100).map { _ in Self.generateUserWithEmptyWatchlist() })
    func testUsersWithEmptyWatchlistAreSkipped(user: ScheduledAnalysisUserData) {
        // Precondition: User has empty watchlist
        #expect(user.watchlist.symbols.count == 0,
                "Test precondition: watchlist should be empty")
        
        // Act: Check eligibility
        let isEligible = filter.isEligible(user)
        
        // Assert: User SHALL be skipped (ineligible)
        #expect(isEligible == false,
                "User with empty watchlist should be ineligible regardless of scheduledAnalysisEnabled (\(user.settings.scheduledAnalysisEnabled))")
    }
    
    @Test("Property: Users with empty watchlist but analysis enabled are still skipped",
          arguments: (0..<50).map { _ in
            let userId = Self.generateRandomUserId()
            let settings = Self.generateSettings(scheduledAnalysisEnabled: true)
            let watchlist = Self.generateWatchlist(userId: userId, symbolCount: 0)
            return ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
          })
    func testUsersWithEmptyWatchlistAndAnalysisEnabledAreSkipped(user: ScheduledAnalysisUserData) {
        // Precondition: User has analysis enabled but empty watchlist
        #expect(user.settings.scheduledAnalysisEnabled == true)
        #expect(user.watchlist.symbols.count == 0)
        
        // Act: Check eligibility
        let isEligible = filter.isEligible(user)
        
        // Assert: User should be skipped due to empty watchlist
        #expect(isEligible == false,
                "User with empty watchlist should be ineligible even with scheduledAnalysisEnabled=true")
    }
    
    // MARK: - Property Tests: Users Failing Both Conditions
    
    @Test("Property: Users failing both conditions are skipped",
          arguments: (0..<50).map { _ in Self.generateUserFailingBothConditions() })
    func testUsersFailingBothConditionsAreSkipped(user: ScheduledAnalysisUserData) {
        // Precondition: User has analysis disabled AND empty watchlist
        #expect(user.settings.scheduledAnalysisEnabled == false,
                "Test precondition: scheduledAnalysisEnabled should be false")
        #expect(user.watchlist.symbols.count == 0,
                "Test precondition: watchlist should be empty")
        
        // Act: Check eligibility
        let isEligible = filter.isEligible(user)
        
        // Assert: User SHALL be skipped
        #expect(isEligible == false,
                "User failing both conditions should be ineligible")
    }
    
    // MARK: - Property Tests: Filter Correctness
    
    @Test("Property: All eligible users in a set are processed, all ineligible are skipped",
          arguments: (0..<50).map { _ in Self.generateRandomUserSet(count: Int.random(in: 5...20)) })
    func testFilterCorrectnessForRandomUserSets(users: [ScheduledAnalysisUserData]) {
        // Act: Filter and categorize
        let eligibleUsers = filter.filterEligibleUsers(users)
        let skippedUsers = filter.filterSkippedUsers(users)
        
        // Assert: Total should equal original count
        #expect(eligibleUsers.count + skippedUsers.count == users.count,
                "Sum of eligible and skipped should equal total users")
        
        // Assert: Every eligible user meets BOTH conditions
        for user in eligibleUsers {
            #expect(user.settings.scheduledAnalysisEnabled == true,
                    "Eligible user should have scheduledAnalysisEnabled=true")
            #expect(user.watchlist.symbols.count > 0,
                    "Eligible user should have watchlist.count > 0")
        }
        
        // Assert: Every skipped user fails at least one condition
        for user in skippedUsers {
            let failsAnalysisCondition = user.settings.scheduledAnalysisEnabled == false
            let failsWatchlistCondition = user.watchlist.symbols.count == 0
            
            #expect(failsAnalysisCondition || failsWatchlistCondition,
                    "Skipped user should fail at least one condition")
        }
    }
    
    @Test("Property: Filtering is deterministic - same input produces same output")
    func testFilteringIsDeterministic() {
        let users = Self.generateRandomUserSet(count: 20)
        
        // Filter multiple times
        let result1 = filter.filterEligibleUsers(users)
        let result2 = filter.filterEligibleUsers(users)
        let result3 = filter.filterEligibleUsers(users)
        
        // Assert: All results should be identical
        #expect(result1.map(\.userId) == result2.map(\.userId),
                "Filtering should be deterministic")
        #expect(result2.map(\.userId) == result3.map(\.userId),
                "Filtering should be deterministic")
    }
    
    @Test("Property: Filtering preserves user identity - no duplicates or losses")
    func testFilteringPreservesUserIdentity() {
        let users = Self.generateRandomUserSet(count: 15)
        let originalUserIds = Set(users.map(\.userId))
        
        // Act: Categorize users
        let (eligible, skipped) = filter.categorizeUsers(users)
        
        // Collect all user IDs from results
        let resultUserIds = Set(eligible.map(\.userId) + skipped.map(\.userId))
        
        // Assert: All original users accounted for, no extras
        #expect(resultUserIds == originalUserIds,
                "All original users should be accounted for in either eligible or skipped")
        #expect(eligible.count + skipped.count == users.count,
                "No users should be duplicated or lost")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Empty user set returns empty eligible set")
    func testEmptyUserSetReturnsEmptyEligibleSet() {
        let emptyUsers: [ScheduledAnalysisUserData] = []
        
        let eligibleUsers = filter.filterEligibleUsers(emptyUsers)
        
        #expect(eligibleUsers.isEmpty,
                "Empty input should produce empty output")
    }
    
    @Test("Property: Set with only ineligible users returns empty eligible set")
    func testAllIneligibleUsersReturnsEmptySet() {
        // Generate users all failing at least one condition
        let users: [ScheduledAnalysisUserData] = (0..<10).map { i in
            if i % 2 == 0 {
                return Self.generateUserWithAnalysisDisabled()
            } else {
                let userId = Self.generateRandomUserId()
                let settings = Self.generateSettings(scheduledAnalysisEnabled: true)
                let watchlist = Self.generateWatchlist(userId: userId, symbolCount: 0)
                return ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
            }
        }
        
        let eligibleUsers = filter.filterEligibleUsers(users)
        
        #expect(eligibleUsers.isEmpty,
                "Set with only ineligible users should return empty eligible set")
    }
    
    @Test("Property: Set with only eligible users returns all users")
    func testAllEligibleUsersReturnsAllUsers() {
        let eligibleOnlyUsers = (0..<10).map { _ in Self.generateEligibleUser() }
        
        let filteredUsers = filter.filterEligibleUsers(eligibleOnlyUsers)
        
        #expect(filteredUsers.count == eligibleOnlyUsers.count,
                "Set with only eligible users should return all users")
    }
    
    // MARK: - Property Tests: Boundary Conditions
    
    @Test("Property: User with exactly 1 symbol and analysis enabled is eligible")
    func testUserWithExactlyOneSymbolIsEligible() {
        let userId = Self.generateRandomUserId()
        let settings = Self.generateSettings(scheduledAnalysisEnabled: true)
        let watchlist = Self.generateWatchlist(userId: userId, symbolCount: 1)
        let user = ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
        
        #expect(user.watchlist.symbols.count == 1,
                "Precondition: exactly 1 symbol")
        
        let isEligible = filter.isEligible(user)
        
        #expect(isEligible == true,
                "User with exactly 1 symbol and analysis enabled should be eligible")
    }
    
    @Test("Property: User with maximum watchlist size (50) and analysis enabled is eligible")
    func testUserWithMaxWatchlistSizeIsEligible() {
        let userId = Self.generateRandomUserId()
        let settings = Self.generateSettings(scheduledAnalysisEnabled: true)
        let watchlist = Self.generateWatchlist(userId: userId, symbolCount: Watchlist.maxSymbols)
        let user = ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
        
        #expect(user.watchlist.symbols.count == Watchlist.maxSymbols,
                "Precondition: maximum symbols")
        
        let isEligible = filter.isEligible(user)
        
        #expect(isEligible == true,
                "User with max watchlist size and analysis enabled should be eligible")
    }
    
    // MARK: - Property Tests: isEligible Consistency
    
    @Test("Property: isEligible result consistent with filter inclusion",
          arguments: (0..<100).map { _ in Self.generateRandomUserSet(count: Int.random(in: 1...10)) })
    func testIsEligibleConsistentWithFilterInclusion(users: [ScheduledAnalysisUserData]) {
        for user in users {
            let isEligible = filter.isEligible(user)
            let eligibleUsers = filter.filterEligibleUsers([user])
            
            if isEligible {
                #expect(eligibleUsers.count == 1,
                        "If isEligible returns true, filterEligibleUsers should include the user")
            } else {
                #expect(eligibleUsers.isEmpty,
                        "If isEligible returns false, filterEligibleUsers should exclude the user")
            }
        }
    }
    
    // MARK: - Property Tests: Various Watchlist Sizes
    
    @Test("Property: Users with various watchlist sizes behave correctly",
          arguments: [0, 1, 2, 5, 10, 25, 49, 50])
    func testVariousWatchlistSizes(symbolCount: Int) {
        let userId = Self.generateRandomUserId()
        let settings = Self.generateSettings(scheduledAnalysisEnabled: true)
        let watchlist = Self.generateWatchlist(userId: userId, symbolCount: symbolCount)
        let user = ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
        
        let isEligible = filter.isEligible(user)
        
        if symbolCount > 0 {
            #expect(isEligible == true,
                    "User with \(symbolCount) symbols and analysis enabled should be eligible")
        } else {
            #expect(isEligible == false,
                    "User with 0 symbols should be ineligible")
        }
    }
    
    // MARK: - Property Tests: Boolean Logic Verification
    
    @Test("Property: Eligibility follows AND logic (both conditions required)",
          arguments: [(true, true), (true, false), (false, true), (false, false)])
    func testEligibilityFollowsAndLogic(analysisEnabled: Bool, hasWatchlist: Bool) {
        let userId = Self.generateRandomUserId()
        let settings = Self.generateSettings(scheduledAnalysisEnabled: analysisEnabled)
        let symbolCount = hasWatchlist ? Int.random(in: 1...10) : 0
        let watchlist = Self.generateWatchlist(userId: userId, symbolCount: symbolCount)
        let user = ScheduledAnalysisUserData(userId: userId, settings: settings, watchlist: watchlist)
        
        let isEligible = filter.isEligible(user)
        
        // AND logic: only true when BOTH conditions are true
        let expectedEligibility = analysisEnabled && hasWatchlist
        
        #expect(isEligible == expectedEligibility,
                "Eligibility should follow AND logic: \(analysisEnabled) AND \(hasWatchlist) = \(expectedEligibility)")
    }
}

// MARK: - Additional Test Support

extension ScheduledAnalysisUserFilteringPropertyTests {
    
    /// Generates test data for parameterized tests that produce eligible users
    static var eligibleUserTestData: [ScheduledAnalysisUserData] {
        return (0..<100).map { _ in generateEligibleUser() }
    }
    
    /// Generates test data for parameterized tests that produce ineligible users
    static var ineligibleUserTestData: [ScheduledAnalysisUserData] {
        return (0..<50).map { _ in generateUserWithAnalysisDisabled() }
            + (0..<50).map { _ in generateUserWithEmptyWatchlist() }
    }
}
