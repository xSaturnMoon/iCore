import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: VMManager
    @State private var showConsole = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D0D1A"), Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                headerSection
                statusCard
                resourceCards
                Spacer()
                actionButtons
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConsole) {
            ConsoleView()
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "6C63FF"), Color(hex: "3F8EFC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("iCore")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("iPad Virtualization Engine")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "8B8BA7"))
        }
    }

    // MARK: - Status Card
    private var statusCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(vm.state.color)
                .frame(width: 14, height: 14)
                .shadow(color: vm.state.color.opacity(0.6), radius: 8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: vm.state)

            Text(vm.state.label)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(vm.state.color)

            Spacer()

            Image(systemName: vm.state.icon)
                .font(.system(size: 24))
                .foregroundColor(vm.state.color)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(vm.state.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Resource Cards
    private var resourceCards: some View {
        HStack(spacing: 20) {
            ResourceBar(
                title: "RAM",
                icon: "memorychip",
                used: vm.ramAllocatedGB,
                total: 8.0,
                unit: "GB",
                accentColor: Color(hex: "6C63FF")
            )
            ResourceBar(
                title: "Storage",
                icon: "internaldrive",
                used: vm.diskUsedGB,
                total: vm.storageAllocatedGB,
                unit: "GB",
                accentColor: Color(hex: "3F8EFC")
            )
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                if vm.state == .stopped {
                    vm.startVM()
                }
                showConsole = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: vm.state == .stopped ? "play.fill" : "terminal")
                    Text(vm.state == .stopped ? "START" : "CONSOLE")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: 400)
                .padding(.vertical, 18)
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

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                    Text("SETTINGS")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: 400)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08))
                .foregroundColor(Color(hex: "8B8BA7"))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Resource Bar Component
struct ResourceBar: View {
    let title: String
    let icon: String
    let used: Double
    let total: Double
    let unit: String
    let accentColor: Color

    private var fraction: Double { min(used / total, 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1f / %.0f %@", used, total, unit))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "8B8BA7"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.6), value: fraction)
                }
            }
            .frame(height: 10)
        }
        .padding(20)
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

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
