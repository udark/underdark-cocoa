//
//  ViewController.swift
//  UDApp
//
//  Created by Virl on 20/09/15.
//  Copyright © 2015 Underdark. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{
	let node: Node;
	
	@IBOutlet weak var peersCountLabel: UILabel!

	@IBOutlet weak var framesCountLabel: UILabel!
	
	@IBOutlet weak var sendFramesButton: UIButton!
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
	}
	
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

	@IBAction func sendFrames(sender: AnyObject)
	{
		for var i = 0; i < 100; ++i
		{
			let frameData = NSMutableData(length: 1024);
			arc4random_buf(frameData!.mutableBytes, frameData!.length)
			//SecRandomCopyBytes(kSecRandomDefault, UInt(s.length), UnsafePointer<UInt8>(s.mutableBytes))
			
			node.broadcastFrame(frameData!);
		}
	}
}

