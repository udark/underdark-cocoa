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
	let dateFormatter = NSDateFormatter()
	
	override init()
	{
		super.init()
		
		//dateFormatter.dateStyle = .NoStyle
		//dateFormatter.timeStyle = .MediumStyle
		
		//[_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		//[_dateFormatter setDateFormat:@"dd.MM.yyyy HH:mm:ss:SSS"];
		
		dateFormatter.formatterBehavior = NSDateFormatterBehavior.Behavior10_4
		dateFormatter.dateFormat = "HH:mm:ss.SSS"
	}
	
	func formatLogMessage(logMessage: DDLogMessage) -> String
	{
		let level: String
		
		if(logMessage.flag.contains(DDLogFlag.Debug)) {
			level = ""
		} else if(logMessage.flag.contains(DDLogFlag.Info)) {
			level = ""
		} else if(logMessage.flag.contains(DDLogFlag.Warning)) {
			level = "WARN"
		} else if(logMessage.flag.contains(DDLogFlag.Error)) {
			level = "ERROR"
		} else {
			level = ""
		}
		
		let date = dateFormatter.stringFromDate(logMessage.timestamp)
		
		let result = "\(date) \(level)\t\(logMessage.message)"
		return result
	}
}
