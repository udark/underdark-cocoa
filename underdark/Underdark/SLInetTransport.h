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

@class SLInetLink;

@interface SLInetTransport : NSObject <UDTransport>

@property (nonatomic, weak) id<UDTransportDelegate> delegate;

@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) bool isConnecting;

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithNodeId:(int64_t)nodeId queue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (void) start;
- (void) stop;

- (void) connect;

- (void) link:(SLInetLink*)link sentFrame:(NSData*)frameData;

@end
