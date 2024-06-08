//
//  JBCTool.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/7/24.
//

import Foundation


@Observable class JBCTool: Identifiable
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
		case hotair = 31 // JT-series?
		case precisionHotair = 32 // TET series?
		case PHS = 33 // No clue
		case PHB = 34 // Also no clue
		
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


	let serialPort: JBCSerialPort?
	var toolType: ToolType = .none
	
	init(serialPort: JBCSerialPort? = nil,toolType: ToolType)
	{
		self.serialPort = serialPort
		self.toolType = toolType
	}
	
	func setStatus(rawResponse: UInt8)
	{
		// Abstract
	}
}

@Observable class JBCSolderingTool: JBCTool
{
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


	var toolStatus: ToolStatus = .unknown
	
	override init(serialPort: JBCSerialPort? = nil,toolType: ToolType)
	{
		super.init(serialPort: serialPort, toolType: toolType)
	}
	
	override func setStatus(rawResponse: UInt8)
	{
		toolStatus = ToolStatus(rawValue: rawResponse) ?? .unknown
	}
}

@Observable class JBCHotairTool: JBCTool
{
	public enum ToolStatus: UInt8
	{
		case unknown = 255
		case stand = 128
		case pedalPressed = 64
		case pedalConnected = 32
		case suctionRequested = 16
		case suction = 8
		case cooling = 4
		case heaterRequested = 2
		case heater = 1
		case none = 0 // ?
	}
	
	
	var toolStatus: ToolStatus = .unknown
	
	override init(serialPort: JBCSerialPort? = nil,toolType: ToolType)
	{
		super.init(serialPort: serialPort, toolType: toolType)
	}
	
	override func setStatus(rawResponse: UInt8)
	{
		toolStatus = ToolStatus(rawValue: rawResponse) ?? .unknown
	}
}

