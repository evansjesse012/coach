import SwiftUI

/// The primary tab — pinned dashboard cards at top, scrollable chat below,
/// input bar at bottom. Owns all navigation, completion, and send logic.
struct CoachTab: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool
    @State private var completionSheet: ChatCompletionSheet?
    @State private var coachNoteExpanded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Pinned Dashboard
                dashboardSection

                Divider()

                // MARK: - Chat Messages
                chatSection

                Divider()

                // MARK: - Input Bar
                inputBar
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack { ConversationHistoryView() }
            }
            .sheet(item: $completionSheet) { sheet in
                completionSheetContent(sheet)
            }
        }
        .task {
            await data.ensurePlanPreGenerated()
            await data.ensureActiveConversation()
            // Inject coach note as first chat message if conversation is empty
            if data.currentMessages.isEmpty {
                await injectCoachNote()
            }
            await drainAutoMatches()
        }
        .onAppear { consumePendingPrompt() }
        .onChange(of: data.pendingChatPrompt) { _, _ in consumePendingPrompt() }
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Race / Goal countdown
                raceCountdownCard

                // Today's workout(s)
                todayWorkoutCards

                // Week summary dots
                weekSummaryCard

                // Coach's daily note (condensed)
                coachNoteCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: 300)
        .background(colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg)
    }

    // MARK: - Race Countdown Card

    @ViewBuilder
    private var raceCountdownCard: some View {
        if let plan = data.trainingPlan,
           let goalId = plan.goalId,
           let event = data.events.first(where: { $0.id == goalId }),
           let dateStr = event.date ?? plan.raceDate,
           let weeksOut = weeksUntil(dateStr), weeksOut > 0 {
            NavigationLink {
                if event.isRace {
                    RaceDetailView(eventId: event.id)
                } else {
                    GoalDetailView(eventId: event.id)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RACE DAY")
                            .font(CoachFonts.mono(9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(event.name)
                            .font(CoachFonts.display(15, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
                            Text("Week \(plan.currentWeek)/\(plan.totalWeeks) \u{00B7} \(phase.name)")
                                .font(CoachFonts.ui(11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(weeksOut)")
                            .font(CoachFonts.display(26, weight: .bold))
                            .foregroundStyle(CoachColors.accent)
                        Text("weeks")
                            .font(CoachFonts.mono(9, weight: .semibold))
                            .foregroundStyle(CoachColors.accent)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
                .padding(12)
                .background(CoachColors.accent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CoachColors.accent.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Today's Workout Cards

    @ViewBuilder
    private var todayWorkoutCards: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let dayIdx = todayDayIndex()
            if dayIdx < wp.sessions.count {
                let dayPlan = wp.sessions[dayIdx]
                if dayPlan.isRest == true {
                    restDayCard
                } else if !dayPlan.sessions.isEmpty {
                    ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sessionIdx, session in
                        NavigationLink {
                            PrescribedSessionDetailView(session: session, dateString: todayString())
                        } label: {
                            ChatWorkoutCard(
                                data: WorkoutCardData(
                                    session: session,
                                    weekNum: plan.currentWeek,
                                    dayIdx: dayIdx,
                                    sessionIdx: sessionIdx
                                ),
                                onCompletion: handleCompletion
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var restDayCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14))
                .foregroundStyle(CoachColors.purple)
            Text("Rest Day")
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    // MARK: - Week Summary Card

    @ViewBuilder
    private var weekSummaryCard: some View {
        if let plan = data.trainingPlan,
           let adherence = computeWeekAdherence(
               plan: plan, weekNum: plan.currentWeek,
               cardio: data.cardio, strength: data.strength
           ) {
            NavigationLink {
                WeekDetailView(initialWeekNum: plan.currentWeek)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(Array(adherence.days.enumerated()), id: \.offset) { _, day in
                                dashboardDot(for: day)
                            }
                        }
                        HStack(spacing: 12) {
                            Text("\(adherence.completed)/\(adherence.prescribed) sessions")
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("\(adherence.adherence)%")
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(adherence.adherence >= 75 ? CoachColors.green : .secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dashboardDot(for day: DayReview) -> some View {
        if day.isRest {
            Image(systemName: "moon.fill")
                .font(.system(size: 10))
                .foregroundStyle(CoachColors.purple)
                .frame(width: 20, height: 20)
        } else if day.isToday {
            Circle()
                .stroke(CoachColors.accent, lineWidth: 2)
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(CoachColors.accent).frame(width: 6, height: 6))
        } else if day.sessions.isEmpty {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 20, height: 20)
        } else {
            let statuses = day.sessions.map(\.status)
            if statuses.allSatisfy({ $0 == .completed }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(CoachColors.green)
                    .frame(width: 20, height: 20)
            } else if statuses.contains(.missed) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(CoachColors.red)
                    .frame(width: 20, height: 20)
            } else if statuses.contains(.substituted) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(CoachColors.blue)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(CoachColors.yellow)
                    .frame(width: 20, height: 20)
            }
        }
    }

    // MARK: - Coach Note Card

    @ViewBuilder
    private var coachNoteCard: some View {
        if let msg = data.settings.pushMessage, !msg.text.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(coachNoteExpanded ? msg.text : truncatedNote(msg.text))
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { withAnimation { coachNoteExpanded.toggle() } }

                if !coachNoteExpanded && msg.text.count > 120 {
                    Text("Read more")
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                        .onTapGesture { withAnimation { coachNoteExpanded = true } }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
            )
        }
    }

    private func truncatedNote(_ text: String) -> String {
        if text.count <= 120 { return text }
        let end = text.index(text.startIndex, offsetBy: 120)
        return String(text[..<end]) + "…"
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if data.currentMessages.isEmpty && !isLoading {
                        newConversationGreeting
                    }
                    ForEach(Array(data.currentMessages.enumerated()), id: \.offset) { index, message in
                        MessageBubble(message: message, onCompletion: handleCompletion)
                            .id(index)
                    }
                    if isLoading {
                        HStack(spacing: 8) {
                            DotsLoader()
                            Text(loadingLabel)
                                .font(CoachFonts.ui(13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: data.currentMessages.count) {
                withAnimation { proxy.scrollTo(data.currentMessages.count - 1, anchor: .bottom) }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !data.currentMessages.isEmpty {
                        proxy.scrollTo(data.currentMessages.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var newConversationGreeting: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CoachColors.accent.opacity(0.6))
            Text("What's on your mind?")
                .font(CoachFonts.ui(14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message your coach...", text: $inputText, axis: .vertical)
                .font(CoachFonts.ui(15))
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : CoachColors.accent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Loading Label

    private var loadingLabel: String {
        if let progress = data.activeToolProgress, !progress.isEmpty { return progress }
        switch data.activeToolName {
        case "create_training_plan": return "Building your plan…"
        case "get_workouts", "get_training_stats", "get_week_review", "get_plan_history":
            return "Reviewing your data…"
        case "get_athlete_profile": return "Checking your profile…"
        case "log_workout": return "Logging workout…"
        case "log_nutrition": return "Logging nutrition…"
        case nil: return "Thinking…"
        default: return "Working…"
        }
    }

    // MARK: - Helpers

    private func todayDayIndex() -> Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private func weeksUntil(_ dateStr: String) -> Int? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days / 7)
    }

    private func consumePendingPrompt() {
        guard let prompt = data.pendingChatPrompt, !prompt.isEmpty else { return }
        inputText = prompt
        isInputFocused = true
        data.pendingChatPrompt = nil
    }

    // MARK: - Coach Note Injection

    private func injectCoachNote() async {
        guard let msg = data.settings.pushMessage, !msg.text.isEmpty else { return }
        let chatMsg = ChatMessage.assistant(
            msg.text,
            conversationId: data.currentConversation?.id
        )
        try? await data.addMessage(chatMsg)
    }

    // MARK: - HealthKit Auto-Match Drain

    private func drainAutoMatches() async {
        let matches = data.unacknowledgedAutoMatches
        guard !matches.isEmpty else { return }
        data.unacknowledgedAutoMatches.removeAll()

        for match in matches {
            let prescribed = match.session.duration ?? match.session.estimatedDurationMin ?? 0
            let isModified = prescribed > 0 && abs(match.actualDuration - prescribed) > Int(Double(prescribed) * 0.2)
            let status: CompletionStatus = isModified ? .modified : .completed

            await generateCompletionResponse(
                session: match.session, status: status, source: .healthKit,
                actualDuration: match.actualDuration, actualDistance: match.actualDistance
            )
        }
    }

    // MARK: - Send Message

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        await data.ensureActiveConversation()

        let userMsg = ChatMessage.user(text, conversationId: data.currentConversation?.id)
        try? await data.addMessage(userMsg)

        isLoading = true
        do {
            let recentSummaries = data.archivedConversations
                .prefix(3)
                .compactMap(\.summary)

            let result = try await runAgentLoop(
                personality: data.settings.personality,
                customText: data.settings.customPrompt,
                messages: data.currentMessages,
                dataService: data,
                recentConversationSummaries: recentSummaries
            )

            let assistantMsg = ChatMessage.assistant(
                result.response,
                metadata: ChatMessageMetadata(
                    logged: result.hasWorkoutLogs,
                    nutritionLogged: result.hasNutritionLogs,
                    planChanged: result.hasPlanChanges,
                    appActionTaken: result.hasAppActions
                ),
                conversationId: data.currentConversation?.id
            )
            try? await data.addMessage(assistantMsg)

            for effect in result.effects {
                switch effect {
                case .workoutLogged(let workout):
                    try? await data.addCardio(workout)
                case .cardioUpdated(let workout):
                    try? await data.updateCardio(workout)
                case .cardioDeleted(let id):
                    try? await data.deleteCardio(id)
                case .strengthDeleted(let id):
                    try? await data.deleteStrength(id)
                case .nutritionLogged(let entry):
                    try? await data.addNutrition(entry)
                case .planCreated(let plan), .planUpdated(let plan):
                    try? await data.savePlan(plan)
                case .planDeleted(let id, let history):
                    try? await data.deletePlan(id, archiveTo: history)
                case .weekUpdated(let weekNum, let weekPlan):
                    if var current = data.trainingPlan {
                        current.weeklyPlans[String(weekNum)] = weekPlan
                        try? await data.savePlan(current)
                    }
                case .progressUpdated(let week, let phase):
                    if var current = data.trainingPlan {
                        current.currentWeek = week
                        current.currentPhase = phase
                        try? await data.savePlan(current)
                    }
                case .eventCreated(let event):
                    try? await data.addEvent(event)
                case .eventUpdated(let event):
                    try? await data.updateEvent(event)
                case .eventDeleted(let id):
                    try? await data.deleteEvent(id)
                case .memoryUpdated(let memory):
                    try? await data.saveMemory(memory)
                case .settingsUpdated(let settings):
                    try? await data.saveSettings(settings)
                case .tabChanged(let tab):
                    data.selectedTab = tab
                }
            }

            Task {
                await extractMemory(
                    messages: data.currentMessages,
                    existingMemory: data.memory,
                    dataService: data
                )
            }
        } catch {
            NSLog("[chat] sendMessage failed: \(error)")
            let errorMsg = ChatMessage.assistant(
                "Sorry, I ran into an error. Please try again.\n\n\(error.localizedDescription)",
                metadata: ChatMessageMetadata(isError: true),
                conversationId: data.currentConversation?.id
            )
            try? await data.addMessage(errorMsg)
        }
        isLoading = false
    }

    // MARK: - Completion Handling

    private func handleCompletion(_ action: CompletionAction) {
        switch action {
        case .didIt(let w, let d, let s):
            Task {
                guard let session = sessionAt(weekNum: w, dayIdx: d, sessionIdx: s) else { return }
                let now = ISO8601DateFormatter().string(from: Date())
                try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                    s.completionStatus = .completed
                    s.completed = true
                    s.completionResolvedAt = now
                }
                await generateCompletionResponse(session: session, status: .completed, source: .manual)
            }
        case .modified(let w, let d, let s):
            if let session = sessionAt(weekNum: w, dayIdx: d, sessionIdx: s) {
                completionSheet = .modified(session: session, weekNum: w, dayIdx: d, sessionIdx: s)
            }
        case .swapped(let w, let d, let s):
            if let session = sessionAt(weekNum: w, dayIdx: d, sessionIdx: s) {
                completionSheet = .swapped(session: session, weekNum: w, dayIdx: d, sessionIdx: s)
            }
        case .skipped(let w, let d, let s):
            completionSheet = .skipped(weekNum: w, dayIdx: d, sessionIdx: s)
        }
    }

    private func sessionAt(weekNum: Int, dayIdx: Int, sessionIdx: Int) -> PrescribedSession? {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(weekNum)],
              dayIdx >= 0, dayIdx < wp.sessions.count,
              sessionIdx >= 0, sessionIdx < wp.sessions[dayIdx].sessions.count else { return nil }
        return wp.sessions[dayIdx].sessions[sessionIdx]
    }

    @ViewBuilder
    private func completionSheetContent(_ sheet: ChatCompletionSheet) -> some View {
        switch sheet {
        case .modified(let session, let w, let d, let s):
            ModifiedCompletionSheet(session: session) { actual in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .modified
                        s.completed = true
                        s.actualDuration = actual.duration
                        s.actualDistance = actual.distance
                        s.completionNote = actual.note.isEmpty ? nil : actual.note
                        s.completionResolvedAt = now
                    }
                    await generateCompletionResponse(
                        session: session, status: .modified, source: .manual,
                        actualDuration: actual.duration, actualDistance: actual.distance,
                        completionNote: actual.note.isEmpty ? nil : actual.note
                    )
                }
            }
            .presentationDetents([.medium])
        case .swapped(let session, let w, let d, let s):
            SwappedCompletionSheet(session: session, otherSessions: []) { actual in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .swapped
                        s.completed = true
                        s.actualSport = actual.sport
                        s.actualDuration = actual.duration
                        s.completionNote = actual.note.isEmpty ? nil : actual.note
                        s.completionResolvedAt = now
                    }
                    await generateCompletionResponse(
                        session: session, status: .swapped, source: .manual,
                        actualDuration: actual.duration, actualSport: actual.sport,
                        completionNote: actual.note.isEmpty ? nil : actual.note
                    )
                }
            }
            .presentationDetents([.medium, .large])
        case .skipped(let w, let d, let s):
            SkippedCompletionSheet { reason, note in
                Task {
                    let session = sessionAt(weekNum: w, dayIdx: d, sessionIdx: s)
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .skipped
                        s.skipReason = reason
                        s.completionNote = note.isEmpty ? nil : note
                        s.completionResolvedAt = now
                    }
                    if let session {
                        await generateCompletionResponse(
                            session: session, status: .skipped, source: .manual,
                            skipReason: reason, completionNote: note.isEmpty ? nil : note
                        )
                    }
                }
            }
            .presentationDetents([.height(340)])
        }
    }

    // MARK: - Completion Response Generation

    private func generateCompletionResponse(
        session: PrescribedSession,
        status: CompletionStatus,
        source: CompletionResponseGenerator.CompletionSource,
        actualDuration: Int? = nil,
        actualDistance: Double? = nil,
        actualSport: String? = nil,
        skipReason: SkipReason? = nil,
        completionNote: String? = nil
    ) async {
        var adherenceSummary: String?
        if let plan = data.trainingPlan,
           let adh = computeWeekAdherence(plan: plan, weekNum: plan.currentWeek, cardio: data.cardio, strength: data.strength) {
            adherenceSummary = "\(adh.completed)/\(adh.prescribed) sessions completed, \(adh.missed) missed"
        }

        var tomorrowPreview: String?
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let tomorrowIdx = todayDayIndex() + 1
            if tomorrowIdx < wp.sessions.count {
                let dp = wp.sessions[tomorrowIdx]
                if dp.isRest == true {
                    tomorrowPreview = "Rest day"
                } else if let first = dp.sessions.first {
                    tomorrowPreview = first.label
                }
            }
        }

        var phaseName: String?
        if let plan = data.trainingPlan,
           let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
            phaseName = phase.name
        }

        let context = CompletionResponseGenerator.CompletionContext(
            session: session, status: status,
            actualDuration: actualDuration, actualDistance: actualDistance,
            actualSport: actualSport, skipReason: skipReason,
            completionNote: completionNote, source: source,
            weekAdherenceSummary: adherenceSummary,
            tomorrowPreview: tomorrowPreview, phaseName: phaseName
        )

        do {
            let response = try await CompletionResponseGenerator.generate(
                context: context, personality: data.settings.personality,
                customPrompt: data.settings.customPrompt
            )
            let msg = ChatMessage.assistant(response, conversationId: data.currentConversation?.id)
            try? await data.addMessage(msg)
        } catch {
            NSLog("[completion-response] failed: \(error.localizedDescription)")
        }
    }
}
