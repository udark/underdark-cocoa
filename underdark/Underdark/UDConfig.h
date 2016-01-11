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

extern const NSTimeInterval configNsdResolveTimeout;

extern const NSTimeInterval configBonjourHeartbeatInterval;
extern const NSTimeInterval configBonjourTimeoutInterval;

extern const NSTimeInterval	configBluetoothScanDuration;
extern const NSTimeInterval	configBluetoothAdvertiseDuration;
extern const NSTimeInterval	configBluetoothBeaconDuration;

extern const NSInteger		configLinkSlowSpeedLimit;
extern const NSInteger		configLinkTestSignalSize;

@interface UDConfig : NSObject

@end
