# TradingGuru Backend Service

Backend service for TradingGuru iOS app, built with Firebase Cloud Functions. Handles scheduled analysis execution, email notifications, and data persistence.

## Overview

This service implements:
- **Scheduled Analysis** (Requirement 8.1): Automatic strategy execution at 7 daily PST times
- **Email Notifications** (Requirements 9.1-9.11): Analysis result delivery to configured email addresses
- **Firestore Integration**: Data persistence for users, watchlists, configurations, and results

## Architecture

```
backend/
├── firebase.json          # Firebase project configuration
├── firestore.rules        # Firestore security rules
├── firestore.indexes.json # Firestore index definitions
├── .firebaserc           # Firebase project aliases
└── functions/
    ├── package.json      # NPM dependencies
    ├── tsconfig.json     # TypeScript configuration
    ├── jest.config.js    # Jest test configuration
    └── src/
        ├── index.ts      # Cloud Functions entry point
        ├── config/
        │   └── scheduledTimes.ts  # Schedule configuration
        ├── services/
        │   ├── firestoreService.ts      # Firestore operations
        │   └── scheduledAnalysisService.ts  # Analysis orchestration
        ├── types/
        │   └── index.ts  # TypeScript type definitions
        └── __tests__/
            ├── setup.ts  # Jest test setup
            └── scheduledTimes.test.ts
```

## Scheduled Analysis Times

Per Requirement 8.1, analysis runs at these PST times (Monday-Friday):

| Time | Description |
|------|-------------|
| 6:30 AM | Pre-market analysis |
| 6:45 AM | Pre-market analysis |
| 7:00 AM | Pre-market analysis |
| 9:00 AM | Market open analysis |
| 11:00 AM | Mid-morning analysis |
| 12:30 PM | Midday analysis |
| 12:45 PM | Midday analysis |

## Development Setup

### Prerequisites
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with Firestore and Cloud Functions enabled

### Installation

```bash
cd backend/functions
npm install
```

### Building

```bash
npm run build
```

### Running Tests

```bash
npm test
```

### Local Development (Emulators)

```bash
# From backend directory
firebase emulators:start
```

This starts:
- Functions emulator on port 5001
- Firestore emulator on port 8080
- Pub/Sub emulator on port 8085
- Emulator UI on port 4000

### Deployment

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:scheduledAnalysis_0630
```

## Environment Configuration

Set the following in Firebase Functions config:

```bash
# Email service configuration (for task 16)
firebase functions:config:set email.api_key="YOUR_SENDGRID_API_KEY"
firebase functions:config:set email.from_address="noreply@tradingguru.app"
```

## Firestore Collections

### Users Collection (`/users/{userId}`)
- `email`: string
- `displayName`: string
- `authProvider`: "google" | "apple" | "passkey"
- `createdAt`: Timestamp
- `lastLoginAt`: Timestamp
- `settings`: UserSettings object

### Watchlist Subcollection (`/users/{userId}/watchlist/{symbolId}`)
- `symbol`: string
- `addedAt`: Timestamp

### Configurations Subcollection (`/users/{userId}/configurations/{strategyId}`)
- `parameters`: Map
- `updatedAt`: Timestamp

### Results Subcollection (`/users/{userId}/results/{resultId}`)
- `ticker`: string
- `type`: "CALL" | "PUT"
- `returnPercentage`: number
- `currentPrice`: number
- `targetPrice`: number
- `signal`: "ORDER" | "HOLD"
- `nextEarningsDate`: Timestamp | null
- `hasEarningsRisk`: boolean
- `analyzedAt`: Timestamp
- `source`: "manual" | "scheduled"
- `scheduledRunId`: string | null

### Scheduled Runs Collection (`/scheduledRuns/{runId}`)
- `scheduledTime`: string
- `executedAt`: Timestamp
- `status`: "pending" | "running" | "completed" | "failed" | "retrying"
- `processedUsers`: number
- `totalUsers`: number
- `errors`: Array of error objects

## Requirements Mapping

| Requirement | Implementation |
|-------------|---------------|
| 8.1 | Cloud Scheduler triggers in `index.ts` |
| 8.2 | User filtering in `firestoreService.ts` |
| 8.3 | Result storage in `firestoreService.ts` |
| 8.7 | Retry logic in `scheduledAnalysisService.ts` |
| 9.1-9.11 | (Task 16 - Email service) |

## License

Proprietary - TradingGuru
