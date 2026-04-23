import SwiftUI

/// Full-screen source of truth for marking, editing, and reviewing a
/// prescribed session. Pushed onto a NavigationStack; every tap origin
/// (Home today card, Plan list, Plan day detail, Activities) routes
/// here. The only exception is a multi-session day tap on the week
/// strip, which goes to a day overview first.
///
/// Phase 1 of the session-status unification — this file creates the
/// view and its state model. Phase 2 and 3 replace legacy completion
/// surfaces with pushes into this view.
struct SessionDetailView: View {
    // MARK: - Inputs

    let session: PrescribedSession
    let dateString: String?   // "yyyy-MM-dd"
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int

    /// Pre-selects a status when the view is pushed from a Today card
    /// quick-log pill (Modified / Swapped send the user here with the
    /// status and the sub-fields ready). nil for normal navigation.
    var preselectedStatus: Theme.SessionStatusKind? = nil

    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Working state

    @State private var workingStatus: Theme.SessionStatusKind = .pending
    @State private var workingActualDuration: String = ""
    @State private var workingActualEffort: String? = nil
    @State private var workingReplacedWith: String = ""
    @State private var workingSkipReason: SkipReason? = nil
    @State private var workingCompletionNote: String = ""
    @State private var workingAthleteNote: String = ""
    @State private var workingRPE: Int? = nil
    @State private var workingFatigue: Int? = nil
    @State private var workingLinkedWorkoutId: String? = nil

    @State private var showDiscardConfirm = false
    @State private var showClearConfirm = false
    @State private var showBrowseSheet = false
    @State private var showReschedulePlaceholder = false
    @State private var hasLoadedInitial = false
    @State private var showWorkoutLogger = false
    @State private var showResumeConfirm = false

    // MARK: - Derived

    private var statusKind: Theme.SessionStatusKind { workingStatus }

    private var linkedWorkout: CardioWorkout? {
        guard let id = workingLinkedWorkoutId else { return nil }
        return data.cardio.first { $0.id == id }
    }

    private var watchCandidate: CardioWorkout? {
        guard workingLinkedWorkoutId == nil else { return nil }
        return Self.autoDetectCandidate(for: session, on: dateString, in: data.cardio)
    }

    private var hasChanges: Bool {
        workingStatus != session.statusKind ||
        trimmed(workingCompletionNote) != (session.completionNote ?? "") ||
        trimmed(workingAthleteNote) != (session.athleteNote ?? "") ||
        parsedActualDuration != session.actualDuration ||
        workingActualEffort != session.actualEffort ||
        trimmed(workingReplacedWith) != (session.replacedWithLabel ?? session.actualSport ?? "") ||
        workingSkipReason != session.skipReason ||
        workingRPE != session.rpe ||
        workingFatigue != session.fatigue ||
        workingLinkedWorkoutId != session.linkedWorkoutId
    }

