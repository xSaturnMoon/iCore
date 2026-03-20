import Foundation

// MARK: - Disk Format
enum DiskFormat: String, Codable {
    case raw   = "raw"
    case qcow2 = "qcow2"
    case iso   = "iso"

    static func detect(from path: String) -> DiskFormat {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "qcow2": return .qcow2
        case "iso":   return .iso
        default:      return .raw
        }
    }

    var qemuFormat: String { rawValue }
}

// MARK: - VMConfig
struct VMConfig: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var diskImagePath: String
    var diskFormat: DiskFormat
    var ramGB: Double
    var storageGB: Int
    var cpuCores: Int
    var networkEnabled: Bool
    var status: String   // "stopped" | "booting" | "running" | "paused"

    init(id: UUID = UUID(), name: String, diskImagePath: String,
         ramGB: Double, storageGB: Int, cpuCores: Int,
         networkEnabled: Bool, status: String) {
        self.id            = id
        self.name          = name
        self.diskImagePath = diskImagePath
        self.diskFormat    = DiskFormat.detect(from: diskImagePath)
        self.ramGB         = ramGB
        self.storageGB     = storageGB
        self.cpuCores      = cpuCores
        self.networkEnabled = networkEnabled
        self.status        = status
    }
}
