//
//  SettingsView.swift
//  TradingGuru
//
//  Settings screen for managing user preferences including scheduled analysis.
//

import SwiftUI

/// View displaying user settings with toggle controls.
///
/// Displays settings for scheduled analysis and email notifications,
/// with toggles that persist changes to the database.
///
/// - Validates: Requirement 8.8 (Settings option to enable/disable scheduled analysis)
/// - Validates: Requirement 9.1 (Email notification settings)
/// - Validates: Requirement 9.2 (Email format validation with error message)
/// - Validates: Requirement 9.10 (Email notification toggle)
/// - Validates: Requirement 2.1 (Settings interface for schedule times)
/// - Validates: Requirement 3.2 (Notification permission status and iOS Settings link)
struct SettingsView: View {
    // MARK: - ViewModel
    
    /// The ViewModel managing settings state and operations
    @Bindable var viewModel: SettingsViewModel
    
    // MARK: - Local State
    
    /// Local state for the email text field
    @State private var emailInput: String = ""
    
    /// Whether the email format is valid (nil means not validated yet)
    @State private var isEmailValid: Bool? = nil
    
    /// Whether the email field is currently focused
    @FocusState private var isEmailFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    settingsContent
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Settings Error", isPresented: $viewModel.showError, presenting: viewModel.currentError) { _ in
                Button("OK") {
                    viewModel.clearError()
                }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
            .task {
                await viewModel.loadSettings()
            }
            .onChange(of: viewModel.notificationEmail) { _, newValue in
                // Sync email input when ViewModel loads settings
                emailInput = newValue ?? ""
                // Reset validation state when settings are loaded
                if !emailInput.isEmpty {
                    isEmailValid = emailInput.isValidEmail
                } else {
                    isEmailValid = nil
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading settings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading settings, please wait")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Settings Content
    
    private var settingsContent: some View {
        List {
            // Scheduled Analysis Section
            scheduledAnalysisSection
            
            // Email Notifications Section
            emailNotificationsSection
            
            // Save Status Section
            if let statusMessage = viewModel.saveState.statusMessage {
                saveStatusSection(message: statusMessage)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Scheduled Analysis Section
    
    /// - Validates: Requirement 8.8 (Settings option for scheduled analysis, default enabled)
    /// - Validates: Requirement 2.1 (Settings interface for schedule times)
    /// - Validates: Requirement 3.2 (Notification permission status and iOS Settings link)
    private var scheduledAnalysisSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.scheduledAnalysisEnabled },
                set: { newValue in
                    Task {
                        await viewModel.setScheduledAnalysisEnabled(newValue)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scheduled Analysis")
                        .font(.body)
                    
                    Text("Automatically run analysis at predefined times during trading hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.saveState.isSaving)
            .accessibilityLabel("Scheduled Analysis")
            .accessibilityValue(viewModel.scheduledAnalysisEnabled ? "Enabled" : "Disabled")
            .accessibilityHint("Double tap to toggle scheduled analysis on or off")
            
            // Schedule configuration link - shown when scheduled analysis is enabled
            /// - Validates: Requirement 2.1 (Settings interface for schedule times)
            if viewModel.scheduledAnalysisEnabled {
                scheduleConfigurationLink
            }
            
            // Notification permission status - shown when scheduled analysis is enabled
            /// - Validates: Requirement 3.2 (Show notification permission status)
            if viewModel.scheduledAnalysisEnabled {
                notificationPermissionRow
            }
        } header: {
            Text("Analysis")
        } footer: {
            if viewModel.scheduledAnalysisEnabled {
                Text("Configure your schedule times and notification preferences to customize when and how you receive analysis alerts.")
            } else {
                Text("When enabled, your watchlist will be analyzed automatically at your configured schedule times.")
            }
        }
    }
    
    // MARK: - Schedule Configuration Link
    
    /// NavigationLink to ScheduleSettingsView for configuring schedule times.
    /// - Validates: Requirement 2.1 (Settings interface for schedule times)
    private var scheduleConfigurationLink: some View {
        NavigationLink {
            ScheduleSettingsView(
                viewModel: createScheduleSettingsViewModel(),
                scheduledAnalysisEnabled: viewModel.scheduledAnalysisEnabled
            )
        } label: {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configure Schedule Times")
                        .font(.body)
                    
                    Text("Set when background analysis runs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .accessibilityLabel("Configure Schedule Times")
        .accessibilityHint("Double tap to configure when background analysis runs")
    }
    
    /// Creates a ScheduleSettingsViewModel instance for the schedule settings view.
    private func createScheduleSettingsViewModel() -> ScheduleSettingsViewModel {
        ScheduleSettingsViewModel(
            settingsRepository: viewModel.repository,
            userId: viewModel.userId
        )
    }
    
    // MARK: - Notification Permission Row
    
    /// Row showing notification permission status with link to iOS Settings if denied.
    /// - Validates: Requirement 3.2 (Show notification permission status and iOS Settings link)
    private var notificationPermissionRow: some View {
        Group {
            switch viewModel.notificationAuthorizationStatus {
            case .authorized:
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.green)
                    
                    Text("Notifications Enabled")
                        .font(.body)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Notifications are enabled")
                
            case .denied:
                Button {
                    openNotificationSettings()
                } label: {
                    HStack {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Disabled")
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Text("Tap to open Settings and enable notifications")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Notifications disabled")
                .accessibilityHint("Double tap to open iOS Settings and enable notifications")
                
            case .notDetermined:
                Button {
                    Task {
                        await viewModel.requestNotificationPermission()
                    }
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Notifications")
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Text("Tap to allow notifications for analysis alerts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .accessibilityLabel("Enable Notifications")
                .accessibilityHint("Double tap to request notification permission")
                
            case .provisional:
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(.blue)
                    
                    Text("Provisional Notifications")
                        .font(.body)
                    
                    Spacer()
                    
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Provisional notifications enabled")
            }
        }
    }
    
    /// Opens the iOS Settings app to the notification settings for this app.
    private func openNotificationSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - Email Notifications Section
    
    /// - Validates: Requirement 9.1 (Settings screen for notification email)
    /// - Validates: Requirement 9.2 (Email format validation with error message)
    /// - Validates: Requirement 9.10 (Email notification toggle)
    private var emailNotificationsSection: some View {
        Section {
            // Email notifications toggle
            Toggle(isOn: Binding(
                get: { viewModel.emailNotificationsEnabled },
                set: { newValue in
                    Task {
                        await viewModel.setEmailNotificationsEnabled(newValue)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email Notifications")
                        .font(.body)
                    
                    Text("Receive analysis results via email after each scheduled run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.saveState.isSaving)
            .accessibilityLabel("Email Notifications")
            .accessibilityValue(viewModel.emailNotificationsEnabled ? "Enabled" : "Disabled")
            .accessibilityHint("Double tap to toggle email notifications on or off")
            
            // Email address input field
            /// - Validates: Requirement 9.1 (Configure notification email address)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Notification Email")
                        .font(.body)
                    Spacer()
                }
                
                TextField("Enter email address", text: $emailInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .disabled(viewModel.saveState.isSaving)
                    .focused($isEmailFieldFocused)
                    .onChange(of: emailInput) { _, newValue in
                        validateEmailInput(newValue)
                    }
                    .onSubmit {
                        saveEmailIfValid()
                    }
                    .accessibilityLabel("Notification Email Address")
                    .accessibilityHint("Enter your email address to receive analysis results")
                
                // Email validation error message
                /// - Validates: Requirement 9.2 (Display error message if format is invalid)
                if let isValid = isEmailValid, !isValid, !emailInput.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Error: Please enter a valid email address")
                }
                
                // Save button for email
                if hasEmailChanged {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            saveEmailIfValid()
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.saveState.isSaving {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                                Text("Save Email")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSaveEmail)
                        .accessibilityLabel("Save Email Address")
                        .accessibilityHint(canSaveEmail ? "Double tap to save your email address" : "Cannot save: email is invalid or empty")
                    }
                    .padding(.top, 4)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if emailInput.isEmpty {
                Text("Configure your notification email address to receive analysis results.")
            } else if isEmailValid == true {
                Text("Analysis results will be sent to your configured email address after each scheduled run.")
            } else {
                Text("Enter a valid email address to save.")
            }
        }
    }
    
    // MARK: - Email Validation Helpers
    
    /// Checks if the email input has changed from the saved value
    private var hasEmailChanged: Bool {
        let savedEmail = viewModel.notificationEmail ?? ""
        return emailInput != savedEmail
    }
    
    /// Checks if the current email can be saved (valid format or empty to clear)
    private var canSaveEmail: Bool {
        // Allow saving if empty (to clear) or if valid email format
        if emailInput.isEmpty {
            return hasEmailChanged
        }
        return isEmailValid == true && hasEmailChanged && !viewModel.saveState.isSaving
    }
    
    /// Validates the email input and updates the validation state
    /// - Parameter email: The email string to validate
    private func validateEmailInput(_ email: String) {
        if email.isEmpty {
            isEmailValid = nil
        } else {
            isEmailValid = email.isValidEmail
        }
    }
    
    /// Saves the email if it's valid, otherwise shows validation error
    private func saveEmailIfValid() {
        isEmailFieldFocused = false
        
        // If empty, allow clearing the email
        if emailInput.isEmpty {
            Task {
                await viewModel.setNotificationEmail(nil)
            }
            return
        }
        
        // Validate before saving
        /// - Validates: Requirement 9.2 (Validate email format before saving)
        guard emailInput.isValidEmail else {
            isEmailValid = false
            return
        }
        
        Task {
            await viewModel.setNotificationEmail(emailInput)
        }
    }
    
    // MARK: - Save Status Section
    
    private func saveStatusSection(message: String) -> some View {
        Section {
            HStack {
                if viewModel.saveState.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                } else if case .saved = viewModel.saveState {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(.trailing, 4)
                } else if case .failed = viewModel.saveState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .padding(.trailing, 4)
                }
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Settings View - Default") {
    let viewModel = SettingsViewModel.preview
    Task {
        await viewModel.loadSettings()
    }
    return SettingsView(viewModel: viewModel)
}

#Preview("Settings View - Analysis Disabled") {
    let viewModel = SettingsViewModel.disabledPreview
    Task {
        await viewModel.loadSettings()
    }
    return SettingsView(viewModel: viewModel)
}
#endif
