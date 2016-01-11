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

#import "UDConfig.h"

const NSTimeInterval configNsdResolveTimeout = 20;

const NSTimeInterval configBonjourHeartbeatInterval = 2;
const NSTimeInterval configBonjourTimeoutInterval = 7;

const NSTimeInterval	configBluetoothScanDuration = 4;			// How long scan for Bluetooth peers.
const NSTimeInterval	configBluetoothAdvertiseDuration = 10;		// How long to advertise before switching to iBeacon.
const NSTimeInterval	configBluetoothBeaconDuration = 2;			// How long advertise iBeacon before switching to advertisement.

const NSInteger			configLinkSlowSpeedLimit = 128 * 1024;		// Below that limit (bytes/sec) link is considered slow.
const NSInteger			configLinkTestSignalSize = 128 * 1024;		// Speed test signal size.

@implementation UDConfig

@end
