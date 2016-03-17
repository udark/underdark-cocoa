//
//  UDCountedData.m
//  Underdark
//
//  Created by Virl on 17/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDCountedData.h"

@implementation UDCountedData
{
	int32_t _refCount;
	NSObject* _refCountLock;
}

- (instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	_refCount = 0;
	_refCountLock = [[NSObject alloc] init];
	
	return self;
}

#pragma mark - UDData

- (void) acquire
{
	@synchronized(_refCountLock) {
		_refCount++;
	}
}

- (void) giveup
{
	@synchronized(_refCountLock) {
		_refCount--;
		assert(_refCount >= 0);
		
		if(_refCount == 0) {
			[self dispose];
		}
	}
}

- (void) retrieve:(UDDataRetrieveBlock _Nonnull)completion
{
	
}

- (void) dispose
{
	
}

@end
