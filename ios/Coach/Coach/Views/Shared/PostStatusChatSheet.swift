import SwiftUI

/// Lightweight "what changed?" sheet surfaced after a session gets marked
/// modified / swapped / skipped — either from the compact status menu on
/// a session card, or from an Apple Watch match confirmation that lands
/// on a non-done status.
///
/// Saves a free-form note to the prescribed session's `completionNote`
/// and, when `postToChat` is true, queues the note as a user message in
/// the coach thread (via `DataService.pendingChatPrompt`) so the coach
/// has context on next turn.
struct PostStatusChatSheet: View {
    let sessionLabel: String
    let status: Theme.SessionStatusKind
    /// The `weekNum`, `dayIdx`, `sessionIdx` of the session being
    /// annotated — passed through to `updateSessionCompletion` so the
    /// save hits the same canonical write path as everything else.
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int

    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss

    @State private var note: String = ""
    @State private var isSaving = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                contextBlock
                promptBlock
                noteField
                Spacer(minLength: 0)
                actionBar
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(Theme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .frame(width: 30, height: 30)
                            .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close without saving")
                }
            }
            .onAppear {
                // Focus the note field so the keyboard comes up immediately —
                // the user just picked a status, they know what they're
                // writing about.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    noteFocused = true
                }
            }
        }
    }

    // MARK: - Subviews

    private var contextBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(status.tint)
                Text(status.label.uppercased())
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(status.tint)
                    .tracking(Theme.Tracking.monoLabel)
            }
            Text(sessionLabel)
                .font(Theme.Typography.sessionTitle)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var promptBlock: some View {
        Text(promptCopy)
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Status-specific prompt. The chat message going to the coach is
    /// the user's reply to this question, so the phrasing should scope
    /// the answer appropriately. For `done`, ask the same kind of
    /// follow-up a real coach would — how it felt, any pain, energy,
    /// soreness — so the LLM has texture beyond the green tick.
    private var promptCopy: String {
        switch status {
        case .done:     return "Nice. How did it feel? Anything worth flagging — pace, effort, pain, energy?"
        case .modified: return "Got it. What did you change about the session?"
        case .swapped:  return "Tell me about the swap — what did you do instead?"
        case .skipped:  return "No stress. What got in the way today?"
        case .pending:  return "Anything you want to tell your coach?"
        }
    }

    private var noteField: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )

            if note.isEmpty {
                Text("Type your answer…")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $note)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .focused($noteFocused)

            // Mic button is a placeholder for the Phase 6 speech-to-text
            // feature — intentionally disabled + muted so the affordance
            // is visible but clearly inert.
            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Button {} label: {
                        Image(systemName: "mic")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.ink3)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.surface2))
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.5)
                    .accessibilityLabel("Voice input (coming soon)")
                }
            }
            .padding(10)
        }
        .frame(minHeight: 160, maxHeight: 220)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Pill(title: isSaving ? "Saving…" : "Save", variant: .primary) {
                Task { await save() }
            }
            .disabled(isSaving || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((isSaving || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1)
        }
    }

    // MARK: - Save

    private func save() async {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        // 1. Persist the note onto the prescribed session.
        do {
            try await data.updateSessionCompletion(
                weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
            ) { s in
                s.completionNote = trimmed
            }
        } catch {
            print("PostStatusChatSheet.save (completionNote) failed: \(error)")
        }

        // 2. Queue the note as a user message so the coach thread picks
        //    it up next time the chat opens. Framed with status + session
        //    name so the coach has context without the user retyping it.
        let statusWord = status.label.lowercased()
        let framed = "I marked \"\(sessionLabel)\" as \(statusWord). \(trimmed)"
        data.pendingChatPrompt = framed

        dismiss()
    }
}