//
//  AuthProviderType.swift
//  TradingGuru
//
//  Authentication provider enumeration for supported sign-in methods.
//

import Foundation

/// Supported authentication providers for user sign-in.
/// - Validates: Requirement 1.1 (Google, Apple, Passkey authentication options)
enum AuthProviderType: String, Codable, CaseIterable {
    case google
    case apple
    case passkey
    
    /// Display name for the authentication provider
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .apple: return "Apple"
        case .passkey: return "Passkey"
        }
    }
}
