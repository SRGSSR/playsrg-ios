//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Supported banner styles.
 */
typedef NS_ENUM(NSInteger, BannerStyle) {
    BannerStyleInfo,
    BannerStyleWarning,
    BannerStyleError
};

/**
 *  Use banners to display messages to the end user. Banner should be provided with a view or view controller
 *  so that they can be correctly displayed in the associated context.
 */
@interface Banner : NSObject

/**
 *  Show a banner in the context of the specified view.
 *
 *  @param style   The style to apply.
 *  @param message The message to display.
 *  @param image   Optional leading image.
 *  @param view    The view context for which the banner must be displayed.
 */
+ (void)showWithStyle:(BannerStyle)style message:(nullable NSString *)message image:(nullable UIImage *)image sticky:(BOOL)sticky inView:(nullable UIView *)view;

/**
 *  Show a banner in the context of the specified view controller.
 *
 *  @param style          The style to apply.
 *  @param message        The message to display.
 *  @param image          Optional leading image.
 *  @param viewController The view context for which the banner must be displayed.
 */
+ (void)showWithStyle:(BannerStyle)style message:(nullable NSString *)message image:(nullable UIImage *)image sticky:(BOOL)sticky inViewController:(nullable UIViewController *)viewController;

@end

@interface Banner (Convenience)

/**
 *  Show a banner for the specified error.
 *
 *  @discussion If no error is provided, the method does nothing.
 */
+ (void)showError:(nullable NSError *)error inView:(nullable UIView *)view;
+ (void)showError:(nullable NSError *)error inViewController:(nullable UIViewController *)viewController;

/**
 *  Show a banner telling the user that the specified item has been (un)favorited.
 *
 *  @discussion If no name is provided, a standard description will be used.
 */
+ (void)showFavorite:(BOOL)isFavorite forItemWithName:(nullable NSString *)name inView:(nullable UIView *)view;
+ (void)showFavorite:(BOOL)isFavorite forItemWithName:(nullable NSString *)name inViewController:(nullable UIViewController *)viewController;

/**
 *  Show a banner telling the user that the specified show has been added to or removed from the subscription list.
 *
 *  @discussion If no name is provided, a standard description will be used.
 */
+ (void)showSubscription:(BOOL)subscribed forShowWithName:(nullable NSString *)name inView:(nullable UIView *)view;
+ (void)showSubscription:(BOOL)subscribed forShowWithName:(nullable NSString *)name inViewController:(nullable UIViewController *)viewController;

/**
 *  Show a banner telling the user that the specified item has been added to or removed from the watch later list.
 *
 *  @discussion If no name is provided, a standard description will be used.
 */
+ (void)showWatchLaterAdded:(BOOL)added forItemWithName:(nullable NSString *)name inView:(nullable UIView *)view;
+ (void)showWatchLaterAdded:(BOOL)added forItemWithName:(nullable NSString *)name inViewController:(nullable UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
