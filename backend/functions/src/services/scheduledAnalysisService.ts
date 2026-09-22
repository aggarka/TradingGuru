/**
 * Scheduled Analysis Service
 *
 * Orchestrates the scheduled analysis execution for all eligible users.
 * Implements Requirements 8.1-8.3, 8.7.
 */

import * as functions from "firebase-functions";
import {
  getEligibleUsers,
  storeAnalysisResults,
  createScheduledRun,
  updateRunProgress,
  updateRunStatus,
  addRunError,
} from "./firestoreService";
import {
  AnalysisResult,
  EligibleUser,
  AnalysisContext,
  ScheduledRunError,
} from "../types";
import { formatPSTTime } from "../config/scheduledTimes";
import {
  analyzeTickerForScheduledRun,
  filterResultsBySignal,
} from "./strategyExecutionService";
import { YahooFinanceError } from "./yahooFinanceService";

/**
 * Error categories for scheduled analysis
 * Used to classify errors and determine retry behavior
 */
export enum ScheduledAnalysisErrorType {
  /** Data retrieval errors from external APIs (Yahoo Finance) - retryable */
  DATA_RETRIEVAL = "DATA_RETRIEVAL",
  /** Database errors (Firestore) - retryable */
  DATABASE = "DATABASE",
  /** Configuration errors - not retryable */
  CONFIGURATION = "CONFIGURATION",
  /** Unknown/unexpected errors */
  UNKNOWN = "UNKNOWN",
}

/**
 * Custom error class for scheduled analysis operations
 */
export class ScheduledAnalysisError extends Error {
  public readonly type: ScheduledAnalysisErrorType;
  public readonly isRetryable: boolean;
  public readonly userId?: string;
  public readonly ticker?: string;

  constructor(
    message: string,
    type: ScheduledAnalysisErrorType,
    options?: {
      userId?: string;
      ticker?: string;
      cause?: Error;
    },
  ) {
    super(message);
    this.name = "ScheduledAnalysisError";
    this.type = type;
    this.userId = options?.userId;
    this.ticker = options?.ticker;

    // Only data retrieval and database errors are retryable
    this.isRetryable = type === ScheduledAnalysisErrorType.DATA_RETRIEVAL ||
                       type === ScheduledAnalysisErrorType.DATABASE;

    // Maintain stack trace
    if (options?.cause && options.cause.stack) {
      this.stack = `${this.stack}\nCaused by: ${options.cause.stack}`;
    }
  }
}

/**
 * Classify an error into a ScheduledAnalysisErrorType
 * @param error - The error to classify
 * @returns The classified error type
 */
export function classifyError(error: unknown): ScheduledAnalysisErrorType {
  if (error instanceof ScheduledAnalysisError) {
    return error.type;
  }

  const errorMessage = error instanceof Error ? error.message.toLowerCase() : String(error).toLowerCase();

  // Data retrieval errors (Yahoo Finance, network issues)
  if (
    errorMessage.includes("fetch") ||
    errorMessage.includes("network") ||
    errorMessage.includes("timeout") ||
    errorMessage.includes("yahoo") ||
    errorMessage.includes("api") ||
    errorMessage.includes("econnrefused") ||
    errorMessage.includes("enotfound") ||
    errorMessage.includes("etimedout") ||
    errorMessage.includes("rate limit") ||
    errorMessage.includes("429") ||
    errorMessage.includes("503") ||
    errorMessage.includes("502") ||
    errorMessage.includes("504")
  ) {
    return ScheduledAnalysisErrorType.DATA_RETRIEVAL;
  }

  // Database errors
  if (
    errorMessage.includes("firestore") ||
    errorMessage.includes("database") ||
    errorMessage.includes("permission denied") ||
    errorMessage.includes("deadline exceeded") ||
    errorMessage.includes("unavailable")
  ) {
    return ScheduledAnalysisErrorType.DATABASE;
  }

  // Configuration errors
  if (
    errorMessage.includes("config") ||
    errorMessage.includes("invalid parameter") ||
    errorMessage.includes("validation")
  ) {
    return ScheduledAnalysisErrorType.CONFIGURATION;
  }

  return ScheduledAnalysisErrorType.UNKNOWN;
}

