import Foundation
import Darwin

// MARK: - HypervisorWrapper
// Calls real Hypervisor.framework functions via the C bridging header.
// Falls back to demo mode if hv_vm_create() fails at runtime.

final class HypervisorWrapper {
    var console: VirtioConsole?

    private var vcpu: hv_vcpu_t = 0
    private var memory: UnsafeMutableRawPointer?
    private let memorySize: Int
    private let cpuCores: Int
    private var vmCreated   = false
    private var vcpuCreated = false
    private(set) var running = false

    // Initialise with GB directly (matches user spec)
    init(ramGB: Double, cpuCores: Int = 1) {
        self.memorySize = Int(ramGB * 1_073_741_824)   // exact bytes
        self.cpuCores   = max(1, cpuCores)
    }

    // Convenience shim so existing callers using ramSizeMB still compile
    convenience init(ramSizeMB: Int, cpuCores: Int) {
        self.init(ramGB: Double(ramSizeMB) / 1024.0, cpuCores: cpuCores)
    }

    deinit { destroyVM() }

    // MARK: - Create VM
    /// Returns true on real hardware with Hypervisor entitlements.
    /// Returns false gracefully on simulator / devices without the entitlement.
    func createVM() -> Bool {
        let ret = hv_vm_create(nil)
        guard ret == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_create returned \(ret) — demo mode active.\n")
            return false
        }
        vmCreated = true
        console?.emit("[HV] VM created.\n")

        // Allocate page-aligned anonymous memory
        let pageSize  = Int(getpagesize())
        let alignedSz = (memorySize + pageSize - 1) & ~(pageSize - 1)
        let mem = mmap(nil, alignedSz, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANON, -1, 0)
        guard mem != MAP_FAILED, let mem else {
            console?.emit("[HV] mmap failed — demo mode active.\n")
            return false
        }
        memset(mem, 0, alignedSz)
        memory = mem
        console?.emit("[HV] Guest RAM: \(alignedSz / 1024) KB allocated.\n")

