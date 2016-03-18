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

@interface UDOutputItem : NSObject

@property (nonatomic) id<UDData> data;
@property (nonatomic) Frame* frame;

- (void) markAsProcessed;

@end
