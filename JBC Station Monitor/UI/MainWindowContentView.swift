//
//  ContentView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/2/24.
//

import SwiftUI
import ORSSerial

struct MainWindowContentView: View 
{
	@Environment(SerialManager.self) var serialManager: SerialManager
	
    var body: some View
	{
		VStack
		{
			ScrollView
			{
				LazyVStack(alignment: .leading)
				{
					ForEach(serialManager.knownStations, id: \.id)
					{ jbcStation in
						JBCStationView(jbcStation: jbcStation)
							.frame(maxWidth: .infinity)
					}

					let ports : [JBCSerialPort] = serialManager.knownPorts.filter({ $0.state != .jbcToolFound })
					
					ForEach(ports, id: \.id)
					{ serialPort in
						SerialPortView(serialPort: serialPort)
							.frame(maxWidth: .infinity)
					}
				}
				.id(UUID())
			}
			.frame(maxWidth: .infinity)
			Divider()
			Text("Found \(serialManager.knownPorts.count) serial ports.")
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding()
	}
}

#Preview 
{
    MainWindowContentView()
		.environment(SerialManager())
}
