import Foundation
import Darwin

// MARK: - HypervisorWrapper
// Launches qemu-aarch64-softmmu (extracted from UTM) via posix_spawn.
// The binary lives in the app bundle under Resources/.
// Dependent dylibs live in Resources/Frameworks/.

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
        let bundle = Bundle.main.bundlePath
        let candidates = [
            bundle + "/Resources/qemu-system-aarch64",
            bundle + "/qemu-system-aarch64",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Locate QEMU firmware directory
    private var qemuDataPath: String? {
        let bundle = Bundle.main.bundlePath
        let p = bundle + "/Resources/qemu-data"
        return FileManager.default.fileExists(atPath: p) ? p : nil
    }

    // MARK: - Frameworks directory for dyld
    private var frameworksPath: String {
        return Bundle.main.bundlePath + "/Resources/Frameworks"
    }

    // MARK: - API
    func loadFramework() -> Bool {
        guard let path = qemuBinaryPath else {
            console?.emit("[QEMU] qemu-system-aarch64 not found in bundle — demo mode.\n")
            return false
        }
        console?.emit("[QEMU] Binary found: \(URL(fileURLWithPath: path).lastPathComponent)\n")
        return true
    }

    func createVM()    -> Bool { return qemuBinaryPath != nil }
    func createVCPU()  -> Bool { return qemuBinaryPath != nil }
    func loadTestBinary() { console?.emit("[QEMU] No disk image provided.\n") }

    func loadKernel(at url: URL) -> Bool {
        diskImagePath = url.path
        diskFormat    = DiskFormat.detect(from: url.path)
        console?.emit("[QEMU] Disk: \(url.lastPathComponent) (\(diskFormat.rawValue))\n")
        return true
    }

    // MARK: - Launch QEMU
    func runVCPU(onExit: @escaping (String) -> Void) {
        guard let qemu = qemuBinaryPath else {
            onExit("[QEMU] Binary missing.\n"); return
        }

        // QEMU data path
        let dataDir = qemuDataPath ?? (Bundle.main.bundlePath + "/Resources/qemu-data")

        // Build arguments
        var args: [String] = [
            qemu,
            "-L", dataDir,                    // firmware search path
            "-M", "virt",
            "-cpu", "host",
            "-smp", "\(cpuCores)",
            "-m", String(format: "%.0f", ramGB * 1024),
            "-nographic",
            "-serial", "mon:stdio",
            "-nodefaults",
            "-device", "virtio-serial-pci",
            "-chardev", "fd,id=con,in=0,out=1",
            "-device", "virtconsole,chardev=con",
        ]

        // Disk / boot
        if !diskImagePath.isEmpty {
            switch diskFormat {
            case .iso:
                args += [
                    "-drive", "file=\(diskImagePath),media=cdrom,if=none,id=cdrom0",
                    "-device", "virtio-scsi-pci",
                    "-device", "scsi-cd,drive=cdrom0",
                    "-boot", "d",
                ]
            case .qcow2:
                args += ["-drive", "file=\(diskImagePath),format=qcow2,if=virtio"]
            case .raw:
                args += ["-drive", "file=\(diskImagePath),format=raw,if=virtio"]
            }
        }

        // Network
        args += ["-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0"]

        console?.emit("[QEMU] Starting: qemu-system-aarch64 \\\n  " +
                      args.dropFirst().joined(separator: " \\\n  ") + "\n\n")

        // Pipe for stdout/stderr
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(&pipefd) == 0 else { onExit("[QEMU] pipe() failed.\n"); return }
        readFd = pipefd[0]

        // File actions
        var fa: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fa)
        posix_spawn_file_actions_adddup2(&fa, pipefd[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fa, pipefd[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fa, pipefd[0])

        // Environment — tell dyld where to find our frameworks
        let dyldPath = frameworksPath
        let envStr   = "DYLD_LIBRARY_PATH=\(dyldPath)"
        var envCStr: [UnsafeMutablePointer<CChar>?] = [strdup(envStr), nil]

        var cStrings: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        cStrings.append(nil)

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)

        let spawnRet = cStrings.withUnsafeMutableBufferPointer { argv in
            envCStr.withUnsafeMutableBufferPointer { envp in
                posix_spawn(&qemuPid, qemu, &fa, &attr, argv.baseAddress, envp.baseAddress)
            }
        }

        posix_spawnattr_destroy(&attr)
        posix_spawn_file_actions_destroy(&fa)
        cStrings.dropLast().forEach { free($0) }
        free(envCStr[0])
        close(pipefd[1])

        guard spawnRet == 0 else {
            close(pipefd[0]); running = false
            onExit("[QEMU] posix_spawn failed (errno \(spawnRet): \(String(cString: strerror(spawnRet)))).\n")
            return
        }

        running = true
        console?.emit("[QEMU] Process started (pid \(qemuPid)).\n")

        let captureFd = pipefd[0]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { close(captureFd); return }
            var buf = [UInt8](repeating: 0, count: 1024)
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
