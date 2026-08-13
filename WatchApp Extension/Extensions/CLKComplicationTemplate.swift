//
//  CLKComplicationTemplate.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 11/26/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import ClockKit
import HealthKit
import LoopKit
import Foundation
import LoopCore
import UIKit

extension CLKComplicationTemplate {

    /// Fraction of the graphic rectangular complication width occupied by the glucose graph.
    /// The remaining width is used for the text bar (glucose value, loop status ring, IOB, time).
    static let rectangularGraphWidthFraction: CGFloat = 0.62

    static func templateForFamily(
        _ family: CLKComplicationFamily,
        from context: WatchContext,
        at date: Date,
        recencyInterval: TimeInterval,
        rectangularFullSize: CGSize = .zero,
        chartGenerator makeChart: () -> UIImage?
    ) -> CLKComplicationTemplate? {
        guard let glucose = context.glucose, let unit = context.displayGlucoseUnit else {
            return nil
        }
        
        return templateForFamily(family,
            glucose: glucose,
            unit: unit,
            glucoseDate: context.glucoseDate,
            trend: context.glucoseTrend,
            eventualGlucose: context.eventualGlucose,
            at: date,
            loopLastRunDate: context.loopLastRunDate,
            loopInterval: context.loopInterval ?? LoopCompletionFreshness.defaultLoopInterval,
            iob: context.iob,
            isClosedLoop: context.isClosedLoop,
            rectangularFullSize: rectangularFullSize,
            recencyInterval: recencyInterval,
            chartGenerator: makeChart)
    }

    static func templateForFamily(
        _ family: CLKComplicationFamily,
        glucose: HKQuantity,
        unit: HKUnit,
        glucoseDate: Date?,
        trend: GlucoseTrend?,
        eventualGlucose: HKQuantity?,
        at date: Date,
        loopLastRunDate: Date?,
        loopInterval: TimeInterval = LoopCompletionFreshness.defaultLoopInterval,
        iob: Double? = nil,
        isClosedLoop: Bool? = nil,
        rectangularFullSize: CGSize = .zero,
        recencyInterval: TimeInterval,
        chartGenerator makeChart: () -> UIImage?
    ) -> CLKComplicationTemplate? {

        let formatter = NumberFormatter.glucoseFormatter(for: unit)
        
        guard let glucoseDate = glucoseDate else {
            return nil
        }
        
        let glucoseString: String
        let trendString: String
        
        let isGlucoseStale = date.timeIntervalSince(glucoseDate) > recencyInterval

        if isGlucoseStale {
            glucoseString = NSLocalizedString("---", comment: "No glucose value representation (3 dashes for mg/dL; no spaces as this will get truncated in the watch complication)")
            trendString = ""
        } else {
            guard let formattedGlucose = formatter.string(from: glucose.doubleValue(for: unit)) else {
                return nil
            }
            glucoseString = formattedGlucose
            trendString = trend?.symbol ?? " "
        }
        
        let loopCompletionFreshness = LoopCompletionFreshness(lastCompletion: loopLastRunDate, at: date, loopInterval: loopInterval)
        
        let tintColor: UIColor
        
        switch loopCompletionFreshness {
        case .fresh:
            tintColor = .tintColor
        case .aging:
            tintColor = .agingColor
        case .stale:
            tintColor = .staleColor
        }

        let glucoseAndTrend = "\(glucoseString)\(trendString)"
        var accessibilityStrings = [glucoseString]

        if let trend = trend {
            accessibilityStrings.append(trend.localizedDescription)
        }

        let glucoseAndTrendText = CLKSimpleTextProvider(text: glucoseAndTrend, shortText: glucoseString, accessibilityLabel: accessibilityStrings.joined(separator: ", "))
        
        let timeText: CLKTextProvider
        
        if let loopLastRunDate = loopLastRunDate {
            timeText = CLKRelativeDateTextProvider(date: loopLastRunDate, style: .natural, units: [.minute, .hour, .day])
        } else {
            timeText = CLKTextProvider(format: "")
        }
        timeText.tintColor = tintColor

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        switch family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackText(line1TextProvider: glucoseAndTrendText, line2TextProvider: timeText)
            template.highlightLine2 = true
            return template
        case .modularLarge:
            return CLKComplicationTemplateModularLargeTallBody(headerTextProvider: timeText, bodyTextProvider: glucoseAndTrendText)
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(textProvider: CLKSimpleTextProvider(text: glucoseString))
        case .extraLarge:
            return CLKComplicationTemplateExtraLargeStackText(line1TextProvider: glucoseAndTrendText, line2TextProvider: timeText)
        case .utilitarianSmall, .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: CLKSimpleTextProvider(text: glucoseString))
        case .utilitarianLarge:
            var eventualGlucoseText = ""
            if  let eventualGlucose = eventualGlucose,
                let eventualGlucoseString = formatter.string(from: eventualGlucose.doubleValue(for: unit))
            {
                eventualGlucoseText = eventualGlucoseString
            }

