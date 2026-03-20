import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: VMManager
    @Environment(\.dismiss) private var dismiss

    @State private var ram: Double = 4
    @State private var storage: Double = 16
    @State private var cores: Int = 2
    @State private var networkEnabled: Bool = true

    let coreOptions = [1, 2, 4]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A0A0F"), Color(hex: "12121E")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "6E6AFF"))
                    }
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    // Invisible balancer
                    Text("Back").opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 18) {
                        settingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionLabel("RAM Allocation")

                                HStack {
                                    Text("\(Int(ram)) GB")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if ram > 5 {
                                        Label("High usage may degrade host", systemImage: "exclamationmark.triangle.fill")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(hex: "FFB300"))
                                    }
                                }

                                Slider(value: $ram, in: 1...6, step: 1)
                                    .tint(ram > 5 ? Color(hex: "FFB300") : Color(hex: "6E6AFF"))

                                HStack {
                                    Text("1 GB").font(.caption).foregroundColor(Color(hex: "555570"))
                                    Spacer()
                                    Text("6 GB").font(.caption).foregroundColor(Color(hex: "555570"))
                                }
                            }
                        }

                        settingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionLabel("Storage Allocation")

                                Text("\(Int(storage)) GB")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Slider(value: $storage, in: 8...64, step: 8)
                                    .tint(Color(hex: "FF6A88"))

                                HStack {
                                    Text("8 GB").font(.caption).foregroundColor(Color(hex: "555570"))
                                    Spacer()
                                    Text("64 GB").font(.caption).foregroundColor(Color(hex: "555570"))
                                }
                            }
                        }

                        settingsCard {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionLabel("CPU Cores")
                                HStack(spacing: 12) {
                                    ForEach(coreOptions, id: \.self) { option in
                                        Button {
                                            cores = option
                                        } label: {
                                            Text("\(option)")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 52)
                                                .background(cores == option
                                                    ? Color(hex: "6E6AFF")
                                                    : Color(hex: "1E1E30"))
                                                .foregroundColor(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(
                                                            cores == option
                                                                ? Color(hex: "6E6AFF")
                                                                : Color(hex: "2A2A3E"),
                                                            lineWidth: 1
                                                        )
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        settingsCard {
                            Toggle(isOn: $networkEnabled) {
                                HStack(spacing: 12) {
                                    Image(systemName: "network")
                                        .foregroundColor(Color(hex: "6E6AFF"))
                                    Text("Network Interface")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .tint(Color(hex: "6E6AFF"))
                        }

                        Button {
                            saveAndRestart()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise")
                                Text("Save & Restart")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "5A56FF"), Color(hex: "7B78FF")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(hex: "5A56FF").opacity(0.4), radius: 10, y: 4)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadSettings)
    }

    // MARK: - Helpers
    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(Color(hex: "16162A"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "2A2A3E"), lineWidth: 1)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "888AAA"))
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        ram     = d.double(forKey: "ram_gb")     .clamped(to: 1...6,  default: 4)
        storage = d.double(forKey: "storage_gb") .clamped(to: 8...64, default: 16)
        cores   = d.integer(forKey: "cpu_cores") .clamped(to: [1,2,4], default: 2)
        networkEnabled = d.object(forKey: "network_enabled") == nil
            ? true
            : d.bool(forKey: "network_enabled")
    }

    private func saveAndRestart() {
        let d = UserDefaults.standard
        d.set(ram,            forKey: "ram_gb")
        d.set(storage,        forKey: "storage_gb")
        d.set(cores,          forKey: "cpu_cores")
        d.set(networkEnabled, forKey: "network_enabled")
        d.synchronize()

        vm.stopVM()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vm.loadSettings()
            vm.startVM()
        }
        dismiss()
    }
}

// MARK: - Clamp helpers
private extension Double {
    func clamped(to range: ClosedRange<Double>, default fallback: Double) -> Double {
        guard self > 0 else { return fallback }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Int {
    func clamped(to allowed: [Int], default fallback: Int) -> Int {
        guard self > 0, allowed.contains(self) else { return fallback }
        return self
    }
}
