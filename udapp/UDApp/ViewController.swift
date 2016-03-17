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
	let node: Node;
	
	@IBOutlet weak var peersCountLabel: UILabel!

	@IBOutlet weak var framesCountLabel: UILabel!
	
	@IBOutlet weak var sendFramesButton: UIButton!
	
	//MARK: - Initialization
	
	required init?(coder aDecoder: NSCoder)
	{
		node = Node();

		super.init(coder: aDecoder)
		
		node.controller = self;
		
		node.start();
	}
	
	deinit
	{
		node.stop();
	}
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
	}

	override func didReceiveMemoryWarning()
	{
		super.didReceiveMemoryWarning()
	}

	func updatePeersCount()
	{
		peersCountLabel?.text = "\(node.peersCount) connected";
	}
	
	func updateFramesCount()
	{
		framesCountLabel?.text = "\(node.framesCount) frames";
		
	}
	
	//MARK: - Actions

	@IBAction func sendFrames(sender: AnyObject)
	{
		let dataLength = 1024;
		
		for var i = 0; i < 100; ++i
		{
			let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
			let frameData = UDLazyData(queue: queue, block: { () -> NSData? in
				let data = NSMutableData(length: dataLength);
				arc4random_buf(data!.mutableBytes, data!.length)
				//SecRandomCopyBytes(kSecRandomDefault, UInt(s.length), UnsafePointer<UInt8>(s.mutableBytes))
				
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					self.node.framesCount++
					self.updateFramesCount()
				})
				
				return data
			})
			
			/*let data = NSMutableData(length: dataLength);
			arc4random_buf(data!.mutableBytes, data!.length)
			let frameData = UDMemoryData(data: data)*/
			
			node.broadcastFrame(frameData);
		}
	}
}

