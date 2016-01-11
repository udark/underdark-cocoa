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

#import "SLBtPeripheral.h"

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDConfig.h"

@interface SLBtPeripheral() <CBPeripheralManagerDelegate>
{
	CBPeripheralManager* _peripheralManager;
	
	NSMutableDictionary* _links; // CBCentral to SLBtPeripheralLink
	bool _serviceAdded;
	bool _beaconAdvertised;
}

@property (nonatomic, readonly) CBMutableCharacteristic* charactNodeId;
@property (nonatomic, readonly) CBMutableCharacteristic* charactStream;

@end

@implementation SLBtPeripheral

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithTransport:(SLBluetoothTransport*)transport
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_links = [NSMutableDictionary dictionary];
	
	NSDictionary* options =
	@{//CBPeripheralManagerOptionRestoreIdentifierKey: @"SLBtPeripheral",
	  CBPeripheralManagerOptionShowPowerAlertKey: @(NO)};
	
	_peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.transport.queue options:options];
	
	//[self startScanning];
	
	return self;
}

- (void) dealloc
{
	if(_peripheralManager)
	{
		_peripheralManager.delegate = nil;
		_peripheralManager = nil;
	}
}

#pragma mark - Scan & Advertise

- (void) advertiseIfNecessary
{
	if(self.transport.state != SLBtStateAdvertising)
		return;
	
	if(!_peripheralManager
	   || !_serviceAdded
	   || _peripheralManager.state != CBPeripheralManagerStatePoweredOn
	   || _peripheralManager.isAdvertising)
		return;
	
	LogDebug(@"Peripheral Advertise Started");
	[self switchAdvertising];
}

- (void) switchAdvertising
{
	if(self.transport.state != SLBtStateAdvertising)
		return;
	
	[_peripheralManager stopAdvertising];

	_beaconAdvertised = !_beaconAdvertised;

	if(_beaconAdvertised)
	{
		//LogDebug(@"Peripheral Switch Beacon");
		
		if(self.beaconData)
			[_peripheralManager startAdvertising:self.beaconData];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configBluetoothBeaconDuration * NSEC_PER_SEC)), self.transport.queue, ^{
			
			[self switchAdvertising];
		});
	}
	else
	{
		//LogDebug(@"Peripheral Switch Advertise");

		NSDictionary* data =
		@{CBAdvertisementDataLocalNameKey: @(self.transport.nodeId).description,
		  CBAdvertisementDataServiceUUIDsKey: @[self.transport.serviceUUID]};
		
		[_peripheralManager startAdvertising:data];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configBluetoothAdvertiseDuration * NSEC_PER_SEC)), self.transport.queue, ^{
			
			[self switchAdvertising];
		});
	}
} // switchAdvertising

- (void) startAdvertising
{
	if(!self.transport.running || self.transport.state != SLBtStateIdle)
		return;
	
	self.transport.state = SLBtStateAdvertising;
	_beaconAdvertised = false;
	
	[self advertiseIfNecessary];
}

- (void) stopAdvertising
{
	if(self.transport.state == SLBtStateAdvertising)
		self.transport.state = SLBtStateIdle;
	
	if(_peripheralManager && _peripheralManager.isAdvertising)
	{
		LogDebug(@"Peripheral Advertise stopped");
		[_peripheralManager stopAdvertising];
	}
}

#pragma mark - Service

- (void) addService
{
	[_peripheralManager removeAllServices];
	
	CBMutableService* service = [[CBMutableService alloc] initWithType:self.transport.serviceUUID primary:YES];
	
	CBMutableCharacteristic* charactNodeId = [[CBMutableCharacteristic alloc] initWithType:self.transport.charactNodeIdUUID properties:(CBCharacteristicPropertyRead) value:self.transport.dataForNodeId permissions:(CBAttributePermissionsReadable)];
	CBMutableDescriptor* descNodeId = [[CBMutableDescriptor alloc] initWithType:[CBUUID UUIDWithString:CBUUIDCharacteristicUserDescriptionString] value:@"nodeId"];
	charactNodeId.descriptors = @[descNodeId];

	CBMutableCharacteristic* charactJack = [[CBMutableCharacteristic alloc] initWithType:self.transport.charactJackUUID properties:(CBCharacteristicPropertyWrite) value:nil permissions:(CBAttributePermissionsWriteable)];
	CBMutableDescriptor* descJack = [[CBMutableDescriptor alloc] initWithType:[CBUUID UUIDWithString:CBUUIDCharacteristicUserDescriptionString] value:@"jack"];
	charactJack.descriptors = @[descJack];

	
	CBMutableCharacteristic* charactStream = [[CBMutableCharacteristic alloc] initWithType:self.transport.charactStreamUUID properties:(CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite | CBCharacteristicPropertyIndicate) value:nil permissions:(CBAttributePermissionsReadable | CBAttributePermissionsWriteable)];
	CBMutableDescriptor* descStream = [[CBMutableDescriptor alloc] initWithType:[CBUUID UUIDWithString:CBUUIDCharacteristicUserDescriptionString] value:@"stream"];
	charactStream.descriptors = @[descStream];
	
	service.characteristics = @[charactNodeId, charactJack, charactStream];
	_charactNodeId = charactNodeId;
	_charactStream = charactStream;
	
	[_peripheralManager addService:service];
}

- (void) removeService
{
	[_peripheralManager removeAllServices];
	_serviceAdded = false;
}

#pragma mark - Links

- (void) linkConnecting:(SLBtPeripheralLink*)link
{
	link.state = SLBtLinkStateConnecting;
}

