//
//  MinimedHUDProvider.swift
//  MinimedKitUI
//
//  Created by Pete Schwamb on 2/4/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import MinimedKit
import SwiftUI

class MinimedHUDProvider: HUDProvider {

    var managerIdentifier: String {
        return MinimedPumpManager.managerIdentifier
    }

    private var state: MinimedPumpManagerState {
        didSet {
            guard visible else {
                return
            }

            if oldValue.lastReservoirReading != state.lastReservoirReading {
                self.updateReservoirView()
            }
        }
    }

    private let pumpManager: MinimedPumpManager
    
    private let insulinTintColor: Color
    
    private let guidanceColors: GuidanceColors

    public init(pumpManager: MinimedPumpManager, insulinTintColor: Color, guidanceColors: GuidanceColors) {
        self.pumpManager = pumpManager
        self.state = pumpManager.state
        self.insulinTintColor = insulinTintColor
        self.guidanceColors = guidanceColors
        pumpManager.stateObservers.insert(self, queue: .main)
    }

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                self.updateReservoirView()
            }
        }
    }

    private weak var reservoirView: ReservoirVolumeHUDView?

    private func updateReservoirView() {
        if let lastReservoirVolume = state.lastReservoirReading,
            let reservoirView = reservoirView
        {
            let reservoirLevel = (lastReservoirVolume.units / pumpManager.pumpReservoirCapacity).clamped(to: 0...1.0)
            reservoirView.level = reservoirLevel
            reservoirView.setReservoirVolume(volume: lastReservoirVolume.units, at: lastReservoirVolume.validAt)
        }
    }

    public func createHUDView() -> LevelHUDView? {

        reservoirView = ReservoirVolumeHUDView.instantiate()

        if visible {
            updateReservoirView()
        }

        return reservoirView
    }

    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        return HUDTapAction.presentViewController(pumpManager.settingsViewController(insulinTintColor: insulinTintColor, guidanceColors: guidanceColors))
    }

    public var hudViewRawState: HUDProvider.HUDViewRawState {
        var rawValue: HUDProvider.HUDViewRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity
        ]

        if let lastReservoirReading = state.lastReservoirReading {
            rawValue["lastReservoirReading"] = lastReservoirReading.rawValue
        }

        return rawValue
    }

    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView? {
        guard let pumpReservoirCapacity = rawValue["pumpReservoirCapacity"] as? Double else {
            return nil
        }

        let reservoirVolumeHUDView = ReservoirVolumeHUDView.instantiate()
        if let rawLastReservoirReading = rawValue["lastReservoirReading"] as? ReservoirReading.RawValue,
            let lastReservoirReading = ReservoirReading(rawValue: rawLastReservoirReading)
        {
            let reservoirLevel = (lastReservoirReading.units / pumpReservoirCapacity).clamped(to: 0...1.0)
            reservoirVolumeHUDView.level = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: lastReservoirReading.units, at: lastReservoirReading.validAt)
        }
        
        return reservoirVolumeHUDView
    }
}

extension MinimedHUDProvider: MinimedPumpManagerStateObserver {
    func didUpdatePumpManagerState(_ state: MinimedPumpManagerState) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.state = state
    }
}
