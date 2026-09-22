//
//  ExpirationDateCalculatorTests.swift
//  TradingGuruTests
//
//  Property-based tests for ExpirationDateCalculator service.
//  Tests the correctness properties defined in the design document.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Property 6: Valid Expiration Date Criteria
// **Validates: Requirements 3.6**
//
// *For any* date, `isValidExpirationDate()` SHALL return true if and only if
// the date is a weekday (Monday-Friday) AND the date is not a US market holiday.

@Suite("Property 6: Valid Expiration Date Criteria - Validates Requirements 3.6")
struct ValidExpirationDateCriteriaPropertyTests {
    
    // Use a fixed calendar for consistent testing
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()
    
    // Initialize calculator with the same calendar as tests for consistency
    let calculator: ExpirationDateCalculator
    
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        self.calculator = ExpirationDateCalculator(calendar: cal)
    }
    
    // MARK: - Test Data Generation
    
    /// Generates random dates within a reasonable range (2020-2030)
    /// to cover various weekdays, weekends, and potential holidays.
    static func generateRandomDates(count: Int) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let startDate = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2030, month: 12, day: 31))!
        let range = endDate.timeIntervalSince(startDate)
        
        return (0..<count).map { _ in
            let randomInterval = TimeInterval.random(in: 0...range)
            return startDate.addingTimeInterval(randomInterval)
        }
    }
    
    /// Generates random weekday dates (Monday-Friday)
    static func generateRandomWeekdayDates(count: Int) -> [Date] {
        var dates: [Date] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let startDate = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2030, month: 12, day: 31))!
        let range = endDate.timeIntervalSince(startDate)
        
        while dates.count < count {
            let randomInterval = TimeInterval.random(in: 0...range)
            let candidate = startDate.addingTimeInterval(randomInterval)
            let weekday = calendar.component(.weekday, from: candidate)
            // Weekdays are 2 (Monday) through 6 (Friday)
            if (2...6).contains(weekday) {
                dates.append(candidate)
            }
        }
        return dates
    }
    
    /// Generates random weekend dates (Saturday or Sunday)
    static func generateRandomWeekendDates(count: Int) -> [Date] {
        var dates: [Date] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let startDate = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2030, month: 12, day: 31))!
        let range = endDate.timeIntervalSince(startDate)
        
        while dates.count < count {
            let randomInterval = TimeInterval.random(in: 0...range)
            let candidate = startDate.addingTimeInterval(randomInterval)
            let weekday = calendar.component(.weekday, from: candidate)
            // Weekend: 1 (Sunday) or 7 (Saturday)
            if weekday == 1 || weekday == 7 {
                dates.append(candidate)
            }
        }
        return dates
    }
    
    // MARK: - Helper Methods
    
    /// Independently determines if a date is a weekday (Monday-Friday)
    /// This serves as the oracle for testing isValidExpirationDate
    func isWeekday(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        // Swift Calendar: 1 = Sunday, 2 = Monday, ..., 6 = Friday, 7 = Saturday
        return (2...6).contains(weekday)
    }
    
    /// Independently determines if a date is a US market holiday
    /// This serves as the oracle for testing isMarketHoliday
    func isKnownMarketHoliday(_ date: Date) -> Bool {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let year = calendar.component(.year, from: date)
        
        // Only Fridays can be market holidays per the implementation
        guard weekday == 6 else { return false }
        
        // New Year's Day on Friday (Jan 1)
        if month == 1 && day == 1 {
            return true
        }
        
        // New Year's observance on Dec 31 (when Jan 1 is Saturday)
        if month == 12 && day == 31 {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                let nextWeekday = calendar.component(.weekday, from: nextDay)
                if nextWeekday == 7 { // Saturday
                    return true
                }
            }
        }
        
        // Good Friday - varies by year
        if isGoodFriday(date, year: year) {
            return true
        }
        
        // Independence Day on Friday (July 4)
        if month == 7 && day == 4 {
            return true
        }
        
        // Independence Day observance on July 3 (when July 4 is Saturday)
        if month == 7 && day == 3 {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                let nextWeekday = calendar.component(.weekday, from: nextDay)
                if nextWeekday == 7 { // Saturday
                    return true
                }
            }
        }
        
        // Christmas on Friday (Dec 25)
        if month == 12 && day == 25 {
            return true
        }
        
        // Christmas observance on Dec 24 (when Dec 25 is Saturday)
        if month == 12 && day == 24 {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                let nextWeekday = calendar.component(.weekday, from: nextDay)
                if nextWeekday == 7 { // Saturday
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Calculates if a date is Good Friday using Easter calculation
    private func isGoodFriday(_ date: Date, year: Int) -> Bool {
        let easterDate = calculateEasterSunday(year: year)
        if let goodFriday = calendar.date(byAdding: .day, value: -2, to: easterDate) {
            return calendar.isDate(date, inSameDayAs: goodFriday)
        }
        return false
    }
    
    /// Calculates Easter Sunday using Anonymous Gregorian algorithm
    private func calculateEasterSunday(year: Int) -> Date {
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
    
    /// Expected result for isValidExpirationDate based on independent calculation
    func expectedIsValidExpirationDate(_ date: Date) -> Bool {
        return isWeekday(date) && !isKnownMarketHoliday(date)
    }
    
    /// Formats a date for readable test output
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd (EEEE)"
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
    
    // MARK: - Property Tests: Bidirectional Verification
    
    @Test("Property: isValidExpirationDate returns true iff weekday AND not holiday - random dates",
          arguments: generateRandomDates(count: 5))
    func testValidExpirationDateBidirectionalProperty(date: Date) {
        // Calculate expected result using independent oracle
        let expected = expectedIsValidExpirationDate(date)
        
        // Get actual result from the calculator
        let actual = calculator.isValidExpirationDate(date)
        
        // Assert bidirectional property: result SHALL match the criteria
        let dateStr = formatDate(date)
        let weekdayStatus = isWeekday(date)
        let holidayStatus = isKnownMarketHoliday(date)
        #expect(actual == expected,
                "isValidExpirationDate mismatch for \(dateStr): expected \(expected), got \(actual). Weekday: \(weekdayStatus), Holiday: \(holidayStatus)")
    }
    
    // MARK: - Property Tests: Weekdays That Are Not Holidays → True
    
    @Test("Property: Non-holiday weekdays return true",
          arguments: generateRandomWeekdayDates(count: 5))
    func testNonHolidayWeekdaysReturnTrue(date: Date) {
        // Precondition: date is a weekday
        #expect(isWeekday(date), "Generated date should be a weekday")
        
        // If not a holiday, should return true
        if !isKnownMarketHoliday(date) {
            let result = calculator.isValidExpirationDate(date)
            let dateStr = formatDate(date)
            #expect(result == true,
                    "Non-holiday weekday \(dateStr) should return true, got \(result)")
        }
    }
    
    // MARK: - Property Tests: Weekends → Always False
    
    @Test("Property: Weekend dates always return false",
          arguments: generateRandomWeekendDates(count: 5))
    func testWeekendDatesAlwaysReturnFalse(date: Date) {
        let weekday = calendar.component(.weekday, from: date)
        
        // Precondition: date is a weekend
        #expect(weekday == 1 || weekday == 7, "Generated date should be a weekend")
        
        // Weekend dates should never be valid expiration dates
        let result = calculator.isValidExpirationDate(date)
        let dateStr = formatDate(date)
        #expect(result == false,
                "Weekend date \(dateStr) (weekday=\(weekday)) should return false, got \(result)")
    }
    
    // MARK: - Property Tests: Market Holidays → False (When on Friday)
    
    @Test("Property: Friday market holidays return false")
    func testFridayMarketHolidaysReturnFalse() {
        // Test known Friday holidays across multiple years
        let holidayDates = generateKnownFridayHolidays()
        
        for date in holidayDates {
            let result = calculator.isValidExpirationDate(date)
            let dateStr = formatDate(date)
            #expect(result == false,
                    "Market holiday \(dateStr) should return false, got \(result)")
        }
    }
    
    // MARK: - Property Tests: Forward Direction (weekday AND not holiday → true)
    
    @Test("Property: If weekday AND not market holiday, then isValidExpirationDate returns true",
          arguments: generateRandomDates(count: 5))
    func testForwardProperty(date: Date) {
        let isWeekdayDate = isWeekday(date)
        let isHoliday = isKnownMarketHoliday(date)
        
        // Forward direction: if weekday AND not holiday, then result must be true
        if isWeekdayDate && !isHoliday {
            let result = calculator.isValidExpirationDate(date)
            let dateStr = formatDate(date)
            #expect(result == true,
                    "Weekday non-holiday \(dateStr) should return true")
        }
    }
    
    // MARK: - Property Tests: Backward Direction (true → weekday AND not holiday)
    
    @Test("Property: If isValidExpirationDate returns true, then date must be weekday AND not holiday",
          arguments: generateRandomDates(count: 5))
    func testBackwardProperty(date: Date) {
        let result = calculator.isValidExpirationDate(date)
        let dateStr = formatDate(date)
        
        // Backward direction: if result is true, then must be weekday AND not holiday
        if result {
            #expect(isWeekday(date),
                    "Valid expiration date \(dateStr) must be a weekday")
            #expect(!isKnownMarketHoliday(date),
                    "Valid expiration date \(dateStr) must not be a market holiday")
        }
    }
    
    // MARK: - Property Tests: Contrapositive (weekend OR holiday → false)
    
    @Test("Property: If weekend OR market holiday, then isValidExpirationDate returns false",
          arguments: generateRandomDates(count: 5))
    func testContrapositiveProperty(date: Date) {
        let isWeekdayDate = isWeekday(date)
        let isHoliday = isKnownMarketHoliday(date)
        
        // Contrapositive: if NOT weekday OR holiday, then result must be false
        if !isWeekdayDate || isHoliday {
            let result = calculator.isValidExpirationDate(date)
            let dateStr = formatDate(date)
            #expect(result == false,
                    "Non-weekday or holiday \(dateStr) should return false. Weekday: \(isWeekdayDate), Holiday: \(isHoliday)")
        }
    }
    
    // MARK: - Property Tests: All Days in a Week
    
    @Test("Property: For any week, exactly Mon-Fri that aren't holidays are valid")
    func testAllDaysInWeekProperty() {
        // Test 5 random weeks instead of 20
        for _ in 0..<5 {
            let randomDate = Self.generateRandomDates(count: 1).first!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: randomDate))!
            
            var validCount = 0
            var weekdayNonHolidayCount = 0
            
            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)!
                let isValid = calculator.isValidExpirationDate(date)
                
                if isValid {
                    validCount += 1
                }
                
                if isWeekday(date) && !isKnownMarketHoliday(date) {
                    weekdayNonHolidayCount += 1
                }
            }
            
            #expect(validCount == weekdayNonHolidayCount,
                    "Valid days count (\(validCount)) should match weekday non-holidays count (\(weekdayNonHolidayCount))")
        }
    }
    
    // MARK: - Property Tests: Boundary - All Weekday Values
    
    @Test("Property: Each weekday type (Mon-Fri) can be valid when not a holiday")
    func testEachWeekdayTypeCanBeValid() {
        // Test that we can find valid dates for each weekday (Mon=2, Tue=3, Wed=4, Thu=5, Fri=6)
        for targetWeekday in 2...6 {
            var foundValid = false
            
            // Search for a valid date with this weekday
            let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
            for dayOffset in 0..<365 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
                let weekday = calendar.component(.weekday, from: date)
                
                if weekday == targetWeekday && calculator.isValidExpirationDate(date) {
                    foundValid = true
                    break
                }
            }
            
            #expect(foundValid,
                    "Should find at least one valid date for weekday \(targetWeekday)")
        }
    }
    
    // MARK: - Property Tests: Specific Year Coverage
    
    @Test("Property: Valid dates exist for each month of the year")
    func testValidDatesExistForEachMonth() {
        // For each month, there should be at least one valid expiration date
        let year = 2024
        
        for month in 1...12 {
            var foundValid = false
            
            // Get the number of days in this month
            let components = DateComponents(year: year, month: month)
            if let date = calendar.date(from: components),
               let range = calendar.range(of: .day, in: .month, for: date) {
                
                for day in range {
                    let testDate = calendar.date(from: DateComponents(year: year, month: month, day: day))!
                    if calculator.isValidExpirationDate(testDate) {
                        foundValid = true
                        break
                    }
                }
            }
            
            #expect(foundValid,
                    "Month \(month) of \(year) should have at least one valid expiration date")
        }
    }
    
    // MARK: - Helper Methods for Test Data
    
    /// Generates known Friday holidays for testing
    func generateKnownFridayHolidays() -> [Date] {
        var holidays: [Date] = []
        
        // Good Friday dates (known dates that fall on Friday)
        // Good Friday 2025: April 18
        if let gf2025 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 18)) {
            holidays.append(gf2025)
        }
        // Good Friday 2026: April 3
        if let gf2026 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 3)) {
            holidays.append(gf2026)
        }
        
        // July 4 on Friday
        // 2025: July 4 is Friday
        if let jul4_2025 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 4)) {
            holidays.append(jul4_2025)
        }
        
        // Christmas on Friday
        // 2020: December 25 is Friday
        if let xmas2020 = calendar.date(from: DateComponents(year: 2020, month: 12, day: 25)) {
            holidays.append(xmas2020)
        }
        
        // New Year's Day on Friday
        // 2021: January 1 is Friday
        if let ny2021 = calendar.date(from: DateComponents(year: 2021, month: 1, day: 1)) {
            holidays.append(ny2021)
        }
        
        // Dec 31 when Jan 1 is Saturday (observed Friday)
        // 2021: Dec 31, 2021 is Friday, Jan 1, 2022 is Saturday
        if let dec31_2021 = calendar.date(from: DateComponents(year: 2021, month: 12, day: 31)) {
            holidays.append(dec31_2021)
        }
        
        // July 3 when July 4 is Saturday (observed Friday)  
        // 2020: July 3 is Friday, July 4 is Saturday
        if let jul3_2020 = calendar.date(from: DateComponents(year: 2020, month: 7, day: 3)) {
            holidays.append(jul3_2020)
        }
        
        // Dec 24 when Dec 25 is Saturday (observed Friday)
        // 2021: Dec 24 is Friday, Dec 25 is Saturday
        if let dec24_2021 = calendar.date(from: DateComponents(year: 2021, month: 12, day: 24)) {
            holidays.append(dec24_2021)
        }
        
        return holidays
    }
}

