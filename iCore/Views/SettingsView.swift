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
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                Divider().background(Color(white: 0.12))
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ramRow
                        Divider().background(Color(white: 0.08)).padding(.leading, 20)
                        storageRow
                        Divider().background(Color(white: 0.08)).padding(.leading, 20)
                        cpuRow
                        Divider().background(Color(white: 0.08)).padding(.leading, 20)
                        networkRow
                        Spacer(minLength: 32)
                        saveButton
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { load() }
    }

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                    Text("Back").font(.system(size: 15))
                }.foregroundColor(Color(hex: "0A84FF"))
            }.buttonStyle(.plain)
            Spacer()
            Text("Settings").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Text("Back").opacity(0).font(.system(size: 15))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    private var ramRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Memory")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.4))
                Spacer()
                HStack(spacing: 0) {
                    stepperBtn("-") { if ramGB > 1.0 { ramGB = (ramGB - 0.1).rounded1dp } }
                    Text(String(format: "%.1f GB", ramGB))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 72)
                        .multilineTextAlignment(.center)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: ramGB)
                    stepperBtn("+") { if ramGB < 6.0 { ramGB = (ramGB + 0.1).rounded1dp } }
                }
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.12), lineWidth: 1))
            }
            if ramGB > 5.0 {
                Text("High RAM allocation may affect iPad performance")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 1, green: 0.84, blue: 0.04))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.2), value: ramGB > 5.0)
    }

    private var storageRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Storage")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.4))
                Spacer()
                Text("\(Int(storageGB)) GB")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2), value: storageGB)
            }
            Slider(value: $storageGB, in: 8...128, step: 8)
                .tint(Color(hex: "0A84FF"))
            HStack {
                Text("8 GB").font(.system(size: 11, design: .monospaced)).foregroundColor(Color(white: 0.25))
                Spacer()
                Text("128 GB").font(.system(size: 11, design: .monospaced)).foregroundColor(Color(white: 0.25))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var cpuRow: some View {
        HStack {
            Text("CPU Cores")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.4))
            Spacer()
            HStack(spacing: 4) {
                ForEach([1, 2, 4], id: \.self) { n in
                    Button { cpuCores = n } label: {
                        Text("\(n)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .frame(width: 44, height: 32)
                            .background(cpuCores == n ? Color(hex: "0A84FF") : Color(white: 0.08))
                            .foregroundColor(cpuCores == n ? .white : Color(white: 0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: cpuCores)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var networkRow: some View {
        HStack {
            Text("Network")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.4))
            Spacer()
            Toggle("", isOn: $netEnabled)
                .tint(Color(hex: "0A84FF"))
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var saveButton: some View {
        Button(action: saveAndRestart) {
            Text("Save & Restart")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(hex: "0A84FF"))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func stepperBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 36, height: 32)
        }.buttonStyle(.plain)
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
        var updated = config
        updated.ramGB          = ramGB
        updated.storageGB      = Int(storageGB)
        updated.cpuCores       = cpuCores
        updated.networkEnabled = netEnabled
        store.update(updated)
        manager.stopVM()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { manager.startVM() }
        dismiss()
    }
}

private extension Double {
    var rounded1dp: Double { (self * 10).rounded() / 10 }
}
