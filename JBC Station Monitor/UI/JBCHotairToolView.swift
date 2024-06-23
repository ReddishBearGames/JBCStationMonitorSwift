//
//  JBCHotairToolView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/14/24.
//

import SwiftUI
import ORSSerial

struct JBCHotairToolView: View
{
	@Environment(JBCHotAirStation.self) var jbcStation: JBCHotAirStation
	@Environment(JBCHotairTool.self) var jbcTool: JBCHotairTool
	
	var body: some View
	{
		GroupBox(label:
					Text("STATUS_LABEL")
			.font(.title)
		)
		{
			VStack(alignment: .leading)
			{
				if jbcTool.toolStatus == []
				{
					Text("JBC_HOTAIR_TOOL_STATUS_IDLE")
						.font(.largeTitle)
				}
				else
				{
					Text("TOOL_STATUS_\(String(jbcTool.toolStatus.localizableKeys.map( { NSLocalizedString($0, comment:"") }).joined(separator: ", ")))")
						.font(.largeTitle)
				}
				ProgressView(value: Double(jbcTool.power) / 1000.0)
				{
					Label("POWER_LABEL_\(Double(jbcTool.power) / 10.0)",systemImage: "bolt.circle")
						.font(.title3)
				}
				if !jbcTool.toolStatus.contains(.stand)
				{
					HStack()
					{
						Label("AIRTEMP_LABEL_\(UTIToCelcius(jbcTool.airTemp))",systemImage: "thermometer.sun")
							.font(.title2)
							.frame(maxWidth:.infinity)
						Label("AIRFLOW_LABEL_\((Double(jbcTool.airflow) / Double(jbcStation.maximumAirflow)) * 100.0)",systemImage: "wind")
							.font(.title2)
							.frame(maxWidth:.infinity)
					}
					.frame(maxWidth:.infinity)
				}
			}
		}
	}
}

#Preview 
{
	let station = JBCHotAirStation(serialPort: JBCSerialPort(serialPort: ORSSerialPort(path: "/dev/cu.usbserial-0001")!),
								   modelName: "JTSE", firmwareVersion: "1234", hardwareVersion: "1234", deviceID: "ABCD")!

	return JBCHotairToolView()
		.environment(station)
		.environment(JBCHotairTool(toolType: .hotair))
}
