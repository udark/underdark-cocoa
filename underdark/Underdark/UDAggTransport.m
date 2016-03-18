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
#import "UDAggData.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"

@interface UDAggTransport()
{
	int32_t _appId;
	__weak id<UDTransportDelegate> _delegate;
	
	bool _running;
	NSMutableArray* _transports;
	NSMutableDictionary<NSNumber*, UDAggLink*>* _linksConnected; // nodeId to UDAggLink
	
	NSMutableArray<UDAggData*>* _dataQueue;
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
	
	_transports = [NSMutableArray array];
	_linksConnected = [NSMutableDictionary dictionary];
	
	_dataQueue = [NSMutableArray array];
	
	return self;
}

- (void) addTransport:(id<UDAdapter>)transport
{
	if(!transport)
		return;
	
	[_transports addObject:transport];
}

#pragma mark - UDTransport

- (void) start
{
	// Delegate queue.
	if(_running)
		return;
	
	_running = true;
	
	sldispatch_async(_ioqueue, ^{
		for(id<UDAdapter> transport in _transports)
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
		for(id<UDAdapter> transport in _transports)
		{
			[transport stop];
		}
	});
}

#pragma mark - UDAdapterDelegate

- (void) transport:(id<UDAdapter>)transport linkConnected:(id<UDLink>)link
{
	UDAggLink* aggregate = _linksConnected[@(link.nodeId)];
	
	bool linksExisted = (aggregate != nil && !aggregate.isEmpty);
	
	if(!aggregate)
	{
		aggregate = [[UDAggLink alloc] initWithNodeId:link.nodeId transport:self];
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

- (void) transport:(id<UDAdapter>)transport linkDisconnected:(id<UDLink>)link
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

- (void) transport:(id<UDAdapter>)transport link:(id<UDLink>)link didReceiveFrame:(NSData*)data
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

#pragma mark - UDAggDataDelegate

- (void) dataDisposed:(nonnull UDAggData*)data
{
	// Any thread.
	
	sldispatch_async(_ioqueue, ^{
		[self sendNextData];
	});
}

- (void) enqueueData:(nonnull UDAggData*)data
{
	// I/O queue.
	[data acquire];
	[_dataQueue addObject:data];
	
	if(_dataQueue.count == 1)
	{
		[self sendNextData];
		return;
	}
}

- (void) sendNextData
{
	// I/O queue.
	if(_dataQueue.count == 0)
		return;
	
	UDAggData* data = _dataQueue.firstObject;
	[_dataQueue removeObjectAtIndex:0];
	
	[data.link sendDataToChildren:data];
	
	[data giveup];
}
@end
