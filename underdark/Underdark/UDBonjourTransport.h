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

@class UDBonjourLink;

@interface UDBonjourTransport : NSObject <UDTransport>

@property (nonatomic, readonly) int32_t appId;
@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly, nonnull) NSString* serviceType;
@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;

@property (nonatomic) bool peerToPeer;

@property (nonatomic, readonly, nullable) UDRunLoopThread * ioThread;

- (nullable instancetype) init NS_UNAVAILABLE;

- (nullable instancetype) initWithAppId:(int32_t)appId
								 nodeId:(int64_t)nodeId
					   delegate:(id<UDTransportDelegate> __nonnull)delegate
						  queue:(dispatch_queue_t __nonnull)queue
					 peerToPeer:(bool)peerToPeer NS_DESIGNATED_INITIALIZER;

- (void) start;
- (void) stop;

- (void) browserDidFail;
- (void) serverDidFail;

- (int64_t) linkPriority;

- (bool) shouldConnectToNodeId:(int64_t)nodeId;

- (void) linkConnecting:(UDBonjourLink * __nonnull)link;
- (void) linkConnected:( UDBonjourLink * __nonnull)link;
- (void) linkDisconnected:(UDBonjourLink * __nonnull)link;
- (void) linkTerminated:(UDBonjourLink * __nonnull)link;

- (void) link:(UDBonjourLink * __nonnull)link receivedFrame:(NSData* __nonnull)frameData;

@end
