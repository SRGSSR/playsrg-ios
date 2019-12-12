//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ContentInsets.h"
#import "RadioChannel.h"

#import <CoconutKit/CoconutKit.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations.
@class MainNavigationController;

/**
 *  Main navigation controller delegate protocol.
 */
@protocol MainNavigationControllerDelegate <NSObject>

@optional

/**
 *  Called when a view controller is shown (either added or revealed).
 */
- (void)mainNavigationController:(MainNavigationController *)mainNavigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)mainNavigationController:(MainNavigationController *)mainNavigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;

@end

/**
 *  Main navigation controller upon which the application navigation is based. If the business unit supports it, a mini
 *  player is displayed at its bottom.
 */
@interface MainNavigationController : HLSViewController <ContainerContentInsets>

/**
 *  Create the navigation with the specified view controller as root. If a radio channel is provided, the navigation bar
 *  will be adjusted accordingly.
 */
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController radioChannel:(nullable RadioChannel *)radioChannel;;

/**
 *  Push the specified view controller.
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Pop the current top view controller.
 */
- (void)popViewControllerAnimated:(BOOL)animated;

/**
 *  Pop to the root view controller.
 */
- (void)popToRootViewControllerAnimated:(BOOL)animated;

/**
 *  The list of view controllers currently loaded in the navigation controller, from the root to the topmost one.
 */
@property (nonatomic, readonly) NSArray<__kindof UIViewController *> *viewControllers;

/**
 *  The navigation delegate.
 */
@property (nonatomic, weak) id<MainNavigationControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
