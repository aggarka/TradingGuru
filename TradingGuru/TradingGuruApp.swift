//
//  TradingGuruApp.swift
//  TradingGuru
//
//  Main app entry point with authentication flow.
//

import SwiftUI
import Combine
import UIKit
import UserNotifications

@main
struct TradingGuruApp: App {
    
    // MARK: - App Delegate
    
    /// App delegate adaptor for UIKit lifecycle events and background task registration.
    /// - Validates: Requirement 1.1 (Register BGProcessingTask on app launch)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - App State
    
    /// The authentication service shared across the app
    @State private var authService: AuthenticationServiceImpl
    
    /// The auth view model for managing authentication state
    @State private var authViewModel: AuthViewModel
    
    // MARK: - Initialization
    
    init() {
        // Create the authentication service
        let service = AuthenticationServiceImpl()
        
        // Register authentication providers
        // Google uses mock mode for now (SDK not integrated)
        let googleProvider = GoogleAuthProvider(useMockMode: true, mockDelay: 1.0)
        googleProvider.configureMockUser(email: "user@gmail.com", displayName: "Google User")
        service.registerProvider(googleProvider)
        
        // Apple Sign-In - using mock mode since capability isn't configured
        // To use real Apple Sign-In:
        // 1. Open project in Xcode
        // 2. Select TradingGuru target > Signing & Capabilities
        // 3. Click + Capability > Sign in with Apple
        // 4. Set useMockMode to false below
        let appleProvider = AppleAuthProvider(useMockMode: false)

        //let appleProvider = AppleAuthProvider(useMockMode: true)
        service.registerProvider(appleProvider)
        
        // Passkey uses mock mode for now
        let passkeyProvider = PasskeyAuthProvider(useMockMode: true)
        service.registerProvider(passkeyProvider)
        
        // Initialize state
        _authService = State(initialValue: service)
        _authViewModel = State(initialValue: AuthViewModel(authenticationService: service))
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView(authViewModel: authViewModel)
        }
    }
}

// MARK: - Root View

/// Root view that handles navigation between authentication, onboarding, and main app
struct RootView: View {
    @Bindable var authViewModel: AuthViewModel
    
    /// Whether to show the onboarding flow
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if authViewModel.shouldNavigateToHome {
                // Check if onboarding should be shown
                if showOnboarding {
                    OnboardingView {
                        showOnboarding = false
                    }
                } else {
                    // Show main app content when authenticated
                    HomeView(authViewModel: authViewModel)
                }
            } else {
                // Show authentication view when not authenticated
                AuthenticationView(
                    onSignIn: authViewModel.makeSignInHandler(),
                    onAuthenticationSuccess: authViewModel.makeAuthenticationSuccessHandler()
                )
            }
        }
        .animation(.easeInOut, value: authViewModel.shouldNavigateToHome)
        .onChange(of: authViewModel.shouldNavigateToHome) { _, navigateToHome in
            // Show onboarding when user first signs in and hasn't completed it
            if navigateToHome && !OnboardingManager.shared.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
}

// MARK: - Home View with TabView

