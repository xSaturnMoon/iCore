import Foundation
import os

// MARK: - MemoryMonitor
/// Polls os_proc_available_memory() every 2 seconds and publishes
/// availability metrics with warning / critical thresholds.
final class MemoryMonitor: ObservableObject {
    @Published var availableMemoryGB: Double = 0
    @Published var isWarning: Bool  = false   // < 500 MB
    @Published var isCritical: Bool = false  // < 200 MB

    private var timer: Timer?

    init() { start() }
    deinit { stop() }

    func start() {
        sample()          // immediate first reading
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sample()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private
    private func sample() {
        let bytes = Double(os_proc_available_memory())
        let gb    = bytes / 1_073_741_824   // bytes → GB

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.availableMemoryGB = gb
            self.isWarning  = gb < 0.5
            let wasCritical = self.isCritical
            self.isCritical = gb < 0.2
            if self.isCritical && !wasCritical {
                NotificationCenter.default.post(name: .memoryPressureCritical, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let memoryPressureCritical = Notification.Name("MemoryPressureCritical")
}
