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

@class SLBtCentral;

@interface SLBtCentralLink : NSObject <UDLink>

@property (nonatomic, readonly, weak) SLBtCentral* central;

@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly) int16_t priority;
@property (nonatomic, readonly) bool slowLink;

@property (nonatomic, readonly) NSInteger transferBytes;
@property (nonatomic, readonly) NSTimeInterval transferTime;
@property (nonatomic, readonly) NSInteger transferSpeed;

@property (nonatomic, readonly) CBPeripheral* peripheral;
@property (nonatomic) SLBtLinkState state;

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithCentral:(SLBtCentral*)central peripheral:(CBPeripheral*)peripheral NS_DESIGNATED_INITIALIZER;

- (void) onPeripheralConnected;

- (void) sendFrame:(NSData*)data;
- (void) disconnect;

- (void) clearBuffers;

@end
