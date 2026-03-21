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
    var diskImagePath: String
    var diskUsedGB: Double = 0

    var onStateChange: ((String) -> Void)?

    private var hypervisor: HypervisorWrapper?
    private var console: VirtioConsole?

    init(ramGB: Double, storageGB: Int, cpuCores: Int, networkEnabled: Bool, diskImagePath: String = "") {
        self.ramGB           = ramGB
        self.storageGB       = storageGB
        self.cpuCores        = cpuCores
        self.networkEnabled  = networkEnabled
        self.diskImagePath   = diskImagePath
    }

    // MARK: - Start
    func startVM() {
        guard state == .stopped || state == .paused else { return }
        setState(.booting)
        consoleOutput = ""

        let monitor   = MemoryMonitor()
        let available = monitor.availableMemoryGB
        let effective = (available > 0.5 && ramGB > available - 0.5)
            ? ((available - 0.5) * 10).rounded() / 10
            : ramGB

        consoleOutput += "[iCore] RAM: \(String(format:"%.1f", effective)) GB  CPU: \(cpuCores) vCPU\n"

        // Log disk image status
        if diskImagePath.isEmpty {
            consoleOutput += "[iCore] Disk: none\n"
        } else {
            let exists = FileManager.default.fileExists(atPath: diskImagePath)
            consoleOutput += "[iCore] Disk: \(URL(fileURLWithPath: diskImagePath).lastPathComponent)\n"
            consoleOutput += "[iCore] Disk readable: \(exists)\n"
            if !exists {
                consoleOutput += "[iCore] ERROR: File not found at:\n  \(diskImagePath)\n"
                consoleOutput += "[iCore] Tip: re-import the file via Settings\n"
            }
        }

        let wrapper = HypervisorWrapper(ramGB: effective, cpuCores: cpuCores)
        let con = VirtioConsole { [weak self] text in
            DispatchQueue.main.async { self?.consoleOutput += text }
        }
        wrapper.console = con
        hypervisor = wrapper
        console    = con

        let fwOK   = wrapper.loadFramework()
        let vmOK   = fwOK  && wrapper.createVM()
        let vcpuOK = vmOK  && wrapper.createVCPU()

        if vcpuOK {
            if !diskImagePath.isEmpty && FileManager.default.fileExists(atPath: diskImagePath) {
                _ = wrapper.loadKernel(at: URL(fileURLWithPath: diskImagePath))
            } else if !diskImagePath.isEmpty {
                consoleOutput += "[iCore] Disk file missing — starting without disk\n"
            }
            setState(.running)
            wrapper.runVCPU { [weak self] msg in
                DispatchQueue.main.async {
                    self?.consoleOutput += msg
                    self?.setState(.stopped)
                }
            }
        } else {
            consoleOutput += "[iCore] QEMU not in bundle — demo mode.\n"
            consoleOutput += "[iCore] Build must include qemu-system-aarch64 in Resources/\n"
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
