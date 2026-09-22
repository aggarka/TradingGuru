//
//  YahooFinanceService.swift
//  TradingGuru
//
//  Implementation of MarketDataService using Yahoo Finance API.
//  Fetches historical prices and earnings dates for stock tickers.
//

import Foundation

/// Service for fetching market data from Yahoo Finance API.
///
/// Implements the `MarketDataService` protocol to provide historical price data
/// and earnings date information for stock tickers.
///
/// - Validates: Requirement 5.1 (Fetch historical price data from Yahoo Finance)
/// - Validates: Requirement 6.8 (Fetch and display next earnings date, N/A if unavailable)
final class YahooFinanceService: MarketDataService, @unchecked Sendable {
    
    // MARK: - Constants
    
    /// Base URL for Yahoo Finance chart API
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
    
    /// Base URL for Yahoo Finance quoteSummary API (for earnings data)
    private let quoteSummaryBaseURL = "https://query1.finance.yahoo.com/v10/finance/quoteSummary/"
    
    /// URLSession for making network requests
    private let session: URLSession
    
    /// Cached crumb token for authenticated requests
    private var cachedCrumb: String?
    
    /// Cached cookies for authenticated requests
    private var cachedCookies: [HTTPCookie]?
    
    /// Lock for thread-safe crumb access
    private let crumbLock = NSLock()
    
    // MARK: - Initialization
    
