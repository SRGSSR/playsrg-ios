//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PageViewController.h"

#import "PlayLogger.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import "MaterialTabs.h"
#import <Masonry/Masonry.h>

@interface PageViewController () <MDCTabBarDelegate>

@property (nonatomic, weak) UIPageViewController *pageViewController;

@property (nonatomic) NSArray<UIViewController *> *viewControllers;
@property (nonatomic) NSInteger initialPage;

@property (nonatomic, weak) MDCTabBar *tabBar;
@property (nonatomic, weak) UIVisualEffectView *blurView;

@end

@implementation PageViewController

#pragma mark Object lifecycle

- (instancetype)initWithViewControllers:(NSArray<UIViewController *> *)viewControllers initialPage:(NSInteger)initialPage
{
    NSAssert(viewControllers.count != 0, @"At least one view controller is required");
    
    if (self = [super init]) {
        self.viewControllers = viewControllers;
        
        if (initialPage < 0 || initialPage >= viewControllers.count) {
            PlayLogWarning(@"pageViewController", @"Invalid page. Fixed to 0");
            initialPage = 0;
        }
        self.initialPage = initialPage;
        
        UIPageViewController *pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                                                   navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                                                 options:@{ UIPageViewControllerOptionInterPageSpacingKey : @100.f }];
        pageViewController.delegate = self;
        
        // Only allow scrolling if several pages are available
        if (viewControllers.count > 1) {
            pageViewController.dataSource = self;
        }
        
        [self setInsetViewController:pageViewController atIndex:0];
        self.pageViewController = pageViewController;
    }
    return self;
}

- (instancetype)initWithViewControllers:(NSArray<UIViewController *> *)viewControllers
{
    return [self initWithViewControllers:viewControllers initialPage:0];
}

#pragma mark View lifecycle

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    
    UIView *placeholderView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:placeholderView];
    [placeholderView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    self.placeholderViews = @[placeholderView];
    
    UIBlurEffectStyle blurEffectStyle;
    if (@available(iOS 13, *)) {
        blurEffectStyle = UIBlurEffectStyleSystemMaterialDark;
    }
    else {
        blurEffectStyle = UIBlurEffectStyleDark;
    }
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:blurEffectStyle];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    [self.view addSubview:blurView];
    [blurView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.mas_topLayoutGuide);          // Warning: Needs self.view to be set, otherwise leads to infinite recursion
        make.left.equalTo(self.view.mas_left);
        make.right.equalTo(self.view.mas_right);
        make.height.equalTo(@60);
    }];
    self.blurView = blurView;
    
    __block BOOL hasTitle = NO;
    __block BOOL hasImage = NO;
    
    NSMutableArray<UITabBarItem *> *tabBarItems = [NSMutableArray array];
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull viewController, NSUInteger idx, BOOL * _Nonnull stop) {
        UITabBarItem *tabBarItem = viewController.tabBarItem;
        if (tabBarItem.title) {
            hasTitle = YES;
        }
        if (tabBarItem.image) {
            hasImage = YES;
        }
        [tabBarItems addObject:tabBarItem];
    }];
    
    MDCTabBar *tabBar = [[MDCTabBar alloc] initWithFrame:blurView.bounds];
    tabBar.tintColor = UIColor.whiteColor;
    // Use ripple effect without color, so that there is no Material-like highlighting (we are NOT adopting Material)
    tabBar.enableRippleBehavior = YES;
    tabBar.rippleColor = UIColor.clearColor;
    tabBar.items = tabBarItems.copy;
    tabBar.alignment = MDCTabBarAlignmentCenter;
    if (hasTitle && hasImage) {
        tabBar.itemAppearance = MDCTabBarItemAppearanceTitledImages;
    }
    else if (hasImage) {
        tabBar.itemAppearance = MDCTabBarItemAppearanceImages;
    }
    else {
        tabBar.itemAppearance = MDCTabBarItemAppearanceTitles;
    }
    tabBar.delegate = self;
    [blurView.contentView addSubview:tabBar];
    [tabBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(blurView.contentView);
    }];
    self.tabBar = tabBar;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tabBar.selectedItem = self.tabBar.items[self.initialPage];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    UIViewController *initialViewController = self.viewControllers[self.initialPage];
    [self.pageViewController setViewControllers:@[initialViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
}

#pragma mark Actions

- (BOOL)switchToIndex:(NSInteger)index animated:(BOOL)animated
{
    if (! [self displayPageAtIndex:index animated:animated]) {
        return NO;
    }
    
    [self.tabBar setSelectedItem:self.tabBar.items[index] animated:animated];
    return YES;
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Status bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark Accessibility

- (BOOL)accessibilityPerformEscape
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return YES;
    }
    else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark Display

- (BOOL)displayPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= self.viewControllers.count) {
        return NO;
    }
    
    UIViewController *currentViewController = self.pageViewController.viewControllers.firstObject;
    NSUInteger currentIndex = [self.viewControllers indexOfObject:currentViewController];
    UIPageViewControllerNavigationDirection direction = (currentIndex < index) ? UIPageViewControllerNavigationDirectionForward : UIPageViewControllerNavigationDirectionReverse;
    
    UIViewController *newViewController = self.viewControllers[index];
    [self.pageViewController setViewControllers:@[newViewController] direction:direction animated:animated completion:nil];
    return YES;
}

- (void)updateTabForViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSUInteger currentIndex = [self.viewControllers indexOfObject:viewController];
    [self.tabBar setSelectedItem:self.tabBar.items[currentIndex] animated:animated];
}

#pragma mark ContainerContentInsets protocol

- (UIEdgeInsets)play_additionalContentInsets
{
    return UIEdgeInsetsMake(CGRectGetHeight(self.blurView.frame), 0.f, 0.f, 0.f);
}

#pragma mark MDCTabBarDelegate protocol

- (void)tabBar:(MDCTabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    NSUInteger index = [tabBar.items indexOfObject:item];
    [self displayPageAtIndex:index animated:YES];
}

#pragma mark UIPageViewControllerDataSource protocol

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger currentIndex = [self.viewControllers indexOfObject:viewController];
    if (currentIndex > 0) {
        return self.viewControllers[currentIndex - 1];
    }
    else {
        return nil;
    }
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger currentIndex = [self.viewControllers indexOfObject:viewController];
    if (currentIndex < self.viewControllers.count - 1) {
        return self.viewControllers[currentIndex + 1];
    }
    else {
        return nil;
    }
}

#pragma mark UIPageViewControllerDelegate protocol

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    if (completed) {
        [self updateTabForViewController:pageViewController.viewControllers.firstObject animated:YES];
    }
}

@end

@implementation UIViewController (PageViewController)

#pragma mark Getters and setters

- (PageViewController *)play_pageViewController
{
    UIViewController *parentViewController = self.parentViewController.parentViewController;
    if ([parentViewController isKindOfClass:PageViewController.class]) {
        return (PageViewController *)parentViewController;
    }
    else {
        return nil;
    }
}

@end

