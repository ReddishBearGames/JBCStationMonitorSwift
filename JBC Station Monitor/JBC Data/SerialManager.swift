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
	// var knownTools: [JBCStation] = [JBCStation]()
	
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
		if let jbcSerial: JBCSerialPort = knownPorts.first(where: { $0.serialPort == serialPort } )
		{
			jbcSerial.receive(rawData:data)
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

