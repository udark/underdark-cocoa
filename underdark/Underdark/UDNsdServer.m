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

#import "UDNsdServer.h"

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#import "UDRunLoopThread.h"
#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDNsdLink.h"

// Listening using CFSocket:
// https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/UsingSocketsandSocketStreams.html#//apple_ref/doc/uid/CH73-SW8

// CFRunLoop internals:
// http://stackoverflow.com/a/15168471

@interface UDNsdServer ()
{
	bool _accepting;

	UDRunLoopThread* _acceptThread;

	CFSocketRef _socket;
	
	NSMutableArray* _links;
	NSMutableArray* _linksConnecting;
	NSMutableArray* _linksTerminating;
}

@property (nonatomic, readonly, weak) id<UDNsdServerDelegate> delegate;

@end

@implementation UDNsdServer

static void UDServerSocketCallBack(
		CFSocketRef socket,
		CFSocketCallBackType callbackType,
		CFDataRef address,
		const void *data,
		void *info)
{
	// Accept Thread
	if(callbackType != kCFSocketAcceptCallBack)
		return;

	UDNsdServer* server = (__bridge UDNsdServer*) info;
	CFSocketNativeHandle handle = *((CFSocketNativeHandle*)data);
	NSData* addressData = (__bridge NSData*)address;

	sldispatch_async(server.queue, ^
	{
	    [server acceptCallback:socket address:addressData handle:handle];
	});
}

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithDelegate:(id<UDNsdServerDelegate>)delegate nodeId:(int64_t)nodeId queue:(nonnull dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;

	_delegate = delegate;
	_queue = queue;
	_nodeId = nodeId;
	_priority = 10;

	_links = [NSMutableArray array];
	_linksConnecting = [NSMutableArray array];
	_linksTerminating = [NSMutableArray array];
	
	_acceptThread = [[UDRunLoopThread alloc] init];
	_acceptThread.coreFoundation = true;
	_acceptThread.name = @"UDNsdServer Accept";
	[_acceptThread start];
	
	_ioThread = [[UDRunLoopThread alloc] init];
	_ioThread.name = @"UDNsdServer I/O";
	[_ioThread start];
	
	return self;
}

- (void) dealloc
{
	[_acceptThread cancel];
	[_ioThread cancel];
}

- (bool) startAccepting
{
	if(_accepting)
		return false;

	// Create socket objects.

	CFSocketContext context;
	context.version = 0;
	context.info = (__bridge void*) self;
	context.retain = CFRetain;
	context.release = CFRelease;
	context.copyDescription = NULL;

	_socket = CFSocketCreate(
			kCFAllocatorDefault,
			PF_INET,
			SOCK_STREAM,
			IPPROTO_TCP,
			kCFSocketAcceptCallBack,
			&UDServerSocketCallBack,
			&context
	);

	if(_socket == NULL)
	{
		LogError(@"nsd CFSocketCreate() failed.");
		return false;
	}
	
	// Bind socket.

	struct sockaddr_in sin;

	memset(&sin, 0, sizeof(sin));
	sin.sin_len = sizeof(sin);
	sin.sin_family = AF_INET;
	sin.sin_port = htons(0);
	sin.sin_addr.s_addr = INADDR_ANY;

	CFDataRef sincfd = CFDataCreate(
			kCFAllocatorDefault,
			(UInt8 *)&sin,
			sizeof(sin));

	CFSocketError socketError = CFSocketSetAddress(_socket, sincfd);
	CFRelease(sincfd);

	if(socketError != kCFSocketSuccess)
	{
		LogError(@"nsd CFSocketSetAddress failed.");
		CFSocketInvalidate(_socket);
		CFRelease(_socket);
		
		return false;
	}
	
	_accepting = true;

	// Schedule socket on runloop

	CFRunLoopSourceRef socketsource = CFSocketCreateRunLoopSource(
			kCFAllocatorDefault,
			_socket,
			0);
	
	CFRunLoopAddSource(
			_acceptThread.cfRunLoop,
			socketsource,
			kCFRunLoopDefaultMode);
	
	CFRelease(socketsource);
	
	// Report socket port to delegate
	
	NSData* addressData = (__bridge_transfer NSData*) CFSocketCopyAddress(_socket);
	struct sockaddr_in *sa = (struct sockaddr_in*)addressData.bytes;
	_port = ntohs(sa->sin_port);
	
	LogDebug(@"nsd bind port %d", _port);
	
	return true;
} // startAccepting

