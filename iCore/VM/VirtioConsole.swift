import Foundation

// MARK: - VirtioConsole
/// Lightweight MMIO serial console. Buffers raw bytes from the VM guest
/// and flushes them as UTF-8 strings via an output callback.
final class VirtioConsole {
    private let onOutput: (String) -> Void
    private var buffer: [UInt8] = []
    private let queue = DispatchQueue(
        label: "com.xsaturnmoon.icore.console",
        qos: .userInteractive
    )

    init(onOutput: @escaping (String) -> Void) {
        self.onOutput = onOutput
    }

    /// Called by HypervisorWrapper for every byte the guest writes to the MMIO UART.
    func processByte(_ byte: UInt8) {
        queue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(byte)
            // Flush on newline or when the buffer grows large.
            if byte == 0x0A || self.buffer.count >= 128 {
                self.flush()
            }
        }
    }

    /// Directly emit a host-side diagnostic string (not guest output).
    func emit(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.flush()
            self.onOutput(text)
        }
    }

    // MARK: - Private
    private func flush() {
        guard !buffer.isEmpty else { return }
        let data = Data(buffer)
        buffer.removeAll(keepingCapacity: true)
        let str = String(data: data, encoding: .utf8)
            ?? data.map { b -> Character in
                let s = Unicode.Scalar(b)
                return Character(s)
            }.reduce("") { $0 + String($1) }
        onOutput(str)
    }
}
