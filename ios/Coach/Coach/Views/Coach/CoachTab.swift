import SwiftUI

/// Pure chat screen. Presented as a sheet from the global FAB. Hosts the
/// simplified header, the message stream with timestamp dividers and
/// suggested replies, and the composer. The "what the coach knows" info
/// (race, phase, recent training) is surfaced via the overflow menu's
/// Coach context sheet — no persistent strip eats screen real estate.
struct CoachTab: View {
    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showHistory = false
    @State private var showContext = false
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool
    @State private var didBootstrap = false

    /// The most recent assistant message. Suggested-reply pills render only
    /// under this message, and only until the user sends any reply.
    private var latestAssistantID: Int? {
        for msg in data.currentMessages.reversed() where msg.role == "assistant" {
            return msg.id
        }
        return nil
    }
    /// Hide pills after the user has sent anything after the latest assistant
    /// message (even if the stored `suggestedReplies` array is still populated).
    private var showSuggestedRepliesForLatest: Bool {
        guard let last = data.currentMessages.last else { return false }
        return last.role == "assistant"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            messagesScroll
            composer
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await data.ensureActiveConversation()
            consumePendingPrompt()
            if !didBootstrap {
                didBootstrap = true
                await injectCoachNoteIfEmpty()
                await drainAutoMatches()
            }
        }
        .onChange(of: data.pendingChatPrompt) { _, _ in
            consumePendingPrompt()
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { ConversationHistoryView() }
        }
        .sheet(isPresented: $showContext) {
            CoachContextSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
    }

    // MARK: - Header (52pt, minimal)

    private var headerRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Left: back / dismiss
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close chat")

                Spacer(minLength: 8)

                // Center: "Coach" + availability dot
                HStack(spacing: 6) {
                    Text("Coach")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Coach available")
                }

                Spacer(minLength: 8)

