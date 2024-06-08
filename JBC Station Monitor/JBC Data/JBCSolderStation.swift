//
//  JBCSolderStation.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCSolderStation: JBCStation
{
	enum Command: UInt8
	{
		case levelsTemps = 51 // 0x33
	}
	
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
	
	override func createNewPort(_ portNum: UInt8, toolType: JBCTool.ToolType)
	{
		let newTool = JBCSolderingTool(serialPort: self.serialPort, toolType: toolType)
		let newStationPort = JBCStationPort(id: portNum, connectedTool: newTool)
		stationPorts.append(newStationPort)
		var portNumData = Data()
		portNumData.append(portNum)
		portNumData.append(toolType.rawValue)
		try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .levelsTemps, data: portNumData))

	}
	
	override func receivedCommand(_ command: JBCStationCommand) -> Bool
	{
		var handled: Bool = false
		if let solderingCommand = Command(rawValue: command.command)
		{
			handled = true
			switch solderingCommand
			{
			case .levelsTemps:
				// See WriteLevelsTemps for how to parse incoming data
				// Not clear on what to do with this yet
				guard command.dataField.count == 13 else
				{
					print("Unexpected data length in levelsTemp response")
					return false
				}
				let portNum: UInt8 = command.dataField[11]
				if let presets = TemperaturePresets(data: command.dataField),
				   let stationPort = stationPorts.first(where: { $0.id == portNum })
				{
					stationPort.temperaturePresets = presets
				}
			default:
				handled = false
			}
		}
		
		if !handled
		{
			handled = super.receivedCommand(command)
		}
		return handled
	}
}

extension JBCSerialPort
{
	// Convenience for passing a Solder Station command directly.
	public func formCommand(FID: UInt8? = nil, solderStationCommand: JBCSolderStation.Command, data: Data = Data(), overrideTargetAddress: UInt8? = nil) throws -> JBCStationCommand
	{
		return try formCommand(FID:FID, command: solderStationCommand.rawValue, data: data, overrideTargetAddress: overrideTargetAddress)
	}
}
