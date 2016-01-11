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

#import "UDBtBeacon.h"

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDTransport.h"

@import CoreLocation;
@import CoreBluetooth;

// Region monitoring: http://developer.radiusnetworks.com/2013/11/13/ibeacon-monitoring-in-the-background-and-foreground.html

// CoreBluetooth background:
// http://stackoverflow.com/a/10096244/1449965

// didDeterminveState/didEnterRegion http://stackoverflow.com/a/21214876/1449965

static NSString* uuidBeaconTemplate = @"8B410640-3924-4B13-A59A-ED64xxxxxxxx";

typedef NS_ENUM(NSUInteger, SLBeaconState)
{
	SLBeaconStateStopped,
	SLBeaconStateMonitoring,
	SLBeaconStateAdvertising
};

@interface UDBtBeacon () <CLLocationManagerDelegate, CBPeripheralManagerDelegate>
{
	NSUUID* _beaconUuid;
	
	CLLocationManager* _locationManager;
	CLBeaconRegion* _region;
	
	CBPeripheralManager* _peripheralManager;
}

@property (nonatomic) SLBeaconState state;

@end

@implementation UDBtBeacon

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithAppId:(int32_t)appId
{
	// Main queue.
	
	if(!(self = [super init]))
		return self;
	
	NSString* hexPart = [NSString stringWithFormat:@"%08X", appId];
	NSString* uuidString = [uuidBeaconTemplate stringByReplacingOccurrencesOfString:@"xxxxxxxx" withString:hexPart];
	_beaconUuid = [[NSUUID alloc] initWithUUIDString:uuidString];
	
	_region = [[CLBeaconRegion alloc] initWithProximityUUID:_beaconUuid identifier:@"SolidarityBeacon"];
	_region.notifyEntryStateOnDisplay = YES;
	_beaconData =  [_region peripheralDataWithMeasuredPower:nil];

	_locationManager = [[CLLocationManager alloc] init];
	_locationManager.delegate = self;
	
	return self;
}

- (void) dealloc
{
	_locationManager.delegate = nil;
	
	[self stopAdvertising];
}

#pragma mark - Public methods

- (void) requestPermissions
{
	[_locationManager requestWhenInUseAuthorization];
}

#pragma mark - Monitoring

- (void) monitorIfNecessary
{
	if(self.state != SLBeaconStateMonitoring)
		return;
	
	LogDebug(@"Beacon Monitoring started");
	
	if(![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]])
	{
		LogError(@"Region monitoring is not available.");
		self.state = SLBeaconStateStopped;
		return;
	}
	
	if([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways)
	{
		LogError(@"Region monitoring is not authorized.");
		self.state = SLBeaconStateStopped;
		return;
	}

	[_locationManager startMonitoringForRegion:_region];
} // monitorIfNecessary

- (void) startMonitoring
{
	if(self.state == SLBeaconStateMonitoring)
		return;
	
	[self stopAdvertising];

	self.state = SLBeaconStateMonitoring;
	
	[self monitorIfNecessary];
} // startMonitoring

- (void) stopMonitoring
{
	if(self.state == SLBeaconStateMonitoring)
	{
		self.state = SLBeaconStateStopped;
		LogDebug(@"Beacon Monitoring stopped");
	}
	
	[_locationManager stopMonitoringForRegion:_region];
}

#pragma mark - Advertising

- (void) advertiseIfNecessary
{
	if(self.state != SLBeaconStateAdvertising)
		return;
	
	[_peripheralManager startAdvertising:self.beaconData];
}

- (void) startAdvertising
{
	if(self.state == SLBeaconStateAdvertising)
		return;
	
	[self stopMonitoring];
	
	self.state = SLBeaconStateAdvertising;
	
	NSDictionary* options =
	@{//CBPeripheralManagerOptionRestoreIdentifierKey: @"SLBtPeripheral",
	  CBPeripheralManagerOptionShowPowerAlertKey: @(NO)};
	
	_peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
	
	[self advertiseIfNecessary];
}

- (void) stopAdvertising
{
	if(self.state == SLBeaconStateAdvertising)
		self.state = SLBeaconStateStopped;
	
	if(_peripheralManager)
	{
		if(_peripheralManager.isAdvertising)
			[_peripheralManager stopAdvertising];
		
		_peripheralManager.delegate = nil;
		_peripheralManager = nil;
	}
}

- (void) notifyBluetoothRequired
{
	sldispatch_async(dispatch_get_main_queue(), ^{
	    [[NSNotificationCenter defaultCenter] postNotificationName:UDBluetoothRequiredNotification object:self];
	});
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	if(status == kCLAuthorizationStatusAuthorizedWhenInUse)
	{
		[_locationManager requestAlwaysAuthorization];
	}
	
	[self monitorIfNecessary];
}

