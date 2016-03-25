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

#import "UDAggLink.h"

#import "UDMemorySource.h"
#import "UDAsyncUtils.h"

@interface UDAggLink()
{
	NSMutableArray<id<UDChannel>> * _channels;
	NSMutableArray<id<UDSource>> * _outputQueue;
	UDFrameData* _preparedFrame; // Currently prepared frame.
}

@end

@implementation UDAggLink

- (instancetype) init
{
	return nil;
}

- (instancetype) initWithNodeId:(int64_t)nodeId transport:(nonnull UDAggTransport*)transport
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_nodeId = nodeId;
	_channels = [NSMutableArray array];
	_outputQueue = [NSMutableArray array];
	
	return self;
}

- (void) dealloc
{
	[_preparedFrame giveup];
	_preparedFrame = nil;
}

- (bool) isEmpty
{
	return _channels.count == 0;
}

- (bool) containsChannel:(nonnull id<UDChannel>)channel
{
	return [_channels containsObject:channel];
}

- (void) addChannel:(nonnull id<UDChannel>)channel
{
	// Transport queue.
	[_channels addObject:channel];
	_channels = [_channels sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
	{
		id<UDChannel> link1 = (id<UDChannel>) obj1;
		id<UDChannel> link2 = (id<UDChannel>) obj2;

		if (link1.priority < link2.priority)
			return NSOrderedAscending;

		return NSOrderedDescending;
	}].mutableCopy;
}

- (void) removeChannel:(nonnull id<UDChannel>)channel
{
	// Transport queue.
	[_channels removeObject:channel];
}

#pragma mark - UDLink

- (void) disconnect
{
	// User queue.

	sldispatch_async(_transport.ioqueue, ^{
		for(id<UDChannel> channel in _channels)
		{
			[channel disconnect];
		}
	});
}

- (void) sendFrame:(NSData*)data
{
	// User queue.
	
	UDMemorySource* memoryData = [[UDMemorySource alloc] initWithData:data];
	[self sendData:memoryData];
}

- (void) sendData:(nonnull id<UDSource>)data
{
	// User queue.
	
	sldispatch_async(_transport.ioqueue, ^{
		[_outputQueue addObject:data];		
		[self sendNextFrame];
	});	
}

- (void) sendNextFrame
{
	// Transport queue.
	
	// Queue is empty.
	if(_outputQueue.count == 0)
		return;
	
	// Already preparing next frame.
	if(_preparedFrame != nil)
		return;
	
	_preparedFrame = [_transport.cache frameDataWithData:_outputQueue.firstObject];
	[_outputQueue removeObjectAtIndex:0];
	
	[_preparedFrame retrieve:^(NSData * _Nullable data) {
		// Transport queue.
		
		if(data == nil)
		{
			[_preparedFrame giveup];
			_preparedFrame = nil;
			[self sendNextFrame];
			return;
		}
		
		id<UDChannel> channel = [_channels firstObject];
		if(!channel) {
			[_preparedFrame giveup];
			_preparedFrame = nil;
			return;
		}
		
		UDOutputItem* outitem = [[UDOutputItem alloc] initWithData:data frameData:_preparedFrame];
		[_preparedFrame giveup];
		_preparedFrame = nil;
		
		[channel sendFrame:outitem];
	}];
} // sendNextFrame

@end
