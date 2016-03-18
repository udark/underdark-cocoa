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

#import "UDCompositeBuffer.h"

@implementation UDCompositeBuffer

- (nonnull instancetype) init
{
	if (!(self = [super init]))
		return self;
	
	_buffers = [NSMutableArray array];
	
	return self;
}

- (void) append:(nonnull UDBuffer*)buffer
{
	[_buffers addObject:buffer];
}

#pragma mark - UDBuffer

- (NSUInteger) length
{
	NSUInteger result = 0;
	
	for(UDBuffer* buffer in _buffers)
	{
		result += buffer.length;
	}
	
	return result;
}

- (nonnull NSData*) readBytesWithOffset:(NSUInteger)offset length:(NSUInteger)len
{
	NSAssert(offset + len <= self.length, @"Out of bounds");
	
	NSMutableData* result = [[NSMutableData alloc] init];
	
	if(_buffers.count == 0)
		return result;

	// 1. Ищем начальный буфер и запоминаем размер предыдущих буферов.
	
	NSUInteger prevBuffersLen = 0;
	int32_t bufIndex = 0;
	
	while(offset >= prevBuffersLen + _buffers[bufIndex].length)
	{
		prevBuffersLen += _buffers[bufIndex].length;
		bufIndex += 1;
	}
	
	UDBuffer* starting = _buffers[bufIndex];
	
	// Appending starting buffer bytes.
	[result appendData:[starting readBytesWithOffset:(offset - prevBuffersLen)]];
	
	NSUInteger countLeft = len - (starting.length - (offset - prevBuffersLen));
	bufIndex += 1;
	
	// 2. Присоединяем байты буферов, пока не закончатся байты, которые надо присоединить.
	
	while (countLeft != 0)
	{
		UDBuffer* buffer = _buffers[bufIndex];
		NSData* bytes = [buffer readBytesWithOffset:0 length:MIN(buffer.length, countLeft)];
		
		countLeft -= bytes.length;
		bufIndex += 1;
		
		[result appendData:bytes];
	}
	
	return result;
}
	
@end
