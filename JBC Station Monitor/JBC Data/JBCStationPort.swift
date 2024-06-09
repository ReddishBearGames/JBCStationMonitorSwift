//
//  JBCStationPort.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCStationPort: Identifiable
{	
	enum ContiunuousModeRate: UInt8
	{
		case off = 0
		case ms10 = 1
		case ms20 = 2
		case ms50 = 3
		case ms100 = 4
		case ms200 = 5
		case ms500 = 6
		case ms1000 = 7
	}
	
	var id: UInt8 // Port number
	var temperaturePresets: TemperaturePresets? = nil
	var selectedTemperature: UInt16 = 0
	var continuousModeRate: ContiunuousModeRate = .off

	let connectedTool: JBCTool
	let serialPort: JBCSerialPort?

	init(serialPort: JBCSerialPort? = nil, id: UInt8, connectedTool: JBCTool)
	{
		self.serialPort = serialPort
		self.id = id
		self.connectedTool = connectedTool
	}
}
