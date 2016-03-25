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

#import "UDFrameData.h"

#import "UDAggLink.h"
#import "UDAsyncUtils.h"
#import "Frames.pb.h"
#import "UDLogging.h"

@implementation UDFrameData
{
	NSData* _Nullable volatile _payload;
	bool volatile _disposed;
}

- (nonnull instancetype) initWithData:(nonnull id<UDSource>)data queue:(nonnull dispatch_queue_t)queue delegate:(nullable id<UDFrameDataDelegate>)delegate
{
	if(!(self = [super init]))
		return self;

	_queue = queue;
	_delegate = delegate;

	_data = data;

	return self;
}

- (void) acquire
{
	sldispatch_async(_queue, ^{
		[_delegate frameDataAcquire:self];
	});
}

- (void) giveup
{
	sldispatch_async(_queue, ^{
		[_delegate frameDataGiveup:self];
	});
}

- (void) dispose
{
	@synchronized(self) {
		_disposed = true;
		_payload = nil;
	}
	
	LogDebug(@"UDFrameData dispose()");
}

- (void) retrieve:(UDFrameSourceRetrieveBlock _Nonnull)completion
{
	// Any thread.
	@synchronized(self) {
		if(_payload != nil)
		{
			NSData* payload = _payload;
			sldispatch_async(_queue, ^{
				completion(payload);
			});
			
			return;
		}
	}
	
	sldispatch_async(_data.queue, ^{
		[_data retrieve:^(NSData * _Nullable data) {
			// Any thread.
			
			if(data == nil)
			{
				sldispatch_async(_queue, ^{
					completion(nil);
				});
				
				return;
			}
			
			sldispatch_async(_queue, ^{
				// Building frame.
				FrameBuilder* frame = [FrameBuilder new];
				frame.kind = FrameKindPayload;
				
				PayloadFrameBuilder* payload = [PayloadFrameBuilder new];
				payload.payload = data;
				
				frame.payload = [payload build];
				
				NSData* result = [[frame build] data];
				
				@synchronized(self) {
					if(!_disposed) {
						_payload = result;
					}
				}
				
				completion(result);
			});
		}]; // retrieve
	}); // dispatch
} // retrieve

@end
