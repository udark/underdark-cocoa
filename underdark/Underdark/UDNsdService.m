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

#import "UDNsdService.h"

#include <dns_sd.h>
#include <arpa/inet.h>

#import "UDRunLoopThread.h"
#import "UDNsdUtil.h"
#import "UDLogging.h"
#import "UDConfig.h"

@interface UDNsdService()
{
	bool _queryingName;
	
	DNSServiceRef _resolveRef;
	CFFileDescriptorRef _fd;
	CFRunLoopSourceRef _source;
}

@property (nonatomic, readonly, weak) id<UDNsdServiceDelegate> delegate;
@property (nonatomic, readonly, weak) UDRunLoopThread* thread;

@end

@implementation UDNsdService

static void UDServiceFileDescriptorCallBack(CFFileDescriptorRef fd, CFOptionFlags callBackTypes, void *info)
{
	if((callBackTypes & kCFFileDescriptorReadCallBack) == 0)
		return;
	
	UDNsdService* self = (__bridge UDNsdService*) info;
	if(self->_resolveRef == NULL)
		return;
	
	if(!CFEqual(fd, self->_fd))
		return;
	
	DNSServiceProcessResult(self->_resolveRef);
} // UDFileDescriptorCallBack

static void UDServiceGetAddrInfoReply(
								DNSServiceRef sdRef,
								DNSServiceFlags flags,
								uint32_t interfaceIndex,
								DNSServiceErrorType errorCode,
								const char *hostname,
								const struct sockaddr *sa,
								uint32_t ttl,
								void *context)
{
	UDNsdService* self = (__bridge UDNsdService*) context;
	
	if(self->_resolveRef == NULL)
		return;
	
	if(errorCode != kDNSServiceErr_NoError)
	{
		LogError(@"nsd resolve UDServiceGetAddrInfoReply() errorCode = %d", errorCode);
		
		[self cancelResolve];
		[self->_delegate serviceDidNotResolve:self];
		return;
	}
	
	[self cancelResolve];

	char buff[INET6_ADDRSTRLEN];
	const char* result = NULL;
	
	if (sa->sa_family == AF_INET)
	{
		struct sockaddr_in *sin = (struct sockaddr_in *) sa;
		
		result =
		inet_ntop(sin->sin_family, &sin->sin_addr, buff, INET_ADDRSTRLEN);
	}
	
	if (sa->sa_family == AF_INET6)
	{
		struct sockaddr_in6 *sin = (struct sockaddr_in6*) sa;
		
		result =
		inet_ntop(sin->sin6_family, &sin->sin6_addr, buff, INET6_ADDRSTRLEN);
	}
	
	if(result == NULL)
	{
		LogError(@"nsd resolve inet_ntop() failed.");
		return;
	}
	
	self->_address = [NSString stringWithUTF8String:result];
	
	[self->_delegate serviceDidResolve:self];
} // UDServiceGetAddrInfoReply

static void UDResolveRunLoopTimerCallBack(CFRunLoopTimerRef timer, void *info)
{
	UDNsdService* self = (__bridge UDNsdService*) info;
	if(self->_resolveRef == NULL)
		return;
	
	LogError(@"nsd resolve DNSServiceGetAddrInfo() timeout.");
	[self cancelResolve];
	[self->_delegate serviceDidNotResolve:self];
}

