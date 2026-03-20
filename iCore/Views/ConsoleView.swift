import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var vm: VMManager
    @Environment(\.dismiss) private var dismiss
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var autoScroll = true

    var body: some View {
        ZStack {
            Color(hex: "080810").ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button {
                        vm.pauseVM()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "6E6AFF"))
                    }

                    Spacer()

                    Text("Serial Console")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        autoScroll.toggle()
                    } label: {
                        Image(systemName: autoScroll ? "arrow.down.to.line" : "pause")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "6E6AFF"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(hex: "0E0E1A"))
                .overlay(
                    Rectangle()
                        .fill(Color(hex: "2A2A3E"))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Console output
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Text(vm.consoleOutput.isEmpty
                                 ? "[iCore] Waiting for output…\n"
                                 : vm.consoleOutput)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(hex: "00E676"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .id("bottom")
                        }
                    }
                    .background(Color(hex: "080810"))
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: vm.consoleOutput) { _ in
                        if autoScroll {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }

                // Status bar
                HStack {
                    Circle()
                        .fill(vm.state.color)
                        .frame(width: 8, height: 8)
                    Text(vm.state.label)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "888AAA"))
                    Spacer()
                    Text("\(vm.consoleOutput.count) chars")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "555570"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "0E0E1A"))
            }
        }
        .navigationBarHidden(true)
    }
}
