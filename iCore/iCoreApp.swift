import SwiftUI

@main
struct iCoreApp: App {
    @StateObject private var store = VMStore()

    var body: some Scene {
        WindowGroup {
            VMListView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
