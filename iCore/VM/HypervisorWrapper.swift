import Foundation
import Darwin

// MARK: - HypervisorWrapper (QEMU + JIT)
// Locates the bundled qemu-system-aarch64 binary (extracted from UTM),
// spawns it via posix_spawn with a stdout pipe, and streams serial output.
// Falls back to VirtioConsole demo if the binary is absent.

final class HypervisorWrapper {
    var console: VirtioConsole?

    private let ramGB:    Double
    private let cpuCores: Int
    private var diskImagePath: String = ""
    private var diskFormat:    DiskFormat = .raw

    private var qemuPid: pid_t  = 0
    private var readFd:  Int32  = -1
    private(set) var running     = false

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
        // 1. Via Bundle resource lookup (works after xcodegen bundles Resources/)
        if let p = Bundle.main.path(forResource: "qemu-system-aarch64", ofType: nil) { return p }
        // 2. Direct path inside app bundle
        let direct = Bundle.main.bundlePath + "/Resources/qemu-system-aarch64"
        if FileManager.default.fileExists(atPath: direct) { return direct }
        return nil
    }

    // MARK: - API surface used by VMManager
    func loadFramework() -> Bool {
        guard let path = qemuBinaryPath else {
            console?.emit("[QEMU] qemu-system-aarch64 not found in bundle — demo mode.\n")
            return false
        }
        console?.emit("[QEMU] Binary: \(path)\n")
        return true
    }

    func createVM()    -> Bool { return qemuBinaryPath != nil }
    func createVCPU()  -> Bool { return qemuBinaryPath != nil }
    func loadTestBinary() { console?.emit("[QEMU] No disk image — demo mode will be used.\n") }

    func loadKernel(at url: URL) -> Bool {
        diskImagePath = url.path
        diskFormat    = DiskFormat.detect(from: url.path)
        console?.emit("[QEMU] Disk image: \(url.lastPathComponent) (\(diskFormat.rawValue))\n")
        return true
    }

    // MARK: - Launch QEMU
    func runVCPU(onExit: @escaping (String) -> Void) {
        guard let qemu = qemuBinaryPath else {
            onExit("[QEMU] Binary missing.\n"); return
        }

        // Base arguments
        var args: [String] = [
            qemu,
            "-M",   "virt",
            "-cpu", "host",
            "-m",   String(format: "%.0fM", ramGB * 1024),
            "-nographic",
        ]

        // Disk / boot arguments — format-aware
        if !diskImagePath.isEmpty {
            switch diskFormat {
            case .iso:
                args += ["-cdrom", diskImagePath, "-boot", "d"]
            case .qcow2:
                args += ["-drive", "file=\(diskImagePath),format=qcow2,if=virtio"]
            case .raw:
                args += ["-drive", "file=\(diskImagePath),format=raw,if=virtio"]
            }
        }

        // Serial → pipe
        args += ["-chardev", "pipe,id=con,path=/dev/fd/1", "-serial", "chardev:con"]

        console?.emit("[QEMU] \(args.joined(separator: " "))\n\n")

        // Create stdout pipe
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(&pipefd) == 0 else { onExit("[QEMU] pipe() failed.\n"); return }
        readFd = pipefd[0]

        // File actions: child stdout+stderr → pipe write-end
        var fa: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fa)
        posix_spawn_file_actions_adddup2(&fa, pipefd[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fa, pipefd[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fa, pipefd[0])

        var cStrings: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        cStrings.append(nil)

        let spawnRet = cStrings.withUnsafeMutableBufferPointer { argv in
            posix_spawn(&qemuPid, qemu, &fa, nil, argv.baseAddress, nil)
        }
        posix_spawn_file_actions_destroy(&fa)
        cStrings.dropLast().forEach { free($0) }
        close(pipefd[1])

        guard spawnRet == 0 else {
            close(pipefd[0]); running = false
            onExit("[QEMU] posix_spawn failed (errno \(spawnRet)).\n")
            return
        }

        running = true
        console?.emit("[QEMU] Process started (pid \(qemuPid)).\n")

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
        if qemuPid > 0 { kill(qemuPid, SIGTERM); qemuPid = 0 }
        if readFd  >= 0 { close(readFd); readFd = -1 }
    }
}
