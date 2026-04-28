import Foundation
import Supabase
import Auth
import PostgREST

/// Loads sample data into Supabase for the signed-in user so the app
/// has something to render during dev/demo. Inserts only — does not clear.
@MainActor
enum SeedData {
    static func clear(in data: DataService) async throws {
        let client = SupabaseService.shared.client
        guard let userId = client.auth.currentUser?.id else {
            throw NSError(domain: "SeedData", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let uid = userId.uuidString.lowercased()

        try await client.from("cardio_workouts").delete().eq("user_id", value: uid).execute()
        try await client.from("strength_sessions").delete().eq("user_id", value: uid).execute()
        try await client.from("personal_records").delete().eq("user_id", value: uid).execute()
        try await client.from("templates").delete().eq("user_id", value: uid).execute()
        try await client.from("events").delete().eq("user_id", value: uid).execute()
        try await client.from("training_plans").delete().eq("user_id", value: uid).execute()
        try await client.from("coaching_memory").delete().eq("user_id", value: uid).execute()

        var s = data.settings
        s.pushMessage = nil
        try await data.saveSettings(s)
    }

    static func load(into data: DataService) async throws {
        let cal = Calendar.current
        let today = Date()
        func day(_ offset: Int) -> String {
            let d = cal.date(byAdding: .day, value: offset, to: today)!
            return localDateString(from: d)
        }

        // 1. Push message
        var settings = data.settings
        settings.pushMessage = PushMessage(
            text: "Welcome back. You're on track for the week — easy 45m run today, then strength tomorrow.",
            actions: ["Log workout", "Adjust plan"],
            count: 1,
            ts: ISO8601DateFormatter().string(from: today)
        )
        try await data.saveSettings(settings)

        // 2. Cardio workouts — past week, mixed sports, fully decorated
        let cardios: [CardioWorkout] = [
            decorateRun(
                date: day(-1), durationMin: 52, distanceMi: 4.5,
                avgHR: 148, maxHR: 167, calories: 510, cadence: 168,
                location: "Riverside loop", note: "Easy aerobic — felt smooth",
                center: (37.7706, -122.4523),
                zoneDist: [0.05, 0.75, 0.18, 0.02, 0]
            ),
            decorateBike(
                date: day(-2), durationMin: 75, distanceMi: 19.9,
                avgHR: 142, maxHR: 162, calories: 640,
                avgPower: 185, cadence: 86,
                location: "Marin Headlands", note: "Z2 endurance ride",
                center: (37.8324, -122.4995),
                zoneDist: [0.10, 0.78, 0.10, 0.02, 0]
            ),
            decorateSwim(
                date: day(-3), durationMin: 40, distanceMi: 1.12,
                avgHR: 138, maxHR: 158, calories: 380,
                note: "Drills + 6x200 pull",
                zoneDist: [0.10, 0.55, 0.30, 0.05, 0]
            ),
            decorateRun(
                date: day(-4), durationMin: 38, distanceMi: 3.1,
                avgHR: 138, maxHR: 152, calories: 360, cadence: 165,
                location: "Neighborhood", note: "Recovery shakeout",
                center: (37.7649, -122.4309),
                zoneDist: [0.20, 0.78, 0.02, 0, 0]
            ),
            decorateBike(
                date: day(-5), durationMin: 95, distanceMi: 26.1,
                avgHR: 156, maxHR: 178, calories: 820,
                avgPower: 210, cadence: 88,
                location: "Tiburon loop", note: "Sweet spot 4x12",
                center: (37.8735, -122.4517),
                zoneDist: [0.05, 0.30, 0.20, 0.40, 0.05]
            ),
            decorateHike(
                date: day(-6), durationMin: 110, distanceMi: 5.0,
                avgHR: 128, maxHR: 145, calories: 590,
                location: "Mt. Tam", note: "Trail with vert",
                center: (37.9235, -122.5965),
                zoneDist: [0.30, 0.55, 0.15, 0, 0]
            ),
        ]
        for c in cardios { try await data.addCardio(c) }

        // 3. Strength history — 2 weeks of lifting with all exercise types
        // represented (weighted / bodyweight / banded / timed) so the Library,
        // PRs, and live workout tracker all have something to render.
        let strengthHistory: [StrengthSession] = [
            // Full Body A — ~12 days ago. Weighted compound lifts.
            StrengthSession(
                id: UUID().uuidString,
                name: "Full Body A",
                date: day(-12),
                duration: 52,
                exercises: [
                    ex("Back Squat", .weighted, rest: 150, sets: [
                        set(1, weight: 135, reps: 5),
                        set(2, weight: 185, reps: 5),
                        set(3, weight: 205, reps: 5),
                        set(4, weight: 205, reps: 5),
                    ]),
                    ex("Bench Press", .weighted, rest: 120, sets: [
                        set(1, weight: 115, reps: 5),
                        set(2, weight: 145, reps: 5),
                        set(3, weight: 165, reps: 5),
                    ]),
                    ex("Barbell Row", .weighted, rest: 90, sets: [
                        set(1, weight: 115, reps: 8),
                        set(2, weight: 125, reps: 8),
                        set(3, weight: 135, reps: 6),
                    ]),
                ],
                templateId: nil
            ),
            // Upper Body Push — ~9 days ago. Weighted + banded accessories.
            StrengthSession(
                id: UUID().uuidString,
                name: "Upper Body Push",
                date: day(-9),
                duration: 45,
                exercises: [
                    ex("Overhead Press", .weighted, rest: 120, sets: [
                        set(1, weight: 75, reps: 5),
                        set(2, weight: 85, reps: 5),
                        set(3, weight: 95, reps: 5),
                    ]),
                    ex("Incline DB Press", .weighted, rest: 75, sets: [
                        set(1, weight: 40, reps: 10),
                        set(2, weight: 45, reps: 10),
                        set(3, weight: 45, reps: 8),
                    ]),
                    ex("Band Pull-Apart", .banded, rest: 30, notes: "Scap retraction — superset with press", sets: [
                        set(1, reps: 15, band: "medium"),
                        set(2, reps: 15, band: "medium"),
                        set(3, reps: 15, band: "medium"),
                    ]),
                    ex("Triceps Pushdown", .banded, rest: 45, sets: [
                        set(1, reps: 12, band: "light"),
                        set(2, reps: 12, band: "light"),
                        set(3, reps: 10, band: "light"),
                    ]),
                ],
                templateId: nil
            ),
            // Lower Body Strength — ~5 days ago. Matches the prescribed
            // session in the plan so the user can see the template flow.
            StrengthSession(
                id: UUID().uuidString,
                name: "Lower Body Strength",
                date: day(-5),
                duration: 55,
                exercises: [
                    ex("Trap Bar Deadlift", .weighted, rest: 120, notes: "Top set felt solid", sets: [
                        set(1, weight: 135, reps: 5),
                        set(2, weight: 165, reps: 5),
                        set(3, weight: 185, reps: 5),
                        set(4, weight: 185, reps: 5),
                    ]),
                    ex("Bulgarian Split Squat", .weighted, rest: 90, sets: [
                        set(1, weight: 35, reps: 8),
                        set(2, weight: 35, reps: 8),
                        set(3, weight: 35, reps: 8),
                    ]),
                    ex("Single Leg RDL", .weighted, rest: 60, sets: [
                        set(1, weight: 30, reps: 10),
                        set(2, weight: 30, reps: 10),
                        set(3, weight: 30, reps: 10),
                    ]),
                    ex("Plank", .timed, rest: 30, sets: [
                        set(1, duration: 45),
                        set(2, duration: 45),
                        set(3, duration: 60),
                    ]),
                ],
                templateId: nil
            ),
            // Core & Mobility — ~2 days ago. Bodyweight + timed holds.
            StrengthSession(
                id: UUID().uuidString,
                name: "Core & Mobility",
                date: day(-2),
                duration: 28,
                exercises: [
                    ex("Push-Up", .bodyweight, rest: 60, sets: [
                        set(1, reps: 15),
                        set(2, reps: 15),
                        set(3, reps: 12),
                    ]),
                    ex("Hollow Hold", .timed, rest: 30, sets: [
                        set(1, duration: 30),
                        set(2, duration: 30),
                        set(3, duration: 30),
                    ]),
                    ex("Side Plank", .timed, rest: 30, notes: "Each side", sets: [
                        set(1, duration: 30),
                        set(2, duration: 30),
                    ]),
                    ex("Bird Dog", .bodyweight, rest: 30, sets: [
                        set(1, reps: 10),
                        set(2, reps: 10),
                    ]),
                ],
                templateId: nil
            ),
        ]
        for s in strengthHistory { try await data.addStrength(s) }

        // 4. Events — upcoming race + completed PR
        var marathon = Event.create(presetId: "marathon", name: "Big Sur Marathon", mode: .race)
        marathon.date = day(45)
        marathon.location = "Carmel, CA"
        marathon.distance = "26.2mi"
        marathon.goal = "3:45:00"
        marathon.stretchGoal = "3:38:00"
        try await data.addEvent(marathon)

        var ten_k = Event.create(presetId: "10k", name: "Spring 10K", mode: .race)
        ten_k.date = day(-30)
        ten_k.location = "Local"
        ten_k.distance = "10K"
        ten_k.goal = "44:00"
        ten_k.result = "43:21"
        ten_k.completed = true
        try await data.addEvent(ten_k)

        // 4b. Strength templates — quick-start workouts the athlete can
        // launch from LogTab's "Start Workout" banner.
        let templates: [Template] = [
            Template(
                id: UUID().uuidString,
                name: "Upper Body Push",
                exercises: [
                    ex("Bench Press", .weighted, rest: 120, sets: [
                        set(1, weight: 115, reps: 5, done: false),
                        set(2, weight: 145, reps: 5, done: false),
                        set(3, weight: 165, reps: 5, done: false),
                    ]),
                    ex("Overhead Press", .weighted, rest: 120, sets: [
                        set(1, weight: 75, reps: 5, done: false),
                        set(2, weight: 85, reps: 5, done: false),
                        set(3, weight: 95, reps: 5, done: false),
                    ]),
                    ex("Incline DB Press", .weighted, rest: 75, sets: [
                        set(1, weight: 45, reps: 10, done: false),
                        set(2, weight: 45, reps: 10, done: false),
                        set(3, weight: 45, reps: 10, done: false),
                    ]),
                    ex("Triceps Pushdown", .banded, rest: 45, sets: [
                        set(1, reps: 12, band: "light", done: false),
                        set(2, reps: 12, band: "light", done: false),
                        set(3, reps: 12, band: "light", done: false),
                    ]),
                    ex("Band Pull-Apart", .banded, rest: 30, sets: [
                        set(1, reps: 15, band: "medium", done: false),
                        set(2, reps: 15, band: "medium", done: false),
                        set(3, reps: 15, band: "medium", done: false),
                    ]),
                ],
                lastUsed: day(-9)
            ),
            Template(
                id: UUID().uuidString,
                name: "Lower Body Strength",
                exercises: [
                    ex("Trap Bar Deadlift", .weighted, rest: 120, sets: [
                        set(1, weight: 135, reps: 5, done: false),
                        set(2, weight: 165, reps: 5, done: false),
                        set(3, weight: 185, reps: 5, done: false),
                        set(4, weight: 185, reps: 5, done: false),
                    ]),
                    ex("Bulgarian Split Squat", .weighted, rest: 90, sets: [
                        set(1, weight: 35, reps: 8, done: false),
                        set(2, weight: 35, reps: 8, done: false),
                        set(3, weight: 35, reps: 8, done: false),
                    ]),
                    ex("Single Leg RDL", .weighted, rest: 60, sets: [
                        set(1, weight: 30, reps: 10, done: false),
                        set(2, weight: 30, reps: 10, done: false),
                        set(3, weight: 30, reps: 10, done: false),
                    ]),
                    ex("Plank", .timed, rest: 30, sets: [
                        set(1, duration: 45, done: false),
                        set(2, duration: 45, done: false),
                        set(3, duration: 60, done: false),
                    ]),
                ],
                lastUsed: day(-5)
            ),
            Template(
                id: UUID().uuidString,
                name: "Full Body Quick",
                exercises: [
                    ex("Goblet Squat", .weighted, rest: 60, sets: [
                        set(1, weight: 45, reps: 10, done: false),
                        set(2, weight: 45, reps: 10, done: false),
                        set(3, weight: 45, reps: 10, done: false),
                    ]),
                    ex("Push-Up", .bodyweight, rest: 45, sets: [
                        set(1, reps: 15, done: false),
                        set(2, reps: 15, done: false),
                        set(3, reps: 15, done: false),
                    ]),
                    ex("DB Row", .weighted, rest: 60, sets: [
                        set(1, weight: 40, reps: 10, done: false),
                        set(2, weight: 40, reps: 10, done: false),
                        set(3, weight: 40, reps: 10, done: false),
                    ]),
                    ex("Plank", .timed, rest: 30, sets: [
                        set(1, duration: 45, done: false),
                        set(2, duration: 45, done: false),
                    ]),
                ],
                lastUsed: day(-18)
            ),
        ]
        for t in templates { try await data.saveTemplate(t) }

        // 4c. Personal records — surface something in ExerciseLibraryView
        // without waiting for the live-workout flow to roll new PRs.
        let prs: [PersonalRecord] = [
            PersonalRecord(
                exerciseSlug: "back-squat", exerciseType: .weighted,
                weight: 205, reps: 5, estimated1RM: 231,
                bestReps: nil, bestDuration: nil, band: nil,
                date: day(-12),
                history: [
                    PRHistoryEntry(weight: 185, reps: 5, estimated1RM: 208, date: day(-33)),
                    PRHistoryEntry(weight: 195, reps: 5, estimated1RM: 220, date: day(-20)),
                    PRHistoryEntry(weight: 205, reps: 5, estimated1RM: 231, date: day(-12)),
                ]
            ),
            PersonalRecord(
                exerciseSlug: "bench-press", exerciseType: .weighted,
                weight: 165, reps: 5, estimated1RM: 186,
                bestReps: nil, bestDuration: nil, band: nil,
                date: day(-12),
                history: [
                    PRHistoryEntry(weight: 155, reps: 5, estimated1RM: 174, date: day(-26)),
                    PRHistoryEntry(weight: 165, reps: 5, estimated1RM: 186, date: day(-12)),
                ]
            ),
            PersonalRecord(
                exerciseSlug: "trap-bar-deadlift", exerciseType: .weighted,
                weight: 185, reps: 5, estimated1RM: 208,
                bestReps: nil, bestDuration: nil, band: nil,
                date: day(-5),
                history: [
                    PRHistoryEntry(weight: 165, reps: 5, estimated1RM: 186, date: day(-19)),
                    PRHistoryEntry(weight: 185, reps: 5, estimated1RM: 208, date: day(-5)),
                ]
            ),
            PersonalRecord(
                exerciseSlug: "overhead-press", exerciseType: .weighted,
                weight: 95, reps: 5, estimated1RM: 107,
                bestReps: nil, bestDuration: nil, band: nil,
                date: day(-9),
                history: [
                    PRHistoryEntry(weight: 85, reps: 5, estimated1RM: 96, date: day(-23)),
                    PRHistoryEntry(weight: 95, reps: 5, estimated1RM: 107, date: day(-9)),
                ]
            ),
            PersonalRecord(
                exerciseSlug: "push-up", exerciseType: .bodyweight,
                weight: nil, reps: nil, estimated1RM: nil,
                bestReps: 15, bestDuration: nil, band: nil,
                date: day(-2),
                history: [
                    PRHistoryEntry(reps: 12, date: day(-30)),
                    PRHistoryEntry(reps: 15, date: day(-2)),
                ]
            ),
            PersonalRecord(
                exerciseSlug: "plank", exerciseType: .timed,
                weight: nil, reps: nil, estimated1RM: nil,
                bestReps: nil, bestDuration: 60, band: nil,
                date: day(-5),
                history: [
                    PRHistoryEntry(duration: 45, date: day(-20)),
                    PRHistoryEntry(duration: 60, date: day(-5)),
                ]
            ),
        ]
        for pr in prs { try await data.savePR(pr) }

        // 5. Training plan with rich phase data + 6 weeks of base sessions.
        // Plan start is snapped to Monday so week math lines up: day 0 of
        // week N is always a Monday for consumers downstream.
        let rawStart = cal.date(byAdding: .day, value: -14, to: today)!
        let planStartStr = localDateString(from: mondayOf(rawStart))
        let plan = TrainingPlan(
            id: UUID().uuidString,
            goalId: marathon.id,
            raceName: "Big Sur Marathon",
            raceDate: day(45),
            startDate: planStartStr,
            totalWeeks: 12,
            currentWeek: 3,
            currentPhase: 1,
            trainingDaysPerWeek: 6,
            phases: [
                basePhase(startOffset: -14),
                buildPhase(startOffset: 28),
                taperPhase(startOffset: 63),
            ],
            weeklyPlans: Dictionary(
                uniqueKeysWithValues:
                    (1...6).map { (String($0), baseWeek(num: $0)) }
                    + (7...11).map { (String($0), buildWeek(num: $0)) }
                    + [("12", taperWeek())]
            )
        )
        try await data.savePlan(plan)

        // 6. Coaching memory
        var mem = data.memory
        mem.permanent = PermanentMemory(
            equipment: ["Trap bar", "Adjustable dumbbells", "Bike trainer", "Pull-up bar"],
            facilities: ["Home gym", "Local pool", "Trail access"],
            schedule: Schedule(
                availableDays: 6,
                preferredTimes: "Early mornings before work",
                constraints: ["No Friday workouts", "Tuesdays max 60m"]
            ),
            medicalHistory: ["Prior R achilles tendinopathy (2023, resolved)"],
            dietaryConstraints: ["Vegetarian"],
            communicationPrefs: "Direct and data-driven. Skip the pep talks.",
            safetyRules: [
                SafetyRule(
                    rule: "No back-to-back hard run days",
                    reason: "History of achilles flare-ups",
                    addedDate: day(-60)
                )
            ]
        )
        mem.observations = Observations(
            patterns: ["Stronger in mornings", "Drops Z2 discipline on weekends"],
            motivators: ["Race goals", "Streak tracking"],
            consistency: "High — 5-6 sessions/week for the last 8 weeks",
            currentFocus: "Build aerobic base for Big Sur Marathon",
            openItems: ["Confirm long-run fueling strategy"],
            coachingNotes: [
                CoachingNoteEntry.newTracking(
                    text: "Tends to under-fuel long runs — keep nudging 60g carbs/hr",
                    relatedTopic: "fueling"
                ),
                CoachingNoteEntry.newTracking(
                    text: "Responds well to RPE-based prescriptions",
                    relatedTopic: "communication"
                ),
            ]
        )
        mem.responseProfile = ResponseProfile(
            volumeVsIntensity: "Tolerates volume well; intensity needs more recovery",
            recoveryRate: "48h after Z4+ sessions",
            easyDayDiscipline: "Slips above Z2 on flat routes",
            sessionPreferences: "Prefers long runs on Saturday mornings",
            skipPatterns: ["Skips drills if rushed"],
            communicationNeeds: "Brief, specific, no fluff"
        )
        mem.injuries = [
            InjuryRecord(
                id: UUID().uuidString,
                area: "Right achilles",
                status: "monitoring",
                severity: "mild",
                firstReported: day(-90),
                lastUpdated: day(-7),
                triggers: ["Hill repeats", "Speed work without warmup"],
                safeActivities: ["Easy runs", "Cycling", "Swimming"],
                modifications: ["Skip plyometrics", "Calf raises 3x/wk"],
                returnCriteria: "Pain-free after 2 hard run days in a row",
                history: [
                    InjuryHistoryEntry(date: day(-30), note: "Mild stiffness after long run"),
                    InjuryHistoryEntry(date: day(-7), note: "No symptoms this week"),
                ]
            )
        ]
        mem.benchmarks = [
            Benchmark(metric: "5K time", value: "20:42", testDate: day(-45), method: "Time trial"),
            Benchmark(metric: "FTP", value: "245W", testDate: day(-30), method: "20m test"),
            Benchmark(metric: "Threshold HR", value: "172 bpm", testDate: day(-45), method: nil),
        ]
        mem.lastUpdated = ISO8601DateFormatter().string(from: today)
        try await data.saveMemory(mem)
    }

    // MARK: - Phase builders

    private static func basePhase(startOffset: Int) -> TrainingPhase {
        let cal = Calendar.current
        let today = Date()
        func day(_ offset: Int) -> String {
            localDateString(from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        return TrainingPhase(
            number: 1,
            name: "Base",
            startDate: day(startOffset),
            endDate: day(startOffset + 42),
            weeks: 6,
            deloadWeek: 4,
            philosophy: "Build a deep aerobic foundation that everything else stacks on. Volume goes up, intensity stays low — this is the slow money.",
            weeklyVolumeRange: VolumeRange(min: 6, max: 8, unit: "hours"),
            sessionsPerWeek: 6,
            intensityDistribution: IntensityDistribution(easy: 80, tempo: 15, threshold: 5, vo2max: 0),
            keyWorkouts: [
                KeyWorkout(name: "Long Run", description: "Progressive Z2 long run, capping at 14mi by week 6"),
                KeyWorkout(name: "Tempo Run", description: "Short tempo work, 3x10min @ tempo with 2min jog recovery"),
                KeyWorkout(name: "Endurance Bike", description: "Z2 cross-training to add aerobic load without run impact"),
            ],
            strengthFocus: "Max strength: heavy 3-5 rep work on trap bar deadlift, split squat, and single-leg RDL",
            physiologicalGoals: [
                "Increase mitochondrial density",
                "Improve fat oxidation at submax intensities",
                "Build connective tissue resilience for marathon volume",
            ],
            progressionRules: "Add 10% weekly volume for 3 weeks, then 30% deload on week 4. Long run increases by 1mi per non-deload week.",
            raceSpecificNotes: "Big Sur is a hilly course with significant rolling terrain. Weekly long runs include rolling routes from week 4 onward."
        )
    }

    private static func buildPhase(startOffset: Int) -> TrainingPhase {
        let cal = Calendar.current
        let today = Date()
        func day(_ offset: Int) -> String {
            localDateString(from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        return TrainingPhase(
            number: 2,
            name: "Build",
            startDate: day(startOffset),
            endDate: day(startOffset + 35),
            weeks: 5,
            deloadWeek: 9,
            philosophy: "Convert base fitness into race-specific speed. Marathon-pace miles in long runs, threshold work mid-week.",
            weeklyVolumeRange: VolumeRange(min: 8, max: 10, unit: "hours"),
            sessionsPerWeek: 6,
            intensityDistribution: IntensityDistribution(easy: 75, tempo: 10, threshold: 12, vo2max: 3),
            keyWorkouts: [
                KeyWorkout(name: "MP Long Run", description: "Progressive long run with final 3-6mi at marathon pace"),
                KeyWorkout(name: "Threshold Intervals", description: "5x1mi @ threshold w/ 90s jog, building to 6x1mi"),
                KeyWorkout(name: "Hill Repeats", description: "8x60s hard uphill efforts with jog-down recovery"),
            ],
            strengthFocus: "Power: explosive lifts (jump squats, kettlebell swings), reduced volume to preserve legs for run sessions",
            physiologicalGoals: [
                "Raise lactate threshold velocity",
                "Improve running economy at marathon pace",
                "Sharpen neuromuscular power for late-race efficiency",
            ],
            progressionRules: "Long run holds at peak (16-18mi) for 3 weeks, deload on week 9 (cut 30% volume + drop intensity work).",
            raceSpecificNotes: "MP work includes downhill segments to prep for Big Sur's net descent. Hill repeats simulate Hurricane Point."
        )
    }

    private static func taperPhase(startOffset: Int) -> TrainingPhase {
        let cal = Calendar.current
        let today = Date()
        func day(_ offset: Int) -> String {
            localDateString(from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        return TrainingPhase(
            number: 3,
            name: "Taper",
            startDate: day(startOffset),
            endDate: day(startOffset + 14),
            weeks: 1,
            deloadWeek: nil,
            philosophy: "Drop volume hard, keep intensity sharp. The work is done — the goal now is to arrive fresh.",
            weeklyVolumeRange: VolumeRange(min: 4, max: 5, unit: "hours"),
            sessionsPerWeek: 5,
            intensityDistribution: IntensityDistribution(easy: 80, tempo: 5, threshold: 10, vo2max: 5),
            keyWorkouts: [
                KeyWorkout(name: "Race Pace Strides", description: "8x100m strides at MP to keep neuromuscular system primed"),
                KeyWorkout(name: "Mini Tempo", description: "20min easy + 15min @ tempo + 10min easy — short and crisp"),
            ],
            strengthFocus: "Maintenance only: 1 short session, lighter loads, no leg fatigue",
            physiologicalGoals: [
                "Restore glycogen stores",
                "Allow connective tissue full recovery",
                "Maintain neuromuscular sharpness",
            ],
            progressionRules: "Volume drops 50% week 1, intensity stays at 80% of build phase. Last hard session 5 days out.",
            raceSpecificNotes: "Carb loading begins 3 days out. Final shakeout run morning of race day, 15min easy + 4 strides."
        )
    }

    // MARK: - Cardio decoration helpers

    private static func decorateRun(
        date: String, durationMin: Int, distanceMi: Double,
        avgHR: Int, maxHR: Int, calories: Int, cadence: Int,
        location: String, note: String,
        center: (lat: Double, lng: Double),
        zoneDist: [Double]
    ) -> CardioWorkout {
        var w = CardioWorkout(
            id: UUID().uuidString, sport: .run, duration: durationMin,
            distance: String(format: "%.2f mi", distanceMi),
            pace: paceString(min: durationMin, mi: distanceMi),
            avgHR: avgHR, maxHR: maxHR,
            calories: calories, avgPower: nil, hrZones: nil,
            notes: note, date: date,
            startTime: nil, endTime: nil, location: location, source: "healthkit"
        )
        attachHealth(
            &w, durationMin: durationMin, distanceMi: distanceMi,
            avgHR: avgHR, maxHR: maxHR, avgPower: nil, cadence: cadence,
            zoneDist: zoneDist
        )
        w.routeSummary = makeRoute(centerLat: center.lat, centerLng: center.lng, miles: distanceMi)
        w.elevationGain = 60
        w.avgCadence = cadence
        return w
    }

    private static func decorateBike(
        date: String, durationMin: Int, distanceMi: Double,
        avgHR: Int, maxHR: Int, calories: Int,
        avgPower: Int, cadence: Int,
        location: String, note: String,
        center: (lat: Double, lng: Double),
        zoneDist: [Double]
    ) -> CardioWorkout {
        var w = CardioWorkout(
            id: UUID().uuidString, sport: .bike, duration: durationMin,
            distance: String(format: "%.1f mi", distanceMi),
            pace: nil,
            avgHR: avgHR, maxHR: maxHR,
            calories: calories, avgPower: avgPower, hrZones: nil,
            notes: note, date: date,
            startTime: nil, endTime: nil, location: location, source: "healthkit"
        )
        attachHealth(
            &w, durationMin: durationMin, distanceMi: distanceMi,
            avgHR: avgHR, maxHR: maxHR, avgPower: avgPower, cadence: cadence,
            zoneDist: zoneDist
        )
        w.routeSummary = makeRoute(centerLat: center.lat, centerLng: center.lng, miles: distanceMi)
        w.elevationGain = 220
        w.avgCadence = cadence
        return w
    }

    private static func decorateSwim(
        date: String, durationMin: Int, distanceMi: Double,
        avgHR: Int, maxHR: Int, calories: Int,
        note: String, zoneDist: [Double]
    ) -> CardioWorkout {
        var w = CardioWorkout(
            id: UUID().uuidString, sport: .swim, duration: durationMin,
            distance: String(format: "%.0f m", distanceMi * 1609.34),
            pace: "2:13 /100m",
            avgHR: avgHR, maxHR: maxHR,
            calories: calories, avgPower: nil, hrZones: nil,
            notes: note, date: date,
            startTime: nil, endTime: nil, location: "Pool", source: "healthkit"
        )
        attachHealth(
            &w, durationMin: durationMin, distanceMi: distanceMi,
            avgHR: avgHR, maxHR: maxHR, avgPower: nil, cadence: nil,
            zoneDist: zoneDist
        )
        return w
    }

    private static func decorateHike(
        date: String, durationMin: Int, distanceMi: Double,
        avgHR: Int, maxHR: Int, calories: Int,
        location: String, note: String,
        center: (lat: Double, lng: Double),
        zoneDist: [Double]
    ) -> CardioWorkout {
        var w = CardioWorkout(
            id: UUID().uuidString, sport: .hike, duration: durationMin,
            distance: String(format: "%.1f mi", distanceMi),
            pace: nil,
            avgHR: avgHR, maxHR: maxHR,
            calories: calories, avgPower: nil, hrZones: nil,
            notes: note, date: date,
            startTime: nil, endTime: nil, location: location, source: "healthkit"
        )
        attachHealth(
            &w, durationMin: durationMin, distanceMi: distanceMi,
            avgHR: avgHR, maxHR: maxHR, avgPower: nil, cadence: nil,
            zoneDist: zoneDist
        )
        w.routeSummary = makeRoute(centerLat: center.lat, centerLng: center.lng, miles: distanceMi)
        w.elevationGain = 480
        return w
    }

    private static func attachHealth(
        _ w: inout CardioWorkout,
        durationMin: Int, distanceMi: Double,
        avgHR: Int, maxHR: Int, avgPower: Int?, cadence: Int?,
        zoneDist: [Double]
    ) {
        let nowIso = ISO8601DateFormatter().string(from: Date())
        let stats = WorkoutStats(
            avgHR: avgHR, maxHR: maxHR, minHR: max(60, avgHR - 30),
            totalEnergy: w.calories,
            totalDistance: distanceMi * 1609.34,
            avgPower: avgPower, maxPower: avgPower.map { Int(Double($0) * 1.5) },
            avgCadence: cadence, avgSpeed: distanceMi * 1609.34 / Double(durationMin * 60),
            elevationGain: nil, swimStrokes: nil, flightsClimbed: nil
        )
        let weather = WeatherSnapshot(tempC: 14, humidity: 62, conditions: "Partly cloudy")
        w.weather = weather
        w.healthData = HealthWorkoutDetail(
            startTime: nowIso, endTime: nowIso, indoor: false,
            stats: stats,
            hrSamples: makeHRSamples(durationMin: durationMin, avg: avgHR, peak: maxHR),
            powerSamples: avgPower.map { makePowerSamples(durationMin: durationMin, avg: $0) },
            cadenceSamples: cadence.map { makeCadenceSamples(durationMin: durationMin, avg: $0) },
            speedSamples: nil,
            hrZones: makeHRZones(totalMin: durationMin, distribution: zoneDist),
            laps: makeLaps(durationMin: durationMin, count: 5, distanceMi: distanceMi, avgHR: avgHR),
            events: nil, subActivities: nil,
            source: SourceInfo(app: "Workout", device: "Apple Watch Ultra", version: "10.4"),
            weather: weather, metadata: nil
        )
        w.syncedAt = nowIso
    }

    // MARK: - Synthetic series generators

    private static func makeHRSamples(durationMin: Int, avg: Int, peak: Int) -> [TimedSample] {
        let n = 60
        let total = Double(durationMin * 60)
        return (0..<n).map { i in
            let progress = Double(i) / Double(n - 1)
            let warmup = sin(progress * .pi)               // 0 → 1 → 0
            let noise = sin(Double(i) * 0.9) * 4
            let v = Double(avg) + Double(peak - avg) * 0.6 * warmup + noise
            return TimedSample(t: Double(i) * total / Double(n - 1), v: v.rounded())
        }
    }

    private static func makePowerSamples(durationMin: Int, avg: Int) -> [TimedSample] {
        let n = 60
        let total = Double(durationMin * 60)
        return (0..<n).map { i in
            let progress = Double(i) / Double(n - 1)
            let pulse = sin(progress * .pi * 4) * 35
            let noise = sin(Double(i) * 1.3) * 10
            let v = Double(avg) + pulse + noise
            return TimedSample(t: Double(i) * total / Double(n - 1), v: max(50, v).rounded())
        }
    }

    private static func makeCadenceSamples(durationMin: Int, avg: Int) -> [TimedSample] {
        let n = 60
        let total = Double(durationMin * 60)
        return (0..<n).map { i in
            let v = Double(avg) + sin(Double(i) * 0.6) * 4
            return TimedSample(t: Double(i) * total / Double(n - 1), v: v.rounded())
        }
    }

    private static func makeHRZones(totalMin: Int, distribution: [Double]) -> HRZoneBreakdown {
        let totalSec = totalMin * 60
        let secs = (0..<5).map { i -> Int in
            guard i < distribution.count else { return 0 }
            return Int(Double(totalSec) * distribution[i])
        }
        return HRZoneBreakdown(z1: secs[0], z2: secs[1], z3: secs[2], z4: secs[3], z5: secs[4])
    }

    private static func makeLaps(durationMin: Int, count: Int, distanceMi: Double, avgHR: Int) -> [LapSplit] {
        let lapDur = Double(durationMin * 60) / Double(count)
        let lapDist = distanceMi * 1609.34 / Double(count)
        let nowIso = ISO8601DateFormatter().string(from: Date())
        return (0..<count).map { i in
            LapSplit(
                index: i + 1,
                startTime: nowIso,
                duration: lapDur,
                distance: lapDist,
                avgHR: avgHR + (i - count / 2) * 2,
                avgPace: nil
            )
        }
    }

    private static func makeRoute(centerLat: Double, centerLng: Double, miles: Double) -> RouteSummary {
        let radius = (miles / 2.0) / 69.0   // rough degrees latitude
        let n = 80
        let pts: [RoutePoint] = (0..<n).map { i in
            let angle = Double(i) / Double(n) * 2 * .pi
            let r = radius * (1 + sin(angle * 3) * 0.15)
            return RoutePoint(
                lat: centerLat + sin(angle) * r,
                lng: centerLng + cos(angle) * r * 1.25,
                alt: 100 + sin(angle * 2) * 30,
                t: Double(i) * 30,
                speed: 3.0
            )
        }
        let lats = pts.map(\.lat)
        let lngs = pts.map(\.lng)
        return RouteSummary(
            points: pts,
            bbox: RouteSummary.BoundingBox(
                minLat: lats.min() ?? 0,
                minLng: lngs.min() ?? 0,
                maxLat: lats.max() ?? 0,
                maxLng: lngs.max() ?? 0
            ),
            pointCount: n,
            distance: miles * 1609.34,
            elevationGain: 60
        )
    }

    private static func paceString(min: Int, mi: Double) -> String {
        let perMile = Double(min) / mi
        let m = Int(perMile)
        let s = Int((perMile - Double(m)) * 60)
        return String(format: "%d:%02d /mi", m, s)
    }

    // MARK: - Week builder

    private static func baseWeek(num: Int) -> WeeklyPlan {
        // Long run progresses 8 → 10 → 12 → 8 (deload) → 13 → 14
        let longRunMiles: [Double] = [8, 10, 12, 8, 13, 14]
        let longRunIdx = min(num - 1, longRunMiles.count - 1)
        let longRun = longRunMiles[longRunIdx]
        let isDeload = num == 4
        // Demo completion on the first two weeks (in the past)
        let isPast = num <= 2

        let easyMiles = isDeload ? 3.0 : 5.0
        let tempoMiles = isDeload ? 4.0 : Double(5 + min(num, 3))
        let bikeMiles = isDeload ? 15.0 : Double(18 + num * 2)

        return WeeklyPlan(
            weekNumber: num,
            phase: 1,
            focusOfWeek: isDeload
                ? "Deload — drop volume, keep one quality day to maintain sharpness."
                : "Aerobic base — long run \(Int(longRun))mi, one tempo session.",
            sessions: [
                DayPlan(day: "monday", isRest: false, sessions: [
                    runSession(
                        label: "\(easyMiles.formattedMi) Easy Run",
                        miles: easyMiles, effort: .easy, zone: "Z2",
                        durMin: Int(easyMiles * 8.5), durMax: Int(easyMiles * 9.5),
                        purpose: "Aerobic base", workout: "\(Int(easyMiles))mi steady",
                        notes: "Keep HR under 145.",
                        completed: isPast
                    )
                ]),
                DayPlan(day: "tuesday", isRest: false, sessions: [
                    strengthSession(
                        label: "Lower Body Strength",
                        durMin: 45, durMax: 55,
                        workout: "Trap bar DL 4x5, BSS 3x8, SL RDL 3x10",
                        completed: isPast,
                        exercises: lowerBodyStrengthExercises
                    ),
                    runSession(
                        label: "30m Easy Spin", miles: 8, effort: .recovery, zone: "Z1",
                        durMin: 25, durMax: 35,
                        sport: "bike",
                        purpose: "Recovery", workout: "30m spin, easy gear",
                        notes: nil,
                        completed: isPast
                    ),
                ]),
                DayPlan(day: "wednesday", isRest: false, sessions: [
                    runSession(
                        label: isDeload ? "\(tempoMiles.formattedMi) Easy Run" : "\(tempoMiles.formattedMi) Tempo",
                        miles: tempoMiles,
                        effort: isDeload ? .easy : .tempo,
                        zone: isDeload ? "Z2" : "Z3",
                        durMin: Int(tempoMiles * 8), durMax: Int(tempoMiles * 9),
                        purpose: isDeload ? "Recovery" : "Lactate threshold",
                        workout: isDeload ? "\(Int(tempoMiles))mi easy" : "1.5mi wu / 3x1mi @ tempo / 1mi cd",
                        notes: nil,
                        completed: isPast
                    )
                ]),
                DayPlan(day: "thursday", isRest: false, sessions: [
                    runSession(
                        label: "Aerobic Swim",
                        miles: 1.2, effort: .easy, zone: "Z2",
                        durMin: 35, durMax: 45,
                        sport: "swim",
                        purpose: "Cross-train", workout: "Drills + 8x100",
                        notes: nil,
                        completed: isPast
                    )
                ]),
                DayPlan(day: "friday", isRest: true, sessions: []),
                DayPlan(day: "saturday", isRest: false, sessions: [
                    runSession(
                        label: "\(longRun.formattedMi) Long Run",
                        miles: longRun, effort: .longEndurance, zone: "Z2",
                        durMin: Int(longRun * 9), durMax: Int(longRun * 11),
                        purpose: "Aerobic endurance",
                        workout: "\(Int(longRun))mi steady — last 2mi at MP if feeling strong",
                        notes: "Practice race-day fueling.",
                        completed: isPast
                    )
                ]),
                DayPlan(day: "sunday", isRest: false, sessions: [
                    runSession(
                        label: "\(bikeMiles.formattedMi) Endurance Ride",
                        miles: bikeMiles, effort: .easy, zone: "Z2",
                        durMin: Int(bikeMiles * 2.7), durMax: Int(bikeMiles * 3.2),
                        sport: "bike",
                        purpose: "Aerobic + recovery",
                        workout: "\(Int(bikeMiles))mi rolling Z2",
                        notes: nil,
                        completed: isPast
                    )
                ]),
            ]
        )
    }

    private static func buildWeek(num: Int) -> WeeklyPlan {
        // num is 7-11 within the plan
        let buildIdx = num - 7   // 0-4
        let longRunMiles: [Double] = [16, 17, 18, 14, 18]   // week 10 (idx 3) is deload
        let longRun = longRunMiles[min(buildIdx, longRunMiles.count - 1)]
        let isDeload = num == 10
        let mpMiles = isDeload ? 0.0 : Double(min(buildIdx + 2, 6))   // last 2-6mi at MP

        return WeeklyPlan(
            weekNumber: num,
            phase: 2,
            focusOfWeek: isDeload
                ? "Deload — recover from peak build, hold one threshold session."
                : "Build — long run \(Int(longRun))mi with \(Int(mpMiles))mi @ marathon pace.",
            sessions: [
                DayPlan(day: "monday", isRest: false, sessions: [
                    runSession(
                        label: "5.0mi Easy Run", miles: 5.0, effort: .easy, zone: "Z2",
                        durMin: 42, durMax: 48,
                        purpose: "Recovery from threshold day",
                        workout: "5mi conversational",
                        notes: nil
                    )
                ]),
                DayPlan(day: "tuesday", isRest: false, sessions: [
                    strengthSession(
                        label: "Power Strength",
                        durMin: 35, durMax: 45,
                        workout: "Jump squats 4x5, KB swings 4x10, push press 3x5",
                        notes: "Explosive intent, full recovery.",
                        exercises: powerStrengthExercises
                    ),
                    runSession(
                        label: "30m Easy Spin", miles: 8, effort: .recovery, zone: "Z1",
                        durMin: 25, durMax: 35, sport: "bike",
                        purpose: "Recovery",
                        workout: "Z1 only",
                        notes: nil
                    ),
                ]),
                DayPlan(day: "wednesday", isRest: false, sessions: [
                    runSession(
                        label: isDeload ? "5.0mi Tempo" : "Threshold Intervals",
                        miles: isDeload ? 5.0 : 7.0,
                        effort: .threshold, zone: "Z4",
                        durMin: isDeload ? 40 : 55, durMax: isDeload ? 45 : 65,
                        purpose: "Lactate threshold velocity",
                        workout: isDeload
                            ? "5mi @ tempo, smooth"
                            : "1.5mi wu / 5x1mi @ threshold w/ 90s jog / 1mi cd",
                        notes: "Stay relaxed in upper body."
                    )
                ]),
                DayPlan(day: "thursday", isRest: false, sessions: [
                    runSession(
                        label: "Yoga", miles: 0, effort: .recovery, zone: nil,
                        durMin: 30, durMax: 45, sport: "other",
                        purpose: "Mobility + recovery",
                        workout: "Hip openers + hamstring focus",
                        notes: nil
                    )
                ]),
                DayPlan(day: "friday", isRest: true, sessions: []),
                DayPlan(day: "saturday", isRest: false, sessions: [
                    runSession(
                        label: "\(longRun.formattedMi) Long Run + MP",
                        miles: longRun,
                        effort: .longEndurance, zone: "Z2-Z3",
                        durMin: Int(longRun * 9), durMax: Int(longRun * 10),
                        purpose: "Race-specific endurance",
                        workout: isDeload
                            ? "\(Int(longRun))mi steady — no quality work"
                            : "\(Int(longRun - mpMiles))mi steady → final \(Int(mpMiles))mi @ MP",
                        notes: "Fuel every 30 min. Practice race-day breakfast."
                    )
                ]),
                DayPlan(day: "sunday", isRest: false, sessions: [
                    runSession(
                        label: "30mi Endurance Ride", miles: 30, effort: .easy, zone: "Z2",
                        durMin: 90, durMax: 105, sport: "bike",
                        purpose: "Aerobic recovery from long run",
                        workout: "Rolling Z2",
                        notes: nil
                    )
                ]),
            ]
        )
    }

    private static func taperWeek() -> WeeklyPlan {
        WeeklyPlan(
            weekNumber: 12,
            phase: 3,
            focusOfWeek: "Race week — sharpen, rest, fuel. Final hard session 5 days out.",
            sessions: [
                DayPlan(day: "monday", isRest: false, sessions: [
                    runSession(
                        label: "4.0mi Easy + Strides", miles: 4.0, effort: .easy, zone: "Z2",
                        durMin: 32, durMax: 38,
                        purpose: "Maintain neuromuscular system",
                        workout: "4mi easy + 6x100m strides @ MP",
                        notes: nil
                    )
                ]),
                DayPlan(day: "tuesday", isRest: false, sessions: [
                    runSession(
                        label: "Mini Tempo", miles: 4.5, effort: .tempo, zone: "Z3",
                        durMin: 38, durMax: 42,
                        purpose: "Last quality work",
                        workout: "1mi wu / 2mi @ tempo / 1.5mi cd",
                        notes: "Crisp and short. No grinding."
                    )
                ]),
                DayPlan(day: "wednesday", isRest: true, sessions: []),
                DayPlan(day: "thursday", isRest: false, sessions: [
                    runSession(
                        label: "3.0mi Easy Run", miles: 3.0, effort: .easy, zone: "Z2",
                        durMin: 24, durMax: 28,
                        purpose: "Shake out the legs",
                        workout: "3mi easy",
                        notes: nil
                    )
                ]),
                DayPlan(day: "friday", isRest: false, sessions: [
                    runSession(
                        label: "Shakeout + Strides", miles: 2.5, effort: .recovery, zone: "Z1-Z2",
                        durMin: 22, durMax: 26,
                        purpose: "Race day prep",
                        workout: "2mi easy + 4x100m strides",
                        notes: "Carb load starts today."
                    )
                ]),
                DayPlan(day: "saturday", isRest: true, sessions: []),
                DayPlan(day: "sunday", isRest: false, sessions: [
                    runSession(
                        label: "Race Day", miles: 26.2, effort: .race, zone: "Z3-Z4",
                        durMin: 220, durMax: 235,
                        purpose: "Execute the race plan",
                        workout: "Big Sur Marathon",
                        notes: "Conservative through Hurricane Point. Trust the work."
                    )
                ]),
            ]
        )
    }

    // MARK: - Session helpers

    private static func runSession(
        label: String, miles: Double, effort: EffortCategory, zone: String?,
        durMin: Int, durMax: Int,
        sport: String = "run",
        purpose: String, workout: String, notes: String?,
        completed: Bool = false
    ) -> PrescribedSession {
        PrescribedSession(
            type: sport,
            label: label,
            duration: (durMin + durMax) / 2,
            estimatedDurationMin: durMin,
            estimatedDurationMax: durMax,
            distanceMiles: miles > 0 ? miles : nil,
            effortCategory: effort,
            completed: completed ? true : nil,
            zone: zone,
            targetIntensity: nil,
            purpose: purpose,
            workout: workout,
            fuel: nil,
            priority: nil,
            notes: notes,
            exercises: nil,
            legs: nil,
            templateId: nil
        )
    }

    private static func strengthSession(
        label: String, durMin: Int, durMax: Int, workout: String, notes: String? = nil,
        completed: Bool = false,
        exercises: [PrescribedExercise]? = nil
    ) -> PrescribedSession {
        PrescribedSession(
            type: "strength",
            label: label,
            duration: (durMin + durMax) / 2,
            estimatedDurationMin: durMin,
            estimatedDurationMax: durMax,
            distanceMiles: nil,
            effortCategory: .strength,
            completed: completed ? true : nil,
            zone: nil,
            targetIntensity: nil,
            purpose: "Strength",
            workout: workout,
            fuel: nil,
            priority: nil,
            notes: notes,
            exercises: exercises,
            legs: nil,
            templateId: nil
        )
    }

    // MARK: - Strength fixture helpers

    /// Shorthand for building a logged Exercise with its sets inline.
    private static func ex(
        _ name: String,
        _ type: ExerciseType = .weighted,
        rest: Int? = nil,
        notes: String? = nil,
        sets: [ExerciseSet]
    ) -> Exercise {
        Exercise(
            name: name,
            exerciseType: type,
            sets: sets,
            rest: rest,
            notes: notes
        )
    }

    /// Shorthand for a single ExerciseSet. `done` defaults to true for the
    /// historical-session fixtures; template/prescribed flows pass done: false
    /// so the athlete starts from an untouched rep count.
    private static func set(
        _ num: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: Double? = nil,
        band: String? = nil,
        done: Bool = true
    ) -> ExerciseSet {
        ExerciseSet(
            setNum: num,
            completed: done,
            weight: weight,
            reps: reps,
            duration: duration,
            band: band
        )
    }

    /// Shorthand for building a plan-prescribed exercise (what `Start Workout`
    /// from a prescribed strength session materializes into live sets).
    private static func pe(
        _ name: String,
        _ type: ExerciseType = .weighted,
        sets: Int,
        reps: Int? = nil,
        weight: Double? = nil,
        duration: Double? = nil,
        band: String? = nil,
        rest: Int? = nil,
        notes: String? = nil
    ) -> PrescribedExercise {
        PrescribedExercise(
            name: name,
            exerciseType: type,
            sets: sets,
            reps: reps,
            weight: weight,
            duration: duration,
            band: band,
            rest: rest,
            notes: notes
        )
    }

    /// Lower-body strength prescription used in base weeks. Matches the
    /// seeded "Lower Body Strength" template so the athlete can choose
    /// either entry point.
    private static var lowerBodyStrengthExercises: [PrescribedExercise] {
        [
            pe("Trap Bar Deadlift", .weighted, sets: 4, reps: 5, weight: 185, rest: 120,
               notes: "Work up to a top set of 5 — leave 1 rep in reserve."),
            pe("Bulgarian Split Squat", .weighted, sets: 3, reps: 8, weight: 35, rest: 90,
               notes: "Dumbbells at sides, drive through front heel."),
            pe("Single Leg RDL", .weighted, sets: 3, reps: 10, weight: 30, rest: 60,
               notes: "Hinge from the hip, hamstring focus."),
            pe("Plank", .timed, sets: 3, duration: 45, rest: 30,
               notes: "Brace, no sag."),
        ]
    }

    /// Power-focused strength for build weeks — preserves legs for run days.
    private static var powerStrengthExercises: [PrescribedExercise] {
        [
            pe("Jump Squat", .bodyweight, sets: 4, reps: 5, rest: 90,
               notes: "Explosive — full recovery between sets."),
            pe("Kettlebell Swing", .weighted, sets: 4, reps: 10, weight: 35, rest: 60,
               notes: "Hip hinge, not a squat."),
            pe("Push Press", .weighted, sets: 3, reps: 5, weight: 95, rest: 120,
               notes: "Legs drive, catch overhead with soft knees."),
            pe("Band Pull-Apart", .banded, sets: 3, reps: 15, band: "medium", rest: 30,
               notes: "Scap retraction / shoulder warmup."),
        ]
    }
}

private extension Double {
    var formattedMi: String {
        if self == self.rounded() { return "\(Int(self))mi" }
        return String(format: "%.1fmi", self)
    }
}
