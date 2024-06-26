//
//  SerialManager.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/2/24.
//

import Foundation
import ORSSerial

@Observable class SerialManager: NSObject, ORSSerialPortDelegate
{
	var knownPorts: [JBCSerialPort] = [JBCSerialPort]()
	var knownStations: [JBCStation] = [JBCStation]()
	
	init(createFake : Bool = false)
	{
		super.init()
		Task
		{
			await findSerialPorts()
		}
	}
	
	func findSerialPorts() async
	{
		let ports: [ORSSerialPort] = ORSSerialPortManager.shared().availablePorts
		var foundPorts: [JBCSerialPort] = [JBCSerialPort]()
		for onePort in ports
		{
			let portIdentifiers = onePort.identifiers
			// Let's ignore vendorless/productless ports for now; this seems to be virtual ports like Bluetooth.
			guard(portIdentifiers?.vendorID != nil ||
				  portIdentifiers?.productID != nil) else { continue }
			onePort.delegate = self
			foundPorts.append(JBCSerialPort(serialPort: onePort))
		}
		let finalPorts = foundPorts
		await MainActor.run
		{
			knownPorts.removeAll()
			knownPorts.append(contentsOf: finalPorts)
		}
	}
	
	// Port delegate callbacks
	func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data)
	{
		// We SHOULD always have a serial port that matches
		let jbcSerial: JBCSerialPort? = knownPorts.first(where: { $0.serialPort == serialPort } )
		// Stations are spawned from serial ports if succesfully opened. We may or may not have one yet.
		let jbcStation: JBCStation? = knownStations.first(where: { $0.serialPort.serialPort == serialPort } )
		// Retrieve the command if any, preferring the station as a "higher level" entity
		if let jbcStation,
		   let jbcSerial
		{
			let commands = jbcStation.receive(rawData: data)
			for oneCommand in commands
			{
				if !jbcSerial.receivedCommand(oneCommand)
				{
					if !jbcStation.receivedCommand(oneCommand)
					{
						dumpUnhandledCommandReply(oneCommand)
					}
				}
			}
		}
		else if let jbcSerial
		{
			let commands = jbcSerial.receive(rawData: data)
			for oneCommand in commands
			{
				if jbcSerial.receivedCommand(oneCommand)
				{
					if jbcSerial.handshakeState == .complete
					{
						if let newStation = JBCStation.CreateStation(serialPort: jbcSerial, rawFirmware:jbcSerial.rawFirmwareResponse ?? "", rawDeviceID:jbcSerial.rawDeviceIDResponse ?? "")
						{
							knownStations.append(newStation)
							newStation.start()
						}
					}
				}
				else
				{
					dumpUnhandledCommandReply(oneCommand)
				}
			}
		}
	}
	
	func unhandledCommandName(commandByte: UInt8) -> String
	{
		// Let's turn the failed command into a string representation of the appropriate enum
		let failedCommandString: String
		if let stationCommand: JBCStationCommand.Command = JBCStationCommand.Command(rawValue: commandByte)
		{
			failedCommandString = String("JBCStationCommand.Command.\(stationCommand)")
		}
		else
		{
			let solderCommand: JBCStationCommand.CommandSolder? = JBCStationCommand.CommandSolder(rawValue: commandByte)
			let hotAirCommand: JBCStationCommand.CommandHotair? = JBCStationCommand.CommandHotair(rawValue: commandByte)
			if let solderCommand = solderCommand,
			   let hotAirCommand = hotAirCommand
			{
				failedCommandString = String("JBCSolderStation.Command.\(solderCommand) or JBCHotAirStation.Command.\(hotAirCommand)")
			}
			else if let solderCommand = solderCommand
			{
				failedCommandString = String("JBCSolderStation.Command.\(solderCommand)")
			}
			else if let hotAirCommand = hotAirCommand
			{
				failedCommandString = String("JBCHotAirStation.Command.\(hotAirCommand)")
			}
			else
			{
				failedCommandString = "Unknown \(commandByte)"
			}
		}
		return failedCommandString
	}
	
	func dumpUnhandledCommandReply(_ command: JBCStationCommand)
	{
		if command.command == JBCStationCommand.Command.nack.rawValue
		{
			let failedCommandString = unhandledCommandName(commandByte: command.dataField[1])
			let failureReason: String
			if let failureCode: JBCSerialPort.CommunicationError = JBCSerialPort.CommunicationError(rawValue: command.dataField[0])
			{
				failureReason = "\(failureCode)"
			}
			else
			{
				failureReason = "Unknown code: \(command.dataField[0])"
			}
			print("Received NACK in response to \(failedCommandString) command. \(failureReason)")
		}
		else
		{
			print("Unhandled command reply: \(unhandledCommandName(commandByte:command.command)) Data: \(command.encode().map { String(format: "%02x", $0) }.joined(separator: ","))")
		}
	}

	
	func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort)
	{
		// knownTools.removeAll(where: { $0.serialPort.serialPort == serialPort }) // This looks stupid/wrong, but our JBCSerialPort *owns* an ORSSerialPort rather than subclassing it
		knownPorts.removeAll(where: { $0.serialPort == serialPort })
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error)
	{
		print("Serial port (\(serialPort)) encountered error: \(error)\n")
	}
	
	func serialPortWasOpened(_ serialPort: ORSSerialPort)
	{
		print("Serial port \(serialPort) was opened\n", terminator: "")
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest)
	{
		/*
		if let jbcSerial: JBCSerialPort = knownPorts.first(where: { $0.serialPort == serialPort } )
		{
			
		}
		 */
	}
	
	func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest)
	{
		print("Timeout!")
	}
	
}

