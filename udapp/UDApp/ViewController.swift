//
//  ViewController.swift
//  UDApp
//
//  Created by Virl on 20/09/15.
//  Copyright © 2015 Underdark. All rights reserved.
//

import UIKit

import Underdark;

class ViewController: UIViewController
{
	@IBOutlet weak var navItem: UINavigationItem!

	@IBOutlet weak var framesCountLabel: UILabel!
	@IBOutlet weak var timeLabel: UILabel!
	@IBOutlet weak var speedLabel: UILabel!
	
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var progressHeight: NSLayoutConstraint!
	
	//MARK: - Initialization
	
	required init?(coder aDecoder: NSCoder)
	{
		super.init(coder: aDecoder)
		
		AppModel.shared.node.controller = self;
	}
	
	deinit
	{
		AppModel.shared.node.stop()
	}
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		progressHeight.constant = 9
		
		for vc in self.tabBarController!.viewControllers!
		{
			let _ = vc.view
		}
		
		AppModel.shared.node.start()
	}

	override func didReceiveMemoryWarning()
	{
		super.didReceiveMemoryWarning()
	}

	func updatePeersCount()
	{
		navItem.title = "\(AppModel.shared.node.peersCount)" + ((AppModel.shared.node.peersCount == 1) ? " peer" : " peers");
	}
	
	func updateFramesCount()
	{
		framesCountLabel.text = "\(AppModel.shared.node.framesCount) frames";
		
		let timeval = AppModel.shared.node.timeEnd - AppModel.shared.node.timeStart
		timeLabel.text = NSString(format: "%.2f seconds", timeval) as String
		
		let speed = Int( Double(AppModel.shared.node.bytesCount) / (AppModel.shared.node.timeEnd - AppModel.shared.node.timeStart + 0.0001) )
		speedLabel.text = "\(speed / 1024) kb/sec"
	}
	
	//MARK: - Actions

	let bgqueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
	
	func frameData(dataLength:Int) -> UDSource
	{
		let result = UDLazySource(queue: bgqueue, block: { () -> NSData? in
			let data = NSMutableData(length: dataLength);
			arc4random_buf(data!.mutableBytes, data!.length)
			//SecRandomCopyBytes(kSecRandomDefault, UInt(s.length), UnsafePointer<UInt8>(s.mutableBytes))
			
			return data
		})
		
		/*let data = NSMutableData(length: dataLength);
		arc4random_buf(data!.mutableBytes, data!.length)
		let result = UDMemorySource(data: data!)*/
		
		return result
	}
	
	@IBAction func sendFramesSmall(sender: AnyObject)
	{
		AppModel.shared.node.broadcastFrame(frameData(1))
		
		for _ in 0 ..< 2000
		{
			AppModel.shared.node.broadcastFrame(frameData(1024));
		}
	}
	
	@IBAction func sendFramesLarge(sender: AnyObject)
	{
		AppModel.shared.node.broadcastFrame(frameData(1))

		for _ in 0 ..< 20
		{
			AppModel.shared.node.broadcastFrame(frameData(100 * 1024));
		}
	}
} // ViewController

