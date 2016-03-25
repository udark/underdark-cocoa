//
//  UDFrameCache.h
//  Underdark
//
//  Created by Virl on 20/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UDFrameData.h"
#import "UDSource.h"

@interface UDFrameCache : NSObject

- (nonnull instancetype) initWithQueue:(nonnull dispatch_queue_t)queue;

- (nonnull UDFrameData*) frameDataWithData:(nonnull id<UDSource>)data;

@end
