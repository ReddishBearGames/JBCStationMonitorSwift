//
//  JBCSolderStation.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCSolderStation: JBCStation
{
	static func ModelNameIsSolderingStation(_ name: String) -> Bool
	{
		return ["DDE"].contains(name)
	}
	
	override init?(serialPort: JBCSerialPort,modelName: String, firmwareVersion: String, hardwareVersion: String, deviceID: String)
	{
		let modelNameParts = modelName.split(separator: "_", maxSplits: 1)
		let useModelName = String(modelNameParts[0])
		guard JBCSolderStation.ModelNameIsSolderingStation(useModelName) else { return nil }
		super.init(serialPort: serialPort, modelName: useModelName, firmwareVersion: firmwareVersion, hardwareVersion: hardwareVersion, deviceID: deviceID)
		stationType = .soldering
	}
}
