/**
 * Strategy Execution Service
 *
 * Implements the Weekly Option Strategy analysis logic.
 * Calculates rolling window returns and identifies CALL/PUT opportunities.
 *
 * Requirements:
 * - 5.2: Calculate rolling window returns
 * - 5.3: Identify best (CALL) and worst (PUT) return windows
 * - 5.4: Calculate target prices using formula
 * - 6.2: CALL has positive return, PUT has negative return
 * - 6.4: Calculate earnings risk indicator
 */

import * as functions from "firebase-functions";
import {
  PricePoint,
  WeeklyOptionConfiguration,
  AnalysisResult,
  OpportunityType,
  Signal,
} from "../types";
import {
  fetchHistoricalPrices,
  fetchEarningsDate,
  getCurrentPrice,
} from "./yahooFinanceService";

/**
 * Rolling window return calculation result
 */
interface RollingWindowReturn {
  startDate: Date;
  endDate: Date;
  returnPct: number;
}

/**
 * Generate a unique ID for analysis results
 */
function generateResultId(): string {
  return `${Date.now()}-${Math.random().toString(36).substring(2, 11)}`;
}

/**
 * Calculate rolling window returns from price data.
 *
 * For each window starting at index i:
 * return = ((prices[i + windowDays].close - prices[i].close) / prices[i].close) * 100
 *
 * Requirements: 5.2 - Rolling window return calculation formula
 *
 * @param prices - Array of price points sorted by date (oldest first)
 * @param windowDays - The number of trading days for each rolling window
 * @returns Array of rolling window returns
 * @throws Error if insufficient data
 */
export function calculateRollingReturns(
  prices: PricePoint[],
  windowDays: number,
): RollingWindowReturn[] {
  // Validate inputs
  if (windowDays <= 0) {
    throw new Error(`Invalid window days value: ${windowDays}. Must be positive.`);
  }

  if (prices.length === 0) {
    throw new Error("No price data available.");
  }

  // Need at least windowDays + 1 data points to calculate one return
  if (prices.length <= windowDays) {
    throw new Error(
      `Insufficient price history. Available: ${prices.length} days, Required: ${windowDays + 1} days.`,
    );
  }

  const returns: RollingWindowReturn[] = [];

  // Calculate rolling returns for each valid window
  // For window starting at index i, we need prices[i] and prices[i + windowDays]
  for (let i = 0; i < prices.length - windowDays; i++) {
    const startPrice = prices[i].close;
    const endPrice = prices[i + windowDays].close;

    // Avoid division by zero
    if (startPrice === 0) {
      continue;
    }

    // Calculate percentage return: ((end - start) / start) * 100
    const returnPct = ((endPrice - startPrice) / startPrice) * 100;

    returns.push({
      startDate: prices[i].date,
      endDate: prices[i + windowDays].date,
      returnPct,
    });
  }

  return returns;
}

/**
 * Calculate target price from current price and return percentage.
 *
 * Formula: targetPrice = currentPrice × (1 + returnPercentage / 100)
 * Rounded to 2 decimal places.
 *
 * Requirements: 5.4 - Target price calculation formula
 *
 * @param currentPrice - The current stock price
 * @param returnPct - The return percentage
 * @returns The target price rounded to 2 decimal places
 */
export function calculateTargetPrice(currentPrice: number, returnPct: number): number {
  const rawTargetPrice = currentPrice * (1 + returnPct / 100);
  return Math.round(rawTargetPrice * 100) / 100;
}

/**
 * Determine the trading signal based on return percentage and premium threshold.
 *
 * Signal is ORDER when the absolute return percentage meets or exceeds
 * the configured premium threshold. Otherwise, the signal is HOLD.
 *
 * @param returnPct - The return percentage
 * @param premiumPct - The configured premium percentage threshold
 * @returns The trading signal (ORDER or HOLD)
 */
export function determineSignal(returnPct: number, premiumPct: number): Signal {
  return Math.abs(returnPct) >= premiumPct ? "ORDER" : "HOLD";
}

/**
 * Calculate whether earnings date poses a risk for the option trade.
 *
 * Earnings risk exists when the next earnings date falls on or before
 * the option expiration date (approximated as windowDays from today).
 *
 * Requirements: 6.4 - Earnings risk when earnings <= expiration
 *
 * @param earningsDate - The next earnings date, or undefined if unavailable
 * @param windowDays - The configured window days (approximates option expiration)
 * @returns true if earnings risk exists, false otherwise
 */
export function calculateEarningsRisk(
  earningsDate: Date | undefined,
  windowDays: number,
): boolean {
  if (!earningsDate) {
    return false;
  }

  const today = new Date();
  const expirationDate = new Date(today);
  expirationDate.setDate(expirationDate.getDate() + windowDays);

  // Earnings risk if earnings is on or before expiration
  return earningsDate <= expirationDate;
}

/**
 * Identify CALL and PUT opportunities from rolling window returns.
 *
 * Requirements:
 * - 5.3: Best return (max) = CALL, worst return (min) = PUT
 * - 5.4: Calculate target prices
 * - 6.2: CALL has positive return, PUT has negative return
 *
 * @param returns - Array of rolling window returns
 * @param currentPrice - The current stock price
 * @param premiumPct - The configured premium percentage threshold
 * @returns Tuple of [CALL return info, PUT return info] or undefined if empty
 */
