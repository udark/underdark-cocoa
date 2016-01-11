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

#import "UDRunLoopThread.h"

@interface UDRunLoopThread ()
{
	dispatch_group_t _waitGroup;
	NSRunLoop* _runLoop;
	CFRunLoopRef _cfRunLoop;
}
@end

@implementation UDRunLoopThread

- (instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	_waitGroup = dispatch_group_create();
	dispatch_group_enter(_waitGroup);
	
	return self;
}

- (void) dealloc
{
	if(_cfRunLoop != NULL)
	{
		CFRelease(_cfRunLoop);
		_cfRunLoop = NULL;
	}
}

- (void) cancel
{
	dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
	[super cancel];
	
	if(_coreFoundation)
	{
		CFRunLoopStop(_cfRunLoop);
	}
	else
	{
		[self performSelector:@selector(noop) onThread:self withObject:nil waitUntilDone:NO];
	}
}

- (void) noop
{
}

- (NSRunLoop*) runLoop
{
	dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
	return _runLoop;
}

- (CFRunLoopRef) cfRunLoop
{
	dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
	return _cfRunLoop;
}

- (void) main
{
	if(_coreFoundation)
	{
		[self mainCoreFoundation];
	}
	else
	{
		[self mainCocoa];
	}
} // main

- (void) mainCoreFoundation
{
	@autoreleasepool
	{
		_cfRunLoop = CFRunLoopGetCurrent();
		CFRetain(_cfRunLoop);
		
		dispatch_group_leave(_waitGroup);
		
		CFRunLoopTimerRef timer =
		CFRunLoopTimerCreate(kCFAllocatorDefault, [[NSDate distantFuture] timeIntervalSinceReferenceDate], 0.0, 0, 0, NULL, NULL);
		
		CFRunLoopAddTimer(_cfRunLoop, timer, kCFRunLoopDefaultMode);
		CFRelease(timer);
		
		while (![NSThread currentThread].isCancelled)
		{
			@autoreleasepool
			{
				SInt32 result =
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, [[NSDate distantFuture] timeIntervalSinceNow], true);
				
				if(result != kCFRunLoopRunHandledSource)
					break;
			}
		}
	}
} // mainCoreFoundation

- (void) mainCocoa
{
	@autoreleasepool
	{
		_runLoop = [NSRunLoop currentRunLoop];
		dispatch_group_leave(_waitGroup);
		
		NSObject* obj = [[NSObject alloc] init];
		
		NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture] interval:0.0 target:obj selector:@selector(description) userInfo:nil repeats:NO];
		[_runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
		
		while (![NSThread currentThread].isCancelled)
		{
			@autoreleasepool
			{
				if( ![_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:30]] )
					break;
			}
		}
	}
} // mainCocoa

@end
