//
//  ResultsDisplayProtocols.swift
//  TradingGuru
//
//  Protocol definitions for analysis results display and sorting.
//

import Foundation

// MARK: - Result Column

/// Columns available for sorting in the results table.
/// - Validates: Requirement 6.1 (Results table columns)
/// - Validates: Requirements 6.8, 6.9 (Sort by new columns)
enum ResultColumn: String, CaseIterable {
    // Existing columns
    case ticker
    case type
    case returnPercentage
    case currentPrice
    case targetPrice
    case signal
    case nextEarningsDate
    
    // NEW: Options columns
    case expirationDate
    case strikePrice
    case bidPremium
    case askPremium
    case midPremium
    
    /// Display name for the column header
    var displayName: String {
        switch self {
        case .ticker: return "Ticker"
        case .type: return "Type"
        case .returnPercentage: return "Return %"
        case .currentPrice: return "Current Price"
        case .targetPrice: return "Target Price"
        case .signal: return "Signal"
        case .nextEarningsDate: return "Next Earnings"
        case .expirationDate: return "Expiration Date"
        case .strikePrice: return "Strike Price"
        case .bidPremium: return "Bid Premium"
        case .askPremium: return "Ask Premium"
        case .midPremium: return "Mid Premium"
        }
    }
}

// MARK: - Sort Direction

/// Direction for sorting results.
/// - Validates: Requirement 6.6 (Toggle sort direction)
enum SortDirection {
    case ascending
    case descending
    
    /// Toggles the sort direction to the opposite value.
    /// - Validates: Requirement 6.6 (Toggle between ascending and descending)
    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
    
    /// Returns the opposite direction without mutating.
    var toggled: SortDirection {
        return self == .ascending ? .descending : .ascending
    }
    
    /// Symbol to display indicating sort direction
    var symbol: String {
        switch self {
        case .ascending: return "↑"
        case .descending: return "↓"
        }
    }
}

// MARK: - Sort State

/// Represents the current sort state for the results table.
struct SortState: Equatable {
    /// The column currently being sorted by
    var column: ResultColumn
    
    /// The direction of the sort
    var direction: SortDirection
    
    /// Creates a new SortState with default values.
    /// - Validates: Requirement 6.5 (Default sort by Return % descending)
    init(column: ResultColumn = .returnPercentage, direction: SortDirection = .descending) {
        self.column = column
        self.direction = direction
    }
    
    /// Updates sort state when a column header is tapped.
    /// - Parameter tappedColumn: The column that was tapped
    /// - Validates: Requirement 6.6 (Toggle direction on same column, reset on different)
    mutating func handleColumnTap(_ tappedColumn: ResultColumn) {
        if column == tappedColumn {
            direction.toggle()
        } else {
            column = tappedColumn
            direction = .descending
        }
    }
}

// MARK: - Results Display Protocol

/// Protocol for results display and management.
/// 
/// Provides functionality for displaying, sorting, and managing
/// analysis results in the UI.
/// 
/// - Validates: Requirements 6.1, 6.5, 6.6, 6.7 (Results display)
protocol ResultsDisplay {
    /// The current results to display.
    var results: [AnalysisResultRow] { get }
    
    /// The column currently being sorted by.
    var sortColumn: ResultColumn { get set }
    
    /// The current sort direction.
    var sortDirection: SortDirection { get set }
    
    /// The timestamp of the last analysis update.
    var lastUpdated: Date? { get }
    
    /// The source of the results (manual or scheduled).
    var resultSource: ResultSource? { get }
    
    /// Sorts results by the specified column.
    /// - Parameter column: The column to sort by
    /// - Validates: Requirement 6.5 (Sort by any column)
    func sort(by column: ResultColumn)
    
    /// Toggles the sort direction for the current column.
    /// - Validates: Requirement 6.6 (Toggle sort direction)
    func toggleSortDirection()
    
    /// Checks if results are available.
    var hasResults: Bool { get }
}

// MARK: - Result Source

/// The source of analysis results.
enum ResultSource: String, Codable {
    /// Results from a manually triggered analysis
    case manual
    
    /// Results from a scheduled analysis run
    case scheduled
}

// MARK: - Results Metadata

/// Metadata about analysis results.
struct ResultsMetadata: Codable, Equatable {
    /// When the analysis was performed
    let timestamp: Date
    
    /// Whether this was a manual or scheduled run
    let source: ResultSource
    
