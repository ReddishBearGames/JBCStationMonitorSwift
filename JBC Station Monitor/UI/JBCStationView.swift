//
//  JBCStationView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import SwiftUI
import ORSSerial

struct JBCStationView: View 
{
	var jbcStation: JBCStation

    var body: some View
	{
		VStack(alignment: .leading)
		{
			Text(verbatim: String(format: NSLocalizedString(jbcStation.stationType.localizableKey, comment:""),jbcStation.modelName))
				.font(.largeTitle)
			Divider()
			HStack
			{
				VStack(alignment: .trailing)
				{
					Text("STATION_CONNECTEDON_LABEL_\(jbcStation.serialPort.serialPort.name)")
					if let stationName = jbcStation.name
					{
						Text("STATION_NAME_LABEL_\(stationName)")
					}
					else
					{
						Text("STATION_UNNAMED_LABEL")
					}
					Text("STATION_FIRMWARE_LABEL_\(jbcStation.firmwareVersion)")
					Text("STATION_HARDWARE_LABEL_\(jbcStation.hardwareVersion)")
					Text("STATION_DEVICEID_LABEL_\(jbcStation.deviceID)")
					Spacer()
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				
				
				VStack
				{
					ForEach(jbcStation.stationPorts, id: \.id)
					{ jbcStationPort in
						JBCStationPortView(jbcStationPort: jbcStationPort)
							.frame(maxWidth: .infinity)
					}
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview 
{
	JBCStationView(jbcStation: JBCSolderStation(serialPort: JBCSerialPort(serialPort: ORSSerialPort(path: "/dev/cu.usbserial-0001")!),
																		  modelName: "DDE_Whatever",
																		  firmwareVersion: "1234",
																		  hardwareVersion: "4321",
																			deviceID: "ABCD")!)
}
