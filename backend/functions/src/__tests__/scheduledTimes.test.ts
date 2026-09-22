/**
 * Scheduled Times Configuration Tests
 *
 * Tests to verify the scheduled analysis times are correctly configured
 * per Requirement 8.1.
 */

import {
  SCHEDULED_TIMES,
  getScheduledTimeConfig,
  formatPSTTime,
  PST_TIMEZONE,
} from "../config/scheduledTimes";

describe("Scheduled Times Configuration", () => {
  describe("SCHEDULED_TIMES", () => {
    it("should have exactly 7 scheduled times", () => {
      expect(SCHEDULED_TIMES).toHaveLength(7);
    });

    it("should include all required times per Requirement 8.1", () => {
      const expectedTimes = ["06:30", "06:45", "07:00", "09:00", "11:00", "12:30", "12:45"];
      const actualTimes = SCHEDULED_TIMES.map((t) => t.displayTime);

      expectedTimes.forEach((time) => {
        expect(actualTimes).toContain(time);
      });
    });

    it("should have valid cron expressions for weekdays only", () => {
      SCHEDULED_TIMES.forEach((time) => {
        // Cron should end with 1-5 for Monday-Friday
        expect(time.cronExpression).toMatch(/\* 1-5$/);
      });
    });

    it("should have consistent hour/minute with displayTime", () => {
      SCHEDULED_TIMES.forEach((time) => {
        const [hours, minutes] = time.displayTime.split(":").map(Number);
        expect(time.hour).toBe(hours);
        expect(time.minute).toBe(minutes);
      });
    });
  });

  describe("getScheduledTimeConfig", () => {
    it("should return configuration for valid time", () => {
      const config = getScheduledTimeConfig("06:30");
      expect(config).toBeDefined();
      expect(config?.hour).toBe(6);
      expect(config?.minute).toBe(30);
    });

    it("should return undefined for invalid time", () => {
      const config = getScheduledTimeConfig("08:00");
      expect(config).toBeUndefined();
    });
  });

  describe("formatPSTTime", () => {
    it("should format time with PST suffix", () => {
      const date = new Date("2024-01-15T14:30:00Z"); // 6:30 AM PST
      const formatted = formatPSTTime(date);
      expect(formatted).toContain("PST");
      expect(formatted).toContain("AM");
    });
  });

  describe("PST_TIMEZONE", () => {
    it("should be America/Los_Angeles", () => {
      expect(PST_TIMEZONE).toBe("America/Los_Angeles");
    });
  });
});