static void UDServiceResolveReply(
								  DNSServiceRef sdRef,
								  DNSServiceFlags flags,
								  uint32_t interfaceIndex,
								  DNSServiceErrorType errorCode,
								  const char *fullname,
								  const char *host,
								  uint16_t nport, /* In network byte order */
								  uint16_t txtLen,
								  const unsigned char *txtRecord,
								  void *context)
{
	UDNsdService* self = (__bridge UDNsdService*) context;
	
	if(self->_resolveRef == NULL)
		return;

	if(errorCode != kDNSServiceErr_NoError)
	{
		LogError(@"nsd resolve UDServiceResolveReply() errorCode = %d", errorCode);
		
		[self cancelResolve];
		[self->_delegate serviceDidNotResolve:self];
		
		return;
	}
	
	//NSString* serviceFullName = [NSString stringWithUTF8String:fullname];
	self->_host = [NSString stringWithUTF8String:host];
	self->_port = ntohs(nport);
	
	[self cancelResolve];
	
	self->_queryingName = true;
	
	DNSServiceErrorType result =
	DNSServiceGetAddrInfo(&self->_resolveRef, self->_peerToPeer ? kDNSServiceFlagsIncludeP2P : 0, 0, kDNSServiceProtocol_IPv4, host, &UDServiceGetAddrInfoReply, (__bridge void*) self);
	
	if(result != kDNSServiceErr_NoError)
	{
		LogError(@"nsd resolve DNSServiceGetAddrInfo() failed errorCode = %d", result);
		
		[self cancelResolve];
		[self->_delegate serviceDidNotResolve:self];
		return;
	}
	
	int fd = DNSServiceRefSockFD(self->_resolveRef);
	
	CFFileDescriptorContext fdcontext;
	fdcontext.version = 0;
	fdcontext.info = (__bridge void*)self;
	fdcontext.retain = &UDCallbackInfoRetain;
	fdcontext.release = &UDCallbackInfoRelease;
	fdcontext.copyDescription = &UDCallbackDescription;
	
	self->_fd = CFFileDescriptorCreate(kCFAllocatorDefault, fd, false, &UDServiceFileDescriptorCallBack, &fdcontext);
	if(self->_fd == NULL)
	{
		LogError(@"nsd resolve address CFFileDescriptorCreate() failed.");
		
		DNSServiceRefDeallocate(self->_resolveRef);
		self->_resolveRef = NULL;
		
		[self.delegate serviceDidNotResolve:self];
		return;
	}
	
	CFFileDescriptorEnableCallBacks(self->_fd, kCFFileDescriptorReadCallBack);
	
	self->_source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, self->_fd, 0);
	if(self->_source == NULL)
	{
		LogError(@"nsd resolve address CFFileDescriptorCreateRunLoopSource() failed.");
		
		CFRelease(self->_fd);
		self->_fd = NULL;
		
		
		DNSServiceRefDeallocate(self->_resolveRef);
		self->_resolveRef = NULL;
		
		[self.delegate serviceDidNotResolve:self];
		return;
	}
	
	CFRunLoopAddSource(self->_thread.cfRunLoop, self->_source, kCFRunLoopDefaultMode);
	CFRunLoopWakeUp(self->_thread.cfRunLoop);
	
	// Name resolve timeout timer.
	CFRunLoopTimerContext ticontext;
	ticontext.version = 0;
	ticontext.info = (__bridge void*)self;
	ticontext.retain = &CFRetain;
	ticontext.release = &CFRelease;
	ticontext.copyDescription = NULL;
	
	CFRunLoopTimerRef timer =
	CFRunLoopTimerCreate(kCFAllocatorDefault, [[NSDate date] timeIntervalSinceReferenceDate] + configNsdResolveTimeout, 0, 0, 0, &UDResolveRunLoopTimerCallBack, &ticontext);
	CFRunLoopAddTimer(self->_thread.cfRunLoop, timer, kCFRunLoopDefaultMode);
	CFRelease(timer);
} // UDServiceResolveReply

- (instancetype) initWithDelegate:(id<UDNsdServiceDelegate>)delegate thread:(UDRunLoopThread*)thread
{
	if(!(self = [super init]))
		return self;
	
	_delegate = delegate;
	_thread = thread;
	
	return self;
}

- (void) cancelResolve
{
	if(_fd != NULL)
	{
		CFRelease(_fd);
		_fd = NULL;
	}

	if(_source != NULL)
	{
		CFRunLoopRemoveSource(_thread.cfRunLoop, _source, kCFRunLoopDefaultMode);
		CFRelease(_source);
		_source = NULL;
	}

	if(_resolveRef != NULL)
	{
		DNSServiceRefDeallocate(_resolveRef);
		_resolveRef = NULL;
	}
} // cancelResolve

- (void) resolve
{
	DNSServiceErrorType result =
	DNSServiceResolve(
					  &_resolveRef,
					  _flags,
					  _interfaceIndex,
					  _name.UTF8String,
					  _regtype.UTF8String,
					 _domain.UTF8String,
					  &UDServiceResolveReply,
					  (__bridge void*) self);
	
	if(result != kDNSServiceErr_NoError)
	{
		LogError(@"nsd resolve DNSServiceResolve() failed.");
		[self.delegate serviceDidNotResolve:self];
		return;
	}
	
	int fd = DNSServiceRefSockFD(_resolveRef);
	
	CFFileDescriptorContext context;
	context.info = (__bridge void*)self;
	context.retain = &UDCallbackInfoRetain;
	context.release = &UDCallbackInfoRelease;
	context.copyDescription = &UDCallbackDescription;
	
	_fd = CFFileDescriptorCreate(kCFAllocatorDefault, fd, false, &UDServiceFileDescriptorCallBack, &context);
	if(_fd == NULL)
	{
		LogError(@"nsd resolve CFFileDescriptorCreate() failed.");
		
		DNSServiceRefDeallocate(_resolveRef);
		_resolveRef = NULL;
		
		[self.delegate serviceDidNotResolve:self];
		return;
	}
	
	CFFileDescriptorEnableCallBacks(_fd, kCFFileDescriptorReadCallBack);
	
	_source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, _fd, 0);
	if(_source == NULL)
	{
		LogError(@"nsd resolve CFFileDescriptorCreateRunLoopSource() failed.");
	
		CFRelease(_fd);
		_fd = NULL;
		
		
		DNSServiceRefDeallocate(_resolveRef);
		_resolveRef = NULL;
		
		[self.delegate serviceDidNotResolve:self];
		return;
	}
	
	CFRunLoopAddSource(_thread.cfRunLoop, _source, kCFRunLoopDefaultMode);
	CFRunLoopWakeUp(_thread.cfRunLoop);
} // resolve

@end
