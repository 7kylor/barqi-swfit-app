import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkReachabilityService {
  static let shared = NetworkReachabilityService()
  
  private(set) var isConnected: Bool = true
  private(set) var connectionType: ConnectionType = .unknown
  
  enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
  }
  
  private let monitor = NWPathMonitor()
  // Note: NWPathMonitor requires a DispatchQueue for its callback
  // This is the only acceptable DispatchQueue usage - required by Apple's API
  // We use a minimal serial queue as recommended by Apple
  private let monitorQueue = DispatchQueue(label: "com.taher.Mawj.network.monitor", qos: .utility)
  
  private init() {
    startMonitoring()
  }
  
  func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        guard let self else { return }
        self.isConnected = path.status == .satisfied
        self.connectionType = self.determineConnectionType(path: path)
      }
    }
    // NWPathMonitor.start(queue:) requires a DispatchQueue - this is Apple's API requirement
    monitor.start(queue: monitorQueue)
  }
  
  func stopMonitoring() {
    monitor.cancel()
  }
  
  private func determineConnectionType(path: NWPath) -> ConnectionType {
    if path.usesInterfaceType(.wifi) {
      return .wifi
    } else if path.usesInterfaceType(.cellular) {
      return .cellular
    } else if path.usesInterfaceType(.wiredEthernet) {
      return .ethernet
    } else {
      return .unknown
    }
  }
  
  /// Returns current connectivity status - uses the already-monitored state
  /// No blocking, no new monitors created
  func checkConnectivity() async -> Bool {
    // Simply return the current tracked state - no need to create a new monitor
    return isConnected
  }
}

