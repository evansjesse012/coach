import SwiftUI

// MARK: - CoachBar
//
// Persistent pill anchored above the tab bar on every primary screen, the
// always-on access point to the coaching relationship. Replaces the old
// floating chat FAB. Two visual states:
//   * Resting     — neutral surface fill, "COACH" kicker, message preview,
//                   pulsing accent dot, accent mic button.
//   * NewMessage  — full accent fill, timestamp kicker, bolder preview,
//                   chevron-right; mic button hidden, dot hidden.
//
// The bar tap opens the chat. The mic button (resting only) is reserved
// for voice mode; until voice ships it falls back to opening chat too.

/// A tappable, persistent coach access point sitting above the tab bar.
struct CoachBar: View {
    /// Plain-text preview of the latest coach message. The caller is
    /// responsible for stripping markdown if desired.
    let preview: String

    /// Right-side timestamp shown only in the new-message state, e.g.
    /// "just now" / "6:14 AM" / "2h ago". Pass `nil` in resting state.
    let timestamp: String?

    /// Drives the visual state — true switches to the proactive accent
    /// treatment.
    let isUnread: Bool

    /// Tap on the bar (anywhere except the mic button).
    let onTap: () -> Void

    /// Tap on the mic button (resting state only).
    let onMic: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left affordance: pulsing dot in resting; nothing in
                // unread (the accent fill is the signal).
                Group {
                    if isUnread {
                        Color.clear.frame(width: 0, height: 0)
                    } else {
                        SignalDot(animate: !reduceMotion)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.leading, isUnread ? 18 : 18)
                .padding(.trailing, isUnread ? 0 : 12)

                // Preview block: kicker + single-line message preview.
                VStack(alignment: .leading, spacing: 3) {
                    Text(kickerText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(isUnread ? 0.04 * 11 : 0.16 * 11)
                        .foregroundStyle(kickerColor)

                    Text(preview)
                        .font(.system(size: 15, weight: isUnread ? .semibold : .medium))
                        .foregroundStyle(previewColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)

                // Right affordance: chevron in unread state, mic button
                // in resting.
                if isUnread {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accentInk.opacity(0.85))
                        .padding(.trailing, 18)
                } else {
                    micButton
                        .padding(.trailing, 8)
                }
            }
            .frame(height: 64)
            .background(barBackground)
            .clipShape(Capsule())
            .overlay(
                // Faint accent outline in resting — ties the chrome to the
                // coach brand without competing with the pulse. Cleared in
                // the unread state where the full accent fill is the
                // boundary.
                Capsule()
                    .stroke(isUnread ? Color.clear : Theme.accent.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 15, x: 0, y: 12)
        }
        .buttonStyle(BarPressStyle())
        .animation(.easeInOut(duration: 0.25), value: isUnread)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach. \(preview). Double tap to open chat.")
    }

    // MARK: - Mic button

    private var micButton: some View {
        Button(action: onMic) {
            Image(systemName: "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentInk)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Talk to coach. Double tap to start voice mode.")
    }

    // MARK: - Tokens

    private var kickerText: String {
        if isUnread, let timestamp, !timestamp.isEmpty {
            return "Coach · \(timestamp)"
        }
        return "Coach"
    }

    private var kickerColor: Color {
        isUnread ? Theme.accentInk.opacity(0.85) : Theme.ink3
    }

    private var previewColor: Color {
        isUnread ? Theme.accentInk : Theme.ink
    }

    @ViewBuilder
    private var barBackground: some View {
        if isUnread {
            Theme.accent
        } else {
            Theme.surface1
        }
    }

    private var shadowColor: Color {
        isUnread ? Theme.accent.opacity(0.35) : Color.black.opacity(0.18)
    }
}

// MARK: - Press style

/// Subtle press dim shared by the bar and (implicitly) wraps the inner
/// mic button — the mic uses `.plain` so it doesn't double-dim.
private struct BarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Signal dot
//
// Small accent dot with a heartbeat-style pulse. The inner dot oscillates
// in opacity + scale; the outer ring expands and fades, repeating. When
// Reduce Motion is on, both freeze at their resting state.

private struct SignalDot: View {
    let animate: Bool
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Outer ring: expands and fades. Always renders so layout stays
            // stable across the static / animating cases.
            Circle()
                .stroke(Theme.accent, lineWidth: 1.5)
                .scaleEffect(pulse ? 1.6 : 0.8)
                .opacity(pulse ? 0 : 0.5)

