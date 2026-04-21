import SwiftUI

/// The primary tab — wraps ChatTab in a NavigationStack with a pinned
/// context bar showing race/plan status and a settings gear.
struct CoachTab: View {
    @Environment(DataService.self) var data
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if data.trainingPlan != nil {
                    contextBar
                    Divider()
                }
                ChatTab()
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
        }
        .task {
            await data.ensurePlanPreGenerated()
        }
    }

    // MARK: - Pinned Context Bar

    /// Compact single-line bar showing race name, weeks out, current
    /// week, and phase. Tappable to jump to Plan tab.
    @ViewBuilder
    private var contextBar: some View {
        if let plan = data.trainingPlan {
            Button {
                data.selectedTab = "plan"
            } label: {
                HStack(spacing: 6) {
                    if let name = plan.raceName {
                        Text(name)
                            .font(CoachFonts.ui(11, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("\u{00B7}")
                            .foregroundStyle(.secondary)
                    }

                    Text("Week \(plan.currentWeek)/\(plan.totalWeeks)")
                        .font(CoachFonts.mono(11, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
                        Text("\u{00B7}")
                            .foregroundStyle(.secondary)
                        Text(phase.name)
                            .font(CoachFonts.ui(11, weight: .medium))
                            .foregroundStyle(CoachColors.green)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(CoachColors.green.opacity(0.05))
            }
            .buttonStyle(.plain)
        }
    }
}
