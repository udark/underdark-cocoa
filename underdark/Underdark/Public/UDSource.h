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

typedef void (^UDSourceRetrieveBlock)(NSData* _Nullable data);

/**
 * Protocol for raw frame data storage for sending and receiving.
 */
@protocol UDSource<NSObject>

/**
 * Queue on which retrieve: method will be called.
 */
@property (nonatomic, readonly, nonnull) dispatch_queue_t queue;

/**
 * Unique ID for the data being sent (can be nil).
 * Using for automatic data sharing between
 */
@property (nonatomic, readonly, nullable) NSString* dataId;

/**
 * Retrieves data from object.
 * Implementations should call the completion handler
 * with retrieved data as argument, or null if data cannot be retrieved.
 */
- (void) retrieve:(UDSourceRetrieveBlock _Nonnull)completion;

@end