//
//  AnyCodableTests.swift
//  CoachTests
//
//  Regression tests for the tool-input deserialization bug. Before the
//  fix in `AnyCodable.init(from:)`, every JSON numeric value was decoded
//  as `Double` because the decoder tried `Double.self` before `Int.self`.
//  Every strict `as? Int` cast in `ToolExecutor` then silently failed,
//  rejecting `patch_weekly_plan`, `generate_week_plan`, `log_workout`,
//  and silently dropping integer ratings during the W1 check-in flow.
//
//  These tests pin the decoder to the correct ordering so the
//  regression can't slip back in.

import XCTest
@testable import Coach

final class AnyCodableTests: XCTestCase {

    /// JSON integer literals should decode as `Int`, not `Double`. This
    /// is the single most important property — every tool-input numeric
    /// downstream cast (`as? Int`) depends on it.
    func testIntegerStaysInt() throws {
        let json = #"{"weekNumber": 5}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        guard let dict = decoded.value as? [String: Any] else {
            XCTFail("expected dict, got \(type(of: decoded.value))")
            return
        }
        XCTAssertNotNil(dict["weekNumber"] as? Int,
            "weekNumber should be Int — got \(type(of: dict["weekNumber"]!))")
        XCTAssertEqual(dict["weekNumber"] as? Int, 5)
    }

    /// JSON float literals (with decimal point) should decode as
    /// `Double`. `intFrom` in ToolExecutor then handles the integer-
    /// valued-Double case (`5.0` → 5).
    func testFloatStaysDouble() throws {
        let json = #"{"distance": 5.5}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict?["distance"] as? Double)
        XCTAssertEqual(dict?["distance"] as? Double, 5.5)
        XCTAssertNil(dict?["distance"] as? Int,
            "5.5 should NOT cast to Int — fractional component")
    }

    /// JSON booleans should decode as `Bool`, never as `Int 0/1`. The
    /// decoder tries Bool before Int as defensive ordering — current
    /// Foundation rejects Bool→Int but the order protects against
    /// future tolerance changes.
    func testBooleanStaysBool() throws {
        let json = #"{"painFlag": true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict?["painFlag"] as? Bool)
        XCTAssertEqual(dict?["painFlag"] as? Bool, true)
        XCTAssertNil(dict?["painFlag"] as? Int,
            "true should NOT cast to Int 1")
    }

    /// Mixed types in a single dict — the realistic tool-input shape
    /// where weekNumber is Int, distance_miles is Double, isRest is
    /// Bool, label is String. Every value should land at its natural
    /// type so downstream casts work.
    func testMixedDictTypes() throws {
        let json = """
        {
            "weekNumber": 4,
            "distance_miles": 12.5,
            "isRest": false,
            "label": "Long Run",
            "fields": null
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        let dict = decoded.value as? [String: Any]
        XCTAssertEqual(dict?["weekNumber"] as? Int, 4)
        XCTAssertEqual(dict?["distance_miles"] as? Double, 12.5)
        XCTAssertEqual(dict?["isRest"] as? Bool, false)
        XCTAssertEqual(dict?["label"] as? String, "Long Run")
        XCTAssertNotNil(dict?["fields"] as? NSNull)
    }

    /// Nested arrays of integers (e.g. the `operations` array on a
    /// patch_weekly_plan call carrying `fromDay: 2, fromIndex: 0` etc.)
    /// should preserve Int typing through the array layer.
    func testNestedArrayOfIntegers() throws {
        let json = """
        {
            "weekNumber": 4,
            "operations": [
                {"op": "move", "fromDay": 2, "fromIndex": 0, "toDay": 3, "toIndex": 0}
            ]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        let dict = decoded.value as? [String: Any]
        let ops = dict?["operations"] as? [[String: Any]]
        XCTAssertEqual(ops?.count, 1)
        let first = ops?.first
        XCTAssertEqual(first?["op"] as? String, "move")
        XCTAssertEqual(first?["fromDay"] as? Int, 2)
        XCTAssertEqual(first?["fromIndex"] as? Int, 0)
        XCTAssertEqual(first?["toDay"] as? Int, 3)
        XCTAssertEqual(first?["toIndex"] as? Int, 0)
    }
}
