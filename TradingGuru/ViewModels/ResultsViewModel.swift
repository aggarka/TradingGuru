//
//  ResultsViewModel.swift
//  TradingGuru
//
//  ViewModel for managing analysis results display.
//

import Foundation
import Observation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// ViewModel for managing analysis results display and sorting.
///
/// Provides properties and methods for:
/// - Displaying analysis results in a table format
/// - Sorting results by column
/// - Filtering results (ONLY_ORDERS, opportunity type)
/// - Persisting and loading results via ResultsRepository
/// - Showing last updated timestamp
/// - Handling empty state and loading states
/// - Real-time updates when scheduled analysis completes
///
/// - Validates: Requirement 6.1-6.8 (Results display functionality)
/// - Validates: Requirement 8.4 (Auto-refresh results when app is open during scheduled completion)
/// - Validates: Requirement 8.5 (Display most recent results)
/// - Validates: Requirement 8.6 (Display "Last updated: [time] PST")
@Observable
final class ResultsViewModel {
    // MARK: - Dependencies
    
    /// The repository for persisting and retrieving results.
    /// - Validates: Requirement 8.5 (Display most recent results)
    private let resultsRepository: ResultsRepository
    
    /// The user identifier for results persistence.
    let userId: String
    
    #if canImport(FirebaseFirestore)
    /// Firestore client for real-time listening.
    /// - Validates: Requirement 8.4 (Auto-refresh results)
    private var firestoreClient: FirestoreClient?
    #endif
    
    /// Whether real-time listening is active.
    private(set) var isListening: Bool = false
    
    // MARK: - Published Properties
    
    /// The current analysis results to display.
    /// - Validates: Requirement 6.1 (Results table data)
    private(set) var results: [AnalysisResultRow] = []
    
    /// The metadata about the current results.
    /// - Validates: Requirement 8.6 (Last updated timestamp)
    private(set) var resultsMetadata: ResultsMetadata?
    
    /// The current sort state for the results table.
    /// - Validates: Requirement 6.5 (Initial sort by Return % descending)
    private(set) var sortState: SortState = SortState(column: .returnPercentage, direction: .descending)
    
    /// The current filter for results display.
    /// - Validates: Requirement 4.5 (ONLY_ORDERS filter)
    var filter: ResultsFilter = .default
    
    /// Whether results are currently being loaded.
    private(set) var isLoading: Bool = false
    
    /// Error message from the last load operation, if any.
    private(set) var loadError: String?
    
    // MARK: - Computed Properties
    
    /// Whether there are results to display.
    /// - Validates: Requirement 6.7 (Empty state detection)
    var hasResults: Bool {
        !results.isEmpty
    }
    
    /// The formatted last updated display string.
    /// Uses metadata timestamp if available, otherwise falls back to stored display string.
    /// - Validates: Requirement 8.6 ("Last updated: [time] PST")
    var lastUpdatedDisplay: String? {
        if let metadata = resultsMetadata {
            return metadata.lastUpdatedDisplay
        }
        return _legacyLastUpdatedDisplay
    }
    
    /// Legacy last updated display string for backward compatibility.
    private var _legacyLastUpdatedDisplay: String?
    
    /// The results sorted according to current sort state.
    /// - Validates: Requirement 6.5 (Allow sorting by any column)
    var sortedResults: [AnalysisResultRow] {
        results.sorted(by: sortState)
    }
    
    /// The results filtered and sorted according to current filter and sort state.
    /// - Validates: Requirement 4.5 (ONLY_ORDERS filter)
    /// - Validates: Requirement 6.5 (Allow sorting by any column)
    var filteredSortedResults: [AnalysisResultRow] {
        results.filtered(by: filter).sorted(by: sortState)
    }
    
    // MARK: - Initialization
    
    /// Creates a new ResultsViewModel instance.
    /// - Parameters:
    ///   - resultsRepository: The repository for persistence (defaults to LocalResultsRepository)
    ///   - userId: The user identifier for persistence context
    init(
        resultsRepository: ResultsRepository = LocalResultsRepository(),
        userId: String = "default_user"
    ) {
        self.resultsRepository = resultsRepository
        self.userId = userId
    }
    
    deinit {
        stopListeningForUpdates()
    }
    
    // MARK: - Public Methods
    
    /// Loads results from the repository.
    /// - Validates: Requirement 8.5 (Display most recent results)
    func loadResults() async {
        isLoading = true
        loadError = nil
        
        do {
            if let stored = try await resultsRepository.getLatestResults(for: userId) {
                self.results = stored.results.map { AnalysisResultRow(from: $0) }
                self.resultsMetadata = stored.metadata
            }
        } catch {
            loadError = "Unable to load results. Please try again."
        }
        
        isLoading = false
    }
    
    /// Saves results to the repository.
    /// - Parameters:
    ///   - results: The analysis results to save
    ///   - metadata: Metadata about the analysis run
    /// - Validates: Requirement 8.5 (Store results for later display)
    func saveResults(_ results: [AnalysisResult], metadata: ResultsMetadata) async {
        do {
            try await resultsRepository.saveResults(results, metadata: metadata, for: userId)
            // Update local state after successful save
            self.results = results.map { AnalysisResultRow(from: $0) }
            self.resultsMetadata = metadata
            self._legacyLastUpdatedDisplay = nil
            loadError = nil
        } catch {
            loadError = "Unable to save results. Please try again."
        }
    }
    
