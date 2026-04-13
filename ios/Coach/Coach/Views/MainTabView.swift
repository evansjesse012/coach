import SwiftUI

struct MainTabView: View {
    @Environment(DataService.self) var dataService

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
