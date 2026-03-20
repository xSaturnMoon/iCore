import SwiftUI

struct VMListView: View {
    @EnvironmentObject var store: VMStore
    @State private var showAdd = false
    @State private var selectedConfig: VMConfig? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0F").ignoresSafeArea()
                RadialGradient(colors: [Color(hex: "1A1A3A").opacity(0.5), .clear],
                               center: .top, startRadius: 0, endRadius: 420).ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    if store.vms.isEmpty { emptyState } else { list }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdd) {
                AddVMView().environmentObject(store)
            }
            .navigationDestination(item: $selectedConfig) { cfg in
                VMDetailView(config: cfg,
                             manager: store.ensureManager(for: cfg))
                    .environmentObject(store)
            }
        }
    }

    // MARK: Header
    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color(hex: "4A47CC"), Color(hex: "7B78FF")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "cpu")
                        .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                }
                Text("iCore")
                    .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            Spacer()
            Button { showAdd = true } label: {
                ZStack {
                    Circle().fill(Color(hex: "1A1A2E")).frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color(hex: "3A3A60"), lineWidth: 1))
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "6E6BFF"))
                }
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "1A1A2E")).frame(width: 88, height: 88)
                Image(systemName: "cpu")
                    .font(.system(size: 34, weight: .light)).foregroundColor(Color(hex: "4A47CC"))
            }
            Text("No VMs yet").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundColor(.white)
            Text("Tap + to create one.").font(.system(size: 15)).foregroundColor(Color(hex: "505070"))
            Spacer()
        }
    }

    // MARK: List
    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(store.vms) { cfg in
                    VMCardRow(config: cfg)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedConfig = cfg }
                        .contextMenu {
                            Button(role: .destructive) { store.delete(id: cfg.id) }
                                label: { Label("Delete VM", systemImage: "trash") }
                        }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 40)
        }
    }
}

// MARK: - VM Row Card
struct VMCardRow: View {
    let config: VMConfig
    private var dotColor: Color {
        switch config.status {
        case "running": return Color(red: 0, green: 0.9, blue: 0.46)
        case "booting", "paused": return Color(red: 1, green: 0.7, blue: 0)
        default: return Color(red: 1, green: 0.3, blue: 0.42)
        }
    }
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1A1A2E")).frame(width: 50, height: 50)
                Image(systemName: "cube").font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "6E6BFF"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(String(format: "%.1f GB RAM · %d GB", config.ramGB, config.storageGB))
                    .font(.system(size: 13)).foregroundColor(Color(hex: "606080"))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 5) {
                    Circle().fill(dotColor).frame(width: 8, height: 8)
                    Text(config.status.uppercased())
                        .font(.system(size: 10, weight: .bold)).foregroundColor(dotColor)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "3A3A60"))
            }
        }
        .padding(16).glassCard()
    }
}
