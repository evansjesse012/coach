import SwiftUI

/// The primary tab — full dashboard with tappable cards. Chat opens as
/// a floating modal overlay via the coach button.
struct CoachTab: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @State private var showSettings = false
    @State private var showCoachChat = false
    @State private var completionSheet: ChatCompletionSheet?
    @State private var coachNoteExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    raceCountdownCard
                    coachNoteCard
                    todayWorkoutCards
                    weekSummaryCard
                    tomorrowPreviewCard
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingCoachButton { showCoachChat = true }
                    .padding(.trailing, 18)
                    .padding(.bottom, 16)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(isPresented: $showCoachChat) {
                NavigationStack {
                    CoachChatSheet()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    showCoachChat = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $completionSheet) { sheet in
                completionSheetContent(sheet)
            }
        }
        .task {
            await data.ensurePlanPreGenerated()
        }
        .onAppear {
            // If there's a pending chat prompt, open the chat sheet
            if data.pendingChatPrompt != nil {
                showCoachChat = true
            }
        }
        .onChange(of: data.pendingChatPrompt) { _, newVal in
            if newVal != nil { showCoachChat = true }
        }
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RACE DAY")
                            .font(CoachFonts.mono(10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(event.name)
                            .font(CoachFonts.display(18, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
                            Text("Week \(plan.currentWeek)/\(plan.totalWeeks) \u{00B7} \(phase.name)")
                                .font(CoachFonts.ui(12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(weeksOut)")
                            .font(CoachFonts.display(32, weight: .bold))
                            .foregroundStyle(CoachColors.accent)
                        Text("weeks")
                            .font(CoachFonts.mono(10, weight: .semibold))
                            .foregroundStyle(CoachColors.accent)
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [CoachColors.accent.opacity(0.1), CoachColors.accent.opacity(0.03)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(CoachColors.accent.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Coach Note Card

    @ViewBuilder
    private var coachNoteCard: some View {
        if let msg = data.settings.pushMessage, !msg.text.isEmpty {
            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(coachNoteExpanded ? msg.text : truncatedNote(msg.text))
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !coachNoteExpanded && msg.text.count > 150 {
                        Button {
                            withAnimation { coachNoteExpanded = true }
                        } label: {
                            Text("Read more")
                                .font(CoachFonts.ui(12, weight: .semibold))
                                .foregroundStyle(CoachColors.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Action buttons
                    if let actions = msg.actions, !actions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(actions.prefix(3)), id: \.self) { action in
                                    Button {
                                        data.pendingChatPrompt = action
                                        showCoachChat = true
                                    } label: {
                                        Text(action)
                                            .font(CoachFonts.ui(12, weight: .semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(CoachColors.accent.opacity(0.15)))
                                            .foregroundStyle(CoachColors.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .onTapGesture {
                if coachNoteExpanded {
                    withAnimation { coachNoteExpanded = false }
                }
            }
        }
    }

    private func truncatedNote(_ text: String) -> String {
        if text.count <= 150 { return text }
        let end = text.index(text.startIndex, offsetBy: 150)
        return String(text[..<end]) + "…"
    }

    // MARK: - Today's Workout Cards

    @ViewBuilder
    private var todayWorkoutCards: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let dayIdx = todayDayIndex()
            if dayIdx < wp.sessions.count {
                let dayPlan = wp.sessions[dayIdx]

                CoachLabel(text: "Today's Focus")

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
        CoachCard {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(CoachColors.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Day")
                        .font(CoachFonts.ui(15, weight: .semibold))
                    Text("Recovery is part of the plan")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Week Summary Card

    @ViewBuilder
    private var weekSummaryCard: some View {
        if let plan = data.trainingPlan,
           let adherence = computeWeekAdherence(
               plan: plan, weekNum: plan.currentWeek,
               cardio: data.cardio, strength: data.strength
           ) {
            CoachLabel(text: "This Week")

            NavigationLink {
                WeekDetailView(initialWeekNum: plan.currentWeek)
            } label: {
                CoachCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Week \(plan.currentWeek)")
                                .font(CoachFonts.display(16, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 6) {
                            ForEach(Array(adherence.days.enumerated()), id: \.offset) { _, day in
                                dashboardDot(for: day)
                            }
                            Spacer()
                        }

                        HStack(spacing: 14) {
                            Text("SESSIONS \(adherence.completed)/\(adherence.prescribed)")
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("ADHERENCE \(adherence.adherence)%")
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(adherence.adherence >= 75 ? CoachColors.green : .secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dashboardDot(for day: DayReview) -> some View {
        if day.isRest {
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundStyle(CoachColors.purple)
                .frame(width: 24, height: 24)
        } else if day.isToday {
            Circle()
                .stroke(CoachColors.accent, lineWidth: 2)
                .frame(width: 24, height: 24)
                .overlay(Circle().fill(CoachColors.accent).frame(width: 8, height: 8))
        } else if day.sessions.isEmpty {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 24, height: 24)
        } else {
            let statuses = day.sessions.map(\.status)
            if statuses.allSatisfy({ $0 == .completed }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CoachColors.green)
                    .frame(width: 24, height: 24)
            } else if statuses.contains(.missed) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CoachColors.red)
                    .frame(width: 24, height: 24)
            } else if statuses.contains(.substituted) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CoachColors.blue)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CoachColors.yellow)
                    .frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - Tomorrow Preview

    @ViewBuilder
    private var tomorrowPreviewCard: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let tomorrowIdx = todayDayIndex() + 1
            if tomorrowIdx < wp.sessions.count {
                let dayPlan = wp.sessions[tomorrowIdx]
                if let session = dayPlan.sessions.first {
                    CoachLabel(text: "Up Next \u{00B7} Tomorrow")
                    NavigationLink {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        let fmt = DateFormatter()
                        let _ = fmt.dateFormat = "yyyy-MM-dd"
                        PrescribedSessionDetailView(session: session, dateString: fmt.string(from: tomorrow))
                    } label: {
                        CoachCard {
                            HStack(spacing: 10) {
                                let effort = session.effortCategory ?? .easy
                                effort.gradient
                                    .frame(width: 4)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                                VStack(alignment: .leading, spacing: 2) {
                                    if let sport = Sport(rawValue: session.type.lowercased()) {
                                        SportBadge(sport: sport)
                                    }
                                    Text(session.label)
                                        .font(CoachFonts.ui(14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let d = session.duration ?? session.estimatedDurationMin {
                                    Text(formatDuration(d))
                                        .font(CoachFonts.mono(13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
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
                }
            }
            .presentationDetents([.medium, .large])
        case .skipped(let w, let d, let s):
            SkippedCompletionSheet { reason, note in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .skipped
                        s.skipReason = reason
                        s.completionNote = note.isEmpty ? nil : note
                        s.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.height(340)])
        }
    }
}

// MARK: - Floating Coach Button

struct FloatingCoachButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CoachColors.accent, CoachColors.accent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: CoachColors.accent.opacity(0.35), radius: 10, y: 4)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coach Chat Sheet

/// The chat interface presented as a modal sheet. Owns conversation
/// management, message sending, and completion response generation.
struct CoachChatSheet: View {
    @Environment(DataService.self) var data
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if data.currentMessages.isEmpty && !isLoading {
                            newConversationGreeting
                        }
                        ForEach(Array(data.currentMessages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
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

            Divider()

            // Input bar
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
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { ConversationHistoryView() }
        }
        .task {
            await data.ensureActiveConversation()
            if data.currentMessages.isEmpty {
                await injectCoachNote()
            }
            await drainAutoMatches()
        }
        .onAppear { consumePendingPrompt() }
        .onChange(of: data.pendingChatPrompt) { _, _ in consumePendingPrompt() }
    }

    // MARK: - Greeting

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

    private func consumePendingPrompt() {
        guard let prompt = data.pendingChatPrompt, !prompt.isEmpty else { return }
        inputText = prompt
        isInputFocused = true
        data.pendingChatPrompt = nil
    }

    private func injectCoachNote() async {
        guard let msg = data.settings.pushMessage, !msg.text.isEmpty else { return }
        let chatMsg = ChatMessage.assistant(msg.text, conversationId: data.currentConversation?.id)
        try? await data.addMessage(chatMsg)
    }

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
            let tomorrowIdx = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
            if tomorrowIdx < wp.sessions.count {
                let dp = wp.sessions[tomorrowIdx]
                if dp.isRest == true { tomorrowPreview = "Rest day" }
                else if let first = dp.sessions.first { tomorrowPreview = first.label }
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
