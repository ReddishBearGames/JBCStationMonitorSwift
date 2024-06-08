//
//  JBCStation.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

@Observable class JBCStation: Identifiable
{
	enum StationType
	{
		case soldering
		case hotair
		case unknown(String)
		
		var localizableKey: String
		{
			let keyEnd: String
			switch self
			{
			case .soldering:
				keyEnd = "SOLDERING"
			case .hotair:
				keyEnd = "HOTAIR"
			case .unknown:
				keyEnd = "UNKNOWN"
			}
			return String(format: "JBC_STATION_TYPE_%@_%%@", keyEnd)
		}
		
	}

	
	let serialPort: JBCSerialPort
	var modelName: String
	var firmwareVersion: String
	var hardwareVersion: String
	var deviceID: String
	var name: String?
	var stationType: StationType = .unknown("")
	var stationPorts = [JBCStationPort]()

	public var id: UInt32
	{
		return self.serialPort.serialPort.ioKitDevice
	}

	
	init?(serialPort: JBCSerialPort,modelName: String, firmwareVersion: String, hardwareVersion: String, deviceID: String)
	{
		self.serialPort = serialPort
		self.modelName = modelName
		self.firmwareVersion = firmwareVersion
		self.hardwareVersion = hardwareVersion
		self.deviceID = deviceID
	}
	
	static func CreateStation(serialPort: JBCSerialPort, rawFirmware:String, rawDeviceID:String) -> JBCStation?
	{
		var newStation: JBCStation? = nil
		let firmwareParts = rawFirmware.split(separator: ":")
		guard firmwareParts.count == 4 else
		{
			return nil
		}
		let modelName = String(firmwareParts[1])
		let firmwareVersion = String(firmwareParts[2])
		let hardwareVersion = String(firmwareParts[3])
		newStation = JBCSolderStation.init(serialPort: serialPort, modelName: modelName, firmwareVersion: firmwareVersion, hardwareVersion: hardwareVersion, deviceID: rawDeviceID)
		if newStation == nil
		{
			newStation = JBCHotAirStation.init(serialPort: serialPort, modelName: modelName, firmwareVersion: firmwareVersion, hardwareVersion: hardwareVersion, deviceID: rawDeviceID)
		}
		return newStation
	}

	func start()
	{
		try? self.serialPort.sendCommand(self.serialPort.formCommand(stationCommand: .stationName))
		setupPorts()
	}
	
	func setupPorts()
	{
		var portNumData: Data = Data()
		for portNum in 0...3
		{
			portNumData.removeAll()
			portNumData.append(UInt8(portNum))
			try? self.serialPort.sendCommand(self.serialPort.formCommand(stationCommand: .portInfo, data: portNumData))
		}
	}
	
	func receive(rawData:Data) -> [JBCStationCommand]
	{
		return self.serialPort.receive(rawData: rawData)
	}

	func receivedCommand(_ command: JBCStationCommand) -> Bool
	{
		var handled: Bool = false
		if let  stationCommand = JBCStationCommand.Command(rawValue: command.command)
		{
			handled = true
			switch stationCommand
			{
			case .nack:
				if command.dataField.count >= 2,
				   command.dataField[0] == JBCSerialPort.CommunicationError.outOfRange.rawValue,
				   command.dataField[1] == JBCStationCommand.Command.portInfo.rawValue
				{
					// If this NACK is an out-of-range response to a port inquiry that's OK.
				}
				else
				{
					handled = false
				}
			case .portInfo:
				guard command.dataField.count == 14 else
				{
					print("Received Portinfo response of different size than expected")
					return false
				}
				// Data payload looks like this:
				// 01,00,b4,00,00,00,00,00,00,00,04,00,00,00
				// Haven't worked out all the fields, but byte 1 is the tool type,
				// byte 2 seems to be a port error status? Byte 11 is a status of sorts, though only seems to have values for the various sleeping modes?
				// and byte 14 is the port number
				let portNum: UInt8 = command.dataField[13] // Keeping in mind they're 0-based
				if let toolType = JBCTool.ToolType(rawValue: command.dataField[0])
				{
					createNewPort(portNum, toolType: toolType)
					var portNumData: Data = Data()
					portNumData.append(portNum)
					try? self.serialPort.sendCommand(self.serialPort.formCommand(stationCommand: .toolStatus, data: portNumData))
				}
				else
				{
					print("Unknown tool type: \(command.dataField[13])")
				}
			case .toolStatus:
				guard command.dataField.count == 2 else
				{
					print("Received tool status of different size than expected")
					return false
				}
				let rawStatus = command.dataField[0]
				let portNum = command.dataField[1]
				if let stationPort = stationPorts.first(where: { $0.id == portNum })
				{
					stationPort.connectedTool.setStatus(rawResponse: rawStatus)
				}
			case .stationName:
				if command.dataField.count > 0
				{
					if let stationName = String(data:command.dataField, encoding: .ascii)
					{
						self.name = stationName
					}
				}
				else
				{
					print("Station is unnamed")
				}
			default:
				handled = false
			}
		}
		return handled
	}

	func createNewPort(_ portNum: UInt8, toolType: JBCTool.ToolType)
	{
		// Abstract, for subclasses
	}
	
}


