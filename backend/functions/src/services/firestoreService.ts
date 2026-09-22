/**
 * Firestore Service
 *
 * Provides access to Firestore collections for scheduled analysis.
 * Handles reading user data, watchlists, configurations, and storing results.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {
  User,
  UserSettings,
  WatchlistItem,
  StrategyConfiguration,
  WeeklyOptionConfiguration,
  AnalysisResult,
  ScheduledRun,
  EligibleUser,
  DEFAULT_WEEKLY_OPTION_CONFIG,
  RunStatus,
  ScheduledRunError,
} from "../types";

/**
 * Firestore collection paths
 */
export const COLLECTIONS = {
  USERS: "users",
  WATCHLIST: "watchlist",
  CONFIGURATIONS: "configurations",
  RESULTS: "results",
  SCHEDULED_RUNS: "scheduledRuns",
} as const;

/**
 * Get Firestore instance
 */
function getFirestore(): FirebaseFirestore.Firestore {
  return admin.firestore();
}

/**
 * Get all users eligible for scheduled analysis
 *
 * Requirements: 8.2 - Query users with scheduledAnalysisEnabled=true AND watchlist.count > 0
 *
 * @returns Array of eligible users with their watchlists and configurations
 */
export async function getEligibleUsers(): Promise<EligibleUser[]> {
  const db = getFirestore();
  const eligibleUsers: EligibleUser[] = [];

  try {
    // Query users with scheduled analysis enabled
    const usersSnapshot = await db
      .collection(COLLECTIONS.USERS)
      .where("settings.scheduledAnalysisEnabled", "==", true)
      .get();

    functions.logger.info(`Found ${usersSnapshot.size} users with scheduled analysis enabled`);

    // For each user, check if they have watchlist items and get their configuration
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data() as User;
      const userId = userDoc.id;

      // Get user's watchlist
      const watchlistSnapshot = await db
        .collection(COLLECTIONS.USERS)
        .doc(userId)
        .collection(COLLECTIONS.WATCHLIST)
        .get();

      // Skip users with empty watchlist
      if (watchlistSnapshot.empty) {
        functions.logger.debug(`Skipping user ${userId}: empty watchlist`);
        continue;
      }

      const watchlist = watchlistSnapshot.docs.map((doc) => {
        const item = doc.data() as WatchlistItem;
        return item.symbol;
      });

      // Get user's strategy configuration (or use defaults)
      const configDoc = await db
        .collection(COLLECTIONS.USERS)
        .doc(userId)
        .collection(COLLECTIONS.CONFIGURATIONS)
        .doc("weekly_option")
        .get();

      let configuration: WeeklyOptionConfiguration;
      if (configDoc.exists) {
        const configData = configDoc.data() as StrategyConfiguration;
        configuration = {
          windowDays: (configData.parameters.windowDays as 1 | 5 | 30) ?? DEFAULT_WEEKLY_OPTION_CONFIG.windowDays,
          lookbackDays: (configData.parameters.lookbackDays as 30 | 60 | 90 | 180 | 360) ??
            DEFAULT_WEEKLY_OPTION_CONFIG.lookbackDays,
          premiumPct: (configData.parameters.premiumPct as number) ?? DEFAULT_WEEKLY_OPTION_CONFIG.premiumPct,
          onlyOrders: (configData.parameters.onlyOrders as boolean) ?? DEFAULT_WEEKLY_OPTION_CONFIG.onlyOrders,
        };
      } else {
        configuration = DEFAULT_WEEKLY_OPTION_CONFIG;
      }

      eligibleUsers.push({
        id: userId,
        watchlist,
        configuration,
        settings: userData.settings,
      });
    }

    functions.logger.info(`${eligibleUsers.length} users are eligible for scheduled analysis`);
    return eligibleUsers;
  } catch (error) {
    functions.logger.error("Error fetching eligible users", { error });
    throw error;
  }
}

/**
 * Store analysis results for a user
 *
 * Requirements: 8.3 - Store results with timestamp and source="scheduled"
 *
 * @param userId - The user's ID
 * @param results - Array of analysis results to store
 * @param runId - The scheduled run ID for reference
 */
export async function storeAnalysisResults(
  userId: string,
  results: AnalysisResult[],
  runId: string,
): Promise<void> {
  const db = getFirestore();
  const batch = db.batch();
  const resultsCollection = db
    .collection(COLLECTIONS.USERS)
    .doc(userId)
    .collection(COLLECTIONS.RESULTS);

  // Store each result
  for (const result of results) {
    const resultRef = resultsCollection.doc(result.id);
    batch.set(resultRef, {
      ...result,
      analyzedAt: admin.firestore.Timestamp.fromDate(result.analyzedAt),
      nextEarningsDate: result.nextEarningsDate ?
        admin.firestore.Timestamp.fromDate(result.nextEarningsDate) : null,
      scheduledRunId: runId,
    });
  }

  try {
    await batch.commit();
    functions.logger.info(`Stored ${results.length} results for user ${userId}`);
  } catch (error) {
    functions.logger.error(`Error storing results for user ${userId}`, { error });
    throw error;
  }
}

/**
 * Create a new scheduled run record
 *
 * @param scheduledTime - The scheduled time (e.g., "06:30")
 * @param totalUsers - Total number of eligible users
 * @returns The created run ID
 */
export async function createScheduledRun(scheduledTime: string, totalUsers: number): Promise<string> {
  const db = getFirestore();
  const runRef = db.collection(COLLECTIONS.SCHEDULED_RUNS).doc();

  const run: Omit<ScheduledRun, "id"> = {
    scheduledTime,
    executedAt: admin.firestore.Timestamp.now(),
    status: "running",
    processedUsers: 0,
    totalUsers,
    errors: [],
  };

  await runRef.set(run);
  functions.logger.info(`Created scheduled run ${runRef.id} for ${scheduledTime}`);
  return runRef.id;
}

/**
 * Update scheduled run progress
 *
 * @param runId - The run ID
 * @param processedUsers - Number of users processed so far
 */
export async function updateRunProgress(runId: string, processedUsers: number): Promise<void> {
  const db = getFirestore();
  await db.collection(COLLECTIONS.SCHEDULED_RUNS).doc(runId).update({
    processedUsers,
  });
}

/**
 * Update scheduled run status
 *
 * @param runId - The run ID
 * @param status - The new status
 */
export async function updateRunStatus(runId: string, status: RunStatus): Promise<void> {
  const db = getFirestore();
  await db.collection(COLLECTIONS.SCHEDULED_RUNS).doc(runId).update({
    status,
  });
}

/**
 * Add error to scheduled run
 *
 * @param runId - The run ID
 * @param error - The error details
 */
export async function addRunError(runId: string, error: ScheduledRunError): Promise<void> {
  const db = getFirestore();
  await db.collection(COLLECTIONS.SCHEDULED_RUNS).doc(runId).update({
    errors: admin.firestore.FieldValue.arrayUnion(error),
  });
}

/**
 * Get user settings by ID
 *
 * @param userId - The user's ID
 * @returns User settings or null if not found
 */
export async function getUserSettings(userId: string): Promise<UserSettings | null> {
  const db = getFirestore();
  const userDoc = await db.collection(COLLECTIONS.USERS).doc(userId).get();

  if (!userDoc.exists) {
    return null;
  }

  const userData = userDoc.data() as User;
  return userData.settings;
}
