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

#import "SLMultipeerTransport.h"

#import "SLMultipeerLink.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"

static NSString* multipeerServiceType = @"underdark";

@interface SLMultipeerTransport() <MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>
{
	volatile bool _running;
	bool _discoveryAllowed;
	MCNearbyServiceAdvertiser* _advertiser;
	MCNearbyServiceBrowser* _browser;
	
	NSMutableArray* _linksConnecting;
	NSMutableDictionary* _linksConnected;
	NSMutableArray* _linksTerminating;
	
	bool _logging;
}

@end

@implementation SLMultipeerTransport

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithNodeId:(int64_t)nodeId queue:(dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;
	
	_logging = true;
	
	_nodeId = nodeId;
	_queue = queue;
	
	_peerId = [[MCPeerID alloc] initWithDisplayName:@(self.nodeId).description];
	
	_linksConnecting = [NSMutableArray array];
	_linksConnected = [NSMutableDictionary dictionary];
	_linksTerminating = [NSMutableArray array];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	
	_inputThread = [[UDRunLoopThread alloc] init];
	_inputThread.name = @"Multipeer Input Thread";
	
	_outputThread = [[UDRunLoopThread alloc] init];
	_outputThread.name = @"Multipeer Output Thread";
	
	[_inputThread start];
	[_outputThread start];
	
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_inputThread cancel];
	_inputThread = nil;
	
	[_outputThread cancel];
	_outputThread = nil;
}

#pragma mark - SLTransport

- (bool) isConnecting
{
	// Background queue.
	return _linksConnecting.count != 0;
}

- (void) start
{
	if(_running)
		return;
	
	_running = true;
	
	sldispatch_async(dispatch_get_main_queue(), ^{
		_discoveryAllowed = ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground);
		[self restartDiscovery];		
	});
}

- (void) stop
{
	if(!_running)
		return;
	
	_running = false;
	
	for(SLMultipeerLink* link in _linksConnected)
	{
		[link disconnect];
	}
	
	sldispatch_async(dispatch_get_main_queue(), ^{
		_discoveryAllowed = false;
		[self stopDiscovery];
	});
}

#pragma mark - Application States

- (void)applicationWillResignActive:(NSNotification*)notification
{
	_discoveryAllowed = false;
	[self stopDiscovery];
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	_discoveryAllowed = true;
	[self restartDiscovery];
}

#pragma mark - Links

- (bool) shouldConnectToNodeId:(int64_t)nodeId
{
	return (_linksConnected[@(nodeId)] == nil);
}

- (SLMultipeerLink*) createLink:(MCPeerID*)peerId
{
	// Main queue.
	SLMultipeerLink* link = [[SLMultipeerLink alloc] initWithPeerId:peerId transport:self];
	if(!link)
		return nil;
	
	sldispatch_async(_queue, ^{
		[_linksConnecting addObject:link];
	});
	
	return link;
}

- (void) linkConnecting:(SLMultipeerLink*)link
{
	if(_logging)
		LogDebug(@"Connecting %@", link);
}

- (void) linkConnected:(SLMultipeerLink*)link
{
	// Background queue.
	
	[_linksConnecting removeObject:link];
	
	id<UDLink> existing = _linksConnected[@(link.nodeId)];
	
	if(existing)
	{
		[link disconnect];
		return;
	}
	
	_linksConnected[@(link.nodeId)] = link;
	
	[self.delegate transport:self linkConnected:link];
}

- (void) linkDisconnected:(SLMultipeerLink*)link
{
	// Background queue.
	
	[_linksConnecting removeObject:link];
	
	if(_logging)
		LogDebug(@"Disconnected %@", link);
	
	id<UDLink> connectedLink = _linksConnected[@(link.nodeId)];
	if(link == connectedLink)
	{
		// Link was connected.
		[_linksConnected removeObjectForKey:@(link.nodeId)];
		[self.delegate transport:self linkDisconnected:link];
	}
	
	[_linksTerminating addObject:link];
	
	sldispatch_async(dispatch_get_main_queue(), ^{
		[self restartDiscovery];
	});
}

- (void) linkTerminated:(SLMultipeerLink*)link
{
	// Background queue.
	//LogDebug(@"Terminated %@", link);
	[_linksTerminating removeObject:link];
}

#pragma mark - Discovery

- (void) restartDiscovery
{
	// Main queue.
	[self stopDiscovery];
	
	if(!_running)
		return;
	
	if(!_discoveryAllowed)
		return;

	//LogDebug(@"Discovery restarted with peerId %@", _peerId);

	_advertiser =
	[[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerId
									  discoveryInfo:nil
										serviceType:multipeerServiceType];
	_advertiser.delegate = self;
	
	_browser =
	[[MCNearbyServiceBrowser alloc] initWithPeer:_peerId serviceType:multipeerServiceType];
	_browser.delegate = self;
	
	[_advertiser startAdvertisingPeer];
	[_browser startBrowsingForPeers];
}

- (void) stopDiscovery
{
	// Main queue.
	[_browser stopBrowsingForPeers];
	_browser.delegate = nil;
	_browser = nil;
	
	[_advertiser stopAdvertisingPeer];
	_advertiser.delegate = nil;
	_advertiser = nil;
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
	// Main queue.

	if(_logging)
		LogDebug(@"Received invitation from peer %@", peerID);
	
	if(peerID.displayName == nil || [peerID.displayName longLongValue] == 0)
	{
		invitationHandler(NO, nil);
		return;
	}
	
	int64_t nodeId = [peerID.displayName longLongValue];
	
	if(nodeId == _nodeId)
	{
		//LogDebug(@"Advertiser ignoring our previous peerId %@", peerID);
		invitationHandler(NO, nil);
		return;
	}
	
	sldispatch_async(_queue, ^{
		if(![self shouldConnectToNodeId:nodeId])
		{
			if(_logging)
				LogDebug(@"Declining invitation: nodeId exists | peer %@", peerID);
			
			sldispatch_async(dispatch_get_main_queue(), ^{
				invitationHandler(NO, nil);
			});
			return;
		}
		
		sldispatch_async(dispatch_get_main_queue(), ^{
			if(_logging)
				LogDebug(@"Accepting invitation from peer %@", peerID);
			
			SLMultipeerLink* link = [self createLink:peerID];
			invitationHandler(YES, link.session);
		});
	});
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
	// Main queue.
	LogError(@"Advertising failed: %@", error);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
	// Main queue.
	sldispatch_async(_queue, ^{
		if(peerID.displayName == nil || [peerID.displayName longLongValue] == 0)
			return;
		
		int64_t nodeId = [peerID.displayName longLongValue];
		if(nodeId == _nodeId)
		{
			//LogDebug(@"Browser ignoring our previous peerId %@", peerID);
			return;
		}
		
		if(![self shouldConnectToNodeId:nodeId])
		{
			if(_logging)
				LogDebug(@"Browser ignoring peer: nodeId exists | %@", peerID);
			
			return;
		}
		
		if(_logging)
			LogDebug(@"Inviting peer %@", peerID);
		
		sldispatch_async(dispatch_get_main_queue(), ^{
			SLMultipeerLink* link = [self createLink:peerID];
			[browser invitePeer:peerID toSession:link.session withContext:nil timeout:15];
		});
	});
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
	// Main queue.
	//LogDebug(@"Browser lost peer: %@", peerID.displayName);
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
	// Main queue.
	LogError(@"Browsing failed: %@", error);
}

@end
