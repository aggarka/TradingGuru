//
//  DataSyncPropertyTests.swift
//  TradingGuruTests
//
//  Property-based tests for data synchronization and conflict resolution.
//  Tests the correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 15: Conflict Resolution by Timestamp
// **Validates: Requirements 7.4**
//
// *For any* local data version and cloud data version with different modification
// timestamps, the conflict resolution SHALL select the version with the more
// recent (later) timestamp.

@Suite("Property 15: Conflict Resolution by Timestamp - Validates Requirements 7.4")
struct ConflictResolutionByTimestampPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    let dataSyncService = DataSyncService.forTesting()
    
    // MARK: - Test Data Types
    
    /// A simple test data type that conforms to TimestampedData for testing
    struct TestVersionedData: TimestampedData, Equatable {
        let id: String
        let value: String
        let updatedAt: Date
        
        init(id: String = UUID().uuidString, value: String, updatedAt: Date) {
            self.id = id
            self.value = value
            self.updatedAt = updatedAt
        }
    }
    
    // MARK: - Timestamp Generation Helpers
    
    /// Reference date for generating test timestamps
    static let referenceDate = Date(timeIntervalSince1970: 1700000000) // Nov 14, 2023
    
    /// Generates a random date within a specified range from the reference date
    static func randomDate(offsetRange: ClosedRange<TimeInterval>) -> Date {
        let offset = TimeInterval.random(in: offsetRange)
        return referenceDate.addingTimeInterval(offset)
    }
    
    /// Generates pairs of timestamps where the first is always earlier than the second
    static func generateOrderedTimestampPairs(count: Int) -> [(earlier: Date, later: Date)] {
        return (0..<count).map { _ in
            // Generate earlier timestamp (0 to 1 year before reference)
            let earlierOffset = TimeInterval.random(in: -31536000...0)
            let earlierDate = referenceDate.addingTimeInterval(earlierOffset)
            
            // Generate later timestamp (1 second to 1 year after earlier)
            let laterOffset = TimeInterval.random(in: 1...31536000)
            let laterDate = earlierDate.addingTimeInterval(laterOffset)
            
            return (earlier: earlierDate, later: laterDate)
        }
    }
    
    /// Generates timestamp differences for testing various time gaps
    static let timestampDifferences: [TimeInterval] = [
        1,          // 1 second
        60,         // 1 minute
        3600,       // 1 hour
        86400,      // 1 day
        604800,     // 1 week
        2592000,    // 30 days
        31536000,   // 1 year
        0.001,      // 1 millisecond
        0.000001,   // 1 microsecond
    ]
    
    // MARK: - Property Tests: Cloud More Recent Than Local
    
    @Test("Property: When cloud timestamp is more recent, cloud data is selected",
          arguments: generateOrderedTimestampPairs(count: 10))
    func testCloudMoreRecentSelectsCloud(timestamps: (earlier: Date, later: Date)) {
        // Arrange: Local has earlier timestamp, cloud has later timestamp
        let localData = TestVersionedData(
            value: "local_value",
            updatedAt: timestamps.earlier
        )
        let cloudData = TestVersionedData(
            value: "cloud_value",
            updatedAt: timestamps.later
        )
        
        // Precondition: Cloud timestamp should be more recent
        #expect(cloudData.updatedAt > localData.updatedAt,
                "Cloud should have more recent timestamp")
        
        // Act: Resolve conflict
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Assert: Cloud data SHALL be selected
        #expect(result.value == "cloud_value",
                "Expected cloud value to be selected when cloud is more recent")
        #expect(result.updatedAt == timestamps.later,
                "Result should have cloud's timestamp")
    }
    
    @Test("Property: When local timestamp is more recent, local data is selected",
          arguments: generateOrderedTimestampPairs(count: 10))
    func testLocalMoreRecentSelectsLocal(timestamps: (earlier: Date, later: Date)) {
        // Arrange: Cloud has earlier timestamp, local has later timestamp
        let localData = TestVersionedData(
            value: "local_value",
            updatedAt: timestamps.later
        )
        let cloudData = TestVersionedData(
            value: "cloud_value",
            updatedAt: timestamps.earlier
        )
        
        // Precondition: Local timestamp should be more recent
        #expect(localData.updatedAt > cloudData.updatedAt,
                "Local should have more recent timestamp")
        
        // Act: Resolve conflict
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Assert: Local data SHALL be selected
        #expect(result.value == "local_value",
                "Expected local value to be selected when local is more recent")
        #expect(result.updatedAt == timestamps.later,
                "Result should have local's timestamp")
    }
    
    // MARK: - Property Tests: Various Time Differences
    
    @Test("Property: Cloud wins with various time differences (small to large)",
          arguments: timestampDifferences)
    func testCloudWinsWithVariousTimeDifferences(timeDiff: TimeInterval) {
        let baseTime = Self.referenceDate
        let localData = TestVersionedData(
            value: "local",
            updatedAt: baseTime
        )
        let cloudData = TestVersionedData(
            value: "cloud",
            updatedAt: baseTime.addingTimeInterval(timeDiff)
        )
        
        // Precondition
        #expect(cloudData.updatedAt > localData.updatedAt)
        
        // Act
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Assert
        #expect(result.value == "cloud",
                "Cloud should win when \(timeDiff) seconds more recent")
    }
    
    @Test("Property: Local wins with various time differences (small to large)",
          arguments: timestampDifferences)
    func testLocalWinsWithVariousTimeDifferences(timeDiff: TimeInterval) {
        let baseTime = Self.referenceDate
        let localData = TestVersionedData(
            value: "local",
            updatedAt: baseTime.addingTimeInterval(timeDiff)
        )
        let cloudData = TestVersionedData(
            value: "cloud",
            updatedAt: baseTime
        )
        
        // Precondition
        #expect(localData.updatedAt > cloudData.updatedAt)
        
        // Act
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Assert
        #expect(result.value == "local",
                "Local should win when \(timeDiff) seconds more recent")
    }
    
    // MARK: - Property Tests: Equal Timestamps
    
    @Test("Property: When timestamps are equal, local data is selected (tie-breaker)")
    func testEqualTimestampsSelectsLocal() {
        let sameTime = Self.referenceDate
        let localData = TestVersionedData(
            value: "local_value",
            updatedAt: sameTime
        )
        let cloudData = TestVersionedData(
            value: "cloud_value",
            updatedAt: sameTime
        )
        
        // Precondition: Timestamps are equal
        #expect(localData.updatedAt == cloudData.updatedAt,
                "Timestamps should be equal")
        
        // Act: Resolve conflict
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Assert: Local data is selected as tie-breaker (per implementation: cloud > local returns cloud)
        // When cloud is NOT greater than local, local is returned
        #expect(result.value == "local_value",
                "Expected local value to be selected when timestamps are equal")
    }
    
    @Test("Property: Equal timestamps with various base times",
          arguments: [
            Date(timeIntervalSince1970: 0),                    // Unix epoch
            Date(timeIntervalSince1970: 1000000000),          // Sep 2001
            Date(timeIntervalSince1970: 1500000000),          // Jul 2017
            Date(timeIntervalSince1970: 1700000000),          // Nov 2023
            Date(timeIntervalSince1970: 2000000000),          // May 2033
          ])
    func testEqualTimestampsAtVariousBaseTimes(baseTime: Date) {
        let localData = TestVersionedData(value: "local", updatedAt: baseTime)
        let cloudData = TestVersionedData(value: "cloud", updatedAt: baseTime)
        
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Local wins on tie
        #expect(result.value == "local",
                "Local should win on timestamp tie")
    }
    
    // MARK: - Property Tests: ConflictResolver Helper
    
    @Test("Property: ConflictResolver.resolve returns .cloud when cloud is more recent",
          arguments: generateOrderedTimestampPairs(count: 10))
    func testConflictResolverReturnsCloudWhenMoreRecent(timestamps: (earlier: Date, later: Date)) {
        let result = ConflictResolver.resolve(
            localTimestamp: timestamps.earlier,
            cloudTimestamp: timestamps.later
        )
        
        #expect(result == .cloud,
                "ConflictResolver should return .cloud when cloud timestamp is more recent")
    }
    
    @Test("Property: ConflictResolver.resolve returns .local when local is more recent",
          arguments: generateOrderedTimestampPairs(count: 10))
    func testConflictResolverReturnsLocalWhenMoreRecent(timestamps: (earlier: Date, later: Date)) {
        let result = ConflictResolver.resolve(
            localTimestamp: timestamps.later,
            cloudTimestamp: timestamps.earlier
        )
        
        #expect(result == .local,
                "ConflictResolver should return .local when local timestamp is more recent")
    }
    
    @Test("Property: ConflictResolver returns .local when timestamps are equal")
    func testConflictResolverReturnsLocalOnTie() {
        let sameTime = Self.referenceDate
        
        let result = ConflictResolver.resolve(
            localTimestamp: sameTime,
            cloudTimestamp: sameTime
        )
        
        #expect(result == .local,
                "ConflictResolver should return .local on timestamp tie")
    }
    
    // MARK: - Property Tests: Transitivity
    
    @Test("Property: Conflict resolution is consistent (same input = same output)")
    func testConflictResolutionIsConsistent() {
        let localTime = Self.referenceDate
        let cloudTime = Self.referenceDate.addingTimeInterval(3600)
        
        let localData = TestVersionedData(value: "local", updatedAt: localTime)
        let cloudData = TestVersionedData(value: "cloud", updatedAt: cloudTime)
        
        // Run resolution multiple times
        let results = (0..<100).map { _ in
            dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        }
        
        // All results should be identical
        let allSame = results.allSatisfy { $0.value == results[0].value }
        #expect(allSame, "Conflict resolution should be deterministic")
    }
    
    @Test("Property: Resolution is symmetric with respect to timestamp comparison")
    func testResolutionIsSymmetricWithTimestamp() {
        let time1 = Self.referenceDate
        let time2 = Self.referenceDate.addingTimeInterval(1000)
        
        let data1 = TestVersionedData(value: "data1", updatedAt: time1)
        let data2 = TestVersionedData(value: "data2", updatedAt: time2)
        
        // When data2 is newer (in cloud position)
        let result1 = dataSyncService.resolveConflict(local: data1, cloud: data2)
        #expect(result1.value == "data2", "Newer data should win")
        
        // When data2 is newer (in local position)
        let result2 = dataSyncService.resolveConflict(local: data2, cloud: data1)
        #expect(result2.value == "data2", "Newer data should still win regardless of position")
    }
    
    // MARK: - Property Tests: Edge Cases with Extreme Timestamps
    
    @Test("Property: Resolution works with very old timestamps")
    func testResolutionWithVeryOldTimestamps() {
        let veryOld = Date(timeIntervalSince1970: 0) // Unix epoch
        let lessOld = Date(timeIntervalSince1970: 1)
        
        let localData = TestVersionedData(value: "old", updatedAt: veryOld)
        let cloudData = TestVersionedData(value: "lessOld", updatedAt: lessOld)
        
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        #expect(result.value == "lessOld",
                "Cloud should win even with very old timestamps")
    }
    
    @Test("Property: Resolution works with far future timestamps")
    func testResolutionWithFarFutureTimestamps() {
        let future = Date(timeIntervalSince1970: 4000000000) // Year 2096
        let moreFuture = Date(timeIntervalSince1970: 4000000001)
        
        let localData = TestVersionedData(value: "future", updatedAt: future)
        let cloudData = TestVersionedData(value: "moreFuture", updatedAt: moreFuture)
        
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        #expect(result.value == "moreFuture",
                "Cloud should win with future timestamps")
    }
    
    @Test("Property: Resolution works with negative timestamps (pre-epoch)")
    func testResolutionWithNegativeTimestamps() {
        let preEpoch1 = Date(timeIntervalSince1970: -1000) // Before Unix epoch
        let preEpoch2 = Date(timeIntervalSince1970: -500)  // Closer to epoch
        
        let localData = TestVersionedData(value: "older", updatedAt: preEpoch1)
        let cloudData = TestVersionedData(value: "newer", updatedAt: preEpoch2)
        
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        #expect(result.value == "newer",
                "Cloud (closer to epoch) should win")
    }
    
    // MARK: - Property Tests: With VersionedData Wrapper
    
    @Test("Property: VersionedData wrapper correctly tracks timestamps",
          arguments: generateOrderedTimestampPairs(count: 10))
    func testVersionedDataWrapperTracksTimestamps(timestamps: (earlier: Date, later: Date)) {
        let localVersioned = VersionedData(
            data: "local_content",
            updatedAt: timestamps.earlier,
            isFromCloud: false
        )
        let cloudVersioned = VersionedData(
            data: "cloud_content",
            updatedAt: timestamps.later,
            isFromCloud: true
        )
        
        // Act
        let result = dataSyncService.resolveConflict(local: localVersioned, cloud: cloudVersioned)
        
        // Assert
        #expect(result.data == "cloud_content",
                "Cloud content should be selected")
        #expect(result.isFromCloud == true,
                "Result should indicate it came from cloud")
        #expect(result.updatedAt == timestamps.later,
                "Result should have cloud's timestamp")
    }
    
    @Test("Property: VersionedData correctly identifies source after resolution")
    func testVersionedDataIdentifiesSource() {
        let localTime = Self.referenceDate
        let cloudTime = Self.referenceDate.addingTimeInterval(-3600) // Cloud is older
        
        let localVersioned = VersionedData(
            data: ["key": "local"],
            updatedAt: localTime,
            isFromCloud: false
        )
        let cloudVersioned = VersionedData(
            data: ["key": "cloud"],
            updatedAt: cloudTime,
            isFromCloud: true
        )
        
        let result = dataSyncService.resolveConflict(local: localVersioned, cloud: cloudVersioned)
        
        #expect(result.isFromCloud == false,
                "Result should indicate it came from local since local is newer")
        #expect(result.data["key"] == "local",
                "Local data should be selected")
    }
    
    // MARK: - Property Tests: Random Data Preservation
    
    @Test("Property: Winning data content is preserved exactly",
          arguments: [
            ("simple text", "other text"),
            ("", "non-empty"),
            ("unicode: 你好世界 🌍", "ascii only"),
            ("with\nnewlines\n", "single line"),
            (String(repeating: "a", count: 1000), "short"),
          ])
    func testWinningDataContentPreserved(localContent: String, cloudContent: String) {
        let localData = TestVersionedData(
            value: localContent,
            updatedAt: Self.referenceDate
        )
        let cloudData = TestVersionedData(
            value: cloudContent,
            updatedAt: Self.referenceDate.addingTimeInterval(1)
        )
        
        let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
        
        // Cloud is newer, so cloud content should be preserved exactly
        #expect(result.value == cloudContent,
                "Cloud content should be preserved exactly")
        #expect(result.value.count == cloudContent.count,
                "Content length should be preserved")
    }
    
    // MARK: - Property Tests: Comprehensive Random Scenarios
    
    @Test("Property: Resolution always selects the version with more recent timestamp (randomized)")
    func testResolutionAlwaysSelectsMoreRecent() {
        // Generate many random test cases
        for _ in 0..<Self.sampleCount {
            let time1 = Self.randomDate(offsetRange: -31536000...31536000)
            let time2 = Self.randomDate(offsetRange: -31536000...31536000)
            
            // Skip if times happen to be equal
            guard time1 != time2 else { continue }
            
            let localData = TestVersionedData(value: "local_\(UUID())", updatedAt: time1)
            let cloudData = TestVersionedData(value: "cloud_\(UUID())", updatedAt: time2)
            
            let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
            
            // The winner should always be the one with the later timestamp
            if time1 > time2 {
                #expect(result.value.hasPrefix("local_"),
                        "Local should win when local timestamp (\(time1)) > cloud timestamp (\(time2))")
            } else {
                #expect(result.value.hasPrefix("cloud_"),
                        "Cloud should win when cloud timestamp (\(time2)) > local timestamp (\(time1))")
            }
        }
    }
    
    @Test("Property: Millisecond differences are correctly resolved")
    func testMillisecondDifferencesResolved() {
        // Test with very small time differences (milliseconds)
        for i in 1...20 {
            let milliseconds = Double(i) / 1000.0
            let baseTime = Self.referenceDate
            
            let localData = TestVersionedData(value: "local", updatedAt: baseTime)
            let cloudData = TestVersionedData(
                value: "cloud",
                updatedAt: baseTime.addingTimeInterval(milliseconds)
            )
            
            let result = dataSyncService.resolveConflict(local: localData, cloud: cloudData)
            
            #expect(result.value == "cloud",
                    "Cloud should win with \(milliseconds * 1000)ms difference")
        }
    }
}

