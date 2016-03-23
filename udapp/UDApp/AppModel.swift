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
	
	init() {
		node = Node();
	}
	
	deinit
	{
		node.stop()
	}
	
	func configure()
	{
		DDLog.addLogger(DDTTYLogger.sharedInstance())
		UDUnderdark.setLogger(UDJackLogger())
		
		node.start()
	}
} // AppModel