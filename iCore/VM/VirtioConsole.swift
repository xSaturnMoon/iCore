import Foundation

final class VirtioConsole {
    private let onOutput: (String) -> Void
    private var buffer: [UInt8] = []
    private let queue = DispatchQueue(label: "com.xsaturnmoon.icore.console", qos: .userInteractive)

    init(onOutput: @escaping (String) -> Void) {
        self.onOutput = onOutput
    }

    /// Process a single byte from the MMIO serial port
    func processByte(_ byte: UInt8) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.buffer.append(byte)

            // Flush on newline or when buffer gets large
            if byte == 0x0A || self.buffer.count >= 128 {
                self.flush()
            }
        }
    }

    /// Emit a string directly to the console output
    func emit(_ text: String) {
        queue.async { [weak self] in
            self?.flush()
            self?.onOutput(text)
        }
    }

    /// Flush the byte buffer as a UTF-8 string
    private func flush() {
        guard !buffer.isEmpty else { return }
        let data = Data(buffer)
        buffer.removeAll(keepingCapacity: true)

        if let str = String(data: data, encoding: .utf8) {
            onOutput(str)
        } else {
            // Fallback: replace non-UTF8 bytes with replacement character
            let str = String(data.map { char -> Character in
                let scalar = Unicode.Scalar(char)
                return Character(scalar)
            })
            onOutput(str)
        }
    }
}
