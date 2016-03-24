//
//  UDByteBuf.h
//  Underdark
//
//  Created by Virl on 24/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UDByteBuf : NSObject

@property (nonatomic, readonly, nonnull) NSMutableData* data;
@property (nonatomic, getter=capacity, setter=setCapacity:) NSUInteger capacity;
@property (nonatomic) NSUInteger readerIndex;
@property (nonatomic) NSUInteger writerIndex;
@property (nonatomic, readonly, getter=readableBytes) NSUInteger readableBytes;
@property (nonatomic, readonly, getter=writableBytes) NSUInteger writableBytes;

- (nonnull instancetype) init NS_DESIGNATED_INITIALIZER;

- (void) ensureWritable:(NSUInteger)minWritableBytes;
- (void) trimWritable:(NSUInteger)maxWritableBytes;
- (void) discardReadBytes;

- (nonnull NSData*) bytes:(NSUInteger)offset length:(NSUInteger)length;
- (void) bytes:(NSUInteger)offset dest:(nonnull uint8_t*)dest length:(NSUInteger)length;

- (nonnull NSData*) readBytes:(NSUInteger)length;
- (void) skipBytes:(NSUInteger)length;

- (void) writeData:(nonnull NSData*)data;
- (void) writeBytes:(nonnull uint8_t*)src length:(NSUInteger)length;
- (void) advanceWriterIndex:(NSUInteger)length;

@end
