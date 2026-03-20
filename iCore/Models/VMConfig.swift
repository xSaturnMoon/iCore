import Foundation

struct VMConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var diskImagePath: String
    var ramGB: Double
    var storageGB: Int
    var cpuCores: Int
    var networkEnabled: Bool
    var status: String   // "stopped" | "booting" | "running" | "paused"
}
