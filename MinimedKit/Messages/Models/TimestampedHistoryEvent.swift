//
//  TimestampedPumpEvent.swift
//  RileyLink
//
//  Created by Nate Racklyeft on 6/15/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation


// Boxes a TimestampedPumpEvent, storing its reconciled date components
public struct TimestampedHistoryEvent {
    public let pumpEvent: PumpEvent
    public let date: Date

    public init(pumpEvent: PumpEvent, date: Date) {
        self.pumpEvent = pumpEvent
        self.date = date
    }

    public func isMutable(atDate date: Date = Date(), forPump model: PumpModel) -> Bool {
        guard let bolus = self.pumpEvent as? BolusNormalPumpEvent else {
            return false
        }
        let deliveryFinishDate = date.addingTimeInterval(bolus.deliveryTime)
        return model.appendsSquareWaveToHistoryOnStartOfDelivery && bolus.type == .square && deliveryFinishDate > date
    }
}


extension TimestampedHistoryEvent: DictionaryRepresentable {
    public var dictionaryRepresentation: [String : Any] {
        var dict = pumpEvent.dictionaryRepresentation

        dict["timestamp"] = DateFormatter.ISO8601DateFormatter().string(from: date)

        return dict
    }
}
