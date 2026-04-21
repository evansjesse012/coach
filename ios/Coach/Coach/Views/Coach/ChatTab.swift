import SwiftUI

struct ChatTab: View {
    @Environment(DataService.self) var data
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool

    // Completion sheet state (for workout cards in chat)
    @State private var completionSheet: ChatCompletionSheet?

    var body: some View {
        VStack(spacing: 0) {
            // Messages — scoped to the current conversation only
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
                    withAnimation {
                        proxy.scrollTo(data.currentMessages.count - 1, anchor: .bottom)
                    }
                }
                .onAppear {
                    // Scroll to the latest message when the chat opens
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
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                ConversationHistoryView()
            }
        }
        .sheet(item: $completionSheet) { sheet in
            completionSheetContent(sheet)
        }
        .task {
            // Ensure we have an active (non-stale) conversation when
            // the chat opens. Stale conversations are archived and a
            // fresh one starts.
            await data.ensureActiveConversation()
        }
        .onAppear {
            consumePendingPrompt()
        }
        .onChange(of: data.pendingChatPrompt) { _, _ in
            consumePendingPrompt()
        }
    }

    // MARK: - New conversation greeting

    private var newConversationGreeting: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CoachColors.accent, CoachColors.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("New conversation")
                .font(CoachFonts.ui(16, weight: .bold))
                .foregroundStyle(.primary)
            Text("Your coach remembers your training history, injuries, and preferences. What's on your mind?")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Loading label

    private var loadingLabel: String {
        if let progress = data.activeToolProgress, !progress.isEmpty {
            return progress
        }
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

    // MARK: - Send Message

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        // Ensure active conversation before first message
        await data.ensureActiveConversation()

        let userMsg = ChatMessage.user(text, conversationId: data.currentConversation?.id)
        try? await data.addMessage(userMsg)

        isLoading = true
        do {
            // Build recent conversation summaries for context continuity
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

            // Apply typed side effects from the agent loop
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

            // Background memory extraction — only on current conversation
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
                let now = ISO8601DateFormatter().string(from: Date())
                try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { session in
                    session.completionStatus = .completed
                    session.completed = true
                    session.completionResolvedAt = now
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
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { session in
                        session.completionStatus = .modified
                        session.completed = true
                        session.actualDuration = actual.duration
                        session.actualDistance = actual.distance
                        session.completionNote = actual.note.isEmpty ? nil : actual.note
                        session.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.medium])
        case .swapped(let session, let w, let d, let s):
            SwappedCompletionSheet(session: session, otherSessions: []) { actual in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { session in
                        session.completionStatus = .swapped
                        session.completed = true
                        session.actualSport = actual.sport
                        session.actualDuration = actual.duration
                        session.completionNote = actual.note.isEmpty ? nil : actual.note
                        session.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.medium, .large])
        case .skipped(let w, let d, let s):
            SkippedCompletionSheet { reason, note in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { session in
                        session.completionStatus = .skipped
                        session.skipReason = reason
                        session.completionNote = note.isEmpty ? nil : note
                        session.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.height(340)])
        }
    }
}

// MARK: - Chat Completion Sheet

enum ChatCompletionSheet: Identifiable {
    case modified(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case swapped(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case skipped(weekNum: Int, dayIdx: Int, sessionIdx: Int)

    var id: String {
        switch self {
        case .modified(_, let w, let d, let s): return "modified-\(w)-\(d)-\(s)"
        case .swapped(_, let w, let d, let s): return "swapped-\(w)-\(d)-\(s)"
        case .skipped(let w, let d, let s): return "skipped-\(w)-\(d)-\(s)"
        }
    }
}

// MARK: - Conversation History View

/// Shows archived conversations with their summaries. Tapping opens
/// the transcript read-only.
struct ConversationHistoryView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            if data.archivedConversations.isEmpty {
                ContentUnavailableView(
                    "No Past Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Your past conversations with the coach will appear here.")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(data.archivedConversations) { convo in
                        NavigationLink {
                            ArchivedConversationView(conversation: convo)
                        } label: {
                            conversationRow(convo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Past Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func conversationRow(_ convo: Conversation) -> some View {
        CoachCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(formatConversationDate(convo.startedAt))
                    .font(CoachFonts.ui(12, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
                if let summary = convo.summary, !summary.isEmpty {
                    Text(summary)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No summary available")
                        .font(CoachFonts.ui(13))
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatConversationDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        let display = DateFormatter()
        display.doesRelativeDateFormatting = true
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
}

// MARK: - Archived Conversation View

/// Read-only transcript of an archived conversation.
struct ArchivedConversationView: View {
    let conversation: Conversation
    @Environment(DataService.self) var data

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messages: [ChatMessage] {
        data.messagesForConversation(conversation.id)
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: conversation.startedAt) else { return "Conversation" }
        let display = DateFormatter()
        display.dateFormat = "MMM d, h:mm a"
        return display.string(from: date)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    var onCompletion: ((CompletionAction) -> Void)?

    @Environment(\.colorScheme) var colorScheme

    private var hasRichContent: Bool {
        message.richContent != nil && !(message.richContent!.isEmpty)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 48) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                // Text bubble (skip if content is empty and we have rich content)
                if !message.content.isEmpty {
                    Text(renderedContent)
                        .font(CoachFonts.ui(14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == "user"
                                ? CoachColors.accent
                                : (colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightElevated)
                        )
                        .foregroundStyle(message.role == "user" ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Rich content components
                if let components = message.richContent {
                    ForEach(components) { component in
                        RichComponentView(component: component, onCompletion: onCompletion)
                    }
                }

                // Side-effect indicators
                if let meta = message.metadata {
                    HStack(spacing: 6) {
                        if meta.logged == true {
                            Label("Logged", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(CoachColors.green)
                        }
                        if meta.planChanged == true {
                            Label("Plan updated", systemImage: "calendar.badge.checkmark")
                                .foregroundStyle(CoachColors.cyan)
                        }
                    }
                    .font(CoachFonts.ui(11))
                }
            }

            // Full-width for assistant messages with rich content
            if message.role == "assistant" && !hasRichContent { Spacer(minLength: 48) }
        }
    }

    private var renderedContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let parsed = try? AttributedString(markdown: message.content, options: options) {
            return parsed
        }
        return AttributedString(message.content)
    }
}
