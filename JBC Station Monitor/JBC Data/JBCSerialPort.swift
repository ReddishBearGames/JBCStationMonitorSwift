//
//  JBCSerialPort.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/2/24.
//

import Foundation
import ORSSerial

@Observable class JBCSerialPort : Identifiable
{
	enum State: Equatable
	{
		case uninitialized
		case initializing
		case unknownDevice
		case jbcToolFound
		//case jbcCommError(JBCStationCommand.CommunicationError)
		
		var localizableKey: String
		{
			let keyEnd: String
			switch self
			{
			case .uninitialized:
				keyEnd = "UNINITIALIZED"
			case .initializing:
				keyEnd = "INITIALIZING"
			case .unknownDevice:
				keyEnd = "UNKNOWN_DEVICE"
			case .jbcToolFound:
				keyEnd = "TOOL_FOUND"
				//case .jbcCommError(_):
				//keyEnd = "TOOL_COMMERROR"
			}
			return String(format: "JBC_SERIALPORT_STATE_%@", keyEnd)
		}
	}
	
	enum CommunicationError: UInt8
	{
		case bcc = 1
		case format = 2
		case outOfRange = 3
		case control = 4
		case robotMode = 5
		case stationModel = 6
		case unknown = 255
	}
	
	
	enum HandshakeStage
	{
		case notStarted
		case waitingForFW
		case waitingForDeviceID
		case waitingForAck
		case complete
	}
	
	public let serialPort: ORSSerialPort
	var state: State = .uninitialized
	var targetAddress: UInt8 = 0
	var sourceAddress: UInt8 = 0
	var handshakeState: HandshakeStage = .notStarted
	var stationModel: String? = nil
	var lastSentFID: UInt8 = 0
	var rawFirmwareResponse: String? = nil
	var rawDeviceIDResponse: String? = nil
	static let FIDMAX: UInt8 = 239 // Anything higher is reserved
	
	init(serialPort: ORSSerialPort)
	{
		self.serialPort = serialPort
	}
	
	public var id: UInt32
	{
		return self.serialPort.ioKitDevice
	}
	
	public func open() async
	{
		await MainActor.run
		{
			self.state = .initializing
		}
		// Set the comm parameters
		self.serialPort.allowsNonStandardBaudRates = true
		self.serialPort.baudRate = NSNumber(value:500000)
		self.serialPort.numberOfStopBits = 1
		self.serialPort.parity = .none
		self.serialPort.usesRTSCTSFlowControl = true
		self.serialPort.numberOfDataBits = 8
		
		await MainActor.run
		{
			self.state = .initializing
		}
		
		self.serialPort.open()
	}
	
	// Convenience for passing a station command directly.
	public func formCommand(FID: UInt8? = nil, stationCommand: JBCStationCommand.Command, data: Data = Data(), overrideTargetAddress: UInt8? = nil) throws -> JBCStationCommand
	{
		return try formCommand(FID:FID, command: stationCommand.rawValue, data: data, overrideTargetAddress: overrideTargetAddress)
	}

	
	public func formCommand(FID: UInt8? = nil, command: UInt8, data: Data = Data(), overrideTargetAddress: UInt8? = nil) throws -> JBCStationCommand
	{
		var useFID: UInt8? = FID
		if useFID == nil
		{
			// If no FID specified, use the next in sequence.
			useFID = lastSentFID + 1
			// Important that we only do this "wrapping" in the nil case, because handshaking requires out-of-bounds FIDs
			if useFID! > JBCSerialPort.FIDMAX
			{
				useFID = 0
			}
		}

		guard let useFID = useFID
		else {
			throw JBCStationCommand.CommandError.malformedPacket("nil FID?!") // I think this is impossible?
		}
			
		let ReturnMe = JBCStationCommand(FID: useFID, command: command,
										 sourceDevice: sourceAddress,
										 targetDevice: overrideTargetAddress ?? targetAddress, dataField: data)
		// Might this never be sent? Sure. Does it matter? Not really.
		self.lastSentFID = useFID
		return ReturnMe
	}
	
