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

#import "UDBonjourChannel.h"

#import <MSWeakTimer/MSWeakTimer.h>

#import "Frames.pb.h"
#import "UDBonjourAdapter.h"
#import "UDConfig.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDMemorySource.h"
#import "UDOutputItem.h"
#import "UDByteBuf.h"

typedef NS_ENUM(NSUInteger, SLBnjState)
{
	SLBnjStateConnecting,
	SLBnjStateConnected,
	SLBnjStateDisconnected
};

@interface UDBonjourChannel () <NSStreamDelegate>
{
	bool _isClient;
	SLBnjState _state;
	
	UDByteBuf* _inputByteBuf;		// Input frame data buffer.
	uint8_t _inputBuffer[1024];		// Input stream buffer.
	
	NSMutableArray<UDOutputItem*>* _outputQueue;	// Output queue with data objects.
	UDOutputItem* _outputItem;		// Currently written UDOutputItem. If nil, then we should call write: on stream directly.
	
	NSUInteger _outputDataOffset;	// Count of outputData's written bytes;
	
	// True if we received haven't writen anything to NSOutputStream
 	// after last receiving of NSStreamEventHasSpaceAvailable.
	// See http://stackoverflow.com/a/23001691
	bool _outputCanWriteToStream;
	
	MSWeakTimer* _heartbeatTimer;
	MSWeakTimer* _timeoutTimer;
	bool _heartbeatReceived;
}

@property (nonatomic, weak) UDBonjourAdapter* adapter;

@property (nonatomic) NSInputStream* inputStream;
@property (nonatomic) NSOutputStream* outputStream;

@end

@implementation UDBonjourChannel

#pragma mark - Initialization

- (instancetype) init
{
	return nil;
}

- (instancetype) initWithAdapter:(UDBonjourAdapter*)adapter
						   input:(NSInputStream*)inputStream
						  output:(NSOutputStream*)outputStream
{
	if(!(self = [super init]))
		return self;
	
	_adapter = adapter;
	_isClient = false;
	_state = SLBnjStateConnecting;
	
	_adapter = adapter;
	_inputByteBuf = [[UDByteBuf alloc] init];
	_outputQueue = [NSMutableArray array];
	_outputCanWriteToStream = false;

	_inputStream = inputStream;
	_outputStream = outputStream;
	
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	
	return self;
}

- (instancetype) initWithNodeId:(int64_t)nodeId
						adapter:(UDBonjourAdapter*)adapter
						  input:(NSInputStream*)inputStream
						 output:(NSOutputStream*)outputStream
{
	if(!(self = [self initWithAdapter:adapter input:inputStream output:outputStream]))
		return self;
	
	_isClient = true;
	_nodeId = nodeId;
	
	return self;
}

- (void) dealloc
{
	//LogDebug(@"dealloc %@", self);
	[_heartbeatTimer invalidate];
	[_timeoutTimer invalidate];
}

- (NSString*) description
{
	return SFMT(@"channel %p | nodeId %lld", self, _nodeId);
}