    /// Creates a new YahooFinanceService instance.
    /// - Parameter session: URLSession to use for network requests (defaults to custom configured session)
    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            // Configure session with proper headers for Yahoo Finance API
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "application/json,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9"
            ]
            configuration.httpCookieAcceptPolicy = .always
            configuration.httpShouldSetCookies = true
            self.session = URLSession(configuration: configuration)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Fetches authentication crumb and cookies from Yahoo Finance.
    ///
    /// Yahoo Finance API requires a crumb token for authenticated endpoints like options.
    /// This method fetches the required cookies and crumb by:
    /// 1. Making a request to fc.yahoo.com to set cookies (gets A3 consent cookie)
    /// 2. Using those cookies to fetch the crumb token from query2.finance.yahoo.com
    ///
    /// - Returns: The crumb token string
    /// - Throws: Error if authentication fails
    private func fetchCrumbAndCookies() async throws -> String {
        // Check if we have a cached crumb
        crumbLock.lock()
        if let crumb = cachedCrumb, cachedCookies != nil && !cachedCookies!.isEmpty {
            let cookies = cachedCookies!
            crumbLock.unlock()
            print("[YahooFinance] Using cached crumb: \(crumb) with \(cookies.count) cookies")
            return crumb
        }
        crumbLock.unlock()
        
        print("[YahooFinance] ====== FETCHING NEW CRUMB AND COOKIES ======")
        
        // Step 1: Visit fc.yahoo.com to get the A3 cookie (consent cookie)
        guard let fcURL = URL(string: "https://fc.yahoo.com") else {
            throw OptionsDataError.networkError(underlying: "Invalid consent URL")
        }
        
        var fcRequest = URLRequest(url: fcURL)
        fcRequest.httpMethod = "GET"
        fcRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        fcRequest.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        fcRequest.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        print("[YahooFinance] Step 1: Fetching cookies from fc.yahoo.com...")
        let (_, fcResponse) = try await session.data(for: fcRequest)
        
        guard let httpResponse = fcResponse as? HTTPURLResponse else {
            throw OptionsDataError.networkError(underlying: "Failed to get consent response")
        }
        
        print("[YahooFinance] fc.yahoo.com response status: \(httpResponse.statusCode)")
        
        // Collect all cookies from various sources
        var cookies: [HTTPCookie] = []
        
        // Method 1: Get cookies from shared storage for yahoo.com domain
        if let yahooURL = URL(string: "https://yahoo.com") {
            let storedCookies = HTTPCookieStorage.shared.cookies(for: yahooURL) ?? []
            print("[YahooFinance] Cookies from storage (yahoo.com): \(storedCookies.count)")
            cookies.append(contentsOf: storedCookies)
        }
        
        // Method 2: Get cookies from shared storage for finance.yahoo.com
        if let financeURL = URL(string: "https://finance.yahoo.com") {
            let financeCookies = HTTPCookieStorage.shared.cookies(for: financeURL) ?? []
            print("[YahooFinance] Cookies from storage (finance.yahoo.com): \(financeCookies.count)")
            cookies.append(contentsOf: financeCookies)
        }
        
        // Method 3: Parse Set-Cookie headers manually
        if let allHeaders = httpResponse.allHeaderFields as? [String: String],
           let responseURL = httpResponse.url {
            let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: responseURL)
            print("[YahooFinance] Cookies from response headers: \(responseCookies.count)")
            for cookie in responseCookies {
                HTTPCookieStorage.shared.setCookie(cookie)
                cookies.append(cookie)
            }
        }
        
        // Remove duplicates by name
        var cookieDict: [String: HTTPCookie] = [:]
        for cookie in cookies {
            cookieDict[cookie.name] = cookie
        }
        cookies = Array(cookieDict.values)
        
        print("[YahooFinance] Total unique cookies: \(cookies.count)")
        for cookie in cookies {
            print("[YahooFinance]   - \(cookie.name): domain=\(cookie.domain), value=\(String(cookie.value.prefix(30)))...")
        }
        
        // Check for A3 cookie specifically
        let hasA3Cookie = cookies.contains { $0.name == "A3" }
        print("[YahooFinance] Has A3 cookie: \(hasA3Cookie)")
        
        // Store cookies
        crumbLock.lock()
        cachedCookies = cookies
        crumbLock.unlock()
        
        // Step 2: Fetch the crumb using query2 endpoint
        print("[YahooFinance] Step 2: Fetching crumb from query2.finance.yahoo.com...")
        
        guard let crumbURL = URL(string: "https://query2.finance.yahoo.com/v1/test/getcrumb") else {
            throw OptionsDataError.networkError(underlying: "Invalid crumb URL")
        }
        
        var crumbRequest = URLRequest(url: crumbURL)
        crumbRequest.httpMethod = "GET"
        crumbRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        crumbRequest.setValue("*/*", forHTTPHeaderField: "Accept")
        crumbRequest.setValue("https://finance.yahoo.com/", forHTTPHeaderField: "Referer")
        crumbRequest.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Origin")
        crumbRequest.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        // Build cookie header manually
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        if !cookieHeader.isEmpty {
            crumbRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            print("[YahooFinance] Sending Cookie header: \(String(cookieHeader.prefix(80)))...")
        } else {
            print("[YahooFinance] WARNING: No cookies to send!")
        }
        
        let (crumbData, crumbResponse) = try await session.data(for: crumbRequest)
        
        guard let crumbHttpResponse = crumbResponse as? HTTPURLResponse else {
            throw OptionsDataError.networkError(underlying: "Invalid crumb response")
        }
        
        print("[YahooFinance] Crumb response status: \(crumbHttpResponse.statusCode)")
        
        let responseBody = String(data: crumbData, encoding: .utf8) ?? "N/A"
        print("[YahooFinance] Crumb response body: \(responseBody)")
        
        // Check for successful response
        guard (200...299).contains(crumbHttpResponse.statusCode) else {
            throw OptionsDataError.networkError(underlying: "Failed to fetch crumb - status \(crumbHttpResponse.statusCode): \(responseBody)")
        }
        
        // Check if response is an error JSON instead of a crumb
        if responseBody.contains("Unauthorized") || responseBody.contains("Invalid") || responseBody.contains("error") {
            print("[YahooFinance] ERROR: Crumb response contains error")
            throw OptionsDataError.networkError(underlying: "Invalid crumb response: \(responseBody)")
        }
        
        let crumb = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !crumb.isEmpty else {
            throw OptionsDataError.networkError(underlying: "Empty crumb response")
        }
        
        // Cache the crumb
        crumbLock.lock()
        cachedCrumb = crumb
        crumbLock.unlock()
        
        print("[YahooFinance] ====== SUCCESS: Got crumb: \(crumb) ======")
        return crumb
    }
    
    /// Clears the cached crumb to force re-authentication.
    private func clearCrumbCache() {
        crumbLock.lock()
        cachedCrumb = nil
        cachedCookies = nil
        crumbLock.unlock()
        print("[YahooFinance] Cleared crumb cache")
    }
    
    // MARK: - MarketDataService Implementation
    
    /// Fetches historical closing prices for a ticker.
    ///
    /// Retrieves daily closing prices from Yahoo Finance for the specified lookback period.
    /// The prices are returned sorted by date in ascending order.
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol (e.g., "AAPL", "GOOGL")
    ///   - lookbackDays: The number of days of history to fetch
    /// - Returns: Array of PricePoint objects sorted by date (oldest first)
    /// - Throws: MarketDataError if the fetch fails
    /// - Validates: Requirement 5.1 (Fetch historical prices for LOOKBACK_DAYS)
    func fetchHistoricalPrices(
        ticker: String,
        lookbackDays: Int
    ) async throws -> [PricePoint] {
        // Validate ticker
        guard isValidTicker(ticker) else {
            throw MarketDataError.invalidTicker(ticker: ticker)
        }
        
        // Build the URL for the chart API
        guard let url = buildChartURL(ticker: ticker, lookbackDays: lookbackDays) else {
            throw MarketDataError.fetchFailed(ticker: ticker, reason: "Invalid URL configuration")
        }
        
        do {
            // Make the request
            let (data, response) = try await session.data(from: url)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MarketDataError.fetchFailed(ticker: ticker, reason: "Invalid response type")
            }
            
            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                throw MarketDataError.rateLimitExceeded
            }
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw MarketDataError.fetchFailed(
                    ticker: ticker,
                    reason: "HTTP error \(httpResponse.statusCode)"
                )
            }
            
            // Parse the response
            let pricePoints = try parseChartResponse(data: data, ticker: ticker)
            
            // Check for insufficient data
            if pricePoints.isEmpty {
                throw MarketDataError.insufficientData(ticker: ticker, required: lookbackDays, available: 0)
            }
            
            return pricePoints
            
        } catch let error as MarketDataError {
            throw error
        } catch let error as URLError {
            throw MarketDataError.networkError(underlying: error.localizedDescription)
        } catch {
            throw MarketDataError.fetchFailed(ticker: ticker, reason: error.localizedDescription)
        }
    }
    
    /// Fetches the next earnings date for a ticker.
    ///
    /// Retrieves the upcoming earnings announcement date from Yahoo Finance.
    /// Returns nil if no earnings date is available.
    ///
    /// - Parameter ticker: The stock ticker symbol
    /// - Returns: The next earnings date, or nil if unavailable
    /// - Throws: MarketDataError if the fetch fails
    /// - Validates: Requirement 6.8 (Fetch earnings date, display N/A if unavailable)
    func fetchEarningsDate(ticker: String) async throws -> Date? {
        // Validate ticker
        guard isValidTicker(ticker) else {
            throw MarketDataError.invalidTicker(ticker: ticker)
        }
        
        do {
            // Fetch crumb and cookies for authenticated request
            let crumb = try await fetchCrumbAndCookies()
            
            // Build the URL for earnings data with crumb
            guard let url = buildEarningsURL(ticker: ticker, crumb: crumb) else {
                throw MarketDataError.fetchFailed(ticker: ticker, reason: "Invalid URL configuration")
            }
            
            // Create request with cookies
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Add cookies to request
            crumbLock.lock()
            if let cookies = cachedCookies {
                let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            crumbLock.unlock()
            
            // Make the request
            let (data, response) = try await session.data(for: request)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MarketDataError.fetchFailed(ticker: ticker, reason: "Invalid response type")
            }
            
            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                throw MarketDataError.rateLimitExceeded
            }
            
            // Check for unauthorized - clear cache and retry once
            if httpResponse.statusCode == 401 {
                print("[YahooFinance] Unauthorized for earnings - clearing cache and retrying")
                crumbLock.lock()
                cachedCrumb = nil
                cachedCookies = nil
                crumbLock.unlock()
                
                // One retry with fresh crumb
                let freshCrumb = try await fetchCrumbAndCookies()
                guard let retryUrl = buildEarningsURL(ticker: ticker, crumb: freshCrumb) else {
                    return nil
                }
                
                var retryRequest = URLRequest(url: retryUrl)
                retryRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
                retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                
                crumbLock.lock()
                if let cookies = cachedCookies {
                    let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    retryRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                }
                crumbLock.unlock()
                
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHttpResponse.statusCode) else {
                    return nil
                }
                
                return try parseEarningsResponse(data: retryData, ticker: ticker)
            }
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                // For earnings, return nil instead of failing completely
                // This is per Requirement 6.8 - display N/A if unavailable
                print("[YahooFinance] Earnings fetch failed with status \(httpResponse.statusCode)")
                return nil
            }
            
            // Parse the response - returns nil if not found
            return try parseEarningsResponse(data: data, ticker: ticker)
            
        } catch let error as MarketDataError {
            // Re-throw specific errors but don't fail on missing earnings
            if case .invalidTicker = error {
                throw error
            }
            // For other errors, return nil to show N/A per Requirement 6.8
            print("[YahooFinance] Earnings fetch error: \(error)")
            return nil
        } catch {
            // For network/parse errors on earnings, return nil
            // The primary data fetch should succeed; earnings is supplementary
            print("[YahooFinance] Earnings fetch exception: \(error)")
            return nil
        }
    }
    
    // MARK: - URL Building
    
    /// Builds the URL for fetching chart data from Yahoo Finance.
    /// - Parameters:
    ///   - ticker: The stock ticker symbol
    ///   - lookbackDays: Number of days of history to fetch
    /// - Returns: The constructed URL, or nil if invalid
    private func buildChartURL(ticker: String, lookbackDays: Int) -> URL? {
        // Calculate the period timestamps
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: endDate)!
        
        let period1 = Int(startDate.timeIntervalSince1970)
        let period2 = Int(endDate.timeIntervalSince1970)
        
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)\(ticker)")
        components?.queryItems = [
            URLQueryItem(name: "period1", value: String(period1)),
            URLQueryItem(name: "period2", value: String(period2)),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includeAdjustedClose", value: "true")
        ]
        
        return components?.url
    }
    
    /// Builds the URL for fetching earnings data from Yahoo Finance.
    /// - Parameters:
    ///   - ticker: The stock ticker symbol
    ///   - crumb: The authentication crumb token
    /// - Returns: The constructed URL, or nil if invalid
    private func buildEarningsURL(ticker: String, crumb: String) -> URL? {
        var components = URLComponents(string: "\(quoteSummaryBaseURL)\(ticker)")
        components?.queryItems = [
            URLQueryItem(name: "modules", value: "calendarEvents"),
            URLQueryItem(name: "crumb", value: crumb)
        ]
        
        return components?.url
    }
    
    // MARK: - Response Parsing
    
    /// Parses the Yahoo Finance chart API response.
    /// - Parameters:
    ///   - data: The raw response data
    ///   - ticker: The ticker symbol (for error messages)
    /// - Returns: Array of PricePoint objects sorted by date
    /// - Throws: MarketDataError if parsing fails
    private func parseChartResponse(data: Data, ticker: String) throws -> [PricePoint] {
        do {
            // Decode JSON response
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            
            // Validate response structure
            guard let result = response.chart.result?.first else {
                throw MarketDataError.invalidDataFormat(ticker: ticker)
            }
            
            // Check for error in response
            if let error = response.chart.error {
                throw MarketDataError.fetchFailed(ticker: ticker, reason: error.description ?? "Unknown error")
            }
            
            // Extract timestamps and closing prices
            guard let timestamps = result.timestamp,
                  let closePrices = result.indicators.quote.first?.close else {
                throw MarketDataError.invalidDataFormat(ticker: ticker)
            }
            
            // Build PricePoint array
            var pricePoints: [PricePoint] = []
            
            for (index, timestamp) in timestamps.enumerated() {
                // Skip if we don't have a corresponding close price or if it's nil
                guard index < closePrices.count,
                      let closePrice = closePrices[index] else {
                    continue
                }
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                pricePoints.append(PricePoint(date: date, close: closePrice))
            }
            
            // Sort by date ascending (oldest first)
            pricePoints.sort { $0.date < $1.date }
            
            return pricePoints
            
        } catch let error as MarketDataError {
            throw error
        } catch {
            throw MarketDataError.invalidDataFormat(ticker: ticker)
        }
    }
    
    /// Parses the Yahoo Finance earnings API response.
    /// - Parameters:
    ///   - data: The raw response data
    ///   - ticker: The ticker symbol (for error messages)
    /// - Returns: The next earnings date (future date only), or nil if not found
    /// - Throws: MarketDataError if parsing fails with critical error
    private func parseEarningsResponse(data: Data, ticker: String) throws -> Date? {
        do {
            // Decode JSON response
            let response = try JSONDecoder().decode(YahooQuoteSummaryResponse.self, from: data)
            
            // Navigate to earnings dates array
            guard let result = response.quoteSummary.result?.first,
                  let calendarEvents = result.calendarEvents,
                  let earnings = calendarEvents.earnings,
                  let earningsDates = earnings.earningsDate, !earningsDates.isEmpty else {
                // No earnings date found - this is expected for some tickers
                return nil
            }
            
            // Get current date for comparison (start of today to include today's earnings)
            let now = Calendar.current.startOfDay(for: Date())
            
            // Convert all earnings dates and filter for future dates
            let futureDates: [Date] = earningsDates.compactMap { earningsDate in
                guard let timestamp = earningsDate.raw else { return nil }
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                // Only include dates that are today or in the future
                return date >= now ? date : nil
            }
            
            // Return the earliest future date (next upcoming earnings)
            let nextEarnings = futureDates.min()
            
            if let nextDate = nextEarnings {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                print("[YahooFinance] \(ticker) next earnings: \(formatter.string(from: nextDate))")
            } else {
                print("[YahooFinance] \(ticker) no future earnings date found")
            }
            
            return nextEarnings
            
        } catch {
            // Parse errors on earnings should return nil, not throw
            // This is supplementary data per Requirement 6.8
            return nil
        }
    }
    
    // MARK: - Validation
    
    /// Validates that a ticker symbol is properly formatted.
    /// - Parameter ticker: The ticker symbol to validate
    /// - Returns: true if valid (1-5 uppercase letters)
    private func isValidTicker(_ ticker: String) -> Bool {
        let pattern = "^[A-Z]{1,5}$"
        return ticker.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Yahoo Finance API Response Models

/// Root response for Yahoo Finance chart API.
private struct YahooChartResponse: Decodable {
    let chart: ChartData
}

/// Chart data container.
private struct ChartData: Decodable {
    let result: [ChartResult]?
    let error: ChartError?
}

/// Error response from Yahoo Finance.
private struct ChartError: Decodable {
    let code: String?
    let description: String?
}

/// Individual chart result.
private struct ChartResult: Decodable {
    let meta: ChartMeta?
    let timestamp: [Int]?
    let indicators: Indicators
}

/// Metadata for chart response.
private struct ChartMeta: Decodable {
    let currency: String?
    let symbol: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
}

/// Indicators container for quote data.
private struct Indicators: Decodable {
    let quote: [QuoteData]
}

/// Quote data containing price arrays.
private struct QuoteData: Decodable {
    let close: [Double?]?
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let volume: [Int?]?
}

// MARK: - Yahoo Finance Quote Summary Response Models

/// Root response for Yahoo Finance quoteSummary API.
private struct YahooQuoteSummaryResponse: Decodable {
    let quoteSummary: QuoteSummary
}

/// Quote summary container.
private struct QuoteSummary: Decodable {
    let result: [QuoteSummaryResult]?
    let error: QuoteSummaryError?
}

/// Error response from quoteSummary API.
private struct QuoteSummaryError: Decodable {
    let code: String?
    let description: String?
}

/// Individual quote summary result.
private struct QuoteSummaryResult: Decodable {
    let calendarEvents: CalendarEvents?
}

/// Calendar events containing earnings info.
private struct CalendarEvents: Decodable {
    let earnings: Earnings?
}

/// Earnings data.
private struct Earnings: Decodable {
    let earningsDate: [EarningsDateValue]?
}

/// Earnings date value with raw timestamp.
private struct EarningsDateValue: Decodable {
    let raw: Int?
    let fmt: String?
}

// MARK: - BatchMarketDataService Extension

extension YahooFinanceService: BatchMarketDataService {
    
    /// Fetches historical prices for multiple tickers with progress reporting.
    ///
    /// Continues fetching even if individual tickers fail, collecting errors for reporting.
    /// Progress is reported after each ticker is processed.
    ///
    /// - Parameters:
    ///   - tickers: Array of ticker symbols to fetch
    ///   - lookbackDays: Number of days of history to fetch for each ticker
    ///   - progressHandler: Closure called with progress updates after each ticker
    /// - Returns: Dictionary mapping tickers to their results (success or failure)
    /// - Validates: Requirement 5.5 (Continue processing on per-ticker failures)
    /// - Validates: Requirement 5.7 (Show progress n/total)
    func fetchBatchHistoricalPrices(
        tickers: [String],
        lookbackDays: Int,
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async -> [String: Result<[PricePoint], MarketDataError>] {
        var results: [String: Result<[PricePoint], MarketDataError>] = [:]
        var errors: [MarketDataError] = []
        let total = tickers.count
        
        for (index, ticker) in tickers.enumerated() {
            // Report progress at start of each ticker
            let progress = AnalysisProgress(
                total: total,
                completed: index,
                currentTicker: ticker,
                errors: errors
            )
            progressHandler(progress)
            
            // Fetch data for this ticker
            do {
                let pricePoints = try await fetchHistoricalPrices(ticker: ticker, lookbackDays: lookbackDays)
                results[ticker] = .success(pricePoints)
            } catch let error as MarketDataError {
                results[ticker] = .failure(error)
                errors.append(error)
            } catch {
                let marketError = MarketDataError.fetchFailed(ticker: ticker, reason: error.localizedDescription)
                results[ticker] = .failure(marketError)
                errors.append(marketError)
            }
        }
        
        // Report final progress
        let finalProgress = AnalysisProgress(
            total: total,
            completed: total,
            currentTicker: nil,
            errors: errors
        )
        progressHandler(finalProgress)
        
        return results
    }
}

// MARK: - OptionsDataService Extension

extension YahooFinanceService: OptionsDataService {
    
    // MARK: - Options API Constants
    
    /// Base URL for Yahoo Finance options API.
    ///
    /// This endpoint provides options chain data including calls and puts
    /// for a given ticker symbol and expiration date.
    /// Using query2 which tends to be more reliable than query1.
    ///
    /// - Validates: Requirement 1.1 (Fetch options chain from Yahoo Finance)
    private var optionsBaseURL: String {
        "https://query2.finance.yahoo.com/v7/finance/options/"
    }
    
    // MARK: - URL Building
    
    /// Builds the URL for fetching options chain data from Yahoo Finance.
    ///
    /// Constructs the API URL with the ticker symbol appended to the base URL
    /// and the expiration date as a Unix timestamp query parameter.
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol (e.g., "AAPL", "MSFT")
    ///   - expiration: The expiration date as a Unix timestamp (seconds since epoch)
    ///   - crumb: Optional crumb token for authentication
    /// - Returns: The constructed URL, or nil if URL construction fails
    ///
    /// - Validates: Requirement 1.1 (Fetch options chain for ticker and expiration)
    private func buildOptionsURL(ticker: String, expiration: Int, crumb: String? = nil) -> URL? {
        var components = URLComponents(string: "\(optionsBaseURL)\(ticker)")
        var queryItems = [
            URLQueryItem(name: "date", value: String(expiration))
        ]
        if let crumb = crumb {
            queryItems.append(URLQueryItem(name: "crumb", value: crumb))
        }
        components?.queryItems = queryItems
        return components?.url
    }
    
    // MARK: - OptionsDataService Protocol Implementation
    
    /// Fetches options chain data from Yahoo Finance.
    ///
    /// Retrieves the options chain for the specified ticker and expiration date,
    /// including all available call and put contracts with their bid/ask prices.
    /// Uses crumb authentication if the initial request fails.
    ///
    /// - Parameters:
    ///   - ticker: The stock ticker symbol (e.g., "AAPL", "MSFT")
    ///   - expirationDate: The target expiration date for the options chain
    /// - Returns: An OptionsChain containing calls and puts arrays
    /// - Throws: OptionsDataError if the fetch fails or data is unavailable
    ///
    /// - Validates: Requirement 1.1 (Fetch options chain for ticker and expiration)
    /// - Validates: Requirement 1.4 (Error handling for options data)
    func fetchOptionsChain(
        ticker: String,
        expirationDate: Date
    ) async throws -> OptionsChain {
        // Validate ticker
        guard isValidTicker(ticker) else {
            print("[YahooFinance] Invalid ticker: \(ticker)")
            throw OptionsDataError.optionsUnavailable(ticker: ticker)
        }
        
        // First, fetch available expiration dates from Yahoo Finance
        // Yahoo requires exact timestamp matching, so we need to find the closest available date
        let availableExpirations = try await fetchAvailableExpirationDates(ticker: ticker)
        
        // Find the best matching expiration date
        let targetTimestamp = Int(expirationDate.timeIntervalSince1970)
        let timestamp = findClosestExpiration(target: targetTimestamp, available: availableExpirations)
        
        print("[YahooFinance] Target expiration: \(targetTimestamp), using available: \(timestamp)")
        print("[YahooFinance] Fetching options for \(ticker) with expiration timestamp: \(timestamp)")
        
        // Helper function to make the options request
        func makeOptionsRequest(crumb: String, cookies: [HTTPCookie]) async throws -> (Data, URLResponse) {
            guard let url = buildOptionsURL(ticker: ticker, expiration: timestamp, crumb: crumb) else {
                throw OptionsDataError.optionsUnavailable(ticker: ticker)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("https://finance.yahoo.com/", forHTTPHeaderField: "Referer")
            request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Origin")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            
            // Add cookies
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            if !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            
            print("[YahooFinance] Options URL: \(url.absoluteString)")
            return try await session.data(for: request)
        }
        
        // Try to fetch with crumb authentication
        do {
            // Get crumb and cookies
            let crumb = try await fetchCrumbAndCookies()
            
            crumbLock.lock()
            let cookies = cachedCookies ?? []
            crumbLock.unlock()
            
            let (data, response) = try await makeOptionsRequest(crumb: crumb, cookies: cookies)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OptionsDataError.optionsUnavailable(ticker: ticker)
            }
            
            print("[YahooFinance] Options response status: \(httpResponse.statusCode) for \(ticker)")
            
            // Log response body for debugging if error
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: data, encoding: .utf8) ?? "N/A"
                print("[YahooFinance] Error response body: \(responseBody.prefix(200))")
            }
            
            // If unauthorized or bad response, clear cache and retry once
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                print("[YahooFinance] Auth failed, clearing cache and retrying...")
                clearCrumbCache()
                
                // Retry with fresh crumb
                let newCrumb = try await fetchCrumbAndCookies()
                
                crumbLock.lock()
                let newCookies = cachedCookies ?? []
                crumbLock.unlock()
                
                let (retryData, retryResponse) = try await makeOptionsRequest(crumb: newCrumb, cookies: newCookies)
                
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw OptionsDataError.optionsUnavailable(ticker: ticker)
                }
                
                print("[YahooFinance] Retry response status: \(retryHttpResponse.statusCode)")
                
                guard (200...299).contains(retryHttpResponse.statusCode) else {
                    let retryBody = String(data: retryData, encoding: .utf8) ?? "N/A"
                    print("[YahooFinance] Retry failed: \(retryBody.prefix(200))")
                    throw OptionsDataError.optionsUnavailable(ticker: ticker)
                }
                
                let chain = try parseOptionsResponse(data: retryData, ticker: ticker, expiration: Date(timeIntervalSince1970: TimeInterval(timestamp)))
                print("[YahooFinance] Parsed \(chain.calls.count) calls and \(chain.puts.count) puts for \(ticker)")
                return chain
            }
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw OptionsDataError.optionsUnavailable(ticker: ticker)
            }
            
            // Parse the options response
            let chain = try parseOptionsResponse(
                data: data,
                ticker: ticker,
                expiration: Date(timeIntervalSince1970: TimeInterval(timestamp))
            )
            
            print("[YahooFinance] Parsed \(chain.calls.count) calls and \(chain.puts.count) puts for \(ticker)")
            
            // Debug: Log first few options to verify data
            if let firstCall = chain.calls.first {
                print("[YahooFinance] Sample CALL: strike=$\(firstCall.strikePrice), bid=$\(firstCall.bid), ask=$\(firstCall.ask), mid=$\(firstCall.midPrice)")
            }
            if let firstPut = chain.puts.first {
                print("[YahooFinance] Sample PUT: strike=$\(firstPut.strikePrice), bid=$\(firstPut.bid), ask=$\(firstPut.ask), mid=$\(firstPut.midPrice)")
            }
            print("[YahooFinance] Expiration date: \(chain.expirationDate)")
            
            return chain
            
        } catch let error as OptionsDataError {
            print("[YahooFinance] Options error for \(ticker): \(error)")
            throw error
        } catch {
            print("[YahooFinance] Network error for \(ticker): \(error.localizedDescription)")
            throw OptionsDataError.networkError(underlying: error.localizedDescription)
        }
    }
    
    // MARK: - Options Response Parsing
    
    /// Fetches available expiration dates for a ticker from Yahoo Finance.
    ///
    /// Makes a request to the options API without a date parameter to get
    /// the list of all available expiration dates for the ticker.
    ///
    /// - Parameter ticker: The stock ticker symbol
    /// - Returns: Array of expiration dates as Unix timestamps
    /// - Throws: OptionsDataError if the fetch fails
    private func fetchAvailableExpirationDates(ticker: String) async throws -> [Int] {
        // Build URL without date parameter to get available expirations
        guard var components = URLComponents(string: "\(optionsBaseURL)\(ticker)") else {
            throw OptionsDataError.optionsUnavailable(ticker: ticker)
        }
        
        // Get crumb for authentication
        let crumb = try await fetchCrumbAndCookies()
        components.queryItems = [URLQueryItem(name: "crumb", value: crumb)]
        
        guard let url = components.url else {
            throw OptionsDataError.optionsUnavailable(ticker: ticker)
        }
        
        crumbLock.lock()
        let cookies = cachedCookies ?? []
        crumbLock.unlock()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://finance.yahoo.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Origin")
        
        // Add cookies
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        if !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        print("[YahooFinance] Fetching available expirations from: \(url.absoluteString)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("[YahooFinance] Failed to fetch available expirations")
            throw OptionsDataError.optionsUnavailable(ticker: ticker)
        }
        
        // Parse response to get expiration dates
        let optionsResponse = try JSONDecoder().decode(YahooOptionsResponse.self, from: data)
        
        guard let result = optionsResponse.optionChain.result?.first,
              let expirations = result.expirationDates,
              !expirations.isEmpty else {
            print("[YahooFinance] No expiration dates available for \(ticker)")
            throw OptionsDataError.optionsUnavailable(ticker: ticker)
        }
        
        print("[YahooFinance] Available expirations for \(ticker): \(expirations.prefix(5))... (total: \(expirations.count))")
        return expirations
    }
    
    /// Finds the closest available expiration date to the target date.
    ///
    /// If no expirations are available, returns the target unchanged.
    /// Prefers the first expiration that is >= target (same or later date).
    /// If all available expirations are earlier than target, uses the latest one.
    ///
    /// - Parameters:
    ///   - target: The desired expiration timestamp
    ///   - available: Array of available expiration timestamps from Yahoo Finance
    /// - Returns: The best matching expiration timestamp
    private func findClosestExpiration(target: Int, available: [Int]) -> Int {
        guard !available.isEmpty else {
            return target
        }
        
        // Sort expirations in ascending order
        let sorted = available.sorted()
        
        // Find the first expiration that is >= target
        if let firstValidExpiration = sorted.first(where: { $0 >= target }) {
            return firstValidExpiration
        }
        
        // All expirations are before target, use the latest available
        return sorted.last!
    }
    
    /// Parses the Yahoo Finance options API response into an OptionsChain.
    ///
    /// Extracts call and put option contracts from the response data,
    /// creating OptionContract objects for each with strike, bid, ask, and expiration.
    ///
    /// - Parameters:
    ///   - data: The raw response data from the API
    ///   - ticker: The stock ticker symbol (for error messages and contract creation)
    ///   - expiration: The expiration date for the options
    /// - Returns: An OptionsChain with parsed calls and puts
    /// - Throws: OptionsDataError if parsing fails
    ///
    /// - Validates: Requirement 1.2 (Retrieve calls and puts at all strikes)
    /// - Validates: Requirement 1.3 (Include strike price, bid price, ask price)
    /// - Validates: Requirement 1.5 (Return empty chain if no contracts)
    private func parseOptionsResponse(
        data: Data,
        ticker: String,
        expiration: Date
    ) throws -> OptionsChain {
        do {
            // Decode the JSON response
            let response = try JSONDecoder().decode(YahooOptionsResponse.self, from: data)
            
            // Navigate to the options data
            guard let result = response.optionChain.result?.first else {
                // No result - return empty chain per Requirement 1.5
                return OptionsChain.empty(ticker: ticker, expirationDate: expiration)
            }
            
            // Check for error in response
            if response.optionChain.error != nil {
                throw OptionsDataError.optionsUnavailable(ticker: ticker)
            }
            
            // Get the options array for the expiration date
            guard let optionsData = result.options?.first else {
                // No options for this expiration - return empty chain per Requirement 1.5
                return OptionsChain.empty(ticker: ticker, expirationDate: expiration)
            }
            
            // Parse call options
            let calls = parseOptionContracts(
                from: optionsData.calls ?? [],
                ticker: ticker,
                type: .call,
                expiration: expiration
            )
            
            // Parse put options
            let puts = parseOptionContracts(
                from: optionsData.puts ?? [],
                ticker: ticker,
                type: .put,
                expiration: expiration
            )
            
            return OptionsChain(
                ticker: ticker,
                expirationDate: expiration,
                calls: calls,
                puts: puts,
                fetchedAt: Date()
            )
            
        } catch let error as OptionsDataError {
            throw error
        } catch {
            throw OptionsDataError.invalidOptionsData(ticker: ticker)
        }
    }
    
    /// Parses an array of raw option data into OptionContract objects.
    ///
    /// - Parameters:
    ///   - rawOptions: Array of raw option data from the API
    ///   - ticker: The underlying stock ticker
    ///   - type: The option type (call or put)
    ///   - expiration: The expiration date for the contracts
    /// - Returns: Array of OptionContract objects
    ///
    /// - Validates: Requirement 1.3 (Include strike, bid, ask for each contract)
    private func parseOptionContracts(
        from rawOptions: [YahooOptionData],
        ticker: String,
        type: OpportunityType,
        expiration: Date
    ) -> [OptionContract] {
        return rawOptions.compactMap { option -> OptionContract? in
            // Require strike price - skip contracts without it
            guard let strike = option.strike else {
                return nil
            }
            
            // Use 0.0 for missing bid/ask (some contracts may have no market)
            let bid = option.bid ?? 0.0
            let ask = option.ask ?? 0.0
            
            return OptionContract(
                ticker: ticker,
                type: type,
                strikePrice: strike,
                bid: bid,
                ask: ask,
                expirationDate: expiration
            )
        }
    }
}

