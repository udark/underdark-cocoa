//
// Created by Virl on 05/08/16.
// Copyright (c) 2016 Underdark. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UDSource.h"

@class UDAsyncSource;

typedef void (^UDAsyncSourceHandler)(NSData* _Nullable data);
typedef void (^UDAsyncSourceRetriever)(UDAsyncSource* _Nonnull source, UDAsyncSourceHandler _Nonnull handler);

@interface UDAsyncSource : NSObject <UDSource>

@property (nonatomic, readonly, nonnull) UDFuture<NSData*, id>* future;
@property (nonatomic, readonly, nullable) NSString* dataId;

- (nonnull instancetype) init NS_UNAVAILABLE;

- (nonnull instancetype) initWithQueue:(nullable dispatch_queue_t)queue
								dataId:(nullable NSString*)dataId
                                 block:(nonnull UDAsyncSourceRetriever)block NS_DESIGNATED_INITIALIZER;

@end
