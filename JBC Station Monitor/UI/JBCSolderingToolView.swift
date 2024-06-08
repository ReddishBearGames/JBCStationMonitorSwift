//
//  JBCSolderingToolView.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/7/24.
//

import SwiftUI

struct JBCSolderingToolView: View 
{
	var jbcTool: JBCSolderingTool
	
    var body: some View
	{
		VStack(alignment: .leading)
		{
			Text("TOOL_STATUS_\(String(format: NSLocalizedString(jbcTool.toolStatus.localizableKey, comment:"")))")
		}
    }
}

#Preview {
	JBCSolderingToolView(jbcTool: JBCSolderingTool(toolType: .microDesolderingIron))
}
