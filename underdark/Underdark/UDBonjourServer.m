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

#import "UDBonjourServer.h"

#import "UDLogging.h"
#import "UDBonjourChannel.h"
#import "UDAsyncUtils.h"

@interface UDBonjourServer() <NSNetServiceDelegate>
{
	bool _running;
	__weak UDBonjourAdapter* _adapter;
	NSNetService* _service;
}
@end

@implementation UDBonjourServer

- (nullable instancetype) init
{
	return nil;
}

- (nonnull instancetype) initWithAdapter:(nonnull UDBonjourAdapter*)adapter
{
	if(!(self = [super init]))
		return self;
	
	_adapter = adapter;
	
	return self;
}

- (void) start
{
	if(_running)
		return;
	
	_service = [[NSNetService alloc] initWithDomain:@"" type:_adapter.serviceType name:@(_adapter.nodeId).description port:0];
	if(!_service)
		return;
	
	_running = true;
	
	_service.includesPeerToPeer = _adapter.peerToPeer;
	_service.delegate = self;
	[_service scheduleInRunLoop:_adapter.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	//[_service startMonitoring];
	
	[_service publishWithOptions:NSNetServiceListenForConnections];
}

- (void) stop
{
	if(!_running)
		return;
	
	_running = false;
	
	//[_service stopMonitoring];
	[_service stop];
	[_service removeFromRunLoop:_adapter.ioThread.runLoop forMode:NSDefaultRunLoopMode];
	_service.delegate = nil;
	_service = nil;
}

- (void) restart
{	
	[self stop];
	[self start];
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidStop:(NSNetService *)sender
{
	// I/O thread.
	
	if(sender != _service)
		return;
	
	LogDebug(@"bnj netServiceDidStop");
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
	// I/O thread.
	
	if(sender != _service)
		return;
	
	LogDebug(@"bnj didUpdateTXTRecordData");
	
	if(!_running)
		return;
	
	//[_service publishWithOptions:NSNetServiceListenForConnections];
}

- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
	// I/O thread.
	
	if(sender != _service)
		return;
	
	//LogDebug(@"bnj didAcceptConnection");
	
	UDBonjourChannel* link = [[UDBonjourChannel alloc] initWithAdapter:_adapter input:inputStream output:outputStream];
	[_adapter channelConnecting:link];
	
	[link connect];
}

- (void)netServiceWillPublish:(NSNetService *)sender
{
	// I/O thread.
	
	if(sender != _service)
		return;
	
	LogDebug(@"bnj netServiceWillPublish");
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
	// I/O thread.
	
	if(sender != _service)
		return;
	
	LogDebug(@"bnj netServiceDidPublish");
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
	// I/O thread.
	
	if(sender != _service)
		return;
	
	LogDebug(@"bnj netServiceDidNotPublish %@", errorDict[NSNetServicesErrorCode]);
	
	dispatch_async(_adapter.queue, ^{
		[_adapter serverDidFail];
	});
}

@end
