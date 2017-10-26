//
//  LogFormatter.swift
//  UDApp
//
//  Created by Virl on 09/08/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import Foundation
import CocoaLumberjack

class LogFormatter: NSObject, DDLogFormatter
{
	let dateFormatter = DateFormatter()
	
	override init()
	{
		super.init()
		
		//dateFormatter.dateStyle = .NoStyle
		//dateFormatter.timeStyle = .MediumStyle
		
		//[_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		//[_dateFormatter setDateFormat:@"dd.MM.yyyy HH:mm:ss:SSS"];
		
		dateFormatter.formatterBehavior = DateFormatter.Behavior.behavior10_4
		dateFormatter.dateFormat = "HH:mm:ss.SSS"
	}
	
	/**
	* Formatters may optionally be added to any logger.
	* This allows for increased flexibility in the logging environment.
	* For example, log messages for log files may be formatted differently than log messages for the console.
	*
	* For more information about formatters, see the "Custom Formatters" page:
	* Documentation/CustomFormatters.md
	*
	* The formatter may also optionally filter the log message by returning nil,
	* in which case the logger will not log the message.
	**/
	func format(message logMessage: DDLogMessage) -> String?
	{
		let level: String
		
		if(logMessage.flag.contains(DDLogFlag.debug)) {
			level = ""
		} else if(logMessage.flag.contains(DDLogFlag.info)) {
			level = ""
		} else if(logMessage.flag.contains(DDLogFlag.warning)) {
			level = "WARN"
		} else if(logMessage.flag.contains(DDLogFlag.error)) {
			level = "ERROR"
		} else {
			level = ""
		}
		
		let date = dateFormatter.string(from: logMessage.timestamp)
		
		let result = "\(date) \(level)\t\(logMessage.message)"
		return result
	}
}
