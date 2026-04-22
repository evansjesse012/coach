import SwiftUI

/// Floating, backdrop-blurred tab bar. Icon on top, mono uppercase
/// label underneath. Active tab: ink background pill with `bg` text.
/// Built for N items; the design spec uses 4.
struct TabBar: View {
    struct Item: Identifiable, Hashable {
        let id: String
        let icon: String       // SF Symbol
        let label: String
    }

    let items: [Item]
    @Binding var selection: String

    /// Horizontal inset from screen edges.
    var sideInset: CGFloat = 14

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                cell(item)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        .padding(.horizontal, sideInset)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func cell(_ item: Item) -> some View {
        let active = item.id == selection
        Button {
            selection = item.id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
                Text(item.label)
                    .font(Theme.Typography.monoLabel)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }
            .foregroundStyle(active ? Theme.bg : Theme.ink2)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(active ? Theme.ink : .clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview host

private struct TabBarPreviewHost: View {
    @State var selection: String = "today"
    var scheme: ColorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            VStack {
                Spacer()
                Text("Selected: \(selection)")
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
                    .padding(.bottom, 120)
            }
            TabBar(
                items: [
                    .init(id: "today", icon: "house", label: "Today"),
                    .init(id: "goals", icon: "target", label: "Goals"),
                    .init(id: "plan",  icon: "calendar", label: "Plan"),
                    .init(id: "log",   icon: "waveform.path.ecg", label: "Log"),
                ],
                selection: $selection
            )
        }
        .preferredColorScheme(scheme)
    }
}

#Preview("TabBar — Light") { TabBarPreviewHost(scheme: .light) }
#Preview("TabBar — Dark")  { TabBarPreviewHost(scheme: .dark)  }