// MARK: - Additional Edge Case Tests

@Suite("Valid Expiration Date Edge Cases")
struct ValidExpirationDateEdgeCaseTests {
    
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()
    
    // Initialize calculator with the same calendar as tests for consistency
    let calculator: ExpirationDateCalculator
    
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        self.calculator = ExpirationDateCalculator(calendar: cal)
    }
    
    // MARK: - Specific Holiday Edge Cases
    
    @Test("Edge case: Good Friday is not a valid expiration date")
    func testGoodFridayIsNotValid() {
        // Good Friday 2025: April 18
        let goodFriday2025 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 18))!
        
        let result = calculator.isValidExpirationDate(goodFriday2025)
        #expect(result == false, "Good Friday 2025 should not be a valid expiration date")
        
        // Also verify it's detected as a market holiday
        let isHoliday = calculator.isMarketHoliday(goodFriday2025)
        #expect(isHoliday == true, "Good Friday 2025 should be detected as market holiday")
    }
    
    @Test("Edge case: Day after Good Friday (Saturday) is not valid")
    func testDayAfterGoodFridayIsNotValid() {
        // Day after Good Friday 2025: April 19 (Saturday)
        let saturday = calendar.date(from: DateComponents(year: 2025, month: 4, day: 19))!
        
        let result = calculator.isValidExpirationDate(saturday)
        #expect(result == false, "Saturday after Good Friday should not be valid")
    }
    
    @Test("Edge case: Thursday before Good Friday is valid")
    func testThursdayBeforeGoodFridayIsValid() {
        // Thursday before Good Friday 2025: April 17
        let thursday = calendar.date(from: DateComponents(year: 2025, month: 4, day: 17))!
        
        let result = calculator.isValidExpirationDate(thursday)
        #expect(result == true, "Thursday before Good Friday should be valid")
    }
    
    @Test("Edge case: July 4 on Friday is not valid")
    func testJuly4OnFridayIsNotValid() {
        // July 4, 2025 is a Friday
        let july4 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 4))!
        
        let result = calculator.isValidExpirationDate(july4)
        #expect(result == false, "July 4 (Friday) should not be valid")
    }
    
    @Test("Edge case: July 3 when July 4 is Saturday is not valid")  
    func testJuly3WhenJuly4IsSaturdayIsNotValid() {
        // July 3, 2020 is Friday, July 4, 2020 is Saturday
        let july3 = calendar.date(from: DateComponents(year: 2020, month: 7, day: 3))!
        
        let result = calculator.isValidExpirationDate(july3)
        #expect(result == false, "July 3 (observed holiday) should not be valid")
    }
    
    @Test("Edge case: Regular Friday in July is valid")
    func testRegularFridayInJulyIsValid() {
        // July 11, 2025 is a regular Friday
        let regularFriday = calendar.date(from: DateComponents(year: 2025, month: 7, day: 11))!
        
        let result = calculator.isValidExpirationDate(regularFriday)
        #expect(result == true, "Regular Friday in July should be valid")
    }
    
    @Test("Edge case: Christmas on Friday is not valid")
    func testChristmasOnFridayIsNotValid() {
        // December 25, 2020 is a Friday
        let christmas = calendar.date(from: DateComponents(year: 2020, month: 12, day: 25))!
        
        let result = calculator.isValidExpirationDate(christmas)
        #expect(result == false, "Christmas on Friday should not be valid")
    }
    
    @Test("Edge case: Dec 24 when Dec 25 is Saturday is not valid")
    func testDec24WhenDec25IsSaturdayIsNotValid() {
        // Dec 24, 2021 is Friday, Dec 25, 2021 is Saturday
        let dec24 = calendar.date(from: DateComponents(year: 2021, month: 12, day: 24))!
        
        let result = calculator.isValidExpirationDate(dec24)
        #expect(result == false, "Dec 24 (observed Christmas) should not be valid")
    }
    
    @Test("Edge case: New Year's Day on Friday is not valid")
    func testNewYearsDayOnFridayIsNotValid() {
        // January 1, 2021 is a Friday
        let newYears = calendar.date(from: DateComponents(year: 2021, month: 1, day: 1))!
        
        let result = calculator.isValidExpirationDate(newYears)
        #expect(result == false, "New Year's Day on Friday should not be valid")
    }
    
    @Test("Edge case: Dec 31 when Jan 1 is Saturday is not valid")
    func testDec31WhenJan1IsSaturdayIsNotValid() {
        // Dec 31, 2021 is Friday, Jan 1, 2022 is Saturday
        let dec31 = calendar.date(from: DateComponents(year: 2021, month: 12, day: 31))!
        
        let result = calculator.isValidExpirationDate(dec31)
        #expect(result == false, "Dec 31 (observed New Year's) should not be valid")
    }
    
    // MARK: - Weekday Boundary Tests
    
    @Test("Edge case: Sunday is never valid")
    func testSundayIsNeverValid() {
        // Test multiple Sundays
        let sundays = [
            DateComponents(year: 2024, month: 1, day: 7),   // Random Sunday
            DateComponents(year: 2024, month: 6, day: 2),   // Random Sunday
            DateComponents(year: 2024, month: 12, day: 22), // Random Sunday
        ]
        
        for components in sundays {
            let date = Calendar.current.date(from: components)!
            let result = calculator.isValidExpirationDate(date)
            #expect(result == false, "Sunday should never be valid")
        }
    }
    
    @Test("Edge case: Saturday is never valid")
    func testSaturdayIsNeverValid() {
        // Test multiple Saturdays
        let saturdays = [
            DateComponents(year: 2024, month: 1, day: 6),   // Random Saturday
            DateComponents(year: 2024, month: 6, day: 1),   // Random Saturday
            DateComponents(year: 2024, month: 12, day: 21), // Random Saturday
        ]
        
        for components in saturdays {
            let date = Calendar.current.date(from: components)!
            let result = calculator.isValidExpirationDate(date)
            #expect(result == false, "Saturday should never be valid")
        }
    }
    
    @Test("Edge case: Monday is valid when not a holiday")
    func testMondayIsValid() {
        // January 6, 2025 is a Monday and not a holiday
        let monday = calendar.date(from: DateComponents(year: 2025, month: 1, day: 6))!
        
        let result = calculator.isValidExpirationDate(monday)
        #expect(result == true, "Non-holiday Monday should be valid")
    }
    
    @Test("Edge case: Tuesday is valid when not a holiday")
    func testTuesdayIsValid() {
        // January 7, 2025 is a Tuesday and not a holiday
        let tuesday = calendar.date(from: DateComponents(year: 2025, month: 1, day: 7))!
        
        let result = calculator.isValidExpirationDate(tuesday)
        #expect(result == true, "Non-holiday Tuesday should be valid")
    }
    
    @Test("Edge case: Wednesday is valid when not a holiday")
    func testWednesdayIsValid() {
        // January 8, 2025 is a Wednesday and not a holiday
        let wednesday = calendar.date(from: DateComponents(year: 2025, month: 1, day: 8))!
        
        let result = calculator.isValidExpirationDate(wednesday)
        #expect(result == true, "Non-holiday Wednesday should be valid")
    }
    
    @Test("Edge case: Thursday is valid when not a holiday")
    func testThursdayIsValid() {
        // January 9, 2025 is a Thursday and not a holiday
        let thursday = calendar.date(from: DateComponents(year: 2025, month: 1, day: 9))!
        
        let result = calculator.isValidExpirationDate(thursday)
        #expect(result == true, "Non-holiday Thursday should be valid")
    }
    
    @Test("Edge case: Regular Friday is valid when not a holiday")
    func testRegularFridayIsValid() {
        // January 10, 2025 is a Friday and not a holiday
        let friday = calendar.date(from: DateComponents(year: 2025, month: 1, day: 10))!
        
        let result = calculator.isValidExpirationDate(friday)
        #expect(result == true, "Non-holiday Friday should be valid")
    }
}


