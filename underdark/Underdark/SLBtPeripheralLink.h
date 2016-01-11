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

@import CoreBluetooth;

#import "SLBluetoothTransport.h"

@class SLBtPeripheral;

@interface SLBtPeripheralLink : NSObject <UDLink>

@property (nonatomic, readonly, weak) SLBtPeripheral* peripheral;

@property (nonatomic) int64_t nodeId;
@property (nonatomic, readonly) bool slowLink;
@property (nonatomic, readonly) int16_t priority;

@property (nonatomic, readonly) CBCentral* central;
@property (nonatomic) SLBtLinkState state;

@property (nonatomic, readonly) NSInteger transferBytes;
@property (nonatomic, readonly) NSTimeInterval transferTime;
@property (nonatomic, readonly) NSInteger transferSpeed;

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithPeripheral:(SLBtPeripheral*)peripheral central:(CBCentral*)central NS_DESIGNATED_INITIALIZER;

- (void) sendFrame:(NSData*)data;
- (void) disconnect;

- (void) clearBuffers;

- (CBATTError) processWriteRequests:(NSArray*)requests;

- (void) retryNotify;

@end
