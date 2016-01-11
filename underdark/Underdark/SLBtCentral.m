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

#import "SLBtCentral.h"

@import UIKit;
@import CoreBluetooth;

#import "UDLogging.h"

const int32_t SLBtTransferSizeMax = 512;//18;

@interface SLBtCentral() <CBCentralManagerDelegate>
{
	CBCentralManager* _centralManager;
	
	NSMutableDictionary* _links; // CBPeripheral to CLBtCentralLink
}
@end

@implementation SLBtCentral

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithTransport:(SLBluetoothTransport*) transport
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_links = [NSMutableDictionary dictionary];
	
	NSDictionary* options =
	@{//CBCentralManagerOptionRestoreIdentifierKey: @"SLBtCentral",
	  CBCentralManagerOptionShowPowerAlertKey: @(NO)};
	
	_centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.transport.queue options:options];

	return self;
}

- (void) dealloc
{
	if(_centralManager)
	{
		[_centralManager stopScan];
		_centralManager = nil;
	}
}

#pragma mark - Scanning

- (void) scanIfNecessary
{
	if(self.transport.state != SLBtStateScanning)
		return;
	
	LogDebug(@"Central Scan started");
	
	if(_centralManager.state != CBCentralManagerStatePoweredOn)
		return;
	
	NSArray* services = nil;
	if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
		services = @[self.transport.serviceUUID];
	
	[_centralManager scanForPeripheralsWithServices:services options:@{}];
}

- (void) startScanning
{
	if(!self.transport.running || self.transport.state != SLBtStateIdle)
		return;

	self.transport.state = SLBtStateScanning;
	
	[self scanIfNecessary];
}

- (void) stopScanning
{
	if(_centralManager)
	{
		[_centralManager stopScan];
	}
	
	if(self.transport.state == SLBtStateScanning)
	{
		self.transport.state = SLBtStateIdle;
		LogDebug(@"Central Scan stopped");
	}
}

#pragma mark - Links

- (void) peripheralDiscovered:(CBPeripheral*)peripheral
{
	SLBtCentralLink* link = _links[peripheral];
	if(link && link.state == SLBtLinkStateUnsuitable)
		return;
	
	if(link && link.state == SLBtLinkStateDisconnected)
	{
		[self linkConnecting:link];
		return;
	}
	
	if(link)
	{
		LogWarn(@"central already exist %@", link);
		return;
	}
	
	link = [[SLBtCentralLink alloc] initWithCentral:self peripheral:peripheral];
	_links[peripheral] = link;
	[self linkConnecting:link];
} // peripheralDiscovered

- (void) disconnectLink:(SLBtCentralLink*)link
{
	[_centralManager cancelPeripheralConnection:link.peripheral];
}

- (void) linkConnecting:(SLBtCentralLink*)link
{
	link.state = SLBtLinkStateConnecting;
	[_centralManager connectPeripheral:link.peripheral options:@{}];
}

- (void) linkUnsuitable:(SLBtCentralLink*)link
{
	LogDebug(@"Unsuitable %@", link);
	link.state = SLBtLinkStateUnsuitable;
	[_centralManager cancelPeripheralConnection:link.peripheral];
}

- (void) linkConnected:(SLBtCentralLink*)link
{
	link.state = SLBtLinkStateConnected;
	LogDebug(@"Connected %@", link);
	[self.transport.delegate transport:self.transport linkConnected:link];
}

- (void) linkDisconnected:(SLBtCentralLink*)link error:(NSError*)error
{
	if(error)
	{
		LogDebug(@"central didDisconnectPeripheral: %@", error);
	}
	else
	{
		LogDebug(@"Disconnected %@", link);
	}
	
	SLBtLinkState state = link.state;
	if(state == SLBtLinkStateUnsuitable)
		return;

	link.state = SLBtLinkStateDisconnected;
	[link clearBuffers];
	
	if(state == SLBtLinkStateConnected)
		[self.transport.delegate transport:self.transport linkDisconnected:link];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	if(central.state == CBCentralManagerStatePoweredOn)
	{
		LogDebug(@"CBCentralManagerStatePoweredOn");
		
		[self scanIfNecessary];
		
		_ready = true;
		[self.transport centralReady];
		
		return;
	}
	
	if(central.state == CBCentralManagerStatePoweredOff)
	{
		LogDebug(@"CBCentralManagerStatePoweredOff");
		
		[self.transport notifyBluetoothRequired];
		return;
	}
	
	if(central.state == CBCentralManagerStateUnknown)
	{
		LogDebug(@"CBCentralManagerStateUnknown");
		return;
	}
	
	if(central.state == CBCentralManagerStateResetting)
	{
		LogDebug(@"CBCentralManagerStateResetting");
		return;
	}
	
	if(central.state == CBCentralManagerStateUnsupported)
	{
		LogDebug(@"CBCentralManagerStateUnsupported");
		
		[self.transport notifyBluetoothRequired];
		return;
	}
	
	if(central.state == CBCentralManagerStateUnauthorized)
	{
		LogDebug(@"CBCentralManagerStateUnauthorized");
		
		[self.transport notifyBluetoothRequired];
		return;
	}
} // centralManagerDidUpdateState

/*- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict
{
	LogDebug(@"central willRestoreState");
	
	NSArray* peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
	if(peripherals)
	{
		for(CBPeripheral* peripheral in peripherals)
		{
			[self peripheralDiscovered:peripheral];
		}
	}
} // willRestoreState*/

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
	LogDebug(@"centralManager didRetrievePeripherals");
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
	LogDebug(@"centralManager didRetrieveConnectedPeripherals");
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	//LogDebug(@"centralManager didDiscoverPeripheral '%@'", peripheral.name);
	
	//NSArray *overflowServiceUUIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey];
	
	[self peripheralDiscovered:peripheral];
} // didDiscoverPeripheral

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
	//LogDebug(@"centralManager didConnectPeripheral");
	
	SLBtCentralLink* link = _links[peripheral];
	
	[link onPeripheralConnected];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	LogDebug(@"centralManager didFailToConnectPeripheral");
	
	SLBtCentralLink* link = _links[peripheral];
	
	[self linkDisconnected:link error:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	SLBtCentralLink* link = _links[peripheral];
	[self linkDisconnected:link error:error];
}

@end
