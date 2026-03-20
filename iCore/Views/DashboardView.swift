import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: VMManager
    @State private var showConsole = false
    @State private var showSettings = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "0A0A0F"), Color(hex: "12121E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    headerSection
                    statusCard
                    resourceBars
                    Spacer()
                    actionButtons
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showConsole) {
                ConsoleView()
                    .environmentObject(vm)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(vm)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("iCore")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("iPad Virtualization")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "888AAA"))
            }
            Spacer()
            // Status indicator dot
            Circle()
                .fill(vm.state.color)
                .frame(width: 14, height: 14)
                .shadow(color: vm.state.color.opacity(0.8), radius: 6)
                .animation(.easeInOut(duration: 0.4), value: vm.state)
        }
    }

    // MARK: - Status Card
    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: vm.state.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(vm.state.color)
                .frame(width: 52, height: 52)
                .background(vm.state.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .animation(.spring(), value: vm.state)

            VStack(alignment: .leading, spacing: 4) {
                Text("Virtual Machine")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "888AAA"))
                Text(vm.state.label)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .animation(.none, value: vm.state.label)
            }
            Spacer()

            if vm.state == .running {
                Button {
                    showConsole = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                        Text("Console")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "2A2A3E"))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color(hex: "16162A"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "2A2A3E"), lineWidth: 1)
        )
    }

    // MARK: - Resource Bars
    private var resourceBars: some View {
        VStack(spacing: 16) {
            resourceBar(
                label: "RAM",
                icon: "memorychip",
                value: vm.ramAllocatedGB,
                max: 8.0,
                color: Color(hex: "6E6AFF"),
                unit: "GB"
            )
            resourceBar(
                label: "Storage",
                icon: "internaldrive",
                value: vm.diskUsedGB,
                max: vm.storageAllocatedGB,
                color: Color(hex: "FF6A88"),
                unit: "GB"
            )
        }
        .padding(20)
        .background(Color(hex: "16162A"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "2A2A3E"), lineWidth: 1)
        )
    }

    private func resourceBar(
        label: String,
        icon: String,
        value: Double,
        max: Double,
        color: Color,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "888AAA"))
                Spacer()
                Text("\(value, specifier: "%.0f") / \(max, specifier: "%.0f") \(unit)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "2A2A3E"))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max > 0 ? geo.size.width * CGFloat(value / max) : 0, height: 8)
                        .animation(.spring(response: 0.5), value: value)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 14) {
            if vm.state == .stopped || vm.state == .paused {
                Button {
                    vm.startVM()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showConsole = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("START")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "5A56FF"), Color(hex: "7B78FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "5A56FF").opacity(0.5), radius: 12, y: 6)
                }
            } else if vm.state == .running || vm.state == .booting {
                Button {
                    vm.stopVM()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                        Text("STOP")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(hex: "FF4D6A"))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "FF4D6A").opacity(0.4), radius: 12, y: 6)
                }
            }

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                    Text("SETTINGS")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "1E1E30"))
                .foregroundColor(Color(hex: "AAAACC"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "2A2A3E"), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
