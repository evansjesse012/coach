import SwiftUI

struct MainTabView: View {
    @Environment(DataService.self) var dataService
    @State private var showActiveWorkoutLogger = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var dataService = dataService
        TabView(selection: $dataService.selectedTab) {
            CoachTab()
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag("coach")

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

            AnalyticsTab()
                .tabItem {
                    Label("Analytics", systemImage: "chart.xyaxis.line")
                }
                .tag("analytics")

            LogTab()
                .tabItem {
                    Label("Activities", systemImage: "list.clipboard.fill")
                }
                .tag("log")
        }
        .tint(CoachColors.accent)
        .safeAreaInset(edge: .bottom) {
            // Floating "Workout in progress" pill
            if dataService.activeStrengthSession != nil {
                MiniActiveWorkoutBar {
                    showActiveWorkoutLogger = true
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: dataService.activeStrengthSession != nil)
        .fullScreenCover(isPresented: $showActiveWorkoutLogger) {
            NavigationStack {
                WorkoutLoggingView()
            }
        }
    }
}

// MARK: - Mini Active Workout Bar

/// Tappable pill sitting just above the system tab bar while a strength
/// workout is live, so the athlete can resume from any tab without having
/// to navigate back through the Activities flow.
private struct MiniActiveWorkoutBar: View {
    @Environment(DataService.self) private var data
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 30, height: 30)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(data.activeStrengthSession?.name ?? "Active workout")
                        .font(CoachFonts.ui(12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let s = data.activeStrengthSession {
                        Text("\(s.completedSetCount) sets · tap to resume")
                            .font(CoachFonts.ui(10))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer()
                ElapsedTimeView(startedAt: data.activeWorkoutStartedAt)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [CoachColors.green, CoachColors.green.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: CoachColors.green.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
