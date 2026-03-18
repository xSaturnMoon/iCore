import Foundation
import Darwin

// MARK: - Hypervisor Type Definitions
typealias hv_return_t = Int32
typealias hv_vcpu_t = UInt64
typealias hv_ipa_t = UInt64
typealias hv_memory_flags_t = UInt64

// Register indices (ARM64 Hypervisor.framework)
let HV_REG_X0:  UInt32 = 0
let HV_REG_X1:  UInt32 = 1
let HV_REG_X2:  UInt32 = 2
let HV_REG_X30: UInt32 = 30
let HV_REG_PC:  UInt32 = 31
let HV_REG_CPSR: UInt32 = 34

// Memory flags
let HV_MEMORY_READ:  hv_memory_flags_t = 1 << 0
let HV_MEMORY_WRITE: hv_memory_flags_t = 1 << 1
let HV_MEMORY_EXEC:  hv_memory_flags_t = 1 << 2

// Exit reasons
let HV_EXIT_REASON_CANCELED:         UInt32 = 0
let HV_EXIT_REASON_EXCEPTION:        UInt32 = 1
let HV_EXIT_REASON_VTIMER_ACTIVATED: UInt32 = 2
let HV_EXIT_REASON_UNKNOWN:          UInt32 = 3

let HV_SUCCESS: hv_return_t = 0

// MMIO UART address — writes here produce serial output
let UART_MMIO_BASE: UInt64 = 0x1000_0000
let VM_MEMORY_BASE:  UInt64 = 0x0001_0000
let VM_MEMORY_SIZE:  Int    = 1024 * 1024  // 1 MB

// MARK: - Exit Structure
struct HVExitException {
    var syndrome: UInt64
    var virtualAddress: UInt64
    var physicalAddress: UInt64
}

struct HVVcpuExit {
    var reason: UInt32
    var padding: UInt32
    var exception: HVExitException
}

// MARK: - Dynamically Loaded Function Types
typealias FN_hv_vm_create     = @convention(c) (UnsafeMutableRawPointer?) -> hv_return_t
typealias FN_hv_vm_destroy    = @convention(c) () -> hv_return_t
typealias FN_hv_vm_map        = @convention(c) (UnsafeMutableRawPointer, hv_ipa_t, Int, hv_memory_flags_t) -> hv_return_t
typealias FN_hv_vm_unmap      = @convention(c) (hv_ipa_t, Int) -> hv_return_t
typealias FN_hv_vcpu_create   = @convention(c) (UnsafeMutablePointer<hv_vcpu_t>, UnsafeMutablePointer<UnsafeMutablePointer<HVVcpuExit>?>, UnsafeMutableRawPointer?) -> hv_return_t
typealias FN_hv_vcpu_destroy  = @convention(c) (hv_vcpu_t) -> hv_return_t
typealias FN_hv_vcpu_run      = @convention(c) (hv_vcpu_t) -> hv_return_t
typealias FN_hv_vcpu_set_reg  = @convention(c) (hv_vcpu_t, UInt32, UInt64) -> hv_return_t
typealias FN_hv_vcpu_get_reg  = @convention(c) (hv_vcpu_t, UInt32, UnsafeMutablePointer<UInt64>) -> hv_return_t

// MARK: - HypervisorWrapper
final class HypervisorWrapper {
    let ramSizeMB: Int
    let cpuCores: Int

    var console: VirtioConsole?

    private var vcpu: hv_vcpu_t = 0
    private var exitInfo: UnsafeMutablePointer<HVVcpuExit>?
    private var memoryRegion: UnsafeMutableRawPointer?
    private var vmCreated = false
    private var vcpuCreated = false
    private var running = false

    // Dynamically loaded functions
    private var fn_vm_create:    FN_hv_vm_create?
    private var fn_vm_destroy:   FN_hv_vm_destroy?
    private var fn_vm_map:       FN_hv_vm_map?
    private var fn_vm_unmap:     FN_hv_vm_unmap?
    private var fn_vcpu_create:  FN_hv_vcpu_create?
    private var fn_vcpu_destroy: FN_hv_vcpu_destroy?
    private var fn_vcpu_run:     FN_hv_vcpu_run?
    private var fn_vcpu_set_reg: FN_hv_vcpu_set_reg?
    private var fn_vcpu_get_reg: FN_hv_vcpu_get_reg?

    private var frameworkHandle: UnsafeMutableRawPointer?

