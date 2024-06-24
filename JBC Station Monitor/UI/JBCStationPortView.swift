//
//  JBCStationPortView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import SwiftUI
import ORSSerial

struct JBCStationPortView: View 
{
	@Environment(JBCStation.self) var jbcStation: JBCStation
	@Environment(JBCStationPort.self) var jbcStationPort: JBCStationPort

	var body: some View
	{
		GroupBox(label:
					Label("PORT_LABEL \(jbcStationPort.id + 1)", systemImage: "cable.connector.horizontal")
					.font(.title2)
				 )
		{
			VStack(alignment: .leading)
			{
				if let solderingTool = jbcStationPort.connectedTool as? JBCSolderingTool,
					let solderStation = jbcStation as? JBCSolderStation
				{
					JBCSolderingPortView()
						.environment(solderingTool)
						.environment(solderStation)
				}
				else if let hotairTool = jbcStationPort.connectedTool as? JBCHotairTool,
						let hotairStation = jbcStation as? JBCHotAirStation
				{
					JBCHotairPortView()
						.environment(hotairTool)
						.environment(hotairStation)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

struct JBCSolderingPortView : View 
{
	@Environment(JBCStationPort.self) var jbcStationPort: JBCStationPort
	@Environment(JBCSolderingTool.self) var jbcTool: JBCSolderingTool
	
	var body: some View
	{
		if let tempPresets = jbcStationPort.temperaturePresets
		{
			if tempPresets.useLevels == .off
			{
				Text("SET_TEMPERATURE_LABEL_\(UTIToCelcius(jbcStationPort.selectedTemperature))")
					.font(.title3)
			}
			PortTempPresetsView(presets: tempPresets)
		}
		else
		{
			Text("SET_TEMPERATURE_LABEL_\(UTIToCelcius(jbcStationPort.selectedTemperature))")
				.font(.title3)
		}
		JBCSolderingToolView()
	}
}

struct JBCHotairPortView : View
{
	@Environment(JBCHotAirStation.self) var jbcStation: JBCHotAirStation
	@Environment(JBCStationPort.self) var jbcStationPort: JBCStationPort
	@Environment(JBCHotairTool.self) var jbcTool: JBCHotairTool
	
	var body: some View
	{
		HStack
		{
			Text("SET_TEMPERATURE_LABEL_\(UTIToCelcius(jbcStationPort.selectedTemperature))")
				.font(.title3)
				.frame(maxWidth:.infinity)
			Text("SET_AIRFLOW_LABEL_\((Double(jbcTool.selectedAirflow) / Double(jbcStation.maximumAirflow)) * 100.0)")
				.font(.title3)
				.frame(maxWidth:.infinity)
		}
		.frame(maxWidth:.infinity)
		JBCHotairToolView()
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
			Text("CELCIUS_TEMPERATURE_DISPLAY\(UTIToCelcius(preset.temperature))")
				.frame(maxWidth: .infinity)
				.background(Color.orange.brightness(0.1))
		}
		else
		{
			Text("CELCIUS_TEMPERATURE_DISPLAY\(UTIToCelcius(preset.temperature))")
				.frame(maxWidth: .infinity)
		}
	}
}

#Preview
{
	let station = JBCSolderStation(serialPort: JBCSerialPort(serialPort: ORSSerialPort(path: "/dev/cu.usbserial-0001")!),
															 modelName: "DDE", firmwareVersion: "1234", hardwareVersion: "1234", deviceID: "ABCD")!
	let stationPort = JBCStationPort(id: 0, connectedTool: JBCSolderingTool(toolType: .solderingIron))
	let tempResponsePacket: [UInt8] = [0x0,0x0,0x01,0x4e,0x0c,0x01,0x8c,0x0a,0x01,0xca,0x08,0x00,0x01]
	let tempResponseData: Data = Data(tempResponsePacket)
	let tempPresets = TemperaturePresets(data: tempResponseData)
	stationPort.temperaturePresets = tempPresets
	return JBCStationPortView()
		.environment(station)
		.environment(stationPort)
}

#Preview
{
	let station = JBCHotAirStation(serialPort: JBCSerialPort(serialPort: ORSSerialPort(path: "/dev/cu.usbserial-0001")!),
								   modelName: "JTSE", firmwareVersion: "1234", hardwareVersion: "1234", deviceID: "ABCD")!
	let stationPort = JBCStationPort(id: 0, connectedTool: JBCHotairTool(toolType: .hotair))
	return JBCStationPortView()
		.environment(station)
		.environment(stationPort)
}
