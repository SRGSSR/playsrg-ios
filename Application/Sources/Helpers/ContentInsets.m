//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ContentInsets.h"

#import <CoconutKit/CoconutKit.h>
#import <DZNEmptyDataSet/DZNEmptyDataSet.h>

static void (*s_viewDidLoad)(id, SEL) = NULL;
static void (*s_viewWillAppear)(id, SEL) = NULL;
static void (*s_willLayoutSubviews)(id, SEL) = NULL;

static void swizzled_viewDidLoad(UIViewController *self, SEL _cmd);
static void swizzled_viewWillAppear(UIViewController *self, SEL _cmd);
static void swizzled_willLayoutSubviews(UIViewController *self, SEL _cmd);

static void UpdateContentInsetsForViewController(UIViewController *viewController);

@implementation UIViewController (ContentInsets)

+ (void)load
{
    HLSSwizzleSelector(self, @selector(viewDidLoad), swizzled_viewDidLoad, &s_viewDidLoad);
    HLSSwizzleSelector(self, @selector(viewWillAppear:), swizzled_viewWillAppear, &s_viewWillAppear);
    HLSSwizzleSelector(self, @selector(viewWillLayoutSubviews), swizzled_willLayoutSubviews, &s_willLayoutSubviews);
}

- (void)play_setNeedsContentInsetsUpdate
{
    UpdateContentInsetsForViewController(self);
    
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull viewController, NSUInteger idx, BOOL * _Nonnull stop) {
        [viewController play_setNeedsContentInsetsUpdate];
    }];
}

@end

/**
 *  Recommended additional content insets to be applied for child controllers of the specified view controller, taking
 *  into account contributions from its whole view controller hierarchy.
 */
static UIEdgeInsets ChildContentInsetsForViewController(UIViewController *viewController)
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    
    UIViewController *currentViewController = viewController;
    while (currentViewController) {
        if ([currentViewController conformsToProtocol:@protocol(ContainerContentInsets)]) {
            UIEdgeInsets currentInsets = ((id<ContainerContentInsets>)currentViewController).play_additionalContentInsets;
            insets = UIEdgeInsetsMake(insets.top + currentInsets.top,
                                      insets.left + currentInsets.left,
                                      insets.bottom + currentInsets.bottom,
                                      insets.right + currentInsets.right);
        }
        currentViewController = currentViewController.parentViewController;
    }
    
    return insets;
}

static void UpdateContentInsetsForViewController(UIViewController *viewController)
{
    if (! [viewController conformsToProtocol:@protocol(ContentInsets)]) {
        return;
    }
    
    UIViewController<ContentInsets> *contentViewController = (UIViewController<ContentInsets> *)viewController;
    NSArray<UIScrollView *> *scrollViews = contentViewController.play_contentScrollViews;
    UIEdgeInsets paddingInsets = contentViewController.play_paddingContentInsets;
    
    if (@available(iOS 11, *)) {
        viewController.additionalSafeAreaInsets = ChildContentInsetsForViewController(viewController.parentViewController);
        [scrollViews enumerateObjectsUsingBlock:^(UIScrollView * _Nonnull scrollView, NSUInteger idx, BOOL * _Nonnull stop) {
            scrollView.contentInset = paddingInsets;
        }];
    }
    else {
        UIEdgeInsets contentInsets = ContentInsetsForViewController(viewController);
        [scrollViews enumerateObjectsUsingBlock:^(UIScrollView * _Nonnull scrollView, NSUInteger idx, BOOL * _Nonnull stop) {
            scrollView.contentInset = UIEdgeInsetsMake(contentInsets.top + paddingInsets.top,
                                                       contentInsets.left + paddingInsets.left,
                                                       contentInsets.bottom + paddingInsets.bottom,
                                                       contentInsets.right + paddingInsets.right);
            scrollView.scrollIndicatorInsets = contentInsets;
        }];
    }
}

