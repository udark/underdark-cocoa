//
//  UDByteBuf.m
//  Underdark
//
//  Created by Virl on 24/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDByteBuf.h"

@interface UDByteBuf()
{
}
@end

@implementation UDByteBuf

#pragma mark - Initialization

- (nonnull instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	_data = [[NSMutableData alloc] init];
	
	return self;
}

#pragma mark - Properties

- (NSUInteger) capacity
{
	return _data.length;
}

- (void) setCapacity:(NSUInteger)ncapacity
{
	if(ncapacity < _writerIndex)
		return;
	
	_data.length = ncapacity;
}

- (NSUInteger) readableBytes
{
	return _writerIndex - _readerIndex;
}

- (NSUInteger) writableBytes
{
	return self.capacity - _writerIndex;
}

#pragma mark - Methods

- (void) ensureWritable:(NSUInteger)minWritableBytes
{
	if(self.capacity - _writerIndex >= minWritableBytes)
		return;
	
	self.capacity = _writerIndex + minWritableBytes;
}

- (void) discardReadBytes
{
	[_data replaceBytesInRange:NSMakeRange(0, _readerIndex) withBytes:NULL length:0];
	_writerIndex -= _readerIndex;
	_readerIndex = 0;
}


@end
