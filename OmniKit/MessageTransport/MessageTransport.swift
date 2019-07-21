//
//  MessageTransport.swift
//  OmniKit
//
//  Created by Pete Schwamb on 8/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import os.log

import RileyLinkBLEKit

protocol MessageLogger: class {
    // Comms logging
    func didSend(_ message: Data)
    func didReceive(_ message: Data)
}

public struct MessageTransportState: Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    public var packetNumber: Int
    public var messageNumber: Int
    
    init(packetNumber: Int, messageNumber: Int) {
        self.packetNumber = packetNumber
        self.messageNumber = messageNumber
    }
    
    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let packetNumber = rawValue["packetNumber"] as? Int,
            let messageNumber = rawValue["messageNumber"] as? Int
            else {
                return nil
        }
        self.packetNumber = packetNumber
        self.messageNumber = messageNumber
    }
    
    public var rawValue: RawValue {
        return [
            "packetNumber": packetNumber,
            "messageNumber": messageNumber
        ]
    }

}

protocol MessageTransportDelegate: class {
    func messageTransport(_ messageTransport: MessageTransport, didUpdate state: MessageTransportState)
}

public enum MessageSendError: Error {
    case podAckedInsteadOfReturningResponse
    case unexpectedPacketType(packetType: PacketType)
    case noResponse
    case emptyResponse
    case rileyLinkDeviceError(error: RileyLinkDeviceError)
    case messageError(error: MessageError)
}

public struct MessageSendFailure {
    let error: MessageSendError
    let hasUnsentData: Bool
}

public enum MessageSendResult {
    case success(Message)
    case failure(MessageSendFailure)
}

protocol MessageTransport {
    var delegate: MessageTransportDelegate? { get set }

    var messageNumber: Int { get }

    func sendMessage(_ message: Message) -> MessageSendResult

    /// Asserts that the caller is currently on the session's queue
    func assertOnSessionQueue()
}

class PodMessageTransport: MessageTransport {

    private let session: CommandSession
    
    private let log = OSLog(category: "PodMessageTransport")
    
    private var state: MessageTransportState {
        didSet {
            self.delegate?.messageTransport(self, didUpdate: state)
        }
    }
    
    private var packetNumber: Int {
        get {
            return state.packetNumber
        }
        set {
            state.packetNumber = newValue
        }
    }
    
    private(set) var messageNumber: Int {
        get {
            return state.messageNumber
        }
        set {
            state.messageNumber = newValue
        }
    }
    
    private let address: UInt32
    private var ackAddress: UInt32 // During pairing, PDM acks with address it is assigning to channel
    
    weak var messageLogger: MessageLogger?
    weak var delegate: MessageTransportDelegate?

    init(session: CommandSession, address: UInt32 = 0xffffffff, ackAddress: UInt32? = nil, state: MessageTransportState) {
        self.session = session
        self.address = address
        self.ackAddress = ackAddress ?? address
        self.state = state
    }
    
    private func incrementPacketNumber(_ count: Int = 1) {
        packetNumber = (packetNumber + count) & 0b11111
    }
    
    private func incrementMessageNumber(_ count: Int = 1) {
        messageNumber = (messageNumber + count) & 0b1111
    }
    
    func makeAckPacket() -> Packet {
        return Packet(address: address, packetType: .ack, sequenceNum: packetNumber, data: Data(bigEndian: ackAddress))
    }
    
    func ackUntilQuiet() {
        
        let packetData = makeAckPacket().encoded()
        
        var lastHeardAt = Date()
        let quietWindow = TimeInterval(milliseconds: 300)
        while lastHeardAt.timeIntervalSinceNow > -quietWindow {
            do {
                let rfPacket = try session.sendAndListen(packetData, repeatCount: 1, timeout: quietWindow, retryCount: 0, preambleExtension: TimeInterval(milliseconds: 40))
                let packet = try Packet(rfPacket: rfPacket)
                if packet.address == address {
                    lastHeardAt = Date() // Pod still sending
                }
            } catch RileyLinkDeviceError.responseTimeout {
                // Haven't heard anything in 300ms.  POD heard our ack.
                break
            } catch {
                continue
            }
        }
        incrementPacketNumber()
    }
    

