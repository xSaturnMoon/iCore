import SwiftUI
import UniformTypeIdentifiers

struct AddVMView: View {
    @EnvironmentObject var store: VMStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1

    // Step 1
    @State private var diskPath = ""
    @State private var diskName = ""
    @State private var isDownloading = false
    @State private var dlProgress: Double = 0
    @State private var showPicker = false

    // Step 2
    @State private var vmName = "Void Linux"
    @State private var ramGB: Double = 4.0
    @State private var storageGB: Double = 32
    @State private var cpuCores = 2
    @State private var netEnabled = true

    private var canNext1: Bool { !diskPath.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0F").ignoresSafeArea()
                RadialGradient(colors: [Color(hex: "1A1A3A").opacity(0.45), .clear],
                               center: .top, startRadius: 0, endRadius: 400).ignoresSafeArea()
                VStack(spacing: 0) {
                    navBar
                    progressBar
                    ScrollView(showsIndicators: false) {
                        Group {
                            switch step {
                            case 1:  step1
                            case 2:  step2
                            default: step3
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 48)
                    }
                    bottomButton
                        .padding(.horizontal, 20).padding(.bottom, 36).padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .fileImporter(isPresented: $showPicker,
                          allowedContentTypes: [UTType(filenameExtension: "img") ?? .data,
                                                UTType(filenameExtension: "qcow2") ?? .data],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    diskPath = url.path; diskName = url.lastPathComponent
                }
            }
        }
    }