// MARK: - Yahoo Finance Options API Response Models

/// Root response for Yahoo Finance options API.
/// - Validates: Requirement 1.2 (Parse options chain structure)
private struct YahooOptionsResponse: Decodable {
    let optionChain: OptionChainContainer
}

/// Container for option chain data.
private struct OptionChainContainer: Decodable {
    let result: [OptionChainResult]?
    let error: OptionChainError?
}

/// Error response from Yahoo Finance options API.
private struct OptionChainError: Decodable {
    let code: String?
    let description: String?
}

/// Individual result containing the options data.
private struct OptionChainResult: Decodable {
    let underlyingSymbol: String?
    let expirationDates: [Int]?
    let strikes: [Double]?
    let options: [OptionsExpirationData]?
}

/// Options data for a specific expiration date.
private struct OptionsExpirationData: Decodable {
    let expirationDate: Int?
    let calls: [YahooOptionData]?
    let puts: [YahooOptionData]?
}

/// Individual option contract data from Yahoo Finance.
/// - Validates: Requirement 1.3 (Strike price, bid price, ask price)
private struct YahooOptionData: Decodable {
    let contractSymbol: String?
    let strike: Double?
    let currency: String?
    let lastPrice: Double?
    let change: Double?
    let percentChange: Double?
    let volume: Int?
    let openInterest: Int?
    let bid: Double?
    let ask: Double?
    let contractSize: String?
    let expiration: Int?
    let lastTradeDate: Int?
    let impliedVolatility: Double?
    let inTheMoney: Bool?
}

