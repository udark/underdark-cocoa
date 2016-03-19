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

@property (nonatomic, nullable) NSData* data;

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data;

- (void) prepare;

- (void) finish;

@end