    /// Encodes and sends a packet to the pod, and receives and decodes its response
    ///
    /// - Parameters:
    ///   - message: The packet to send
    ///   - repeatCount: Number of times to repeat packet before listening for a response. 0 = send once and do not repeat.
    ///   - packetResponseTimeout: The amount of time to wait before retrying
    ///   - exchangeTimeout: The amount of time to continue retrying before giving up
    ///   - preambleExtension: Duration of preamble. Default is 127ms
    /// - Returns: The received response packet
    /// - Throws:
    ///     - MessageSendError.noResponse
    ///     - RileyLinkDeviceError
    func exchangePackets(packet: Packet, repeatCount: Int = 0, packetResponseTimeout: TimeInterval = .milliseconds(333), exchangeTimeout:TimeInterval = .seconds(9), preambleExtension: TimeInterval = .milliseconds(127)) throws -> Packet {
        let packetData = packet.encoded()
        let radioRetryCount = 9
        
        let start = Date()
        
        incrementPacketNumber()
        
        while (-start.timeIntervalSinceNow < exchangeTimeout)  {
            do {
                let rfPacket = try session.sendAndListen(packetData, repeatCount: repeatCount, timeout: packetResponseTimeout, retryCount: radioRetryCount, preambleExtension: preambleExtension)
                
                let candidatePacket: Packet
                
                do {
                    candidatePacket = try Packet(rfPacket: rfPacket)
                } catch PacketError.insufficientData {
                    log.debug("Insufficient packet data: %@", rfPacket.data.hexadecimalString)
                    continue
                } catch let error {
                    log.debug("Packet error: %@", String(describing: error))
                    continue
                }
                
                guard candidatePacket.address == packet.address else {
                    continue
                }
                
                guard candidatePacket.sequenceNum == ((packet.sequenceNum + 1) & 0b11111) else {
                    continue
                }
                
                // Once we have verification that the POD heard us, we can increment our counters
                incrementPacketNumber()
                
                return candidatePacket
            } catch RileyLinkDeviceError.responseTimeout {
                continue
            }
        }
        
        throw MessageSendError.noResponse
    }

    /// Packetizes a message, and performs a set of packet exchanges to send a message and receive the response
    ///
    /// - Parameters:
    ///   - message: The message to send
    /// - Returns: The message send result, which includes response or error details

    func sendMessage(_ message: Message) -> MessageSendResult {
        
        messageNumber = message.sequenceNum
        incrementMessageNumber()

        var dataRemaining = message.encoded()
        log.debug("Send: %@", String(describing: message))
        log.debug("Send(Hex): %@", dataRemaining.hexadecimalString)

        do {
            let responsePacket = try { () throws -> Packet in
                var firstPacket = true
                messageLogger?.didSend(dataRemaining)
                while true {
                    let packetType: PacketType = firstPacket ? .pdm : .con
                    let sendPacket = Packet(address: address, packetType: packetType, sequenceNum: self.packetNumber, data: dataRemaining)
                    dataRemaining = dataRemaining.subdata(in: sendPacket.data.count..<dataRemaining.count)
                    firstPacket = false
                    let response = try self.exchangePackets(packet: sendPacket)
                    if dataRemaining.count == 0 {
                        return response
                    }
                }
            }()
            
            guard responsePacket.packetType != .ack else {
                messageLogger?.didReceive(responsePacket.data)
                log.debug("Pod responded with ack instead of response: %@", String(describing: responsePacket))
                return .failure(MessageSendFailure(error: .podAckedInsteadOfReturningResponse, hasUnsentData: !dataRemaining.isEmpty))
            }
            
            // Assemble fragmented message from multiple packets
            let response =  try { () throws -> Message in
                var responseData = responsePacket.data
                while true {
                    do {
                        let msg = try Message(encodedData: responseData)
                        log.debug("Recv(Hex): %@", responseData.hexadecimalString)
                        messageLogger?.didReceive(responseData)
                        return msg
                    } catch MessageError.notEnoughData {
                        log.debug("Sending ACK for CON")
                        let conPacket = try self.exchangePackets(packet: makeAckPacket(), repeatCount: 3, preambleExtension:TimeInterval(milliseconds: 40))
                        
                        guard conPacket.packetType == .con else {
                            log.debug("Expected CON packet, received; %@", String(describing: conPacket))
                            throw MessageSendError.unexpectedPacketType(packetType: conPacket.packetType)
                        }
                        responseData += conPacket.data
                    }
                }
                }()

            ackUntilQuiet()
            
            guard response.messageBlocks.count > 0 else {
                log.debug("Empty response")
                return .failure(MessageSendFailure(error: .emptyResponse, hasUnsentData: false))
            }
            
            if response.messageBlocks[0].blockType != .errorResponse {
                incrementMessageNumber()
            }
            
            log.debug("Recv: %@", String(describing: response))
            return .success(response)
        } catch let error as MessageError {
            log.error("MessageError during communication with POD: %@", String(describing: error))
            return .failure(MessageSendFailure(error: .messageError(error: error), hasUnsentData: !dataRemaining.isEmpty))
        } catch let error as RileyLinkDeviceError {
            log.error("RileyLinkDeviceError during communication with POD: %@", String(describing: error))
            var hasUnsentData = !dataRemaining.isEmpty
            switch error {
            case .unsupportedCommand, .writeSizeLimitExceeded:
                hasUnsentData = true
            case .peripheralManagerError(let peripheralManagerError):
                switch peripheralManagerError {
                case .notReady, .unknownCharacteristic:
                    hasUnsentData = true
                default:
                    break
                }
            default:
                break
            }
            return .failure(MessageSendFailure(error: .rileyLinkDeviceError(error: error), hasUnsentData: hasUnsentData))
        } catch let error as MessageSendError {
            log.error("MessageSendError during communication with POD: %@", String(describing: error))
            return .failure(MessageSendFailure(error: error, hasUnsentData: !dataRemaining.isEmpty))
        } catch let error {
            fatalError("Unexpected error: \(String(describing: error))")
        }
    }

    func assertOnSessionQueue() {
        session.assertOnSessionQueue()
    }
}
