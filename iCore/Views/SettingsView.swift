import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: VMManager
    @Environment(\.dismiss) private var dismiss

    // RAM in 0.5 GB steps: 1.0 … 6.0
    private let ramOptions: [Double] = stride(from: 1.0, through: 6.0, by: 0.5).map { $0 }
    @State private var selectedRAMIndex: Int = 6   // default 4.0 GB (index 6)
    @State private var storage: Double = 16
    @State private var cores: Int = 2
    @State private var networkEnabled: Bool = true

    private var selectedRAM: Double { ramOptions[selectedRAMIndex] }

    var body: some View {
        ZStack {
            Color(hex: "0A0A0F").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "1A1A3A").opacity(0.5), .clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ramSection
                        storageSection
                        cpuSection
                        networkSection
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadSettings)
    }

    // MARK: Nav bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color(hex: "6E6BFF"))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            // Balance
            Text("Back").opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: RAM Section
    private var ramSection: some View {
        settingsSection(header: "Memory") {
            VStack(alignment: .leading, spacing: 16) {
                // Big value display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", selectedRAM))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: selectedRAMIndex)
                    Text("GB")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "4A47CC"))
                        .padding(.bottom, 4)
                }

                // Warning
                if selectedRAM > 5.0 {
                    Label("High allocation may degrade host performance.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "FFB300"))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Picker wheel
                Picker("RAM", selection: $selectedRAMIndex) {
                    ForEach(ramOptions.indices, id: \.self) { i in
                        Text(String(format: "%.1f GB", ramOptions[i]))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
                .tint(Color(hex: "6E6BFF"))
            }
            .animation(.spring(response: 0.35), value: selectedRAM > 5.0)
        }
    }

    // MARK: Storage Section
    private var storageSection: some View {
        settingsSection(header: "Storage") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(storage))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: storage)
                    Text("GB")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "CC47A0"))
                        .padding(.bottom, 4)
                }

                Slider(value: $storage, in: 8...128, step: 8)
                    .tint(
                        LinearGradient(
                            colors: [Color(hex: "CC47A0"), Color(hex: "FF78D8")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                HStack {
                    Text("8 GB").font(.caption).foregroundColor(Color(hex: "505070"))
                    Spacer()
                    Text("128 GB").font(.caption).foregroundColor(Color(hex: "505070"))
                }
            }
        }
    }

    // MARK: CPU Section
    private var cpuSection: some View {
        settingsSection(header: "CPU Cores") {
            HStack(spacing: 10) {
                ForEach([1, 2, 4], id: \.self) { n in
                    Button { cores = n } label: {
                        VStack(spacing: 4) {
                            Text("\(n)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text(n == 1 ? "core" : "cores")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(cores == n
                            ? LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(hex: "1A1A2E"), Color(hex: "1A1A2E")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .foregroundColor(cores == n ? .white : Color(hex: "606080"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(cores == n ? Color(hex: "6E6BFF").opacity(0.6) : Color(hex: "2A2A44"), lineWidth: 1)
                        )
                        .shadow(color: cores == n ? Color(hex: "4A47CC").opacity(0.4) : .clear, radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3), value: cores)
                }
            }
        }
    }

    // MARK: Network Section
    private var networkSection: some View {
        settingsSection(header: "Network") {
            Toggle(isOn: $networkEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "1E2E50"))
                            .frame(width: 34, height: 34)
                        Image(systemName: "network")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "6E6BFF"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Virtual Network Interface")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("eth0 (192.168.64.x)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "505070"))
                    }
                }
            }
            .tint(Color(hex: "6E6BFF"))
        }
    }

    // MARK: Save Button
    private var saveButton: some View {
        Button(action: saveAndRestart) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                Text("Save & Restart")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(hex: "4A47CC").opacity(0.5), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Helpers
    @ViewBuilder
    private func settingsSection<Content: View>(header: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "505070"))
                .tracking(1.2)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)

            content()
                .padding(18)
                .glassCard()
        }
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        let savedRAM = d.double(forKey: "ram_gb")
        if let idx = ramOptions.firstIndex(of: savedRAM) {
            selectedRAMIndex = idx
        } else {
            selectedRAMIndex = ramOptions.firstIndex(of: 4.0) ?? 6
        }
        let s = d.double(forKey: "storage_gb")
        storage = s >= 8 ? min(s, 128) : 16

        let c = d.integer(forKey: "cpu_cores")
        cores = [1, 2, 4].contains(c) ? c : 2

        networkEnabled = d.object(forKey: "network_enabled") == nil
            ? true : d.bool(forKey: "network_enabled")
    }

    private func saveAndRestart() {
        let d = UserDefaults.standard
        d.set(selectedRAM,   forKey: "ram_gb")
        d.set(storage,       forKey: "storage_gb")
        d.set(cores,         forKey: "cpu_cores")
        d.set(networkEnabled,forKey: "network_enabled")
        d.synchronize()

        vm.stopVM()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            vm.loadSettings()
            vm.startVM()
        }
        dismiss()
    }
}
