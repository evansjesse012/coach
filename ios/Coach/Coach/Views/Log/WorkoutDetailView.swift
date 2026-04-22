import SwiftUI
import Charts
import MapKit

struct WorkoutDetailView: View {
    let workout: CardioWorkout
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    /// Finds a prescribed session that was auto-matched to this workout.
    private var matchedSession: (session: PrescribedSession, weekNum: Int)? {
        guard let plan = data.trainingPlan else { return nil }
        // Only look for matches on non-manual workouts
        guard workout.source != "manual" else { return nil }

        // Search current and recent weeks for a session completed on the same date
        for weekNum in max(1, plan.currentWeek - 2)...plan.currentWeek {
            guard let wp = plan.weeklyPlans[String(weekNum)] else { continue }
            for dayPlan in wp.sessions {
                for session in dayPlan.sessions {
                    guard session.completionStatus != nil,
                          session.completionNote == "Auto-matched from Apple Watch",
                          session.type.lowercased() == workout.sport.rawValue else { continue }
                    // Check if durations are close
                    if let actual = session.actualDuration, abs(actual - workout.duration) < 120 {
                        return (session, weekNum)
                    }
                }
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                matchedSessionCard
                statGrid
                if workout.healthData?.hrSamples?.isEmpty == false {
                    hrChartSection
                }
                if workout.healthData?.hrZones != nil {
                    hrZonesSection
                }
                if workout.healthData?.powerSamples?.isEmpty == false {
                    powerChartSection
                }
                if workout.healthData?.cadenceSamples?.isEmpty == false {
                    cadenceChartSection
                }
                if let route = workout.routeSummary, !route.points.isEmpty {
                    mapSection(route: route)
                }
                if let laps = workout.healthData?.laps, !laps.isEmpty {
                    lapsSection(laps: laps)
                }
                if let weather = workout.weather ?? workout.healthData?.weather {
                    weatherSection(weather: weather)
                }
                if let notes = workout.notes, !notes.isEmpty {
                    notesSection(notes: notes)
                }
                if let source = workout.healthData?.source {
                    sourceFooter(source: source)
                }
            }
            .padding()
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle(formatDateShort(workout.date))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        CoachCard(accentColor: workout.sport.swiftUIColor) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SportBadge(sport: workout.sport)
                    Spacer()
                    if let location = workout.location {
                        Label(location, systemImage: "mappin.circle")
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(formatDateRelative(workout.date))
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
                if let notes = workout.notes, !notes.isEmpty {
                    Text(notes)
                        .font(CoachFonts.ui(14))
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Matched Session Card

    @ViewBuilder
    private var matchedSessionCard: some View {
        if let match = matchedSession {
            CoachCard {
                HStack(spacing: 10) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CoachColors.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Matched to plan")
                            .font(CoachFonts.ui(11, weight: .semibold))
                            .foregroundStyle(CoachColors.green)
                        Text(match.session.label)
                            .font(CoachFonts.ui(14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Week \(match.weekNum)")
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Stat Grid

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCell("Duration", formatDuration(workout.duration))
            if let dist = workout.distance {
                statCell("Distance", dist)
            }
            if let pace = workout.pace {
                statCell("Pace", pace)
            }
            if let cal = workout.calories {
                statCell("Calories", "\(cal)")
            }
            if let hr = workout.avgHR {
                statCell("Avg HR", "\(hr)")
            }
            if let hr = workout.maxHR {
                statCell("Max HR", "\(hr)")
            }
            if let p = workout.avgPower {
                statCell("Avg Power", "\(p)W")
            }
            if let cad = workout.avgCadence {
                statCell("Cadence", "\(cad)")
            }
            if let elev = workout.elevationGain {
                statCell("Elevation", "\(elev)m")
            }
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(CoachFonts.display(18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    // MARK: - HR Chart

    private var hrChartSection: some View {
        chartCard(title: "Heart Rate") {
            if let samples = workout.healthData?.hrSamples {
                Chart(samples.indices, id: \.self) { idx in
                    LineMark(
                        x: .value("t", samples[idx].t),
                        y: .value("bpm", samples[idx].v)
                    )
                    .foregroundStyle(CoachColors.accent)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxisLabel("bpm")
                .frame(height: 140)
            }
        }
    }

    // MARK: - HR Zones

    private var hrZonesSection: some View {
        chartCard(title: "Time in HR Zones") {
            if let z = workout.healthData?.hrZones {
                let total = max(1, z.z1 + z.z2 + z.z3 + z.z4 + z.z5)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        zoneBar("Z1", seconds: z.z1, total: total, color: CoachColors.green.opacity(0.4))
                        zoneBar("Z2", seconds: z.z2, total: total, color: CoachColors.green)
                        zoneBar("Z3", seconds: z.z3, total: total, color: CoachColors.yellow)
                        zoneBar("Z4", seconds: z.z4, total: total, color: CoachColors.accent)
                        zoneBar("Z5", seconds: z.z5, total: total, color: CoachColors.red)
                    }
                    .frame(height: 30)
                    HStack(spacing: 12) {
                        zoneLegend("Z1", seconds: z.z1)
                        zoneLegend("Z2", seconds: z.z2)
                        zoneLegend("Z3", seconds: z.z3)
                        zoneLegend("Z4", seconds: z.z4)
                        zoneLegend("Z5", seconds: z.z5)
                    }
                }
            }
        }
    }

    private func zoneBar(_ label: String, seconds: Int, total: Int, color: Color) -> some View {
        let frac = Double(seconds) / Double(total)
        return color
            .frame(width: nil)
            .frame(maxWidth: .infinity)
            .overlay(
                Text(label)
                    .font(CoachFonts.ui(10, weight: .bold))
                    .foregroundStyle(.white.opacity(seconds > 0 ? 1 : 0))
            )
            .layoutPriority(frac)
    }

    private func zoneLegend(_ label: String, seconds: Int) -> some View {
        VStack(spacing: 1) {
            Text(label).font(CoachFonts.ui(10, weight: .semibold)).foregroundStyle(.secondary)
            Text(formatDurationShort(seconds)).font(CoachFonts.mono(11))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDurationShort(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m == 0 { return "\(s)s" }
        return s == 0 ? "\(m)m" : "\(m)m\(s)s"
    }

    // MARK: - Power / Cadence

    private var powerChartSection: some View {
        chartCard(title: "Power") {
            if let samples = workout.healthData?.powerSamples {
                Chart(samples.indices, id: \.self) { idx in
                    LineMark(
                        x: .value("t", samples[idx].t),
                        y: .value("W", samples[idx].v)
                    )
                    .foregroundStyle(CoachColors.cyan)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxisLabel("W")
                .frame(height: 120)
            }
        }
    }

    private var cadenceChartSection: some View {
        chartCard(title: "Cadence") {
            if let samples = workout.healthData?.cadenceSamples {
                Chart(samples.indices, id: \.self) { idx in
                    LineMark(
                        x: .value("t", samples[idx].t),
                        y: .value("rpm", samples[idx].v)
                    )
                    .foregroundStyle(CoachColors.purple)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxisLabel("rpm")
                .frame(height: 100)
            }
        }
    }

    // MARK: - Map

    private func mapSection(route: RouteSummary) -> some View {
        chartCard(title: "Route") {
            let coords = route.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (route.bbox.minLat + route.bbox.maxLat) / 2,
                    longitude: (route.bbox.minLng + route.bbox.maxLng) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max(0.005, (route.bbox.maxLat - route.bbox.minLat) * 1.4),
                    longitudeDelta: max(0.005, (route.bbox.maxLng - route.bbox.minLng) * 1.4)
                )
            )
            Map(initialPosition: .region(region), interactionModes: []) {
                MapPolyline(coordinates: coords)
                    .stroke(CoachColors.accent, lineWidth: 4)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Laps

    private func lapsSection(laps: [LapSplit]) -> some View {
        chartCard(title: "Laps") {
            VStack(spacing: 6) {
                ForEach(laps) { lap in
                    HStack {
                        Text("\(lap.index)")
                            .font(CoachFonts.mono(13, weight: .semibold))
                            .frame(width: 24, alignment: .leading)
                        Text(formatDurationShort(Int(lap.duration)))
                            .font(CoachFonts.mono(13))
                        if let dist = lap.distance {
                            Spacer()
                            Text(String(format: "%.2fmi", dist * 0.000621371))
                                .font(CoachFonts.mono(12))
                                .foregroundStyle(.secondary)
                        }
                        if let hr = lap.avgHR {
                            Text("\(hr) bpm")
                                .font(CoachFonts.mono(12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Weather / Notes / Source

    private func weatherSection(weather: WeatherSnapshot) -> some View {
        chartCard(title: "Weather") {
            HStack(spacing: 16) {
                if let temp = weather.tempC {
                    Label(String(format: "%.0f°C", temp), systemImage: "thermometer")
                }
                if let h = weather.humidity {
                    Label(String(format: "%.0f%%", h), systemImage: "humidity")
                }
                if let c = weather.conditions {
                    Label(c, systemImage: "cloud")
                }
            }
            .font(CoachFonts.ui(13))
            .foregroundStyle(.secondary)
        }
    }

    private func notesSection(notes: String) -> some View {
        chartCard(title: "Notes") {
            Text(notes)
                .font(CoachFonts.ui(13))
        }
    }

    private func sourceFooter(source: SourceInfo) -> some View {
        HStack {
            Image(systemName: "applewatch")
                .foregroundStyle(.secondary)
            Text([source.app, source.device].compactMap { $0 }.joined(separator: " · "))
                .font(CoachFonts.ui(11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Card chrome

    @ViewBuilder
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CoachLabel(text: title)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}
