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

public enum Endian
{
	case big, little
}

protocol IntegerTransform: Sequence where Element: FixedWidthInteger 
{
	func toInteger<I: FixedWidthInteger>(endian: Endian) -> I
}

extension IntegerTransform 
{
	func toInteger<I: FixedWidthInteger>(endian: Endian) -> I 
	{
		let f = { (accum: I, next: Element) in accum &<< next.bitWidth | I(next) }
		return endian == .big ? reduce(0, f) : reversed().reduce(0, f)
	}
}

extension Data: IntegerTransform {}
extension Array: IntegerTransform where Element: FixedWidthInteger {}

public extension FixedWidthInteger 
{
	var bigEndianBytes: [UInt8]
	{
		withUnsafeBytes(of: bigEndian, Array.init)
	}
	
	var littleEndianBytes: [UInt8]
	{
		withUnsafeBytes(of: littleEndian, Array.init)
	}
}