    // MARK: Nav bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel").font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "6E6BFF"))
            }.buttonStyle(.plain)
            Spacer()
            Text(stepTitle).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Text("Step \(step) of 3").font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "505070"))
        }.padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var stepTitle: String {
        switch step { case 1: return "Choose Disk Image"; case 2: return "Configure VM"; default: return "Ready to Create" }
    }

    // MARK: Progress bar
    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color(hex: "6E6BFF") : Color(hex: "2A2A44"))
                    .frame(height: 3)
                    .animation(.spring(), value: step)
            }
        }.padding(.horizontal, 20).padding(.bottom, 12)
    }

    // MARK: Step 1 — Disk Image
    private var step1: some View {
        VStack(spacing: 14) {
            // Import card
            Button { showPicker = true } label: {
                optionCard(
                    icon: "folder.fill", iconColor: Color(hex: "6E6BFF"),
                    title: "Import from Files",
                    subtitle: diskName.isEmpty ? "Accepts .img and .qcow2" : diskName,
                    subtitleColor: diskName.isEmpty ? Color(hex: "505070") : Color(hex: "6E6BFF"),
                    trailing: diskName.isEmpty
                        ? AnyView(Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "3A3A60")))
                        : AnyView(Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(Color(red: 0, green: 0.9, blue: 0.46)))
                )
            }.buttonStyle(.plain)

            // Download card
            VStack(spacing: 0) {
                optionCard(
                    icon: isDownloading ? "stop.circle.fill" : "arrow.down.circle.fill",
                    iconColor: Color(hex: "CC47A0"),
                    title: "Download Void Linux ARM64",
                    subtitle: isDownloading ? "\(Int(dlProgress * 100))% downloaded"
                             : (diskPath.contains("void-linux") ? "Downloaded ✓" : "~1.2 GB"),
                    subtitleColor: diskPath.contains("void-linux") ? Color(red: 0, green: 0.9, blue: 0.46) : Color(hex: "505070"),
                    trailing: AnyView(EmptyView())
                )
                .onTapGesture { startFakeDownload() }

                if isDownloading {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: "2A2A44")).frame(height: 4)
                            Capsule().fill(Color(hex: "CC47A0"))
                                .frame(width: g.size.width * dlProgress, height: 4)
                                .animation(.linear(duration: 0.3), value: dlProgress)
                        }
                    }
                    .frame(height: 4).padding(.horizontal, 18).padding(.bottom, 14)
                }
            }.glassCard()
        }
    }

    private func optionCard(icon: String, iconColor: Color, title: String, subtitle: String,
                            subtitleColor: Color, trailing: AnyView) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1A1A2E")).frame(width: 52, height: 52)
                Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 13)).foregroundColor(subtitleColor).lineLimit(1)
            }
            Spacer()
            trailing
        }.padding(16)
    }

    private func startFakeDownload() {
        guard !isDownloading && !diskPath.contains("void-linux") else { return }
        isDownloading = true; dlProgress = 0
        // Simulate 3-second download with timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { t in
            dlProgress += 0.025
            if dlProgress >= 1.0 {
                dlProgress = 1.0; t.invalidate(); isDownloading = false
                diskPath = "void-linux-arm64.img"; diskName = "void-linux-arm64.img"
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: Step 2 — Configure
    private var step2: some View {
        VStack(spacing: 14) {
            // Name
            settingSection(header: "VM Name") {
                TextField("VM Name", text: $vmName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(16)
            }

            // RAM stepper
            settingSection(header: "Memory") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
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
                            stepperBtn(icon: "minus", action: { if ramGB > 1.0 { ramGB = (ramGB - 0.1).rounded1dp } })
                            Text(String(format: "%.1f", ramGB))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white).frame(width: 48).multilineTextAlignment(.center)
                            stepperBtn(icon: "plus", action: { if ramGB < 6.0 { ramGB = (ramGB + 0.1).rounded1dp } })
                        }
                        .background(Color(hex: "1A1A2E")).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2A2A44"), lineWidth: 1))
                    }
                }
                .animation(.spring(response: 0.3), value: ramGB > 5.0)
            }

            // Storage
            settingSection(header: "Storage") {
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

            // CPU
            settingSection(header: "CPU Cores") {
                HStack(spacing: 10) {
                    ForEach([1, 2, 4], id: \.self) { n in
                        Button { cpuCores = n } label: {
                            VStack(spacing: 3) {
                                Text("\(n)").font(.system(size: 22, weight: .bold, design: .rounded))
                                Text(n == 1 ? "core" : "cores").font(.system(size: 11, weight: .medium))
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

            // Network
            settingSection(header: "Network") {
                Toggle(isOn: $netEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "network").foregroundColor(Color(hex: "6E6BFF"))
                        Text("Virtual Network Interface").font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                    }
                }.tint(Color(hex: "6E6BFF"))
            }
        }
    }

    private func stepperBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(Color(hex: "6E6BFF"))
                .frame(width: 40, height: 40)
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingSection<C: View>(header: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header.uppercased())
                .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "505070")).tracking(1)
                .padding(.horizontal, 4)
            content().padding(16).glassCard()
        }
    }

    // MARK: Step 3 — Summary
    private var step3: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                summaryRow(label: "Name",    value: vmName)
                Divider().background(Color(hex: "2A2A44"))
                summaryRow(label: "Disk",    value: diskName)
                Divider().background(Color(hex: "2A2A44"))
                summaryRow(label: "RAM",     value: String(format: "%.1f GB", ramGB))
                Divider().background(Color(hex: "2A2A44"))
                summaryRow(label: "Storage", value: "\(Int(storageGB)) GB")
                Divider().background(Color(hex: "2A2A44"))
                summaryRow(label: "CPU",     value: "\(cpuCores) \(cpuCores == 1 ? "core" : "cores")")
                Divider().background(Color(hex: "2A2A44"))
                summaryRow(label: "Network", value: netEnabled ? "Enabled" : "Disabled")
            }.glassCard()
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "808090"))
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
        }.padding(.horizontal, 18).padding(.vertical, 14)
    }

    // MARK: Bottom button
    private var bottomButton: some View {
        Button(action: advance) {
            Text(step < 3 ? "Next" : "Create VM")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(
                    Group {
                        if (step == 1 && !canNext1) {
                            AnyView(Color(hex: "1A1A2E"))
                        } else {
                            AnyView(LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF")],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                )
                .foregroundColor(step == 1 && !canNext1 ? Color(hex: "505070") : .white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (step == 1 && !canNext1) ? .clear : Color(hex: "4A47CC").opacity(0.45),
                        radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(step == 1 && !canNext1)
        .animation(.spring(response: 0.3), value: canNext1)
    }

    private func advance() {
        if step < 3 {
            withAnimation(.spring(response: 0.4)) { step += 1 }
        } else {
            let cfg = VMConfig(id: UUID(), name: vmName, diskImagePath: diskPath,
                               ramGB: ramGB, storageGB: Int(storageGB),
                               cpuCores: cpuCores, networkEnabled: netEnabled, status: "stopped")
            store.add(cfg)
            dismiss()
        }
    }
}

// MARK: - Double rounding helper
private extension Double {
    var rounded1dp: Double { (self * 10).rounded() / 10 }
}
