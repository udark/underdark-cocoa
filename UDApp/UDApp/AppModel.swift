//
//  AppModel.swift
//  UDApp
//
//  Created by Virl on 23/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import Foundation

import CocoaLumberjack
import XCDLumberjackNSLogger
import Underdark

class AppModel
{
	static let shared = AppModel()
	
	var node: Node!
	var formLogger = FormLogger()
	
	init()
	{
		
	}

	func configure()
	{
		configureLogging()
		
		node = Node()
	}
	
	func configureLogging()
	{
		DDTTYLogger.sharedInstance.logFormatter = LogFormatter()
		DDLog.add(DDTTYLogger.sharedInstance)
		
		let xcdlogger = XCDLumberjackNSLogger(bonjourServiceName: "solidlog")
		LoggerSetViewerHost(xcdlogger.logger, "192.168.4.148" as CFString, 50000)
		DDLog.add(xcdlogger)
		
		formLogger.logFormatter = LogFormatter()
		DDLog.add(formLogger)

		UDUnderdark.setLogger(UDJackLogger())
	}
} // AppModel
