//
// Created by Virl on 03/09/15.
// Copyright (c) 2015 Underdark. All rights reserved.
//

#import "UDNsdAdvertiser.h"
#import "UDLogging.h"

#include <dns_sd.h>
#include <arpa/inet.h>

@interface UDNsdAdvertiser ()
{
	bool _running;
	NSString* _serviceType;
	NSString* _serviceName;

	DNSServiceRef _sdref;
}

@property (nonatomic, readonly, weak) id<UDNsdAdvertiserDelegate> delegate;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation UDNsdAdvertiser

static void UDServiceRegisterReply(
		DNSServiceRef sdRef,
		DNSServiceFlags flags,
		DNSServiceErrorType errorCode,
		const char *name,
		const char *regtype,
		const char *domain,
		void *context
)
{
	UDNsdAdvertiser* self = (__bridge UDNsdAdvertiser*) context;

	if(errorCode != kDNSServiceErr_NoError)
	{
		LogError(@"nsd adv UDServiceRegisterReply() failed.");
		[self stop];
		return;
	}
	
	LogDebug(@"nsd adv success");
}

- (instancetype) init
{
	@throw nil;
}

- (instancetype) initWithDelegate:(id<UDNsdAdvertiserDelegate>)delegate
                          service:(NSString*)serviceType
                             name:(NSString*)serviceName
                            queue:(dispatch_queue_t)queue
{
	if(!(self = [super init]))
		return self;

	_delegate = delegate;
	_serviceType = serviceType;
	_serviceName = serviceName;
	_queue = queue;

	return self;
}

- (void) dealloc
{
	[self stop];
}

- (bool) startWithPort:(int)port
{
	if(_running)
		return true;

	_running = true;

	DNSServiceErrorType result =
	DNSServiceRegister(
			&_sdref,
			_peerToPeer ? kDNSServiceInterfaceIndexP2P : kDNSServiceInterfaceIndexAny,
			_peerToPeer ? kDNSServiceFlagsIncludeP2P : 0,
			[_serviceName UTF8String],
			[_serviceType UTF8String],
			NULL,
			NULL,
			htons(port),
			0,
			NULL,
			&UDServiceRegisterReply,
			(__bridge void*) self
	);

	if(result != kDNSServiceErr_NoError)
	{
		_running = false;
		LogDebug(@"nsd browser advertiser failed");
		return false;
	}
	
	DNSServiceProcessResult(_sdref);
	
	return _running;
} // startWithPort

- (void) stop
{
	if(!_running)
		return;

	_running = false;

	DNSServiceRefDeallocate(_sdref);
	_sdref = NULL;
} // stop

@end