    init(ramSizeMB: Int, cpuCores: Int) {
        self.ramSizeMB = ramSizeMB
        self.cpuCores = max(1, cpuCores)
        loadFramework()
    }

    deinit {
        destroyVM()
        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }

    // MARK: - Dynamic Loading
    private func loadFramework() {
        let paths = [
            "/System/Library/Frameworks/Hypervisor.framework/Hypervisor",
            "/System/Library/Frameworks/Hypervisor.framework/Versions/A/Hypervisor"
        ]

        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) {
                frameworkHandle = handle
                break
            }
        }

        guard let handle = frameworkHandle else {
            console?.emit("[HV] Hypervisor.framework not found on this device.\n")
            return
        }

        fn_vm_create    = loadSym(handle, "hv_vm_create")
        fn_vm_destroy   = loadSym(handle, "hv_vm_destroy")
        fn_vm_map       = loadSym(handle, "hv_vm_map")
        fn_vm_unmap     = loadSym(handle, "hv_vm_unmap")
        fn_vcpu_create  = loadSym(handle, "hv_vcpu_create")
        fn_vcpu_destroy = loadSym(handle, "hv_vcpu_destroy")
        fn_vcpu_run     = loadSym(handle, "hv_vcpu_run")
        fn_vcpu_set_reg = loadSym(handle, "hv_vcpu_set_reg")
        fn_vcpu_get_reg = loadSym(handle, "hv_vcpu_get_reg")
    }

    private func loadSym<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    // MARK: - VM Lifecycle
    func createVM() -> Bool {
        guard let vmCreate = fn_vm_create,
              let vmMap = fn_vm_map,
              let vcpuCreate = fn_vcpu_create,
              let vcpuSetReg = fn_vcpu_set_reg else {
            console?.emit("[HV] Required Hypervisor functions not available.\n")
            return false
        }

        // Create the VM
        let ret = vmCreate(nil)
        guard ret == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_create failed: \(ret)\n")
            return false
        }
        vmCreated = true
        console?.emit("[HV] VM created successfully.\n")

        // Allocate and map guest memory
        let pageSize = Int(getpagesize())
        let alignedSize = (VM_MEMORY_SIZE + pageSize - 1) & ~(pageSize - 1)

        var rawPtr: UnsafeMutableRawPointer?
        let allocRet = posix_memalign(&rawPtr, pageSize, alignedSize)
        guard allocRet == 0, let mem = rawPtr else {
            console?.emit("[HV] Memory allocation failed.\n")
            return false
        }
        memoryRegion = mem
        memset(mem, 0, alignedSize)

        let mapRet = vmMap(mem, VM_MEMORY_BASE, alignedSize, HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC)
        guard mapRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vm_map failed: \(mapRet)\n")
            return false
        }
        console?.emit("[HV] Mapped \(alignedSize / 1024) KB at IPA 0x\(String(VM_MEMORY_BASE, radix: 16)).\n")

        // Load test binary into memory
        let binary = TestBinary.code
        binary.withUnsafeBufferPointer { buf in
            memcpy(mem, buf.baseAddress!, buf.count)
        }
        console?.emit("[HV] Loaded test binary (\(binary.count) bytes).\n")

        // Create vCPU
        var exitPtr: UnsafeMutablePointer<HVVcpuExit>?
        let cpuRet = vcpuCreate(&vcpu, &exitPtr, nil)
        guard cpuRet == HV_SUCCESS else {
            console?.emit("[HV] hv_vcpu_create failed: \(cpuRet)\n")
            return false
        }
        exitInfo = exitPtr
        vcpuCreated = true

        // Set initial registers
        _ = vcpuSetReg(vcpu, HV_REG_PC, VM_MEMORY_BASE)
        _ = vcpuSetReg(vcpu, HV_REG_CPSR, 0x3C5)  // EL1h, interrupts masked
        console?.emit("[HV] vCPU created. PC=0x\(String(VM_MEMORY_BASE, radix: 16)) CPSR=0x3C5\n")
        console?.emit("[HV] Starting execution...\n\n")

        return true
    }

    func run() {
        guard let vcpuRun = fn_vcpu_run,
              let vcpuGetReg = fn_vcpu_get_reg,
              let vcpuSetReg = fn_vcpu_set_reg else { return }

        running = true

        while running {
            let ret = vcpuRun(vcpu)
            guard ret == HV_SUCCESS, let exit = exitInfo?.pointee else {
                console?.emit("[HV] vCPU run error: \(ret)\n")
                break
            }

            switch exit.reason {
            case HV_EXIT_REASON_EXCEPTION:
                let syndrome = exit.exception.syndrome
                let ec = (syndrome >> 26) & 0x3F

                if ec == 0x24 || ec == 0x25 {
                    // Data abort — check if it's our UART
                    let faultAddr = exit.exception.physicalAddress
                    let isWrite = ((syndrome >> 6) & 1) == 1
                    let srt = UInt32((syndrome >> 16) & 0x1F)

                    if faultAddr == UART_MMIO_BASE && isWrite {
                        var regValue: UInt64 = 0
                        _ = vcpuGetReg(vcpu, HV_REG_X0 + srt, &regValue)
                        let byte = UInt8(regValue & 0xFF)
                        console?.processByte(byte)
                    }

                    // Advance PC past the faulting instruction
                    var pc: UInt64 = 0
                    _ = vcpuGetReg(vcpu, HV_REG_PC, &pc)
                    _ = vcpuSetReg(vcpu, HV_REG_PC, pc + 4)

                } else if ec == 0x01 {
                    // WFI/WFE — VM is halted
                    console?.emit("\n[HV] VM halted (WFE). Execution complete.\n")
                    running = false
                } else {
                    console?.emit("[HV] Unhandled exception EC=0x\(String(ec, radix: 16)) syndrome=0x\(String(syndrome, radix: 16))\n")
                    running = false
                }

            case HV_EXIT_REASON_CANCELED:
                running = false

            default:
                console?.emit("[HV] Unknown exit reason: \(exit.reason)\n")
                running = false
            }
        }
    }

    func stop() {
        running = false
    }

    func destroyVM() {
        if vcpuCreated {
            fn_vcpu_destroy?(vcpu)
            vcpuCreated = false
        }
        if vmCreated {
            if let mem = memoryRegion {
                fn_vm_unmap?(VM_MEMORY_BASE, VM_MEMORY_SIZE)
                free(mem)
                memoryRegion = nil
            }
            fn_vm_destroy?()
            vmCreated = false
        }
    }
}

