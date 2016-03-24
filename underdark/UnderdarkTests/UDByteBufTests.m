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

#import <UIKit/UIKit.h>

@import XCTest;

#import "UDByteBuf.h"

@interface UDByteBufTests : XCTestCase
{
}
@end

@implementation UDByteBufTests

- (void)invokeTest
{
	self.continueAfterFailure = NO;
	@try { [super invokeTest]; } @finally { self.continueAfterFailure = YES; }
}

- (void) setUp
{
	[super setUp];
}

- (void) tearDown
{
	[super tearDown];
}

- (NSData*) data:(NSUInteger)length
{
	NSMutableData* data = [NSMutableData dataWithLength:length];
	
	if(length != 0)
		arc4random_buf(data.mutableBytes, data.length);
	
	return data;
}

- (void) testWriteRead
{
	UDByteBuf* buffer = [[UDByteBuf alloc] init];
	
	NSData* data1 = [self data:100];
	[buffer writeData:data1];

	NSData* data2 = [self data:30];
	[buffer writeData:data2];

	NSData* data3 = [self data:200];
	[buffer ensureWritable:data3.length];
	[buffer writeData:data3];

	NSData* ndata1 = [buffer readBytes:data1.length];
	[buffer skipBytes:data2.length];
	[buffer discardReadBytes];
	NSData* ndata3 = [buffer readBytes:data3.length];

	XCTAssertEqual(0, memcmp(data1.bytes, ndata1.bytes, data1.length));
	XCTAssertEqual(0, memcmp(data3.bytes, ndata3.bytes, data3.length));
}

@end
