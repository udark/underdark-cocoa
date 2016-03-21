//
//  UDOutputItem.h
//  Underdark
//
//  Created by Virl on 18/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UDFrameData.h"

@interface UDOutputItem : NSObject

@property (nonatomic, readonly, nullable) NSData* data;
@property (nonatomic, readonly, nullable) UDFrameData* frameData;

@property (nonatomic, readonly, getter=isEnding) bool isEnding;

+ (nonnull UDOutputItem*) ending;

- (nonnull instancetype) initWithData:(nullable NSData*)data frameData:(nullable UDFrameData*)frameData;

@end
