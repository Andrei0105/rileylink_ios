//
//  PodInfoFaultEvent.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFaultEvent : PodInfo {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
//    public enum lengthType: UInt8{
//        case normal = 0x10
//        case configuredAlerts = 0x13
//        case faultEvents = 0x16
//        case dataLog = 0x04*numberOfWords+0x08
//        case faultDataInitializationTime = 0x11
//        case hardcodedValues  = 0x5
//        case resetStatus = numberOfBytes & 0x03
//        case dumpRecentFlashLog = 0x13
//        case dumpOlderFlashlog = 0x14
//
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10
    
    public var podInfoType: PodInfoResponseSubType = .faultEvents
    public let reservoirStatus: StatusResponse.ReservoirStatus
    public let deliveryType: DeliveryType
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let unknownPageCode: Double
    public let originalLoggedFaultEvent: PodInfoResponseSubType.FaultEventType
    public let faultEventTimeSinceActivation: Double
    public let insulinRemaining: Double
    public let timeActive: TimeInterval
    public let secondaryLoggedFaultEvent: PodInfoResponseSubType.FaultEventType
    public let logEventError: Bool
    public let reservoirStatusAtFirstLoggedFaultEvent: StatusResponse.ReservoirStatus
    public let recieverLowGain: UInt8
    public let radioRSSI: UInt8
    public let reservoirStatusAtFirstLoggedFaultEventCheck: StatusResponse.ReservoirStatus
    public let insulinStateTableCorruption: Bool
    public let immediateBolusInProgress: Bool
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < 19 {
            throw MessageBlockError.notEnoughData
        }
        
        guard let reservoirStatus = StatusResponse.ReservoirStatus(rawValue: encodedData[1]) else {
            throw MessageError.unknownValue(value: encodedData[1], typeDescription: "StatusResponse.ReservoirStatus")
        }
        self.reservoirStatus = reservoirStatus
        
        self.deliveryType = DeliveryType(rawValue: encodedData[2] & 0xf)
        
        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[3] & 0x3) << 8) | Int(encodedData[4]))
        
        self.podMessageCounter = encodedData[5]
        self.unknownPageCode = Double(Int(encodedData[6]) | Int(encodedData[7]))
        
        guard let originalLoggedFaultEvent = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[8]) else {
            throw MessageError.unknownValue(value: encodedData[8], typeDescription: "FaultEventType")
        }
        self.originalLoggedFaultEvent = originalLoggedFaultEvent
        
        self.faultEventTimeSinceActivation = TimeInterval(minutes: Double((Int(encodedData[9] & 0b1) << 8) + Int(encodedData[10])))
        
        self.insulinRemaining = podPulseSize * Double((Int(encodedData[11] & 0x3) << 8) | Int(encodedData[12]))
        
        self.timeActive = TimeInterval(minutes: Double((Int(encodedData[13] & 0b1) << 8) + Int(encodedData[14])))
        
        self.secondaryLoggedFaultEvent = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[15])!
        
        self.logEventError = encodedData[16] == 2

        self.insulinStateTableCorruption = encodedData[17] & 0b10000000 != 0
        
        guard let reservoirStatusAtFirstLoggedFaultEventType = StatusResponse.ReservoirStatus(rawValue: encodedData[17] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[17] & 0xF, typeDescription: "ProgressType")
        }
        
        self.immediateBolusInProgress = encodedData[17] & 0b00010000 != 0
        
        self.reservoirStatusAtFirstLoggedFaultEvent = reservoirStatusAtFirstLoggedFaultEventType
        
        self.recieverLowGain = encodedData[18] >> 4
        
        self.radioRSSI =  encodedData[18] & 0xF
        
        guard let reservoirStatusAtFirstLoggedFaultEventCheckType = StatusResponse.ReservoirStatus(rawValue: encodedData[19] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[19] & 0xF, typeDescription: "ProgressType")
        }
        self.reservoirStatusAtFirstLoggedFaultEventCheck = reservoirStatusAtFirstLoggedFaultEventCheckType
        
        self.data = Data(encodedData)
    }
}
