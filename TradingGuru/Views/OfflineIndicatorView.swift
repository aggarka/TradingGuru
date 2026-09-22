//
//  OfflineIndicatorView.swift
//  TradingGuru
//
//  View component that displays offline status indicator.
//  Shows when network connectivity is unavailable.
//

import SwiftUI
import Combine

// MARK: - Offline Indicator View

/// A persistent banner that displays when the app is offline.
/// Shows the offline status and indicates cached data is being displayed.
///
/// Usage:
/// ```swift
/// VStack {
///     OfflineIndicatorView(networkMonitor: NetworkMonitor.shared)
///     // Rest of your content
/// }
/// ```
///
/// - Validates: Requirement 7.5 (Show persistent offline status indicator)
struct OfflineIndicatorView: View {
    
    // MARK: - Properties
    
    /// The network monitor to observe for connectivity changes
    @ObservedObject var networkMonitor: NetworkMonitor
    
    /// Optional last sync timestamp to display
    var lastSyncTimestamp: Date?
    
    /// Whether to show the compact version (just icon and text)
    var compact: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        if !networkMonitor.isConnected {
            if compact {
                compactIndicator
            } else {
                fullIndicator
            }
        }
    }
    
    // MARK: - Private Views
    
    /// Full-width banner indicator
    private var fullIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("You're offline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let lastSync = lastSyncTimestamp {
                    Text("Showing cached data from \(formattedTimestamp(lastSync))")
                        .font(.caption)
                        .opacity(0.8)
                } else {
                    Text("Showing cached data")
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.15))
        .foregroundColor(.orange)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    /// Compact inline indicator
    private var compactIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12))
            
            Text("Offline")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .foregroundColor(.orange)
        .cornerRadius(4)
    }
    
    // MARK: - Private Helpers
    
    /// Formats a timestamp for display.
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Offline Status Badge

/// A small badge that indicates offline status.
/// Use in navigation bars or compact spaces.
///
/// - Validates: Requirement 7.5 (Persistent offline status indicator)
struct OfflineStatusBadge: View {
    
    // MARK: - Properties
    
    @ObservedObject var networkMonitor: NetworkMonitor
    
    // MARK: - Body
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                
                Text("Offline")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Network Status View Modifier

/// View modifier that adds offline indicator to any view.
///
/// Usage:
/// ```swift
/// ContentView()
///     .withOfflineIndicator(networkMonitor: NetworkMonitor.shared)
/// ```
struct OfflineIndicatorModifier: ViewModifier {
    @ObservedObject var networkMonitor: NetworkMonitor
    var lastSyncTimestamp: Date?
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            OfflineIndicatorView(
                networkMonitor: networkMonitor,
                lastSyncTimestamp: lastSyncTimestamp
            )
            
            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds an offline indicator banner at the top of the view.
    /// - Parameters:
    ///   - networkMonitor: The network monitor to observe
    ///   - lastSyncTimestamp: Optional timestamp of last successful sync
    /// - Returns: View with offline indicator
    func withOfflineIndicator(
        networkMonitor: NetworkMonitor,
        lastSyncTimestamp: Date? = nil
    ) -> some View {
        modifier(OfflineIndicatorModifier(
            networkMonitor: networkMonitor,
            lastSyncTimestamp: lastSyncTimestamp
        ))
    }
}

// MARK: - Offline Data Notice

/// A notice card displayed when showing cached/offline data.
/// Provides more context than the simple banner.
///
/// - Validates: Requirement 7.5 (Display cached data indication)
struct OfflineDataNotice: View {
    
    // MARK: - Properties
    
    @ObservedObject var networkMonitor: NetworkMonitor
    var dataType: String = "data"
    var lastSyncTimestamp: Date?
    var onRetry: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        if !networkMonitor.isConnected {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Offline Mode")
                            .font(.headline)
                        
                        Text("Showing cached \(dataType)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let lastSync = lastSyncTimestamp {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        
                        Text("Last synced: \(formattedTimestamp(lastSync))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let retry = onRetry {
                    Button(action: retry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Connection")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct OfflineIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full indicator - offline
            VStack {
                OfflineIndicatorView(
                    networkMonitor: createOfflineMonitor(),
                    lastSyncTimestamp: Date().addingTimeInterval(-3600)
                )
                Spacer()
            }
            .previewDisplayName("Full Banner")
            
            // Compact indicator - offline
            OfflineIndicatorView(
                networkMonitor: createOfflineMonitor(),
                compact: true
            )
            .previewDisplayName("Compact")
            
            // Status badge
            OfflineStatusBadge(networkMonitor: createOfflineMonitor())
                .previewDisplayName("Badge")
            
            // Data notice
            OfflineDataNotice(
                networkMonitor: createOfflineMonitor(),
                dataType: "watchlist",
                lastSyncTimestamp: Date().addingTimeInterval(-7200),
                onRetry: { }
            )
            .padding()
            .previewDisplayName("Data Notice")
            
            // Online state (should show nothing)
            OfflineIndicatorView(networkMonitor: NetworkMonitor())
                .previewDisplayName("Online (Empty)")
        }
    }
    
    /// Creates a mock network monitor in offline state for previews
    private static func createOfflineMonitor() -> NetworkMonitor {
        let monitor = NetworkMonitor()
        // Note: In real previews, you'd use a mock that can be set to offline
        return monitor
    }
}
#endif
