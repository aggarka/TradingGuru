/**
 * Jest Test Setup
 *
 * Configures the test environment for Cloud Functions testing.
 * Sets up Firebase Admin SDK mocks and test utilities.
 */

// Mock Firebase Admin SDK initialization
jest.mock("firebase-admin", () => {
  return {
    initializeApp: jest.fn(),
    firestore: jest.fn(() => ({
      collection: jest.fn(),
      doc: jest.fn(),
      batch: jest.fn(),
    })),
  };
});

// Set up environment variables for testing
process.env.GCLOUD_PROJECT = "tradingguru-test";
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: "tradingguru-test",
  databaseURL: "https://tradingguru-test.firebaseio.com",
});

// Global test utilities
beforeAll(() => {
  // Any global setup
});

afterAll(() => {
  // Any global cleanup
});

afterEach(() => {
  // Reset all mocks after each test
  jest.clearAllMocks();
});
