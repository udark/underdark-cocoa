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

#ifndef Underdark_UDTransport_h
#define Underdark_UDTransport_h

#import "UDLink.h"

extern NSString* UDBluetoothRequiredNotification;
extern NSString* UDBeaconDetectedNotification;

/**
 * Abstract transport protocol, which can aggregate multiple
 * network communication protocols.
 * All methods of this class must be called via same queue
 * that was supplied when creating its object.
 */
@protocol UDTransport;

/**
 * UDTransport callback delegate.
 * All methods of this interface will be called on UDTransport's queue.
 * @see UDLink
 * @see UDTransport
 */
@protocol UDTransportDelegate <NSObject>

/**
 * Called when transport discovered new device and established connection with it.
 * @param transport transport instance that discovered the device
 * @param link connection object to discovered device
 */
- (void) transport:(id<UDTransport>)transport linkConnected:(id<UDLink>)link;

/**
 * Called when connection to device is closed explicitly from either side
 * or because device is out of range.
 * @param transport transport instance that lost the device
 * @param link connection object to disconnected device
 */
- (void) transport:(id<UDTransport>)transport linkDisconnected:(id<UDLink>)link;

/**
 * Called when new data frame is received from remote device.
 * @param transport transport instance that connected to the device
 * @param link connection object for the device
 * @param frameData frame data received from remote device
 * @see [UDLink sendFrame:]
 */
- (void) transport:(id<UDTransport>)transport link:(id<UDLink>)link didReceiveFrame:(NSData*)frameData;

@end

@protocol UDTransport <NSObject>

@property (nonatomic, readonly) dispatch_queue_t queue;

/**
 * Starts underlying network advertising and discovery.
 * For each call of this method there must be corresponding
 * stop call.
 */
- (void) start;

/**
 * Stops network advertising and discovery
 * and disconnects all links.
 * For each call of this method there must be corresponding
 * start call previously.
 */
- (void) stop;

@end

#endif
