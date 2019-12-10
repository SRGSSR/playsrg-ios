//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MenuItemInfo.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TabBarController : UITabBarController <UINavigationControllerDelegate>

/**
 *  Open the menu item.
 */
- (void)openMenuItemInfo:(MenuItemInfo *)menuItemInfo;

/**
 *  Push the specified view controller into the center navigation controller.
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Display the account header.
 */
- (void)displayAccountHeaderAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
