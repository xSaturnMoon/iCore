import SwiftUI

struct ConsoleView: View {
    @ObservedObject var manager: VMManager
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true
    @State private var cursorOn   = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                toolbar
                Divider().background(Color(white: 0.1))
                outputPane
                Divider().background(Color(white: 0.1))
                statusBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { t in
                if manager.state == .stopped { t.invalidate() }
                cursorOn.toggle()
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Button { manager.pauseVM(); dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                    Text("Back").font(.system(size: 15))
                }.foregroundColor(Color(hex: "0A84FF"))
            }.buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "FF5F57")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "FEBC2E")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "28C840")).frame(width: 10, height: 10)
            }
            Spacer()
            Button { autoScroll.toggle() } label: {
                Image(systemName: autoScroll ? "arrow.down.to.line" : "pause")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.3))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color(white: 0.04))
    }

    private var outputPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("iCore  —  ARM64 Guest Console\n")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.2))
                    Text(manager.consoleOutput.isEmpty ? "Waiting for output…" : manager.consoleOutput)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(white: 0.85))
                    Text(cursorOn ? "▌" : " ")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                        .animation(.none, value: cursorOn)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(Color.black)
            .onChange(of: manager.consoleOutput) { _, _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(manager.state.color).frame(width: 6, height: 6)
            Text(manager.state.label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.3))
            Spacer()
            Text("\(manager.consoleOutput.count) chars")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.04))
    }
}
