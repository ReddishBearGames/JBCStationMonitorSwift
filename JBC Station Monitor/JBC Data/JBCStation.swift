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
		setupPorts()
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

	func setupPorts()
	{
		var portNum: Data = Data()
		portNum.append(UInt8(1))
		try? self.serialPort.sendCommand(self.serialPort.formCommand(command: .portInfo, data: portNum))
	}
	
	func receive(rawData:Data) -> JBCStationCommand?
	{
		return self.serialPort.receive(rawData: rawData)
	}

	func receivedCommand(_ command: JBCStationCommand) -> Bool
	{
		return false
	}
	
}
