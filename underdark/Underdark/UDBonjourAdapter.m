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

#import "UDBonjourAdapter.h"

@import UIKit;

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDTimeExtender.h"
#import "UDBonjourChannel.h"
#import "UDBtBeacon.h"
#import "UDBtReach.h"
#import "UDWifiReach.h"
#import "UDBonjourBrowser.h"
#import "UDBonjourServer.h"

// Error codes: https://developer.apple.com/library/mac/documentation/Networking/Reference/CFNetworkErrors/index.html#//apple_ref/c/tdef/CFNetworkErrors

@interface UDBonjourAdapter () <UDReachDelegate, UDSuspendListener>
{
	bool _running;
	bool _suspended;
	NSString* _serviceType;
	
	UDTimeExtender* _timeExtender;
	
	__weak id<UDAdapterDelegate> _delegate;
	NSMutableArray<UDBonjourChannel*> * _channelsConnecting;
	NSMutableArray<UDBonjourChannel*> * _channels;
	NSMutableArray<UDBonjourChannel*> * _channelsTerminating;
	
	UDBtBeacon* _beacon;
	id<UDReach> _reach;
	
	UDBonjourBrowser* _browser;
	UDBonjourServer* _server;
}

@end

@implementation UDBonjourAdapter

#pragma mark - Initialization

- (instancetype) init
{
	return nil;
}

- (instancetype) initWithAppId:(int32_t)appId
						nodeId:(int64_t)nodeId
					   delegate:(nonnull id<UDAdapterDelegate>)delegate
						  queue:(nonnull dispatch_queue_t)queue
					 peerToPeer:(bool)peerToPeer
{
	if(!(self = [super init]))
		return self;
	
	_peerToPeer = peerToPeer;
	
	_appId = appId;
	_nodeId = nodeId;
	_delegate = delegate;
	_queue = queue;
	
	_channelsConnecting = [NSMutableArray array];
	_channels = [NSMutableArray array];
	_channelsTerminating = [NSMutableArray array];
	
	_ioThread = [[UDRunLoopThread alloc] init];
	
	if(peerToPeer)
	{
		_ioThread.name = @"Underdark P2P I/O";
		_serviceType = [NSString stringWithFormat:@"_udark1-p2p-app%d._tcp.", appId];
		_linkPriority = 15;
		_reach = [[UDBtReach alloc] initWithDelegate:self queue:queue];
	}
	else
	{
		_ioThread.name = @"Underdark I/O";
		_serviceType = [NSString stringWithFormat:@"_underdark1-app%d._tcp.", appId];
		_linkPriority = 10;
		_reach= [[UDWifiReach alloc] initWithDelegate:self queue:queue];
	}
	
	_timeExtender = [[UDTimeExtender alloc] initWithName:@"UDBonjourAdapter"];
	
	[_ioThread start];
	
	_browser = [[UDBonjourBrowser alloc] initWithAdapter:self];
	_server = [[UDBonjourServer alloc] initWithAdapter:self];
	
	return self;
}

- (void) dealloc
{
	[self stop];
	
	[_ioThread cancel];
	_ioThread = nil;
}

#pragma mark - UDAdapter

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
		if(_peerToPeer)
		{
			_beacon = [[UDBtBeacon alloc] initWithAppId:_appId];
			[_beacon requestPermissions];
		}
	});
	
	[_reach start];
} //start

- (void) stop
{
	// Transport queue.
	if(!_running)
		return;
	
	_running = false;
	_suspended = false;
	
	[_reach stop];

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
	
	[_browser restart];
	[_server restart];
}

- (void) ifaceBecomeUnreachable:(id<UDReach>)reach
{
	// Transport queue.
}

#pragma mark - Browser & Server Delegate

- (void) browserDidFail
{
	// Transport queue.
	if([_reach isReachable])
	{
		[_browser restart];
		return;
	}
	
	[_browser stop];
}

- (void) serverDidFail
{
	// Transport queue.
	if([_reach isReachable])
	{
		[_server restart];
		return;
	}
	
	[_server stop];
}

#pragma mark - Network utils

- (bool) shouldConnectToNodeId:(int64_t)nodeId
{
	// Transport queue.
	if(nodeId == _nodeId)
		return false;
	
	for(UDBonjourChannel* link in _channels)
	{
		if(link.nodeId == nodeId)
		{
			//LogDebug(@"bnj link already exists to nodeId %lld", nodeId);
			return false;
		}
	}
	
	for(UDBonjourChannel* link in _channelsConnecting)
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
		[_reach stop];
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
			// App process was resumed by OS.
			_suspended = false;
			[_reach stop];
			[_reach start];
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
			// App process was resumed by OS.
			_suspended = false;
			
			[_reach stop];
			[_reach start];
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

#pragma mark - Channels

- (void) channelConnecting:(nonnull UDBonjourChannel*)channel
{
	// Transport queue.
	
	[_channelsConnecting addObject:channel];

	// Debug:
	//[_browser stop];
	//[_server stop];
}

- (void) channelConnected:(nonnull UDBonjourChannel*)channel
{
	// Transport queue.

	[_channelsConnecting removeObject:channel];
	[_channels addObject:channel];

	sldispatch_async(self.queue, ^{
		[self->_delegate adapter:self channelConnected:channel];
	});
}

- (void) channelDisconnected:(nonnull UDBonjourChannel*)channel
{
	// Transport queue.
	
	bool wasConnected = [_channels containsObject:channel];
	[_channels removeObject:channel];
	[_channelsConnecting removeObject:channel];

	if(![_channelsTerminating containsObject:channel])
		[_channelsTerminating addObject:channel];
	
	if(wasConnected)
	{
		sldispatch_async(self.queue, ^{
			[self->_delegate adapter:self channelDisconnected:channel];
		});
	}
	
	if(_running)
	{
		[_browser restart];
	}
}

- (void) channelTerminated:(nonnull UDBonjourChannel*)channel
{
	// Transport queue.

	[_channelsTerminating removeObject:channel];
}

- (void) channelCanSendMore:(nonnull UDBonjourChannel*)channel
{
	// Transport queue.
	
	sldispatch_async(self.queue, ^{
		[_delegate adapter:self channelCanSendMore:channel];
	});
}

- (void) channel:(nonnull UDBonjourChannel*)channel receivedFrame:(nonnull NSData*)frameData
{
	// Transport queue.
	
	sldispatch_async(self.queue, ^{
		[self->_delegate adapter:self channel:channel didReceiveFrame:frameData];
	});
}

@end
