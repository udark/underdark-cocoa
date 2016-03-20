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

@property (nonatomic, nullable) NSData* data;
@property (nonatomic, nullable) UDFrameData* frameData;

- (nonnull instancetype) initWithData:(nonnull NSData*)data frameData:(nullable UDFrameData*)frameData;

@end
