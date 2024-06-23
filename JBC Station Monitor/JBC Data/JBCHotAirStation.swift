//
//  JBCHotAirStation.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCHotAirStation: JBCStation
{
	var maximumAirflow: UInt16 = 1000
	var minimumAirflow: UInt16 = 10
	
	static func ModelNameIsHotAirStation(_ name: String) -> Bool
	{
		return ["JTSE"].contains(name)
	}
	
	override func createNewPort(_ portNum: UInt8, rawToolType: UInt8)
	{
		if let toolType = JBCHotairTool.ToolType(rawValue: rawToolType)
		{
			let newTool = JBCHotairTool(serialPort:self.serialPort, toolType: toolType)
			let newStationPort = JBCStationPort(serialPort:self.serialPort, id: portNum, connectedTool: newTool)
			stationPorts.append(newStationPort)
			try? self.serialPort.sendCommand(self.serialPort.formCommand(hotairStationCommand: .maxMinAirflow))
			var portNumData = Data()
			portNumData.append(portNum)
			try? self.serialPort.sendCommand(self.serialPort.formCommand(hotairStationCommand: .selectedAirflow, data:portNumData))
			try? self.serialPort.sendCommand(self.serialPort.formCommand(hotairStationCommand: .airTemp, data:portNumData))
			try? self.serialPort.sendCommand(self.serialPort.formCommand(hotairStationCommand: .power, data:portNumData))
		}
	}
	
	override init?(serialPort: JBCSerialPort,modelName: String, firmwareVersion: String, hardwareVersion: String, deviceID: String)
	{
		let modelNameParts = modelName.split(separator: "_", maxSplits: 1)
		let useModelName = String(modelNameParts[0])
		guard JBCHotAirStation.ModelNameIsHotAirStation(useModelName) else { return nil }
		super.init(serialPort: serialPort, modelName: useModelName, firmwareVersion: firmwareVersion, hardwareVersion: hardwareVersion, deviceID: deviceID)
		stationType = .hotair
	}
	
	override func receivedCommand(_ command: JBCStationCommand) -> Bool
	{
		var handled: Bool = false
		if let hotairCommand = JBCStationCommand.CommandHotair(rawValue: command.command)
		{
			handled = true
			switch hotairCommand
			{
			case .connectedTool:
				if let stationPort = stationPorts.first(where: { $0.id == command.dataField[1] }),
				   let connectedTool = stationPort.connectedHotAirTool()
				{
					connectedTool.toolType = JBCHotairTool.ToolType(rawValue: command.dataField[0]) ?? .hotair
				}
			case .selectedAirflow:
				if let flowResponse = try? JBCStationCommand.extractTwoByteValueAndPortFromCommonResponse(command.dataField)
				{
					if let stationPort: JBCStationPort = stationPorts.first(where: { $0.id == flowResponse.port }),
					   let hotairTool = stationPort.connectedHotAirTool()
					{
						hotairTool.selectedAirflow = flowResponse.temperatures[0]
					}
				}
			case .maxMinAirflow:
				if command.dataField.count == 4
				{
					maximumAirflow = command.dataField[0...1].toInteger(endian: .little)
					minimumAirflow = command.dataField[2...3].toInteger(endian: .little)
				}
			case .airTemp:
				if let tempResponse = try? JBCStationCommand.extractTwoByteValueAndPortFromCommonResponse(command.dataField)
				{
					if let stationPort = stationPorts.first(where: { $0.id == tempResponse.port }),
					   let hotairTool = stationPort.connectedHotAirTool()
					{
						hotairTool.airTemp = tempResponse.temperatures[0]
					}
				}
				else
				{
					return false
				}
			case .power:
				if let powerResponse = try? JBCStationCommand.extractTwoByteValueAndPortFromCommonResponse(command.dataField)
				{
					if let stationPort = stationPorts.first(where: { $0.id == powerResponse.port }),
					   let hotairTool = stationPort.connectedHotAirTool()
					{
						hotairTool.power = powerResponse.temperatures[0]
					}
				}
				else
				{
					return false
				}
			case .continuousModeUpdate:
				// I think there can only be 1 port?
				let portNum = 0
				if let stationPort = stationPorts.first(where: { $0.id == portNum }),
				   let hotairTool = stationPort.connectedHotAirTool()
				{
					hotairTool.setStatus(rawResponse: command.dataField[13])
					let temp: UInt16 = command.dataField[1...2].toInteger(endian: .little)
					let flow: UInt16 = command.dataField[3...4].toInteger(endian: .little)
					let power: UInt16 = command.dataField[5...6].toInteger(endian: .little)
					hotairTool.airTemp = temp
					hotairTool.airflow = flow
					hotairTool.power = power
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
	enum CommandHotair: UInt8
	{
		case airTemp = 82 // 0x52
		case power = 84 // 0x54
		case connectedTool = 85 // 0x55
		case selectedAirflow = 89 // 0x59
		case continuousModeUpdate = 130 // 82
		case maxMinAirflow = 164 // 0xa4
	}
}


extension JBCSerialPort
{
	// Convenience for passing a Hot Air Station command directly.
	public func formCommand(FID: UInt8? = nil, hotairStationCommand: JBCStationCommand.CommandHotair, data: Data = Data(), overrideTargetAddress: UInt8? = nil) throws -> JBCStationCommand
	{
		return try formCommand(FID:FID, command: hotairStationCommand.rawValue, data: data, overrideTargetAddress: overrideTargetAddress)
	}
}

extension JBCStationPort
{
	public func connectedHotAirTool() -> JBCHotairTool?
	{
		return connectedTool as? JBCHotairTool
	}
}


