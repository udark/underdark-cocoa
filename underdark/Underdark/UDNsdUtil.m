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

#import "UDNsdUtil.h"

#include <net/if.h>

void* UDCallbackInfoRetain(void* info)
{
	return (void*) CFRetain(info);
}

void UDCallbackInfoRelease(void* info)
{
	return CFRelease(info);
}

CFStringRef UDCallbackDescription(void*info)
{
	NSObject* obj = (__bridge NSObject*)info;
	return (__bridge_retained CFStringRef) obj.description;
}

NSString* UDDnsErrorToString(DNSServiceErrorType error)
{
	NSString* str = @"";
	
	switch (error)
	{
		case kDNSServiceErr_NoError:
			str = @"kDNSServiceErr_NoError";
			break;
		case kDNSServiceErr_Unknown:
			str = @"kDNSServiceErr_Unknown";
			break;
		case kDNSServiceErr_NoSuchName:
			str = @"kDNSServiceErr_NoSuchName";
			break;
		case kDNSServiceErr_NoMemory:
			str = @"kDNSServiceErr_NoMemory";
			break;
		case kDNSServiceErr_BadParam:
			str = @"kDNSServiceErr_BadParam";
			break;
		case kDNSServiceErr_BadReference:
			str = @"kDNSServiceErr_BadReference";
			break;
		case kDNSServiceErr_BadState:
			str = @"kDNSServiceErr_BadState";
			break;
		case kDNSServiceErr_BadFlags:
			str = @"kDNSServiceErr_BadFlags";
			break;
		case kDNSServiceErr_Unsupported:
			str = @"kDNSServiceErr_Unsupported";
			break;
		case kDNSServiceErr_NotInitialized:
			str = @"kDNSServiceErr_NotInitialized";
			break;
		case kDNSServiceErr_AlreadyRegistered:
			str = @"kDNSServiceErr_AlreadyRegistered";
			break;
		case kDNSServiceErr_NameConflict:
			str = @"kDNSServiceErr_NameConflict";
			break;
		case kDNSServiceErr_Invalid:
			str = @"kDNSServiceErr_Invalid";
			break;
		case kDNSServiceErr_Firewall:
			str = @"kDNSServiceErr_Firewall";
			break;
		case kDNSServiceErr_Incompatible:
			str = @"kDNSServiceErr_Incompatible";
			break;
		case kDNSServiceErr_BadInterfaceIndex:
			str = @"kDNSServiceErr_BadInterfaceIndex";
			break;
		case kDNSServiceErr_Refused:
			str = @"kDNSServiceErr_Refused";
			break;
		case kDNSServiceErr_NoSuchRecord:
			str = @"kDNSServiceErr_NoSuchRecord";
			break;
		case kDNSServiceErr_NoAuth:
			str = @"kDNSServiceErr_NoAuth";
			break;
		case kDNSServiceErr_NoSuchKey:
			str = @"kDNSServiceErr_NoSuchKey";
			break;
		case kDNSServiceErr_NATTraversal:
			str = @"kDNSServiceErr_NATTraversal";
			break;
		case kDNSServiceErr_DoubleNAT:
			str = @"kDNSServiceErr_DoubleNAT";
			break;
		case kDNSServiceErr_BadTime:
			str = @"kDNSServiceErr_BadTime";
			break;
		case kDNSServiceErr_BadSig:
			str = @"kDNSServiceErr_BadSig";
			break;
		case kDNSServiceErr_BadKey:
			str = @"kDNSServiceErr_BadKey";
			break;
		case kDNSServiceErr_Transient:
			str = @"kDNSServiceErr_Transient";
			break;
		case kDNSServiceErr_ServiceNotRunning:
			str = @"kDNSServiceErr_ServiceNotRunning";
			break;
		case kDNSServiceErr_NATPortMappingUnsupported:
			str = @"kDNSServiceErr_NATPortMappingUnsupported";
			break;
		case kDNSServiceErr_NATPortMappingDisabled:
			str = @"kDNSServiceErr_NATPortMappingDisabled";
			break;
		case kDNSServiceErr_NoRouter:
			str = @"kDNSServiceErr_NoRouter";
			break;
		case kDNSServiceErr_PollingMode:
			str = @"kDNSServiceErr_PollingMode";
			break;
		case kDNSServiceErr_Timeout:
			str = @"kDNSServiceErr_Timeout";
			break;
	}
	
	return str;
}

NSString* UDInterfaceIndexToName(uint32_t interfaceIndex)
{
	char ifname[IFNAMSIZ];
	char* ifresult = if_indextoname(interfaceIndex, ifname);
	
	NSString* interfaceName = @"";
	if(ifresult != NULL)
		interfaceName = [NSString stringWithUTF8String:ifresult];
	
	return interfaceName;
}