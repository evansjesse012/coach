import Foundation
import HealthKit
import CoreLocation

/// Imports workout data from Apple Health / Apple Watch with full detail:
/// heart rate (avg/max/min + time series + zone breakdown), route (GPS
/// points downsampled to ~100 for map rendering), cadence, pace, elevation
/// gain, source device, and indoor flag. Each workout's enrichment requires
/// 2-3 additional HealthKit queries, so a 10-workout sync may take a few
/// seconds.
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
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Fetch Recent Workouts (fully enriched)

    func fetchWorkouts(days: Int = 30) async throws -> [CardioWorkout] {
        let hkWorkouts = try await fetchHKWorkouts(days: days)
        var results: [CardioWorkout] = []
        for hk in hkWorkouts {
            if let enriched = await enrichWorkout(hk) {
                results.append(enriched)
            }
        }
        return results
    }

    // MARK: - Raw HKWorkout fetch

    private func fetchHKWorkouts(days: Int) async throws -> [HKWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Enrich a single HKWorkout with all available data

    private func enrichWorkout(_ hk: HKWorkout) async -> CardioWorkout? {
        let sport = mapActivityType(hk.workoutActivityType)
        guard sport != .strength && sport != .other else { return nil }

        // Formatters
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let isoFmt = ISO8601DateFormatter()

        // Basic fields
        let duration = Int(hk.duration / 60)
        let distanceMiles = hk.totalDistance?.doubleValue(for: .mile())
        let distanceMeters = hk.totalDistance?.doubleValue(for: .meter())
        let caloriesDouble = hk.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        // Pace (min/mi)
        var pace: String?
        if let dist = distanceMiles, dist > 0, duration > 0 {
            let paceMinPerMile = Double(duration) / dist
            let paceMin = Int(paceMinPerMile)
            let paceSec = Int((paceMinPerMile - Double(paceMin)) * 60)
            pace = String(format: "%d:%02d/mi", paceMin, paceSec)
        }

        // Average speed (m/s)
        var avgSpeed: Double?
        if let dist = distanceMeters, hk.duration > 0 {
            avgSpeed = dist / hk.duration
        }

        // Metadata
        let indoor = hk.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        let sourceApp = hk.sourceRevision.source.name
        let sourceDevice = hk.sourceRevision.productType

        // Async enrichment queries
        let hrData = await fetchHeartRateData(for: hk)
        let routeData = await fetchRouteData(for: hk)
        let cadence = await fetchAverageCadence(for: hk)

        let elevationGain = routeData?.elevationGain

        // Build the rich HealthWorkoutDetail
        let healthDetail = HealthWorkoutDetail(
            startTime: isoFmt.string(from: hk.startDate),
            endTime: isoFmt.string(from: hk.endDate),
            indoor: indoor,
            stats: WorkoutStats(
                avgHR: hrData?.avgHR,
                maxHR: hrData?.maxHR,
                minHR: hrData?.minHR,
                totalEnergy: caloriesDouble.map { Int($0) },
                totalDistance: distanceMeters,
                avgCadence: cadence,
                avgSpeed: avgSpeed,
                elevationGain: elevationGain
            ),
            hrSamples: hrData?.samples,
            source: SourceInfo(app: sourceApp, device: sourceDevice)
        )

        return CardioWorkout(
            id: hk.uuid.uuidString,
            sport: sport,
            duration: duration,
            distance: distanceMiles.map { String(format: "%.2f mi", $0) },
            pace: pace,
            avgHR: hrData?.avgHR,
            maxHR: hrData?.maxHR,
            calories: caloriesDouble.map { Int($0) },
            hrZones: hrData?.zones,
            date: dateFmt.string(from: hk.startDate),
            startTime: timeFmt.string(from: hk.startDate),
            endTime: timeFmt.string(from: hk.endDate),
            source: "healthkit",
            healthData: healthDetail,
            routeSummary: routeData,
            avgCadence: cadence,
            avgSpeed: avgSpeed,
            elevationGain: elevationGain.map { Int($0) },
            syncedAt: isoFmt.string(from: Date())
        )
    }

    // MARK: - Heart Rate

    private struct HRResult {
        var avgHR: Int
        var maxHR: Int
        var minHR: Int
        var samples: [TimedSample]
        var zones: HRZones
    }

    private func fetchHeartRateData(for workout: HKWorkout) async -> HRResult? {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let hrSamples = samples as? [HKQuantitySample], !hrSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpmValues = hrSamples.map { $0.quantity.doubleValue(for: unit) }

                let avgHR = Int(bpmValues.reduce(0, +) / Double(bpmValues.count))
                let maxHR = Int(bpmValues.max() ?? 0)
                let minHR = Int(bpmValues.min() ?? 0)

                // Time series for charts
                let timedSamples = hrSamples.map { sample in
                    TimedSample(
                        t: sample.startDate.timeIntervalSince1970,
                        v: sample.quantity.doubleValue(for: unit)
                    )
                }

                // HR zone distribution (% of samples in each zone)
                // Uses max HR 190 as placeholder — same as WorkoutMatcher
                let maxHRCeiling = 190.0
                var z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0
                for hr in bpmValues {
                    let pct = hr / maxHRCeiling
                    if pct < 0.60 { z1 += 1 }
                    else if pct < 0.70 { z2 += 1 }
                    else if pct < 0.80 { z3 += 1 }
                    else if pct < 0.90 { z4 += 1 }
                    else { z5 += 1 }
                }
                let total = max(1, z1 + z2 + z3 + z4 + z5)
                let zones = HRZones(
                    z1: z1 * 100 / total,
                    z2: z2 * 100 / total,
                    z3: z3 * 100 / total,
                    z4: z4 * 100 / total,
                    z5: z5 * 100 / total
                )

                continuation.resume(returning: HRResult(
                    avgHR: avgHR,
                    maxHR: maxHR,
                    minHR: minHR,
                    samples: timedSamples,
                    zones: zones
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - Route / GPS

    private func fetchRouteData(for workout: HKWorkout) async -> RouteSummary? {
        // Find the route object associated with this workout
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }

        guard let route = routes.first else { return nil }

        // Extract all location points from the route
        let locations: [CLLocation] = await withCheckedContinuation { continuation in
            var allLocations: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, _ in
                if let newLocations {
                    allLocations.append(contentsOf: newLocations)
                }
                if done {
                    continuation.resume(returning: allLocations)
                }
            }
            store.execute(query)
        }

        guard !locations.isEmpty else { return nil }

        // Downsample to ~100 points for the summary (full route can be
        // thousands of points — too much for JSONB storage and map rendering)
        let step = max(1, locations.count / 100)
        let downsampled = stride(from: 0, to: locations.count, by: step).map { locations[$0] }

        let points = downsampled.map { loc in
            RoutePoint(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude,
                alt: loc.altitude,
                t: loc.timestamp.timeIntervalSince1970,
                speed: loc.speed >= 0 ? loc.speed : nil
            )
        }

        // Bounding box for map viewport
        let lats = points.map(\.lat)
        let lngs = points.map(\.lng)
        let bbox = RouteSummary.BoundingBox(
            minLat: lats.min() ?? 0,
            minLng: lngs.min() ?? 0,
            maxLat: lats.max() ?? 0,
            maxLng: lngs.max() ?? 0
        )

        // Elevation gain — sum of positive altitude deltas
        var elevGain: Double = 0
        for i in 1..<locations.count {
            let delta = locations[i].altitude - locations[i - 1].altitude
            if delta > 0 { elevGain += delta }
        }

        // Total distance from GPS points
        var totalDist: Double = 0
        for i in 1..<locations.count {
            totalDist += locations[i].distance(from: locations[i - 1])
        }

        return RouteSummary(
            points: points,
            bbox: bbox,
            pointCount: locations.count,
            distance: totalDist,
            elevationGain: elevGain
        )
    }

    // MARK: - Cadence (steps per minute)

    private func fetchAverageCadence(for workout: HKWorkout) async -> Int? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                guard let sum = stats?.sumQuantity()?.doubleValue(for: .count()) else {
                    continuation.resume(returning: nil)
                    return
                }
                let durationMinutes = workout.duration / 60
                guard durationMinutes > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                // Steps per minute (SPM) — common running cadence metric
                continuation.resume(returning: Int(sum / durationMinutes))
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