    /// The strategy used for the analysis
    let strategyId: String
    
    /// The scheduled run ID if applicable
    let scheduledRunId: String?
    
    /// Creates a new ResultsMetadata instance.
    init(
        timestamp: Date = Date(),
        source: ResultSource,
        strategyId: String,
        scheduledRunId: String? = nil
    ) {
        self.timestamp = timestamp
        self.source = source
        self.strategyId = strategyId
        self.scheduledRunId = scheduledRunId
    }
    
    /// Formatted last updated string for display.
    /// - Validates: Requirement 8.6 ("Last updated: [time] PST")
    var lastUpdatedDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return "Last updated: \(formatter.string(from: timestamp)) PST"
    }
}

// MARK: - Results Filter

/// Filter options for results display.
struct ResultsFilter: Equatable {
    /// Show only ORDER signals.
    /// - Validates: Requirement 4.5 (ONLY_ORDERS filter)
    var onlyOrders: Bool
    
    /// Filter by opportunity type (nil = show all)
    var opportunityType: OpportunityType?
    
    /// Creates a new ResultsFilter with defaults.
    init(onlyOrders: Bool = false, opportunityType: OpportunityType? = nil) {
        self.onlyOrders = onlyOrders
        self.opportunityType = opportunityType
    }
    
    /// Default filter showing all results.
    static let `default` = ResultsFilter()
}

// MARK: - Results Repository Protocol

/// Protocol for persisting and retrieving analysis results.
protocol ResultsRepository {
    /// Saves analysis results for a user.
    /// - Parameters:
    ///   - results: The analysis results to save
    ///   - metadata: Metadata about the analysis run
    ///   - userId: The user's identifier
    /// - Throws: Error if save fails
    func saveResults(
        _ results: [AnalysisResult],
        metadata: ResultsMetadata,
        for userId: String
    ) async throws
    
    /// Retrieves the latest results for a user.
    /// - Parameter userId: The user's identifier
    /// - Returns: Tuple of results and metadata, or nil if none exist
    /// - Validates: Requirement 8.5 (Display most recent results)
    func getLatestResults(for userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)?
    
    /// Retrieves results from a specific scheduled run.
    /// - Parameters:
    ///   - runId: The scheduled run identifier
    ///   - userId: The user's identifier
    /// - Returns: Tuple of results and metadata, or nil if not found
    func getResults(forRunId runId: String, userId: String) async throws -> (results: [AnalysisResult], metadata: ResultsMetadata)?
}

// MARK: - Results Sorting Extension

