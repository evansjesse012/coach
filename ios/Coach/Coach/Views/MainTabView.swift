import SwiftUI

/// Root tab container. Hosts five tabs (Today · Goals · Plan · Log · Stats)
/// rendered in a ZStack so each keeps its own NavigationStack state across
/// tab switches. A custom floating `TabBar` sits on top. The Coach chat
/// reachable from a floating action button (FAB), which also auto-presents
/// whenever any caller sets `data.pendingChatPrompt`.
struct MainTabView: View {
    @Environment(DataService.self) private var data

    @State private var showActiveWorkoutLogger = false
    @State private var showCoachChat = false

    private static let validTabs: Set<String> = ["today", "goals", "plan", "log", "stats"]

    var body: some View {
        @Bindable var data = data

        ZStack(alignment: .bottom) {
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

            // Floating chat FAB (bottom-right, above the tab bar).
            VStack(spacing: 0) {
                Spacer()
                HStack {
                    Spacer()
                    FAB(icon: "bubble.left.fill") {
                        showCoachChat = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 92)
                }
            }
            .allowsHitTesting(true)

            // Bottom floating stack: active-workout pill (if any) + tab bar.
            VStack(spacing: 8) {
                if data.activeStrengthSession != nil {
                    MiniActiveWorkoutBar {
                        showActiveWorkoutLogger = true
                    }
                    .padding(.horizontal, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                TabBar(items: tabItems, selection: $data.selectedTab)
            }
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

    private func normalizeSelectedTab() {
        if data.selectedTab == "coach" {
            data.selectedTab = "today"
            showCoachChat = true
            return
        }
        if data.selectedTab == "analytics" { data.selectedTab = "stats"; return }
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
