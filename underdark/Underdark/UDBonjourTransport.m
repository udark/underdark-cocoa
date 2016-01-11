/*
 * Copyright (c) 2016 Vladimir L. Shabanov <virlof@gmail.com>
 *
 * Licensed under the Underdark License, Version 1.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://underdark.io/LICENSE.txt
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "UDBonjourTransport.h"

@import UIKit;

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDTimeExtender.h"
#import "UDBonjourLink.h"
#import "UDBtBeacon.h"
#import "UDBtReach.h"
#import "UDWifiReach.h"
#import "UDBonjourBrowser.h"
#import "UDBonjourServer.h"

// Error codes: https://developer.apple.com/library/mac/documentation/Networking/Reference/CFNetworkErrors/index.html#//apple_ref/c/tdef/CFNetworkErrors

@interface UDBonjourTransport () <UDReachDelegate, UDSuspendListener>
{
	bool _running;
	bool _suspended;
	NSString* _serviceType;
	
	UDTimeExtender* _timeExtender;
	
	__weak id<UDTransportDelegate> _delegate;
	NSMutableArray* _linksConnecting;
	NSMutableArray* _links;
	NSMutableArray* _linksTerminating;
	
	UDBtBeacon* _beacon;
	UDBtReach* _btReach;
	UDWifiReach* _wifiReach;
	UDBonjourBrowser* _browser;
	UDBonjourServer* _server;
}

@end

@implementation UDBonjourTransport

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithAppId:(int32_t)appId
						nodeId:(int64_t)nodeId
					   delegate:(id<UDTransportDelegate>)delegate
						  queue:(dispatch_queue_t)queue
					 peerToPeer:(bool)peerToPeer
{
	if(!(self = [super init]))
		return self;
	
	_peerToPeer = peerToPeer;
	
	_appId = appId;
	_nodeId = nodeId;
	_delegate = delegate;
	_queue = queue;
	
	_linksConnecting = [NSMutableArray array];
	_links = [NSMutableArray array];
	_linksTerminating = [NSMutableArray array];
	
	_serviceType = [NSString stringWithFormat:@"_underdark1-app%d._tcp.", appId];
	_timeExtender = [[UDTimeExtender alloc] initWithName:@"UDBonjourTransport"];
	
	_ioThread = [[UDRunLoopThread alloc] init];
	_ioThread.name = @"Underdark I/O";
	
	[_ioThread start];
	
	_browser = [[UDBonjourBrowser alloc] initWithTransport:self];
	_server = [[UDBonjourServer alloc] initWithTransport:self];
	_btReach = [[UDBtReach alloc] initWithDelegate:self queue:queue];
	_wifiReach= [[UDWifiReach alloc] initWithDelegate:self queue:queue];
	
	return self;
}

- (void) dealloc
{
	[self stop];
	
	[_ioThread cancel];
	_ioThread = nil;
}

- (void) start
{
	// Transport queue.
	
	if(_running)
		return;
	
	_running = true;
	
	[UDTimeExtender registerListener:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beaconDetected:) name:UDBeaconDetectedNotification object:nil];
	
	sldispatch_async(dispatch_get_main_queue(), ^{
		_beacon = [[UDBtBeacon alloc] initWithAppId:_appId];
		[_beacon requestPermissions];
	});
	
	[_btReach start];
	[_wifiReach start];
} //start

- (void) stop
{
	// Transport queue.
	if(!_running)
		return;
	
	_running = false;
	_suspended = false;
	
	[_btReach stop];
	[_wifiReach stop];

	sldispatch_async(dispatch_get_main_queue(), ^{
		[_beacon stopAdvertising];
		_beacon = nil;
	});
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
} //stop

#pragma mark - UDReachDelegate

- (void) ifaceBecomeReachable:(id<UDReach>)reach
{
	// Transport queue.
	if(!_running || _suspended)
		return;
	
	if(reach == _wifiReach || (_peerToPeer && reach == _btReach))
	{
		[_browser restart];
		[_server restart];
	}
}

- (void) ifaceBecomeUnreachable:(id<UDReach>)reach
{
	// Transport queue.
}

#pragma mark - Browser & Server Delegate

- (void) browserDidFail
{
	if([_wifiReach isReachable] || (_peerToPeer && _btReach.isReachable))
	{
		[_browser restart];
		return;
	}
	
	[_browser stop];
}

- (void) serverDidFail
{
	if([_wifiReach isReachable] || (_peerToPeer && _btReach.isReachable))
	{
		[_server restart];
		return;
	}
	
	[_server stop];
}

#pragma mark - Network utils

- (bool) shouldConnectToNodeId:(int64_t)nodeId
{
	if(nodeId == _nodeId)
		return false;
	
	for(UDBonjourLink * link in _links)
	{
		if(link.nodeId == nodeId)
		{
			//LogDebug(@"bnj link already exists to nodeId %lld", nodeId);
			return false;
		}
	}
	
	for(UDBonjourLink * link in _linksConnecting)
	{
		if(link.nodeId == nodeId)
		{
			//LogDebug(@"bnj link already exists to nodeId %lld", nodeId);
			return false;
		}
	}
	
	return true;
} // shouldConnectToNodeId

#pragma mark - Application States

- (void)applicationWillSuspend:(UDTimeExtender*)timeExtender
{
	// Main thread.
	dispatch_sync(self.queue, ^{
		_suspended = true;
		[_btReach stop];
		[_server stop];
		[_browser stop];
	});
}

- (void)applicationDidEnterBackground:(NSNotification*)notification
{
	// Main thread.
	sldispatch_async(self.queue, ^{
		if(!_running)
			return;
		
		if(_suspended)
		{
			_suspended = false;
			[_btReach start];
			
			[_wifiReach stop];
			[_wifiReach start];
		}

		sldispatch_async(dispatch_get_main_queue(), ^{
			[_beacon stopAdvertising];
			[_beacon startMonitoring];
		});
	});
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	// Main thread.
	if(!_running)
		return;
	
	[_timeExtender cancel];
	
	sldispatch_async(self.queue, ^{
		if(!_running)
			return;

		if(_suspended)
		{
			_suspended = false;
			[_btReach start];
			
			[_wifiReach stop];
			[_wifiReach start];
		}

		sldispatch_async(dispatch_get_main_queue(), ^{
			[_beacon stopMonitoring];
			[_beacon startAdvertising];
		});
	});
}

- (void)beaconDetected:(NSNotification*)notification
{
	//[[SLAppModel shared].notify notifyMeshDetected];
	
	[_timeExtender extendBackgroundTime];
	
	[_browser start];
	[_server start];
}

#pragma mark - Links

- (int64_t) linkPriority
{
	if(self.peerToPeer)
		return 15;
	
	return 10;
}

- (void) linkConnecting:(UDBonjourLink *)link
{
	// Transport queue.
	
	[_linksConnecting addObject:link];
}

- (void) linkConnected:(UDBonjourLink *)link
{
	// Transport queue.

	[_linksConnecting removeObject:link];
	[_links addObject:link];

	sldispatch_async(self.queue, ^{
		[self->_delegate transport:self linkConnected:link];
	});
}

- (void) linkDisconnected:(UDBonjourLink *)link
{
	// Transport queue.
	
	bool wasConnected = [_links containsObject:link];
	[_links removeObject:link];
	[_linksConnecting removeObject:link];

	if(![_linksTerminating containsObject:link])
		[_linksTerminating addObject:link];
	
	if(wasConnected)
	{
		sldispatch_async(self.queue, ^{
			[self->_delegate transport:self linkDisconnected:link];
		});
	}
	
	if(_running)
	{
		[_browser restart];
	}
}

- (void) linkTerminated:(UDBonjourLink *)link
{
	// Transport queue.
	
	[_linksTerminating removeObject:link];
}

- (void) link:(UDBonjourLink *)link receivedFrame:(NSData*)frameData
{
	// Transport queue.
	[self->_delegate transport:self link:link didReceiveFrame:frameData];
}

@end
