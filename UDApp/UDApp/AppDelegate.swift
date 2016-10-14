//
//  AppDelegate.swift
//  UDApp
//
//  Created by Virl on 20/09/15.
//  Copyright © 2015 Underdark. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		// Override point for customization after application launch.
		
		AppModel.shared.configure()

		//AppModel.shared.udlogger.log("app didFinishLaunchingWithOptions")

		return true
	}

	func applicationWillResignActive(application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationWillResignActive")
	}

	func applicationDidEnterBackground(application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationDidEnterBackground")
	}

	func applicationWillEnterForeground(application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationWillEnterForeground")
	}

	func applicationDidBecomeActive(application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationDidBecomeActive")
	}

	func applicationWillTerminate(application: UIApplication) {
	}
}

