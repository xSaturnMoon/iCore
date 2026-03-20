import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: VMStore
    @Environment(\.dismiss) private var dismiss

    let config: VMConfig
    @ObservedObject var manager: VMManager

    @State private var ramGB: Double = 4.0
    @State private var storageGB: Double = 32
    @State private var cpuCores = 2
    @State private var netEnabled = true

    var body: some View {
        ZStack {
            Color(hex: "0A0A0F").ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "1A1A3A").opacity(0.45), .clear],
                           center: .top, startRadius: 0, endRadius: 400).ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ramSection
                        storageSection
                        cpuSection
                        networkSection
                        saveButton
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 48)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { load() }
    }

    // MARK: Nav bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 15, weight: .medium))
                }.foregroundColor(Color(hex: "6E6BFF"))
            }.buttonStyle(.plain)
            Spacer()
            Text("Settings").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Text("Back").opacity(0)
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: RAM
    private var ramSection: some View {
        settingBlock(header: "Memory") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", ramGB))
                            .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.white)
                            .contentTransition(.numericText()).animation(.spring(response: 0.25), value: ramGB)
                        Text("GB").font(.system(size: 20, weight: .semibold)).foregroundColor(Color(hex: "4A47CC"))
                    }
                    if ramGB > 5.0 {
                        Text("High RAM may affect iPad performance")
                            .font(.system(size: 12)).foregroundColor(Color(hex: "FFB300"))
                            .transition(.opacity)
                    }
                }
                Spacer()
                HStack(spacing: 0) {
                    stepperBtn("-") { if ramGB > 1.0 { ramGB = (ramGB - 0.1).rounded1dp } }
                    Text(String(format: "%.1f", ramGB))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white).frame(width: 46).multilineTextAlignment(.center)
                    stepperBtn("+") { if ramGB < 6.0 { ramGB = (ramGB + 0.1).rounded1dp } }
                }
                .background(Color(hex: "1A1A2E")).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2A2A44"), lineWidth: 1))
            }.animation(.spring(response: 0.3), value: ramGB > 5.0)
        }
    }

    private func stepperBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 18, weight: .bold)).foregroundColor(Color(hex: "6E6BFF"))
                .frame(width: 40, height: 40)
        }.buttonStyle(.plain)
    }

    // MARK: Storage
    private var storageSection: some View {
        settingBlock(header: "Storage") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(storageGB))")
                        .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .contentTransition(.numericText()).animation(.spring(response: 0.25), value: storageGB)
                    Text("GB").font(.system(size: 20, weight: .semibold)).foregroundColor(Color(hex: "CC47A0"))
                }
                Slider(value: $storageGB, in: 8...128, step: 8)
                    .tint(LinearGradient(colors: [Color(hex: "CC47A0"), Color(hex: "FF78D8")],
                                         startPoint: .leading, endPoint: .trailing))
                HStack {
                    Text("8 GB").font(.caption).foregroundColor(Color(hex: "505070"))
                    Spacer()
                    Text("128 GB").font(.caption).foregroundColor(Color(hex: "505070"))
                }
            }
        }
    }

    // MARK: CPU
    private var cpuSection: some View {
        settingBlock(header: "CPU Cores") {
            HStack(spacing: 10) {
                ForEach([1, 2, 4], id: \.self) { n in
                    Button { cpuCores = n } label: {
                        VStack(spacing: 3) {
                            Text("\(n)").font(.system(size: 22, weight: .bold, design: .rounded))
                            Text(n == 1 ? "core" : "cores").font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(cpuCores == n
                            ? LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(hex: "1A1A2E"), Color(hex: "1A1A2E")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .foregroundColor(cpuCores == n ? .white : Color(hex: "606080"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(cpuCores == n ? Color(hex: "6E6BFF").opacity(0.5) : Color(hex: "2A2A44"), lineWidth: 1))
                    }.buttonStyle(.plain).animation(.spring(response: 0.25), value: cpuCores)
                }
            }
        }
    }

    // MARK: Network
    private var networkSection: some View {
        settingBlock(header: "Network") {
            Toggle(isOn: $netEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: "network").foregroundColor(Color(hex: "6E6BFF"))
                    Text("Virtual Network Interface").font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                }
            }.tint(Color(hex: "6E6BFF"))
        }
    }

    // MARK: Save
    private var saveButton: some View {
        Button(action: saveAndRestart) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .bold))
                Text("Save & Restart").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(hex: "4A47CC").opacity(0.45), radius: 12, y: 4)
        }.buttonStyle(.plain).padding(.top, 6)
    }

    // MARK: Helpers
    @ViewBuilder
    private func settingBlock<C: View>(header: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header.uppercased())
                .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "505070")).tracking(1)
                .padding(.horizontal, 4)
            content().padding(16).glassCard()
        }
    }

    private func load() {
        ramGB      = manager.ramGB
        storageGB  = Double(manager.storageGB)
        cpuCores   = manager.cpuCores
        netEnabled = manager.networkEnabled
    }

    private func saveAndRestart() {
        manager.ramGB          = ramGB
        manager.storageGB      = Int(storageGB)
        manager.cpuCores       = cpuCores
        manager.networkEnabled = netEnabled

        // Persist to store
        var updated = config
        updated.ramGB          = ramGB
        updated.storageGB      = Int(storageGB)
        updated.cpuCores       = cpuCores
        updated.networkEnabled = netEnabled
        store.update(updated)

        manager.stopVM()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            manager.startVM()
        }
        dismiss()
    }
}

private extension Double {
    var rounded1dp: Double { (self * 10).rounded() / 10 }
}
