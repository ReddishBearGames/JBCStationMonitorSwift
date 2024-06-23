//
//  JBCTool.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/7/24.
//

import Foundation


@Observable class JBCTool: Identifiable
{
	let serialPort: JBCSerialPort?
	
	init(serialPort: JBCSerialPort? = nil)
	{
		self.serialPort = serialPort
	}
	
	func setStatus(rawResponse: UInt8)
	{
		// Abstract
	}
}

@Observable class JBCSolderingTool: JBCTool
{
	enum ToolType : UInt8
	{
		case none = 0
		case microSolderingIron = 1 // T210
		case solderingIron = 2 // T245
		case microTweezers = 3 // PA120
		case tweezers = 4 // HT420
		case microDesolderingIron = 5 // DS360
		case desolderingIron  = 6 // DR560
		case nanoSolderingIron = 7 // NT105 - Discontinued, unclear what the replacement is?
		case nanoTweezers = 8 // Very unsure this is right
		case heavyDutySoldering = 9 // T470
		
		var localizableKey: String
		{
			let keyEnd: String
			switch self
			{
			case .none:
				keyEnd = "NONE"
			case .microSolderingIron:
				keyEnd = "MICROSOLDERING"
			case .solderingIron:
				keyEnd = "SOLDERING"
			case .microTweezers:
				keyEnd = "MICROTWEEZERS"
			case .tweezers:
				keyEnd = "TWEEZERS"
			case .microDesolderingIron:
				keyEnd = "MICRODESOLDERING"
			case .desolderingIron:
				keyEnd = "DESOLDERING"
			case .nanoSolderingIron:
				keyEnd = "NANOSOLDERING"
			case .nanoTweezers:
				keyEnd = "NANOTWEEZERS"
			case .heavyDutySoldering:
				keyEnd = "HEAVYSOLDERING"
			}
			return String(format: "JBC_TOOL_TYPE_%@", keyEnd)
		}
		
	}
	
	public enum ToolStatus: UInt8
	{
		case unknown = 255
		case desolder = 16 // Not entirely sure what this means
		case extractor = 8 // Or this
		case hibernatiom = 4
		case sleep = 2
		case stand = 1
		case operating = 0 // I think?
		
		var localizableKey: String
		{
			let keyEnd: String
			switch self
			{
			case .unknown:
				keyEnd = "UNKNOWN"
			case .desolder:
				keyEnd = "DESOLDERING"
			case .extractor:
				keyEnd = "EXTRACTOR"
			case .hibernatiom:
				keyEnd = "HIBERNATION"
			case .sleep:
				keyEnd = "SLEEP"
			case .stand:
				keyEnd = "STAND"
			case .operating:
				keyEnd = "OPERATING"
			}
			return String(format: "JBC_SOLDERING_TOOL_STATUS_%@", keyEnd)
		}

	}

	var toolType: ToolType
	var toolStatus: ToolStatus = .unknown
	var tipTemp: UInt16 = 0
	var tipTwoTemp: UInt16 = 0

	init(serialPort: JBCSerialPort? = nil,toolType: ToolType)
	{
		self.toolType = toolType
		super.init(serialPort: serialPort)
	}
	
	override func setStatus(rawResponse: UInt8)
	{
		toolStatus = ToolStatus(rawValue: rawResponse) ?? .unknown
	}
}

@Observable class JBCHotairTool: JBCTool
{
	enum ToolType : UInt8
	{
		case none = 0
		case hotair = 1 // JT-series?
		case precisionHotair = 2 // TET series?
		case PHS = 3 // No clue
		case PHB = 4 // Also no clue
		
		var localizableKey: String
		{
			let keyEnd: String
			switch self
			{
			case .none:
				keyEnd = "NONE"
			case .hotair:
				keyEnd = "HOTAIR"
			case .precisionHotair:
				keyEnd = "PRECISIONHOTAIR"
			case .PHS:
				keyEnd = "PHS"
			case .PHB:
				keyEnd = "PHB"
			}
			return String(format: "JBC_TOOL_TYPE_%@", keyEnd)
		}
	}
	
	public struct ToolStatus: OptionSet
	{
		let rawValue: UInt8
		
		static let  unknown = 255
		static let stand = ToolStatus(rawValue: 128)
		static let pedalPressed = ToolStatus(rawValue:64)
		static let pedalConnected = ToolStatus(rawValue:32)
		static let suctionRequested = ToolStatus(rawValue:16)
		static let suction = ToolStatus(rawValue:8)
		static let cooling = ToolStatus(rawValue:4)
		static let heaterRequested = ToolStatus(rawValue:2)
		static let heater = ToolStatus(rawValue:1)
		static let none = ToolStatus([]) // ?
		
		var localizableKeys: [String]
		{
			let keyFormat = "JBC_HOTAIR_TOOL_STATUS_%@"
			var keys = [String]()
			if self.contains(.stand)
			{
				keys.append(String(format:keyFormat,"STAND"))
			}
			if self.contains(.pedalConnected)
			{
				keys.append(String(format:keyFormat,"PEDALCONNECTED"))
			}
			if self.contains(.pedalPressed)
			{
				keys.append(String(format:keyFormat,"PEDALPRESSED"))
			}
			if self.contains(.suctionRequested)
			{
				keys.append(String(format:keyFormat,"SUCTIONREQUESTED"))
			}
			if self.contains(.suction)
			{
				keys.append(String(format:keyFormat,"SUCTION"))
			}
			if self.contains(.cooling)
			{
				keys.append(String(format:keyFormat,"COOLING"))
			}
			if self.contains(.heaterRequested)
			{
				keys.append(String(format:keyFormat,"HEATERREQ"))
			}
			if self.contains(.heater)
			{
				keys.append(String(format:keyFormat,"HEATER"))
			}

			return keys
		}

	}
	
	var toolType: ToolType
	var toolStatus: ToolStatus = []
	var selectedAirflow: UInt16 = 500
	var airflow: UInt16 = 0
	var airTemp: UInt16 = 0
	var power: UInt16 = 0
	
	init(serialPort: JBCSerialPort? = nil,toolType: ToolType)
	{
		self.toolType = toolType
		super.init(serialPort: serialPort)
	}
	
	override func setStatus(rawResponse: UInt8)
	{
		toolStatus = ToolStatus(rawValue: rawResponse)
	}
}

