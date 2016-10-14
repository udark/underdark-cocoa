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
		    asynchronous: Bool,
		    level: UDLogLevel,
		    flag: UDLogFlag,
		    context: Int,
		    file: UnsafePointer<Int8>,
		    function: UnsafePointer<Int8>,
		    line: UInt,
		    tag: AnyObject?,
		    message: String
    )
	{
		// Any thread.

		withVaList([message]) { pointer in
			DDLog.log(
					asynchronous,
					level: DDLogLevel(rawValue: level.rawValue) ?? DDLogLevel.Info,
					flag: DDLogFlag(rawValue: flag.rawValue) ?? DDLogFlag.Info,
					context: context,
					file: file,
					function: function,
					line: line,
					tag: tag,
					format: "%@",
					args: pointer
					)
		}
	} // log
}
