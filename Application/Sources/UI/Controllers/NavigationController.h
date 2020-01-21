//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RadioChannel.h"

#import "PlayApplicationNavigation.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Standard navigation controller with Play look-and-feel and behavior.
 */
@interface NavigationController : UINavigationController <PlayApplicationNavigation>

/**
 *  Create a navigation controller with standard customizable look-and-feel.
 *
 *  @param tintColor       The tint color applied to the title and icons.
 *  @param backgroundColor The background color to be applied. If none standard blur is applied, otherwise the navigation bar is opaque.
 *  @param statusBarStyle  The style of the status bar when the navigation controller is displayed.
 */
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
                                 tintColor:(nullable UIColor *)tintColor
                           backgroundColor:(nullable UIColor *)backgroundColor
                            statusBarStyle:(UIStatusBarStyle)statusBarStyle;

/**
 *  Create a navigation controller with standard look-and-feel.
 */
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

/**
 *  Update the navigation bar, optionally branded for a radio channel. If none is provided, a default look-and-feel is applied.
*/
- (void)updateWithRadioChannel:(nullable RadioChannel *)radioChannel;

@end

@interface NavigationController (Unavailable)

- (instancetype)initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
