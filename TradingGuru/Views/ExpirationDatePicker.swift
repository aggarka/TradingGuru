//
//  ExpirationDatePicker.swift
//  TradingGuru
//
//  A reusable SwiftUI view for selecting options expiration dates.
//

import SwiftUI

// MARK: - Date Validation Result

/// Result of validating a date for options expiration.
///
/// Encapsulates the validation outcome including whether the date is valid,
/// any warnings that should be displayed, and error messages for invalid dates.
struct DateValidationResult: Equatable {
    /// Whether the date is valid for options expiration
    let isValid: Bool
    
    /// Warning message to display (e.g., non-Friday warning)
    let warningMessage: String?
    
    /// Error message for invalid dates
    let errorMessage: String?
    
    /// Creates a successful validation result with optional warning
    static func valid(warning: String? = nil) -> DateValidationResult {
        DateValidationResult(isValid: true, warningMessage: warning, errorMessage: nil)
    }
    
    /// Creates a failed validation result with error message
    static func invalid(error: String) -> DateValidationResult {
        DateValidationResult(isValid: false, warningMessage: nil, errorMessage: error)
    }
}

// MARK: - Date Validation Logic

/// Validates dates for options expiration.
///
/// This struct provides reusable validation logic for determining if a date
/// is valid for options trading and whether it should show warnings.
///
/// - Validates: Requirement 3.6 (Valid trading day validation)
/// - Validates: Requirement 3.7 (Invalid date error messages)
struct ExpirationDateValidator {
    
    let calendar: Calendar
    let expirationCalculator: ExpirationDateCalculation?
    
    init(calendar: Calendar = .current, expirationCalculator: ExpirationDateCalculation? = nil) {
        self.calendar = calendar
        self.expirationCalculator = expirationCalculator
    }
    
    /// Validates a date for options expiration.
    ///
    /// Checks:
    /// 1. Date is a weekday (Monday-Friday)
    /// 2. Date is not a market holiday (if calculator is provided)
    /// 3. Warns if date is not a Friday (typical expiration day)
    ///
    /// - Parameter date: The date to validate
    /// - Returns: Validation result with validity status and any messages
    /// - Validates: Requirement 3.6 (Valid trading day validation)
    /// - Validates: Requirement 3.7 (Invalid date error messages)
    func validate(_ date: Date) -> DateValidationResult {
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if weekend (Sunday = 1, Saturday = 7)
        if weekday == 1 || weekday == 7 {
            let dayName = weekday == 1 ? "Sunday" : "Saturday"
            return .invalid(error: "Market is closed on \(dayName). Please select a weekday.")
        }
        
        // Check if market holiday using calculator if available
        if let calculator = expirationCalculator {
            if !calculator.isValidExpirationDate(date) {
                // It's a weekday but not valid - must be a holiday
                return .invalid(error: "Market is closed on this date (holiday). Please select another date.")
            }
        }
        
        // Valid date - check for Friday warning
        if weekday != 6 {  // Friday = 6
            let dayName = dayOfWeekName(weekday)
            return .valid(warning: "\(dayName) selected. Weekly options typically expire on Fridays.")
        }
        
        return .valid()
    }
    
    /// Returns whether a date is a weekday (Monday-Friday).
    ///
    /// - Parameter date: The date to check
    /// - Returns: `true` if the date is a weekday
    func isWeekday(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return (2...6).contains(weekday)
    }
    
    /// Returns whether a date is a Friday.
    ///
    /// - Parameter date: The date to check
    /// - Returns: `true` if the date is a Friday
    func isFriday(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 6
    }
    
    /// Returns the name of the day of the week.
    private func dayOfWeekName(_ weekday: Int) -> String {
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
}

// MARK: - Expiration Date Picker

/// A view that allows users to select a custom options expiration date or use the automatic calculation.
///
/// This picker provides:
/// - A DatePicker for selecting a specific expiration date
/// - A "Reset" button to clear the override and return to automatic calculation
/// - Display text indicating whether a custom or default date is being used
/// - Date constraints limiting selection to reasonable future dates (within 1 year)
/// - Validation for weekdays only (rejects weekends)
/// - Warning when non-Friday is selected (typical expiration day)
///
/// The selected date is bound to an optional `Date?`, where:
/// - `nil` indicates automatic calculation should be used
/// - A `Date` value indicates the user's custom override
///
/// - Validates: Requirement 3.1 (Date picker control for custom expiration date)
/// - Validates: Requirement 3.3 (Display currently selected expiration date)
/// - Validates: Requirement 3.6 (Valid trading day validation)
/// - Validates: Requirement 3.7 (Invalid date error messages)
struct ExpirationDatePicker: View {
    // MARK: - Bindings
    
