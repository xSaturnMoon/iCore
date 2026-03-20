import SwiftUI

struct VMDetailView: View {
    @EnvironmentObject var store: VMStore
    let config: VMConfig
    @ObservedObject var manager: VMManager
    @Environment(\.dismiss) private var dismiss
    @State private var showConsole  = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(hex: "0A0A0F").ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "1A1A3A").opacity(0.6), .clear],
                           center: .top, startRadius: 0, endRadius: 500).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    navBar
                    statusCard
                    resourceBars
                    Spacer(minLength: 20)
                    actionButtons
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 44)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConsole) {
            ConsoleView(manager: manager)
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(config: config, manager: manager).environmentObject(store)
        }
    }

    // MARK: Nav bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("iCore").font(.system(size: 15, weight: .medium))
                }.foregroundColor(Color(hex: "6E6BFF"))
            }.buttonStyle(.plain)
            Spacer()
            Text(config.name).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            Spacer()
            statusDot
        }
    }

    private var statusDot: some View {
        ZStack {
            if manager.state == .running {
                Circle().fill(manager.state.color.opacity(0.22)).frame(width: 28, height: 28)
                    .pulsingGlow(color: manager.state.color)
            }
            Circle().fill(manager.state.color).frame(width: 12, height: 12)
                .shadow(color: manager.state.color.opacity(0.8), radius: 4)
        }.animation(.spring(response: 0.4), value: manager.state)
    }

    // MARK: Status card
    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(manager.state.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: manager.state.icon)
                    .font(.system(size: 24, weight: .semibold)).foregroundColor(manager.state.color)
            }.animation(.spring(), value: manager.state)
            VStack(alignment: .leading, spacing: 3) {
                Text("Virtual Machine").font(.system(size: 12)).foregroundColor(Color(hex: "606080"))
                Text(manager.state.label)
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            Spacer()
            if manager.state == .running {
                Button { showConsole = true } label: {
                    Label("Console", systemImage: "terminal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "8A88FF"))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(hex: "1E1E38")).clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "3A3A60"), lineWidth: 1))
                }.buttonStyle(.plain).transition(.scale.combined(with: .opacity))
            }
        }
        .padding(18).glassCard()
    }

    // MARK: Resource bars
    private var resourceBars: some View {
        VStack(spacing: 14) {
            bar(label: "RAM", icon: "memorychip",
                value: manager.ramGB, max: 8,
                colors: [Color(hex: "4A47CC"), Color(hex: "8A78FF")],
                text: String(format: "%.1f / 8.0 GB", manager.ramGB))
            Divider().background(Color(hex: "2A2A44"))
            bar(label: "Storage", icon: "internaldrive",
                value: Double(manager.storageGB), max: 128,
                colors: [Color(hex: "CC47A0"), Color(hex: "FF78D8")],
                text: "\(manager.storageGB) / 128 GB")
        }
        .padding(18).glassCard()
    }

    private func bar(label: String, icon: String, value: Double, max: Double,
                     colors: [Color], text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.last ?? .white)
                Text(label).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "A0A0C0"))
                Spacer()
                Text(text).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "1E1E38")).frame(height: 7)
                    Capsule()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max > 0 ? g.size.width * CGFloat(min(value/max, 1)) : 0, height: 7)
                        .animation(.spring(response: 0.6), value: value)
                }
            }.frame(height: 7)
        }
    }

    // MARK: Action buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if manager.state == .stopped || manager.state == .paused {
                Button {
                    manager.startVM()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showConsole = true }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                        Text("START").font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "6E6BFF")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "5A56FF").opacity(0.5), radius: 16, y: 6)
                }.buttonStyle(.plain)
            } else {
                Button { manager.stopVM() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill").font(.system(size: 16, weight: .bold))
                        Text("STOP").font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(hex: "CC2244")).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "CC2244").opacity(0.4), radius: 12, y: 5)
                }.buttonStyle(.plain)
            }
            Button { showSettings = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill").font(.system(size: 14, weight: .semibold))
                    Text("SETTINGS").font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(.ultraThinMaterial).foregroundColor(Color(hex: "A0A0C0"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "2A2A44"), lineWidth: 1))
            }.buttonStyle(.plain)
        }.animation(.spring(response: 0.35), value: manager.state)
    }
}
