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

#import "UDAggTransport.h"

#import "UDAggLink.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"

@interface UDAggTransport()
{
	int32_t _appId;
	__weak id<UDTransportDelegate> _delegate;
	
	bool _running;
	NSMutableArray* _transports;
	NSMutableDictionary* _linksConnected; // nodeId to SLAggregateLink
}
@end

@implementation UDAggTransport

- (instancetype) initWithAppId:(int32_t)appId
						nodeId:(int64_t)nodeId
					  delegate:(id<UDTransportDelegate>)delegate
						 queue:(dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;
	
	_appId = appId;
	_queue = queue;
	_childsQueue = dispatch_queue_create("Underdark Transport", DISPATCH_QUEUE_SERIAL);
	_delegate = delegate;
	
	_transports = [NSMutableArray array];
	_linksConnected = [NSMutableDictionary dictionary];
	
	return self;
}

- (void) addTransport:(id<UDTransport>)transport
{
	if(!transport)
		return;
	
	[_transports addObject:transport];
}

#pragma mark - SLTransport

- (void) start
{
	// Delegate queue.
	if(_running)
		return;
	
	_running = true;
	
	sldispatch_async(_childsQueue, ^{
		for(id<UDTransport> transport in _transports)
		{
			[transport start];
		}
	});
}

- (void) stop
{
	// Delegate queue.
	if(!_running)
		return;
	
	_running = false;
	
	sldispatch_async(_childsQueue, ^{
		for(id<UDTransport> transport in _transports)
		{
			[transport stop];
		}
	});
}

#pragma mark - SLTransportDelegate

- (void) transport:(id<UDTransport>)transport linkConnected:(id<UDLink>)link
{
	UDAggLink* aggregate = _linksConnected[@(link.nodeId)];
	
	bool linksExisted = (aggregate != nil && !aggregate.isEmpty);
	
	if(!aggregate)
	{
		aggregate = [[UDAggLink alloc] initWithNodeId:link.nodeId];
		_linksConnected[@(link.nodeId)] = aggregate;
	}
	
	[aggregate addLink:link];
	
	if(!linksExisted)
	{
		sldispatch_async(_queue, ^{
			[_delegate transport:self linkConnected:aggregate];
		});
	}
}

- (void) transport:(id<UDTransport>)transport linkDisconnected:(id<UDLink>)link
{
	UDAggLink* aggregate = _linksConnected[@(link.nodeId)];
	if(!aggregate)
		return;
	
	if([aggregate containsLink:link])
	{
		// Link was connected.
		[aggregate removeLink:link];
	}
	
	if(aggregate.isEmpty)
	{
		[_linksConnected removeObjectForKey:@(aggregate.nodeId)];
		
		sldispatch_async(_queue, ^{
			[_delegate transport:self linkDisconnected:aggregate];
		});
	}
}

- (void) transport:(id<UDTransport>)transport link:(id<UDLink>)link didReceiveFrame:(NSData*)data
{
	UDAggLink* aggregate = _linksConnected[@(link.nodeId)];
	if(!aggregate)
	{
		LogError(@"Aggregate doesn't exist for %@", link);
		return;
	}
	
	if(![aggregate containsLink:link])
	{
		LogError(@"Aggregate doesn't contain %@", link);
		return;
	}
	
	sldispatch_async(_queue, ^{
		[_delegate transport:self link:aggregate didReceiveFrame:data];
	});
}

@end
