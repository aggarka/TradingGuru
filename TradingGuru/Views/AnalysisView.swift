//
//  AnalysisView.swift
//  TradingGuru
//
//  Analysis screen for strategy selection and configuration.
//

import SwiftUI

/// View displaying strategy selection dropdown and configuration interface.
///
/// Allows users to:
/// - Select a trading strategy from a dropdown with a placeholder prompt
/// - View and modify the configuration for the selected strategy
/// - Run analysis with the configured strategy
///
/// - Validates: Requirement 3.1 (Display strategy selection dropdown with placeholder prompt)
/// - Validates: Requirement 3.2 (Include Weekly_Option_Strategy as available option)
/// - Validates: Requirement 3.3 (Load and display configuration interface within 2 seconds)
/// - Validates: Requirement 3.6 (Disable run analysis button when no strategy selected)
struct AnalysisView: View {
    // MARK: - ViewModel
    
    /// The ViewModel managing analysis state and operations
    @Bindable var viewModel: AnalysisViewModel
    
    // MARK: - Local State
    
    /// Tracks the selected strategy ID for the Picker binding
    @State private var selectedStrategyId: String = ""
    
    /// Tracks if initial auto-selection has been done
    @State private var hasAutoSelected: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Strategy selection section
                    strategySelectionSection
                    
                    // Configuration interface or placeholder
                    configurationSection
                    
                    Spacer(minLength: 0)
                    
