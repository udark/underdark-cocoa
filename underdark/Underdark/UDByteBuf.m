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

- (void) trimWritable:(NSUInteger)maxWritableBytes
{
	if(self.capacity - _writerIndex <= maxWritableBytes)
		return;
	
	self.capacity = _writerIndex + maxWritableBytes;
}

- (void) discardReadBytes
{
	[_data replaceBytesInRange:NSMakeRange(0, _readerIndex) withBytes:NULL length:0];
	_writerIndex -= _readerIndex;
	_readerIndex = 0;
}

- (nonnull NSData*) bytes:(NSUInteger)offset length:(NSUInteger)length
{
	NSAssert(offset < _data.length - _writerIndex, @"offset >= capacity");
	NSAssert(offset + length <= _data.length, @"offset + length > capacity");
	
	return [_data subdataWithRange:NSMakeRange(offset, length)];
}

- (void) bytes:(NSUInteger)offset dest:(nonnull uint8_t*)dest length:(NSUInteger)length
{
	NSAssert(dest != nil, @"dest == nil");
	NSAssert(offset < _data.length, @"offset >= capacity");
	NSAssert(offset + length <= _data.length, @"offset + length > capacity");

	[_data getBytes:dest range:NSMakeRange(offset, length)];
}

- (nonnull NSData*) readBytes:(NSUInteger)length
{
	NSAssert(length <= self.readableBytes, @"length > readableBytes");
	
	NSData* result = [_data subdataWithRange:NSMakeRange(_readerIndex, length)];
	_readerIndex += length;
	
	return result;
}

- (void) skipBytes:(NSUInteger)length
{
	NSAssert(length <= self.readableBytes, @"length > readableBytes");
	_readerIndex += length;
}

- (void) writeData:(nonnull NSData*)data
{
	[self ensureWritable:data.length];
	[_data replaceBytesInRange:NSMakeRange(_writerIndex, data.length) withBytes:data.bytes length:data.length];
	_writerIndex += data.length;
}

- (void) writeBytes:(nonnull uint8_t*)src length:(NSUInteger)length
{
	[self ensureWritable:length];
	[_data replaceBytesInRange:NSMakeRange(_writerIndex, length) withBytes:src length:length];
	_writerIndex += length;
}

- (void) advanceWriterIndex:(NSUInteger)length
{
	NSAssert(_writerIndex + length <= _data.length, @"_writerIndex + length > capacity");
	_writerIndex += length;
}

@end
