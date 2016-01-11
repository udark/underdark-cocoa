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

#import "UDRouter.h"
#import "UDTransport.h"
#import "UDPacket.h"

@interface UDRouterImpl : NSObject <UDRouter, UDTransportDelegate>

@property (nonatomic, readonly, nonnull) id<UDTransport> transport;
@property (nonatomic, readonly, weak) id<UDRouterDelegate> delegate;

@property (nonatomic, readonly, nonnull, getter=peers) NSArray<NSNumber*> *peers;

- (nullable instancetype) initWithTransport:(nonnull id<UDTransport>)transport delegate:(nullable id<UDRouterDelegate>) delegate;

- (void) sendPacketToSelf:(nonnull UDPacket*)packet;
- (void) sendPacketToAll:(nonnull UDPacket*)packet;

@end
