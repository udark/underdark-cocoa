//
//  UDOutputItem.m
//  Underdark
//
//  Created by Virl on 18/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDOutputItem.h"

#import "UDAsyncUtils.h"

@implementation UDOutputItem
{
}

+ (nonnull UDOutputItem*) ending
{
	return [[UDOutputItem alloc] init];
}

- (nonnull instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	return self;
}

- (nonnull instancetype) initWithData:(nullable NSData*)data frameData:(nullable UDFrameData*)frameData
{
	if(!(self = [super init]))
		return self;
	
	_data = data;
	_frameData = frameData;
	
	[frameData acquire];

	return self;
}

- (void) dealloc
{
	[_frameData giveup];
}

- (bool) isEnding
{
	return _data == nil && _frameData == nil;
}

@end