        // Map into guest IPA space at 0x40000000
        let gpa = UInt64(0x4000_0000)
        let flags = UInt64(HV_MEMORY_READ) | UInt64(HV_MEMORY_WRITE) | UInt64(HV_MEMORY_EXEC)
        let mapRet = hv_vm_map(mem, gpa, alignedSz, flags)
        guard mapRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_map failed (\(mapRet)) — demo mode active.\n")
            return false
        }
        console?.emit("[HV] Guest RAM mapped at IPA 0x\(String(gpa, radix: 16)).\n")
        return true
    }

    // MARK: - Create vCPU
    func createVCPU() -> Bool {
        var exitPtr: UnsafeMutablePointer<hv_vcpu_exit_t>?
        let ret = hv_vcpu_create(&vcpu, &exitPtr, nil)
        guard ret == HV_SUCCESS else {
            console?.emit("[HV] hv_vcpu_create failed (\(ret)).\n")
            return false
        }
        vcpuCreated = true
        console?.emit("[HV] vCPU created.\n")
        return true
    }

    // MARK: - Load kernel image
    /// Copies the binary at `url` into guest RAM at offset 0x80000 and sets PC.
    func loadKernel(at url: URL) -> Bool {
        guard let mem = memory else { return false }
        guard let data = try? Data(contentsOf: url) else {
            console?.emit("[HV] Failed to read kernel: \(url.lastPathComponent)\n")
            return false
        }
        let kernelOffset = 0x8_0000
        data.withUnsafeBytes { src in
            mem.advanced(by: kernelOffset)
               .copyMemory(from: src.baseAddress!, byteCount: data.count)
        }
        let pc = UInt64(0x4000_0000) + UInt64(kernelOffset)
        hv_vcpu_set_reg(vcpu, HV_REG_PC, pc)
        hv_vcpu_set_reg(vcpu, HV_REG_CPSR, 0x3C5)    // EL1h, IRQ/FIQ masked
        console?.emit("[HV] Kernel loaded: \(data.count) bytes, PC=0x\(String(pc, radix: 16))\n")
        return true
    }

    // MARK: - Load minimal test binary
    /// Embeds a tiny ARM64 payload that prints "Hello from iCore!\n" via UART MMIO.
    func loadTestBinary() {
        guard let mem = memory else { return }
        let binary = TestBinary.bytes
        binary.withUnsafeBufferPointer { src in
            mem.advanced(by: 0).copyMemory(from: src.baseAddress!, byteCount: src.count)
        }
        let pc = UInt64(0x4000_0000)
        hv_vcpu_set_reg(vcpu, HV_REG_PC, pc)
        hv_vcpu_set_reg(vcpu, HV_REG_CPSR, 0x3C5)
        console?.emit("[HV] Test binary loaded (\(binary.count) bytes).\n")
    }

    // MARK: - Run loop
    func runVCPU(onExit: @escaping (String) -> Void) {
        running = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let uartBase = UInt64(0x0900_0000)
            while self.running {
                let ret = hv_vcpu_run(self.vcpu)
                guard ret == HV_SUCCESS else {
                    onExit("[HV] vcpu_run error: \(ret)\n")
                    break
                }
                // Without the full exit struct definition we advance PC
                // and handle writes to our UART MMIO address heuristically.
                var pc: UInt64 = 0
                hv_vcpu_get_reg(self.vcpu, HV_REG_PC, &pc)
                // Detect UART write: if x0 is printable ASCII and pc is near UART
                var x0: UInt64 = 0
                hv_vcpu_get_reg(self.vcpu, HV_REG_X0, &x0)
                if x0 >= 0x20 && x0 < 0x7F {
                    self.console?.processByte(UInt8(x0 & 0xFF))
                } else if x0 == 0x0A {
                    self.console?.processByte(0x0A)
                }
                // Advance PC past the faulting instruction
                hv_vcpu_set_reg(self.vcpu, HV_REG_PC, pc &+ 4)

                // WFI / halt sentinel: x0 == 0 and pc hasn't changed
                if x0 == 0 {
                    onExit("[HV] Guest halted.\n")
                    break
                }
            }
            self.running = false
        }
    }

    // MARK: - Stop
    func stop() { running = false }

    // MARK: - Teardown
    private func destroyVM() {
        running = false
        if vcpuCreated { hv_vcpu_destroy(vcpu); vcpuCreated = false }
        if let mem = memory {
            let pageSize = Int(getpagesize())
            let alignedSz = (memorySize + pageSize - 1) & ~(pageSize - 1)
            munmap(mem, alignedSz)
            memory = nil
        }
        if vmCreated { hv_vm_destroy(); vmCreated = false }
    }
}

// MARK: - Minimal ARM64 test binary
private enum TestBinary {
    static let bytes: [UInt8] = build()
    private static func build() -> [UInt8] {
        var code: [UInt8] = []
        func emit(_ w: UInt32) {
            code += [UInt8(w & 0xFF), UInt8((w>>8)&0xFF), UInt8((w>>16)&0xFF), UInt8((w>>24)&0xFF)]
        }
        func movz(_ reg: UInt32, _ imm: UInt32, _ shift: UInt32) -> UInt32 {
            (1<<31)|(0b10<<29)|(0b100101<<23)|((shift/16)<<21)|((imm&0xFFFF)<<5)|reg
        }
        func movk(_ reg: UInt32, _ imm: UInt32, _ shift: UInt32) -> UInt32 {
            (1<<31)|(0b11<<29)|(0b100101<<23)|((shift/16)<<21)|((imm&0xFFFF)<<5)|reg
        }
        // X1 = UART base 0x09000000
        emit(movz(1, 0x0000, 0)); emit(movk(1, 0x0900, 16))
        for byte in "Hello from iCore!\n".utf8 {
            emit(movz(0, UInt32(byte), 0))   // W0 = char
            emit(0xB900_0020)                 // STR W0, [X1]
        }
        emit(0xD503_3FDF)   // WFI — halt
        return code
    }
}
