import SwiftUI
import Supabase
import Functions

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct RaceDetailView: View {
    let eventId: String

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var weatherLoading = false
    @State private var weatherError: String?

    @State private var generatingOverview = false
    @State private var overviewError: String?
    @State private var showAllTips = false

    @State private var newNote: String = ""

    @State private var showEditSheet = false
    @State private var presentedURL: IdentifiableURL?

    var body: some View {
        ScrollView {
            if let event = currentEvent {
                VStack(alignment: .leading, spacing: 12) {
                    header(event: event)
                    aiOverviewCard(event: event)
                    weatherCard(event: event)
                    if let plan = event.planSections, hasPlanContent(plan) {
                        racePlanCard(plan: plan)
                    }
                    notesCard(event: event)
                    if event.completed {
                        resultCard(event: event)
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Race not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This event may have been deleted.")
                )
            }
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if currentEvent != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .task(id: eventId) {
            await loadWeatherIfNeeded()
        }
        .sheet(isPresented: $showEditSheet) {
            EditGoalSheet(eventId: eventId, isPresented: $showEditSheet) { result in
                if case .deleted = result {
                    dismiss()
                }
            }
        }
        .sheet(item: $presentedURL) { wrapped in
            SafariSheet(url: wrapped.url)
        }
    }

    // MARK: - Live event lookup (so external edits flow in)

    private var currentEvent: Event? {
        data.events.first { $0.id == eventId }
    }

    // MARK: - Header

    private func header(event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let preset = EventPreset.all.first(where: { $0.id == event.presetId }) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(CoachColors.accent)
                }
                CoachPill(text: event.mode.rawValue.uppercased(), color: CoachColors.accent)
                Spacer()
                if let date = event.date, !event.completed, let days = daysUntil(date), days >= 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        if days < 7 {
                            Text("\(days)")
                                .font(CoachFonts.display(28, weight: .bold))
                                .foregroundStyle(CoachColors.accent)
                            Text("days")
                                .font(CoachFonts.ui(10))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(days / 7)")
                                .font(CoachFonts.display(28, weight: .bold))
                                .foregroundStyle(CoachColors.accent)
                            Text("weeks")
                                .font(CoachFonts.ui(10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if event.completed {
                    CoachPill(text: "DONE", color: CoachColors.green)
                }
            }

            Text(event.name)
                .font(CoachFonts.display(22, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 3) {
                if let date = event.date {
                    Label(formatDateLong(date), systemImage: "calendar")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.circle")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                }
                if let distance = event.distance, !distance.isEmpty {
                    Label(distance, systemImage: "ruler")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                }
                if let urlString = event.url,
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    Button {
                        presentedURL = IdentifiableURL(url: url)
                    } label: {
                        Label("Official site", systemImage: "link")
                            .font(CoachFonts.ui(13, weight: .medium))
                            .foregroundStyle(CoachColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if (event.goal?.isEmpty == false) || (event.stretchGoal?.isEmpty == false) {
                HStack(spacing: 16) {
                    if let goal = event.goal, !goal.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GOAL")
                                .font(CoachFonts.ui(10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Text(goal)
                                .font(CoachFonts.mono(16, weight: .semibold))
                        }
                    }
                    if let stretch = event.stretchGoal, !stretch.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STRETCH")
                                .font(CoachFonts.ui(10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Text(stretch)
                                .font(CoachFonts.mono(16, weight: .semibold))
                                .foregroundStyle(CoachColors.accent)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [CoachColors.accent.opacity(0.15), CoachColors.accent.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CoachColors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - AI Overview

    private func aiOverviewCard(event: Event) -> some View {
        sectionCard(title: "Race Overview") {
            if let conditions = event.aiConditions, hasOverviewContent(conditions) {
                populatedOverview(conditions: conditions, event: event)
            } else {
                emptyOverview(event: event)
            }
        }
    }

    private func populatedOverview(conditions: AIConditions, event: Event) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let summary = conditions.summary, !summary.isEmpty {
                Text(summary)
                    .font(CoachFonts.ui(14))
                    .foregroundStyle(textColor(0.75))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            statChipStrip(conditions: conditions)

            if let tips = conditions.tips, !tips.isEmpty {
                tipsSection(tips: tips)
            }

            HStack {
                Spacer()
                Button {
                    Task { await generateOverview(event: event) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Regenerate")
                            .font(CoachFonts.ui(12, weight: .medium))
                    }
                    .foregroundStyle(CoachColors.accent)
                }
                .buttonStyle(.plain)
                .disabled(generatingOverview)
            }
            .padding(.top, 2)

            if let err = overviewError {
                Text(err)
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.red)
            }
        }
    }

    private func emptyOverview(event: Event) -> some View {
        VStack(spacing: 12) {
            Text("No overview yet. Have your coach generate a race-day briefing.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                Task { await generateOverview(event: event) }
            } label: {
                HStack {
                    if generatingOverview {
                        ProgressView().controlSize(.small)
                    }
                    Text(generatingOverview ? "Generating…" : "Generate race overview")
                }
                .font(CoachFonts.ui(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(CoachColors.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(generatingOverview)

            if let err = overviewError {
                Text(err)
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Stat Chip Strip

    private func statChipStrip(conditions: AIConditions) -> some View {
        HStack(spacing: 8) {
            if let terrain = conditions.terrain, !terrain.short.isEmpty {
                statChip(label: "TERRAIN", value: terrain.short)
            }
            if let elevation = conditions.elevation, !elevation.short.isEmpty {
                statChip(label: "ELEVATION", value: elevation.short)
            }
            if let climate = conditions.climate, !climate.short.isEmpty {
                statChip(label: "CLIMATE", value: climate.short)
            }
        }
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CoachFonts.ui(10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(mutedLabel)
            Text(value)
                .font(CoachFonts.ui(12, weight: .medium))
                .foregroundStyle(textColor(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Tips

    private func tipsSection(tips: [TipValue]) -> some View {
        let visibleCount = showAllTips ? tips.count : min(4, tips.count)
        let visible = Array(tips.prefix(visibleCount))
        let hiddenCount = tips.count - visibleCount
        let borderColor = colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.04)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { idx, tip in
                tipRow(number: idx + 1, tip: tip, isLast: idx == visible.count - 1)
                    .overlay(
                        Group {
                            if idx < visible.count - 1 {
                                Rectangle()
                                    .fill(borderColor)
                                    .frame(height: 1)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                    )
            }

            if tips.count > 4 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllTips.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllTips
                             ? "Show fewer"
                             : "Show \(hiddenCount > 0 ? hiddenCount : tips.count - 4) more tips")
                            .font(CoachFonts.ui(12, weight: .medium))
                        Image(systemName: showAllTips ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(CoachColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tipRow(number: Int, tip: TipValue, isLast: Bool) -> some View {
        let isHighPriority = number <= 3

        let badgeBg = isHighPriority
            ? CoachColors.accent.opacity(0.2)
            : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
        let badgeFg = isHighPriority
            ? CoachColors.accent
            : (colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4))

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(CoachFonts.ui(11, weight: .semibold))
                .foregroundStyle(badgeFg)
                .frame(minWidth: 22, minHeight: 22)
                .background(Circle().fill(badgeBg))

            tipText(tip)
                .font(CoachFonts.ui(13))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private func tipText(_ tip: TipValue) -> Text {
        if let headline = tip.headline, !headline.isEmpty {
            let lead = Text(headline)
                .font(CoachFonts.ui(13, weight: .medium))
                .foregroundColor(textColor(0.9))
            let sep = Text(" — ").foregroundColor(textColor(0.7))
            let body = Text(tip.detail).foregroundColor(textColor(0.7))
            return lead + sep + body
        }
        return Text(tip.detail).foregroundColor(textColor(0.7))
    }

    private func hasOverviewContent(_ c: AIConditions) -> Bool {
        if let s = c.summary, !s.isEmpty { return true }
        if c.terrain?.short.isEmpty == false { return true }
        if c.elevation?.short.isEmpty == false { return true }
        if c.climate?.short.isEmpty == false { return true }
        if let tips = c.tips, !tips.isEmpty { return true }
        return false
    }

    // MARK: - Weather

    private func weatherCard(event: Event) -> some View {
        sectionCard(title: "Weather") {
            VStack(alignment: .leading, spacing: 0) {
                if weatherLoading {
                    weatherLoadingState
                } else if let err = weatherError {
                    weatherErrorState(err)
                } else if let w = event.weatherData, !w.isClimateEstimate, w.temperatureHigh != nil {
                    weatherPopulatedState(weather: w, event: event)
                } else if event.location == nil || event.location?.isEmpty == true || event.date == nil {
                    Text("Add a date and location to fetch the forecast.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                } else {
                    weatherEmptyState(event: event)
                }
            }
        }
    }

    // 4h. Loading
    private var weatherLoadingState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading forecast…")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(mutedLabel)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    // 4g. Error
    private func weatherErrorState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load forecast")
                .font(CoachFonts.ui(13))
                .foregroundStyle(mutedLabel)
            Button {
                Task { await loadWeather(force: true) }
            } label: {
                Text("Try again")
                    .font(CoachFonts.ui(12, weight: .medium))
                    .foregroundStyle(CoachColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // 4a-4e. Populated
    private func weatherPopulatedState(weather: WeatherData, event: Event) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            weatherConditionHeader(weather: weather)
                .padding(.bottom, 12)

            weatherStatsRow(weather: weather)
                .padding(.bottom, 14)

            if let hourly = weather.hourly, !hourly.isEmpty {
                raceMorningStrip(hourly: hourly)
                    .padding(.bottom, 12)
            }

            if let impact = weather.impact {
                impactBox(impact: impact)
                    .padding(.bottom, 10)
            }

            weatherFreshnessLine(weather: weather)
        }
    }

    // 4a. Condition header
    private func weatherConditionHeader(weather: WeatherData) -> some View {
        HStack(alignment: .top, spacing: 10) {
            WeatherIcon(code: weather.weatherCode)
                .frame(width: 44, height: 44)
                .background(chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.weatherDescription ?? "Mixed conditions")
                    .font(CoachFonts.ui(15, weight: .medium))
                    .foregroundStyle(textColor(0.85))
                if let feels = feelsLikeText(weather) {
                    Text(feels)
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(mutedLabel)
                }
            }
            .padding(.top, 4)

            Spacer()

            Button {
                Task { await loadWeather(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundStyle(mutedIcon)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
    }

    private func feelsLikeText(_ weather: WeatherData) -> String? {
        if let feel = weather.hourly?.first?.apparentTempF {
            return "Feels like \(Int(feel.rounded()))°F at start"
        }
        return nil
    }

    // 4b. Stats row (4 columns with inline units and dividers)
    private func weatherStatsRow(weather: WeatherData) -> some View {
        HStack(spacing: 0) {
            weatherStatCell(
                value: weather.temperatureHigh.map { "\(Int($0.rounded()))" } ?? "—",
                unit: "°",
                label: "HIGH",
                isLast: false
            )
            weatherStatCell(
                value: weather.temperatureLow.map { "\(Int($0.rounded()))" } ?? "—",
                unit: "°",
                label: "LOW",
                isLast: false
            )
            weatherStatCell(
                value: weather.windSpeed.map { "\(Int($0.rounded()))" } ?? "—",
                unit: "mph",
                unitLeadingSpace: true,
                label: "WIND",
                isLast: false
            )
            weatherStatCell(
                value: weather.precipitationProbability.map { "\(Int($0.rounded()))" } ?? (weather.precipitation.map { "\(Int($0.rounded()))" } ?? "—"),
                unit: "%",
                label: "PRECIP",
                isLast: true
            )
        }
    }

    private func weatherStatCell(
        value: String,
        unit: String,
        unitLeadingSpace: Bool = false,
        label: String,
        isLast: Bool
    ) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: unitLeadingSpace ? 2 : 0) {
                    Text(value)
                        .font(CoachFonts.display(20, weight: .semibold))
                        .foregroundStyle(textColor(0.85))
                    Text(unit)
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(mutedLabel)
                }
                .lineLimit(1)
                Text(label)
                    .font(CoachFonts.ui(10, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(mutedLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            if !isLast {
                Rectangle()
                    .fill(dividerColor)
                    .frame(width: 1)
                    .padding(.vertical, 8)
            }
        }
    }

    // 4c. Race morning hourly strip
    private func raceMorningStrip(hourly: [HourlyWeatherPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RACE MORNING")
                .font(CoachFonts.ui(11, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(mutedLabel)

            HStack(spacing: 0) {
                ForEach(Array(hourly.enumerated()), id: \.offset) { idx, point in
                    hourlySlot(point: point, isGunTime: idx == 0)
                }
            }
        }
    }

    private func hourlySlot(point: HourlyWeatherPoint, isGunTime: Bool) -> some View {
        VStack(spacing: 2) {
            Text(hourLabel(point.hour))
                .font(CoachFonts.ui(10, weight: .medium))
                .foregroundStyle(isGunTime ? AnyShapeStyle(CoachColors.accent) : AnyShapeStyle(mutedLabel))
                .padding(.bottom, 2)
            Text("\(Int(point.tempF.rounded()))°")
                .font(CoachFonts.ui(14, weight: .medium))
                .foregroundStyle(textColor(0.8))
                .padding(.bottom, 1)
            Text("\(Int((point.windMph ?? 0).rounded())) mph")
                .font(CoachFonts.ui(10))
                .foregroundStyle(mutedLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isGunTime
                ? RoundedRectangle(cornerRadius: 8).fill(CoachColors.accent.opacity(0.08))
                : nil
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "AM" : "PM"
        return "\(hour12) \(period)"
    }

    // 4d. Impact assessment
    @ViewBuilder
    private func impactBox(impact: WeatherImpact) -> some View {
        let (bg, border, dot) = impactColors(for: impact.rating)
        let (lead, rest) = splitImpactAssessment(impact.assessment)

        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
                .frame(minWidth: 8)

            Text(rest.isEmpty ? lead : "\(lead) \(rest)")
                .font(CoachFonts.ui(12))
                .foregroundColor(textColor(0.75))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .background(bg)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func impactColors(for rating: String) -> (Color, Color, Color) {
        switch rating.lowercased() {
        case "good":
            return (
                Color(red: 29/255, green: 158/255, blue: 117/255).opacity(0.08),
                Color(red: 29/255, green: 158/255, blue: 117/255).opacity(0.15),
                Color(red: 29/255, green: 158/255, blue: 117/255)
            )
        case "challenging":
            return (
                Color(red: 226/255, green: 75/255, blue: 74/255).opacity(0.08),
                Color(red: 226/255, green: 75/255, blue: 74/255).opacity(0.15),
                Color(red: 226/255, green: 75/255, blue: 74/255)
            )
        default: // moderate
            return (
                Color(red: 186/255, green: 117/255, blue: 23/255).opacity(0.08),
                Color(red: 186/255, green: 117/255, blue: 23/255).opacity(0.15),
                Color(red: 186/255, green: 117/255, blue: 23/255)
            )
        }
    }

    /// Split the assessment into the first sentence (bold lead-in) and the rest.
    private func splitImpactAssessment(_ text: String) -> (String, String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let period = trimmed.firstIndex(of: ".") {
            let lead = String(trimmed[...period]).trimmingCharacters(in: .whitespaces)
            let rest = String(trimmed[trimmed.index(after: period)...]).trimmingCharacters(in: .whitespaces)
            return (lead, rest)
        }
        return (trimmed, "")
    }

    // 4e. Freshness line
    private func weatherFreshnessLine(weather: WeatherData) -> some View {
        HStack {
            Spacer()
            Text("Forecast via Open-Meteo · \(freshnessText(weather))")
                .font(CoachFonts.ui(11))
                .foregroundStyle(mutedFootnote)
            Spacer()
        }
        .padding(.top, 10)
    }

    private func freshnessText(_ weather: WeatherData) -> String {
        guard let fetchedAt = weather.fetchedAt else { return "Updated just now" }
        let seconds = Date().timeIntervalSince1970 - fetchedAt
        if seconds < 3600 { return "Updated just now" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "Updated \(hours)h ago" }
        let days = hours / 24
        return "Updated \(days) day\(days == 1 ? "" : "s") ago"
    }

    // 4f. Empty state (race > 16 days)
    private func weatherEmptyState(event: Event) -> some View {
        VStack(spacing: 8) {
            WeatherIcon(code: 2) // partly cloudy default
                .frame(width: 28, height: 28)
                .opacity(0.3)

            Text("Forecast available ~2 weeks out")
                .font(CoachFonts.ui(13))
                .foregroundStyle(mutedLabel)

            if let unlockDate = forecastUnlockDate(for: event.date) {
                Text("We'll show race-day conditions once \(unlockDate) arrives")
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(mutedFootnote)
                    .multilineTextAlignment(.center)
            }

            if let climate = event.aiConditions?.climate?.short, !climate.isEmpty {
                Text("Climate avg: \(climate)")
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(mutedLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func forecastUnlockDate(for dateStr: String?) -> String? {
        guard let dateStr else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return nil }
        guard let unlock = Calendar.current.date(byAdding: .day, value: -16, to: date) else { return nil }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: unlock)
    }

    // MARK: - Race plan sections

    private func hasPlanContent(_ p: RacePlanSections) -> Bool {
        [p.strategy, p.nutrition, p.pacing, p.gear, p.mentalPlan].contains { ($0 ?? "").isEmpty == false }
    }

    private func racePlanCard(plan: RacePlanSections) -> some View {
        sectionCard(title: "Race Plan") {
            VStack(alignment: .leading, spacing: 12) {
                planRow("Strategy", plan.strategy)
                planRow("Pacing", plan.pacing)
                planRow("Nutrition", plan.nutrition)
                planRow("Gear", plan.gear)
                planRow("Mental plan", plan.mentalPlan)
            }
        }
    }

    @ViewBuilder
    private func planRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(CoachFonts.ui(10, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(CoachFonts.ui(13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Notes

    private func notesCard(event: Event) -> some View {
        sectionCard(title: "Athlete Notes") {
            VStack(alignment: .leading, spacing: 10) {
                if event.notes.isEmpty {
                    Text("Gear lists, mental cues, race-day reminders")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(mutedLabel)
                } else {
                    ForEach(event.notes.indices, id: \.self) { idx in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(CoachColors.accent)
                            Text(event.notes[idx])
                                .font(CoachFonts.ui(13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                Task { await removeNote(at: idx) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    TextField("Add a note…", text: $newNote, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(chipBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        Task { await addNote() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(newNote.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : CoachColors.accent)
                    }
                    .disabled(newNote.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Result

    private func resultCard(event: Event) -> some View {
        sectionCard(title: "Result") {
            VStack(alignment: .leading, spacing: 8) {
                if let result = event.result, !result.isEmpty {
                    HStack {
                        Text("Finish")
                        Spacer()
                        Text(result).font(CoachFonts.mono(14, weight: .semibold))
                    }
                    .font(CoachFonts.ui(13))
                }
                if let placement = event.placement, !placement.isEmpty {
                    HStack {
                        Text("Place")
                        Spacer()
                        Text(placement).font(CoachFonts.mono(14, weight: .semibold))
                    }
                    .font(CoachFonts.ui(13))
                }
                if let splits = event.splits {
                    Divider()
                    splitRow("Swim", splits.swim)
                    splitRow("T1", splits.t1)
                    splitRow("Bike", splits.bike)
                    splitRow("T2", splits.t2)
                    splitRow("Run", splits.run)
                    splitRow("Total", splits.total)
                }
            }
        }
    }

    @ViewBuilder
    private func splitRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack {
                Text(label).font(CoachFonts.ui(13)).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(CoachFonts.mono(13))
            }
        }
    }

    // MARK: - Card chrome (consistent section card style)

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(CoachFonts.ui(11, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(mutedLabel)
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

    // MARK: - Color tokens (local helpers using the existing CoachColors system)

    private var mutedLabel: Color {
        colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)
    }
    private var mutedFootnote: Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25)
    }
    private var mutedIcon: Color {
        colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3)
    }
    private var chipBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }
    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    private func textColor(_ opacity: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(opacity) : Color.black.opacity(opacity)
    }

    // MARK: - Actions

    private func addNote() async {
        guard var event = currentEvent else { return }
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        event.notes.append(trimmed)
        try? await data.updateEvent(event)
        newNote = ""
    }

    private func removeNote(at idx: Int) async {
        guard var event = currentEvent, idx < event.notes.count else { return }
        event.notes.remove(at: idx)
        try? await data.updateEvent(event)
    }

    /// Load weather from cache if fresh (<6h), else fetch fresh.
    private func loadWeatherIfNeeded() async {
        guard let event = currentEvent else { return }
        if let cached = event.weatherData,
           let fetchedAt = cached.fetchedAt,
           Date().timeIntervalSince1970 - fetchedAt < 6 * 3600 {
            // Cache still fresh
            return
        }
        await loadWeather(force: true)
    }

    private func loadWeather(force: Bool) async {
        guard var event = currentEvent,
              let location = event.location, !location.isEmpty,
              let date = event.date else {
            return
        }
        weatherLoading = true
        weatherError = nil
        do {
            let w = try await WeatherService.shared.getWeather(location: location, date: date)
            event.weatherData = w
            try? await data.updateEvent(event)
            await generateImpactIfNeeded(for: event)
        } catch {
            weatherError = error.localizedDescription
        }
        weatherLoading = false
    }

    /// Fire an AI impact assessment in the background if the current weather
    /// doesn't already have one.
    private func generateImpactIfNeeded(for event: Event) async {
        guard var fresh = data.events.first(where: { $0.id == event.id }),
              let weather = fresh.weatherData,
              !weather.isClimateEstimate,
              !WeatherImpactGenerator.isCached(weather.impact, for: weather) else {
            return
        }
        do {
            let impact = try await WeatherImpactGenerator.generate(for: fresh, weather: weather)
            var updatedWeather = weather
            updatedWeather.impact = impact
            fresh.weatherData = updatedWeather
            try? await data.updateEvent(fresh)
        } catch {
            NSLog("[race-detail] impact generation failed: \(error)")
        }
    }

    private func generateOverview(event: Event) async {
        generatingOverview = true
        overviewError = nil
        do {
            let result = try await RaceConditionsGenerator.generate(for: event)
            var updated = event
            updated.aiConditions = result.conditions
            if let url = result.officialURL, !url.isEmpty {
                updated.url = url
            }
            try await data.updateEvent(updated)
        } catch {
            overviewError = error.localizedDescription
        }
        generatingOverview = false
    }

}

// MARK: - Weather Icon

/// Small SF-Symbol-backed weather icon, tinted based on WMO code.
private struct WeatherIcon: View {
    let code: Int?

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 22, weight: .medium))
            .symbolRenderingMode(.palette)
            .foregroundStyle(primaryColor, secondaryColor)
    }

    private var symbolName: String {
        guard let code else { return "cloud.sun.fill" }
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.max.fill"
        case 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65, 80, 81, 82: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    private var primaryColor: Color {
        guard let code else { return Color(red: 239/255, green: 159/255, blue: 39/255) }
        switch code {
        case 0, 1: return Color(red: 239/255, green: 159/255, blue: 39/255) // amber sun
        case 61...99 where code != 71 && code != 73 && code != 75 && code != 85 && code != 86:
            return Color(red: 133/255, green: 183/255, blue: 235/255) // blue rain
        default: return Color.primary.opacity(0.55)
        }
    }

    private var secondaryColor: Color {
        Color.primary.opacity(0.35)
    }
}
