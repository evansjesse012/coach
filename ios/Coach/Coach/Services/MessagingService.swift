import Foundation
import Supabase
import UserNotifications

/// Handles external messaging (SMS/iMessage) and voice calls via Twilio,
/// proxied through Supabase Edge Functions for secure API key management.
@MainActor
@Observable
final class MessagingService {
    var isCallActive = false
    var isSendingSMS = false
    var phoneNumber: String = ""
    var messagingEnabled = false
    var callsEnabled = false
    var error: String?

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - SMS / iMessage

    /// Sends a text message to the user via Twilio SMS.
    /// Called by the coach after completing actions (e.g., "I logged your workout — here's a summary").
    func sendSMS(message: String, to phone: String? = nil) async throws {
        let target = phone ?? phoneNumber
        guard !target.isEmpty else {
            error = "No phone number configured"
            return
        }

        isSendingSMS = true
        defer { isSendingSMS = false }

        let body: [String: Any] = [
            "to": target,
            "message": message,
            "channel": "sms",
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await client.functions.invoke(
            "send-message",
            options: .init(body: bodyData)
        )
    }

    // MARK: - Outbound Coach Call

    /// Initiates a voice call from the coach to the user via Twilio.
    /// The call connects to the AI coach's voice agent for a real-time conversation.
    func initiateCoachCall(
        personality: Personality,
        context: String = ""
    ) async throws {
        guard !phoneNumber.isEmpty else {
            error = "No phone number configured"
            return
        }

        isCallActive = true

        let body: [String: Any] = [
            "to": phoneNumber,
            "personality": personality.rawValue,
            "context": context,
            "action": "initiate_call",
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        do {
            _ = try await client.functions.invoke(
                "coach-call",
                options: .init(body: bodyData)
            )
        } catch {
            isCallActive = false
            throw error
        }
    }

    /// Ends the active coach call.
    func endCoachCall() async {
        let body: [String: Any] = [
            "action": "end_call",
            "to": phoneNumber,
        ]

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            _ = try await client.functions.invoke(
                "coach-call",
                options: .init(body: bodyData)
            )
        } catch {
            // Call may have already ended
        }

        isCallActive = false
    }

    // MARK: - Schedule Coach Check-in

    /// Schedules the coach to call or text the user at a specific time.
    /// Useful for morning check-ins, post-workout reviews, etc.
    func scheduleCheckIn(
        type: CheckInType,
        time: Date,
        personality: Personality,
        message: String? = nil
    ) async throws {
        let formatter = ISO8601DateFormatter()

        let body: [String: Any] = [
            "action": "schedule",
            "type": type.rawValue,
            "scheduled_at": formatter.string(from: time),
            "personality": personality.rawValue,
            "message": message ?? "",
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await client.functions.invoke(
            "coach-call",
            options: .init(body: bodyData)
        )
    }

    // MARK: - Register Push Token

    func registerPushToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        let body: [String: String] = [
            "token": tokenString,
            "platform": "ios",
        ]

        do {
            let bodyData = try JSONEncoder().encode(body)
            _ = try await client.functions.invoke(
                "register-device",
                options: .init(body: bodyData)
            )
        } catch {
            // Silent fail — push registration is best-effort
        }
    }
}

// MARK: - Check-In Types

enum CheckInType: String, Codable, CaseIterable, Identifiable {
    case morningBrief = "morning_brief"
    case preWorkout = "pre_workout"
    case postWorkout = "post_workout"
    case eveningReview = "evening_review"
    case accountability = "accountability"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morningBrief: return "Morning Brief"
        case .preWorkout: return "Pre-Workout"
        case .postWorkout: return "Post-Workout"
        case .eveningReview: return "Evening Review"
        case .accountability: return "Accountability Check"
        }
    }

    var description: String {
        switch self {
        case .morningBrief: return "Today's plan and motivation"
        case .preWorkout: return "Warm-up and session preview"
        case .postWorkout: return "Recovery and session review"
        case .eveningReview: return "Day summary and tomorrow's prep"
        case .accountability: return "Are you doing the work?"
        }
    }

    var sfSymbol: String {
        switch self {
        case .morningBrief: return "sunrise.fill"
        case .preWorkout: return "figure.run"
        case .postWorkout: return "checkmark.circle.fill"
        case .eveningReview: return "moon.stars.fill"
        case .accountability: return "flame.fill"
        }
    }
}

// MARK: - Messaging Channel

enum MessagingChannel: String, Codable, CaseIterable, Identifiable {
    case sms
    case push
    case call

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sms: return "Text Message"
        case .push: return "Push Notification"
        case .call: return "Phone Call"
        }
    }
}
