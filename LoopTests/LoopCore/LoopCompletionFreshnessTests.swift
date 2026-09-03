//
//  LoopCompletionFreshnessTests.swift
//  LoopTests
//
//  Created by Nathaniel Hamming on 2020-10-28.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopCore

class LoopCompletionFreshnessTests: XCTestCase {

    func testInitializationWithAge() {
        let freshAge = TimeInterval(minutes: 5)
        let agingAge = TimeInterval(minutes: 15)
        let staleAge1 = TimeInterval(minutes: 20)
        let staleAge2 = TimeInterval(hours: 20)
        
        XCTAssertEqual(LoopCompletionFreshness(age: nil), .stale)
        XCTAssertEqual(LoopCompletionFreshness(age: freshAge), .fresh)
        XCTAssertEqual(LoopCompletionFreshness(age: agingAge), .aging)
        XCTAssertEqual(LoopCompletionFreshness(age: staleAge1), .stale)
        XCTAssertEqual(LoopCompletionFreshness(age: staleAge2), .stale)
    }
    
    func testInitializationWithLoopCompletion() {
        let freshDate = Date().addingTimeInterval(-.minutes(1))
        let agingDate = Date().addingTimeInterval(-.minutes(7))
        let staleDate1 = Date().addingTimeInterval(-.minutes(17))
        let staleDate2 = Date().addingTimeInterval(-.hours(13))
        
        XCTAssertEqual(LoopCompletionFreshness(lastCompletion: nil), .stale)
        XCTAssertEqual(LoopCompletionFreshness(lastCompletion: freshDate), .fresh)
        XCTAssertEqual(LoopCompletionFreshness(lastCompletion: agingDate), .aging)
        XCTAssertEqual(LoopCompletionFreshness(lastCompletion: staleDate1), .stale)
        XCTAssertEqual(LoopCompletionFreshness(lastCompletion: staleDate2), .stale)
    }

    func testMaxAge() {
        var loopCompletionFreshness: LoopCompletionFreshness = .fresh
        XCTAssertEqual(loopCompletionFreshness.maxAge, TimeInterval.minutes(6))
        
        loopCompletionFreshness = .aging
        XCTAssertEqual(loopCompletionFreshness.maxAge, TimeInterval.minutes(16))
        
        loopCompletionFreshness = .stale
        XCTAssertNil(loopCompletionFreshness.maxAge)
    }

    func testMaxAgeScalesWithLoopInterval() {
        let interval = TimeInterval(minutes: 15)

        XCTAssertEqual(LoopCompletionFreshness.fresh.maxAge(for: interval), TimeInterval.minutes(16))
        XCTAssertEqual(LoopCompletionFreshness.aging.maxAge(for: interval), TimeInterval.minutes(46))
        XCTAssertNil(LoopCompletionFreshness.stale.maxAge(for: interval))
    }

    func testInitializationWithCustomLoopInterval() {
        let interval = TimeInterval(minutes: 15)

        // With a 15 min interval, ages that would be "aging"/"stale" at the default cadence stay fresh.
        XCTAssertEqual(LoopCompletionFreshness(age: .minutes(15), loopInterval: interval), .fresh)
        XCTAssertEqual(LoopCompletionFreshness(age: .minutes(16), loopInterval: interval), .fresh)
        XCTAssertEqual(LoopCompletionFreshness(age: .minutes(30), loopInterval: interval), .aging)
        XCTAssertEqual(LoopCompletionFreshness(age: .minutes(46), loopInterval: interval), .aging)
        XCTAssertEqual(LoopCompletionFreshness(age: .minutes(47), loopInterval: interval), .stale)
    }
}