UIEdgeInsets ContentInsetsForViewController(UIViewController *viewController)
{
    UIEdgeInsets insets = ChildContentInsetsForViewController(viewController.parentViewController);
    if (@available(iOS 11, *)) {
        UIEdgeInsets safeAreaInsets = viewController.additionalSafeAreaInsets;
        return UIEdgeInsetsMake(insets.top + safeAreaInsets.top,
                                insets.left + safeAreaInsets.left,
                                insets.bottom + safeAreaInsets.bottom,
                                insets.right + safeAreaInsets.right);
    }
    else {
        return UIEdgeInsetsMake(insets.top + viewController.topLayoutGuide.length,
                                insets.left,
                                insets.bottom + viewController.bottomLayoutGuide.length,
                                insets.right);
    }
}

UIEdgeInsets ContentInsetsForScrollView(UIScrollView *scrollView)
{
    // Extract the padding applied to the scroll view, if any
    UIEdgeInsets paddingInsets = UIEdgeInsetsZero;
    if ([scrollView.nearestViewController conformsToProtocol:@protocol(ContentInsets)]) {
        UIViewController<ContentInsets> *contentViewController = (UIViewController<ContentInsets> *)scrollView.nearestViewController;
        if ([contentViewController.play_contentScrollViews containsObject:scrollView]) {
            paddingInsets = contentViewController.play_paddingContentInsets;
        }
    }
    
    if (@available(iOS 11, *)) {
        return UIEdgeInsetsMake(scrollView.adjustedContentInset.top + paddingInsets.top,
                                scrollView.adjustedContentInset.left + paddingInsets.left,
                                scrollView.adjustedContentInset.bottom + paddingInsets.bottom,
                                scrollView.adjustedContentInset.right + paddingInsets.right);
    }
    else {
        return UIEdgeInsetsMake(scrollView.contentInset.top + paddingInsets.top,
                                scrollView.contentInset.left + paddingInsets.left,
                                scrollView.contentInset.bottom + paddingInsets.bottom,
                                scrollView.contentInset.right + paddingInsets.right);
    }
}

CGFloat VerticalOffsetForEmptyDataSet(UIScrollView *scrollView)
{
    // Returns the offset to apply to the empty data set center so that its center lies within the visible
    // scroll area. This is required since the empty view is not resized to take into account content insets.
    UIEdgeInsets contentInsets = ContentInsetsForScrollView(scrollView);
    return -(contentInsets.top + contentInsets.bottom) / 2.f;
}

static void swizzled_viewDidLoad(UIViewController *self, SEL _cmd)
{
    s_viewDidLoad(self, _cmd);
    
    // Apply content insets calculations in -viewDidLoad as well for correct initial content offset
    UpdateContentInsetsForViewController(self);
}

static void swizzled_viewWillAppear(UIViewController *self, SEL _cmd)
{
    s_viewWillAppear(self, _cmd);
    
    // DZNEmpty data set calculations must account for content insets. Perform with the next run loop iteration to force
    // a data set reload with accurate context for calculations.
    dispatch_async(dispatch_get_main_queue(), ^{
        UpdateContentInsetsForViewController(self);
        
        if ([self conformsToProtocol:@protocol(ContentInsets)]) {
            UIViewController<ContentInsets> *contentViewController = (UIViewController<ContentInsets> *)self;
            NSArray<UIScrollView *> *scrollViews = contentViewController.play_contentScrollViews;
            [scrollViews enumerateObjectsUsingBlock:^(UIScrollView * _Nonnull scrollView, NSUInteger idx, BOOL * _Nonnull stop) {
                [scrollView reloadEmptyDataSet];
            }];
        }
    });
}

static void swizzled_willLayoutSubviews(UIViewController *self, SEL _cmd)
{
    s_willLayoutSubviews(self, _cmd);
    
    UpdateContentInsetsForViewController(self);
}
