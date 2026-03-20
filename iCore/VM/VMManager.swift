import SwiftUI

// MARK: - VM State
enum VMState: String, Equatable {
    case stopped = "stopped"
    case booting = "booting"
    case running = "running"
    case paused  = "paused"

    var label: String { rawValue.uppercased() }

    var color: Color {
        switch self {
        case .stopped: return Color(red: 1.0, green: 0.30, blue: 0.42)
        case .booting: return Color(red: 1.0, green: 0.70, blue: 0.00)
        case .running: return Color(red: 0.00, green: 0.90, blue: 0.46)
        case .paused:  return Color(red: 1.0, green: 0.70, blue: 0.00)
        }
    }

    var icon: String {
        switch self {
        case .stopped: return "stop.circle.fill"
        case .booting: return "arrow.triangle.2.circlepath"
        case .running: return "checkmark.circle.fill"
        case .paused:  return "pause.circle.fill"
        }
    }
}

// MARK: - VMManager
final class VMManager: ObservableObject {
    @Published var state: VMState = .stopped
    @Published var consoleOutput: String = ""

    var ramGB: Double
    var storageGB: Int
    var cpuCores: Int
    var networkEnabled: Bool
    var diskUsedGB: Double = 0

    var onStateChange: ((String) -> Void)?

    private var hypervisor: HypervisorWrapper?
    private var console: VirtioConsole?

    init(ramGB: Double, storageGB: Int, cpuCores: Int, networkEnabled: Bool) {
        self.ramGB          = ramGB
        self.storageGB      = storageGB
        self.cpuCores       = cpuCores
        self.networkEnabled = networkEnabled
    }

    // MARK: - Start
    func startVM() {
        guard state == .stopped || state == .paused else { return }
        setState(.booting)
        consoleOutput = ""

        // Memory check — clamp to available - 0.5 GB
        let monitor   = MemoryMonitor()
        let available = monitor.availableMemoryGB
        let effective: Double
        if available > 0.5 && ramGB > available - 0.5 {
            effective = ((available - 0.5) * 10).rounded() / 10
            consoleOutput += "[iCore] Requested \(String(format:"%.1f",ramGB)) GB, available \(String(format:"%.1f",available)) GB → clamping to \(String(format:"%.1f",effective)) GB\n"
        } else {
            effective = ramGB
        }
        consoleOutput += "[iCore] Memory available: \(String(format:"%.1f", available)) GB\n"

        let wrapper = HypervisorWrapper(ramGB: effective, cpuCores: cpuCores)
        let con = VirtioConsole { [weak self] text in
            DispatchQueue.main.async { self?.consoleOutput += text }
        }
        wrapper.console = con
        hypervisor = wrapper
        console    = con

        // ── Real boot path ──────────────────────────────────────────────────
        // Only attempted when a disk image has been provided by the user.
        // If any step fails, we transparently fall through to demo mode.
        // ────────────────────────────────────────────────────────────────────
        // (diskImagePath is not stored in VMManager; check via onStateChange
        //  caller or extend VMConfig. For this build we always try real HV
        //  first, then fall back.)

        let fwOK    = wrapper.loadFramework()
        let vmOK    = fwOK   && wrapper.createVM()
        let vcpuOK  = vmOK   && wrapper.createVCPU()

        if vcpuOK {
            // Real Hypervisor path — load test binary and run
            wrapper.loadTestBinary()
            setState(.running)
            wrapper.runVCPU { [weak self] msg in
                DispatchQueue.main.async {
                    self?.consoleOutput += msg
                    self?.setState(.stopped)
                }
            }
        } else {
            // Demo fallback — VirtioConsole fake boot sequence
            consoleOutput += "[iCore] Hypervisor not available — running in demo mode.\n"
            con.onBoot = { [weak self] in
                DispatchQueue.main.async { self?.setState(.running) }
            }
            con.startStream()
        }
    }

    // MARK: - Controls
    func pauseVM() {
        guard state == .running else { return }
        console?.stopStream()
        hypervisor?.stop()
        setState(.paused)
    }

    func stopVM() {
        console?.stopStream()
        hypervisor?.stop()
        hypervisor = nil
        console    = nil
        setState(.stopped)
        consoleOutput = ""
    }

    private func setState(_ s: VMState) {
        state = s
        onStateChange?(s.rawValue)
    }
}
