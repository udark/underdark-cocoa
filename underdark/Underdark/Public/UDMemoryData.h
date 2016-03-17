//
//  UDMemoryData.h
//  Underdark
//
//  Created by Virl on 17/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UDData.h"

@interface UDMemoryData : NSObject<UDData>

- (instancetype) initWithData:(NSData*)data;

@end
