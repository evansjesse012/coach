import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = "home"
    @Environment(DataService.self) var dataService

    var body: some View {
        TabView(selection: $selectedTab) {
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
                    Label("Log", systemImage: "list.clipboard.fill")
                }
                .tag("log")

            ChatTab()
                .tabItem {
                    Label("Coach", systemImage: "message.fill")
                }
                .tag("coach")
        }
        .tint(CoachColors.accent)
    }
}
