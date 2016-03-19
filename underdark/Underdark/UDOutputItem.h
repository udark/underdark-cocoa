//
//  UDOutputItem.h
//  Underdark
//
//  Created by Virl on 18/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UDData.h"
#import "Frames.pb.h"

@protocol UDOutputItemDelegate <NSObject>

- (void) outputItemPrepared;
- (void) outputItemFinished;
- (void) outputItemDiscarded;

@end

@interface UDOutputItem : NSObject

@property (nonatomic, readonly, weak) id<UDOutputItemDelegate> delegate;

@property (nonatomic, nullable) NSData* data;

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data queue:(nonnull dispatch_queue_t)queue delegate:(nonnull id<UDOutputItemDelegate>)delegate;

- (void) prepare;

- (void) finish;

@end
