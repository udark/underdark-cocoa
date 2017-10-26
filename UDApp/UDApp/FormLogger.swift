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
	func logMessage(_ message: String)
}

@objc
class FormLogger: NSObject, DDLogger
{
	fileprivate weak var delegate : FormLoggerDelegate?
	fileprivate var messages = [String]()
	
	override init()
	{
	}
	
	func updateDelegate(_ delegate: FormLoggerDelegate?)
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
	
	func appendMessage(_ message: String)
	{
		// Main thread.
		
		guard self.delegate != nil else {
			self.messages.append(message)
			return
		}
		
		self.delegate?.logMessage(message)
	}
	
	// MARK: - DDLogger
	
	var logFormatter: DDLogFormatter = LogFormatter()
	var loggerName: String = "UDApp"
	
	func log(message logMessage: DDLogMessage)
	{
		guard let message = logFormatter.format(message: logMessage) else {
			return
		}
		
		DispatchQueue.main.async {
			self.appendMessage(message)
		}
	}
}

func LogDebug(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance)
{
	_DDLogMessage(message, level: level, flag: .debug, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogInfo(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
	_DDLogMessage(message, level: level, flag: .info, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogWarn(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
	_DDLogMessage(message, level: level, flag: .warning, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogVerbose(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = true, ddlog: DDLog = DDLog.sharedInstance) {
	_DDLogMessage(message, level: level, flag: .verbose, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}

func LogError(_ message: @autoclosure () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: AnyObject? = nil, asynchronous async: Bool = false, ddlog: DDLog = DDLog.sharedInstance) {
	_DDLogMessage(message, level: level, flag: .error, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
}
