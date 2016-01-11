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

#import "SLBtCentralLink.h"

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "SLBtCentral.h"

@interface SLBtCentralLink() <CBPeripheralDelegate>
{
	CBCharacteristic* _charactNodeId;
	CBCharacteristic* _charactJack;
	CBCharacteristic* _charactStream;
	
	NSMutableData* _inputData;		// Input frame data buffer.
	
	NSMutableArray* _outputQueue;	// Output frame queue.
	NSData* _outputData;			// Currently written frame. If nil, then we should call write: on characteristic directly.
	NSUInteger _outputDataOffset;	// Count of outputData's written bytes;
	NSInteger _outputWriteLen;
	
	NSTimeInterval _transferStartTime;
}
@end

@implementation SLBtCentralLink

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithCentral:(SLBtCentral*)central peripheral:(CBPeripheral*)peripheral
{
	if(!(self = [super init]))
		return self;
	
	_inputData = [[NSMutableData alloc] init];
	_state = SLBtLinkStateConnecting;
	_central = central;
	_peripheral = peripheral;
	_peripheral.delegate = self;
	
	_priority = 20;
	_slowLink = true;
	
	_outputQueue = [NSMutableArray array];
	
	return self;
}

- (void) dealloc
{
	_peripheral.delegate = nil;
}

- (NSString*) description
{
	return SFMT(@"linkc %p | nodeId %lld | peripheral %p", self, _nodeId, _peripheral);
}

#pragma mark - SLLink

- (void) sendFrame:(NSData*)data
{
	if(self.state != SLBtLinkStateConnected)
		return;
	
	NSMutableData* frameData = [NSMutableData data];
	uint32_t frameBodySize = (uint32_t)data.length;
	frameBodySize = CFSwapInt32HostToBig(frameBodySize);
	[frameData appendBytes:&frameBodySize length:sizeof(frameBodySize)];
	[frameData appendData:data];
	
	if(_outputData == nil)
	{
		_transferStartTime = [NSDate timeIntervalSinceReferenceDate];
		_outputData = frameData;
		[self writeNextBytes];
		return;
	}
	
	[_outputQueue addObject:frameData];
} // sendFrame

- (void) disconnect
{
	if(self.state != SLBtLinkStateConnecting && self.state != SLBtLinkStateConnected)
		return;
	
	[self.central disconnectLink:self];
}

- (void) clearBuffers
{
	_inputData = [[NSMutableData alloc] init];
	_outputData = nil;
	_outputDataOffset = 0;
	_outputWriteLen = 0;
}


#pragma mark - Transfer

- (void) onPeripheralConnected
{
	[_peripheral discoverServices:@[self.central.transport.serviceUUID]];
}

- (void) writeNextBytes
{
	// Stream thread.
	if(self.state != SLBtLinkStateConnected)
		return;
	
	if(!_outputData)
		return;
	
	if(_transferStartTime != 0)
	{
		_transferBytes += _outputWriteLen;
		_transferTime += [NSDate timeIntervalSinceReferenceDate] - _transferStartTime;
		_transferSpeed = (NSInteger)(_transferBytes / _transferTime);
	}
	
	_outputDataOffset += _outputWriteLen;
	_outputWriteLen = 0;
	if(_outputDataOffset == _outputData.length)
	{
		// Frame is fully written - getting next from output queue.
		_transferStartTime = 0;
		_outputDataOffset = 0;
		_outputData = nil;
		
		if(_outputQueue.count == 0)
			return;
		
		_outputData = [_outputQueue firstObject];
		[_outputQueue removeObjectAtIndex:0];
	}
	
	_outputWriteLen = MIN(SLBtTransferSizeMax, _outputData.length - _outputDataOffset);
	NSData* bytesData = [_outputData subdataWithRange:NSMakeRange(_outputDataOffset, _outputWriteLen)];
	
	[self.peripheral writeValue:bytesData forCharacteristic:_charactStream type:CBCharacteristicWriteWithResponse];
	
	//LogDebug(@"Write speed %d bytes/sec", (int32_t)(_transferBytes / _transferTime));
} // writeNextBytes

