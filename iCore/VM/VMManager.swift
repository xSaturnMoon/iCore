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
    private var console: VirtioConsole?

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

        state = .booting
        consoleOutput = ""

        let wrapper = HypervisorWrapper(
            ramSizeMB: Int(ramAllocatedGB) * 1024,
            cpuCores: cpuCores
        )

        let con = VirtioConsole { [weak self] text in
            DispatchQueue.main.async {
                self?.consoleOutput += text
            }
        }

        // When boot sequence completes, transition to running
        con.onBoot = { [weak self] in
            DispatchQueue.main.async {
                self?.state = .running
            }
        }

        wrapper.console = con
        _ = wrapper.createVM()

        hypervisor = wrapper
        console    = con

        con.startStream()
    }

    func pauseVM() {
        guard state == .running else { return }
        console?.stopStream()
        hypervisor?.stop()
        state = .paused
    }

    func stopVM() {
        console?.stopStream()
        hypervisor?.stop()
        hypervisor = nil
        console    = nil
        state = .stopped
    }
}
