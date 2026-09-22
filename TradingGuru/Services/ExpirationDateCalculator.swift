//
//  ExpirationDateCalculator.swift
//  TradingGuru
//
//  Service for calculating weekly options expiration dates with market holiday awareness.
//  Implements the expiration date calculation algorithm for the Weekly Option Strategy.
//

import Foundation

// MARK: - Expiration Date Calculator

/// Calculates weekly option expiration dates with holiday awareness.
///
/// This calculator determines the next valid expiration date for weekly options,
/// typically the next Friday from the reference date. It handles special cases:
/// - Friday after market close (4 PM) moves to next Friday
/// - Saturday/Sunday skips to next week's Friday
/// - Market holidays on Friday fall back to Thursday
///
/// Usage:
/// ```swift
/// let calculator = ExpirationDateCalculator()
/// let expiration = calculator.calculateDefaultExpiration(from: Date())
/// ```
///
/// - Validates: Requirement 2.1 (Default expiration as next Friday)
/// - Validates: Requirement 2.6 (Skip to following week from weekend)
final class ExpirationDateCalculator: ExpirationDateCalculation {
    
    // MARK: - Properties
    
    /// The calendar used for date calculations.
    /// Defaults to the current calendar but can be injected for testing.
    private let calendar: Calendar
    
    /// Market close hour in 24-hour format (4 PM = 16).
    /// Used to determine if Friday has passed market close.
    private let marketCloseHour: Int = 16
    
    // MARK: - Initialization
    
    /// Creates a new ExpirationDateCalculator.
    /// - Parameter calendar: The calendar to use for date calculations. Defaults to `.current`.
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    // MARK: - ExpirationDateCalculation Protocol
    
    /// Calculates the default weekly expiration date from a reference date.
    ///
    /// The algorithm:
    /// 1. Find the next Friday from the reference date
    /// 2. If Friday is after market close, move to the following Friday
    /// 3. If Saturday or Sunday, skip to the following week's Friday
    /// 4. If Friday is a market holiday, fall back to Thursday
    /// 5. Normalize to midnight UTC for consistent API calls with Yahoo Finance
    ///
    /// - Parameter referenceDate: The date to calculate from (typically today)
    /// - Returns: The next valid expiration date (Friday, or Thursday if Friday is a holiday) at midnight UTC
    /// - Validates: Requirement 2.1 (Default expiration as next Friday)
    /// - Validates: Requirement 2.2 (Holiday fallback to Thursday)
    /// - Validates: Requirement 2.6 (Skip to following week from weekend)
    func calculateDefaultExpiration(from referenceDate: Date) -> Date {
        var targetDate = nextFriday(from: referenceDate)
        
        // If Friday is a holiday, use Thursday
        if isMarketHoliday(targetDate) {
            targetDate = calendar.date(byAdding: .day, value: -1, to: targetDate)!
        }
        
        // Normalize to midnight UTC for consistent timestamp matching with Yahoo Finance
        // Yahoo Finance expiration dates are always at 00:00:00 UTC
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        
        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        return utcCalendar.date(from: components) ?? calendar.startOfDay(for: targetDate)
    }
    
    /// Validates whether a date is a valid options expiration date.
    ///
    /// A valid expiration date must be:
    /// - A weekday (Monday through Friday)
    /// - Not a US market holiday
    ///
    /// - Parameter date: The date to validate
    /// - Returns: `true` if the date is a valid trading day, `false` otherwise
    /// - Validates: Requirement 3.6 (Valid trading day validation)
    func isValidExpirationDate(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        
        // Weekday must be Monday (2) through Friday (6)
        guard (2...6).contains(weekday) else {
            return false
        }
        
        // Must not be a market holiday
        return !isMarketHoliday(date)
    }
    
    /// Checks whether a date is a US market holiday.
    ///
    /// This method detects Friday holidays that affect weekly options expiration:
    /// - New Year's Day (January 1 on Friday, or December 31 if January 1 is Saturday)
    /// - Good Friday (varies by year, calculated from Easter Sunday)
    /// - Independence Day (July 4 on Friday, or July 3 if July 4 is Saturday)
    /// - Christmas Day (December 25 on Friday, or December 24 if December 25 is Saturday)
    ///
    /// Note: Only Friday holidays are checked because weekly options typically expire on Fridays.
    /// When a Friday is a holiday, the expiration moves to Thursday.
    ///
    /// - Parameter date: The date to check
    /// - Returns: `true` if the date is a US market holiday, `false` otherwise
    /// - Validates: Requirement 2.3 (Recognized market holidays on Fridays)
    /// - Validates: Requirement 2.4 (July 4 and Christmas on Saturday handling)
    /// - Validates: Requirement 2.5 (New Year's Day on Saturday handling)
    func isMarketHoliday(_ date: Date) -> Bool {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let year = calendar.component(.year, from: date)
        
        // Only check Fridays (weekday = 6 in Swift's Calendar)
        guard weekday == 6 else { return false }
        
        // New Year's Day: January 1 on Friday, or December 31 if January 1 is Saturday
        // Validates: Requirement 2.5
        if (month == 1 && day == 1) || (month == 12 && day == 31 && isNextDaySaturday(date)) {
            return true
        }
        
        // Good Friday: varies by year, always two days before Easter Sunday
        // Validates: Requirement 2.3
        if isGoodFriday(date, year: year) {
            return true
        }
        
        // Independence Day: July 4 on Friday, or July 3 if July 4 is Saturday
        // Validates: Requirement 2.4
        if (month == 7 && day == 4) || (month == 7 && day == 3 && isNextDaySaturday(date)) {
            return true
        }
        
        // Christmas Day: December 25 on Friday, or December 24 if December 25 is Saturday
        // Validates: Requirement 2.4
        if (month == 12 && day == 25) || (month == 12 && day == 24 && isNextDaySaturday(date)) {
            return true
        }
        
        return false
    }
    