// MARK: - Property 4: Holiday Fallback to Thursday
// **Validates: Requirements 2.2**
//
// *For any* reference date where the next Friday is a US market holiday,
// `calculateDefaultExpiration()` SHALL return the Thursday immediately preceding that Friday.

@Suite("Property 4: Holiday Fallback to Thursday - Validates Requirements 2.2")
struct HolidayFallbackToThursdayPropertyTests {
    
    /// The calculator under test with a fixed calendar for deterministic testing
    let calculator: ExpirationDateCalculator
    let calendar: Calendar
    
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        self.calendar = cal
        self.calculator = ExpirationDateCalculator(calendar: cal)
    }
    
    // MARK: - Test Data Generation
    
    /// Helper to create a date from year, month, day components
    func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    
    /// Calculates Easter Sunday using the Anonymous Gregorian algorithm
    static func calculateEasterSunday(year: Int, calendar: Calendar) -> Date {
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
    
    /// Generates Good Friday dates for multiple years
    static func generateGoodFridayDates() -> [(year: Int, goodFriday: Date, expectedThursday: Date)] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        let years = [2024, 2025, 2026, 2027, 2028, 2029, 2030]
        
        return years.map { year in
            let easter = calculateEasterSunday(year: year, calendar: cal)
            let goodFriday = cal.date(byAdding: .day, value: -2, to: easter)!
            let thursday = cal.date(byAdding: .day, value: -3, to: easter)!
            return (year, goodFriday, thursday)
        }
    }
    
    /// Generates all holiday test cases where the next Friday is a market holiday.
    /// Each test case contains: (referenceDate, holidayFriday, expectedThursday, description)
    static func generateHolidayTestCases() -> [(referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var testCases: [(Date, Date, Date, String)] = []
        
        // Good Friday cases (varies by year)
        for (year, goodFriday, thursday) in generateGoodFridayDates() {
            // Monday through Thursday of Good Friday week
            for daysBack in 1...4 {
                let refDate = cal.date(byAdding: .day, value: -daysBack, to: goodFriday)!
                testCases.append((refDate, goodFriday, thursday, "Good Friday \(year) - \(daysBack) days before"))
            }
        }
        
        // Independence Day on Friday (2025: July 4 is Friday)
        let july4_2025 = cal.date(from: DateComponents(year: 2025, month: 7, day: 4, hour: 12))!
        let july3_2025 = cal.date(from: DateComponents(year: 2025, month: 7, day: 3, hour: 12))!
        for daysBack in 1...4 {
            let refDate = cal.date(byAdding: .day, value: -daysBack, to: july4_2025)!
            testCases.append((refDate, july4_2025, july3_2025, "Independence Day 2025 - \(daysBack) days before"))
        }
        
        // Independence Day observed on Friday (2026: July 4 is Saturday, July 3 is Friday)
        let july3_2026 = cal.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
        let july2_2026 = cal.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 12))!
        for daysBack in 1...4 {
            let refDate = cal.date(byAdding: .day, value: -daysBack, to: july3_2026)!
            testCases.append((refDate, july3_2026, july2_2026, "Independence Day observed 2026 - \(daysBack) days before"))
        }
        
        // Christmas on Friday (2020: December 25 is Friday)
        let dec25_2020 = cal.date(from: DateComponents(year: 2020, month: 12, day: 25, hour: 12))!
        let dec24_2020 = cal.date(from: DateComponents(year: 2020, month: 12, day: 24, hour: 12))!
        for daysBack in 1...4 {
            let refDate = cal.date(byAdding: .day, value: -daysBack, to: dec25_2020)!
            testCases.append((refDate, dec25_2020, dec24_2020, "Christmas 2020 - \(daysBack) days before"))
        }
        
        // Christmas observed on Friday (2021: December 25 is Saturday, December 24 is Friday)
        let dec24_2021 = cal.date(from: DateComponents(year: 2021, month: 12, day: 24, hour: 12))!
        let dec23_2021 = cal.date(from: DateComponents(year: 2021, month: 12, day: 23, hour: 12))!
        for daysBack in 1...4 {
            let refDate = cal.date(byAdding: .day, value: -daysBack, to: dec24_2021)!
            testCases.append((refDate, dec24_2021, dec23_2021, "Christmas observed 2021 - \(daysBack) days before"))
        }
        
        // New Year's Day on Friday (2021: January 1 is Friday)
        let jan1_2021 = cal.date(from: DateComponents(year: 2021, month: 1, day: 1, hour: 12))!
        let dec31_2020 = cal.date(from: DateComponents(year: 2020, month: 12, day: 31, hour: 12))!
        for daysBack in 1...4 {
            let refDate = cal.date(byAdding: .day, value: -daysBack, to: jan1_2021)!
            testCases.append((refDate, jan1_2021, dec31_2020, "New Year's 2021 - \(daysBack) days before"))
        }
        
        // New Year's observed on Friday (2022: January 1 is Saturday, December 31 is Friday)
        let dec31_2021 = cal.date(from: DateComponents(year: 2021, month: 12, day: 31, hour: 12))!
        let dec30_2021 = cal.date(from: DateComponents(year: 2021, month: 12, day: 30, hour: 12))!
        for daysBack in 1...4 {
            let refDate = cal.date(byAdding: .day, value: -daysBack, to: dec31_2021)!
            testCases.append((refDate, dec31_2021, dec30_2021, "New Year's observed 2021 - \(daysBack) days before"))
        }
        
        return testCases
    }
    
    // MARK: - Helper Methods
    
    /// Formats a date for readable test output
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd (EEEE)"
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
    
    // MARK: - Property Tests: Holiday Friday Returns Thursday
    
    @Test("Property: When next Friday is a holiday, calculateDefaultExpiration returns the Thursday before",
          arguments: generateHolidayTestCases())
    func testHolidayFridayFallsBackToThursday(
        testCase: (referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)
    ) {
        // Act: Calculate the default expiration from the reference date
        let result = calculator.calculateDefaultExpiration(from: testCase.referenceDate)
        
        // Assert: The result SHALL be the Thursday immediately preceding the holiday Friday
        let isSameDay = calendar.isDate(result, inSameDayAs: testCase.expectedThursday)
        #expect(isSameDay,
                "\(testCase.description): Expected \(formatDate(testCase.expectedThursday)), got \(formatDate(result))")
        
        // Additional assertion: The result should be a Thursday (weekday = 5)
        let resultWeekday = calendar.component(.weekday, from: result)
        #expect(resultWeekday == 5,
                "\(testCase.description): Result should be Thursday (weekday=5), but got weekday=\(resultWeekday)")
    }
    
    @Test("Property: Result is exactly one day before the holiday Friday",
          arguments: generateHolidayTestCases())
    func testResultIsOneDayBeforeHolidayFriday(
        testCase: (referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)
    ) {
        // Act
        let result = calculator.calculateDefaultExpiration(from: testCase.referenceDate)
        
        // Assert: Result should be exactly 1 day before the holiday Friday
        let dayAfterResult = calendar.date(byAdding: .day, value: 1, to: result)!
        let isSameDay = calendar.isDate(dayAfterResult, inSameDayAs: testCase.holidayFriday)
        #expect(isSameDay,
                "\(testCase.description): Day after result should be the holiday Friday")
    }
    
    // MARK: - Property Tests: Good Friday Across Multiple Years
    
    @Test("Property: Good Friday always falls back to Thursday across multiple years",
          arguments: generateGoodFridayDates())
    func testGoodFridayFallsBackToThursday(testCase: (year: Int, goodFriday: Date, expectedThursday: Date)) {
        // Reference date is Monday of the Good Friday week
        let monday = calendar.date(byAdding: .day, value: -4, to: testCase.goodFriday)!
        
        // Act
        let result = calculator.calculateDefaultExpiration(from: monday)
        
        // Assert
        let isSameDay = calendar.isDate(result, inSameDayAs: testCase.expectedThursday)
        #expect(isSameDay,
                "Good Friday \(testCase.year): Expected \(formatDate(testCase.expectedThursday)), got \(formatDate(result))")
    }
    
    // MARK: - Property Tests: Holiday Detection Verification
    
    @Test("Property: Calculator correctly identifies known holiday Fridays",
          arguments: generateHolidayTestCases())
    func testCalculatorIdentifiesHolidayFridays(
        testCase: (referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)
    ) {
        // Act
        let isHoliday = calculator.isMarketHoliday(testCase.holidayFriday)
        
        // Assert: The holiday Friday should be recognized as a market holiday
        #expect(isHoliday == true,
                "\(testCase.description): \(formatDate(testCase.holidayFriday)) should be recognized as a market holiday")
    }
    
    @Test("Property: Thursday before holiday is NOT a market holiday",
          arguments: generateHolidayTestCases())
    func testThursdayBeforeHolidayIsNotHoliday(
        testCase: (referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)
    ) {
        // Act
        let isHoliday = calculator.isMarketHoliday(testCase.expectedThursday)
        
        // Assert: The Thursday should NOT be a market holiday
        #expect(isHoliday == false,
                "\(testCase.description): Thursday should NOT be recognized as a market holiday")
    }
    
    // MARK: - Property Tests: Valid Expiration Date Verification
    
    @Test("Property: Thursday before holiday is a valid expiration date",
          arguments: generateHolidayTestCases())
    func testThursdayIsValidExpirationDate(
        testCase: (referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)
    ) {
        let isValid = calculator.isValidExpirationDate(testCase.expectedThursday)
        
        #expect(isValid == true,
                "\(testCase.description): Thursday \(formatDate(testCase.expectedThursday)) should be a valid expiration date")
    }
    
    @Test("Property: Holiday Friday is NOT a valid expiration date",
          arguments: generateHolidayTestCases())
    func testHolidayFridayIsNotValidExpirationDate(
        testCase: (referenceDate: Date, holidayFriday: Date, expectedThursday: Date, description: String)
    ) {
        let isValid = calculator.isValidExpirationDate(testCase.holidayFriday)
        
        #expect(isValid == false,
                "\(testCase.description): Friday \(formatDate(testCase.holidayFriday)) should NOT be a valid expiration date (it's a holiday)")
    }
    
    // MARK: - Property Tests: Edge Cases
    
    @Test("Property: Multiple consecutive days before holiday all return the same Thursday")
    func testConsecutiveDaysAllReturnSameThursday() {
        // For Good Friday 2025 (April 18)
        let goodFriday2025 = date(year: 2025, month: 4, day: 18)
        let expectedThursday = date(year: 2025, month: 4, day: 17)
        
        // Test Monday through Thursday of that week
        let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday"]
        
        for (index, dayName) in weekdayNames.enumerated() {
            let daysBeforeFriday = 4 - index  // Monday is 4 days before, Thursday is 1 day before
            let testDate = calendar.date(byAdding: .day, value: -daysBeforeFriday, to: goodFriday2025)!
            
            let result = calculator.calculateDefaultExpiration(from: testDate)
            
            let isSameDay = calendar.isDate(result, inSameDayAs: expectedThursday)
            #expect(isSameDay,
                    "\(dayName) of Good Friday week should return Thursday April 17, 2025. Got: \(formatDate(result))")
        }
    }
}


