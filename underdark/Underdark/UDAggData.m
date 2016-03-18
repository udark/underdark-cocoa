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

#import "UDAggData.h"

#import "UDAggLink.h"
#import "UDAsyncUtils.h"
#import "Frames.pb.h"

@implementation UDAggData
{
	id<UDData> _Nonnull _data;
	NSData* _Nullable volatile _frameData;
	bool volatile _disposed;
}

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data delegate:(nullable id<UDAggDataDelegate>)delegate
{
	if(!(self = [super init]))
		return self;
	
	_data = data;
	[_data acquire];
	
	_delegate = delegate;

	return self;
}

- (void) acquire
{
	[super acquire];
	[_data acquire];
}

- (void) giveup
{
	[_data giveup];
	[super giveup];
}

- (void) dispose
{
	@synchronized(self) {
		_disposed = true;
		_frameData = nil;
	}
	
	[_delegate dataDisposed:self];
}

- (void) retrieve:(UDDataRetrieveBlock _Nonnull)completion
{
	// Any thread.
	if(_frameData != nil)
	{
		sldispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			completion(_frameData);
		});
		
		return;
	}
	
	[_data retrieve:^(NSData * _Nullable data) {
		// Any thread.
		
		if(data == nil)
		{
			sldispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				completion(nil);
			});

			return;
		}
		
		// Building frame.
		FrameBuilder* frame = [FrameBuilder new];
		frame.kind = FrameKindPayload;
		
		PayloadFrameBuilder* payload = [PayloadFrameBuilder new];
		payload.payload = data;
		
		frame.payload = [payload build];
		
		NSData* localData = [[frame build] data];
		
		@synchronized(self) {
			if(!_disposed) {
				_frameData = localData;
			}
		}
		
		sldispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			completion(_frameData);
		});
	}];
} // retrieve

@end
