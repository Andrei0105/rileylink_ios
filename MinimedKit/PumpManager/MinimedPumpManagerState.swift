//
//  MinimedPumpManagerState.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import RileyLinkKit
import RileyLinkBLEKit

public struct MinimedPumpManagerState: RawRepresentable, Equatable {
    public typealias RawValue = PumpManager.RawStateValue

    public static let version = 2

    public var batteryChemistry: BatteryChemistryType

    public var preferredInsulinDataSource: InsulinDataSource

    public var pumpColor: PumpColor

    public var pumpModel: PumpModel
    
    public var pumpFirmwareVersion: String

    public var pumpID: String

    public var pumpRegion: PumpRegion
    
    public var isPumpSuspended: Bool

    public var lastValidFrequency: Measurement<UnitFrequency>?

    public var lastTuned: Date?
    
    public var batteryPercentage: Double?

    public var lastReservoirReading: ReservoirReading?
    
    public var pumpSettings: PumpSettings {
        get {
            return PumpSettings(pumpID: pumpID, pumpRegion: pumpRegion)
        }
        set {
            pumpID = newValue.pumpID
            pumpRegion = newValue.pumpRegion
        }
    }

    public var pumpState: PumpState {
        get {
            var state = PumpState()
            state.pumpModel = pumpModel
            state.timeZone = timeZone
            state.lastValidFrequency = lastValidFrequency
            state.lastTuned = lastTuned
            return state
        }
        set {
            if let model = newValue.pumpModel {
                pumpModel = model
            }
            lastValidFrequency = newValue.lastValidFrequency
            lastTuned = newValue.lastTuned
            timeZone = newValue.timeZone
        }
    }

    public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?

    public var timeZone: TimeZone

    public init(batteryChemistry: BatteryChemistryType = .alkaline, preferredInsulinDataSource: InsulinDataSource = .pumpHistory, pumpColor: PumpColor, pumpID: String, pumpModel: PumpModel, pumpFirmwareVersion: String, pumpRegion: PumpRegion, rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?, timeZone: TimeZone, lastValidFrequency: Measurement<UnitFrequency>? = nil, isPumpSuspended: Bool = false, batteryPercentage: Double? = nil, lastReservoirReading: ReservoirReading? = nil) {
        self.batteryChemistry = batteryChemistry
        self.preferredInsulinDataSource = preferredInsulinDataSource
        self.pumpColor = pumpColor
        self.pumpID = pumpID
        self.pumpModel = pumpModel
        self.pumpFirmwareVersion = pumpFirmwareVersion
        self.pumpRegion = pumpRegion
        self.rileyLinkConnectionManagerState = rileyLinkConnectionManagerState
        self.timeZone = timeZone
        self.isPumpSuspended = isPumpSuspended
        self.lastValidFrequency = lastValidFrequency
        self.batteryPercentage = batteryPercentage
        self.lastReservoirReading = lastReservoirReading
    }

    public init?(rawValue: RawValue) {
        guard
            let version = rawValue["version"] as? Int,
            let batteryChemistryRaw = rawValue["batteryChemistry"] as? BatteryChemistryType.RawValue,
            let insulinDataSourceRaw = rawValue["insulinDataSource"] as? InsulinDataSource.RawValue,
            let pumpColorRaw = rawValue["pumpColor"] as? PumpColor.RawValue,
            let pumpID = rawValue["pumpID"] as? String,
            let pumpModelNumber = rawValue["pumpModel"] as? PumpModel.RawValue,
            let pumpRegionRaw = rawValue["pumpRegion"] as? PumpRegion.RawValue,
            let timeZoneSeconds = rawValue["timeZone"] as? Int,

            let batteryChemistry = BatteryChemistryType(rawValue: batteryChemistryRaw),
            let insulinDataSource = InsulinDataSource(rawValue: insulinDataSourceRaw),
            let pumpColor = PumpColor(rawValue: pumpColorRaw),
            let pumpModel = PumpModel(rawValue: pumpModelNumber),
            let pumpRegion = PumpRegion(rawValue: pumpRegionRaw),
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds)
        else {
            return nil
        }
        
        var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState? = nil
        
