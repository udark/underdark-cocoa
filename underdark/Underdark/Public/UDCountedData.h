//
//  UDCountedData.h
//  Underdark
//
//  Created by Virl on 17/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UDData.h"

@interface UDCountedData : NSObject <UDData>

/**
 * Inits ref counted data object with ref count = 1.
 */
- (instancetype) init NS_DESIGNATED_INITIALIZER;

/**
 * Called automatically when reference count reaches 0.
 * DO NOT call this method manually!.
 */
- (void) dispose;

@end
