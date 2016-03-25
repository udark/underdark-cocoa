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

#import "UDLazySource.h"

#import "UDAsyncUtils.h"

@implementation UDLazySource
{
	UDLazyDataRetrieveBlock _block;
}

- (nonnull instancetype) init NS_UNAVAILABLE
{
	return nil;
}

- (nonnull instancetype) initWithQueue:(nullable dispatch_queue_t)queue block:(nonnull UDLazyDataRetrieveBlock)block dataId:(nullable NSString*)dataId
{
	if(!(self = [super init]))
		return self;
	
	_queue = (queue == nil) ? dispatch_get_main_queue() : queue;
	_block = [block copy];
	
	_dataId = dataId;
	
	return self;
}

- (nonnull instancetype) initWithQueue:(nullable dispatch_queue_t)queue block:(nonnull UDLazyDataRetrieveBlock)block
{
	return [self initWithQueue:queue block:block dataId:nil];
}

- (void) dealloc
{
	
}

#pragma mark - UDData

- (void) retrieve:(UDSourceRetrieveBlock _Nonnull)completion
{
	NSData* data = _block();
	completion(data);
} // retrieve

@end