        // Migrate
        if version == 1
        {
            if let oldRileyLinkPumpManagerStateRaw = rawValue["rileyLinkPumpManagerState"] as? [String : Any],
                let connectedPeripheralIDs = oldRileyLinkPumpManagerStateRaw["connectedPeripheralIDs"] as? [String]
            {
                rileyLinkConnectionManagerState = RileyLinkConnectionManagerState(autoConnectIDs: Set(connectedPeripheralIDs))
            }
        } else {
            if let rawState = rawValue["rileyLinkConnectionManagerState"] as? RileyLinkConnectionManagerState.RawValue {
                rileyLinkConnectionManagerState = RileyLinkConnectionManagerState(rawValue: rawState)
            }
        }

        let isPumpSuspended = (rawValue["isPumpSuspended"] as? Bool) ?? false
        
        let lastValidFrequency: Measurement<UnitFrequency>?
        if let frequencyRaw = rawValue["lastValidFrequency"] as? Double {
            lastValidFrequency = Measurement<UnitFrequency>(value: frequencyRaw, unit: .megahertz)
        } else {
            lastValidFrequency = nil
        }
        
        let pumpFirmwareVersion = (rawValue["pumpFirmwareVersion"] as? String) ?? ""
        let batteryPercentage = rawValue["batteryPercentage"] as? Double
        
        let lastReservoirReading: ReservoirReading?
        if let rawLastReservoirReading = rawValue["lastReservoirReading"] as? ReservoirReading.RawValue {
            lastReservoirReading = ReservoirReading(rawValue: rawLastReservoirReading)
        } else {
            lastReservoirReading = nil
        }
        
        self.init(
            batteryChemistry: batteryChemistry,
            preferredInsulinDataSource: insulinDataSource,
            pumpColor: pumpColor,
            pumpID: pumpID,
            pumpModel: pumpModel,
            pumpFirmwareVersion: pumpFirmwareVersion,
            pumpRegion: pumpRegion,
            rileyLinkConnectionManagerState: rileyLinkConnectionManagerState,
            timeZone: timeZone,
            lastValidFrequency: lastValidFrequency,
            isPumpSuspended: isPumpSuspended,
            batteryPercentage: batteryPercentage,
            lastReservoirReading: lastReservoirReading
        )
    }

    public var rawValue: RawValue {
        var value: [String : Any] = [
            "batteryChemistry": batteryChemistry.rawValue,
            "insulinDataSource": preferredInsulinDataSource.rawValue,
            "pumpColor": pumpColor.rawValue,
            "pumpID": pumpID,
            "pumpModel": pumpModel.rawValue,
            "pumpFirmwareVersion": pumpFirmwareVersion,
            "pumpRegion": pumpRegion.rawValue,
            "timeZone": timeZone.secondsFromGMT(),
            "isPumpSuspended": isPumpSuspended,
            "version": MinimedPumpManagerState.version,
            ]
        
        if let rileyLinkConnectionManagerState = rileyLinkConnectionManagerState {
            value["rileyLinkConnectionManagerState"] = rileyLinkConnectionManagerState.rawValue
        }
        
        if let frequency = lastValidFrequency?.converted(to: .megahertz) {
            value["lastValidFrequency"] = frequency.value
        }
        
        if let batteryPercentage = batteryPercentage {
            value["batteryPercentage"] = batteryPercentage
        }

        if let lastReservoirReading = lastReservoirReading {
            value["lastReservoirReading"] = lastReservoirReading.rawValue
        }

        return value
    }
}


extension MinimedPumpManagerState {
    static let idleListeningEnabledDefaults: RileyLinkDevice.IdleListeningState = .enabled(timeout: .minutes(4), channel: 0)
}


extension MinimedPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## MinimedPumpManagerState",
            "batteryChemistry: \(batteryChemistry)",
            "preferredInsulinDataSource: \(preferredInsulinDataSource)",
            "pumpColor: \(pumpColor)",
            "pumpID: ✔︎",
            "pumpModel: \(pumpModel.rawValue)",
            "pumpFirmwareVersion: \(pumpFirmwareVersion)",
            "pumpRegion: \(pumpRegion)",
            "lastValidFrequency: \(String(describing: lastValidFrequency))",
            "timeZone: \(timeZone)",
            "isPumpSuspended: \(isPumpSuspended)",
            "batteryPercentage: \(String(describing: batteryPercentage))",
            "reservoirUnits: \(String(describing: lastReservoirReading?.units))",
            "reservoirValidAt: \(String(describing: lastReservoirReading?.validAt))",
            String(reflecting: rileyLinkConnectionManagerState),
        ].joined(separator: "\n")
    }
}
