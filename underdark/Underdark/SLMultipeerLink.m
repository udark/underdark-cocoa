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

#import "SLMultipeerLink.h"

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDConfig.h"

// Threads & runloops:
// http://stackoverflow.com/a/7223765/1449965

// NSOutputStream: http://stackoverflow.com/a/23001691/1449965

@interface SLMultipeerLink() <MCSessionDelegate, NSStreamDelegate>
{
	dispatch_queue_t _queue;
	
	MCPeerID* _peerId;
	volatile bool _disconnected;

	__weak SLNode* _node;
	
	NSOutputStream* _outputStream;
	NSInputStream* _inputStream;
	
	NSMutableData* _inputData;		// Input frame data buffer.
	uint8_t _inputBuffer[1024];		// Input stream buffer.
	
	NSMutableArray* _outputQueue;	// Output frame queue.
	NSData* _outputData;			// Currently written frame. If nil, then we should call write: on stream directly.
	NSUInteger _outputDataOffset;	// Count of outputData's written bytes;
	
	NSTimeInterval _transferStartTime;
	
	bool _shouldLog;
}

@end

@implementation SLMultipeerLink

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithPeerId:(MCPeerID*)peerId transport:(SLMultipeerTransport*)transport
{
	// Main queue.
	if(!(self = [super init]))
		return self;
	
	//_shouldLog = true;
	
	_transport = transport;
	_queue = transport.queue;
	
	_inputData = [[NSMutableData alloc] init];
	_outputQueue = [NSMutableArray array];
	
	_peerId = peerId;
	_nodeId = [peerId.displayName longLongValue];
	_session = [[MCSession alloc] initWithPeer:transport.peerId securityIdentity:nil encryptionPreference:MCEncryptionRequired];
	_session.delegate = self;
	
	//LogDebug(@"Created %@", self);
	
	return self;
}

- (void) dealloc
{
	//if(_shouldLog)
	//	LogDebug(@"link dealloc()");
}

- (int16_t) priority
{
	return 10;
}

- (NSString*) description
{
	return SFMT(@"link %p | session %p | peer %@", self, _session, _peerId);
}

#pragma mark - SLLink

- (void) disconnect
{
	// Background queue.
	if(_disconnected)
		return;
	
	_disconnected = true;
	
	[self disconnectInternal];
}

- (void) disconnectInternal
{
	// Background queue.

	if(_shouldLog)
		LogDebug(@"link disconnect()");
	
	[self.transport linkDisconnected:self];
	
	sldispatch_async(dispatch_get_main_queue(), ^{
		//if(_shouldLog)
		//	LogDebug(@"link session disconnect()");
		
		_session.delegate = nil;
		[_session disconnect];
		
		sldispatch_async(_queue, ^{
			[self closeStreams];
		});
	});
} // disconnect

- (void) sendFrame:(NSData*)data
{
	// Background queue.
	if(_disconnected)
		return;
	
	NSMutableData* frameData = [NSMutableData data];
	uint32_t frameBodySize = (uint32_t)data.length;
	frameBodySize = CFSwapInt32HostToBig(frameBodySize);
	[frameData appendBytes:&frameBodySize length:sizeof(frameBodySize)];
	[frameData appendData:data];
	
	[self performSelector:@selector(writeFrame:) onThread:_transport.outputThread withObject:frameData waitUntilDone:NO];
}

#pragma mark - Utility

- (void) closeStreams
{
	// Background queue.
	
	if(_shouldLog)
		LogDebug(@"link closeStreams()");
	
	[self performSelector:@selector(closeInputStream) onThread:_transport.inputThread withObject:nil waitUntilDone:NO];
}

- (void) closeInputStream
{
	// Input thread.
	
	if(_inputStream)
	{
		if(_shouldLog)
			LogDebug(@"link inputStream close()");
		
		_inputStream.delegate = nil;
		[_inputStream close];
		//[_inputStream removeFromRunLoop:[_transport.inputThread runLoop] forMode:NSDefaultRunLoopMode];
		_inputStream = nil;
	}
	
	[self performSelector:@selector(closeOutputStream) onThread:_transport.outputThread withObject:nil waitUntilDone:NO];
}

- (void) closeOutputStream
{
	// Output thread.
	
	[_outputQueue removeAllObjects];
	
	if(_outputStream)
	{
		if(_shouldLog)
			LogDebug(@"link outStream close()");

		_outputStream.delegate = nil;
		[_outputStream close];
		//[_outputStream removeFromRunLoop:[_transport.outputThread runLoop] forMode:NSDefaultRunLoopMode];
		_outputStream = nil;
	}
	
	if(_disconnected)
	{
		sldispatch_async(_queue, ^{
			//if(_shouldLog)
			//	LogDebug(@"link transport linkTerminated");
			[self.transport linkTerminated:self];
		});
	}
}

- (NSString*) stringForSessionState:(MCSessionState)state
{
	switch (state)
	{
		case MCSessionStateConnected:
			return @"Connected";
			
		case MCSessionStateConnecting:
			return @"Connecting";
			
		case MCSessionStateNotConnected:
			return @"NotConnected";
	}
	
	return @"";
}