                // Right: overflow menu
                Menu {
                    Button {
                        showContext = true
                    } label: {
                        Label("Coach context", systemImage: "info.circle")
                    }
                    Button {
                        showHistory = true
                    } label: {
                        Label("Message history", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Chat options")
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
        }
        .background(Theme.bg)
    }

    // MARK: - Messages scroll

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if data.currentMessages.isEmpty && !isLoading {
                    emptyState
                        .padding(.horizontal, Theme.Spacing.screenH)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        messageStreamContent
                        if isLoading {
                            loadingIndicator.id("loading")
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .onChange(of: data.currentMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var messageStreamContent: some View {
        let msgs = data.currentMessages
        ForEach(Array(msgs.enumerated()), id: \.offset) { idx, msg in
            if let dividerText = dividerText(at: idx, in: msgs) {
                ChatTimestampDivider(text: dividerText)
            }
            MessageBubble(message: msg)
                .id(idx)
                .frame(maxWidth: .infinity, alignment: msg.role == "user" ? .trailing : .leading)

            if msg.role == "assistant",
               msg.id == latestAssistantID,
               showSuggestedRepliesForLatest,
               let replies = msg.suggestedReplies, !replies.isEmpty {
                SuggestedRepliesRow(replies: replies) { reply in
                    applySuggestedReply(reply)
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Returns the text for a divider shown ABOVE the message at `idx`, or
    /// nil if no divider is warranted. First message always gets a divider
    /// (anchored on the conversation's start). Subsequent messages get one
    /// when > 30 minutes have passed or the calendar date changes vs. the
    /// previous message. Messages without a parseable timestamp skip the
    /// divider rather than guess.
    private func dividerText(at idx: Int, in msgs: [ChatMessage]) -> String? {
        let curDate = messageDate(msgs[idx])
        if idx == 0 {
            // Anchor the first divider either on the message's own timestamp
            // or the conversation's startedAt fallback.
            let anchor = curDate ?? conversationStartDate
            guard let d = anchor else { return nil }
            return chatDividerText(for: d)
        }
        guard let cur = curDate, let prev = messageDate(msgs[idx - 1]) else { return nil }
        let cal = Calendar.current
        let crossedDay = !cal.isDate(cur, inSameDayAs: prev)
        let bigGap = cur.timeIntervalSince(prev) > 30 * 60
        guard crossedDay || bigGap else { return nil }
        return chatDividerText(for: cur)
    }

    private func messageDate(_ msg: ChatMessage) -> Date? {
        guard let ts = msg.createdAt, !ts.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
    }

    private var conversationStartDate: Date? {
        guard let ts = data.currentConversation?.startedAt, !ts.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let last = data.currentMessages.indices.last {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .padding(.bottom, 2)
                .accessibilityHidden(true)
            Text("Your coach is here")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Ask anything about your training, or tell me how you're feeling today.")
                .font(Theme.Typography.bodyS)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280)
                .padding(.bottom, 10)
            SuggestedRepliesRow(replies: starterReplies) { reply in
                applySuggestedReply(reply)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private let starterReplies = [
        "How's my week looking?",
        "I'm feeling tired",
        "Can I swap a workout?",
    ]

    // MARK: - Loading indicator

    private var loadingIndicator: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 2, height: 18)
            DotsLoader()
            Text(loadingLabel)
                .font(Theme.Typography.monoMeta)
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
        }
    }

    private var loadingLabel: String {
        if let p = data.activeToolProgress, !p.isEmpty { return p }
        if let t = data.activeToolName, !t.isEmpty {
            return t.replacingOccurrences(of: "_", with: " ").capitalized + "…"
        }
        return "Thinking…"
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(alignment: .bottom) {
                TextField("Message Coach…", text: $inputText, axis: .vertical)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )

            sendButton
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var sendButton: some View {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let disabled = trimmed.isEmpty || isLoading
        return Button {
            Task { await sendMessage() }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accentInk)
                .frame(width: 36, height: 36)
                .background(disabled ? Theme.ink3 : Theme.accent)
                .clipShape(Circle())
                .shadow(color: (disabled ? Color.clear : Theme.accent.opacity(0.3)), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Suggested reply pre-fill

    private func applySuggestedReply(_ text: String) {
        inputText = text
        isInputFocused = true
    }

    // MARK: - Pending prompt / bootstrap

    private func consumePendingPrompt() {
        guard let prompt = data.pendingChatPrompt, !prompt.isEmpty else { return }
        inputText = prompt
        isInputFocused = true
        data.pendingChatPrompt = nil
    }

    private func injectCoachNoteIfEmpty() async {
        guard data.currentMessages.isEmpty,
              let msg = data.settings.pushMessage,
              !msg.text.isEmpty else { return }
        let chatMsg = ChatMessage.assistant(msg.text, conversationId: data.currentConversation?.id)
        try? await data.addMessage(chatMsg)
    }

    private func drainAutoMatches() async {
        let matches = data.unacknowledgedAutoMatches
        guard !matches.isEmpty else { return }
        data.unacknowledgedAutoMatches.removeAll()

        for match in matches {
            await generateCompletionResponse(
                session: match.session,
                status: match.detectedStatus,
                source: .healthKit,
                actualDuration: match.actualDuration,
                actualDistance: match.actualDistance
            )

            if match.detectedStatus == .swapped || match.detectedStatus == .modified {
                let description = match.detectedStatus == .swapped
                    ? "I did a different workout than prescribed — can you check if the rest of the week needs adjusting?"
                    : "My workout was significantly different from the prescription — should we adjust anything?"
                let systemMsg = ChatMessage.user(description, conversationId: data.currentConversation?.id)
                try? await data.addMessage(systemMsg)
                await sendAgentMessage(description)
            }
        }
    }

    // MARK: - Agent dispatch

    /// Sends a message through the agent loop without user input. Used by
    /// auto-match follow-up.
    private func sendAgentMessage(_ text: String) async {
        do {
            let recentSummaries = data.archivedConversations.prefix(3).compactMap(\.summary)
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
                conversationId: data.currentConversation?.id,
                suggestedReplies: result.suggestedReplies.isEmpty ? nil : result.suggestedReplies
            )
            try? await data.addMessage(assistantMsg)
            await applyAgentEffects(result.effects)
        } catch {
            NSLog("[auto-match-eval] agent call failed: \(error)")
        }
    }

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
            let recentSummaries = data.archivedConversations.prefix(3).compactMap(\.summary)
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
                conversationId: data.currentConversation?.id,
                suggestedReplies: result.suggestedReplies.isEmpty ? nil : result.suggestedReplies
            )
            try? await data.addMessage(assistantMsg)
            await applyAgentEffects(result.effects)
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

    /// Applies the agent's side-effect list to DataService. Kept separate so
    /// both sendMessage() and sendAgentMessage() can share it.
    private func applyAgentEffects(_ effects: [ToolEffect]) async {
        for effect in effects {
            switch effect {
            case .workoutLogged(let w):   try? await data.addCardio(w)
            case .cardioUpdated(let w):   try? await data.updateCardio(w)
            case .cardioDeleted(let id):  try? await data.deleteCardio(id)
            case .strengthDeleted(let id): try? await data.deleteStrength(id)
            case .nutritionLogged(let e): try? await data.addNutrition(e)
            case .planCreated(let p), .planUpdated(let p): try? await data.savePlan(p)
            case .planDeleted(let id, let h): try? await data.deletePlan(id, archiveTo: h)
            case .weekUpdated(let n, let wp):
                if var c = data.trainingPlan {
                    c.weeklyPlans[String(n)] = wp
                    try? await data.savePlan(c)
                }
            case .progressUpdated(let w, let p):
                if var c = data.trainingPlan {
                    c.currentWeek = w
                    c.currentPhase = p
                    try? await data.savePlan(c)
                }
            case .eventCreated(let e):    try? await data.addEvent(e)
            case .eventUpdated(let e):    try? await data.updateEvent(e)
            case .eventDeleted(let id):   try? await data.deleteEvent(id)
            case .memoryUpdated(let m):   try? await data.saveMemory(m)
            case .settingsUpdated(let s): try? await data.saveSettings(s)
            case .tabChanged(let t):      data.selectedTab = t
            }
        }
    }

    private func generateCompletionResponse(
        session: PrescribedSession,
        status: CompletionStatus,
        source: CompletionResponseGenerator.CompletionSource,
        actualDuration: Int? = nil,
        actualDistance: Double? = nil
    ) async {
        var adherenceSummary: String?
        if let plan = data.trainingPlan,
           let adh = computeWeekAdherence(plan: plan, weekNum: plan.currentWeek, cardio: data.cardio, strength: data.strength) {
            adherenceSummary = "\(adh.completed)/\(adh.prescribed) sessions completed, \(adh.missed) missed"
        }
        let context = CompletionResponseGenerator.CompletionContext(
            session: session,
            status: status,
            actualDuration: actualDuration,
            actualDistance: actualDistance,
            actualSport: nil,
            skipReason: nil,
            completionNote: nil,
            source: source,
            weekAdherenceSummary: adherenceSummary,
            tomorrowPreview: nil,
            phaseName: nil
        )
        do {
            let response = try await CompletionResponseGenerator.generate(
                context: context,
                personality: data.settings.personality,
                customPrompt: data.settings.customPrompt
            )
            let msg = ChatMessage.assistant(response, conversationId: data.currentConversation?.id)
            try? await data.addMessage(msg)
        } catch {
            NSLog("[auto-match] completion response failed: \(error)")
        }
    }
}
