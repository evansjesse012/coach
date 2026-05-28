import SwiftUI

/// Bottom sheet presented from the "More" tab in the primary nav. Hosts
/// secondary destinations that don't justify a top-level tab — Goals,
/// Log, Stats, Settings. Each row carries an icon, title, subtitle, and
/// trailing chevron in the standard iOS drill-cell shape.
///
/// The sheet is dismissible by tap-outside (system default), swipe-down
/// (system default via `presentationDragIndicator`), or the X button in
/// the toolbar. Tapping a row dismisses first, then routes — switching
/// tabs mid-dismiss visibly snaps in SwiftUI, so the route fires after
/// a tiny delay that lines up with the sheet's exit animation.
struct MoreSheet: View {
    enum Destination: String {
        case goals, log, stats, settings
    }

    /// Caller routes to the chosen destination. For goals / log / stats
    /// this is typically setting `data.selectedTab` to the destination
    /// id; for settings it's flipping the Settings sheet's binding.
    let onSelect: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    row(.goals,    icon: "target",                  title: "Goals",    subtitle: "Races and key milestones")
                    divider
                    row(.log,      icon: "list.clipboard.fill",     title: "Log",      subtitle: "Workout history")
                    divider
                    row(.stats,    icon: "chart.xyaxis.line",       title: "Stats",    subtitle: "Training load and trends")
                    divider
                    row(.settings, icon: "gearshape.fill",          title: "Settings", subtitle: "Preferences and account")
                }
                .background(Theme.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Theme.bg)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.surface2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 0.5)
            .padding(.leading, 62)
    }

    private func row(_ dest: Destination, icon: String, title: String, subtitle: String) -> some View {
        Button {
            dismiss()
            // Defer the route so the sheet's dismiss animation finishes
            // first — switching `selectedTab` mid-dismiss visibly snaps
            // the underlying view in SwiftUI.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onSelect(dest)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
