import SwiftUI

struct ChatTab: View {
    @Environment(DataService.self) var data
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(data.messages.enumerated()), id: \.offset) { index, message in
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
                    .onChange(of: data.messages.count) {
                        withAnimation {
                            proxy.scrollTo(data.messages.count - 1, anchor: .bottom)
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
        }
        .onAppear {
            consumePendingPrompt()
        }
        .onChange(of: data.pendingChatPrompt) { _, _ in
            consumePendingPrompt()
        }
    }

    private var loadingLabel: String {
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

        let userMsg = ChatMessage.user(text)
        try? await data.addMessage(userMsg)

        isLoading = true
        do {
            let result = try await runAgentLoop(
                personality: data.settings.personality,
                customText: data.settings.customPrompt,
                messages: data.messages,
                dataService: data
            )

            let assistantMsg = ChatMessage.assistant(result.response, metadata: ChatMessageMetadata(
                logged: result.hasWorkoutLogs,
                nutritionLogged: result.hasNutritionLogs,
                planChanged: result.hasPlanChanges,
                appActionTaken: result.hasAppActions
            ))
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

            // Background memory extraction
            Task {
                await extractMemory(
                    messages: data.messages,
                    existingMemory: data.memory,
                    dataService: data
                )
            }
        } catch {
            NSLog("[chat] sendMessage failed: \(error)")
            let errorMsg = ChatMessage.assistant(
                "Sorry, I ran into an error. Please try again.\n\n\(error.localizedDescription)",
                metadata: ChatMessageMetadata(isError: true)
            )
            try? await data.addMessage(errorMsg)
        }
        isLoading = false
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 48) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
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

            if message.role == "assistant" { Spacer(minLength: 48) }
        }
    }

    /// Parse the message as inline markdown so **bold**, *italic*, `code`,
    /// and [links](url) render properly. Line breaks are preserved. Falls back
    /// to the raw string if parsing fails.
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