/// Main home view shown after successful authentication with tab navigation.
///
/// Implements the main app navigation structure with four tabs:
/// - Watchlist: Manage stock ticker symbols
/// - Analysis: Select and configure trading strategies
/// - Results: View analysis results in table format
/// - Settings: Configure user preferences and account
///
/// - Validates: Requirement 1.5 (Navigate to home screen after authentication)
/// - Validates: Requirement 1.9 (Provide access to protected features while authenticated)
struct HomeView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var selectedTab: TabSelection = .watchlist
    @State private var watchlistViewModel: WatchlistViewModel?
    @State private var analysisViewModel: AnalysisViewModel?
    @State private var resultsViewModel: ResultsViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    
    enum TabSelection {
        case watchlist
        case analysis
        case results
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Watchlist Tab
            if let viewModel = watchlistViewModel {
                WatchlistView(viewModel: viewModel)
                    .tabItem {
                        Label("Watchlist", systemImage: "list.bullet")
                    }
                    .tag(TabSelection.watchlist)
            } else {
                ProgressView("Loading...")
                    .tabItem {
                        Label("Watchlist", systemImage: "list.bullet")
                    }
                    .tag(TabSelection.watchlist)
            }
            
            // Analysis Tab
            // - Validates: Requirement 3.1 (Display strategy selection dropdown)
            // - Validates: Requirement 3.2 (Include Weekly_Option_Strategy)
            // - Validates: Requirements 4.1-4.11 (Configuration handling)
            if let viewModel = analysisViewModel {
                AnalysisView(viewModel: viewModel)
                    .tabItem {
                        Label("Analysis", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(TabSelection.analysis)
            } else {
                ProgressView("Loading...")
                    .tabItem {
                        Label("Analysis", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(TabSelection.analysis)
            }
            
            // Results Tab
            // - Validates: Requirements 6.1-6.8 (Results display)
            if let viewModel = resultsViewModel {
                ResultsView(viewModel: viewModel)
                    .tabItem {
                        Label("Results", systemImage: "tablecells")
                    }
                    .tag(TabSelection.results)
            } else {
                ProgressView("Loading...")
                    .tabItem {
                        Label("Results", systemImage: "tablecells")
                    }
                    .tag(TabSelection.results)
            }
            
            // Settings Tab
            // - Validates: Requirement 8.8 (Settings option for scheduled analysis)
            // - Validates: Requirement 9.1 (Email notification settings)
            // - Validates: Requirement 9.10 (Email notification toggle)
            if let viewModel = settingsViewModel {
                MainSettingsView(
                    settingsViewModel: viewModel,
                    authViewModel: authViewModel
                )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(TabSelection.settings)
            } else {
                ProgressView("Loading...")
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(TabSelection.settings)
            }
        }
        .task {
            // Initialize ViewModels with the current user
            if let userId = authViewModel.currentUser?.id {
                // Initialize Watchlist ViewModel
                // Use retryable repository wrapper for automatic exponential backoff (1s, 2s, 4s)
                // - Validates: Requirement 2.9 (Database unavailability shows error and preserves local state)
                // - Validates: Requirement 7.6 (Retry failed operations up to 3 times)
                // - Validates: Requirement 7.7 (Display message suggesting network check after exhausting retries)
                let baseWatchlistRepository = LocalWatchlistRepository()
                let retryableWatchlistRepository = RetryableWatchlistRepository(
                    repository: baseWatchlistRepository,
                    retryService: DatabaseRetryService()
                )
                let watchlistValidation = WatchlistValidationService()
                watchlistViewModel = WatchlistViewModel(
                    repository: retryableWatchlistRepository,
                    validation: watchlistValidation,
                    userId: userId
                )
                
                // Initialize Analysis ViewModel
                // Use retryable configuration repository for automatic exponential backoff (1s, 2s, 4s)
                // - Validates: Requirement 4.6 (Persist configuration to database)
                // - Validates: Requirement 4.7 (Load previously saved configuration)
                // - Validates: Requirement 4.8 (Apply defaults if no saved config)
                // - Validates: Requirement 4.9 (Display error and retain values on save failure)
                // - Validates: Requirement 7.6 (Retry failed operations up to 3 times)
                let baseConfigRepository = ConfigurationRepositoryImpl.forTesting()
                let retryableConfigRepository = RetryableConfigurationRepository(
                    repository: baseConfigRepository,
                    retryService: DatabaseRetryService()
                )
                let configValidation = ConfigurationValidationService()
                analysisViewModel = AnalysisViewModel(
                    configurationRepository: retryableConfigRepository,
                    validationService: configValidation,
                    userId: userId
                )
                
                // Initialize Results ViewModel with persistence
                // - Validates: Requirements 6.1-6.8 (Results display)
                // - Validates: Requirement 8.5 (Display most recent results)
                let resultsRepository = LocalResultsRepository()
                resultsViewModel = ResultsViewModel(
                    resultsRepository: resultsRepository,
                    userId: userId
                )
                
                // Load previously saved results
                if let resultsVM = resultsViewModel {
                    await resultsVM.loadResults()
                }
                
                // Sync initial onlyOrders filter from configuration to results view
                // - Validates: Requirement 4.5 (ONLY_ORDERS filter)
                if let analysisVM = analysisViewModel, let resultsVM = resultsViewModel {
                    resultsVM.setOnlyOrdersFilter(analysisVM.weeklyOptionConfiguration.onlyOrders)
                    resultsVM.setOptionTypeFilter(analysisVM.weeklyOptionConfiguration.optionTypeFilter.opportunityType)
                }
                
                // Initialize Settings ViewModel
                // - Validates: Requirement 8.8 (Settings option for scheduled analysis)
                // - Validates: Requirement 9.1, 9.10 (Email notification settings)
                let settingsRepository = LocalSettingsRepository()
                settingsViewModel = SettingsViewModel(
                    repository: settingsRepository,
                    userId: userId
                )
            }
        }
        // Sync watchlist tickers to analysis view model when switching to Analysis tab
        // or when watchlist changes
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .analysis {
                syncWatchlistToAnalysis()
            }
        }
        .onChange(of: watchlistViewModel?.symbols) { _, _ in
            // Sync whenever watchlist changes (if on analysis tab)
            if selectedTab == .analysis {
                syncWatchlistToAnalysis()
            }
        }
        // Sync analysis results to results view when analysis completes and save for persistence
        // Also send notification if ORDER signals are found
        .onChange(of: analysisViewModel?.analysisResults) { _, newResults in
            if let results = newResults, !results.isEmpty, let resultsVM = resultsViewModel {
                // Create metadata for the analysis run
                let metadata = ResultsMetadata(
                    timestamp: Date(),
                    source: .manual,
                    strategyId: WeeklyOptionConfiguration.strategyId
                )
                
                // Update the view with results
                resultsVM.updateResults(results, metadata: metadata)
                
                // Save results for persistence
                Task {
                    await resultsVM.saveResults(results, metadata: metadata)
                }
                
                // Send notification if ORDER signals found
                let orderCount = results.filter { $0.signal == .order }.count
                print("[TradingGuru] Analysis complete: \(results.count) results, \(orderCount) ORDER signals")
                
                if orderCount > 0 {
                    Task {
                        print("[TradingGuru] Sending notification for \(orderCount) ORDER signals...")
                        // Send notification directly for manual analysis
                        let notificationManager = LocalNotificationManager()
                        let content = UNMutableNotificationContent()
                        content.title = "TradingGuru Analysis Complete"
                        content.body = "\(orderCount) ORDER signal\(orderCount == 1 ? "" : "s") found! Tap to review."
                        content.badge = NSNumber(value: orderCount)
                        content.sound = .default
                        content.categoryIdentifier = LocalNotificationManager.analysisCategoryId
                        content.userInfo = ["action": "showResults"]
                        
                        let request = UNNotificationRequest(
                            identifier: "analysis-\(UUID().uuidString)",
                            content: content,
                            trigger: nil
                        )
                        
                        do {
                            try await UNUserNotificationCenter.current().add(request)
                            print("[TradingGuru] Notification sent successfully!")
                        } catch {
                            print("[TradingGuru] Failed to send notification: \(error)")
                        }
                    }
                }
            }
        }
        // Sync the onlyOrders filter from configuration to results view
        // - Validates: Requirement 4.5 (ONLY_ORDERS filter)
        .onChange(of: analysisViewModel?.weeklyOptionConfiguration.onlyOrders) { _, newValue in
            if let onlyOrders = newValue {
                resultsViewModel?.setOnlyOrdersFilter(onlyOrders)
            }
        }
        // Sync the optionTypeFilter from configuration to results view
        .onChange(of: analysisViewModel?.weeklyOptionConfiguration.optionTypeFilter) { _, newValue in
            if let filter = newValue {
                resultsViewModel?.setOptionTypeFilter(filter.opportunityType)
            }
        }
        // Sync filters when configuration finishes loading (initial load)
        .onChange(of: analysisViewModel?.isConfigurationLoaded) { _, isLoaded in
            if isLoaded == true, let analysisVM = analysisViewModel, let resultsVM = resultsViewModel {
                resultsVM.setOnlyOrdersFilter(analysisVM.weeklyOptionConfiguration.onlyOrders)
                resultsVM.setOptionTypeFilter(analysisVM.weeklyOptionConfiguration.optionTypeFilter.opportunityType)
            }
        }
        // MARK: - Deep Link Navigation
        // Handle navigation from notification tap to results screen.
        // When the user taps on an analysis complete notification, the AppDelegate posts
        // .showAnalysisResults notification. This observer switches to the Results tab.
        // Works whether the app was in foreground, background, or terminated.
        // - Validates: Requirement 3.6 (Navigate to analysis results screen on notification tap)
        .onReceive(NotificationCenter.default.publisher(for: .showAnalysisResults)) { _ in
            // Switch to the Results tab
            selectedTab = .results
            
            // Optionally refresh results if the view model is available
            if let resultsVM = resultsViewModel {
                Task {
                    await resultsVM.loadResults()
                }
            }
        }
        // MARK: - Scheduled Analysis Completed
        // Handle completion of foreground scheduled analysis.
        // Refreshes results display when scheduled analysis completes while app is active.
        .onReceive(NotificationCenter.default.publisher(for: .scheduledAnalysisCompleted)) { notification in
            print("[TradingGuru] Scheduled analysis completed notification received")
            
            // Refresh results display
            if let resultsVM = resultsViewModel {
                Task {
                    await resultsVM.loadResults()
                }
            }
            
            // Log the results
            if let userInfo = notification.userInfo,
               let resultsCount = userInfo["resultsCount"] as? Int,
               let orderCount = userInfo["orderCount"] as? Int {
                print("[TradingGuru] Scheduled analysis: \(resultsCount) results, \(orderCount) ORDER signals")
            }
        }
        // MARK: - Foreground Refresh
        // Handle app returning to foreground after background analysis.
        // When the app enters foreground, clear the badge count and refresh results
        // to display any new analysis results from background execution.
        // Also checks for missed scheduled analysis and runs it if needed.
        // - Validates: Requirement 5.5 (Refresh results display when app returns to foreground)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Clear badge count when app enters foreground
            UIApplication.shared.applicationIconBadgeNumber = 0
            
            // Refresh results display to show any new results from background analysis
            if let resultsVM = resultsViewModel {
                Task {
                    await resultsVM.loadResults()
                }
            }
            
            // Check for missed scheduled analysis and run if needed
            Task {
                await ForegroundScheduledAnalysisService.shared.checkForMissedAnalysis()
            }
            
            // Optionally refresh notification authorization status in settings
            if let settingsVM = settingsViewModel {
                Task {
                    await settingsVM.refreshNotificationAuthorizationStatus()
                }
            }
        }
    }
    
    /// Syncs the watchlist tickers from WatchlistViewModel to AnalysisViewModel
    private func syncWatchlistToAnalysis() {
        guard let watchlistVM = watchlistViewModel,
              let analysisVM = analysisViewModel else { return }
        analysisVM.setWatchlistTickers(watchlistVM.symbols)
    }
}

