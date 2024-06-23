//
//  JBCSolderingToolView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/7/24.
//

import SwiftUI

struct JBCSolderingToolView: View 
{
	@Environment(JBCSolderingTool.self) var jbcTool: JBCSolderingTool

    var body: some View
	{
		VStack(alignment: .leading)
		{
			Text("TOOL_STATUS_\(String(format: NSLocalizedString(jbcTool.toolStatus.localizableKey, comment:"")))")
			JBCSolderingCurrentTempView()
		}
    }
}

struct JBCSolderingCurrentTempView: View
{
	@Environment(JBCSolderingTool.self) var jbcTool: JBCSolderingTool
	
	var body: some View
	{
		VStack()
		{
			GroupBox(label:
						Label("CURRENT_TEMP_LABEL", systemImage: "thermometer.sun")
				.font(.title)
			)
			{
				switch jbcTool.toolType
				{
				case .microSolderingIron,
						.solderingIron,
						.microDesolderingIron,
						.desolderingIron,
						.nanoSolderingIron:
					JBCSolderingIronView()
				case .microTweezers,
						.tweezers,
						.nanoTweezers,
						.heavyDutySoldering:
					JBCSolderingTweezersView()
				default:
					EmptyView()
				}
			}
		}
		.frame(maxWidth:.infinity)
	}
	
}

struct JBCSolderingIronView: View
{
	@Environment(JBCSolderingTool.self) var jbcTool: JBCSolderingTool
	
	var body: some View
	{
		Text("CELCIUS_TEMPERATURE_DISPLAY\(UTIToCelcius(jbcTool.tipTemp))")
			.font(.largeTitle)
			.frame(maxWidth:.infinity)
	}
}

struct JBCSolderingTweezersView: View
{
	@Environment(JBCSolderingTool.self) var jbcTool: JBCSolderingTool
	
	var body: some View
	{
		HStack
		{
			Text("CELCIUS_TEMPERATURE_DISPLAY\(UTIToCelcius(jbcTool.tipTemp))")
				.font(.largeTitle)
				.frame(maxWidth:.infinity)
			Text("CELCIUS_TEMPERATURE_DISPLAY\(UTIToCelcius(jbcTool.tipTwoTemp))")
				.font(.largeTitle)
				.frame(maxWidth:.infinity)
		}
		.frame(maxWidth:.infinity)
	}
}

#Preview {
	JBCSolderingToolView()
		.environment(JBCSolderingTool(toolType: .microDesolderingIron))
}

#Preview {
	JBCSolderingToolView()
		.environment(JBCSolderingTool(toolType: .microTweezers))
}
