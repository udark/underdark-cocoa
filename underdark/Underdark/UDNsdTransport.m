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

#import "UDNsdTransport.h"

#import "UDNsdServer.h"
#import "UDNsdBrowser.h"
#import "UDNsdAdvertiser.h"
#import "UDAsyncUtils.h"

@interface UDNsdTransport () <UDNsdServerDelegate, UDNsdBrowserDelegate, UDNsdAdvertiserDelegate>
{
	bool _running;
	int64_t _nodeId;
	NSString* _serviceType;

	UDNsdServer* _server;
	UDNsdAdvertiser* _advertiser;
	UDNsdBrowser* _browser;
}

@property (nonatomic, readonly, weak) id<UDTransportDelegate> delegate;
@end

@implementation UDNsdTransport

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithDelegate:(id<UDTransportDelegate>)delegate
                            appId:(int32_t)appId
                           nodeId:(int64_t)nodeId
					   peerToPeer:(bool)peerToPeer
                            queue:(dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;

	_delegate = delegate;
	_queue = queue;
	
	_nodeId = nodeId;

	_serviceType = [NSString stringWithFormat:@"_underdark1-app%d._tcp.", appId];

	_server = [[UDNsdServer alloc] initWithDelegate:self nodeId:nodeId queue:queue];
	_advertiser = [[UDNsdAdvertiser alloc] initWithDelegate:self service:_serviceType name:@(nodeId).description queue:queue];
	_advertiser.peerToPeer = peerToPeer;
	_browser = [[UDNsdBrowser alloc] initWithDelegate:self service:_serviceType queue:self.queue];
	_browser.peerToPeer = peerToPeer;

	return self;
}

- (void)start
{
	if(_running)
		return;

	_running = true;
	
/*#if !TARGET_IPHONE_SIMULATOR
	if([_server startAccepting])
	{
		[_advertiser startWithPort:_server.port];
	}
#endif*/
	
	[_browser start];
}

- (void)stop
{
	if(!_running)
		return;

	_running = false;

	[_browser stop];
	[_advertiser stop];
	[_server stopAccepting];
}

#pragma mark - UDNsdBrowserDelegate

- (void) serviceResolved:(UDNsdService*)service
{
	int64_t destNodeId = [service.name longLongValue];
	if(destNodeId == _nodeId)
		return;
	
	if(destNodeId != 0 && [_server isLinkConnectedToNodeId:destNodeId])
		return;
	
	[_server connectToHost:service.address port:service.port interface:service.interfaceIndex];
}

#pragma mark - UDNsdAdvertiserDelegate

#pragma mark - UDNsdServerDelegate

- (void) server:(nonnull UDNsdServer*)server linkConnected:(nonnull UDNsdLink*)link
{
	[self.delegate transport:self linkConnected:link];
}

- (void) server:(nonnull UDNsdServer*)server linkDisconnected:(nonnull UDNsdLink*)link
{
	[self.delegate transport:self linkDisconnected:link];
	
	if(link.interfaceIndex != 0)
	{
		//[_browser stop];
		//[_browser start];
		[_browser reconfirmRecord:@(link.nodeId).description interface:link.interfaceIndex];
	}
}

- (void) server:(nonnull UDNsdServer*)server link:(nonnull UDNsdLink *)link didReceiveFrame:(nonnull NSData*)frameData
{
	[self.delegate transport:self link:link didReceiveFrame:frameData];
}


@end