- (void)locationManager:(CLLocationManager*)manager
	  didDetermineState:(CLRegionState)state
			  forRegion:(CLRegion*)region
{
	if (state != CLRegionStateInside)
	{
		//LogDebug(@"CLRegionStateOutside");
		return;
	}
	
	//LogDebug(@"CLRegionStateInside");
	[[NSNotificationCenter defaultCenter] postNotificationName:UDBeaconDetectedNotification object:nil];
}

- (void)locationManager:(CLLocationManager *)manager
		 didEnterRegion:(CLRegion *)region
{
	//LogDebug(@"didEnterRegion");
}

- (void)locationManager:(CLLocationManager *)manager
		  didExitRegion:(CLRegion *)region
{
	//LogDebug(@"didExitRegion");
}

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error
{
	LogError(@"LocationManager failed: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager
monitoringDidFailForRegion:(CLRegion *)region
			  withError:(NSError *)error
{
	NSString* name = @"";
	switch (error.code)
	{
		case kCLErrorLocationUnknown: name = @"kCLErrorLocationUnknown"; break;
		case kCLErrorDenied: name = @"kCLErrorDenied"; break;
		case kCLErrorNetwork: name = @"kCLErrorNetwork"; break;
		case kCLErrorHeadingFailure: name = @"kCLErrorHeadingFailure"; break;
		case kCLErrorRegionMonitoringDenied: name = @"kCLErrorRegionMonitoringDenied"; break;
		case kCLErrorRegionMonitoringFailure: name = @"kCLErrorRegionMonitoringFailure"; break;
		case kCLErrorRegionMonitoringSetupDelayed: name = @"kCLErrorRegionMonitoringSetupDelayed"; break;
		case kCLErrorRegionMonitoringResponseDelayed: name = @"kCLErrorRegionMonitoringResponseDelayed"; break;
		case kCLErrorGeocodeFoundNoResult: name = @"kCLErrorGeocodeFoundNoResult"; break;
		case kCLErrorGeocodeFoundPartialResult: name = @"kCLErrorGeocodeFoundPartialResult"; break;
		case kCLErrorGeocodeCanceled: name = @"kCLErrorGeocodeCanceled"; break;
		case kCLErrorDeferredFailed: name = @"kCLErrorDeferredFailed"; break;
		case kCLErrorDeferredNotUpdatingLocation: name = @"kCLErrorDeferredNotUpdatingLocation"; break;
		case kCLErrorDeferredAccuracyTooLow: name = @"kCLErrorDeferredAccuracyTooLow"; break;
		case kCLErrorDeferredDistanceFiltered: name = @"kCLErrorDeferredDistanceFiltered"; break;
		case kCLErrorDeferredCanceled: name = @"kCLErrorDeferredCanceled"; break;
		case kCLErrorRangingUnavailable: name = @"kCLErrorRangingUnavailable"; break;
		case kCLErrorRangingFailure: name = @"kCLErrorRangingFailure"; break;
	}
	
	LogError(@"LocationManager monitoring failed (%@): %@", name, error);
}

- (void)locationManager:(CLLocationManager *)manager
didStartMonitoringForRegion:(CLRegion *)region
{
	//LogDebug(@"Region monitoring started.");
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	if(peripheral.state == CBPeripheralManagerStatePoweredOn)
	{
		//LogDebug(@"beacon CBPeripheralManagerStatePoweredOn");
		
		[self advertiseIfNecessary];
		
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStatePoweredOff)
	{
		//LogDebug(@"beacon CBPeripheralManagerStatePoweredOff");
		
		[self notifyBluetoothRequired];
		
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateUnknown)
	{
		//LogDebug(@"beacon CBPeripheralManagerStateUnknown");
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateResetting)
	{
		//LogDebug(@"beacon CBPeripheralManagerStateResetting");
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateUnsupported)
	{
		//LogError(@"beacon CBPeripheralManagerStateUnsupported");
		
		[self notifyBluetoothRequired];
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateUnauthorized)
	{
		//LogError(@"CBPeripheralManagerStateUnauthorized");
		
		[self notifyBluetoothRequired];
		return;
	}
} // peripheralManagerDidUpdateState

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
	if(error)
	{
		LogError(@"beacon didStartAdvertising failed: %@", error);
		if(self.state == SLBeaconStateAdvertising)
			self.state = SLBeaconStateStopped;
		
		return;
	}
} //peripheralManagerDidStartAdvertising

@end
