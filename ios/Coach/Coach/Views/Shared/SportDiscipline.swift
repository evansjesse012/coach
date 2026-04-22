import Foundation

/// Maps the app's `Sport` enum to the design system's `Theme.Discipline` used
/// for color coding, icons, and uppercase discipline labels.
extension Sport {
    var discipline: Theme.Discipline {
        switch self {
        case .run:      return .run
        case .bike:     return .bike
        case .swim:     return .swim
        case .strength: return .strength
        case .brick, .hike, .other: return .run
        }
    }
}
