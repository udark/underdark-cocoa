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

#import "UDAdapter.h"
#import "UDRunLoopThread.h"

@class UDBonjourChannel;

@interface UDBonjourAdapter : NSObject <UDAdapter>

@property (nonatomic, readonly) int32_t appId;
@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly, nonnull) NSString* serviceType;
@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;

@property (nonatomic, readonly) bool peerToPeer;

@property (nonatomic, readonly, nullable) UDRunLoopThread * ioThread;

@property (nonatomic, readonly) int16_t linkPriority;

- (nonnull instancetype) init NS_UNAVAILABLE;

- (nonnull instancetype) initWithAppId:(int32_t)appId
								 nodeId:(int64_t)nodeId
					   delegate:(nonnull id<UDAdapterDelegate>)delegate
						  queue:(nonnull dispatch_queue_t)queue
					 peerToPeer:(bool)peerToPeer NS_DESIGNATED_INITIALIZER;

- (void) start;
- (void) stop;

- (void) browserDidFail;
- (void) serverDidFail;

- (bool) shouldConnectToNodeId:(int64_t)nodeId;

- (void) channelConnecting:(nonnull UDBonjourChannel*)channel;
- (void) channelConnected:(nonnull UDBonjourChannel*)channel;
- (void) channelDisconnected:(nonnull UDBonjourChannel*)channel;
- (void) channelTerminated:(nonnull UDBonjourChannel*)channel;

- (void) channelCanSendMore:(nonnull UDBonjourChannel*)channel;
- (void) channel:(nonnull UDBonjourChannel*)channel receivedFrame:(nonnull NSData*)frameData;

@end
