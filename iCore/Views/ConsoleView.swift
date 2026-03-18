import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var vm: VMManager
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true

    var body: some View {
        ZStack {
            Color(hex: "0A0A14").ignoresSafeArea()

            VStack(spacing: 0) {
                consoleHeader
                Divider().background(Color.white.opacity(0.1))
                consoleBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    vm.pauseVM()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Dashboard")
                    }
                    .foregroundColor(Color(hex: "6C63FF"))
                }
            }
        }
    }

    // MARK: - Header
    private var consoleHeader: some View {
        HStack {
            Circle()
                .fill(vm.state.color)
                .frame(width: 10, height: 10)
                .shadow(color: vm.state.color.opacity(0.5), radius: 6)

            Text(vm.state.label)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(vm.state.color)

            Spacer()

            Text("iCore Console")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Button {
                autoScroll.toggle()
            } label: {
                Image(systemName: autoScroll ? "arrow.down.to.line" : "arrow.down.to.line.compact")
                    .foregroundColor(autoScroll ? Color(hex: "6C63FF") : Color(hex: "8B8BA7"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Console Body
    private var consoleBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(vm.consoleOutput.isEmpty ? "Waiting for VM output..." : vm.consoleOutput)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(vm.consoleOutput.isEmpty ? Color(hex: "8B8BA7") : Color(hex: "00FF88"))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
            }
            .onChange(of: vm.consoleOutput) { _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(hex: "0A0A14"))
    }
}
