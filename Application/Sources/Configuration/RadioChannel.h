//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations
@class RadioChannel;

/**
 *  Images associated with the radio channel.
 */
OBJC_EXPORT UIImage *RadioChannelBanner22Image(RadioChannel * _Nullable radioChannel);
OBJC_EXPORT UIImage *RadioChannelLogo22Image(RadioChannel * _Nullable radioChannel);
OBJC_EXPORT UIImage *RadioChannelLogo44Image(RadioChannel * _Nullable radioChannel);
OBJC_EXPORT UIImage *RadioChannelNavigationBarImage(RadioChannel * _Nullable radioChannel);

/**
 *  Image overrides.
 */
OBJC_EXPORT NSString * _Nullable RadioChannelImageOverridePath(RadioChannel * _Nullable radioChannel, NSString *type);

/**
 *  Represent a radio channel in the application configuration.
 */
@interface RadioChannel : NSObject

/**
 *  Create the radio channel from a dictionary. Return `nil` if the dictionary format is incorrect.
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

/**
 *  The unique identifier of the radio channel (`SRGChannel` uid).
 */
@property (nonatomic, readonly, copy) NSString *uid;

/**
 *  The radio channel name.
 */
@property (nonatomic, readonly, copy) NSString *name;

/**
 *  The radio channel primary color.
 */
@property (nonatomic, readonly) UIColor *color;

/**
 *  The radio channel title color (white by default).
 */
@property (nonatomic, readonly) UIColor *titleColor;

/**
 *  Return `YES` iff the status bar should be dark for this channel.
 */
@property (nonatomic, readonly, getter=hasDarkStatusBar) BOOL darkStatusBar;

/**
 *  Set to `YES` to hide the badge stroke (the badge stroke color matches title color). Default is `NO`.
 */
@property (nonatomic, readonly, getter=isBadgeStrokeHidden) BOOL badgeStrokeHidden;

/**
 *  The number of placeholders to be displayed while content is being loaded.
 */
@property (nonatomic, readonly) NSInteger numberOfLivePlaceholders;

/**
 *  The sections ordered list.
 */
@property (nonatomic, readonly) NSArray<NSNumber *> *homeSections;                      // wrap `HomeSection` values

@end

NS_ASSUME_NONNULL_END
