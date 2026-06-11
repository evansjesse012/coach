import SwiftUI

/// Root tab container. Hosts the four primary tabs (Today · Week · Plan
/// · More) plus the four More-only destinations (Goals · Log · Stats ·
/// Settings) rendered in a ZStack so each keeps its own NavigationStack
/// state across tab switches. An anchored `BottomNavBar` is mounted via
/// `.safeAreaInset(edge: .bottom)` so each tab's scroll content ends
/// naturally above the bar without per-screen bottom padding.
///
/// The Coach affordance lives inside `BottomNavBar` as a circular icon
/// in its own rounded container, peer to the primary nav. Tapping it
/// opens the existing `CoachTab` chat sheet — the same destination as
/// before; only the entry point chrome changed. The unread badge on
/// the Coach circle preserves the "you have a message" signal that
/// used to render via the wide CoachBar pill.
struct MainTabView: View {
    @Environment(DataService.self) private var data
    @Environment(\.scenePhase) private var scenePhase

    @State private var showActiveWorkoutLogger = false
    @State private var showCoachChat = false
    @State private var showMoreSheet = false
    @State private var showSettings = false

    /// Tabs that the bar can directly select. More-only destinations
    /// (goals / log / stats / settings) are still rendered in the
    /// ZStack — they just have no entry in the nav, so the active
    /// accent doesn't light up while the user is on them.
    private static let validTabs: Set<String> = [
        "today", "week", "plan", "goals", "log", "stats", "settings"
    ]

    var body: some View {
        @Bindable var data = data

        ZStack {
            Theme.bg.ignoresSafeArea()

            // Tab content — all destinations stay in the tree to
            // preserve per-tab NavigationStack state across switches.
            Group {
                tabContent(id: "today") { HomeTab() }
                tabContent(id: "week")  { weekTabContent }
                tabContent(id: "plan")  { PlanTab() }
                tabContent(id: "goals") { GoalsTab() }
                tabContent(id: "log")   { LogTab() }
                tabContent(id: "stats") { AnalyticsTab() }
            }
        }
        // Pinned above the anchored bar: the active-workout pill, when
        // a strength session is live. The wide CoachBar pill that used
        // to live here was replaced by the Coach circle in BottomNavBar.
        .overlay(alignment: .bottom) {
            if data.activeStrengthSession != nil {
                MiniActiveWorkoutBar { showActiveWorkoutLogger = true }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: data.activeStrengthSession != nil)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(
                items: tabItems,
                selection: $data.selectedTab,
                onCoachTap: { showCoachChat = true },
                onMoreTap: { showMoreSheet = true },
                onReselect: { tappedId in
                    // Each tab's NavigationStack listens for its own id
                    // and pops to root — matches native TabView
                    // reselect behavior.
                    NotificationCenter.default.post(name: .popTabToRoot, object: tappedId)
                },
                coachUnread: data.hasUnreadCoachMessage
            )
            .background(Theme.bg.ignoresSafeArea(edges: .bottom))
        }
        .fullScreenCover(isPresented: $showActiveWorkoutLogger) {
            NavigationStack { WorkoutLoggingView() }
        }
        .sheet(isPresented: $showCoachChat) {
            NavigationStack { CoachTab() }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showMoreSheet) {
            MoreSheet { dest in
                switch dest {
                case .goals:    data.selectedTab = "goals"
                case .log:      data.selectedTab = "log"
                case .stats:    data.selectedTab = "stats"
                case .settings: showSettings = true
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .onChange(of: data.shouldOpenChat) { _, open in
            // Flows like the post-status sheet set this flag after
            // posting a user message to the coach thread. Open the
            // chat so the athlete sees their own message + the agent's
            // reply as it streams in, then reset the flag so the next
            // toggle re-fires.
            if open {
                showCoachChat = true
                data.shouldOpenChat = false
            }
        }
        .onChange(of: showCoachChat) { _, shown in
            if shown {
                // Opening the chat clears the unread badge — every
                // existing assistant message is now considered seen.
                data.markChatAsSeen()
            } else {
                // Chat dismissed — clear any pending prompt so
                // subsequent sets re-trigger the sheet.
                data.pendingChatPrompt = nil
            }
        }
        .onAppear {
            Task { await maybePromptWeeklyCheckIn() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-evaluate on foreground in case the athlete crossed
            // the trigger window with the app already running (cold
            // launch is handled by the .onAppear above).
            if phase == .active {
                Task { await maybePromptWeeklyCheckIn() }
            }
        }
    }

    // MARK: - Week tab content

    /// The Week tab roots at the existing `WeekDetailView` for the
    /// plan's current week. Wrapped in its own NavigationStack so the
    /// week selector inside renders correctly and any future pushes
    /// stay scoped to this tab.
    @ViewBuilder
    private var weekTabContent: some View {
        NavigationStack {
            WeekDetailView(initialWeekNum: data.trainingPlan?.currentWeek ?? 1)
        }
    }

    // MARK: - Weekly check-in trigger

    /// Posts the wrap-up opener as a coach-initiated assistant message
    /// when the current time falls in the end-of-week window (last
    /// evening of the athlete's week / first morning of the new one)
    /// AND no completed review exists for the week being wrapped up.
    /// Idempotent within the same window thanks to the UserDefaults
    /// debounce in `WeeklyArtifactsService`.
    private func maybePromptWeeklyCheckIn() async {
        guard WeeklyArtifactsService.shouldPromptCheckIn(
            now: Date(),
            reviews: data.weeklyReviews,
            anchor: data.settings.weekAnchor
        ) != nil else { return }
        await data.postCoachOpener(
            "Hey, let's wrap up the week. How did it feel overall?"
        )
        WeeklyArtifactsService.markPromptedForCheckIn()
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent<V: View>(id: String, @ViewBuilder view: () -> V) -> some View {
        view()
            .opacity(data.selectedTab == id ? 1 : 0)
            .allowsHitTesting(data.selectedTab == id)
    }

    private var tabItems: [BottomNavBar.Item] {
        [
            .init(id: "today", icon: "house",                     label: "Today"),
            .init(id: "week",  icon: "calendar.day.timeline.left", label: "Week"),
            .init(id: "plan",  icon: "calendar",                  label: "Plan"),
            .init(id: "more",  icon: "line.3.horizontal",         label: "More"),
        ]
    }

    // MARK: - Selected-tab normalization
    //
    // Legacy callers across the codebase still set `data.selectedTab`
    // to "coach" (opens chat) or "analytics" (renamed to "stats").
    // Intercept those so existing call sites keep working without
    // edits.

    /// Called once on first appear. Resets any stale/legacy
    /// selectedTab value (including the old "coach" default) to
    /// "today" silently. This must NOT open the coach chat sheet —
    /// that would pop on every app launch because DataService still
    /// initializes selectedTab to "coach" for backward compat.
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

/// Tappable pill shown just above the bottom nav whenever a strength
/// workout is live, so the athlete can resume from any tab.
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
