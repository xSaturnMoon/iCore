import Foundation
import Darwin

// MARK: - C-compatible type aliases (mirror Hypervisor.framework ABI)
typealias hv_return_t       = Int32
typealias hv_vcpu_t         = UInt64
typealias hv_ipa_t          = UInt64
typealias hv_memory_flags_t = UInt64

// Memory protection flags
let HV_MEMORY_READ:  hv_memory_flags_t = 1 << 0
let HV_MEMORY_WRITE: hv_memory_flags_t = 1 << 1
let HV_MEMORY_EXEC:  hv_memory_flags_t = 1 << 2

let HV_SUCCESS: hv_return_t = 0

// ARM64 general-purpose register indices
let HV_REG_X0:   UInt32 = 0
let HV_REG_X30:  UInt32 = 30
let HV_REG_PC:   UInt32 = 32   // hv_reg_t: HV_REG_PC = 32
let HV_REG_CPSR: UInt32 = 33   // hv_reg_t: HV_REG_CPSR = 33

// Exit reason constants
let HV_EXIT_REASON_EXCEPTION: UInt32 = 1
let HV_EXIT_REASON_CANCELED:  UInt32 = 2
let HV_EXIT_REASON_VTIMER_ACTIVATED: UInt32 = 3

// Guest memory layout
private let VM_MEMORY_BASE: hv_ipa_t = 0x4000_0000
private let VM_MEMORY_SIZE: Int      = 32 * 1024 * 1024  // 32 MB
private let UART_MMIO_BASE: hv_ipa_t = 0x0900_0000       // PL011 style

// MARK: - C struct mirrors
struct HVException {
    var syndrome:        UInt64
    var virtualAddress:  UInt64
    var physicalAddress: UInt64
}

struct HVVcpuExit {
    var reason:    UInt32
    var padding:   UInt32 = 0
    var exception: HVException
}

// MARK: - Function-pointer type aliases
private typealias FN_hv_vm_create   = @convention(c) (UnsafeMutableRawPointer?) -> hv_return_t
private typealias FN_hv_vm_destroy  = @convention(c) () -> hv_return_t
private typealias FN_hv_vm_map      = @convention(c) (UnsafeMutableRawPointer, hv_ipa_t, Int, hv_memory_flags_t) -> hv_return_t
private typealias FN_hv_vcpu_create = @convention(c) (UnsafeMutablePointer<hv_vcpu_t>, UnsafeMutablePointer<UnsafeMutablePointer<HVVcpuExit>?>, UnsafeMutableRawPointer?) -> hv_return_t
private typealias FN_hv_vcpu_destroy = @convention(c) (hv_vcpu_t) -> hv_return_t
private typealias FN_hv_vcpu_run    = @convention(c) (hv_vcpu_t) -> hv_return_t
private typealias FN_hv_vcpu_set_reg = @convention(c) (hv_vcpu_t, UInt32, UInt64) -> hv_return_t
private typealias FN_hv_vcpu_get_reg = @convention(c) (hv_vcpu_t, UInt32, UnsafeMutablePointer<UInt64>) -> hv_return_t

// MARK: - HypervisorWrapper
final class HypervisorWrapper {
    var console: VirtioConsole?

    private let ramSizeMB: Int
    private let cpuCores:  Int

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var memoryRegion:    UnsafeMutableRawPointer?
    private var vcpu:             hv_vcpu_t = 0
    private var exitInfo:         UnsafeMutablePointer<HVVcpuExit>?
    private var vmCreated   = false
    private var vcpuCreated = false
    private(set) var running = false

    // Dynamic function pointers
    private var fn_vm_create:    FN_hv_vm_create?
    private var fn_vm_destroy:   FN_hv_vm_destroy?
    private var fn_vm_map:       FN_hv_vm_map?
    private var fn_vcpu_create:  FN_hv_vcpu_create?
    private var fn_vcpu_destroy: FN_hv_vcpu_destroy?
    private var fn_vcpu_run:     FN_hv_vcpu_run?
    private var fn_vcpu_set_reg: FN_hv_vcpu_set_reg?
    private var fn_vcpu_get_reg: FN_hv_vcpu_get_reg?

    init(ramSizeMB: Int, cpuCores: Int) {
        self.ramSizeMB = ramSizeMB
        self.cpuCores  = max(1, cpuCores)
        loadFramework()
    }

    deinit {
        destroyVM()
        if let h = frameworkHandle { dlclose(h) }
    }

