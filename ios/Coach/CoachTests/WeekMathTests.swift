//
//  WeekMathTests.swift
//  CoachTests
//
//  Table-driven tests for the centralized week math: `weekStart(of:anchor:)`,
//  `todayDayIndex(anchor:now:)`, `sessionDateString(...anchor:)`, and
//  `WeekBoundary`. This is the math that was previously duplicated (and
//  diverging) across five call sites — the patch-executor bug that falsely
//  rejected week edits came from one copy skipping the week-start snap.
//  These tests pin every anchor × misaligned-start combination so the
//  whole bug class stays dead.

import XCTest
@testable import Coach

final class WeekMathTests: XCTestCase {

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func date(_ s: String) -> Date {
        guard let d = fmt.date(from: s) else {
            XCTFail("bad test date \(s)")
            return Date()
        }
        return d
    }

    // MARK: - Weekday

    func testCalendarWeekdayRoundTrip() {
        for day in Weekday.allCases {
            XCTAssertEqual(Weekday(calendarWeekday: day.calendarWeekday), day)
        }
    }

    func testWeekOrderStartsAtAnchorAndCovers7Days() {
        for anchor in Weekday.allCases {
            let order = anchor.weekOrder
            XCTAssertEqual(order.count, 7)
            XCTAssertEqual(order.first, anchor)
            XCTAssertEqual(Set(order).count, 7, "weekOrder must contain each weekday once")
            XCTAssertEqual(order.last, anchor.previous)
        }
    }

    func testPreviousWrapsCorrectly() {
        XCTAssertEqual(Weekday.monday.previous, .sunday)
        XCTAssertEqual(Weekday.sunday.previous, .saturday)
    }

    // MARK: - weekStart(of:anchor:)

    /// 2026-06-10 is a Wednesday. The week start for each anchor is the
    /// nearest anchor day at or before it.
    func testWeekStartFromAWednesday() {
        let wednesday = date("2026-06-10")
        let expected: [Weekday: String] = [
            .monday: "2026-06-08",
            .sunday: "2026-06-07",
            .tuesday: "2026-06-09",
            .wednesday: "2026-06-10",   // already on the anchor — no-op
            .thursday: "2026-06-04",
            .friday: "2026-06-05",
            .saturday: "2026-06-06",
        ]
        for (anchor, want) in expected {
            let got = fmt.string(from: weekStart(of: wednesday, anchor: anchor))
            XCTAssertEqual(got, want, "anchor \(anchor.rawValue)")
        }
    }

    func testWeekStartIsIdempotent() {
        for anchor in Weekday.allCases {
            let snapped = weekStart(of: date("2026-06-10"), anchor: anchor)
            XCTAssertEqual(weekStart(of: snapped, anchor: anchor), snapped,
                "snapping an already-snapped date must be a no-op (anchor \(anchor.rawValue))")
        }
    }

    /// The snap never moves a date forward, and never further back than 6 days.
    func testWeekStartAlwaysAtOrBefore() {
        let cal = Calendar.current
        for anchor in Weekday.allCases {
            for offset in 0..<14 {
                let d = cal.date(byAdding: .day, value: offset, to: date("2026-06-01"))!
                let ws = weekStart(of: d, anchor: anchor)
                let gap = cal.dateComponents([.day], from: ws, to: d).day!
                XCTAssertTrue((0...6).contains(gap),
                    "gap \(gap) out of range for \(fmt.string(from: d)) anchor \(anchor.rawValue)")
                XCTAssertEqual(cal.component(.weekday, from: ws), anchor.calendarWeekday)
            }
        }
    }

    // MARK: - todayDayIndex

    func testTodayDayIndexAcrossAnchors() {
        let wednesday = date("2026-06-10")
        XCTAssertEqual(todayDayIndex(anchor: .monday, now: wednesday), 2)
        XCTAssertEqual(todayDayIndex(anchor: .sunday, now: wednesday), 3)
        XCTAssertEqual(todayDayIndex(anchor: .wednesday, now: wednesday), 0)
        XCTAssertEqual(todayDayIndex(anchor: .thursday, now: wednesday), 6)
    }

    func testTodayDayIndexMatchesWeekOrder() {
        // dayIdx must agree with weekOrder: sessions[idx] is the weekday
        // at weekOrder[idx].
        let cal = Calendar.current
        for anchor in Weekday.allCases {
            for offset in 0..<7 {
                let d = cal.date(byAdding: .day, value: offset, to: date("2026-06-07"))!
                let idx = todayDayIndex(anchor: anchor, now: d)
                let weekday = Weekday(calendarWeekday: cal.component(.weekday, from: d))!
                XCTAssertEqual(anchor.weekOrder[idx], weekday)
            }
        }
    }

    // MARK: - sessionDateString

