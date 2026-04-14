import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(DataService.self) var dataService

    init() {
        Self.configureTabBarAppearance()
    }

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
        .tint(Self.activeSwiftUIColor)
    }

    // MARK: - Tab bar styling
    // Flat dark bar, subtle 1px top separator, near-white active items,
    // muted gray inactive items, no blur/shadow. Applied globally via
    // UITabBarAppearance — there's only one TabView in the app.

    private static let barBackground = UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1E / 255, alpha: 1)
    private static let barSeparator = UIColor.white.withAlphaComponent(0.08)
    private static let inactiveColor = UIColor(red: 0x6B / 255, green: 0x6B / 255, blue: 0x6F / 255, alpha: 1)
    private static let activeColor = UIColor(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xE8 / 255, alpha: 1)
    private static let activeSwiftUIColor = Color(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xE8 / 255)

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = barBackground
        appearance.backgroundEffect = nil
        // `shadowColor` here is actually the bar's top separator line, not a drop shadow.
        appearance.shadowColor = barSeparator

        let item = UITabBarItemAppearance()
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .regular)

        item.normal.iconColor = inactiveColor
        item.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor,
            .font: labelFont,
        ]

        item.selected.iconColor = activeColor
        item.selected.titleTextAttributes = [
            .foregroundColor: activeColor,
            .font: labelFont,
        ]

        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
