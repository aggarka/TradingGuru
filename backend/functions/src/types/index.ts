/**
 * TradingGuru Backend Types
 *
 * Type definitions for all data models used in the backend service.
 * These types mirror the iOS client models for consistency.
 */

/**
 * User profile data stored in Firestore
 */
export interface User {
  id: string;
  email?: string;
  displayName?: string;
  authProvider: AuthProviderType;
  createdAt: FirebaseFirestore.Timestamp;
  lastLoginAt: FirebaseFirestore.Timestamp;
  settings: UserSettings;
}

/**
 * User settings for notifications and scheduled analysis
 */
export interface UserSettings {
  notificationEmail?: string;
  emailNotificationsEnabled: boolean;
  scheduledAnalysisEnabled: boolean;
  updatedAt: FirebaseFirestore.Timestamp;
}

/**
 * Authentication provider types
 */
export type AuthProviderType = "google" | "apple" | "passkey";

/**
 * Watchlist symbol entry in Firestore
 */
export interface WatchlistItem {
  symbol: string;
  addedAt: FirebaseFirestore.Timestamp;
}

/**
 * Strategy configuration stored per user
 */
export interface StrategyConfiguration {
  strategyId: string;
  parameters: Record<string, ConfigValue>;
  updatedAt: FirebaseFirestore.Timestamp;
}

/**
 * Configuration value types
 */
export type ConfigValue = number | boolean | string;

/**
 * Weekly Option Strategy specific configuration
 */
export interface WeeklyOptionConfiguration {
  windowDays: 1 | 5 | 30;
  lookbackDays: 30 | 60 | 90 | 180 | 360;
  premiumPct: number; // 0.1 to 5.0
  onlyOrders: boolean;
}

/**
 * Default configuration values
 */
export const DEFAULT_WEEKLY_OPTION_CONFIG: WeeklyOptionConfiguration = {
  windowDays: 5,
  lookbackDays: 180,
  premiumPct: 0.5,
  onlyOrders: false,
};

/**
 * Price point from Yahoo Finance
 */
export interface PricePoint {
  date: Date;
  close: number;
}

/**
 * Analysis result for a single ticker
 */
export interface AnalysisResult {
  id: string;
  ticker: string;
  type: OpportunityType;
  returnPercentage: number;
  currentPrice: number;
  targetPrice: number;
  signal: Signal;
  nextEarningsDate?: Date;
  hasEarningsRisk: boolean;
  analyzedAt: Date;
  source: AnalysisSource;
  scheduledRunId?: string;
}

/**
 * Opportunity type - CALL or PUT
 */
export type OpportunityType = "CALL" | "PUT";

/**
 * Trading signal
 */
export type Signal = "ORDER" | "HOLD";

/**
 * Source of the analysis
 */
export type AnalysisSource = "manual" | "scheduled";

/**
 * Scheduled run record
 */
export interface ScheduledRun {
  id: string;
  scheduledTime: string;
  executedAt: FirebaseFirestore.Timestamp;
  status: RunStatus;
  processedUsers: number;
  totalUsers: number;
  errors: ScheduledRunError[];
}

/**
 * Scheduled run status
 */
export type RunStatus = "pending" | "running" | "completed" | "failed" | "retrying";

/**
 * Error entry for scheduled run
 */
export interface ScheduledRunError {
  userId: string;
  ticker?: string;
  error: string;
  timestamp: Date;
}

/**
 * User eligible for scheduled analysis
 * Requirements: 8.2 - Users must have scheduledAnalysisEnabled=true AND watchlist.count > 0
 */
export interface EligibleUser {
  id: string;
  watchlist: string[];
  configuration: WeeklyOptionConfiguration;
  settings: UserSettings;
}

/**
 * Analysis execution context
 */
export interface AnalysisContext {
  scheduledTime: string;
  runId: string;
  executedAt: Date;
}
