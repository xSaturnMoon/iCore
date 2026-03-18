import SwiftUI

@main
struct iCoreApp: App {
    @StateObject private var vmManager = VMManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DashboardView()
            }
            .environmentObject(vmManager)
            .preferredColorScheme(.dark)
        }
    }
}
