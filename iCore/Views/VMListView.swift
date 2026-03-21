import SwiftUI

struct VMListView: View {
    @EnvironmentObject var store: VMStore
    @State private var showAdd = false
    @State private var selectedConfig: VMConfig? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    Divider().background(Color(white: 0.12))
                    if store.vms.isEmpty { emptyState } else { list }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdd) {
                AddVMView().environmentObject(store)
            }
            .navigationDestination(item: $selectedConfig) { cfg in
                VMDetailView(config: cfg, manager: store.ensureManager(for: cfg))
                    .environmentObject(store)
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("iCore")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(white: 0.5))
                    .frame(width: 32, height: 32)
                    .background(Color(white: 0.1))
                    .clipShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Color(white: 0.2))
            Text("No virtual machines")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(white: 0.35))
            Text("Tap + to add one")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.2))
            Spacer()
        }
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(store.vms) { cfg in
                    VMCardRow(config: cfg)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedConfig = cfg }
                        .contextMenu {
                            Button(role: .destructive) { store.delete(id: cfg.id) }
                                label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
            .padding(.bottom, 40)
        }
    }
}

struct VMCardRow: View {
    let config: VMConfig

    private var statusColor: Color {
        switch config.status {
        case "running": return Color(red: 0.19, green: 0.82, blue: 0.35)
        case "booting", "paused": return Color(red: 1, green: 0.84, blue: 0.04)
        default: return Color(white: 0.25)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(white: 0.45))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(config.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(String(format: "%.1f GB RAM  ·  %d GB  ·  %d vCPU",
                            config.ramGB, config.storageGB, config.cpuCores))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white: 0.3))
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.2))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.black)
        .overlay(Rectangle().fill(Color(white: 0.08)).frame(height: 0.5), alignment: .bottom)
    }
}
