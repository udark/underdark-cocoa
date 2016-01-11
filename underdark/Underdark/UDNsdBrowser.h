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

#import "UDNsdService.h"

@protocol UDNsdBrowserDelegate <NSObject>

- (void) serviceResolved:(UDNsdService*)service;

@end

@interface UDNsdBrowser : NSObject

@property (nonatomic) bool peerToPeer;

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithDelegate:(id<UDNsdBrowserDelegate>)delegate
                          service:(NSString*)serviceType
                            queue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (void) start;
- (void) stop;

- (void) reconfirmRecord:(NSString*)name interface:(uint32_t)interfaceIndex;

@end
