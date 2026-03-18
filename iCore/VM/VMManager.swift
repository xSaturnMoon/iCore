import SwiftUI
import Foundation

enum VMState: Equatable {
    case stopped
    case booting
    case running
    case paused

    var label: String {
        switch self {
        case .stopped: return "STOPPED"
        case .booting: return "BOOTING"
        case .running: return "RUNNING"
        case .paused:  return "PAUSED"
        }
    }

    var color: Color {
        switch self {
        case .stopped: return Color(hex: "FF4D6A")
        case .booting: return Color(hex: "FFB300")
        case .running: return Color(hex: "00E676")
        case .paused:  return Color(hex: "FFB300")
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
    private var shouldRun = false

    init() {
        loadSettings()
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        ramAllocatedGB = defaults.double(forKey: "ram_gb")
        if ramAllocatedGB < 1 { ramAllocatedGB = 4.0 }
        storageAllocatedGB = defaults.double(forKey: "storage_gb")
        if storageAllocatedGB < 8 { storageAllocatedGB = 16.0 }
        cpuCores = defaults.integer(forKey: "cpu_cores")
        if cpuCores < 1 { cpuCores = 2 }
        networkEnabled = defaults.bool(forKey: "network_enabled")
    }

    func startVM() {
        guard state == .stopped || state == .paused else { return }

        vmTask?.cancel()
        shouldRun = true

        vmTask = Task { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.state = .booting
                self.consoleOutput = ""
            }

            let wrapper = HypervisorWrapper(
                ramSizeMB: Int(self.ramAllocatedGB * 1024),
                cpuCores: self.cpuCores
            )
            self.hypervisor = wrapper

            let console = VirtioConsole { [weak self] text in
                Task { @MainActor in
                    self?.consoleOutput += text
                }
            }
            wrapper.console = console

            let created = wrapper.createVM()

            await MainActor.run {
                if created {
                    self.state = .running
                } else {
                    self.consoleOutput += "[iCore] VM creation failed. "
                    self.consoleOutput += "Hypervisor.framework may not be available on this device.\n"
                    self.consoleOutput += "[iCore] Entering demo mode with simulated output...\n\n"
                    self.state = .running
                }
            }

            if created {
                wrapper.run()
            } else {
                await self.runDemoOutput()
            }

            if self.shouldRun {
                await MainActor.run {
                    self.state = .stopped
                }
            }
        }
    }

    func pauseVM() {
        guard state == .running else { return }
        shouldRun = false
        hypervisor?.stop()
        state = .paused
    }

    func stopVM() {
        shouldRun = false
        hypervisor?.stop()
        hypervisor?.destroyVM()
        hypervisor = nil
        vmTask?.cancel()
        vmTask = nil
        state = .stopped
        consoleOutput = ""
    }

    func restartVM() {
        stopVM()
        loadSettings()
        startVM()
    }

    // MARK: - Demo Mode
    private func runDemoOutput() async {
        let bootLines = [
            "[    0.000000] Booting Linux on physical CPU 0x0000000000\n",
            "[    0.000000] Linux version 6.6.0 (void@builder) (aarch64-linux-gnu-gcc 13.2) #1 SMP\n",
            "[    0.000000] Machine model: iCore Virtual Platform\n",
            "[    0.000000] Memory: \(Int(ramAllocatedGB * 1024))MB available\n",
            "[    0.000010] CPU: ARMv8 Processor [Apple Silicon]\n",
            "[    0.000015] CPU cores: \(cpuCores)\n",
            "[    0.000100] Calibrating delay loop... 48.00 BogoMIPS\n",
            "[    0.010000] pid_max: default: 32768 minimum: 301\n",
            "[    0.020000] Mount-cache hash table entries: 4096\n",
            "[    0.025000] Dentry cache hash table entries: 65536\n",
            "[    0.030000] Inode-cache hash table entries: 32768\n",
            "[    0.040000] Memory: \(Int(ramAllocatedGB * 1024 - 64))MB/\(Int(ramAllocatedGB * 1024))MB available\n",
            "[    0.050000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=\(cpuCores)\n",
            "[    0.060000] rcu: Hierarchical RCU implementation.\n",
            "[    0.070000] Console: colour dummy device 80x25\n",
            "[    0.080000] printk: console [tty0] enabled\n",
            "[    0.090000] virtio_mmio: iCore Virtio Console initialized\n",
            "[    0.100000] Serial: iCore MMIO UART driver\n",
            "[    0.110000] NET: Registered PF_NETLINK/PF_ROUTE protocol family\n",
            "[    0.120000] virtio_blk virtio0: [vda] \(Int(storageAllocatedGB))GB disk\n",
            "[    0.130000] EXT4-fs (vda): mounted filesystem\n",
            "[    0.140000] VFS: Mounted root (ext4 filesystem) on device 254:0.\n",
            "[    0.150000] Run /sbin/init as init process\n",
            "[    0.200000] systemd[1]: Detected virtualization hypervisor-framework.\n",
            "[    0.210000] systemd[1]: Detected architecture arm64.\n",
            "[    0.220000] systemd[1]: Hostname set to <icore-vm>.\n",
            "[    0.500000] systemd[1]: Reached target Multi-User System.\n",
            "\n",
            "Welcome to Void Linux ARM64 (iCore Virtual Machine)\n",
            "Kernel 6.6.0 on an aarch64 (/dev/ttyS0)\n",
            "\n",
            "icore-vm login: ",
        ]

        for line in bootLines {
            guard shouldRun else { return }
            for char in line {
                guard shouldRun else { return }
                await MainActor.run {
                    self.consoleOutput += String(char)
                }
                try? await Task.sleep(nanoseconds: 2_000_000)
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        while shouldRun {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