// MARK: - Integration Tests for Conflict Resolution

@Suite("Conflict Resolution Integration Tests")
struct ConflictResolutionIntegrationTests {
    
    let dataSyncService = DataSyncService.forTesting()
    
    @Test("Integration: StrategyConfiguration conflict resolution uses timestamp")
    func testStrategyConfigurationConflictResolution() {
        let olderTime = Date(timeIntervalSince1970: 1700000000)
        let newerTime = Date(timeIntervalSince1970: 1700003600)
        
        let localConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["windowDays": .integer(5)],
            updatedAt: olderTime
        )
        
        let cloudConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["windowDays": .integer(30)],
            updatedAt: newerTime
        )
        
        let result = dataSyncService.resolveConflict(local: localConfig, cloud: cloudConfig)
        
        #expect(result.parameters["windowDays"] == .integer(30),
                "Cloud configuration should win with newer timestamp")
        #expect(result.updatedAt == newerTime,
                "Result should have cloud's timestamp")
    }
    
    @Test("Integration: Local configuration wins when more recent")
    func testLocalConfigurationWinsWhenMoreRecent() {
        let newerTime = Date(timeIntervalSince1970: 1700003600)
        let olderTime = Date(timeIntervalSince1970: 1700000000)
        
        let localConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["premiumPct": .decimal(2.5)],
            updatedAt: newerTime
        )
        
        let cloudConfig = StrategyConfiguration(
            strategyId: "weekly_option",
            parameters: ["premiumPct": .decimal(1.0)],
            updatedAt: olderTime
        )
        
        let result = dataSyncService.resolveConflict(local: localConfig, cloud: cloudConfig)
        
        #expect(result.parameters["premiumPct"] == .decimal(2.5),
                "Local configuration should win with newer timestamp")
    }
}
