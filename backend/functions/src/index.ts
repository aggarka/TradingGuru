/**
 * TradingGuru Cloud Functions
 *
 * Entry point for all Cloud Functions handling scheduled analysis,
 * email notifications, and backend processing.
 *
 * Scheduled Analysis Times (PST):
 * - 6:30 AM, 6:45 AM, 7:00 AM (Pre-market)
 * - 9:00 AM (Market open)
 * - 11:00 AM (Mid-morning)
 * - 12:30 PM, 12:45 PM (Midday)
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { runScheduledAnalysis } from "./services/scheduledAnalysisService";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export Firestore client for use across services
export const db = admin.firestore();

/**
 * Scheduled Analysis Functions
 *
 * These functions are triggered by Cloud Scheduler at the specified PST times.
 * Each function runs the analysis for all eligible users.
 *
 * Requirements: 8.1 - THE System SHALL automatically execute the configured
 * strategy analysis at the following times in PST timezone.
 */

// 6:30 AM PST - Pre-market analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis0630 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("30 6 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 6:30 AM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("06:30");
    return null;
  });

// 6:45 AM PST - Pre-market analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis0645 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("45 6 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 6:45 AM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("06:45");
    return null;
  });

// 7:00 AM PST - Pre-market analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis0700 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("0 7 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 7:00 AM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("07:00");
    return null;
  });

// 9:00 AM PST - Market open analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis0900 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("0 9 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 9:00 AM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("09:00");
    return null;
  });

// 11:00 AM PST - Mid-morning analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis1100 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("0 11 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 11:00 AM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("11:00");
    return null;
  });

// 12:30 PM PST - Midday analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis1230 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("30 12 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 12:30 PM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("12:30");
    return null;
  });

// 12:45 PM PST - Midday analysis
// eslint-disable-next-line camelcase
export const scheduledAnalysis1245 = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("45 12 * * 1-5")
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("Starting scheduled analysis at 12:45 PM PST", {
      eventId: context.eventId,
      timestamp: context.timestamp,
    });
    await runScheduledAnalysis("12:45");
    return null;
  });
