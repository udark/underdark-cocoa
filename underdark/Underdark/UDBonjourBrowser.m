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
#import "UDBonjourChannel.h"
#import "UDAsyncUtils.h"

const NSTimeInterval UDBonjourBrowserTimeout = 10;

typedef NS_ENUM(NSUInteger, UDBnjBrowserState)
{
	UDBnjBrowserStateStopped,
	UDBnjBrowserStateStarting,
	UDBnjBrowserStateRunning,
	UDBnjBrowserStateStopping
};

@interface UDBonjourBrowser() <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
	UDBnjBrowserState _state;
	UDBnjBrowserState _desiredState;
	
	NSNetServiceBrowser* _browser;
	NSMutableArray* _servicesDiscovered;
	
	NSMutableDictionary* _times; // name NSString to detection NSTimeInterval since reference date.
}

@property (nonatomic, readonly, weak, nullable) UDBonjourAdapter* adapter;

@end

@implementation UDBonjourBrowser

#pragma mark - Initialization

- (instancetype) init
{
	return nil;
}

- (instancetype) initWithAdapter:(UDBonjourAdapter*)adapter
{
	if(!(self = [super init]))
		return self;
	
	_adapter = adapter;
	
	_state = UDBnjBrowserStateStopped;
	_desiredState = UDBnjBrowserStateStopped;
	
	_servicesDiscovered = [NSMutableArray array];
	_times = [NSMutableDictionary dictionary];
	
	return self;
}

#pragma mark - Public API

- (void) start
{
	[self performSelector:@selector(startImpl) onThread:_adapter.ioThread withObject:nil waitUntilDone:YES];
}

- (void) stop
{
	[self performSelector:@selector(stopImpl) onThread:_adapter.ioThread withObject:nil waitUntilDone:YES];
}

- (void) restart
{
	[self stop];
	[self start];
}

#pragma mark - Browser

- (void) startImpl
{
	//  Browser thread.
	
	_desiredState = UDBnjBrowserStateRunning;
	
	if(_state != UDBnjBrowserStateStopped)
		return;
	
	_state = UDBnjBrowserStateStarting;
	
	_browser = [[NSNetServiceBrowser alloc] init];
	_browser.includesPeerToPeer = _adapter.peerToPeer;
	_browser.delegate = self;
	
	//[_browser scheduleInRunLoop:_adapter.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	
	[_browser searchForServicesOfType:_adapter.serviceType inDomain:@""];
} // startImpl

- (void) stopImpl
{
	//  Browser thread.

	_desiredState = UDBnjBrowserStateStopped;
	
	if(_state != UDBnjBrowserStateRunning)
		return;
	
	_state = UDBnjBrowserStateStopping;
	
	[_browser stop];
	//[_browser removeFromRunLoop:_adapter.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	//_browser.delegate = nil;
	//_browser = nil;
}

- (void) checkDesiredState
{
	// Service thread.
	if(_desiredState == UDBnjBrowserStateRunning && _state == UDBnjBrowserStateStopped)
	{
		[self startImpl];
	}
	else if(_desiredState == UDBnjBrowserStateStopped && _state == UDBnjBrowserStateRunning)
	{
		[self stopImpl];
	}
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

	NSInputStream* inputStream;
	NSOutputStream* outputStream;
	
	if(![netService getInputStream:&inputStream outputStream:&outputStream])
	{
		LogError(@"bnj failed to get streams to nodeId %lld", nodeId);
		return;
	}
	
	sldispatch_async(_adapter.queue, ^{
		if(![_adapter shouldConnectToNodeId:nodeId])
		{
			[inputStream open];
			[inputStream close];
			[outputStream open];
			[outputStream close];
			return;
		}

		LogDebug(@"bnj discovered nodeId %lld", nodeId);
		
		UDBonjourChannel* link = [[UDBonjourChannel alloc] initWithNodeId:nodeId adapter:_adapter input:inputStream output:outputStream];
		[_adapter channelConnecting:link];
		
		[link connect];
	});
} // didFindService

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
	// I/O thread.
	
	//LogDebug(@"netServiceBrowserWillSearch");
	
	_state = UDBnjBrowserStateRunning;
	[self checkDesiredState];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidStopSearch");
	
	_browser.delegate = nil;
	_browser = nil;
	_state = UDBnjBrowserStateStopped;
	
	[self checkDesiredState];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidNotSearch: errorCode %@", errorDict[NSNetServicesErrorCode]);
	
	_browser.delegate = nil;
	_browser = nil;
	_state = UDBnjBrowserStateStopped;
	_desiredState = UDBnjBrowserStateStopped;
	
	dispatch_async(_adapter.queue, ^{
		[_adapter browserDidFail];
	});
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
	// I/O thread.
	
	LogDebug(@"netServiceBrowserDidFindDomain '%@'", domainString);
	[_browser searchForServicesOfType:_adapter.serviceType inDomain:domainString];
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