extension Array where Element == AnalysisResultRow {
    /// Returns a sorted copy of the results based on the specified sort state.
    /// - Parameter sortState: The sort configuration
    /// - Returns: Sorted array of results
    /// - Validates: Requirements 6.5, 6.6 (Results sorting)
    func sorted(by sortState: SortState) -> [AnalysisResultRow] {
        return sorted { lhs, rhs in
            let ascending = sortState.direction == .ascending
            
            switch sortState.column {
            case .ticker:
                return ascending ? lhs.ticker < rhs.ticker : lhs.ticker > rhs.ticker
            case .type:
                return ascending ? lhs.type < rhs.type : lhs.type > rhs.type
            case .returnPercentage:
                return ascending ? lhs.rawReturnPercentage < rhs.rawReturnPercentage : lhs.rawReturnPercentage > rhs.rawReturnPercentage
            case .currentPrice:
                return ascending ? lhs.rawCurrentPrice < rhs.rawCurrentPrice : lhs.rawCurrentPrice > rhs.rawCurrentPrice
            case .targetPrice:
                return ascending ? lhs.rawTargetPrice < rhs.rawTargetPrice : lhs.rawTargetPrice > rhs.rawTargetPrice
            case .signal:
                return ascending ? lhs.signal < rhs.signal : lhs.signal > rhs.signal
            case .nextEarningsDate:
                // Handle nil dates - nil goes to end for ascending, beginning for descending
                switch (lhs.rawNextEarningsDate, rhs.rawNextEarningsDate) {
                case (nil, nil): return false
                case (nil, _): return !ascending
                case (_, nil): return ascending
                case let (lhsDate?, rhsDate?):
                    return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
                }
            
            // MARK: - Options Columns Sorting
            // - Validates: Requirements 6.8, 6.9 (Sort by new columns)
            // Nil values are sorted to the end for ascending, beginning for descending
            
            case .expirationDate:
                // Handle nil dates - nil goes to end for ascending, beginning for descending
                switch (lhs.rawExpirationDate, rhs.rawExpirationDate) {
                case (nil, nil): return false
                case (nil, _): return !ascending  // nil goes to end for ascending
                case (_, nil): return ascending   // non-nil comes before nil for ascending
                case let (lhsDate?, rhsDate?):
                    return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
                }
                
            case .strikePrice:
                // Handle nil values - nil goes to end for ascending, beginning for descending
                switch (lhs.rawStrikePrice, rhs.rawStrikePrice) {
                case (nil, nil): return false
                case (nil, _): return !ascending  // nil goes to end for ascending
                case (_, nil): return ascending   // non-nil comes before nil for ascending
                case let (lhsPrice?, rhsPrice?):
                    return ascending ? lhsPrice < rhsPrice : lhsPrice > rhsPrice
                }
                
            case .bidPremium:
                // Handle nil values - nil goes to end for ascending, beginning for descending
                // Note: AnalysisResultRow doesn't have rawBidPremium, use rawMidPremium as proxy
                // or extract from string. For now, use string comparison as fallback.
                // Bid premium sorting uses the bidPremium display string.
                let lhsBid = lhs.extractBidPremiumValue()
                let rhsBid = rhs.extractBidPremiumValue()
                switch (lhsBid, rhsBid) {
                case (nil, nil): return false
                case (nil, _): return !ascending
                case (_, nil): return ascending
                case let (lhsVal?, rhsVal?):
                    return ascending ? lhsVal < rhsVal : lhsVal > rhsVal
                }
                
            case .askPremium:
                // Handle nil values - nil goes to end for ascending, beginning for descending
                // Ask premium sorting uses the askPremium display string.
                let lhsAsk = lhs.extractAskPremiumValue()
                let rhsAsk = rhs.extractAskPremiumValue()
                switch (lhsAsk, rhsAsk) {
                case (nil, nil): return false
                case (nil, _): return !ascending
                case (_, nil): return ascending
                case let (lhsVal?, rhsVal?):
                    return ascending ? lhsVal < rhsVal : lhsVal > rhsVal
                }
                
            case .midPremium:
                // Handle nil values - nil goes to end for ascending, beginning for descending
                switch (lhs.rawMidPremium, rhs.rawMidPremium) {
                case (nil, nil): return false
                case (nil, _): return !ascending  // nil goes to end for ascending
                case (_, nil): return ascending   // non-nil comes before nil for ascending
                case let (lhsPremium?, rhsPremium?):
                    return ascending ? lhsPremium < rhsPremium : lhsPremium > rhsPremium
                }
            }
        }
    }
    
    /// Filters results based on the specified filter criteria.
    /// - Parameter filter: The filter configuration
    /// - Returns: Filtered array of results
    func filtered(by filter: ResultsFilter) -> [AnalysisResultRow] {
        return self.filter { row in
            // Check ONLY_ORDERS filter
            if filter.onlyOrders && row.signal != Signal.order.rawValue {
                return false
            }
            
            // Check opportunity type filter
            if let type = filter.opportunityType, row.type != type.rawValue {
                return false
            }
            
            return true
        }
    }
}


// MARK: - AnalysisResultRow Premium Value Extraction

extension AnalysisResultRow {
    /// Extracts the numeric value from the bid premium display string.
    /// - Returns: The bid premium value, or nil if "N/A" or unparseable
    /// - Validates: Requirements 6.8, 6.9 (Sort by premium columns)
    func extractBidPremiumValue() -> Double? {
        return Self.extractCurrencyValue(from: bidPremium)
    }
    
    /// Extracts the numeric value from the ask premium display string.
    /// - Returns: The ask premium value, or nil if "N/A" or unparseable
    /// - Validates: Requirements 6.8, 6.9 (Sort by premium columns)
    func extractAskPremiumValue() -> Double? {
        return Self.extractCurrencyValue(from: askPremium)
    }
    
    /// Extracts a numeric value from a currency-formatted string.
    /// - Parameter string: The formatted string (e.g., "$1.25" or "N/A")
    /// - Returns: The numeric value, or nil if unparseable
    private static func extractCurrencyValue(from string: String) -> Double? {
        // Return nil for N/A values
        guard string != "N/A" else { return nil }
        
        // Remove currency symbol and whitespace
        let cleaned = string
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleaned)
    }
}
