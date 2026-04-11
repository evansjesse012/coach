import Foundation
import HealthKit

/// Imports workout data from Apple Health / Apple Watch.
/// Requires HealthKit capability and user permission.
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Authorization

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Fetch Recent Workouts

    func fetchWorkouts(days: Int = 30) async throws -> [CardioWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples as? [HKWorkout] ?? []).compactMap { hk -> CardioWorkout? in
                    let sport = self.mapActivityType(hk.workoutActivityType)
                    guard sport != .strength && sport != .other else { return nil }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let dateStr = formatter.string(from: hk.startDate)

                    let duration = Int(hk.duration / 60) // Convert seconds to minutes

                    var distance: String?
                    if let dist = hk.totalDistance?.doubleValue(for: .mile()) {
                        distance = String(format: "%.2f mi", dist)
                    }

                    var calories: Int?
                    if let cal = hk.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        calories = Int(cal)
                    }

                    return CardioWorkout(
                        id: hk.uuid.uuidString,
                        sport: sport,
                        duration: duration,
                        distance: distance,
                        calories: calories,
                        date: dateStr,
                        source: "healthkit"
                    )
                }

                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    // MARK: - Map HK Activity to Sport

    private func mapActivityType(_ type: HKWorkoutActivityType) -> Sport {
        switch type {
        case .running, .walking: return .run
        case .cycling: return .bike
        case .swimming: return .swim
        case .hiking: return .hike
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        default: return .other
        }
    }
}
