//
//  ScheduleTimePickerView.swift
//  TradingGuru
//
//  Time picker view for selecting schedule times in 15-minute increments.
//

import SwiftUI

/// View for selecting a schedule time for background analysis.
///
/// Presents hour and minute pickers in wheel style, allowing selection of times
/// in 15-minute increments from 00:00 to 23:45 in the user's local timezone.
///
/// - Validates: Requirement 2.1 (Settings interface for schedule times)
/// - Validates: Requirement 2.2 (15-minute increments from 00:00 to 23:45)
struct ScheduleTimePickerView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @ObservedObject var viewModel: ScheduleSettingsViewModel
    
    // MARK: - State
    
    /// Selected hour (0-23)
    @State private var selectedHour: Int = 6
    
    /// Selected minute (0, 15, 30, or 45)
    @State private var selectedMinute: Int = 30
    
    // MARK: - Constants
    
    /// Valid hours for selection (0-23)
    private let hours = Array(0...23)
    
    /// Valid minutes for selection (15-minute increments)
    /// - Validates: Requirement 2.2 (15-minute increments)
    private let minutes = ScheduleTime.validMinutes
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time display header
                timeDisplayHeader
                
                // Time pickers
                timePickerSection
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Schedule Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to dismiss without adding a schedule time")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addScheduleTime()
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Add schedule time")
                    .accessibilityHint("Double tap to add the selected time to your schedule")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Time Display Header
    
    private var timeDisplayHeader: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("Selected time: \(formattedTimeAccessible)")
            
            Text("Select a time for scheduled analysis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Time Picker Section
    
    private var timePickerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Hour picker
                Picker("Hour", selection: $selectedHour) {
                    ForEach(hours, id: \.self) { hour in
                        Text(formatHour(hour))
                            .tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Hour")
                .accessibilityValue(formatHour(selectedHour))
                
                Text(":")
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundStyle(.secondary)
                
                // Minute picker
                /// - Validates: Requirement 2.2 (15-minute increments)
                Picker("Minute", selection: $selectedMinute) {
                    ForEach(minutes, id: \.self) { minute in
                        Text(formatMinute(minute))
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Minute")
                .accessibilityValue(formatMinute(selectedMinute))
            }
            .padding(.horizontal)
            .frame(height: 180)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    // MARK: - Formatting
    
    /// Formats the selected time for display (12-hour format with AM/PM)
    private var formattedTime: String {
        let period = selectedHour < 12 ? "AM" : "PM"
        let displayHour = selectedHour == 0 ? 12 : (selectedHour > 12 ? selectedHour - 12 : selectedHour)
        return String(format: "%d:%02d %@", displayHour, selectedMinute, period)
    }
    
    /// Accessible version of the formatted time
    private var formattedTimeAccessible: String {
        let period = selectedHour < 12 ? "AM" : "PM"
        let displayHour = selectedHour == 0 ? 12 : (selectedHour > 12 ? selectedHour - 12 : selectedHour)
        return "\(displayHour) \(selectedMinute) \(period)"
    }
    
    /// Formats hour for picker display (12-hour format)
    private func formatHour(_ hour: Int) -> String {
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "AM" : "PM"
        return "\(displayHour) \(period)"
    }
    
    /// Formats minute for picker display
    private func formatMinute(_ minute: Int) -> String {
        String(format: "%02d", minute)
    }
    
    // MARK: - Actions
    
    /// Adds the selected schedule time and dismisses the sheet
    private func addScheduleTime() {
        guard let time = ScheduleTime.create(hour: selectedHour, minute: selectedMinute) else {
            return
        }
        
        Task {
            await viewModel.addScheduleTime(time)
            
            // Dismiss only if no error occurred
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Schedule Time Picker") {
    ScheduleTimePickerView(viewModel: ScheduleSettingsViewModel.preview)
}
#endif
