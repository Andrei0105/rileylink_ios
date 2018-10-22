//
//  DeviceDataManager.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkKit
import RileyLinkKitUI
import RileyLinkBLEKit
import MinimedKit
import MinimedKitUI
import NightscoutUploadKit
import LoopKit
import LoopKitUI
import os.log

class DeviceDataManager {

    let rileyLinkConnectionManager: RileyLinkConnectionManager
    
    var pumpManager: PumpManagerUI? {
        didSet {
            pumpManager?.pumpManagerDelegate = self
            UserDefaults.standard.pumpManagerRawValue = pumpManager?.rawValue
        }
    }
    

    public let log = OSLog(category: "DeviceDataManager")
    
    init() {
        
        if let connectionManagerState = UserDefaults.standard.rileyLinkConnectionManagerState {
            rileyLinkConnectionManager = RileyLinkConnectionManager(state: connectionManagerState)
        } else {
            rileyLinkConnectionManager = RileyLinkConnectionManager(autoConnectIDs: [])
        }
        rileyLinkConnectionManager.delegate = self
        rileyLinkConnectionManager.setScanningEnabled(true)

        if let pumpManagerRawValue = UserDefaults.standard.pumpManagerRawValue {
            pumpManager = PumpManagerFromRawValue(pumpManagerRawValue, rileyLinkDeviceProvider: rileyLinkConnectionManager.deviceProvider) as? PumpManagerUI
            pumpManager?.pumpManagerDelegate = self
        }
    }
}

extension DeviceDataManager: RileyLinkConnectionManagerDelegate {
    func rileyLinkConnectionManager(_ rileyLinkConnectionManager: RileyLinkConnectionManager, didChange state: RileyLinkConnectionManagerState)
    {
        UserDefaults.standard.rileyLinkConnectionManagerState = state
    }    
}

extension DeviceDataManager: PumpManagerDelegate {
    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval) {
        log.debug("didAdjustPumpClockBy %@", adjustment)
    }
    
    func pumpManagerDidUpdateState(_ pumpManager: PumpManager) {
        UserDefaults.standard.pumpManagerRawValue = pumpManager.rawValue
    }
    
    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager) {
    }
    
    func pumpManagerShouldProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool {
        return true
    }
    
    func pumpManager(_ pumpManager: PumpManager, didUpdateStatus status: PumpManagerStatus) {
    }
    
    func pumpManagerWillDeactivate(_ pumpManager: PumpManager) {
        self.pumpManager = nil
    }
    
    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError) {
        log.error("pumpManager didError %@", String(describing: error))
    }
    
    func pumpManager(_ pumpManager: PumpManager, didReadPumpEvents events: [NewPumpEvent], completion: @escaping (_ error: Error?) -> Void) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) -> Void) {
    }
    
    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager) {
    }
    
    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date {
        return Date().addingTimeInterval(.hours(-2))
    }
    
    func startDateToFilterNewReservoirEvents(for manager: PumpManager) -> Date {
        return Date().addingTimeInterval(.minutes(-15))
    }    
}
