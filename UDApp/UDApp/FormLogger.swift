//
//  UILogger.swift
//  UDApp
//
//  Created by Virl on 09/08/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import Foundation

import CocoaLumberjack

protocol FormLoggerDelegate : class {
	func logMessage(message: String)
}

@objc
class FormLogger: NSObject, DDLogger
{
	private weak var delegate : FormLoggerDelegate?
	private var messages = [String]()
	
	override init()
	{
	}
	
	func updateDelegate(delegate: FormLoggerDelegate?)
	{
		// Main thread.
		
		self.delegate = delegate
		
		guard delegate != nil else {
			return
		}
		
		for message in messages {
			self.delegate?.logMessage(message)
		}
		
		messages.removeAll()
	}
	
	func appendMessage(message: String)
	{
		// Main thread.
		
		guard self.delegate != nil else {
			self.messages.append(message)
			return
		}
		
		self.delegate?.logMessage(message)
	}
	
	// MARK: - DDLogger
	
	var logFormatter: DDLogFormatter!
	var loggerName: String = "UDApp"
	
	func logMessage(logMessage: DDLogMessage)
	{
		let message: String
		
		if(logFormatter == nil) {
			message = logMessage.message
		} else {
			message = logFormatter.formatLogMessage(logMessage)
		}
		
		dispatch_async(dispatch_get_main_queue()) {
			self.appendMessage(message)
		}
	}
}

func LogDebug(@autoclosure message: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance())
{
	_DDLogMessage(message, level: level, flag: .Debug, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogInfo(@autoclosure message: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance()) {
	_DDLogMessage(message, level: level, flag: .Info, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogWarn(@autoclosure message: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance()) {
	_DDLogMessage(message, level: level, flag: .Warning, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogVerbose(@autoclosure message: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance()) {
	_DDLogMessage(message, level: level, flag: .Verbose, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogError(@autoclosure message: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = false, ddlog: DDLog = DDLog.sharedInstance()) {
	_DDLogMessage(message, level: level, flag: .Error, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}
