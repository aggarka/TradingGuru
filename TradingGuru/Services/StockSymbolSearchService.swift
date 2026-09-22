//
//  StockSymbolSearchService.swift
//  TradingGuru
//
//  Service for searching stock symbols using Yahoo Finance autocomplete API.
//

import Foundation

// MARK: - Search Result Model

/// Represents a stock symbol search result from Yahoo Finance.
struct StockSearchResult: Identifiable, Equatable {
    let id = UUID()
    
    /// The ticker symbol (e.g., "AAPL")
    let symbol: String
    
    /// The company name (e.g., "Apple Inc.")
    let name: String
    
    /// The exchange where the stock is traded (e.g., "NASDAQ")
    let exchange: String
    
    /// The type of security (e.g., "EQUITY" for stock, "ETF" for ETF)
    let type: String
    
    /// Whether this is an equity (stock or ETF) - filters out indices, futures, etc.
    var isEquity: Bool {
        type == "EQUITY" || type == "ETF"
    }
}

// MARK: - Search Service Protocol

/// Protocol for stock symbol search functionality.
protocol StockSymbolSearching {
    /// Searches for stock symbols matching the query.
    /// - Parameter query: The search query (symbol or company name)
    /// - Returns: Array of matching search results
    func search(query: String) async throws -> [StockSearchResult]
}

// MARK: - Search Service Implementation

/// Service for searching stock symbols using Yahoo Finance autocomplete API.
final class StockSymbolSearchService: StockSymbolSearching {
    
    // MARK: - Constants
    
    /// Yahoo Finance autocomplete API URL
    private let searchURL = "https://query2.finance.yahoo.com/v1/finance/search"
    
    /// URLSession for making network requests
    private let session: URLSession
    
    /// Minimum characters required to trigger a search
    static let minimumQueryLength = 1
    
    /// Maximum number of results to return
    static let maxResults = 10
    
    // MARK: - Initialization
    
    /// Creates a new StockSymbolSearchService instance.
    /// - Parameter session: URLSession to use for network requests
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Search
    
    /// Searches for stock symbols matching the query.
    /// - Parameter query: The search query (symbol or company name)
    /// - Returns: Array of matching search results filtered to equities only
    func search(query: String) async throws -> [StockSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        
        guard trimmedQuery.count >= Self.minimumQueryLength else {
            return []
        }
        
        guard var components = URLComponents(string: searchURL) else {
            return []
        }
        
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmedQuery),
            URLQueryItem(name: "quotesCount", value: String(Self.maxResults)),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "listsCount", value: "0"),
            URLQueryItem(name: "enableFuzzyQuery", value: "false"),
            URLQueryItem(name: "quotesQueryId", value: "tss_match_phrase_query")
        ]
        
        guard let url = components.url else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        return parseSearchResponse(data: data)
    }
    
    // MARK: - Response Parsing
    
    /// Parses the Yahoo Finance search response.
    private func parseSearchResponse(data: Data) -> [StockSearchResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotes = json["quotes"] as? [[String: Any]] else {
            return []
        }
        
        return quotes.compactMap { quote -> StockSearchResult? in
            guard let symbol = quote["symbol"] as? String,
                  let name = quote["shortname"] as? String ?? quote["longname"] as? String else {
                return nil
            }
            
            let exchange = quote["exchange"] as? String ?? ""
            let quoteType = quote["quoteType"] as? String ?? "S"
            
            let result = StockSearchResult(
                symbol: symbol,
                name: name,
                exchange: exchange,
                type: quoteType
            )
            
            // Only include equities (stocks and ETFs)
            guard result.isEquity else {
                return nil
            }
            
            return result
        }
    }
}
