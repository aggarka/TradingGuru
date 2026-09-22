//
//  ScheduleSettingsView.swift
//  TradingGuru
//
//  Settings view for configuring schedule times and notification frequency.
//

import SwiftUI

/// View for managing schedule times and notification frequency settings.
///
/// Displays a Form with sections for:
/// - Schedule times list with swipe-to-delete
/// - Add schedule time button (disabled at max capacity)
/// - Notification frequency picker
///
/// - Validates: Requirement 2.1 (Settings interface for schedule times)
/// - Validates: Requirement 2.3 (Add schedule time with persistence)
/// - Validates: Requirement 2.4 (Remove schedule time with persistence)
/// - Validates: Requirement 2.5 (1-8 schedule times limit)
/// - Validates: Requirement 2.6 (Maximum limit error message)
/// - Validates: Requirement 2.8 (Message when no schedule times configured)
/// - Validates: Requirement 4.1 (Notification frequency options)
/// - Validates: Requirement 4.6 (Notification frequency persistence)
struct ScheduleSettingsView: View {
    
    // MARK: - ViewModel
    
    @ObservedObject var viewModel: ScheduleSettingsViewModel
    
    /// Whether scheduled analysis is enabled (passed from parent settings)
    var scheduledAnalysisEnabled: Bool = true
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // Schedule Times Section
            scheduleTimesSection
            
            // Notifications Section
            notificationsSection
        }
        .navigationTitle("Schedule Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showTimePicker) {
            ScheduleTimePickerView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadSettings()
        }
        .onChange(of: viewModel.scheduleTimes) { _, _ in
            Task {
                await viewModel.updateBackgroundScheduling()
            }
        }
        .onChange(of: viewModel.notificationFrequency) { _, _ in
            Task {
                await viewModel.saveSettings()
            }
        }
    }
    
    // MARK: - Schedule Times Section
    
    /// Section displaying schedule times list with add/delete functionality.
    /// - Validates: Requirement 2.1 (Settings interface for schedule times)
    /// - Validates: Requirement 2.3 (Add schedule time)
    /// - Validates: Requirement 2.4 (Remove schedule time)
    /// - Validates: Requirement 2.5 (1-8 schedule times)
    /// - Validates: Requirement 2.6 (Maximum limit message)
    private var scheduleTimesSection: some View {
        Section {
            // Warning message when scheduled analysis is enabled but no times configured
            /// - Validates: Requirement 2.8 (Message when no schedule times)
            if scheduledAnalysisEnabled && viewModel.hasNoScheduleTimes {
                noScheduleTimesWarning
            }
            
            // List of schedule times with swipe-to-delete
            ForEach(viewModel.scheduleTimes, id: \.self) { time in
                scheduleTimeRow(time)
            }
            .onDelete { offsets in
                Task {
                    await viewModel.removeScheduleTimes(at: offsets)
                }
            }
            
            // Add button or max limit message
            /// - Validates: Requirement 2.5 (Maximum of 8 schedule times)
            /// - Validates: Requirement 2.6 (Error message for maximum limit)
            if viewModel.canAddMoreTimes {
                addScheduleTimeButton
            } else {
                maximumLimitMessage
            }
        } header: {
            Text("Schedule Times")
        } footer: {
            scheduleTimesFooter
        }
    }
    
    /// Warning message when scheduled analysis is enabled but no times are configured.
    private var noScheduleTimesWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No Schedule Times")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Add at least one schedule time for background analysis to run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: No schedule times configured. Add at least one schedule time for background analysis to run.")
    }
    
    /// Row displaying a single schedule time.
    private func scheduleTimeRow(_ time: ScheduleTime) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.blue)
                .font(.body)
            
            Text(time.displayStringWithPeriod)
                .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scheduled time: \(time.displayStringWithPeriod)")
        .accessibilityHint("Swipe left to delete")
    }
    
    /// Button to add a new schedule time.
    private var addScheduleTimeButton: some View {
        Button {
            viewModel.showTimePicker = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                
                Text("Add Schedule Time")
                    .foregroundStyle(.blue)
            }
        }
        .accessibilityLabel("Add Schedule Time")
        .accessibilityHint("Double tap to open time picker. \(viewModel.remainingSlots) slots remaining.")
    }
    
    /// Message displayed when maximum schedule times reached.
    private var maximumLimitMessage: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            
            Text("Maximum of \(UserSettings.maxScheduleTimes) schedule times reached")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Maximum of \(UserSettings.maxScheduleTimes) schedule times reached. Delete an existing time to add a new one.")
    }
    
    /// Footer text for schedule times section.
    private var scheduleTimesFooter: some View {
        Group {
            if viewModel.scheduleTimes.isEmpty {
                Text("Configure when you want background analysis to run. You can add up to \(UserSettings.maxScheduleTimes) different times.")
            } else {
                Text("Background analysis will run at the scheduled times when the device is connected to WiFi and charging. Swipe left on a time to delete it.")
            }
        }
    }
    
    // MARK: - Notifications Section
    
    /// Section for notification frequency settings.
    /// - Validates: Requirement 4.1 (Notification frequency options)
    /// - Validates: Requirement 4.6 (Notification frequency persistence)
    private var notificationsSection: some View {
        Section {
            Picker("Frequency", selection: $viewModel.notificationFrequency) {
                ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.displayLabel)
                        .tag(frequency)
                }
            }
            .accessibilityLabel("Notification Frequency")
            .accessibilityValue(viewModel.notificationFrequency.displayLabel)
            .accessibilityHint("Double tap to change how often you receive notifications")
        } header: {
            Text("Notifications")
        } footer: {
            Text("Controls how often you receive notifications when ORDER signals are found. Choose a lower frequency to reduce notification volume.")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Schedule Settings - Default") {
    NavigationStack {
        ScheduleSettingsView(viewModel: ScheduleSettingsViewModel.preview)
    }
}

#Preview("Schedule Settings - Full") {
    NavigationStack {
        ScheduleSettingsView(viewModel: ScheduleSettingsViewModel.fullPreview)
    }
}

#Preview("Schedule Settings - Empty") {
    NavigationStack {
        ScheduleSettingsView(
            viewModel: ScheduleSettingsViewModel.emptyPreview,
            scheduledAnalysisEnabled: true
        )
    }
}
#endif