    /// Updates the results with new analysis data.
    /// - Parameters:
    ///   - newResults: The new analysis results
    ///   - timestamp: When the analysis was performed
    func updateResults(_ newResults: [AnalysisResult], timestamp: Date = Date()) {
        self.results = newResults.map { AnalysisResultRow(from: $0) }
        self._legacyLastUpdatedDisplay = formatLastUpdated(timestamp)
        self.resultsMetadata = nil
        self.loadError = nil
    }
    
    /// Updates results with metadata.
    /// - Parameters:
    ///   - newResults: The new analysis results
    ///   - metadata: The metadata about the analysis
    func updateResults(_ newResults: [AnalysisResult], metadata: ResultsMetadata) {
        self.results = newResults.map { AnalysisResultRow(from: $0) }
        self.resultsMetadata = metadata
        self._legacyLastUpdatedDisplay = nil
        self.loadError = nil
    }
    
    /// Clears all results and resets the view.
    func clearResults() {
        self.results = []
        self._legacyLastUpdatedDisplay = nil
        self.resultsMetadata = nil
        self.loadError = nil
    }
    
    /// Sorts results by the specified column.
    /// If tapping the same column, toggles sort direction.
    /// If tapping a different column, sorts descending by that column.
    /// - Parameter column: The column to sort by
    /// - Validates: Requirements 6.5, 6.6 (Sort by column, toggle direction)
    func sort(by column: ResultColumn) {
        sortState.handleColumnTap(column)
    }
    
    /// Updates the filter for results display.
    /// - Parameter newFilter: The new filter to apply
    /// - Validates: Requirement 4.5 (ONLY_ORDERS filter)
    func updateFilter(_ newFilter: ResultsFilter) {
        self.filter = newFilter
    }
    
    /// Sets the ONLY_ORDERS filter.
    /// - Parameter onlyOrders: Whether to show only ORDER signals
    /// - Validates: Requirement 4.5 (ONLY_ORDERS filter)
    func setOnlyOrdersFilter(_ onlyOrders: Bool) {
        self.filter.onlyOrders = onlyOrders
    }
    
    /// Sets the option type filter (CALL, PUT, or Both).
    /// - Parameter opportunityType: The OpportunityType to filter by, or nil for both
    func setOptionTypeFilter(_ opportunityType: OpportunityType?) {
        self.filter.opportunityType = opportunityType
    }
    
    /// Clears any load error.
    func clearError() {
        self.loadError = nil
    }
    
    // MARK: - Real-Time Listening
    
    #if canImport(FirebaseFirestore)
    /// Starts listening for real-time results updates from Firestore.
    /// This enables auto-refresh when scheduled analysis completes while the app is open.
    /// - Parameter firestoreClient: The Firestore client to use for listening
    /// - Validates: Requirement 8.4 (Auto-refresh results when app is open during scheduled completion)
    func startListeningForUpdates(using firestoreClient: FirestoreClient) {
        guard !isListening else { return }
        
        self.firestoreClient = firestoreClient
        firestoreClient.syncDelegate = self
        firestoreClient.startResultsListener(for: userId)
        isListening = true
    }
    
    /// Stops listening for real-time results updates.
    func stopListeningForUpdates() {
        guard isListening else { return }
        
        firestoreClient?.stopResultsListener(for: userId)
        firestoreClient?.syncDelegate = nil
        firestoreClient = nil
        isListening = false
    }
    #else
    /// Placeholder for non-Firebase builds.
    func startListeningForUpdates() {
        // No-op when Firebase is not available
    }
    
    /// Placeholder for non-Firebase builds.
    func stopListeningForUpdates() {
        // No-op when Firebase is not available
    }
    #endif
    
    // MARK: - Private Methods
    
    /// Formats the last updated timestamp for display.
    /// - Parameter date: The timestamp to format
    /// - Returns: Formatted string like "Last updated: Jan 15, 2024 at 9:30 AM PST"
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return "Last updated: \(formatter.string(from: date)) PST"
    }
}

// MARK: - FirestoreSyncDelegate Conformance

#if canImport(FirebaseFirestore)
extension ResultsViewModel: FirestoreSyncDelegate {
    /// Called when analysis results are updated from Firestore (e.g., scheduled analysis completes).
    /// - Parameters:
    ///   - results: Updated array of analysis results
    ///   - metadata: Metadata about the analysis
    ///   - userId: The user ID the update applies to
    /// - Validates: Requirement 8.4 (Auto-refresh results when app is open during scheduled completion)
    func resultsDidUpdate(_ results: [AnalysisResult], metadata: ResultsMetadata, for userId: String) {
        guard userId == self.userId else { return }
        
        // Update on main thread for UI safety
        Task { @MainActor in
            self.results = results.map { AnalysisResultRow(from: $0) }
            self.resultsMetadata = metadata
            self._legacyLastUpdatedDisplay = nil
            self.loadError = nil
        }
    }
    
