//
//  UnderdarkLogger.swift
//  UDApp
//
//  Created by Virl on 23/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import Foundation

import CocoaLumberjack
import Underdark

@objc
class UDJackLogger: NSObject, UDLogger
{
	override init()
	{
	}

	func log(
		_ asynchronous: Bool,
		level: UDLogLevel,
		flag: UDLogFlag,
		context: Int,
		file: UnsafePointer<Int8>!,
		function: UnsafePointer<Int8>!,
		line: UInt,
		tag: Any?,
		message: String)
	{
		// Any thread.

		withVaList([message]) { pointer in
			DDLog.log(
					asynchronous: asynchronous,
					level: DDLogLevel(rawValue: level.rawValue) ?? DDLogLevel.info,
					flag: DDLogFlag(rawValue: flag.rawValue),
					context: context,
					file: file,
					function: function,
					line: line,
					tag: tag,
					format: "%@",
					arguments: pointer
					)
		}
	} // log
}
