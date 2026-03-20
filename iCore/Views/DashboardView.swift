import SwiftUI

// MARK: - Pulsing Glow Modifier
struct PulsingGlow: ViewModifier {
    let color: Color
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(pulsing ? 0.9 : 0.3), radius: pulsing ? 12 : 4)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

extension View {
    func pulsingGlow(color: Color) -> some View {
        modifier(PulsingGlow(color: color))
    }
}

// MARK: - DashboardView
struct DashboardView: View {
    @EnvironmentObject var vm: VMManager
    @State private var showConsole  = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Deep-black base
                Color(hex: "0A0A0F").ignoresSafeArea()

                // Subtle radial accent
                RadialGradient(
                    colors: [Color(hex: "1A1A3A").opacity(0.6), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        statusCard
                        resourceSection
                        Spacer(minLength: 24)
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showConsole) {
                ConsoleView().environmentObject(vm)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView().environmentObject(vm)
            }
        }
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            // Icon + title
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "7B78FF")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "cpu")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCore")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("iPad Virtualization")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "606080"))
                }
            }
            Spacer()
            // Animated status indicator
            statusDot
        }
    }

    private var statusDot: some View {
        ZStack {
            if vm.state == .running {
                Circle()
                    .fill(vm.state.color.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .pulsingGlow(color: vm.state.color)
            }
            Circle()
                .fill(vm.state.color)
                .frame(width: 12, height: 12)
                .shadow(color: vm.state.color.opacity(0.8), radius: 4)
        }
        .animation(.spring(response: 0.4), value: vm.state)
    }

    // MARK: Status Card
    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(vm.state.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: vm.state.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(vm.state.color)
                    .symbolEffect(.variableColor, isActive: vm.state == .booting)
            }
            .animation(.spring(), value: vm.state)

            VStack(alignment: .leading, spacing: 3) {
                Text("Virtual Machine")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "606080"))
                Text(vm.state.label)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()

            if vm.state == .running {
                Button { showConsole = true } label: {
                    Label("Console", systemImage: "terminal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "8A88FF"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(hex: "1E1E38"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "3A3A60"), lineWidth: 1))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: Resource Bars
    private var resourceSection: some View {
        VStack(spacing: 14) {
            resourceBar(
                label: "RAM",
                icon: "memorychip",
                value: vm.ramAllocatedGB,
                max: 8.0,
                colors: [Color(hex: "4A47CC"), Color(hex: "8A78FF")],
                format: { "\(String(format: "%.1f", $0)) / 8.0 GB" }
            )
            Divider().background(Color(hex: "2A2A44"))
            resourceBar(
                label: "Storage",
                icon: "internaldrive",
                value: vm.diskUsedGB,
                max: vm.storageAllocatedGB,
                colors: [Color(hex: "CC47A0"), Color(hex: "FF78D8")],
                format: { "\(String(format: "%.0f", $0)) / \(String(format: "%.0f", vm.storageAllocatedGB)) GB" }
            )
        }
        .padding(18)
        .glassCard()
    }

    private func resourceBar(
        label: String,
        icon: String,
        value: Double,
        max: Double,
        colors: [Color],
        format: (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.last ?? .white)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "A0A0C0"))
                Spacer()
                Text(format(value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "1E1E38"))
                        .frame(height: 7)
                    Capsule()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max > 0 ? geo.size.width * CGFloat(min(value / max, 1)) : 0, height: 7)
                        .animation(.spring(response: 0.6), value: value)
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if vm.state == .stopped || vm.state == .paused {
                Button {
                    vm.startVM()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showConsole = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("START")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF"), Color(hex: "4A3FCC")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "5A56FF").opacity(0.55), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))

            } else {
                Button { vm.stopVM() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("STOP")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "CC2244"))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "CC2244").opacity(0.4), radius: 12, y: 5)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Settings — frosted glass style
            Button { showSettings = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("SETTINGS")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .foregroundColor(Color(hex: "A0A0C0"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "2A2A44"), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.35), value: vm.state)
    }
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(hex: "13132A"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "3A3A60").opacity(0.8), Color(hex: "2A2A44").opacity(0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,
                  red:   Double(r)/255,
                  green: Double(g)/255,
                  blue:  Double(b)/255,
                  opacity: Double(a)/255)
    }
}