// MARK: - Account Settings View (Simplified)

/// Combined settings view that includes both app settings and account management.
///
/// Integrates SettingsView functionality (scheduled analysis, email notifications)
/// with account management features (sign out).
///
/// - Validates: Requirement 8.8 (Settings option for scheduled analysis)
/// - Validates: Requirement 9.1 (Email notification settings)
/// - Validates: Requirement 9.10 (Email notification toggle)
/// - Validates: Requirement 1.10 (Sign-out functionality)
struct MainSettingsView: View {
    @Bindable var settingsViewModel: SettingsViewModel
    @Bindable var authViewModel: AuthViewModel
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteAccountError = false
    @State private var showingOnboardingTutorial = false
    
    /// Local state for the email text field
    @State private var emailInput: String = ""
    
    /// Whether the email format is valid (nil means not validated yet)
    @State private var isEmailValid: Bool? = nil
    
    /// Whether the email field is currently focused
    @FocusState private var isEmailFieldFocused: Bool
    
    /// Whether to show the test notification result alert
    @State private var showTestNotificationAlert = false
    
    /// Message to show in the test notification alert
    @State private var testNotificationMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if settingsViewModel.isLoading {
                    loadingView
                } else {
                    settingsContent
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Settings Error", isPresented: $settingsViewModel.showError, presenting: settingsViewModel.currentError) { _ in
                Button("OK") {
                    settingsViewModel.clearError()
                }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    Task {
                        do {
                            try await authViewModel.deleteAccount()
                        } catch {
                            showingDeleteAccountError = true
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.")
            }
            .alert("Account Deletion Failed", isPresented: $showingDeleteAccountError) {
                Button("OK") { }
            } message: {
                Text(authViewModel.currentError?.catalogMessage(provider: nil) ?? "Unable to delete your account. Please try again or contact support.")
            }
            .alert("Test Notification", isPresented: $showTestNotificationAlert) {
                Button("OK") { }
            } message: {
                Text(testNotificationMessage)
            }
            .fullScreenCover(isPresented: $showingOnboardingTutorial) {
                OnboardingView {
                    showingOnboardingTutorial = false
                }
            }
            .task {
                await settingsViewModel.loadSettings()
            }
            .onChange(of: settingsViewModel.notificationEmail) { _, newValue in
                emailInput = newValue ?? ""
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
    }
    
    // MARK: - Settings Content
    
    private var settingsContent: some View {
        List {
            // Account Section
            accountSection
            
            // Scheduled Analysis Section
            scheduledAnalysisSection
            
            // Email Notifications Section
            emailNotificationsSection
            
            // Save Status Section
            if let statusMessage = settingsViewModel.saveState.statusMessage {
                saveStatusSection(message: statusMessage)
            }
            
            // Help & Support Section
            helpSection
            
            // Sign Out Section
            signOutSection
            
            // Delete Account Section
            deleteAccountSection
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            if let user = authViewModel.currentUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName ?? "User")
                            .font(.headline)
                        if let email = user.email {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Signed in with \(user.authProvider.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            if let expiration = authViewModel.sessionExpirationDate {
                HStack {
                    Text("Session expires")
                    Spacer()
                    Text(expiration, style: .date)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Scheduled Analysis Section
    
    /// - Validates: Requirement 8.8 (Settings option for scheduled analysis, default enabled)
    /// - Validates: Requirement 2.1 (Settings interface for schedule times)
    /// - Validates: Requirement 3.2 (Notification permission status and iOS Settings link)
    private var scheduledAnalysisSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settingsViewModel.scheduledAnalysisEnabled },
                set: { newValue in
                    Task {
                        await settingsViewModel.setScheduledAnalysisEnabled(newValue)
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
            .disabled(settingsViewModel.saveState.isSaving)
            
            // Schedule configuration link - shown when scheduled analysis is enabled
            /// - Validates: Requirement 2.1 (Settings interface for schedule times)
            if settingsViewModel.scheduledAnalysisEnabled {
                scheduleConfigurationLink
            }
            
            // Notification permission status - shown when scheduled analysis is enabled
            /// - Validates: Requirement 3.2 (Show notification permission status)
            if settingsViewModel.scheduledAnalysisEnabled {
                notificationPermissionRow
            }
            
            // Test Notification button - shown when scheduled analysis is enabled
            if settingsViewModel.scheduledAnalysisEnabled {
                testNotificationButton
            }
        } header: {
            Text("Analysis")
        } footer: {
            if settingsViewModel.scheduledAnalysisEnabled {
                Text("Configure your schedule times and notification preferences to customize when and how you receive analysis alerts.")
            } else {
                Text("When enabled, your watchlist will be analyzed automatically at your configured schedule times.")
            }
        }
    }
    
    // MARK: - Test Notification Button
    
    /// Button to send a test notification for debugging purposes.
    private var testNotificationButton: some View {
        Button {
            Task {
                let success = await settingsViewModel.sendTestNotification()
                if success {
                    testNotificationMessage = "Test notification sent! Check your notifications."
                } else {
                    testNotificationMessage = "Failed to send notification. Please enable notifications first."
                }
                showTestNotificationAlert = true
            }
        } label: {
            HStack {
                Image(systemName: "bell.and.waves.left.and.right")
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Test Notification")
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text("Verify notifications are working")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .accessibilityLabel("Send Test Notification")
        .accessibilityHint("Double tap to send a test notification and verify delivery is working")
    }
    
    // MARK: - Schedule Configuration Link
    
    /// NavigationLink to ScheduleSettingsView for configuring schedule times.
    /// - Validates: Requirement 2.1 (Settings interface for schedule times)
    private var scheduleConfigurationLink: some View {
        NavigationLink {
            ScheduleSettingsView(
                viewModel: createScheduleSettingsViewModel(),
                scheduledAnalysisEnabled: settingsViewModel.scheduledAnalysisEnabled
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
            settingsRepository: settingsViewModel.repository,
            userId: authViewModel.currentUser?.id ?? ""
        )
    }
    
    // MARK: - Notification Permission Row
    
    /// Row showing notification permission status with link to iOS Settings if denied.
    /// - Validates: Requirement 3.2 (Show notification permission status and iOS Settings link)
    private var notificationPermissionRow: some View {
        Group {
            switch settingsViewModel.notificationAuthorizationStatus {
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
                        await settingsViewModel.requestNotificationPermission()
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
    
    /// - Validates: Requirement 9.1, 9.2, 9.10 (Email notification settings)
    private var emailNotificationsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settingsViewModel.emailNotificationsEnabled },
                set: { newValue in
                    Task {
                        await settingsViewModel.setEmailNotificationsEnabled(newValue)
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
            .disabled(settingsViewModel.saveState.isSaving)
            
            // Email address input field
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
                    .disabled(settingsViewModel.saveState.isSaving)
                    .focused($isEmailFieldFocused)
                    .onChange(of: emailInput) { _, newValue in
                        validateEmailInput(newValue)
                    }
                    .onSubmit {
                        saveEmailIfValid()
                    }
                
                // Email validation error
                if let isValid = isEmailValid, !isValid, !emailInput.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Save button
                if hasEmailChanged {
                    HStack {
                        Spacer()
                        Button(action: { saveEmailIfValid() }) {
                            HStack(spacing: 6) {
                                if settingsViewModel.saveState.isSaving {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                                Text("Save Email")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSaveEmail)
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
    
    // MARK: - Help & Support Section
    
    /// Help section with link to How to Use guide and tutorial replay.
    private var helpSection: some View {
        Section("Help & Support") {
            NavigationLink {
                HowToUseView()
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.blue)
                    Text("How to Use TradingGuru")
                }
            }
            
            Button {
                showingOnboardingTutorial = true
            } label: {
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.purple)
                    Text("View Tutorial")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Sign Out Section
    
    /// - Validates: Requirement 1.10 (Sign-out clears session and returns to auth screen)
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Delete Account Section
    
    /// Delete account section for App Store compliance.
    /// Apps with account creation must provide account deletion.
    private var deleteAccountSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteAccountAlert = true
            } label: {
                HStack {
                    Spacer()
                    if authViewModel.isDeletingAccount {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text("Delete Account")
                    Spacer()
                }
            }
            .disabled(authViewModel.isDeletingAccount)
        } footer: {
            Text("Permanently delete your account and all associated data. This action cannot be undone.")
        }
    }
    
    // MARK: - Save Status Section
    
    private func saveStatusSection(message: String) -> some View {
        Section {
            HStack {
                if settingsViewModel.saveState.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                } else if case .saved = settingsViewModel.saveState {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(.trailing, 4)
                } else if case .failed = settingsViewModel.saveState {
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
    
    // MARK: - Email Validation Helpers
    
    private var hasEmailChanged: Bool {
        let savedEmail = settingsViewModel.notificationEmail ?? ""
        return emailInput != savedEmail
    }
    
    private var canSaveEmail: Bool {
        if emailInput.isEmpty {
            return hasEmailChanged
        }
        return isEmailValid == true && hasEmailChanged && !settingsViewModel.saveState.isSaving
    }
    
    private func validateEmailInput(_ email: String) {
        if email.isEmpty {
            isEmailValid = nil
        } else {
            isEmailValid = email.isValidEmail
        }
    }
    
    private func saveEmailIfValid() {
        isEmailFieldFocused = false
        
        if emailInput.isEmpty {
            Task {
                await settingsViewModel.setNotificationEmail(nil)
            }
            return
        }
        
        guard emailInput.isValidEmail else {
            isEmailValid = false
            return
        }
        
        Task {
            await settingsViewModel.setNotificationEmail(emailInput)
        }
    }
}

// MARK: - Account Settings View (Legacy - kept for compatibility)

struct AccountSettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section("Account") {
                    if let user = authViewModel.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName ?? "User")
                                    .font(.headline)
                                if let email = user.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Signed in with \(user.authProvider.displayName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let expiration = authViewModel.sessionExpirationDate {
                        HStack {
                            Text("Session expires")
                            Spacer()
                            Text(expiration, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Upcoming Features Section
                Section("Coming Soon") {
                    Label("Email Notifications", systemImage: "envelope")
                        .foregroundStyle(.secondary)
                    Label("Scheduled Analysis", systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
                
                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Root - Not Authenticated") {
    RootView(authViewModel: AuthViewModel.preview)
}

#Preview("Root - Authenticated") {
    RootView(authViewModel: AuthViewModel.authenticatedPreview)
}

#Preview("Settings View") {
    let mockRepo = MockSettingsRepository()
    let settingsVM = SettingsViewModel(repository: mockRepo, userId: "preview-user")
    let authVM = AuthViewModel.authenticatedPreview
    return MainSettingsView(settingsViewModel: settingsVM, authViewModel: authVM)
}
#endif
