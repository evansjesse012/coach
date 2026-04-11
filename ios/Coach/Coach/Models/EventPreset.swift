import Foundation

struct EventPreset: Identifiable {
    let id: String
    let name: String
    let icon: String      // SF Symbol name
    let category: String
    let defaultMode: EventMode

    static let all: [EventPreset] = [
        EventPreset(id: "marathon", name: "Marathon", icon: "figure.run", category: "Running", defaultMode: .race),
        EventPreset(id: "half-marathon", name: "Half Marathon", icon: "figure.run", category: "Running", defaultMode: .race),
        EventPreset(id: "10k", name: "10K", icon: "figure.run", category: "Running", defaultMode: .race),
        EventPreset(id: "5k", name: "5K", icon: "figure.run", category: "Running", defaultMode: .race),
        EventPreset(id: "ultra", name: "Ultra Marathon", icon: "figure.run", category: "Running", defaultMode: .race),
        EventPreset(id: "trail-race", name: "Trail Race", icon: "figure.hiking", category: "Running", defaultMode: .race),
        EventPreset(id: "full-tri", name: "Full Triathlon", icon: "arrow.triangle.2.circlepath", category: "Triathlon", defaultMode: .race),
        EventPreset(id: "half-tri", name: "Half Triathlon", icon: "arrow.triangle.2.circlepath", category: "Triathlon", defaultMode: .race),
        EventPreset(id: "olympic-tri", name: "Olympic Triathlon", icon: "arrow.triangle.2.circlepath", category: "Triathlon", defaultMode: .race),
        EventPreset(id: "sprint-tri", name: "Sprint Triathlon", icon: "arrow.triangle.2.circlepath", category: "Triathlon", defaultMode: .race),
        EventPreset(id: "century", name: "Century Ride", icon: "bicycle", category: "Cycling", defaultMode: .race),
        EventPreset(id: "gran-fondo", name: "Gran Fondo", icon: "bicycle", category: "Cycling", defaultMode: .race),
        EventPreset(id: "swim-race", name: "Open Water Swim", icon: "figure.pool.swim", category: "Swimming", defaultMode: .race),
        EventPreset(id: "custom", name: "Custom Goal", icon: "target", category: "Other", defaultMode: .goal),
    ]
}