- (NSString*) stringForStreamEvent:(NSStreamEvent)eventCode
{
	switch (eventCode)
	{
		case NSStreamEventNone:
			return @"NSStreamEventNone";

		case NSStreamEventOpenCompleted:
			return @"NSStreamEventOpenCompleted";
			
		case NSStreamEventHasBytesAvailable:
			return @"NSStreamEventHasBytesAvailable";
			
		case NSStreamEventHasSpaceAvailable:
			return @"NSStreamEventHasSpaceAvailable";
			
		case NSStreamEventErrorOccurred:
			return @"NSStreamEventErrorOccurred";
			
		case NSStreamEventEndEncountered:
			return @"NSStreamEventEndEncountered";
	}
	
	return @"";
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession*)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
	//NSString* desc = [self stringForSessionState:state];
	//LogInfo(@"link %p | session %p | peer %@ | state %@", self, session, peerID, desc);
	
	// Session queue.
	
	if(state == MCSessionStateNotConnected)
	{
		if(_disconnected)
			return;
		
		_disconnected = true;
		
		if(_shouldLog)
			LogDebug(@"link session NotConnected");
		
		sldispatch_async(_queue, ^{
			[self disconnectInternal];
		});
		
		return;
	}
	
	if(state == MCSessionStateConnecting)
	{
		sldispatch_async(_queue, ^{
			[self.transport linkConnecting:self];
		});
		return;
	}
	
	if(state == MCSessionStateConnected)
	{
		//_shouldLog = true;
		
		NSError* error;
		_outputStream = [session startStreamWithName:@(_nodeId).description toPeer:_peerId error:&error];
		if(error)
		{
			LogError(@"Failed to start stream: %@", error);
			return;
		}
		
		_outputStream.delegate = self;
		[_outputStream scheduleInRunLoop:[_transport.outputThread runLoop] forMode:NSDefaultRunLoopMode];
		[_outputStream open];

		sldispatch_async(_queue, ^{
			[self.transport linkConnected:self];
		});
		
		return;
	}
} // didChangeState

- (void)session:(MCSession*)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
	// Session queue.
	//LogDebug(@"session didReceiveData");
}

- (void)session:(MCSession*)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
	// Session queue.
	//LogDebug(@"session didReceiveStream");
	_inputStream = stream;
	stream.delegate = self;
	[stream scheduleInRunLoop:[_transport.inputThread runLoop] forMode:NSDefaultRunLoopMode];
	[stream open];
}

- (void)session:(MCSession*)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
	// Session queue.
	//LogDebug(@"session didStartReceivingResourceWithName: %@", resourceName);
}

- (void)session:(MCSession*)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
	// Session queue.
	//LogDebug(@"session didFinishReceivingResourceWithName: %@", resourceName);
}

- (void)session:(MCSession*)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void(^)(BOOL accept))certificateHandler
{
	// Session queue.
	//LogError(@"session didReceiveCertificate");
	
	if(certificateHandler)
		certificateHandler(YES);
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
		sldispatch_async(_queue, ^{
			[self disconnect];
		});
	}
} // outputStream

- (void) writeFrame:(NSData*)data
{
	// Stream thread.
	
	if(_outputData == nil)
	{
		/*static int foo = 0;
		++foo;
		if(foo % 500 == 0)
			NSLog(@"out %d", foo);*/
		
		// If we're not currently writing any frame, start writing.
		_transferStartTime = [NSDate timeIntervalSinceReferenceDate];
		_outputData = data;
		[self writeNextBytes];
		return;
	}
	
	// Otherwise add frame to output queue.
	[_outputQueue addObject:data];
}

- (void)writeNextBytes
{
	// Stream thread.
	if(!_outputData)
		return;
	
	uint8_t* bytes = (uint8_t *)_outputData.bytes;
	bytes += _outputDataOffset;
	NSInteger len = MIN(sizeof(_inputBuffer), _outputData.length - _outputDataOffset);
	
	NSInteger result = [_outputStream write:bytes maxLength:len];
	if(result < 0)
	{
		LogError(@"Output stream error %@", _outputStream.streamError);
		sldispatch_async(_queue, ^{
			[self disconnect];
		});
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
	if(!_slowLink  && _transferBytes >= configLinkTestSignalSize && _transferSpeed <= configLinkSlowSpeedLimit)
	{
		LogDebug(@"Slow link detected.");
		_slowLink = true;
	}
	
	_outputDataOffset += result;
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
			//LogDebug(@"input NSStreamEventHasBytesAvailable");
			while(stream.hasBytesAvailable)
			{
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
				if(len != sizeof(_inputBuffer))
					break;

				break;
			}
			
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
		sldispatch_async(_queue, ^{
			[self disconnect];
		});
	}
} // inputStream

- (void)formFrames
{
	// Stream thread.
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
		
		//NSData *remainingData = [_inputData subdataWithRange:NSMakeRange(frameSize, _inputData.length - frameSize)];
		//_inputData = [NSMutableData dataWithData:remainingData];
		
		/*static int foo = 0;
		++foo;
		if(foo % 500 == 0)
			NSLog(@"in %d", foo);*/
		
		sldispatch_async(_queue, ^{
			[self.transport.delegate transport:self.transport link:self didReceiveFrame:frameData];
		});
	} // while
} // formFrames

@end
