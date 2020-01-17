//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PageViewController.h"

#import "PlayLogger.h"
#import "TabStrip.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <Masonry/Masonry.h>

// Associated object keys
static void *s_pageItemKey = &s_pageItemKey;

@interface PageViewController ()

@property (nonatomic, weak) UIPageViewController *pageViewController;

@property (nonatomic) NSArray<UIViewController *> *viewControllers;
@property (nonatomic) NSInteger initialPage;

@property (nonatomic, weak) TabStrip *tabStrip;
@property (nonatomic, weak) UIVisualEffectView *blurView;

@end

@interface PageItem ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic) UIImage *image;

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
    
    TabStrip *tabStrip = [[TabStrip alloc] initWithFrame:blurView.bounds];
    [blurView.contentView addSubview:tabStrip];
    [tabStrip mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(blurView.contentView).with.insets(UIEdgeInsetsMake(8.f, 0.f, 8.f, 0.f));
    }];
    self.tabStrip = tabStrip;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tabStrip setPageViewController:self withInitialSelectedIndex:self.initialPage];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    UIViewController *initialViewController = self.viewControllers[self.initialPage];
    [self.pageViewController setViewControllers:@[initialViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
}

#pragma mark Actions

- (BOOL)switchToIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index >= 0 && index < self.viewControllers.count) {
        UIViewController *currentViewController = self.pageViewController.viewControllers.firstObject;
        NSUInteger currentIndex = [self.viewControllers indexOfObject:currentViewController];
        
        UIViewController *newViewController = self.viewControllers[index];
        UIPageViewControllerNavigationDirection direction = (currentIndex < index) ? UIPageViewControllerNavigationDirectionForward : UIPageViewControllerNavigationDirectionReverse;
        [self.pageViewController setViewControllers:@[newViewController] direction:direction animated:animated completion:nil];
        
        if (self.tabStrip) {
            self.tabStrip.selectedIndex = index;
        }
        else {
            self.initialPage = index;
        }
        return YES;
    }
    else {
        return NO;
    }
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

#pragma mark ContainerContentInsets protocol

- (UIEdgeInsets)play_additionalContentInsets
{
    return UIEdgeInsetsMake(CGRectGetHeight(self.blurView.frame), 0.f, 0.f, 0.f);
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

@end

@implementation PageItem

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image
{
    if (self = [super init]) {
        self.title = title;
        self.image = image;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; title = %@; image = %@>",
            self.class,
            self,
            self.title,
            self.image];
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

// Use KVO-compliant naming convention
- (void)setPlay_pageItem:(PageItem *)pageItem
{
    objc_setAssociatedObject(self, s_pageItemKey, pageItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (PageItem *)play_pageItem
{
    return objc_getAssociatedObject(self, s_pageItemKey);
}

@end

