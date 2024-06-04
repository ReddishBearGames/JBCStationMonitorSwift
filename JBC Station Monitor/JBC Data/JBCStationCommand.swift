//
//  JBCStationCommand.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/2/24.
//

import Foundation

struct JBCStationCommand
{
	enum ProtocolVersion
	{
		case protocolOne
		case protocolTwo
	}
	
	enum CommandError: Error
	{
		case malformedPacket(String)
	}
	
	enum Command: UInt8
	{
		case handshake = 0
		case endOfTransmission = 4
		case ack = 6
		case nack = 21
		case syn = 22
		case discover = 29
		case deviceID = 30 // Seems to be something like a UUID? Serial?
		case reset = 32
		case firmware = 33
	}
	
	var protocolVersion: ProtocolVersion = .protocolTwo
	var FID: UInt8 // What is this?
	var command: Command
	var sourceDevice: UInt8
	var targetDevice: UInt8
	var dataField: Data
	var NumberMessage: UInt?
	var date: Date?
	var response: Bool = false
	var delayedResponse: Bool = false
	
	static let startField: UInt8 = 0x02 // ASCII STX / Start Transmission
	static let stopField: UInt8 = 0x03 // ASCII ETX / End Transmission
	static let controlField: UInt8 = 0x10 // ASCII DLE / Data Link Escape

	static func minimumPacketLength(version: ProtocolVersion) -> UInt
	{
		switch version
		{
		case .protocolOne:
			return 7 // Start + To + From + Cmd + Len=0 + BCC + End
		case .protocolTwo:
			return 8 // Start + To + From + FID + Cmd + Len=0 + BCC + End
		}
	}
	
	
	static func command(fromReceivedPacket packet: Data, received: Bool, version: ProtocolVersion) throws -> JBCStationCommand
	{
		guard packet.count >= minimumPacketLength(version: version),
			  packet[0] == JBCStationCommand.startField,
				packet[packet.count - 1] == JBCStationCommand.stopField else
		{
			throw CommandError.malformedPacket("Packet too short \(packet.count), or wrong start or end values.\(packet.map { String(format: "%02d", $0) }.joined(separator: ","))")
		}
		
		let targetAddress: UInt8 = packet[received ? 1 : 2]
		let sourceAddress: UInt8 = packet[received ? 2 : 1]
		let FID: UInt8 = packet[3]
		guard let command: Command = Command(rawValue: packet[4]) else
		{
			throw CommandError.malformedPacket("Unrecognized command: \(packet[4])")
		}
		let dataLength: UInt8 = packet[5]
		guard packet.count == minimumPacketLength(version: version) + UInt(dataLength) else
		{
			throw CommandError.malformedPacket("Packet too short \(packet.count) \(packet.map { String(format: "%02d", $0) }.joined(separator: ","))")
		}
		let dataField: Data = (dataLength > 0) ? Data(packet[6...5+dataLength]) : Data()
		
		let ReturnMe: JBCStationCommand = JBCStationCommand(FID: FID, command: command, sourceDevice: sourceAddress, targetDevice: targetAddress, dataField: dataField)
		
		var bcc: UInt8 = 0
		var checkPacket = packet
		checkPacket[checkPacket.count - 2] = 0
		for oneByte in checkPacket
		{
			bcc = bcc ^ oneByte
		}
		guard bcc == packet[packet.count - 2] else
		{
			throw CommandError.malformedPacket("BCC mismatch: \(bcc) vs \(packet[packet.count - 2])")
		}
		
		return ReturnMe
	}
	
	func encode() -> Data
	{
		var ReturnMe: Data = Data()
		ReturnMe.append(JBCStationCommand.startField)
		ReturnMe.append(targetDevice)
		ReturnMe.append(sourceDevice)
		if protocolVersion == .protocolTwo
		{
			ReturnMe.append(FID)
		}
		ReturnMe.append(command.rawValue)
		ReturnMe.append(UInt8(dataField.count))
		ReturnMe.append(dataField)
		ReturnMe.append(JBCStationCommand.stopField)
		var bcc: UInt8 = 0
		for oneByte in ReturnMe
		{
			bcc = bcc ^ oneByte
		}
		// I think the BCC byte goes before the stopField?
		ReturnMe.insert(bcc, at: ReturnMe.count - 1)
		return ReturnMe
	}
	
	func encodeToTransmit() -> Data
	{
		let encodedCommand = encode()
		var ReturnMe: Data = Data()
		for oneByte in encodedCommand
		{
			if oneByte == JBCStationCommand.startField ||
				oneByte == JBCStationCommand.stopField ||
				oneByte == JBCStationCommand.controlField
			{
				// If the byte is the start or stop fields, we need to send the control character.
				// If the data IS the control character, we need to escape it by sending it twice.
				ReturnMe.append(JBCStationCommand.controlField)
			}
			ReturnMe.append(oneByte)
		}
		return ReturnMe
	}
}

