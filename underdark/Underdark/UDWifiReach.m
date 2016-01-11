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

#import "UDWifiReach.h"

#import <ifaddrs.h>
#import <net/if.h>
#import <SystemConfiguration/CaptiveNetwork.h>

//#import <KSReachability/KSReachability.h>

#import "UDLogging.h"
#import "UDAsyncUtils.h"

@import UIKit;
@import SystemConfiguration;

/* Detect that Wi-Fi is on:
 http://stackoverflow.com/a/25956280/1449965
 http://www.enigmaticape.com/blog/determine-wifi-enabled-ios-one-weird-trick
 */

/* Reachability libs:
 https://github.com/tonymillion/Reachability
 https://github.com/belkevich/reachability-ios
 https://github.com/GlennChiu/GCNetworkReachability
 https://github.com/kstenerud/KSReachability
*/

@interface UDWifiReach ()
{
	bool _running;
	__weak id<UDReachDelegate> _delegate;
	dispatch_queue_t _queue;
	
	bool _reachable;
	NSString* _lastSSID;
	
	//KSReachability* _reach;
}

@end

@implementation UDWifiReach

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithDelegate:(id<UDReachDelegate>)delegate queue:(dispatch_queue_t)queue
{
	// Background queue.

	if(!(self = [super init]))
		return self;
	
	_delegate = delegate;
	_queue = queue;
	
	return self;
}

- (void) dealloc
{
	[self stop];
}

- (void) start
{
	// Transport queue.
	if(_running)
		return;
	
	_running = true;
	
	/*_reach = [KSReachability reachabilityToHost:@"8.8.8.8"];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onReachabilityChanged:)
												 name:kDefaultNetworkReachabilityChangedNotification
											   object:nil];
	
	_reach.notificationName = kDefaultNetworkReachabilityChangedNotification;*/
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	
	[self refresh];
}

- (void) stop
{
	// Transport queue.
	if(!_running)
		return;
	
	_running = false;
	_reachable = false;
	_lastSSID = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	/*if(_reach)
	{
		_reach.notificationName = nil;
		_reach = nil;
		
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}*/
}

/*- (void) onReachabilityChanged:(NSNotification*) notification
{
	// Main thread.
	
	KSReachability* reach = (KSReachability*)notification.object;
	
	if(!reach.reachable || reach.WWANOnly)
	{
		LogInfo(@"Wi-Fi become unavailable.");
		_isWiFiReachable = false;
		return;
	}
	
	LogInfo(@"Wi-Fi become available.");
	_isWiFiReachable = true;
	dispatch_async(_transport.queue, ^{
		//[_transport onReachableViaWiFi];
	});
}*/

#pragma mark - Application States

- (void)applicationDidEnterBackground:(NSNotification*)notification
{
	// Main thread.
	sldispatch_async(_queue, ^{
		[self refresh];
	});
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	// Main thread.
	sldispatch_async(_queue, ^{
		[self refresh];
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), _queue, ^{
		[self refresh];
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), _queue, ^{
		[self refresh];
	});
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), _queue, ^{
		[self refresh];
	});
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), _queue, ^{
		[self refresh];
	});
}

#pragma mark - Reachability

- (bool) isReachable
{
	return [self isWiFiEnabled] && [self isWiFiConnected];
}

- (void) refresh
{
	if(!_running)
		return;

	NSString* currentSSID = [self SSID];
	
	if(_reachable && [self isReachable]
	   && currentSSID && ![_lastSSID isEqual:currentSSID])
	{
		LogDebug(@"wifi-reach yes");
		_reachable = true;
		_lastSSID = currentSSID;
		[_delegate ifaceBecomeReachable:self];
		return;
	}

	if(!_reachable && [self isReachable] )
	{
		//LogDebug(@"wifi-reach yes");
		_reachable = true;
		_lastSSID = currentSSID;
		[_delegate ifaceBecomeReachable:self];
		return;
	}
	
	if(_reachable && ![self isReachable] )
	{
		//LogDebug(@"wifi-reach no");
		_reachable = false;
		_lastSSID = nil;
		[_delegate ifaceBecomeUnreachable:self];
		return;
	}
}

- (bool) isWiFiEnabledOld
{
	NSCountedSet * cset = [NSCountedSet new];
	
	struct ifaddrs *interfaces = NULL;
	
	if( ! getifaddrs(&interfaces) ) {
		for( struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next)
		{
			if ( (interface->ifa_flags & IFF_UP) == IFF_UP )
			{
				[cset addObject:[NSString stringWithUTF8String:interface->ifa_name]];
			}
		}
		
		if(interfaces)
			freeifaddrs(interfaces);
	}
	
	return [cset countForObject:@"awdl0"] > 1;
}

- (bool) isWiFiEnabled
{
#if TARGET_IPHONE_SIMULATOR
	return true;
#else
	struct ifaddrs *addresses;
	struct ifaddrs *cursor;
	bool wiFiAvailable = false;
	
	if (getifaddrs(&addresses) != 0)
		return false;
	
	cursor = addresses;
	while (cursor != NULL) {
		if (cursor -> ifa_addr -> sa_family == AF_INET
			&& !(cursor -> ifa_flags & IFF_LOOPBACK)) // Ignore the loopback address
		{
			// Check for WiFi adapter
			if (strcmp(cursor -> ifa_name, "en0") == 0) {
				wiFiAvailable = true;
				break;
			}
		}
		cursor = cursor -> ifa_next;
	}
	
	freeifaddrs(addresses);
	return wiFiAvailable;
#endif
}

- (NSDictionary *) wifiDetails
{
#if TARGET_IPHONE_SIMULATOR
	return nil;
#else
	return
	(__bridge NSDictionary *)
	CNCopyCurrentNetworkInfo(
							 CFArrayGetValueAtIndex( CNCopySupportedInterfaces(), 0)
        );
#endif
}

- (bool) isWiFiConnected
{
#if TARGET_IPHONE_SIMULATOR
	return true;
#else
	return [self wifiDetails] != nil;
#endif
}

- (NSString *) SSID
{
	return [self wifiDetails][@"SSID"];
}

- (NSString *) BSSID
{
	return [self wifiDetails][@"BSSID"];
}
@end