    /// The selected expiration date override.
    /// When `nil`, the system uses automatic expiration date calculation.
    /// When set, this date is used for all subsequent analyses in the session.
    @Binding var selectedDate: Date?
    
    // MARK: - Dependencies
    
    /// Optional calculator for determining the default expiration date and validation.
    /// If provided, the view can display the calculated default date when no override is set,
    /// and validate dates for market holidays.
    var expirationCalculator: ExpirationDateCalculation?
    
    // MARK: - Callbacks
    
    /// Called when the user selects a new valid date.
    /// This allows parent views to perform additional actions like validation.
    var onDateSelected: ((Date) -> Void)?
    
    /// Called when the user clears the date override.
    var onDateCleared: (() -> Void)?
    
    /// Called when the user selects an invalid date.
    /// Provides the error message for the invalid date.
    var onValidationError: ((String) -> Void)?
    
    // MARK: - Local State
    
    /// The date displayed in the DatePicker.
    /// This is separate from `selectedDate` to allow the picker to always show a valid date.
    @State private var pickerDate: Date
    
    /// Whether the date picker is expanded (for inline style).
    @State private var isExpanded: Bool = false
    
    /// Current validation error message (if any).
    @State private var validationError: String?
    
    /// Current warning message (if any).
    @State private var warningMessage: String?
    
    // MARK: - Computed Properties
    
    /// The minimum selectable date (today).
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    /// The maximum selectable date (1 year from today).
    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }
    
    /// Whether a custom date is currently selected (override is active).
    private var hasCustomDate: Bool {
        selectedDate != nil
    }
    
    /// The default expiration date calculated by the calculator (if available).
    private var calculatedDefaultDate: Date? {
        expirationCalculator?.calculateDefaultExpiration(from: Date())
    }
    
    /// The validator for checking date validity.
    private var validator: ExpirationDateValidator {
        ExpirationDateValidator(
            calendar: .current,
            expirationCalculator: expirationCalculator
        )
    }
    
    /// Description text shown below the picker.
    private var descriptionText: String {
        if hasCustomDate {
            return "Using custom expiration date"
        } else if let defaultDate = calculatedDefaultDate {
            return "Using default: \(formatDate(defaultDate))"
        } else {
            return "Using automatic expiration calculation"
        }
    }
    
    // MARK: - Initialization
    