    // MARK: - Holiday Helper Methods
    
    /// Checks if the day after the given date is a Saturday.
    ///
    /// Used for holiday observance rules: when certain holidays fall on Saturday,
    /// the preceding Friday is observed as the market holiday.
    ///
    /// - Parameter date: The date to check
    /// - Returns: `true` if the next day is Saturday (weekday = 7)
    private func isNextDaySaturday(_ date: Date) -> Bool {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
        return calendar.component(.weekday, from: nextDay) == 7
    }
    
    /// Checks if the given date is Good Friday.
    ///
    /// Good Friday is always the Friday before Easter Sunday (2 days prior).
    /// Easter Sunday is calculated using the Anonymous Gregorian algorithm.
    ///
    /// - Parameters:
    ///   - date: The date to check
    ///   - year: The year for Easter calculation
    /// - Returns: `true` if the date is Good Friday
    private func isGoodFriday(_ date: Date, year: Int) -> Bool {
        let easterDate = calculateEasterSunday(year: year)
        let goodFriday = calendar.date(byAdding: .day, value: -2, to: easterDate)!
        return calendar.isDate(date, inSameDayAs: goodFriday)
    }
    
    /// Calculates the date of Easter Sunday for a given year.
    ///
    /// Uses the Anonymous Gregorian algorithm (also known as the Meeus/Jones/Butcher algorithm)
    /// to compute Easter Sunday. This algorithm is valid for years 1583 and beyond.
    ///
    /// The algorithm computes Easter based on the lunar cycle and the spring equinox,
    /// accounting for the Gregorian calendar corrections.
    ///
    /// Reference: https://en.wikipedia.org/wiki/Date_of_Easter#Anonymous_Gregorian_algorithm
    ///
    /// - Parameter year: The year for which to calculate Easter Sunday
    /// - Returns: The date of Easter Sunday for the given year
    private func calculateEasterSunday(year: Int) -> Date {
        // Anonymous Gregorian algorithm
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    
    // MARK: - Private Helper Methods
    
    /// Finds the next Friday from the reference date.
    ///
    /// The algorithm handles special cases:
    /// - If reference date is Friday before market close: returns the same Friday
    /// - If reference date is Friday after market close: returns next Friday (7 days later)
    /// - If reference date is Saturday: returns next Friday (6 days later)
    /// - If reference date is Sunday: returns next Friday (5 days later)
    /// - For weekdays Monday-Thursday: returns the upcoming Friday of the same week
    ///
    /// In Swift's Calendar, weekday values are:
    /// - 1 = Sunday
    /// - 2 = Monday
    /// - 3 = Tuesday
    /// - 4 = Wednesday
    /// - 5 = Thursday
    /// - 6 = Friday
    /// - 7 = Saturday
    ///
    /// - Parameter date: The reference date
    /// - Returns: The next valid Friday for options expiration
    /// - Validates: Requirement 2.1 (Default expiration as next Friday)
    /// - Validates: Requirement 2.6 (Skip to following week if Saturday/Sunday)
    private func nextFriday(from date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        
        // Calculate days until next Friday (Friday = 6)
        var daysToAdd: Int
        switch weekday {
        case 1:  // Sunday
            daysToAdd = 5
        case 2:  // Monday
            daysToAdd = 4
        case 3:  // Tuesday
            daysToAdd = 3
        case 4:  // Wednesday
            daysToAdd = 2
        case 5:  // Thursday
            daysToAdd = 1
        case 6:  // Friday
            daysToAdd = 0
        case 7:  // Saturday - skip to next Friday
            daysToAdd = 6
        default:
            daysToAdd = 0
        }
        
        // If Friday but after market close, move to next Friday
        // Validates: Requirement 2.1 - handles Friday after market close case
        if weekday == 6 {
            let hour = calendar.component(.hour, from: date)
            if hour >= marketCloseHour {
                daysToAdd = 7
            }
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)!
    }
}
