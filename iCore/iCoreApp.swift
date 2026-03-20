import SwiftUI

@main
struct iCoreApp: App {
    @StateObject private var vm = VMManager()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(vm)
                .preferredColorScheme(.dark)
        }
    }
}
