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
                                    Text("Thinking...")
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
                logged: !result.workoutsLogged.isEmpty,
                nutritionLogged: !result.nutritionLogged.isEmpty,
                planChanged: !result.planChanges.isEmpty,
                appActionTaken: !result.appActions.isEmpty
            ))
            try? await data.addMessage(assistantMsg)

            // Process side effects
            for workout in result.workoutsLogged {
                try? await data.addCardio(workout)
            }
            for entry in result.nutritionLogged {
                try? await data.addNutrition(entry)
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
            let errorMsg = ChatMessage.assistant(
                "Sorry, I ran into an error. Please try again.",
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
                Text(message.content)
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
}
