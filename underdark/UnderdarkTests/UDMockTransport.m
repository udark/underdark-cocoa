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

#import "UDMockTransport.h"

#import "UDAsyncUtils.h"
#import "UDMockLink.h"

@interface UDMockTransport ()
{
}
@end

@implementation UDMockTransport

#pragma mark - UDTransport

- (instancetype) initWithNodeId:(int64_t)nodeId queue:(dispatch_queue_t)queue
{
	if(!(self = [super initWithNodeId:nodeId queue:queue]))
		return self;
	
	return self;
}

#pragma mark - UDTransport

- (void) start
{
}

- (void) stop
{
}

#pragma mark - UDMockNode

- (void) mlinkCreated:(UDMockLink*)link
{
}

- (void) mlinkConnected:(UDMockLink*)link
{
	dispatch_async(self.queue, ^{
		[self.delegate transport:self linkConnected:link];
	});
}

- (void) mlinkDisconnected:(UDMockLink*)link
{
	sldispatch_async(self.queue, ^{
		[self.delegate transport:self linkDisconnected:link];
	});
}

- (void) mlink:(id<UDLink>)link didReceiveFrame:(NSData *)data
{
	// Any thread.
	
	sldispatch_async(self.queue, ^{
		[self.delegate transport:self link:link didReceiveFrame:data];
	});
}

@end