    private var parsedActualDuration: Int? {
        let t = workingActualDuration.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        return Int(t)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                heroSection
                prescriptionSection
                if isStrengthWithExercises {
                    strengthWorkoutSection
                }
                statusSection
                watchSection
                coachNotesSection
                nutritionSection
                athleteNotesSection
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .clearsTabBar()
        .background(Theme.bg.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { attemptBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .principal) {
                Text(headerDateLabel)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink2)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showReschedulePlaceholder = true } label: {
                        Label("Reschedule", systemImage: "calendar.badge.clock")
                    }
                    Button(role: .destructive) {
                        showReschedulePlaceholder = true
                    } label: {
                        Label("Delete from plan", systemImage: "trash")
                    }
                    Button { showReschedulePlaceholder = true } label: {
                        Label("Report issue", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Session options")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveBar
        }
        .confirmationDialog(
            "Clear logged data for this session?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { clearLoggedData() }
            Button("Cancel", role: .cancel) { workingStatus = session.statusKind }
        } message: {
            Text("This removes the duration, notes, RPE, and any linked workout you've recorded.")
        }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .sheet(isPresented: $showBrowseSheet) {
            BrowseRecentWorkoutsSheet(
                session: session,
                dateString: dateString,
                cardio: data.cardio,
                currentLinkedId: workingLinkedWorkoutId,
                onPick: { picked in
                    workingLinkedWorkoutId = picked.id
                    if workingActualDuration.isEmpty { workingActualDuration = "\(picked.duration)" }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Coming soon", isPresented: $showReschedulePlaceholder) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This action will ship in a later phase. For now, use the overflow menu on the plan screen.")
        }
        .fullScreenCover(isPresented: $showWorkoutLogger) {
            NavigationStack { WorkoutLoggingView() }
        }
        .confirmationDialog(
            "Workout already in progress",
            isPresented: $showResumeConfirm,
            titleVisibility: .visible
        ) {
            Button("Resume") { showWorkoutLogger = true }
            Button("Discard and start new", role: .destructive) {
                data.cancelActiveWorkout()
                data.startStrengthWorkout(StrengthSession.fromPrescribed(session))
                showWorkoutLogger = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let active = data.activeStrengthSession {
                Text("You have \u{201C}\(active.name)\u{201D} in progress. Resume it or start a new one?")
            }
        }
        .onAppear { loadFromSessionIfNeeded() }
    }

    // MARK: - Hero section

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: discipline.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(discipline.color)
                Text(disciplineTagLine)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(discipline.color)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }

            Text(session.label)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)

            if !heroStats.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(heroStats.prefix(3).enumerated()), id: \.offset) { _, stat in
                        heroStatCell(stat)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func heroStatCell(_ stat: HeroStat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stat.value)
                    .font(Theme.Typography.mono(18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let unit = stat.unit {
                    Text(unit)
                        .font(Theme.Typography.mono(11))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    // MARK: - Prescription section

    /// Purpose / zone + pace / workout description / warning — everything
    /// the coach prescribed, rendered before the quick-log surfaces. Each
    /// sub-block is conditional; the whole section disappears if the
    /// session carries none of the four fields.
    @ViewBuilder
    private var prescriptionSection: some View {
        let hasZoneOrPace = (session.zone?.isEmpty == false) || (session.paceRange?.isEmpty == false)
        let hasPurpose    = session.purpose?.isEmpty  == false
        let hasWorkout    = session.workout?.isEmpty  == false
        let hasWarning    = session.warning?.isEmpty  == false
        if hasPurpose || hasZoneOrPace || hasWorkout || hasWarning {
            VStack(alignment: .leading, spacing: 12) {
                if let purpose = session.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(Theme.Typography.body)
                        .italic()
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if hasZoneOrPace { zonePaceRow }
                if let workout = session.workout, !workout.isEmpty {
                    workoutPrescriptionCard(workout)
                }
                if let warning = session.warning, !warning.isEmpty {
                    warningCallout(warning)
                }
            }
        }
    }

    @ViewBuilder
    private var zonePaceRow: some View {
        HStack(spacing: 10) {
            if let zone = session.zone, !zone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(zone)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(Theme.accent)
                .background(Theme.accentSoft, in: Capsule())
            }
            if let pace = session.paceRange, !pace.isEmpty {
                Text("\(pace) pace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
        }
    }

    private func workoutPrescriptionCard(_ workout: String) -> some View {
        Text(workout)
            .font(Theme.Typography.mono(13))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
            )
    }

    private func warningCallout(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.modifiedAccent)
                .padding(.top, 1)
            Text(warning)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.modifiedSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.modifiedAccent.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Strength workout section

    /// True when this session prescribes strength work with at least one
    /// exercise. Cardio sessions and strength sessions with no exercise
    /// payload fall through without this block.
    private var isStrengthWithExercises: Bool {
        session.type.lowercased() == "strength"
            && (session.exercises?.isEmpty == false)
    }

    @ViewBuilder
    private var strengthWorkoutSection: some View {
        if let exercises = session.exercises, !exercises.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                startWorkoutButton
                exerciseList(exercises)
            }
        }
    }

    private var startWorkoutButton: some View {
        Pill(
            title: startWorkoutLabel,
            icon: "play.fill",
            variant: .primary,
            action: tapStartWorkout
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startWorkoutLabel: String {
        if let active = data.activeStrengthSession, active.templateId == session.templateId {
            return "Resume workout"
        }
        if data.activeStrengthSession != nil {
            return "Start workout"
        }
        return "Start workout"
    }

    private func tapStartWorkout() {
        if data.activeStrengthSession != nil {
            // Resume the in-progress session if it's this same template,
            // otherwise ask before discarding it.
            if data.activeStrengthSession?.templateId == session.templateId {
                showWorkoutLogger = true
            } else {
                showResumeConfirm = true
            }
        } else {
            data.startStrengthWorkout(StrengthSession.fromPrescribed(session))
            showWorkoutLogger = true
        }
    }

    private func exerciseList(_ exercises: [PrescribedExercise]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Exercises")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text("\(exercises.count) · \(totalSets(exercises)) sets")
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }
                VStack(spacing: 10) {
                    ForEach(Array(exercises.enumerated()), id: \.offset) { idx, exercise in
                        exerciseRow(exercise, index: idx)
                    }
                }
            }
        }
    }

    private func exerciseRow(_ exercise: PrescribedExercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(Theme.Typography.mono(12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        Text(exercise.exerciseType.label)
                            .font(Theme.Typography.monoLabelS)
                            .textCase(.uppercase)
                            .tracking(Theme.Tracking.monoLabel)
                            .foregroundStyle(Theme.accent)
                        if let rest = exercise.rest, rest > 0 {
                            Text("Rest \(formatRest(rest))")
                                .font(Theme.Typography.monoMeta)
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                }
                Spacer(minLength: 8)
                Text(setsRepsText(exercise))
                    .font(Theme.Typography.mono(13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
            }
            if let cue = exercise.notes, !cue.isEmpty {
                Text(cue)
                    .font(Theme.Typography.small)
                    .italic()
                    .foregroundStyle(Theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }

    private func totalSets(_ exercises: [PrescribedExercise]) -> Int {
        exercises.reduce(0) { $0 + ($1.sets ?? 0) }
    }

    private func setsRepsText(_ exercise: PrescribedExercise) -> String {
        let sets = exercise.sets ?? 0
        if let reps = exercise.reps, reps > 0 {
            if let weight = exercise.weight, weight > 0 {
                let w = weight == weight.rounded() ? "\(Int(weight))" : String(format: "%.1f", weight)
                return "\(sets)×\(reps) · \(w)lb"
            }
            return "\(sets)×\(reps)"
        }
        if let d = exercise.duration, d > 0 {
            return "\(sets)×\(Int(d))s"
        }
        if let band = exercise.band, !band.isEmpty {
            return "\(sets) \(band)"
        }
        return sets > 0 ? "\(sets) sets" : "—"
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }

    // MARK: - Status section

    @ViewBuilder
    private var statusSection: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Status")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                HStack(alignment: .center, spacing: 10) {
                    currentStatusPill
                    Spacer()
                    Text("Tap to change")
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }

                Rectangle().fill(Theme.line).frame(height: 1)

                statusPickerRow

                statusSubFields
            }
        }
    }

    private var currentStatusPill: some View {
        HStack(spacing: 8) {
            Image(systemName: statusKind.icon)
                .font(.system(size: 14, weight: .semibold))
            Text(statusKind.label)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(statusKind.tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(statusKind.fill))
        .overlay(
            Capsule().strokeBorder(statusKind.border ?? .clear, lineWidth: statusKind.border == nil ? 0 : 1)
        )
    }

    @ViewBuilder
    private var statusPickerRow: some View {
        let options: [Theme.SessionStatusKind] = [.pending, .done, .modified, .swapped, .skipped]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    statusChoice(opt)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func statusChoice(_ opt: Theme.SessionStatusKind) -> some View {
        let selected = opt == workingStatus
        return Button {
            selectStatus(opt)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: opt.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(opt.label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? opt.tint : Theme.ink2)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? opt.fill : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(
                    selected ? (opt.border ?? .clear) : Theme.line,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func selectStatus(_ new: Theme.SessionStatusKind) {
        // Going back to pending on a logged session triggers a confirm
        // before we drop the captured data.
        let wasLogged = session.completionStatus != nil ||
            hadAnyLoggedField() ||
            workingLinkedWorkoutId != nil
        if new == .pending && wasLogged {
            workingStatus = .pending
            showClearConfirm = true
            return
        }
        workingStatus = new
        // Seed helpful defaults when moving into a status for the first time.
        if new == .modified && workingActualDuration.isEmpty,
           let planned = session.duration { workingActualDuration = "\(planned)" }
    }

    @ViewBuilder
    private var statusSubFields: some View {
        switch workingStatus {
        case .modified:
            modifiedFields
        case .swapped:
            swappedFields
        case .skipped:
            skippedFields
        case .done, .pending:
            EmptyView()
        }
    }

    @ViewBuilder
    private var modifiedFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeled("Actual duration") {
                HStack(spacing: 8) {
                    TextField("minutes", text: $workingActualDuration)
                        .keyboardType(.numberPad)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink)
                    Text("min")
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            labeled("Effort") {
                effortSegmented
            }
            labeled("Notes") {
                noteField($workingCompletionNote, placeholder: "What changed?")
            }
        }
    }

    @ViewBuilder
    private var swappedFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeled("Replaced with") {
                TextField("What did you do instead?", text: $workingReplacedWith)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            labeled("Actual duration") {
                HStack(spacing: 8) {
                    TextField("minutes", text: $workingActualDuration)
                        .keyboardType(.numberPad)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink)
                    Text("min")
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            labeled("Notes") {
                noteField($workingCompletionNote, placeholder: "Why the swap?")
            }
        }
    }

    @ViewBuilder
    private var skippedFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeled("Reason") {
                reasonChips
            }
            labeled("Notes") {
                noteField($workingCompletionNote, placeholder: "Anything to note?")
            }
        }
    }

    private var effortSegmented: some View {
        let options: [(String, String)] = [
            ("easier", "Easier"),
            ("as_planned", "As planned"),
            ("harder", "Harder"),
        ]
        return HStack(spacing: 6) {
            ForEach(options, id: \.0) { opt in
                let selected = workingActualEffort == opt.0
                Button {
                    workingActualEffort = selected ? nil : opt.0
                } label: {
                    Text(opt.1)
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Theme.accentInk : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? Theme.accent : Theme.surface2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reasonChips: some View {
        let options: [(SkipReason, String)] = [
            (.fatigue, "Tired"),
            (.soreness, "Sick"),
            (.time, "Schedule"),
            (.life, "Other"),
        ]
        return FlowLayout(spacing: 8) {
            ForEach(options, id: \.0) { opt in
                let selected = workingSkipReason == opt.0
                Button {
                    workingSkipReason = selected ? nil : opt.0
                } label: {
                    Text(opt.1)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? Theme.warn : Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected ? Theme.warnBg : Color.clear)
                        )
                        .overlay(
                            Capsule().strokeBorder(selected ? Theme.warn : Theme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Watch section

    @ViewBuilder
    private var watchSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity data")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                if let linked = linkedWorkout {
                    watchLinkedCard(linked)
                    Button {
                        workingLinkedWorkoutId = nil
                    } label: {
                        Text("Unlink this workout")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ink3)
                            .underline()
                    }
                    .buttonStyle(.plain)
                } else if let candidate = watchCandidate {
                    Text("We detected a workout that may match this session")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    watchCandidateCard(candidate)
                    HStack(spacing: 10) {
                        Pill(title: "Link this workout", variant: .primary) {
                            workingLinkedWorkoutId = candidate.id
                            if workingActualDuration.isEmpty {
                                workingActualDuration = "\(candidate.duration)"
                            }
                            if workingStatus == .pending {
                                workingStatus = .done
                            }
                        }
                        Pill(title: "Browse others", variant: .secondary) {
                            showBrowseSheet = true
                        }
                    }
                } else {
                    Text("Link a workout from your Apple Watch to see actual data.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Pill(title: "Browse recent workouts", variant: .secondary) {
                        showBrowseSheet = true
                    }
                }
            }
        }
    }

    private func watchCandidateCard(_ workout: CardioWorkout) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Theme.surface2).frame(width: 34, height: 34)
                Image(systemName: "applewatch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.sport.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(watchCandidateMeta(workout))
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 0)
            Text(matchScoreLabel(for: workout))
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(matchScoreTint(for: workout))
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
        }
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func watchLinkedCard(_ workout: CardioWorkout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Linked workout")
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.accent)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                Spacer(minLength: 0)
            }

            let stats = linkedStats(workout)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
                spacing: 10
            ) {
                ForEach(stats, id: \.label) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.label)
                            .font(Theme.Typography.monoLabelS)
                            .foregroundStyle(Theme.ink3)
                            .textCase(.uppercase)
                            .tracking(Theme.Tracking.monoLabel)
                        Text(s.value)
                            .font(Theme.Typography.mono(14, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }

            Text(linkedFooter(workout))
                .font(Theme.Typography.monoMeta)
                .foregroundStyle(Theme.ink3)
        }
        .padding(14)
        .background(Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Coach notes

    @ViewBuilder
    private var coachNotesSection: some View {
        if let notes = session.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.accent).frame(width: 5, height: 5)
                    Text("From your coach")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 2)
                    Text(notes)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface1)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Nutrition

    @ViewBuilder
    private var nutritionSection: some View {
        if let fuel = session.fuel, hasAnyFuel(fuel) {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Nutrition")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    nutritionRow(label: "Before",  text: fuel.pre)
                    nutritionRow(label: "During",  text: fuel.during)
                    nutritionRow(label: "After",   text: fuel.post)
                }
            }
        }
    }

