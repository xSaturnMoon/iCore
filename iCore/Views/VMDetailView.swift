import SwiftUI

struct VMDetailView: View {
    @EnvironmentObject var store: VMStore
    let config: VMConfig
    @ObservedObject var manager: VMManager
    @StateObject private var mem = MemoryMonitor()
    @Environment(\.dismiss) private var dismiss
    @State private var showConsole  = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                Divider().background(Color(white: 0.12))
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        statusSection
                        Divider().background(Color(white: 0.08))
                        specsSection
                        Divider().background(Color(white: 0.08))
                        memorySection
                        Divider().background(Color(white: 0.08))
                        diskSection
                        Spacer(minLength: 32)
                        actionButtons
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConsole) {
            ConsoleView(manager: manager)
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(config: config, manager: manager).environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoryPressureCritical)) { _ in
            if manager.state == .running { manager.stopVM() }
        }
    }

    // MARK: Nav
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                    Text("VMs").font(.system(size: 15))
                }.foregroundColor(Color(hex: "0A84FF"))
            }.buttonStyle(.plain)
            Spacer()
            Text(config.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.4))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    // MARK: Status
    private var statusSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(manager.state.color)
                .frame(width: 8, height: 8)
                .shadow(color: manager.state == .running ? manager.state.color.opacity(0.6) : .clear, radius: 4)
            Text(manager.state.label)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.6))
            Spacer()
            if manager.state == .running {
                Button { showConsole = true } label: {
                    Text("Open Console")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "0A84FF"))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.2), value: manager.state)
    }

    // MARK: Specs
    private var specsSection: some View {
        VStack(spacing: 0) {
            specRow(label: "RAM", value: String(format: "%.1f GB", manager.ramGB))
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            specRow(label: "Storage", value: "\(manager.storageGB) GB")
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            specRow(label: "CPU", value: "\(manager.cpuCores) vCPU")
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            specRow(label: "Network", value: manager.networkEnabled ? "Enabled" : "Disabled")
        }
        .padding(.vertical, 4)
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    // MARK: Memory
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Available Memory")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
                Spacer()
                Text(String(format: "%.2f GB free", mem.availableMemoryGB))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(mem.isCritical ? Color(red: 1, green: 0.27, blue: 0.23) :
                                     mem.isWarning  ? Color(red: 1, green: 0.84, blue: 0.04) :
                                     Color(white: 0.5))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: mem.availableMemoryGB)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(mem.isCritical ? Color(red: 1, green: 0.27, blue: 0.23) :
                              mem.isWarning  ? Color(red: 1, green: 0.84, blue: 0.04) :
                              Color(hex: "0A84FF"))
                        .frame(width: g.size.width * CGFloat(min(mem.availableMemoryGB / 8.0, 1.0)), height: 4)
                        .animation(.easeOut(duration: 0.4), value: mem.availableMemoryGB)
                }
            }.frame(height: 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Disk
    private var diskSection: some View {
        HStack {
            Text("Disk Image")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.4))
            Spacer()
            if manager.diskImagePath.isEmpty {
                Text("No image selected")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(white: 0.25))
            } else {
                Text(URL(fileURLWithPath: manager.diskImagePath).lastPathComponent)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            if manager.state == .stopped || manager.state == .paused {
                Button {
                    manager.startVM()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showConsole = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                        Text("Start").font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "0A84FF"))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            } else {
                Button { manager.stopVM() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill").font(.system(size: 14, weight: .bold))
                        Text("Stop").font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1, green: 0.27, blue: 0.23))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: manager.state)
    }
}
