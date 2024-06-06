//
//  Utils.swift
//  JBC Station Monitor
//
//  Created by Chris Backas on 6/5/24.
//

import Foundation

func withContinousObservation<T>(of value: @escaping @autoclosure () -> T, execute: @escaping (T) -> Void) 
{
	withObservationTracking 
	{
		execute(value())
	}
	onChange:
	{
		Task { @MainActor in
			withContinousObservation(of: value(), execute: execute)
		}
	}
}
