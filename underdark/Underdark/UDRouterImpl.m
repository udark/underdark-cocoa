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

#import "UDRouterImpl.h"

#import "Packets.pb.h"

@interface UDRouterImpl()
{
	NSMutableDictionary<NSNumber*, UDPacketKind*> * _packetKinds;
	NSMutableDictionary<NSNumber*, id<UDLink>> * _links;
}

@end

@implementation UDRouterImpl

#pragma mark - Initialization

- (instancetype) initWithTransport:(nonnull id<UDTransport>)transport delegate:(nullable id<UDRouterDelegate>) delegate
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	_delegate = delegate;
	_packetKinds = [NSMutableDictionary dictionary];
	_links = [NSMutableDictionary dictionary];
	
	return self;
}

#pragma mark - UDRouter

- (NSArray<NSNumber*>*) peers
{
	return _links.allKeys;
}

- (void) registerPacketKind:(nonnull UDPacketKind*)packetKind
{
	_packetKinds[@(packetKind.kindId)] = (UDPacketKind*)[packetKind copy];
}

- (void) unregisterPacketKind:(int32_t)packetKindId
{
	[_packetKinds removeObjectForKey:@(packetKindId)];
}

- (void) start
{
	[_transport start];
}

- (void) stop
{
	[_transport stop];
}

- (void) sendPacketToSelf:(nonnull UDPacket*)packet
{
	
}

- (void) sendPacketToAll:(nonnull UDPacket*)packet
{
	
}

#pragma mark - UDTransportDelegate

- (void) transport:(id<UDTransport>)transport linkConnected:(id<UDLink>)link
{
	_links[@(link.nodeId)] = link;
	
	[self.delegate router:self peerConnected:link.nodeId];
}

- (void) transport:(id<UDTransport>)transport linkDisconnected:(id<UDLink>)link
{
	if(_links[@(link.nodeId)] == nil)
		return;
	
	[_links removeObjectForKey:@(link.nodeId)];
	[self.delegate router:self peerConnected:link.nodeId];
}

- (void) transport:(id<UDTransport>)transport link:(id<UDLink>)link didReceiveFrame:(NSData*)frameData
{
	Packet* packet;
	
	@try {
		packet = [Packet parseFromData:frameData];
	}
	@catch (NSException *exception) {
		return;
	}
	@finally {
	}
	
	UDPacketKind* packetKind = _packetKinds[@(packet.packetId)];
	if(packetKind == nil)
		return;
	
	if(packetKind.listenable)
	{
		UDPacket* udpacket = [[UDPacket alloc] init];
		udpacket.packetId = packet.packetId;
		udpacket.kind = packet.kind;
		udpacket.nodeId = packet.nodeId;
		udpacket.age = packet.age;
		udpacket.payload = packet.payload;
		
		[self.delegate router:self didReceivePacket:udpacket fromPeer:link.nodeId];
	}
} // didReceiveFrame

@end
