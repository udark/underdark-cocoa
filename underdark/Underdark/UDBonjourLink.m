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

#import "UDBonjourLink.h"

#import <MSWeakTimer/MSWeakTimer.h>

#import "UDBonjourTransport.h"
#import "Frames.pb.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"

#import "UDConfig.h"

typedef NS_ENUM(NSUInteger, SLBnjState)
{
	SLBnjStateConnecting,
	SLBnjStateConnected,
	SLBnjStateDisconnected
};

@interface UDOutputData : NSObject

@property (nonatomic) id<UDData> data;
@property (nonatomic) Frame* frame;

- (void) giveup;

@end
@implementation UDOutputData

- (void) giveup
{
	[self.data giveup];
}

@end

@interface UDBonjourLink () <NSStreamDelegate>
{
	__weak UDBonjourTransport * _transport;
	
	bool _isClient;
	SLBnjState _state;
	
	NSMutableData* _inputData;		// Input frame data buffer.
	uint8_t _inputBuffer[1024];		// Input stream buffer.
	
	NSMutableArray<UDOutputData*>* _outputQueue;	// Output queue with data objects.
	UDOutputData* _outputData;		// Currently written UDBonjourData. If nil, then we should call write: on stream directly.
	
	NSData* _outputBytes;			// If nil, then bytes is not yet acquired from _outputData.
	NSUInteger _outputDataOffset;	// Count of outputData's written bytes;
	
	NSTimeInterval _transferStartTime;
	
	MSWeakTimer* _heartbeatTimer;
	MSWeakTimer* _timeoutTimer;
	bool _heartbeatReceived;
}

@property (nonatomic, weak) UDBonjourTransport * transport;

@property (nonatomic) NSInputStream* inputStream;
@property (nonatomic) NSOutputStream* outputStream;

@end

@implementation UDBonjourLink

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithTransport:(UDBonjourTransport *)transport input:(NSInputStream*)inputStream output:(NSOutputStream*)outputStream
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_isClient = false;
	_state = SLBnjStateConnecting;
	
	_transport = transport;
	_inputData = [[NSMutableData alloc] init];
	_outputQueue = [NSMutableArray array];

	_inputStream = inputStream;
	_outputStream = outputStream;
	
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	
	return self;
}

- (instancetype) initWithNodeId:(int64_t)nodeId transport:(UDBonjourTransport *)transport input:(NSInputStream*)inputStream output:(NSOutputStream*)outputStream
{
	if(!(self = [self initWithTransport:transport input:inputStream output:outputStream]))
		return self;
	
	_isClient = true;
	_nodeId = nodeId;
	
	return self;
}

- (void) dealloc
{
	LogDebug(@"dealloc %@", self);
	[_heartbeatTimer invalidate];
	[_timeoutTimer invalidate];
}

- (NSString*) description
{
	return SFMT(@"link %p | nodeId %lld", self, _nodeId);
}

- (int16_t) priority
{
	return self.transport.linkPriority;
}

#pragma mark - Heartbeat

- (void) sendHeartbeat
{
	// Transport queue.
	FrameBuilder* frame = [FrameBuilder new];
	frame.kind = FrameKindHeartbeat;
	
	HeartbeatFrameBuilder* payload = [HeartbeatFrameBuilder new];
	frame.heartbeat = [payload build];

	//LogDebug(@"bnj link sent heartbeat");
	[self sendLinkFrame:[frame build]];
}

- (void) checkHeartbeat
{
	// Transport queue.
	[self performSelector:@selector(checkHeartbeatImpl) onThread:self.transport.ioThread withObject:nil waitUntilDone:NO];
}

- (void) checkHeartbeatImpl
{
	// Stream thread.
	
	if(_heartbeatReceived)
	{
		_heartbeatReceived = false;
		return;
	}
	
	LogWarn(@"link heartbeat timeout");
	[self closeStreams];
}

#pragma mark - UDLink