    /// Creates an ExpirationDatePicker with the specified bindings and configuration.
    /// - Parameters:
    ///   - selectedDate: Binding to the optional selected date
    ///   - expirationCalculator: Optional calculator for default date display and validation
    ///   - onDateSelected: Callback when a valid date is selected
    ///   - onDateCleared: Callback when the date is cleared
    ///   - onValidationError: Callback when an invalid date is selected
    init(
        selectedDate: Binding<Date?>,
        expirationCalculator: ExpirationDateCalculation? = nil,
        onDateSelected: ((Date) -> Void)? = nil,
        onDateCleared: (() -> Void)? = nil,
        onValidationError: ((String) -> Void)? = nil
    ) {
        self._selectedDate = selectedDate
        self.expirationCalculator = expirationCalculator
        self.onDateSelected = onDateSelected
        self.onDateCleared = onDateCleared
        self.onValidationError = onValidationError
        
        // Initialize picker date to selected date, calculated default, or today
        // Convert from UTC to local calendar date for display in DatePicker
        let initialDate: Date
        if let selected = selectedDate.wrappedValue {
            initialDate = Self.utcToLocalCalendarDate(selected)
        } else if let calculator = expirationCalculator {
            let utcDate = calculator.calculateDefaultExpiration(from: Date())
            initialDate = Self.utcToLocalCalendarDate(utcDate)
        } else {
            // Default to next Friday if no calculator
            initialDate = Self.nextFriday(from: Date())
        }
        self._pickerDate = State(initialValue: initialDate)
        self._validationError = State(initialValue: nil)
        self._warningMessage = State(initialValue: nil)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and reset button
            headerView
            
            // Date picker
            datePickerView
            
            // Error message (if any)
            if let error = validationError {
                errorView(message: error)
            }
            
            // Warning message (if any)
            if validationError == nil, let warning = warningMessage {
                warningView(message: warning)
            }
            
            // Description text
            descriptionView
        }
        .onChange(of: selectedDate) { _, newValue in
            // Sync picker date when selectedDate changes externally
            // Convert from UTC to local calendar date for display
            if let date = newValue {
                pickerDate = Self.utcToLocalCalendarDate(date)
                // Re-validate to update warning message (validate using local date)
                let result = validator.validate(pickerDate)
                warningMessage = result.warningMessage
                validationError = nil
            } else {
                // Clear messages when date is cleared
                warningMessage = nil
                validationError = nil
            }
        }
    }
    
    // MARK: - Header View
    
    /// Header containing the title and reset button.
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Expiration Date")
                    .font(.body)
                
                Text("Select a custom expiration or use automatic")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Reset button (only shown when custom date is selected)
            if hasCustomDate {
                Button(action: clearDateOverride) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                        Text("Reset")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset to automatic expiration")
                .accessibilityHint("Double tap to clear custom date and use automatic calculation")
            }
        }
    }
    
    // MARK: - Date Picker View
    
    /// The main date picker component.
    private var datePickerView: some View {
        DatePicker(
            "Expiration Date",
            selection: $pickerDate,
            in: minimumDate...maximumDate,
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .onChange(of: pickerDate) { _, newDate in
            handleDateSelection(newDate)
        }
        .accessibilityLabel("Expiration date picker")
        .accessibilityHint("Select a date for options expiration")
        .accessibilityValue(formatDate(pickerDate))
    }
    
    // MARK: - Description View
    
    /// Shows whether custom or automatic date is being used.
    private var descriptionView: some View {
        HStack(spacing: 6) {
            Image(systemName: hasCustomDate ? "calendar.badge.checkmark" : "calendar")
                .foregroundStyle(hasCustomDate ? .blue : .secondary)
                .font(.caption)
            
            Text(descriptionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(descriptionText)
    }
    
    // MARK: - Error View
    
    /// Shows validation error message for invalid dates.
    /// - Validates: Requirement 3.7 (Invalid date error messages)
    private func errorView(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
    
    // MARK: - Warning View
    
    /// Shows warning message for non-typical expiration dates.
    private func warningView(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: \(message)")
    }
    
    // MARK: - Actions
    
    /// Handles date selection from the picker.
    /// Validates the date and rejects invalid selections (weekends, holidays).
    /// Shows warnings for non-Friday selections.
    /// - Parameter date: The newly selected date (in local timezone from DatePicker)
    /// - Validates: Requirement 3.6 (Valid trading day validation)
    /// - Validates: Requirement 3.7 (Invalid date error messages)
    private func handleDateSelection(_ date: Date) {
        // Validate the selected date
        let result = validator.validate(date)
        
        if result.isValid {
            // Clear any previous error
            validationError = nil
            
            // Set warning message if present
            warningMessage = result.warningMessage
            
            // Convert local date to UTC midnight for storage
            // The date picker gives us a local date, but we store as UTC midnight
            let utcDate = Self.localToUtcMidnight(date)
            
            // Update the selected date
            selectedDate = utcDate
            onDateSelected?(utcDate)
        } else {
            // Invalid date - set error and don't update selectedDate
            validationError = result.errorMessage
            warningMessage = nil
            
            // Notify of validation error
            if let error = result.errorMessage {
                onValidationError?(error)
            }
            
            // Revert picker to previous valid date or default
            revertToLastValidDate()
        }
    }
    
    /// Reverts the picker date to the last valid date.
    /// Called when user selects an invalid date.
    private func revertToLastValidDate() {
        // Short delay to allow the picker UI to update first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let currentSelection = selectedDate {
                // Revert to last valid selection (convert from UTC to local for display)
                pickerDate = Self.utcToLocalCalendarDate(currentSelection)
            } else if let defaultDate = calculatedDefaultDate {
                // Revert to calculated default (convert from UTC to local for display)
                pickerDate = Self.utcToLocalCalendarDate(defaultDate)
            } else {
                // Revert to next Friday
                pickerDate = Self.nextFriday(from: Date())
            }
        }
    }
    
    /// Clears the date override and returns to automatic calculation.
    private func clearDateOverride() {
        selectedDate = nil
        validationError = nil
        warningMessage = nil
        onDateCleared?()
        
        // Reset picker to calculated default or next Friday (convert from UTC to local for display)
        if let defaultDate = calculatedDefaultDate {
            pickerDate = Self.utcToLocalCalendarDate(defaultDate)
        } else {
            pickerDate = Self.nextFriday(from: Date())
        }
    }
    
    // MARK: - Helpers
    
    /// Formats a date for display in YYYY-MM-DD format.
    /// Uses UTC timezone to correctly display dates stored as UTC midnight.
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    /// Calculates the next Friday from a given date.
    /// - Parameter date: The reference date
    /// - Returns: The next Friday
    private static func nextFriday(from date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Calculate days until Friday (Friday = 6 in Calendar)
        var daysToAdd: Int
        switch weekday {
        case 1: daysToAdd = 5  // Sunday
        case 2: daysToAdd = 4  // Monday
        case 3: daysToAdd = 3  // Tuesday
        case 4: daysToAdd = 2  // Wednesday
        case 5: daysToAdd = 1  // Thursday
        case 6: daysToAdd = 7  // Friday -> next Friday
        case 7: daysToAdd = 6  // Saturday
        default: daysToAdd = 0
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
    }
    
    /// Converts a UTC date to a local calendar date for display in DatePicker.
    /// Preserves the year/month/day from UTC and creates a local date with those components.
    /// This ensures dates stored as UTC midnight (e.g., 2026-07-10 00:00:00 UTC) display
    /// correctly in the local timezone (as July 10, not July 9).
    /// - Parameter utcDate: A date stored as UTC midnight
    /// - Returns: A date in local timezone with the same year/month/day
    private static func utcToLocalCalendarDate(_ utcDate: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        
        // Extract year/month/day from the UTC date
        let components = utcCalendar.dateComponents([.year, .month, .day], from: utcDate)
        
        // Create a local date with those same components
        let localCalendar = Calendar.current
        return localCalendar.date(from: components) ?? utcDate
    }
    
    /// Converts a local date from DatePicker to UTC midnight for storage.
    /// Takes the year/month/day from the local date and creates a UTC midnight date.
    /// This ensures dates selected by the user are stored consistently as UTC midnight.
    /// - Parameter localDate: A date from the DatePicker (in local timezone)
    /// - Returns: A date at midnight UTC with the same year/month/day
    private static func localToUtcMidnight(_ localDate: Date) -> Date {
        let localCalendar = Calendar.current
        
        // Extract year/month/day from the local date
        let components = localCalendar.dateComponents([.year, .month, .day], from: localDate)
        
        // Create a UTC midnight date with those same components
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        return utcCalendar.date(from: components) ?? localDate
    }
}

// MARK: - Preview

#Preview("No Selection") {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date? = nil
        
        var body: some View {
            List {
                Section("Expiration Override") {
                    ExpirationDatePicker(selectedDate: $selectedDate)
                }
            }
        }
    }
    return PreviewWrapper()
}

