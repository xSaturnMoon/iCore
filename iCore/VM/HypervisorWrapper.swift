import Foundation

// MARK: - HypervisorWrapper (Stub)
/// Simulates an ARM64 VM boot sequence without any real hypervisor calls.
/// Streams fake boot log lines via VirtioConsole, then signals running state.
final class HypervisorWrapper {
    var console: VirtioConsole?

    private let ramSizeMB: Int
    private let cpuCores: Int
    private var task: Task<Void, Never>?
    private(set) var running = false

    init(ramSizeMB: Int, cpuCores: Int) {
        self.ramSizeMB = ramSizeMB
        self.cpuCores  = max(1, cpuCores)
    }

    deinit { stop() }

    func createVM() -> Bool {
        console?.emit("[iCore] Initializing virtual machine (\(ramSizeMB) MB RAM, \(cpuCores) vCPU)…\n")
        return true
    }

    func run() {
        running = true
        // VirtioConsole handles the streaming; nothing to block on here.
        // The caller (VMManager) drives the Task lifetime.
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
    }
}
