/**
 * Scheduled Analysis Times Configuration
 *
 * Defines the 7 daily analysis execution times in PST timezone
 * as specified in Requirement 8.1.
 *
 * Requirements: 8.1 - THE System SHALL automatically execute the configured
 * strategy analysis at the following times in PST timezone: 6:30 AM, 6:45 AM,
 * 7:00 AM, 9:00 AM, 11:00 AM, 12:30 PM, and 12:45 PM
 */

export interface ScheduledTime {
  /** Display name for the scheduled time (e.g., "06:30") */
  displayTime: string;
  /** Hour in 24-hour format (0-23) */
  hour: number;
  /** Minute (0-59) */
  minute: number;
  /** Cron expression for Cloud Scheduler */
  cronExpression: string;
  /** Description of the time slot */
  description: string;
}

/**
 * All scheduled analysis times in PST timezone.
 * These correspond to Cloud Scheduler triggers defined in index.ts.
 */
export const SCHEDULED_TIMES: ScheduledTime[] = [
  {
    displayTime: "06:30",
    hour: 6,
    minute: 30,
    cronExpression: "30 6 * * 1-5",
    description: "Pre-market analysis (6:30 AM PST)",
  },
  {
    displayTime: "06:45",
    hour: 6,
    minute: 45,
    cronExpression: "45 6 * * 1-5",
    description: "Pre-market analysis (6:45 AM PST)",
  },
  {
    displayTime: "07:00",
    hour: 7,
    minute: 0,
    cronExpression: "0 7 * * 1-5",
    description: "Pre-market analysis (7:00 AM PST)",
  },
  {
    displayTime: "09:00",
    hour: 9,
    minute: 0,
    cronExpression: "0 9 * * 1-5",
    description: "Market open analysis (9:00 AM PST)",
  },
  {
    displayTime: "11:00",
    hour: 11,
    minute: 0,
    cronExpression: "0 11 * * 1-5",
    description: "Mid-morning analysis (11:00 AM PST)",
  },
  {
    displayTime: "12:30",
    hour: 12,
    minute: 30,
    cronExpression: "30 12 * * 1-5",
    description: "Midday analysis (12:30 PM PST)",
  },
  {
    displayTime: "12:45",
    hour: 12,
    minute: 45,
    cronExpression: "45 12 * * 1-5",
    description: "Midday analysis (12:45 PM PST)",
  },
];

/**
 * PST timezone identifier for use with date formatting
 */
export const PST_TIMEZONE = "America/Los_Angeles";

/**
 * Get the scheduled time configuration by display time
 * @param displayTime - The time in HH:MM format (e.g., "06:30")
 * @returns The scheduled time configuration or undefined if not found
 */
export function getScheduledTimeConfig(displayTime: string): ScheduledTime | undefined {
  return SCHEDULED_TIMES.find((time) => time.displayTime === displayTime);
}

/**
 * Format a Date object to PST time string
 * @param date - The date to format
 * @returns Formatted time string in HH:MM AM/PM PST format
 */
export function formatPSTTime(date: Date): string {
  return date.toLocaleString("en-US", {
    timeZone: PST_TIMEZONE,
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }) + " PST";
}

/**
 * Get current date/time in PST timezone
 * @returns ISO string representation of current PST time
 */
export function getCurrentPSTDate(): Date {
  const now = new Date();
  const pstString = now.toLocaleString("en-US", { timeZone: PST_TIMEZONE });
  return new Date(pstString);
}
