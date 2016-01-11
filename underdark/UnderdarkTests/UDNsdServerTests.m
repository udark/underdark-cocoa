//
//  UDNsdServerTests.m
//  Underdark
//
//  Created by Virl on 13/09/15.
//  Copyright (c) 2015 Underdark. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "UDNsdServer.h"

@interface UDNsdServerTests : XCTestCase <UDNsdServerDelegate>

@end

@implementation UDNsdServerTests
{
	UDNsdServer* _server1;
	UDNsdServer* _server2;

	id<UDLink> _link1;
	id<UDLink> _link2;
	
	NSMutableArray* _framesSent;
	NSMutableArray* _framesReceived;

	XCTestExpectation* _expectConnected;
	XCTestExpectation* _expectFrames;
	XCTestExpectation* _expectDisconnected;
}

- (void) setUp
{
	[super setUp];
}

- (void) tearDown
{
	[_server1 stopAccepting];
	[_link1 disconnect];
	[_link2 disconnect];
	
	[super tearDown];
}

- (void) testServer
{
	[self accept];
	[self connect];
	[self frames];
	[self disconnect];
}

- (void) accept
{
	_server1 = [[UDNsdServer alloc] initWithDelegate:self nodeId:42 queue:dispatch_get_main_queue()];
	_server2 = [[UDNsdServer alloc] initWithDelegate:self nodeId:69 queue:dispatch_get_main_queue()];
	
	XCTAssertTrue([_server1 startAccepting], @"Accepting started");
}

- (void) connect
{
	_expectConnected = [self expectationWithDescription:@"Links Connected"];
	[_server2 connectToHost:@"127.0.0.1" port:_server1.port interface:0];
	
	[self waitForExpectationsWithTimeout:5.0 handler:nil];
	_expectConnected = nil;
}

- (NSMutableData*) randomData:(int)size
{
	NSMutableData* theData = [NSMutableData dataWithCapacity:size];
	for( unsigned int i = 0 ; i < size / 4; ++i )
	{
		u_int32_t randomBits = arc4random();
		[theData appendBytes:(void*)&randomBits length:4];
	}
	return theData;
}

- (void) genFrame:(int)size
{
	NSData* frameData = [self randomData:size];
	[_framesSent addObject:frameData];
}

- (void) frames
{
	_framesSent = [NSMutableArray array];
	_framesReceived = [NSMutableArray array];
	
	[self genFrame:6000];
	[self genFrame:500];
	[self genFrame:10];
	[self genFrame:1 * 1024 * 1024];
	[self genFrame:4000];

	_expectFrames = [self expectationWithDescription:@"Frames Received"];

	for(NSData* frameData in _framesSent)
		[_link1 sendFrame:frameData];
	
	[self waitForExpectationsWithTimeout:5.0 handler:nil];
	_expectFrames = nil;
}

- (void) disconnect
{
	_expectDisconnected = [self expectationWithDescription:@"Links Disconnected"];
	[_link1 disconnect];
	
	[self waitForExpectationsWithTimeout:5.0 handler:nil];
	_expectDisconnected = nil;
}

#pragma mark - UDNsdServerDelegate

- (void) server:(nonnull UDNsdServer*)server linkConnected:(nonnull UDNsdLink*)link
{
	if(server == _server1)
		_link1 = link;

	if(server == _server2)
		_link2 = link;

	if(_link1 && _link2)
		[_expectConnected fulfill];
}

- (void) server:(nonnull UDNsdServer*)server linkDisconnected:(nonnull UDNsdLink*)link
{
	if(server == _server1)
		_link1 = nil;
	
	if(server == _server2)
		_link2 = nil;
	
	if(!_link1 && !_link2)
		[_expectDisconnected fulfill];
}

- (void) server:(nonnull UDNsdServer*)server link:(nonnull UDNsdLink *)link didReceiveFrame:(nonnull NSData*)frameData
{
	if(link != _link2)
		return;
	
	[_framesReceived addObject:frameData];
	
	if(_framesReceived.count == _framesSent.count)
	{
		bool fulfilled = true;
		
		for(int i = 0; i < _framesSent.count; ++i)
		{
			NSData* dataSent = _framesSent[i];
			NSData* dataReceived = _framesReceived[i];
			
			if(dataSent.length != dataReceived.length)
			{
				fulfilled = false;
				break;
			}
			
			if(0 != memcmp(dataSent.bytes, dataReceived.bytes, dataSent.length))
			{
				fulfilled = false;
				break;
			}
		} // for
		
		if(fulfilled)
			[_expectFrames fulfill];
	} // if
}


@end
