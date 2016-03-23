//
//  AppModel.swift
//  UDApp
//
//  Created by Virl on 23/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

import Foundation

import CocoaLumberjack
import Underdark

class AppModel
{
	static let shared = AppModel()
	
	let node: Node
	var udlogger = UDJackLogger()
	
	init() {
		UDUnderdark.setLogger(udlogger)
		DDLog.addLogger(DDTTYLogger.sharedInstance())
		
		node = Node();
	}
	
	deinit
	{
	}
	
	func configure()
	{
	}
} // AppModel