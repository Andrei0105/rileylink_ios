//
//  ReservoirStatus.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/28/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public enum ReservoirStatus: UInt8, CustomStringConvertible {
    case initialized = 0
    case tankPowerActivated = 1
    case tankFillCompleted = 2
    case pairingSuccess = 3
    case priming = 4
    case readyForInjection = 5
    case injectionStarted = 6
    case injectionDone = 7
    case aboveFiftyUnits = 8
    case belowFiftyUnits = 9
    case oneNotUsedButin33 = 10
    case twoNotUsedButin33 = 11
    case threeNotUsedButin33 = 12
    case errorEventLoggedShuttingDown = 13
    case delayedPrime = 14 // Saw this after delaying prime for a day
    case inactive = 15 // ($1C Deactivate Pod or packet header mismatch)
    
    public var description: String {
        switch self {
        case .initialized:
            return LocalizedString("Initialized", comment: "Pod inititialized")
        case .tankPowerActivated:
            return LocalizedString("Tank power activated", comment: "Pod power to motor activated")
        case .tankFillCompleted:
            return LocalizedString("Tank fill completed", comment: "Pod tank fill completed")
        case .pairingSuccess:
            return LocalizedString("Paired", comment: "Pod status after pairing")
        case .priming:
            return LocalizedString("Priming", comment: "Pod status when priming")
        case .readyForInjection:
            return LocalizedString("Ready to insert cannula", comment: "Pod status when ready for cannula insertion")
        case .injectionStarted:
            return LocalizedString("Cannula inserting", comment: "Pod status when inserting cannula")
        case .injectionDone:
            return LocalizedString("Cannula inserted", comment: "Pod status when cannula insertion finished")
        case .aboveFiftyUnits:
            return LocalizedString("Normal", comment: "Pod status when running above fifty units")
        case .belowFiftyUnits:
            return LocalizedString("Below 50 units", comment: "Pod status when running below fifty units")
        case .oneNotUsedButin33:
            return LocalizedString("oneNotUsedButin33", comment: "Pod status oneNotUsedButin33")
        case .twoNotUsedButin33:
            return LocalizedString("twoNotUsedButin33", comment: "Pod status twoNotUsedButin33")
        case .threeNotUsedButin33:
            return LocalizedString("threeNotUsedButin33", comment: "Pod status threeNotUsedButin33")
        case .errorEventLoggedShuttingDown:
            return LocalizedString("Error event logged, shutting down", comment: "Pod status error event logged shutting down")
        case .delayedPrime:
            return LocalizedString("Prime not completed", comment: "Pod status when prime has not completed")
        case .inactive:
            return LocalizedString("Deactivated", comment: "Pod status when pod has been deactivated")
        }
    }
}
    
