//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (PlaySRG)

@property (class, nonatomic, readonly) UIColor *play_redColor;
@property (class, nonatomic, readonly) UIColor *play_liveRedColor;
@property (class, nonatomic, readonly) UIColor *play_progressRedColor;
@property (class, nonatomic, readonly) UIColor *play_notificationRedColor;
@property (class, nonatomic, readonly) UIColor *play_blackColor;
@property (class, nonatomic, readonly) UIColor *play_lightGrayColor;
@property (class, nonatomic, readonly) UIColor *play_grayColor;
@property (class, nonatomic, readonly) UIColor *play_popoverGrayColor;

@property (class, nonatomic, readonly) UIColor *play_lightGrayButtonBackgroundColor;
@property (class, nonatomic, readonly) UIColor *play_grayThumbnailImageViewBackgroundColor;
@property (class, nonatomic, readonly) UIColor *play_blackDurationLabelBackgroundColor;
@property (class, nonatomic, readonly) UIColor *play_whiteBadgeColor;

@property (class, nonatomic, readonly) UIColor *play_blurTintColor API_DEPRECATED("Use UIBlurEffectStyleSystemMaterialDark", ios(9.0, 12.0));

@end

NS_ASSUME_NONNULL_END
