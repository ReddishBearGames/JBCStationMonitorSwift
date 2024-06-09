//
//  TemperaturePresetLevels.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/8/24.
//

import Foundation

struct TemperatureLevel: Hashable
{
	var onOff: TemperaturePresets.OnOff = .off
	var temperature: UInt16 = 0 // "UTI"
	
	init?(data: Data)
	{
		guard data.count == 3,
			let onOff = TemperaturePresets.OnOff(rawValue:data[0])
		else { return nil }
		self.onOff = onOff

		let u16: UInt16 = data[1...2].toInteger(endian: .little)
		self.temperature = u16
	}
	
	func encode() -> Data
	{
		var data: Data = Data()
		data.append(onOff.rawValue)
		data.append(contentsOf: temperature.littleEndianBytes)
		return data
	}
	
}

struct TemperaturePresets
{
	// Why an enum at all for what's really a bool? Just for convenience of
	// encode/decode really.
	enum OnOff: UInt8
	{
		case off = 0
		case on = 1
	}
	
	enum SelectedLevel: UInt8
	{
		case one = 0
		case two = 1
		case three = 2
	}
	
	var useLevels: OnOff = .off
	var selectedLevel: SelectedLevel = .one
	var levels: [TemperatureLevel]
	
	init?(data: Data)
	{
		guard data.count == 13,
			  let useLevels = OnOff(rawValue: data[0]),
			  let selectedLevel = SelectedLevel(rawValue: data[1])
		else { return nil }
		
		self.useLevels = useLevels
		self.selectedLevel = selectedLevel
		var levels = [TemperatureLevel]()
		for levelIndex in 0...2
		{
			let levelData = Data(data[(2+levelIndex*3)...(4+levelIndex*3)])
			guard let oneTempLevel = TemperatureLevel.init(data: levelData) else { return nil }
			levels.append(oneTempLevel)
		}
		self.levels = levels
	}
	
	func encode() -> Data
	{
		var data: Data = Data()
		data.append(self.useLevels.rawValue)
		data.append(self.selectedLevel.rawValue)
		for oneTempLevel: TemperatureLevel in levels
		{
			data.append(oneTempLevel.encode())
		}
		return data
	}
}
