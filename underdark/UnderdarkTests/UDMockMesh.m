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

#import "UDMockMesh.h"

#import "UDMockLink.h"
#import "UDUtil.h"

@interface UDMockMesh ()
{
	NSMutableArray* _nodes;
}
@end

@implementation UDMockMesh
@synthesize nodes = _nodes;

- (instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	_nodes = [NSMutableArray array];
	
	return self;
}

- (UDMockNode*)node:(NSUInteger)i
{
	return _nodes[i];
}

- (void) addNode:(UDMockNode*)node
{
	[_nodes addObject:node];
}

- (void) c:(NSUInteger)i t:(NSUInteger)j
{
	UDMockNode* node1 = _nodes[i];
	UDMockNode* node2 = _nodes[j];
	
	UDMockLink* link1 = [node1 connectTo:node2];
	UDMockLink* link2 = [node2 connectTo:node1];
	link1.link = link2;
	link2.link = link1;
	[node1 didConnectTo:link1];
	[node2 didConnectTo:link2];
}

- (void) sendPacket:(NSUInteger)i
{
	UDMockNode* node = _nodes[i];
	
	UDPacket* packet = [[UDPacket alloc] init];
	packet.packetId = [UDUtil generateId];
	packet.kind = UDPacketKindMockMessage;
	packet.payload = [@"Some message" dataUsingEncoding:NSUTF8StringEncoding];
	
	[node broadcastPacket:packet];
}

- (UDPacket*) messagePacket:(int64_t)nodeId
{
	/*MessageSignalBuilder* payload = [MessageSignal builder];
	payload.kind = MediaKindText;
	payload.text = @"Some message";
	
	SignalBuilder* signal = [Signal builder];
	signal.signalId = [Signal uuidInteger];
	signal.kind = SignalKindMessage;
	signal.nodeId = nodeId;
	signal.agems = 0;
	signal.local = false;
	
	signal.message = [payload build];
	
	return [signal build];*/
	return nil;
}

- (UDPacket*) greetingPacket:(int64_t)nodeId signalIds:(NSArray*)packetIds
{
	/*if(!signalIds)
		signalIds = @[];
	
	GreetingSignalBuilder* payload = [GreetingSignal builder];
	[payload setSignalIdsArray:signalIds];
	
	SignalBuilder* signal = [Signal builder];
	signal.signalId = [Signal uuidInteger];
	signal.kind = SignalKindGreeting;
	signal.nodeId = nodeId;
	signal.agems = 0;
	signal.local = true;
	
	signal.greeting = [payload build];
	
	return [signal build];*/
	return nil;
}

@end
