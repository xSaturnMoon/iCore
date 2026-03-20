import Foundation

final class VMStore: ObservableObject {
    @Published var vms: [VMConfig] = []
    private var managers: [UUID: VMManager] = [:]
    private let key = "com.xsaturnmoon.icore.vms"

    init() { load() }

    // MARK: - Manager Access
    func ensureManager(for config: VMConfig) -> VMManager {
        if let m = managers[config.id] { return m }
        let m = VMManager(ramGB: config.ramGB,
                          storageGB: config.storageGB,
                          cpuCores: config.cpuCores,
                          networkEnabled: config.networkEnabled)
        m.onStateChange = { [weak self] raw in
            DispatchQueue.main.async {
                guard let i = self?.vms.firstIndex(where: { $0.id == config.id }) else { return }
                self?.vms[i].status = raw
            }
        }
        managers[config.id] = m
        return m
    }

    // MARK: - CRUD
    func add(_ config: VMConfig) { vms.append(config); save() }

    func delete(id: UUID) {
        managers[id]?.stopVM()
        managers.removeValue(forKey: id)
        vms.removeAll { $0.id == id }
        save()
    }

    func update(_ config: VMConfig) {
        guard let i = vms.firstIndex(where: { $0.id == config.id }) else { return }
        vms[i] = config
        save()
    }

    // MARK: - Persistence
    func save() {
        guard let data = try? JSONEncoder().encode(vms) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VMConfig].self, from: data)
        else { return }
        vms = decoded
    }
}
