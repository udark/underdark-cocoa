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

#import "UDTransport.h"

@class SLBtCentralLink;
@class SLBtPeripheralLink;

typedef NS_ENUM(NSUInteger, SLBtState)
{
	SLBtStateIdle,
	SLBtStateAdvertising,
	SLBtStateScanning
};

typedef NS_ENUM(NSUInteger, SLBtLinkState)
{
	SLBtLinkStateConnecting,
	SLBtLinkStateUnsuitable,
	SLBtLinkStateConnected,
	SLBtLinkStateDisconnected
};

@interface SLBluetoothTransport : NSObject <UDTransport>

@property (nonatomic, weak) id<UDTransportDelegate> delegate;
@property (nonatomic, readonly) bool isConnecting;

@property (nonatomic, readonly) int64_t nodeId;
@property (nonatomic, readonly) dispatch_queue_t queue;

@property (nonatomic, readonly) bool running;
@property (nonatomic)			SLBtState state;

@property (nonatomic, readonly)	CBUUID* serviceUUID;
@property (nonatomic, readonly)	CBUUID* charactNodeIdUUID;
@property (nonatomic, readonly)	CBUUID* charactJackUUID;
@property (nonatomic, readonly)	CBUUID* charactStreamUUID;

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithAppId:(int32_t)appId nodeId:(int64_t)nodeId queue:(dispatch_queue_t) queue NS_DESIGNATED_INITIALIZER;

- (void) start;
- (void) stop;

- (void) centralReady;
- (void) peripheralReady;

- (void) startAdvertising;
- (void) stopAdvertising;
- (void) startScanning;
- (void) stopScanning;

- (NSData*) dataForNodeId;
- (int64_t) nodeIdForData:(NSData*)data;

- (void) notifyBluetoothRequired;

@end
