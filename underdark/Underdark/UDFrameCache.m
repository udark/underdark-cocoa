//
//  UDFrameCache.m
//  Underdark
//
//  Created by Virl on 20/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDFrameCache.h"

@interface UDFrameCache() <UDFrameDataDelegate>
{
	dispatch_queue_t _queue;
	NSMutableDictionary<NSString*, UDFrameData*> * _sources;
}
@end

@implementation UDFrameCache

- (nonnull instancetype) initWithQueue:(nonnull dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;
	
	_queue = queue;
	_sources = [NSMutableDictionary dictionary];
	
	return self;
}

- (nonnull UDFrameData*) frameSourceWithData:(nonnull id<UDData>)data
{
	UDFrameData* result;
	
	if(data.dataId == nil) {
		result = [[UDFrameData alloc] initWithData:data queue:_queue delegate:self];
		return result;
	}
	
	result = _sources[data.dataId];
	
	if(result == nil) {
		result = [[UDFrameData alloc] initWithData:data queue:_queue delegate:self];
		_sources[data.dataId] = result;
	}
	
	return result;
}

#pragma mark - UDFrameDataDelegate

- (void) frameDataAcquire:(nonnull UDFrameData*)frameData
{
	
}

- (void) frameDataGiveup:(nonnull UDFrameData*)frameData
{
	
}

@end
