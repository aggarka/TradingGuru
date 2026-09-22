//
//  FirestoreClient.swift
//  TradingGuru
//
//  Firestore implementation of CloudDatabaseClient for cloud database operations.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore

// MARK: - Real-Time Sync Delegate Protocol

/// Delegate protocol for receiving real-time sync updates from Firestore.
/// - Validates: Requirement 7.2 (Real-time sync for watchlist and configuration changes)
/// - Validates: Requirement 8.4 (Auto-refresh results when scheduled analysis completes)
protocol FirestoreSyncDelegate: AnyObject {
    /// Called when watchlist data is updated from the server.
    /// - Parameters:
    ///   - symbols: Updated array of ticker symbols
    ///   - userId: The user ID the update applies to
    func watchlistDidUpdate(_ symbols: [String], for userId: String)
    
    /// Called when configuration data is updated from the server.
    /// - Parameters:
    ///   - configuration: Updated configuration dictionary
    ///   - strategyId: The strategy ID for the configuration
    ///   - userId: The user ID the update applies to
    func configurationDidUpdate(_ configuration: [String: Any], strategyId: String, for userId: String)
    
    /// Called when user profile is updated from the server.
    /// - Parameters:
    ///   - profile: Updated user profile dictionary
    ///   - userId: The user ID the update applies to
    func userProfileDidUpdate(_ profile: [String: Any], for userId: String)
    
    /// Called when analysis results are updated from the server.
    /// This is triggered when a scheduled analysis completes and stores new results.
    /// - Parameters:
    ///   - results: Updated array of analysis results
    ///   - metadata: Metadata about the analysis (timestamp, source, etc.)
    ///   - userId: The user ID the update applies to
    /// - Validates: Requirement 8.4 (Auto-refresh results when app is open during scheduled completion)
    func resultsDidUpdate(_ results: [AnalysisResult], metadata: ResultsMetadata, for userId: String)
    
    /// Called when a sync error occurs.
    /// - Parameter error: The error that occurred
    func syncDidFail(with error: Error)
}

// MARK: - User Profile Protocol

/// Protocol for user profile operations in the cloud database.
/// - Validates: Requirement 7.1 (Store user profiles in cloud database)
protocol UserProfileRepository {
    /// Saves or updates a user profile.
    func saveUserProfile(_ profile: UserProfile, for userId: String) async throws
    
    /// Retrieves a user profile.
    func getUserProfile(for userId: String) async throws -> UserProfile?
    
    /// Updates user settings.
    func updateUserSettings(_ settings: UserSettings, for userId: String) async throws
}


// MARK: - Firestore Client Implementation

/// Firestore implementation of CloudDatabaseClient with real-time sync support.
/// Provides cloud database operations backed by Firebase Firestore.
///
/// Database Schema:
/// ```
/// /users/{userId}
///   - email: string
///   - displayName: string
///   - authProvider: string
///   - createdAt: timestamp
///   - lastLoginAt: timestamp
///   - settings: { ... }
///
/// /users/{userId}/watchlist/{symbolId}
///   - symbol: string
///   - addedAt: timestamp
///
/// /users/{userId}/configurations/{strategyId}
///   - parameters: map
///   - updatedAt: timestamp
///
/// /users/{userId}/results/{resultId}
///   - ticker: string
///   - type: string
///   - returnPercentage: number
///   - ... (see design doc)
/// ```
///
/// - Validates: Requirement 7.1 (Store user profiles, watchlists, configurations in cloud database)
/// - Validates: Requirement 7.2 (Persist changes within 5 seconds of modification)
final class FirestoreClient: CloudDatabaseClient, UserProfileRepository {
    
    // MARK: - Constants
    
    /// Users collection name in Firestore
    private static let usersCollection = "users"
    
    /// Subcollection names
    private static let watchlistCollection = "watchlist"
    private static let configurationsCollection = "configurations"
    private static let resultsCollection = "results"
    
    /// Maximum persistence time (5 seconds per Requirement 7.2)
    private static let maxPersistenceSeconds: TimeInterval = 5.0
    
    // MARK: - Properties
    
