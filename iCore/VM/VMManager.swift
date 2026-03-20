import SwiftUI
import Foundation

// MARK: - VM State
enum VMState: Equatable {
    case stopped, booting, running, paused

    var label: String {
        switch self {
        case .stopped: return "STOPPED"
        case .booting:  return "BOOTING"
        case .running:  return "RUNNING"
        case .paused:   return "PAUSED"
        }
    }

    var color: Color {
        switch self {
        case .stopped: return Color(red: 1.0, green: 0.30, blue: 0.42)
        case .booting:  return Color(red: 1.0, green: 0.70, blue: 0.00)
        case .running:  return Color(red: 0.00, green: 0.90, blue: 0.46)
        case .paused:   return Color(red: 1.0, green: 0.70, blue: 0.00)
        }
    }

    var icon: String {
        switch self {
        case .stopped: return "stop.circle.fill"
        case .booting:  return "arrow.triangle.2.circlepath"
        case .running:  return "checkmark.circle.fill"
        case .paused:   return "pause.circle.fill"
        }
    }
}

// MARK: - VMManager
final class VMManager: ObservableObject {
    @Published var state: VMState = .stopped
    @Published var consoleOutput: String = ""
    @Published var ramAllocatedGB: Double = 4.0
    @Published var storageAllocatedGB: Double = 16.0
    @Published var diskUsedGB: Double = 0.0
    @Published var cpuCores: Int = 2
    @Published var networkEnabled: Bool = true

    private var hypervisor: HypervisorWrapper?
    private var vmTask: Task<Void, Never>?

    init() { loadSettings() }

    func loadSettings() {
        let d = UserDefaults.standard
        let ram = d.double(forKey: "ram_gb")
        ramAllocatedGB = ram > 0 ? ram : 4.0

        let storage = d.double(forKey: "storage_gb")
        storageAllocatedGB = storage >= 8 ? storage : 16.0

        let cores = d.integer(forKey: "cpu_cores")
        cpuCores = [1, 2, 4].contains(cores) ? cores : 2

        if d.object(forKey: "network_enabled") != nil {
            networkEnabled = d.bool(forKey: "network_enabled")
        }
    }

    func startVM() {
        guard state == .stopped || state == .paused else { return }
        vmTask?.cancel()

        vmTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.state = .booting
                self.consoleOutput = ""
            }

            let wrapper = HypervisorWrapper(
                ramSizeMB: Int(self.ramAllocatedGB) * 1024,
                cpuCores: self.cpuCores
            )

            let console = VirtioConsole { [weak self] text in
                guard let self else { return }
                Task { @MainActor in
                    self.consoleOutput += text
                }
            }
            wrapper.console = console

            let ok = wrapper.createVM()

            await MainActor.run {
                if ok {
                    self.state = .running
                    self.hypervisor = wrapper
                } else {
                    self.consoleOutput += "[iCore] VM creation failed.\n"
                    self.consoleOutput += "[iCore] Hypervisor.framework may not be available on this device.\n"
                    self.state = .stopped
                }
            }

            guard ok else { return }

            await Task.detached(priority: .userInitiated) {
                wrapper.run()
            }.value

            await MainActor.run {
                if self.state == .running {
                    self.state = .stopped
                }
            }
        }
    }

    func pauseVM() {
        guard state == .running else { return }
        hypervisor?.stop()
        state = .paused
    }

    func stopVM() {
        vmTask?.cancel()
        hypervisor?.stop()
        hypervisor = nil
        Task { @MainActor in
            self.state = .stopped
        }
    }
}
