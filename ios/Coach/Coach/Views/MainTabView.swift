import SwiftUI

struct MainTabView: View {
    @Environment(DataService.self) var dataService

    // Near-white for the active item, dark for the tab bar tint so the
    // Liquid Glass bar reads as part of the dark app surface above it.
    private static let activeColor = Color(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xE8 / 255)
    private static let barTint = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1E / 255)

    var body: some View {
        @Bindable var dataService = dataService
        TabView(selection: $dataService.selectedTab) {
            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag("home")

            GoalsTab()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag("goals")

            PlanTab()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag("plan")

            LogTab()
                .tabItem {
                    Label("Activities", systemImage: "list.clipboard.fill")
                }
                .tag("log")

            ChatTab()
                .tabItem {
                    Label("Coach", systemImage: "message.fill")
                }
                .tag("coach")
        }
        .tint(Self.activeColor)
        .toolbarBackground(Self.barTint, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
