//
//  JBCHotAirStation.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCHotAirStation: JBCStation
{
	static func ModelNameIsHotAirStation(_ name: String) -> Bool
	{
		return ["JTSE"].contains(name)
	}
	
	override func createNewPort(_ portNum: UInt8, toolType: JBCTool.ToolType)
	{
		let newTool = JBCHotairTool(serialPort:self.serialPort, toolType: toolType)
		let newStationPort = JBCStationPort(id: portNum, connectedTool: newTool)
		stationPorts.append(newStationPort)
	}
	
	override init?(serialPort: JBCSerialPort,modelName: String, firmwareVersion: String, hardwareVersion: String, deviceID: String)
	{
		let modelNameParts = modelName.split(separator: "_", maxSplits: 1)
		let useModelName = String(modelNameParts[0])
		guard JBCHotAirStation.ModelNameIsHotAirStation(useModelName) else { return nil }
		super.init(serialPort: serialPort, modelName: useModelName, firmwareVersion: firmwareVersion, hardwareVersion: hardwareVersion, deviceID: deviceID)
		stationType = .hotair
	}
}

/*
extension JBCSerialPort
{
	// Convenience for passing a Hot Air Station command directly.
	public func formCommand(FID: UInt8? = nil, hotairStationCommand: JBCSolderStation.Command, data: Data = Data(), overrideTargetAddress: UInt8? = nil) throws -> JBCStationCommand
	{
		return try formCommand(FID:FID, command: hotairStationCommand.rawValue, data: data, overrideTargetAddress: overrideTargetAddress)
	}
}

*/
