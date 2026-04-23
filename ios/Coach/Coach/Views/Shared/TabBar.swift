import SwiftUI

/// Broadcast when the user taps the tab they're already on. Each tab listens
/// for its own id and pops its NavigationStack to root — the native TabView
/// behavior the anchored custom bar has to reimplement.
extension Notification.Name {
    static let popTabToRoot = Notification.Name("coach.popTabToRoot")
}

extension View {
    /// Pops the enclosing NavigationStack to root when the user taps the
    /// tab matching `tabId` while already on it. Each tab owns its own
    /// `@State var path = NavigationPath()` and applies this modifier.
    ///
    /// Clearing `path` alone isn't reliable: closure-style NavigationLinks
    /// (`NavigationLink { Destination() } label: { ... }`) don't always sync
    /// their pushes into the bound path, so `path = NavigationPath()` can be
    /// a no-op while the pushed destination stays on screen. To guarantee
    /// the pop we also flip a rebuild id on the modified view, which forces
    /// SwiftUI to recreate the NavigationStack and unmount anything pushed
    /// on top of root. This matches the native tab-reselect behavior in
    /// Mail / Messages / Phone (scroll resets, pushed views dismiss).
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
                // Clear the path too in case the closure-style links did
                // sync their pushes — harmless if the path was empty.
                path.wrappedValue = NavigationPath()
                // Rebuild the subtree — unmounts any pushed destinations.
                rootID = UUID()
            }
    }
}

/// Anchored, edge-to-edge tab bar. Full width, solid `surface1` background,
/// 1pt hairline on top, 56pt content row above the bottom safe area. Active
/// state is communicated by color only — icon + label shift from `ink3` to
/// `accent` with a 200ms color crossfade. No pill background, no shadow.
///
/// Designed to be mounted via `.safeAreaInset(edge: .bottom)` so the parent
/// view's safe area automatically shrinks to exclude it, and scrollable
/// content ends naturally above the bar without per-screen padding.
struct TabBar: View {
    struct Item: Identifiable, Hashable {
        let id: String
        let icon: String       // SF Symbol
        let label: String      // Sentence-case, e.g. "Today"
        var hasBadge: Bool = false
    }

    let items: [Item]
    @Binding var selection: String
    /// Called when the user taps the tab that is already selected. The
    /// caller typically uses this to pop the current tab's NavigationStack
    /// back to root.
    var onReselect: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    cell(item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 56)
        }
        .background(Theme.surface1)
    }

    @ViewBuilder
    private func cell(_ item: Item) -> some View {
        let active = item.id == selection
        Button {
            if selection == item.id {
                onReselect?(item.id)
            } else {
                selection = item.id
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .regular))
                    if item.hasBadge {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
                }
                Text(item.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(-0.05)
            }
            .foregroundStyle(active ? Theme.accent : Theme.ink3)
            .animation(.easeOut(duration: 0.2), value: active)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview host

private struct TabBarPreviewHost: View {
    @State var selection: String
    let scheme: ColorScheme

    init(selection: String, scheme: ColorScheme) {
        self._selection = State(initialValue: selection)
        self.scheme = scheme
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Spacer()
                Text("Screen content")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink2)
                Text("selected: \(selection)")
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(
                items: [
                    .init(id: "today", icon: "house",              label: "Today"),
                    .init(id: "goals", icon: "target",             label: "Goals"),
                    .init(id: "plan",  icon: "calendar",           label: "Plan"),
                    .init(id: "log",   icon: "list.clipboard.fill",label: "Log"),
                    .init(id: "stats", icon: "chart.xyaxis.line", label: "Stats"),
                ],
                selection: $selection
            )
            .background(Theme.surface1.ignoresSafeArea(edges: .bottom))
        }
        .preferredColorScheme(scheme)
    }
}

#Preview("TabBar — Light, Today")  { TabBarPreviewHost(selection: "today", scheme: .light) }
#Preview("TabBar — Light, Plan")   { TabBarPreviewHost(selection: "plan",  scheme: .light) }
#Preview("TabBar — Dark, Today")   { TabBarPreviewHost(selection: "today", scheme: .dark) }
#Preview("TabBar — Dark, Stats")   { TabBarPreviewHost(selection: "stats", scheme: .dark) }