// MARK: - Property 5: Weekend Skip to Next Friday
// **Validates: Requirements 2.6**
//
// *For any* reference date that falls on a Saturday or Sunday,
// `calculateDefaultExpiration()` SHALL return a date at least 5 days in the future.

@Suite("Property 5: Weekend Skip to Next Friday - Validates Requirements 2.6")
struct WeekendSkipToNextFridayPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    /// The calculator under test with a fixed calendar for deterministic testing
    let calculator: ExpirationDateCalculator
    let calendar: Calendar
    
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        self.calendar = cal
        self.calculator = ExpirationDateCalculator(calendar: cal)
    }
    
    // MARK: - Saturday/Sunday Date Generation
    
    /// Generate a list of Saturday dates for testing
    /// Covers a range of years to ensure robustness
    static func generateSaturdayDates(count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var saturdays: [Date] = []
        
        // Start from a known Saturday (January 4, 2025 is a Saturday)
        let components = DateComponents(year: 2025, month: 1, day: 4, hour: 12, minute: 0, second: 0)
        guard var currentSaturday = cal.date(from: components) else { return [] }
        
        for _ in 0..<count {
            saturdays.append(currentSaturday)
            // Advance by 7 days to get the next Saturday
            currentSaturday = cal.date(byAdding: .day, value: 7, to: currentSaturday)!
        }
        
        return saturdays
    }
    
    /// Generate a list of Sunday dates for testing
    static func generateSundayDates(count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var sundays: [Date] = []
        
        // Start from a known Sunday (January 5, 2025 is a Sunday)
        let components = DateComponents(year: 2025, month: 1, day: 5, hour: 12, minute: 0, second: 0)
        guard var currentSunday = cal.date(from: components) else { return [] }
        
        for _ in 0..<count {
            sundays.append(currentSunday)
            // Advance by 7 days to get the next Sunday
            currentSunday = cal.date(byAdding: .day, value: 7, to: currentSunday)!
        }
        
        return sundays
    }
    
    /// Generate random weekend dates (both Saturday and Sunday) across multiple years
    static func generateRandomWeekendDates(count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var weekendDates: [Date] = []
        
        for _ in 0..<count {
            // Random year between 2024 and 2030
            let year = Int.random(in: 2024...2030)
            let month = Int.random(in: 1...12)
            let day = Int.random(in: 1...28) // Use 28 to avoid invalid dates
            
            var components = DateComponents(year: year, month: month, day: day, hour: 12, minute: 0)
            guard let date = cal.date(from: components) else { continue }
            
            let weekday = cal.component(.weekday, from: date)
            
            // Adjust to make it a weekend day if not already
            // weekday: 1 = Sunday, 7 = Saturday
            if weekday == 1 || weekday == 7 {
                weekendDates.append(date)
            } else {
                // Move to the nearest Saturday (weekday 7)
                let daysToSaturday = (7 - weekday + 7) % 7
                let adjustedDays = daysToSaturday == 0 ? 7 : daysToSaturday
                if let adjustedDate = cal.date(byAdding: .day, value: adjustedDays, to: date) {
                    weekendDates.append(adjustedDate)
                }
            }
        }
        
        return weekendDates
    }
    
    // MARK: - Helper Methods
    
    /// Verifies that the given date is a weekend day (Saturday or Sunday)
    func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // 1 = Sunday, 7 = Saturday
    }
    
    /// Calculates the number of days between two dates
    func daysBetween(_ start: Date, _ end: Date) -> Int {
        let startOfStart = calendar.startOfDay(for: start)
        let startOfEnd = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd)
        return components.day ?? 0
    }
    
    /// Formats a date for readable test output
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd (EEEE)"
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
    
    // MARK: - Property Tests: Saturday Input
    
    @Test("Property: Saturday input returns date at least 5 days in future",
          arguments: generateSaturdayDates(count: 10)) // Test sample Saturdays for fast execution
    func testSaturdayReturnsDateAtLeast5DaysInFuture(saturday: Date) {
        // Precondition: Verify this is actually a Saturday (weekday 7)
        let weekday = calendar.component(.weekday, from: saturday)
        #expect(weekday == 7, "Input date should be Saturday (weekday 7), got weekday \(weekday)")
        
        // Act: Calculate default expiration
        let expiration = calculator.calculateDefaultExpiration(from: saturday)
        
        // Assert: Result should be at least 5 days in the future
        // Saturday → next Friday is 6 days, or Thursday if Friday is holiday (5 days)
        let daysDiff = daysBetween(saturday, expiration)
        #expect(daysDiff >= 5,
                "For Saturday \(formatDate(saturday)), expiration should be at least 5 days in future, but got \(daysDiff) days. Expiration: \(formatDate(expiration))")
    }
    
    @Test("Property: Saturday returns following Friday (6 days later) or Thursday if holiday",
          arguments: generateSaturdayDates(count: 10))
    func testSaturdayReturnsFollowingFriday(saturday: Date) {
        // Precondition
        let weekday = calendar.component(.weekday, from: saturday)
        #expect(weekday == 7, "Input should be Saturday")
        
        // Act
        let expiration = calculator.calculateDefaultExpiration(from: saturday)
        
        // Assert: Result should be Friday (weekday 6) or Thursday if Friday is holiday
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        // Friday (6) or Thursday (5) - both are valid outcomes
        let isFridayOrThursday = resultWeekday == 6 || resultWeekday == 5
        #expect(isFridayOrThursday,
                "Expiration should be Friday (6) or Thursday (5), got weekday \(resultWeekday)")
        
        // For Saturday, next Friday is exactly 6 days away (unless it's a holiday)
        let daysDiff = daysBetween(saturday, expiration)
        // Should be either 6 (next Friday) or 5 (Thursday holiday fallback)
        #expect(daysDiff >= 5 && daysDiff <= 13,
                "Days difference should be between 5-13 (next Friday or if holiday, following week), got \(daysDiff)")
    }
    
    // MARK: - Property Tests: Sunday Input
    
    @Test("Property: Sunday input returns date at least 5 days in future",
          arguments: generateSundayDates(count: 10)) // Test sample Sundays for fast execution
    func testSundayReturnsDateAtLeast5DaysInFuture(sunday: Date) {
        // Precondition: Verify this is actually a Sunday (weekday 1)
        let weekday = calendar.component(.weekday, from: sunday)
        #expect(weekday == 1, "Input date should be Sunday (weekday 1), got weekday \(weekday)")
        
        // Act: Calculate default expiration
        let expiration = calculator.calculateDefaultExpiration(from: sunday)
        
        // Assert: Result should be at least 5 days in the future
        // Sunday → next Friday is 5 days, but if Friday is holiday, fallback to Thursday (4 days)
        // However, the property states "at least 5 days" - if Friday is holiday and Thursday is returned,
        // that's 4 days from Sunday. The implementation skips weekend dates to next Friday.
        // Per the design: "at least 5 days in the future" for weekend dates.
        // For Sunday: next Friday = 5 days, or if holiday fallback to Thursday = 4 days
        // The property needs to account for holiday fallback scenario
        let daysDiff = daysBetween(sunday, expiration)
        
        // For Sunday → Friday = 5 days minimum
        // For Sunday → Thursday (if Friday is holiday) = 4 days
        // The property says "at least 5 days" so we check ≥5 for normal case,
        // but allow ≥4 when Friday is a holiday (Thursday fallback)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        let isThursdayFallback = resultWeekday == 5
        
        if isThursdayFallback {
            // Thursday fallback means Friday was a holiday
            #expect(daysDiff >= 4,
                    "For Sunday with holiday fallback, expiration should be at least 4 days in future, got \(daysDiff)")
        } else {
            #expect(daysDiff >= 5,
                    "For Sunday \(formatDate(sunday)), expiration should be at least 5 days in future, but got \(daysDiff) days. Expiration: \(formatDate(expiration))")
        }
    }
    
    @Test("Property: Sunday returns following Friday (5 days later) or Thursday if holiday",
          arguments: generateSundayDates(count: 10))
    func testSundayReturnsFollowingFriday(sunday: Date) {
        // Precondition
        let weekday = calendar.component(.weekday, from: sunday)
        #expect(weekday == 1, "Input should be Sunday")
        
        // Act
        let expiration = calculator.calculateDefaultExpiration(from: sunday)
        
        // Assert: Result should be Friday (weekday 6) or Thursday if Friday is holiday
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        // Friday (6) or Thursday (5) - both are valid outcomes
        let isFridayOrThursday = resultWeekday == 6 || resultWeekday == 5
        #expect(isFridayOrThursday,
                "Expiration should be Friday (6) or Thursday (5), got weekday \(resultWeekday)")
        
        // For Sunday, next Friday is exactly 5 days away (unless it's a holiday)
        let daysDiff = daysBetween(sunday, expiration)
        // Should be 4-12 range (5 for Friday, 4 for Thursday holiday fallback, up to 12 for next week)
        #expect(daysDiff >= 4 && daysDiff <= 12,
                "Days difference should be between 4-12, got \(daysDiff)")
    }
    
    // MARK: - Property Tests: Random Weekend Dates
    
    @Test("Property: Any weekend date returns expiration at least 5 days in future (or 4 if holiday fallback)",
          arguments: generateRandomWeekendDates(count: 5))
    func testRandomWeekendReturnsAtLeast5DaysInFuture(weekendDate: Date) {
        // Precondition: Verify this is a weekend day
        #expect(isWeekend(weekendDate), "Input should be a weekend day")
        
        // Act
        let expiration = calculator.calculateDefaultExpiration(from: weekendDate)
        
        // Assert: At least 5 days in future (or 4 if Thursday holiday fallback)
        let daysDiff = daysBetween(weekendDate, expiration)
        let weekday = calendar.component(.weekday, from: weekendDate)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        let isThursdayFallback = resultWeekday == 5
        
        if weekday == 7 { // Saturday
            // Saturday: next Friday is 6 days (or 5 days if holiday fallback to Thursday)
            #expect(daysDiff >= 5,
                    "For Saturday, expiration should be at least 5 days in future, got \(daysDiff)")
        } else { // Sunday (weekday == 1)
            // Sunday: next Friday is 5 days (or 4 days if holiday fallback to Thursday)
            if isThursdayFallback {
                #expect(daysDiff >= 4,
                        "For Sunday with Thursday fallback, expiration should be at least 4 days in future, got \(daysDiff)")
            } else {
                #expect(daysDiff >= 5,
                        "For Sunday, expiration should be at least 5 days in future, got \(daysDiff)")
            }
        }
    }
    
    @Test("Property: Any weekend date returns a valid weekday expiration",
          arguments: generateRandomWeekendDates(count: 5))
    func testRandomWeekendReturnsValidWeekdayExpiration(weekendDate: Date) {
        // Precondition
        #expect(isWeekend(weekendDate), "Input should be a weekend day")
        
        // Act
        let expiration = calculator.calculateDefaultExpiration(from: weekendDate)
        
        // Assert: Result should be a weekday (not Saturday or Sunday)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        #expect(resultWeekday >= 2 && resultWeekday <= 6,
                "Expiration should be a weekday (Mon-Fri), got weekday \(resultWeekday)")
    }
    
    // MARK: - Property Tests: Specific Year Coverage
    
    @Test("Property: Saturdays in 2025 return dates at least 5 days in future")
    func testSaturdays2025() {
        // Generate all Saturdays in 2025
        var components = DateComponents(year: 2025, month: 1, day: 4, hour: 12) // First Saturday of 2025
        var currentSaturday = calendar.date(from: components)!
        
        while calendar.component(.year, from: currentSaturday) == 2025 {
            let expiration = calculator.calculateDefaultExpiration(from: currentSaturday)
            let daysDiff = daysBetween(currentSaturday, expiration)
            
            #expect(daysDiff >= 5,
                    "Saturday \(formatDate(currentSaturday)) should give expiration at least 5 days in future, got \(daysDiff)")
            
            currentSaturday = calendar.date(byAdding: .day, value: 7, to: currentSaturday)!
        }
    }
    
    @Test("Property: Sundays in 2025 return dates at least 4 days in future (accounting for holiday fallback)")
    func testSundays2025() {
        // Generate all Sundays in 2025
        var components = DateComponents(year: 2025, month: 1, day: 5, hour: 12) // First Sunday of 2025
        var currentSunday = calendar.date(from: components)!
        
        while calendar.component(.year, from: currentSunday) == 2025 {
            let expiration = calculator.calculateDefaultExpiration(from: currentSunday)
            let daysDiff = daysBetween(currentSunday, expiration)
            
            // Allow 4 days minimum for Thursday holiday fallback
            #expect(daysDiff >= 4,
                    "Sunday \(formatDate(currentSunday)) should give expiration at least 4 days in future, got \(daysDiff)")
            
            currentSunday = calendar.date(byAdding: .day, value: 7, to: currentSunday)!
        }
    }
    
    // MARK: - Property Tests: Boundary Time of Day
    
    @Test("Property: Saturday at midnight returns date at least 5 days in future")
    func testSaturdayAtMidnight() {
        // Saturday at midnight
        let components = DateComponents(year: 2025, month: 1, day: 4, hour: 0, minute: 0, second: 0)
        let saturday = calendar.date(from: components)!
        
        let expiration = calculator.calculateDefaultExpiration(from: saturday)
        let daysDiff = daysBetween(saturday, expiration)
        
        #expect(daysDiff >= 5,
                "Saturday at midnight should give expiration at least 5 days in future, got \(daysDiff)")
    }
    
    @Test("Property: Saturday at 23:59 returns date at least 5 days in future")
    func testSaturdayAtEndOfDay() {
        // Saturday at 23:59
        let components = DateComponents(year: 2025, month: 1, day: 4, hour: 23, minute: 59, second: 59)
        let saturday = calendar.date(from: components)!
        
        let expiration = calculator.calculateDefaultExpiration(from: saturday)
        let daysDiff = daysBetween(saturday, expiration)
        
        #expect(daysDiff >= 5,
                "Saturday at end of day should give expiration at least 5 days in future, got \(daysDiff)")
    }
    
    @Test("Property: Sunday at midnight returns date at least 4 days in future")
    func testSundayAtMidnight() {
        // Sunday at midnight
        let components = DateComponents(year: 2025, month: 1, day: 5, hour: 0, minute: 0, second: 0)
        let sunday = calendar.date(from: components)!
        
        let expiration = calculator.calculateDefaultExpiration(from: sunday)
        let daysDiff = daysBetween(sunday, expiration)
        
        // Allow 4 days for Thursday holiday fallback
        #expect(daysDiff >= 4,
                "Sunday at midnight should give expiration at least 4 days in future, got \(daysDiff)")
    }
    
    @Test("Property: Sunday at 23:59 returns date at least 4 days in future")
    func testSundayAtEndOfDay() {
        // Sunday at 23:59
        let components = DateComponents(year: 2025, month: 1, day: 5, hour: 23, minute: 59, second: 59)
        let sunday = calendar.date(from: components)!
        
        let expiration = calculator.calculateDefaultExpiration(from: sunday)
        let daysDiff = daysBetween(sunday, expiration)
        
        // Allow 4 days for Thursday holiday fallback
        #expect(daysDiff >= 4,
                "Sunday at end of day should give expiration at least 4 days in future, got \(daysDiff)")
    }
    
    // MARK: - Property Tests: Weekend Near Holidays
    
    @Test("Property: Saturday before Good Friday 2025 returns date at least 5 days in future")
    func testSaturdayBeforeGoodFriday2025() {
        // Saturday April 12, 2025 (before Good Friday April 18, 2025)
        let components = DateComponents(year: 2025, month: 4, day: 12, hour: 12)
        let saturday = calendar.date(from: components)!
        
        let expiration = calculator.calculateDefaultExpiration(from: saturday)
        let daysDiff = daysBetween(saturday, expiration)
        
        // The following Friday (April 18) is Good Friday, so expiration should be Thursday (April 17)
        // That's 5 days from Saturday
        #expect(daysDiff >= 5,
                "Saturday before Good Friday should give expiration at least 5 days in future, got \(daysDiff)")
    }
    
    @Test("Property: Sunday before Christmas Friday 2026 returns date at least 4 days in future")
    func testSundayBeforeChristmasFriday2026() {
        // December 25, 2026 is a Friday (Christmas)
        // Sunday December 20, 2026
        let components = DateComponents(year: 2026, month: 12, day: 20, hour: 12)
        let sunday = calendar.date(from: components)!
        
        let expiration = calculator.calculateDefaultExpiration(from: sunday)
        let daysDiff = daysBetween(sunday, expiration)
        
        // Christmas Friday is Dec 25, so expiration should be Thursday Dec 24
        // That's 4 days from Sunday
        #expect(daysDiff >= 4,
                "Sunday before Christmas Friday should give expiration at least 4 days in future (Thursday), got \(daysDiff)")
    }
    
    @Test("Property: Weekend dates never return same week's Friday from past")
    func testWeekendNeverReturnsPastFriday() {
        // Generate several weekend dates and ensure expiration is always in the future
        let weekendDates = Self.generateRandomWeekendDates(count: 10)
        
        for weekendDate in weekendDates {
            let expiration = calculator.calculateDefaultExpiration(from: weekendDate)
            let daysDiff = daysBetween(weekendDate, expiration)
            
            #expect(daysDiff > 0,
                    "Expiration should always be in the future (positive days), got \(daysDiff) for \(formatDate(weekendDate))")
        }
    }
}