// MARK: - Stock Quote Service Extension

extension YahooFinanceService {
    
    /// Fetches real-time quote data for a single ticker.
    ///
    /// Uses the Yahoo Finance chart API to retrieve current price, change, and percent change.
    ///
    /// - Parameter ticker: The stock ticker symbol (e.g., "AAPL")
    /// - Returns: A StockQuote with current price data
    /// - Throws: MarketDataError if the fetch fails
    func fetchQuote(ticker: String) async throws -> StockQuote {
        // Validate ticker
        guard isValidTicker(ticker) else {
            throw MarketDataError.invalidTicker(ticker: ticker)
        }
        
        // Build URL for chart API with 1-day data to get current price info
        guard let url = buildQuoteURL(ticker: ticker) else {
            throw MarketDataError.fetchFailed(ticker: ticker, reason: "Invalid URL configuration")
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MarketDataError.fetchFailed(ticker: ticker, reason: "Invalid response type")
            }
            
            if httpResponse.statusCode == 429 {
                throw MarketDataError.rateLimitExceeded
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw MarketDataError.fetchFailed(
                    ticker: ticker,
                    reason: "HTTP error \(httpResponse.statusCode)"
                )
            }
            
            return try parseQuoteResponse(data: data, ticker: ticker)
            
        } catch let error as MarketDataError {
            throw error
        } catch let error as URLError {
            throw MarketDataError.networkError(underlying: error.localizedDescription)
        } catch {
            throw MarketDataError.fetchFailed(ticker: ticker, reason: error.localizedDescription)
        }
    }
    
    /// Fetches quotes for multiple tickers.
    ///
    /// - Parameter tickers: Array of ticker symbols to fetch
    /// - Returns: Dictionary mapping tickers to their quote results (success or failure)
    func fetchQuotes(tickers: [String]) async -> [String: Result<StockQuote, MarketDataError>] {
        var results: [String: Result<StockQuote, MarketDataError>] = [:]
        
        // Use TaskGroup for concurrent fetching with error handling per ticker
        await withTaskGroup(of: (String, Result<StockQuote, MarketDataError>).self) { group in
            for ticker in tickers {
                group.addTask {
                    do {
                        let quote = try await self.fetchQuote(ticker: ticker)
                        return (ticker, .success(quote))
                    } catch let error as MarketDataError {
                        return (ticker, .failure(error))
                    } catch {
                        return (ticker, .failure(.fetchFailed(ticker: ticker, reason: error.localizedDescription)))
                    }
                }
            }
            
            for await (ticker, result) in group {
                results[ticker] = result
            }
        }
        
        return results
    }
    
    /// Builds the URL for fetching quote data from Yahoo Finance.
    /// Uses the chart API with range=1d&interval=1d to get current market data.
    private func buildQuoteURL(ticker: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)\(ticker)")
        components?.queryItems = [
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "false")
        ]
        return components?.url
    }
    
    /// Parses the chart API response to extract quote data.
    private func parseQuoteResponse(data: Data, ticker: String) throws -> StockQuote {
        do {
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            
            guard let result = response.chart.result?.first,
                  let meta = result.meta else {
                throw MarketDataError.invalidDataFormat(ticker: ticker)
            }
            
            // Extract quote data from meta
            guard let regularMarketPrice = meta.regularMarketPrice else {
                throw MarketDataError.invalidDataFormat(ticker: ticker)
            }
            
            // Get previous close for calculating change
            let previousClose = meta.chartPreviousClose ?? meta.previousClose ?? regularMarketPrice
            
            let change = regularMarketPrice - previousClose
            let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
            
            return StockQuote(
                symbol: ticker,
                price: regularMarketPrice,
                change: change,
                changePercent: changePercent
            )
            
        } catch let error as MarketDataError {
            throw error
        } catch {
            throw MarketDataError.invalidDataFormat(ticker: ticker)
        }
    }
}

// MARK: - Extended Chart Meta for Quote Data

/// Extended metadata that includes previous close for change calculation.
private extension ChartMeta {
    // Note: ChartMeta already defined above, adding computed properties would require
    // modifying the original struct. Instead, we'll decode additional fields inline.
}

/// Extended chart meta with additional fields for quote calculation.
private struct ExtendedChartMeta: Decodable {
    let currency: String?
    let symbol: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
}
