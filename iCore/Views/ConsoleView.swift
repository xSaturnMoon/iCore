import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var vm: VMManager
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true
    @State private var cursorOn  = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                consoleOutput
                statusBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Blink cursor every 0.5 s
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
                if vm.state == .stopped { t.invalidate() }
                cursorOn.toggle()
            }
        }
    }

    // MARK: Toolbar
    private var toolbar: some View {
        HStack {
            Button {
                vm.pauseVM()
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color(hex: "6E6BFF"))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(Color(hex: "FF5F57")).frame(width: 11, height: 11)
                Circle().fill(Color(hex: "FEBC2E")).frame(width: 11, height: 11)
                Circle().fill(Color(hex: "28C840")).frame(width: 11, height: 11)
            }

            Spacer()

            Button {
                autoScroll.toggle()
            } label: {
                Image(systemName: autoScroll ? "arrow.down.to.line" : "pause")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "6E6BFF"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(hex: "0D0D0D"))
        .overlay(Rectangle().fill(Color(hex: "1A1A1A")).frame(height: 1), alignment: .bottom)
    }

    // MARK: Console output
    private var consoleOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Prompt header
                    Text("iCore Terminal — ARM64 Guest Console\n")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "444466"))

                    // Output text
                    let output = vm.consoleOutput.isEmpty
                        ? "Waiting for VM output…"
                        : vm.consoleOutput
                    Text(output)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "00DD66"))

                    // Blinking cursor
                    Text(cursorOn ? "█" : " ")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "00DD66"))
                        .animation(.none, value: cursorOn)

                    Color.clear.frame(height: 1).id("bottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(Color.black)
            .onChange(of: vm.consoleOutput) { _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: Status bar
    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.state.color)
                .frame(width: 7, height: 7)
            Text(vm.state.label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "505070"))
            Spacer()
            Text("\(vm.consoleOutput.count) chars")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(hex: "303050"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "0D0D0D"))
        .overlay(Rectangle().fill(Color(hex: "1A1A1A")).frame(height: 1), alignment: .top)
    }
}
