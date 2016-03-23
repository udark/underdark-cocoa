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
#import "UDFrameData.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"

@interface UDAggTransport()
{
	int32_t _appId;
	__weak id<UDTransportDelegate> _delegate;
	
	bool _running;
	NSMutableArray< id<UDAdapter> > * _adapters;
	NSMutableDictionary<NSNumber*, UDAggLink*> * _linksConnected; // nodeId to UDAggLink
}
@end

@implementation UDAggTransport

- (nonnull instancetype) initWithAppId:(int32_t)appId
								 nodeId:(int64_t)nodeId
							   delegate:(nullable id<UDTransportDelegate>)delegate
								  queue:(nullable dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;
	
	_appId = appId;
	_queue = queue;
	_ioqueue = dispatch_queue_create("UDAggTransport", DISPATCH_QUEUE_SERIAL);
	_delegate = delegate;
	
	_adapters = [NSMutableArray array];
	_linksConnected = [NSMutableDictionary dictionary];
	
	_cache = [[UDFrameCache alloc] initWithQueue:_ioqueue];
	
	return self;
}

- (void) addAdapter:(nonnull id<UDAdapter>)adapter
{
	if(!adapter)
		return;

	[_adapters addObject:adapter];
}

#pragma mark - UDTransport

- (void) start
{
	// Delegate queue.
	if(_running)
		return;
	
	_running = true;
	
	sldispatch_async(_ioqueue, ^{
		for(id<UDAdapter> transport in _adapters)
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
	
	sldispatch_async(_ioqueue, ^{
		for(id<UDAdapter> transport in _adapters)
		{
			[transport stop];
		}
	});
}

#pragma mark - UDAdapterDelegate

- (void) adapter:(id<UDAdapter>)transport channelConnected:(id<UDChannel>)link
{
	UDAggLink* aggregate = _linksConnected[@(link.nodeId)];
	
	bool linksExisted = (aggregate != nil && !aggregate.isEmpty);
	
	if(!aggregate)
	{
		aggregate = [[UDAggLink alloc] initWithNodeId:link.nodeId transport:self];
		_linksConnected[@(link.nodeId)] = aggregate;
	}

	[aggregate addChannel:link];
	
	if(!linksExisted)
	{
		sldispatch_async(_queue, ^{
			[_delegate transport:self linkConnected:aggregate];
		});
	}
}

- (void) adapter:(id<UDAdapter>)transport channelDisconnected:(id<UDChannel>)channel
{
	UDAggLink* aggregate = _linksConnected[@(channel.nodeId)];
	if(!aggregate)
		return;
	
	if([aggregate containsChannel:channel])
	{
		// Link was connected.
		[aggregate removeChannel:channel];
	}
	
	if(aggregate.isEmpty)
	{
		[_linksConnected removeObjectForKey:@(aggregate.nodeId)];
		
		sldispatch_async(_queue, ^{
			[_delegate transport:self linkDisconnected:aggregate];
		});
	}
}

- (void) adapter:(id<UDAdapter>)adapter channelCanSendMore:(id<UDChannel>)channel
{
	UDAggLink* link = _linksConnected[@(channel.nodeId)];
	if(!link)
	{
		LogError(@"Link doesn't exist for %@", channel);
		return;
	}
	
	if(![link containsChannel:channel])
	{
		LogError(@"Link doesn't contain %@", channel);
		return;
	}
	
	[link sendNextFrame];
}


- (void) adapter:(id<UDAdapter>)adapter channel:(id<UDChannel>)channel didReceiveFrame:(NSData*)data
{
	UDAggLink* link = _linksConnected[@(channel.nodeId)];
	if(!link)
	{
		LogError(@"Link doesn't exist for channel %@", channel);
		return;
	}
	
	if(![link containsChannel:channel])
	{
		LogError(@"Link doesn't contain channel %@", channel);
		return;
	}
	
	sldispatch_async(_queue, ^{
		[_delegate transport:self link:link didReceiveFrame:data];
	});
}

@end
