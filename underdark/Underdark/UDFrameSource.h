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

#import "UDData.h"

typedef void (^UDFrameSourceRetrieveBlock)(NSData* _Nullable data);

@class UDFrameSource;

@protocol UDFrameSourceDelegate <NSObject>

// Called on any thread.
- (void) frameSourceDisposed:(nonnull UDFrameSource*)frameSource;

@end

@interface UDFrameSource : NSObject

@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;
@property (nonatomic, readonly, weak) id<UDFrameSourceDelegate> delegate;

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data queue:(nonnull dispatch_queue_t)queue delegate:(nullable id<UDFrameSourceDelegate>)delegate;

- (void) acquire;
- (void) giveup;

- (void) retrieve:(UDFrameSourceRetrieveBlock _Nonnull)completion;

@end
