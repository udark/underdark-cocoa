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

#import "UDRunLoopThread.h"
#import "UDNsdLink.h"

@class UDNsdServer;

@protocol UDNsdServerDelegate <NSObject>

- (void) server:(nonnull UDNsdServer*)server linkConnected:(nonnull UDNsdLink*)link;
- (void) server:(nonnull UDNsdServer*)server linkDisconnected:(nonnull UDNsdLink*)link;
- (void) server:(nonnull UDNsdServer*)server link:(nonnull UDNsdLink *)link didReceiveFrame:(nonnull NSData*)frameData;

@end

@interface UDNsdServer : NSObject

@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic) int16_t priority;

@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;
@property (nonatomic, readonly, nonnull) UDRunLoopThread* ioThread;

- (nullable instancetype) init NS_UNAVAILABLE;

- (nullable instancetype) initWithDelegate:(nonnull id<UDNsdServerDelegate>)delegate nodeId:(int64_t)nodeId queue:(nonnull dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (bool) startAccepting;
- (void) stopAccepting;

- (bool) isLinkConnectedToNodeId:(int64_t)nodeId;
- (void) connectToHost:(nonnull NSString*)host port:(uint16_t)port interface:(uint32_t)interfaceIndex;

- (void) linkConnecting:(nonnull UDNsdLink *)link;
- (void) linkConnected:(nonnull UDNsdLink *)link;
- (void) linkDisconnected:(nonnull UDNsdLink *)link;
- (void) linkTerminated:(nonnull UDNsdLink *)link;
- (void) link:(nonnull UDNsdLink *)link didReceiveFrame:(nonnull NSData*)frameData;

@end