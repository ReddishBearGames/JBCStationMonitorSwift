//
//  JBCStationPortView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import SwiftUI

struct JBCStationPortView: View 
{
	var jbcStationPort: JBCStationPort

	var body: some View
	{
		GroupBox(label:
					Label("PORT_LABEL \(jbcStationPort.id + 1)", systemImage: "cable.connector.horizontal")
					.font(.title2)
				 )
		{
			VStack(alignment: .leading)
			{
				if let tempPresets = jbcStationPort.temperaturePresets
				{
					PortTempPresetsView(presets: tempPresets)
				}
				if jbcStationPort.connectedTool.toolType != .none
				{
					Text("TOOL_TYPE_LABEL_\(String(format: NSLocalizedString(jbcStationPort.connectedTool.toolType.localizableKey, comment:"")))")
				}
				
				if let solderingTool = jbcStationPort.connectedTool as? JBCSolderingTool
				{
					JBCSolderingToolView(jbcTool: solderingTool)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

struct PortTempPresetsView : View
{
	var presets: TemperaturePresets
	
	var body: some View
	{
		VStack()
		{
			HStack
			{
				Text("TEMPERATURE_PRESETS_LABEL")
					.font(.title3)
				if presets.useLevels == .off
				{
					Text("TEMPERATURE_PRESETS_DISABLED_LABEL")
						.font(.title3)
				}
			}
			HStack()
			{
				ForEach(presets.levels.indices, id:\.self)
				{ index in
					TemperatureLevelView(preset: presets.levels[index],chosen: presets.selectedLevel.rawValue == index)
				}
			}
			.overlay(Color.gray.opacity(presets.useLevels == .off ? 0.6 : 0.0))
		}
		.frame(maxWidth: .infinity)
		.padding(10)
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.stroke(.gray, lineWidth: 3))
	}
}

struct TemperatureLevelView: View
{
	var preset: TemperatureLevel
	var chosen: Bool

	var body: some View
	{
		if chosen
		{
			Text("\(preset.temperatureInCelsius())\u{00B0}")
				.frame(maxWidth: .infinity)
				.background(Color.orange.brightness(0.1))
		}
		else
		{
			Text("\(preset.temperatureInCelsius())\u{00B0}")
				.frame(maxWidth: .infinity)
		}
	}
}

#Preview
{
	let stationPort = JBCStationPort(id: 0, connectedTool: JBCTool(toolType: .microSolderingIron))
	let tempResponsePacket: [UInt8] = [0x0,0x0,0x01,0x4e,0x0c,0x01,0x8c,0x0a,0x01,0xca,0x08,0x00,0x01]
	let tempResponseData: Data = Data(tempResponsePacket)
	let tempPresets = TemperaturePresets(data: tempResponseData)
	stationPort.temperaturePresets = tempPresets
	return JBCStationPortView(jbcStationPort: stationPort)
}