function identifyOpportunities(
  returns: RollingWindowReturn[],
  currentPrice: number,
  premiumPct: number,
): { call: RollingWindowReturn & { targetPrice: number; signal: Signal };
     put: RollingWindowReturn & { targetPrice: number; signal: Signal } } | undefined {
  if (returns.length === 0 || currentPrice <= 0) {
    return undefined;
  }

  // Find best return (maximum) for CALL opportunity
  const bestReturn = returns.reduce((best, current) =>
    current.returnPct > best.returnPct ? current : best,
  );

  // Find worst return (minimum) for PUT opportunity
  const worstReturn = returns.reduce((worst, current) =>
    current.returnPct < worst.returnPct ? current : worst,
  );

  return {
    call: {
      ...bestReturn,
      targetPrice: calculateTargetPrice(currentPrice, bestReturn.returnPct),
      signal: determineSignal(bestReturn.returnPct, premiumPct),
    },
    put: {
      ...worstReturn,
      targetPrice: calculateTargetPrice(currentPrice, worstReturn.returnPct),
      signal: determineSignal(Math.abs(worstReturn.returnPct), premiumPct),
    },
  };
}

/**
 * Execute strategy analysis for a single ticker.
 *
 * This method executes the complete analysis pipeline:
 * 1. Fetch historical prices from Yahoo Finance
 * 2. Fetch next earnings date
 * 3. Calculate rolling window returns
 * 4. Identify CALL and PUT opportunities
 * 5. Generate AnalysisResult objects
 *
 * Requirements:
 * - 5.1: Fetch historical prices for LOOKBACK_DAYS
 * - 5.2: Calculate rolling window returns
 * - 5.3: Identify CALL/PUT opportunities
 * - 5.4: Calculate target prices
 * - 8.3: Results include source="scheduled" and timestamp
 *
 * @param ticker - The stock ticker symbol
 * @param configuration - The strategy configuration
 * @param scheduledRunId - The scheduled run ID for reference
 * @returns Array of AnalysisResult (one CALL and one PUT opportunity)
 * @throws Error if analysis fails
 */
export async function analyzeTickerForScheduledRun(
  ticker: string,
  configuration: WeeklyOptionConfiguration,
  scheduledRunId: string,
): Promise<AnalysisResult[]> {
  functions.logger.info(`Analyzing ticker ${ticker}`, {
    windowDays: configuration.windowDays,
    lookbackDays: configuration.lookbackDays,
    premiumPct: configuration.premiumPct,
  });

  // 1. Fetch historical prices (Requirement 5.1)
  const priceData = await fetchHistoricalPrices(ticker, configuration.lookbackDays);

  // 2. Calculate rolling window returns (Requirement 5.2)
  const returns = calculateRollingReturns(priceData, configuration.windowDays);

  if (returns.length === 0) {
    throw new Error(`Insufficient data to calculate returns for ${ticker}`);
  }

  // 3. Fetch earnings date (optional - don't fail on error) (Requirement 6.8)
  const earningsDate = await fetchEarningsDate(ticker);

  // 4. Get current price
  const currentPrice = getCurrentPrice(priceData);
  if (!currentPrice) {
    throw new Error(`Unable to determine current price for ${ticker}`);
  }

  // 5. Identify CALL/PUT opportunities (Requirement 5.3)
  const opportunities = identifyOpportunities(returns, currentPrice, configuration.premiumPct);

  if (!opportunities) {
    throw new Error(`Unable to identify opportunities for ${ticker}`);
  }

  // 6. Calculate earnings risk (Requirement 6.4)
  const hasEarningsRisk = calculateEarningsRisk(earningsDate, configuration.windowDays);

  const analyzedAt = new Date();

  // 7. Create CALL result (Requirement 5.4, 6.2)
  const callResult: AnalysisResult = {
    id: generateResultId(),
    ticker,
    type: "CALL" as OpportunityType,
    returnPercentage: opportunities.call.returnPct,
    currentPrice,
    targetPrice: opportunities.call.targetPrice,
    signal: opportunities.call.signal,
    nextEarningsDate: earningsDate,
    hasEarningsRisk,
    analyzedAt,
    source: "scheduled",
    scheduledRunId,
  };

  // 8. Create PUT result (Requirement 5.4, 6.2)
  const putResult: AnalysisResult = {
    id: generateResultId(),
    ticker,
    type: "PUT" as OpportunityType,
    returnPercentage: opportunities.put.returnPct,
    currentPrice,
    targetPrice: opportunities.put.targetPrice,
    signal: opportunities.put.signal,
    nextEarningsDate: earningsDate,
    hasEarningsRisk,
    analyzedAt,
    source: "scheduled",
    scheduledRunId,
  };

  functions.logger.debug(`Analysis complete for ${ticker}`, {
    callReturn: callResult.returnPercentage,
    putReturn: putResult.returnPercentage,
    currentPrice,
    hasEarningsRisk,
  });

  return [callResult, putResult];
}

/**
 * Filter analysis results based on ONLY_ORDERS configuration.
 *
 * When onlyOrders is true, only results with ORDER signal are returned.
 *
 * @param results - Array of analysis results
 * @param onlyOrders - Whether to filter to only ORDER signals
 * @returns Filtered array of results
 */
export function filterResultsBySignal(
  results: AnalysisResult[],
  onlyOrders: boolean,
): AnalysisResult[] {
  if (!onlyOrders) {
    return results;
  }
  return results.filter((result) => result.signal === "ORDER");
}
