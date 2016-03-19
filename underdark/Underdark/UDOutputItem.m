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
	id<UDData> _Nonnull _source;
}

- (nonnull instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	return self;
}

- (void) dealloc
{
	[_source giveup];
}

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data
{
	if(!(self = [super init]))
		return self;
	
	_source = data;
	
	[_source acquire];

	return self;
}

- (void) prepare
{
	// Queue.
	
	[_source retrieve:^(NSData * _Nullable data) {
		// Any thread.
		if(data == nil)
		{
			return;
		}
		
		_data = data;
	}];
}

@end
