//
//  MarketDataProtocols.swift
//  TradingGuru
//
//  Protocol definitions for market data services (Yahoo Finance integration).
//

import Foundation

// MARK: - Market Data Service Protocol

/// Protocol for market data services that fetch price and earnings data.
/// 
/// This protocol abstracts the data source for market information,
/// enabling different implementations (Yahoo Finance, mock data, etc.).
/// 
/// - Validates: Requirements 5.1, 6.8 (Data fetching for strategy execution)
protocol MarketDataService {
    /// Fetches historical closing prices for a ticker.
    /// - Parameters:
    ///   - ticker: The stock ticker symbol
    ///   - lookbackDays: The number of days of history to fetch
    /// - Returns: Array of PricePoint objects sorted by date
    /// - Throws: MarketDataError if the fetch fails
    /// - Validates: Requirement 5.1 (Fetch historical prices for LOOKBACK_DAYS)
    func fetchHistoricalPrices(
        ticker: String,
        lookbackDays: Int
    ) async throws -> [PricePoint]
    
    /// Fetches the next earnings date for a ticker.
    /// - Parameter ticker: The stock ticker symbol
    /// - Returns: The next earnings date, or nil if unavailable
    /// - Throws: MarketDataError if the fetch fails
    /// - Validates: Requirement 6.8 (Fetch earnings date, display N/A if unavailable)
    func fetchEarningsDate(ticker: String) async throws -> Date?
}

// MARK: - Market Data Error

/// Errors that can occur during market data operations.
/// - Validates: Requirements 5.5, 5.6 (Data retrieval error handling)
enum MarketDataError: Error, Equatable {
    /// Failed to fetch data for a specific ticker.
    /// - Validates: Requirement 5.5 (Data retrieval failure per ticker)
    case fetchFailed(ticker: String, reason: String)
    
    /// Insufficient price data available for analysis.
    /// - Validates: Requirement 5.6 (Insufficient data handling)
    case insufficientData(ticker: String, required: Int, available: Int)
    
    /// Invalid ticker symbol.
    case invalidTicker(ticker: String)
    
    /// Network error during data fetch.
    case networkError(underlying: String)
    
    /// Rate limit exceeded.
    case rateLimitExceeded
    
    /// API returned invalid data format.
    case invalidDataFormat(ticker: String)
}

extension MarketDataError: LocalizedError {
    /// Detailed error description for logging.
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let ticker, let reason):
            return "\(ticker): Unable to fetch data - \(reason)"
        case .insufficientData(let ticker, let required, let available):
            return "\(ticker): Insufficient price history (\(available) days available, \(required) required)"
        case .invalidTicker(let ticker):
            return "\(ticker): Invalid ticker symbol"
        case .networkError:
            return "Unable to retrieve data for any symbols. Please try again later."
        case .rateLimitExceeded:
            return "Too many requests. Please try again in a few minutes."
        case .invalidDataFormat(let ticker):
            return "\(ticker): Invalid data format received"
        }
    }
    
    /// The ticker associated with this error, if applicable.
    var ticker: String? {
        switch self {
        case .fetchFailed(let ticker, _),
             .insufficientData(let ticker, _, _),
             .invalidTicker(let ticker),
             .invalidDataFormat(let ticker):
            return ticker
        case .networkError, .rateLimitExceeded:
            return nil
        }
    }
    
    /// User-friendly error message from the error catalog.
    /// - Validates: Requirements 5.5, 5.6
    var catalogMessage: String {
        switch self {
        case .fetchFailed(let ticker, _):
            return ErrorMessageCatalog.AnalysisExecution.dataFetchFailed(ticker)
        case .insufficientData(let ticker, _, _):
            return ErrorMessageCatalog.AnalysisExecution.insufficientData(ticker)
        case .invalidTicker(let ticker):
            return ErrorMessageCatalog.AnalysisExecution.dataFetchFailed(ticker)
        case .networkError:
            return ErrorMessageCatalog.AnalysisExecution.allTickersFailed
        case .rateLimitExceeded:
            return "Too many requests. Please try again in a few minutes."
        case .invalidDataFormat(let ticker):
            return ErrorMessageCatalog.AnalysisExecution.dataFetchFailed(ticker)
        }
    }
}

// MARK: - Analysis Progress

/// Represents the progress of a batch analysis operation.
struct AnalysisProgress {
    /// The total number of tickers to analyze
    let total: Int
    
    /// The number of tickers completed so far
    let completed: Int
    
    /// The current ticker being processed
    let currentTicker: String?
    
    /// Any errors encountered so far
    let errors: [MarketDataError]
    
    /// Progress as a percentage (0.0 to 1.0)
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    /// Progress description for display
    /// - Validates: Requirement 5.7 (Show progress n/total)
    var description: String {
        return "\(completed)/\(total)"
    }
    
    /// Creates a new AnalysisProgress instance.
    init(
        total: Int,
        completed: Int = 0,
        currentTicker: String? = nil,
        errors: [MarketDataError] = []
    ) {
        self.total = total
        self.completed = completed
        self.currentTicker = currentTicker
        self.errors = errors
    }
}

// MARK: - Batch Market Data Service Extension

/// Extended protocol for batch operations on market data.
protocol BatchMarketDataService: MarketDataService {
    /// Fetches data for multiple tickers with progress reporting.
    /// - Parameters:
    ///   - tickers: Array of ticker symbols to fetch
    ///   - lookbackDays: The number of days of history to fetch
    ///   - progressHandler: Closure called with progress updates
    /// - Returns: Dictionary mapping tickers to their price data
    /// - Note: Continues fetching even if individual tickers fail
    func fetchBatchHistoricalPrices(
        tickers: [String],
        lookbackDays: Int,
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async -> [String: Result<[PricePoint], MarketDataError>]
}

// MARK: - Options Data Service Protocol

/// Protocol extension for options chain data fetching.
///
/// This protocol extends `MarketDataService` to add options chain fetching
/// capabilities, enabling services to retrieve real-time options data
/// including calls and puts at all available strike prices.
///
/// - Validates: Requirement 1.1 (Fetch options chain for ticker and expiration)
/// - Validates: Requirement 1.2 (Retrieve calls and puts at all strikes)
/// - Validates: Requirement 1.3 (Include strike price, bid, and ask for each contract)
protocol OptionsDataService: MarketDataService {
    
    /// Fetches the options chain for a ticker and expiration date.
    ///
    /// Retrieves all available option contracts (calls and puts) for the
    /// specified ticker symbol at the given expiration date. Each contract
    /// includes strike price, bid price, and ask price data.
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol (e.g., "AAPL", "MSFT")
    ///   - expirationDate: The target expiration date for the options chain
    /// - Returns: An `OptionsChain` containing all calls and puts for the expiration
    /// - Throws: `OptionsDataError` if the fetch fails or data is unavailable
    ///
    /// - Validates: Requirement 1.1 (Fetch options chain for ticker and expiration)
    /// - Validates: Requirement 1.2 (Retrieve calls and puts at all strikes)
    /// - Validates: Requirement 1.3 (Include strike, bid, ask for each contract)
    func fetchOptionsChain(
        ticker: String,
        expirationDate: Date
    ) async throws -> OptionsChain
}
