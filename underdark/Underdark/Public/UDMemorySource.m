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

#import "UDMemorySource.h"

@implementation UDMemorySource
{
	 NSData* _Nullable _data;
}

#pragma mark - Initialization

- (nonnull instancetype) init NS_UNAVAILABLE
{
	return nil;
}

- (nonnull instancetype) initWithData:(nonnull NSData*)data dataId:(nullable NSString*)dataId
{
	if(!(self = [super init]))
		return self;
	
	_dataId = dataId;
	_data = data;
	_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	
	return self;
}

- (nonnull instancetype) initWithData:(nonnull NSData*)data
{
	return [self initWithData:data dataId:nil];
}

#pragma mark - UDData

- (void) retrieve:(UDSourceRetrieveBlock _Nonnull)completion
{
	completion(_data);
}

@end
