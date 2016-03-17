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

@interface UDAggLink()
{
	NSMutableArray* _links;
}

@end

@implementation UDAggLink

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithNodeId:(int64_t)nodeId transport:(UDAggTransport*)transport
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_nodeId = nodeId;
	_links = [NSMutableArray array];
	
	return self;
}

- (bool) isEmpty
{
	return _links.count == 0;
}

- (bool) containsLink:(id<UDLink>)link
{
	return [_links containsObject:link];
}

- (void) disconnect
{
	for(id<UDLink> link in _links)
	{
		[link disconnect];
	}
}

- (void) addLink:(id<UDLink>)link
{
	// I/O queue.
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

- (void) removeLink:(id<UDLink>)link
{
	// I/O queue.
	[_links removeObject:link];
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
	UDAggData* aggData = [[UDAggData alloc] initWithData:data delegate:_transport];
	
	sldispatch_async(_transport.ioqueue, ^{
		[_transport enqueueData:aggData];		
	});
}

- (void) sendDataToChildren:(nonnull UDAggData*)data
{
	// I/O queue.
	id<UDLink> link = [_links firstObject];
	if(!link) {
		[data dispose];
		return;
	}
	
	[link sendData:data];
}

@end
