//
//  UnderdarkTests.m
//  UnderdarkTests
//
//  Created by Virl on 30/06/15.
//  Copyright (c) 2015 Underdark. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "UDNsdAdvertiser.h"
#import "UDNsdBrowser.h"

@interface UDNsdBrowserTests : XCTestCase <UDNsdAdvertiserDelegate, UDNsdBrowserDelegate>
{
	XCTestExpectation* _expect;
}
@end

@implementation UDNsdBrowserTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testDiscovery
{
	UDNsdAdvertiser* advertiser = [[UDNsdAdvertiser alloc] initWithDelegate:self service:@"_foosvc._tcp." name:@"test1" queue:dispatch_get_main_queue()];
	
	XCTAssertTrue([advertiser startWithPort:14357], @"Advertiser started");
	
	UDNsdBrowser* browser = [[UDNsdBrowser alloc] initWithDelegate:self service:@"_foosvc._tcp." queue:dispatch_get_main_queue()];
	[browser start];
	
	_expect = [self expectationWithDescription:@"Service Resolved"];
	
	[self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
		[browser stop];
		[advertiser stop];
	}];
}

#pragma mark - UDNsdAdvertiserDelegate

#pragma mark - UDNsdBrowserDelegate

- (void) serviceResolved:(UDNsdService*)service
{
	XCTAssertEqualObjects(@"test1", service.name);
	XCTAssertEqual(14357, service.port);
	
	[_expect fulfill];
}

@end
