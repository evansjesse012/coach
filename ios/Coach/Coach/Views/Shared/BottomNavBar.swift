import SwiftUI

// MARK: - Tab-reselect plumbing
//
// Broadcast when the user taps the tab they're already on. Each tab
// listens for its own id and pops its NavigationStack to root — the
// native TabView behavior the anchored custom bar has to reimplement.

extension Notification.Name {
    static let popTabToRoot = Notification.Name("coach.popTabToRoot")
}

extension View {
    /// Pops the enclosing NavigationStack to root when the user taps
    /// the tab matching `tabId` while already on it. Each tab owns its
    /// own `@State var path = NavigationPath()` and applies this
    /// modifier.
    ///
    /// Clearing `path` alone isn't reliable: closure-style
    /// NavigationLinks (`NavigationLink { Destination() } label: { ... }`)
    /// don't always sync their pushes into the bound path, so
    /// `path = NavigationPath()` can be a no-op while the pushed
    /// destination stays on screen. To guarantee the pop we also flip
    /// a rebuild id on the modified view, which forces SwiftUI to
    /// recreate the NavigationStack and unmount anything pushed on
    /// top of root.
    func popsOnTabReselect(tabId: String, path: Binding<NavigationPath>) -> some View {
        modifier(PopsOnTabReselect(tabId: tabId, path: path))
    }
}

private struct PopsOnTabReselect: ViewModifier {
    let tabId: String
    let path: Binding<NavigationPath>
    @State private var rootID = UUID()

    func body(content: Content) -> some View {
        content
            .id(rootID)
            .onReceive(NotificationCenter.default.publisher(for: .popTabToRoot)) { notif in
                guard let id = notif.object as? String, id == tabId else { return }
                path.wrappedValue = NavigationPath()
                rootID = UUID()
            }
    }
}

// MARK: - Bottom nav bar

/// Two-container bottom nav inspired by Whoop: a primary nav holding
/// four tab buttons (Today, Week, Plan, More), plus a separate Coach
/// container sitting to the right with a ~10pt gap. Both containers
/// share `surface1` fill, 1pt `line` border, 24pt corner radius, and
/// 6pt internal padding so they align on the same vertical baseline.
///
/// The Coach container hosts a circular outlined button with the
/// chat-bubble glyph centered inside, and a small accent dot in the
/// top-right corner when there's an unread assistant message. No
/// pulse — calm and omnipresent.
///
/// When `selection` doesn't match any of the four primary tab ids
/// (e.g. the user is on a More-only page like Goals / Log / Stats /
/// Settings), no tab shows the active accent — those destinations
/// live outside the primary nav.
struct BottomNavBar: View {
    struct Item: Identifiable, Hashable {
        let id: String
        let icon: String       // SF Symbol
        let label: String
    }

    let items: [Item]
    @Binding var selection: String
    /// Tapping the Coach button. Caller opens the chat sheet.
    var onCoachTap: () -> Void
    /// Tapping the More tab. Caller opens the More sheet — More itself
    /// does NOT set `selection`, since it has no tab content and never
    /// shows the active state.
    var onMoreTap: () -> Void
    /// Called when the user taps the tab that is already selected.
    /// Caller pops the current tab's NavigationStack to root.
    var onReselect: ((String) -> Void)? = nil
    /// Renders a small accent dot in the top-right of the Coach circle
    /// when true. Preserves the unread visualization from the old
    /// CoachBar.
    var coachUnread: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            primaryContainer
                .frame(maxWidth: .infinity)
            coachContainer
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Containers

    private var primaryContainer: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                cell(item)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(6)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var coachContainer: some View {
        coachButton
            .padding(6)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }

    // MARK: - Cells

    /// Active state derives from selection match. The "more" cell is
    /// special-cased: it never sets selection and so never lights up,
    /// reinforcing that it's a sheet trigger, not a tab destination.
    @ViewBuilder
    private func cell(_ item: Item) -> some View {
        let active = (item.id == selection)
        Button {
            if item.id == "more" {
                onMoreTap()
                return
            }
            if selection == item.id {
                onReselect?(item.id)
            } else {
                selection = item.id
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .regular))
                Text(item.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(-0.05)
            }
            .foregroundStyle(active ? Theme.accent : Theme.ink3)
            .animation(.easeOut(duration: 0.2), value: active)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var coachButton: some View {
        Button(action: onCoachTap) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .strokeBorder(Theme.accent, lineWidth: 1.5)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Theme.accent)
                    )
                if coachUnread {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(Theme.surface1, lineWidth: 1.5)
                        )
                        .offset(x: 2, y: -2)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(coachUnread ? "Coach, new message" : "Coach")
    }
}

// MARK: - Preview

private struct BottomNavBarPreviewHost: View {
    @State var selection: String
    @State var coachUnread: Bool
    let scheme: ColorScheme

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack {
                Spacer()
                Text("selected: \(selection)")
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(
                items: [
                    .init(id: "today", icon: "house",                     label: "Today"),
                    .init(id: "week",  icon: "calendar.day.timeline.left", label: "Week"),
                    .init(id: "plan",  icon: "calendar",                  label: "Plan"),
                    .init(id: "more",  icon: "line.3.horizontal",         label: "More"),
                ],
                selection: $selection,
                onCoachTap: {},
                onMoreTap: {},
                coachUnread: coachUnread
            )
        }
        .preferredColorScheme(scheme)
    }
}

#Preview("Bottom nav — Light, Today")  { BottomNavBarPreviewHost(selection: "today", coachUnread: false, scheme: .light) }
#Preview("Bottom nav — Light, Plan, unread") { BottomNavBarPreviewHost(selection: "plan", coachUnread: true, scheme: .light) }
#Preview("Bottom nav — Dark, Week")    { BottomNavBarPreviewHost(selection: "week",  coachUnread: false, scheme: .dark) }
#Preview("Bottom nav — Dark, no primary match (More-only page)") { BottomNavBarPreviewHost(selection: "goals", coachUnread: false, scheme: .dark) }
