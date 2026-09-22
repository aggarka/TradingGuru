//
//  ExpirationDatePickerTests.swift
//  TradingGuruTests
//
//  Unit tests for ExpirationDatePicker date validation logic.
//  Tests the validation of selected dates for options expiration.
//

import Testing
import Foundation
@testable import TradingGuru

// MARK: - Date Validation Result Tests

@Suite("DateValidationResult Tests")
struct DateValidationResultTests {
    
    @Test("valid() creates successful result with no messages")
    func testValidCreatesSuccessfulResult() {
        let result = DateValidationResult.valid()
        
        #expect(result.isValid == true)
        #expect(result.warningMessage == nil)
        #expect(result.errorMessage == nil)
    }
    
    @Test("valid(warning:) creates successful result with warning")
    func testValidWithWarningCreatesResultWithWarning() {
        let warning = "Test warning message"
        let result = DateValidationResult.valid(warning: warning)
        
        #expect(result.isValid == true)
        #expect(result.warningMessage == warning)
        #expect(result.errorMessage == nil)
    }
    
    @Test("invalid(error:) creates failed result with error")
    func testInvalidCreatesFailedResult() {
        let error = "Test error message"
        let result = DateValidationResult.invalid(error: error)
        
        #expect(result.isValid == false)
        #expect(result.warningMessage == nil)
        #expect(result.errorMessage == error)
    }
    
    @Test("DateValidationResult is equatable")
    func testEquatable() {
        let result1 = DateValidationResult.valid(warning: "warning")
        let result2 = DateValidationResult.valid(warning: "warning")
        let result3 = DateValidationResult.valid()
        
        #expect(result1 == result2)
        #expect(result1 != result3)
    }
}

// MARK: - Expiration Date Validator Tests

@Suite("ExpirationDateValidator Tests")
struct ExpirationDateValidatorTests {
    
    // Use a fixed calendar for consistent testing
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()
    
    // MARK: - Helper Methods
    
    /// Creates a date from year, month, day components
    func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    
    // MARK: - Weekday Validation Tests
    
    @Test("Validates Monday as valid trading day")
    func testMondayIsValid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 6, 2025 is a Monday
        let monday = date(year: 2025, month: 1, day: 6)
        
