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

#import "UDNsdBrowser.h"

#include <dns_sd.h>
#include <netdb.h>
#include <arpa/inet.h>

#import "UDLogging.h"
#import "UDAsyncUtils.h"
#import "UDRunLoopThread.h"
#import "UDNsdUtil.h"
#import "UDNsdService.h"

// https://developer.apple.com/library/ios/documentation/Networking/Reference/DNSServiceDiscovery_CRef/

// kDNSServiceFlagsIncludeP2P

// kDNSServiceInterfaceIndexAny
// kDNSServiceInterfaceIndexP2P

@interface UDNsdBrowser () <UDNsdServiceDelegate>
{
	NSString* _serviceType;
	
	UDRunLoopThread* _thread;

	DNSServiceRef _browseRef;
	CFFileDescriptorRef _browseFd;
	CFRunLoopSourceRef _browseSource;
	
	NSMutableArray* _services;
}

@property (nonatomic, readonly) bool running;

@property (nonatomic, readonly, weak) id<UDNsdBrowserDelegate> delegate;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation UDNsdBrowser

// Service resolving:
// https://developer.apple.com/library/mac/documentation/Networking/Conceptual/dns_discovery_api/Articles/resolving.html

static void UDServiceBrowseReply(
		DNSServiceRef sdRef,
		DNSServiceFlags flags,
		uint32_t interfaceIndex,
		DNSServiceErrorType errorCode,
		const char *name,
		const char *regtype,
		const char *domain,
		void *context)
{
	if(errorCode != kDNSServiceErr_NoError)
	{
		LogError(@"nsd UDServiceBrowseReply() errorCode = %d", errorCode);
		return;
	}

	UDNsdBrowser* self = (__bridge UDNsdBrowser*) context;
	if(!self.running)
		return;

	NSString* serviceName = [NSString stringWithUTF8String:name];
	NSString* serviceRegType = [NSString stringWithUTF8String:regtype];
	NSString* serviceDomain = [NSString stringWithUTF8String:domain];

	if ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd)
	{
		// Added
		LogDebug(@"nsd browse add %@ iface %d", serviceName, interfaceIndex);
		
		UDNsdService* service = [[UDNsdService alloc] initWithDelegate:self thread:self->_thread];
		service.peerToPeer = self->_peerToPeer;
		service.flags = flags;
		service.interfaceIndex = interfaceIndex;
		service.name = serviceName;
		service.regtype = serviceRegType;
		service.domain = serviceDomain;
		
		[self->_services addObject:service];
		[service resolve];
	}
	else
	{
		// Removed
		LogDebug(@"nsd browse remove %@", serviceName);
	}
} // UDServiceBrowseReply

static void UDFileDescriptorCallBack(CFFileDescriptorRef fd, CFOptionFlags callBackTypes, void *info)
{
	if((callBackTypes & kCFFileDescriptorReadCallBack) == 0)
		return;
	
	UDNsdBrowser* self = (__bridge UDNsdBrowser*) info;
	if(!self.running)
		return;
	
	if(CFEqual(fd, self->_browseFd))
	{
		DNSServiceProcessResult(self->_browseRef);
		return;
	}
	
} // UDFileDescriptorCallBack

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithDelegate:(id<UDNsdBrowserDelegate>)delegate
                          service:(NSString*)serviceType
                            queue:(dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;

	_delegate = delegate;
	_serviceType = serviceType;
	_queue = queue;

	_services = [NSMutableArray array];
	
	_thread = [[UDRunLoopThread alloc] init];
	_thread.name = @"UDNsdBrowser";
	_thread.coreFoundation = true;
	[_thread start];
	
	return self;
}

- (void) dealloc
{
	[self stop];
	[_thread cancel];
	_thread = nil;
}

- (void) start
{
	CFRunLoopPerformBlock(_thread.cfRunLoop, kCFRunLoopDefaultMode, ^{
		[self startImpl];
	});
	
	CFRunLoopWakeUp(_thread.cfRunLoop);
}

- (void) stop
{
	dispatch_group_t group = dispatch_group_create();
	dispatch_group_enter(group);
	
	CFRunLoopPerformBlock(_thread.cfRunLoop, kCFRunLoopDefaultMode, ^{
		[self stopImpl];
		dispatch_group_leave(group);
	});
	
	CFRunLoopWakeUp(_thread.cfRunLoop);
	
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

- (void) startImpl
{
	if(_running)
		return;

	_running = true;

	DNSServiceErrorType result =
	DNSServiceBrowse(
			&_browseRef,
			_peerToPeer ? kDNSServiceFlagsIncludeP2P : 0,
			_peerToPeer ? kDNSServiceInterfaceIndexP2P : kDNSServiceInterfaceIndexAny,
			[_serviceType UTF8String],
			NULL,
			&UDServiceBrowseReply,
			(__bridge void*)self
	);

	if(result != kDNSServiceErr_NoError)
	{
		_running = false;
		LogDebug(@"nsd browser start failed");
		return;
	}
	
	int fd = DNSServiceRefSockFD(_browseRef);
	
	CFFileDescriptorContext context;
	context.info = (__bridge void*)self;
	context.retain = &UDCallbackInfoRetain;
	context.release = &UDCallbackInfoRelease;
	context.copyDescription = &UDCallbackDescription;
	
	_browseFd =	CFFileDescriptorCreate(kCFAllocatorDefault, fd, false, &UDFileDescriptorCallBack, &context);
	CFFileDescriptorEnableCallBacks(_browseFd, kCFFileDescriptorReadCallBack);
	
	_browseSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, _browseFd, 0);
	CFRunLoopAddSource(_thread.cfRunLoop, _browseSource, kCFRunLoopDefaultMode);
	CFRunLoopWakeUp(_thread.cfRunLoop);
} // start

