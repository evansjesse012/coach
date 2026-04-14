import SwiftUI

// MARK: - Picker Sheet

/// Small sheet that lets the athlete pick between the chat-driven flow and the
/// full form when creating a new goal/race. Presented from GoalsTab's + button.
struct GoalCreationPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    /// Fires with the selected mode after the picker dismisses. The caller is
    /// responsible for presenting the right follow-up sheet.
    let onPick: (GoalCreationMode) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("How do you want to add it?")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                tile(
                    mode: .chat,
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Chat with Coach",
                    subtitle: "Describe your race in your own words — I'll fill in the details and ask follow-ups."
                )

                tile(
                    mode: .form,
                    icon: "doc.text.fill",
                    title: "Fill out a form",
                    subtitle: "Use the full form to set every field yourself."
                )

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Add a Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func tile(
        mode: GoalCreationMode,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            dismiss()
            onPick(mode)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
                    .frame(width: 36, height: 36)
                    .background(CoachColors.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CoachFonts.ui(15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
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
        .buttonStyle(.plain)
    }
}

enum GoalCreationMode {
    case chat
    case form
}

// MARK: - Race Creation Chat Sheet

/// Embedded chat focused on creating a single race. Keeps its own local
/// message state so it doesn't pollute the main coach transcript. Reuses
/// `runAgentLoop` + the existing system prompt, which already contains the
/// "creating a goal/race card" instructions.
struct RaceCreationChatSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isSending: Bool = false
    @State private var createdEvent: Event? = nil
    @FocusState private var inputFocused: Bool

    private let greeting = "Tell me about your next race — name, date, location, type, whatever you've got. I'll ask follow-ups if I need more, then add it to your goals."

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            MessageBubble(message: .assistant(greeting))
                                .id("greeting")

                            ForEach(Array(messages.enumerated()), id: \.offset) { idx, msg in
                                MessageBubble(message: msg)
                                    .id(idx)
                            }

                            if isSending {
                                HStack(spacing: 8) {
                                    DotsLoader()
                                    Text("Thinking…")
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
                        withAnimation {
                            proxy.scrollTo(messages.count - 1, anchor: .bottom)
                        }
                    }
                    .onChange(of: isSending) { _, new in
                        if new {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                if let event = createdEvent {
                    doneButton(for: event)
                } else {
                    inputBar
                }
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Add Race with Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                inputFocused = true
            }
        }
    }

    // MARK: - Subviews

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Tell me about your race…", text: $input, axis: .vertical)
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
                    .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : CoachColors.accent)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func doneButton(for event: Event) -> some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Done — \(event.name) added")
                    .font(CoachFonts.ui(15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CoachColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding()
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

            // Only handle event creation here — other side effects aren't in
            // scope for this focused flow. The model, guided by the system
            // prompt's race-card section, should only call app_action create
            // goal once it has enough info.
            for effect in result.effects {
                if case let .eventCreated(event) = effect {
                    try? await data.addEvent(event)
                    withAnimation { createdEvent = event }
                    break
                }
            }
        } catch {
            NSLog("[race-creation-chat] send failed: \(error)")
            messages.append(.assistant("Sorry — \(error.localizedDescription)", metadata: ChatMessageMetadata(isError: true)))
        }

        isSending = false
    }
}