#Preview("With Custom Date") {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date? = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        
        var body: some View {
            List {
                Section("Expiration Override") {
                    ExpirationDatePicker(selectedDate: $selectedDate)
                }
            }
        }
    }
    return PreviewWrapper()
}

#Preview("With Calculator (shows validation)") {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date? = nil
        let calculator = ExpirationDateCalculator()
        
        var body: some View {
            List {
                Section("Expiration Override") {
                    ExpirationDatePicker(
                        selectedDate: $selectedDate,
                        expirationCalculator: calculator,
                        onDateSelected: { date in
                            print("Selected: \(date)")
                        },
                        onDateCleared: {
                            print("Cleared")
                        },
                        onValidationError: { error in
                            print("Validation error: \(error)")
                        }
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}

#Preview("Non-Friday Selection (shows warning)") {
    struct PreviewWrapper: View {
        // Select next Monday
        @State private var selectedDate: Date? = {
            let calendar = Calendar.current
            var date = Date()
            while calendar.component(.weekday, from: date) != 2 { // Monday
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return date
        }()
        
        var body: some View {
            List {
                Section("Expiration Override") {
                    ExpirationDatePicker(
                        selectedDate: $selectedDate,
                        expirationCalculator: ExpirationDateCalculator()
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}

#Preview("In Configuration Interface") {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date? = nil
        
        var body: some View {
            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Weekly Option Strategy", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.headline)
                            
                            Text("Analyzes historical price data to identify optimal CALL and PUT entry points.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section("Configuration") {
                        // Window Days picker placeholder
                        HStack {
                            Text("Window Days")
                            Spacer()
                            Text("5 days")
                                .foregroundStyle(.secondary)
                        }
                        
                        // Lookback Days picker placeholder
                        HStack {
                            Text("Lookback Days")
                            Spacer()
                            Text("180 days")
                                .foregroundStyle(.secondary)
                        }
                        
                        // Expiration Date picker with validation
                        ExpirationDatePicker(
                            selectedDate: $selectedDate,
                            expirationCalculator: ExpirationDateCalculator(),
                            onDateSelected: { date in
                                print("Selected: \(date)")
                            },
                            onDateCleared: {
                                print("Cleared")
                            },
                            onValidationError: { error in
                                print("Validation error: \(error)")
                            }
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Analysis")
            }
        }
    }
    return PreviewWrapper()
}
