//
//  LocalResultsRepository.swift
//  TradingGuru
//
//  Local implementation of ResultsRepository using UserDefaults for persistence.
//

import Foundation

/// Local implementation of ResultsRepository that persists data using UserDefaults.
///
/// This implementation provides local persistence for analysis results, suitable for:
/// - Development and testing
/// - Offline-first behavior when cloud database is unavailable
/// - Caching results for quick access
///
/// - Validates: Requirement 8.5 (Display most recent results)
final class LocalResultsRepository: ResultsRepository {
    
    // MARK: - Constants
    
    private enum Keys {
        static let resultsPrefix = "tradingguru.results."
        static let metadataPrefix = "tradingguru.metadata."
        static let runResultsPrefix = "tradingguru.run."
    }
    
    // MARK: - Dependencies
    
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    /// Creates a new LocalResultsRepository instance.
    /// - Parameter userDefaults: The UserDefaults instance to use (defaults to .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }
    
    // MARK: - ResultsRepository Implementation
    
    /// Saves analysis results for a user.
    /// - Parameters:
    ///   - results: The analysis results to save
    ///   - metadata: Metadata about the analysis run
    ///   - userId: The user's identifier
    /// - Throws: Error if encoding or save fails
    func saveResults(
        _ results: [AnalysisResult],
        metadata: ResultsMetadata,
        for userId: String
    ) async throws {
        let resultsKey = Keys.resultsPrefix + userId
        let metadataKey = Keys.metadataPrefix + userId
        
        let resultsData = try encoder.encode(results)
        let metadataData = try encoder.encode(metadata)
        
        userDefaults.set(resultsData, forKey: resultsKey)
        userDefaults.set(metadataData, forKey: metadataKey)
        
        // If this is a scheduled run, also store by run ID
        if let runId = metadata.scheduledRunId {
            let runKey = Keys.runResultsPrefix + userId + "." + runId
            let runData = try encoder.encode(StoredRunResults(results: results, metadata: metadata))
            userDefaults.set(runData, forKey: runKey)
        }
    }
    
    /// Retrieves the latest results for a user.
    /// - Parameter userId: The user's identifier
    /// - Returns: Tuple of results and metadata, or nil if none exist
    /// - Validates: Requirement 8.5 (Display most recent results)
    func getLatestResults(for userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)? {
        let resultsKey = Keys.resultsPrefix + userId
        let metadataKey = Keys.metadataPrefix + userId
        
        guard let resultsData = userDefaults.data(forKey: resultsKey),
              let metadataData = userDefaults.data(forKey: metadataKey) else {
            return nil
        }
        
        let results = try decoder.decode([AnalysisResult].self, from: resultsData)
        let metadata = try decoder.decode(ResultsMetadata.self, from: metadataData)
        
        return (results: results, metadata: metadata)
    }
    
    /// Retrieves results from a specific scheduled run.
    /// - Parameters:
    ///   - runId: The scheduled run identifier
    ///   - userId: The user's identifier
    /// - Returns: Tuple of results and metadata, or nil if not found
    func getResults(forRunId runId: String, userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)? {
        let runKey = Keys.runResultsPrefix + userId + "." + runId
        
        guard let runData = userDefaults.data(forKey: runKey) else {
            return nil
        }
        
        let storedRun = try decoder.decode(StoredRunResults.self, from: runData)
        return (results: storedRun.results, metadata: storedRun.metadata)
    }
    
    // MARK: - Additional Methods
    
    /// Clears all stored results for a user.
    /// - Parameter userId: The user's identifier
    func clearResults(for userId: String) {
        let resultsKey = Keys.resultsPrefix + userId
        let metadataKey = Keys.metadataPrefix + userId
        
        userDefaults.removeObject(forKey: resultsKey)
        userDefaults.removeObject(forKey: metadataKey)
    }
    
    /// Checks if results exist for a user.
    /// - Parameter userId: The user's identifier
    /// - Returns: true if results exist
    func hasResults(for userId: String) -> Bool {
        let resultsKey = Keys.resultsPrefix + userId
        return userDefaults.data(forKey: resultsKey) != nil
    }
}

// MARK: - Supporting Types

/// Internal structure for storing run results.
private struct StoredRunResults: Codable {
    let results: [AnalysisResult]
    let metadata: ResultsMetadata
}

// MARK: - Mock Repository for Testing

/// A mock implementation of ResultsRepository for testing purposes.
final class MockResultsRepository: ResultsRepository {
    
    // MARK: - Test State
    
    /// Stored results by user ID.
    var storedResults: [String: ([AnalysisResult], ResultsMetadata)] = [:]
    
    /// Stored run results by (userId, runId).
    var storedRunResults: [String: ([AnalysisResult], ResultsMetadata)] = [:]
    
    /// Whether save should throw an error.
    var shouldFailSave: Bool = false
    
    /// Whether load should throw an error.
    var shouldFailLoad: Bool = false
    
    /// The error to throw when failing.
    var errorToThrow: Error = NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    
    /// Number of times saveResults was called.
    var saveCallCount: Int = 0
    
    /// Number of times getLatestResults was called.
    var loadCallCount: Int = 0
    
    // MARK: - ResultsRepository Implementation
    
    func saveResults(
        _ results: [AnalysisResult],
        metadata: ResultsMetadata,
        for userId: String
    ) async throws {
        saveCallCount += 1
        
        if shouldFailSave {
            throw errorToThrow
        }
        
        storedResults[userId] = (results, metadata)
        
        if let runId = metadata.scheduledRunId {
            let key = "\(userId).\(runId)"
            storedRunResults[key] = (results, metadata)
        }
    }
    
    func getLatestResults(for userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)? {
        loadCallCount += 1
        
        if shouldFailLoad {
            throw errorToThrow
        }
        
        return storedResults[userId]
    }
    
    func getResults(forRunId runId: String, userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)? {
        if shouldFailLoad {
            throw errorToThrow
        }
        
        let key = "\(userId).\(runId)"
        return storedRunResults[key]
    }
    
    // MARK: - Test Helpers
    
    /// Resets all test state.
    func reset() {
        storedResults.removeAll()
        storedRunResults.removeAll()
        shouldFailSave = false
        shouldFailLoad = false
        saveCallCount = 0
        loadCallCount = 0
    }
}