        let result = validator.validate(monday)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
        // Should show warning because it's not Friday
        #expect(result.warningMessage != nil)
        #expect(result.warningMessage?.contains("Monday") == true)
    }
    
    @Test("Validates Tuesday as valid trading day")
    func testTuesdayIsValid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 7, 2025 is a Tuesday
        let tuesday = date(year: 2025, month: 1, day: 7)
        
        let result = validator.validate(tuesday)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
        #expect(result.warningMessage?.contains("Tuesday") == true)
    }
    
    @Test("Validates Wednesday as valid trading day")
    func testWednesdayIsValid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 8, 2025 is a Wednesday
        let wednesday = date(year: 2025, month: 1, day: 8)
        
        let result = validator.validate(wednesday)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
        #expect(result.warningMessage?.contains("Wednesday") == true)
    }
    
    @Test("Validates Thursday as valid trading day")
    func testThursdayIsValid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 9, 2025 is a Thursday
        let thursday = date(year: 2025, month: 1, day: 9)
        
        let result = validator.validate(thursday)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
        #expect(result.warningMessage?.contains("Thursday") == true)
    }
    
    @Test("Validates Friday as valid trading day with no warning")
    func testFridayIsValidWithNoWarning() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 10, 2025 is a Friday
        let friday = date(year: 2025, month: 1, day: 10)
        
        let result = validator.validate(friday)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
        #expect(result.warningMessage == nil)
    }
    
    // MARK: - Weekend Validation Tests
    
    @Test("Rejects Saturday with appropriate error message")
    func testSaturdayIsInvalid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 11, 2025 is a Saturday
        let saturday = date(year: 2025, month: 1, day: 11)
        
        let result = validator.validate(saturday)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("Saturday") == true)
        #expect(result.errorMessage?.contains("Market is closed") == true)
        #expect(result.warningMessage == nil)
    }
    
    @Test("Rejects Sunday with appropriate error message")
    func testSundayIsInvalid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        // January 12, 2025 is a Sunday
        let sunday = date(year: 2025, month: 1, day: 12)
        
        let result = validator.validate(sunday)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("Sunday") == true)
        #expect(result.errorMessage?.contains("Market is closed") == true)
        #expect(result.warningMessage == nil)
    }
    
    // MARK: - Holiday Validation Tests (with calculator)
    
    @Test("Rejects market holiday when calculator is provided")
    func testMarketHolidayIsInvalidWithCalculator() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let calculator = ExpirationDateCalculator(calendar: cal)
        let validator = ExpirationDateValidator(calendar: cal, expirationCalculator: calculator)
        
        // Good Friday 2025: April 18 (a market holiday)
        let goodFriday = date(year: 2025, month: 4, day: 18)
        
        let result = validator.validate(goodFriday)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("holiday") == true)
        #expect(result.warningMessage == nil)
    }
    
    @Test("Accepts regular Friday when calculator is provided")
    func testRegularFridayIsValidWithCalculator() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let calculator = ExpirationDateCalculator(calendar: cal)
        let validator = ExpirationDateValidator(calendar: cal, expirationCalculator: calculator)
        
        // January 10, 2025 is a regular Friday (not a holiday)
        let friday = date(year: 2025, month: 1, day: 10)
        
        let result = validator.validate(friday)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
        #expect(result.warningMessage == nil)
    }
    
    @Test("Rejects July 4th on Friday as market holiday")
    func testJuly4OnFridayIsInvalid() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let calculator = ExpirationDateCalculator(calendar: cal)
        let validator = ExpirationDateValidator(calendar: cal, expirationCalculator: calculator)
        
        // July 4, 2025 is a Friday and Independence Day
        let july4 = date(year: 2025, month: 7, day: 4)
        
        let result = validator.validate(july4)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("holiday") == true)
    }
    
    // MARK: - isWeekday Tests
    
    @Test("isWeekday returns true for Monday through Friday")
    func testIsWeekdayForWeekdays() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        // Test each weekday
        let monday = date(year: 2025, month: 1, day: 6)
        let tuesday = date(year: 2025, month: 1, day: 7)
        let wednesday = date(year: 2025, month: 1, day: 8)
        let thursday = date(year: 2025, month: 1, day: 9)
        let friday = date(year: 2025, month: 1, day: 10)
        
        #expect(validator.isWeekday(monday) == true)
        #expect(validator.isWeekday(tuesday) == true)
        #expect(validator.isWeekday(wednesday) == true)
        #expect(validator.isWeekday(thursday) == true)
        #expect(validator.isWeekday(friday) == true)
    }
    
    @Test("isWeekday returns false for Saturday and Sunday")
    func testIsWeekdayForWeekends() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        let saturday = date(year: 2025, month: 1, day: 11)
        let sunday = date(year: 2025, month: 1, day: 12)
        
        #expect(validator.isWeekday(saturday) == false)
        #expect(validator.isWeekday(sunday) == false)
    }
    
    // MARK: - isFriday Tests
    
    @Test("isFriday returns true only for Fridays")
    func testIsFriday() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        // Test each day of the week
        let monday = date(year: 2025, month: 1, day: 6)
        let tuesday = date(year: 2025, month: 1, day: 7)
        let wednesday = date(year: 2025, month: 1, day: 8)
        let thursday = date(year: 2025, month: 1, day: 9)
        let friday = date(year: 2025, month: 1, day: 10)
        let saturday = date(year: 2025, month: 1, day: 11)
        let sunday = date(year: 2025, month: 1, day: 12)
        
        #expect(validator.isFriday(monday) == false)
        #expect(validator.isFriday(tuesday) == false)
        #expect(validator.isFriday(wednesday) == false)
        #expect(validator.isFriday(thursday) == false)
        #expect(validator.isFriday(friday) == true)
        #expect(validator.isFriday(saturday) == false)
        #expect(validator.isFriday(sunday) == false)
    }
    
    // MARK: - Warning Message Content Tests
    
    @Test("Warning message includes day name and expiration info")
    func testWarningMessageContent() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        // Monday should produce warning with "Monday" and "Friday"
        let monday = date(year: 2025, month: 1, day: 6)
        let result = validator.validate(monday)
        
        #expect(result.warningMessage?.contains("Monday") == true)
        #expect(result.warningMessage?.contains("Friday") == true)
        #expect(result.warningMessage?.contains("typically expire") == true)
    }
    
    // MARK: - Error Message Content Tests
    
    @Test("Weekend error message is user-friendly")
    func testWeekendErrorMessageContent() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        let saturday = date(year: 2025, month: 1, day: 11)
        let result = validator.validate(saturday)
        
        #expect(result.errorMessage?.contains("Market is closed") == true)
        #expect(result.errorMessage?.contains("weekday") == true)
    }
    
    @Test("Holiday error message is user-friendly")
    func testHolidayErrorMessageContent() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let calculator = ExpirationDateCalculator(calendar: cal)
        let validator = ExpirationDateValidator(calendar: cal, expirationCalculator: calculator)
        
        // Good Friday 2025
        let goodFriday = date(year: 2025, month: 4, day: 18)
        let result = validator.validate(goodFriday)
        
        #expect(result.errorMessage?.contains("Market is closed") == true)
        #expect(result.errorMessage?.contains("holiday") == true)
    }
}

