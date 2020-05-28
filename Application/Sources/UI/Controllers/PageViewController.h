//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ContentInsets.h"
#import "TabBarActionable.h"

#import <CoconutKit/CoconutKit.h>
#import <SRGAnalytics/SRGAnalytics.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Abstract container class to display pages of contents, between which the user can change using a swipe or a tab strip.
 *  Tabs can be customized by associating a `UITabBarItem` with a view controller.
 *
 *  To use `PageViewController`, bind its `placeholderViews` property to a single view where pages will be displayed.
 */
@interface PageViewController : HLSPlaceholderViewController <ContainerContentInsets, SRGAnalyticsContainerViewTracking, TabBarActionable, UIPageViewControllerDataSource, UIPageViewControllerDelegate>

/**
 *  Create an instance displaying the supplied view controllers, and starting at the specified page.
 *
 *  @discussion If the page is not valid, the first page will be used instead.
 */
- (instancetype)initWithViewControllers:(NSArray<UIViewController *> *)viewControllers initialPage:(NSUInteger)initialPage NS_DESIGNATED_INITIALIZER;

/**
 *  Create an instance displaying the supplied view controllers, and starting with the first page.
 */
- (instancetype)initWithViewControllers:(NSArray<UIViewController *> *)viewControllers;

/**
 *  Switch to a tab index.
 *
 *  @discussion If the index is not valid, nothing changes and the method returns `NO`. Otherwise `YES`.
 */
- (BOOL)switchToIndex:(NSUInteger)index animated:(BOOL)animated;

/**
 *  The view controllers loaded as pages.
 */
@property (nonatomic, readonly) NSArray<UIViewController *> *viewControllers;

@end

/**
 *  Subclassing hooks.
 */
@interface PageViewController (Subclassing)

/**
 *  Called when the spcified view controller has been displayed, either because the user tapped on the corresponding
 *  tab, or because `-switchToIndex:animated:` has been called.
 */
- (void)didDisplayViewController:(UIViewController *)viewController animated:(BOOL)animated NS_REQUIRES_SUPER;

@end

@interface UIViewController (PageViewController)

/**
 *  The parent page view controller, if any.
 */
@property (nonatomic, readonly, nullable) PageViewController *play_pageViewController;

@end

NS_ASSUME_NONNULL_END
