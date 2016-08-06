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

@class UDLazySource;

typedef NSData* _Nullable (^UDLazySourceRetriever)(UDLazySource* _Nonnull source);

@interface UDLazySource : NSObject<UDSource>

@property (nonatomic, readonly, nonnull) UDFuture<NSData*, id>* future;
@property (nonatomic, readonly, nullable) NSString* dataId;

- (nonnull instancetype) init NS_UNAVAILABLE;

- (nonnull instancetype) initWithQueue:(nullable dispatch_queue_t)queue
								dataId:(nullable NSString*)dataId
                                 block:(nonnull UDLazySourceRetriever)block NS_DESIGNATED_INITIALIZER;

- (nonnull instancetype) initWithQueue:(nullable dispatch_queue_t)queue
                                 block:(nonnull UDLazySourceRetriever)block;


@end
