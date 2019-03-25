//
//  PodStateTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class PodStateTests: XCTestCase {

    let now = Date()
    
    func testNonceValues() {
        var podState = PodState(address: 0x1f000000, activatedAt: now, expiresAt: now.addingTimeInterval(.hours(72)), piVersion: "1.1.0", pmVersion: "1.1.0", lot: 42560, tid: 661771)
        
        XCTAssertEqual(podState.currentNonce, 0x8c61ee59)
        podState.advanceToNextNonce()
        XCTAssertEqual(podState.currentNonce, 0xc0256620)
        podState.advanceToNextNonce()
        XCTAssertEqual(podState.currentNonce, 0x15022c8a)
        podState.advanceToNextNonce()
        XCTAssertEqual(podState.currentNonce, 0xacf076ca)
    }
    
    func testResyncNonce() {
        do {
            let config = try VersionResponse(encodedData: Data(hexadecimalString: "011502070002070002020000a62b0002249da11f00ee860318")!)
            var podState = PodState(address: 0x1f00ee86, activatedAt: now, expiresAt: now.addingTimeInterval(.hours(72)), piVersion: "1.1.0", pmVersion: "1.1.0", lot: config.lot, tid: config.tid)

            XCTAssertEqual(42539, config.lot)
            XCTAssertEqual(140445,  config.tid)
            
            XCTAssertEqual(0x8fd39264,  podState.currentNonce)

            // ID1:1f00ee86 PTYPE:PDM SEQ:26 ID2:1f00ee86 B9:24 BLEN:6 BODY:1c042e07c7c703c1 CRC:f4
            let sentPacket = try Packet(encodedData: Data(hexadecimalString: "1f00ee86ba1f00ee8624061c042e07c7c703c1f4")!)
            let sentMessage = try Message(encodedData: sentPacket.data)
            let sentCommand = sentMessage.messageBlocks[0] as! DeactivatePodCommand
            
            let errorResponse = try ErrorResponse(encodedData: Data(hexadecimalString: "06031492c482f5")!)

            XCTAssertEqual(9, sentMessage.sequenceNum)

            podState.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: sentCommand.nonce, messageSequenceNum: sentMessage.sequenceNum)
            
            XCTAssertEqual(0x40ccdacb,  podState.currentNonce)


        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
}