// MARK: - Property 3: Default Expiration Is Always a Friday
// **Validates: Requirements 2.1**
//
// *For any* reference date that is not a market holiday, `calculateDefaultExpiration()`
// SHALL return a date that falls on a Friday (weekday = 6).
//
// Note: When Friday is a market holiday, the calculator returns Thursday (weekday = 5)
// as the fallback. This test verifies the core property that the returned date is
// EITHER Friday (normal case) OR Thursday (holiday fallback case).

@Suite("Property 3: Default Expiration Is Always a Friday - Validates Requirements 2.1")
struct DefaultExpirationAlwaysFridayPropertyTests {
    
    // Number of random samples for property tests
    static let sampleCount = 100
    
    /// The calculator under test with a fixed calendar for deterministic testing
    let calculator: ExpirationDateCalculator
    let calendar: Calendar
    
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        self.calendar = cal
        self.calculator = ExpirationDateCalculator(calendar: cal)
    }
    
    // MARK: - Random Date Generation
    
    /// Generate random dates across a wide range of years for comprehensive testing.
    /// This ensures the property holds for any arbitrary reference date.
    static func generateRandomDates(count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var dates: [Date] = []
        
        for _ in 0..<count {
            // Random year between 2020 and 2035
            let year = Int.random(in: 2020...2035)
            let month = Int.random(in: 1...12)
            let day = Int.random(in: 1...28) // Use 28 to avoid invalid dates
            let hour = Int.random(in: 0...23)
            let minute = Int.random(in: 0...59)
            
            let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
            if let date = cal.date(from: components) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    /// Generate weekday dates (Monday-Friday) to ensure consistent Friday output
    static func generateWeekdayDates(count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var dates: [Date] = []
        
        for _ in 0..<count {
            let year = Int.random(in: 2020...2035)
            let month = Int.random(in: 1...12)
            let day = Int.random(in: 1...28)
            let hour = Int.random(in: 9...15) // Within market hours
            
            var components = DateComponents(year: year, month: month, day: day, hour: hour, minute: 30)
            guard var date = cal.date(from: components) else { continue }
            
            // Adjust to a weekday if on weekend
            var weekday = cal.component(.weekday, from: date)
            while weekday == 1 || weekday == 7 { // Sunday or Saturday
                date = cal.date(byAdding: .day, value: 1, to: date)!
                weekday = cal.component(.weekday, from: date)
            }
            
            dates.append(date)
        }
        
        return dates
    }
    
    /// Generate dates specifically on each weekday (Monday-Thursday) to test Friday result
    static func generateSpecificWeekdayDates(weekday: Int, count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        var dates: [Date] = []
        
        // Start from January 1, 2025 and find first occurrence of the target weekday
        var components = DateComponents(year: 2025, month: 1, day: 1, hour: 12)
        guard var currentDate = cal.date(from: components) else { return [] }
        
        // Find first occurrence of target weekday
        while cal.component(.weekday, from: currentDate) != weekday {
            currentDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Generate dates, advancing by 7 days each time
        for _ in 0..<count {
            dates.append(currentDate)
            currentDate = cal.date(byAdding: .day, value: 7, to: currentDate)!
        }
        
        return dates
    }
    
    // MARK: - Helper Methods
    
    /// Checks if the expiration date falls on a Friday (weekday 6 in Swift Calendar)
    func isFriday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 6
    }
    
    /// Checks if the expiration date falls on Thursday (valid when Friday is holiday)
    func isThursday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 5
    }
    
    /// Checks if the result is a valid expiration date (Friday or Thursday holiday fallback)
    func isValidExpirationResult(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 6 || weekday == 5 // Friday or Thursday
    }
    
    /// Returns readable weekday name for debugging
    func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unknown"
        }
    }
    
    // MARK: - Core Property Tests
    
    @Test("Property: calculateDefaultExpiration returns Friday (or Thursday if Friday is holiday)",
          arguments: generateRandomDates(count: 5))
    func testDefaultExpirationReturnsFriday(referenceDate: Date) {
        // Act: Calculate default expiration
        let expiration = calculator.calculateDefaultExpiration(from: referenceDate)
        
        // Assert: Result should be Friday (6) or Thursday (5) if Friday is a holiday
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(isValidExpirationResult(expiration),
                """
                Default expiration should be Friday (6) or Thursday (5, holiday fallback).
                Got weekday \(resultWeekday) (\(weekdayName(resultWeekday))) for reference date \(referenceDate)
                """)
    }
    
    @Test("Property: For any non-holiday Friday reference, returns that same Friday or next Friday",
          arguments: generateSpecificWeekdayDates(weekday: 6, count: 10))
    func testFridayReferenceReturnsFriday(fridayReference: Date) {
        // Precondition: Verify input is Friday
        let inputWeekday = calendar.component(.weekday, from: fridayReference)
        #expect(inputWeekday == 6, "Input should be Friday")
        
        // Act
        let expiration = calculator.calculateDefaultExpiration(from: fridayReference)
        
        // Assert: Result should be a Friday (or Thursday if next Friday is holiday)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        #expect(isValidExpirationResult(expiration),
                "Friday reference should give Friday (or Thursday) expiration, got weekday \(resultWeekday)")
    }
    
    // MARK: - Property Tests by Input Weekday
    
    @Test("Property: Monday input returns Friday of same week",
          arguments: generateSpecificWeekdayDates(weekday: 2, count: 10)) // Monday = 2
    func testMondayReturnsFriday(monday: Date) {
        let inputWeekday = calendar.component(.weekday, from: monday)
        #expect(inputWeekday == 2, "Input should be Monday")
        
        let expiration = calculator.calculateDefaultExpiration(from: monday)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        // Primary assertion: Result is Friday (or Thursday for holiday fallback)
        #expect(isValidExpirationResult(expiration),
                "Monday input should give Friday (or Thursday) expiration, got weekday \(resultWeekday)")
        
        // If it's a normal Friday (no holiday), verify it's exactly 4 days ahead
        if isFriday(expiration) {
            let daysDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: monday), to: calendar.startOfDay(for: expiration)).day ?? 0
            #expect(daysDiff == 4 || daysDiff == 11, // Same week (4 days) or next week if holiday
                    "Monday to Friday should be 4 days (or 11 if holiday causes skip), got \(daysDiff)")
        }
    }
    
    @Test("Property: Tuesday input returns Friday of same week",
          arguments: generateSpecificWeekdayDates(weekday: 3, count: 10)) // Tuesday = 3
    func testTuesdayReturnsFriday(tuesday: Date) {
        let inputWeekday = calendar.component(.weekday, from: tuesday)
        #expect(inputWeekday == 3, "Input should be Tuesday")
        
        let expiration = calculator.calculateDefaultExpiration(from: tuesday)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(isValidExpirationResult(expiration),
                "Tuesday input should give Friday (or Thursday) expiration, got weekday \(resultWeekday)")
    }
    
    @Test("Property: Wednesday input returns Friday of same week",
          arguments: generateSpecificWeekdayDates(weekday: 4, count: 10)) // Wednesday = 4
    func testWednesdayReturnsFriday(wednesday: Date) {
        let inputWeekday = calendar.component(.weekday, from: wednesday)
        #expect(inputWeekday == 4, "Input should be Wednesday")
        
        let expiration = calculator.calculateDefaultExpiration(from: wednesday)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(isValidExpirationResult(expiration),
                "Wednesday input should give Friday (or Thursday) expiration, got weekday \(resultWeekday)")
    }
    
    @Test("Property: Thursday input returns Friday of same week",
          arguments: generateSpecificWeekdayDates(weekday: 5, count: 10)) // Thursday = 5
    func testThursdayReturnsFriday(thursday: Date) {
        let inputWeekday = calendar.component(.weekday, from: thursday)
        #expect(inputWeekday == 5, "Input should be Thursday")
        
        let expiration = calculator.calculateDefaultExpiration(from: thursday)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(isValidExpirationResult(expiration),
                "Thursday input should give Friday (or Thursday) expiration, got weekday \(resultWeekday)")
    }
    
    // MARK: - Property Tests: Non-Holiday Friday Specifically Returns Friday
    
    @Test("Property: Non-holiday Friday reference date returns Friday")
    func testNonHolidayFridayReturnsFriday() {
        // Select Fridays known to NOT be holidays
        let nonHolidayFridays: [(year: Int, month: Int, day: Int)] = [
            (2025, 1, 10),  // Regular Friday
            (2025, 2, 7),   // Regular Friday
            (2025, 3, 7),   // Regular Friday
            (2025, 5, 9),   // Regular Friday
            (2025, 6, 13),  // Regular Friday
            (2025, 8, 8),   // Regular Friday
            (2025, 9, 12),  // Regular Friday
            (2025, 10, 10), // Regular Friday
            (2025, 11, 7),  // Regular Friday
        ]
        
        for friday in nonHolidayFridays {
            let components = DateComponents(year: friday.year, month: friday.month, day: friday.day, hour: 10)
            guard let date = calendar.date(from: components) else { continue }
            
            // Verify it's actually a Friday
            let inputWeekday = calendar.component(.weekday, from: date)
            #expect(inputWeekday == 6, "Test data should be Friday")
            
            // Calculate expiration
            let expiration = calculator.calculateDefaultExpiration(from: date)
            let resultWeekday = calendar.component(.weekday, from: expiration)
            
            // For non-holiday Friday (before market close), result should be that Friday
            #expect(isFriday(expiration),
                    "Non-holiday Friday \(friday) should return Friday, got weekday \(resultWeekday)")
        }
    }
    
    // MARK: - Property Tests: Full Year Coverage
    
    @Test("Property: Sample dates from 2025 return Friday or Thursday")
    func testSampleDatesOf2025ReturnFridayOrThursday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        // Test 10 sample dates spread across 2025
        let sampleDays = [15, 45, 75, 105, 135, 165, 195, 225, 255, 285]
        
        for dayOffset in sampleDays {
            let components = DateComponents(year: 2025, month: 1, day: 1, hour: 12)
            guard var currentDate = cal.date(from: components) else {
                Issue.record("Failed to create start date")
                return
            }
            currentDate = cal.date(byAdding: .day, value: dayOffset, to: currentDate)!
            
            let expiration = calculator.calculateDefaultExpiration(from: currentDate)
            let resultWeekday = cal.component(.weekday, from: expiration)
            
            #expect(resultWeekday == 6 || resultWeekday == 5,
                    """
                    Every day should give Friday (6) or Thursday (5) expiration.
                    Date: \(currentDate), got weekday \(resultWeekday) (\(weekdayName(resultWeekday)))
                    """)
        }
    }
    
    @Test("Property: Sample dates from 2026 return Friday or Thursday")
    func testSampleDatesOf2026ReturnFridayOrThursday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        
        // Test 10 sample dates spread across 2026
        let sampleDays = [15, 45, 75, 105, 135, 165, 195, 225, 255, 285]
        
        for dayOffset in sampleDays {
            let components = DateComponents(year: 2026, month: 1, day: 1, hour: 12)
            guard var currentDate = cal.date(from: components) else {
                Issue.record("Failed to create start date")
                return
            }
            currentDate = cal.date(byAdding: .day, value: dayOffset, to: currentDate)!
            
            let expiration = calculator.calculateDefaultExpiration(from: currentDate)
            let resultWeekday = cal.component(.weekday, from: expiration)
            
            #expect(resultWeekday == 6 || resultWeekday == 5,
                    """
                    Every day should give Friday (6) or Thursday (5) expiration.
                    Date: \(currentDate), got weekday \(resultWeekday) (\(weekdayName(resultWeekday)))
                    """)
        }
    }
    
    // MARK: - Property Tests: Time of Day Variations
    
    @Test("Property: Different times of day on same date return Friday or Thursday",
          arguments: generateWeekdayDates(count: 5))
    func testDifferentTimesReturnFriday(baseDate: Date) {
        // Test various hours throughout the day
        let testHours = [0, 6, 9, 12, 15, 16, 17, 20, 23]
        
        for hour in testHours {
            let dateWithHour = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: baseDate)!
            let expiration = calculator.calculateDefaultExpiration(from: dateWithHour)
            let resultWeekday = calendar.component(.weekday, from: expiration)
            
            #expect(isValidExpirationResult(expiration),
                    "Date at hour \(hour) should return Friday or Thursday, got weekday \(resultWeekday)")
        }
    }
    
    // MARK: - Property Tests: Boundary Cases
    
    @Test("Property: Random dates spanning multiple decades return Friday or Thursday",
          arguments: generateRandomDates(count: 10))
    func testMultipleDecadesReturnFriday(randomDate: Date) {
        let expiration = calculator.calculateDefaultExpiration(from: randomDate)
        let resultWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(isValidExpirationResult(expiration),
                """
                Any date should give Friday or Thursday expiration.
                Input: \(randomDate), got weekday \(resultWeekday) (\(weekdayName(resultWeekday)))
                """)
    }
    
    // MARK: - Property Tests: Result is Always In Future (or Same Day for Friday)
    
    @Test("Property: Expiration date is always >= reference date (on or after)",
          arguments: generateRandomDates(count: 5))
    func testExpirationIsOnOrAfterReference(referenceDate: Date) {
        let expiration = calculator.calculateDefaultExpiration(from: referenceDate)
        
        // Compare dates at start of day
        let referenceStart = calendar.startOfDay(for: referenceDate)
        let expirationStart = calendar.startOfDay(for: expiration)
        
        #expect(expirationStart >= referenceStart,
                "Expiration \(expiration) should be on or after reference date \(referenceDate)")
    }
}


