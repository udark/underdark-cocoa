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


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		AppModel.shared.configure()

		//AppModel.shared.udlogger.log("app didFinishLaunchingWithOptions")

		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationWillResignActive")
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationDidEnterBackground")
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationWillEnterForeground")
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		//AppModel.shared.udlogger.log("app applicationDidBecomeActive")
	}

	func applicationWillTerminate(_ application: UIApplication) {
	}
}

