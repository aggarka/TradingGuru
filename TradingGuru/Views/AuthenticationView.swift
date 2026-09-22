//
//  AuthenticationView.swift
//  TradingGuru
//
//  Authentication screen displaying sign-in options for Google, Apple, and Passkey.
//

import SwiftUI

/// View displaying authentication options for users to sign in.
///
/// Displays three authentication provider buttons (Google, Apple, Passkey),
/// shows a loading indicator during authentication, and displays error messages
/// for various failure scenarios.
///
/// - Validates: Requirement 1.1 (Display authentication options)
/// - Validates: Requirement 1.6 (Display error messages for failure categories)
/// - Validates: Requirement 1.7 (Display timeout error message)
struct AuthenticationView: View {
    // MARK: - State Properties
    
    /// Whether authentication is currently in progress
    @State private var isLoading = false
    
    /// The current error to display, if any
    @State private var currentError: AuthError?
    
    /// Whether to show the error alert
    @State private var showError = false
    
    /// The authentication provider currently being used
    @State private var selectedProvider: AuthProviderType?
    
    // MARK: - Callbacks
    
    /// Callback invoked when user selects an authentication provider
    var onSignIn: ((AuthProviderType) async throws -> User)?
    
    /// Callback invoked when authentication succeeds
    var onAuthenticationSuccess: ((User) -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // App logo and title
                headerSection
                
                Spacer()
                
                // Authentication buttons
                authenticationButtonsSection
                
                Spacer()
                
                // Footer text
                footerSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
        }
        .alert("Sign In Error", isPresented: $showError, presenting: currentError) { _ in
            Button("OK") {
                currentError = nil
            }
        } message: { error in
            Text(error.errorDescription ?? "An unknown error occurred.")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            
            Text("TradingGuru")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text("Sign in to access your trading analysis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TradingGuru. Sign in to access your trading analysis")
    }
    
    // MARK: - Authentication Buttons Section
    
    private var authenticationButtonsSection: some View {
        VStack(spacing: 16) {
            // Google Sign-In Button
            AuthenticationButton(
                provider: .google,
                isLoading: isLoading && selectedProvider == .google,
                isDisabled: isLoading
            ) {
                await handleSignIn(with: .google)
            }
            
            // Apple Sign-In Button
            AuthenticationButton(
                provider: .apple,
                isLoading: isLoading && selectedProvider == .apple,
                isDisabled: isLoading
            ) {
                await handleSignIn(with: .apple)
            }
            
            // Passkey Button
            AuthenticationButton(
                provider: .passkey,
                isLoading: isLoading && selectedProvider == .passkey,
                isDisabled: isLoading
            ) {
                await handleSignIn(with: .passkey)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Text("By signing in, you agree to our Terms of Service and Privacy Policy")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Signing in...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signing in, please wait")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Actions
    
    /// Handles the sign-in flow for the selected provider.
    /// - Parameter provider: The authentication provider to use
    private func handleSignIn(with provider: AuthProviderType) async {
        guard !isLoading else { return }
        
        isLoading = true
        selectedProvider = provider
        currentError = nil
        
        do {
            if let signIn = onSignIn {
                let user = try await signIn(provider)
                await MainActor.run {
                    isLoading = false
                    selectedProvider = nil
                    onAuthenticationSuccess?(user)
                }
            }
        } catch let error as AuthError {
            await MainActor.run {
                isLoading = false
                selectedProvider = nil
                currentError = error
                showError = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                selectedProvider = nil
                currentError = .networkError(underlying: error.localizedDescription)
                showError = true
            }
        }
    }
}

// MARK: - Authentication Button Component

/// A styled button for authentication providers.
///
/// Displays the provider's icon, name, and handles loading states.
/// Supports accessibility features including VoiceOver labels.
struct AuthenticationButton: View {
    let provider: AuthProviderType
    let isLoading: Bool
    let isDisabled: Bool
    let action: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 12) {
                providerIcon
                    .frame(width: 24, height: 24)
                
                if isLoading {
                    ProgressView()
                        .tint(textColor)
                } else {
                    Text("Sign in with \(provider.displayName)")
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .foregroundStyle(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.6 : 1.0)
        .accessibilityLabel("Sign in with \(provider.displayName)")
        .accessibilityHint(isLoading ? "Authentication in progress" : "Double tap to sign in")
        .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }
    
    // MARK: - Provider-Specific Styling
    
    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .google:
            // Google "G" logo representation using multicolor gradient
            Image(systemName: "g.circle.fill")
                .resizable()
                .symbolRenderingMode(.multicolor)
        case .apple:
            Image(systemName: "apple.logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .passkey:
            Image(systemName: "key.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    private var backgroundColor: Color {
        switch provider {
        case .google:
            return .white
        case .apple:
            return .black
        case .passkey:
            return .blue
        }
    }
    
    private var textColor: Color {
        switch provider {
        case .google:
            return .primary
        case .apple:
            return .white
        case .passkey:
            return .white
        }
    }
    
    private var borderColor: Color {
        switch provider {
        case .google:
            return .gray.opacity(0.3)
        case .apple:
            return .clear
        case .passkey:
            return .clear
        }
    }
}

// MARK: - Preview

#Preview("Authentication View") {
    AuthenticationView()
}

#Preview("Authentication View - Loading") {
    AuthenticationView(
        onSignIn: { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            throw AuthError.timeout
        }
    )
}
