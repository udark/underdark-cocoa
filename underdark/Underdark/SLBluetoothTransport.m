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

#import "SLBluetoothTransport.h"

@import CoreBluetooth;

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDConfig.h"
#import "UDTimeExtender.h"
#import "SLBtCentral.h"
#import "SLBtPeripheral.h"
#import "UDBtBeacon.h"

// Bluetooth in background: http://stackoverflow.com/questions/9896562/what-exactly-can-corebluetooth-applications-do-whilst-in-the-background

@import UIKit;

NSString* serviceUUID = @"771DDBB5-F7F5-4D9C-8A0A-7507A9E504FB";
NSString* charactNodeIdUUID = @"8971EEE6-5D58-470D-93D1-5D549922AFC9";
NSString* charactJackUUID = @"18D8B369-09D6-48C5-9843-413F9569663F";
NSString* charactStreamUUID = @"935D922B-7753-4B0D-8395-325C209E951F";

@interface SLBluetoothTransport()
{
	int32_t _appId;
	
	SLBtCentral* _central;
	SLBtPeripheral* _peripheral;
	UDBtBeacon * _beacon;
	
	UDTimeExtender* _timeExtender;
	bool _willEnterForeground;
}

@end

@implementation SLBluetoothTransport

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithAppId:(int32_t)appId nodeId:(int64_t)nodeId queue:(dispatch_queue_t) queue
{
	// Main thread.
	
	if(!(self = [super init]))
		return self;
	
	_serviceUUID = [CBUUID UUIDWithString:serviceUUID];
	_charactNodeIdUUID = [CBUUID UUIDWithString:charactNodeIdUUID];
	_charactJackUUID = [CBUUID UUIDWithString:charactJackUUID];
	_charactStreamUUID = [CBUUID UUIDWithString:charactStreamUUID];
	
	_nodeId = nodeId;
	_queue = queue;
	
	_timeExtender = [[UDTimeExtender alloc] initWithName:@"UDBluetoothTransport"];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beaconDetected:) name:UDBeaconDetectedNotification object:nil];
	
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self stop];
}

#pragma mark - Launch

- (void) start
{
	if(_running)
		return;
	
	_running = true;
	
	sldispatch_async(dispatch_get_main_queue(), ^{
		_beacon = [[UDBtBeacon alloc] initWithAppId:_appId];
		[_beacon requestPermissions];
	});
	
	_central = [[SLBtCentral alloc] initWithTransport:self];
	_peripheral = [[SLBtPeripheral alloc] initWithTransport:self];
} // start

- (void) stop
{
	if(!_running)
		return;
	
	[self stopScanning];
	[self stopAdvertising];
	[self startMonitoring];
	
	_running = false;
} // stop

- (void) bluetoothReady
{
	if(!_running)
		return;

	if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
	{
		// Background
		[self stopScanning];
		[self stopAdvertising];
		[self startMonitoring];
	}
	else
	{
		// Foreground
		[self stopMonitoring];
		[self scanForShortTime:^{
			if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
				return;
			
			[self startAdvertising];
		}];
	}
} // bluetoothReady

- (void) centralReady
{
	if(_central.ready && _peripheral.ready)
		[self bluetoothReady];
}

- (void) peripheralReady
{
	if(_central.ready && _peripheral.ready)
		[self bluetoothReady];
}

#pragma mark - Application states

- (void)beaconDetected:(NSNotification*)notification
{
	if(!_running)
		return;
	
	// Main thread.
	[_timeExtender extendBackgroundTime];
	
	//[[SLAppModel shared].notify notifyMeshDetected];
	
	sldispatch_async(self.queue, ^{
		LogDebug(@"Beacon detected — scanning.");
		[self scanForShortTime:^{
			
		}];
	});
}

- (void)applicationDidEnterBackground:(NSNotification*)notification
{
	// Main thread.
	
	if(!_running)
		return;
	
	_willEnterForeground = false;
	
	sldispatch_async(self.queue, ^{
		[self stopScanning];
		[self stopAdvertising];
	});
	
	[_beacon startMonitoring];
	
} // applicationDidEnterBackground

- (void)applicationWillEnterForeground:(NSNotification*)notification
{
	// Main thread.
	
	if(!_running)
		return;
	
	_willEnterForeground = true;
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	// Main thread.
	
	if(!_running)
		return;

	if(!_willEnterForeground)
		return;
	
	_willEnterForeground = false;
	
	[_beacon stopMonitoring];
	
	sldispatch_async(self.queue, ^{
		[self scanForShortTime:^{
			if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
				return;
			
			[self startAdvertising];
		}];
	});
} // applicationDidBecomeActive

#pragma mark - Advertising

- (void) advertiseForShortTime:(void (^)())completion
{
	if(self.state == SLBtStateAdvertising)
		return;
	
	[self stopScanning];
	[self startAdvertising];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configBluetoothScanDuration * NSEC_PER_SEC)), self.queue, ^{
		[self stopAdvertising];
		
		if(completion)
			completion();
	});
}

- (void) startAdvertising
{
	sldispatch_async(dispatch_get_main_queue(), ^{
		[_beacon stopMonitoring];
	});
	
	_peripheral.beaconData = _beacon.beaconData;
	[_peripheral startAdvertising];
}

- (void) stopAdvertising
{
	[_peripheral stopAdvertising];
}

- (void) startMonitoring
{
	sldispatch_async(dispatch_get_main_queue(), ^{
		[_beacon startMonitoring];
	});
}

- (void) stopMonitoring
{
	sldispatch_async(dispatch_get_main_queue(), ^{
		[_beacon stopMonitoring];
	});
}

#pragma mark - Scanning

- (void) scanForShortTime:(void (^)())completion;
{
	if(!_running)
		return;
	
	if(self.state == SLBtStateScanning)
		return;
	
	[self stopAdvertising];
	[self startScanning];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configBluetoothScanDuration * NSEC_PER_SEC)), self.queue, ^{
		[self stopScanning];
		
		if(completion)
			completion();
	});
}

- (void) startScanning
{
	[_central startScanning];
}

- (void) stopScanning
{
	[_central stopScanning];
}

#pragma mark - Data

- (NSData*) dataForNodeId
{
	int64_t nodeId = self.nodeId;
	nodeId = CFSwapInt64HostToBig(nodeId);
	
	NSData* data = [NSData dataWithBytes:&nodeId length:sizeof(nodeId)];
	return data;
}

- (int64_t) nodeIdForData:(NSData*)data
{
	int64_t nodeId;
	if(data.length < sizeof(nodeId))
		return 0;
	
	nodeId = *( (int64_t*) data.bytes );
	nodeId = CFSwapInt64BigToHost(nodeId);
	return nodeId;
}

#pragma mark - Notifications

- (void) notifyBluetoothRequired
{
	sldispatch_async(dispatch_get_main_queue(), ^{
	    [[NSNotificationCenter defaultCenter] postNotificationName:UDBluetoothRequiredNotification object:self];
	});
}

@end
