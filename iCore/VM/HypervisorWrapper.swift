import Foundation
import Hypervisor

// MARK: - Constants
private let VM_MEMORY_BASE: hv_ipa_t = 0x4000_0000
private let VM_MEMORY_SIZE: Int      = 32 * 1024 * 1024   // 32 MB
private let UART_MMIO_BASE: hv_ipa_t = 0x0900_0000        // PL011-style UART

// MARK: - HypervisorWrapper
final class HypervisorWrapper {
    var console: VirtioConsole?

    private let ramSizeMB: Int
    private let cpuCores:  Int

    private var memoryRegion: UnsafeMutableRawPointer?
    private var vcpu:          hv_vcpu_t = 0
    private var exitInfo:      UnsafeMutablePointer<hv_vcpu_exit_t>?

    private var vmCreated   = false
    private var vcpuCreated = false
    private(set) var running = false

    init(ramSizeMB: Int, cpuCores: Int) {
        self.ramSizeMB = ramSizeMB
        self.cpuCores  = max(1, cpuCores)
    }

    deinit { destroyVM() }

    // MARK: - Create

    func createVM() -> Bool {
        // 1. Create VM
        let createRet = hv_vm_create(nil)
        guard createRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_create failed: \(createRet)\n")
            return false
        }
        vmCreated = true
        console?.emit("[HV] VM created.\n")

        // 2. Allocate page-aligned RAM
        let pageSize  = Int(getpagesize())
        let alignedSz = (VM_MEMORY_SIZE + pageSize - 1) & ~(pageSize - 1)
        var rawPtr: UnsafeMutableRawPointer?
        guard posix_memalign(&rawPtr, pageSize, alignedSz) == 0, let mem = rawPtr else {
            console?.emit("[HV] RAM allocation failed.\n")
            return false
        }
        memset(mem, 0, alignedSz)
        memoryRegion = mem

        // 3. Map guest RAM
        let mapRet = hv_vm_map(mem, VM_MEMORY_BASE, alignedSz,
                               hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC))
        guard mapRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_map failed: \(mapRet)\n")
            return false
        }
        console?.emit("[HV] Guest RAM: \(alignedSz / 1024) KB at IPA 0x\(String(VM_MEMORY_BASE, radix: 16)).\n")

        // 4. Load test binary
        let binary = TestBinary.armBytes
        binary.withUnsafeBufferPointer { buf in
            memcpy(mem, buf.baseAddress!, buf.count)
        }
        console?.emit("[HV] Test binary loaded (\(binary.count) bytes).\n")

        // 5. Create vCPU
        var exitPtr: UnsafeMutablePointer<hv_vcpu_exit_t>?
        let cpuRet = hv_vcpu_create(&vcpu, &exitPtr, nil)
        guard cpuRet == HV_SUCCESS, let ep = exitPtr else {
            console?.emit("[HV] hv_vcpu_create failed: \(cpuRet)\n")
            return false
        }
        exitInfo    = ep
        vcpuCreated = true

        // 6. Set initial register state
        hv_vcpu_set_reg(vcpu, HV_REG_PC,   VM_MEMORY_BASE)
        hv_vcpu_set_reg(vcpu, HV_REG_CPSR, 0x3C5)   // AArch64 EL1h
        console?.emit("[HV] vCPU ready. PC=0x\(String(VM_MEMORY_BASE, radix: 16)) CPSR=0x3C5\n")
        console?.emit("[HV] Starting execution…\n\n")
        return true
    }

    // MARK: - Run loop

    func run() {
        running = true
        while running {
            let ret = hv_vcpu_run(vcpu)
            guard ret == HV_SUCCESS, let ep = exitInfo else {
                console?.emit("[HV] Run error: \(ret)\n")
                break
            }

            let exit = ep.pointee
            switch exit.reason {

            case HV_EXIT_REASON_EXCEPTION:
                let syndrome  = exit.exception.syndrome
                let ec        = (syndrome >> 26) & 0x3F

                if ec == 0x24 || ec == 0x25 {
                    // Data abort — check for UART MMIO write
                    let faultAddr = exit.exception.physical_address
                    let isWrite   = ((syndrome >> 6) & 1) == 1
                    let srt       = (syndrome >> 16) & 0x1F   // source register

                    if faultAddr == UART_MMIO_BASE && isWrite {
                        var regVal: UInt64 = 0
                        hv_vcpu_get_reg(vcpu, hv_reg_t(rawValue: HV_REG_X0.rawValue + UInt32(srt))!, &regVal)
                        console?.processByte(UInt8(regVal & 0xFF))
                    }
                    // Advance PC past the faulting instruction
                    var pc: UInt64 = 0
                    hv_vcpu_get_reg(vcpu, HV_REG_PC, &pc)
                    hv_vcpu_set_reg(vcpu, HV_REG_PC, pc &+ 4)

                } else if ec == 0x01 {
                    // WFI/WFE — guest halted
                    console?.emit("\n[HV] VM halted (WFI). Done.\n")
                    running = false
                } else {
                    console?.emit("[HV] Unhandled EC=0x\(String(ec, radix: 16))\n")
                    running = false
                }

            case HV_EXIT_REASON_CANCELED:
                running = false

            default:
                console?.emit("[HV] Unknown exit: \(exit.reason)\n")
                running = false
            }
        }
    }

    func stop() { running = false }

    // MARK: - Teardown

    private func destroyVM() {
        running = false
        if vcpuCreated {
            hv_vcpu_destroy(vcpu)
            vcpuCreated = false
        }
        if let mem = memoryRegion {
            free(mem)
            memoryRegion = nil
        }
        if vmCreated {
            hv_vm_destroy()
            vmCreated = false
        }
    }
}

// MARK: - Minimal ARM64 test binary
/// Writes "Hello from iCore!\n" byte-by-byte to UART_MMIO_BASE via STR,
/// then halts with WFI.
private enum TestBinary {
    static let armBytes: [UInt8] = build()

    private static func build() -> [UInt8] {
        var code: [UInt8] = []

        func emit(_ insn: UInt32) {
            code += [
                UInt8(insn & 0xFF),
                UInt8((insn >> 8)  & 0xFF),
                UInt8((insn >> 16) & 0xFF),
                UInt8((insn >> 24) & 0xFF),
            ]
        }

        // MOVZ Xn, #imm16, LSL #shift
        func movz(_ reg: UInt32, _ imm: UInt32, _ shift: UInt32) -> UInt32 {
            let hw = shift / 16
            return (1 << 31) | (0b10 << 29) | (0b100101 << 23) | (hw << 21) | ((imm & 0xFFFF) << 5) | reg
        }
        // MOVK Xn, #imm16, LSL #shift
        func movk(_ reg: UInt32, _ imm: UInt32, _ shift: UInt32) -> UInt32 {
            let hw = shift / 16
            return (1 << 31) | (0b11 << 29) | (0b100101 << 23) | (hw << 21) | ((imm & 0xFFFF) << 5) | reg
        }

        let uartBase: UInt32 = 0x0900_0000
        // X1 = UART base
        emit(movz(1, uartBase & 0xFFFF, 0))
        if (uartBase >> 16) != 0 {
            emit(movk(1, uartBase >> 16, 16))
        }

        for byte in "Hello from iCore!\n".utf8 {
            // MOVZ W0, #byte
            emit(movz(0, UInt32(byte), 0))
            // STR W0, [X1]  (offset 0)
            emit(0xB900_0020)
        }

        // WFI
        emit(0xD503_3FDF)
        return code
    }
}