    // MARK: - Dynamic Loading
    private func loadFramework() {
        let candidates = [
            "/System/Library/Frameworks/Hypervisor.framework/Hypervisor",
            "/System/Library/Frameworks/Hypervisor.framework/Versions/A/Hypervisor",
        ]
        for path in candidates {
            if let h = dlopen(path, RTLD_NOW) {
                frameworkHandle = h
                break
            }
        }
        guard let h = frameworkHandle else {
            console?.emit("[HV] Hypervisor.framework not found – running in simulation mode.\n")
            return
        }

        func sym<T>(_ name: String) -> T? {
            dlsym(h, name).map { unsafeBitCast($0, to: T.self) }
        }
        fn_vm_create    = sym("hv_vm_create")
        fn_vm_destroy   = sym("hv_vm_destroy")
        fn_vm_map       = sym("hv_vm_map")
        fn_vcpu_create  = sym("hv_vcpu_create")
        fn_vcpu_destroy = sym("hv_vcpu_destroy")
        fn_vcpu_run     = sym("hv_vcpu_run")
        fn_vcpu_set_reg = sym("hv_vcpu_set_reg")
        fn_vcpu_get_reg = sym("hv_vcpu_get_reg")
    }

    // MARK: - VM Lifecycle
    func createVM() -> Bool {
        guard let vmCreate = fn_vm_create,
              let vmMap    = fn_vm_map,
              let vcpuCreate = fn_vcpu_create,
              let vcpuSetReg = fn_vcpu_set_reg
        else {
            console?.emit("[HV] Hypervisor.framework symbols not loaded.\n")
            return false
        }

        // 1. Create VM
        let createRet = vmCreate(nil)
        guard createRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_create failed: \(createRet)\n")
            return false
        }
        vmCreated = true
        console?.emit("[HV] VM created.\n")

        // 2. Allocate page-aligned guest RAM
        let pageSize   = Int(getpagesize())
        let alignedSz  = (VM_MEMORY_SIZE + pageSize - 1) & ~(pageSize - 1)
        var rawPtr: UnsafeMutableRawPointer?
        guard posix_memalign(&rawPtr, pageSize, alignedSz) == 0, let mem = rawPtr else {
            console?.emit("[HV] RAM allocation failed.\n")
            return false
        }
        memset(mem, 0, alignedSz)
        memoryRegion = mem

        // 3. Map guest RAM → IPA
        let mapRet = vmMap(mem, VM_MEMORY_BASE, alignedSz,
                           HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC)
        guard mapRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_map failed: \(mapRet)\n")
            return false
        }
        console?.emit("[HV] Guest RAM: \(alignedSz / 1024) KB at IPA 0x\(String(VM_MEMORY_BASE, radix:16)).\n")

        // 4. Load test binary
        let binary = TestBinary.armBytes
        binary.withUnsafeBufferPointer { buf in
            memcpy(mem, buf.baseAddress!, buf.count)
        }
        console?.emit("[HV] Test binary loaded (\(binary.count) bytes).\n")

        // 5. Create vCPU
        var exitPtr: UnsafeMutablePointer<HVVcpuExit>?
        let cpuRet = vcpuCreate(&vcpu, &exitPtr, nil)
        guard cpuRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vcpu_create failed: \(cpuRet)\n")
            return false
        }
        exitInfo    = exitPtr
        vcpuCreated = true

        // 6. Set initial register state
        _ = vcpuSetReg(vcpu, HV_REG_PC,   VM_MEMORY_BASE)
        _ = vcpuSetReg(vcpu, HV_REG_CPSR, 0x3C5)   // AArch64 EL1h, IRQ/FIQ masked
        console?.emit("[HV] vCPU ready. PC=0x\(String(VM_MEMORY_BASE, radix:16)) CPSR=0x3C5\n")
        console?.emit("[HV] Starting execution…\n\n")
        return true
    }

    // MARK: - Run loop
    func run() {
        guard let vcpuRun    = fn_vcpu_run,
              let vcpuGetReg = fn_vcpu_get_reg,
              let vcpuSetReg = fn_vcpu_set_reg
        else { return }

        running = true
        while running {
            let ret = vcpuRun(vcpu)
            guard ret == HV_SUCCESS, let exitPtr = exitInfo else {
                console?.emit("[HV] Run error: \(ret)\n")
                break
            }

            let exit = exitPtr.pointee
            switch exit.reason {

            case HV_EXIT_REASON_EXCEPTION:
                let syndrome = exit.exception.syndrome
                let ec = (syndrome >> 26) & 0x3F

                if ec == 0x24 || ec == 0x25 {
                    // Data abort: possibly our UART MMIO
                    let faultAddr = exit.exception.physicalAddress
                    let isWrite   = ((syndrome >> 6) & 1) == 1
                    let srt       = UInt32((syndrome >> 16) & 0x1F)

                    if faultAddr == UART_MMIO_BASE && isWrite {
                        var regVal: UInt64 = 0
                        _ = vcpuGetReg(vcpu, HV_REG_X0 + srt, &regVal)
                        console?.processByte(UInt8(regVal & 0xFF))
                    }
                    // Advance PC past the faulting instruction
                    var pc: UInt64 = 0
                    _ = vcpuGetReg(vcpu, HV_REG_PC, &pc)
                    _ = vcpuSetReg(vcpu, HV_REG_PC, pc &+ 4)

                } else if ec == 0x01 {
                    // WFI/WFE → VM voluntarily halted
                    console?.emit("\n[HV] VM halted (WFI). Execution complete.\n")
                    running = false
                } else {
                    console?.emit("[HV] Unhandled EC=0x\(String(ec, radix:16)) syndrome=0x\(String(syndrome, radix:16))\n")
                    running = false
                }

            case HV_EXIT_REASON_CANCELED:
                running = false

            case HV_EXIT_REASON_VTIMER_ACTIVATED:
                break  // ignore timer interrupts for now

            default:
                console?.emit("[HV] Unknown exit: \(exit.reason)\n")
                running = false
            }
        }
    }

    func stop() {
        running = false
    }

    // MARK: - Teardown
    private func destroyVM() {
        running = false
        if vcpuCreated, let vcpuDestroy = fn_vcpu_destroy {
            _ = vcpuDestroy(vcpu)
            vcpuCreated = false
        }
        if let mem = memoryRegion {
            free(mem)
            memoryRegion = nil
        }
        if vmCreated, let vmDestroy = fn_vm_destroy {
            _ = vmDestroy()
            vmCreated = false
        }
    }
}

