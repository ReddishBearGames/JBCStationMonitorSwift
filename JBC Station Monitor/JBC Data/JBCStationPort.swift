//
//  JBCStationPort.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCStationPort: Identifiable
{	
	var id: UInt8 // Port number
	var temperaturePresets: TemperaturePresets? = nil	

	let connectedTool: JBCTool
	
	init(id: UInt8, connectedTool: JBCTool) 
	{
		self.id = id
		self.connectedTool = connectedTool
	}
}
