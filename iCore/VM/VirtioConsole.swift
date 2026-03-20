import Foundation

// MARK: - VirtioConsole (Stub)
/// Streams a simulated Void Linux ARM64 boot sequence, one line at a time,
/// with a short delay between each entry. Calls onBoot() when complete.
final class VirtioConsole {
    private let onOutput: (String) -> Void
    var onBoot: (() -> Void)?

    private var streamTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "com.xsaturnmoon.icore.console", qos: .userInteractive)

    private static let bootLines: [String] = [
        "Void Linux ARM64 booting…",
        "Loading kernel modules…",
        "Starting runit services…",
        "Network: eth0 up (192.168.64.1)",
        "Starting Enlightenment WM…",
        "Boot complete. Welcome to Void Linux.",
    ]

    init(onOutput: @escaping (String) -> Void) {
        self.onOutput = onOutput
    }

    /// Begin streaming fake boot lines with 0.3 s delay each.
    func startStream() {
        streamTask?.cancel()
        streamTask = Task {
            // Short initial pause before first line
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 s boot delay
            for line in Self.bootLines {
                guard !Task.isCancelled else { return }
                let text = line + "\n"
                await MainActor.run { self.onOutput(text) }
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 s between lines
            }
            guard !Task.isCancelled else { return }
            onBoot?()
        }
    }

    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// Emit a host-side diagnostic string immediately.
    func emit(_ text: String) {
        queue.async { [weak self] in
            DispatchQueue.main.async { self?.onOutput(text) }
        }
    }

    /// Accept a raw byte (no-op in stub; kept for API compatibility).
    func processByte(_ byte: UInt8) {}
}
