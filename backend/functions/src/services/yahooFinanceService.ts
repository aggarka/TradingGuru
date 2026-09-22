/**
 * Yahoo Finance Service
 *
 * Fetches historical price data and earnings dates from Yahoo Finance API.
 * Used by scheduled analysis to retrieve market data for strategy execution.
 *
 * Requirements:
 * - 5.1: Fetch historical price data from Yahoo Finance for LOOKBACK_DAYS
 * - 6.8: Fetch earnings date, display N/A if unavailable
 */

import * as functions from "firebase-functions";
import { PricePoint } from "../types";

/**
 * Base URLs for Yahoo Finance APIs
 */
const CHART_BASE_URL = "https://query1.finance.yahoo.com/v8/finance/chart/";
const QUOTE_SUMMARY_BASE_URL = "https://query1.finance.yahoo.com/v10/finance/quoteSummary/";

/**
 * Yahoo Finance chart API response structure
 */
interface YahooChartResponse {
  chart: {
    result?: Array<{
      meta?: {
        currency?: string;
        symbol?: string;
        regularMarketPrice?: number;
      };
      timestamp?: number[];
      indicators: {
        quote: Array<{
          close?: (number | null)[];
          open?: (number | null)[];
          high?: (number | null)[];
          low?: (number | null)[];
          volume?: (number | null)[];
        }>;
      };
    }>;
    error?: {
      code?: string;
      description?: string;
    };
  };
}

/**
 * Yahoo Finance quote summary API response structure
 */
interface YahooQuoteSummaryResponse {
  quoteSummary: {
    result?: Array<{
      calendarEvents?: {
        earnings?: {
          earningsDate?: Array<{
            raw?: number;
            fmt?: string;
          }>;
        };
      };
    }>;
    error?: {
      code?: string;
      description?: string;
    };
  };
}

/**
 * Error types for Yahoo Finance operations
 */
export class YahooFinanceError extends Error {
  constructor(
    public ticker: string,
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "YahooFinanceError";
  }
}

/**
 * Validate ticker symbol format (1-5 uppercase letters)
 *
 * @param ticker - The ticker symbol to validate
 * @returns true if valid, false otherwise
 */
function isValidTicker(ticker: string): boolean {
  const pattern = /^[A-Z]{1,5}$/;
  return pattern.test(ticker);
}

/**
 * Fetch historical closing prices for a ticker from Yahoo Finance.
 *
 * Retrieves daily closing prices for the specified lookback period.
 * Prices are returned sorted by date in ascending order (oldest first).
 *
 * Requirements: 5.1 - Fetch historical prices for LOOKBACK_DAYS period
 *
 * @param ticker - The stock ticker symbol (e.g., "AAPL", "GOOGL")
 * @param lookbackDays - The number of days of history to fetch
 * @returns Array of PricePoint objects sorted by date (oldest first)
 * @throws YahooFinanceError if the fetch fails
 */
export async function fetchHistoricalPrices(
  ticker: string,
  lookbackDays: number,
): Promise<PricePoint[]> {
  // Validate ticker
  if (!isValidTicker(ticker)) {
    throw new YahooFinanceError(ticker, "INVALID_TICKER", `Invalid ticker symbol: ${ticker}`);
  }

  // Calculate period timestamps
  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - lookbackDays);

  const period1 = Math.floor(startDate.getTime() / 1000);
  const period2 = Math.floor(endDate.getTime() / 1000);

  // Build URL with query parameters
  const url = `${CHART_BASE_URL}${ticker}?period1=${period1}&period2=${period2}&interval=1d&includeAdjustedClose=true`;

  functions.logger.debug(`Fetching prices for ${ticker}`, { url, lookbackDays });

  try {
    const response = await fetch(url);

    // Check for rate limiting
    if (response.status === 429) {
      throw new YahooFinanceError(ticker, "RATE_LIMIT", "Rate limit exceeded");
    }

    // Check for HTTP errors
    if (!response.ok) {
      throw new YahooFinanceError(
        ticker,
        "HTTP_ERROR",
        `HTTP error ${response.status}: ${response.statusText}`,
      );
    }

    const data: YahooChartResponse = await response.json();

    // Check for API errors in response
    if (data.chart.error) {
      throw new YahooFinanceError(
        ticker,
        data.chart.error.code || "API_ERROR",
        data.chart.error.description || "Unknown API error",
      );
    }

    // Validate response structure
    const result = data.chart.result?.[0];
    if (!result) {
      throw new YahooFinanceError(ticker, "INVALID_RESPONSE", "No data in response");
    }

    const timestamps = result.timestamp;
    const closePrices = result.indicators?.quote?.[0]?.close;

    if (!timestamps || !closePrices) {
      throw new YahooFinanceError(ticker, "INVALID_DATA", "Missing price data in response");
    }

    // Build PricePoint array
    const pricePoints: PricePoint[] = [];

    for (let i = 0; i < timestamps.length; i++) {
      const closePrice = closePrices[i];
      if (closePrice !== null && closePrice !== undefined) {
        pricePoints.push({
          date: new Date(timestamps[i] * 1000),
          close: closePrice,
        });
      }
    }

    // Sort by date ascending (oldest first)
    pricePoints.sort((a, b) => a.date.getTime() - b.date.getTime());

    // Check for empty result
    if (pricePoints.length === 0) {
      throw new YahooFinanceError(
        ticker,
        "INSUFFICIENT_DATA",
        `No price data available for ${ticker}`,
      );
    }

    functions.logger.debug(`Fetched ${pricePoints.length} price points for ${ticker}`);
    return pricePoints;
  } catch (error) {
    if (error instanceof YahooFinanceError) {
      throw error;
    }
    throw new YahooFinanceError(
      ticker,
      "FETCH_FAILED",
      error instanceof Error ? error.message : "Unknown error",
    );
  }
}

/**
 * Fetch the next earnings date for a ticker from Yahoo Finance.
 *
 * Returns undefined if no earnings date is available.
 *
 * Requirements: 6.8 - Fetch earnings date, display N/A if unavailable
 *
 * @param ticker - The stock ticker symbol
 * @returns The next earnings date, or undefined if unavailable
 */
export async function fetchEarningsDate(ticker: string): Promise<Date | undefined> {
  // Validate ticker
  if (!isValidTicker(ticker)) {
    return undefined;
  }

  const url = `${QUOTE_SUMMARY_BASE_URL}${ticker}?modules=calendarEvents`;

  functions.logger.debug(`Fetching earnings date for ${ticker}`, { url });

  try {
    const response = await fetch(url);

    // Don't throw on HTTP errors for earnings - just return undefined
    if (!response.ok) {
      functions.logger.debug(`Earnings fetch failed for ${ticker}: ${response.status}`);
      return undefined;
    }

    const data: YahooQuoteSummaryResponse = await response.json();

    // Navigate to earnings date
    const earningsDate = data.quoteSummary.result?.[0]?.calendarEvents?.earnings?.earningsDate?.[0];

    if (!earningsDate?.raw) {
      return undefined;
    }

    return new Date(earningsDate.raw * 1000);
  } catch (error) {
    // Don't throw errors for earnings - it's supplementary data
    functions.logger.debug(`Error fetching earnings for ${ticker}`, { error });
    return undefined;
  }
}

/**
 * Get current price from the most recent price point
 *
 * @param pricePoints - Array of price points (assumed sorted oldest first)
 * @returns The most recent closing price, or undefined if empty
 */
export function getCurrentPrice(pricePoints: PricePoint[]): number | undefined {
  if (pricePoints.length === 0) {
    return undefined;
  }
  return pricePoints[pricePoints.length - 1].close;
}
