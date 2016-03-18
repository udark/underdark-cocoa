//
//  UDOutputItem.m
//  Underdark
//
//  Created by Virl on 18/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDOutputItem.h"

@implementation UDOutputItem
{
	bool _processed;
}

- (instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	return self;
}

- (void) dealloc
{
	if(!_processed) {
		[self.data giveup];
	}
}

- (void) markAsProcessed
{
	_processed = true;
	[self.data giveup];
}

@end
