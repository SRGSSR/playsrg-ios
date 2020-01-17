//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ContentInsets.h"

#import <CoconutKit/CoconutKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Page item to be associated with a view controller.
 */
@interface PageItem : NSObject

/**
 *  Create a page item with the specified information.
 */
- (instancetype)initWithTitle:(nullable NSString *)title image:(nullable UIImage *)image;

/**
 *  Item title.
 */
@property (nonatomic, copy, readonly, nullable) NSString *title;

/**
 *  Item image.
 */
@property (nonatomic, readonly, nullable) UIImage *image;

@end

/**
 *  Abstract container class to display pages of contents, between which the user can change using a swipe or a tab strip.
 *  Tabs can be customized by associating a `PageItem` with a view controller.
 *
 *  To use `PageViewController`, bind its `placeholderViews` property to a single view where pages will be displayed.
 */
@interface PageViewController : HLSPlaceholderViewController <ContainerContentInsets, UIPageViewControllerDataSource, UIPageViewControllerDelegate>

/**
 *  Create an instance displaying the supplied view controllers, and starting at the specified page.
 *
 *  @discussion If the page is not valid, the first page will be used instead.
 */
- (instancetype)initWithViewControllers:(NSArray<UIViewController *> *)viewControllers initialPage:(NSInteger)initialPage NS_DESIGNATED_INITIALIZER;

/**
 *  Create an instance displaying the supplied view controllers, and starting with the first page.
 */
- (instancetype)initWithViewControllers:(NSArray<UIViewController *> *)viewControllers;

/**
 *  Switch to a tab index.
 *
 *  @discussion If the index is not valid, nothing changes and the method returns `NO`. Otherwise `YES`.
 */
- (BOOL)switchToIndex:(NSInteger)index animated:(BOOL)animated;

/**
 *  The view controllers loaded as pages.
 */
@property (nonatomic, readonly) NSArray<UIViewController *> *viewControllers;

@end

@interface UIViewController (PageViewController)

/**
 *  The parent page view controller, if any.
 */
@property (nonatomic, readonly, nullable) PageViewController *play_pageViewController;

/**
 *  Item information to be displayed by a page view controller.
 *
 *  @discussion If an image has been set, the title will not be displayed. It will still be used for accessibility
 *              purposes, though.
 */
@property (nonatomic, nullable) PageItem *play_pageItem;

@end

NS_ASSUME_NONNULL_END