            let format = NSLocalizedString("UtilitarianLargeFlat", tableName: "ckcomplication", comment: "Utilitarian large flat format string (1: Glucose & Trend symbol) (2: Eventual Glucose) (3: Time)")

            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: String(format: format, arguments: [
                    glucoseAndTrend,
                    eventualGlucoseText,
                    timeFormatter.string(from: glucoseDate)
                ]
            )))
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                return CLKComplicationTemplateGraphicCornerStackText(innerTextProvider: timeText, outerTextProvider: glucoseAndTrendText)
            } else {
                return nil
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                return CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText(
                    gaugeProvider: CLKSimpleGaugeProvider(style: .fill, gaugeColor: tintColor, fillFraction: 1),
                    bottomTextProvider: CLKSimpleTextProvider(text: trendString),
                    centerTextProvider: CLKSimpleTextProvider(text: glucoseString)
                )
            } else {
                return nil
            }
        case .graphicBezel:
            if #available(watchOSApplicationExtension 5.0, *) {
                guard
                    let circularTemplate = templateForFamily(.graphicCircular,
                                                             glucose: glucose,
                                                             unit: unit,
                                                             glucoseDate: glucoseDate,
                                                             trend: trend,
                                                             eventualGlucose: eventualGlucose,
                                                             at: date,
                                                             loopLastRunDate: loopLastRunDate,
                                                             recencyInterval: recencyInterval,
                                                             chartGenerator: makeChart
                        ) as? CLKComplicationTemplateGraphicCircular
                else {
                    fatalError("\(#function) invoked with .graphicCircular must return a subclass of CLKComplicationTemplateGraphicCircular")
                }
                return CLKComplicationTemplateGraphicBezelCircularText(circularTemplate: circularTemplate, textProvider: timeText)
            } else {
                return nil
            }
        case .graphicRectangular:
            if #available(watchOSApplicationExtension 5.0, *) {
                // Active insulin (IOB) string shown in the text bar.
                let iobString: String?
                if !isGlucoseStale, let iob = iob {
                    let insulinFormatter = QuantityFormatter(for: .internationalUnit())
                    insulinFormatter.numberFormatter.minimumFractionDigits = 1
                    insulinFormatter.numberFormatter.maximumFractionDigits = 1
                    iobString = insulinFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: iob))
                } else {
                    iobString = nil
                }

                // Relative time since the last completed loop (e.g. "3 min").
                let timeString: String
                if let loopLastRunDate = loopLastRunDate {
                    let relativeFormatter = DateComponentsFormatter()
                    relativeFormatter.allowedUnits = [.minute, .hour, .day]
                    relativeFormatter.unitsStyle = .short
                    relativeFormatter.maximumUnitCount = 1
                    timeString = relativeFormatter.string(from: date.timeIntervalSince(loopLastRunDate)) ?? ""
                } else {
                    timeString = ""
                }

                let image = rectangularComplicationImage(
                    fullSize: rectangularFullSize,
                    graphImage: makeChart(),
                    glucoseString: glucoseString,
                    trendString: trendString,
                    timeString: timeString,
                    iobString: iobString,
                    isClosedLoop: isClosedLoop,
                    tintColor: tintColor
                )
                return CLKComplicationTemplateGraphicRectangularFullImage(
                    imageProvider: CLKFullColorImageProvider(fullColorImage: image)
                )
            } else {
                return nil
            }
        case .graphicExtraLarge:
            if #available(watchOSApplicationExtension 5.0, *) {
                return CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeSimpleText(
                    gaugeProvider: CLKSimpleGaugeProvider(style: .fill, gaugeColor: tintColor, fillFraction: 1),
                    bottomTextProvider: CLKSimpleTextProvider(text: trendString),
                    centerTextProvider: CLKSimpleTextProvider(text: glucoseString)
                )
            } else {
                return nil
            }
        @unknown default:
            return nil
        }
    }

    /// Renders the graphic rectangular complication as a single image with the glucose graph on the
    /// left and a text bar (loop status ring, glucose value, IOB, time) on the right.
    private static func rectangularComplicationImage(
        fullSize: CGSize,
        graphImage: UIImage?,
        glucoseString: String,
        trendString: String,
        timeString: String,
        iobString: String?,
        isClosedLoop: Bool?,
        tintColor: UIColor
    ) -> UIImage {
        guard fullSize.width > 0, fullSize.height > 0 else {
            return graphImage ?? UIImage()
        }

        UIGraphicsBeginImageContextWithOptions(fullSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return graphImage ?? UIImage()
        }

        let graphWidth = (fullSize.width * rectangularGraphWidthFraction).rounded()

        // Glucose graph on the left.
        graphImage?.draw(in: CGRect(x: 0, y: 0, width: graphWidth, height: fullSize.height))

        // Text bar on the right.
        let barX = graphWidth + 5
        var y: CGFloat = 2

        let glucoseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
            .foregroundColor: UIColor.chartLabel
        ]
        let glucoseText = "\(glucoseString)\(trendString)" as NSString
        let glucoseTextSize = glucoseText.size(withAttributes: glucoseAttributes)

        // Loop status ring, to the left of the glucose value.
        var glucoseX = barX
        if let isClosedLoop = isClosedLoop {
            let ringDiameter: CGFloat = 12
            let ringRect = CGRect(
                x: barX,
                y: y + (glucoseTextSize.height - ringDiameter) / 2,
                width: ringDiameter,
                height: ringDiameter
            )
            drawLoopRing(in: context, rect: ringRect, lineWidth: 2.5, isClosedLoop: isClosedLoop, color: tintColor)
            glucoseX = ringRect.maxX + 4
        }

        glucoseText.draw(at: CGPoint(x: glucoseX, y: y), withAttributes: glucoseAttributes)
        y += glucoseTextSize.height + 3

        if let iobString = iobString {
            let iobAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.chartLabel
            ]
            let iobText = iobString as NSString
            iobText.draw(at: CGPoint(x: barX, y: y), withAttributes: iobAttributes)
            y += iobText.size(withAttributes: iobAttributes).height + 2
        }

        if !timeString.isEmpty {
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: tintColor
            ]
            (timeString as NSString).draw(at: CGPoint(x: barX, y: y), withAttributes: timeAttributes)
        }

        return UIGraphicsGetImageFromCurrentImageContext() ?? (graphImage ?? UIImage())
    }

    /// Draws the loop status ring used in the app: a full ring when closed loop is enabled and a
    /// ring with a gap at the top when open. Colored by loop completion freshness.
    private static func drawLoopRing(in context: CGContext, rect: CGRect, lineWidth: CGFloat, isClosedLoop: Bool, color: UIColor) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)

        if isClosedLoop {
            context.strokeEllipse(in: rect)
        } else {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2
            let topAngle: CGFloat = -.pi / 2
            let gapAngle: CGFloat = .pi / 3
            context.addArc(
                center: center,
                radius: radius,
                startAngle: topAngle + gapAngle / 2,
                endAngle: topAngle + 2 * .pi - gapAngle / 2,
                clockwise: false
            )
            context.strokePath()
        }

        context.restoreGState()
    }
}
