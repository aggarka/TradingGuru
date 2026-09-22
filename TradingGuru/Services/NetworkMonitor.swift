//
//  NetworkMonitor.swift
//  TradingGuru
//
//  Service to monitor network connectivity status.
//  Provides observable network state for UI updates.
//

import Foundation
import Network
import Combine

// MARK: - Network Status

/// Represents the current network connectivity status.
/// - Validates: Requirement 7.5 (Display cached data and offline status indicator)
enum NetworkStatus: Equatable {
    /// Device is connected to the network
    case online
    
    /// Device is not connected to the network
    case offline
    
    /// Network status is being determined
    case unknown
    
    /// Whether the device has network connectivity
    var isConnected: Bool {
        self == .online
    }
    
    /// Human-readable description of the network status
    var description: String {
        switch self {
        case .online:
            return "Connected"
        case .offline:
            return "Offline"
        case .unknown:
            return "Checking connection..."
        }
    }
}

// MARK: - Network Monitor Protocol

/// Protocol for monitoring network connectivity.
/// - Validates: Requirement 7.5 (Detect network unavailability)
protocol NetworkMonitoring: AnyObject {
    /// The current network status
    var status: NetworkStatus { get }
    
    /// Publisher for network status changes
    var statusPublisher: AnyPublisher<NetworkStatus, Never> { get }
    
    /// Whether the network is currently available
    var isConnected: Bool { get }
    
    /// Starts monitoring network connectivity
    func startMonitoring()
    
    /// Stops monitoring network connectivity
    func stopMonitoring()
}

// MARK: - Network Monitor Implementation

/// Service that monitors network connectivity using NWPathMonitor.
/// Publishes status changes for reactive UI updates.
///
/// Usage:
/// ```swift
/// let monitor = NetworkMonitor.shared
/// monitor.startMonitoring()
///
/// // Subscribe to status changes
/// monitor.statusPublisher
///     .sink { status in
///         print("Network status: \(status)")
///     }
/// ```
///
/// - Validates: Requirement 7.5 (Network unavailability detection)
final class NetworkMonitor: NetworkMonitoring, ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide network monitoring
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    /// The current network status, observable for SwiftUI
    @Published private(set) var status: NetworkStatus = .unknown
    
    // MARK: - Properties
    
    /// Publisher for network status changes
    var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        $status.eraseToAnyPublisher()
    }
    
    /// Whether the network is currently available
    var isConnected: Bool {
        status.isConnected
    }
    
    /// The NWPathMonitor instance for detecting network changes
    private let monitor: NWPathMonitor
    
    /// Dedicated queue for network monitoring
    private let monitorQueue = DispatchQueue(label: "com.tradingguru.networkmonitor")
    
    /// Whether monitoring is currently active
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    /// Creates a new NetworkMonitor instance.
    /// Use `NetworkMonitor.shared` for app-wide monitoring.
    init() {
        self.monitor = NWPathMonitor()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - NetworkMonitoring Protocol
    
    /// Starts monitoring network connectivity.
    /// Safe to call multiple times - subsequent calls are ignored if already monitoring.
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateStatus(from: path)
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    /// Stops monitoring network connectivity.
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
    }
    
    // MARK: - Private Methods
    
    /// Updates the network status based on the current path.
    /// - Parameter path: The current network path from NWPathMonitor
    private func updateStatus(from path: NWPath) {
        switch path.status {
        case .satisfied:
            status = .online
        case .unsatisfied, .requiresConnection:
            status = .offline
        @unknown default:
            status = .unknown
        }
    }
}

// MARK: - Mock Network Monitor for Testing

/// Mock implementation of NetworkMonitoring for testing purposes.
final class MockNetworkMonitor: NetworkMonitoring, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var status: NetworkStatus = .online
    
    // MARK: - Properties
    
    var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        $status.eraseToAnyPublisher()
    }
    
    var isConnected: Bool {
        status.isConnected
    }
    
    // MARK: - NetworkMonitoring Protocol
    
    func startMonitoring() {
        // No-op for mock
    }
    
    func stopMonitoring() {
        // No-op for mock
    }
    
    // MARK: - Testing Helpers
    
    /// Simulates going offline
    func simulateOffline() {
        status = .offline
    }
    
    /// Simulates coming back online
    func simulateOnline() {
        status = .online
    }
    
    /// Sets a specific network status
    func setStatus(_ newStatus: NetworkStatus) {
        status = newStatus
    }
}
