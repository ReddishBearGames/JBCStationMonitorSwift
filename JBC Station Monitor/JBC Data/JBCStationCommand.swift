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
		case nack = 21 // 0x15
		case syn = 22
		case discover = 29
		case deviceID = 30 // Seems to be something like a UUID? Serial?
		case reset = 32
		case firmware = 33
		case portInfo = 48 // 0x30
		case selectedTemperature = 80 // 0x50
		case toolStatus = 87 // 0x57
		case continuousMode = 128 // 80
		case continuousModeW = 129 // 81
		case stationName = 177 // 0xB1
		
		case solderCommand = 250 // Use the solderCommand field instead
	}
	
	var protocolVersion: ProtocolVersion = .protocolTwo
	var FID: UInt8 // What is this?
	var command: UInt8 // Why not the Command enum? Because different stations have different command subsets unfortunately...
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
		let command: UInt8 = packet[4]
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
		ReturnMe.append(command)
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
		for (index,oneByte) in encodedCommand.enumerated()
		{
			if (oneByte == JBCStationCommand.startField && index == 0) ||
				(oneByte == JBCStationCommand.stopField  && index == encodedCommand.count - 1) ||
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
	
	static func extractTwoByteValueAndPortFromCommonResponse(_ data: Data, numTemps: Int = 1) throws -> (port: UInt8, temperatures: [UInt16])
	{
		// Need one byte for the port address, and two for each temperature reading we're expecting to be here.
		guard data.count == 1 + (2*numTemps) else
		{
			throw CommandError.malformedPacket("Common Temperature response must be three bytes")
		}
		let portNum = data[data.count - 1]
		var temps = [UInt16]()
		
		for tempIndex in 0..<numTemps
		{
			let utiTemp: UInt16 = data[(tempIndex*2)...(tempIndex*2 + 1)].toInteger(endian: .little)
			temps.append(utiTemp)
		}
		return (port: portNum, temperatures: temps)
	}
}

