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

	private var node: Node!

	//MARK: - Initialization
	
	required init?(coder aDecoder: NSCoder)
	{
		super.init(coder: aDecoder)
	}
	
	deinit
	{
		node.stop()
	}
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		self.node = AppModel.shared.node
		node.controller = self
		
		progressHeight.constant = 9
		
		for vc in self.tabBarController!.viewControllers!
		{
			let _ = vc.view
		}

		updatePeersCount()

		node.start()
	}

	override func didReceiveMemoryWarning()
	{
		super.didReceiveMemoryWarning()
	}

	func updatePeersCount()
	{
		let peersSuffix = ((AppModel.shared.node.peersCount == 1) ? "peer" : "peers")
		let linksSuffix = ((AppModel.shared.node.linksCount == 1) ? "link" : "links")

		navItem.title = "\(AppModel.shared.node.peersCount) " + peersSuffix
				+ " | \(AppModel.shared.node.linksCount) " + linksSuffix
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
		let future = UDFutureLazy(queue: bgqueue) { (context) -> NSData? in
			let data = NSMutableData(length: dataLength);
			arc4random_buf(data!.mutableBytes, data!.length)
			return data
		}
		
		/*let data = NSMutableData(length: dataLength);
		arc4random_buf(data!.mutableBytes, data!.length)
		let result = UDFutureKnown(data: data!)*/

		return UDSource(future: future)
	}
	
	func frameData2(dataLength:Int) -> UDSource
	{
		let data = NSMutableData(length: dataLength);
		arc4random_buf(data!.mutableBytes, data!.length)
		
		let future = UDFutureKnown(result: data)
		
		return UDSource(future: future)
	}
	
	@IBAction func sendFramesSmall(sender: AnyObject)
	{
		autoreleasepool { 
			node.broadcastFrame(frameData(1))
			
			node.longTransferBegin()
			
			for _ in 0 ..< 2000
			{
				node.broadcastFrame(frameData(1024));
			}
			
			node.longTransferEnd()
		}
	}
	
	@IBAction func sendFramesLarge(sender: AnyObject)
	{
		autoreleasepool { 
			node.broadcastFrame(frameData(1))
			
			node.longTransferBegin()
			
			for _ in 0 ..< 20
			{
				AppModel.shared.node.broadcastFrame(frameData(100 * 1024));
			}
			
			node.longTransferEnd()
		}
	}
	
	@IBAction func sendFramesVeryLarge(sender: AnyObject)
	{
		autoreleasepool { 
			node.broadcastFrame(frameData(1))
			
			node.longTransferBegin()
			
			for _ in 0 ..< 2
			{
				node.broadcastFrame(frameData(2 * 1024 * 1024));
			}
			
			node.longTransferEnd()			
		}
	}

	@IBAction func sendFramesGigantic(sender: AnyObject)
	{
		autoreleasepool {
			node.broadcastFrame(frameData(1))
			
			node.longTransferBegin()
			
			var frames = [UDSource]()
			
			for _ in 0 ..< 1000
			{
				autoreleasepool {
					frames.append(frameData(1024 * 1024))
				}
			}
			
			node.broadcastFrames(frames)
			
			node.longTransferEnd()
		}
	}
} // ViewController