                    // Run analysis button
                    runAnalysisSection
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Auto-select the first strategy when view appears
                if !hasAutoSelected, let firstStrategy = viewModel.availableStrategies.first {
                    hasAutoSelected = true
                    selectedStrategyId = firstStrategy.id
                    handleStrategySelection(firstStrategy.id)
                }
            }
            .alert("Analysis Error", isPresented: $viewModel.showError, presenting: viewModel.currentError) { error in
                if case .configurationLoadFailed = error {
                    Button("Retry") {
                        Task {
                            await viewModel.retryLoadConfiguration()
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.clearError()
                    }
                } else {
                    Button("OK") {
                        viewModel.clearError()
                    }
                }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
        }
    }
    
    // MARK: - Strategy Selection Section
    
    /// State for showing strategy info sheet
    @State private var showStrategyInfo = false
    
    /// Strategy selection dropdown with placeholder prompt.
    /// - Validates: Requirement 3.1 (Display strategy selection dropdown with placeholder prompt)
    /// - Validates: Requirement 3.2 (Include Weekly_Option_Strategy as available option)
    private var strategySelectionSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Strategy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.tradingTextSecondary)
                        .fixedSize()
                    
                    // Strategy dropdown picker - takes remaining space
                    Picker("Select a Strategy", selection: $selectedStrategyId) {
                        // Placeholder option
                        Text("Select")
                            .tag("")
                        
                        // Available strategies - use full name
                        ForEach(viewModel.availableStrategies) { strategy in
                            Text(strategy.name)
                                .tag(strategy.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .onChange(of: selectedStrategyId) { oldValue, newValue in
                        handleStrategySelection(newValue)
                    }
                    .accessibilityLabel("Strategy selection")
                    .accessibilityHint("Double tap to select a trading strategy")
                    
                    Spacer(minLength: 0)
                }
                
                // Strategy subtitle and info button (shown when strategy is selected)
                if viewModel.hasSelectedStrategy {
                    HStack(spacing: 6) {
                        Text("Sell covered calls & cash-secured puts")
                            .font(.caption)
                            .foregroundStyle(Color.tradingTextSecondary)
                            .lineLimit(1)
                        
                        Button {
                            showStrategyInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(Color.tradingAccent)
                        }
                        .accessibilityLabel("Strategy information")
                        .accessibilityHint("Shows detailed explanation of this strategy")
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            
            Divider()
        }
        .sheet(isPresented: $showStrategyInfo) {
            StrategyInfoSheet()
        }
    }
    
    // MARK: - Configuration Section
    
    /// Configuration interface for the selected strategy.
    /// - Validates: Requirement 3.3 (Load and display configuration interface within 2 seconds)
    @ViewBuilder
    private var configurationSection: some View {
        if viewModel.isLoadingConfiguration {
            // Loading state
            configurationLoadingView
        } else if viewModel.hasSelectedStrategy && viewModel.isConfigurationLoaded {
            // Configuration interface for selected strategy
            configurationInterface
        } else if !viewModel.hasSelectedStrategy {
            // No strategy selected - show placeholder
            noStrategyPlaceholder
        } else {
            // Strategy selected but configuration not loaded (error state)
            configurationErrorPlaceholder
        }
    }
    
    /// Loading indicator while configuration is being loaded.
    private var configurationLoadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading configuration...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading strategy configuration, please wait")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Placeholder shown when no strategy is selected.
    private var noStrategyPlaceholder: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chart.bar.doc.horizontal")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(Color.tradingAccent.opacity(0.4))
                .accessibilityHidden(true)
            
            Text("Select a Strategy")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Choose a trading strategy from the dropdown above to configure and run analysis on your watchlist.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Select a strategy. Choose a trading strategy from the dropdown above to configure and run analysis on your watchlist.")
    }
    
    /// Placeholder shown when configuration failed to load.
    private var configurationErrorPlaceholder: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            
            Text("Configuration Unavailable")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Unable to load the configuration interface. Please try again or select a different strategy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                Task {
                    await viewModel.retryLoadConfiguration()
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Configuration unavailable. Unable to load the configuration interface.")
    }
    
    /// Configuration interface for the currently selected strategy.
    @ViewBuilder
    private var configurationInterface: some View {
        if viewModel.selectedStrategy?.id == WeeklyOptionConfiguration.strategyId {
            WeeklyOptionConfigurationView(
                configuration: $viewModel.weeklyOptionConfiguration,
                onConfigurationChanged: { config in
                    // Save configuration when it changes
                    Task {
                        await viewModel.saveConfiguration(config)
                    }
                },
                saveState: viewModel.saveState,
                loadState: viewModel.loadState,
                validationError: viewModel.validationError,
                isSaving: viewModel.isSaving,
                // Expiration date picker bindings
                // - Validates: Requirement 3.1 (Date picker control for custom expiration)
                // - Validates: Requirement 3.3 (Display currently selected expiration date)
                expirationOverride: viewModel.expirationOverride,
                effectiveExpirationDate: viewModel.effectiveExpirationDate,
                expirationValidationError: viewModel.expirationValidationError,
                onExpirationSelected: { date in
                    viewModel.setExpirationOverride(date)
                },
                onExpirationCleared: {
                    viewModel.clearExpirationOverride()
                }
            )
        } else {
            // Fallback for unknown strategies
            Text("Configuration interface not available")
                .foregroundStyle(.secondary)
                .padding()
        }
    }
    
    // MARK: - Run Analysis Section
    
    /// Run analysis button at the bottom of the screen.
    /// - Validates: Requirement 3.6 (Disable run analysis button when no strategy selected)
    /// - Validates: Requirement 5.7 (Display loading indicator with progress n/total)
    private var runAnalysisSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Analysis progress indicator (shown when running)
                // - Validates: Requirement 5.7 (Display loading indicator showing n/total tickers processed)
                if viewModel.isRunningAnalysis {
                    analysisProgressView
                }
                
                // Error summary (shown after analysis with errors)
                // - Validates: Requirements 5.5, 5.6 (Error indicators and insufficient data messages)
                if viewModel.hasTickerErrors && !viewModel.isRunningAnalysis {
                    tickerErrorsView
                }
                
                // Run Analysis Button with themed styling
                Button {
                    Task {
                        await viewModel.runAnalysis()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isRunningAnalysis {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        
                        Text(runAnalysisButtonText)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.canRunAnalysis ? Color.tradingAccent : Color.gray.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canRunAnalysis)
                .accessibilityLabel(viewModel.isRunningAnalysis ? "Running analysis" : "Run analysis")
                .accessibilityHint(viewModel.canRunAnalysis ? "Double tap to run analysis with the selected strategy" : "Select a strategy first to enable this button")
                
                if !viewModel.hasSelectedStrategy {
                    Text("Select a strategy to enable analysis")
                        .font(.caption)
                        .foregroundStyle(Color.tradingTextSecondary)
                } else if viewModel.watchlistTickers.isEmpty {
                    Text("Add tickers to your watchlist to run analysis")
                        .font(.caption)
                        .foregroundStyle(Color.tradingTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.tradingCardBackground)
        }
    }
    
    /// Text for the run analysis button based on current state.
    private var runAnalysisButtonText: String {
        if viewModel.isRunningAnalysis {
            return viewModel.analysisExecutionState.progressDescription
        } else {
            return "Run Analysis"
        }
    }
    
    // MARK: - Analysis Progress View
    
    /// Progress view shown while analysis is running.
    /// - Validates: Requirement 5.7 (Display loading indicator showing n/total tickers processed)
    private var analysisProgressView: some View {
        VStack(spacing: 8) {
            // Progress bar with themed accent color
            ProgressView(value: viewModel.analysisExecutionState.percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.tradingAccent))
            
            // Progress text
            Text(viewModel.analysisExecutionState.progressDescription)
                .font(.caption)
                .foregroundStyle(Color.tradingTextSecondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analysis progress")
        .accessibilityValue(viewModel.analysisExecutionState.progressDescription)
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Ticker Errors View
    
    /// View showing errors for failed tickers after analysis.
    /// - Validates: Requirement 5.5 (Display error indicator for failed tickers)
    /// - Validates: Requirement 5.6 (Display message indicating insufficient data)
    private var tickerErrorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.warning)
                Text("\(viewModel.failedTickerCount) ticker\(viewModel.failedTickerCount == 1 ? "" : "s") failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                
                Button {
                    viewModel.clearTickerErrors()
                } label: {
                    Text("Dismiss")
                        .font(.caption)
                        .foregroundStyle(Color.tradingAccent)
                }
            }
            
            // Error list (scrollable if many errors)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.tickerErrors) { error in
                        tickerErrorRow(error)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .padding(12)
        .background(Color.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ticker errors: \(viewModel.failedTickerCount) tickers failed during analysis")
    }
    
    /// A single row showing an error for a specific ticker.
    /// - Parameter error: The ticker analysis error to display
    private func tickerErrorRow(_ error: TickerAnalysisError) -> some View {
        HStack(spacing: 8) {
            // Error type icon
            Image(systemName: errorIcon(for: error.errorType))
                .foregroundStyle(errorColor(for: error.errorType))
                .font(.caption)
            
            // Error message
            Text(error.message)
                .font(.caption)
                .foregroundStyle(Color.tradingTextSecondary)
                .lineLimit(2)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(error.message)
    }
    
    /// Returns the appropriate icon for an error type.
    private func errorIcon(for errorType: TickerErrorType) -> String {
        switch errorType {
        case .fetchFailed:
            return "xmark.circle.fill"
        case .insufficientData:
            return "clock.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    /// Returns the appropriate color for an error type using theme colors.
    private func errorColor(for errorType: TickerErrorType) -> Color {
        switch errorType {
        case .fetchFailed:
            return .error
        case .insufficientData:
            return .warning
        case .unknown:
            return .tradingTextSecondary
        }
    }
    
    // MARK: - Actions
    
    /// Handles strategy selection from the dropdown.
    /// - Parameter strategyId: The selected strategy ID, or empty string for placeholder
    private func handleStrategySelection(_ strategyId: String) {
        let strategy = viewModel.availableStrategies.first { $0.id == strategyId }
        Task {
            await viewModel.selectStrategy(strategy)
        }
    }
}

// MARK: - Weekly Option Configuration View

/// Configuration interface for the Weekly Option Strategy.
///
/// Displays configuration options for:
/// - WINDOW_DAYS picker with options 1, 5, 30
/// - LOOKBACK_DAYS picker with options 30, 60, 90, 180, 360
/// - PREMIUM_PCT numeric input (0.1% to 5.0%, 0.1% increments)
/// - ONLY_ORDERS toggle switch
/// - Confirmation indicator on successful save
/// - Error indicators for save and load failures
///
/// - Validates: Requirement 4.1 (Display configuration options for WINDOW_DAYS, LOOKBACK_DAYS, PREMIUM_PCT, ONLY_ORDERS)
/// - Validates: Requirement 4.2 (WINDOW_DAYS options of 1, 5, and 30 days)
/// - Validates: Requirement 4.3 (LOOKBACK_DAYS options of 30, 60, 90, 180, and 360 days)
/// - Validates: Requirement 4.4 (PREMIUM_PCT numeric input 0.1% to 5.0% in 0.1% increments)
/// - Validates: Requirement 4.5 (ONLY_ORDERS toggle switch)
/// - Validates: Requirement 4.6 (Display confirmation indicator on save)
/// - Validates: Requirement 4.9 (Display error on save failure)
/// - Validates: Requirement 4.10 (Display error on load failure)
/// - Validates: Requirement 4.11 (Display validation error message)
private struct WeeklyOptionConfigurationView: View {
    @Binding var configuration: WeeklyOptionConfiguration
    
    /// Callback invoked when configuration changes, to trigger save
    var onConfigurationChanged: ((WeeklyOptionConfiguration) -> Void)?
    
    /// Current save state from ViewModel
    var saveState: ConfigurationSaveState
    
    /// Current load state from ViewModel
    var loadState: ConfigurationDataLoadState
    
    /// Validation error from ViewModel
    var validationError: String?
    
    /// Whether save operation is in progress
    var isSaving: Bool
    
    // MARK: - Expiration Date Properties
    // - Validates: Requirement 3.1 (Date picker control for custom expiration)
    // - Validates: Requirement 3.3 (Display currently selected expiration date)
    
    /// User-selected expiration date override (nil means automatic calculation)
    var expirationOverride: Date?
    
    /// The effective expiration date that will be used for analysis
    var effectiveExpirationDate: Date
    
    /// Validation error for expiration date selection
    var expirationValidationError: String?
    
    /// Callback when user selects a custom expiration date
    var onExpirationSelected: ((Date) -> Void)?
    
    /// Callback when user clears the expiration override
    var onExpirationCleared: (() -> Void)?
    
    /// Timer for hiding the save confirmation
    @State private var confirmationTimer: Task<Void, Never>?
    
    /// Local binding state for expiration date picker
    @State private var localExpirationDate: Date?
    
    var body: some View {
        List {
            // Load error banner (if applicable)
            // - Validates: Requirement 4.10 (Display error on load failure)
            if loadState.hasError, let loadError = loadState.errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Configuration section
            // - Validates: Requirement 4.1 (Display configuration options)
            Section {
                // Window Days picker
                // - Validates: Requirement 4.2 (WINDOW_DAYS options of 1, 5, and 30 days)
                windowDaysPicker
                
                // Lookback Days picker
                // - Validates: Requirement 4.3 (LOOKBACK_DAYS options of 30, 60, 90, 180, and 360 days)
                lookbackDaysPicker
                
                // Premium PCT stepper
                // - Validates: Requirement 4.4 (PREMIUM_PCT numeric input 0.1% to 5.0% in 0.1% increments)
                premiumPctStepper
                
                // Expiration Date picker
                // - Validates: Requirement 3.1 (Date picker control for custom expiration)
                // - Validates: Requirement 3.3 (Display currently selected expiration date)
                expirationDatePickerSection
                
                // Only Orders toggle
                // - Validates: Requirement 4.5 (ONLY_ORDERS toggle switch)
                onlyOrdersToggle
                
                // Option Type filter picker (Call/Put/Both)
                optionTypeFilterPicker
            } header: {
                HStack {
                    Text("Configuration")
                    Spacer()
                    // Save state indicator
                    saveStateIndicator
                }
            }
            
            // Validation error display
            // - Validates: Requirement 4.11 (Display validation error message)
            if let error = validationError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            // Save error display
            // - Validates: Requirement 4.9 (Display error on save failure)
            if case .failed(let error) = saveState {
                Section {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.easeInOut(duration: 0.3), value: saveState)
    }
    
    // MARK: - Save State Indicator
    
    /// Displays the current save state (saving, saved, or error).
    /// - Validates: Requirement 4.6 (Display confirmation indicator on save)
    /// - Validates: Requirement 4.9 (Display error on save failure)
    @ViewBuilder
    private var saveStateIndicator: some View {
        switch saveState {
        case .saving:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Saving...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Saving configuration")
            
        case .saved(let date):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .transition(.opacity.combined(with: .scale))
            .accessibilityLabel("Configuration saved successfully at \(date.formatted(date: .omitted, time: .shortened))")
            
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Save failed")
            
        case .idle:
            EmptyView()
        }
    }
    
    // MARK: - Window Days Picker
    
    /// Picker for WINDOW_DAYS parameter with options 1, 5, 30.
    /// - Validates: Requirement 4.2 (WINDOW_DAYS options of 1, 5, and 30 days)
    private var windowDaysPicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Window Days")
                Text("Rolling return period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Window Days", selection: Binding(
                get: { configuration.windowDays },
                set: { newValue in
                    configuration.windowDays = newValue
                    handleConfigurationChange()
                }
            )) {
                ForEach(WeeklyOptionConfiguration.validWindowDays, id: \.self) { days in
                    Text("\(days) day\(days == 1 ? "" : "s")").tag(days)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Window days")
            .accessibilityHint("Number of days for rolling return calculation. Options are 1, 5, or 30 days.")
        }
    }
    
    // MARK: - Lookback Days Picker
    
    /// Picker for LOOKBACK_DAYS parameter with options 30, 60, 90, 180, 360.
    /// - Validates: Requirement 4.3 (LOOKBACK_DAYS options of 30, 60, 90, 180, and 360 days)
    private var lookbackDaysPicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lookback Days")
                Text("Historical analysis period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Lookback Days", selection: Binding(
                get: { configuration.lookbackDays },
                set: { newValue in
                    configuration.lookbackDays = newValue
                    handleConfigurationChange()
                }
            )) {
                ForEach(WeeklyOptionConfiguration.validLookbackDays, id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Lookback days")
            .accessibilityHint("Historical period to analyze. Options are 30, 60, 90, 180, or 360 days.")
        }
    }
    
    // MARK: - Premium PCT Stepper
    
    /// Stepper for PREMIUM_PCT parameter accepting 0.1% to 5.0% in 0.1% increments.
    /// - Validates: Requirement 4.4 (PREMIUM_PCT numeric input 0.1% to 5.0% in 0.1% increments)
    private var premiumPctStepper: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Premium %")
                Text("Target option premium")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            // Stepper with numeric display
            HStack(spacing: 8) {
                // Decrease button
                Button {
                    decrementPremium()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canDecrementPremium ? .blue : .gray.opacity(0.5))
                }
                .disabled(!canDecrementPremium)
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease premium")
                .accessibilityHint("Decreases premium by 0.1 percent")
                
                // Current value display
                Text(String(format: "%.1f%%", configuration.premiumPct))
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Current premium percentage")
                    .accessibilityValue(String(format: "%.1f percent", configuration.premiumPct))
                
                // Increase button
                Button {
                    incrementPremium()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canIncrementPremium ? .blue : .gray.opacity(0.5))
                }
                .disabled(!canIncrementPremium)
                .buttonStyle(.plain)
                .accessibilityLabel("Increase premium")
                .accessibilityHint("Increases premium by 0.1 percent")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Premium percentage stepper")
        .accessibilityHint("Accepts values from 0.1% to 5.0% in 0.1% increments")
    }
    
    // MARK: - Expiration Date Picker Section
    
    /// Section for selecting options expiration date.
    /// Uses the ExpirationDatePicker component to allow users to override the default expiration.
    ///
    /// - Validates: Requirement 3.1 (Date picker control for custom expiration)
    /// - Validates: Requirement 3.3 (Display currently selected expiration date)
    private var expirationDatePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ExpirationDatePicker(
                selectedDate: Binding(
                    get: { expirationOverride },
                    set: { newDate in
                        if let date = newDate {
                            onExpirationSelected?(date)
                        } else {
                            onExpirationCleared?()
                        }
                    }
                ),
                expirationCalculator: ExpirationDateCalculator(),
                onDateSelected: { date in
                    onExpirationSelected?(date)
                },
                onDateCleared: {
                    onExpirationCleared?()
                },
                onValidationError: { _ in
                    // Validation errors are handled by the picker itself
                }
            )
            
            // Display effective expiration date
            // - Validates: Requirement 3.3 (Display currently selected expiration date)
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Analysis will use: \(formatExpirationDate(effectiveExpirationDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Effective expiration date: \(formatExpirationDate(effectiveExpirationDate))")
            
            // Display validation error from ViewModel (if any)
            if let error = expirationValidationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Expiration date error: \(error)")
            }
        }
    }
    
    /// Formats the expiration date for display.
    /// Uses UTC timezone to correctly display dates stored as UTC midnight.
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string in YYYY-MM-DD format
    private func formatExpirationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    // MARK: - Only Orders Toggle
    
    /// Toggle for ONLY_ORDERS parameter.
    /// - Validates: Requirement 4.5 (ONLY_ORDERS toggle switch)
    private var onlyOrdersToggle: some View {
        Toggle(isOn: Binding(
            get: { configuration.onlyOrders },
            set: { newValue in
                configuration.onlyOrders = newValue
                handleConfigurationChange()
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show Only Orders")
                Text("Filter to ORDER signals only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Show only orders")
        .accessibilityHint("When enabled, filters results to show only ORDER signals, hiding HOLD results")
    }
    
    // MARK: - Option Type Filter Picker
    
    /// Picker for option type filter (Call/Put/Both).
    /// Controls which option types are shown in the results.
    private var optionTypeFilterPicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Option Type")
                Text("Filter by CALL or PUT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Option Type", selection: Binding(
                get: { configuration.optionTypeFilter },
                set: { newValue in
                    configuration.optionTypeFilter = newValue
                    handleConfigurationChange()
                }
            )) {
                ForEach(OptionTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.displayLabel).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Option type filter")
            .accessibilityHint("Select Call to show only calls, Put to show only puts, or Both to show all options")
        }
    }
    
    // MARK: - Premium PCT Helpers
    
    /// Whether the premium can be decreased (not at minimum).
    private var canDecrementPremium: Bool {
        configuration.premiumPct > WeeklyOptionConfiguration.premiumPctRange.lowerBound + 0.001
    }
    
    /// Whether the premium can be increased (not at maximum).
    private var canIncrementPremium: Bool {
        configuration.premiumPct < WeeklyOptionConfiguration.premiumPctRange.upperBound - 0.001
    }
    
    /// Decrements the premium percentage by the step value (0.1).
    private func decrementPremium() {
        let newValue = configuration.premiumPct - WeeklyOptionConfiguration.premiumPctStep
        let roundedValue = (newValue * 10).rounded() / 10 // Round to avoid floating point issues
        
        if roundedValue >= WeeklyOptionConfiguration.premiumPctRange.lowerBound {
            configuration.premiumPct = roundedValue
            handleConfigurationChange()
        }
    }
    
    /// Increments the premium percentage by the step value (0.1).
    private func incrementPremium() {
        let newValue = configuration.premiumPct + WeeklyOptionConfiguration.premiumPctStep
        let roundedValue = (newValue * 10).rounded() / 10 // Round to avoid floating point issues
        
        if roundedValue <= WeeklyOptionConfiguration.premiumPctRange.upperBound {
            configuration.premiumPct = roundedValue
            handleConfigurationChange()
        }
    }
    
    // MARK: - Configuration Change Handling
    
    /// Handles configuration changes by triggering save.
    /// - Validates: Requirement 4.6 (Display confirmation indicator on save)
    private func handleConfigurationChange() {
        // Validate the configuration
        if WeeklyOptionConfiguration.validatePremiumPct(configuration.premiumPct) != nil {
            // Don't trigger save for invalid values - ViewModel will handle validation error display
            return
        }
        
        // Notify of the change (ViewModel handles persistence and state)
        onConfigurationChanged?(configuration)
    }
}

// MARK: - Strategy Info Sheet

/// Sheet displaying detailed information about the Weekly Option Strategy.
private struct StrategyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Overview section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Overview", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.tradingAccent)
                        
                        Text("The Weekly Option Strategy identifies opportunities to generate income by selling options based on historical price patterns.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Covered Call section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Covered Call (CALL Signal)", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        
                        Text("When a stock shows consistent positive returns over the lookback period, it may be a good candidate to sell covered calls.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Label("You own shares of the stock", systemImage: "checkmark.circle")
                            Label("Sell call options against your shares", systemImage: "checkmark.circle")
                            Label("Collect premium as income", systemImage: "checkmark.circle")
                            Label("Stock may be called away if price rises above strike", systemImage: "exclamationmark.triangle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Cash-Secured Put section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Cash-Secured Put (PUT Signal)", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                        
                        Text("When a stock shows negative returns and trades below its historical range, it may be a good candidate to sell cash-secured puts.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Have cash set aside to buy the stock", systemImage: "checkmark.circle")
                            Label("Sell put options to collect premium", systemImage: "checkmark.circle")
                            Label("Buy stock at lower price if assigned", systemImage: "checkmark.circle")
                            Label("Obligated to buy if price drops below strike", systemImage: "exclamationmark.triangle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Configuration section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Configuration Options", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundStyle(Color.tradingAccent)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            configRow(title: "Window Days", description: "Period for calculating rolling returns (1, 5, or 30 days)")
                            configRow(title: "Lookback Days", description: "Historical period to analyze (30 to 360 days)")
                            configRow(title: "Premium %", description: "Target option premium percentage (0.1% to 5.0%)")
                            configRow(title: "Orders Only", description: "Show only strong ORDER signals vs all opportunities")
                            configRow(title: "Expiration Date", description: "Option expiration date (defaults to next Friday)")
                        }
                    }
                    
                    Divider()
                    
                    // Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Important", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        
                        Text("Options trading involves significant risk and is not suitable for all investors. Past performance does not guarantee future results. Always conduct your own research before making investment decisions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Weekly Option Strategy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func configRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Analysis View - No Selection") {
    AnalysisView(viewModel: AnalysisViewModel(
        configurationRepository: nil,
        validationService: nil,
        strategy: nil,
        expirationDateCalculator: nil,
        userId: "preview-user"
    ))
}
#endif
