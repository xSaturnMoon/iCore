import SwiftUI
import UniformTypeIdentifiers

struct AddVMView: View {
    @EnvironmentObject var store: VMStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var diskPath = ""
    @State private var diskName = ""
    @State private var showPicker = false
    @State private var vmName = "Void Linux"
    @State private var ramGB: Double = 2.0
    @State private var storageGB: Double = 32
    @State private var cpuCores = 2
    @State private var netEnabled = true

    private var canNext1: Bool { !diskPath.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    navBar
                    Divider().background(Color(white: 0.12))
                    progressDots
                    ScrollView(showsIndicators: false) {
                        Group {
                            switch step {
                            case 1:  step1
                            case 2:  step2
                            default: step3
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
                VStack {
                    Spacer()
                    bottomButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .background(
                            LinearGradient(colors: [Color.black, Color.black.opacity(0)],
                                           startPoint: .bottom, endPoint: .top)
                            .frame(height: 80)
                            .ignoresSafeArea(),
                            alignment: .bottom
                        )
                }
            }
            .navigationBarHidden(true)
            .fileImporter(isPresented: $showPicker,
                          allowedContentTypes: [UTType(filenameExtension: "img")   ?? .data,
                                                UTType(filenameExtension: "qcow2") ?? .data,
                                                UTType(filenameExtension: "iso")   ?? .data],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let dest = docs.appendingPathComponent(url.lastPathComponent)
                    do {
                        if FileManager.default.fileExists(atPath: dest.path) {
                            try FileManager.default.removeItem(at: dest)
                        }
                        try FileManager.default.copyItem(at: url, to: dest)
                        diskPath = dest.path
                        diskName = url.lastPathComponent
                    } catch {
                        diskPath = url.path
                        diskName = url.lastPathComponent
                    }
                }
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel").font(.system(size: 15)).foregroundColor(Color(hex: "0A84FF"))
            }.buttonStyle(.plain)
            Spacer()
            Text(stepTitle).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Text("Cancel").opacity(0).font(.system(size: 15))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    private var stepTitle: String {
        switch step { case 1: return "Disk Image"; case 2: return "Configuration"; default: return "Summary" }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color(hex: "0A84FF") : Color(white: 0.12))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Step 1
    private var step1: some View {
        VStack(spacing: 1) {
            Button { showPicker = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: diskName.isEmpty ? "folder" : "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(diskName.isEmpty ? Color(white: 0.4) : Color(red: 0.19, green: 0.82, blue: 0.35))
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import from Files")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text(diskName.isEmpty ? "Accepts .img, .qcow2, .iso" : diskName)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(diskName.isEmpty ? Color(white: 0.3) : Color(hex: "0A84FF"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.2))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(white: 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Step 2
    private var step2: some View {
        VStack(spacing: 0) {
            // Name
            sectionHeader("Name")
            HStack {
                TextField("VM Name", text: $vmName)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer().frame(height: 20)

            // RAM
            sectionHeader("Memory")
            VStack(spacing: 10) {
                HStack {
                    Text(String(format: "%.1f GB", ramGB))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: ramGB)
                    Spacer()
                    HStack(spacing: 0) {
                        stepperBtn("-") { if ramGB > 1.0 { ramGB = (ramGB - 0.1).rounded1dp } }
                        stepperBtn("+") { if ramGB < 6.0 { ramGB = (ramGB + 0.1).rounded1dp } }
                    }
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if ramGB > 5.0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                        Text("High RAM may affect iPad performance")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 1, green: 0.84, blue: 0.04))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.2), value: ramGB > 5.0)

            Spacer().frame(height: 20)

            // Storage
            sectionHeader("Storage")
            VStack(spacing: 10) {
                HStack {
                    Text("\(Int(storageGB)) GB")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: storageGB)
                    Spacer()
                }
                Slider(value: $storageGB, in: 8...128, step: 8).tint(Color(hex: "0A84FF"))
                HStack {
                    Text("8 GB").font(.system(size: 11, design: .monospaced)).foregroundColor(Color(white: 0.25))
                    Spacer()
                    Text("128 GB").font(.system(size: 11, design: .monospaced)).foregroundColor(Color(white: 0.25))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer().frame(height: 20)

            // CPU
            sectionHeader("CPU Cores")
            HStack(spacing: 4) {
                ForEach([1, 2, 4], id: \.self) { n in
                    Button { cpuCores = n } label: {
                        VStack(spacing: 2) {
                            Text("\(n)").font(.system(size: 22, weight: .semibold, design: .monospaced))
                            Text(n == 1 ? "core" : "cores").font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(cpuCores == n ? Color(hex: "0A84FF") : Color(white: 0.05))
                        .foregroundColor(cpuCores == n ? .white : Color(white: 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: cpuCores)
                }
            }

            Spacer().frame(height: 20)

            // Network
            sectionHeader("Network")
            HStack {
                Text("Virtual network interface")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                Toggle("", isOn: $netEnabled).tint(Color(hex: "0A84FF")).labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Step 3
    private var step3: some View {
        VStack(spacing: 0) {
            summaryRow("Name", vmName)
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            summaryRow("Disk", diskName.isEmpty ? "—" : diskName)
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            summaryRow("RAM", String(format: "%.1f GB", ramGB))
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            summaryRow("Storage", "\(Int(storageGB)) GB")
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            summaryRow("CPU", "\(cpuCores) vCPU")
            Divider().background(Color(white: 0.08)).padding(.leading, 20)
            summaryRow("Network", netEnabled ? "Enabled" : "Disabled")
        }
        .background(Color(white: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(Color(white: 0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(white: 0.3))
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }

    private func stepperBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 40, height: 36)
        }.buttonStyle(.plain)
    }

    private var bottomButton: some View {
        Button(action: advance) {
            Text(step < 3 ? "Continue" : "Create VM")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(step == 1 && !canNext1 ? Color(white: 0.1) : Color(hex: "0A84FF"))
                .foregroundColor(step == 1 && !canNext1 ? Color(white: 0.3) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(step == 1 && !canNext1)
        .animation(.easeInOut(duration: 0.15), value: canNext1)
    }

    private func advance() {
        if step < 3 {
            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
        } else {
            let cfg = VMConfig(id: UUID(), name: vmName, diskImagePath: diskPath,
                               ramGB: ramGB, storageGB: Int(storageGB),
                               cpuCores: cpuCores, networkEnabled: netEnabled, status: "stopped")
            store.add(cfg)
            dismiss()
        }
    }
}

private extension Double {
    var rounded1dp: Double { (self * 10).rounded() / 10 }
}
