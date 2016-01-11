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

#import "SLInetReach.h"

//#import <KSReachability/KSReachability.h>

#import "SLInetTransport.h"
#import "UDLogging.h"

/* Reachability libs:
 https://github.com/tonymillion/Reachability
 https://github.com/belkevich/reachability-ios
 https://github.com/GlennChiu/GCNetworkReachability
 https://github.com/kstenerud/KSReachability
*/

@interface SLInetReach()
{
	//KSReachability* _reach;
}

@property (nonatomic, weak) SLInetTransport* transport;

@end

@implementation SLInetReach

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithTransport:(SLInetTransport*)transport
{
	// Background queue.

	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	
	return self;
}

- (void) dealloc
{
	[self stop];
}

- (void) start
{
	// Background queue.
	
	[self stop];
	
	/*_reach = [KSReachability reachabilityToHost:@"apple.com"];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onReachabilityChanged:)
												 name:kDefaultNetworkReachabilityChangedNotification
											   object:nil];
	
	_reach.notificationName = kDefaultNetworkReachabilityChangedNotification;*/
}

- (void) stop
{
	// Background queue.
	
	/*if(_reach)
	{
		_reach.notificationName = nil;
		_reach = nil;
		
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}*/
}

- (void) onReachabilityChanged:(NSNotification*) notification
{
	// Main thread.
	
	/*KSReachability* reach = (KSReachability*)notification.object;
	
	if(!reach.reachable)
	{
		LogInfo(@"Inet become unreachable.");
		return;
	}
	
	LogInfo(@"Inet become reachable.");
	dispatch_async(_transport.queue, ^{
		[_transport connect];
	}); */
}

@end
