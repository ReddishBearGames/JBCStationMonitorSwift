//
//  SerialPortView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/2/24.
//

import SwiftUI
import ORSSerial

struct SerialPortView: View
{
	var serialPort: JBCSerialPort
	
    var body: some View
	{
		VStack
		{
			HStack
			{
				Text(serialPort.serialPort.name)
					.font(.headline)
				Spacer()
			}
			HStack
			{
				VStack
				{
					HStack
					{
						Text("SERIAL_VIEW_VENDOR_LABEL")
							.font(.subheadline)
						Text(serialPort.serialPort.identifiers?.vendorID.stringValue ?? "Unknown")
							.font(.subheadline)
						Spacer()
					}
					HStack
					{
						Text("SERIAL_VIEW_PRODUCT_LABEL")
							.font(.subheadline)
						Text(serialPort.serialPort.identifiers?.productID.stringValue ?? "Unknown")
							.font(.subheadline)
						Spacer()
					}
					HStack
					{
						Text("SERIAL_VIEW_STATUS_LABEL")
							.font(.subheadline)
						Text(LocalizedStringKey(serialPort.state.localizableKey))
							.font(.subheadline)
						switch serialPort.state
						{
						default:
							EmptyView()
						}
						Spacer()
					}
				}
				VStack
				{
					Spacer()
					if serialPort.state == .uninitialized
					{
						Button("BUTTON_OPEN_PORT")
						{
							Task
							{
								await serialPort.open()
							}
						}
					}
				}
			}
			
		}
		.padding()
	}
}

#Preview {
    SerialPortView(serialPort: JBCSerialPort(serialPort: ORSSerialPort(path: "/dev/cu.usbserial-31140")!))
}
