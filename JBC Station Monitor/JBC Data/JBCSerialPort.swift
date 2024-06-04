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
	
	
	public let serialPort: ORSSerialPort
	var state: State = .uninitialized
	var targetAddress: UInt8 = 0
	var sourceAddress: UInt8 = 0
	
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
	
	public func formCommand(FID: UInt8, command: JBCStationCommand.Command, data: Data = Data(), overrideSourceAddress: UInt8? = nil) -> JBCStationCommand
	{
		let ReturnMe = JBCStationCommand(FID: FID, command: command,
										 sourceDevice: overrideSourceAddress ?? sourceAddress,
										 targetDevice: targetAddress, dataField: data)
		return ReturnMe
	}
	
	public func sendCommand(_ command: JBCStationCommand)
	{
		print("Transmit Command: \(command.encode().map { String(format: "%02d", $0) }.joined(separator: ","))")
		let transmitData = command.encodeToTransmit()
		self.serialPort.send(transmitData)
		//print("Transmitted: \(transmitData.map { String(format: "%02d", $0) }.joined(separator: ","))")
	}
	
	var receivingPacket: Data = Data()
	var receivedControlCharacter: Bool = false
	
	func receive(rawData:Data)
	{
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
						print("Received packet: \(receivingPacket.map { String(format: "%02d", $0) }.joined(separator: ","))")
						do
						{
							try receivedCommand(JBCStationCommand.command(fromReceivedPacket: receivingPacket, received: true, version: .protocolTwo))
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
	}
	
	func receivedCommand(_ command: JBCStationCommand)
	{
		guard command.targetDevice == sourceAddress ||
				command.command == .handshake else
		{
			print("Ignoring broadcast: \(command)")
			return
		}
		
		switch command.command {
		case .handshake:
			if command.FID == 253 && // Magic number?
				command.targetDevice == 0 && // Broadcast
				sourceAddress == 0 && // If these are both 0, we haven't handled the handshake broadcast yet
				targetAddress == 0 &&
				command.dataField.count == 1 &&
				command.dataField[0] == JBCStationCommand.Command.discover.rawValue
			{
				// Acknowledge the device's desired address
				targetAddress = command.sourceDevice
				var data: Data = Data()
				sourceAddress = 16
				data.append(sourceAddress)
				sendCommand(formCommand(FID: 253, command: .handshake, data: data))
			}
			else if command.FID == 253 &&
					command.sourceDevice == targetAddress &&
					command.dataField.count == 1 &&
					command.dataField[0] == JBCStationCommand.Command.ack.rawValue
			{
				// We're given our final address in this packet
				sourceAddress = command.targetDevice
				/*
				 // Under some conditions this appears to be done, but unclear to me what they are...
				var data: Data = Data()
				data.append(6)
				sendCommand(formCommand(FID: 253, command: .handshake, data: data, overrideSourceAddress: sourceAddress ^ 0x80)) // Weird magic values everywhere... This appears to get us back to the 16 we were originally using?
				 */
				//sendCommand(formCommand(FID: 237, command: .firmware))
				sendCommand(formCommand(FID: 237, command: .deviceID))
			}
		default:
			print("Unhandled command \(command.command)")
		}
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