	public func sendCommand(_ command: JBCStationCommand)
	{
		print("Transmit Command: \(command.encode().map { String(format: "%02x", $0) }.joined(separator: ","))")
		let transmitData = command.encodeToTransmit()
		self.serialPort.send(transmitData)
		//print("Transmitted: \(transmitData.map { String(format: "%02x", $0) }.joined(separator: ","))")
	}
	
	var receivingPacket: Data = Data()
	var receivedControlCharacter: Bool = false
	
	func receive(rawData:Data) -> [JBCStationCommand]
	{
		var returnCommands = [JBCStationCommand]()
		for oneByte in rawData
		{
			//print("\"\(String(format:"%02d", oneByte))\"")
			if oneByte == JBCStationCommand.controlField
			{
				if (receivedControlCharacter)
				{
					// If we received TWO of these back-to-back, treat it as literal data and clear the flag
					receivingPacket.append(oneByte)
					receivedControlCharacter = false
				}
				else
				{
					// When we first receive this, we can't know what to do with it until we receive a subsequent character
					receivedControlCharacter = true
				}
			}
			else
			{
				receivingPacket.append(oneByte)
				// Was the PREVIOUS character a control character and this is a 'stop'?
				if (receivedControlCharacter && oneByte == JBCStationCommand.stopField)
				{
					// It was, so start a new message.
					if receivingPacket.count > 0
					{
						print("Received packet: \(receivingPacket.map { String(format: "%02x", $0) }.joined(separator: ","))")
						do
						{
							let newReturnCommand = try JBCStationCommand.command(fromReceivedPacket: receivingPacket, received: true, version: .protocolTwo)
							returnCommands.append(newReturnCommand)
						}
						catch
						{
							print("Failed to formulate command from packet: \(error)")
						}
					}
					receivingPacket.removeAll()
				}
				receivedControlCharacter = false
			}
		}
		return returnCommands
	}
	
	func receivedCommand(_ command: JBCStationCommand) -> Bool
	{
		var handledCommand: Bool = false
		if let stationCommand = JBCStationCommand.Command(rawValue: command.command)
		{
			switch stationCommand
			{
			case .handshake:
				if handshakeState == .notStarted &&
					command.FID == 253 && // Magic number?
					command.targetDevice == 0 && // Broadcast
					sourceAddress == 0 && // If these are both 0, we haven't handled the handshake broadcast yet
					targetAddress == 0 &&
					command.dataField.count == 1 &&
					command.dataField[0] == JBCStationCommand.Command.discover.rawValue
				{
					// We reply to the handshake broadcast with an ACK in the payload, but the main command is still "handshake".
					// The device's address is XOR'd by 80 for the source of this response - unclear if that's a magic number of if that's us choosing
					// what our address will ultimately be.
					var data: Data = Data()
					data.append(JBCStationCommand.Command.ack.rawValue)
					try? sendCommand(formCommand(FID: 253, stationCommand: .handshake, data: data, overrideTargetAddress: command.sourceDevice ^ 0x80))
					// Immedaitely followup with a firmware request.
					try? sendCommand(formCommand(FID: 237, stationCommand: .firmware, overrideTargetAddress: command.sourceDevice))
					// Accept the device's address AFTER sending the above
					targetAddress = command.sourceDevice
					handshakeState = .waitingForFW
					handledCommand = true
				}
				else if handshakeState == .complete
				{
					// Just "eat" the command.
					handledCommand = true
				}
			case .firmware:
				if command.FID == 237
				{
					guard let firmwareResponse: String = String(data:command.dataField, encoding: .ascii)
					else {
						print("Failed to parse FIRMWARE payload.")
						return handledCommand
					}
					self.rawFirmwareResponse = firmwareResponse
					
					if handshakeState == .waitingForFW
					{
						// This came back as part of the handshake process, move along in that process.
						// Start the FID counter from 0
						lastSentFID = 0
						targetAddress = 0
						try? sendCommand(formCommand(stationCommand: .deviceID, overrideTargetAddress: command.sourceDevice))
						targetAddress = command.sourceDevice
						handshakeState = .waitingForDeviceID
					}
					handledCommand = true
				}
			case .deviceID:
				guard let deviceID: String = String(data:command.dataField, encoding: .ascii)
				else {
					print("Failed to parse DEVICEID payload.")
					return handledCommand
				}
				self.rawDeviceIDResponse = deviceID
				handledCommand = true
				
				if handshakeState == .waitingForDeviceID
				{
					// Send an ACK
					targetAddress = 0
					try? sendCommand(formCommand(stationCommand: .ack, overrideTargetAddress: command.sourceDevice))
					targetAddress = command.sourceDevice
					// And expect one in turn
					handshakeState = .waitingForAck
				}
			case .ack:
				if handshakeState == .waitingForAck &&
					lastSentFID == command.FID
				{
					handledCommand = true
					
					if command.dataField.count == 1 &&
						command.dataField[0] == JBCStationCommand.Command.ack.rawValue
					{
						// Accept our address, handshake complete!
						sourceAddress = command.targetDevice
						handshakeState = .complete
						state = .jbcToolFound
					}
					else
					{
						print("Received bad ACK")
					}
				}
				else
				{
					print("Unexpected ACK received")
				}
			default:
				break
			}
		}
		return handledCommand
	}
	
