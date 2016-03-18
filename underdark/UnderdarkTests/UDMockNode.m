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

#import "UDMockNode.h"

#import "UDMockLink.h"
#import "UDAsyncUtils.h"
#import "UDMockTransport.h"
#import "UDRouterImpl.h"
#import "UDUtil.h"

int32_t UDPacketKindMockMessage = 1;

@interface UDMockNode () <UDTransport>
{
	NSMutableArray* _links;
	UDRouterImpl* _router;
}
@end

@implementation UDMockNode

#pragma mark - Initialization

- (instancetype) initWithNodeId:(int64_t)nodeId queue:(dispatch_queue_t)queue
{
	// Main thread.
	if(!(self = [super init]))
		return self;
	
	_nodeId = nodeId;
	_queue = queue;
	
	_links = [NSMutableArray array];
	
	return self;
}

- (instancetype) init
{
	// Main thread.
	
	self = [self initWithNodeId:[UDUtil generateId] queue:dispatch_queue_create("UDMockNode", DISPATCH_QUEUE_SERIAL)];
	if(!self)
		return self;
	
	_handler = [[UDMockHandler alloc] init];
	_router = [[UDRouterImpl alloc] initWithTransport:self delegate:_handler];
	
	[_router start];
	
	return self;
}

- (void) dealloc
{
	//LogDebug(@"UDMockNode dealloc()");
}

#pragma mark - Signals

- (void) broadcastPacket:(UDPacket*)packet
{
	// Any thread.
	sldispatch_async(self.queue, ^{
		[_router sendPacketToSelf:packet];
		[_router sendPacketToAll:packet];
	});
}

#pragma mark - Links

- (UDMockLink*) connectTo:(UDMockNode*)node
{
	// Main thread.
	UDMockLink* link = [[UDMockLink alloc] initWithNode:self toNodeId:node.nodeId];
	
	[self mlinkCreated:link];
	
	return link;
}

- (void) didConnectTo:(UDMockLink*)link
{
	// Main thread.
	[self mlinkConnected:link];
}

- (void) remove
{
	// Main thread.
	sldispatch_async(self.queue, ^{
		NSArray* links = [_links copy];
		for(UDMockLink* link in links)
		{
			[self mlinkDisconnected:link];
			[link.link.fromNode mlinkDisconnected:link.link];
			
			link.link.link = nil;
			link.link = nil;
		}
		
		[_links removeAllObjects];
		
		[_router stop];
	});
}

#pragma mark - UDTransport

- (void) start
{
	// Called by router.
}

- (void) stop
{
	// Called by router.
}

#pragma mark - UDMockLink Delegate

- (void) mlinkCreated:(UDMockLink*)link
{
	// Any thread.
	sldispatch_async(self.queue, ^{
		[_links addObject:link];
	});
}

- (void) mlinkConnected:(UDMockLink*)link
{
	dispatch_async(self.queue, ^{
		[_router transport:self linkConnected:link];
	});
}

- (void) mlinkDisconnected:(UDMockLink*)link
{
	dispatch_async(self.queue, ^{
		[_router transport:self linkDisconnected:link];
		[_links removeObject:link];
	});
}

- (void) mlink:(UDMockLink*)link didReceiveFrame:(NSData *)data
{
	// Any queue.
	sldispatch_async(self.queue, ^{
		[_router transport:self link:link didReceiveFrame:data];
	});
} // didReceiveFrame

@end
