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
						print("Unhandled command reply: \(oneCommand.command) Data: \(oneCommand.encode().map { String(format: "%02x", $0) }.joined(separator: ","))")
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
					print("Unhandled command reply at serial stage: \(oneCommand.command)")
				}
			}
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