	func verifyCheck(_ checksumData: Data) -> Bool
	{
		var result: Bool = false;
		guard checksumData.count > 0,
			  let lastByte: UInt8 = checksumData.last
		else { return result }
		
		var accumulator: UInt8 = 0
		for oneByte in checksumData
		{
			accumulator += oneByte;
		}
		let check: UInt8 = (accumulator & 0xFF) | 0x20
		result = lastByte == check
		
		return result;
	}
	
}

extension ORSSerialPort
{
	var identifiers: (vendorID: NSNumber, productID: NSNumber)?
	{
		var ReturnMe: (vendorID: NSNumber, productID: NSNumber)? = nil
		var deviceIterator = io_iterator_t()
		defer
		{
			IOObjectRelease(deviceIterator)
		}
		
		guard (IORegistryEntryCreateIterator(self.ioKitDevice,
											 kIOServicePlane,
											 IOOptionBits(kIORegistryIterateRecursively + kIORegistryIterateParents),
											 &deviceIterator) == KERN_SUCCESS)
		else { return nil }
		
		
		var oneDeviceEntry: io_registry_entry_t = IOIteratorNext(deviceIterator)
		while (oneDeviceEntry != IO_OBJECT_NULL &&
			   ReturnMe == nil &&
			   oneDeviceEntry != IO_OBJECT_NULL)
		{
			defer
			{
				IOObjectRelease(oneDeviceEntry)
				oneDeviceEntry = IOIteratorNext(deviceIterator)
			}
			
			var usbProperties: Unmanaged<CFMutableDictionary>?
			guard (IORegistryEntryCreateCFProperties(oneDeviceEntry, &usbProperties, kCFAllocatorDefault, 0) == kIOReturnSuccess) else { continue }
			defer
			{
				usbProperties?.release()
			}
			guard let propertiesDict = usbProperties?.takeUnretainedValue() as? [String: AnyObject] else { continue	}
			
			guard let vendorID: NSNumber = propertiesDict[kUSBVendorID] as? NSNumber,
				  let productID: NSNumber = propertiesDict[kUSBProductID] as? NSNumber else { continue }
			
			
			ReturnMe = (vendorID:vendorID,productID:productID)
		}
		
		return ReturnMe
	}
}
