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

#import "UDTimeExtender.h"

#import "UDLogging.h"

@import UIKit;

@interface UDSuspendWrapper : NSObject
@property (nonatomic, weak) id<UDSuspendListener> listener;
@end
@implementation UDSuspendWrapper
@end

static NSMutableArray* udSuspendWrappers;
static dispatch_once_t onceToken;

@interface UDTimeExtender()
{
	UIBackgroundTaskIdentifier _backgroundTaskId;
	NSString* _name;
}
@end

@implementation UDTimeExtender

+ (void) registerListener:(id<UDSuspendListener>)listener
{
	dispatch_once(&onceToken, ^{
		udSuspendWrappers = [NSMutableArray array];
	});
	
	UDSuspendWrapper* wrapper = [[UDSuspendWrapper alloc] init];
	wrapper.listener = listener;
	
	@synchronized(self)
	{
		[udSuspendWrappers addObject:wrapper];
	}
}

+ (void) notifyListeners:(UDTimeExtender*)timeExtender
{
	dispatch_once(&onceToken, ^{
		udSuspendWrappers = [NSMutableArray array];
	});
	
	NSMutableArray* wrappers;
	@synchronized(self)
	{
		wrappers = udSuspendWrappers.mutableCopy;
	}
	
	NSMutableArray* removed = [NSMutableArray array];
	for(UDSuspendWrapper* wrapper in wrappers)
	{
		[wrapper.listener applicationWillSuspend:timeExtender];
		if(wrapper.listener == nil)
			[removed addObject:wrapper];
	}
	
	@synchronized(self)
	{
		[udSuspendWrappers removeObjectsInArray:removed];
	}
}

- (instancetype) init
{
	return [self initWithName:@""];
}

- (instancetype) initWithName:(NSString*)name
{
	if(!(self = [super init]))
		return self;
	
	_backgroundTaskId = UIBackgroundTaskInvalid;
	_name = name;
	if(_name == nil)
		_name = @"";
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
	
	return self;
}

- (void) dealloc
{
	[self cancel];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillEnterForeground:(NSNotification*)notification
{
	[self cancel];
}

- (void) extendBackgroundTime
{
	// Any queue.
	
	//[[self class] notifyListeners:self];
	
	@synchronized(self)
	{
		[self extendInternal];
	}
}

- (void) cancel
{
	// Any queue.
	UIBackgroundTaskIdentifier taskId;
	
	@synchronized(self)
	{
		taskId = _backgroundTaskId;
		_backgroundTaskId = UIBackgroundTaskInvalid;
	}
	
	if(taskId != UIBackgroundTaskInvalid)
	{
		LogDebug(@"bg task canceled");
		[[UIApplication sharedApplication] endBackgroundTask:taskId];
	}
}

- (void) extendInternal
{
	// Any queue.
	
	UIApplication* application = [UIApplication sharedApplication];
	
	if(_backgroundTaskId != UIBackgroundTaskInvalid)
		return;
	
	LogDebug(@"bg task created");
	
	_backgroundTaskId =
	[application beginBackgroundTaskWithName:_name expirationHandler:^{
		
		// Main thread.
		
		[[self class] notifyListeners:self];
		
		UIBackgroundTaskIdentifier taskId;
		
		@synchronized(self)
		{
			LogDebug(@"Background task '%@' expired.", _name);
			
			taskId = _backgroundTaskId;
			_backgroundTaskId = UIBackgroundTaskInvalid;
			
		}
		
		[application endBackgroundTask:taskId];
	}];
}

@end
