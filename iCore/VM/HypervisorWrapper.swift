import Foundation
import Darwin

// MARK: - HypervisorWrapper (dlopen/dlsym runtime loading)
// Hypervisor.framework is not in the iOS SDK, so we never link against it.
// Instead we open it at runtime and resolve symbols via dlsym.
// Falls back to demo mode (VirtioConsole) if the framework or entitlement is unavailable.

final class HypervisorWrapper {
    var console: VirtioConsole?

    // MARK: Function pointer types
    private typealias FN_vm_create    = @convention(c) (UnsafeMutableRawPointer?) -> Int32
    private typealias FN_vm_destroy   = @convention(c) () -> Int32
    private typealias FN_vm_map       = @convention(c) (UnsafeMutableRawPointer, UInt64, Int, UInt64) -> Int32
    private typealias FN_vcpu_create  = @convention(c) (UnsafeMutablePointer<UInt64>,
                                                         UnsafeMutablePointer<UnsafeMutableRawPointer?>,
                                                         UnsafeMutableRawPointer?) -> Int32
    private typealias FN_vcpu_destroy = @convention(c) (UInt64) -> Int32
    private typealias FN_vcpu_run     = @convention(c) (UInt64) -> Int32
    private typealias FN_vcpu_get_reg = @convention(c) (UInt64, UInt32, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias FN_vcpu_set_reg = @convention(c) (UInt64, UInt32, UInt64) -> Int32

    // MARK: Resolved symbols
    private var hvHandle:     UnsafeMutableRawPointer?
    private var fn_vm_create:    FN_vm_create?
    private var fn_vm_destroy:   FN_vm_destroy?
    private var fn_vm_map:       FN_vm_map?
    private var fn_vcpu_create:  FN_vcpu_create?
    private var fn_vcpu_destroy: FN_vcpu_destroy?
    private var fn_vcpu_run:     FN_vcpu_run?
    private var fn_vcpu_get_reg: FN_vcpu_get_reg?
    private var fn_vcpu_set_reg: FN_vcpu_set_reg?

    // MARK: State
    private var vcpu: UInt64 = 0
    private var memory: UnsafeMutableRawPointer?
    private let memorySize: Int
    private let cpuCores:   Int
    private var vmCreated   = false
    private var vcpuCreated = false
    private(set) var running = false

    var isAvailable: Bool { hvHandle != nil && fn_vm_create != nil }

    init(ramGB: Double, cpuCores: Int = 1) {
        self.memorySize = Int(ramGB * 1_073_741_824)
        self.cpuCores   = max(1, cpuCores)
    }

    convenience init(ramSizeMB: Int, cpuCores: Int) {
        self.init(ramGB: Double(ramSizeMB) / 1024.0, cpuCores: cpuCores)
    }

    deinit {
        destroyVM()
        if let h = hvHandle { dlclose(h) }
    }

    // MARK: - Load framework
    func loadFramework() -> Bool {
        let path = "/System/Library/Frameworks/Hypervisor.framework/Hypervisor"
        guard let handle = dlopen(path, RTLD_NOW) else {
            console?.emit("[HV] dlopen failed: \(String(cString: dlerror()))\n")
            return false
        }
        hvHandle = handle

        func sym<T>(_ name: String) -> T? {
            guard let ptr = dlsym(handle, name) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }
        fn_vm_create    = sym("hv_vm_create")
        fn_vm_destroy   = sym("hv_vm_destroy")
        fn_vm_map       = sym("hv_vm_map")
        fn_vcpu_create  = sym("hv_vcpu_create")
        fn_vcpu_destroy = sym("hv_vcpu_destroy")
        fn_vcpu_run     = sym("hv_vcpu_run")
        fn_vcpu_get_reg = sym("hv_vcpu_get_reg")
        fn_vcpu_set_reg = sym("hv_vcpu_set_reg")

        guard fn_vm_create != nil else {
            console?.emit("[HV] Symbol resolution failed — demo mode.\n")
            return false
        }
        console?.emit("[HV] Hypervisor.framework loaded.\n")
        return true
    }

    // MARK: - Create VM
    func createVM() -> Bool {
        guard let create = fn_vm_create else { return false }
        guard create(nil) == 0 else {
            console?.emit("[HV] hv_vm_create failed — demo mode.\n")
            return false
        }
        vmCreated = true
        console?.emit("[HV] VM created.\n")

        let pageSize  = Int(getpagesize())
        let alignedSz = (memorySize + pageSize - 1) & ~(pageSize - 1)
        let mem = mmap(nil, alignedSz, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
        guard mem != MAP_FAILED, let mem else {
            console?.emit("[HV] mmap failed.\n"); return false
        }
        memset(mem, 0, alignedSz)
        memory = mem

        let gpa: UInt64 = 0x4000_0000
        let flags: UInt64 = (1 << 0) | (1 << 1) | (1 << 2)   // READ | WRITE | EXEC
        guard fn_vm_map?(mem, gpa, alignedSz, flags) == 0 else {
            console?.emit("[HV] hv_vm_map failed.\n"); return false
        }
        console?.emit("[HV] Guest RAM: \(alignedSz / 1024) KB at IPA 0x\(String(gpa, radix:16)).\n")
        return true
    }

    // MARK: - Create vCPU
    func createVCPU() -> Bool {
        guard let create = fn_vcpu_create else { return false }
        var exitPtr: UnsafeMutableRawPointer? = nil
        guard create(&vcpu, &exitPtr, nil) == 0 else {
            console?.emit("[HV] hv_vcpu_create failed.\n"); return false
        }
        vcpuCreated = true
        console?.emit("[HV] vCPU created.\n")
        return true
    }

    // MARK: - Load kernel image
    func loadKernel(at url: URL) -> Bool {
        guard let mem = memory, let data = try? Data(contentsOf: url) else { return false }
        let offset = 0x8_0000
        data.withUnsafeBytes { src in
            mem.advanced(by: offset).copyMemory(from: src.baseAddress!, byteCount: data.count)
        }
        let pc = UInt64(0x4000_0000) + UInt64(offset)
        fn_vcpu_set_reg?(vcpu, 32, pc)      // HV_REG_PC
        fn_vcpu_set_reg?(vcpu, 33, 0x3C5)  // HV_REG_CPSR — EL1h
        console?.emit("[HV] Kernel loaded (\(data.count) bytes), PC=0x\(String(pc, radix:16)).\n")
        return true
    }

    // MARK: - Load minimal test binary
    func loadTestBinary() {
        guard let mem = memory else { return }
        let binary = TestBinary.bytes
        binary.withUnsafeBufferPointer { src in
            mem.advanced(by: 0).copyMemory(from: src.baseAddress!, byteCount: src.count)
        }
        fn_vcpu_set_reg?(vcpu, 32, 0x4000_0000)  // HV_REG_PC
        fn_vcpu_set_reg?(vcpu, 33, 0x3C5)         // HV_REG_CPSR
        console?.emit("[HV] Test binary loaded (\(binary.count) bytes).\n")
    }

    // MARK: - Run loop
    func runVCPU(onExit: @escaping (String) -> Void) {
        guard let run = fn_vcpu_run else { return }
        running = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            while self.running {
                guard run(self.vcpu) == 0 else {
                    onExit("[HV] vcpu_run error.\n"); break
                }
                var pc: UInt64 = 0
                self.fn_vcpu_get_reg?(self.vcpu, 32, &pc)   // PC
                var x0: UInt64 = 0
                self.fn_vcpu_get_reg?(self.vcpu, 0,  &x0)   // X0
                if x0 >= 0x20 && x0 < 0x7F { self.console?.processByte(UInt8(x0 & 0xFF)) }
                else if x0 == 0x0A         { self.console?.processByte(0x0A) }
                self.fn_vcpu_set_reg?(self.vcpu, 32, pc &+ 4)
                if x0 == 0 { onExit("[HV] Guest halted.\n"); break }
            }
            self.running = false
        }
    }

    func stop() { running = false }

    // MARK: - Teardown
    private func destroyVM() {
        running = false
        if vcpuCreated   { fn_vcpu_destroy?(vcpu); vcpuCreated = false }
        if let mem = memory {
            let pageSize  = Int(getpagesize())
            let alignedSz = (memorySize + pageSize - 1) & ~(pageSize - 1)
            munmap(mem, alignedSz); memory = nil
        }
        if vmCreated     { fn_vm_destroy?(); vmCreated = false }
    }
}

// MARK: - Minimal ARM64 test binary
private enum TestBinary {
    static let bytes: [UInt8] = build()
    private static func build() -> [UInt8] {
        var c: [UInt8] = []
        func w(_ v: UInt32) { c += [UInt8(v&0xFF),UInt8((v>>8)&0xFF),UInt8((v>>16)&0xFF),UInt8((v>>24)&0xFF)] }
        func movz(_ r: UInt32, _ i: UInt32, _ s: UInt32) -> UInt32 {
            (1<<31)|(2<<29)|(0b100101<<23)|((s/16)<<21)|((i&0xFFFF)<<5)|r }
        func movk(_ r: UInt32, _ i: UInt32, _ s: UInt32) -> UInt32 {
            (1<<31)|(3<<29)|(0b100101<<23)|((s/16)<<21)|((i&0xFFFF)<<5)|r }
        // X1 = UART base 0x09000000
        w(movz(1,0x0000,0)); w(movk(1,0x0900,16))
        for b in "Hello from iCore!\n".utf8 {
            w(movz(0,UInt32(b),0)); w(0xB900_0020)   // STR W0,[X1]
        }
        w(0xD503_3FDF)  // WFI
        return c
    }
}
