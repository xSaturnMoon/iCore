import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: VMManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("ram_gb") private var ramGB: Double = 4.0
    @AppStorage("storage_gb") private var storageGB: Double = 16.0
    @AppStorage("cpu_cores") private var cpuCores: Int = 2
    @AppStorage("network_enabled") private var networkEnabled: Bool = true

    @State private var showRestartAlert = false

    var body: some View {
        ZStack {
            Color(hex: "0D0D1A").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    settingsHeader
                    ramSection
                    storageSection
                    cpuSection
                    networkSection
                    saveButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Dashboard")
                    }
                    .foregroundColor(Color(hex: "6C63FF"))
                }
            }
        }
        .alert("Restart VM?", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                vm.restartVM()
                dismiss()
            }
        } message: {
            Text("Settings saved. The VM will restart with the new configuration.")
        }
    }

    // MARK: - Header
    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "6C63FF"), Color(hex: "3F8EFC")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Settings")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: - RAM Section
    private var ramSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("RAM", systemImage: "memorychip")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f GB", ramGB))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "6C63FF"))
                }

                Slider(value: $ramGB, in: 1...6, step: 1)
                    .tint(Color(hex: "6C63FF"))

                HStack {
                    Text("1 GB")
                    Spacer()
                    Text("6 GB")
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "8B8BA7"))

                if ramGB > 5 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: "FFB300"))
                        Text("High RAM may affect iPad performance")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "FFB300"))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "FFB300").opacity(0.1))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: ramGB)
                }
            }
        }
    }

    // MARK: - Storage Section
    private var storageSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Storage", systemImage: "internaldrive")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f GB", storageGB))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "3F8EFC"))
                }

                Slider(value: $storageGB, in: 8...64, step: 4)
                    .tint(Color(hex: "3F8EFC"))

                HStack {
                    Text("8 GB")
                    Spacer()
                    Text("64 GB")
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "8B8BA7"))
            }
        }
    }

    // MARK: - CPU Section
    private var cpuSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("CPU Cores", systemImage: "cpu")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Picker("CPU Cores", selection: $cpuCores) {
                    Text("1 Core").tag(1)
                    Text("2 Cores").tag(2)
                    Text("4 Cores").tag(4)
                }
                .pickerStyle(.segmented)
                .colorMultiply(Color(hex: "6C63FF"))
            }
        }
    }

    // MARK: - Network Section
    private var networkSection: some View {
        SettingsCard {
            Toggle(isOn: $networkEnabled) {
                Label("Network", systemImage: networkEnabled ? "wifi" : "wifi.slash")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .tint(Color(hex: "6C63FF"))
        }
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            UserDefaults.standard.set(ramGB, forKey: "ram_gb")
            UserDefaults.standard.set(storageGB, forKey: "storage_gb")
            UserDefaults.standard.set(cpuCores, forKey: "cpu_cores")
            UserDefaults.standard.set(networkEnabled, forKey: "network_enabled")

            if vm.state != .stopped {
                showRestartAlert = true
            } else {
                vm.loadSettings()
                dismiss()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                Text("Save & Restart")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: 400)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "6C63FF"), Color(hex: "3F8EFC")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color(hex: "6C63FF").opacity(0.4), radius: 12, y: 6)
        }
    }
}

// MARK: - Settings Card
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
