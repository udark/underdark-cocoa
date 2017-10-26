//
//  Node.swift
//  UDApp
//
//  Created by Virl on 20/09/15.
//  Copyright © 2015 Underdark. All rights reserved.
//

import UIKit

import Underdark;

class Node: NSObject, UDTransportDelegate
{
	let appId: Int32 = 234235
	let nodeId: Int64
	let queue = DispatchQueue.main
	var transport: UDTransport
	
	var peers = [String:[UDLink]]()   // nodeId to links to it.
	
	weak var controller: ViewController?
	
	var peersCount = 0
	var linksCount = 0
	var framesCount = 0
	
	var bytesCount = 0
	var timeStart : TimeInterval = 0
	var timeEnd : TimeInterval = 0
	
	override init()
	{
		var buf : Int64 = 0
		repeat
		{
			arc4random_buf(&buf, MemoryLayout.size(ofValue: buf))
		} while buf == 0

		if(buf < 0) {
			buf = -buf;
		}

		nodeId = buf;

		let transportKinds = [UDTransportKind.wifi.rawValue, UDTransportKind.bluetooth.rawValue]
		//let transportKinds = [UDTransportKind.Wifi.rawValue];
		//let transportKinds = [UDTransportKind.Bluetooth.rawValue];
		
		transport = UDUnderdark.configureTransport(withAppId: appId, nodeId: nodeId, queue: queue, kinds: transportKinds)

		super.init()

		transport.delegate = self
	}
	
	func start()
	{
		controller?.updateFramesCount()
		controller?.updatePeersCount()
		
		transport.start()
	}
	
	func stop()
	{
		transport.stop()
		
		framesCount = 0
		controller?.updateFramesCount()
	}
	
	func broadcastFrame(_ frameData: UDSource<NSData>)
	{
		if(peers.isEmpty) { return; }
		
		controller?.updateFramesCount()

		for links in peers.values
		{
			guard let link = links.first else {
				continue
			}

			link.sendFrame(with: frameData as! UDSource<AnyObject>)
		}
	}
	
	func broadcastFrames(_ sources: [UDSource<NSData>])
	{
		for source in sources
		{
			broadcastFrame(source)
		}
	}

	func longTransferBegin() {
		for links in peers.values {
			for link in links {
				link.longTransferBegin()
			}
		}
	}

	func longTransferEnd() {
		for links in peers.values {
			for link in links {
				link.longTransferEnd()
			}
		}
	}
	
	// MARK: - UDTransportDelegate
	
	func transport(_ transport: UDTransport, linkConnected link: UDLink)
	{
		if(peers[String(link.nodeId)] == nil) {
			peers[String(link.nodeId)] = [UDLink]()
			peersCount += 1
		}

		var links: [UDLink] = peers[String(link.nodeId)]!
		links.append(link)
		links.sort { (link1, link2) -> Bool in
			return link1.priority < link2.priority
		}

		peers[String(link.nodeId)] = links
		linksCount += 1

		controller?.updatePeersCount();
	}
	
	func transport(_ transport: UDTransport, linkDisconnected link: UDLink)
	{
		guard var links = peers[String(link.nodeId)] else {
			return
		}

		links = links.filter() { $0 !== link }

		if(links.isEmpty) {
			peers.removeValue(forKey: String(link.nodeId))
			peersCount -= 1
		} else {
			peers[String(link.nodeId)] = links
		}

		linksCount -= 1
		controller?.updatePeersCount();
	}
	
	func transport(_ transport: UDTransport, link: UDLink, didReceiveFrame data: Data)
	{
		if(data.count == 1) {
			framesCount = 0
			bytesCount = 0
			timeStart = Date.timeIntervalSinceReferenceDate
			timeEnd = Date.timeIntervalSinceReferenceDate
		}
		else {
			framesCount += 1
			bytesCount += data.count
			timeEnd = Date.timeIntervalSinceReferenceDate
		}
		
		controller?.updateFramesCount();
	}
}
