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

#import "UDSource.h"

typedef void (^UDFrameSourceRetrieveBlock)(NSData* _Nullable data);

@class UDFrameData;

@protocol UDFrameDataDelegate<NSObject>

- (void) frameDataAcquire:(nonnull UDFrameData*)frameData;
- (void) frameDataGiveup:(nonnull UDFrameData*)frameData;

@end

@interface UDFrameData : NSObject

@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;
@property (nonatomic, readonly, weak, nullable) id<UDFrameDataDelegate> delegate;

@property (nonatomic, readonly, nonnull) id<UDSource> data;

- (nonnull instancetype) initWithData:(nonnull id<UDSource>)data queue:(nonnull dispatch_queue_t)queue delegate:(nullable id<UDFrameDataDelegate>)delegate;

- (void) acquire;
- (void) giveup;

- (void) dispose;

- (void) retrieve:(UDFrameSourceRetrieveBlock _Nonnull)completion;

@end