- (void) connect
{
	// Transport queue.
	[_inputStream scheduleInRunLoop:self.transport.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop:self.transport.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	
	[_inputStream open];
	[_outputStream open];
}

- (void) disconnect
{
	// Listener queue.
	if(_state == SLBnjStateDisconnected)
		return;
	
	[self performSelector:@selector(writeData:) onThread:self.transport.ioThread withObject:[[UDOutputData alloc] init] waitUntilDone:NO];
}

- (void) closeStreams
{
	// Stream thread.
	
	[_heartbeatTimer invalidate];
	_heartbeatTimer = nil;
	
	[_timeoutTimer invalidate];
	_timeoutTimer = nil;
	
	if(_inputStream)
	{
		LogDebug(@"link inputStream close()");
		
		_inputStream.delegate = nil;
		[_inputStream close];
		//[_inputStream removeFromRunLoop:[_transport.inputThread runLoop] forMode:NSDefaultRunLoopMode];
		_inputStream = nil;
	}
	
	for(id<UDData> data in _outputQueue) {
		[data giveup];
	}
	
	[_outputQueue removeAllObjects];
	
	
	[_outputData giveup];
	_outputData = nil;
	_outputDataOffset = 0;
	
	if(_outputStream)
	{
		LogDebug(@"link outStream close()");
		
		_outputStream.delegate = nil;
		[_outputStream close];
		//[_outputStream removeFromRunLoop:[_transport.outputThread runLoop] forMode:NSDefaultRunLoopMode];
		_outputStream = nil;
	}
	
	if(_state == SLBnjStateConnecting
	   || _state == SLBnjStateConnected)
	{
		_state = SLBnjStateDisconnected;
		
		sldispatch_async(_transport.queue, ^{
			[self.transport linkDisconnected:self];
			[self performSelector:@selector(onTerminated) onThread:self.transport.ioThread withObject:nil waitUntilDone:NO];
		});
		
		return;
	}
} // closeStreams

- (void) onTerminated
{
	// Stream thread.
	
	if(_state != SLBnjStateDisconnected)
		return;
	
	for(id<UDData> data in _outputQueue) {
		[data giveup];
	}
	
	[_outputQueue removeAllObjects];
	
	
	_outputData = nil;
	[_outputData giveup];
	_outputDataOffset = 0;
	
	//if(_shouldLog)
	//	LogDebug(@"link transport linkTerminated");
	
	UDBonjourTransport * transport = _transport;
	
	sldispatch_async(transport.queue, ^{
		[transport linkTerminated:self];
	});
	
	_transport = nil;
}

#pragma mark - Writing

- (void) sendData:(nonnull id<UDData>)data
{
	// Transport queue.
	[data acquire];
	[data giveup]; // By per UDLink sendData: contract.
	
	UDOutputData* outdata = [[UDOutputData alloc] init];
	outdata.data = data;
	
	[self performSelector:@selector(writeData:) onThread:self.transport.ioThread withObject:outdata waitUntilDone:NO];
}

- (void) sendFrame:(NSData*)data
{
	// Transport queue.
	FrameBuilder* frame = [FrameBuilder new];
	frame.kind = FrameKindPayload;
	
	PayloadFrameBuilder* payload = [PayloadFrameBuilder new];
	payload.payload = data;
	
	frame.payload = [payload build];
	
	[self sendLinkFrame:[frame build]];
}

- (void) sendLinkFrame:(Frame*)frame
{
	// Any queue.
	
	UDOutputData* outdata = [[UDOutputData alloc] init];
	outdata.frame = frame;
	
	[self performSelector:@selector(writeData:) onThread:self.transport.ioThread withObject:outdata waitUntilDone:NO];
}

- (void) sendLinkFrame2:(Frame*)frame
{
	// Any queue.
	NSMutableData* frameData = [NSMutableData data];
	NSData* frameBody = frame.data;
	uint32_t frameBodySize = CFSwapInt32HostToBig((uint32_t)frameBody.length);
	[frameData appendBytes:&frameBodySize length:sizeof(frameBodySize)];
	[frameData appendData:frameBody];
	
	[self performSelector:@selector(writeFrame:) onThread:self.transport.ioThread withObject:frameData waitUntilDone:NO];
}

- (void) writeData:(UDOutputData*)outdata
{
	// Stream thread.
	
	// frameData already acquired.
	
	if(_state == SLBnjStateDisconnected)
	{
		[outdata giveup];
		return;
	}
	
	// Add data to output queue.
	[_outputQueue addObject:outdata];
	
	// If we're not currently writing any data, start writing.
	if(_outputData == nil) {
		[self writeNextData];
	}
}

- (void) writeNextData
{
	// Stream thread.
	
	if(_state == SLBnjStateDisconnected)
		return;
	
	_transferStartTime = [NSDate timeIntervalSinceReferenceDate];
	
	[_outputData giveup];
	
	_outputBytes = nil;
	_outputDataOffset = 0;
	_outputData = [_outputQueue firstObject];
	if(_outputData == nil)
		return;
	
	[_outputQueue removeObjectAtIndex:0];
	
	if(_outputData.frame != nil)
	{
		_outputBytes = [self dataForFrame:_outputData.frame];
		[self writeNextBytes];
		
		return;
	}
	
	if(_outputData.data != nil)
	{
		[_outputData.data retrieve:^(NSData * _Nullable data) {
			// Any thread.
			[self performSelector:@selector(outputDataBytesRetrieved:) onThread:self.transport.ioThread withObject:data waitUntilDone:NO];
		}];
		
		return;
	}
	
	// Empty UDOutputData object encountered — disconnecting.
	_outputData = nil;
	[self closeStreams];
	
} // writeNextData

- (void) outputDataBytesRetrieved:(nullable NSData*)dataBytes
{
	// Stream thread.
	
	if(_state == SLBnjStateDisconnected)
		return;
	
	if(dataBytes == nil) {
		// Data no more actural - get next from queue.
		[self writeNextData];
		return;
	}
	
	// Building frame.
	FrameBuilder* frame = [FrameBuilder new];
	frame.kind = FrameKindPayload;
	
	PayloadFrameBuilder* payload = [PayloadFrameBuilder new];
	payload.payload = dataBytes;
	
	frame.payload = [payload build];
	
	_outputBytes = [self dataForFrame:[frame build]];
	[self writeNextBytes];
}

- (NSData*) dataForFrame:(Frame*)frame
{
	// Any thread.
	NSMutableData* frameData = [NSMutableData data];
	NSData* frameBody = frame.data;
	uint32_t frameBodySize = CFSwapInt32HostToBig((uint32_t)frameBody.length);
	[frameData appendBytes:&frameBodySize length:sizeof(frameBodySize)];
	[frameData appendData:frameBody];
	
	return frameData;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	if(stream == _outputStream)
		[self outputStream:_outputStream handleEvent:eventCode];
	else if(stream == _inputStream)
		[self inputStream:_inputStream handleEvent:eventCode];
}

- (void)outputStream:(NSOutputStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	// Stream thread.
	
	//LogDebug(@"output %@", [self stringForStreamEvent:eventCode]);
	
	bool shouldClose = false;
	
	switch (eventCode)
	{
		case NSStreamEventNone:
		{
			LogError(@"output NSStreamEventNone (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
			
		case NSStreamEventOpenCompleted:
		{
			//LogDebug(@"output NSStreamEventOpenCompleted");
			
			//LogDebug(@"bnj sent nodeId to server");
			
			FrameBuilder* frame = [FrameBuilder new];
			frame.kind = FrameKindHello;
			
			HelloFrameBuilder* payload = [HelloFrameBuilder new];
			payload.nodeId = self.transport.nodeId;
			
			PeerBuilder* peer = [PeerBuilder new];
			peer.address = [NSData data];
			peer.legacy = false;
			//peer.ports
			
			payload.peer = [peer build];
			frame.hello = [payload build];
			
			[self sendLinkFrame:[frame build]];
			
			_heartbeatTimer = [MSWeakTimer scheduledTimerWithTimeInterval:configBonjourHeartbeatInterval target:self selector:@selector(sendHeartbeat) userInfo:nil repeats:YES dispatchQueue:self.transport.queue];
			[_heartbeatTimer fire];

			break;
		}
			
		case NSStreamEventHasBytesAvailable:
		{
			break;
		}
			
		case NSStreamEventHasSpaceAvailable:
		{
			[self writeNextBytes];
			break;
		}
			
		case NSStreamEventErrorOccurred:
		{
			LogError(@"output NSStreamEventErrorOccurred (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
			
		case NSStreamEventEndEncountered:
		{
			LogDebug(@"output NSStreamEventEndEncountered (connection closed by server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
	}
	
	if(shouldClose)
	{
		stream.delegate = nil;
		[stream close];
		
		[self closeStreams];
	}
} // outputStream

- (void) writeNextBytes
{
	// Stream thread.
	
	if(_state == SLBnjStateDisconnected)
		return;
	
	if(!_outputBytes)
		return;
	
	uint8_t* bytes = (uint8_t *)_outputBytes.bytes;
	bytes += _outputDataOffset;
	NSInteger len = MIN(sizeof(_inputBuffer), _outputBytes.length - _outputDataOffset);
	
	// Writing to NSOutputStream:
	// http://stackoverflow.com/a/23001691/1449965
	// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Articles/WritingOutputStreams.html
	
	NSInteger result = [_outputStream write:bytes maxLength:len];
	if(result < 0)
	{
		LogError(@"Output stream error %@", _outputStream.streamError);
		
		[self closeStreams];
		return;
	}
	
	//LogDebug(@"output wrote bytes %d", result);
	
	if(result == 0)
		return;
	
	if(_transferStartTime != 0)
	{
		_transferBytes += result;
		_transferTime += [NSDate timeIntervalSinceReferenceDate] - _transferStartTime;
		_transferSpeed = (NSInteger)(_transferBytes / _transferTime);
	}
	
	//LogDebug(@"Write speed %d bytes/sec", (int32_t)(_transferBytes / _transferTime));
	
	_outputDataOffset += result;
	if(_outputDataOffset == _outputBytes.length)
	{
		// Frame is fully written - getting next from output queue.
		[self writeNextData];
	}
} // writeNextBytes

- (void)inputStream:(NSInputStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	// Stream thread.
	//LogDebug(@"input %@", [self stringForStreamEvent:eventCode]);
	
	bool shouldClose = false;
	
	switch (eventCode)
	{
		case NSStreamEventNone:
		{
			LogError(@"input NSStreamEventNone (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
			
		case NSStreamEventOpenCompleted:
		{
			//LogDebug(@"input NSStreamEventOpenCompleted");
			_heartbeatReceived = true;
			break;
		}
			
		case NSStreamEventEndEncountered:
			LogDebug(@"input NSStreamEventEndEncountered (connection closed by server): %@", [stream streamError]);
			shouldClose = true;
			// If all data hasn't been read, fall through to the "has bytes" event.
			if(![stream hasBytesAvailable])
				break;
			
		case NSStreamEventHasBytesAvailable:
		{
			if(_state == SLBnjStateDisconnected)
				break;
			
			_heartbeatReceived = true;

			//LogDebug(@"input NSStreamEventHasBytesAvailable");
			NSInteger len = [stream read:_inputBuffer maxLength:sizeof(_inputBuffer)];
			
			if(len > 0)
			{
				[_inputData appendBytes:_inputBuffer length:len];
			}
			else if(len < 0)
			{
				LogError(@"Input stream error %@", stream.streamError);
				shouldClose = true;
				break;
			}
			
			//LogDebug(@"input read bytes %d", len);
			
			[self formFrames];
			break;
		}
			
		case NSStreamEventHasSpaceAvailable:
		{
			break;
		}
			
		case NSStreamEventErrorOccurred:
		{
			LogError(@"input NSStreamEventErrorOccurred (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
	} // switch
	
	if(shouldClose)
	{
		stream.delegate = nil;
		[stream close];
		
		[self closeStreams];
	}
} // inputStream

- (void)formFrames
{
	// Stream thread.
	
	while(true)
	{
		_heartbeatReceived = true;

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
		NSData* frameBody = [_inputData subdataWithRange:NSMakeRange(frameHeaderSize, frameBodySize)];
		
		// Moving remaining bytes to the start.
		if(_inputData.length != frameSize)
			memmove(_inputData.mutableBytes, (int8_t*)_inputData.mutableBytes + frameSize, _inputData.length - frameSize);
		
		// Shrinking inputData.
		_inputData.length = _inputData.length - frameSize;
		
		//NSData *remainingData = [_inputData subdataWithRange:NSMakeRange(frameSize, _inputData.length - frameSize)];
		//_inputData = [NSMutableData dataWithData:remainingData];
		
		/*static int foo = 0;
		 ++foo;
		 if(foo % 500 == 0)
			NSLog(@"in %d", foo);*/
		
		if(frameBody.length == 0)
			continue;
		
		Frame* frame;
		
		@try
		{
			frame = [Frame parseFromData:frameBody];
		}
		@catch (NSException *exception)
		{
			continue;
		}
		@finally
		{
		}
		
		if(_state == SLBnjStateConnecting)
		{
			if(frame.kind != FrameKindHello || !frame.hasHello)
				continue;
			
			_nodeId = frame.hello.nodeId;
			
			//LogDebug(@"bnj link hello received nodeId %lld", _nodeId);
			
			_state = SLBnjStateConnected;
			
			_timeoutTimer = [MSWeakTimer scheduledTimerWithTimeInterval:configBonjourTimeoutInterval target:self selector:@selector(checkHeartbeat) userInfo:nil repeats:YES dispatchQueue:self.transport.queue];

			sldispatch_async(self.transport.queue, ^{
				[self.transport linkConnected:self];
			});
			
			continue;
		}
		
		if(frame.kind == FrameKindHeartbeat)
		{
			if(!frame.hasHeartbeat)
				continue;
			
			//LogDebug(@"link heartbeat");
		}
		
		if(frame.kind == FrameKindPayload)
		{
			if(!frame.hasPayload || frame.payload.payload == nil)
				continue;
		
			sldispatch_async(self.transport.queue, ^{
				[self.transport link:self receivedFrame:frame.payload.payload];
			});
		}
	} // while
} // formFrames

@end
