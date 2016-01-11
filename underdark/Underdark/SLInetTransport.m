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

#import "SLInetTransport.h"

#import "Commands.pb.h"

#import "UDLogging.h"
#import "UDAsyncUtils.h"

#import "SLInetLink.h"
#import "SLInetReach.h"
#import "Events.pb.h"

@import UIKit;

typedef NS_ENUM(NSUInteger, SLInetState)
{
	SLInetStateDisconnected,
	SLInetStateConnecting,
	SLInetStateConnected,
	SLInetStateDisconnecting
};

@interface SLInetTransport() <NSStreamDelegate>
{
	volatile bool _running;
	
	NSInputStream* _inputStream;
	NSOutputStream* _outputStream;
	
	NSMutableData* _inputData;		// Input frame data buffer.
	uint8_t _inputBuffer[1024];		// Input stream buffer.
	
	NSMutableArray* _outputQueue;	// Output frame queue.
	NSData* _outputData;			// Currently written frame. If nil, then we should call write: on stream directly.
	NSUInteger _outputDataOffset;	// Count of outputData's written bytes;
	
	NSMutableDictionary* _links;	// nodeId to SLInetLink
	
	SLInetReach* _reach;
	
	bool _shouldConnectAfterDisconnect;
	bool _shouldDisconnectAfterConnect;
}

@property (nonatomic) SLInetState state;

@property (nonatomic, readonly, nullable) UDRunLoopThread * inputThread;
@property (nonatomic, readonly, nullable) UDRunLoopThread * outputThread;

@end

@implementation SLInetTransport

#pragma mark - Initialization

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithNodeId:(int64_t)nodeId queue:(dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;
	
	_nodeId = nodeId;
	_queue = queue;
	_state = SLInetStateDisconnected;
	
	_reach = [[SLInetReach alloc] initWithTransport:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	
	_inputThread = [[UDRunLoopThread alloc] init];
	_inputThread.name = @"Inet Input Thread";
	
	_outputThread = [[UDRunLoopThread alloc] init];
	_outputThread.name = @"Inet Output Thread";
	
	[_inputThread start];
	[_outputThread start];
	
	return self;
}

- (void) dealloc
{
	[_reach stop];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_inputThread cancel];
	_inputThread = nil;
	
	[_outputThread cancel];
	_outputThread = nil;
}

- (void) start
{
	// Background queue.
	
	if(_running)
		return;
	
	_running = true;
	
	[_reach start];
	
	[self connect];
} //start

- (void) stop
{
	// Background queue.
	if(!_running)
		return;
	
	_running = false;
	
	[_reach stop];
	
	[self disconnect];
} //stop

#pragma mark - Application States

- (void)applicationDidEnterBackground:(NSNotification*)notification
{
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
}

#pragma mark - Actions

- (void) connect
{
	// Background queue.
	
	if(!_running)
		return;
	
	if(self.state == SLInetStateDisconnecting)
	{
		_shouldConnectAfterDisconnect = true;
		return;
	}
	
	if(self.state != SLInetStateDisconnected)
		return;
	
	_state = SLInetStateConnecting;
	LogDebug(@"Inet connecting...");
	
	NSInputStream* inputStream;
	NSOutputStream* outputStream;
	
	// CFStreamCreatePairWithSocketToHost
	[NSStream getStreamsToHostWithName:@"127.0.0.1" port:8463 inputStream:&inputStream outputStream:&outputStream];
	_inputStream = inputStream;
	_outputStream = outputStream;
	
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	[_inputStream scheduleInRunLoop:[_inputThread runLoop] forMode:NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop:[_outputThread runLoop] forMode:NSDefaultRunLoopMode];
	[_inputStream open];
	[_outputStream open];
} // connect

- (void) disconnect
{
	// Background queue.
	
	if(self.state == SLInetStateConnecting)
	{
		_shouldDisconnectAfterConnect = true;
		return;
	}
	
	if(self.state != SLInetStateConnected)
		return;
	
	[self closeStreams];
}

- (void) closeStreams
{
	// Background queue.
	
	_state = SLInetStateDisconnecting;
	LogDebug(@"Inet disconnecting...");
	
	[self performSelector:@selector(closeInputStream) onThread:_inputThread withObject:nil waitUntilDone:NO];
}

#pragma mark - Utility

- (void) onConnected
{
	// Background queue.
	
	if(self.state == SLInetStateConnected)
		return;
	
	_state = SLInetStateConnected;
	LogDebug(@"Inet connected.");

	if(_shouldDisconnectAfterConnect)
	{
		_shouldDisconnectAfterConnect = false;
		[self disconnect];
	}
}

- (void) onDisconnected
{
	// Background queue.
	
	if(self.state == SLInetStateDisconnected)
		return;
	
	_state = SLInetStateDisconnected;
	LogDebug(@"Inet disconnected.");
	
	if(_shouldConnectAfterDisconnect)
	{
		_shouldConnectAfterDisconnect = false;
		[self connect];
	}
}

