//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSection.h"
#import "RadioChannel.h"
#import "TopicSection.h"
#import "TVChannel.h"

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSArray<NSNumber * /* HomeSection */> * _Nullable FirebaseConfigurationHomeSections(NSString *string);
OBJC_EXPORT NSArray<NSNumber * /* TopicSection */> * _Nullable FirebaseConfigurationTopicSections(NSString *string);

/**
 *  Manages configuration with Firebase, including updates.
 */
@interface FirebaseConfiguration: NSObject

/**
 *  Create a configuration with the provided dictionary as local fallback, and a block called when the configuration
 *  is updated.
 */
- (instancetype)initWithDefaultsDictionary:(NSDictionary *)defaultsDictionary updateBlock:(void (^)(FirebaseConfiguration *configuration))updateBlock;

/**
 *  Primitive type accessors. Return `nil` if the key is not found, or if the type of the object is incorrect.
 */
- (nullable NSString *)stringForKey:(NSString *)key;
- (nullable NSNumber *)numberForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

/**
 *  JSON accessors. Return `nil` if the key is not found, or if the type of the object is incorrect.
 */
- (nullable NSArray *)JSONArrayForKey:(NSString *)key;
- (nullable NSDictionary *)JSONDictionaryForKey:(NSString *)key;

/**
 *  Section accessors. Return an empty array if no valid data is found under the specified key.
 */
- (NSArray<NSNumber * /* HomeSection */> *)homeSectionsForKey:(NSString *)key;
- (NSArray<NSNumber * /* TopicSection */> *)topicSectionsForKey:(NSString *)key;

/**
 *  Channel accessors. Return an empty array if no valid data is found under the specified key.
 */
- (NSArray<RadioChannel *> *)radioChannelsForKey:(NSString *)key defaultHomeSections:(NSArray<NSNumber * /* HomeSection */> *)defaultHomeSections;
- (NSArray<TVChannel *> *)tvChannelsForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END