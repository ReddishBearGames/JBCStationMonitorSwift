//
//  JBC_Station_MonitorApp.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/2/24.
//

import SwiftUI

@main
struct JBC_Station_MonitorApp: App 
{
	@State var serialManager: SerialManager = SerialManager()

	var body: some Scene
	{
        WindowGroup 
		{
			MainWindowContentView()
				.environment(serialManager)
        }
    }
}
