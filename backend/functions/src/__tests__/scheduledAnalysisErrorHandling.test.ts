/**
 * Scheduled Analysis Error Handling Tests
 *
 * Tests for error handling, classification, and retry logic.
 * Validates Requirement 8.7: Log failures and retry once after 2-minute delay on data retrieval errors.
 */

import {
  classifyError,
  isRetryableError,
  ScheduledAnalysisError,
  ScheduledAnalysisErrorType,
  RETRY_DELAY_MS,
} from "../services/scheduledAnalysisService";

// Mock firebase-functions logger
jest.mock("firebase-functions", () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

describe("Scheduled Analysis Error Handling", () => {
  describe("ScheduledAnalysisErrorType enum", () => {
    it("should have all expected error types", () => {
      expect(ScheduledAnalysisErrorType.DATA_RETRIEVAL).toBe("DATA_RETRIEVAL");
      expect(ScheduledAnalysisErrorType.DATABASE).toBe("DATABASE");
      expect(ScheduledAnalysisErrorType.CONFIGURATION).toBe("CONFIGURATION");
      expect(ScheduledAnalysisErrorType.UNKNOWN).toBe("UNKNOWN");
    });
  });

  describe("ScheduledAnalysisError class", () => {
    it("should create error with DATA_RETRIEVAL type as retryable", () => {
      const error = new ScheduledAnalysisError(
        "Network timeout",
        ScheduledAnalysisErrorType.DATA_RETRIEVAL,
      );

      expect(error.message).toBe("Network timeout");
      expect(error.type).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      expect(error.isRetryable).toBe(true);
      expect(error.name).toBe("ScheduledAnalysisError");
    });

    it("should create error with DATABASE type as retryable", () => {
      const error = new ScheduledAnalysisError(
        "Firestore unavailable",
        ScheduledAnalysisErrorType.DATABASE,
      );

      expect(error.type).toBe(ScheduledAnalysisErrorType.DATABASE);
      expect(error.isRetryable).toBe(true);
    });

    it("should create error with CONFIGURATION type as non-retryable", () => {
      const error = new ScheduledAnalysisError(
        "Invalid configuration",
        ScheduledAnalysisErrorType.CONFIGURATION,
      );

      expect(error.type).toBe(ScheduledAnalysisErrorType.CONFIGURATION);
      expect(error.isRetryable).toBe(false);
    });

    it("should create error with UNKNOWN type as non-retryable", () => {
      const error = new ScheduledAnalysisError(
        "Something went wrong",
        ScheduledAnalysisErrorType.UNKNOWN,
      );

      expect(error.type).toBe(ScheduledAnalysisErrorType.UNKNOWN);
      expect(error.isRetryable).toBe(false);
    });

    it("should store userId and ticker when provided", () => {
      const error = new ScheduledAnalysisError(
        "API error",
        ScheduledAnalysisErrorType.DATA_RETRIEVAL,
        { userId: "user123", ticker: "AAPL" },
      );

      expect(error.userId).toBe("user123");
      expect(error.ticker).toBe("AAPL");
    });

    it("should include cause error in stack trace when provided", () => {
      const cause = new Error("Original error");
      const error = new ScheduledAnalysisError(
        "Wrapped error",
        ScheduledAnalysisErrorType.DATA_RETRIEVAL,
        { cause },
      );

      expect(error.stack).toContain("Caused by:");
    });
  });

  describe("classifyError", () => {
    describe("DATA_RETRIEVAL errors", () => {
      it("should classify fetch errors as DATA_RETRIEVAL", () => {
        const error = new Error("fetch failed: ECONNREFUSED");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify network errors as DATA_RETRIEVAL", () => {
        const error = new Error("Network request failed");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify timeout errors as DATA_RETRIEVAL", () => {
        const error = new Error("Request timeout exceeded");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify Yahoo errors as DATA_RETRIEVAL", () => {
        const error = new Error("Yahoo Finance API error");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify API errors as DATA_RETRIEVAL", () => {
        const error = new Error("API returned 500");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify connection refused errors as DATA_RETRIEVAL", () => {
        const error = new Error("ECONNREFUSED");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify DNS errors as DATA_RETRIEVAL", () => {
        const error = new Error("ENOTFOUND");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify ETIMEDOUT errors as DATA_RETRIEVAL", () => {
        const error = new Error("ETIMEDOUT");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify rate limit errors as DATA_RETRIEVAL", () => {
        const error = new Error("Rate limit exceeded");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify HTTP 429 errors as DATA_RETRIEVAL", () => {
        const error = new Error("HTTP 429 Too Many Requests");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify HTTP 502 errors as DATA_RETRIEVAL", () => {
        const error = new Error("HTTP 502 Bad Gateway");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify HTTP 503 errors as DATA_RETRIEVAL", () => {
        const error = new Error("HTTP 503 Service Unavailable");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });

      it("should classify HTTP 504 errors as DATA_RETRIEVAL", () => {
        const error = new Error("HTTP 504 Gateway Timeout");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      });
    });

    describe("DATABASE errors", () => {
      it("should classify Firestore errors as DATABASE", () => {
        const error = new Error("Firestore operation failed");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATABASE);
      });

      it("should classify database errors as DATABASE", () => {
        const error = new Error("Database connection failed");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATABASE);
      });

      it("should classify permission denied errors as DATABASE", () => {
        const error = new Error("Permission denied");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATABASE);
      });

      it("should classify deadline exceeded errors as DATABASE", () => {
        const error = new Error("Deadline exceeded");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATABASE);
      });

      it("should classify unavailable errors as DATABASE", () => {
        const error = new Error("Service unavailable");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATABASE);
      });
    });

    describe("CONFIGURATION errors", () => {
      it("should classify config errors as CONFIGURATION", () => {
        const error = new Error("Config file not found");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.CONFIGURATION);
      });

      it("should classify invalid parameter errors as CONFIGURATION", () => {
        const error = new Error("Invalid parameter value");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.CONFIGURATION);
      });

      it("should classify validation errors as CONFIGURATION", () => {
        const error = new Error("Validation failed for input");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.CONFIGURATION);
      });
    });

    describe("UNKNOWN errors", () => {
      it("should classify generic errors as UNKNOWN", () => {
        const error = new Error("Something went wrong");
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.UNKNOWN);
      });

      it("should classify non-Error objects as UNKNOWN", () => {
        expect(classifyError("string error")).toBe(ScheduledAnalysisErrorType.UNKNOWN);
        expect(classifyError(42)).toBe(ScheduledAnalysisErrorType.UNKNOWN);
        expect(classifyError(null)).toBe(ScheduledAnalysisErrorType.UNKNOWN);
      });
    });

    describe("ScheduledAnalysisError passthrough", () => {
      it("should return the type from ScheduledAnalysisError directly", () => {
        const error = new ScheduledAnalysisError(
          "Test error",
          ScheduledAnalysisErrorType.DATABASE,
        );
        expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATABASE);
      });
    });
  });

  describe("isRetryableError", () => {
    describe("retryable errors", () => {
      it("should return true for DATA_RETRIEVAL errors", () => {
        const error = new Error("Fetch failed");
        expect(isRetryableError(error)).toBe(true);
      });

      it("should return true for DATABASE errors", () => {
        const error = new Error("Firestore error");
        expect(isRetryableError(error)).toBe(true);
      });

      it("should return true for ScheduledAnalysisError with DATA_RETRIEVAL type", () => {
        const error = new ScheduledAnalysisError(
          "API error",
          ScheduledAnalysisErrorType.DATA_RETRIEVAL,
        );
        expect(isRetryableError(error)).toBe(true);
      });

      it("should return true for ScheduledAnalysisError with DATABASE type", () => {
        const error = new ScheduledAnalysisError(
          "DB error",
          ScheduledAnalysisErrorType.DATABASE,
        );
        expect(isRetryableError(error)).toBe(true);
      });
    });

    describe("non-retryable errors", () => {
      it("should return false for CONFIGURATION errors", () => {
        const error = new Error("Invalid config value");
        expect(isRetryableError(error)).toBe(false);
      });

      it("should return false for UNKNOWN errors", () => {
        const error = new Error("Generic failure");
        expect(isRetryableError(error)).toBe(false);
      });

      it("should return false for ScheduledAnalysisError with CONFIGURATION type", () => {
        const error = new ScheduledAnalysisError(
          "Config error",
          ScheduledAnalysisErrorType.CONFIGURATION,
        );
        expect(isRetryableError(error)).toBe(false);
      });

      it("should return false for ScheduledAnalysisError with UNKNOWN type", () => {
        const error = new ScheduledAnalysisError(
          "Unknown error",
          ScheduledAnalysisErrorType.UNKNOWN,
        );
        expect(isRetryableError(error)).toBe(false);
      });
    });
  });

  describe("RETRY_DELAY_MS constant", () => {
    it("should be 2 minutes (120000 ms) as per Requirement 8.7", () => {
      expect(RETRY_DELAY_MS).toBe(2 * 60 * 1000);
      expect(RETRY_DELAY_MS).toBe(120000);
    });
  });

  describe("Error handling scenarios", () => {
    it("should handle case-insensitive error matching", () => {
      const lowerError = new Error("fetch failed");
      const upperError = new Error("FETCH FAILED");
      const mixedError = new Error("Fetch Failed");

      expect(classifyError(lowerError)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      expect(classifyError(upperError)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
      expect(classifyError(mixedError)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
    });

    it("should handle errors that match multiple patterns", () => {
      // Error containing both API and database keywords - API comes first in checks
      const error = new Error("API call to database failed");
      expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.DATA_RETRIEVAL);
    });

    it("should handle empty error messages", () => {
      const error = new Error("");
      expect(classifyError(error)).toBe(ScheduledAnalysisErrorType.UNKNOWN);
    });

    it("should handle undefined error", () => {
      expect(classifyError(undefined)).toBe(ScheduledAnalysisErrorType.UNKNOWN);
    });
  });
});
