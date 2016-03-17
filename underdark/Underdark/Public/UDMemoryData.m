//
//  UDMemoryData.m
//  Underdark
//
//  Created by Virl on 17/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDMemoryData.h"

@implementation UDMemoryData
{
	 NSData* _Nullable _data;
}

#pragma mark - Initialization

- (instancetype) initWithData:(NSData*)data
{
	if(!(self = [super init]))
		return self;
	
	_data = data;
	
	return self;
}

#pragma mark - UDData
- (void) retrieve:(void (^ _Nonnull)( NSData* _Nullable  data) )completion
{
	completion(_data);
}

- (void) dispose
{
	_data = nil;
}


@end