- (void) closeInputStream
{
	// Input thread.
	
	if(_inputStream)
	{
		LogDebug(@"inet inputStream close()");
		
		_inputStream.delegate = nil;
		[_inputStream close];
		//[_inputStream removeFromRunLoop:[_transport.inputThread runLoop] forMode:NSDefaultRunLoopMode];
		_inputStream = nil;
	}
	
	[self performSelector:@selector(closeOutputStream) onThread:_outputThread withObject:nil waitUntilDone:NO];
}

- (void) closeOutputStream
{
	// Output thread.
	
	//[_outputQueue removeAllObjects];
	
	if(_outputStream)
	{
		LogDebug(@"inet outStream close()");
		
		_outputStream.delegate = nil;
		[_outputStream close];
		//[_outputStream removeFromRunLoop:[_transport.outputThread runLoop] forMode:NSDefaultRunLoopMode];
		_outputStream = nil;
	}
	
	sldispatch_async(self.queue, ^{
		_state = SLInetStateDisconnected;
	});
}

#pragma mark - Event handling

- (void) handleEvent:(Event*)event
{
	// Background queue.
	
	if(event.type == EventEventTypeSignal)
	{
		SLInetLink* link = self->_links[@(event.signal.nodeId)];
		if(!link)
			return;
		
		[self.delegate transport:self link:link didReceiveFrame:event.signal.data];
	}
}

- (void) link:(SLInetLink*)link sentFrame:(NSData*)frameData
{
	// Background queue.
	
	SignalCommandBuilder* signalCommand = [SignalCommand builder];
	signalCommand.nodeId = link.nodeId;
	signalCommand.data = frameData;

	CommandBuilder* command = [Command builder];
	command.type = CommandCommandTypeSignal;
	
	command.signal = [signalCommand build];
	
	NSData* commandData = [[command build] data];
	if(!commandData)
		return;
	
	[self sendFrame:commandData];
}

- (void) sendFrame:(NSData*)data
{
	// Background queue.

	if(self.state != SLInetStateConnected)
		return;
	
	NSMutableData* frameData = [NSMutableData data];
	uint32_t frameBodySize = (uint32_t)data.length;
	frameBodySize = CFSwapInt32HostToBig(frameBodySize);
	[frameData appendBytes:&frameBodySize length:sizeof(frameBodySize)];
	[frameData appendData:data];
	
	[self performSelector:@selector(writeFrame:) onThread:_outputThread withObject:frameData waitUntilDone:NO];
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
	//LogDebug(@"inet output %@", [self stringForStreamEvent:eventCode]);
	
	bool shouldClose = false;
	
	switch (eventCode)
	{
		case NSStreamEventNone:
		{
			LogError(@"inet output NSStreamEventNone (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
			
		case NSStreamEventOpenCompleted:
		{
			LogDebug(@"inet output NSStreamEventOpenCompleted");
			sldispatch_async(self.queue, ^{
				[self onConnected];
			});
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
			LogError(@"inet output NSStreamEventErrorOccurred (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
			
		case NSStreamEventEndEncountered:
		{
			LogDebug(@"inet output NSStreamEventEndEncountered (connection closed by server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
	}
	
	if(shouldClose)
	{
		stream.delegate = nil;
		[stream close];
		sldispatch_async(_queue, ^{
			[self closeStreams];
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
	
	_outputDataOffset += result;
	if(_outputDataOffset == _outputData.length)
	{
		// Frame is fully written - getting next from output queue.
		_outputDataOffset = 0;
		_outputData = nil;
		
		if(_outputQueue.count != 0)
		{
			_outputData = [_outputQueue firstObject];
			[_outputQueue removeObjectAtIndex:0];
		}
		
		//++barCount;
		//LogDebug(@"Frame sent %d", barCount);
	}
} // writeNextBytes

- (void)inputStream:(NSInputStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	// Stream thread.
	//LogDebug(@"inet input %@", [self stringForStreamEvent:eventCode]);
	
	bool shouldClose = false;
	
	switch (eventCode)
	{
		case NSStreamEventNone:
		{
			LogError(@"inet input NSStreamEventNone (cannot connect to server): %@", [stream streamError]);
			shouldClose = true;
			break;
		}
			
		case NSStreamEventOpenCompleted:
		{
			LogDebug(@"inet input NSStreamEventOpenCompleted");
			sldispatch_async(self.queue, ^{
				[self onConnected];
			});
			break;
		}
			
		case NSStreamEventEndEncountered:
			LogDebug(@"inet input NSStreamEventEndEncountered (connection closed by server): %@", [stream streamError]);
			shouldClose = true;
			// If all data hasn't been read, fall through to the "has bytes" event.
			if(![stream hasBytesAvailable])
				break;
			
		case NSStreamEventHasBytesAvailable:
		{
			//LogDebug(@"inet input NSStreamEventHasBytesAvailable");
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
			[self closeStreams];
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
		//NSData* frameData = [_inputData subdataWithRange:NSMakeRange(frameHeaderSize, frameBodySize)];
		
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
		
		/*Event* event = [Event eventFromData:frameData];
		if(event)
		{
			sldispatch_async(_queue, ^{
				[self handleEvent:event];
			});
		}*/
	} // while
} // formFrames

@end
