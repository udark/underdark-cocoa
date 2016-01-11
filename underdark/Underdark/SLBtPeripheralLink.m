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

#import "SLBtPeripheralLink.h"

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "SLBtPeripheral.h"

// Streams через BLE: http://stackoverflow.com/questions/19280429/reading-long-characteristic-values-using-corebluetooth

@interface SLBtPeripheralLink()
{
	NSMutableData* _inputData;		// Input frame data buffer.
	
	NSMutableArray* _outputQueue;	// Output frame queue.
	NSData* _outputData;			// Currently written frame. If nil, then we should call write: on characteristic directly.
	NSUInteger _outputDataOffset;	// Count of outputData's written bytes;

	NSTimeInterval _transferStartTime;
	bool _isNotifyFailed;
}
@end

@implementation SLBtPeripheralLink

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithPeripheral:(SLBtPeripheral*)peripheral central:(CBCentral*)central
{
	if(!(self = [super init]))
		return self;
	
	_inputData = [[NSMutableData alloc] init];
	_outputQueue = [NSMutableArray array];
	
	_peripheral = peripheral;
	_central = central;
	_priority = 20;
	
	_state = SLBtLinkStateConnecting;
	
	return self;
}

- (void) dealloc
{
}

- (NSString*) description
{
	return SFMT(@"linkp %p | nodeId %lld | peripheral %p", self, _nodeId, _central);
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
		
		if(_isNotifyFailed)
			return;
		
		[self writeNextBytes];
		return;
	}
	
	[_outputQueue addObject:frameData];
}

- (void) disconnect
{
	if(self.state != SLBtLinkStateConnecting && self.state != SLBtLinkStateConnected)
		return;
	
	[self.peripheral linkDisconnected:self];
}

- (void) clearBuffers
{
	_inputData = [[NSMutableData alloc] init];
	
	_outputDataOffset = 0;
	_outputData = nil;
	[_outputQueue removeAllObjects];
}

#pragma mark - Input

- (CBATTError) processWriteRequests:(NSArray*)requests
{
	NSString* desc = @"";
	for(CBATTRequest* request in requests)
		desc = SCAT(desc, SFMT(@" [%p, %lu, %lu]", request.central, (unsigned long)request.offset, (unsigned long)request.value.length));
	//LogDebug(@"write reqs%@", desc);
	
	NSUInteger lengthPrevious = _inputData.length;
	NSUInteger lengthCurrent = 0;
	
	for(CBATTRequest* request in requests)
	{
		if(request.offset + request.value.length > lengthCurrent)
		{
			lengthCurrent = request.offset + request.value.length;
		}
	}
	
	_inputData.length = _inputData.length + lengthCurrent;
	
	for(CBATTRequest* request in requests)
	{
		unsigned char* dest = (unsigned char*)_inputData.mutableBytes + lengthPrevious + request.offset;
		memcpy(dest, request.value.bytes, request.value.length);
	}
	
	[self formFrames];
	
	return CBATTErrorSuccess;
}

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
		
		//LogDebug(@"peripheral link didReceiveFrame");
		[self.peripheral.transport.delegate transport:self.peripheral.transport link:self didReceiveFrame:frameData];
	} // while
} // formFrames

#pragma mark - Output

- (void) retryNotify
{
	if(!_isNotifyFailed)
		return;
	
	_isNotifyFailed = false;
	
	sldispatch_async(self.peripheral.transport.queue, ^{
		[self writeNextBytes];
	});
}

- (void) writeNextBytes
{
	if(self.state != SLBtLinkStateConnected)
		return;
	
	if(!_outputData)
		return;
	
	NSInteger writeLen = MIN(self.central.maximumUpdateValueLength, _outputData.length - _outputDataOffset);
	NSData* data = [_outputData subdataWithRange:NSMakeRange(_outputDataOffset, writeLen)];
	
	_isNotifyFailed = ![self.peripheral link:self bytesAvailable:data];

	if(_isNotifyFailed)
	{
		//LogDebug(@"updateValue queue is full");
		return;
	}
	
	//LogDebug(@"peripheral write %ld", writeLen);
	
	if(_transferStartTime != 0)
	{
		_transferBytes += writeLen;
		_transferTime += [NSDate timeIntervalSinceReferenceDate] - _transferStartTime;
		_transferSpeed = (NSInteger)(_transferBytes / _transferTime);
	}
	
	//LogDebug(@"Write speed %d bytes/sec", (int32_t)(_transferBytes / _transferTime));
	
	_outputDataOffset += writeLen;
	if(_outputDataOffset == _outputData.length)
	{
		// Frame is fully written - getting next from output queue.
		_transferStartTime = 0;
		_outputDataOffset = 0;
		_outputData = nil;
		
		if(_outputQueue.count != 0)
		{
			_outputData = [_outputQueue firstObject];
			[_outputQueue removeObjectAtIndex:0];
		}
	}
	
	sldispatch_async(self.peripheral.transport.queue, ^{
		[self writeNextBytes];
	});
} // writeNextBytes

@end