- (int16_t) priority
{
	return self.adapter.linkPriority;
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
	[self performSelector:@selector(checkHeartbeatImpl) onThread:self.adapter.ioThread withObject:nil waitUntilDone:NO];
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

#pragma mark - UDChannel

- (void) connect
{
	// Transport queue.
	[_inputStream scheduleInRunLoop:self.adapter.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop:self.adapter.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	
	[_inputStream open];
	[_outputStream open];
}

- (void) disconnect
{
	// Transport queue.
	if(_state == SLBnjStateDisconnected)
		return;
	
	[self performSelector:@selector(writeData:) onThread:self.adapter.ioThread withObject:[[UDOutputItem alloc] init] waitUntilDone:NO];
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
	
	[_outputQueue removeAllObjects];
	
	_outputItem = nil;
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
		
		sldispatch_async(_adapter.queue, ^{
			[self.adapter channelDisconnected:self];
			[self performSelector:@selector(onTerminated) onThread:self.adapter.ioThread withObject:nil waitUntilDone:NO];
		});
		
		return;
	}
} // closeStreams

- (void) onTerminated
{
	// Stream thread.
	
	if(_state != SLBnjStateDisconnected)
		return;
	
	[_outputQueue removeAllObjects];
	
	_outputItem = nil;
	_outputDataOffset = 0;
	
	//if(_shouldLog)
	//	LogDebug(@"link transport linkTerminated");
	
	UDBonjourAdapter* transport = _adapter;
	
	sldispatch_async(transport.queue, ^{
		[transport channelTerminated:self];
	});
	
	_adapter = nil;
}

#pragma mark - Writing

- (void) sendFrame:(nonnull UDOutputItem*)frameData
{
	// Transport queue.
	
	UDOutputItem* frameHeader = [self frameHeaderForFrameData:frameData.data];
	[self performSelector:@selector(enqueueItem:) onThread:self.adapter.ioThread withObject:frameHeader waitUntilDone:NO];

	[self performSelector:@selector(enqueueItem:) onThread:self.adapter.ioThread withObject:frameData waitUntilDone:NO];
}

- (void) sendLinkFrame:(Frame*)frame
{
	// Any queue.

	UDOutputItem* frameBody = [[UDOutputItem alloc] initWithData:[frame data] frameData:nil];

	sldispatch_async(_adapter.queue, ^{
		[self sendFrame:frameBody];
	});
}

- (void) enqueueItem:(UDOutputItem*)item
{
	// Stream thread.
	
	if(_state == SLBnjStateDisconnected)
		return;
	
	// If we're not currently writing any item, start writing next.
	if(_outputItem == nil)
	{
		_outputItem = item;
		_outputDataOffset = 0;

		[self writeNextBytes];
		return;
	}
	
	// Otherwise add item to output queue.
	[_outputQueue addObject:item];
}

- (void) writeNextBytes
{
	// Stream thread.
	
	if(_state == SLBnjStateDisconnected)
		return;
	
	while(_outputItem != nil)
	{
		if(_outputItem.isEnding)
		{
			_outputItem = nil;
			_outputDataOffset = 0;
			[self closeStreams];
			return;
		}
		
		// We already written something to NSOutputStream
		// after receiving NSStreamEventHasSpaceAvailable.
		// So we must wait for next event, otherwise we will block.
		if(!_outputCanWriteToStream)
		{
			//LogDebug(@"writeNextBytes fail");
			return;
		}
		
		//LogDebug(@"writeNextBytes pass");
		
		uint8_t* bytes = (uint8_t *)_outputItem.data.bytes;
		bytes += _outputDataOffset;
		
		NSInteger len = (NSInteger) MIN(512, _outputItem.data.length - _outputDataOffset);
		
		// Writing to NSOutputStream:
		// http://stackoverflow.com/a/23001691/1449965
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Articles/WritingOutputStreams.html
		
		NSInteger result;
	 
		if(len != 0)
		{
			_outputCanWriteToStream = false;
			result = [_outputStream write:bytes maxLength:(NSUInteger)len];
		}
		else
		{
			result = 0;
		}
		
		if(result < 0)
		{
			LogError(@"Output stream error %@", _outputStream.streamError);
			
			[self closeStreams];
			return;
		}
		
		_outputDataOffset += result;
		if(_outputDataOffset == _outputItem.data.length)
		{
			// Item is fully written - getting next from output queue.
			_outputDataOffset = 0;
			_outputItem = nil;
			
			if(_outputQueue.count == 0)
			{
				if(_state == SLBnjStateConnected)
				{
					sldispatch_async(_adapter.queue, ^{
						[_adapter channelCanSendMore:self];
					});
				}
				
				return;
			}
			else
			{
				_outputItem = _outputQueue.firstObject;
				[_outputQueue removeObjectAtIndex:0];
			}
		}
	} // while
} // writeNextBytes

#pragma mark - Boxing

- (UDOutputItem*) frameHeaderForFrameData:(NSData*)frameData
{
	// Any thread.
	NSMutableData* headerData = [NSMutableData data];
	uint32_t frameBodySize = CFSwapInt32HostToBig((uint32_t)frameData.length);
	[headerData appendBytes:&frameBodySize length:sizeof(frameBodySize)];
	
	UDOutputItem* outitem = [[UDOutputItem alloc] initWithData:headerData frameData:nil];
	
	return outitem;
}

- (void)formFrames
{
	// Stream thread.
	
	while(true)
	{
		_heartbeatReceived = true;
		
		// Calculating how much data still must be appended to receive message body size.
		const size_t frameHeaderSize = sizeof(uint32_t);
		
		// If current buffer length is not enough to create frame header - so continue reading.
		if(_inputByteBuf.readableBytes < frameHeaderSize)
		{
			[_inputByteBuf trimWritable:sizeof(_inputBuffer)];
			break;
		}
		
		// Calculating frame body size.
		uint32_t frameBodySize =  *( ((const uint32_t*)(_inputByteBuf.data.bytes + _inputByteBuf.readerIndex)) + 0) ;
		frameBodySize = CFSwapInt32BigToHost(frameBodySize);
		
		size_t frameSize = frameHeaderSize + frameBodySize;
		
		// We don't have full frame in input buffer - so continue reading.
		if(frameSize > _inputByteBuf.readableBytes)
		{
			[_inputByteBuf ensureWritable:frameSize - _inputByteBuf.readableBytes];
			[_inputByteBuf trimWritable:frameSize - _inputByteBuf.readableBytes];
			break;
		}
		
		[_inputByteBuf skipBytes:frameHeaderSize];
		NSData* frameBody = [_inputByteBuf readBytes:frameBodySize];
		
		[_inputByteBuf discardReadBytes];
		
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
		
		[self processInputFrame:frame];
		
	} // while
} // formFrames

- (void) processInputFrame:(Frame*)frame
{
	// Stream thread.
	
	if(_state == SLBnjStateConnecting)
	{
		if(frame.kind != FrameKindHello || !frame.hasHello)
			return;
		
		_nodeId = frame.hello.nodeId;
		
		//LogDebug(@"bnj link hello received nodeId %lld", _nodeId);
		
		_state = SLBnjStateConnected;
		
		_timeoutTimer = [MSWeakTimer scheduledTimerWithTimeInterval:configBonjourTimeoutInterval target:self selector:@selector(checkHeartbeat) userInfo:nil repeats:YES dispatchQueue:self.adapter.queue];
		
		sldispatch_async(self.adapter.queue, ^{
			[self.adapter channelConnected:self];
			[_adapter channelCanSendMore:self];
		});
		
		return;
	}
	
	if(frame.kind == FrameKindHeartbeat)
	{
		if(!frame.hasHeartbeat)
			return;
		
		//LogDebug(@"link heartbeat");
		return;
	}
	
	if(frame.kind == FrameKindPayload)
	{
		if(!frame.hasPayload || frame.payload.payload == nil)
			return;
		
		sldispatch_async(self.adapter.queue, ^{
			[self.adapter channel:self receivedFrame:frame.payload.payload];
		});
		
		return;
	}
} // processInputFrame

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
			payload.nodeId = self.adapter.nodeId;
			
			PeerBuilder* peer = [PeerBuilder new];
			peer.address = [NSData data];
			peer.legacy = false;
			//peer.ports
			
			payload.peer = [peer build];
			frame.hello = [payload build];
			
			[self sendLinkFrame:[frame build]];
			
			_heartbeatTimer = [MSWeakTimer scheduledTimerWithTimeInterval:configBonjourHeartbeatInterval target:self selector:@selector(sendHeartbeat) userInfo:nil repeats:YES dispatchQueue:self.adapter.queue];
			[_heartbeatTimer fire];

			break;
		}
			
		case NSStreamEventHasBytesAvailable:
		{
			break;
		}
			
		case NSStreamEventHasSpaceAvailable:
		{
			//LogDebug(@"NSStreamEventHasSpaceAvailable");
			_outputCanWriteToStream = true;
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
				[_inputByteBuf writeBytes:_inputBuffer length:(NSUInteger)len];
			}
			else if(len == 0)
			{
				LogError(@"Input stream EOF.");
				shouldClose = true;
				break;
			}
			else if(len < 0)
			{
				LogError(@"Input stream error: %@", stream.streamError);
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

@end
