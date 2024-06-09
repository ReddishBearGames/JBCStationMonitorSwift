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
		case cartridge = 72 // 0x48
		case tipTemp = 82 // 0x52
		case mosTemp = 89 // 0x59, Not sure what this actually is
		case maxTemp = 162 // 0xa2
		case minTemp = 164 // 0xa4
	}
	
	static func ModelNameIsSolderingStation(_ name: String) -> Bool
	{
		return ["DDE"].contains(name)
	}
	
	var maxTemp: UInt16 = 0
	var minTemp: UInt16 = 0
	var levelsUpdateTimer: Timer? = nil
	
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
		let newStationPort = JBCStationPort(serialPort:self.serialPort, id: portNum, connectedTool: newTool)
		stationPorts.append(newStationPort)
		var portNumData = Data()
		portNumData.append(portNum)
		try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .mosTemp, data: portNumData))
		try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .tipTemp, data: portNumData))
		portNumData.append(toolType.rawValue)
		try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .levelsTemps, data: portNumData))
		try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .maxTemp))
		try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .minTemp))
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
					if presets.useLevels == .on
					{
						// Schedule an update on this periodically, in case the user changes the currently selected preset
						self.levelsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false)
						{ timer in
							var portNumData: Data = Data()
							portNumData.append(portNum)
							portNumData.append(stationPort.connectedTool.toolType.rawValue)
							try? self.serialPort.sendCommand(self.serialPort.formCommand(solderStationCommand: .levelsTemps, data: portNumData))
						}
					}
				}
			//case .cartridge:
			case .maxTemp:
				maxTemp = command.dataField.toInteger(endian: .little)
			case .minTemp:
				minTemp = command.dataField.toInteger(endian: .little)
			case .mosTemp:
				if let tempResponse = try? JBCStationCommand.extractTempAndPortFromCommonResponse(command.dataField)
				{
					if stationPorts.first(where: { $0.id == tempResponse.port }) != nil
					{
						print("Reported MOS Temp of \(UTIToCelcius(tempResponse.temperatures[0])) on port \(tempResponse.port)")
					}
				}
				else
				{
					return false
				}
			case .tipTemp:
				if let tempResponse = try? JBCStationCommand.extractTempAndPortFromCommonResponse(command.dataField, numTemps: 2)
				{
					if let stationPort = stationPorts.first(where: { $0.id == tempResponse.port })
					{
						stationPort.connectedTool.tipTemp = tempResponse.temperatures[0]
						stationPort.connectedTool.tipTwoTemp = tempResponse.temperatures[1]
					}
				}
				else
				{
					return false
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
