import SwiftUI

/// Root tab container. Hosts five tabs (Today · Goals · Plan · Log · Stats)
/// rendered in a ZStack so each keeps its own NavigationStack state across
/// tab switches. An anchored `TabBar` is mounted via `.safeAreaInset(edge: .bottom)`
/// so each tab's scroll content ends naturally above the bar without
/// per-screen bottom padding. A Coach chat FAB hovers 16pt above the tab
/// bar's top edge; the `MiniActiveWorkoutBar` pill floats just above the
/// tab bar when a strength workout is live.
struct MainTabView: View {
    @Environment(DataService.self) private var data

    @State private var showActiveWorkoutLogger = false
    @State private var showCoachChat = false

    private static let validTabs: Set<String> = ["today", "goals", "plan", "log", "stats"]

    var body: some View {
        @Bindable var data = data

        ZStack {
            Theme.bg.ignoresSafeArea()

            // Tab content — all five tabs stay in the tree to preserve
            // per-tab NavigationStack state across switches.
            Group {
                tabContent(id: "today") { HomeTab() }
                tabContent(id: "goals") { GoalsTab() }
                tabContent(id: "plan")  { PlanTab() }
                tabContent(id: "log")   { LogTab() }
                tabContent(id: "stats") { AnalyticsTab() }
            }
        }
        // Pinned above the anchored tab bar: the active-workout pill (when
        // present) and the chat FAB. Both align to the bottom of the content
        // area, which — thanks to safeAreaInset below — ends at the tab bar
        // top edge.
        .overlay(alignment: .bottom) {
            if data.activeStrengthSession != nil {
                MiniActiveWorkoutBar { showActiveWorkoutLogger = true }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FAB(icon: "bubble.left.fill") {
                showCoachChat = true
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        // Anchored tab bar: content sits above the safe area; its `surface1`
        // background extends into the home-indicator region so the bar
        // appears to reach the device's bottom edge.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(items: tabItems, selection: $data.selectedTab)
                .background(Theme.surface1.ignoresSafeArea(edges: .bottom))
        }
        .animation(.easeInOut(duration: 0.25), value: data.activeStrengthSession != nil)
        .fullScreenCover(isPresented: $showActiveWorkoutLogger) {
            NavigationStack { WorkoutLoggingView() }
        }
        .sheet(isPresented: $showCoachChat) {
            NavigationStack { CoachTab() }
        }
        .onAppear { normalizeSelectedTab() }
        .onChange(of: data.selectedTab) { _, new in
            handleTabChange(to: new)
        }
        .onChange(of: data.pendingChatPrompt) { _, new in
            if let new, !new.isEmpty {
                showCoachChat = true
            }
        }
        .onChange(of: showCoachChat) { _, shown in
            if !shown {
                // Chat dismissed — clear any pending prompt so subsequent
                // sets re-trigger the sheet.
                data.pendingChatPrompt = nil
            }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent<V: View>(id: String, @ViewBuilder view: () -> V) -> some View {
        view()
            .opacity(data.selectedTab == id ? 1 : 0)
            .allowsHitTesting(data.selectedTab == id)
    }

    private var tabItems: [TabBar.Item] {
        [
            .init(id: "today", icon: "house",                label: "Today"),
            .init(id: "goals", icon: "target",               label: "Goals"),
            .init(id: "plan",  icon: "calendar",             label: "Plan"),
            .init(id: "log",   icon: "list.clipboard.fill",  label: "Log"),
            .init(id: "stats", icon: "chart.xyaxis.line",    label: "Stats"),
        ]
    }

    // MARK: - Selected-tab normalization
    //
    // Legacy callers across the codebase still set `data.selectedTab` to
    // "coach" (opens chat) or "analytics" (renamed to "stats"). Intercept
    // those so existing call sites keep working without edits.

    /// Called once on first appear. Resets any stale/legacy selectedTab value
    /// (including the old "coach" default) to "today" silently. This must NOT
    /// open the coach chat sheet — that would pop on every app launch because
    /// DataService still initializes selectedTab to "coach" for backward compat.
    private func normalizeSelectedTab() {
        if !Self.validTabs.contains(data.selectedTab) {
            data.selectedTab = "today"
        }
    }

    private func handleTabChange(to new: String) {
        if new == "coach" {
            showCoachChat = true
            data.selectedTab = "today"
            return
        }
        if new == "analytics" {
            data.selectedTab = "stats"
            return
        }
        if !Self.validTabs.contains(new) {
            data.selectedTab = "today"
        }
    }
}

// MARK: - Mini Active Workout Bar

/// Tappable pill shown just above the tab bar whenever a strength workout
/// is live, so the athlete can resume from any tab.
private struct MiniActiveWorkoutBar: View {
    @Environment(DataService.self) private var data
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.accentInk.opacity(0.22))
                        .frame(width: 30, height: 30)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accentInk)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(data.activeStrengthSession?.name ?? "Active workout")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accentInk)
                        .lineLimit(1)
                    if let s = data.activeStrengthSession {
                        Text("\(s.completedSetCount) sets · tap to resume")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Theme.accentInk.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                ElapsedTimeView(startedAt: data.activeWorkoutStartedAt)
                    .foregroundStyle(Theme.accentInk)
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accentInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Theme.accent, Theme.accentDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