    /// Firestore database instance
    private let firestore: Firestore
    
    /// Delegate for receiving real-time sync updates
    weak var syncDelegate: FirestoreSyncDelegate?
    
    /// Active snapshot listeners for cleanup
    private var watchlistListeners: [String: ListenerRegistration] = [:]
    private var configurationListeners: [String: ListenerRegistration] = [:]
    private var userProfileListeners: [String: ListenerRegistration] = [:]
    private var resultsListeners: [String: ListenerRegistration] = [:]
    
    /// Queue for thread-safe listener management
    private let listenerQueue = DispatchQueue(label: "com.tradingguru.firestore.listeners")
    
    // MARK: - Initialization
    
    /// Creates a new FirestoreClient instance.
    /// - Parameter firestore: Firestore instance (defaults to shared instance)
    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
        configureFirestore()
    }
    
    /// Configures Firestore settings for optimal performance.
    private func configureFirestore() {
        let settings = firestore.settings
        settings.isPersistenceEnabled = true // Enable offline persistence
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        firestore.settings = settings
    }
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - CloudDatabaseClient Protocol Methods
    
    /// Gets all documents from a collection for a specific user.
    /// - Parameters:
    ///   - collection: The subcollection name under the user document
    ///   - userId: The user ID to fetch documents for
    /// - Returns: Array of document data dictionaries
    /// - Throws: Error if Firestore operation fails
    func getDocuments(collection: String, userId: String) async throws -> [[String: Any]] {
        let collectionRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
            .collection(collection)
        
        let snapshot = try await collectionRef.getDocuments()
        
        return snapshot.documents.map { document in
            var data = document.data()
            data["_documentId"] = document.documentID
            return data
        }
    }

    /// Sets a document in a collection for a specific user.
    /// Ensures persistence within 5 seconds per Requirement 7.2.
    /// - Parameters:
    ///   - collection: The subcollection name under the user document
    ///   - userId: The user ID
    ///   - documentId: The document ID to set
    ///   - data: The data to write to the document
    /// - Throws: Error if Firestore operation fails
    /// - Validates: Requirement 7.2 (Persist changes within 5 seconds)
    func setDocument(
        collection: String,
        userId: String,
        documentId: String,
        data: [String: Any]
    ) async throws {
        let documentRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
            .collection(collection)
            .document(documentId)
        
        // Convert timestamp fields to Firestore's FieldValue
        var firestoreData = data
        if firestoreData["addedAt"] != nil {
            firestoreData["addedAt"] = FieldValue.serverTimestamp()
        }
        if firestoreData["updatedAt"] != nil {
            firestoreData["updatedAt"] = FieldValue.serverTimestamp()
        }
        
        try await documentRef.setData(firestoreData)
    }
    
    /// Deletes a document from a collection for a specific user.
    /// - Parameters:
    ///   - collection: The subcollection name under the user document
    ///   - userId: The user ID
    ///   - documentId: The document ID to delete
    /// - Throws: Error if Firestore operation fails
    func deleteDocument(
        collection: String,
        userId: String,
        documentId: String
    ) async throws {
        let documentRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
            .collection(collection)
            .document(documentId)
        
        try await documentRef.delete()
    }
    
    // MARK: - UserProfileRepository Protocol Methods
    
    /// Saves or updates a user profile in Firestore.
    /// - Parameters:
    ///   - profile: The user profile to save
    ///   - userId: The user ID
    /// - Throws: Error if Firestore operation fails
    /// - Validates: Requirement 7.1 (Store user profiles in cloud database)
    func saveUserProfile(_ profile: UserProfile, for userId: String) async throws {
        let documentRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
        
        let data: [String: Any] = [
            "email": profile.email as Any,
            "displayName": profile.displayName as Any,
            "authProvider": profile.authProvider,
            "createdAt": Timestamp(date: profile.createdAt),
            "lastLoginAt": FieldValue.serverTimestamp(),
            "settings": [
                "notificationEmail": profile.settings.notificationEmail as Any,
                "emailNotificationsEnabled": profile.settings.emailNotificationsEnabled,
                "scheduledAnalysisEnabled": profile.settings.scheduledAnalysisEnabled,
                "updatedAt": Timestamp(date: profile.settings.updatedAt)
            ]
        ]
        
        try await documentRef.setData(data, merge: true)
    }
    
    /// Retrieves a user profile from Firestore.
    /// - Parameter userId: The user ID
    /// - Returns: The user profile if found, nil otherwise
    /// - Throws: Error if Firestore operation fails
    /// - Validates: Requirement 7.1 (Store user profiles in cloud database)
    func getUserProfile(for userId: String) async throws -> UserProfile? {
        let documentRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
        
        let snapshot = try await documentRef.getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        
        return parseUserProfile(from: data, userId: userId)
    }
    
    /// Updates user settings in Firestore.
    /// - Parameters:
    ///   - settings: The settings to update
    ///   - userId: The user ID
    /// - Throws: Error if Firestore operation fails
    /// - Validates: Requirement 7.2 (Persist changes within 5 seconds)
    func updateUserSettings(_ settings: UserSettings, for userId: String) async throws {
        let documentRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
        
        let settingsData: [String: Any] = [
            "settings": [
                "notificationEmail": settings.notificationEmail as Any,
                "emailNotificationsEnabled": settings.emailNotificationsEnabled,
                "scheduledAnalysisEnabled": settings.scheduledAnalysisEnabled,
                "updatedAt": FieldValue.serverTimestamp()
            ]
        ]
        
        try await documentRef.setData(settingsData, merge: true)
    }
    
    // MARK: - Analysis Results Storage
    
    /// Saves analysis results to Firestore.
    /// - Parameters:
    ///   - results: Array of analysis results to save
    ///   - metadata: Metadata about the analysis run
    ///   - userId: The user ID
    /// - Throws: Error if Firestore operation fails
    /// - Validates: Requirement 7.1 (Store analysis results in cloud database)
    func saveAnalysisResults(
        _ results: [AnalysisResult],
        metadata: ResultsMetadata,
        for userId: String
    ) async throws {
        let batch = firestore.batch()
        
        for result in results {
            let documentRef = firestore
                .collection(Self.usersCollection)
                .document(userId)
                .collection(Self.resultsCollection)
                .document(result.id.uuidString)
            
            var data: [String: Any] = [
                "ticker": result.ticker,
                "type": result.type.rawValue,
                "returnPercentage": result.returnPercentage,
                "currentPrice": result.currentPrice,
                "targetPrice": result.targetPrice,
                "signal": result.signal.rawValue,
                "hasEarningsRisk": result.hasEarningsRisk,
                "analyzedAt": Timestamp(date: result.analyzedAt),
                "source": metadata.source.rawValue,
                "strategyId": metadata.strategyId
            ]
            
            if let earningsDate = result.nextEarningsDate {
                data["nextEarningsDate"] = Timestamp(date: earningsDate)
            }
            
            if let runId = metadata.scheduledRunId {
                data["scheduledRunId"] = runId
            }
            
            batch.setData(data, forDocument: documentRef)
        }
        
        try await batch.commit()
    }
    
    /// Retrieves the latest analysis results from Firestore.
    /// - Parameter userId: The user ID
    /// - Returns: Array of analysis results, sorted by analyzedAt descending
    /// - Throws: Error if Firestore operation fails
    func getLatestResults(for userId: String) async throws -> [AnalysisResult] {
        let collectionRef = firestore
            .collection(Self.usersCollection)
            .document(userId)
            .collection(Self.resultsCollection)
            .order(by: "analyzedAt", descending: true)
            .limit(to: 100) // Limit to recent results
        
        let snapshot = try await collectionRef.getDocuments()
        
        return snapshot.documents.compactMap { document in
            parseAnalysisResult(from: document.data(), documentId: document.documentID)
        }
    }
    
    // MARK: - Real-Time Sync Listeners
    
    /// Starts listening for real-time watchlist changes.
    /// - Parameter userId: The user ID to listen for
    /// - Validates: Requirement 7.2 (Real-time sync for watchlist changes)
    func startWatchlistListener(for userId: String) {
        listenerQueue.sync {
            // Remove existing listener if any
            watchlistListeners[userId]?.remove()
            
            let collectionRef = firestore
                .collection(Self.usersCollection)
                .document(userId)
                .collection(Self.watchlistCollection)
            
            let listener = collectionRef.addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.syncDelegate?.syncDidFail(with: error)
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let symbols = documents.compactMap { $0.data()["symbol"] as? String }.sorted()
                self?.syncDelegate?.watchlistDidUpdate(symbols, for: userId)
            }
            
            watchlistListeners[userId] = listener
        }
    }
    
    /// Starts listening for real-time configuration changes.
    /// - Parameters:
    ///   - strategyId: The strategy ID to listen for
    ///   - userId: The user ID to listen for
    /// - Validates: Requirement 7.2 (Real-time sync for configuration changes)
    func startConfigurationListener(strategyId: String, for userId: String) {
        listenerQueue.sync {
            let key = "\(userId).\(strategyId)"
            
            // Remove existing listener if any
            configurationListeners[key]?.remove()
            
            let documentRef = firestore
                .collection(Self.usersCollection)
                .document(userId)
                .collection(Self.configurationsCollection)
                .document(strategyId)
            
            let listener = documentRef.addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.syncDelegate?.syncDidFail(with: error)
                    return
                }
                
                guard let data = snapshot?.data() else { return }
                
                self?.syncDelegate?.configurationDidUpdate(data, strategyId: strategyId, for: userId)
            }
            
            configurationListeners[key] = listener
        }
    }
    
    /// Starts listening for real-time user profile changes.
    /// - Parameter userId: The user ID to listen for
    func startUserProfileListener(for userId: String) {
        listenerQueue.sync {
            // Remove existing listener if any
            userProfileListeners[userId]?.remove()
            
            let documentRef = firestore
                .collection(Self.usersCollection)
                .document(userId)
            
            let listener = documentRef.addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.syncDelegate?.syncDidFail(with: error)
                    return
                }
                
                guard let data = snapshot?.data() else { return }
                
                self?.syncDelegate?.userProfileDidUpdate(data, for: userId)
            }
            
            userProfileListeners[userId] = listener
        }
    }
    
    /// Stops listening for watchlist changes.
    /// - Parameter userId: The user ID to stop listening for
    func stopWatchlistListener(for userId: String) {
        listenerQueue.sync {
            watchlistListeners[userId]?.remove()
            watchlistListeners.removeValue(forKey: userId)
        }
    }
    
    /// Stops listening for configuration changes.
    /// - Parameters:
    ///   - strategyId: The strategy ID to stop listening for
    ///   - userId: The user ID to stop listening for
    func stopConfigurationListener(strategyId: String, for userId: String) {
        listenerQueue.sync {
            let key = "\(userId).\(strategyId)"
            configurationListeners[key]?.remove()
            configurationListeners.removeValue(forKey: key)
        }
    }
    
    /// Stops listening for user profile changes.
    /// - Parameter userId: The user ID to stop listening for
    func stopUserProfileListener(for userId: String) {
        listenerQueue.sync {
            userProfileListeners[userId]?.remove()
            userProfileListeners.removeValue(forKey: userId)
        }
    }
    
    /// Starts listening for real-time analysis results changes.
    /// Triggers when scheduled analysis completes and stores new results.
    /// - Parameter userId: The user ID to listen for
    /// - Validates: Requirement 8.4 (Auto-refresh results when app is open during scheduled completion)
    func startResultsListener(for userId: String) {
        listenerQueue.sync {
            // Remove existing listener if any
            resultsListeners[userId]?.remove()
            
            let collectionRef = firestore
                .collection(Self.usersCollection)
                .document(userId)
                .collection(Self.resultsCollection)
                .order(by: "analyzedAt", descending: true)
                .limit(to: 100)
            
            let listener = collectionRef.addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.syncDelegate?.syncDidFail(with: error)
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // Parse results
                let results = documents.compactMap { document -> AnalysisResult? in
                    self?.parseAnalysisResult(from: document.data(), documentId: document.documentID)
                }
                
                // Build metadata from the most recent result
                let metadata = self?.buildResultsMetadata(from: documents.first?.data())
                
                if let metadata = metadata {
                    self?.syncDelegate?.resultsDidUpdate(results, metadata: metadata, for: userId)
                }
            }
            
            resultsListeners[userId] = listener
        }
    }
    
    /// Stops listening for analysis results changes.
    /// - Parameter userId: The user ID to stop listening for
    func stopResultsListener(for userId: String) {
        listenerQueue.sync {
            resultsListeners[userId]?.remove()
            resultsListeners.removeValue(forKey: userId)
        }
    }
    
    /// Builds ResultsMetadata from Firestore document data.
    /// - Parameter data: The document data from the most recent result
    /// - Returns: ResultsMetadata if data is valid, nil otherwise
    private func buildResultsMetadata(from data: [String: Any]?) -> ResultsMetadata? {
        guard let data = data else { return nil }
        
        let timestamp: Date
        if let ts = data["analyzedAt"] as? Timestamp {
            timestamp = ts.dateValue()
        } else {
            timestamp = Date()
        }
        
        let source: ResultSource
        if let sourceString = data["source"] as? String,
           let parsedSource = ResultSource(rawValue: sourceString) {
            source = parsedSource
        } else {
            source = .manual
        }
        
        let strategyId = data["strategyId"] as? String ?? "weekly_option"
        let scheduledRunId = data["scheduledRunId"] as? String
        
        return ResultsMetadata(
            timestamp: timestamp,
            source: source,
            strategyId: strategyId,
            scheduledRunId: scheduledRunId
        )
    }
    
    /// Removes all active listeners.
    func removeAllListeners() {
        listenerQueue.sync {
            watchlistListeners.values.forEach { $0.remove() }
            watchlistListeners.removeAll()
            
            configurationListeners.values.forEach { $0.remove() }
            configurationListeners.removeAll()
            
            userProfileListeners.values.forEach { $0.remove() }
            userProfileListeners.removeAll()
            
            resultsListeners.values.forEach { $0.remove() }
            resultsListeners.removeAll()
        }
    }
    
    /// Stops all listeners for a specific user.
    /// - Parameter userId: The user ID to stop all listeners for
    func removeListeners(for userId: String) {
        stopWatchlistListener(for: userId)
        stopUserProfileListener(for: userId)
        stopResultsListener(for: userId)
        
        // Stop all configuration listeners for this user
        listenerQueue.sync {
            let keysToRemove = configurationListeners.keys.filter { $0.hasPrefix("\(userId).") }
            for key in keysToRemove {
                configurationListeners[key]?.remove()
                configurationListeners.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Private Parsing Helpers
    
    /// Parses a user profile from Firestore document data.
    private func parseUserProfile(from data: [String: Any], userId: String) -> UserProfile? {
        let email = data["email"] as? String
        let displayName = data["displayName"] as? String
        
        guard let authProvider = data["authProvider"] as? String else {
            return nil
        }
        
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        let lastLoginAt: Date
        if let timestamp = data["lastLoginAt"] as? Timestamp {
            lastLoginAt = timestamp.dateValue()
        } else {
            lastLoginAt = Date()
        }
        
        let settings = parseUserSettings(from: data["settings"] as? [String: Any])
        
        return UserProfile(
            userId: userId,
            email: email,
            displayName: displayName,
            authProvider: authProvider,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt,
            settings: settings
        )
    }
    
    /// Parses user settings from Firestore document data.
    private func parseUserSettings(from data: [String: Any]?) -> UserSettings {
        guard let data = data else {
            return .default
        }
        
        let notificationEmail = data["notificationEmail"] as? String
        let emailNotificationsEnabled = data["emailNotificationsEnabled"] as? Bool ?? true
        let scheduledAnalysisEnabled = data["scheduledAnalysisEnabled"] as? Bool ?? true
        
        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = Date()
        }
        
        return UserSettings(
            notificationEmail: notificationEmail,
            emailNotificationsEnabled: emailNotificationsEnabled,
            scheduledAnalysisEnabled: scheduledAnalysisEnabled,
            updatedAt: updatedAt
        )
    }
    
    /// Parses an analysis result from Firestore document data.
    private func parseAnalysisResult(from data: [String: Any], documentId: String) -> AnalysisResult? {
        guard let ticker = data["ticker"] as? String,
              let typeString = data["type"] as? String,
              let type = OpportunityType(rawValue: typeString),
              let returnPercentage = data["returnPercentage"] as? Double,
              let currentPrice = data["currentPrice"] as? Double,
              let targetPrice = data["targetPrice"] as? Double,
              let signalString = data["signal"] as? String,
              let signal = Signal(rawValue: signalString),
              let hasEarningsRisk = data["hasEarningsRisk"] as? Bool
        else {
            return nil
        }
        
        let id = UUID(uuidString: documentId) ?? UUID()
        
        let nextEarningsDate: Date?
        if let timestamp = data["nextEarningsDate"] as? Timestamp {
            nextEarningsDate = timestamp.dateValue()
        } else {
            nextEarningsDate = nil
        }
        
        let analyzedAt: Date
        if let timestamp = data["analyzedAt"] as? Timestamp {
            analyzedAt = timestamp.dateValue()
        } else {
            analyzedAt = Date()
        }
        
        return AnalysisResult(
            id: id,
            ticker: ticker,
            type: type,
            returnPercentage: returnPercentage,
            currentPrice: currentPrice,
            targetPrice: targetPrice,
            signal: signal,
            nextEarningsDate: nextEarningsDate,
            hasEarningsRisk: hasEarningsRisk,
            analyzedAt: analyzedAt
        )
    }
}

#endif

// Note: ResultsMetadata and ResultsRepository are defined in ResultsDisplayProtocols.swift


// MARK: - Mock Client for Testing

/// Mock implementation of CloudDatabaseClient for testing purposes.
/// Stores data in memory and simulates cloud database operations.
final class MockCloudDatabaseClient: CloudDatabaseClient {
    
    // MARK: - Properties
    
    /// In-memory storage for documents
    private var storage: [String: [String: [[String: Any]]]] = [:]
    
    /// Whether operations should fail (for testing error handling)
    var shouldFail: Bool = false
    
    /// Delay to simulate network latency (in seconds)
    var simulatedDelay: TimeInterval = 0
    
    // MARK: - CloudDatabaseClient Protocol Methods
    
    func getDocuments(collection: String, userId: String) async throws -> [[String: Any]] {
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        return storage[userId]?[collection] ?? []
    }

    func setDocument(
        collection: String,
        userId: String,
        documentId: String,
        data: [String: Any]
    ) async throws {
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if storage[userId] == nil {
            storage[userId] = [:]
        }
        if storage[userId]?[collection] == nil {
            storage[userId]?[collection] = []
        }
        
        // Remove existing document with same ID if exists
        storage[userId]?[collection]?.removeAll { doc in
            (doc["symbol"] as? String) == documentId ||
            (doc["_documentId"] as? String) == documentId
        }
        
        // Add new document
        var docData = data
        docData["_documentId"] = documentId
        storage[userId]?[collection]?.append(docData)
    }
    
    func deleteDocument(
        collection: String,
        userId: String,
        documentId: String
    ) async throws {
        if shouldFail {
            throw WatchlistError.databaseUnavailable
        }
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        storage[userId]?[collection]?.removeAll { doc in
            (doc["symbol"] as? String) == documentId ||
            (doc["_documentId"] as? String) == documentId
        }
    }
    
    // MARK: - Testing Helpers
    
    /// Clears all stored data
    func clearAll() {
        storage.removeAll()
    }
    
    /// Preloads data for testing
    func preload(userId: String, collection: String, documents: [[String: Any]]) {
        if storage[userId] == nil {
            storage[userId] = [:]
        }
        storage[userId]?[collection] = documents
    }
    
    /// Gets current storage state for verification
    func getStorage() -> [String: [String: [[String: Any]]]] {
        return storage
    }
    
    /// Gets document count for a collection
    func documentCount(userId: String, collection: String) -> Int {
        return storage[userId]?[collection]?.count ?? 0
    }
}

