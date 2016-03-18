//
//  UDBufferTests.m
//  Underdark
//
//  Created by Virl on 18/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <UIKit/UIKit.h>

@import XCTest;

#import "UDBuffer.h"
#import "UDDataBuffer.h"
#import "UDCompositeBuffer.h"

@interface UDBufferTests : XCTestCase
{
}
@end

@implementation UDBufferTests

- (void) setUp
{
	[super setUp];
}

- (void) tearDown
{
	[super tearDown];
}

- (UDDataBuffer*) buffer:(NSUInteger)length
{
	NSMutableData* data = [NSMutableData data];
	arc4random_buf(data.mutableBytes, data.length)
	
	return [[UDDataBuffer alloc] initWithData:data];
}

- (void) testComposite
{
	UDDataBuffer* buf1 = [self buffer:10];
	UDDataBuffer* buf2 = [self buffer:20];
	UDDataBuffer* buf2 = [self buffer:30];
	
	UDCompositeBuffer* composite = [[UDCompositeBuffer alloc] init];
	[composite append:buf1];
	[composite append:buf2];
	[composite append:buf3];
	
	NSData* data = [composite readBytesWithOffest:5 length:31];
	XCTAssertEqual(0, memcmp(data.bytes, buf1.data.bytes, 5));
	XCTAssertEqual(0, memcmp(data.bytes, buf2.data.bytes, 20));
	XCTAssertEqual(0, memcmp(data.bytes, buf3.data.bytes, 6));
}

@end