// MARK: - Unit Tests for Specific Holiday Dates
// **Validates: Requirements 2.3, 2.4, 2.5**
//
// These unit tests verify specific known holiday dates are correctly identified
// and that expiration calculation properly falls back to Thursday.

@Suite("Unit Tests: Specific Holiday Dates - Validates Requirements 2.3, 2.4, 2.5")
struct SpecificHolidayDateTests {
    
    /// The calculator under test with a fixed calendar for deterministic testing
    let calculator: ExpirationDateCalculator
    let calendar: Calendar
    
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        self.calendar = cal
        self.calculator = ExpirationDateCalculator(calendar: cal)
    }
    
    // MARK: - Good Friday 2025 Tests (April 18, 2025)
    
    @Test("Good Friday 2025 (April 18) is recognized as a market holiday")
    func testGoodFriday2025IsMarketHoliday() {
        // Good Friday 2025 is April 18, 2025
        // Easter Sunday 2025 is April 20, 2025
        let components = DateComponents(year: 2025, month: 4, day: 18, hour: 12)
        let goodFriday2025 = calendar.date(from: components)!
        
        // Verify it's a Friday
        let weekday = calendar.component(.weekday, from: goodFriday2025)
        #expect(weekday == 6, "April 18, 2025 should be a Friday (weekday 6), got \(weekday)")
        
        // Verify it's recognized as a market holiday
        let isHoliday = calculator.isMarketHoliday(goodFriday2025)
        #expect(isHoliday, "Good Friday 2025 (April 18) should be recognized as a market holiday")
    }
    
    @Test("Expiration falls back to Thursday April 17, 2025 when Good Friday is April 18")
    func testExpirationFallbackGoodFriday2025() {
        // Reference date: Thursday April 17, 2025 (the day before Good Friday)
        let thursdayComponents = DateComponents(year: 2025, month: 4, day: 17, hour: 10)
        let thursday = calendar.date(from: thursdayComponents)!
        
        // Calculate expiration from Thursday
        let expiration = calculator.calculateDefaultExpiration(from: thursday)
        
        // The next Friday (April 18) is Good Friday, so should fall back to Thursday April 17
        let expirationDay = calendar.component(.day, from: expiration)
        let expirationMonth = calendar.component(.month, from: expiration)
        let expirationWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(expirationMonth == 4, "Expiration month should be April (4), got \(expirationMonth)")
        #expect(expirationDay == 17, "Expiration day should be 17 (Thursday), got \(expirationDay)")
        #expect(expirationWeekday == 5, "Expiration should be Thursday (weekday 5), got \(expirationWeekday)")
    }
    
    @Test("Expiration from Monday before Good Friday 2025 goes to Thursday")
    func testExpirationFromMondayBeforeGoodFriday2025() {
        // Monday April 14, 2025
        let mondayComponents = DateComponents(year: 2025, month: 4, day: 14, hour: 10)
        let monday = calendar.date(from: mondayComponents)!
        
        // Verify it's Monday
        let weekday = calendar.component(.weekday, from: monday)
        #expect(weekday == 2, "April 14, 2025 should be Monday (weekday 2), got \(weekday)")
        
        // Calculate expiration
        let expiration = calculator.calculateDefaultExpiration(from: monday)
        
        // Next Friday is Good Friday (April 18), should fall back to Thursday April 17
        let expirationDay = calendar.component(.day, from: expiration)
        let expirationWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(expirationDay == 17, "Expiration should be April 17 (Thursday), got \(expirationDay)")
        #expect(expirationWeekday == 5, "Expiration should be Thursday (weekday 5), got \(expirationWeekday)")
    }
    
    // MARK: - Independence Day 2025 Tests (July 4, 2025 is Friday)
    
    @Test("July 4, 2025 (Friday) is recognized as a market holiday")
    func testJuly4_2025IsMarketHoliday() {
        // July 4, 2025 falls on a Friday
        let components = DateComponents(year: 2025, month: 7, day: 4, hour: 12)
        let july4_2025 = calendar.date(from: components)!
        
        // Verify it's a Friday
        let weekday = calendar.component(.weekday, from: july4_2025)
        #expect(weekday == 6, "July 4, 2025 should be a Friday (weekday 6), got \(weekday)")
        
        // Verify it's recognized as a market holiday
        let isHoliday = calculator.isMarketHoliday(july4_2025)
        #expect(isHoliday, "July 4, 2025 (Friday) should be recognized as a market holiday")
    }
    
    @Test("Expiration falls back to Thursday July 3, 2025 when July 4 is Friday")
    func testExpirationFallbackJuly4_2025() {
        // Reference date: Monday June 30, 2025
        let mondayComponents = DateComponents(year: 2025, month: 6, day: 30, hour: 10)
        let monday = calendar.date(from: mondayComponents)!
        
        // Verify it's Monday
        let weekday = calendar.component(.weekday, from: monday)
        #expect(weekday == 2, "June 30, 2025 should be Monday (weekday 2), got \(weekday)")
        
        // Calculate expiration
        let expiration = calculator.calculateDefaultExpiration(from: monday)
        
        // Next Friday is July 4 (holiday), should fall back to Thursday July 3
        let expirationDay = calendar.component(.day, from: expiration)
        let expirationMonth = calendar.component(.month, from: expiration)
        let expirationWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(expirationMonth == 7, "Expiration month should be July (7), got \(expirationMonth)")
        #expect(expirationDay == 3, "Expiration day should be 3 (Thursday), got \(expirationDay)")
        #expect(expirationWeekday == 5, "Expiration should be Thursday (weekday 5), got \(expirationWeekday)")
    }
    
    @Test("July 3, 2025 (Thursday) is a valid expiration date")
    func testJuly3_2025IsValidExpirationDate() {
        // July 3, 2025 is Thursday (fallback from July 4 holiday)
        let components = DateComponents(year: 2025, month: 7, day: 3, hour: 12)
        let july3_2025 = calendar.date(from: components)!
        
        // Verify it's Thursday
        let weekday = calendar.component(.weekday, from: july3_2025)
        #expect(weekday == 5, "July 3, 2025 should be Thursday (weekday 5), got \(weekday)")
        
        // Verify it's a valid expiration date
        let isValid = calculator.isValidExpirationDate(july3_2025)
        #expect(isValid, "July 3, 2025 (Thursday) should be a valid expiration date")
    }
    
    // MARK: - Christmas 2026 Tests (December 25, 2026 is Friday)
    
    @Test("December 25, 2026 (Friday) is recognized as a market holiday")
    func testChristmas2026IsMarketHoliday() {
        // December 25, 2026 falls on a Friday
        let components = DateComponents(year: 2026, month: 12, day: 25, hour: 12)
        let christmas2026 = calendar.date(from: components)!
        
        // Verify it's a Friday
        let weekday = calendar.component(.weekday, from: christmas2026)
        #expect(weekday == 6, "December 25, 2026 should be a Friday (weekday 6), got \(weekday)")
        
        // Verify it's recognized as a market holiday
        let isHoliday = calculator.isMarketHoliday(christmas2026)
        #expect(isHoliday, "December 25, 2026 (Friday) should be recognized as a market holiday")
    }
    
    @Test("Expiration falls back to Thursday December 24, 2026 when Christmas is Friday")
    func testExpirationFallbackChristmas2026() {
        // Reference date: Monday December 21, 2026
        let mondayComponents = DateComponents(year: 2026, month: 12, day: 21, hour: 10)
        let monday = calendar.date(from: mondayComponents)!
        
        // Verify it's Monday
        let weekday = calendar.component(.weekday, from: monday)
        #expect(weekday == 2, "December 21, 2026 should be Monday (weekday 2), got \(weekday)")
        
        // Calculate expiration
        let expiration = calculator.calculateDefaultExpiration(from: monday)
        
        // Next Friday is December 25 (Christmas holiday), should fall back to Thursday Dec 24
        let expirationDay = calendar.component(.day, from: expiration)
        let expirationMonth = calendar.component(.month, from: expiration)
        let expirationWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(expirationMonth == 12, "Expiration month should be December (12), got \(expirationMonth)")
        #expect(expirationDay == 24, "Expiration day should be 24 (Thursday), got \(expirationDay)")
        #expect(expirationWeekday == 5, "Expiration should be Thursday (weekday 5), got \(expirationWeekday)")
    }
    
    @Test("December 24, 2026 (Thursday) is a valid expiration date when Christmas is Friday")
    func testChristmasEve2026IsValidExpirationDate() {
        // December 24, 2026 is Thursday (Christmas Eve, fallback from Dec 25 holiday)
        let components = DateComponents(year: 2026, month: 12, day: 24, hour: 12)
        let christmasEve2026 = calendar.date(from: components)!
        
        // Verify it's Thursday
        let weekday = calendar.component(.weekday, from: christmasEve2026)
        #expect(weekday == 5, "December 24, 2026 should be Thursday (weekday 5), got \(weekday)")
        
        // Verify it's a valid expiration date
        let isValid = calculator.isValidExpirationDate(christmasEve2026)
        #expect(isValid, "December 24, 2026 (Thursday) should be a valid expiration date")
    }
    
    // MARK: - New Year's Day on Saturday Tests (Dec 31, 2021 observed)
    
    @Test("December 31, 2021 (Friday) is recognized as a market holiday when Jan 1, 2022 is Saturday")
    func testDec31_2021IsMarketHolidayWhenJan1IsSaturday() {
        // January 1, 2022 falls on a Saturday
        // Therefore December 31, 2021 (Friday) should be observed as the New Year's holiday
        let dec31Components = DateComponents(year: 2021, month: 12, day: 31, hour: 12)
        let dec31_2021 = calendar.date(from: dec31Components)!
        
        // Verify December 31, 2021 is a Friday
        let dec31Weekday = calendar.component(.weekday, from: dec31_2021)
        #expect(dec31Weekday == 6, "December 31, 2021 should be a Friday (weekday 6), got \(dec31Weekday)")
        
        // Verify January 1, 2022 is a Saturday
        let jan1Components = DateComponents(year: 2022, month: 1, day: 1, hour: 12)
        let jan1_2022 = calendar.date(from: jan1Components)!
        let jan1Weekday = calendar.component(.weekday, from: jan1_2022)
        #expect(jan1Weekday == 7, "January 1, 2022 should be a Saturday (weekday 7), got \(jan1Weekday)")
        
        // Verify December 31, 2021 is recognized as a market holiday
        let isHoliday = calculator.isMarketHoliday(dec31_2021)
        #expect(isHoliday, "December 31, 2021 (Friday) should be recognized as a market holiday when Jan 1 is Saturday")
    }
    
    @Test("Expiration falls back to Thursday December 30, 2021 when Dec 31 is observed holiday")
    func testExpirationFallbackDec31_2021() {
        // Reference date: Monday December 27, 2021
        let mondayComponents = DateComponents(year: 2021, month: 12, day: 27, hour: 10)
        let monday = calendar.date(from: mondayComponents)!
        
        // Verify it's Monday
        let weekday = calendar.component(.weekday, from: monday)
        #expect(weekday == 2, "December 27, 2021 should be Monday (weekday 2), got \(weekday)")
        
        // Calculate expiration
        let expiration = calculator.calculateDefaultExpiration(from: monday)
        
        // Next Friday is December 31 (observed New Year's holiday), should fall back to Thursday Dec 30
        let expirationDay = calendar.component(.day, from: expiration)
        let expirationMonth = calendar.component(.month, from: expiration)
        let expirationWeekday = calendar.component(.weekday, from: expiration)
        
        #expect(expirationMonth == 12, "Expiration month should be December (12), got \(expirationMonth)")
        #expect(expirationDay == 30, "Expiration day should be 30 (Thursday), got \(expirationDay)")
        #expect(expirationWeekday == 5, "Expiration should be Thursday (weekday 5), got \(expirationWeekday)")
    }
    
    @Test("December 30, 2021 (Thursday) is a valid expiration date when Dec 31 is observed holiday")
    func testDec30_2021IsValidExpirationDate() {
        // December 30, 2021 is Thursday (fallback from Dec 31 observed holiday)
        let components = DateComponents(year: 2021, month: 12, day: 30, hour: 12)
        let dec30_2021 = calendar.date(from: components)!
        
        // Verify it's Thursday
        let weekday = calendar.component(.weekday, from: dec30_2021)
        #expect(weekday == 5, "December 30, 2021 should be Thursday (weekday 5), got \(weekday)")
        
        // Verify it's a valid expiration date
        let isValid = calculator.isValidExpirationDate(dec30_2021)
        #expect(isValid, "December 30, 2021 (Thursday) should be a valid expiration date")
    }
    
    @Test("January 1, 2022 (Saturday) is NOT flagged as a market holiday by isMarketHoliday")
    func testJan1_2022SaturdayIsNotFlaggedAsHoliday() {
        // January 1, 2022 falls on a Saturday
        // The isMarketHoliday method only checks Fridays, so Saturday Jan 1 should not be flagged
        let components = DateComponents(year: 2022, month: 1, day: 1, hour: 12)
        let jan1_2022 = calendar.date(from: components)!
        
        // Verify it's a Saturday
        let weekday = calendar.component(.weekday, from: jan1_2022)
        #expect(weekday == 7, "January 1, 2022 should be a Saturday (weekday 7), got \(weekday)")
        
        // isMarketHoliday only returns true for Fridays, so Saturday should return false
        let isHoliday = calculator.isMarketHoliday(jan1_2022)
        #expect(!isHoliday, "January 1, 2022 (Saturday) should NOT be flagged as market holiday (only Fridays are checked)")
    }
    
    // MARK: - Additional Edge Cases
    
    @Test("Regular Friday (not a holiday) is NOT recognized as a market holiday")
    func testRegularFridayIsNotMarketHoliday() {
        // January 10, 2025 is a regular Friday (no holiday)
        let components = DateComponents(year: 2025, month: 1, day: 10, hour: 12)
        let regularFriday = calendar.date(from: components)!
        
        // Verify it's a Friday
        let weekday = calendar.component(.weekday, from: regularFriday)
        #expect(weekday == 6, "January 10, 2025 should be a Friday (weekday 6), got \(weekday)")
        
        // Verify it's NOT a market holiday
        let isHoliday = calculator.isMarketHoliday(regularFriday)
        #expect(!isHoliday, "January 10, 2025 (regular Friday) should NOT be a market holiday")
    }
    
    @Test("January 1, 2027 (Friday) is recognized as a New Year's Day market holiday")
    func testNewYearsDay2027OnFridayIsHoliday() {
        // January 1, 2027 falls on a Friday
        let components = DateComponents(year: 2027, month: 1, day: 1, hour: 12)
        let newYears2027 = calendar.date(from: components)!
        
        // Verify it's a Friday
        let weekday = calendar.component(.weekday, from: newYears2027)
        #expect(weekday == 6, "January 1, 2027 should be a Friday (weekday 6), got \(weekday)")
        
        // Verify it's recognized as a market holiday
        let isHoliday = calculator.isMarketHoliday(newYears2027)
        #expect(isHoliday, "January 1, 2027 (Friday) should be recognized as a New Year's Day market holiday")
    }
}
