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

#import "UDMemoryData.h"
#import "UDAsyncUtils.h"

@interface UDAggLink() <UDChannelDelegate>
{
	NSMutableArray<id<UDChannel>> * _links;
	NSMutableArray<id<UDData>> * _outputQueue;
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
	_links = [NSMutableArray array];
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
	return _links.count == 0;
}

- (bool) containsLink:(id<UDChannel>)link
{
	return [_links containsObject:link];
}

- (void) addLink:(id<UDChannel>)link
{
	// Transport queue.
	[_links addObject:link];
	_links = [_links sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
			  {
				  id<UDLink> link1 = (id<UDLink>)obj1;
				  id<UDLink> link2 = (id<UDLink>)obj2;
				  
				  if(link1.priority < link2.priority)
					  return NSOrderedAscending;
				  
				  return NSOrderedDescending;
			  }].mutableCopy;
}

- (void) removeLink:(id<UDChannel>)link
{
	// Transport queue.
	[_links removeObject:link];
}

#pragma mark - UDLink

- (void) disconnect
{
	// User queue.
	
	for(id<UDChannel> link in _links)
	{
		[link disconnect];
	}
}

- (void) sendFrame:(NSData*)data
{
	// User queue.
	
	UDMemoryData* memoryData = [[UDMemoryData alloc] initWithData:data];
	[self sendData:memoryData];
}

- (void) sendData:(nonnull id<UDData>)data
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
	
	// Already preparing next frame.
	if(_preparedFrame != nil)
		return;
	
	// Queue is empty.
	if(_outputQueue.firstObject == nil)
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
		
		id<UDChannel> link = [_links firstObject];
		if(!link) {
			[_preparedFrame giveup];
			_preparedFrame = nil;
			return;
		}
		
		UDOutputItem* outitem = [[UDOutputItem alloc] initWithData:data frameData:_preparedFrame];
		[link sendFrame:outitem];
	}];
} // sendNextFrame

#pragma mark - UDChannelDelegate

- (void) channelCanSendMore:(nonnull id<UDChannel>)channel
{
	// Transport queue.
	[self sendNextFrame];
}

@end