// MARK: - Test Binary (ARM64 machine code)
enum TestBinary {
    // ARM64 binary that writes "Hello from iCore Hypervisor!\n" to MMIO UART at 0x10000000
    //
    // Assembly:
    //   movz  x1, #0x1000, lsl #16    // x1 = 0x10000000 (UART address)
    //   adr   x0, .+28               // x0 = pointer to string data
    //   ldrb  w2, [x0], #1           // load byte, post-increment
    //   cbz   w2, .+12              // if null terminator, jump to WFE
    //   strb  w2, [x1]              // write byte to UART (triggers VM exit)
    //   b     .-12                  // loop back to ldrb
    //   wfe                         // halt
    //   b     .-4                   // infinite halt loop
    //   .ascii "Hello from iCore Hypervisor!\n\0"

    static let code: [UInt8] = [
        // movz x1, #0x1000, lsl #16  →  0xD2A20001
        0x01, 0x00, 0xA2, 0xD2,
        // adr x0, .+28               →  0x100000E0
        0xE0, 0x00, 0x00, 0x10,
        // ldrb w2, [x0], #1           →  0x38401402
        0x02, 0x14, 0x40, 0x38,
        // cbz w2, .+12               →  0x34000062  (skip 3 insns = 12 bytes)
        0x62, 0x00, 0x00, 0x34,
        // strb w2, [x1]              →  0x39000022
        0x22, 0x00, 0x00, 0x39,
        // b .-12                     →  0x17FFFFFD
        0xFD, 0xFF, 0xFF, 0x17,
        // wfe                        →  0xD503205F
        0x5F, 0x20, 0x03, 0xD5,
        // b .-4                      →  0x17FFFFFF
        0xFF, 0xFF, 0xFF, 0x17,
        // String: "Hello from iCore Hypervisor!\n\0"
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x66, 0x72,  // Hello fr
        0x6F, 0x6D, 0x20, 0x69, 0x43, 0x6F, 0x72, 0x65,  // om iCore
        0x20, 0x48, 0x79, 0x70, 0x65, 0x72, 0x76, 0x69,  //  Hypervi
        0x73, 0x6F, 0x72, 0x21, 0x0A, 0x00               // sor!\n\0
    ]
}