    // MARK: - Unused Delegate Methods
    
    func watchlistDidUpdate(_ symbols: [String], for userId: String) {
        // Not used by ResultsViewModel
    }
    
    func configurationDidUpdate(_ configuration: [String: Any], strategyId: String, for userId: String) {
        // Not used by ResultsViewModel
    }
    
    func userProfileDidUpdate(_ profile: [String: Any], for userId: String) {
        // Not used by ResultsViewModel
    }
    
    func syncDidFail(with error: Error) {
        // Log error but don't disturb the UI
        print("ResultsViewModel sync error: \(error.localizedDescription)")
    }
}
#endif

// MARK: - Preview Helpers

extension ResultsViewModel {
    /// Creates a preview instance with sample data demonstrating all visual indicators.
    ///
    /// Includes examples of:
    /// - CALL with ORDER signal (blue background, green type, green positive return)
    /// - PUT with HOLD signal and earnings risk (red earnings date, red type, red negative return)
    /// - CALL with HOLD signal (normal background, green type, green positive return)
    /// - PUT with ORDER signal and earnings risk (blue background, red earnings date, red negative return)
    ///
    /// - Validates: Requirements 6.2, 6.3, 6.4 (Visual indicators)
    static var preview: ResultsViewModel {
        let viewModel = ResultsViewModel()
        
        let sampleResults: [AnalysisResult] = [
            // CALL + ORDER signal: Blue background, green type, positive return (green)
            // - Validates: Requirement 6.2 (CALL with positive return in green)
            // - Validates: Requirement 6.3 (ORDER row with blue background)
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
            // PUT + HOLD + earnings risk: Normal background, red type, red negative return, red earnings date
            // - Validates: Requirement 6.2 (PUT with negative return in red)
            // - Validates: Requirement 6.4 (Earnings date in red when hasEarningsRisk is true)
            AnalysisResult(
                ticker: "GOOGL",
                type: .put,
                returnPercentage: -3.18,
                currentPrice: 142.30,
                targetPrice: 137.77,
                signal: .hold,
                nextEarningsDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                hasEarningsRisk: true
            ),
            // CALL + HOLD: Normal background, green type, positive return (green)
            // - Validates: Requirement 6.2 (CALL with positive return)
            AnalysisResult(
                ticker: "MSFT",
                type: .call,
                returnPercentage: 2.45,
                currentPrice: 380.00,
                targetPrice: 389.31,
                signal: .hold,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            ),
            // PUT + ORDER + earnings risk: Blue background, red type, red negative return, red earnings date
            // - Validates: Requirement 6.2 (PUT with negative return in red)
            // - Validates: Requirement 6.3 (ORDER row with blue background)
            // - Validates: Requirement 6.4 (Earnings date in red when hasEarningsRisk is true)
            AnalysisResult(
                ticker: "NVDA",
                type: .put,
                returnPercentage: -4.50,
                currentPrice: 450.00,
                targetPrice: 429.75,
                signal: .order,
                nextEarningsDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                hasEarningsRisk: true
            ),
            // CALL + ORDER: Blue background, green type, positive return (green), N/A earnings
            // - Validates: Requirement 6.3 (ORDER row with blue background)
            // - Validates: Requirement 6.8 ("N/A" for missing earnings date)
            AnalysisResult(
                ticker: "AMZN",
                type: .call,
                returnPercentage: 3.75,
                currentPrice: 185.00,
                targetPrice: 191.94,
                signal: .order,
                nextEarningsDate: nil,
                hasEarningsRisk: false
            )
        ]
        
        viewModel.updateResults(sampleResults)
        return viewModel
    }
    
    /// Creates a preview instance with no data.
    static var emptyPreview: ResultsViewModel {
        ResultsViewModel()
    }
    
    /// Creates a preview instance in loading state.
    static var loadingPreview: ResultsViewModel {
        let viewModel = ResultsViewModel()
        viewModel.isLoading = true
        return viewModel
    }
    
    /// Creates a preview instance with an error.
    static var errorPreview: ResultsViewModel {
        let viewModel = ResultsViewModel()
        viewModel.loadError = "Unable to load results. Please try again."
        return viewModel
    }
    
    /// Creates a preview instance with scheduled results and last updated timestamp.
    /// - Validates: Requirement 8.6 (Display "Last updated: [time] PST")
    static var scheduledPreview: ResultsViewModel {
        let viewModel = ResultsViewModel()
        
        let sampleResults: [AnalysisResult] = [
            AnalysisResult(
                ticker: "AAPL",
                type: .call,
                returnPercentage: 5.25,
                currentPrice: 178.50,
                targetPrice: 187.87,
                signal: .order,
                nextEarningsDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                hasEarningsRisk: false
            )
        ]
        
        let metadata = ResultsMetadata(
            timestamp: Date(),
            source: .scheduled,
            strategyId: "weekly_option",
            scheduledRunId: "scheduled_run_123"
        )
        
        viewModel.updateResults(sampleResults, metadata: metadata)
        return viewModel
    }
}
