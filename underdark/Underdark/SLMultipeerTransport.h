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

#import "UDTransport.h"
#import "UDRunLoopThread.h"

@import MultipeerConnectivity;

@class SLMultipeerLink;

@interface SLMultipeerTransport : NSObject <UDTransport>

@property (nonatomic, weak, nullable) id<UDTransportDelegate> delegate;

@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly, nonnull)	MCPeerID* peerId;
@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;
@property (nonatomic, readonly, nullable) UDRunLoopThread * inputThread;
@property (nonatomic, readonly, nullable) UDRunLoopThread * outputThread;

- (nullable instancetype) init NS_UNAVAILABLE;

- (nullable instancetype) initWithNodeId:(int64_t)nodeId queue:(__nonnull dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (void) start;
- (void) stop;

- (void) restartDiscovery;

- (void) linkConnecting:(SLMultipeerLink* __nonnull)link;
- (void) linkConnected:(SLMultipeerLink* __nonnull)link;
- (void) linkDisconnected:(SLMultipeerLink* __nonnull)link;
- (void) linkTerminated:(SLMultipeerLink* __nonnull)link;

@end