            // Inner dot: gentle pulse.
            Circle()
                .fill(Theme.accent)
                .scaleEffect(pulse ? 1.15 : 1.0)
                .opacity(pulse ? 1.0 : 0.6)
        }
        .frame(width: 8, height: 8)
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Preview helpers

extension String {
    /// Light-weight markdown stripper for the bar's single-line preview.
    /// Removes the noisy syntax (** _ ` # > links) without pulling in a
    /// real parser. Collapses whitespace into single spaces.
    func chatPreview() -> String {
        var s = self
        // Bold/italic/code markers
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        s = s.replacingOccurrences(of: "`", with: "")
        // Headings + blockquotes
        s = s.replacingOccurrences(of: #"(?m)^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?m)^\s{0,3}>\s+"#, with: "", options: .regularExpression)
        // Markdown links [text](url) → text
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        // Suggested-replies marker the chat appends — never show in preview
        s = s.replacingOccurrences(of: #"<!--sr:.*?-->"#, with: "", options: .regularExpression)
        // Collapse whitespace
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Format a chat-message timestamp for the bar kicker:
///   < 60s  →  "just now"
///   today  →  h:mm a   ("6:14 AM")
///   else   →  Nh ago   ("2h ago" / "1d ago")
func formatCoachBarTimestamp(_ iso: String?) -> String? {
    guard let iso, let date = parseChatISO(iso) else { return nil }
    let elapsed = Date().timeIntervalSince(date)
    if elapsed < 60 { return "just now" }
    if Calendar.current.isDateInToday(date) {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
    if elapsed < 3600 * 24 {
        return "\(Int(elapsed / 3600))h ago"
    }
    let days = Int(elapsed / (3600 * 24))
    return "\(days)d ago"
}

private func parseChatISO(_ s: String) -> Date? {
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: s) { return d }
    let f2 = ISO8601DateFormatter()
    f2.formatOptions = [.withInternetDateTime]
    return f2.date(from: s)
}

// MARK: - Previews

#Preview("CoachBar — Resting · Light") {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        CoachBar(
            preview: "Easy 45 min today — keep it conversational.",
            timestamp: nil,
            isUnread: false,
            onTap: {},
            onMic: {}
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    .preferredColorScheme(.light)
}

#Preview("CoachBar — Resting · Dark") {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        CoachBar(
            preview: "Easy 45 min today — keep it conversational.",
            timestamp: nil,
            isUnread: false,
            onTap: {},
            onMic: {}
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    .preferredColorScheme(.dark)
}

#Preview("CoachBar — New message · Light") {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        CoachBar(
            preview: "Quick note on tomorrow's tempo — let's tweak the pace.",
            timestamp: "just now",
            isUnread: true,
            onTap: {},
            onMic: {}
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    .preferredColorScheme(.light)
}

#Preview("CoachBar — New message · Dark") {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        CoachBar(
            preview: "Quick note on tomorrow's tempo — let's tweak the pace.",
            timestamp: "2h ago",
            isUnread: true,
            onTap: {},
            onMic: {}
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    .preferredColorScheme(.dark)
}

#Preview("CoachBar — State transition") {
    StateTransitionPreview()
}

private struct StateTransitionPreview: View {
    @State private var unread = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Button("Toggle state (currently \(unread ? "new" : "resting"))") {
                    unread.toggle()
                }
                .padding()
                CoachBar(
                    preview: "Quick note on tomorrow's tempo — let's tweak the pace.",
                    timestamp: unread ? "just now" : nil,
                    isUnread: unread,
                    onTap: {},
                    onMic: {}
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }
}
