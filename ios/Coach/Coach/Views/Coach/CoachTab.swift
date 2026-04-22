import SwiftUI

/// Pure chat screen. In the new nav this is presented as a sheet from the
/// global FAB — there is no tab-resident dashboard anymore.
struct CoachTab: View {
    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    @State private var didBootstrap = false

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            programContextStrip
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
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)

            avatarCircle

            VStack(alignment: .leading, spacing: 2) {
                Text("Coach")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Direct · Data-backed")
                    .font(Theme.Typography.monoLabelS)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }

            Spacer(minLength: 0)

            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var avatarCircle: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.accent, Theme.accentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            Text("C")
                .font(Theme.Typography.mono(14, weight: .semibold))
                .foregroundStyle(Theme.accentInk)
        }
    }

    // MARK: - Program context strip

    private var programContextStrip: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline) {
                Text(leftContext)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let phase = rightContext {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                        Text(phase)
                            .font(Theme.Typography.monoLabel)
                            .foregroundStyle(Theme.accent)
                            .textCase(.uppercase)
                            .tracking(Theme.Tracking.monoLabel)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.vertical, 10)
            Hairline()
        }
    }

    private var leftContext: String {
        guard let plan = data.trainingPlan else { return "No active plan" }
        var parts: [String] = []
        if let name = plan.raceName, !name.isEmpty {
            parts.append(name)
        }
        parts.append("Wk \(plan.currentWeek) / \(plan.totalWeeks)")
        return parts.joined(separator: " · ")
    }

    private var rightContext: String? {
        data.trainingPlan?.current?.name
    }

    // MARK: - Messages scroll

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if data.currentMessages.isEmpty && !isLoading {
                        emptyState.padding(.top, 60)
                    }
                    ForEach(Array(data.currentMessages.enumerated()), id: \.offset) { idx, msg in
                        MessageBubble(message: msg)
                            .id(idx)
                            .frame(maxWidth: .infinity, alignment: msg.role == "user" ? .trailing : .leading)
                    }
                    if isLoading {
                        loadingIndicator.id("loading")
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.vertical, 20)
            }
            .onChange(of: data.currentMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.accent)
            Text("What's on your mind?")
                .font(Theme.Typography.sessionTitle)
                .foregroundStyle(Theme.ink)
            Text("Ask about today's session, request a plan change, or log a workout.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

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
                TextField("Message your coach…", text: $inputText, axis: .vertical)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .focused($isInputFocused)
                    .lineLimit(1...6)
                    .submitLabel(.send)
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
                conversationId: data.currentConversation?.id
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
                conversationId: data.currentConversation?.id
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
