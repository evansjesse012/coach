import Foundation
import Supabase
import Functions

/// Phase 4b: turns a `RecoverySnapshot` (+ optional training-load context)
/// into the 2-3 sentence "recovery_picture" narrative the main coach
/// prompt reads each turn.
///
/// This is a coach-to-coach briefing, not athlete-facing copy — it's
/// describing the situation to the coaching LLM so *it* can respond to
/// the athlete in voice. So we don't pass personality through here; the
/// briefing is plain and analytical, and the main agent translates.
///
/// We use a small fast model (Haiku 4.5) since the input is structured
/// and the output is short. The narrative is cached per-day in
/// `AgentLoop` so this runs at most once per session per calendar day.
@MainActor
enum RecoveryPictureGenerator {

    /// Returns the narrative paragraph, or nil if the snapshot has no
    /// usable signal or the model call fails. Callers should treat nil
    /// as "no recovery picture this turn" — Section 7 already covers the
    /// missing-data case.
    static func generate(
        snapshot: RecoverySnapshot,
        trainingLoad: TrainingLoadSnapshot?
    ) async -> String? {
        guard snapshot.hasAnySignal else { return nil }

        let userPrompt = buildUserPrompt(snapshot: snapshot, trainingLoad: trainingLoad)

        let body: [String: Any] = [
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": userPrompt]],
            "max_tokens": 250,
            "model": "claude-haiku-4-5",
        ]

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return nil
        }

        let client = SupabaseService.shared.client
        do {
            let response: LightResponse = try await client.functions.invoke(
                "chat",
                options: .init(body: bodyData)
            ) { data, response in
                guard 200..<300 ~= response.statusCode else {
                    throw NSError(domain: "RecoveryPictureGenerator", code: response.statusCode)
                }
                return try JSONDecoder().decode(LightResponse.self, from: data)
            }
            let text = response.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    You are an expert endurance coaching assistant producing a brief recovery briefing for the head coach. The head coach will read your briefing and use it to decide what to say to the athlete — your output is coach-to-coach, not athlete-facing.

    Write 2-3 sentences in plain, analytical prose. Reason about the data; do not recite numbers. Frame deltas (e.g. "HRV is well below baseline" rather than "HRV is 41ms vs 52ms baseline"). When training load context is provided, weave it in — a low TSB with rough recovery numbers means something different than a fresh TSB with the same recovery numbers.

    Cover what's notable, not everything. If most signals are normal, say so briefly. If something is sharply off, lead with that. If wrist temperature is elevated alongside rising RHR or respiratory rate, name the possibility of illness. If there's clearly insufficient data to read, say "limited data" and stop.

    Do not give prescriptive advice ("the athlete should..."). Your job is to describe the state, not the response. Output ONLY the briefing paragraph — no preamble, no headers, no bullet points.
    """

    private static func buildUserPrompt(
        snapshot: RecoverySnapshot,
        trainingLoad: TrainingLoadSnapshot?
    ) -> String {
        var lines: [String] = []
        lines.append("Recovery snapshot:")

        if let hrv = snapshot.hrvMs {
            if let base = snapshot.hrvBaselineMs, base > 0 {
                let pct = (hrv - base) / base * 100
                lines.append("- HRV (overnight): \(fmt(hrv)) ms (baseline \(fmt(base)) ms, \(signedPct(pct)))")
            } else {
                lines.append("- HRV (overnight): \(fmt(hrv)) ms (no baseline yet)")
            }
        }
        if let rhr = snapshot.restingHrBpm {
            if let base = snapshot.restingHrBaselineBpm, base > 0 {
                let delta = rhr - base
                lines.append("- Resting HR: \(fmt(rhr)) bpm (baseline \(fmt(base)), \(signed(delta)) bpm)")
            } else {
                lines.append("- Resting HR: \(fmt(rhr)) bpm (no baseline yet)")
            }
        }
        if let rr = snapshot.respiratoryRate {
            if let base = snapshot.respiratoryRateBaseline, base > 0 {
                let delta = rr - base
                lines.append("- Respiratory rate: \(fmt(rr))/min (baseline \(fmt(base)), \(signed(delta)))")
            } else {
                lines.append("- Respiratory rate: \(fmt(rr))/min")
            }
        }
        if let temp = snapshot.wristTempDeltaC {
            lines.append("- Wrist temperature deviation: \(signed(temp)) °C from baseline")
        }
        if let sleep = snapshot.sleep {
            var s = "- Sleep: \(fmt(sleep.asleepHours))h asleep"
            if abs(sleep.inBedHours - sleep.asleepHours) > 0.1 {
                s += " (\(fmt(sleep.inBedHours))h in bed)"
            }
            var stages: [String] = []
            if let d = sleep.deepHours  { stages.append("\(fmt(d))h deep") }
            if let r = sleep.remHours   { stages.append("\(fmt(r))h REM") }
            if let a = sleep.awakeHours { stages.append("\(fmt(a))h awake") }
            if !stages.isEmpty { s += ", " + stages.joined(separator: " / ") }
            lines.append(s)
        }
        if let steps = snapshot.stepsYesterday {
            if let base = snapshot.stepsBaseline, base > 0 {
                let pct = Double(steps - base) / Double(base) * 100
                lines.append("- Steps yesterday: \(steps) (baseline \(base), \(signedPct(pct)))")
            } else {
                lines.append("- Steps yesterday: \(steps)")
            }
        }
        if let kcal = snapshot.activeEnergyYesterdayKcal {
            if let base = snapshot.activeEnergyBaselineKcal, base > 0 {
                let pct = Double(kcal - base) / Double(base) * 100
                lines.append("- Active energy yesterday: \(kcal) kcal (baseline \(base), \(signedPct(pct)))")
            } else {
                lines.append("- Active energy yesterday: \(kcal) kcal")
            }
        }
        if let vo2 = snapshot.vo2Max {
            lines.append("- VO2 max (latest): \(fmt(vo2)) ml/kg/min")
        }
        if let mass = snapshot.bodyMassKg {
            lines.append("- Body mass (latest): \(fmt(mass)) kg")
        }

        if let load = trainingLoad {
            lines.append("")
            lines.append("Training load context:")
            lines.append("- CTL \(fmt(load.ctl)) · ATL \(fmt(load.atl)) · TSB \(fmt(load.tsb))" +
                         (load.ctlRamp7d.map { " · 7d CTL Δ \(signed($0))" } ?? ""))
        }

        lines.append("")
        lines.append("Write the briefing.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting helpers

    private static func fmt(_ x: Double) -> String { String(format: "%.1f", x) }
    private static func signed(_ x: Double) -> String {
        x >= 0 ? "+\(fmt(x))" : fmt(x)
    }
    private static func signedPct(_ x: Double) -> String {
        let s = String(format: "%.0f", x)
        return x >= 0 ? "+\(s)%" : "\(s)%"
    }

    // MARK: - Edge function response

    private struct LightResponse: Codable {
        let content: [Block]
        struct Block: Codable {
            let type: String
            let text: String?
        }
    }
}