- (void) stopAccepting
{
	if(!_accepting)
		return;

	_accepting = false;

	CFSocketInvalidate(_socket);
	CFRelease(_socket);
} // stopAccepting

- (void) acceptCallback:(CFSocketRef)socket
                address:(NSData*)addressData
                 handle:(CFSocketNativeHandle)handle
{
	// Transport queue.
	
	if(!CFEqual(socket, _socket))
	{
		CFSocketInvalidate(socket);
		CFRelease(socket);
		return;
	}

	struct sockaddr_in *sa = (struct sockaddr_in*)addressData.bytes;

	char buf[INET6_ADDRSTRLEN];
	inet_ntop(sa->sin_family, &(sa->sin_addr), buf, INET6_ADDRSTRLEN);

	NSString* address = [NSString stringWithUTF8String:buf];

	LogDebug(@"nsd accept() host %@", address);
	
	CFReadStreamRef readStream = NULL;
	CFWriteStreamRef writeStream = NULL;
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, handle, &readStream, &writeStream);
	
	if(!readStream || !writeStream)
	{
		LogWarn(@"nsd accept CFStreamCreatePairWithSocket() failed.");
		
		if (readStream)
			CFRelease(readStream);
		
		if (writeStream)
			CFRelease(writeStream);
		
		close(handle);
		return;
	}
	
	CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	NSInputStream* inputStream = (__bridge_transfer NSInputStream*)readStream;
	NSOutputStream* outputStream = (__bridge_transfer NSOutputStream*)writeStream;
	
	LogDebug(@"nsd accepted host '%@'", address);
	
	UDNsdLink* link = [[UDNsdLink alloc] initWithServer:self input:inputStream output:outputStream];
	[self linkConnecting:link];
	[link connect];
} // acceptCallback

- (bool) isLinkConnectedToNodeId:(int64_t)nodeId
{
	for(UDNsdLink* link in _links)
	{
		if(link.nodeId == nodeId)
			return true;
	}
	
	return false;
}

- (void) connectToHost:(NSString*)host port:(uint16_t)port interface:(uint32_t)interfaceIndex
{
	CFReadStreamRef readStream = NULL;
	CFWriteStreamRef writeStream = NULL;
	
	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)host, port, &readStream, &writeStream);
	
	if(!readStream || !writeStream)
	{
		LogWarn(@"nsd connect CFStreamCreatePairWithSocketToHost() failed.");
		
		if (readStream)
			CFRelease(readStream);
		
		if (writeStream)
			CFRelease(writeStream);
		
		return;
	}
	
	NSInputStream* inputStream = (__bridge_transfer NSInputStream*)readStream;
	NSOutputStream* outputStream = (__bridge_transfer NSOutputStream*)writeStream;
	
	LogDebug(@"nsd connect host '%@:%d'", host, port);
	
	UDNsdLink* link = [[UDNsdLink alloc] initWithServer:self input:inputStream output:outputStream];
	link.interfaceIndex = interfaceIndex;
	[self linkConnecting:link];
	[link connect];
} // connectToHost

#pragma mark - Links

- (void) linkConnecting:(UDNsdLink *)link
{
	// Transport queue.
	
	[_linksConnecting addObject:link];
}

- (void) linkConnected:(UDNsdLink *)link
{
	// Transport queue.
	
	[_linksConnecting removeObject:link];
	[_links addObject:link];
	
	[self->_delegate server:self linkConnected:link];
}

- (void) linkDisconnected:(UDNsdLink *)link
{
	// Transport queue.
	
	bool wasConnected = [_links containsObject:link];
	[_links removeObject:link];
	[_linksConnecting removeObject:link];
	
	if(![_linksTerminating containsObject:link])
		[_linksTerminating addObject:link];
	
	if(wasConnected)
	{
		sldispatch_async(self.queue, ^{
			[self->_delegate server:self linkDisconnected:link];
		});
	}
}

- (void) linkTerminated:(UDNsdLink *)link
{
	// Transport queue.
	
	[_linksTerminating removeObject:link];
}

- (void) link:(UDNsdLink *)link didReceiveFrame:(NSData*)frameData
{
	// Transport queue.
	[self->_delegate server:self link:link didReceiveFrame:frameData];
}

@end