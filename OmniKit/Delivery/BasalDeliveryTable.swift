//
//  BasalDeliveryTable.swift
//  OmniKit
//
//  Created by Pete Schwamb on 4/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalTableEntry {
    let segments: Int
    let pulses: Int
    let alternateSegmentPulse: Bool
    
    public init(encodedData: Data) {
        segments = Int(encodedData[0] >> 4) + 1
        pulses = (Int(encodedData[0] & 0b11) << 8) + Int(encodedData[1])
        alternateSegmentPulse = (encodedData[0] >> 3) & 0x1 == 1
    }
    
    public init(segments: Int, pulses: Int, alternateSegmentPulse: Bool) {
        self.segments = segments
        self.pulses = pulses
        self.alternateSegmentPulse = alternateSegmentPulse
    }
    
    public var data: Data {
        let pulsesHighBits = UInt8((pulses >> 8) & 0b11)
        let pulsesLowBits = UInt8(pulses & 0xff)
        return Data(bytes: [
            UInt8((segments - 1) << 4) + UInt8((alternateSegmentPulse ? 1 : 0) << 3) + pulsesHighBits,
            UInt8(pulsesLowBits)
            ])
    }
    
    public func checksum() -> UInt16 {
        let checksumPerSegment = (pulses & 0xff) + (pulses >> 8)
        return UInt16(checksumPerSegment * segments + (alternateSegmentPulse ? segments / 2 : 0))
    }
    
}

public struct BasalDeliveryTable {
    static let segmentDuration: TimeInterval = .minutes(30)
    
    let entries: [BasalTableEntry]
    
    public init(entries: [BasalTableEntry]) {
        self.entries = entries
    }
    
    public init(schedule: BasalSchedule) {
        var tableEntries = [BasalTableEntry]()
        
        let durations = schedule.durations()
        
        for entry in durations {
            tableEntries.append(contentsOf: BasalDeliveryTable.rateToTableEntries(rate: entry.rate, duration: entry.duration))
        }
        self.entries = tableEntries
    }
    
    public init(tempBasalRate: Double, duration: TimeInterval) {
        self.entries = BasalDeliveryTable.rateToTableEntries(rate: tempBasalRate, duration: duration)
    }
    
    private static func rateToTableEntries(rate: Double, duration: TimeInterval) -> [BasalTableEntry] {
        var tableEntries = [BasalTableEntry]()

        let pulsesPerSegment = rate * BasalDeliveryTable.segmentDuration / TimeInterval(hours: 1) / podPulseSize
        let alternateSegmentPulse = pulsesPerSegment - floor(pulsesPerSegment) > 0
        var remaining = Int(duration / BasalDeliveryTable.segmentDuration)
        while remaining > 0 {
            let segments = min(remaining, 16)
            let tableEntry = BasalTableEntry(segments: segments, pulses: Int(pulsesPerSegment), alternateSegmentPulse: alternateSegmentPulse)
            tableEntries.append(tableEntry)
            remaining -= segments
        }
        return tableEntries
    }
    
    public func numSegments() -> Int {
        return entries.reduce(0) { $0 + $1.segments }
    }
}

public struct RateEntry {
    let totalPulses: Double
    let delayBetweenPulses: TimeInterval
    
    public init(totalPulses: Double, delayBetweenPulses: TimeInterval) {
        self.totalPulses = totalPulses
        self.delayBetweenPulses = delayBetweenPulses
    }
    
    public var rate: Double {
        if totalPulses == 0 {
            return 0
        } else {
            return TimeInterval(hours: 1) / delayBetweenPulses * podPulseSize
        }
    }
    
    public var duration: TimeInterval {
        if totalPulses == 0 {
            return delayBetweenPulses / 10
        } else {
            return delayBetweenPulses * Double(totalPulses)
        }
    }
    
    public var data: Data {
        var data = Data()
        data.appendBigEndian(UInt16(totalPulses * 10))
        if totalPulses == 0 {
            data.appendBigEndian(UInt32(delayBetweenPulses.hundredthsOfMilliseconds) * 10)
        } else {
            data.appendBigEndian(UInt32(delayBetweenPulses.hundredthsOfMilliseconds))
        }
        return data
    }
    
    public static func makeEntries(rate: Double, duration: TimeInterval) -> [RateEntry] {
        let maxPulses: Double = 6300
        var entries = [RateEntry]()
        
        var remainingPulses = rate * duration.hours / podPulseSize
        let delayBetweenPulses = TimeInterval(hours: 1) / rate * podPulseSize
        
        var timeRemaining = duration

        while (remainingPulses > 0 || (rate == 0 && timeRemaining > 0)) {
            if rate == 0 {
                entries.append(RateEntry(totalPulses: 0, delayBetweenPulses: .minutes(30)))
                timeRemaining -= .minutes(30)
            } else {
                let pulseCount = min(maxPulses, remainingPulses)
                let entry = RateEntry(totalPulses: pulseCount, delayBetweenPulses: delayBetweenPulses)
                entries.append(entry)
                remainingPulses -= pulseCount
                timeRemaining -= entry.duration
            }
        }
        return entries
    }
}





