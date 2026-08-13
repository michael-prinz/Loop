//
//  LoopCompletionFreshness.swift
//  Loop
//
//  Created by Pete Schwamb on 1/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum LoopCompletionFreshness {
    case fresh
    case aging
    case stale

    /// The loop interval assumed when no custom interval is supplied. This matches Loop's default
    /// cadence and keeps the historical `fresh`/`aging` thresholds of 6 and 16 minutes.
    public static let defaultLoopInterval: TimeInterval = .minutes(5)

    /// Maximum age for this freshness category based on the default loop interval.
    public var maxAge: TimeInterval? {
        return maxAge(for: LoopCompletionFreshness.defaultLoopInterval)
    }

    /// Maximum age for this freshness category, scaled to the given loop interval.
    ///
    /// The thresholds track the configured loop interval so that a longer (custom) interval does
    /// not prematurely turn the loop status indicator yellow/red:
    /// - `fresh`: one loop interval plus a one-minute buffer.
    /// - `aging`: three loop intervals plus a one-minute buffer.
    ///
    /// With the default 5 minute interval this yields the historical 6 and 16 minute thresholds.
    public func maxAge(for loopInterval: TimeInterval) -> TimeInterval? {
        switch self {
        case .fresh:
            return loopInterval + .minutes(1)
        case .aging:
            return loopInterval * 3 + .minutes(1)
        case .stale:
            return nil
        }
    }

    public init(age: TimeInterval?, loopInterval: TimeInterval = LoopCompletionFreshness.defaultLoopInterval) {
        guard let age = age else {
            self = .stale
            return
        }

        switch age {
        case let t where t <= LoopCompletionFreshness.fresh.maxAge(for: loopInterval)!:
            self = .fresh
        case let t where t <= LoopCompletionFreshness.aging.maxAge(for: loopInterval)!:
            self = .aging
        default:
            self = .stale
        }
    }

    public init(lastCompletion: Date?, at date: Date = Date(), loopInterval: TimeInterval = LoopCompletionFreshness.defaultLoopInterval) {
        guard let lastCompletion = lastCompletion else {
            self = .stale
            return
        }

        self = LoopCompletionFreshness(age: date.timeIntervalSince(lastCompletion), loopInterval: loopInterval)
    }

}