- (void) stopImpl
{
	if(!_running)
		return;

	_running = false;

	CFRelease(_browseFd);
	_browseFd = NULL;
	
	CFRunLoopRemoveSource(_thread.cfRunLoop, _browseSource, kCFRunLoopDefaultMode);
	CFRelease(_browseSource);
	_browseSource = NULL;
	
	DNSServiceRefDeallocate(_browseRef);
	_browseRef = NULL;
	
	for(UDNsdService* service in _services)
	{
		[service cancelResolve];
	}
	
	[_services removeAllObjects];
} // stop

- (void) reconfirmRecord:(NSString*)name interface:(uint32_t)interfaceIndex
{
	// https://developer.apple.com/library/prerelease/ios/documentation/Networking/Conceptual/NSNetServiceProgGuide/Articles/ResolvingServices.html#//apple_ref/doc/uid/20001078-SW9
	
	// serviceName should be in the form
	// "name.service.protocol.domain.".  For example:
	// "MyLaptop._ftp._tcp.local."
	NSString* serviceName = SFMT(@"%@.%@", name, _serviceType);
	
	if([serviceName characterAtIndex:serviceName.length - 1] == '.')
	{
		serviceName = [serviceName stringByAppendingString:@"local."];
	}
	else
	{
		serviceName = [serviceName stringByAppendingString:@".local."];
	}
	
	NSArray * serviceNameComponents;
	NSUInteger serviceNameComponentsCount;
	
	// "nodeId._underdark1-app4325._tcp.local."
	serviceNameComponents = [serviceName componentsSeparatedByString:@"."];
	serviceNameComponentsCount = [serviceNameComponents count];
	
	if ((serviceNameComponentsCount < 5) || ([serviceNameComponents[serviceNameComponentsCount - 1] length] != 0))
		return;

	NSString* protocol = [serviceNameComponents[2] lowercaseString];
	if ( ![protocol isEqual:@"_tcp"] && ![protocol isEqual:@"_udp"] )
	 	return;
	
	NSString* domainFullName = [[serviceNameComponents subarrayWithRange:NSMakeRange(1, serviceNameComponentsCount - 1)] componentsJoinedByString:@"."];
	
	NSMutableData* recordData = [[NSMutableData alloc] init];
	for (NSString * label in serviceNameComponents)
	{
		const char *    labelStr;
		uint8_t         labelStrLen;
		
		labelStr = [label UTF8String];
		if (strlen(labelStr) >= 64)
		{
			LogWarn(@"nsd browse reconfirm label too long: '%@'", label);
			return;
		}
		
		// cast is safe because of length check
		labelStrLen = (uint8_t) strlen(labelStr);
			
		[recordData appendBytes:&labelStrLen length:sizeof(labelStrLen)];
		[recordData appendBytes:labelStr length:labelStrLen];
	}
	
	if ([recordData length] >= 256)
	{
		LogWarn(@"nsd browse reconfirm record data too long");
		return;
	}
	
	DNSServiceErrorType err = DNSServiceReconfirmRecord(
									0,
									interfaceIndex,
									[domainFullName UTF8String],
									kDNSServiceType_PTR,
									kDNSServiceClass_IN,
									// cast is safe because of recordData length check above
									(uint16_t) [recordData length],
									[recordData bytes]
									);
	if (err != kDNSServiceErr_NoError)
	{
		LogWarn(@"nsd browse reconfirm record error: %d '%@' iface=(%d)'%@'", (int) err, UDDnsErrorToString(err), interfaceIndex, UDInterfaceIndexToName(interfaceIndex));
		return;
	}
	
	LogDebug(@"nsd browse reconfirm success iface = %d", interfaceIndex);
} // reconfirmRecord

#pragma mark - UDNsdServiceDelegate

- (void) serviceDidResolve:(UDNsdService*)service
{
	[_services removeObject:service];
	
	LogDebug(@"nsd resolved '%@' host '%@:%d' iface (%d)'%@'", service.name, service.host, service.port, service.interfaceIndex, UDInterfaceIndexToName(service.interfaceIndex));
	
	sldispatch_async(self.queue, ^{
		[self.delegate serviceResolved:service];
	});
} // serviceDidResolve

- (void) serviceDidNotResolve:(UDNsdService *)service
{
	[_services removeObject:service];
}

@end
