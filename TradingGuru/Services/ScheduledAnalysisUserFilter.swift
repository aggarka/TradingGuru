//
//  ScheduledAnalysisUserFilter.swift
//  TradingGuru
//
//  Service for filtering users eligible for scheduled analysis execution.
//  Implements user eligibility logic per Requirement 8.2.
//

import Foundation

// MARK: - Scheduled Analysis User Data

/// Represents a user with their profile and watchlist for scheduled analysis eligibility checks.
/// This model is used to evaluate whether a user should be processed during scheduled analysis runs.
struct ScheduledAnalysisUserData: Equatable {
    /// The user's unique identifier
    let userId: String
    
    /// The user's settings including scheduledAnalysisEnabled flag
    let settings: UserSettings
    
    /// The user's watchlist containing ticker symbols
    let watchlist: Watchlist
    
    /// Creates a ScheduledAnalysisUserData instance.
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - settings: The user's settings
    ///   - watchlist: The user's watchlist
    init(
        userId: String,
        settings: UserSettings,
        watchlist: Watchlist
    ) {
        self.userId = userId
        self.settings = settings
        self.watchlist = watchlist
    }
}

// MARK: - Scheduled Analysis User Filter

/// Service for filtering users eligible for scheduled analysis execution.
/// - Validates: Requirement 8.2 (Run analysis for users with scheduledAnalysisEnabled=true AND watchlist.count > 0)
struct ScheduledAnalysisUserFilter {
    
    /// Checks if a single user is eligible for scheduled analysis.
    ///
    /// A user is eligible if and only if BOTH conditions are met:
    /// 1. `scheduledAnalysisEnabled == true` in their settings
    /// 2. `watchlist.count > 0` (they have at least one ticker in their watchlist)
    ///
    /// - Parameter user: The user data to check
    /// - Returns: `true` if the user is eligible, `false` otherwise
    /// - Validates: Requirement 8.2
    func isEligible(_ user: ScheduledAnalysisUserData) -> Bool {
        // Both conditions must be true
        let hasScheduledAnalysisEnabled = user.settings.scheduledAnalysisEnabled
        let hasWatchlistItems = user.watchlist.symbols.count > 0
        
        return hasScheduledAnalysisEnabled && hasWatchlistItems
    }
    
    /// Filters a set of users to return only those eligible for scheduled analysis.
    ///
    /// Users are eligible if and only if BOTH conditions are met:
    /// 1. `scheduledAnalysisEnabled == true` in their settings
    /// 2. `watchlist.count > 0` (they have at least one ticker in their watchlist)
    ///
    /// Users failing either condition are skipped (not included in the result).
    ///
    /// - Parameter users: Array of user data to filter
    /// - Returns: Array of eligible users only
    /// - Validates: Requirement 8.2
    func filterEligibleUsers(_ users: [ScheduledAnalysisUserData]) -> [ScheduledAnalysisUserData] {
        return users.filter { isEligible($0) }
    }
    
    /// Returns the list of users that were skipped (not eligible) for scheduled analysis.
    ///
    /// These are users failing at least one of the eligibility conditions:
    /// - `scheduledAnalysisEnabled == false`, OR
    /// - `watchlist.count == 0`
    ///
    /// - Parameter users: Array of user data to check
    /// - Returns: Array of ineligible (skipped) users
    /// - Validates: Requirement 8.2
    func filterSkippedUsers(_ users: [ScheduledAnalysisUserData]) -> [ScheduledAnalysisUserData] {
        return users.filter { !isEligible($0) }
    }
    
    /// Categorizes users into eligible and skipped groups.
    ///
    /// - Parameter users: Array of user data to categorize
    /// - Returns: Tuple containing (eligible users, skipped users)
    /// - Validates: Requirement 8.2
    func categorizeUsers(_ users: [ScheduledAnalysisUserData]) -> (eligible: [ScheduledAnalysisUserData], skipped: [ScheduledAnalysisUserData]) {
        var eligible: [ScheduledAnalysisUserData] = []
        var skipped: [ScheduledAnalysisUserData] = []
        
        for user in users {
            if isEligible(user) {
                eligible.append(user)
            } else {
                skipped.append(user)
            }
        }
        
        return (eligible, skipped)
    }
    
    /// Returns the reason a user is ineligible for scheduled analysis.
    ///
    /// - Parameter user: The user data to check
    /// - Returns: Nil if eligible, or a reason string if ineligible
    func ineligibilityReason(_ user: ScheduledAnalysisUserData) -> String? {
        let hasScheduledAnalysisEnabled = user.settings.scheduledAnalysisEnabled
        let hasWatchlistItems = user.watchlist.symbols.count > 0
        
        if !hasScheduledAnalysisEnabled && !hasWatchlistItems {
            return "Scheduled analysis disabled and empty watchlist"
        } else if !hasScheduledAnalysisEnabled {
            return "Scheduled analysis disabled"
        } else if !hasWatchlistItems {
            return "Empty watchlist"
        }
        
        return nil // Eligible
    }
}
