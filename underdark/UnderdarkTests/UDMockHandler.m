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

#import "UDMockHandler.h"

@interface UDMockHandler ()

@end

@implementation UDMockHandler

- (instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	_packets = [NSMutableDictionary dictionary];
	
	return self;
}

#pragma mark - UDRouterDelegate

- (void) router:(nonnull id<UDRouter>)router peerConnected:(int64_t)peerNodeId
{
	if(router.peers.count == 1) {
		_meshConnectedCount++;
	}
	
	_peerConnectedCount++;
}

- (void) router:(nonnull id<UDRouter>)router peerDisconnected:(int64_t)peerNodeId
{
	if(router.peers.count == 0) {
		_meshConnectedCount--;
	}
}

- (void) router:(nonnull id<UDRouter>)router didReceivePacket:(nonnull UDPacket*)packet fromPeer:(int64_t)peerNodeId
{
	/*_packets[@(packet.packetId)] = packet;
	
	if(packet.kind == UDPacketKindMockMessage)
	{
		_packetsReceivedCount++;
	}*/
}

- (void) router:(nonnull id<UDRouter>)router needsAllPacketIdsWithKindId:(int32_t)packetKindId completion:(nonnull void (^)(NSArray<NSNumber*>* _Nonnull packetIds))completion
{
	completion(@[]);
}

- (void) router:(nonnull id<UDRouter>)router needsPacketWithId:(int64_t)packetId kind:(int32_t)packetKind completion:(nonnull void (^)(UDPacket* _Nullable packet))completion
{
	completion(nil);
}

@end