// MARK: - Minimal ARM64 test binary
/// Writes "Hello from iCore!\n" one byte at a time to UART_MMIO_BASE (0x09000000),
/// then executes WFI to halt the vCPU.
private enum TestBinary {
    static let armBytes: [UInt8] = {
        // UART base address: 0x09000000 → stored in X1
        // str w0, [x1]  →  stores the character byte from W0 to UART
        // wfi           →  waits-for-interrupt to signal halt
        //
        // The following shellcode:
        // 1. Loads UART base into X1
        // 2. For each character byte, loads it into W0 and STRs to UART
        // 3. Executes WFI
        var code: [UInt8] = []

        func emit32(_ insn: UInt32) {
            code += [
                UInt8(insn & 0xFF),
                UInt8((insn >> 8)  & 0xFF),
                UInt8((insn >> 16) & 0xFF),
                UInt8((insn >> 24) & 0xFF),
            ]
        }

        let uartBase: UInt32 = 0x0900_0000
        let message = Array("Hello from iCore!\n".utf8)

        // MOV X1, #(uartBase)  — using MOVZ + MOVK for 32-bit immediate
        // MOVZ X1, #0x0900, LSL #16
        emit32(0xD281_2001 | (0x0900 << 5))  // MOVZ X1, #0x0900, lsl #16 — correct encoding below
        // Rebuild correct encoding:
        // MOVZ Xn, #imm16, LSL #shift
        // encoding: 1_10_100101_shift_imm16_Rd
        // MOVZ X1, #0x0900, LSL #16 → shift=1 → 0xD2A12001
        code = []
        func movz(_ reg: UInt32, _ imm: UInt32, _ shift: UInt32) -> UInt32 {
            // Xn: SF=1, opc=10 (MOVZ), op=100101
            let sf: UInt32 = 1
            let opc: UInt32 = 0b10
            let hw = shift / 16
            return (sf << 31) | (opc << 29) | (0b00101 << 23) | (0b1 << 22) | (hw << 21) | (imm << 5) | reg
        }
        func movk(_ reg: UInt32, _ imm: UInt32, _ shift: UInt32) -> UInt32 {
            let sf: UInt32 = 1
            let opc: UInt32 = 0b11
            let hw = shift / 16
            return (sf << 31) | (opc << 29) | (0b00101 << 23) | (0b1 << 22) | (hw << 21) | (imm << 5) | reg
        }
        func movImm32ToX(_ reg: UInt32, _ val: UInt32) {
            // Load lower 16 bits
            emit32(movz(reg, val & 0xFFFF, 0))
            // Load upper 16 bits if needed
            if (val >> 16) != 0 {
                emit32(movk(reg, val >> 16, 16))
            }
        }

        movImm32ToX(1, uartBase)  // X1 = UART base

        for byte in message {
            // MOVZ W0, #byte
            emit32(movz(0, UInt32(byte), 0))   // W0 = byte (W0 is lower 32 bits of X0)
            // STR W0, [X1]   →  0xB9000020
            emit32(0xB900_0020)
        }

        // WFI  → 0xD503_3FDF
        emit32(0xD503_3FDF)

        return code
    }()
}