    /// Aligned start: week 1 day 0 is the start date itself; dates walk
    /// forward one day per index and 7 per week.
    func testSessionDateStringAlignedStart() {
        // 2026-06-08 is a Monday.
        let got = sessionDateString(planStartDate: "2026-06-08", weekNumber: 1, dayIdx: 0, anchor: .monday)
        XCTAssertEqual(got, "2026-06-08")
        XCTAssertEqual(sessionDateString(planStartDate: "2026-06-08", weekNumber: 1, dayIdx: 1, anchor: .monday), "2026-06-09")
        XCTAssertEqual(sessionDateString(planStartDate: "2026-06-08", weekNumber: 8, dayIdx: 1, anchor: .monday), "2026-07-28")
    }

    /// THE regression: a startDate that drifted off its anchor must snap
    /// BACK to the anchor, not shift the whole week forward. (This exact
    /// case — Monday-anchored plan with a Wednesday startDate — is what
    /// made the patch executor reject completed past sessions as
    /// "future".)
    func testSessionDateStringMisalignedStartSnapsBack() {
        // 2026-06-10 is a Wednesday; its Monday is 2026-06-08.
        XCTAssertEqual(
            sessionDateString(planStartDate: "2026-06-10", weekNumber: 1, dayIdx: 0, anchor: .monday),
            "2026-06-08"
        )
        // Day 1 (Tuesday) of week 1 is 2026-06-09 — in the PAST relative
        // to the start date, which is the scenario the future-completion
        // guard must tolerate.
        XCTAssertEqual(
            sessionDateString(planStartDate: "2026-06-10", weekNumber: 1, dayIdx: 1, anchor: .monday),
            "2026-06-09"
        )
    }

    /// Sunday-anchored plan: day 0 of each week is a Sunday.
    func testSessionDateStringSundayAnchor() {
        // 2026-06-07 is a Sunday.
        XCTAssertEqual(sessionDateString(planStartDate: "2026-06-07", weekNumber: 1, dayIdx: 0, anchor: .sunday), "2026-06-07")
        XCTAssertEqual(sessionDateString(planStartDate: "2026-06-07", weekNumber: 1, dayIdx: 6, anchor: .sunday), "2026-06-13")
        XCTAssertEqual(sessionDateString(planStartDate: "2026-06-07", weekNumber: 2, dayIdx: 0, anchor: .sunday), "2026-06-14")
        // Misaligned: Wednesday start on a Sunday anchor snaps back to Sunday.
        XCTAssertEqual(sessionDateString(planStartDate: "2026-06-10", weekNumber: 1, dayIdx: 0, anchor: .sunday), "2026-06-07")
    }

    func testSessionDateStringNilAndMalformedStart() {
        XCTAssertNil(sessionDateString(planStartDate: nil, weekNumber: 1, dayIdx: 0, anchor: .monday))
        XCTAssertNil(sessionDateString(planStartDate: "garbage", weekNumber: 1, dayIdx: 0, anchor: .monday))
    }

    // MARK: - weekRangeLabel

    func testWeekRangeLabelSpansSevenDays() {
        // Monday 2026-06-08 → Sunday 2026-06-14.
        XCTAssertEqual(
            weekRangeLabel(planStartDate: "2026-06-08", weekNumber: 1, anchor: .monday),
            "Jun 8 \u{2014} Jun 14"
        )
        // Sunday anchor: Sunday 2026-06-07 → Saturday 2026-06-13.
        XCTAssertEqual(
            weekRangeLabel(planStartDate: "2026-06-07", weekNumber: 1, anchor: .sunday),
            "Jun 7 \u{2014} Jun 13"
        )
    }

    // MARK: - WeekBoundary

    func testWeekBoundaryStartAndEnd() {
        let wednesday = date("2026-06-10")
        XCTAssertEqual(WeekBoundary.weekStartString(of: wednesday, anchor: .monday), "2026-06-08")
        XCTAssertEqual(WeekBoundary.weekEndString(of: wednesday, anchor: .monday), "2026-06-14")
        XCTAssertEqual(WeekBoundary.weekStartString(of: wednesday, anchor: .sunday), "2026-06-07")
        XCTAssertEqual(WeekBoundary.weekEndString(of: wednesday, anchor: .sunday), "2026-06-13")
    }

    /// On the last day of the athlete's week, the review covers the week
    /// ending today; on any other day it covers the prior week.
    func testReviewWeekStartString() {
        // Monday anchor: Sunday 2026-06-14 is the last day of the week
        // that started Monday 2026-06-08.
        XCTAssertEqual(
            WeekBoundary.reviewWeekStartString(of: date("2026-06-14"), anchor: .monday),
            "2026-06-08"
        )
        // Mid-week (Wednesday) reviews the PRIOR week.
        XCTAssertEqual(
            WeekBoundary.reviewWeekStartString(of: date("2026-06-10"), anchor: .monday),
            "2026-06-01"
        )
        // Sunday anchor: Saturday 2026-06-13 is the last day of the week
        // that started Sunday 2026-06-07.
        XCTAssertEqual(
            WeekBoundary.reviewWeekStartString(of: date("2026-06-13"), anchor: .sunday),
            "2026-06-07"
        )
        // The first day of a Sunday week reviews the prior week.
        XCTAssertEqual(
            WeekBoundary.reviewWeekStartString(of: date("2026-06-07"), anchor: .sunday),
            "2026-05-31"
        )
    }
}
