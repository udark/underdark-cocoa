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

#include <dns_sd.h>

@class UDNsdService;
@class UDRunLoopThread;

@protocol UDNsdServiceDelegate <NSObject>

- (void) serviceDidResolve:(UDNsdService*)service;
- (void) serviceDidNotResolve:(UDNsdService *)service;

@end

@interface UDNsdService : NSObject

@property (nonatomic) bool peerToPeer;

@property (nonatomic) DNSServiceFlags flags;
@property (nonatomic) uint32_t interfaceIndex;
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* regtype;
@property (nonatomic) NSString* domain;

@property (nonatomic, readonly) NSString* host;
@property (nonatomic, readonly) NSString* address;
@property (nonatomic, readonly) int port;

- (instancetype) initWithDelegate:(id<UDNsdServiceDelegate>)delegate thread:(UDRunLoopThread*)thread;

- (void) resolve;
- (void) cancelResolve;

@end
