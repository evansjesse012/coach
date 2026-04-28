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
    /// True when the persistent CoachBar is rendering its expanded
    /// in-place card (full message visible, up to 300pt tall). Auto-set
    /// when a new assistant message arrives so the athlete reads it
    /// without leaving the current tab. Tap-outside collapses; tap-bar
    /// opens chat.
    @State private var coachBarExpanded = false

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

            // Tap-catcher behind the CoachBar when it's expanded. Sits
            // ABOVE tab content (so taps anywhere on the screen
            // collapse the bar) but BELOW the bar itself in z-order
            // (so taps on the bar still open chat). Transparent — no
            // dim, just a hit-test surface.
            if coachBarExpanded {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coachBarExpanded = false
                        data.markChatAsSeen()
                    }
                    .transition(.opacity)
            }
        }
        // Pinned above the anchored tab bar: the active-workout pill (when
        // present) sits above the persistent CoachBar. Both align to the
        // bottom of the content area, which — thanks to safeAreaInset
        // below — ends at the tab bar top edge.
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if data.activeStrengthSession != nil {
                    MiniActiveWorkoutBar { showActiveWorkoutLogger = true }
                        .padding(.horizontal, 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                CoachBar(
                    preview: coachBarPreview,
                    fullText: coachBarFullText,
                    timestamp: coachBarTimestamp,
                    isUnread: data.hasUnreadCoachMessage,
                    isExpanded: coachBarExpanded,
                    onTap: {
                        coachBarExpanded = false
                        showCoachChat = true
                    },
                    onMic: {
                        coachBarExpanded = false
                        showCoachChat = true
                    } // voice mode falls back to chat
                )
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
        .animation(.spring(duration: 0.3), value: coachBarExpanded)
        // Anchored tab bar: content sits above the safe area; its `surface1`
        // background extends into the home-indicator region so the bar
        // appears to reach the device's bottom edge.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(
                items: tabItems,
                selection: $data.selectedTab,
                onReselect: { tappedId in
                    // Each tab's NavigationStack listens for its own id and
                    // pops to root — matches native TabView reselect behavior.
                    NotificationCenter.default.post(name: .popTabToRoot, object: tappedId)
                }
            )
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
        .onChange(of: data.shouldOpenChat) { _, open in
            // Flows like the post-status sheet set this flag after
            // posting a user message to the coach thread. Open the chat
            // so the athlete sees their own message + the agent's reply
            // as it streams in, then reset the flag so the next toggle
            // re-fires.
            if open {
                showCoachChat = true
                data.shouldOpenChat = false
            }
        }
        .onChange(of: showCoachChat) { _, shown in
            if shown {
                // Opening the chat clears the unread badge — every existing
                // assistant message is now considered seen.
                data.markChatAsSeen()
                // Also collapse the bar — chat is the canonical surface now.
                coachBarExpanded = false
            } else {
                // Chat dismissed — clear any pending prompt so subsequent
                // sets re-trigger the sheet.
                data.pendingChatPrompt = nil
            }
        }
        .onChange(of: data.hasUnreadCoachMessage) { _, isUnread in
            // Auto-expand the bar when a new assistant message lands so
            // the athlete reads the full text in-place. Collapsing back
            // to the resting pill is athlete-driven (tap-outside or
            // tap-bar-to-open-chat).
            if isUnread {
                coachBarExpanded = true
            } else {
                coachBarExpanded = false
            }
        }
    }

    // MARK: - CoachBar bindings

    /// Single-line preview of the latest assistant message, with markdown
    /// stripped. Empty when no messages exist — the CoachBar falls back
    /// to its `"Talk with coach"` placeholder in that case.
    private var coachBarPreview: String {
        guard let msg = data.latestAssistantMessage else { return "" }
        return msg.content.chatPreview()
    }

    /// Full text of the latest assistant message — used by the bar's
    /// expanded card. nil when there's no message to render.
    private var coachBarFullText: String? {
        guard let msg = data.latestAssistantMessage else { return nil }
        // Strip the suggested-replies marker but keep markdown formatting
        // so the expanded card can render bold / italic / etc. properly.
        let pattern = #"<!--sr:.*?-->"#
        return msg.content
            .replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Timestamp shown in the unread state. Hidden in resting.
    private var coachBarTimestamp: String? {
        guard data.hasUnreadCoachMessage,
              let msg = data.latestAssistantMessage else { return nil }
        return formatCoachBarTimestamp(msg.createdAt)
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
