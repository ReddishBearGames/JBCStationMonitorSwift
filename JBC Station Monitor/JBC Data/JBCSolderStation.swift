//
//  JBCSolderStation.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCSolderStation: JBCStation
{
	// Each port in the update packet is this long
	static let ContinuousModePortUpdateLength = 10
	// First byte that starts the port updates section of the response data
	static let ContinuousModePortUpdateStartPosition = 1
	// Position containing the Tool Status in the *subfield* of a Port Update
	static let ContinuousModePortUpdateToolStatusPosition = 8
	
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
	
	override func createNewPort(_ portNum: UInt8, rawToolType: UInt8)
	{
		if let toolType = JBCSolderingTool.ToolType(rawValue: rawToolType)
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
	}
	
	override func receivedCommand(_ command: JBCStationCommand) -> Bool
	{
		var handled: Bool = false
		if let solderingCommand = JBCStationCommand.CommandSolder(rawValue: command.command)
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
							portNumData.append(stationPort.connectedHotAirTool()!.toolType.rawValue)
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
				if let tempResponse = try? JBCStationCommand.extractTwoByteValueAndPortFromCommonResponse(command.dataField)
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
				if let tempResponse = try? JBCStationCommand.extractTwoByteValueAndPortFromCommonResponse(command.dataField, numTemps: 2)
				{
					if let stationPort = stationPorts.first(where: { $0.id == tempResponse.port })
					{
						if let connectedTool = stationPort.connectedSolderTool()
						{
							connectedTool.tipTemp = tempResponse.temperatures[0]
							connectedTool.tipTwoTemp = tempResponse.temperatures[1]
						}
					}
				}
				else
				{
					return false
				}
			case .continuousModeUpdate:
				let numberOfPorts = (command.dataField.count - 1) / JBCSolderStation.ContinuousModePortUpdateLength
				for portNum in 0..<numberOfPorts
				{
					let fieldStartPos = 1 + portNum * JBCSolderStation.ContinuousModePortUpdateLength
					let fieldEndPos = fieldStartPos + JBCSolderStation.ContinuousModePortUpdateLength
					let subfield: Data = Data(command.dataField[fieldStartPos..<fieldEndPos])
					let utiTipTemp: UInt16 = subfield[0...1].toInteger(endian: .little)
					let utiTip2Temp: UInt16 = subfield[2...3].toInteger(endian: .little)
					let status: UInt8 = subfield[JBCSolderStation.ContinuousModePortUpdateToolStatusPosition]
					if let stationPort = stationPorts.first(where: { $0.id == portNum }),
						let connectedTool = stationPort.connectedSolderTool()
					{
						connectedTool.tipTemp = utiTipTemp
						connectedTool.tipTwoTemp = utiTip2Temp
						connectedTool.setStatus(rawResponse: status)
					}
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


extension JBCStationCommand
{
	enum CommandSolder: UInt8
	{
		case levelsTemps = 51 // 0x33
		case cartridge = 72 // 0x48
		case tipTemp = 82 // 0x52
		case mosTemp = 89 // 0x59, Not sure what this actually is
		case continuousModeUpdate = 130 // 82
		case maxTemp = 162 // 0xa2
		case minTemp = 164 // 0xa4
	}
}

extension JBCSerialPort
{
	// Convenience for passing a Solder Station command directly.
	public func formCommand(FID: UInt8? = nil, solderStationCommand: JBCStationCommand.CommandSolder, data: Data = Data(), overrideTargetAddress: UInt8? = nil) throws -> JBCStationCommand
	{
		return try formCommand(FID:FID, command: solderStationCommand.rawValue, data: data, overrideTargetAddress: overrideTargetAddress)
	}
}

extension JBCStationPort
{
	public func connectedSolderTool() -> JBCSolderingTool?
	{
		return connectedTool as? JBCSolderingTool
	}
}