- (void) linkConnected:(SLBtPeripheralLink*)link
{
	link.state = SLBtLinkStateConnected;
	LogDebug(@"Connected %@", link);
	[self.transport.delegate transport:self.transport linkConnected:link];
}

- (void) linkDisconnected:(SLBtPeripheralLink*)link
{
	SLBtLinkState state = link.state;
	if(state == SLBtLinkStateUnsuitable)
		return;

	LogDebug(@"Disconnected %@", link);
	
	link.state = SLBtLinkStateDisconnected;
	[link clearBuffers];

	if(state == SLBtLinkStateConnected)
		[self.transport.delegate transport:self.transport linkDisconnected:link];
}

- (bool) link:(SLBtPeripheralLink*)link bytesAvailable:(NSData*)data
{
	return [_peripheralManager updateValue:data forCharacteristic:self.charactStream onSubscribedCentrals:@[link.central]];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	if(peripheral.state == CBPeripheralManagerStatePoweredOn)
	{
		LogDebug(@"CBPeripheralManagerStatePoweredOn");
		
		[self addService];
		
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStatePoweredOff)
	{
		LogDebug(@"CBPeripheralManagerStatePoweredOff");
		
		[self removeService];
		
		[self.transport notifyBluetoothRequired];
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateUnknown)
	{
		LogDebug(@"CBPeripheralManagerStateUnknown");
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateResetting)
	{
		LogDebug(@"CBPeripheralManagerStateResetting");
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateUnsupported)
	{
		//LogError(@"CBPeripheralManagerStateUnsupported");
		
		[self.transport notifyBluetoothRequired];
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateUnauthorized)
	{
		LogError(@"CBPeripheralManagerStateUnauthorized");
		
		[self.transport notifyBluetoothRequired];
		return;
	}
} // peripheralManagerDidUpdateState

/*- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict
{
	LogDebug(@"peripheral willRestoreState");
	
	NSArray* services = dict[CBPeripheralManagerRestoredStateServicesKey];
	NSDictionary* advdata = dict[CBPeripheralManagerRestoredStateAdvertisementDataKey];
}*/

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
	if(error)
	{
		LogError(@"peripheralManager didAddService failed: %@", error);
		return;
	}
	
	//LogDebug(@"peripheralManager didAddService");
	
	_serviceAdded = true;
	_ready = true;
	
	[self advertiseIfNecessary];
	[self.transport peripheralReady];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
	if(error)
	{
		LogError(@"peripheralManager didStartAdvertising failed: %@", error);
		return;
	}
	
	//LogDebug(@"peripheralManager didStartAdvertising");
	
} //peripheralManagerDidStartAdvertising

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
	LogDebug(@"peripheral didSubscribeToCharacteristic");

	if([characteristic.UUID isEqual:self.transport.charactStreamUUID])
	{
		SLBtPeripheralLink* link = _links[central];
		if(!link)
			return;
		
		if(link.state != SLBtLinkStateConnecting)
			return;
		
		[self linkConnected:link];
		
		return;
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
	SLBtPeripheralLink* link = _links[central];
	if(!link)
	{
		LogWarn(@"didUnsubscribeFromCharacteristic: no link for central %p", central);
		return;
	}
	
	LogDebug(@"peripheral didUnsubscribeFromCharacteristic");
	[self linkDisconnected:link];
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
	//LogDebug(@"peripheralManagerIsReadyToUpdateSubscribers");
	for(SLBtPeripheralLink* link in _links.allValues)
	{
		if(link.state != SLBtLinkStateConnected)
			continue;
		
		[link retryNotify];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
	//LogDebug(@"peripheralManager didReceiveReadRequest");
	
	if([request.characteristic.UUID isEqual:self.transport.charactNodeIdUUID])
	{
		LogDebug(@"Peripheral readRequest nodeId");
		
		if (request.offset > self.charactNodeId.value.length)
		{
			[peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
			return;
		}
		
		request.value = [self.charactNodeId.value subdataWithRange:NSMakeRange(request.offset, self.charactNodeId.value.length - request.offset)];
		
		[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
		return;
	}
} // didReceiveReadRequest

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
	// Нужно отвечать только на первый request чтобы ответить на все.
	
	CBATTRequest* request = [requests firstObject];
	
	if([request.characteristic.UUID isEqual:self.transport.charactJackUUID])
	{
		SLBtPeripheralLink* link = _links[request.central];
		if(link && link.state != SLBtLinkStateDisconnected)
		{
			LogWarn(@"didReceiveWriteRequests nodeId: %p already present in links", request.central);
			return;
		}

		int64_t nodeId = [self.transport nodeIdForData:request.value];
		if(nodeId == 0)
		{
			[peripheral respondToRequest:request withResult:CBATTErrorInvalidAttributeValueLength];
			return;
		}
		
		LogDebug(@"didReceiveWriteRequests nodeId %lld offset %lu", nodeId, (unsigned long)request.offset);
		
		if(!link)
			link = [[SLBtPeripheralLink alloc] initWithPeripheral:self central:request.central];
		
		link.nodeId = nodeId;
		_links[link.central] = link;
		[self linkConnecting:link];

		[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
		return;
	}
	
	if([request.characteristic.UUID isEqual:self.transport.charactStreamUUID])
	{
		SLBtPeripheralLink* link = _links[request.central];
		if(!link)
		{
			LogWarn(@"didReceiveWriteRequests stream: no link for central %p", request.central);
			return;
		}
		
		if(link.state == SLBtLinkStateDisconnected)
		{
			return;
		}
		
		CBATTError result = [link processWriteRequests:requests];
		
		[peripheral respondToRequest:request withResult:result];
		return;
	}
	
	[peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
} // didReceiveWriteRequests

@end
