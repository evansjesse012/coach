import SwiftUI
import Supabase
import Functions

struct RaceDetailView: View {
    let eventId: String

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    @State private var weather: WeatherData?
    @State private var weatherLoading = false
    @State private var weatherError: String?

    @State private var generatingOverview = false
    @State private var overviewError: String?

    @State private var newNote: String = ""

    @State private var safariURL: IdentifiedURL?
    @State private var editingURL = false
    @State private var urlDraft = ""

    var body: some View {
        ScrollView {
            if let event = currentEvent {
                VStack(alignment: .leading, spacing: 16) {
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
        .task(id: eventId) {
            await loadWeather()
        }
        .sheet(item: $safariURL) { wrapped in
            SafariSheet(url: wrapped.url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $editingURL) {
            editURLSheet
        }
    }

    // MARK: - Live event lookup (so external edits flow in)

    private var currentEvent: Event? {
        data.events.first { $0.id == eventId }
    }

    // MARK: - Header

    private func header(event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let preset = EventPreset.all.first(where: { $0.id == event.presetId }) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(CoachColors.accent)
                }
                CoachPill(text: event.mode.rawValue.uppercased(), color: CoachColors.accent)
                Spacer()
                if let date = event.date, !event.completed, let days = daysUntil(date), days >= 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(days)")
                            .font(CoachFonts.display(28, weight: .bold))
                            .foregroundStyle(CoachColors.accent)
                        Text("days")
                            .font(CoachFonts.ui(10))
                            .foregroundStyle(.secondary)
                    }
                }
                if event.completed {
                    CoachPill(text: "DONE", color: CoachColors.green)
                }
            }

            Text(event.name)
                .font(CoachFonts.display(24, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 4) {
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
                officialSiteRow(event: event)
            }

            if event.goal != nil || event.stretchGoal != nil {
                HStack(spacing: 8) {
                    if let goal = event.goal, !goal.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GOAL").font(CoachFonts.ui(9, weight: .semibold)).tracking(0.5).foregroundStyle(.secondary)
                            Text(goal).font(CoachFonts.mono(14, weight: .semibold))
                        }
                    }
                    if let stretch = event.stretchGoal, !stretch.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STRETCH").font(CoachFonts.ui(9, weight: .semibold)).tracking(0.5).foregroundStyle(.secondary)
                            Text(stretch).font(CoachFonts.mono(14, weight: .semibold)).foregroundStyle(CoachColors.accent)
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding(.top, 4)
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
            VStack(alignment: .leading, spacing: 12) {
                if let conditions = event.aiConditions, hasOverviewContent(conditions) {
                    if let summary = conditions.summary, !summary.isEmpty {
                        Text(summary)
                            .font(CoachFonts.ui(14))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        if let terrain = conditions.terrain, !terrain.isEmpty {
                            overviewCell("Terrain", terrain)
                        }
                        if let elevation = conditions.elevation, !elevation.isEmpty {
                            overviewCell("Elevation", elevation)
                        }
                        if let climate = conditions.climate, !climate.isEmpty {
                            overviewCell("Climate", climate)
                        }
                    }

                    if let tips = conditions.tips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("COACH'S TIPS")
                                .font(CoachFonts.ui(10, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                            ForEach(tips, id: \.self) { tip in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•")
                                        .foregroundStyle(CoachColors.accent)
                                    Text(tip)
                                        .font(CoachFonts.ui(13))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            Task { await generateOverview(event: event) }
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                                .font(CoachFonts.ui(12))
                        }
                        .disabled(generatingOverview)
                    }
                } else {
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
                                    ProgressView()
                                        .controlSize(.small)
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
                    }
                    .padding(.vertical, 8)
                }

                if let err = overviewError {
                    Text(err)
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func overviewCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CoachFonts.ui(9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(CoachFonts.ui(13))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func officialSiteRow(event: Event) -> some View {
        if let urlString = event.url, let url = URL(string: urlString) {
            HStack(spacing: 6) {
                Button {
                    safariURL = IdentifiedURL(url: url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("Official site")
                            .underline()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                    }
                    .font(CoachFonts.ui(13, weight: .medium))
                    .foregroundStyle(CoachColors.accent)
                }
                .buttonStyle(.plain)

                Button {
                    urlDraft = urlString
                    editingURL = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else if event.mode == .race {
            Button {
                urlDraft = ""
                editingURL = true
            } label: {
                Label("Add official site", systemImage: "globe.badge.chevron.backward")
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var editURLSheet: some View {
        NavigationStack {
            Form {
                Section("Official race website") {
                    TextField("https://...", text: $urlDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Edit URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingURL = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveURL() }
                    }
                }
            }
        }
    }

    private func hasOverviewContent(_ c: AIConditions) -> Bool {
        return [(c.summary ?? ""), (c.terrain ?? ""), (c.elevation ?? ""), (c.climate ?? "")].contains { !$0.isEmpty }
            || (c.tips?.isEmpty == false)
    }

    // MARK: - Weather

    private func weatherCard(event: Event) -> some View {
        sectionCard(title: "Weather") {
            VStack(alignment: .leading, spacing: 8) {
                if weatherLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading forecast…")
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)
                    }
                } else if let w = weather {
                    HStack(alignment: .top, spacing: 16) {
                        if let high = w.temperatureHigh {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HIGH").font(CoachFonts.ui(9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                                Text("\(Int(high))°F").font(CoachFonts.display(20, weight: .bold))
                            }
                        }
                        if let low = w.temperatureLow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LOW").font(CoachFonts.ui(9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                                Text("\(Int(low))°F").font(CoachFonts.display(20, weight: .bold))
                            }
                        }
                        if let wind = w.windSpeed {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WIND").font(CoachFonts.ui(9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                                Text("\(Int(wind)) mph").font(CoachFonts.display(20, weight: .bold))
                            }
                        }
                        if let precip = w.precipitation {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PRECIP").font(CoachFonts.ui(9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                                Text(String(format: "%.1f\"", precip)).font(CoachFonts.display(20, weight: .bold))
                            }
                        }
                    }
                    if let desc = w.weatherDescription {
                        Text(desc)
                            .font(CoachFonts.ui(13))
                            .foregroundStyle(.secondary)
                    }
                    if w.isClimateEstimate {
                        Text("Climate estimate (5-yr avg) — date is beyond the 16-day forecast")
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.tertiary)
                    }
                    HStack {
                        Spacer()
                        Button {
                            Task { await loadWeather() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise").font(CoachFonts.ui(12))
                        }
                    }
                } else if let err = weatherError {
                    Text(err)
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.red)
                } else if event.location == nil || event.location?.isEmpty == true || event.date == nil {
                    Text("Add a date and location to fetch the forecast.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No weather data.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.5)
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
                    Text("Drop your own thoughts, gear lists, mental cues, anything you want to remember on race day.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(event.notes.indices, id: \.self) { idx in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(CoachColors.accent)
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
                        .background(colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated)
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

    // MARK: - Result (for completed races)

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

    // MARK: - Card chrome

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(CoachFonts.ui(11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
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

    private func loadWeather() async {
        guard let event = currentEvent,
              let location = event.location, !location.isEmpty,
              let date = event.date else {
            return
        }
        weatherLoading = true
        weatherError = nil
        do {
            weather = try await WeatherService.shared.getWeather(location: location, date: date)
        } catch {
            weatherError = error.localizedDescription
        }
        weatherLoading = false
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

    private func saveURL() async {
        guard var event = currentEvent else { return }
        let trimmed = urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        event.url = trimmed.isEmpty ? nil : trimmed
        try? await data.updateEvent(event)
        editingURL = false
    }
}

private struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
