import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Hangar", systemImage: "house")
                }

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "list.bullet.rectangle")
                }

            AddEntryHubView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
