//
//  UDOutputItem.m
//  Underdark
//
//  Created by Virl on 18/03/16.
//  Copyright © 2016 Underdark. All rights reserved.
//

#import "UDOutputItem.h"

#import "UDAsyncUtils.h"

typedef NS_ENUM(NSUInteger, UDOutputItemState) {
	UDOutputItemStateInit,
	UDOutputItemStatePrepared,
	UDOutputItemStateDiscarded,
	UDOutputItemStateFinished
};

@implementation UDOutputItem
{
	dispatch_queue_t _Nonnull _queue;
	id<UDData> _Nonnull _source;
	
	UDOutputItemState volatile _state;
}

- (nonnull instancetype) init
{
	if(!(self = [super init]))
		return self;
	
	return self;
}

- (void) dealloc
{
	[self discard];
}

- (nonnull instancetype) initWithData:(nonnull id<UDData>)data queue:(nonnull dispatch_queue_t)queue delegate:(nonnull id<UDOutputItemDelegate>)delegate
{
	if(!(self = [super init]))
		return self;
	
	_delegate = delegate;
	_queue = queue;
	_source = data;
	
	_state = UDOutputItemStateInit;
	
	[_source acquire];

	return self;
}

- (void) prepare
{
	// Queue.
	
	NSAssert(_state == UDOutputItemStateInit, @"UDOutputItemState != Init");
	
	[_source retrieve:^(NSData * _Nullable data) {
		// Any thread.
		if(data == nil)
		{
			[self discard];
			return;
		}
		
		sldispatch_async(_queue, ^{
			_state = UDOutputItemStatePrepared;

			_data = data;
			[_delegate outputItemPrepared];
		});
	}];
}

- (void) discard
{
	// Any thread.
	if(_state == UDOutputItemStateDiscarded || _state == UDOutputItemStateFinished)
		return;

	_state = UDOutputItemStateDiscarded;
	
	[_source giveup];
	
	id<UDOutputItemDelegate> delegate = _delegate;
	
	sldispatch_async(_queue, ^{
		[delegate outputItemDiscarded];
	});
}

- (void) finish
{
	NSAssert(_state == UDOutputItemStatePrepared, @"UDOutputItemState != Prepared");
		
	_state = UDOutputItemStateFinished;
	
	[_source giveup];

	sldispatch_async(_queue, ^{
		[_delegate outputItemFinished];
	});
}

@end