    private func nutritionRow(label: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            Text(text?.isEmpty == false ? text! : "—")
                .font(Theme.Typography.body)
                .foregroundStyle(text?.isEmpty == false ? Theme.ink : Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hasAnyFuel(_ fuel: SessionFuel) -> Bool {
        (fuel.pre?.isEmpty    == false) ||
        (fuel.during?.isEmpty == false) ||
        (fuel.post?.isEmpty   == false)
    }

    // MARK: - Athlete notes

    @ViewBuilder
    private var athleteNotesSection: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("How did it go?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                noteField($workingAthleteNote, placeholder: "Felt great, hit all the targets…", lineLimit: 3...6)

                labeled("RPE") {
                    numberPicker(range: 1...10, selection: $workingRPE, accent: Theme.accent)
                }
                labeled("Fatigue now") {
                    numberPicker(range: 1...10, selection: $workingFatigue, accent: Theme.info)
                }
            }
        }
    }

    // MARK: - Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 10) {
                Button {
                    attemptBack()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Pill(title: "Save", variant: .primary) {
                    Task { await save() }
                }
                .disabled(!hasChanges)
                .opacity(hasChanges ? 1.0 : 0.5)
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.vertical, 10)
        }
        .background(Theme.bg)
    }

    // MARK: - Save / Load

    private func loadFromSessionIfNeeded() {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true

        workingStatus = preselectedStatus ?? session.statusKind
        workingActualDuration = session.actualDuration.map { "\($0)" } ?? ""
        workingActualEffort = session.actualEffort
        workingReplacedWith = session.replacedWithLabel ?? session.actualSport ?? ""
        workingSkipReason = session.skipReason
        workingCompletionNote = session.completionNote ?? ""
        workingAthleteNote = session.athleteNote ?? ""
        workingRPE = session.rpe
        workingFatigue = session.fatigue
        workingLinkedWorkoutId = session.linkedWorkoutId
    }

    private func save() async {
        try? await data.updateSessionCompletion(
            weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
        ) { s in
            switch workingStatus {
            case .pending:
                clearMutation(&s)
            case .done:
                s.completionStatus = .completed
                s.completed = true
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                s.actualDuration = parsedActualDuration ?? s.actualDuration
                s.actualEffort = nil
                s.replacedWithLabel = nil
                s.skipReason = nil
                s.completionNote = nilIfEmpty(workingCompletionNote)
            case .modified:
                s.completionStatus = .modified
                s.completed = true
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                s.actualDuration = parsedActualDuration
                s.actualEffort = workingActualEffort
                s.replacedWithLabel = nil
                s.skipReason = nil
                s.completionNote = nilIfEmpty(workingCompletionNote)
            case .swapped:
                s.completionStatus = .swapped
                s.completed = true
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                s.actualDuration = parsedActualDuration
                s.actualSport = matchedSportRawValue(for: workingReplacedWith)
                s.replacedWithLabel = nilIfEmpty(workingReplacedWith)
                s.actualEffort = nil
                s.skipReason = nil
                s.completionNote = nilIfEmpty(workingCompletionNote)
            case .skipped:
                s.completionStatus = .skipped
                s.completed = false
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                s.actualDuration = nil
                s.actualEffort = nil
                s.replacedWithLabel = nil
                s.skipReason = workingSkipReason
                s.completionNote = nilIfEmpty(workingCompletionNote)
            }
            s.linkedWorkoutId = workingLinkedWorkoutId
            s.rpe = workingRPE
            s.fatigue = workingFatigue
            s.athleteNote = nilIfEmpty(workingAthleteNote)
        }
        dismiss()
    }

    private func clearLoggedData() {
        workingStatus = .pending
        workingActualDuration = ""
        workingActualEffort = nil
        workingReplacedWith = ""
        workingSkipReason = nil
        workingCompletionNote = ""
        workingLinkedWorkoutId = nil
    }

    private func clearMutation(_ s: inout PrescribedSession) {
        s.completionStatus = nil
        s.completed = nil
        s.actualDuration = nil
        s.actualEffort = nil
        s.actualSport = nil
        s.replacedWithLabel = nil
        s.skipReason = nil
        s.completionNote = nil
        s.completionResolvedAt = nil
        s.completionNeedsReview = nil
    }

    private func hadAnyLoggedField() -> Bool {
        !workingActualDuration.isEmpty ||
        workingActualEffort != nil ||
        !workingReplacedWith.isEmpty ||
        workingSkipReason != nil ||
        !workingCompletionNote.isEmpty
    }

    private func attemptBack() {
        if hasChanges {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            content()
        }
    }

    private func noteField(_ binding: Binding<String>, placeholder: String, lineLimit: ClosedRange<Int> = 2...6) -> some View {
        TextField(placeholder, text: binding, axis: .vertical)
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.ink)
            .lineLimit(lineLimit)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func numberPicker(range: ClosedRange<Int>, selection: Binding<Int?>, accent: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(range, id: \.self) { n in
                    let selected = selection.wrappedValue == n
                    Button {
                        selection.wrappedValue = selected ? nil : n
                    } label: {
                        Text("\(n)")
                            .font(Theme.Typography.mono(13, weight: .medium))
                            .foregroundStyle(selected ? Theme.accentInk : Theme.ink)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(selected ? accent : Theme.surface2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    private var discipline: Theme.Discipline {
        if let sport = Sport(rawValue: session.type) { return sport.discipline }
        if session.type == "strength" { return .strength }
        return .run
    }

    private var disciplineTagLine: String {
        if let cat = session.effortCategory {
            return "\(discipline.label) · \(cat.label.uppercased())"
        }
        if let zone = session.zone {
            return "\(discipline.label) · \(zone.uppercased())"
        }
        return discipline.label
    }

    private var headerDateLabel: String {
        guard let d = dateString, !d.isEmpty else { return "" }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let date = inF.date(from: d) else { return d }
        let outF = DateFormatter(); outF.dateFormat = "EEEE · MMM d"
        return outF.string(from: date)
    }

    private struct HeroStat { let label: String; let value: String; let unit: String? }

    private var heroStats: [HeroStat] {
        var out: [HeroStat] = []
        if let dur = session.duration {
            out.append(.init(label: "Time", value: "\(dur)", unit: "m"))
        } else if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            out.append(.init(label: "Time", value: "\(lo)–\(hi)", unit: "m"))
        }
        if let zone = session.zone, !zone.isEmpty {
            out.append(.init(label: "Zone", value: zone.uppercased(), unit: nil))
        }
        if let pace = session.paceRange, !pace.isEmpty {
            out.append(.init(label: "Pace", value: pace, unit: nil))
        } else if let dist = session.distanceMiles {
            out.append(.init(label: "Distance", value: String(format: "%.1f", dist), unit: "mi"))
        }
        return out
    }

    // MARK: - Watch helpers

    private func watchCandidateMeta(_ w: CardioWorkout) -> String {
        var parts: [String] = []
        parts.append("\(w.duration)m")
        if let dist = w.distance, !dist.isEmpty { parts.append(dist) }
        parts.append(startTimeLabel(for: w))
        return parts.joined(separator: " · ")
    }

    private func startTimeLabel(for w: CardioWorkout) -> String {
        // CardioWorkout uses a date string "yyyy-MM-dd"; we don't have start
        // time, so fall back to the date label.
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        if let d = inF.date(from: w.date) {
            let outF = DateFormatter(); outF.dateFormat = "MMM d"
            return outF.string(from: d)
        }
        return w.date
    }

    private func linkedFooter(_ w: CardioWorkout) -> String {
        "Recorded \(startTimeLabel(for: w))"
    }

    private struct LinkedStat { let label: String; let value: String }

    private func linkedStats(_ w: CardioWorkout) -> [LinkedStat] {
        var out: [LinkedStat] = []
        out.append(.init(label: "Duration", value: "\(w.duration)m"))
        if let dist = w.distance, !dist.isEmpty {
            out.append(.init(label: "Distance", value: dist))
        }
        if let hr = w.avgHR {
            out.append(.init(label: "Avg HR", value: "\(hr) bpm"))
        }
        return out
    }

    private func matchScoreLabel(for w: CardioWorkout) -> String {
        switch Self.matchScore(for: session, workout: w) {
        case .high:   return "Match · High"
        case .medium: return "Match · Medium"
        case .low:    return "Match · Low"
        }
    }

    private func matchScoreTint(for w: CardioWorkout) -> Color {
        switch Self.matchScore(for: session, workout: w) {
        case .high:   return Theme.accent
        case .medium: return Theme.modifiedAccent
        case .low:    return Theme.ink3
        }
    }

    // MARK: - Auto-detect

    enum MatchScore { case high, medium, low }

    /// Finds the best candidate CardioWorkout for this session within a
    /// 24-hour window centered on the session's scheduled date. Matches by
    /// discipline first, then ranks by duration similarity. Returns nil
    /// when no same-discipline workout falls inside the window.
    ///
    /// Exposed as a static for unit tests; the view instance calls it via
    /// `watchCandidate`.
    static func autoDetectCandidate(
        for session: PrescribedSession,
        on dateString: String?,
        in cardio: [CardioWorkout]
    ) -> CardioWorkout? {
        guard let dateString, !dateString.isEmpty else { return nil }
        let iso = DateFormatter(); iso.dateFormat = "yyyy-MM-dd"
        guard let center = iso.date(from: dateString) else { return nil }
        let lower = center.addingTimeInterval(-24 * 3600)
        let upper = center.addingTimeInterval(24 * 3600)

        let sessionSport = Sport(rawValue: session.type)
        let candidates = cardio.compactMap { w -> (workout: CardioWorkout, date: Date)? in
            guard let d = iso.date(from: w.date) else { return nil }
            guard d >= lower, d <= upper else { return nil }
            if let s = sessionSport, w.sport != s { return nil }
            return (w, d)
        }
        guard !candidates.isEmpty else { return nil }

        // Rank by duration similarity to planned (smaller diff = better).
        let planned = session.duration ?? session.estimatedDurationMin
        let ranked = candidates.sorted { lhs, rhs in
            let l = abs(lhs.workout.duration - (planned ?? lhs.workout.duration))
            let r = abs(rhs.workout.duration - (planned ?? rhs.workout.duration))
            return l < r
        }
        return ranked.first?.workout
    }

    static func matchScore(for session: PrescribedSession, workout: CardioWorkout) -> MatchScore {
        let sportMatches = Sport(rawValue: session.type).map { $0 == workout.sport } ?? false
        let planned = session.duration ?? session.estimatedDurationMin ?? workout.duration
        let diffPct = abs(Double(workout.duration - planned)) / max(Double(planned), 1)
        if sportMatches && diffPct <= 0.15 { return .high }
        if sportMatches && diffPct <= 0.40 { return .medium }
        return .low
    }

    // MARK: - Small utilities

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func nilIfEmpty(_ s: String) -> String? {
        let t = trimmed(s); return t.isEmpty ? nil : t
    }
    private func matchedSportRawValue(for label: String) -> String? {
        let lower = label.lowercased().trimmingCharacters(in: .whitespaces)
        return Sport(rawValue: lower)?.rawValue
    }
}

// MARK: - Browse recent workouts sheet

/// Sheet shown when the athlete taps "Browse recent workouts" from the
/// activity-data section. Lists cardio activities within a generous
/// window around the session's date, sorted recent-first. Tap a row to
/// link it.
private struct BrowseRecentWorkoutsSheet: View {
    let session: PrescribedSession
    let dateString: String?
    let cardio: [CardioWorkout]
    let currentLinkedId: String?
    let onPick: (CardioWorkout) -> Void

    @Environment(\.dismiss) private var dismiss

    private var candidates: [CardioWorkout] {
        let iso = DateFormatter(); iso.dateFormat = "yyyy-MM-dd"
        guard let ds = dateString, let center = iso.date(from: ds) else {
            return cardio.sorted { $0.date > $1.date }
        }
        let lower = center.addingTimeInterval(-3 * 24 * 3600)
        let upper = center.addingTimeInterval(3 * 24 * 3600)
        let filtered = cardio.compactMap { w -> CardioWorkout? in
            guard let d = iso.date(from: w.date), d >= lower, d <= upper else { return nil }
            return w
        }
        return filtered.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if candidates.isEmpty {
                        ContentUnavailableView(
                            "No nearby workouts",
                            systemImage: "applewatch.slash",
                            description: Text("We didn't find any Apple Watch workouts within 3 days of this session.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(candidates) { w in
                            Button {
                                onPick(w)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Theme.surface2)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Image(systemName: "applewatch")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Theme.ink)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.sport.label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.ink)
                                        Text("\(w.date) · \(w.duration)m")
                                            .font(Theme.Typography.monoMeta)
                                            .foregroundStyle(Theme.ink3)
                                    }
                                    Spacer(minLength: 0)
                                    if currentLinkedId == w.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            currentLinkedId == w.id ? Theme.accent : Theme.line,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.vertical, 12)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Recent workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Flow layout

/// Light-weight flow layout for wrapping chips that don't fit on one
/// line. Good enough for the skip-reason chip row.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Previews

private func previewSession(
    status: CompletionStatus? = nil,
    actualDuration: Int? = nil,
    actualEffort: String? = nil,
    skipReason: SkipReason? = nil,
    linkedWorkoutId: String? = nil,
    completionNote: String? = nil
) -> PrescribedSession {
    PrescribedSession(
        type: "bike",
        label: "Z2 Spin — Cadence Focus",
        duration: 45,
        estimatedDurationMin: nil,
        estimatedDurationMax: nil,
        distanceMiles: 12,
        effortCategory: .easy,
        completed: status != nil && status != .skipped,
        zone: "Z2",
        targetIntensity: nil,
        paceRange: nil,
        purpose: "Build aerobic base with cadence work.",
        workout: nil,
        fuel: nil,
        priority: nil,
        notes: "Focus on smooth pedal stroke and 90 rpm cadence. Keep HR low.",
        warning: nil,
        exercises: nil,
        legs: nil,
        templateId: nil,
        completionStatus: status,
        actualDuration: actualDuration,
        actualDistance: nil,
        actualSport: nil,
        skipReason: skipReason,
        completionNote: completionNote,
        completionResolvedAt: nil,
        completionNeedsReview: nil,
        linkedWorkoutId: linkedWorkoutId,
        actualEffort: actualEffort,
        replacedWithLabel: nil,
        rpe: nil,
        fatigue: nil,
        athleteNote: nil
    )
}

#Preview("Session Detail — pending, no watch (light)") {
    NavigationStack {
        SessionDetailView(
            session: previewSession(),
            dateString: "2026-04-23",
            weekNum: 1, dayIdx: 3, sessionIdx: 0
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Session Detail — done, watch linked (light)") {
    NavigationStack {
        SessionDetailView(
            session: previewSession(status: .completed, actualDuration: 46, linkedWorkoutId: "wk-1"),
            dateString: "2026-04-23",
            weekNum: 1, dayIdx: 3, sessionIdx: 0
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Session Detail — modified (light)") {
    NavigationStack {
        SessionDetailView(
            session: previewSession(status: .modified, actualDuration: 38, actualEffort: "harder",
                                    completionNote: "Cut short, legs heavy"),
            dateString: "2026-04-23",
            weekNum: 1, dayIdx: 3, sessionIdx: 0
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Session Detail — skipped (dark)") {
    NavigationStack {
        SessionDetailView(
            session: previewSession(status: .skipped, skipReason: .fatigue,
                                    completionNote: "Slept badly, pushed to tomorrow"),
            dateString: "2026-04-23",
            weekNum: 1, dayIdx: 3, sessionIdx: 0
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Session Detail — swapped (dark)") {
    NavigationStack {
        SessionDetailView(
            session: previewSession(status: .swapped, actualDuration: 55,
                                    completionNote: "Rode with a friend's group"),
            dateString: "2026-04-23",
            weekNum: 1, dayIdx: 3, sessionIdx: 0
        )
    }
    .preferredColorScheme(.dark)
}
