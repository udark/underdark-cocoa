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

#import "UDBonjourBrowser.h"

#include <arpa/inet.h>

#import "UDLogging.h"
#import "UDBonjourLink.h"

const NSTimeInterval UDBonjourBrowserTimeout = 10;

@interface UDBonjourBrowser() <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
	bool _running;
	__weak UDBonjourTransport* _transport;
	
	NSNetServiceBrowser* _browser;
	NSMutableArray* _servicesDiscovered;
	
	NSMutableDictionary* _times; // name NSString to detection NSTimeInterval since reference date.
}
@end

@implementation UDBonjourBrowser

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithTransport:(UDBonjourTransport*)transport
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_servicesDiscovered = [NSMutableArray array];
	_times = [NSMutableDictionary dictionary];
	
	return self;
}

- (void) start
{
	if(_running)
		return;
	
	_running = true;
	
	_browser = [[NSNetServiceBrowser alloc] init];
	_browser.includesPeerToPeer = _transport.peerToPeer;
	_browser.delegate = self;
	[_browser scheduleInRunLoop:_transport.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	
	[_browser searchForServicesOfType:_transport.serviceType inDomain:@""];
}

- (void) stop
{
	if(!_running)
		return;
	
	_running = false;
	
	[_browser stop];
	[_browser removeFromRunLoop:_transport.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	_browser.delegate = nil;
	_browser = nil;
}

- (void) restart
{
	[self stop];
	[self start];
}

#pragma mark - NSNetServiceBrowserDelegate

- (bool) shouldConnectToService:(NSNetService *)netService
{
	/*for (NSData* addressData in netService.addresses)
	 {
		struct sockaddr_in  *socketAddress = (struct sockaddr_in *) addressData.bytes;
		
		NSString* address = SFMT(@"%s:%d", inet_ntoa(socketAddress->sin_addr), socketAddress->sin_port);
		
		NSNumber* lastDetect = _times[address];
		_times[address] = @([NSDate timeIntervalSinceReferenceDate]);
		
		if(lastDetect == nil)
		{
	 		// We haven't detected this address yet.
			continue;
		}
		
		if( ([NSDate timeIntervalSinceReferenceDate] - lastDetect.doubleValue) > UDBonjourBrowserTimeout )
		{
			// That address detection timed out.
	 		continue;
		}
		
		// We've already detected that node recently.
		return;
	 } // for*/
	
	NSNumber* lastDetect = _times[netService.name];
	_times[netService.name] = @([NSDate timeIntervalSinceReferenceDate]);
	
	if(lastDetect == nil)
	{
		// We haven't detected this address yet.
		return true;
	}
	
	if( ([NSDate timeIntervalSinceReferenceDate] - lastDetect.doubleValue) > UDBonjourBrowserTimeout )
	{
		// That address detection timed out.
		return true;
	}
	
	// We've already detected that node recently.
	return false;
} // shouldConnectToService

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing
{
	// I/O thread.
	
	//LogDebug(@"netServiceBrowserDidFindService %@", netService);
	
	//[_servicesDiscovered addObject:netService];
	
	if(![self shouldConnectToService:netService])
		return;
	
	int64_t nodeId = [netService.name longLongValue];
	if(nodeId == 0)
		return;
	
	if(![_transport shouldConnectToNodeId:nodeId])
		return;
	
	LogDebug(@"bnj discovered nodeId %lld", nodeId);
	
	NSInputStream* inputStream;
	NSOutputStream* outputStream;
	
	if(![netService getInputStream:&inputStream outputStream:&outputStream])
	{
		LogError(@"bnj failed to get streams to nodeId %lld", nodeId);
		return;
	}
	
	UDBonjourLink * link = [[UDBonjourLink alloc] initWithNodeId:nodeId transport:_transport input:inputStream output:outputStream];
	[_transport linkConnecting:link];
	
	[link connect];
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
	// I/O thread.
	
	//LogDebug(@"netServiceBrowserWillSearch");
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidStopSearch");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidNotSearch: errorCode %@", errorDict[NSNetServicesErrorCode]);
	[_transport browserDidFail];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidFindDomain '%@'", domainString);
	[_browser searchForServicesOfType:_transport.serviceType inDomain:domainString];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidRemoveDomain");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing
{
	// I/O thread.
	
	//LogDebug(@"netServiceBrowserDidRemoveService");
	[_servicesDiscovered removeObject:netService];
}

#pragma mark - NSNetServiceDelegate Resolve

- (void)netServiceWillResolve:(NSNetService *)sender
{
	// I/O thread.
	
	//LogDebug(@"bnj netServiceWillResolve");
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	// I/O thread.
	
	//LogDebug(@"bnj netServiceDidResolveAddress");
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
	// I/O thread.
	
	LogDebug(@"bnj netServiceDidNotResolve %@", errorDict[NSNetServicesErrorCode]);
}

@end
