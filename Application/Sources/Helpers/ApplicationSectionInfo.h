//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "ApplicationConfiguration.h"
#import "Notification.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString * ApplicationSectionOptionKey NS_STRING_ENUM;

OBJC_EXPORT ApplicationSectionOptionKey const ApplicationSectionOptionNotificationKey;                              // Key to access the notification key, as an `Notification`.
OBJC_EXPORT ApplicationSectionOptionKey const ApplicationSectionOptionSearchMediaTypeOptionKey;                     // Key to access the search media type option key, as an `NSNUmber`.
OBJC_EXPORT ApplicationSectionOptionKey const ApplicationSectionOptionSearchQueryKey;                               // Key to access the search query key, as a `NSString`.
OBJC_EXPORT ApplicationSectionOptionKey const ApplicationSectionOptionShowAZIndexKey;                               // Key to access the A-Z index key, as a `NSString`.
OBJC_EXPORT ApplicationSectionOptionKey const ApplicationSectionOptionShowByDateDateKey;                            // Key to access the "show by date" date key, as an `NSDate`.

@interface ApplicationSectionInfo : NSObject

+ (ApplicationSectionInfo *)applicationSectionInfoWithApplicationSection:(ApplicationSection)applicationSection;
+ (ApplicationSectionInfo *)applicationSectionInfoWithNotification:(Notification *)notification;
+ (ApplicationSectionInfo *)applicationSectionInfoWithRadioChannel:(RadioChannel *)radioChannel;

+ (ApplicationSectionInfo *)applicationSectionInfoWithApplicationSection:(ApplicationSection)applicationSection options:(nullable NSDictionary<ApplicationSectionOptionKey, id> *)options;
+ (ApplicationSectionInfo *)applicationSectionInfoWithRadioChannel:(RadioChannel *)radioChannel options:(nullable NSDictionary<ApplicationSectionOptionKey, id> *)options;

- (instancetype)initWithApplicationSection:(ApplicationSection)applicationSection title:(NSString *)title uid:(nullable NSString *)uid options:(nullable NSDictionary<NSString *, id> *)options NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) ApplicationSection applicationSection;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy, nullable) NSString *uid;

@property (nonatomic, readonly, nullable) UIImage *image;

@property (nonatomic, readonly, nullable) NSDictionary<ApplicationSectionOptionKey, id> *options;

/**
 *  Returns a radio channel iff the application section info is related to a radio channel, `nil` otherwise.
 */
@property (nonatomic, readonly, nullable) RadioChannel *radioChannel;

@end

@interface ApplicationSectionInfo (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

