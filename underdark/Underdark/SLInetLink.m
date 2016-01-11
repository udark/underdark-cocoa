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

#import "SLInetLink.h"

#import "SLInetTransport.h"

@interface SLInetLink()

@property (nonatomic, weak) SLInetTransport* transport;

@end

@implementation SLInetLink

- (instancetype) initWithTransport:(SLInetTransport*)transport nodeId:(int64_t)nodeId
{
	if(!(self = [super init]))
		return self;
	
	_transport = transport;
	
	_nodeId = nodeId;
	_slowLink = true;
	
	return self;
}

- (void) dealloc
{
	
}

- (int16_t) priority
{
	return 20;
}

- (void) sendFrame:(NSData*)data
{
	[self.transport link:self sentFrame:data];
}

- (void) disconnect
{
	
}

@end