// MARK: - Validator Without Calculator Tests

@Suite("ExpirationDateValidator Without Calculator Tests")
struct ExpirationDateValidatorWithoutCalculatorTests {
    
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()
    
    /// Creates a date from year, month, day components
    func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    
    @Test("Validates weekdays without checking holidays when no calculator")
    func testValidatesWeekdaysWithoutHolidayCheck() {
        // Without a calculator, holidays aren't checked
        let validator = ExpirationDateValidator(calendar: calendar, expirationCalculator: nil)
        
        // Good Friday 2025 - would be invalid with calculator, but valid without
        let goodFriday = date(year: 2025, month: 4, day: 18)
        
        let result = validator.validate(goodFriday)
        
        // Should be valid because we only check for weekends without a calculator
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test("Still rejects weekends without calculator")
    func testRejectsWeekendsWithoutCalculator() {
        let validator = ExpirationDateValidator(calendar: calendar, expirationCalculator: nil)
        
        let saturday = date(year: 2025, month: 1, day: 11)
        let sunday = date(year: 2025, month: 1, day: 12)
        
        let saturdayResult = validator.validate(saturday)
        let sundayResult = validator.validate(sunday)
        
        #expect(saturdayResult.isValid == false)
        #expect(sundayResult.isValid == false)
    }
}

// MARK: - Multiple Dates Property Tests

@Suite("Expiration Date Validation Property Tests")
struct ExpirationDateValidationPropertyTests {
    
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()
    
    /// Creates a date from year, month, day components
    func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    
    /// Generates random dates for a month
    func generateDatesForMonth(year: Int, month: Int) -> [Date] {
        let range: ClosedRange<Int>
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: range = 1...31
        case 4, 6, 9, 11: range = 1...30
        case 2: range = 1...28
        default: range = 1...28
        }
        
        return range.compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
        }
    }
    
    @Test("All Saturdays in 2025 are invalid")
    func testAllSaturdaysInvalid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        // Generate all Saturdays in January 2025
        let saturdays = [4, 11, 18, 25].map { date(year: 2025, month: 1, day: $0) }
        
        for saturday in saturdays {
            let result = validator.validate(saturday)
            #expect(result.isValid == false, "Saturday should be invalid")
        }
    }
    
    @Test("All Sundays in 2025 are invalid")
    func testAllSundaysInvalid() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        // Generate all Sundays in January 2025
        let sundays = [5, 12, 19, 26].map { date(year: 2025, month: 1, day: $0) }
        
        for sunday in sundays {
            let result = validator.validate(sunday)
            #expect(result.isValid == false, "Sunday should be invalid")
        }
    }
    
    @Test("All non-holiday Fridays have no warning")
    func testNonHolidayFridaysHaveNoWarning() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let calculator = ExpirationDateCalculator(calendar: cal)
        let validator = ExpirationDateValidator(calendar: cal, expirationCalculator: calculator)
        
        // Regular Fridays in January 2025 (none are holidays)
        let fridays = [3, 10, 17, 24, 31].map { date(year: 2025, month: 1, day: $0) }
        
        for friday in fridays {
            let result = validator.validate(friday)
            if result.isValid {
                #expect(result.warningMessage == nil, "Valid Friday should have no warning")
            }
        }
    }
    
    @Test("All weekdays except Friday have warning")
    func testWeekdaysExceptFridayHaveWarning() {
        let validator = ExpirationDateValidator(calendar: calendar)
        
        // First week of January 2025: Mon=6, Tue=7, Wed=8, Thu=9
        let nonFridayWeekdays = [6, 7, 8, 9].map { date(year: 2025, month: 1, day: $0) }
        
        for weekday in nonFridayWeekdays {
            let result = validator.validate(weekday)
            #expect(result.isValid == true, "Weekday should be valid")
            #expect(result.warningMessage != nil, "Non-Friday weekday should have warning")
            #expect(result.warningMessage?.contains("Friday") == true, "Warning should mention Friday")
        }
    }
}
