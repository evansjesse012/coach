import SwiftUI

/// Small solid circle color-coded to a discipline.
/// Default 7pt matches the design system spec (6–8pt range).
struct DisciplineDot: View {
    let discipline: Theme.Discipline
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(discipline.color)
            .frame(width: size, height: size)
    }
}

#Preview("DisciplineDot — Light") {
    HStack(spacing: 14) {
        ForEach(Theme.Discipline.allCases, id: \.self) { d in
            HStack(spacing: 6) {
                DisciplineDot(discipline: d)
                Text(d.label)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink2)
                    .tracking(Theme.Tracking.monoLabel)
            }
        }
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("DisciplineDot — Dark") {
    HStack(spacing: 14) {
        ForEach(Theme.Discipline.allCases, id: \.self) { d in
            HStack(spacing: 6) {
                DisciplineDot(discipline: d)
                Text(d.label)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink2)
                    .tracking(Theme.Tracking.monoLabel)
            }
        }
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
