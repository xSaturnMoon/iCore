import Foundation
import Darwin

// MARK: - HypervisorWrapper (QEMU + JIT)
// Uses UTM's prebuilt qemu-system-aarch64 binary, embedded in the app bundle
// under Libraries/. Spawns it via posix_spawn with a stdio pipe and streams
// serial output back to the VMManager console callback.
// Falls back to the VirtioConsole demo sequence if the binary is not present.

final class HypervisorWrapper {
    var console: VirtioConsole?

    private let ramGB:    Double
    private let cpuCores: Int
    private var diskImagePath: String = ""

    private var qemuPid: pid_t = 0
    private var readFd:   Int32 = -1
    private(set) var running = false

    init(ramGB: Double, cpuCores: Int = 1) {
        self.ramGB    = ramGB
        self.cpuCores = max(1, cpuCores)
    }

    convenience init(ramSizeMB: Int, cpuCores: Int) {
        self.init(ramGB: Double(ramSizeMB) / 1024.0, cpuCores: cpuCores)
    }

    deinit { stop() }

    // MARK: - Locate QEMU binary
    private var qemuBinaryPath: String? {
        let bundle = Bundle.main.bundlePath
        let candidates = [
            "\(bundle)/Libraries/qemu-system-aarch64",
            "\(bundle)/qemu-system-aarch64",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - API compatible with VMManager
    func loadFramework() -> Bool {
        guard let path = qemuBinaryPath else {
            console?.emit("[QEMU] qemu-system-aarch64 not found in bundle — demo mode.\n")
            return false
        }
        console?.emit("[QEMU] Found binary: \(path)\n")
        return true
    }

    func createVM() -> Bool  { return qemuBinaryPath != nil }
    func createVCPU() -> Bool { return qemuBinaryPath != nil }
    func loadTestBinary()    { console?.emit("[QEMU] No disk image — will boot with test payload.\n") }
    func loadKernel(at url: URL) -> Bool {
        diskImagePath = url.path
        console?.emit("[QEMU] Disk image: \(url.lastPathComponent)\n")
        return true
    }

    // MARK: - Launch QEMU
    func runVCPU(onExit: @escaping (String) -> Void) {
        guard let qemu = qemuBinaryPath else {
            onExit("[QEMU] Binary missing.\n"); return
        }

        // Build argument list
        var args: [String] = [
            qemu,
            "-M", "virt",
            "-cpu", "host",
            "-m", String(format: "%.0fM", ramGB * 1024),
            "-nographic",
            "-chardev", "pipe,id=console,path=/dev/fd/1",
            "-serial",  "chardev:console",
        ]
        if !diskImagePath.isEmpty {
            args += ["-drive", "file=\(diskImagePath),format=raw,if=virtio"]
        }

        console?.emit("[QEMU] Launching: \(args.joined(separator: " "))\n")

        // Pipe for stdout/stderr → console
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(&pipefd) == 0 else {
            onExit("[QEMU] pipe() failed.\n"); return
        }
        readFd = pipefd[0]

        // posix_spawn file actions: redirect child stdout+stderr to pipe write-end
        var fa: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fa)
        posix_spawn_file_actions_adddup2(&fa, pipefd[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fa, pipefd[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fa, pipefd[0])

        // Convert String array to C argv
        var cStrings: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        cStrings.append(nil)

        let spawnRet = cStrings.withUnsafeMutableBufferPointer { argv in
            posix_spawn(&qemuPid, qemu, &fa, nil, argv.baseAddress, nil)
        }
        posix_spawn_file_actions_destroy(&fa)
        cStrings.dropLast().forEach { free($0) }
        close(pipefd[1])

        guard spawnRet == 0 else {
            close(pipefd[0])
            running = false
            onExit("[QEMU] posix_spawn failed (errno \(spawnRet)).\n")
            return
        }

        running = true
        console?.emit("[QEMU] Process started (pid \(qemuPid)).\n")

        // Stream output on a background thread
        let captureFd = pipefd[0]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { close(captureFd); return }
            var buf = [UInt8](repeating: 0, count: 512)
            while self.running {
                let n = read(captureFd, &buf, buf.count)
                guard n > 0 else { break }
                for i in 0..<n { self.console?.processByte(buf[i]) }
            }
            close(captureFd)
            waitpid(self.qemuPid, nil, 0)
            self.running = false
            onExit("[QEMU] Process exited.\n")
        }
    }

    // MARK: - Stop
    func stop() {
        running = false
        if qemuPid > 0 {
            kill(qemuPid, SIGTERM)
            qemuPid = 0
        }
        if readFd >= 0 {
            close(readFd)
            readFd = -1
        }
    }
}
