import SwiftUI
import Charts

struct AnalyticsTab: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    private var fitness: [TrainingStressCalculator.FitnessDataPoint] {
        TrainingStressCalculator.fitnessTimeSeries(cardio: data.cardio, strength: data.strength)
    }

    private var weeklyVolume: [TrainingStressCalculator.WeeklyVolume] {
        TrainingStressCalculator.weeklyVolume(cardio: data.cardio, strength: data.strength)
    }

    private var weeklyTSS: [TrainingStressCalculator.WeeklyTSS] {
        TrainingStressCalculator.weeklyTSS(cardio: data.cardio, strength: data.strength)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if data.cardio.isEmpty && data.strength.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        currentStats
                        fitnessChart
                        weeklyVolumeChart
                        weeklyTSSChart
                        raceDayReadiness
                    }
                    .padding()
                }
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Data Yet")
                .font(CoachFonts.display(20, weight: .bold))
            Text("Log workouts to see your training stress, fitness curves, and volume tracking.")
                .font(CoachFonts.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Current Stats (CTL / ATL / TSB)

    @ViewBuilder
    private var currentStats: some View {
        if let latest = fitness.last {
            VStack(alignment: .leading, spacing: 12) {
                CoachLabel(text: "Current")
                HStack(spacing: 0) {
                    statBox(label: "FITNESS", value: String(format: "%.0f", latest.ctl), color: CoachColors.blue)
                    statBox(label: "FATIGUE", value: String(format: "%.0f", latest.atl), color: CoachColors.red)
                    statBox(label: "FORM", value: String(format: "%+.0f", latest.tsb), color: latest.tsb >= 0 ? CoachColors.green : CoachColors.yellow)
                }
            }
        }
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(CoachFonts.mono(9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(CoachFonts.display(24, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fitness Chart (CTL / ATL / TSB)

    @ViewBuilder
    private var fitnessChart: some View {
        let points = fitness.suffix(90) // last 90 days
        if points.count >= 7 {
            VStack(alignment: .leading, spacing: 8) {
                CoachLabel(text: "Fitness & Fatigue")
                Text("90 days")
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(Array(points)) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("CTL", p.ctl)
                        )
                        .foregroundStyle(CoachColors.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("ATL", p.atl)
                        )
                        .foregroundStyle(CoachColors.red.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }

                    // TSB area fill
                    ForEach(Array(points)) { p in
                        AreaMark(
                            x: .value("Date", p.date),
                            y: .value("TSB", p.tsb)
                        )
                        .foregroundStyle(
                            p.tsb >= 0
                                ? CoachColors.green.opacity(0.15)
                                : CoachColors.red.opacity(0.1)
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartLegend(.visible)
                .frame(height: 200)
                .padding(12)
                .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Weekly Volume by Sport

    @ViewBuilder
    private var weeklyVolumeChart: some View {
        let volumes = weeklyVolume.suffix(12) // last 12 weeks
        if !volumes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CoachLabel(text: "Weekly Volume")

                Chart {
                    ForEach(Array(volumes)) { v in
                        BarMark(
                            x: .value("Week", v.weekStart, unit: .weekOfYear),
                            y: .value("Hours", v.runMinutes / 60)
                        )
                        .foregroundStyle(CoachColors.green)

                        BarMark(
                            x: .value("Week", v.weekStart, unit: .weekOfYear),
                            y: .value("Hours", v.bikeMinutes / 60)
                        )
                        .foregroundStyle(CoachColors.blue)

                        BarMark(
                            x: .value("Week", v.weekStart, unit: .weekOfYear),
                            y: .value("Hours", v.swimMinutes / 60)
                        )
                        .foregroundStyle(CoachColors.cyan)

                        BarMark(
                            x: .value("Week", v.weekStart, unit: .weekOfYear),
                            y: .value("Hours", v.strengthMinutes / 60)
                        )
                        .foregroundStyle(CoachColors.yellow)

                        BarMark(
                            x: .value("Week", v.weekStart, unit: .weekOfYear),
                            y: .value("Hours", v.otherMinutes / 60)
                        )
                        .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                .chartForegroundStyleScale([
                    "Run": CoachColors.green,
                    "Bike": CoachColors.blue,
                    "Swim": CoachColors.cyan,
                    "Strength": CoachColors.yellow,
                    "Other": Color.gray.opacity(0.5),
                ])
                .frame(height: 180)
                .padding(12)
                .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Weekly TSS

    @ViewBuilder
    private var weeklyTSSChart: some View {
        let weeks = weeklyTSS.suffix(12)
        if !weeks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CoachLabel(text: "Weekly Training Stress")

                Chart {
                    ForEach(Array(weeks)) { w in
                        BarMark(
                            x: .value("Week", w.weekStart, unit: .weekOfYear),
                            y: .value("TSS", w.tss)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CoachColors.accent, CoachColors.accent.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .frame(height: 160)
                .padding(12)
                .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Race Day Readiness

    @ViewBuilder
    private var raceDayReadiness: some View {
        if let latest = fitness.last,
           let projection = TrainingStressCalculator.raceDayProjection(
               currentCTL: latest.ctl,
               currentATL: latest.atl,
               plan: data.trainingPlan,
               events: data.events
           ) {
            let fmt = DateFormatter()
            let _ = fmt.dateFormat = "MMM d, yyyy"
            let daysOut = Calendar.current.dateComponents([.day], from: Date(), to: projection.date).day ?? 0

            VStack(alignment: .leading, spacing: 12) {
                CoachLabel(text: "Race Day Readiness")

                CoachCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PROJECTED FORM")
                                    .font(CoachFonts.mono(10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%+.0f TSB", projection.projectedTSB))
                                    .font(CoachFonts.display(24, weight: .bold))
                                    .foregroundStyle(readinessColor(projection.projectedTSB))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(daysOut) days out")
                                    .font(CoachFonts.mono(11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(fmt.string(from: projection.date))
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        readinessBar(tsb: projection.projectedTSB)

                        Text(readinessLabel(projection.projectedTSB))
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func readinessBar(tsb: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            // TSB range: -30 to +30, clamp for display
            let clamped = max(-30, min(30, tsb))
            let midpoint = w / 2
            let offset = (clamped / 30) * (w / 2)

            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))

                // Optimal zone (TSB +5 to +25)
                let optLeft = midpoint + (5.0 / 30) * (w / 2)
                let optRight = midpoint + (25.0 / 30) * (w / 2)
                RoundedRectangle(cornerRadius: 4)
                    .fill(CoachColors.green.opacity(0.15))
                    .frame(width: optRight - optLeft)
                    .offset(x: optLeft)

                // Marker
                Circle()
                    .fill(readinessColor(tsb))
                    .frame(width: 12, height: 12)
                    .offset(x: midpoint + offset - 6)
            }
        }
        .frame(height: 12)
    }

    private func readinessColor(_ tsb: Double) -> Color {
        if tsb >= 5 && tsb <= 25 { return CoachColors.green }
        if tsb > 25 { return CoachColors.blue }  // overtapered
        if tsb < -10 { return CoachColors.red }   // fatigued
        return CoachColors.yellow
    }

    private func readinessLabel(_ tsb: Double) -> String {
        if tsb >= 5 && tsb <= 25 { return "Projected form is in the optimal race-day window (+5 to +25)." }
        if tsb > 25 { return "Risk of detraining — form is high but fitness may have decayed." }
        if tsb >= 0 { return "Close to optimal — the taper should bring form into range." }
        if tsb >= -10 { return "Carrying moderate fatigue — form should improve with taper." }
        return "Heavy fatigue load — race-day form depends on an effective taper."
    }
}
