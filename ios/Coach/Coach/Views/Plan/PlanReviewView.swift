import SwiftUI

struct PlanReviewView: View {
    let plan: TrainingPlan

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                ForEach(plan.phases.sorted(by: { $0.number < $1.number })) { phase in
                    PhaseDetailContent(plan: plan, phase: phase)
                    if phase.number != plan.phases.map(\.number).max() {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Plan Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAN REVIEW")
                .font(CoachFonts.ui(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(plan.raceName ?? "Training Plan")
                .font(CoachFonts.display(22, weight: .bold))
            HStack(spacing: 12) {
                Text("\(plan.totalWeeks) weeks")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
                if let raceDate = plan.raceDate {
                    Text("Race: \(formatDateLong(raceDate))")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(CoachColors.accent)
                }
            }
        }
    }
}