- (void)formFrames
{
	while(true)
	{
		// Calculating how much data still must be appended to receive message body size.
		const size_t frameHeaderSize = sizeof(uint32_t);
		
		// If current buffer length is not enough to create frame header - so continue reading.
		if(_inputData.length < frameHeaderSize)
			break;
		
		// Calculating frame body size.
		uint32_t frameBodySize =  *( ((const uint32_t*)[_inputData bytes]) + 0) ;
		frameBodySize = CFSwapInt32BigToHost(frameBodySize);
		
		size_t frameSize = frameHeaderSize + frameBodySize;
		
		// We don't have full frame in input buffer - so continue reading.
		if(frameSize > _inputData.length)
			break;
		
		// We have our frame at the start of inputData.
		NSData* frameData = [_inputData subdataWithRange:NSMakeRange(frameHeaderSize, frameBodySize)];
		
		// Moving remaining bytes to the start.
		if(_inputData.length != frameSize)
			memmove(_inputData.mutableBytes, (int8_t*)_inputData.mutableBytes + frameSize, _inputData.length - frameSize);
		
		// Shrinking inputData.
		_inputData.length = _inputData.length - frameSize;
		
		//LogDebug(@"central link didReceiveFrame");
		[self.central.transport.delegate transport:self.central.transport link:self didReceiveFrame:frameData];
	} // while
} // formFrames

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error;
{
	if(error)
	{
		LogError(@"peripheral didDiscoverServices failed: %@", error);
		[self.central disconnectLink:self];
		return;
	}
	
	for(CBService* service in peripheral.services)
	{
		if([service.UUID isEqual:self.central.transport.serviceUUID])
		{
			NSArray* uuids = @[self.central.transport.charactNodeIdUUID,
							   self.central.transport.charactJackUUID,
							   self.central.transport.charactStreamUUID];
			[_peripheral discoverCharacteristics:uuids forService:service];
			return;
		}
	}
	
	[self.central linkUnsuitable:self];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
	if(error)
	{
		LogError(@"peripheral didDiscoverCharacteristicsForService failed: %@", error);
		[self.central disconnectLink:self];
		return;
	}
	
	for(CBCharacteristic* charact in service.characteristics)
	{
		if([charact.UUID isEqual:self.central.transport.charactNodeIdUUID])
			_charactNodeId = charact;

		if([charact.UUID isEqual:self.central.transport.charactJackUUID])
			_charactJack = charact;

		if([charact.UUID isEqual:self.central.transport.charactStreamUUID])
			_charactStream = charact;
	}
	
	if(!_charactNodeId || !_charactStream || !_charactJack)
	{
		LogError(@"Missing characteristics in %@", self);
		[self.central linkUnsuitable:self];
		return;
	}
	
	LogDebug(@"Suitable %@", self);
	[self.peripheral readValueForCharacteristic:_charactNodeId];
} // didDiscoverCharacteristicsForService

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if(error)
	{
		LogError(@"didUpdateNotificationStateForCharacteristic failed: %@", error);
		[self.central disconnectLink:self];
		return;
	}
	
	if([characteristic.UUID isEqual:self.central.transport.charactStreamUUID])
	{
		LogDebug(@"didUpdateNotificationStateForCharacteristic");
		
		[self.central linkConnected:self];
		
		return;
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if([characteristic.UUID isEqual:self.central.transport.charactNodeIdUUID])
	{
		if(!characteristic.value)
		{
			[self.central disconnectLink:self];
		}
		
		_nodeId = [self.central.transport nodeIdForData:characteristic.value];
		
		LogDebug(@"Determined nodeId for %@", self);
		
		[peripheral writeValue:[self.central.transport dataForNodeId] forCharacteristic:_charactJack type:CBCharacteristicWriteWithResponse];
		
		return;
	}
	
	if([characteristic.UUID isEqual:self.central.transport.charactStreamUUID])
	{
		if(!characteristic.value)
			return;
		
		//LogDebug(@"central received %lu", (unsigned long)characteristic.value.length);
		[_inputData appendData:characteristic.value];
		[self formFrames];
		
		return;
	}
} // didUpdateValueForCharacteristic

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if(error)
	{
		LogError(@"didWriteValueForCharacteristic failed: %@", error);
		[self.central disconnectLink:self];
		return;
	}
	
	if([characteristic.UUID isEqual:self.central.transport.charactJackUUID])
	{
		LogDebug(@"didWriteValueForCharacteristic jack");
		if(self.state == SLBtLinkStateConnecting)
		{
			[peripheral setNotifyValue:YES forCharacteristic:_charactStream];
			return;
		}
		
		return;
	}
	
	if([characteristic.UUID isEqual:self.central.transport.charactStreamUUID])
	{
		[self writeNextBytes];
	}
} // didWriteValueForCharacteristic

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
	LogDebug(@"peripheralDidInvalidateServices %@", self);
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices
{
	
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
	
}



@end
