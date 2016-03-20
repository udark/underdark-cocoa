//
//  UDFrameCache.m
//  Underdark
//
//  Created by Virl on 20/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDFrameCache.h"

@interface UDFrameCache()
{
	dispatch_queue_t _queue;
}
@end

@implementation UDFrameCache

- (nonnull instancetype) initWithQueue:(nonnull dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;
	
	_queue = queue;
	
	return self;
}

- (nonnull UDFrameSource*) frameSourceWithData:(nonnull id<UDData>)data
{
	UDFrameSource* result;
	
	if(data.dataId == nil) {
		result = [[UDFrameSource alloc] initWithData:data queue:_queue delegate:nil];
		return result;
	}
	
	return nil;
}

@end
