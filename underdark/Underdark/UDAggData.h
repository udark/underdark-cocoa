/*
 * Copyright (c) 2016 Vladimir L. Shabanov <virlof@gmail.com>
 *
 * Licensed under the Underdark License, Version 1.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://underdark.io/LICENSE.txt
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "UDCountedData.h"
#import "UDLink.h"

@class UDAggData;
@class UDAggLink;

@protocol UDAggDataDelegate <NSObject>

// Called on any thread.
- (void) dataDisposed:(nonnull UDAggData*)data;

@end

@interface UDAggData : UDCountedData

@property (nonatomic, weak) id<UDAggDataDelegate> delegate;
@property (nonatomic, weak) UDAggLink* link;

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data delegate:(nullable id<UDAggDataDelegate>)delegate;

@end
