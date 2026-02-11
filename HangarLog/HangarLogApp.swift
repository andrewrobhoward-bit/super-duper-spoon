import SwiftUI
import SwiftData

@main
struct HangarLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Entry.self])
    }
}
