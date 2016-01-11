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

#import "UDPacketKind.h"
#import "UDPacket.h"
#import "UDTransport.h"

@protocol UDRouter;

@protocol UDRouterDelegate

@required
- (void) router:(nonnull id<UDRouter>)router peerConnected:(int64_t)peerNodeId;
@required
- (void) router:(nonnull id<UDRouter>)router peerDisconnected:(int64_t)peerNodeId;
@required
- (void) router:(nonnull id<UDRouter>)router didReceivePacket:(nonnull UDPacket*)packet fromPeer:(int64_t)peerNodeId;

@optional
- (void) router:(nonnull id<UDRouter>)router needsAllPacketIdsWithKindId:(int32_t)packetKindId completion:(nonnull void (^)(NSArray<NSNumber*>* _Nonnull packetIds))completion;

@optional
- (void) router:(nonnull id<UDRouter>)router needsPacketWithId:(int64_t)packetId kind:(int32_t)packetKind completion:(nonnull void (^)(UDPacket* _Nullable packet))completion;

@end

@protocol UDRouter

@property (nonatomic, readonly, nonnull) id<UDTransport> transport;
@property (nonatomic, readonly, weak) id<UDRouterDelegate> delegate;

/// Array of peers' nodeIds. Must be accessed only on the same queue as other methods.
@property (nonatomic, readonly, nonnull, getter=peers) NSArray<NSNumber*> *peers;

- (void) registerPacketKind:(nonnull UDPacketKind*)packetKind;
- (void) unregisterPacketKind:(int32_t)packetKindId;

- (void) start;
- (void) stop;

- (void) sendPacketToSelf:(nonnull UDPacket*)packet;
- (void) sendPacketToAll:(nonnull UDPacket*)packet;

@end
