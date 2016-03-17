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

#import "UDLazyData.h"

#import "UDAsyncUtils.h"

@implementation UDLazyData
{
	dispatch_queue_t volatile _queue;
	UDLazyDataRetrieveBlock _Nullable volatile _block;
	NSData* _Nullable volatile _data;
}

- (nullable instancetype) initWithQueue:(nullable dispatch_queue_t)queue block:(nonnull UDLazyDataRetrieveBlock)block
{
	if(!(self = [super init]))
		return self;
	
	_queue = (queue == nil) ? dispatch_get_main_queue() : queue;
	_block = [block copy];
	
	return self;
}

#pragma mark - UDData

- (bool) disposed
{
	return _block == nil;
}

- (void) dispose
{
	// Any thread.
	@synchronized(self)
	{
		_queue = nil;
		_block = nil;
		_data = nil;
	}
}

- (void) retrieve:(UDDataRetrieveBlock _Nonnull)completion
{
	// I/O thread.
	
	if(self.disposed)
	{
		completion(nil);
		return;
	}
	
	if(_data == nil) {
		sldispatch_async(_queue, ^{
			UDLazyDataRetrieveBlock localBlock = _block;
			
			if(localBlock == nil)
			{
				// We already disposed.
				completion(nil);
				return;
			}
			
			NSData* localData = nil;
			
			@synchronized(self) {
				if(_data != nil)
				{
					// Data already retrieved.
					localData = _data;
				}
			}
			
			if(localData == nil) {
				localData = localBlock();
				
				if(localData == nil) {
					// Cannot retrieve data - we're disposed.
					[self dispose];
				}
			}
			
			if(!self.disposed) {
				@synchronized(self) {
					_data = localData;
				}
			}
			
			completion(localData);
		});
		
		return;
	} // if data == nil
	
	completion(_data);
} // retrieve

@end
