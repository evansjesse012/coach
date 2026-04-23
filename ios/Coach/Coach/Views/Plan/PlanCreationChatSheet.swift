import SwiftUI

/// Embedded chat for building a training plan. Stays on the Plan tab (no
/// navigation to the Coach tab), uses a focused local message array so it
/// doesn't clutter the main coach transcript, and defers to the existing
/// PLAN CREATION section of the main system prompt — the coach already
/// knows the right questions to ask and when to call create_training_plan.
///
/// The sheet optionally takes a preselected goal id. When set, the greeting
/// is seeded with that race's name and timeline so the athlete sees "Let's
/// build your plan for Big Sur Marathon — about 16 weeks out. How many days
/// a week…" instead of a blank "what's your race?" prompt. When no goal is
/// preselected, the coach discovers it via get_goals on the first turn.
struct PlanCreationChatSheet: View {
    /// Optional pre-selected goal id. nil means no specific race was chosen
    /// when opening the sheet.
    let preselectedGoalId: String?

    init(preselectedGoalId: String? = nil) {
        self.preselectedGoalId = preselectedGoalId
    }

    @Environment(\.dismiss) var dismiss
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    // Full message array sent to the API. Index 0 is a synthetic setup
    // message that the UI hides — it gives the coach the context it needs
    // to open the conversation without making the athlete retype the race
    // name. Index 1 is the seeded coach greeting that opens the chat.
    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isSending: Bool = false
    @State private var createdPlan: TrainingPlan? = nil
    @State private var initializedOnce = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Skip the synthetic index-0 setup message when rendering.
                            ForEach(Array(messages.enumerated()).dropFirst(), id: \.offset) { idx, msg in
                                MessageBubble(message: msg)
                                    .id(idx)
                            }
                            if isSending {
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
                    .onChange(of: messages.count) {
                        withAnimation { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                    }
                    .onChange(of: isSending) { _, new in
                        if new {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                    .onChange(of: data.activeToolProgress) { _, _ in
                        if isSending {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                if let plan = createdPlan {
                    doneButton(for: plan)
                } else if hasEligibleGoal {
                    inputBar
                } else {
                    noGoalState
                }
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Build Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                guard !initializedOnce else { return }
                initializedOnce = true
                seedMessages()
                inputFocused = hasEligibleGoal
            }
        }
    }

    // MARK: - Seed

    /// Build the opening user/assistant message pair from the current state.
    /// The synthetic user message at index 0 is invisible in the UI but gives
    /// the coach the context it needs to open the conversation.
    private func seedMessages() {
        let target: Event? = {
            if let p = preselectedEvent { return p }
            if activeEvents.count == 1 { return activeEvents.first }
            return nil
        }()

        if let event = target {
            let datePart = event.date.map { " on \(formatDateShort($0))" } ?? ""
            let weeksPhrase = weeksUntilString(event)
            let weeksClause = weeksPhrase.map { " — \($0)" } ?? ""
            let setupWeeksClause = weeksPhrase.map { " (\($0))" } ?? ""

            messages = [
                .user("Let's build my training plan for \(event.name)\(setupWeeksClause). Ask me up to 3 questions (days/week, long-run day, strength days), then call create_training_plan. Use the auto-computed plan length — don't ask how many weeks."),
                .assistant("Let's build your plan for \(event.name)\(datePart)\(weeksClause). How many days a week can you train, and do you prefer Saturday or Sunday for your long run?"),
            ]
        } else if activeEvents.count > 1 {
            let names = activeEvents.map(\.name).joined(separator: ", ")
            messages = [
                .user("Let's build my training plan. Active goals on my list: \(names). Ask me which one first, then ask up to 3 follow-ups (days/week, long-run day, strength days), then call create_training_plan."),
                .assistant("I see a few active goals — \(names). Which one are we building around?"),
            ]
        }
        // No active events: messages stays empty, noGoalState renders instead.
    }

    // MARK: - Subviews

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Your answer…", text: $input, axis: .vertical)
                .font(CoachFonts.ui(15))
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.ink3.opacity(0.4) : Theme.accent)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func doneButton(for plan: TrainingPlan) -> some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan saved")
                        .font(CoachFonts.ui(15, weight: .semibold))
                    Text("\(plan.totalWeeks)-week plan · week 1 ready")
                        .font(CoachFonts.ui(11))
                        .opacity(0.9)
                }
                Spacer()
                Text("View plan →")
                    .font(CoachFonts.ui(13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(CoachColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding()
    }

    private var noGoalState: some View {
        VStack(spacing: 14) {
            Text("You need to add a race before I can build a plan.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                dismiss()
                data.selectedTab = "goals"
            } label: {
                Label("Add a race", systemImage: "plus.circle.fill")
                    .font(CoachFonts.ui(14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(CoachColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var activeEvents: [Event] {
        data.events.filter { !$0.completed }
    }

    private var preselectedEvent: Event? {
        guard let id = preselectedGoalId else { return nil }
        return data.events.first { $0.id == id }
    }

    private var hasEligibleGoal: Bool {
        !activeEvents.isEmpty
    }

    private func weeksUntilString(_ event: Event) -> String? {
        guard let dateStr = event.date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: dateStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
        guard days > 0 else { return nil }
        let weeks = Int(ceil(Double(days) / 7.0))
        return "about \(weeks) weeks out"
    }

    /// Surface the real `activeToolProgress` string during plan generation
    /// so the athlete sees "Generating week 1 of 16…" in the loading bubble
    /// instead of a flat "Thinking…".
    private var loadingLabel: String {
        if let progress = data.activeToolProgress, !progress.isEmpty {
            return progress
        }
        switch data.activeToolName {
        case "create_training_plan": return "Building your plan…"
        case "get_athlete_profile": return "Checking your profile…"
        case "get_goals": return "Looking up your goals…"
        default: return "Thinking…"
        }
    }

    // MARK: - Send

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        inputFocused = false

        messages.append(.user(text))
        isSending = true

        do {
            let result = try await runAgentLoop(
                personality: data.settings.personality,
                customText: data.settings.customPrompt,
                messages: messages,
                dataService: data
            )

            messages.append(.assistant(result.response))

            // Only handle effects relevant to the plan-building flow.
            for effect in result.effects {
                switch effect {
                case .planCreated(let plan), .planUpdated(let plan):
                    try? await data.savePlan(plan)
                    withAnimation { createdPlan = plan }
                case .memoryUpdated(let memory):
                    try? await data.saveMemory(memory)
                default:
                    break
                }
            }
        } catch {
            NSLog("[plan-creation-chat] send failed: \(error)")
            messages.append(.assistant(
                "Sorry — \(error.localizedDescription)",
                metadata: ChatMessageMetadata(isError: true)
            ))
        }

        isSending = false
    }
}
