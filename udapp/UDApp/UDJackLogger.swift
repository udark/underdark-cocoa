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
class UDJackLogger: NSObject, UDLogger {
	
	override init()
	{
	}
	
    func log(asynchronous: Bool, level: UDLogLevel, flag: UDLogFlag, context: Int, file: UnsafePointer<Int8>, function: UnsafePointer<Int8>, line: UInt, tag: AnyObject!, message: String!)
	{
		DDLog.log(asynchronous, message: message, level:  DDLogLevel(rawValue: level.rawValue)!, flag: DDLogFlag(rawValue: flag.rawValue), context: context, file: file, function: function, line: line, tag: tag)

	}
}