/**
 * Check if an error is retryable based on its type
 * @param error - The error to check
 * @returns true if the error is retryable
 */
export function isRetryableError(error: unknown): boolean {
  if (error instanceof ScheduledAnalysisError) {
    return error.isRetryable;
  }

  const errorType = classifyError(error);
  return errorType === ScheduledAnalysisErrorType.DATA_RETRIEVAL ||
         errorType === ScheduledAnalysisErrorType.DATABASE;
}

/** Retry delay in milliseconds (2 minutes as per Requirement 8.7) */
export const RETRY_DELAY_MS = 2 * 60 * 1000;

/**
 * Run scheduled analysis for all eligible users
 *
 * Requirements:
 * - 8.1: Execute at specified PST times
 * - 8.2: Run for users with scheduledAnalysisEnabled=true AND watchlist.count > 0
 * - 8.3: Store results with timestamp and source="scheduled"
 * - 8.7: Log failures, retry once after 2-minute delay
 *
 * @param scheduledTime - The scheduled time identifier (e.g., "06:30")
 */
export async function runScheduledAnalysis(scheduledTime: string): Promise<void> {
  functions.logger.info("Starting scheduled analysis", {
    scheduledTime,
    timestamp: new Date().toISOString(),
    event: "SCHEDULED_ANALYSIS_START",
  });
  const executedAt = new Date();

  try {
    // Get all eligible users (Requirement 8.2)
    const eligibleUsers = await getEligibleUsers();

    if (eligibleUsers.length === 0) {
      functions.logger.info("No eligible users found for scheduled analysis", {
        scheduledTime,
        event: "NO_ELIGIBLE_USERS",
      });
      return;
    }

    functions.logger.info("Found eligible users for analysis", {
      scheduledTime,
      userCount: eligibleUsers.length,
      event: "ELIGIBLE_USERS_FOUND",
    });

    // Create scheduled run record
    const runId = await createScheduledRun(scheduledTime, eligibleUsers.length);

    const context: AnalysisContext = {
      scheduledTime,
      runId,
      executedAt,
    };

    // Process each user - individual failures don't affect other users
    let processedCount = 0;
    let successCount = 0;
    let failureCount = 0;
    const failedUsers: string[] = [];

    for (const user of eligibleUsers) {
      const result = await processUserWithErrorHandling(user, context);
      processedCount++;

      if (result.success) {
        successCount++;
      } else {
        failureCount++;
        failedUsers.push(user.id);
      }

      await updateRunProgress(runId, processedCount);
    }

    // Update run status to completed
    await updateRunStatus(runId, "completed");

    functions.logger.info("Scheduled analysis completed", {
      scheduledTime,
      runId,
      totalUsers: eligibleUsers.length,
      processedCount,
      successCount,
      failureCount,
      failedUsers: failedUsers.length > 0 ? failedUsers : undefined,
      event: "SCHEDULED_ANALYSIS_COMPLETE",
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    const errorType = classifyError(error);

    functions.logger.error("Fatal error in scheduled analysis", {
      error: errorMessage,
      errorType,
      scheduledTime,
      stack: error instanceof Error ? error.stack : undefined,
      event: "SCHEDULED_ANALYSIS_FATAL_ERROR",
    });

    throw error;
  }
}

/**
 * Result of processing a single user
 */
interface ProcessUserResult {
  success: boolean;
  error?: string;
  errorType?: ScheduledAnalysisErrorType;
  retriedSuccessfully?: boolean;
}

/**
 * Process a user's analysis with comprehensive error handling and retry logic
 *
 * Requirements: 8.7 - Log failures, retry once after 2-minute delay on data retrieval errors
 *
 * @param user - The eligible user to process
 * @param context - The analysis execution context
 * @returns Result indicating success or failure
 */
async function processUserWithErrorHandling(
  user: EligibleUser,
  context: AnalysisContext,
): Promise<ProcessUserResult> {
  try {
    await processUserAnalysis(user, context);
    return { success: true };
  } catch (error) {
    // Log the initial failure
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    const errorType = classifyError(error);
    const ticker = error instanceof ScheduledAnalysisError ? error.ticker : undefined;

    functions.logger.error("Error processing user analysis", {
      userId: user.id,
      error: errorMessage,
      errorType,
      ticker,
      watchlistSize: user.watchlist.length,
      isRetryable: isRetryableError(error),
      event: "USER_ANALYSIS_INITIAL_FAILURE",
    });

    // Record the error
    const runError: ScheduledRunError = {
      userId: user.id,
      ticker,
      error: `[${errorType}] ${errorMessage}`,
      timestamp: new Date(),
    };
    await addRunError(context.runId, runError);

    // Retry once after 2-minute delay for retryable errors (Requirement 8.7)
    if (isRetryableError(error)) {
      functions.logger.info("Scheduling retry for user", {
        userId: user.id,
        errorType,
        delayMs: RETRY_DELAY_MS,
        event: "USER_ANALYSIS_RETRY_SCHEDULED",
      });

      const retryResult = await retryWithDelay(user, context);

      if (retryResult.success) {
        return {
          success: true,
          retriedSuccessfully: true,
        };
      } else {
        return {
          success: false,
          error: retryResult.error,
          errorType: retryResult.errorType,
          retriedSuccessfully: false,
        };
      }
    }

    // Non-retryable error - continue processing other users
    functions.logger.warn("Non-retryable error, skipping retry", {
      userId: user.id,
      errorType,
      event: "USER_ANALYSIS_NO_RETRY",
    });

    return {
      success: false,
      error: errorMessage,
      errorType,
    };
  }
}

/**
 * Process analysis for a single user
 *
 * @param user - The eligible user to process
 * @param context - The analysis execution context
 * @throws ScheduledAnalysisError on failure
 */
async function processUserAnalysis(user: EligibleUser, context: AnalysisContext): Promise<void> {
  functions.logger.info("Starting user analysis", {
    userId: user.id,
    watchlistSize: user.watchlist.length,
    configuration: {
      windowDays: user.configuration.windowDays,
      lookbackDays: user.configuration.lookbackDays,
      premiumPct: user.configuration.premiumPct,
    },
    event: "USER_ANALYSIS_START",
  });

  const results: AnalysisResult[] = [];
  const tickerErrors: Array<{ ticker: string; error: string; errorType: ScheduledAnalysisErrorType }> = [];

  // Process each ticker in the user's watchlist
  for (const ticker of user.watchlist) {
    try {
      // Execute strategy analysis for this ticker (Requirements 5.1-5.4, 8.3)
      const tickerResults = await analyzeTicker(ticker, user, context);
      results.push(...tickerResults);
    } catch (error) {
      // Log error for individual ticker and continue (Requirement 8.7)
      const errorMessage = error instanceof Error ? error.message : "Unknown error";
      const errorType = classifyError(error);

      functions.logger.warn("Error analyzing ticker", {
        ticker,
        userId: user.id,
        error: errorMessage,
        errorType,
        event: "TICKER_ANALYSIS_ERROR",
      });

      tickerErrors.push({ ticker, error: errorMessage, errorType });
    }
  }

  // If all tickers failed, throw an error to trigger retry
  if (tickerErrors.length === user.watchlist.length && user.watchlist.length > 0) {
    // Check if majority of errors are data retrieval errors
    const dataRetrievalErrors = tickerErrors.filter(
      (e) => e.errorType === ScheduledAnalysisErrorType.DATA_RETRIEVAL,
    );

    if (dataRetrievalErrors.length > tickerErrors.length / 2) {
      throw new ScheduledAnalysisError(
        `All ${tickerErrors.length} tickers failed with data retrieval errors`,
        ScheduledAnalysisErrorType.DATA_RETRIEVAL,
        { userId: user.id },
      );
    }

    throw new ScheduledAnalysisError(
      `All ${tickerErrors.length} tickers failed`,
      ScheduledAnalysisErrorType.UNKNOWN,
      { userId: user.id },
    );
  }

  // Store results (Requirement 8.3)
  if (results.length > 0) {
    await storeAnalysisResults(user.id, results, context.runId);
  }

  functions.logger.info("User analysis completed", {
    userId: user.id,
    resultsCount: results.length,
    tickerErrorCount: tickerErrors.length,
    tickerErrors: tickerErrors.length > 0 ? tickerErrors.map((e) => e.ticker) : undefined,
    event: "USER_ANALYSIS_COMPLETE",
  });
}

/**
 * Analyze a single ticker using the strategy execution service.
 *
 * Executes the Weekly Option Strategy analysis:
 * 1. Fetch historical prices from Yahoo Finance
 * 2. Calculate rolling window returns
 * 3. Identify CALL and PUT opportunities
 * 4. Return analysis results
 *
 * Requirements:
 * - 5.1-5.4: Strategy execution logic
 * - 8.3: Results include source="scheduled" and scheduledRunId
 *
 * @param ticker - The stock ticker symbol
 * @param user - The user configuration
 * @param context - The analysis context
 * @returns Array of analysis results for the ticker (CALL and PUT)
 */
async function analyzeTicker(
  ticker: string,
  user: EligibleUser,
  context: AnalysisContext,
): Promise<AnalysisResult[]> {
  try {
    // Execute strategy analysis using the strategy execution service
    const results = await analyzeTickerForScheduledRun(
      ticker,
      user.configuration,
      context.runId,
    );

    // Apply ONLY_ORDERS filter if configured
    return filterResultsBySignal(results, user.configuration.onlyOrders);
  } catch (error) {
    // Convert Yahoo Finance errors to ScheduledAnalysisError for proper classification
    if (error instanceof YahooFinanceError) {
      throw new ScheduledAnalysisError(
        error.message,
        ScheduledAnalysisErrorType.DATA_RETRIEVAL,
        { userId: user.id, ticker, cause: error as Error },
      );
    }

    // Re-throw other errors - wrap in ScheduledAnalysisError for consistent handling
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new ScheduledAnalysisError(
      errorMessage,
      classifyError(error),
      { userId: user.id, ticker, cause: error instanceof Error ? error : undefined },
    );
  }
}

/**
 * Retry result type
 */
interface RetryResult {
  success: boolean;
  error?: string;
  errorType?: ScheduledAnalysisErrorType;
}

/**
 * Retry user analysis after a delay
 * Requirement 8.7: Retry once after 2-minute delay on data retrieval errors
 *
 * @param user - The user to retry
 * @param context - The analysis context
 * @returns Result of the retry attempt
 */
async function retryWithDelay(user: EligibleUser, context: AnalysisContext): Promise<RetryResult> {
  functions.logger.info("Starting retry delay", {
    userId: user.id,
    delayMs: RETRY_DELAY_MS,
    retryScheduledAt: new Date(Date.now() + RETRY_DELAY_MS).toISOString(),
    event: "USER_ANALYSIS_RETRY_DELAY_START",
  });

  // Update run status to indicate retrying
  await updateRunStatus(context.runId, "retrying");

  return new Promise((resolve) => {
    setTimeout(async () => {
      try {
        functions.logger.info("Executing retry attempt", {
          userId: user.id,
          event: "USER_ANALYSIS_RETRY_ATTEMPT",
        });

        await processUserAnalysis(user, context);

        functions.logger.info("Retry successful", {
          userId: user.id,
          event: "USER_ANALYSIS_RETRY_SUCCESS",
        });

        resolve({ success: true });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : "Unknown error";
        const errorType = classifyError(error);
        const ticker = error instanceof ScheduledAnalysisError ? error.ticker : undefined;

        functions.logger.error("Retry failed", {
          userId: user.id,
          error: errorMessage,
          errorType,
          ticker,
          event: "USER_ANALYSIS_RETRY_FAILURE",
        });

        // Log final failure
        const runError: ScheduledRunError = {
          userId: user.id,
          ticker,
          error: `[RETRY FAILED][${errorType}] ${errorMessage}`,
          timestamp: new Date(),
        };
        await addRunError(context.runId, runError);

        resolve({
          success: false,
          error: errorMessage,
          errorType,
        });
      }
    }, RETRY_DELAY_MS);
  });
}

/**
 * Format analysis timestamp for display
 * @param date - The analysis execution date
 * @returns Formatted string like "Last updated: 6:30 AM PST"
 */
export function formatAnalysisTimestamp(date: Date): string {
  return `Last updated: ${formatPSTTime(date)}`;
}
